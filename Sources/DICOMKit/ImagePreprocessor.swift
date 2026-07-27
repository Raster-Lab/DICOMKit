/// Image Preprocessing for DICOM Print Management
///
/// Phase 3.1 of the DICOM Print Management implementation.
/// Prepares DICOM images for optimal print quality by applying window/level,
/// rescale operations, LUT transformations, and polarity handling.
///
/// Reference: PS3.4 Annex H - Print Management Service Class

import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - Print Color Mode

/// Print color mode for image preparation
public enum PrintColorMode: String, Sendable {
    case grayscale = "GRAYSCALE"
    case color = "COLOR"
}

// MARK: - Prepared Image

/// Prepared image ready for printing
public struct PreparedImage: Sendable {
    /// The processed pixel data
    public let pixelData: Data
    
    /// Image width in pixels
    public let width: Int
    
    /// Image height in pixels
    public let height: Int
    
    /// Bits allocated per pixel (typically 8 or 16)
    public let bitsAllocated: Int
    
    /// Samples per pixel (1 for grayscale, 3 for RGB)
    public let samplesPerPixel: Int

    /// Photometric interpretation (e.g., "MONOCHROME2", "RGB")
    public let photometricInterpretation: String

    /// Bits actually used per sample (≤ `bitsAllocated`), e.g. 12 stored in
    /// 16 allocated for deep-grayscale film printers.
    public let bitsStored: Int

    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        bitsAllocated: Int,
        samplesPerPixel: Int,
        photometricInterpretation: String,
        bitsStored: Int? = nil
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.bitsAllocated = bitsAllocated
        self.samplesPerPixel = samplesPerPixel
        self.photometricInterpretation = photometricInterpretation
        self.bitsStored = bitsStored ?? bitsAllocated
    }
}

// MARK: - Image Preprocessor

/// Actor for preparing DICOM images for printing
///
/// Provides a complete image preprocessing pipeline including:
/// - Window/level application for CT/MR images
/// - Rescale slope/intercept application
/// - Modality LUT transformation
/// - VOI LUT transformation
/// - Presentation LUT application
/// - MONOCHROME polarity handling
/// - Color space conversion
public actor ImagePreprocessor {
    
    /// Creates a new image preprocessor
    public init() {}
    
    // MARK: - Main Preparation Method
    
    /// Prepares a DICOM dataset for printing
    ///
    /// This method performs the complete image preprocessing pipeline:
    /// 1. Extracts pixel data from the dataset
    /// 2. Applies rescale slope/intercept
    /// 3. Applies modality LUT (if present)
    /// 4. Applies VOI LUT or window/level
    /// 5. Handles MONOCHROME polarity
    /// 6. Converts color space if needed
    ///
    /// - Parameters:
    ///   - dataSet: The DICOM dataset containing the image
    ///   - colorMode: Target color mode for printing
    ///   - windowSettings: Optional window settings (if nil, auto-calculated)
    /// - Returns: Prepared image ready for printing
    /// - Throws: ImagePreprocessingError if preprocessing fails
    public func prepareForPrint(
        dataSet: DataSet,
        colorMode: PrintColorMode,
        windowSettings: WindowSettings? = nil
    ) async throws -> PreparedImage {
        // Extract pixel data descriptor
        guard dataSet.pixelDataDescriptor() != nil else {
            throw ImagePreprocessingError.missingPixelData
        }

        // Extract raw pixel data
        guard let pixelData = dataSet.pixelData() else {
            throw ImagePreprocessingError.invalidPixelData
        }

        return try await prepareForPrint(
            pixelData: pixelData,
            dataSet: dataSet,
            frameIndex: 0,
            colorMode: colorMode,
            windowSettings: windowSettings
        )
    }

    /// Prepares one frame of already-extracted (decoded) pixel data for printing.
    ///
    /// Use this variant when the pixel data came from `DICOMFile.tryPixelData()`
    /// (which decodes encapsulated transfer syntaxes to native frames) or when a
    /// frame other than the first is wanted. The `dataSet` supplies the rescale
    /// and window attributes; the pixel bytes and descriptor come from
    /// `pixelData` so a decoded/corrected descriptor is honored.
    ///
    /// - Parameters:
    ///   - pixelData: Decoded native pixel data with its descriptor
    ///   - dataSet: The source data set (rescale slope/intercept, window)
    ///   - frameIndex: Zero-based frame to prepare
    ///   - colorMode: Target color mode for printing
    ///   - windowSettings: Optional window settings (if nil, auto-calculated)
    public func prepareForPrint(
        pixelData: PixelData,
        dataSet: DataSet,
        frameIndex: Int = 0,
        colorMode: PrintColorMode,
        windowSettings: WindowSettings? = nil,
        outputBitDepth: Int = 8
    ) async throws -> PreparedImage {
        let descriptor = pixelData.descriptor
        guard frameIndex >= 0, frameIndex < descriptor.numberOfFrames else {
            throw ImagePreprocessingError.invalidFrameData
        }
        // Grayscale P-Values beyond 16 bits are not defined for Basic Print;
        // color output is always 8 bits per sample.
        guard (8...16).contains(outputBitDepth) else {
            throw ImagePreprocessingError.unsupportedBitsAllocated(outputBitDepth)
        }
        let photometric = descriptor.photometricInterpretation

        // Handle different photometric interpretations
        if photometric.isMonochrome {
            return try await preprocessMonochromeImage(
                pixelData: pixelData,
                descriptor: descriptor,
                dataSet: dataSet,
                colorMode: colorMode,
                windowSettings: windowSettings,
                frameIndex: frameIndex,
                outputBitDepth: outputBitDepth
            )
        } else if photometric.isPaletteColor {
            return try await preprocessPaletteColorImage(
                pixelData: pixelData,
                descriptor: descriptor,
                dataSet: dataSet,
                colorMode: colorMode,
                frameIndex: frameIndex
            )
        } else if photometric.isColor {
            return try await preprocessColorImage(
                pixelData: pixelData,
                descriptor: descriptor,
                colorMode: colorMode,
                frameIndex: frameIndex
            )
        } else {
            throw ImagePreprocessingError.unsupportedPhotometricInterpretation(photometric.rawValue)
        }
    }
    
    // MARK: - Monochrome Image Processing
    
    private func preprocessMonochromeImage(
        pixelData: PixelData,
        descriptor: PixelDataDescriptor,
        dataSet: DataSet,
        colorMode: PrintColorMode,
        windowSettings: WindowSettings?,
        frameIndex: Int = 0,
        outputBitDepth: Int = 8
    ) async throws -> PreparedImage {
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height

        guard let frameData = pixelData.frameData(at: frameIndex) else {
            throw ImagePreprocessingError.invalidFrameData
        }
        
        // Extract pixel values as doubles for processing
        var pixelValues = try extractPixelValues(
            from: frameData,
            descriptor: descriptor,
            count: totalPixels
        )
        
        // Apply rescale slope and intercept
        pixelValues = applyRescale(
            to: pixelValues,
            dataSet: dataSet
        )
        
        // Determine window settings
        let window: WindowSettings
        if let providedWindow = windowSettings {
            window = providedWindow
        } else {
            // Auto-calculate from pixel range
            let minVal = pixelValues.min() ?? 0.0
            let maxVal = pixelValues.max() ?? 1.0
            let center = (minVal + maxVal) / 2.0
            let width = maxVal - minVal
            window = WindowSettings(center: center, width: max(1.0, width))
        }
        
        // Apply window/level transformation
        var normalizedPixels = pixelValues.map { window.apply(to: $0) }
        
        // Handle MONOCHROME1 polarity (invert)
        if descriptor.photometricInterpretation == .monochrome1 {
            normalizedPixels = normalizedPixels.map { 1.0 - $0 }
        }
        
        // Convert to unsigned P-Values at the requested depth: 8-bit stays one
        // byte per pixel; 9–16 bits emit little-endian UInt16 samples with
        // bitsStored = outputBitDepth (e.g. 12-in-16 for deep-grayscale film).
        let maxValue = Double((1 << outputBitDepth) - 1)
        let outputData: Data
        let bitsAllocated: Int
        if outputBitDepth <= 8 {
            outputData = Data(normalizedPixels.map {
                UInt8(min(max($0 * maxValue, 0.0), maxValue))
            })
            bitsAllocated = 8
        } else {
            var data = Data(capacity: normalizedPixels.count * 2)
            for value in normalizedPixels {
                let sample = UInt16(min(max(value * maxValue, 0.0), maxValue))
                data.append(UInt8(sample & 0xFF))
                data.append(UInt8(sample >> 8))
            }
            outputData = data
            bitsAllocated = 16
        }

        return PreparedImage(
            pixelData: outputData,
            width: width,
            height: height,
            bitsAllocated: bitsAllocated,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2",
            bitsStored: outputBitDepth
        )
    }
    
    // MARK: - Color Image Processing
    
    private func preprocessColorImage(
        pixelData: PixelData,
        descriptor: PixelDataDescriptor,
        colorMode: PrintColorMode,
        frameIndex: Int = 0
    ) async throws -> PreparedImage {
        let width = descriptor.columns
        let height = descriptor.rows

        // Uncompressed YBR sources must be converted to RGB before printing —
        // Basic Color Image Boxes carry RGB (PS3.3 C.13.5). YBR_FULL is
        // full-resolution interleaved; YBR_FULL_422 / YBR_PARTIAL_422 are
        // packed 2 bytes/pixel (Y1 Y2 Cb Cr per pixel pair, PS3.5 §8.7.4) —
        // `PixelData.frameData(at:)` assumes 3 samples/pixel, so packed frames
        // are sliced manually here. 4:2:0 and the ICT/RCT codestream variants
        // never occur uncompressed and are rejected. (Compressed YBR sources
        // arrive here already decoded to full-resolution samples.)
        let sourcePI = descriptor.photometricInterpretation
        var frameData: Data
        if sourcePI == .ybrFull422 || sourcePI == .ybrPartial422 {
            guard descriptor.bitsAllocated == 8, (width * height) % 2 == 0 else {
                throw ImagePreprocessingError.unsupportedPhotometricInterpretation(sourcePI.rawValue)
            }
            let packedFrameSize = width * height * 2
            let start = pixelData.data.startIndex + frameIndex * packedFrameSize
            guard start + packedFrameSize <= pixelData.data.endIndex else {
                throw ImagePreprocessingError.insufficientPixelData
            }
            frameData = Self.convertYBR422ToRGB(
                Data(pixelData.data[start..<(start + packedFrameSize)]),
                fullRange: sourcePI == .ybrFull422
            )
        } else {
            guard let nativeFrame = pixelData.frameData(at: frameIndex) else {
                throw ImagePreprocessingError.invalidFrameData
            }
            frameData = nativeFrame
            if sourcePI.isYBR {
                guard sourcePI == .ybrFull, descriptor.bitsAllocated == 8,
                      descriptor.samplesPerPixel == 3 else {
                    throw ImagePreprocessingError.unsupportedPhotometricInterpretation(sourcePI.rawValue)
                }
                frameData = Self.convertYBRFullToRGB(frameData)
            }
        }

        // For color images, we may need to convert based on printer capabilities
        if colorMode == .grayscale {
            // Convert RGB to grayscale
            let grayscaleData = try convertRGBToGrayscale(
                frameData: frameData,
                descriptor: descriptor
            )
            
            return PreparedImage(
                pixelData: grayscaleData,
                width: width,
                height: height,
                bitsAllocated: 8,
                samplesPerPixel: 1,
                photometricInterpretation: "MONOCHROME2"
            )
        } else {
            // Keep as RGB, but ensure 8-bit per sample
            let normalizedData = try normalizeColorData(
                frameData: frameData,
                descriptor: descriptor
            )
            
            return PreparedImage(
                pixelData: normalizedData,
                width: width,
                height: height,
                bitsAllocated: 8,
                samplesPerPixel: 3,
                photometricInterpretation: "RGB"
            )
        }
    }
    
    // MARK: - Palette Color Image Processing
    
    private func preprocessPaletteColorImage(
        pixelData: PixelData,
        descriptor: PixelDataDescriptor,
        dataSet: DataSet,
        colorMode: PrintColorMode,
        frameIndex: Int = 0
    ) async throws -> PreparedImage {
        // Each stored value indexes the Red/Green/Blue Palette Color Lookup
        // Tables (PS3.3 C.7.6.3.1.5); the LUT module is required for PALETTE
        // COLOR images.
        guard let lut = dataSet.paletteColorLUT() else {
            throw ImagePreprocessingError.missingPaletteLUT
        }
        guard let frameData = pixelData.frameData(at: frameIndex) else {
            throw ImagePreprocessingError.invalidFrameData
        }

        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        let bytesPerSample = descriptor.bytesPerSample

        var rgbBytes = [UInt8]()
        rgbBytes.reserveCapacity(totalPixels * 3)
        for i in 0..<totalPixels {
            let index: Int
            if bytesPerSample == 1 {
                guard i < frameData.count else {
                    throw ImagePreprocessingError.insufficientPixelData
                }
                index = Int(frameData[i])
            } else if bytesPerSample == 2 {
                let offset = i * 2
                guard offset + 1 < frameData.count else {
                    throw ImagePreprocessingError.insufficientPixelData
                }
                index = Int(UInt16(frameData[offset]) | (UInt16(frameData[offset + 1]) << 8))
            } else {
                throw ImagePreprocessingError.unsupportedBitsAllocated(descriptor.bitsAllocated)
            }
            let (r, g, b) = lut.lookup(index)
            rgbBytes.append(r)
            rgbBytes.append(g)
            rgbBytes.append(b)
        }

        if colorMode == .grayscale {
            var grayBytes = [UInt8]()
            grayBytes.reserveCapacity(totalPixels)
            for i in 0..<totalPixels {
                let offset = i * 3
                let gray = 0.299 * Double(rgbBytes[offset])
                    + 0.587 * Double(rgbBytes[offset + 1])
                    + 0.114 * Double(rgbBytes[offset + 2])
                grayBytes.append(UInt8(min(max(gray, 0.0), 255.0)))
            }
            return PreparedImage(
                pixelData: Data(grayBytes),
                width: width,
                height: height,
                bitsAllocated: 8,
                samplesPerPixel: 1,
                photometricInterpretation: "MONOCHROME2"
            )
        }

        return PreparedImage(
            pixelData: Data(rgbBytes),
            width: width,
            height: height,
            bitsAllocated: 8,
            samplesPerPixel: 3,
            photometricInterpretation: "RGB"
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractPixelValues(
        from frameData: Data,
        descriptor: PixelDataDescriptor,
        count: Int
    ) throws -> [Double] {
        var pixelValues = [Double]()
        pixelValues.reserveCapacity(count)
        
        let bytesPerSample = descriptor.bytesPerSample
        let bitShift = descriptor.bitShift
        let storedBitMask = descriptor.storedBitMask
        let isSigned = descriptor.isSigned
        
        for i in 0..<count {
            let offset = i * bytesPerSample
            guard offset + bytesPerSample <= frameData.count else {
                throw ImagePreprocessingError.insufficientPixelData
            }
            
            var rawValue: Int = 0
            
            if bytesPerSample == 1 {
                rawValue = Int(frameData[offset])
            } else if bytesPerSample == 2 {
                let byte1 = UInt16(frameData[offset])
                let byte2 = UInt16(frameData[offset + 1])
                rawValue = Int((byte2 << 8) | byte1)
            } else {
                throw ImagePreprocessingError.unsupportedBitsAllocated(descriptor.bitsAllocated)
            }
            
            // Apply bit shift and mask
            rawValue = (rawValue >> bitShift) & storedBitMask
            
            // Handle signed values
            var pixelValue: Double
            if isSigned {
                let signBit = 1 << (descriptor.bitsStored - 1)
                if rawValue & signBit != 0 {
                    // Negative value
                    let mask = (1 << descriptor.bitsStored) - 1
                    pixelValue = Double(rawValue | ~mask)
                } else {
                    pixelValue = Double(rawValue)
                }
            } else {
                pixelValue = Double(rawValue)
            }
            
            pixelValues.append(pixelValue)
        }
        
        return pixelValues
    }
    
    private func applyRescale(
        to pixelValues: [Double],
        dataSet: DataSet
    ) -> [Double] {
        // Get rescale slope and intercept using DataSet extension methods
        let rescaleSlope = dataSet.rescaleSlope()
        let rescaleIntercept = dataSet.rescaleIntercept()
        
        // Apply: outputValue = pixelValue * slope + intercept
        return pixelValues.map { $0 * rescaleSlope + rescaleIntercept }
    }
    
    private func convertRGBToGrayscale(
        frameData: Data,
        descriptor: PixelDataDescriptor
    ) throws -> Data {
        let totalPixels = descriptor.columns * descriptor.rows
        let samplesPerPixel = descriptor.samplesPerPixel
        
        guard samplesPerPixel == 3 else {
            throw ImagePreprocessingError.invalidSamplesPerPixel(samplesPerPixel)
        }
        
        var grayscaleBytes = [UInt8]()
        grayscaleBytes.reserveCapacity(totalPixels)
        
        // Use standard luminance formula: Y = 0.299*R + 0.587*G + 0.114*B
        for i in 0..<totalPixels {
            let offset = i * 3
            guard offset + 2 < frameData.count else {
                throw ImagePreprocessingError.insufficientPixelData
            }
            
            let r = Double(frameData[offset])
            let g = Double(frameData[offset + 1])
            let b = Double(frameData[offset + 2])
            
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            grayscaleBytes.append(UInt8(min(max(gray, 0.0), 255.0)))
        }
        
        return Data(grayscaleBytes)
    }
    
    /// Converts interleaved 8-bit YBR_FULL samples to RGB in a new buffer.
    ///
    /// Reference: DICOM PS3.3 C.7.6.3.1.2 (full-range YCbCr → RGB):
    /// R = Y + 1.402(Cr−128), G = Y − 0.344136(Cb−128) − 0.714136(Cr−128),
    /// B = Y + 1.772(Cb−128).
    static func convertYBRFullToRGB(_ data: Data) -> Data {
        var output = [UInt8](repeating: 0, count: data.count)
        let pixelCount = data.count / 3
        data.withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            for i in 0..<pixelCount {
                let offset = i * 3
                let y = Double(bytes[offset])
                let cb = Double(bytes[offset + 1])
                let cr = Double(bytes[offset + 2])

                let r = y + 1.402 * (cr - 128.0)
                let g = y - 0.344136 * (cb - 128.0) - 0.714136 * (cr - 128.0)
                let b = y + 1.772 * (cb - 128.0)

                output[offset] = UInt8(max(0.0, min(255.0, r.rounded())))
                output[offset + 1] = UInt8(max(0.0, min(255.0, g.rounded())))
                output[offset + 2] = UInt8(max(0.0, min(255.0, b.rounded())))
            }
        }
        return Data(output)
    }

    /// Converts packed 8-bit 4:2:2 YCbCr (Y1 Y2 Cb Cr per pixel pair) to
    /// interleaved RGB, upsampling chroma by pairing.
    ///
    /// - Parameters:
    ///   - packed: Packed frame bytes, 2 bytes per pixel.
    ///   - fullRange: `true` for YBR_FULL_422 (full-range, PS3.3 C.7.6.3.1.2);
    ///     `false` for YBR_PARTIAL_422 (BT.601 studio range, Y 16–235).
    static func convertYBR422ToRGB(_ packed: Data, fullRange: Bool) -> Data {
        let bytes = [UInt8](packed)
        let pairCount = bytes.count / 4
        var output = [UInt8](repeating: 0, count: pairCount * 6)
        var dst = 0
        func clamp(_ v: Double) -> UInt8 { UInt8(max(0.0, min(255.0, v.rounded()))) }
        for pair in 0..<pairCount {
            let src = pair * 4
            let cb = Double(bytes[src + 2]) - 128.0
            let cr = Double(bytes[src + 3]) - 128.0
            for lumaOffset in 0...1 {
                let y = Double(bytes[src + lumaOffset])
                let r: Double, g: Double, b: Double
                if fullRange {
                    r = y + 1.402 * cr
                    g = y - 0.344136 * cb - 0.714136 * cr
                    b = y + 1.772 * cb
                } else {
                    let scaledY = 1.1644 * (y - 16.0)
                    r = scaledY + 1.5960 * cr
                    g = scaledY - 0.3917 * cb - 0.8129 * cr
                    b = scaledY + 2.0172 * cb
                }
                output[dst] = clamp(r)
                output[dst + 1] = clamp(g)
                output[dst + 2] = clamp(b)
                dst += 3
            }
        }
        return Data(output)
    }

    private func normalizeColorData(
        frameData: Data,
        descriptor: PixelDataDescriptor
    ) throws -> Data {
        // For now, assume data is already 8-bit RGB
        // In the future, could handle 16-bit RGB here
        if descriptor.bitsAllocated == 8 {
            return frameData
        } else {
            throw ImagePreprocessingError.unsupportedBitsAllocated(descriptor.bitsAllocated)
        }
    }
}

// MARK: - Image Preprocessing Error

/// Errors that can occur during image preprocessing
public enum ImagePreprocessingError: Error, CustomStringConvertible {
    case missingPixelData
    case invalidPixelData
    case invalidFrameData
    case insufficientPixelData
    case unsupportedPhotometricInterpretation(String)
    case unsupportedBitsAllocated(Int)
    case invalidSamplesPerPixel(Int)
    case missingPaletteLUT
    case notYetImplemented(String)
    
    public var description: String {
        switch self {
        case .missingPixelData:
            return "Missing pixel data in dataset"
        case .invalidPixelData:
            return "Invalid pixel data format"
        case .invalidFrameData:
            return "Invalid frame data"
        case .insufficientPixelData:
            return "Insufficient pixel data for image dimensions"
        case .unsupportedPhotometricInterpretation(let value):
            return "Unsupported photometric interpretation: \(value)"
        case .unsupportedBitsAllocated(let bits):
            return "Unsupported bits allocated: \(bits)"
        case .invalidSamplesPerPixel(let samples):
            return "Invalid samples per pixel: \(samples)"
        case .missingPaletteLUT:
            return "Missing palette color lookup table"
        case .notYetImplemented(let feature):
            return "Feature not yet implemented: \(feature)"
        }
    }
}
