/// DICOM Structured Reporting Template Infrastructure
///
/// Provides foundational types for defining and validating DICOM SR Templates (TID).
/// Templates define the structure and constraints for SR content.
///
/// Reference: PS3.16 Annex A - SR Templates
/// Reference: PS3.16 Chapter 6 - Form of Template Specifications
///
/// NEMA-verified: 2026a, checked 2026-09-25 — `RequirementLevel` is text-diffed against
/// PS3.16 2026a §6.1.7 (M, MC, U, UC), and every `TemplateIdentifier` constant against the
/// TID section titles of PS3.16 2026a Annex A. The template rows themselves live in
/// SRCoreTemplates and SRMeasurementTemplates (Bucket C2).

import Foundation

// MARK: - Template Identifier

/// Identifier for a DICOM SR Template
///
/// Templates are identified by a Template ID (TID) and an optional version.
/// Example: TID 300 - Measurement, TID 1500 - Measurement Report
public struct TemplateIdentifier: Sendable, Equatable, Hashable {
    /// The numeric template identifier (e.g., 300, 1500)
    public let templateID: String
    
    /// Optional version string for the template
    public let version: String?
    
    /// The mapping resource that defines this template (e.g., "DCMR" for DICOM Content Mapping Resource)
    public let mappingResource: String
    
    /// Creates a template identifier
    /// - Parameters:
    ///   - templateID: The numeric template ID (e.g., "300", "1500")
    ///   - version: Optional version string
    ///   - mappingResource: The mapping resource (default: "DCMR")
    public init(templateID: String, version: String? = nil, mappingResource: String = "DCMR") {
        self.templateID = templateID
        self.version = version
        self.mappingResource = mappingResource
    }
    
    /// Creates a template identifier from an integer TID
    /// - Parameters:
    ///   - tid: The numeric template ID
    ///   - version: Optional version string
    ///   - mappingResource: The mapping resource (default: "DCMR")
    public init(tid: Int, version: String? = nil, mappingResource: String = "DCMR") {
        self.templateID = String(tid)
        self.version = version
        self.mappingResource = mappingResource
    }
}

extension TemplateIdentifier: CustomStringConvertible {
    public var description: String {
        if let version = version {
            return "TID \(templateID) v\(version)"
        }
        return "TID \(templateID)"
    }
}

// MARK: - Well-Known Template Identifiers

extension TemplateIdentifier {
    // MARK: Core Templates
    
    /// TID 300 - Measurement
    public static let measurement = TemplateIdentifier(tid: 300)
    
    /// TID 320 - Image or Spatial Coordinates
    public static let imageOrSpatialCoordinates = TemplateIdentifier(tid: 320)

    /// TID 1601 - Image Library Entry
    ///
    /// Before 2026-09-25 this constant was TID 320, which is "Image or Spatial
    /// Coordinates" in PS3.16; Image Library Entry is TID 1601.
    public static let imageLibraryEntry = TemplateIdentifier(tid: 1601)
    
    /// TID 1001 - Observation Context
    public static let observationContext = TemplateIdentifier(tid: 1001)
    
    /// TID 1002 - Observer Context
    public static let observerContext = TemplateIdentifier(tid: 1002)
    
    /// TID 1204 - Language of Content Item and Descendants
    public static let languageOfContent = TemplateIdentifier(tid: 1204)
    
    // MARK: Measurement Templates
    
    /// TID 1400 - Linear Measurement
    public static let linearMeasurements = TemplateIdentifier(tid: 1400)

    /// TID 1410 - Planar ROI Measurements and Qualitative Evaluations
    public static let planarROIMeasurements = TemplateIdentifier(tid: 1410)

    /// TID 1411 - Volumetric ROI Measurements and Qualitative Evaluations
    public static let volumetricROIMeasurements = TemplateIdentifier(tid: 1411)

    /// TID 1419 - ROI Measurements
    public static let roiMeasurements = TemplateIdentifier(tid: 1419)

    /// TID 1420 - Measurements Derived From Multiple ROI Measurements
    public static let multipleROIMeasurements = TemplateIdentifier(tid: 1420)

    // MARK: Document Templates

    /// TID 1500 - Measurement Report
    public static let measurementReport = TemplateIdentifier(tid: 1500)

    /// TID 1501 - Measurement and Qualitative Evaluation Group
    public static let measurementGroup = TemplateIdentifier(tid: 1501)

    /// TID 1600 - Image Library
    public static let imageLibrary = TemplateIdentifier(tid: 1600)

    // MARK: CAD Templates

    /// TID 4000 - Mammography CAD Document Root
    public static let mammographyCADDocumentRoot = TemplateIdentifier(tid: 4000)

    /// TID 4019 - Algorithm Identification
    public static let algorithmIdentification = TemplateIdentifier(tid: 4019)

    @available(*, unavailable, renamed: "mammographyCADDocumentRoot",
               message: "TID 4000 is 'Mammography CAD Document Root' in PS3.16; there is no 'CAD Analysis' template.")
    public static var cadAnalysis: TemplateIdentifier { fatalError() }

    @available(*, unavailable, renamed: "algorithmIdentification",
               message: "TID 4019 is 'Algorithm Identification' in PS3.16; there is no 'CAD Finding' template.")
    public static var cadFinding: TemplateIdentifier { fatalError() }
}

// MARK: - Requirement Level

/// Requirement Type of a template row (PS3.16 §6.1.7)
///
/// The four symbols of PS3.16 2026a §6.1.7: M, MC, U and UC. The requirement type
/// interacts with VM: an M/MC row occurs 1 (VM 1) or 1–n (VM 1-n) times, a U/UC row
/// 0–1 or 0–n times.
///
/// Reference: PS3.16 Section 6.1.7 - Requirement Type
public enum RequirementLevel: String, Sendable, Equatable, Hashable, CaseIterable {
    /// M — Mandatory. Shall be present.
    case mandatory = "M"

    /// MC — Mandatory Conditional. Shall be present if the specified condition is satisfied.
    case mandatoryConditional = "MC"

    /// U — User Option. May or may not be present.
    case userOption = "U"

    /// UC — User Option Conditional. May not be present; may be present according to
    /// the specified condition.
    case userOptionConditional = "UC"

    /// Not a PS3.16 requirement type. Rows that "depend on other factors" are MC or UC.
    @available(*, deprecated, message: "PS3.16 §6.1.7 has no 'C' requirement type; use .mandatoryConditional or .userOptionConditional.")
    case conditional = "C"

    /// The old name for `U`, which is "User Option" in PS3.16, not "User Conditional".
    @available(*, deprecated, renamed: "userOption")
    public static var userConditional: RequirementLevel { .userOption }

    /// The four standard requirement types, in PS3.16 order.
    public static var allCases: [RequirementLevel] {
        [.mandatory, .mandatoryConditional, .userOption, .userOptionConditional]
    }

    /// Display name for the requirement level
    public var displayName: String {
        switch self {
        case .mandatory: return "Mandatory"
        case .mandatoryConditional: return "Mandatory Conditional"
        case .userOption: return "User Option"
        case .userOptionConditional: return "User Option Conditional"
        case .conditional: return "Conditional (non-standard)"
        }
    }

    /// Whether the row shall be present unconditionally (M only; MC depends on its
    /// condition, U and UC are optional).
    public var isMandatory: Bool {
        switch self {
        case .mandatory:
            return true
        case .mandatoryConditional, .userOption, .userOptionConditional, .conditional:
            return false
        }
    }
}

extension RequirementLevel: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

// MARK: - Cardinality

/// Cardinality constraint for template content items
///
/// Defines how many instances of a content item are allowed.
public struct Cardinality: Sendable, Equatable, Hashable {
    /// Minimum number of instances (0 for optional)
    public let minimum: Int
    
    /// Maximum number of instances (nil for unbounded)
    public let maximum: Int?
    
    /// Creates a cardinality constraint
    /// - Parameters:
    ///   - minimum: Minimum instances required
    ///   - maximum: Maximum instances allowed (nil for unbounded)
    public init(minimum: Int, maximum: Int? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
    
    /// Exactly one instance required (1..1)
    public static let one = Cardinality(minimum: 1, maximum: 1)
    
    /// Zero or one instance allowed (0..1)
    public static let zeroOrOne = Cardinality(minimum: 0, maximum: 1)
    
    /// One or more instances required (1..n)
    public static let oneOrMore = Cardinality(minimum: 1, maximum: nil)
    
    /// Zero or more instances allowed (0..n)
    public static let zeroOrMore = Cardinality(minimum: 0, maximum: nil)
    
    /// Returns whether this cardinality allows zero instances
    public var allowsZero: Bool {
        minimum == 0
    }
    
    /// Returns whether this cardinality allows multiple instances
    public var allowsMultiple: Bool {
        maximum == nil || maximum! > 1
    }
    
    /// Returns whether a given count satisfies this cardinality
    /// - Parameter count: The number of instances
    /// - Returns: True if the count is within the cardinality bounds
    public func isSatisfied(by count: Int) -> Bool {
        if count < minimum {
            return false
        }
        if let max = maximum, count > max {
            return false
        }
        return true
    }
}

extension Cardinality: CustomStringConvertible {
    public var description: String {
        if let max = maximum {
            if minimum == max {
                return "\(minimum)"
            }
            return "\(minimum)..\(max)"
        }
        return "\(minimum)..n"
    }
}

// MARK: - Template Row Condition

/// Condition that determines when a template row applies
///
/// Some template rows are conditional on other content being present.
public enum TemplateRowCondition: Sendable, Equatable {
    /// No condition - row always applies
    case none
    
    /// Row applies if the specified concept is present
    case ifPresent(concept: CodedConcept)
    
    /// Row applies if the specified concept has the specified value
    case ifEquals(concept: CodedConcept, value: CodedConcept)
    
    /// Row applies if the specified concept is not present
    case ifAbsent(concept: CodedConcept)
    
    /// Row applies if any of the conditions are met
    case anyOf([TemplateRowCondition])
    
    /// Row applies if all conditions are met
    case allOf([TemplateRowCondition])
    
    /// Custom condition with description
    case custom(description: String)
}

// MARK: - Template Row

/// Definition of a single row in an SR template
///
/// Each row specifies constraints on a content item including its value type,
/// relationship, requirement level, and cardinality.
///
/// Reference: PS3.16 Section 6.1 - Template Table Field Definition
public struct TemplateRow: Sendable, Equatable {
    /// Unique identifier for this row within the template
    public let rowID: String?
    
    /// Nesting level within the template (0 = top level)
    public let nestingLevel: Int
    
    /// Relationship type for this row
    public let relationshipType: RelationshipType
    
    /// Value type constraint
    public let valueType: ContentItemValueType
    
    /// Concept name constraint (if specified)
    public let conceptName: ConceptNameConstraint
    
    /// Value constraint (for CODE or NUM items)
    public let valueConstraint: ValueConstraint
    
    /// Requirement level
    public let requirementLevel: RequirementLevel
    
    /// Cardinality constraint
    public let cardinality: Cardinality
    
    /// Condition for when this row applies
    public let condition: TemplateRowCondition
    
    /// Included template (for rows that reference another template)
    public let includedTemplate: TemplateIdentifier?
    
    /// Creates a template row definition
    public init(
        rowID: String? = nil,
        nestingLevel: Int = 0,
        relationshipType: RelationshipType,
        valueType: ContentItemValueType,
        conceptName: ConceptNameConstraint = .any,
        valueConstraint: ValueConstraint = .any,
        requirementLevel: RequirementLevel = .mandatory,
        cardinality: Cardinality = .one,
        condition: TemplateRowCondition = .none,
        includedTemplate: TemplateIdentifier? = nil
    ) {
        self.rowID = rowID
        self.nestingLevel = nestingLevel
        self.relationshipType = relationshipType
        self.valueType = valueType
        self.conceptName = conceptName
        self.valueConstraint = valueConstraint
        self.requirementLevel = requirementLevel
        self.cardinality = cardinality
        self.condition = condition
        self.includedTemplate = includedTemplate
    }
}

// MARK: - Concept Name Constraint

/// Constraint on the concept name of a content item
public enum ConceptNameConstraint: Sendable, Equatable {
    /// Any concept name is allowed
    case any
    
    /// Must be exactly this concept
    case exact(CodedConcept)
    
    /// Must be from this context group
    case fromContextGroup(contextGroupID: Int)
    
    /// Must be one of these concepts
    case oneOf([CodedConcept])
    
    /// Must match the baseline concept from CID
    case baselineCID(contextGroupID: Int, baseline: CodedConcept)
}

// MARK: - Value Constraint

/// Constraint on the value of a content item
public enum ValueConstraint: Sendable, Equatable {
    /// Any value is allowed
    case any
    
    /// Must be exactly this coded value
    case exactCode(CodedConcept)
    
    /// Must be from this context group
    case fromContextGroup(contextGroupID: Int)
    
    /// Must be one of these coded values
    case oneOfCodes([CodedConcept])
    
    /// Numeric value must be in specified units
    case numericUnits(unitCode: CodedConcept)
    
    /// Text value with pattern constraint
    case textPattern(String)
    
    /// Custom value constraint with description
    case custom(description: String)
}

// MARK: - SR Template Protocol

/// Protocol for DICOM SR Template definitions
///
/// Implementations of this protocol define the structure and constraints
/// of specific templates (TIDs).
public protocol SRTemplate: Sendable {
    /// The template identifier (TID)
    static var identifier: TemplateIdentifier { get }
    
    /// Display name for the template
    static var displayName: String { get }
    
    /// Description of what this template is used for
    static var templateDescription: String { get }
    
    /// The rows that define this template's structure
    static var rows: [TemplateRow] { get }
    
    /// Root value type (usually CONTAINER)
    static var rootValueType: ContentItemValueType { get }
    
    /// Whether this template is extensible (allows additional content)
    static var isExtensible: Bool { get }
}

// MARK: - Template Protocol Default Implementations

extension SRTemplate {
    /// Default root value type is CONTAINER
    public static var rootValueType: ContentItemValueType {
        .container
    }
    
    /// Default to non-extensible
    public static var isExtensible: Bool {
        false
    }
}

// MARK: - Template Registry

/// Thread-safe storage for template types
private final class TemplateStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var templates: [String: any SRTemplate.Type] = [:]
    
    func register(_ templateType: any SRTemplate.Type) {
        lock.lock()
        defer { lock.unlock() }
        templates[templateType.identifier.templateID] = templateType
    }
    
    func template(for templateID: String) -> (any SRTemplate.Type)? {
        lock.lock()
        defer { lock.unlock() }
        return templates[templateID]
    }
    
    func allTemplates() -> [any SRTemplate.Type] {
        lock.lock()
        defer { lock.unlock() }
        return Array(templates.values)
    }
}

/// Registry of known SR templates
///
/// Provides lookup of template definitions by identifier.
public struct TemplateRegistry: Sendable {
    /// Shared singleton instance
    public static let shared = TemplateRegistry()
    
    /// Thread-safe storage
    private let storage = TemplateStorage()
    
    private init() {
        registerBuiltInTemplates()
    }
    
    /// Registers built-in templates
    private func registerBuiltInTemplates() {
        // Core templates will be registered here as they are implemented
        register(TID300Measurement.self)
        register(TID1601ImageLibraryEntry.self)
        register(TID1001ObservationContext.self)
        register(TID1002ObserverContext.self)
        register(TID1204LanguageOfContent.self)
        register(TID1400LinearMeasurements.self)
        register(TID1410PlanarROIMeasurements.self)
        register(TID1411VolumetricROIMeasurements.self)
        register(TID1419ROIMeasurements.self)
        register(TID1420MultipleROIMeasurements.self)
        register(TID1500MeasurementReport.self)
        register(TID1501MeasurementGroup.self)
        register(TID1600ImageLibrary.self)
    }
    
    /// Registers a template type
    /// - Parameter templateType: The template type to register
    public func register<T: SRTemplate>(_ templateType: T.Type) {
        storage.register(templateType)
    }
    
    /// Looks up a template by identifier
    /// - Parameter identifier: The template identifier
    /// - Returns: The template type if found
    public func template(for identifier: TemplateIdentifier) -> (any SRTemplate.Type)? {
        storage.template(for: identifier.templateID)
    }
    
    /// Looks up a template by TID number
    /// - Parameter tid: The template ID number
    /// - Returns: The template type if found
    public func template(tid: Int) -> (any SRTemplate.Type)? {
        template(for: TemplateIdentifier(tid: tid))
    }
    
    /// Returns all registered template identifiers
    public var registeredTemplates: [TemplateIdentifier] {
        storage.allTemplates().map { $0.identifier }
    }
}
