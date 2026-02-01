import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// DICOMFile extensions for pixel data access
///
/// Provides convenient methods to access pixel data and render images
/// from a DICOM file.
/// Reference: DICOM PS3.3 C.7.6.3 - Image Pixel Module
extension DICOMFile {
    // MARK: - Pixel Data Access
    
    /// Extracts pixel data from the DICOM file
    ///
    /// Returns the uncompressed pixel data along with its descriptor.
    /// For compressed transfer syntaxes (JPEG, JPEG 2000, RLE), the pixel data
    /// is automatically decompressed using the appropriate codec.
    /// Returns nil if pixel data is not present or cannot be extracted.
    ///
    /// - Returns: PixelData if extraction succeeds
    public func pixelData() -> PixelData? {
        // First try to get uncompressed pixel data directly
        if let uncompressedData = dataSet.pixelData() {
            return uncompressedData
        }
        
        // Check if we have encapsulated (compressed) pixel data
        guard let encapsulated = dataSet.encapsulatedPixelData(),
              let tsUID = transferSyntaxUID else {
            return nil
        }
        
        // Get the codec for this transfer syntax
        guard let codec = CodecRegistry.shared.codec(for: tsUID) else {
            // No codec available for this transfer syntax
            return nil
        }
        
        // Decompress all frames
        let descriptor = encapsulated.descriptor
        var decompressedData = Data()
        
        for frameIndex in 0..<descriptor.numberOfFrames {
            guard let frameData = encapsulated.frameData(at: frameIndex) else {
                // Could not retrieve frame data from encapsulated pixel data
                return nil
            }
            
            do {
                let decompressedFrame = try codec.decodeFrame(
                    frameData,
                    descriptor: descriptor,
                    frameIndex: frameIndex
                )
                decompressedData.append(decompressedFrame)
            } catch {
                // Decompression failed - codec could not decode the compressed frame data
                // This can happen if the compressed data is corrupted or uses an unsupported
                // variant of the compression format
                return nil
            }
        }
        
        return PixelData(data: decompressedData, descriptor: descriptor)
    }
    
    /// Extracts pixel data from the DICOM file, throwing detailed errors on failure
    ///
    /// Returns the uncompressed pixel data along with its descriptor.
    /// For compressed transfer syntaxes (JPEG, JPEG 2000, RLE), the pixel data
    /// is automatically decompressed using the appropriate codec.
    ///
    /// This method provides detailed error information when pixel data extraction fails,
    /// unlike `pixelData()` which simply returns nil.
    ///
    /// - Returns: PixelData if extraction succeeds
    /// - Throws: `PixelDataError` with detailed information about the failure
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     let pixelData = try dicomFile.tryPixelData()
    ///     // Use pixel data...
    /// } catch let error as PixelDataError {
    ///     print("Failed to extract pixel data: \(error.description)")
    ///     print("Explanation: \(error.explanation)")
    /// }
    /// ```
    public func tryPixelData() throws -> PixelData {
        // First check if we have a valid descriptor
        guard let descriptor = dataSet.pixelDataDescriptor() else {
            throw PixelDataError.missingDescriptor
        }
        
        // Check if pixel data element exists
        guard let pixelDataElement = dataSet[.pixelData] else {
            throw PixelDataError.missingPixelData
        }
        
        // Try to get uncompressed pixel data directly
        if !pixelDataElement.valueData.isEmpty {
            return PixelData(data: pixelDataElement.valueData, descriptor: descriptor)
        }
        
        // Check if we have encapsulated (compressed) pixel data
        guard let encapsulated = dataSet.encapsulatedPixelData() else {
            throw PixelDataError.missingPixelData
        }
        
        guard let tsUID = transferSyntaxUID else {
            throw PixelDataError.missingTransferSyntax
        }
        
        // Get the codec for this transfer syntax
        guard let codec = CodecRegistry.shared.codec(for: tsUID) else {
            throw PixelDataError.unsupportedTransferSyntax(tsUID)
        }
        
        // Decompress all frames
        var decompressedData = Data()
        
        for frameIndex in 0..<descriptor.numberOfFrames {
            guard let frameData = encapsulated.frameData(at: frameIndex) else {
                throw PixelDataError.frameExtractionFailed(frameIndex: frameIndex)
            }
            
            do {
                let decompressedFrame = try codec.decodeFrame(
                    frameData,
                    descriptor: descriptor,
                    frameIndex: frameIndex
                )
                decompressedData.append(decompressedFrame)
            } catch {
                throw PixelDataError.decodingFailed(
                    frameIndex: frameIndex,
                    reason: error.localizedDescription
                )
            }
        }
        
        return PixelData(data: decompressedData, descriptor: descriptor)
    }
    
    /// Creates a PixelDataDescriptor from the file's image pixel attributes
    ///
    /// - Returns: PixelDataDescriptor if all required attributes are present
    public func pixelDataDescriptor() -> PixelDataDescriptor? {
        dataSet.pixelDataDescriptor()
    }
    
    // MARK: - Window Settings
    
    /// Returns the first window settings from the file
    ///
    /// - Returns: WindowSettings if present
    public func windowSettings() -> WindowSettings? {
        dataSet.windowSettings()
    }
    
    /// Returns all window settings from the file
    ///
    /// - Returns: Array of WindowSettings
    public func allWindowSettings() -> [WindowSettings] {
        dataSet.allWindowSettings()
    }
    
#if canImport(CoreGraphics)
    // MARK: - Image Rendering
    
    /// Renders the specified frame to a CGImage
    ///
    /// Uses automatic windowing based on pixel value range for monochrome images.
    /// For palette color images, uses the palette lookup table from the DICOM file.
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds
    public func renderFrame(_ frameIndex: Int = 0) -> CGImage? {
        guard let pixelData = pixelData() else {
            return nil
        }
        
        let lut = dataSet.paletteColorLUT()
        let renderer = PixelDataRenderer(pixelData: pixelData, paletteColorLUT: lut)
        return renderer.renderFrame(frameIndex)
    }
    
    /// Renders the specified frame to a CGImage with custom window settings
    ///
    /// - Parameters:
    ///   - frameIndex: The frame index to render (default 0)
    ///   - window: Custom window settings for grayscale mapping
    /// - Returns: CGImage if rendering succeeds
    public func renderFrame(_ frameIndex: Int = 0, window: WindowSettings) -> CGImage? {
        guard let pixelData = pixelData() else {
            return nil
        }
        
        let lut = dataSet.paletteColorLUT()
        let renderer = PixelDataRenderer(pixelData: pixelData, paletteColorLUT: lut)
        
        if pixelData.descriptor.photometricInterpretation.isMonochrome {
            return renderer.renderMonochromeFrame(frameIndex, window: window)
        } else if pixelData.descriptor.photometricInterpretation.isPaletteColor {
            return renderer.renderPaletteColorFrame(frameIndex)
        } else {
            return renderer.renderColorFrame(frameIndex)
        }
    }
    
    /// Renders the specified frame using window settings from the DICOM file
    ///
    /// Falls back to automatic windowing if no window settings are present.
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds
    public func renderFrameWithStoredWindow(_ frameIndex: Int = 0) -> CGImage? {
        if let window = windowSettings() {
            return renderFrame(frameIndex, window: window)
        } else {
            return renderFrame(frameIndex)
        }
    }
#endif
    
    // MARK: - Image Dimensions
    
    /// Returns the number of rows (height) in the image
    public var imageRows: Int? {
        dataSet.imageRows
    }
    
    /// Returns the number of columns (width) in the image
    public var imageColumns: Int? {
        dataSet.imageColumns
    }
    
    /// Returns the number of frames in the image
    public var numberOfFrames: Int? {
        dataSet.numberOfFrames
    }
    
    /// Whether this file contains multi-frame image data
    public var isMultiFrame: Bool {
        (numberOfFrames ?? 1) > 1
    }
    
    // MARK: - Photometric Interpretation
    
    /// Returns the photometric interpretation
    public var photometricInterpretation: PhotometricInterpretation? {
        dataSet.photometricInterpretation
    }
    
    /// Whether the image data is monochrome
    public var isMonochrome: Bool {
        photometricInterpretation?.isMonochrome ?? false
    }
    
    /// Whether the image data is color
    public var isColor: Bool {
        photometricInterpretation?.isColor ?? false
    }
    
    /// Whether the image data uses palette color lookup tables
    public var isPaletteColor: Bool {
        photometricInterpretation?.isPaletteColor ?? false
    }
    
    // MARK: - Palette Color Lookup Table
    
    /// Returns the palette color lookup table for PALETTE COLOR images
    ///
    /// - Returns: PaletteColorLUT if present and valid
    public func paletteColorLUT() -> PaletteColorLUT? {
        dataSet.paletteColorLUT()
    }
    
    // MARK: - Pixel Value Range
    
    /// Calculates the actual pixel value range in the specified frame
    ///
    /// - Parameter frameIndex: The frame index (default 0)
    /// - Returns: Tuple of (min, max) values if available
    public func pixelRange(forFrame frameIndex: Int = 0) -> (min: Int, max: Int)? {
        pixelData()?.pixelRange(forFrame: frameIndex)
    }
    
    // MARK: - Rescale Values
    
    /// Returns the rescale intercept value
    public func rescaleIntercept() -> Double {
        dataSet.rescaleIntercept()
    }
    
    /// Returns the rescale slope value
    public func rescaleSlope() -> Double {
        dataSet.rescaleSlope()
    }
    
    /// Applies the rescale transformation to a pixel value
    ///
    /// OutputUnits = Rescale Slope * StoredValue + Rescale Intercept
    ///
    /// - Parameter storedValue: The stored pixel value
    /// - Returns: The rescaled value in output units
    public func rescale(_ storedValue: Double) -> Double {
        dataSet.rescale(storedValue)
    }
}
