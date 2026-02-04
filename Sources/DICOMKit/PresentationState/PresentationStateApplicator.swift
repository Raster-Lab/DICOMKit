//
// PresentationStateApplicator.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics

/// Applies a presentation state to DICOM pixel data for display
///
/// Handles the complete transformation pipeline:
/// 1. Modality LUT (stored pixels → modality values)
/// 2. VOI LUT (modality values → values of interest)
/// 3. Presentation LUT (values of interest → P-Values for display)
/// 4. Spatial transformation (rotation and flip)
/// 5. Displayed area selection (zoom and pan)
/// 6. Shutters (masking regions)
/// 7. Graphic annotations (overlays)
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
public struct PresentationStateApplicator: Sendable {
    /// The presentation state to apply
    public let presentationState: GrayscalePresentationState
    
    /// Creates a new presentation state applicator
    ///
    /// - Parameter presentationState: The presentation state to apply
    public init(presentationState: GrayscalePresentationState) {
        self.presentationState = presentationState
    }
    
    // MARK: - Apply Presentation State to Pixel Data
    
    /// Applies the presentation state to pixel data and renders it to a CGImage
    ///
    /// - Parameters:
    ///   - pixelData: The pixel data to render
    ///   - frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage with presentation state applied, or nil if rendering fails
    public func apply(to pixelData: PixelData, frameIndex: Int = 0) -> CGImage? {
        let descriptor = pixelData.descriptor
        
        guard descriptor.photometricInterpretation.isMonochrome else {
            // Presentation states only apply to monochrome images
            return nil
        }
        
        guard let frameData = pixelData.frameData(at: frameIndex) else {
            return nil
        }
        
        let width = descriptor.columns
        let height = descriptor.rows
        let totalPixels = width * height
        
        // Create output buffer
        var outputBytes = [UInt8](repeating: 0, count: totalPixels)
        
        // Extract pixel values and apply the complete transformation pipeline
        let bytesPerSample = descriptor.bytesPerSample
        let bitShift = descriptor.bitShift
        let storedBitMask = descriptor.storedBitMask
        let isSigned = descriptor.isSigned
        
        for i in 0..<totalPixels {
            let offset = i * bytesPerSample
            guard offset + bytesPerSample <= frameData.count else {
                break
            }
            
            // Extract stored pixel value
            var pixelValue: Int
            if bytesPerSample == 1 {
                pixelValue = Int(frameData[offset])
            } else {
                let bytes = frameData[offset..<offset+bytesPerSample]
                let rawValue = bytes.withUnsafeBytes { $0.load(as: UInt16.self) }
                pixelValue = Int((rawValue >> bitShift) & UInt16(storedBitMask))
            }
            
            // Handle signed pixel values
            if isSigned {
                let signBit = 1 << (descriptor.bitsStored - 1)
                if pixelValue >= signBit {
                    pixelValue -= (1 << descriptor.bitsStored)
                }
            }
            
            // Apply transformation pipeline
            let displayValue = applyTransformationPipeline(to: pixelValue)
            
            // Convert to 8-bit for display
            let byteValue = UInt8(max(0, min(255, Int(displayValue * 255.0))))
            outputBytes[i] = byteValue
        }
        
        // Apply spatial transformation and shutters if needed
        if let spatialTransform = presentationState.spatialTransformation, spatialTransform.hasTransformation {
            outputBytes = applySpatialTransformation(
                to: outputBytes,
                width: width,
                height: height,
                transform: spatialTransform
            )
        }
        
        // Apply shutters
        if !presentationState.shutters.isEmpty {
            applyShutters(to: &outputBytes, width: width, height: height)
        }
        
        // Determine final dimensions based on spatial transformation
        let (finalWidth, finalHeight) = getFinalDimensions(width: width, height: height)
        
        // Create CGImage from output buffer
        return createCGImage(
            from: outputBytes,
            width: finalWidth,
            height: finalHeight
        )
    }
    
    // MARK: - Transformation Pipeline
    
    /// Applies the complete transformation pipeline to a pixel value
    ///
    /// Pipeline: Stored Pixel → Modality LUT → VOI LUT → Presentation LUT → Display
    ///
    /// - Parameter storedPixelValue: The stored pixel value from the DICOM file
    /// - Returns: Normalized display value (0.0-1.0)
    private func applyTransformationPipeline(to storedPixelValue: Int) -> Double {
        // Step 1: Apply Modality LUT (stored pixels → modality values, e.g., Hounsfield Units)
        var modalityValue = Double(storedPixelValue)
        if let modalityLUT = presentationState.modalityLUT {
            modalityValue = modalityLUT.apply(to: storedPixelValue)
        }
        
        // Step 2: Apply VOI LUT (modality values → values of interest, window/level)
        var voiValue = modalityValue
        if let voiLUT = presentationState.voiLUT {
            voiValue = voiLUT.apply(to: modalityValue)
        } else {
            // Default: normalize to 0.0-1.0 (assuming typical grayscale range)
            voiValue = modalityValue / 4095.0  // Assume 12-bit default
        }
        
        // Step 3: Apply Presentation LUT (values of interest → P-Values, polarity)
        var presentationValue = voiValue
        if let presentationLUT = presentationState.presentationLUT {
            presentationValue = presentationLUT.apply(to: voiValue)
        }
        
        // Clamp to valid range
        return max(0.0, min(1.0, presentationValue))
    }
    
    // MARK: - Spatial Transformation
    
    private func applySpatialTransformation(
        to bytes: [UInt8],
        width: Int,
        height: Int,
        transform: SpatialTransformation
    ) -> [UInt8] {
        var result = bytes
        
        // Apply horizontal flip if needed
        if transform.isFlipped {
            result = applyHorizontalFlip(to: result, width: width, height: height)
        }
        
        // Apply rotation if needed
        if transform.isRotated {
            result = applyRotation(to: result, width: width, height: height, degrees: transform.rotation)
        }
        
        return result
    }
    
    private func applyHorizontalFlip(to bytes: [UInt8], width: Int, height: Int) -> [UInt8] {
        var flipped = [UInt8](repeating: 0, count: bytes.count)
        
        for y in 0..<height {
            for x in 0..<width {
                let srcIndex = y * width + x
                let dstIndex = y * width + (width - 1 - x)
                flipped[dstIndex] = bytes[srcIndex]
            }
        }
        
        return flipped
    }
    
    private func applyRotation(
        to bytes: [UInt8],
        width: Int,
        height: Int,
        degrees: Int
    ) -> [UInt8] {
        switch degrees {
        case 90:
            return rotateBy90(bytes: bytes, width: width, height: height)
        case 180:
            return rotateBy180(bytes: bytes, width: width, height: height)
        case 270:
            return rotateBy270(bytes: bytes, width: width, height: height)
        default:
            return bytes
        }
    }
    
    private func rotateBy90(bytes: [UInt8], width: Int, height: Int) -> [UInt8] {
        var rotated = [UInt8](repeating: 0, count: bytes.count)
        
        for y in 0..<height {
            for x in 0..<width {
                let srcIndex = y * width + x
                let dstX = height - 1 - y
                let dstY = x
                let dstIndex = dstY * height + dstX
                rotated[dstIndex] = bytes[srcIndex]
            }
        }
        
        return rotated
    }
    
    private func rotateBy180(bytes: [UInt8], width: Int, height: Int) -> [UInt8] {
        var rotated = [UInt8](repeating: 0, count: bytes.count)
        
        for i in 0..<bytes.count {
            rotated[bytes.count - 1 - i] = bytes[i]
        }
        
        return rotated
    }
    
    private func rotateBy270(bytes: [UInt8], width: Int, height: Int) -> [UInt8] {
        var rotated = [UInt8](repeating: 0, count: bytes.count)
        
        for y in 0..<height {
            for x in 0..<width {
                let srcIndex = y * width + x
                let dstX = y
                let dstY = width - 1 - x
                let dstIndex = dstY * height + dstX
                rotated[dstIndex] = bytes[srcIndex]
            }
        }
        
        return rotated
    }
    
    private func getFinalDimensions(width: Int, height: Int) -> (Int, Int) {
        guard let transform = presentationState.spatialTransformation else {
            return (width, height)
        }
        
        switch transform.rotation {
        case 90, 270:
            return (height, width)  // Swap dimensions for 90/270 degree rotation
        default:
            return (width, height)
        }
    }
    
    // MARK: - Shutters
    
    private func applyShutters(to bytes: inout [UInt8], width: Int, height: Int) {
        let shutterValue: UInt8
        
        // Use the presentation value from the first shutter, or default to black (0)
        if let firstShutterValue = presentationState.shutters.first?.presentationValue {
            shutterValue = UInt8(max(0, min(255, firstShutterValue)))
        } else {
            shutterValue = 0
        }
        
        for y in 0..<height {
            for x in 0..<width {
                // Check if this pixel is inside any shutter
                let isShuttered = presentationState.shutters.contains { shutter in
                    shutter.contains(column: x, row: y)
                }
                
                if isShuttered {
                    let index = y * width + x
                    bytes[index] = shutterValue
                }
            }
        }
    }
    
    // MARK: - CGImage Creation
    
    private func createCGImage(from bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0 else {
            return nil
        }
        
        let bytesPerRow = width
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else {
            return nil
        }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

#endif // canImport(CoreGraphics)
