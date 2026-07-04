import Foundation
import DICOMCore
import DICOMDictionary

/// Pixel editing operations.
public enum PixelOperation: Sendable {
    case mask(x: Int, y: Int, width: Int, height: Int, fillValue: Int)
    case crop(x: Int, y: Int, width: Int, height: Int)
    case windowLevel(center: Double, width: Double)
    case invert
}

/// Image dimensions/format after a pixel-edit run (for adapter summaries).
public struct PixelEditInfo: Sendable {
    public let columns: Int
    public let rows: Int
    public let bitsAllocated: Int
    public let samplesPerPixel: Int
}

/// Internal descriptor holding pixel data metadata from the DICOM data set.
/// (Named to avoid colliding with the public `DICOMCore.PixelDataDescriptor`.)
struct PixelEditDescriptor {
    let rows: Int
    let columns: Int
    let bitsAllocated: Int
    let bitsStored: Int
    let highBit: Int
    let pixelRepresentation: Int
    let samplesPerPixel: Int
    let numberOfFrames: Int

    var bytesPerSample: Int { bitsAllocated / 8 }
    var bytesPerPixel: Int { bytesPerSample * samplesPerPixel }
    var maxValue: Int { (1 << bitsStored) - 1 }
    var isSigned: Bool { pixelRepresentation == 1 }

    /// Lowest representable stored value: 0 unsigned, −2^(bitsStored−1) signed.
    var storedMin: Int { isSigned ? -(1 << (bitsStored - 1)) : 0 }
    /// Highest representable stored value: 2^bitsStored−1 unsigned, 2^(bitsStored−1)−1 signed.
    var storedMax: Int { isSigned ? (1 << (bitsStored - 1)) - 1 : (1 << bitsStored) - 1 }

    /// Samples in a single frame (rows × columns × samples-per-pixel).
    var frameSampleCount: Int { rows * columns * samplesPerPixel }
    /// Bytes in a single frame.
    var frameByteCount: Int { frameSampleCount * bytesPerSample }
}

/// Pixel data editor for DICOM files.
///
/// Lives in the DICOMKit library so the `dicom-pixedit` CLI and DICOMStudio run
/// the exact same pixel algorithms. Verbose progress flows through the injected
/// `log` closure. Use `processData` for an in-memory transform (DICOMStudio writes
/// via its sandbox-aware path) or `processFile` for a direct read→write.
public struct PixelEditor {
    public let verbose: Bool
    private let log: (String) -> Void

    public init(verbose: Bool, log: @escaping (String) -> Void = { _ in }) {
        self.verbose = verbose
        self.log = log
    }

    /// Parse a region string in "x,y,width,height" format.
    public func parseRegion(_ regionString: String) throws -> (x: Int, y: Int, width: Int, height: Int) {
        let parts = regionString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else {
            throw PixelEditError.invalidRegion(regionString)
        }
        guard parts[0] >= 0, parts[1] >= 0, parts[2] > 0, parts[3] > 0 else {
            throw PixelEditError.invalidRegion(regionString)
        }
        return (x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    /// Applies the operations to a DICOM file given as raw bytes, returning the
    /// edited DICOM bytes plus the resulting image info. No file I/O — the caller
    /// chooses how to persist the result (e.g. a sandbox-aware write).
    @discardableResult
    public func processData(_ inputData: Data, operations: [PixelOperation]) throws -> (data: Data, info: PixelEditInfo) {
        let dicomFile = try DICOMFile.read(from: inputData)

        var dataSet = dicomFile.dataSet
        var fileMeta = dicomFile.fileMetaInformation

        guard let pixelElement = dataSet[.pixelData] else {
            throw PixelEditError.noPixelData
        }

        // Pixel-edit operations work on raw, uncompressed samples. If the source uses
        // an encapsulated (compressed) transfer syntax — RLE, JPEG, JPEG 2000, JPEG-LS,
        // JPEG XL — its Pixel Data element holds a fragmented/compressed bitstream, not a
        // flat pixel array. Editing those bytes in place corrupts the bitstream, and the
        // result (still tagged as the compressed syntax) can't be decoded by a viewer like
        // Horos, so the image fails to display. So decode the source to native pixels via
        // the shared codec path and emit uncompressed Explicit VR Little Endian — the same
        // representation every viewer/CLI expects after a pixel edit.
        let sourceSyntax = dicomFile.transferSyntaxUID.flatMap { TransferSyntax.from(uid: $0) }
        let isEncapsulated = (sourceSyntax?.isEncapsulated ?? false)
            || (pixelElement.encapsulatedFragments?.isEmpty == false)

        let descriptor: PixelEditDescriptor
        var pixelData: Data
        let pixelVR: VR

        if isEncapsulated {
            // Decodes every frame to native samples (and maps YBR JPEG/J2K to RGB).
            let decoded = try dicomFile.tryPixelData()
            let d = decoded.descriptor
            descriptor = PixelEditDescriptor(
                rows: d.rows, columns: d.columns,
                bitsAllocated: d.bitsAllocated, bitsStored: d.bitsStored,
                highBit: d.highBit, pixelRepresentation: d.isSigned ? 1 : 0,
                samplesPerPixel: d.samplesPerPixel, numberOfFrames: d.numberOfFrames
            )
            pixelData = decoded.data
            // Native Pixel Data VR: OW for >8-bit samples, OB for 8-bit.
            pixelVR = d.bitsAllocated > 8 ? .OW : .OB
            // Reflect the decoded format in the data set — decoding can change the
            // photometric interpretation and sample layout (e.g. a YBR JPEG becomes RGB).
            dataSet.setString(d.photometricInterpretation.rawValue, for: .photometricInterpretation, vr: .CS)
            dataSet.setUInt16(UInt16(d.samplesPerPixel), for: .samplesPerPixel)
            if d.samplesPerPixel > 1 {
                dataSet.setUInt16(UInt16(d.planarConfiguration), for: .planarConfiguration)
            } else {
                dataSet.remove(tag: .planarConfiguration)
            }
            // Emit uncompressed Explicit VR Little Endian.
            fileMeta = uncompressedFileMeta(from: fileMeta)
            if verbose {
                log("Decoded compressed pixel data (\(sourceSyntax?.displayName ?? "compressed")) → Explicit VR Little Endian")
            }
        } else {
            descriptor = try extractDescriptor(from: dataSet)
            pixelData = pixelElement.valueData
            pixelVR = pixelElement.vr
        }

        if verbose {
            log("Image: \(descriptor.columns)x\(descriptor.rows), \(descriptor.bitsAllocated)-bit, \(descriptor.samplesPerPixel) sample(s)")
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
                    log("Applied mask: (\(x),\(y)) \(width)x\(height), fill=\(fillValue)")
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
                    log("Cropped to: \(newWidth)x\(newHeight)")
                }

            case .windowLevel(let center, let width):
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                try applyWindowLevel(pixelData: &pixelData, descriptor: currentDescriptor,
                                     center: center, width: width)
                // Baking a window remaps stored pixels across the full representable stored
                // range (signed-aware), so the file's old VOI Window Center/Width now
                // describes the pre-bake mapping and would clip the result. Re-point the
                // stored VOI window to that range so the baked contrast is what a viewer shows.
                resetVOIWindowAfterBake(in: &dataSet, descriptor: currentDescriptor)
                if verbose {
                    log("Applied window/level: center=\(center), width=\(width)")
                }

            case .invert:
                let currentDescriptor = descriptorWith(descriptor, rows: currentRows, columns: currentColumns)
                try applyInvert(pixelData: &pixelData, descriptor: currentDescriptor)
                // Inverting stored pixel values without also inverting the file's VOI window
                // pushes every value to the far side of the (unchanged) Window Center, so a
                // viewer that honours the stored window — DICOMStudio's viewer, the image
                // exporter, Horos — renders the image solid white. Re-point the window so the
                // inverted pixels display as a true photographic negative.
                invertVOIWindow(in: &dataSet, descriptor: currentDescriptor)
                if verbose {
                    log("Inverted pixel values")
                }
            }
        }

        // Update pixel data element (native VR: as-read for native sources, OW/OB for
        // sources that were just decoded from a compressed transfer syntax).
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: pixelVR, data: pixelData)

        // Update rows/columns if changed by crop
        if currentRows != descriptor.rows {
            dataSet.setUInt16(UInt16(currentRows), for: .rows)
        }
        if currentColumns != descriptor.columns {
            dataSet.setUInt16(UInt16(currentColumns), for: .columns)
        }

        let updatedFile = DICOMFile(fileMetaInformation: fileMeta, dataSet: dataSet)
        let outputData = try updatedFile.write()
        let info = PixelEditInfo(columns: currentColumns, rows: currentRows,
                                 bitsAllocated: descriptor.bitsAllocated, samplesPerPixel: descriptor.samplesPerPixel)
        return (outputData, info)
    }

    /// Reads a DICOM file, applies the operations, and writes the result to disk.
    public func processFile(inputPath: String, outputPath: String, operations: [PixelOperation]) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        let fileData = try Data(contentsOf: inputURL)
        let (outputData, _) = try processData(fileData, operations: operations)
        try outputData.write(to: outputURL)

        if verbose {
            log(PixelEditConsole.writtenLine(path: outputURL.path))
        }
    }

    // MARK: - Pixel Operations

    func applyMask(pixelData: inout Data, descriptor: PixelEditDescriptor,
                   region: (x: Int, y: Int, width: Int, height: Int), fillValue: Int) throws {
        let endX = min(region.x + region.width, descriptor.columns)
        let endY = min(region.y + region.height, descriptor.rows)

        guard region.x < descriptor.columns, region.y < descriptor.rows else {
            throw PixelEditError.regionOutOfBounds
        }

        let startX = max(region.x, 0)
        let startY = max(region.y, 0)

        // Mask the same region on every frame.
        for frame in 0..<descriptor.numberOfFrames {
            let frameBase = frame * descriptor.frameSampleCount
            for y in startY..<endY {
                for x in startX..<endX {
                    let pixelOffset = y * descriptor.columns + x
                    for s in 0..<descriptor.samplesPerPixel {
                        let sampleIndex = frameBase + pixelOffset * descriptor.samplesPerPixel + s
                        setPixelValue(in: &pixelData, at: sampleIndex, value: fillValue, descriptor: descriptor)
                    }
                }
            }
        }
    }

    func applyCrop(pixelData: Data, descriptor: PixelEditDescriptor,
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

        let frameByteCount = descriptor.frameByteCount
        var croppedData = Data(capacity: newWidth * newHeight * descriptor.bytesPerPixel * descriptor.numberOfFrames)

        // Crop the same region out of every frame and concatenate.
        for frame in 0..<descriptor.numberOfFrames {
            let frameBase = frame * frameByteCount
            for y in startY..<endY {
                let srcRowStart = frameBase + (y * descriptor.columns + startX) * descriptor.bytesPerPixel
                let srcRowEnd = srcRowStart + newWidth * descriptor.bytesPerPixel

                guard srcRowEnd <= pixelData.count else {
                    throw PixelEditError.pixelDataTruncated
                }

                let lower = pixelData.index(pixelData.startIndex, offsetBy: srcRowStart)
                let upper = pixelData.index(pixelData.startIndex, offsetBy: srcRowEnd)
                croppedData.append(pixelData[lower..<upper])
            }
        }

        return (croppedData, newWidth, newHeight)
    }

    func applyWindowLevel(pixelData: inout Data, descriptor: PixelEditDescriptor,
                          center: Double, width: Double) throws {
        guard width > 0 else {
            throw PixelEditError.invalidWindowWidth
        }

        let totalSamples = descriptor.frameSampleCount * descriptor.numberOfFrames
        // Bake into the FULL representable stored range: [0, maxValue] for unsigned,
        // [−2^(b−1), 2^(b−1)−1] for signed. Scaling to the unsigned max for signed data
        // would exceed the signed storage clamp, leaving the baked image in only half the
        // range → it renders ~2× too dark. For unsigned this is identical to the previous
        // [0, maxValue] mapping.
        let outMin = Double(descriptor.storedMin)
        let outMax = Double(descriptor.storedMax)
        let span = outMax - outMin

        for i in 0..<totalSamples {
            let rawValue = getPixelValue(from: pixelData, at: i, descriptor: descriptor)
            let input = Double(rawValue)

            // DICOM window/level formula (PS3.3 C.11.2.1.2), normalised to [0, 1].
            let normalized: Double
            if width <= 1.0 {
                normalized = input <= center - 0.5 ? 0.0 : 1.0
            } else if input <= center - 0.5 - (width - 1.0) / 2.0 {
                normalized = 0.0
            } else if input > center - 0.5 + (width - 1.0) / 2.0 {
                normalized = 1.0
            } else {
                normalized = (input - (center - 0.5)) / (width - 1.0) + 0.5
            }

            let output = outMin + normalized * span
            let clamped = Int(max(outMin, min(outMax, output)))
            setPixelValue(in: &pixelData, at: i, value: clamped, descriptor: descriptor)
        }
    }

    func applyInvert(pixelData: inout Data, descriptor: PixelEditDescriptor) throws {
        let totalSamples = descriptor.frameSampleCount * descriptor.numberOfFrames
        let pivot = invertPivot(for: descriptor)

        for i in 0..<totalSamples {
            let value = getPixelValue(from: pixelData, at: i, descriptor: descriptor)
            let inverted = pivot - value
            setPixelValue(in: &pixelData, at: i, value: inverted, descriptor: descriptor)
        }
    }

    // MARK: - Helpers

    private func extractDescriptor(from dataSet: DataSet) throws -> PixelEditDescriptor {
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
        let numberOfFrames = max(1, dataSet.numberOfFrames ?? 1)

        return PixelEditDescriptor(
            rows: Int(rows),
            columns: Int(columns),
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            highBit: Int(highBit),
            pixelRepresentation: Int(pixelRep),
            samplesPerPixel: Int(samplesPerPixel),
            numberOfFrames: numberOfFrames
        )
    }

    /// Returns a copy of the File Meta Information re-pointed at Explicit VR Little
    /// Endian, with the group length (0002,0000) recomputed so the FMI stays
    /// self-consistent after the transfer-syntax change.
    private func uncompressedFileMeta(from meta: DataSet) -> DataSet {
        var fmi = meta
        fmi.setString(TransferSyntax.explicitVRLittleEndian.uid, for: .transferSyntaxUID, vr: .UI)
        // Recompute group length over everything that follows it.
        fmi.remove(tag: .fileMetaInformationGroupLength)
        let writer = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        let bytes = fmi.write(using: writer)
        fmi[.fileMetaInformationGroupLength] = DataElement.uint32(
            tag: .fileMetaInformationGroupLength, value: UInt32(bytes.count))
        return fmi
    }

    private func descriptorWith(_ base: PixelEditDescriptor, rows: Int, columns: Int) -> PixelEditDescriptor {
        PixelEditDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: base.bitsAllocated,
            bitsStored: base.bitsStored,
            highBit: base.highBit,
            pixelRepresentation: base.pixelRepresentation,
            samplesPerPixel: base.samplesPerPixel,
            numberOfFrames: base.numberOfFrames
        )
    }

    // MARK: - VOI window (0028,1050/0028,1051) maintenance

    /// The stored value `p` such that `p − stored` reverses the stored-value range onto
    /// itself — the pivot both the pixel inversion and the VOI-window inversion use.
    ///
    /// - Unsigned: the highest stored value, `2^bitsStored − 1`.
    /// - Signed (two's complement): `min + max = −1`, independent of `bitsStored`
    ///   (e.g. 16-bit signed spans −32768…32767, whose sum is −1). Using the unsigned
    ///   `maxValue` here would push every signed sample past the positive clamp, i.e.
    ///   render the whole frame white — the very bug this fixes.
    private func invertPivot(for descriptor: PixelEditDescriptor) -> Int {
        descriptor.isSigned ? -1 : descriptor.maxValue
    }

    /// Re-points the VOI Window Center so an inverted image displays as a true negative.
    ///
    /// Viewers apply the VOI window in *stored* space after the Modality LUT, so a stored
    /// center `Cs` becomes `pivot − Cs` under the inversion `s' = pivot − s`. Window Center
    /// is persisted in *output* units (Rescale Slope·stored + Intercept); the equivalent
    /// output-space transform is `C' = slope·pivot + 2·intercept − C`. Window Width is a
    /// span and is unchanged. No stored window ⇒ nothing to do (viewers auto-window from the
    /// pixel range, which already tracks the inverted data). Reference: PS3.3 C.11.2.
    private func invertVOIWindow(in dataSet: inout DataSet, descriptor: PixelEditDescriptor) {
        guard let centers = dataSet.decimalStrings(for: .windowCenter), !centers.isEmpty else { return }
        let slope = dataSet.rescaleSlope()
        let intercept = dataSet.rescaleIntercept()
        let k = slope * Double(invertPivot(for: descriptor)) + 2.0 * intercept
        let newCenters = centers.map { formatDS(k - $0.value) }
        dataSet.setStrings(newCenters, for: .windowCenter, vr: .DS)
        if verbose {
            log("Inverted VOI window center(s) → \(newCenters.joined(separator: "\\")) so the negative displays correctly")
        }
    }

    /// Replaces the VOI window after a window/level bake, which has already flattened the
    /// chosen window across the full representable stored range (`[0, maxValue]` unsigned,
    /// `[−2^(b−1), 2^(b−1)−1]` signed). A viewer honouring the pre-bake window would re-clip
    /// the result, so set the stored window to that same full range (stored center
    /// `(storedMin+storedMax)/2`, width `storedMax−storedMin`, rescaled to output units) —
    /// exactly the baked contrast. Any per-window explanation no longer applies and is dropped.
    private func resetVOIWindowAfterBake(in dataSet: inout DataSet, descriptor: PixelEditDescriptor) {
        let slope = dataSet.rescaleSlope()
        let intercept = dataSet.rescaleIntercept()
        let storedCenter = Double(descriptor.storedMin + descriptor.storedMax) / 2.0
        let storedWidth = Swift.max(1.0, Double(descriptor.storedMax - descriptor.storedMin))
        let center = slope * storedCenter + intercept
        let width = Swift.max(1.0, abs(slope) * storedWidth)
        dataSet.setString(formatDS(center), for: .windowCenter, vr: .DS)
        dataSet.setString(formatDS(width), for: .windowWidth, vr: .DS)
        dataSet.remove(tag: .windowCenterWidthExplanation)
    }

    /// Formats a value as a DICOM Decimal String (DS, ≤ 16 bytes): integral values print
    /// without a fractional part, others with compact significant-digit precision. Non-finite
    /// values (only reachable from pathological rescale metadata) degrade to "0" rather than
    /// emit a non-conformant "nan"/"inf" token.
    private func formatDS(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.8g", value)
        if s.count > 16 { s = String(s.prefix(16)) }
        return s
    }

    private func getPixelValue(from data: Data, at sampleIndex: Int, descriptor: PixelEditDescriptor) -> Int {
        let byteOffset = sampleIndex * descriptor.bytesPerSample

        if descriptor.bytesPerSample == 1 {
            guard byteOffset < data.count else { return 0 }
            let raw = data[data.startIndex + byteOffset]
            return descriptor.isSigned ? Int(Int8(bitPattern: raw)) : Int(raw)
        } else {
            let idx = data.startIndex + byteOffset
            guard idx + 1 < data.endIndex else { return 0 }
            let lo = UInt16(data[idx])
            let hi = UInt16(data[idx + 1])
            let raw = lo | (hi << 8)
            return descriptor.isSigned ? Int(Int16(bitPattern: raw)) : Int(raw)
        }
    }

    private func setPixelValue(in data: inout Data, at sampleIndex: Int, value: Int, descriptor: PixelEditDescriptor) {
        let byteOffset = sampleIndex * descriptor.bytesPerSample

        if descriptor.bytesPerSample == 1 {
            guard byteOffset < data.count else { return }
            if descriptor.isSigned {
                data[data.startIndex + byteOffset] = UInt8(bitPattern: Int8(clamping: value))
            } else {
                data[data.startIndex + byteOffset] = UInt8(clamping: value)
            }
        } else {
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

public enum PixelEditError: Error, LocalizedError {
    case invalidRegion(String)
    case noPixelData
    case regionOutOfBounds
    case pixelDataTruncated
    case missingTag(String)
    case invalidWindowWidth

    public var errorDescription: String? {
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

// MARK: - Shared console output (dicom-pixedit CLI ⇄ Workshop executor)

/// Builds the console lines `dicom-pixedit` prints around the engine's own
/// verbose log (which is shared already via the `PixelEditor` log closure).
/// The CLI text is canonical; the Workshop executor renders identical strings.
/// All lines are verbose-gated on both surfaces — a non-verbose run is silent.
public enum PixelEditConsole {
    /// Verbose run header (input path, output path, operation count).
    public static func headerLines(input: String, output: String, operationCount: Int) -> [String] {
        ["Input: \(input)", "Output: \(output)", "Operations: \(operationCount)"]
    }

    /// Verbose confirmation after the output file is written.
    public static func writtenLine(path: String) -> String {
        "Written: \(path)"
    }

    /// Verbose end-of-run line.
    public static func doneLine() -> String {
        "Done."
    }
}
