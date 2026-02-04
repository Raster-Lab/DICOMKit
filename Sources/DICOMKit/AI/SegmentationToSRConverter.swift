/// Segmentation to Structured Report Converter
///
/// Provides utilities for converting DICOM Segmentation (SEG) objects into Structured Report
/// documents. This enables the extraction of measurements and findings from segmentation
/// results and their representation in a standardized SR format.
///
/// Reference: PS3.3 Section A.51 - Segmentation IOD
/// Reference: PS3.3 Section C.8.20 - Segmentation Image Module
/// Reference: PS3.16 TID 1500 - Measurement Report

import Foundation
import DICOMCore

// MARK: - Segmentation Result

/// Represents extracted information from a DICOM Segmentation object
public struct SegmentationResult: Sendable {
    /// Segment information
    public struct Segment: Sendable, Equatable {
        /// Segment number (1-based)
        public let number: Int
        
        /// Segment label/description
        public let label: String
        
        /// Segmented property category
        public let category: CodedConcept?
        
        /// Segmented property type
        public let type: CodedConcept?
        
        /// Optional anatomic region
        public let anatomicRegion: CodedConcept?
        
        /// Tracking identifier (for measurement tracking)
        public let trackingIdentifier: String?
        
        /// Tracking UID (for measurement tracking)
        public let trackingUID: String?
        
        /// Creates a new segment
        public init(
            number: Int,
            label: String,
            category: CodedConcept? = nil,
            type: CodedConcept? = nil,
            anatomicRegion: CodedConcept? = nil,
            trackingIdentifier: String? = nil,
            trackingUID: String? = nil
        ) {
            self.number = number
            self.label = label
            self.category = category
            self.type = type
            self.anatomicRegion = anatomicRegion
            self.trackingIdentifier = trackingIdentifier
            self.trackingUID = trackingUID
        }
    }
    
    /// Measurement extracted from segmentation
    public struct Measurement: Sendable, Equatable {
        /// Segment number this measurement belongs to
        public let segmentNumber: Int
        
        /// Measurement name/concept
        public let concept: CodedConcept
        
        /// Measured value
        public let value: Double
        
        /// Unit of measurement
        public let unit: CodedConcept
        
        /// Optional derivation description
        public let derivation: String?
        
        /// Creates a new measurement
        public init(
            segmentNumber: Int,
            concept: CodedConcept,
            value: Double,
            unit: CodedConcept,
            derivation: String? = nil
        ) {
            self.segmentNumber = segmentNumber
            self.concept = concept
            self.value = value
            self.unit = unit
            self.derivation = derivation
        }
    }
    
    /// Source segmentation SOP Instance UID
    public let sopInstanceUID: String
    
    /// Source segmentation SOP Class UID
    public let sopClassUID: String
    
    /// Referenced image series
    public let referencedSeriesUID: String?
    
    /// Segments in the segmentation
    public let segments: [Segment]
    
    /// Measurements derived from segments
    public let measurements: [Measurement]
    
    /// Creates a new segmentation result
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        referencedSeriesUID: String? = nil,
        segments: [Segment],
        measurements: [Measurement]
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.referencedSeriesUID = referencedSeriesUID
        self.segments = segments
        self.measurements = measurements
    }
}

// MARK: - Converter

/// Converts segmentation results to Structured Report documents
public struct SegmentationToSRConverter: Sendable {
    
    // MARK: - Error Types
    
    /// Errors that can occur during conversion
    public enum ConversionError: Error, Sendable, Equatable {
        /// No segments to convert
        case noSegments
        
        /// Missing required segmentation information
        case missingSegmentationInfo(String)
        
        /// Invalid measurement value
        case invalidMeasurement(String)
        
        /// General conversion error
        case conversionFailed(String)
    }
    
    // MARK: - Configuration
    
    /// Configuration for segmentation SR conversion
    public struct ConversionConfiguration: Sendable {
        /// Patient ID (required)
        public let patientID: String
        
        /// Patient name (optional)
        public let patientName: String?
        
        /// Study Instance UID (required)
        public let studyInstanceUID: String
        
        /// Study date (optional)
        public let studyDate: String?
        
        /// Study time (optional)
        public let studyTime: String?
        
        /// Series Instance UID (optional, will be generated if not provided)
        public let seriesInstanceUID: String?
        
        /// Instance number (optional)
        public let instanceNumber: String?
        
        /// Whether to include image library references
        public let includeImageLibrary: Bool
        
        /// Creates a new conversion configuration
        public init(
            patientID: String,
            patientName: String? = nil,
            studyInstanceUID: String,
            studyDate: String? = nil,
            studyTime: String? = nil,
            seriesInstanceUID: String? = nil,
            instanceNumber: String? = nil,
            includeImageLibrary: Bool = true
        ) {
            self.patientID = patientID
            self.patientName = patientName
            self.studyInstanceUID = studyInstanceUID
            self.studyDate = studyDate
            self.studyTime = studyTime
            self.seriesInstanceUID = seriesInstanceUID
            self.instanceNumber = instanceNumber
            self.includeImageLibrary = includeImageLibrary
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new segmentation to SR converter
    public init() {}
    
    // MARK: - Conversion Methods
    
    /// Converts segmentation result to a Measurement Report SR document (TID 1500)
    ///
    /// Creates a DICOM Measurement Report that includes information about the segments
    /// and their derived measurements. This follows the TID 1500 template structure.
    ///
    /// - Parameters:
    ///   - segmentationResult: The segmentation result to convert
    ///   - configuration: Configuration with patient and study information
    /// - Returns: DICOM DataSet containing the SR document
    /// - Throws: ConversionError if conversion fails
    public func convertToMeasurementReport(
        segmentationResult: SegmentationResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        // Validate segments
        guard !segmentationResult.segments.isEmpty else {
            throw ConversionError.noSegments
        }
        
        var builder = MeasurementReportBuilder()
        
        // Set patient information
        builder = builder.withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Add image library if configured
        if configuration.includeImageLibrary {
            // Add the segmentation object itself as a reference
            builder = builder.addImageReference(
                sopClassUID: segmentationResult.sopClassUID,
                sopInstanceUID: segmentationResult.sopInstanceUID
            )
        }
        
        // Add measurement groups - one per segment
        for segment in segmentationResult.segments {
            // Find measurements for this segment
            let segmentMeasurements = segmentationResult.measurements.filter {
                $0.segmentNumber == segment.number
            }
            
            // Create tracking identifier for this segment
            let trackingID = segment.trackingIdentifier ?? "Segment-\(segment.number)"
            let trackingUID = segment.trackingUID ?? generateUID()
            
            // Get finding site if available
            let findingSite = segment.anatomicRegion ?? segment.type
            
            // Add measurement group
            var groupBuilder = builder.addMeasurementGroup(
                trackingIdentifier: trackingID,
                trackingUID: trackingUID,
                findingSite: findingSite
            )
            
            // Add each measurement
            for measurement in segmentMeasurements {
                groupBuilder = groupBuilder.addMeasurement(
                    concept: measurement.concept,
                    value: measurement.value,
                    unit: measurement.unit
                )
            }
            
            builder = groupBuilder
        }
        
        return try builder.build()
    }
    
    /// Converts segmentation result to an Enhanced SR document
    ///
    /// Creates a more flexible Enhanced SR document with sections for each segment.
    ///
    /// - Parameters:
    ///   - segmentationResult: The segmentation result to convert
    ///   - configuration: Configuration with patient and study information
    /// - Returns: DICOM DataSet containing the SR document
    /// - Throws: ConversionError if conversion fails
    public func convertToEnhancedSR(
        segmentationResult: SegmentationResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        // Validate segments
        guard !segmentationResult.segments.isEmpty else {
            throw ConversionError.noSegments
        }
        
        var builder = EnhancedSRBuilder()
        
        // Set patient information
        builder = builder.withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Add a findings section with information about each segment
        builder = builder.addSection(
            heading: CodedConcept.commonSections.findings,
            content: {
                EnhancedSectionContent.text("Segmentation Analysis Results")
                
                for segment in segmentationResult.segments {
                    // Segment header
                    EnhancedSectionContent.text("Segment \(segment.number): \(segment.label)")
                    
                    // Add segment type if available
                    if let type = segment.type {
                        EnhancedSectionContent.text("Type: \(type.codeMeaning)")
                    }
                    
                    // Add anatomic region if available
                    if let region = segment.anatomicRegion {
                        EnhancedSectionContent.text("Region: \(region.codeMeaning)")
                    }
                    
                    // Find measurements for this segment
                    let segmentMeasurements = segmentationResult.measurements.filter {
                        $0.segmentNumber == segment.number
                    }
                    
                    // Add measurements
                    for measurement in segmentMeasurements {
                        EnhancedSectionContent.measurement(
                            concept: measurement.concept,
                            value: measurement.value,
                            unit: measurement.unit
                        )
                    }
                }
            }
        )
        
        return try builder.build()
    }
    
    // MARK: - Private Helpers
    
    private func generateUID() -> String {
        // Generate a simple UID for tracking purposes
        let timestamp = Date().timeIntervalSince1970
        let random = Int.random(in: 1000...9999)
        return "2.25.\(Int(timestamp * 1000)).\(random)"
    }
}

// MARK: - Common Measurement Concepts

extension CodedConcept {
    /// Common measurement concepts for segmentation analysis
    public enum SegmentationMeasurements {
        /// Volume measurement
        public static var volume: CodedConcept {
            CodedConcept(
                codeValue: "G-D705",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Volume"
            )
        }
        
        /// Area measurement
        public static var area: CodedConcept {
            CodedConcept(
                codeValue: "G-A220",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Area"
            )
        }
        
        /// Maximum diameter
        public static var maximumDiameter: CodedConcept {
            CodedConcept(
                codeValue: "G-A185",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Maximum Diameter"
            )
        }
        
        /// Minimum diameter
        public static var minimumDiameter: CodedConcept {
            CodedConcept(
                codeValue: "G-A186",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Minimum Diameter"
            )
        }
        
        /// Mean intensity
        public static var meanIntensity: CodedConcept {
            CodedConcept(
                codeValue: "C0444504",
                codingSchemeDesignator: "UMLS",
                codeMeaning: "Mean Intensity"
            )
        }
        
        /// Standard deviation
        public static var standardDeviation: CodedConcept {
            CodedConcept(
                codeValue: "R-10047",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Standard Deviation"
            )
        }
    }
}

// MARK: - Common Units

extension CodedConcept {
    /// Common units for segmentation measurements
    public enum SegmentationUnits {
        /// Cubic millimeter (mm³)
        public static var cubicMillimeter: CodedConcept {
            CodedConcept(
                codeValue: "mm3",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Cubic Millimeter"
            )
        }
        
        /// Square millimeter (mm²)
        public static var squareMillimeter: CodedConcept {
            CodedConcept(
                codeValue: "mm2",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Square Millimeter"
            )
        }
        
        /// Millimeter (mm)
        public static var millimeter: CodedConcept {
            CodedConcept(
                codeValue: "mm",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Millimeter"
            )
        }
        
        /// Hounsfield Unit (HU)
        public static var hounsfieldUnit: CodedConcept {
            CodedConcept(
                codeValue: "[hnsf'U]",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Hounsfield Unit"
            )
        }
        
        /// No unit (count, percentage, etc.)
        public static var noUnit: CodedConcept {
            CodedConcept(
                codeValue: "1",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "No Unit"
            )
        }
    }
}
