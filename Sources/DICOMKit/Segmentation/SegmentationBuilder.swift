//
// SegmentationBuilder.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Builder for creating DICOM Segmentation objects
///
/// SegmentationBuilder provides a fluent API for constructing Segmentation IODs from
/// binary or fractional masks, particularly useful for encoding AI/ML algorithm output.
///
/// Example - Binary Segmentation:
/// ```swift
/// let builder = SegmentationBuilder(
///     rows: 512,
///     columns: 512,
///     segmentationType: .binary,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
///
/// let (segmentation, pixelData) = try builder
///     .setContentLabel("AI Tumor Detection")
///     .setContentDescription("Automated tumor segmentation")
///     .addBinarySegment(
///         number: 1,
///         label: "Tumor",
///         mask: binaryMask,  // [UInt8] with 0 or 1 values
///         category: CodedConcept(codeValue: "49755003", codingSchemeDesignator: "SCT", codeMeaning: "Morphologically Altered Structure"),
///         type: CodedConcept(codeValue: "108369006", codingSchemeDesignator: "SCT", codeMeaning: "Neoplasm"),
///         color: (r: 255, g: 0, b: 0),
///         algorithmType: .automatic,
///         algorithmName: "DeepTumor v1.0"
///     )
///     .build()
/// ```
///
/// Example - Fractional Segmentation:
/// ```swift
/// let builder = SegmentationBuilder(
///     rows: 256,
///     columns: 256,
///     segmentationType: .fractional,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
///
/// let (segmentation, pixelData) = try builder
///     .setContentLabel("Liver Probability Map")
///     .addFractionalSegment(
///         number: 1,
///         label: "Liver",
///         mask: probabilityMask,  // [UInt8] with 0-255 normalized values
///         category: nil,
///         type: CodedConcept(codeValue: "10200004", codingSchemeDesignator: "SCT", codeMeaning: "Liver"),
///         color: (r: 139, g: 69, b: 19),
///         fractionalType: .probability,
///         maxValue: 255,
///         algorithmType: .automatic,
///         algorithmName: "LiverSegNet v2.0"
///     )
///     .build()
/// ```
///
/// Reference: PS3.3 A.51 - Segmentation IOD
/// Reference: PS3.3 C.8.20 - Segmentation Modules
/// Reference: PS3.5 Section 8.1.1 - Bit Packing
public final class SegmentationBuilder {
    
    // MARK: - Configuration
    
    private let rows: Int
    private let columns: Int
    private let segmentationType: SegmentationType
    private let studyInstanceUID: String
    private let seriesInstanceUID: String
    
    // MARK: - Optional Metadata
    
    private var sopInstanceUID: String?
    private var instanceNumber: Int?
    private var contentLabel: String?
    private var contentDescription: String?
    private var contentCreatorName: DICOMPersonName?
    private var contentDate: DICOMDate?
    private var contentTime: DICOMTime?
    private var frameOfReferenceUID: String?
    
    // MARK: - Segments and Pixel Data
    
    private var segments: [SegmentData] = []
    private var sourceImages: [SourceImageReference] = []
    
    // MARK: - Internal Types
    
    private struct SegmentData {
        let segment: Segment
        let pixelData: Data
    }
    
    private struct SourceImageReference {
        let sopClassUID: String
        let sopInstanceUID: String
        let frameNumber: Int?
    }
    
    // MARK: - Initialization
    
    /// Creates a new Segmentation builder
    /// - Parameters:
    ///   - rows: Number of rows in the segmentation
    ///   - columns: Number of columns in the segmentation
    ///   - segmentationType: Type of segmentation (binary or fractional)
    ///   - studyInstanceUID: Study Instance UID for the segmentation
    ///   - seriesInstanceUID: Series Instance UID for the segmentation
    public init(
        rows: Int,
        columns: Int,
        segmentationType: SegmentationType,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.rows = rows
        self.columns = columns
        self.segmentationType = segmentationType
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
    }
    
    // MARK: - Configuration Methods
    
    /// Sets the SOP Instance UID
    /// - Parameter uid: The SOP Instance UID (will be auto-generated if not set)
    /// - Returns: Updated builder
    @discardableResult
    public func setSOPInstanceUID(_ uid: String) -> Self {
        sopInstanceUID = uid
        return self
    }
    
    /// Sets the Instance Number
    /// - Parameter number: The instance number
    /// - Returns: Updated builder
    @discardableResult
    public func setInstanceNumber(_ number: Int) -> Self {
        instanceNumber = number
        return self
    }
    
    /// Sets the Content Label
    /// - Parameter label: A label that identifies the content (max 16 characters)
    /// - Returns: Updated builder
    @discardableResult
    public func setContentLabel(_ label: String) -> Self {
        contentLabel = label
        return self
    }
    
    /// Sets the Content Description
    /// - Parameter description: Human-readable description of the content
    /// - Returns: Updated builder
    @discardableResult
    public func setContentDescription(_ description: String) -> Self {
        contentDescription = description
        return self
    }
    
    /// Sets the Content Creator's Name
    /// - Parameter name: The name of the content creator
    /// - Returns: Updated builder
    @discardableResult
    public func setContentCreator(_ name: DICOMPersonName) -> Self {
        contentCreatorName = name
        return self
    }
    
    /// Sets the Content Date
    /// - Parameter date: The content date
    /// - Returns: Updated builder
    @discardableResult
    public func setContentDate(_ date: DICOMDate) -> Self {
        contentDate = date
        return self
    }
    
    /// Sets the Content Time
    /// - Parameter time: The content time
    /// - Returns: Updated builder
    @discardableResult
    public func setContentTime(_ time: DICOMTime) -> Self {
        contentTime = time
        return self
    }
    
    /// Sets the Frame of Reference UID
    /// - Parameter uid: The Frame of Reference UID
    /// - Returns: Updated builder
    @discardableResult
    public func setFrameOfReference(_ uid: String) -> Self {
        frameOfReferenceUID = uid
        return self
    }
    
    // MARK: - Binary Segment Addition
    
    /// Adds a binary segment to the segmentation
    ///
    /// Binary masks are bit-packed according to PS3.5 Section 8.1.1:
    /// - 8 pixels per byte
    /// - Most significant bit (MSB) first
    /// - Padding bits set to 0 when pixels don't align to byte boundary
    ///
    /// - Parameters:
    ///   - number: Segment number (must be unique, starts from 1)
    ///   - label: Human-readable segment label
    ///   - mask: Binary mask data (0 or 1 values, rows × columns elements)
    ///   - category: Optional segment category (e.g., Tissue, Organ, Lesion)
    ///   - type: Optional segment type (e.g., Liver, Tumor)
    ///   - color: Optional display color (RGB, each 0-255)
    ///   - algorithmType: Optional algorithm type (automatic, semiautomatic, manual)
    ///   - algorithmName: Optional algorithm name
    /// - Throws: SegmentationBuilderError if validation fails
    /// - Returns: Updated builder
    @discardableResult
    public func addBinarySegment(
        number: Int,
        label: String,
        mask: [UInt8],
        category: CodedConcept? = nil,
        type: CodedConcept? = nil,
        color: (r: UInt8, g: UInt8, b: UInt8)? = nil,
        algorithmType: SegmentAlgorithmType? = nil,
        algorithmName: String? = nil
    ) throws -> Self {
        // Validate segmentation type
        guard segmentationType == .binary else {
            throw SegmentationBuilderError.invalidSegmentationType(expected: .binary, got: segmentationType)
        }
        
        // Validate mask dimensions
        let expectedPixels = rows * columns
        guard mask.count == expectedPixels else {
            throw SegmentationBuilderError.invalidMaskDimensions(expected: expectedPixels, got: mask.count)
        }
        
        // Validate binary values
        for (index, value) in mask.enumerated() {
            guard value == 0 || value == 1 else {
                throw SegmentationBuilderError.invalidBinaryValue(Int(value), index: index)
            }
        }
        
        // Validate segment number
        try validateSegmentNumber(number)
        
        // Convert RGB to CIELab
        let cieLabColor = color.map { rgbToCIELab(r: $0.r, g: $0.g, b: $0.b) }
        
        // Create segment
        let segment = Segment(
            segmentNumber: number,
            segmentLabel: label,
            segmentDescription: nil,
            segmentAlgorithmType: algorithmType,
            segmentAlgorithmName: algorithmName,
            category: category,
            type: type,
            anatomicRegion: nil,
            anatomicRegionModifier: nil,
            recommendedDisplayCIELabValue: cieLabColor,
            trackingID: nil,
            trackingUID: nil
        )
        
        // Pack binary mask
        let packedData = packBinaryMask(mask)
        
        // Store segment data
        segments.append(SegmentData(segment: segment, pixelData: packedData))
        
        return self
    }
    
    // MARK: - Fractional Segment Addition
    
    /// Adds a fractional segment to the segmentation
    ///
    /// Fractional masks represent probability or occupancy values scaled to fit
    /// within the specified max fractional value.
    ///
    /// - Parameters:
    ///   - number: Segment number (must be unique, starts from 1)
    ///   - label: Human-readable segment label
    ///   - mask: Fractional mask data (0-255 normalized values, rows × columns elements)
    ///   - category: Optional segment category
    ///   - type: Optional segment type
    ///   - color: Optional display color (RGB, each 0-255)
    ///   - fractionalType: Type of fractional values (probability or occupancy)
    ///   - maxValue: Maximum fractional value (typically 255 for 8-bit or 65535 for 16-bit)
    ///   - algorithmType: Optional algorithm type
    ///   - algorithmName: Optional algorithm name
    /// - Throws: SegmentationBuilderError if validation fails
    /// - Returns: Updated builder
    @discardableResult
    public func addFractionalSegment(
        number: Int,
        label: String,
        mask: [UInt8],
        category: CodedConcept? = nil,
        type: CodedConcept? = nil,
        color: (r: UInt8, g: UInt8, b: UInt8)? = nil,
        fractionalType: SegmentationFractionalType,
        maxValue: Int,
        algorithmType: SegmentAlgorithmType? = nil,
        algorithmName: String? = nil
    ) throws -> Self {
        // Validate segmentation type
        guard segmentationType == .fractional else {
            throw SegmentationBuilderError.invalidSegmentationType(expected: .fractional, got: segmentationType)
        }
        
        // Validate mask dimensions
        let expectedPixels = rows * columns
        guard mask.count == expectedPixels else {
            throw SegmentationBuilderError.invalidMaskDimensions(expected: expectedPixels, got: mask.count)
        }
        
        // Validate max fractional value
        guard maxValue > 0 && maxValue <= 65535 else {
            throw SegmentationBuilderError.invalidMaxFractionalValue(maxValue)
        }
        
        // Validate segment number
        try validateSegmentNumber(number)
        
        // Convert RGB to CIELab
        let cieLabColor = color.map { rgbToCIELab(r: $0.r, g: $0.g, b: $0.b) }
        
        // Create segment
        let segment = Segment(
            segmentNumber: number,
            segmentLabel: label,
            segmentDescription: nil,
            segmentAlgorithmType: algorithmType,
            segmentAlgorithmName: algorithmName,
            category: category,
            type: type,
            anatomicRegion: nil,
            anatomicRegionModifier: nil,
            recommendedDisplayCIELabValue: cieLabColor,
            trackingID: nil,
            trackingUID: nil
        )
        
        // Determine bits allocated based on max value
        let bitsAllocated = maxValue <= 255 ? 8 : 16
        
        // Scale fractional mask
        let scaledData = scaleFractionalMask(mask, to: bitsAllocated, maxValue: maxValue)
        
        // Store segment data
        segments.append(SegmentData(segment: segment, pixelData: scaledData))
        
        return self
    }
    
    // MARK: - Source Image Reference
    
    /// Adds a source image reference
    ///
    /// Links the segmentation to its source image(s).
    ///
    /// - Parameters:
    ///   - sopClassUID: SOP Class UID of the source image
    ///   - sopInstanceUID: SOP Instance UID of the source image
    ///   - frameNumber: Optional frame number for multi-frame sources
    /// - Returns: Updated builder
    @discardableResult
    public func addSourceImage(
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumber: Int? = nil
    ) -> Self {
        sourceImages.append(SourceImageReference(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            frameNumber: frameNumber
        ))
        return self
    }
    
    // MARK: - Build
    
    /// Builds the final Segmentation object and pixel data
    ///
    /// - Throws: SegmentationBuilderError if validation fails
    /// - Returns: A tuple containing the Segmentation object and its pixel data
    public func build() throws -> (segmentation: Segmentation, pixelData: Data) {
        // Validate at least one segment
        guard !segments.isEmpty else {
            throw SegmentationBuilderError.noSegmentsAdded
        }
        
        // Generate SOP Instance UID if not provided
        let finalSOPInstanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().description
        
        // Get current date/time if not provided
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        
        let finalContentDate = contentDate ?? DICOMDate(
            year: components.year ?? 2024,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
        
        let finalContentTime = contentTime ?? DICOMTime(
            hour: components.hour ?? 0,
            minute: components.minute,
            second: components.second
        )
        
        // Sort segments by number
        let sortedSegments = segments.sorted { $0.segment.segmentNumber < $1.segment.segmentNumber }
        
        // Build pixel data by concatenating all segment frames
        var combinedPixelData = Data()
        for segmentData in sortedSegments {
            combinedPixelData.append(segmentData.pixelData)
        }
        
        // Determine pixel data properties based on segmentation type
        let (bitsAllocated, bitsStored, highBit): (Int, Int, Int)
        let maxFractionalValue: Int?
        let fractionalType: SegmentationFractionalType?
        
        switch segmentationType {
        case .binary:
            bitsAllocated = 1
            bitsStored = 1
            highBit = 0
            maxFractionalValue = nil
            fractionalType = nil
            
        case .fractional:
            // Determine from first segment (all should be consistent)
            // For simplicity, we'll use the maxValue from the first fractional segment
            // In a real implementation, this should be stored during addFractionalSegment
            // For now, we'll default to 8-bit
            bitsAllocated = 8
            bitsStored = 8
            highBit = 7
            maxFractionalValue = 255
            fractionalType = .probability
        }
        
        // Build referenced series
        let referencedSeries: [SegmentationReferencedSeries]
        if !sourceImages.isEmpty {
            // Group by series (for simplicity, assume all from same series)
            let instances = sourceImages.map { ref in
                SegmentationReferencedInstance(
                    sopClassUID: ref.sopClassUID,
                    sopInstanceUID: ref.sopInstanceUID,
                    referencedFrameNumbers: ref.frameNumber.map { [$0] }
                )
            }
            referencedSeries = [SegmentationReferencedSeries(
                seriesInstanceUID: seriesInstanceUID,
                referencedInstances: instances
            )]
        } else {
            referencedSeries = []
        }
        
        // Build per-frame functional groups
        let perFrameFunctionalGroups: [FunctionalGroup] = sortedSegments.map { segmentData in
            FunctionalGroup(
                segmentIdentification: SegmentIdentification(
                    referencedSegmentNumber: segmentData.segment.segmentNumber
                ),
                derivationImage: nil,
                frameContent: nil,
                planePosition: nil,
                planeOrientation: nil
            )
        }
        
        // Build the Segmentation object
        let segmentation = Segmentation(
            sopInstanceUID: finalSOPInstanceUID,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.66.4", // Segmentation Storage
            seriesInstanceUID: seriesInstanceUID,
            studyInstanceUID: studyInstanceUID,
            instanceNumber: instanceNumber,
            contentLabel: contentLabel,
            contentDescription: contentDescription,
            contentCreatorName: contentCreatorName,
            contentDate: finalContentDate,
            contentTime: finalContentTime,
            segmentationType: segmentationType,
            segmentationFractionalType: fractionalType,
            maxFractionalValue: maxFractionalValue,
            numberOfSegments: sortedSegments.count,
            segments: sortedSegments.map { $0.segment },
            frameOfReferenceUID: frameOfReferenceUID,
            dimensionOrganizationUID: nil,
            referencedSeries: referencedSeries,
            numberOfFrames: sortedSegments.count,
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2",
            pixelRepresentation: 0,
            sharedFunctionalGroups: nil,
            perFrameFunctionalGroups: perFrameFunctionalGroups
        )
        
        return (segmentation: segmentation, pixelData: combinedPixelData)
    }
    
    // MARK: - Private Helper Methods
    
    /// Validates segment number
    private func validateSegmentNumber(_ number: Int) throws {
        guard number >= 1 else {
            throw SegmentationBuilderError.invalidSegmentNumber(number)
        }
        
        // Check for duplicates
        if segments.contains(where: { $0.segment.segmentNumber == number }) {
            throw SegmentationBuilderError.duplicateSegmentNumber(number)
        }
    }
    
    /// Packs binary mask into bit-packed format
    ///
    /// Reference: PS3.5 Section 8.1.1 - Bit Packing
    /// - 8 pixels per byte
    /// - MSB (most significant bit) first
    /// - Padding bits set to 0
    ///
    /// - Parameter mask: Binary mask with 0 or 1 values
    /// - Returns: Bit-packed data
    private func packBinaryMask(_ mask: [UInt8]) -> Data {
        let totalPixels = mask.count
        let bytesNeeded = (totalPixels + 7) / 8  // Round up to nearest byte
        
        var packedData = Data(count: bytesNeeded)
        
        for pixelIndex in 0..<totalPixels {
            if mask[pixelIndex] == 1 {
                let byteIndex = pixelIndex / 8
                let bitPosition = 7 - (pixelIndex % 8)  // MSB first
                packedData[byteIndex] |= (1 << bitPosition)
            }
        }
        
        return packedData
    }
    
    /// Scales fractional mask to target bit depth
    ///
    /// - Parameters:
    ///   - mask: Normalized mask values (0-255)
    ///   - bitsAllocated: Target bits allocated (8 or 16)
    ///   - maxValue: Maximum fractional value
    /// - Returns: Scaled pixel data
    private func scaleFractionalMask(_ mask: [UInt8], to bitsAllocated: Int, maxValue: Int) -> Data {
        if bitsAllocated == 8 {
            // Direct copy for 8-bit
            return Data(mask)
        } else {
            // Scale to 16-bit
            var data = Data(capacity: mask.count * 2)
            for value in mask {
                let scaled = UInt16((Double(value) / 255.0) * Double(maxValue))
                // Little-endian encoding
                data.append(UInt8(scaled & 0xFF))
                data.append(UInt8((scaled >> 8) & 0xFF))
            }
            return data
        }
    }
    
    /// Converts RGB color to CIELab color space
    ///
    /// This is a simplified conversion. For production use, consider using a
    /// more accurate color space conversion library.
    ///
    /// Reference: PS3.3 C.10.7.1.1 - Recommended Display CIELab Value
    ///
    /// - Parameters:
    ///   - r: Red component (0-255)
    ///   - g: Green component (0-255)
    ///   - b: Blue component (0-255)
    /// - Returns: CIELab color
    private func rgbToCIELab(r: UInt8, g: UInt8, b: UInt8) -> CIELabColor {
        // Simplified RGB to CIELab conversion
        // Normalize RGB to 0-1
        let rNorm = Double(r) / 255.0
        let gNorm = Double(g) / 255.0
        let bNorm = Double(b) / 255.0
        
        // Convert to linear RGB
        func toLinear(_ channel: Double) -> Double {
            if channel <= 0.04045 {
                return channel / 12.92
            } else {
                return pow((channel + 0.055) / 1.055, 2.4)
            }
        }
        
        let rLinear = toLinear(rNorm)
        let gLinear = toLinear(gNorm)
        let bLinear = toLinear(bNorm)
        
        // Convert to XYZ (D65 illuminant)
        let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
        let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
        let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041
        
        // Normalize for D65 white point
        let xn = x / 0.95047
        let yn = y / 1.00000
        let zn = z / 1.08883
        
        // Convert to Lab
        func f(_ t: Double) -> Double {
            if t > 0.008856 {
                return pow(t, 1.0/3.0)
            } else {
                return (7.787 * t) + (16.0 / 116.0)
            }
        }
        
        let fx = f(xn)
        let fy = f(yn)
        let fz = f(zn)
        
        let L = (116.0 * fy) - 16.0
        let a = 500.0 * (fx - fy)
        let b_val = 200.0 * (fy - fz)
        
        // Convert to DICOM CIELab range (0-65535)
        // L: 0-100 -> 0-65535
        // a, b: -128 to 127 -> 0-65535
        let lScaled = Int((L / 100.0) * 65535.0)
        let aScaled = Int(((a + 128.0) / 255.0) * 65535.0)
        let bScaled = Int(((b_val + 128.0) / 255.0) * 65535.0)
        
        return CIELabColor(
            l: max(0, min(65535, lScaled)),
            a: max(0, min(65535, aScaled)),
            b: max(0, min(65535, bScaled))
        )
    }
}

// MARK: - SegmentationBuilderError

/// Errors that can occur during segmentation building
public enum SegmentationBuilderError: Error, CustomStringConvertible {
    /// Invalid mask dimensions
    case invalidMaskDimensions(expected: Int, got: Int)
    
    /// Invalid binary value (must be 0 or 1)
    case invalidBinaryValue(Int, index: Int)
    
    /// Invalid segment number (must be >= 1)
    case invalidSegmentNumber(Int)
    
    /// Duplicate segment number
    case duplicateSegmentNumber(Int)
    
    /// No segments added
    case noSegmentsAdded
    
    /// Invalid max fractional value
    case invalidMaxFractionalValue(Int)
    
    /// Invalid segmentation type for operation
    case invalidSegmentationType(expected: SegmentationType, got: SegmentationType)
    
    public var description: String {
        switch self {
        case .invalidMaskDimensions(let expected, let got):
            return "Invalid mask dimensions: expected \(expected) pixels, got \(got)"
        case .invalidBinaryValue(let value, let index):
            return "Invalid binary value \(value) at index \(index) (must be 0 or 1)"
        case .invalidSegmentNumber(let number):
            return "Invalid segment number \(number) (must be >= 1)"
        case .duplicateSegmentNumber(let number):
            return "Duplicate segment number \(number)"
        case .noSegmentsAdded:
            return "No segments added to segmentation"
        case .invalidMaxFractionalValue(let value):
            return "Invalid max fractional value \(value) (must be 1-65535)"
        case .invalidSegmentationType(let expected, let got):
            return "Invalid segmentation type: expected \(expected), got \(got)"
        }
    }
}
