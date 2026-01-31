import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics

/// Renders DICOM pixel data to CGImage for display
///
/// Supports rendering of uncompressed DICOM images including:
/// - MONOCHROME1 and MONOCHROME2 grayscale images
/// - RGB color images
/// - PALETTE COLOR images with lookup tables
/// - 8-bit, 12-bit, and 16-bit images
/// - Multi-frame images (individual frame rendering)
///
/// Reference: DICOM PS3.3 C.7.6.3 - Image Pixel Module
public struct PixelDataRenderer: Sendable {
    /// The pixel data to render
    public let pixelData: PixelData
    
    /// Optional palette color lookup table for PALETTE COLOR images
    public let paletteColorLUT: PaletteColorLUT?
    
    /// Creates a new renderer for the specified pixel data
    /// - Parameter pixelData: The pixel data to render
    public init(pixelData: PixelData) {
        self.pixelData = pixelData
        self.paletteColorLUT = nil
    }
    
    /// Creates a new renderer for the specified pixel data with a palette color LUT
    /// - Parameters:
    ///   - pixelData: The pixel data to render
    ///   - paletteColorLUT: Palette color lookup table for PALETTE COLOR images
    public init(pixelData: PixelData, paletteColorLUT: PaletteColorLUT?) {
        self.pixelData = pixelData
        self.paletteColorLUT = paletteColorLUT
    }
    
    // MARK: - CGImage Rendering
    
    /// Renders a frame to a CGImage using default settings
    ///
    /// For monochrome images, calculates window settings from the actual pixel range.
    /// For palette color images, uses the palette lookup table if provided.
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds, nil otherwise
    public func renderFrame(_ frameIndex: Int = 0) -> CGImage? {
        let descriptor = pixelData.descriptor
        
        if descriptor.photometricInterpretation.isMonochrome {
            // Calculate auto window from actual pixel range
            guard let range = pixelData.pixelRange(forFrame: frameIndex) else {
                return nil
            }
            
            let center = Double(range.min + range.max) / 2.0
            let width = Double(range.max - range.min)
            let window = WindowSettings(center: center, width: max(1.0, width))
            
            return renderMonochromeFrame(frameIndex, window: window)
        } else if descriptor.photometricInterpretation.isPaletteColor {
            return renderPaletteColorFrame(frameIndex)
        } else {
            return renderColorFrame(frameIndex)
        }
    }
    
    /// Renders a monochrome frame to a CGImage with specified window settings
    /// - Parameters:
    ///   - frameIndex: The frame index to render (default 0)
    ///   - window: Window settings for grayscale mapping
    /// - Returns: CGImage if rendering succeeds, nil otherwise
    public func renderMonochromeFrame(_ frameIndex: Int = 0, window: WindowSettings) -> CGImage? {
        let descriptor = pixelData.descriptor
        
        guard descriptor.photometricInterpretation.isMonochrome else {
            return nil
        }
        
        guard let frameData = pixelData.frameData(at: frameIndex) else {
            return nil
        }
        
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        
        // Create grayscale output buffer
        var outputBytes = [UInt8](repeating: 0, count: totalPixels)
        
        // Extract pixel values and apply windowing
        let bytesPerSample = descriptor.bytesPerSample
        let bitShift = descriptor.bitShift
        let storedBitMask = descriptor.storedBitMask
        let isSigned = descriptor.isSigned
        let bitsStored = descriptor.bitsStored
        let isMonochrome1 = descriptor.photometricInterpretation == .monochrome1
        
        for i in 0..<totalPixels {
            let offset = i * bytesPerSample
            guard offset + bytesPerSample <= frameData.count else {
                break
            }
            
            // Read raw value
            let rawValue: Int
            if bytesPerSample == 1 {
                rawValue = Int(frameData[offset])
            } else {
                let low = Int(frameData[offset])
                let high = Int(frameData[offset + 1])
                rawValue = low | (high << 8)
            }
            
            // Apply bit masking
            let shiftedValue = rawValue >> bitShift
            var maskedValue = shiftedValue & storedBitMask
            
            // Apply sign extension if needed
            if isSigned {
                let signBit = 1 << (bitsStored - 1)
                if maskedValue & signBit != 0 {
                    maskedValue = maskedValue - (1 << bitsStored)
                }
            }
            
            // Apply window transform
            var normalized = window.apply(to: Double(maskedValue))
            
            // For MONOCHROME1, invert the output (white = minimum)
            if isMonochrome1 {
                normalized = 1.0 - normalized
            }
            
            // Clamp and convert to 8-bit
            outputBytes[i] = UInt8(max(0, min(255, normalized * 255.0)))
        }
        
        return createGrayscaleCGImage(from: outputBytes, width: width, height: height)
    }
    
    /// Renders a color frame to a CGImage
    ///
    /// Handles RGB and YBR color images with 3 samples per pixel.
    /// For PALETTE COLOR images, use renderPaletteColorFrame instead.
    ///
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds, nil otherwise
    public func renderColorFrame(_ frameIndex: Int = 0) -> CGImage? {
        let descriptor = pixelData.descriptor
        
        // Only handle RGB/YBR color images, not PALETTE COLOR
        guard descriptor.photometricInterpretation.isColor,
              !descriptor.photometricInterpretation.isPaletteColor else {
            return nil
        }
        
        guard descriptor.samplesPerPixel == 3 else {
            return nil
        }
        
        guard let frameData = pixelData.frameData(at: frameIndex) else {
            return nil
        }
        
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        
        // Create RGB output buffer (4 bytes per pixel: RGBA)
        var outputBytes = [UInt8](repeating: 255, count: totalPixels * 4)
        
        let bytesPerSample = descriptor.bytesPerSample
        let planarConfig = descriptor.planarConfiguration
        let bitShift = descriptor.bitShift
        let storedBitMask = descriptor.storedBitMask
        let maxValue = (1 << descriptor.bitsStored) - 1
        
        for pixelIndex in 0..<totalPixels {
            var r: Int = 0
            var g: Int = 0
            var b: Int = 0
            
            if planarConfig == 0 {
                // Color-by-pixel: R1G1B1R2G2B2...
                let baseOffset = pixelIndex * 3 * bytesPerSample
                
                if bytesPerSample == 1 {
                    if baseOffset + 2 < frameData.count {
                        r = Int(frameData[baseOffset])
                        g = Int(frameData[baseOffset + 1])
                        b = Int(frameData[baseOffset + 2])
                    }
                } else {
                    if baseOffset + 5 < frameData.count {
                        r = Int(frameData[baseOffset]) | (Int(frameData[baseOffset + 1]) << 8)
                        g = Int(frameData[baseOffset + 2]) | (Int(frameData[baseOffset + 3]) << 8)
                        b = Int(frameData[baseOffset + 4]) | (Int(frameData[baseOffset + 5]) << 8)
                    }
                }
            } else {
                // Color-by-plane: R1R2...G1G2...B1B2...
                let planeSize = totalPixels * bytesPerSample
                let rOffset = pixelIndex * bytesPerSample
                let gOffset = planeSize + pixelIndex * bytesPerSample
                let bOffset = 2 * planeSize + pixelIndex * bytesPerSample
                
                if bytesPerSample == 1 {
                    if bOffset < frameData.count {
                        r = Int(frameData[rOffset])
                        g = Int(frameData[gOffset])
                        b = Int(frameData[bOffset])
                    }
                } else {
                    if bOffset + 1 < frameData.count {
                        r = Int(frameData[rOffset]) | (Int(frameData[rOffset + 1]) << 8)
                        g = Int(frameData[gOffset]) | (Int(frameData[gOffset + 1]) << 8)
                        b = Int(frameData[bOffset]) | (Int(frameData[bOffset + 1]) << 8)
                    }
                }
            }
            
            // Apply bit masking
            r = (r >> bitShift) & storedBitMask
            g = (g >> bitShift) & storedBitMask
            b = (b >> bitShift) & storedBitMask
            
            // Normalize to 8-bit
            let scale = 255.0 / Double(maxValue)
            let outputOffset = pixelIndex * 4
            outputBytes[outputOffset] = UInt8(max(0, min(255, Double(r) * scale)))
            outputBytes[outputOffset + 1] = UInt8(max(0, min(255, Double(g) * scale)))
            outputBytes[outputOffset + 2] = UInt8(max(0, min(255, Double(b) * scale)))
            outputBytes[outputOffset + 3] = 255 // Alpha
        }
        
        // Handle YBR to RGB conversion if needed
        if isYBRPhotometricInterpretation(descriptor.photometricInterpretation) {
            convertYBRToRGB(&outputBytes, totalPixels: totalPixels)
        }
        
        return createRGBACGImage(from: outputBytes, width: width, height: height)
    }
    
    /// Renders a palette color frame to a CGImage
    ///
    /// Uses the palette color lookup table to convert indexed pixel values
    /// to RGB colors.
    ///
    /// Reference: DICOM PS3.3 C.7.6.3.1.5 - Palette Color Lookup Table Module
    ///
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds, nil otherwise
    public func renderPaletteColorFrame(_ frameIndex: Int = 0) -> CGImage? {
        let descriptor = pixelData.descriptor
        
        guard descriptor.photometricInterpretation.isPaletteColor else {
            return nil
        }
        
        guard let lut = paletteColorLUT else {
            return nil
        }
        
        guard let frameData = pixelData.frameData(at: frameIndex) else {
            return nil
        }
        
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        
        // Create RGB output buffer (4 bytes per pixel: RGBA)
        var outputBytes = [UInt8](repeating: 255, count: totalPixels * 4)
        
        let bytesPerSample = descriptor.bytesPerSample
        let bitShift = descriptor.bitShift
        let storedBitMask = descriptor.storedBitMask
        let isSigned = descriptor.isSigned
        let bitsStored = descriptor.bitsStored
        
        for pixelIndex in 0..<totalPixels {
            let offset = pixelIndex * bytesPerSample
            guard offset + bytesPerSample <= frameData.count else {
                break
            }
            
            // Read raw pixel value (index into LUT)
            let rawValue: Int
            if bytesPerSample == 1 {
                rawValue = Int(frameData[offset])
            } else {
                let low = Int(frameData[offset])
                let high = Int(frameData[offset + 1])
                rawValue = low | (high << 8)
            }
            
            // Apply bit masking
            let shiftedValue = rawValue >> bitShift
            var maskedValue = shiftedValue & storedBitMask
            
            // Apply sign extension if needed
            if isSigned {
                let signBit = 1 << (bitsStored - 1)
                if maskedValue & signBit != 0 {
                    maskedValue = maskedValue - (1 << bitsStored)
                }
            }
            
            // Look up the color in the palette
            let (red, green, blue) = lut.lookup(maskedValue)
            
            // Write to output buffer
            let outputOffset = pixelIndex * 4
            outputBytes[outputOffset] = red
            outputBytes[outputOffset + 1] = green
            outputBytes[outputOffset + 2] = blue
            outputBytes[outputOffset + 3] = 255 // Alpha
        }
        
        return createRGBACGImage(from: outputBytes, width: width, height: height)
    }
    
    // MARK: - Private Helpers
    
    /// Creates a grayscale CGImage from pixel bytes
    private func createGrayscaleCGImage(from bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let bytesPerRow = width
        
        guard let dataProvider = CGDataProvider(data: Data(bytes) as CFData) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    
    /// Creates an RGBA CGImage from pixel bytes
    private func createRGBACGImage(from bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bytesPerRow = width * 4
        
        guard let dataProvider = CGDataProvider(data: Data(bytes) as CFData) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    
    /// Checks if photometric interpretation is a YBR variant
    private func isYBRPhotometricInterpretation(_ pi: PhotometricInterpretation) -> Bool {
        switch pi {
        case .ybrFull, .ybrFull422, .ybrPartial422, .ybrPartial420, .ybrICT, .ybrRCT:
            return true
        default:
            return false
        }
    }
    
    /// Converts YBR pixel data to RGB in place
    /// Reference: DICOM PS3.3 C.7.6.3.1.2
    private func convertYBRToRGB(_ bytes: inout [UInt8], totalPixels: Int) {
        for i in 0..<totalPixels {
            let offset = i * 4
            let y = Double(bytes[offset])
            let cb = Double(bytes[offset + 1])
            let cr = Double(bytes[offset + 2])
            
            // YBR_FULL to RGB conversion
            // Reference: PS3.3 C.7.6.3.1.2
            let r = y + 1.402 * (cr - 128.0)
            let g = y - 0.344136 * (cb - 128.0) - 0.714136 * (cr - 128.0)
            let b = y + 1.772 * (cb - 128.0)
            
            bytes[offset] = UInt8(max(0, min(255, r)))
            bytes[offset + 1] = UInt8(max(0, min(255, g)))
            bytes[offset + 2] = UInt8(max(0, min(255, b)))
        }
    }
}

#endif
