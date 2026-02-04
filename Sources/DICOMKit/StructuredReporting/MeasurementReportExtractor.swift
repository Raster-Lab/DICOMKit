/// Measurement Report Extraction API
///
/// Provides high-level extraction of TID 1500 Measurement Report data from SR documents.
///
/// Reference: PS3.16 TID 1500 - Measurement Report
/// Reference: PS3.16 TID 1501 - Measurement Group

import Foundation
import DICOMCore

/// Represents an extracted TID 1500 Measurement Report
///
/// Provides structured access to measurement groups, image library entries,
/// and qualitative evaluations from a TID 1500 compliant SR document.
///
/// Example:
/// ```swift
/// let parser = SRDocumentParser()
/// let document = try parser.parse(dataSet: dataSet)
/// let report = try MeasurementReport.extract(from: document)
/// 
/// for group in report.measurementGroups {
///     print("Tracking: \(group.trackingIdentifier)")
///     for measurement in group.measurements {
///         print("  \(measurement.conceptName?.codeMeaning ?? "Measurement"): \(measurement.value)")
///     }
/// }
/// ```
public struct MeasurementReport: Sendable, Equatable {
    
    // MARK: - Document Information
    
    /// The original SR document
    public let document: SRDocument
    
    /// Document title (Concept Name of root container)
    public var documentTitle: CodedConcept? {
        document.documentTitle
    }
    
    /// Procedure reported codes
    public let proceduresReported: [CodedConcept]
    
    /// Language of content
    public let languageOfContent: CodedConcept?
    
    // MARK: - Content Structures
    
    /// Image library entries (TID 1600)
    public let imageLibraryEntries: [ImageReference]
    
    /// Measurement groups (TID 1501)
    public let measurementGroups: [ExtractedMeasurementGroup]
    
    /// Qualitative evaluations
    public let qualitativeEvaluations: [CodedConcept]
    
    // MARK: - Extraction API
    
    /// Extracts a measurement report from an SR document
    /// - Parameter document: The SR document to extract from
    /// - Returns: An extracted measurement report
    /// - Throws: `ExtractionError` if the document is not a valid measurement report
    public static func extract(from document: SRDocument) throws -> MeasurementReport {
        // Validate document type
        guard let docType = document.documentType,
              docType.sopClassUID == SRDocumentType.comprehensiveSR.sopClassUID ||
              docType.sopClassUID == SRDocumentType.comprehensive3DSR.sopClassUID else {
            throw ExtractionError.invalidDocumentType(
                "Document must be Comprehensive SR or Comprehensive 3D SR for TID 1500, got: \(document.sopClassUID)"
            )
        }
        
        // Extract procedures reported
        let proceduresReported = extractProceduresReported(from: document.rootContent)
        
        // Extract language of content
        let languageOfContent = extractLanguageOfContent(from: document.rootContent)
        
        // Extract image library (TID 1600)
        let imageLibraryEntries = extractImageLibrary(from: document.rootContent)
        
        // Extract measurement groups (TID 1501)
        let measurementGroups = try extractMeasurementGroups(from: document.rootContent)
        
        // Extract qualitative evaluations
        let qualitativeEvaluations = extractQualitativeEvaluations(from: document.rootContent)
        
        return MeasurementReport(
            document: document,
            proceduresReported: proceduresReported,
            languageOfContent: languageOfContent,
            imageLibraryEntries: imageLibraryEntries,
            measurementGroups: measurementGroups,
            qualitativeEvaluations: qualitativeEvaluations
        )
    }
    
    // MARK: - Private Extraction Helpers
    
    private static func extractProceduresReported(from container: ContainerContentItem) -> [CodedConcept] {
        var procedures: [CodedConcept] = []
        
        for item in container.contentItems {
            if let codeItem = item.asCode,
               codeItem.conceptName?.codeValue == "121058" { // Procedure Reported
                procedures.append(codeItem.conceptCode)
            }
        }
        
        return procedures
    }
    
    private static func extractLanguageOfContent(from container: ContainerContentItem) -> CodedConcept? {
        for item in container.contentItems {
            if let codeItem = item.asCode,
               codeItem.conceptName?.codeValue == "121049" { // Language of Content Item and Descendants
                return codeItem.conceptCode
            }
        }
        return nil
    }
    
    private static func extractImageLibrary(from container: ContainerContentItem) -> [ImageReference] {
        var entries: [ImageReference] = []
        
        // Find Image Library container (TID 1600)
        for item in container.contentItems {
            if let imageLibContainer = item.asContainer,
               imageLibContainer.conceptName?.codeValue == "111028" { // Image Library
                
                // Extract image references from the library
                for imageItem in imageLibContainer.contentItems {
                    if let imageRef = imageItem.asImage {
                        entries.append(imageRef.imageReference)
                    }
                }
            }
        }
        
        return entries
    }
    
    private static func extractMeasurementGroups(from container: ContainerContentItem) throws -> [ExtractedMeasurementGroup] {
        var groups: [ExtractedMeasurementGroup] = []
        
        // Find Imaging Measurements container
        for item in container.contentItems {
            if let measurementsContainer = item.asContainer,
               measurementsContainer.conceptName?.codeValue == "126010" { // Imaging Measurements
                
                // Each child container is a Measurement Group (TID 1501)
                for groupItem in measurementsContainer.contentItems {
                    if let groupContainer = groupItem.asContainer,
                       groupContainer.conceptName?.codeValue == "125007" { // Measurement Group
                        
                        let group = try extractSingleMeasurementGroup(from: groupContainer)
                        groups.append(group)
                    }
                }
            }
        }
        
        return groups
    }
    
    private static func extractSingleMeasurementGroup(from container: ContainerContentItem) throws -> ExtractedMeasurementGroup {
        var trackingIdentifier: String?
        var trackingUID: String?
        var findingType: CodedConcept?
        var findingSite: CodedConcept?
        var measurements: [Measurement] = []
        var qualitativeEvaluations: [CodedConcept] = []
        
        for item in container.contentItems {
            // Extract tracking identifier
            if let textItem = item.asText,
               textItem.conceptName?.codeValue == "112039" { // Tracking Identifier
                trackingIdentifier = textItem.textValue
            }
            
            // Extract tracking UID
            else if let uidItem = item.asUIDRef,
                    uidItem.conceptName?.codeValue == "112040" { // Tracking Unique Identifier
                trackingUID = uidItem.uidValue
            }
            
            // Extract finding type
            else if let codeItem = item.asCode,
                    codeItem.conceptName?.codeValue == "121071" { // Finding
                findingType = codeItem.conceptCode
            }
            
            // Extract finding site
            else if let codeItem = item.asCode,
                    codeItem.conceptName?.codeValue == "363698007" { // Finding Site
                findingSite = codeItem.conceptCode
            }
            
            // Extract numeric measurements
            else if let numItem = item.asNumeric {
                let measurement = Measurement(from: numItem)
                measurements.append(measurement)
            }
            
            // Extract qualitative evaluations (CODE items)
            else if let codeItem = item.asCode {
                qualitativeEvaluations.append(codeItem.conceptCode)
            }
        }
        
        guard let trackingID = trackingIdentifier else {
            throw ExtractionError.missingRequiredElement("Tracking Identifier is required for Measurement Group")
        }
        
        return ExtractedMeasurementGroup(
            trackingIdentifier: trackingID,
            trackingUID: trackingUID,
            findingType: findingType,
            findingSite: findingSite,
            measurements: measurements,
            qualitativeEvaluations: qualitativeEvaluations
        )
    }
    
    private static func extractQualitativeEvaluations(from container: ContainerContentItem) -> [CodedConcept] {
        var evaluations: [CodedConcept] = []
        
        for item in container.contentItems {
            if let codeItem = item.asCode,
               let conceptName = codeItem.conceptName,
               // Common qualitative evaluation concept names
               ["121071", "121073", "121074"].contains(conceptName.codeValue) {
                evaluations.append(codeItem.conceptCode)
            }
        }
        
        return evaluations
    }
}

// MARK: - Supporting Types

// Note: ImageReference type is defined in DICOMCore.ContentItem and is reused here

/// Represents a measurement group (TID 1501)
public struct ExtractedMeasurementGroup: Sendable, Equatable {
    /// Tracking identifier for the measurement group
    public let trackingIdentifier: String
    
    /// Tracking unique identifier (UID)
    public let trackingUID: String?
    
    /// Type of finding being measured
    public let findingType: CodedConcept?
    
    /// Anatomical site of the finding
    public let findingSite: CodedConcept?
    
    /// Numeric measurements in this group
    public let measurements: [Measurement]
    
    /// Qualitative evaluations (coded concepts)
    public let qualitativeEvaluations: [CodedConcept]
    
    /// Creates a measurement group
    public init(
        trackingIdentifier: String,
        trackingUID: String? = nil,
        findingType: CodedConcept? = nil,
        findingSite: CodedConcept? = nil,
        measurements: [Measurement] = [],
        qualitativeEvaluations: [CodedConcept] = []
    ) {
        self.trackingIdentifier = trackingIdentifier
        self.trackingUID = trackingUID
        self.findingType = findingType
        self.findingSite = findingSite
        self.measurements = measurements
        self.qualitativeEvaluations = qualitativeEvaluations
    }
}

// MARK: - Extraction Errors

/// Errors that can occur during extraction
public enum ExtractionError: Error, Sendable, Equatable {
    /// Invalid document type for extraction
    case invalidDocumentType(String)
    
    /// Missing required element
    case missingRequiredElement(String)
    
    /// Invalid structure
    case invalidStructure(String)
}

extension ExtractionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidDocumentType(let message):
            return "Invalid document type: \(message)"
        case .missingRequiredElement(let message):
            return "Missing required element: \(message)"
        case .invalidStructure(let message):
            return "Invalid structure: \(message)"
        }
    }
}
