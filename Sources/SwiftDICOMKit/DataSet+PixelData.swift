import Foundation
import DICOMCore

/// DataSet extensions for pixel data access
///
/// Provides convenient methods to extract pixel data and related attributes
/// from a DICOM data set.
/// Reference: DICOM PS3.3 C.7.6.3 - Image Pixel Module
extension DataSet {
    // MARK: - Pixel Data Descriptor
    
    /// Creates a PixelDataDescriptor from the data set's image pixel attributes
    ///
    /// Extracts all necessary attributes to describe the pixel data format.
    /// Returns nil if required attributes are missing.
    ///
    /// - Returns: PixelDataDescriptor if all required attributes are present
    public func pixelDataDescriptor() -> PixelDataDescriptor? {
        // Required attributes
        guard let rows = uint16(for: .rows),
              let columns = uint16(for: .columns),
              let bitsAllocated = uint16(for: .bitsAllocated),
              let bitsStored = uint16(for: .bitsStored),
              let highBit = uint16(for: .highBit),
              let pixelRepresentation = uint16(for: .pixelRepresentation) else {
            return nil
        }
        
        // Photometric Interpretation (required for image data)
        let photometricString = string(for: .photometricInterpretation) ?? "MONOCHROME2"
        guard let photometricInterpretation = PhotometricInterpretation.parse(photometricString) else {
            return nil
        }
        
        // Optional attributes with defaults
        let samplesPerPixel = uint16(for: .samplesPerPixel) ?? 1
        let planarConfiguration = uint16(for: .planarConfiguration) ?? 0
        
        // Number of frames (default 1 for single-frame images)
        let numberOfFrames: Int
        if let frameString = string(for: .numberOfFrames),
           let frames = Int(frameString.trimmingCharacters(in: .whitespaces)) {
            numberOfFrames = frames
        } else {
            numberOfFrames = 1
        }
        
        return PixelDataDescriptor(
            rows: Int(rows),
            columns: Int(columns),
            numberOfFrames: numberOfFrames,
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            highBit: Int(highBit),
            isSigned: pixelRepresentation != 0,
            samplesPerPixel: Int(samplesPerPixel),
            photometricInterpretation: photometricInterpretation,
            planarConfiguration: Int(planarConfiguration)
        )
    }
    
    // MARK: - Pixel Data Extraction
    
    /// Extracts pixel data from the data set
    ///
    /// Returns the uncompressed pixel data along with its descriptor.
    /// Returns nil if pixel data is not present or cannot be extracted.
    ///
    /// - Returns: PixelData if extraction succeeds
    public func pixelData() -> PixelData? {
        guard let descriptor = pixelDataDescriptor() else {
            return nil
        }
        
        // Get the pixel data element
        guard let element = self[.pixelData],
              !element.valueData.isEmpty else {
            return nil
        }
        
        return PixelData(data: element.valueData, descriptor: descriptor)
    }
    
    // MARK: - Window Settings
    
    /// Returns the first window settings from the data set
    ///
    /// Extracts Window Center and Window Width values to create WindowSettings.
    /// Returns nil if window values are not present.
    ///
    /// - Returns: WindowSettings if present
    public func windowSettings() -> WindowSettings? {
        guard let centerDS = decimalString(for: .windowCenter),
              let widthDS = decimalString(for: .windowWidth) else {
            return nil
        }
        
        let explanation = string(for: .windowCenterWidthExplanation)
        let functionString = string(for: .voiLUTFunction)
        let function = VOILUTFunction.parse(functionString)
        
        return WindowSettings(
            center: centerDS.value,
            width: widthDS.value,
            explanation: explanation,
            function: function
        )
    }
    
    /// Returns all window settings from the data set
    ///
    /// DICOM allows multiple window center/width pairs.
    /// Returns an empty array if no window settings are present.
    ///
    /// - Returns: Array of WindowSettings
    public func allWindowSettings() -> [WindowSettings] {
        guard let centers = decimalStrings(for: .windowCenter),
              let widths = decimalStrings(for: .windowWidth),
              !centers.isEmpty, !widths.isEmpty else {
            return []
        }
        
        // Get explanations (may be fewer than windows)
        let explanations = strings(for: .windowCenterWidthExplanation) ?? []
        let functionString = string(for: .voiLUTFunction)
        let function = VOILUTFunction.parse(functionString)
        
        var settings: [WindowSettings] = []
        let count = Swift.min(centers.count, widths.count)
        
        for i in 0..<count {
            let explanation = i < explanations.count ? explanations[i] : nil
            settings.append(WindowSettings(
                center: centers[i].value,
                width: widths[i].value,
                explanation: explanation,
                function: function
            ))
        }
        
        return settings
    }
    
    // MARK: - Rescale Values
    
    /// Returns the rescale intercept value
    ///
    /// Used to convert stored pixel values to output units.
    /// Reference: PS3.3 C.11.1.1.2 - Rescale Intercept
    ///
    /// - Returns: Rescale intercept (default 0.0 if not present)
    public func rescaleIntercept() -> Double {
        decimalString(for: .rescaleIntercept)?.value ?? 0.0
    }
    
    /// Returns the rescale slope value
    ///
    /// Used to convert stored pixel values to output units.
    /// Reference: PS3.3 C.11.1.1.2 - Rescale Slope
    ///
    /// - Returns: Rescale slope (default 1.0 if not present)
    public func rescaleSlope() -> Double {
        decimalString(for: .rescaleSlope)?.value ?? 1.0
    }
    
    /// Applies the rescale transformation to a pixel value
    ///
    /// OutputUnits = Rescale Slope * StoredValue + Rescale Intercept
    /// Reference: PS3.3 C.11.1.1.2
    ///
    /// - Parameter storedValue: The stored pixel value
    /// - Returns: The rescaled value in output units (e.g., Hounsfield Units for CT)
    public func rescale(_ storedValue: Double) -> Double {
        rescaleSlope() * storedValue + rescaleIntercept()
    }
    
    // MARK: - Image Dimensions
    
    /// Returns the number of rows (height) in the image
    public var imageRows: Int? {
        uint16(for: .rows).map { Int($0) }
    }
    
    /// Returns the number of columns (width) in the image
    public var imageColumns: Int? {
        uint16(for: .columns).map { Int($0) }
    }
    
    /// Returns the number of frames in the image
    public var numberOfFrames: Int? {
        if let frameString = string(for: .numberOfFrames),
           let frames = Int(frameString.trimmingCharacters(in: .whitespaces)) {
            return frames
        }
        return nil
    }
    
    // MARK: - Photometric Interpretation
    
    /// Returns the photometric interpretation
    public var photometricInterpretation: PhotometricInterpretation? {
        guard let value = string(for: .photometricInterpretation) else {
            return nil
        }
        return PhotometricInterpretation.parse(value)
    }
}
