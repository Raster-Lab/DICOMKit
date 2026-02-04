/// DICOM Content Item Protocol
///
/// Defines the common interface for all content items in DICOM Structured Reporting.
/// Content items form a tree structure representing the document content.
///
/// Reference: PS3.3 Section C.17.3 - SR Document Content Module

/// Protocol defining common properties and behaviors for all SR content items
public protocol ContentItem: Sendable, Equatable {
    /// The value type of this content item
    var valueType: ContentItemValueType { get }
    
    /// The concept name that describes what this content item represents
    /// Encoded as Concept Name Code Sequence (0040,A043)
    var conceptName: CodedConcept? { get }
    
    /// The relationship type to the parent content item
    /// Encoded as Relationship Type (0040,A010)
    var relationshipType: RelationshipType? { get }
    
    /// Optional observation date/time for this content item
    /// Encoded as Observation DateTime (0040,A032)
    var observationDateTime: String? { get }
    
    /// Optional observation UID for unique identification
    /// Encoded as Observation UID (0040,A171)
    var observationUID: String? { get }
    
    /// Returns whether this content item can have children
    var canHaveChildren: Bool { get }
}

// MARK: - Default Implementations

extension ContentItem {
    public var canHaveChildren: Bool {
        valueType.canHaveChildren
    }
}

// MARK: - Continuity of Content

/// Continuity of Content for CONTAINER content items
///
/// Specifies whether the content items within a CONTAINER form a continuous narrative
/// or are separate items.
public enum ContinuityOfContent: String, Sendable, Equatable, Hashable {
    /// SEPARATE - Items are logically separate (like a list)
    case separate = "SEPARATE"
    
    /// CONTINUOUS - Items form a continuous narrative
    case continuous = "CONTINUOUS"
}

// MARK: - Graphic Type for Spatial Coordinates

/// Graphic types for SCOORD spatial coordinates
///
/// Defines the shape described by 2D spatial coordinates.
/// Reference: PS3.3 Table C.18.6-1
public enum GraphicType: String, Sendable, Equatable, Hashable, CaseIterable {
    /// A single point
    case point = "POINT"
    
    /// Multiple points connected by straight lines
    case polyline = "POLYLINE"
    
    /// Multiple points connected by straight lines forming a closed polygon
    case polygon = "POLYGON"
    
    /// An ellipse defined by four points
    case ellipse = "ELLIPSE"
    
    /// A circle defined by center and a point on the circumference
    case circle = "CIRCLE"
    
    /// Multiple disconnected points
    case multipoint = "MULTIPOINT"
    
    /// Returns the minimum number of points required
    public var minimumPoints: Int {
        switch self {
        case .point: return 1
        case .multipoint: return 2
        case .polyline: return 2
        case .polygon: return 3
        case .circle: return 2
        case .ellipse: return 4
        }
    }
}

/// Graphic types for SCOORD3D spatial coordinates
///
/// Defines the shape described by 3D spatial coordinates.
/// Reference: PS3.3 Table C.18.9-1
public enum GraphicType3D: String, Sendable, Equatable, Hashable, CaseIterable {
    /// A single point
    case point = "POINT"
    
    /// Multiple points connected by straight lines
    case polyline = "POLYLINE"
    
    /// Multiple points connected by straight lines forming a closed polygon
    case polygon = "POLYGON"
    
    /// An ellipse defined by four points
    case ellipse = "ELLIPSE"
    
    /// An ellipsoid defined by six points
    case ellipsoid = "ELLIPSOID"
    
    /// Multiple disconnected points
    case multipoint = "MULTIPOINT"
    
    /// Returns the minimum number of points required
    public var minimumPoints: Int {
        switch self {
        case .point: return 1
        case .multipoint: return 2
        case .polyline: return 2
        case .polygon: return 3
        case .ellipse: return 4
        case .ellipsoid: return 6
        }
    }
}

/// Temporal range types for TCOORD temporal coordinates
///
/// Defines how temporal coordinates should be interpreted.
/// Reference: PS3.3 Table C.18.7-1
public enum TemporalRangeType: String, Sendable, Equatable, Hashable, CaseIterable {
    /// A single point in time
    case point = "POINT"
    
    /// Multiple disconnected points in time
    case multipoint = "MULTIPOINT"
    
    /// Multiple segments (ranges) of time
    case segment = "SEGMENT"
    
    /// Multiple segments specified by begin only
    case beginSegment = "BEGIN"
    
    /// Multiple segments specified by end only
    case endSegment = "END"
}

// MARK: - Numeric Value Qualifier

/// Qualifier for numeric content items indicating special values
///
/// Used when a measurement cannot be made normally.
public enum NumericValueQualifier: String, Sendable, Equatable, Hashable {
    /// Value is not a number (result of division by zero, etc.)
    case notANumber = "NOT A NUMBER"
    
    /// Value is negative infinity
    case negativeInfinity = "NEGATIVE INFINITY"
    
    /// Value is positive infinity
    case positiveInfinity = "POSITIVE INFINITY"
    
    /// Value underflows the representable range
    case underflow = "UNDERFLOW"
    
    /// Value overflows the representable range
    case overflow = "OVERFLOW"
}

// MARK: - SOP Reference for SR

/// Reference to a DICOM SOP Instance for Structured Reporting
///
/// Used by COMPOSITE, IMAGE, and WAVEFORM content items to reference DICOM objects.
/// Named differently from DICOMNetwork.SOPReference to avoid ambiguity.
public struct ReferencedSOP: Sendable, Equatable, Hashable {
    /// SOP Class UID of the referenced instance
    public let sopClassUID: String
    
    /// SOP Instance UID of the referenced instance
    public let sopInstanceUID: String
    
    /// Creates a SOP reference
    /// - Parameters:
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID
    public init(sopClassUID: String, sopInstanceUID: String) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
    }
}

/// Reference to a DICOM image with optional frame specification
public struct ImageReference: Sendable, Equatable, Hashable {
    /// The SOP reference
    public let sopReference: ReferencedSOP
    
    /// Optional frame numbers (for multi-frame images)
    public let frameNumbers: [Int]?
    
    /// Optional segment numbers (for segmentation objects)
    public let segmentNumbers: [Int]?
    
    /// Optional purpose of reference
    public let purposeOfReference: CodedConcept?
    
    /// Creates an image reference
    /// - Parameters:
    ///   - sopReference: The SOP reference
    ///   - frameNumbers: Optional frame numbers
    ///   - segmentNumbers: Optional segment numbers
    ///   - purposeOfReference: Optional purpose of reference
    public init(
        sopReference: ReferencedSOP,
        frameNumbers: [Int]? = nil,
        segmentNumbers: [Int]? = nil,
        purposeOfReference: CodedConcept? = nil
    ) {
        self.sopReference = sopReference
        self.frameNumbers = frameNumbers
        self.segmentNumbers = segmentNumbers
        self.purposeOfReference = purposeOfReference
    }
    
    /// Creates an image reference with just UIDs
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil
    ) {
        self.sopReference = ReferencedSOP(sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID)
        self.frameNumbers = frameNumbers
        self.segmentNumbers = nil
        self.purposeOfReference = nil
    }
}

/// Reference to waveform data with optional channel specification
public struct WaveformReference: Sendable, Equatable, Hashable {
    /// The SOP reference
    public let sopReference: ReferencedSOP
    
    /// Optional channel numbers
    public let channelNumbers: [Int]?
    
    /// Creates a waveform reference
    /// - Parameters:
    ///   - sopReference: The SOP reference
    ///   - channelNumbers: Optional channel numbers
    public init(sopReference: ReferencedSOP, channelNumbers: [Int]? = nil) {
        self.sopReference = sopReference
        self.channelNumbers = channelNumbers
    }
}
