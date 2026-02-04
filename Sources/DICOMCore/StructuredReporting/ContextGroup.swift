/// ContextGroup - DICOM Context Group support (PS3.16)
///
/// Provides structures for working with DICOM Context Groups (CIDs) which
/// define sets of coded concepts for specific purposes in DICOM.
///
/// Reference: PS3.16 - Content Mapping Resource
/// Reference: PS3.16 Annex B - DCMR Context Group Definitions

#if canImport(Foundation)
import Foundation
#endif

/// A DICOM Context Group definition
///
/// Context Groups (CIDs) define sets of coded concepts that are valid
/// for specific purposes within DICOM. For example, CID 244 defines
/// the valid codes for laterality.
///
/// Example:
/// ```swift
/// let laterality = ContextGroup.laterality
/// if laterality.contains(CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")) {
///     print("Valid laterality code")
/// }
/// ```
public struct ContextGroup: Sendable, Equatable {
    /// The Context Identifier (CID) number
    public let cid: Int
    
    /// The name of the context group
    public let name: String
    
    /// Whether this context group is extensible (allows additional codes)
    public let isExtensible: Bool
    
    /// The version of the context group
    public let version: String?
    
    /// The coded concepts that are members of this context group
    public let members: [CodedConcept]
    
    /// Creates a context group
    /// - Parameters:
    ///   - cid: The Context Identifier number
    ///   - name: The name of the context group
    ///   - isExtensible: Whether additional codes are allowed (default: true)
    ///   - version: Optional version string
    ///   - members: The coded concepts in this group
    public init(
        cid: Int,
        name: String,
        isExtensible: Bool = true,
        version: String? = nil,
        members: [CodedConcept]
    ) {
        self.cid = cid
        self.name = name
        self.isExtensible = isExtensible
        self.version = version
        self.members = members
    }
    
    /// Check if a coded concept is a member of this context group
    /// - Parameter concept: The coded concept to check
    /// - Returns: true if the concept is in this context group
    public func contains(_ concept: CodedConcept) -> Bool {
        members.contains(concept)
    }
    
    /// Validate a coded concept against this context group
    /// - Parameter concept: The coded concept to validate
    /// - Returns: ValidationResult indicating whether the concept is valid
    public func validate(_ concept: CodedConcept) -> ValidationResult {
        if contains(concept) {
            return .valid
        }
        
        if isExtensible {
            return .extensionCode
        }
        
        return .invalid(reason: "Code \(concept.codeValue) is not a member of CID \(cid) (\(name))")
    }
    
    /// Result of validating a concept against a context group
    public enum ValidationResult: Sendable, Equatable {
        /// The concept is a defined member of the context group
        case valid
        /// The concept is not a defined member, but the group is extensible
        case extensionCode
        /// The concept is invalid for this context group
        case invalid(reason: String)
        
        /// Whether the concept can be used (valid or extension)
        public var isAcceptable: Bool {
            switch self {
            case .valid, .extensionCode:
                return true
            case .invalid:
                return false
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension ContextGroup: CustomStringConvertible {
    public var description: String {
        let extensible = isExtensible ? "extensible" : "non-extensible"
        return "CID \(cid) - \(name) (\(extensible), \(members.count) codes)"
    }
}

// MARK: - CID 218: Quantitative Temporal Relation

extension ContextGroup {
    /// CID 218 - Quantitative Temporal Relation
    ///
    /// Defines temporal relationships for measurements and observations.
    public static let quantitativeTemporalRelation = ContextGroup(
        cid: 218,
        name: "Quantitative Temporal Relation",
        isExtensible: false,
        members: [
            CodedConcept(codeValue: "R-40899", scheme: .SRT, codeMeaning: "Before"),
            CodedConcept(codeValue: "R-4089A", scheme: .SRT, codeMeaning: "After"),
            CodedConcept(codeValue: "R-4089B", scheme: .SRT, codeMeaning: "During"),
            CodedConcept(codeValue: "R-4089C", scheme: .SRT, codeMeaning: "At"),
            CodedConcept(codeValue: "R-4089D", scheme: .SRT, codeMeaning: "Simultaneously"),
            CodedConcept(codeValue: "121110", scheme: .DCM, codeMeaning: "Baseline"),
            CodedConcept(codeValue: "121111", scheme: .DCM, codeMeaning: "Post-baseline"),
            CodedConcept(codeValue: "121112", scheme: .DCM, codeMeaning: "Pre-baseline"),
        ]
    )
}

// MARK: - CID 244: Laterality

extension ContextGroup {
    /// CID 244 - Laterality
    ///
    /// Defines codes for specifying the laterality of body parts.
    public static let laterality = ContextGroup(
        cid: 244,
        name: "Laterality",
        isExtensible: false,
        members: [
            CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right"),
            CodedConcept(codeValue: "7771000", scheme: .SCT, codeMeaning: "Left"),
            CodedConcept(codeValue: "51440002", scheme: .SCT, codeMeaning: "Bilateral"),
            CodedConcept(codeValue: "66459002", scheme: .SCT, codeMeaning: "Unilateral"),
        ]
    )
}

// MARK: - CID 4021: Finding Site

extension ContextGroup {
    /// CID 4021 - Finding Site (partial)
    ///
    /// Defines anatomical locations where findings can be reported.
    /// This is a partial implementation with common sites.
    public static let findingSite = ContextGroup(
        cid: 4021,
        name: "Finding Site",
        isExtensible: true,
        members: [
            // Head
            CodedConcept(codeValue: "69536005", scheme: .SCT, codeMeaning: "Head"),
            CodedConcept(codeValue: "12738006", scheme: .SCT, codeMeaning: "Brain"),
            CodedConcept(codeValue: "89546000", scheme: .SCT, codeMeaning: "Skull"),
            // Neck
            CodedConcept(codeValue: "45048000", scheme: .SCT, codeMeaning: "Neck"),
            CodedConcept(codeValue: "69748006", scheme: .SCT, codeMeaning: "Thyroid gland"),
            // Chest
            CodedConcept(codeValue: "51185008", scheme: .SCT, codeMeaning: "Chest"),
            CodedConcept(codeValue: "39607008", scheme: .SCT, codeMeaning: "Lung"),
            CodedConcept(codeValue: "80891009", scheme: .SCT, codeMeaning: "Heart"),
            CodedConcept(codeValue: "76752008", scheme: .SCT, codeMeaning: "Breast"),
            // Abdomen
            CodedConcept(codeValue: "818983003", scheme: .SCT, codeMeaning: "Abdomen"),
            CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver"),
            CodedConcept(codeValue: "64033007", scheme: .SCT, codeMeaning: "Kidney"),
            CodedConcept(codeValue: "78961009", scheme: .SCT, codeMeaning: "Spleen"),
            CodedConcept(codeValue: "15776009", scheme: .SCT, codeMeaning: "Pancreas"),
            // Pelvis
            CodedConcept(codeValue: "816092008", scheme: .SCT, codeMeaning: "Pelvis"),
            CodedConcept(codeValue: "89837001", scheme: .SCT, codeMeaning: "Bladder"),
            CodedConcept(codeValue: "41216001", scheme: .SCT, codeMeaning: "Prostate"),
            // Spine
            CodedConcept(codeValue: "421060004", scheme: .SCT, codeMeaning: "Spine"),
            // Extremities
            CodedConcept(codeValue: "53120007", scheme: .SCT, codeMeaning: "Upper extremity"),
            CodedConcept(codeValue: "61685007", scheme: .SCT, codeMeaning: "Lower extremity"),
        ]
    )
}

// MARK: - CID 6147: Response Evaluation

extension ContextGroup {
    /// CID 6147 - Response Evaluation
    ///
    /// Defines codes for evaluating treatment response (RECIST-style).
    public static let responseEvaluation = ContextGroup(
        cid: 6147,
        name: "Response Evaluation",
        isExtensible: true,
        members: [
            CodedConcept(codeValue: "126000", scheme: .DCM, codeMeaning: "Complete Response"),
            CodedConcept(codeValue: "126001", scheme: .DCM, codeMeaning: "Partial Response"),
            CodedConcept(codeValue: "126002", scheme: .DCM, codeMeaning: "Stable Disease"),
            CodedConcept(codeValue: "126003", scheme: .DCM, codeMeaning: "Progressive Disease"),
            CodedConcept(codeValue: "126004", scheme: .DCM, codeMeaning: "Not Evaluable"),
            CodedConcept(codeValue: "126005", scheme: .DCM, codeMeaning: "Non-CR/Non-PD"),
        ]
    )
}

// MARK: - CID 7021: Measurement Report Document Titles

extension ContextGroup {
    /// CID 7021 - Measurement Report Document Titles
    ///
    /// Defines document titles for measurement reports.
    public static let measurementReportDocumentTitles = ContextGroup(
        cid: 7021,
        name: "Measurement Report Document Titles",
        isExtensible: true,
        members: [
            CodedConcept(codeValue: "126000", scheme: .DCM, codeMeaning: "Imaging Measurement Report"),
            CodedConcept(codeValue: "126001", scheme: .DCM, codeMeaning: "Oncology Measurement Report"),
            CodedConcept(codeValue: "126002", scheme: .DCM, codeMeaning: "Baseline Tumor Measurement Report"),
            CodedConcept(codeValue: "126003", scheme: .DCM, codeMeaning: "Follow-Up Tumor Measurement Report"),
        ]
    )
}

// MARK: - CID 7464: General Region of Interest Measurement Units

extension ContextGroup {
    /// CID 7464 - General Region of Interest Measurement Units
    ///
    /// Defines units commonly used for ROI measurements.
    public static let roiMeasurementUnits = ContextGroup(
        cid: 7464,
        name: "General Region of Interest Measurement Units",
        isExtensible: true,
        members: [
            // Length units
            CodedConcept(codeValue: "mm", scheme: .UCUM, codeMeaning: "millimeter"),
            CodedConcept(codeValue: "cm", scheme: .UCUM, codeMeaning: "centimeter"),
            CodedConcept(codeValue: "m", scheme: .UCUM, codeMeaning: "meter"),
            // Area units
            CodedConcept(codeValue: "mm2", scheme: .UCUM, codeMeaning: "square millimeter"),
            CodedConcept(codeValue: "cm2", scheme: .UCUM, codeMeaning: "square centimeter"),
            // Volume units
            CodedConcept(codeValue: "mm3", scheme: .UCUM, codeMeaning: "cubic millimeter"),
            CodedConcept(codeValue: "cm3", scheme: .UCUM, codeMeaning: "cubic centimeter"),
            CodedConcept(codeValue: "mL", scheme: .UCUM, codeMeaning: "milliliter"),
            CodedConcept(codeValue: "L", scheme: .UCUM, codeMeaning: "liter"),
            // Density
            CodedConcept(codeValue: "[hnsf'U]", scheme: .UCUM, codeMeaning: "Hounsfield unit"),
            // Ratio
            CodedConcept(codeValue: "1", scheme: .UCUM, codeMeaning: "no units"),
            CodedConcept(codeValue: "%", scheme: .UCUM, codeMeaning: "percent"),
            // Angle
            CodedConcept(codeValue: "deg", scheme: .UCUM, codeMeaning: "degree"),
        ]
    )
}

// MARK: - CID 12301: Imaging Observations

extension ContextGroup {
    /// CID 12301 - Imaging Observations (partial)
    ///
    /// Common observations made during imaging studies.
    public static let imagingObservations = ContextGroup(
        cid: 12301,
        name: "Imaging Observations",
        isExtensible: true,
        members: [
            CodedConcept(codeValue: "4147007", scheme: .SCT, codeMeaning: "Mass"),
            CodedConcept(codeValue: "27925004", scheme: .SCT, codeMeaning: "Nodule"),
            CodedConcept(codeValue: "52988006", scheme: .SCT, codeMeaning: "Lesion"),
            CodedConcept(codeValue: "441457006", scheme: .SCT, codeMeaning: "Cyst"),
            CodedConcept(codeValue: "36222007", scheme: .SCT, codeMeaning: "Calcification"),
            CodedConcept(codeValue: "35013009", scheme: .SCT, codeMeaning: "Effusion"),
            CodedConcept(codeValue: "50960005", scheme: .SCT, codeMeaning: "Hemorrhage"),
            CodedConcept(codeValue: "267038008", scheme: .SCT, codeMeaning: "Edema"),
            CodedConcept(codeValue: "125605004", scheme: .SCT, codeMeaning: "Fracture"),
            CodedConcept(codeValue: "128462008", scheme: .SCT, codeMeaning: "Metastasis"),
        ]
    )
}

// MARK: - CID 6051: Breast Imaging Finding

extension ContextGroup {
    /// CID 6051 - Breast Imaging Finding (partial)
    ///
    /// Findings specific to breast imaging (mammography, breast MRI, etc.)
    public static let breastImagingFinding = ContextGroup(
        cid: 6051,
        name: "Breast Imaging Finding",
        isExtensible: true,
        members: [
            CodedConcept(codeValue: "4147007", scheme: .SCT, codeMeaning: "Mass"),
            CodedConcept(codeValue: "36222007", scheme: .SCT, codeMeaning: "Calcification"),
            CodedConcept(codeValue: "129766006", scheme: .SCT, codeMeaning: "Architectural Distortion"),
            CodedConcept(codeValue: "129767002", scheme: .SCT, codeMeaning: "Asymmetry"),
            CodedConcept(codeValue: "129769004", scheme: .SCT, codeMeaning: "Focal Asymmetry"),
            CodedConcept(codeValue: "F-01790", scheme: .SRT, codeMeaning: "Skin Thickening"),
            CodedConcept(codeValue: "F-01791", scheme: .SRT, codeMeaning: "Nipple Retraction"),
            CodedConcept(codeValue: "F-01796", scheme: .SRT, codeMeaning: "Axillary Lymph Node"),
        ]
    )
}

// MARK: - CID 6024: Derivation (Measurement)

extension ContextGroup {
    /// CID 6024 - Derivation
    ///
    /// How a measurement value was derived.
    public static let derivation = ContextGroup(
        cid: 6024,
        name: "Derivation",
        isExtensible: true,
        members: [
            CodedConcept(codeValue: "255214003", scheme: .SCT, codeMeaning: "Calculated"),
            CodedConcept(codeValue: "258090004", scheme: .SCT, codeMeaning: "Estimated"),
            CodedConcept(codeValue: "258224002", scheme: .SCT, codeMeaning: "Measured"),
            CodedConcept(codeValue: "C118028", scheme: .NCIt, codeMeaning: "Derived"),
        ]
    )
}

// MARK: - Context Group Registry

/// Registry of known context groups
///
/// Provides lookup and management of DICOM context groups.
///
/// Example:
/// ```swift
/// let registry = ContextGroupRegistry.shared
/// if let laterality = registry.group(forCID: 244) {
///     print("Found: \(laterality.name)")
/// }
/// ```
public final class ContextGroupRegistry: @unchecked Sendable {
    /// The shared registry instance with well-known groups pre-registered
    public static let shared = ContextGroupRegistry()
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    /// Internal storage by CID
    private var groups: [Int: ContextGroup] = [:]
    
    /// Creates an empty registry
    public init() {
        registerWellKnownGroups()
    }
    
    /// Register well-known context groups
    private func registerWellKnownGroups() {
        let wellKnown: [ContextGroup] = [
            .quantitativeTemporalRelation,
            .laterality,
            .findingSite,
            .responseEvaluation,
            .measurementReportDocumentTitles,
            .roiMeasurementUnits,
            .imagingObservations,
            .breastImagingFinding,
            .derivation
        ]
        
        for group in wellKnown {
            groups[group.cid] = group
        }
    }
    
    /// Look up a context group by its CID
    /// - Parameter cid: The Context Identifier number
    /// - Returns: The context group if found, nil otherwise
    public func group(forCID cid: Int) -> ContextGroup? {
        lock.lock()
        defer { lock.unlock() }
        return groups[cid]
    }
    
    /// Register a new context group
    /// - Parameter group: The context group to register
    public func register(_ group: ContextGroup) {
        lock.lock()
        defer { lock.unlock() }
        groups[group.cid] = group
    }
    
    /// Get all registered context groups
    /// - Returns: Array of all registered context groups
    public var allGroups: [ContextGroup] {
        lock.lock()
        defer { lock.unlock() }
        return Array(groups.values)
    }
    
    /// Validate a coded concept against a specific context group
    /// - Parameters:
    ///   - concept: The coded concept to validate
    ///   - cid: The Context Identifier number
    /// - Returns: ValidationResult, or nil if the CID is not registered
    public func validate(_ concept: CodedConcept, againstCID cid: Int) -> ContextGroup.ValidationResult? {
        lock.lock()
        defer { lock.unlock() }
        return groups[cid]?.validate(concept)
    }
}
