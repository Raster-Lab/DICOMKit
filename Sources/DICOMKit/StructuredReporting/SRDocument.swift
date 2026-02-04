/// DICOM Structured Reporting Document
///
/// Represents a parsed DICOM SR document with its content tree.
///
/// Reference: PS3.3 Section C.17 - SR Document Information Object Definitions

import Foundation
import DICOMCore

/// A parsed DICOM Structured Reporting document
///
/// SRDocument provides a high-level representation of a DICOM SR document,
/// including document metadata and the hierarchical content tree.
///
/// Example:
/// ```swift
/// let parser = SRDocumentParser()
/// let document = try parser.parse(dataSet: dataSet)
/// print(document.documentTitle?.codeMeaning ?? "Untitled")
/// ```
public struct SRDocument: Sendable, Equatable {
    // MARK: - Document Identification
    
    /// SOP Class UID (0008,0016)
    public let sopClassUID: String
    
    /// SOP Instance UID (0008,0018)
    public let sopInstanceUID: String
    
    /// SR Document type derived from SOP Class UID
    public var documentType: SRDocumentType? {
        SRDocumentType.from(sopClassUID: sopClassUID)
    }
    
    // MARK: - Patient Information
    
    /// Patient ID (0010,0020)
    public let patientID: String?
    
    /// Patient Name (0010,0010)
    public let patientName: String?
    
    // MARK: - Study Information
    
    /// Study Instance UID (0020,000D)
    public let studyInstanceUID: String?
    
    /// Study Date (0008,0020)
    public let studyDate: String?
    
    /// Study Time (0008,0030)
    public let studyTime: String?
    
    /// Accession Number (0008,0050)
    public let accessionNumber: String?
    
    // MARK: - Series Information
    
    /// Series Instance UID (0020,000E)
    public let seriesInstanceUID: String?
    
    /// Series Number (0020,0011)
    public let seriesNumber: String?
    
    /// Modality (0008,0060)
    public let modality: String?
    
    // MARK: - Document Header
    
    /// Content Date (0008,0023)
    public let contentDate: String?
    
    /// Content Time (0008,0033)
    public let contentTime: String?
    
    /// Instance Number (0020,0013)
    public let instanceNumber: String?
    
    /// Completion Flag (0040,A491)
    public let completionFlag: CompletionFlag?
    
    /// Verification Flag (0040,A493)
    public let verificationFlag: VerificationFlag?
    
    /// Preliminary Flag (0040,A496)
    public let preliminaryFlag: PreliminaryFlag?
    
    // MARK: - Content Tree
    
    /// Document title from the root container's Concept Name Code Sequence
    public let documentTitle: CodedConcept?
    
    /// Root content item (always a CONTAINER for valid SR documents)
    public let rootContent: ContainerContentItem
    
    /// All content items in the document (flattened tree)
    public var allContentItems: [AnyContentItem] {
        collectAllContentItems(from: rootContent)
    }
    
    /// Total count of content items in the document
    public var contentItemCount: Int {
        countContentItems(in: rootContent)
    }
    
    // MARK: - Initialization
    
    /// Creates a new SR document
    /// - Parameters:
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - patientID: Optional patient ID
    ///   - patientName: Optional patient name
    ///   - studyInstanceUID: Optional study instance UID
    ///   - studyDate: Optional study date
    ///   - studyTime: Optional study time
    ///   - accessionNumber: Optional accession number
    ///   - seriesInstanceUID: Optional series instance UID
    ///   - seriesNumber: Optional series number
    ///   - modality: Optional modality
    ///   - contentDate: Optional content date
    ///   - contentTime: Optional content time
    ///   - instanceNumber: Optional instance number
    ///   - completionFlag: Optional completion flag
    ///   - verificationFlag: Optional verification flag
    ///   - preliminaryFlag: Optional preliminary flag
    ///   - documentTitle: Optional document title
    ///   - rootContent: The root container content item
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        patientID: String? = nil,
        patientName: String? = nil,
        studyInstanceUID: String? = nil,
        studyDate: String? = nil,
        studyTime: String? = nil,
        accessionNumber: String? = nil,
        seriesInstanceUID: String? = nil,
        seriesNumber: String? = nil,
        modality: String? = nil,
        contentDate: String? = nil,
        contentTime: String? = nil,
        instanceNumber: String? = nil,
        completionFlag: CompletionFlag? = nil,
        verificationFlag: VerificationFlag? = nil,
        preliminaryFlag: PreliminaryFlag? = nil,
        documentTitle: CodedConcept? = nil,
        rootContent: ContainerContentItem
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.patientID = patientID
        self.patientName = patientName
        self.studyInstanceUID = studyInstanceUID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.accessionNumber = accessionNumber
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.modality = modality
        self.contentDate = contentDate
        self.contentTime = contentTime
        self.instanceNumber = instanceNumber
        self.completionFlag = completionFlag
        self.verificationFlag = verificationFlag
        self.preliminaryFlag = preliminaryFlag
        self.documentTitle = documentTitle
        self.rootContent = rootContent
    }
    
    // MARK: - Content Tree Helpers
    
    /// Collects all content items from the tree (depth-first)
    private func collectAllContentItems(from container: ContainerContentItem) -> [AnyContentItem] {
        var items: [AnyContentItem] = []
        for item in container.contentItems {
            items.append(item)
            if let nestedContainer = item.asContainer {
                items.append(contentsOf: collectAllContentItems(from: nestedContainer))
            }
        }
        return items
    }
    
    /// Counts all content items in the tree
    private func countContentItems(in container: ContainerContentItem) -> Int {
        var count = container.contentItems.count
        for item in container.contentItems {
            if let nestedContainer = item.asContainer {
                count += countContentItems(in: nestedContainer)
            }
        }
        return count
    }
    
    // MARK: - Content Access Methods
    
    /// Finds all content items with the specified concept name
    /// - Parameter conceptName: The concept name to search for
    /// - Returns: Array of matching content items
    public func findContentItems(withConceptName conceptName: CodedConcept) -> [AnyContentItem] {
        allContentItems.filter { $0.conceptName == conceptName }
    }
    
    /// Finds all content items of the specified value type
    /// - Parameter valueType: The value type to search for
    /// - Returns: Array of matching content items
    public func findContentItems(ofType valueType: ContentItemValueType) -> [AnyContentItem] {
        allContentItems.filter { $0.valueType == valueType }
    }
    
    /// Finds all numeric content items (NUM value type)
    /// - Returns: Array of numeric content items
    public func findNumericItems() -> [NumericContentItem] {
        allContentItems.compactMap { $0.asNumeric }
    }
    
    /// Finds all text content items (TEXT value type)
    /// - Returns: Array of text content items
    public func findTextItems() -> [TextContentItem] {
        allContentItems.compactMap { $0.asText }
    }
    
    /// Finds all code content items (CODE value type)
    /// - Returns: Array of code content items
    public func findCodeItems() -> [CodeContentItem] {
        allContentItems.compactMap { $0.asCode }
    }
    
    /// Finds all image reference content items (IMAGE value type)
    /// - Returns: Array of image content items
    public func findImageItems() -> [ImageContentItem] {
        allContentItems.compactMap { $0.asImage }
    }
    
    /// Finds all spatial coordinate content items (SCOORD value type)
    /// - Returns: Array of spatial coordinate content items
    public func findSpatialCoordinateItems() -> [SpatialCoordinatesContentItem] {
        allContentItems.compactMap { $0.asSpatialCoordinates }
    }
    
    /// Finds all container content items (CONTAINER value type)
    /// - Returns: Array of container content items
    public func findContainerItems() -> [ContainerContentItem] {
        allContentItems.compactMap { $0.asContainer }
    }
}

// MARK: - SR Document Flags

/// Completion flag for SR documents
///
/// Reference: PS3.3 Table C.17.2.5-1
public enum CompletionFlag: String, Sendable, Equatable, Hashable {
    /// Document content is complete
    case complete = "COMPLETE"
    
    /// Document content is partial
    case partial = "PARTIAL"
}

/// Verification flag for SR documents
///
/// Reference: PS3.3 Table C.17.2.5-1
public enum VerificationFlag: String, Sendable, Equatable, Hashable {
    /// Document content is verified
    case verified = "VERIFIED"
    
    /// Document content is not verified
    case unverified = "UNVERIFIED"
}

/// Preliminary flag for SR documents
///
/// Reference: PS3.3 Table C.17.2.5-1
public enum PreliminaryFlag: String, Sendable, Equatable, Hashable {
    /// Document is preliminary
    case preliminary = "PRELIMINARY"
    
    /// Document is final
    case final = "FINAL"
}

// MARK: - CustomStringConvertible

extension SRDocument: CustomStringConvertible {
    public var description: String {
        let title = documentTitle?.codeMeaning ?? "Untitled"
        let type = documentType?.displayName ?? "Unknown SR"
        return "\(type): \(title) (\(contentItemCount) items)"
    }
}
