import Foundation

#if canImport(ImageIO)
import ImageIO
import CoreGraphics

/// Native JPEG codec using Apple's ImageIO framework
///
/// Supports JPEG Baseline, Extended, and Lossless transfer syntaxes.
/// Reference: DICOM PS3.5 Section A.4.1-A.4.3
public struct NativeJPEGCodec: ImageCodec, Sendable {
    /// Supported JPEG transfer syntaxes
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpegBaseline.uid,     // 1.2.840.10008.1.2.4.50
        TransferSyntax.jpegExtended.uid,     // 1.2.840.10008.1.2.4.51
        TransferSyntax.jpegLossless.uid,     // 1.2.840.10008.1.2.4.57
        TransferSyntax.jpegLosslessSV1.uid   // 1.2.840.10008.1.2.4.70
    ]
    
    public init() {}
    
    /// Decodes a JPEG-compressed frame
    /// - Parameters:
    ///   - frameData: JPEG compressed data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Frame index (unused for single frame decode)
    /// - Returns: Uncompressed pixel data
    /// - Throws: DICOMError if decoding fails
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG data")
        }
        
        // Create image source from JPEG data
        guard let imageSource = CGImageSourceCreateWithData(frameData as CFData, nil) else {
            throw DICOMError.parsingFailed("Failed to create image source from JPEG data")
        }
        
        // Get the image
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DICOMError.parsingFailed("Failed to decode JPEG image")
        }
        
        // Extract pixel data from CGImage
        return try extractPixelData(from: cgImage, descriptor: descriptor)
    }
    
    /// Extracts raw pixel data from a CGImage
    private func extractPixelData(from image: CGImage, descriptor: PixelDataDescriptor) throws -> Data {
        let width = image.width
        let height = image.height
        let bytesPerSample = descriptor.bytesPerSample
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
}

#endif
