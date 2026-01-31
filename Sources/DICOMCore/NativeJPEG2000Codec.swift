import Foundation

#if canImport(ImageIO)
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Native JPEG 2000 codec using Apple's ImageIO framework
///
/// Supports JPEG 2000 lossless and lossy transfer syntaxes.
/// Provides both decoding and encoding capabilities.
/// Reference: DICOM PS3.5 Section A.4.4
public struct NativeJPEG2000Codec: ImageCodec, ImageEncoder, Sendable {
    /// Supported JPEG 2000 transfer syntaxes for decoding
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpeg2000Lossless.uid,  // 1.2.840.10008.1.2.4.90
        TransferSyntax.jpeg2000.uid           // 1.2.840.10008.1.2.4.91
    ]
    
    /// Supported JPEG 2000 transfer syntaxes for encoding
    ///
    /// ImageIO supports both lossless and lossy JPEG 2000 encoding.
    public static let supportedEncodingTransferSyntaxes: [String] = [
        TransferSyntax.jpeg2000Lossless.uid,  // 1.2.840.10008.1.2.4.90
        TransferSyntax.jpeg2000.uid           // 1.2.840.10008.1.2.4.91
    ]
    
    public init() {}
    
    // MARK: - Decoding
    
    /// Decodes a JPEG 2000-compressed frame
    /// - Parameters:
    ///   - frameData: JPEG 2000 compressed data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Frame index (unused for single frame decode)
    /// - Returns: Uncompressed pixel data
    /// - Throws: DICOMError if decoding fails
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG 2000 data")
        }
        
        // Create image source from JPEG 2000 data
        // ImageIO can handle JP2 format directly
        guard let imageSource = CGImageSourceCreateWithData(frameData as CFData, nil) else {
            throw DICOMError.parsingFailed("Failed to create image source from JPEG 2000 data")
        }
        
        // Check the image type
        let typeIdentifier = CGImageSourceGetType(imageSource) as String?
        
        // Get the image
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DICOMError.parsingFailed("Failed to decode JPEG 2000 image (type: \(typeIdentifier ?? "unknown"))")
        }
        
        // Extract pixel data from CGImage
        return try extractPixelData(from: cgImage, descriptor: descriptor)
    }
    
    // MARK: - Encoding
    
    /// Whether this encoder supports the given configuration
    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        // JPEG 2000 supports various bit depths
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }
        
        // Support grayscale and RGB
        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }
        
        return true
    }
    
    /// Encodes a single frame to JPEG 2000 format
    /// - Parameters:
    ///   - frameData: Uncompressed frame data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Zero-based frame index
    ///   - configuration: Compression configuration
    /// - Returns: JPEG 2000 compressed frame data
    /// - Throws: DICOMError if encoding fails
    public func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int, configuration: CompressionConfiguration) throws -> Data {
        // Create CGImage from raw pixel data
        let cgImage = try createCGImage(from: frameData, descriptor: descriptor)
        
        // Encode to JPEG 2000
        return try encodeToJPEG2000(cgImage, configuration: configuration, descriptor: descriptor)
    }
    
    // MARK: - Private Decoding Helpers
    
    /// Extracts raw pixel data from a CGImage
    private func extractPixelData(from image: CGImage, descriptor: PixelDataDescriptor) throws -> Data {
        let width = image.width
        let height = image.height
        let samplesPerPixel = descriptor.samplesPerPixel
        
        // Validate dimensions
        guard width == descriptor.columns && height == descriptor.rows else {
            throw DICOMError.parsingFailed("Decoded image dimensions (\(width)x\(height)) don't match expected (\(descriptor.columns)x\(descriptor.rows))")
        }
        
        // Determine output format
        if samplesPerPixel == 1 {
            // Grayscale
            return try extractGrayscaleData(from: image, descriptor: descriptor)
        } else if samplesPerPixel == 3 {
            // RGB
            return try extractRGBData(from: image, descriptor: descriptor)
        } else {
            throw DICOMError.parsingFailed("Unsupported samples per pixel: \(samplesPerPixel)")
        }
    }
    
    /// Extracts grayscale pixel data
    private func extractGrayscaleData(from image: CGImage, descriptor: PixelDataDescriptor) throws -> Data {
        let width = descriptor.columns
        let height = descriptor.rows
        let bytesPerSample = descriptor.bytesPerSample
        
        // Create grayscale context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo: CGBitmapInfo
        
        if bytesPerSample == 1 {
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        } else {
            // 16-bit grayscale
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
        }
        
        let bytesPerRow = width * bytesPerSample
        let totalBytes = bytesPerRow * height
        
        var pixelData = Data(count: totalBytes)
        
        try pixelData.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else {
                throw DICOMError.parsingFailed("Failed to get pixel buffer address")
            }
            
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bytesPerSample * 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw DICOMError.parsingFailed("Failed to create grayscale context")
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        return pixelData
    }
    
    /// Extracts RGB pixel data
    private func extractRGBData(from image: CGImage, descriptor: PixelDataDescriptor) throws -> Data {
        let width = descriptor.columns
        let height = descriptor.rows
        let bytesPerSample = descriptor.bytesPerSample
        
        // For RGB, we need 3 samples per pixel
        let bytesPerPixel = 3 * bytesPerSample
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        
        // Create RGB context (using RGBA internally, then strip alpha)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rgbaBytesPerRow = width * 4 * bytesPerSample
        var rgbaData = Data(count: rgbaBytesPerRow * height)
        
        let bitmapInfo: CGBitmapInfo
        if bytesPerSample == 1 {
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        } else {
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
        }
        
        try rgbaData.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else {
                throw DICOMError.parsingFailed("Failed to get pixel buffer address")
            }
            
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bytesPerSample * 8,
                bytesPerRow: rgbaBytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw DICOMError.parsingFailed("Failed to create RGB context")
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Strip alpha channel to get pure RGB
        var rgbData = Data(capacity: totalBytes)
        
        if bytesPerSample == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let rgbaOffset = y * rgbaBytesPerRow + x * 4
                    rgbData.append(rgbaData[rgbaOffset])     // R
                    rgbData.append(rgbaData[rgbaOffset + 1]) // G
                    rgbData.append(rgbaData[rgbaOffset + 2]) // B
                }
            }
        } else {
            for y in 0..<height {
                for x in 0..<width {
                    let rgbaOffset = y * rgbaBytesPerRow + x * 8
                    rgbData.append(rgbaData[rgbaOffset])     // R low
                    rgbData.append(rgbaData[rgbaOffset + 1]) // R high
                    rgbData.append(rgbaData[rgbaOffset + 2]) // G low
                    rgbData.append(rgbaData[rgbaOffset + 3]) // G high
                    rgbData.append(rgbaData[rgbaOffset + 4]) // B low
                    rgbData.append(rgbaData[rgbaOffset + 5]) // B high
                }
            }
        }
        
        return rgbData
    }
    
    // MARK: - Private Encoding Helpers
    
    /// Creates a CGImage from raw pixel data
    private func createCGImage(from data: Data, descriptor: PixelDataDescriptor) throws -> CGImage {
        let width = descriptor.columns
        let height = descriptor.rows
        let bytesPerSample = descriptor.bytesPerSample
        let samplesPerPixel = descriptor.samplesPerPixel
        let bitsPerComponent = bytesPerSample * 8
        
        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        let bytesPerRow: Int
        var processedData = data
        
        if samplesPerPixel == 1 {
            // Grayscale
            colorSpace = CGColorSpaceCreateDeviceGray()
            if bytesPerSample == 1 {
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            } else {
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
            }
            bytesPerRow = width * bytesPerSample
        } else if samplesPerPixel == 3 {
            // RGB - need to convert to RGBA for CGImage
            colorSpace = CGColorSpaceCreateDeviceRGB()
            if bytesPerSample == 1 {
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            } else {
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
            }
            bytesPerRow = width * 4 * bytesPerSample
            
            // Convert RGB to RGBA by adding alpha channel
            processedData = try addAlphaChannel(to: data, descriptor: descriptor)
        } else {
            throw DICOMError.parsingFailed("Unsupported samples per pixel for encoding: \(samplesPerPixel)")
        }
        
        // Create CGImage from data
        guard let dataProvider = CGDataProvider(data: processedData as CFData) else {
            throw DICOMError.parsingFailed("Failed to create data provider for encoding")
        }
        
        let bitsPerPixel: Int
        if samplesPerPixel == 1 {
            bitsPerPixel = bitsPerComponent
        } else {
            bitsPerPixel = 4 * bitsPerComponent // RGBA
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw DICOMError.parsingFailed("Failed to create CGImage for encoding")
        }
        
        return cgImage
    }
    
    /// Adds alpha channel to RGB data to create RGBA data
    private func addAlphaChannel(to rgbData: Data, descriptor: PixelDataDescriptor) throws -> Data {
        let width = descriptor.columns
        let height = descriptor.rows
        let bytesPerSample = descriptor.bytesPerSample
        let rgbBytesPerPixel = 3 * bytesPerSample
        let rgbaBytesPerPixel = 4 * bytesPerSample
        
        var rgbaData = Data(capacity: width * height * rgbaBytesPerPixel)
        
        if bytesPerSample == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let rgbOffset = (y * width + x) * rgbBytesPerPixel
                    guard rgbOffset + 2 < rgbData.count else {
                        throw DICOMError.parsingFailed("RGB data too short for pixel at (\(x), \(y))")
                    }
                    rgbaData.append(rgbData[rgbOffset])     // R
                    rgbaData.append(rgbData[rgbOffset + 1]) // G
                    rgbaData.append(rgbData[rgbOffset + 2]) // B
                    rgbaData.append(0xFF)                    // A (fully opaque)
                }
            }
        } else {
            // 16-bit samples
            for y in 0..<height {
                for x in 0..<width {
                    let rgbOffset = (y * width + x) * rgbBytesPerPixel
                    guard rgbOffset + 5 < rgbData.count else {
                        throw DICOMError.parsingFailed("RGB data too short for pixel at (\(x), \(y))")
                    }
                    rgbaData.append(rgbData[rgbOffset])     // R low
                    rgbaData.append(rgbData[rgbOffset + 1]) // R high
                    rgbaData.append(rgbData[rgbOffset + 2]) // G low
                    rgbaData.append(rgbData[rgbOffset + 3]) // G high
                    rgbaData.append(rgbData[rgbOffset + 4]) // B low
                    rgbaData.append(rgbData[rgbOffset + 5]) // B high
                    rgbaData.append(0xFF)                    // A low
                    rgbaData.append(0xFF)                    // A high
                }
            }
        }
        
        return rgbaData
    }
    
    /// Encodes a CGImage to JPEG 2000 data
    private func encodeToJPEG2000(_ image: CGImage, configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) throws -> Data {
        let mutableData = NSMutableData()
        
        // Use JP2 (JPEG 2000) format - UTType.jpeg2000 for type safety
        let jp2UTType = UTType.jpeg2000.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(mutableData, jp2UTType, 1, nil) else {
            throw DICOMError.parsingFailed("Failed to create JPEG 2000 image destination")
        }
        
        // Set compression options
        var options: [CFString: Any] = [:]
        
        // For JPEG 2000, use lossless if preferLossless is set
        if configuration.preferLossless || configuration.quality.isLossless {
            // Lossless JPEG 2000 - quality of 1.0 means lossless
            options[kCGImageDestinationLossyCompressionQuality] = 1.0
        } else {
            // Lossy compression with specified quality
            options[kCGImageDestinationLossyCompressionQuality] = configuration.quality.value
        }
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw DICOMError.parsingFailed("Failed to finalize JPEG 2000 encoding")
        }
        
        return mutableData as Data
    }
}

#endif
