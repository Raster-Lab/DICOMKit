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
        // First check if we have a valid descriptor (throws detailed error if missing)
        let descriptor: PixelDataDescriptor
        do {
            descriptor = try dataSet.tryPixelDataDescriptor()
        } catch let error as PixelDataError {
            // If missing attributes and this is a non-image SOP class, provide enhanced error
            if case .missingAttributes(let attributes) = error {
                let sopUID = sopClassUID
                let isNonImage = sopUID.map { Self.isNonImageSOPClass($0) } ?? false
                
                if isNonImage {
                    // This is a known non-image SOP class - provide context
                    let sopName = sopUID.flatMap { UIDDictionary.lookup(uid: $0)?.name }
                    throw PixelDataError.nonImageSOPClass(
                        missingAttributes: attributes,
                        sopClassUID: sopUID,
                        sopClassName: sopName
                    )
                }
            }
            throw error
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
    
    /// Creates a PixelDataDescriptor from the file's image pixel attributes,
    /// throwing detailed errors if required attributes are missing.
    ///
    /// - Returns: PixelDataDescriptor if all required attributes are present
    /// - Throws: `PixelDataError.missingAttributes` with the list of missing attribute names
    public func tryPixelDataDescriptor() throws -> PixelDataDescriptor {
        try dataSet.tryPixelDataDescriptor()
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
    
    /// Renders the specified frame to a CGImage, throwing detailed errors on failure
    ///
    /// Uses automatic windowing based on pixel value range for monochrome images.
    /// For palette color images, uses the palette lookup table from the DICOM file.
    ///
    /// This method provides detailed error information when pixel data extraction fails,
    /// which is useful for CT and other modality-specific images where understanding
    /// the failure reason is important.
    ///
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds
    /// - Throws: `PixelDataError` with detailed information about the failure
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     let image = try dicomFile.tryRenderFrame(0)
    ///     // Use rendered image...
    /// } catch let error as PixelDataError {
    ///     print("Failed to render: \(error.description)")
    /// }
    /// ```
    public func tryRenderFrame(_ frameIndex: Int = 0) throws -> CGImage? {
        let pixelData = try tryPixelData()
        
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
        
        return renderFrameWithWindow(pixelData: pixelData, frameIndex: frameIndex, window: window)
    }
    
    /// Renders the specified frame to a CGImage with custom window settings,
    /// throwing detailed errors on failure
    ///
    /// - Parameters:
    ///   - frameIndex: The frame index to render (default 0)
    ///   - window: Custom window settings for grayscale mapping
    /// - Returns: CGImage if rendering succeeds
    /// - Throws: `PixelDataError` with detailed information about the failure
    public func tryRenderFrame(_ frameIndex: Int = 0, window: WindowSettings) throws -> CGImage? {
        let pixelData = try tryPixelData()
        
        return renderFrameWithWindow(pixelData: pixelData, frameIndex: frameIndex, window: window)
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
    
    /// Renders the specified frame using window settings from the DICOM file,
    /// throwing detailed errors on failure
    ///
    /// Falls back to automatic windowing if no window settings are present.
    /// This method provides detailed error information when pixel data extraction fails.
    ///
    /// - Parameter frameIndex: The frame index to render (default 0)
    /// - Returns: CGImage if rendering succeeds
    /// - Throws: `PixelDataError` with detailed information about the failure
    public func tryRenderFrameWithStoredWindow(_ frameIndex: Int = 0) throws -> CGImage? {
        if let window = windowSettings() {
            return try tryRenderFrame(frameIndex, window: window)
        } else {
            return try tryRenderFrame(frameIndex)
        }
    }
    
    // MARK: - Private Rendering Helpers
    
    /// Internal helper to render a frame with window settings using provided pixel data
    private func renderFrameWithWindow(pixelData: PixelData, frameIndex: Int, window: WindowSettings) -> CGImage? {
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
    
    // MARK: - SOP Class Helpers
    
    /// Known non-image SOP Class UIDs that do not contain pixel data
    ///
    /// These SOP classes represent document-based DICOM objects such as
    /// Structured Reports, Presentation States, and other non-image data.
    private static let nonImageSOPClasses: Set<String> = [
        // Structured Report SOP Classes
        "1.2.840.10008.5.1.4.1.1.88.11",    // Basic Text SR Storage
        "1.2.840.10008.5.1.4.1.1.88.22",    // Enhanced SR Storage
        "1.2.840.10008.5.1.4.1.1.88.33",    // Comprehensive SR Storage
        "1.2.840.10008.5.1.4.1.1.88.34",    // Comprehensive 3D SR Storage
        "1.2.840.10008.5.1.4.1.1.88.35",    // Extensible SR Storage
        "1.2.840.10008.5.1.4.1.1.88.40",    // Procedure Log Storage
        "1.2.840.10008.5.1.4.1.1.88.50",    // Mammography CAD SR Storage
        "1.2.840.10008.5.1.4.1.1.88.59",    // Key Object Selection Document Storage
        "1.2.840.10008.5.1.4.1.1.88.65",    // Chest CAD SR Storage
        "1.2.840.10008.5.1.4.1.1.88.67",    // X-Ray Radiation Dose SR Storage
        "1.2.840.10008.5.1.4.1.1.88.68",    // Radiopharmaceutical Radiation Dose SR Storage
        "1.2.840.10008.5.1.4.1.1.88.69",    // Colon CAD SR Storage
        "1.2.840.10008.5.1.4.1.1.88.70",    // Implantation Plan SR Storage
        "1.2.840.10008.5.1.4.1.1.88.71",    // Acquisition Context SR Storage
        "1.2.840.10008.5.1.4.1.1.88.72",    // Simplified Adult Echo SR Storage
        "1.2.840.10008.5.1.4.1.1.88.73",    // Patient Radiation Dose SR Storage
        "1.2.840.10008.5.1.4.1.1.88.74",    // Planned Imaging Agent Administration SR Storage
        "1.2.840.10008.5.1.4.1.1.88.75",    // Performed Imaging Agent Administration SR Storage
        "1.2.840.10008.5.1.4.1.1.88.76",    // Enhanced X-Ray Radiation Dose SR Storage
        
        // Presentation State SOP Classes
        "1.2.840.10008.5.1.4.1.1.11.1",     // Grayscale Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.2",     // Color Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.3",     // Pseudo-Color Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.4",     // Blending Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.5",     // XA/XRF Grayscale Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.6",     // Grayscale Planar MPR Volumetric Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.7",     // Compositing Planar MPR Volumetric Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.8",     // Advanced Blending Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.9",     // Volume Rendering Volumetric Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.10",    // Segmented Volume Rendering Volumetric Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.11",    // Multiple Volume Rendering Volumetric Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.12",    // Variable Modality LUT Softcopy Presentation State Storage
        
        // RT Structure and Plan SOP Classes (non-image, no pixel data)
        // Note: RT Dose Storage (481.2) and RT Image Storage (481.1) are NOT included
        // as they contain pixel data
        "1.2.840.10008.5.1.4.1.1.481.3",    // RT Structure Set Storage
        "1.2.840.10008.5.1.4.1.1.481.4",    // RT Beams Treatment Record Storage
        "1.2.840.10008.5.1.4.1.1.481.5",    // RT Plan Storage
        "1.2.840.10008.5.1.4.1.1.481.6",    // RT Brachy Treatment Record Storage
        "1.2.840.10008.5.1.4.1.1.481.7",    // RT Treatment Summary Record Storage
        "1.2.840.10008.5.1.4.1.1.481.8",    // RT Ion Plan Storage
        "1.2.840.10008.5.1.4.1.1.481.9",    // RT Ion Beams Treatment Record Storage
        
        // Waveform SOP Classes
        "1.2.840.10008.5.1.4.1.1.9.1.1",    // 12-lead ECG Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.1.2",    // General ECG Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.1.3",    // Ambulatory ECG Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.2.1",    // Hemodynamic Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.3.1",    // Cardiac Electrophysiology Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.4.1",    // Basic Voice Audio Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.4.2",    // General Audio Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.5.1",    // Arterial Pulse Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.6.1",    // Respiratory Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.6.2",    // Multichannel Respiratory Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.7.1",    // Routine Scalp Electroencephalogram Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.7.2",    // Electromyogram Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.7.3",    // Electrooculogram Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.7.4",    // Sleep Electroencephalogram Waveform Storage
        "1.2.840.10008.5.1.4.1.1.9.8.1",    // Body Position Waveform Storage
        
        // Encapsulated Document SOP Classes
        "1.2.840.10008.5.1.4.1.1.104.1",    // Encapsulated PDF Storage
        "1.2.840.10008.5.1.4.1.1.104.2",    // Encapsulated CDA Storage
        "1.2.840.10008.5.1.4.1.1.104.3",    // Encapsulated STL Storage
        "1.2.840.10008.5.1.4.1.1.104.4",    // Encapsulated OBJ Storage
        "1.2.840.10008.5.1.4.1.1.104.5",    // Encapsulated MTL Storage
        
        // Measurement SOP Classes
        "1.2.840.10008.5.1.4.1.1.78.1",     // Lensometry Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.2",     // Autorefraction Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.3",     // Keratometry Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.4",     // Subjective Refraction Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.5",     // Visual Acuity Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.6",     // Spectacle Prescription Report Storage
        "1.2.840.10008.5.1.4.1.1.78.7",     // Ophthalmic Axial Measurements Storage
        "1.2.840.10008.5.1.4.1.1.78.8",     // Intraocular Lens Calculations Storage
        
        // Other non-image SOP Classes
        "1.2.840.10008.5.1.4.1.1.66",       // Raw Data Storage
        "1.2.840.10008.5.1.4.1.1.66.1",     // Spatial Registration Storage
        "1.2.840.10008.5.1.4.1.1.66.2",     // Spatial Fiducials Storage
        "1.2.840.10008.5.1.4.1.1.66.3",     // Deformable Spatial Registration Storage
        // Note: Segmentation Storage (66.4) contains pixel data for binary/fractional masks
        "1.2.840.10008.5.1.4.1.1.66.5",     // Surface Segmentation Storage
        "1.2.840.10008.5.1.4.1.1.66.6",     // Tractography Results Storage
        "1.2.840.10008.5.1.4.1.1.67",       // Real World Value Mapping Storage
        "1.2.840.10008.5.1.4.1.1.68.1",     // Surface Scan Mesh Storage
        "1.2.840.10008.5.1.4.1.1.68.2",     // Surface Scan Point Cloud Storage
        "1.2.840.10008.5.1.4.1.1.91.1",     // Content Assessment Results Storage
        "1.2.840.10008.5.1.4.1.1.200.1",    // CT Defined Procedure Protocol Storage
        "1.2.840.10008.5.1.4.1.1.200.2",    // CT Performed Procedure Protocol Storage
        "1.2.840.10008.5.1.4.1.1.200.8",    // XA Defined Procedure Protocol Storage
        "1.2.840.10008.5.1.4.1.1.200.9",    // XA Performed Procedure Protocol Storage
    ]
    
    /// Checks if a SOP Class UID represents a non-image DICOM object
    ///
    /// Non-image SOP classes include Structured Reports, Presentation States,
    /// Waveforms, and other document-based DICOM objects that do not contain pixel data.
    ///
    /// - Parameter sopClassUID: The SOP Class UID to check
    /// - Returns: true if the SOP class is known to be a non-image type
    private static func isNonImageSOPClass(_ sopClassUID: String) -> Bool {
        return nonImageSOPClasses.contains(sopClassUID)
    }
}
