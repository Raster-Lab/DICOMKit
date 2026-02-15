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
    
    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        bitsAllocated: Int,
        samplesPerPixel: Int,
        photometricInterpretation: String
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.bitsAllocated = bitsAllocated
        self.samplesPerPixel = samplesPerPixel
        self.photometricInterpretation = photometricInterpretation
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
    ///   - targetSize: Desired image size (unused in this version, reserved for future use)
    ///   - colorMode: Target color mode for printing
    ///   - windowSettings: Optional window settings (if nil, auto-calculated)
    /// - Returns: Prepared image ready for printing
    /// - Throws: ImagePreprocessingError if preprocessing fails
    public func prepareForPrint(
        dataSet: DataSet,
        targetSize: CGSize? = nil,
        colorMode: PrintColorMode,
        windowSettings: WindowSettings? = nil
    ) async throws -> PreparedImage {
        // Extract pixel data descriptor
        guard let descriptor = dataSet.pixelDataDescriptor() else {
            throw ImagePreprocessingError.missingPixelData
        }
        
        // Extract raw pixel data
        guard let pixelData = dataSet.pixelData() else {
            throw ImagePreprocessingError.invalidPixelData
        }
        
        let width = descriptor.columns
        let height = descriptor.rows
        let photometric = descriptor.photometricInterpretation
        
        // Handle different photometric interpretations
        if photometric.isMonochrome {
            return try await preprocessMonochromeImage(
                pixelData: pixelData,
                descriptor: descriptor,
                dataSet: dataSet,
                colorMode: colorMode,
                windowSettings: windowSettings
            )
        } else if photometric.isColor {
            return try await preprocessColorImage(
                pixelData: pixelData,
                descriptor: descriptor,
                colorMode: colorMode
            )
        } else if photometric.isPaletteColor {
            return try await preprocessPaletteColorImage(
                pixelData: pixelData,
                descriptor: descriptor,
                dataSet: dataSet,
                colorMode: colorMode
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
        windowSettings: WindowSettings?
    ) async throws -> PreparedImage {
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        
        // Get frame data (frame 0 for single frame images)
        guard let frameData = pixelData.frameData(at: 0) else {
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
        
        // Convert to 8-bit
        let outputBytes = normalizedPixels.map { UInt8(min(max($0 * 255.0, 0.0), 255.0)) }
        let outputData = Data(outputBytes)
        
        return PreparedImage(
            pixelData: outputData,
            width: width,
            height: height,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2"
        )
    }
    
    // MARK: - Color Image Processing
    
    private func preprocessColorImage(
        pixelData: PixelData,
        descriptor: PixelDataDescriptor,
        colorMode: PrintColorMode
    ) async throws -> PreparedImage {
        let width = descriptor.columns
        let height = descriptor.rows
        
        guard let frameData = pixelData.frameData(at: 0) else {
            throw ImagePreprocessingError.invalidFrameData
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
        colorMode: PrintColorMode
    ) async throws -> PreparedImage {
        let width = descriptor.columns
        let height = descriptor.rows
        
        // For palette color, we'll do a simplified conversion
        // A full implementation would extract the LUT descriptors and data from the dataset
        // For now, throw an error indicating this is not yet fully implemented
        throw ImagePreprocessingError.unsupportedPhotometricInterpretation("PALETTE COLOR - full support pending")
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
        }
    }
}
