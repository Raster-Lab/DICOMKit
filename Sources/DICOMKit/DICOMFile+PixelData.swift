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
    /// Returns nil if pixel data is not present or cannot be extracted.
    ///
    /// - Returns: PixelData if extraction succeeds
    public func pixelData() -> PixelData? {
        dataSet.pixelData()
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
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds
    public func renderFrame(_ frameIndex: Int = 0) -> CGImage? {
        guard let pixelData = pixelData() else {
            return nil
        }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
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
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        
        if pixelData.descriptor.photometricInterpretation.isMonochrome {
            return renderer.renderMonochromeFrame(frameIndex, window: window)
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
