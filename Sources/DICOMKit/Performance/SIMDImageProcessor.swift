import Foundation

#if canImport(Accelerate)
import Accelerate

/// SIMD-accelerated image processing operations for DICOM pixel data
///
/// Provides optimized implementations of common image processing operations
/// using vector instructions (SIMD) for improved performance.
///
/// This implementation uses Apple's Accelerate framework and is only available
/// on Apple platforms (iOS, macOS, visionOS).
public struct SIMDImageProcessor {
    
    /// Applies window/level transformation to pixel data using SIMD acceleration
    ///
    /// This is significantly faster than scalar implementation for large images.
    ///
    /// - Parameters:
    ///   - pixelData: Input pixel data (UInt16 values)
    ///   - windowCenter: Window center value
    ///   - windowWidth: Window width value
    ///   - bitsStored: Number of bits stored per pixel
    /// - Returns: Transformed pixel data (UInt8 values, 0-255 range)
    public static func applyWindowLevel(
        to pixelData: [UInt16],
        windowCenter: Double,
        windowWidth: Double,
        bitsStored: Int = 16
    ) -> [UInt8] {
        let count = pixelData.count
        var output = [UInt8](repeating: 0, count: count)
        
        // Calculate window parameters
        let minValue = windowCenter - windowWidth / 2.0
        let maxValue = windowCenter + windowWidth / 2.0
        let range = maxValue - minValue
        
        guard range > 0 else {
            // Invalid window, return zeros
            return output
        }
        
        let scale = 255.0 / range
        
        // Use vDSP for vectorized operations
        var floatPixels = [Float](repeating: 0, count: count)
        
        // Convert UInt16 to Float
        vDSP_vfltu16(pixelData, 1, &floatPixels, 1, vDSP_Length(count))
        
        // Subtract minValue
        var minValueFloat = Float(minValue)
        vDSP_vsadd(floatPixels, 1, &minValueFloat, &floatPixels, 1, vDSP_Length(count))
        
        // Multiply by scale
        var scaleFloat = Float(scale)
        vDSP_vsmul(floatPixels, 1, &scaleFloat, &floatPixels, 1, vDSP_Length(count))
        
        // Clip to [0, 255]
        var lowerBound: Float = 0
        var upperBound: Float = 255
        vDSP_vclip(floatPixels, 1, &lowerBound, &upperBound, &floatPixels, 1, vDSP_Length(count))
        
        // Convert to UInt8
        vDSP_vfixu8(floatPixels, 1, &output, 1, vDSP_Length(count))
        
        return output
    }
    
    /// Applies inversion (MONOCHROME1) to pixel data using SIMD
    ///
    /// - Parameter pixelData: Input pixel data (UInt8 values, 0-255)
    /// - Returns: Inverted pixel data
    public static func invertPixels(_ pixelData: [UInt8]) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: pixelData.count)
        
        // Convert to float
        var floatPixels = [Float](repeating: 0, count: pixelData.count)
        vDSP_vfltu8(pixelData, 1, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        // Invert: output = 255 - input
        var maxValue: Float = 255
        vDSP_vsbsbm(floatPixels, 1, &maxValue, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        // Convert back to UInt8
        vDSP_vfixu8(floatPixels, 1, &output, 1, vDSP_Length(pixelData.count))
        
        return output
    }
    
    /// Normalizes pixel data to 8-bit range using SIMD
    ///
    /// Maps input values from [minValue, maxValue] to [0, 255]
    ///
    /// - Parameters:
    ///   - pixelData: Input pixel data
    ///   - minValue: Minimum input value
    ///   - maxValue: Maximum input value
    /// - Returns: Normalized pixel data (UInt8)
    public static func normalize(
        _ pixelData: [UInt16],
        minValue: UInt16,
        maxValue: UInt16
    ) -> [UInt8] {
        let count = pixelData.count
        var output = [UInt8](repeating: 0, count: count)
        
        let range = Double(maxValue) - Double(minValue)
        guard range > 0 else {
            return output
        }
        
        let scale = 255.0 / range
        let offset = -Double(minValue) * scale
        
        // Convert to float
        var floatPixels = [Float](repeating: 0, count: count)
        vDSP_vfltu16(pixelData, 1, &floatPixels, 1, vDSP_Length(count))
        
        // Scale and offset
        var scaleFloat = Float(scale)
        var offsetFloat = Float(offset)
        vDSP_vsmsa(floatPixels, 1, &scaleFloat, &offsetFloat, &floatPixels, 1, vDSP_Length(count))
        
        // Clip to [0, 255]
        var lowerBound: Float = 0
        var upperBound: Float = 255
        vDSP_vclip(floatPixels, 1, &lowerBound, &upperBound, &floatPixels, 1, vDSP_Length(count))
        
        // Convert to UInt8
        vDSP_vfixu8(floatPixels, 1, &output, 1, vDSP_Length(count))
        
        return output
    }
    
    /// Finds minimum and maximum values in pixel data using SIMD
    ///
    /// - Parameter pixelData: Input pixel data
    /// - Returns: Tuple of (min, max) values
    public static func findMinMax(_ pixelData: [UInt16]) -> (min: UInt16, max: UInt16) {
        guard !pixelData.isEmpty else {
            return (0, 0)
        }
        
        // Convert to float for vDSP operations
        var floatPixels = [Float](repeating: 0, count: pixelData.count)
        vDSP_vfltu16(pixelData, 1, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        var minValue: Float = 0
        var maxValue: Float = 0
        
        vDSP_minv(floatPixels, 1, &minValue, vDSP_Length(pixelData.count))
        vDSP_maxv(floatPixels, 1, &maxValue, vDSP_Length(pixelData.count))
        
        return (min: UInt16(minValue), max: UInt16(maxValue))
    }
    
    /// Applies linear contrast adjustment using SIMD
    ///
    /// - Parameters:
    ///   - pixelData: Input pixel data (UInt8)
    ///   - alpha: Contrast multiplier (1.0 = no change, >1.0 = more contrast)
    ///   - beta: Brightness offset (0 = no change)
    /// - Returns: Adjusted pixel data
    public static func adjustContrast(
        _ pixelData: [UInt8],
        alpha: Float,
        beta: Float
    ) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: pixelData.count)
        
        // Convert to float
        var floatPixels = [Float](repeating: 0, count: pixelData.count)
        vDSP_vfltu8(pixelData, 1, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        // Apply: output = alpha * input + beta
        var alphaVar = alpha
        var betaVar = beta
        vDSP_vsmsa(floatPixels, 1, &alphaVar, &betaVar, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        // Clip to [0, 255]
        var lowerBound: Float = 0
        var upperBound: Float = 255
        vDSP_vclip(floatPixels, 1, &lowerBound, &upperBound, &floatPixels, 1, vDSP_Length(pixelData.count))
        
        // Convert back to UInt8
        vDSP_vfixu8(floatPixels, 1, &output, 1, vDSP_Length(pixelData.count))
        
        return output
    }
}

#endif
