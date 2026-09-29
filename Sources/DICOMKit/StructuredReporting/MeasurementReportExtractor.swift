// NEMA-verified: 2026a, checked 2026-09-29 — reads the content tree per PS3.16 2026a Tables TID 1500, TID 1204, TID 1600/1601/1602, TID 1501 (rows 2, 3, 3b, 6, 11) and tolerates the pre-2026-09-29 flat placements (images directly under Image Library, Country of Language beside the language item); concept codes per Table D-1
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
    
    /// Language of content (TID 1204 row 1)
    public let languageOfContent: CodedConcept?

    /// Country of language (TID 1204 row 2)
    public let countryOfLanguage: CodedConcept?

    // MARK: - Content Structures

    /// Image library entries (TID 1600): the IMAGE items of every Image Library Group
    /// (TID 1600 rows 2 and 4 → TID 1601 row 1), in document order. IMAGE items written
    /// directly under the Image Library container (the pre-2026-09-29 layout) are read too.
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
        
        // Extract language of content and its country (TID 1204)
        let (languageOfContent, countryOfLanguage) = extractLanguage(from: document.rootContent)

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
            countryOfLanguage: countryOfLanguage,
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
               codeItem.conceptName?.codeValue == "121058" { // TID 1500 row 4: Procedure reported
                procedures.append(codeItem.conceptCode)
            }
        }

        return procedures
    }

    /// TID 1500 row 2 → TID 1204: row 1 (121049, DCM) HAS CONCEPT MOD CODE at the root; row 2
    /// (121046, DCM) is its child. DICOMCore cannot nest under a CODE item, so the country is
    /// also accepted as a root-level sibling (what `MeasurementReportBuilder` writes).
    private static func extractLanguage(from container: ContainerContentItem) -> (CodedConcept?, CodedConcept?) {
        var language: CodedConcept?
        var country: CodedConcept?
        for item in container.contentItems {
            guard let codeItem = item.asCode, let concept = codeItem.conceptName else { continue }
            if concept.codeValue == "121049", language == nil {
                language = codeItem.conceptCode
            } else if concept.codeValue == "121046", country == nil {
                country = codeItem.conceptCode
            }
        }
        return (language, country)
    }

    /// TID 1600: row 1 CONTAINER (111028, DCM, "Image Library"); row 2 CONTAINS CONTAINER
    /// (126200, DCM, "Image Library Group"); row 4 CONTAINS TID 1601 row 1 IMAGE. IMAGE items
    /// found directly under the Image Library container are read as well.
    private static func extractImageLibrary(from container: ContainerContentItem) -> [ImageReference] {
        var entries: [ImageReference] = []

        for item in container.contentItems {
            guard let imageLibContainer = item.asContainer,
                  imageLibContainer.conceptName?.codeValue == "111028" else { continue }

            for libraryItem in imageLibContainer.contentItems {
                if let group = libraryItem.asContainer,
                   group.conceptName?.codeValue == "126200" {
                    entries += group.contentItems.compactMap { $0.asImage?.imageReference }
                } else if let image = libraryItem.asImage {
                    entries.append(image.imageReference)
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
            // TID 1501 row 2: HAS OBS CONTEXT TEXT (112039, DCM, "Tracking Identifier")
            if let textItem = item.asText,
               textItem.conceptName?.codeValue == "112039" {
                trackingIdentifier = textItem.textValue
            }

            // TID 1501 row 3: HAS OBS CONTEXT UIDREF (112040, DCM, "Tracking Unique Identifier")
            else if let uidItem = item.asUIDRef,
                    uidItem.conceptName?.codeValue == "112040" {
                trackingUID = uidItem.uidValue
            }

            // TID 1501 row 3b: CONTAINS CODE (121071, DCM, "Finding")
            else if let codeItem = item.asCode,
                    codeItem.conceptName?.codeValue == "121071" {
                findingType = codeItem.conceptCode
            }

            // TID 1501 row 6: HAS CONCEPT MOD CODE (363698007, SCT, "Finding Site")
            else if let codeItem = item.asCode,
                    codeItem.conceptName?.codeValue == "363698007" {
                findingSite = codeItem.conceptCode
            }

            // TID 1501 row 10 → TID 300 row 1: NUM measurements
            else if let numItem = item.asNumeric {
                let measurement = Measurement(from: numItem)
                measurements.append(measurement)
            }

            // TID 1501 row 11: CONTAINS CODE ($QualType) qualitative evaluations. Concept
            // modifiers of the group (HAS CONCEPT MOD, e.g. row 7 Laterality written beside
            // the Finding Site) are not evaluations.
            else if let codeItem = item.asCode,
                    codeItem.relationshipType != .hasConceptMod {
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
            // TID 1500 row 9: a "Qualitative Evaluations" (C0034375, UMLS)
            // container whose CODE children are the evaluations.
            if let evaluationsContainer = item.asContainer,
               evaluationsContainer.conceptName?.codeValue == "C0034375" {
                evaluations += evaluationsContainer.contentItems.compactMap { $0.asCode?.conceptCode }
            }
            // Evaluations written directly under the root.
            else if let codeItem = item.asCode,
                    let conceptName = codeItem.conceptName,
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
