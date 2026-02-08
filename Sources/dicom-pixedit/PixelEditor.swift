import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Pixel editing operations
enum PixelOperation {
    case mask(x: Int, y: Int, width: Int, height: Int, fillValue: Int)
    case crop(x: Int, y: Int, width: Int, height: Int)
    case windowLevel(center: Double, width: Double)
    case invert
}

/// Descriptor holding pixel data metadata from the DICOM data set
struct PixelDataDescriptor {
    let rows: Int
    let columns: Int
    let bitsAllocated: Int
    let bitsStored: Int
    let highBit: Int
    let pixelRepresentation: Int
    let samplesPerPixel: Int
    
    /// Bytes per single sample value
    var bytesPerSample: Int {
        bitsAllocated / 8
    }
    
    /// Bytes per pixel (accounts for multi-sample pixels like RGB)
    var bytesPerPixel: Int {
        bytesPerSample * samplesPerPixel
    }
    
    /// Maximum storable value based on bits stored
    var maxValue: Int {
        (1 << bitsStored) - 1
    }
    
    /// Whether pixel values are signed
    var isSigned: Bool {
        pixelRepresentation == 1
    }
}

/// Pixel data editor for DICOM files
struct PixelEditor {
    let verbose: Bool
    
    /// Parse a region string in "x,y,width,height" format
    func parseRegion(_ regionString: String) throws -> (x: Int, y: Int, width: Int, height: Int) {
        let parts = regionString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else {
            throw PixelEditError.invalidRegion(regionString)
        }
        guard parts[0] >= 0, parts[1] >= 0, parts[2] > 0, parts[3] > 0 else {
            throw PixelEditError.invalidRegion(regionString)
        }
        return (x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }
    
    /// Process a DICOM file with the given pixel editing operations
    func processFile(inputPath: String, outputPath: String, operations: [PixelOperation]) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        let fileData = try Data(contentsOf: inputURL)
        let dicomFile = try DICOMFile.read(from: fileData)
        
        var dataSet = dicomFile.dataSet
        let descriptor = try extractDescriptor(from: dataSet)
        
        guard let pixelElement = dataSet[.pixelData] else {
            throw PixelEditError.noPixelData
        }
        var pixelData = pixelElement.valueData
        
        if verbose {
            fprintln("Image: \(descriptor.columns)x\(descriptor.rows), \(descriptor.bitsAllocated)-bit, \(descriptor.samplesPerPixel) sample(s)")
        }
        
        var currentRows = descriptor.rows
        var currentColumns = descriptor.columns
        
        for operation in operations {
            switch operation {
            case .mask(let x, let y, let width, let height, let fillValue):
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                try applyMask(pixelData: &pixelData, descriptor: currentDescriptor,
                              region: (x: x, y: y, width: width, height: height), fillValue: fillValue)
                if verbose {
                    fprintln("Applied mask: (\(x),\(y)) \(width)x\(height), fill=\(fillValue)")
                }
                
            case .crop(let x, let y, let width, let height):
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                let (croppedData, newWidth, newHeight) = try applyCrop(
                    pixelData: pixelData, descriptor: currentDescriptor,
                    region: (x: x, y: y, width: width, height: height))
                pixelData = croppedData
                currentColumns = newWidth
                currentRows = newHeight
                if verbose {
                    fprintln("Cropped to: \(newWidth)x\(newHeight)")
                }
                
            case .windowLevel(let center, let width):
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                try applyWindowLevel(pixelData: &pixelData, descriptor: currentDescriptor,
                                     center: center, width: width)
                if verbose {
                    fprintln("Applied window/level: center=\(center), width=\(width)")
                }
                
            case .invert:
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                try applyInvert(pixelData: &pixelData, descriptor: currentDescriptor)
                if verbose {
                    fprintln("Inverted pixel values")
                }
            }
        }
        
        // Update pixel data element
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: pixelElement.vr, data: pixelData)
        
        // Update rows/columns if changed by crop
        if currentRows != descriptor.rows {
            dataSet.setUInt16(UInt16(currentRows), for: .rows)
        }
        if currentColumns != descriptor.columns {
            dataSet.setUInt16(UInt16(currentColumns), for: .columns)
        }
        
        let updatedFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: dataSet)
        let outputData = try updatedFile.write()
        try outputData.write(to: outputURL)
        
        if verbose {
            fprintln("Written: \(outputURL.path)")
        }
    }
    
    // MARK: - Pixel Operations
    
    /// Apply a mask to a rectangular region, setting all pixels to the fill value
    func applyMask(pixelData: inout Data, descriptor: PixelDataDescriptor,
                   region: (x: Int, y: Int, width: Int, height: Int), fillValue: Int) throws {
        let endX = min(region.x + region.width, descriptor.columns)
        let endY = min(region.y + region.height, descriptor.rows)
        
        guard region.x < descriptor.columns, region.y < descriptor.rows else {
            throw PixelEditError.regionOutOfBounds
        }
        
        let startX = max(region.x, 0)
        let startY = max(region.y, 0)
        
        for y in startY..<endY {
            for x in startX..<endX {
                let pixelOffset = y * descriptor.columns + x
                for s in 0..<descriptor.samplesPerPixel {
                    let sampleIndex = pixelOffset * descriptor.samplesPerPixel + s
                    setPixelValue(in: &pixelData, at: sampleIndex, value: fillValue, descriptor: descriptor)
                }
            }
        }
    }
    
    /// Crop pixel data to the specified region
    func applyCrop(pixelData: Data, descriptor: PixelDataDescriptor,
                   region: (x: Int, y: Int, width: Int, height: Int)) throws -> (Data, Int, Int) {
        let endX = min(region.x + region.width, descriptor.columns)
        let endY = min(region.y + region.height, descriptor.rows)
        
        guard region.x < descriptor.columns, region.y < descriptor.rows else {
            throw PixelEditError.regionOutOfBounds
        }
        
        let startX = max(region.x, 0)
        let startY = max(region.y, 0)
        let newWidth = endX - startX
        let newHeight = endY - startY
        
        var croppedData = Data(capacity: newWidth * newHeight * descriptor.bytesPerPixel)
        
        for y in startY..<endY {
            let srcRowStart = (y * descriptor.columns + startX) * descriptor.bytesPerPixel
            let srcRowEnd = srcRowStart + newWidth * descriptor.bytesPerPixel
            
            guard srcRowEnd <= pixelData.count else {
                throw PixelEditError.pixelDataTruncated
            }
            
            croppedData.append(pixelData[srcRowStart..<srcRowEnd])
        }
        
        return (croppedData, newWidth, newHeight)
    }
    
    /// Apply window/level transformation permanently to pixel data
    func applyWindowLevel(pixelData: inout Data, descriptor: PixelDataDescriptor,
                          center: Double, width: Double) throws {
        guard width > 0 else {
            throw PixelEditError.invalidWindowWidth
        }
        
        let totalPixels = descriptor.rows * descriptor.columns * descriptor.samplesPerPixel
        let maxOutput = Double(descriptor.maxValue)
        
        for i in 0..<totalPixels {
            let rawValue = getPixelValue(from: pixelData, at: i, descriptor: descriptor)
            let input = Double(rawValue)
            
            // DICOM window/level formula (PS3.3 C.11.2.1.2)
            let output: Double
            if width <= 1.0 {
                // Degenerate case: threshold at center
                output = input <= center - 0.5 ? 0.0 : maxOutput
            } else if input <= center - 0.5 - (width - 1.0) / 2.0 {
                output = 0.0
            } else if input > center - 0.5 + (width - 1.0) / 2.0 {
                output = maxOutput
            } else {
                output = ((input - (center - 0.5)) / (width - 1.0) + 0.5) * maxOutput
            }
            
            let clamped = Int(max(0.0, min(maxOutput, output)))
            setPixelValue(in: &pixelData, at: i, value: clamped, descriptor: descriptor)
        }
    }
    
    /// Invert all pixel values
    func applyInvert(pixelData: inout Data, descriptor: PixelDataDescriptor) throws {
        let totalPixels = descriptor.rows * descriptor.columns * descriptor.samplesPerPixel
        let maxVal = descriptor.maxValue
        
        for i in 0..<totalPixels {
            let value = getPixelValue(from: pixelData, at: i, descriptor: descriptor)
            let inverted = maxVal - value
            setPixelValue(in: &pixelData, at: i, value: inverted, descriptor: descriptor)
        }
    }
    
    // MARK: - Helpers
    
    /// Extract pixel data descriptor from the data set
    private func extractDescriptor(from dataSet: DataSet) throws -> PixelDataDescriptor {
        guard let rows = dataSet.uint16(for: .rows) else {
            throw PixelEditError.missingTag("Rows")
        }
        guard let columns = dataSet.uint16(for: .columns) else {
            throw PixelEditError.missingTag("Columns")
        }
        
        let bitsAllocated = dataSet.uint16(for: .bitsAllocated) ?? 16
        let bitsStored = dataSet.uint16(for: .bitsStored) ?? bitsAllocated
        let highBit = dataSet.uint16(for: .highBit) ?? (bitsStored - 1)
        let pixelRep = dataSet.uint16(for: .pixelRepresentation) ?? 0
        let samplesPerPixel = dataSet.uint16(for: .samplesPerPixel) ?? 1
        
        return PixelDataDescriptor(
            rows: Int(rows),
            columns: Int(columns),
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            highBit: Int(highBit),
            pixelRepresentation: Int(pixelRep),
            samplesPerPixel: Int(samplesPerPixel)
        )
    }
    
    /// Create a new descriptor with updated rows/columns (used after crop)
    private func descriptorWith(_ base: PixelDataDescriptor, rows: Int, columns: Int) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: base.bitsAllocated,
            bitsStored: base.bitsStored,
            highBit: base.highBit,
            pixelRepresentation: base.pixelRepresentation,
            samplesPerPixel: base.samplesPerPixel
        )
    }
    
    /// Read a single pixel sample value at the given sample index
    private func getPixelValue(from data: Data, at sampleIndex: Int, descriptor: PixelDataDescriptor) -> Int {
        let byteOffset = sampleIndex * descriptor.bytesPerSample
        
        if descriptor.bytesPerSample == 1 {
            guard byteOffset < data.count else { return 0 }
            let raw = data[data.startIndex + byteOffset]
            return descriptor.isSigned ? Int(Int8(bitPattern: raw)) : Int(raw)
        } else {
            // 16-bit (little-endian)
            let idx = data.startIndex + byteOffset
            guard idx + 1 < data.endIndex else { return 0 }
            let lo = UInt16(data[idx])
            let hi = UInt16(data[idx + 1])
            let raw = lo | (hi << 8)
            return descriptor.isSigned ? Int(Int16(bitPattern: raw)) : Int(raw)
        }
    }
    
    /// Write a single pixel sample value at the given sample index
    private func setPixelValue(in data: inout Data, at sampleIndex: Int, value: Int, descriptor: PixelDataDescriptor) {
        let byteOffset = sampleIndex * descriptor.bytesPerSample
        
        if descriptor.bytesPerSample == 1 {
            guard byteOffset < data.count else { return }
            if descriptor.isSigned {
                data[data.startIndex + byteOffset] = UInt8(bitPattern: Int8(clamping: value))
            } else {
                data[data.startIndex + byteOffset] = UInt8(clamping: value)
            }
        } else {
            // 16-bit (little-endian)
            let idx = data.startIndex + byteOffset
            guard idx + 1 < data.endIndex else { return }
            if descriptor.isSigned {
                let clamped = UInt16(bitPattern: Int16(clamping: value))
                data[idx] = UInt8(clamped & 0xFF)
                data[idx + 1] = UInt8(clamped >> 8)
            } else {
                let clamped = UInt16(clamping: value)
                data[idx] = UInt8(clamped & 0xFF)
                data[idx + 1] = UInt8(clamped >> 8)
            }
        }
    }
}

// MARK: - Errors

enum PixelEditError: Error, LocalizedError {
    case invalidRegion(String)
    case noPixelData
    case regionOutOfBounds
    case pixelDataTruncated
    case missingTag(String)
    case invalidWindowWidth
    
    var errorDescription: String? {
        switch self {
        case .invalidRegion(let str):
            return "Invalid region format '\(str)'. Expected x,y,width,height with positive width/height"
        case .noPixelData:
            return "DICOM file contains no pixel data"
        case .regionOutOfBounds:
            return "Region is entirely outside the image bounds"
        case .pixelDataTruncated:
            return "Pixel data is shorter than expected for the given image dimensions"
        case .missingTag(let name):
            return "Required DICOM tag missing: \(name)"
        case .invalidWindowWidth:
            return "Window width must be greater than 0"
        }
    }
}

// MARK: - Stderr output

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
