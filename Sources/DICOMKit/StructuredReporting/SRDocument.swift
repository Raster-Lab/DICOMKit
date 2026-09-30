// NEMA-verified: 2026a, checked 2026-09-30 — Completion, Verification and Preliminary Flag terms match PS3.3 2026a Table C.17-2; Verifying Observer Sequence (0040,A073) Item attributes and types (A075 Type 1, A088 Type 2, A027 Type 1, A030 Type 1) match Table C.17-2, tags and VRs PS3.6 Table 6-1; the tree walk descends into the Content Sequence of every value type (Table C.17-6, D31)
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

    /// Verifying Observer Sequence (0040,A073), Type 1C: "Required if Verification Flag
    /// (0040,A493) is VERIFIED", with "One or more Items" (PS3.3 2026a Table C.17-2).
    /// Under PS3.5 2026a 7.4.2 a Type 1C element "shall not be included" when its
    /// condition is not met, so it is empty unless the document is VERIFIED.
    public let verifyingObservers: [VerifyingObserver]
    
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
    ///   - verifyingObservers: Verifying Observer Sequence Items; required (one or more)
    ///     when `verificationFlag` is `.verified` (PS3.3 Table C.17-2)
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
        verifyingObservers: [VerifyingObserver] = [],
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
        self.verifyingObservers = verifyingObservers
        self.documentTitle = documentTitle
        self.rootContent = rootContent
    }
    
    /// A copy of this document with the given Verifying Observer Sequence Items
    ///
    /// The SR builders produce the content and flags; a document marked VERIFIED also needs
    /// the observers who verified it (PS3.3 2026a Table C.17-2, Type 1C) before
    /// `SRDocumentSerializer` will write it.
    /// - Parameter observers: The Verifying Observer Sequence Items
    /// - Returns: The same document with `verifyingObservers` replaced
    public func withVerifyingObservers(_ observers: [VerifyingObserver]) -> SRDocument {
        SRDocument(
            sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID,
            patientID: patientID, patientName: patientName,
            studyInstanceUID: studyInstanceUID, studyDate: studyDate, studyTime: studyTime,
            accessionNumber: accessionNumber,
            seriesInstanceUID: seriesInstanceUID, seriesNumber: seriesNumber, modality: modality,
            contentDate: contentDate, contentTime: contentTime, instanceNumber: instanceNumber,
            completionFlag: completionFlag, verificationFlag: verificationFlag,
            preliminaryFlag: preliminaryFlag, verifyingObservers: observers,
            documentTitle: documentTitle, rootContent: rootContent)
    }

    // MARK: - Content Tree Helpers
    
    /// Collects all content items from the tree (depth-first), including the children of
    /// non-CONTAINER items (PS3.3 Table C.17-6)
    private func collectAllContentItems(from container: ContainerContentItem) -> [AnyContentItem] {
        collectAllContentItems(in: container.contentItems)
    }

    private func collectAllContentItems(in contentItems: [AnyContentItem]) -> [AnyContentItem] {
        var items: [AnyContentItem] = []
        for item in contentItems {
            items.append(item)
            items.append(contentsOf: collectAllContentItems(in: item.contentItems))
        }
        return items
    }
    
    /// Counts all content items in the tree
    private func countContentItems(in container: ContainerContentItem) -> Int {
        collectAllContentItems(from: container).count
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
/// Reference: PS3.3 Table C.17-2 (SR Document General Module)
public enum CompletionFlag: String, Sendable, Equatable, Hashable {
    /// Document content is complete
    case complete = "COMPLETE"
    
    /// Document content is partial
    case partial = "PARTIAL"
}

/// Verification flag for SR documents
///
/// Reference: PS3.3 Table C.17-2 (SR Document General Module)
public enum VerificationFlag: String, Sendable, Equatable, Hashable {
    /// Document content is verified
    case verified = "VERIFIED"
    
    /// Document content is not verified
    case unverified = "UNVERIFIED"
}

/// One Item of the Verifying Observer Sequence (0040,A073)
///
/// "The person or persons authorized to verify documents of this type and accept
/// responsibility for the content of this document" (PS3.3 2026a Table C.17-2).
///
/// Reference: PS3.3 2026a Table C.17-2 (SR Document General Module)
public struct VerifyingObserver: Sendable, Equatable, Hashable {
    /// Verifying Observer Name (0040,A075), Type 1, VR PN
    public let name: String

    /// Verifying Observer Identification Code Sequence (0040,A088), Type 2: "Zero or one
    /// Item shall be included" (Code Sequence Macro, Table 8.8-1; no Baseline CID). `nil`
    /// is written as the sequence with zero Items.
    public let identificationCode: CodedConcept?

    /// Verifying Organization (0040,A027), Type 1, VR LO: the organization to which the
    /// Verifying Observer Name is accountable
    public let organization: String

    /// Verification DateTime (0040,A030), Type 1, VR DT ("YYYYMMDDHHMMSS.FFFFFF&ZZXX")
    public let verificationDateTime: String

    /// Creates a Verifying Observer Sequence Item
    /// - Parameters:
    ///   - name: Verifying Observer Name (0040,A075), Type 1
    ///   - identificationCode: Verifying Observer Identification Code Sequence (0040,A088) Item, Type 2
    ///   - organization: Verifying Organization (0040,A027), Type 1
    ///   - verificationDateTime: Verification DateTime (0040,A030), Type 1, a DT value
    public init(
        name: String,
        identificationCode: CodedConcept? = nil,
        organization: String,
        verificationDateTime: String
    ) {
        self.name = name
        self.identificationCode = identificationCode
        self.organization = organization
        self.verificationDateTime = verificationDateTime
    }
}

/// Preliminary flag for SR documents
///
/// Reference: PS3.3 Table C.17-2 (SR Document General Module)
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
