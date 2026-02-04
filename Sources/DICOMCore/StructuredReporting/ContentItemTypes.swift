/// DICOM Structured Reporting Content Item Types
///
/// Concrete implementations of all DICOM SR content item value types.
///
/// Reference: PS3.3 Table C.17.3-1 - Value Type Definitions

// MARK: - Text Content Item

/// TEXT content item - contains unstructured free text
///
/// Reference: PS3.3 Section C.17.3.2.1
public struct TextContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .text
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The text value (0040,A160)
    public let textValue: String
    
    /// Creates a text content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - textValue: The text content
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        textValue: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.textValue = textValue
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Code Content Item

/// CODE content item - contains a coded concept value
///
/// Reference: PS3.3 Section C.17.3.2.2
public struct CodeContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .code
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The coded concept value (0040,A168)
    public let conceptCode: CodedConcept
    
    /// Creates a code content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - conceptCode: The coded value
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        conceptCode: CodedConcept,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.conceptCode = conceptCode
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Numeric Content Item

/// NUM content item - contains a numeric measurement with units
///
/// Reference: PS3.3 Section C.17.3.2.3
public struct NumericContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .num
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The numeric value(s) (0040,A30A) as decimal strings
    public let numericValues: [Double]
    
    /// The measurement units (0040,08EA)
    public let measurementUnits: CodedConcept?
    
    /// Optional floating point values (0040,A161)
    public let floatingPointValues: [Double]?
    
    /// Optional qualifier for special values
    public let numericValueQualifier: NumericValueQualifier?
    
    /// Creates a numeric content item with a single value
    /// - Parameters:
    ///   - conceptName: The concept name describing this measurement
    ///   - value: The numeric value
    ///   - units: The measurement units
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        value: Double,
        units: CodedConcept? = nil,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.numericValues = [value]
        self.measurementUnits = units
        self.floatingPointValues = nil
        self.numericValueQualifier = nil
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Creates a numeric content item with multiple values
    /// - Parameters:
    ///   - conceptName: The concept name describing this measurement
    ///   - values: The numeric values
    ///   - units: The measurement units
    ///   - floatingPointValues: Optional high-precision floating point values
    ///   - qualifier: Optional qualifier for special values
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        values: [Double],
        units: CodedConcept? = nil,
        floatingPointValues: [Double]? = nil,
        qualifier: NumericValueQualifier? = nil,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.numericValues = values
        self.measurementUnits = units
        self.floatingPointValues = floatingPointValues
        self.numericValueQualifier = qualifier
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// The primary numeric value (first value if multiple)
    public var value: Double? {
        numericValues.first
    }
}

// MARK: - Date Content Item

/// DATE content item - contains a date value
///
/// Reference: PS3.3 Section C.17.3.2.4
public struct DateContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .date
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The date value (0040,A121) in DICOM DA format (YYYYMMDD)
    public let dateValue: String
    
    /// Creates a date content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - dateValue: The date value in DICOM DA format
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        dateValue: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.dateValue = dateValue
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Time Content Item

/// TIME content item - contains a time value
///
/// Reference: PS3.3 Section C.17.3.2.5
public struct TimeContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .time
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The time value (0040,A122) in DICOM TM format (HHMMSS.FFFFFF)
    public let timeValue: String
    
    /// Creates a time content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - timeValue: The time value in DICOM TM format
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        timeValue: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.timeValue = timeValue
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - DateTime Content Item

/// DATETIME content item - contains a combined date/time value
///
/// Reference: PS3.3 Section C.17.3.2.6
public struct DateTimeContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .datetime
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The datetime value (0040,A120) in DICOM DT format
    public let dateTimeValue: String
    
    /// Creates a datetime content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - dateTimeValue: The datetime value in DICOM DT format
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        dateTimeValue: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.dateTimeValue = dateTimeValue
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Person Name Content Item

/// PNAME content item - contains a person name value
///
/// Reference: PS3.3 Section C.17.3.2.7
public struct PersonNameContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .pname
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The person name value (0040,A123) in DICOM PN format
    public let personName: String
    
    /// Creates a person name content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - personName: The person name in DICOM PN format
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        personName: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.personName = personName
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - UID Reference Content Item

/// UIDREF content item - contains a DICOM UID reference
///
/// Reference: PS3.3 Section C.17.3.2.8
public struct UIDRefContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .uidref
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The UID value (0040,A124)
    public let uidValue: String
    
    /// Creates a UID reference content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - uidValue: The UID value
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        uidValue: String,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.uidValue = uidValue
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Composite Content Item

/// COMPOSITE content item - references a DICOM composite SOP instance
///
/// Reference: PS3.3 Section C.17.3.2.9
public struct CompositeContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .composite
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The referenced SOP instance
    public let referencedSOPSequence: ReferencedSOP
    
    /// Creates a composite content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - referencedSOPSequence: The SOP reference
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        referencedSOPSequence: ReferencedSOP,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.referencedSOPSequence = referencedSOPSequence
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Convenience initializer with UIDs
    public init(
        conceptName: CodedConcept? = nil,
        sopClassUID: String,
        sopInstanceUID: String,
        relationshipType: RelationshipType? = nil
    ) {
        self.conceptName = conceptName
        self.referencedSOPSequence = ReferencedSOP(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID
        )
        self.relationshipType = relationshipType
        self.observationDateTime = nil
        self.observationUID = nil
    }
}

// MARK: - Image Content Item

/// IMAGE content item - references a DICOM image, optionally with frames
///
/// Reference: PS3.3 Section C.17.3.2.10
public struct ImageContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .image
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The image reference
    public let imageReference: ImageReference
    
    /// Creates an image content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - imageReference: The image reference
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        imageReference: ImageReference,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.imageReference = imageReference
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Convenience initializer with UIDs
    public init(
        conceptName: CodedConcept? = nil,
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil,
        relationshipType: RelationshipType? = nil
    ) {
        self.conceptName = conceptName
        self.imageReference = ImageReference(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            frameNumbers: frameNumbers
        )
        self.relationshipType = relationshipType
        self.observationDateTime = nil
        self.observationUID = nil
    }
}

// MARK: - Waveform Content Item

/// WAVEFORM content item - references waveform data
///
/// Reference: PS3.3 Section C.17.3.2.11
public struct WaveformContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .waveform
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The waveform reference
    public let waveformReference: WaveformReference
    
    /// Creates a waveform content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - waveformReference: The waveform reference
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        waveformReference: WaveformReference,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.waveformReference = waveformReference
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
}

// MARK: - Spatial Coordinates Content Item (2D)

/// SCOORD content item - contains 2D spatial coordinates
///
/// Reference: PS3.3 Section C.17.3.2.12
public struct SpatialCoordinatesContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .scoord
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The graphic type defining the shape
    public let graphicType: GraphicType
    
    /// The coordinate data as pairs of (column, row)
    /// Encoded as Graphic Data (0070,0022)
    public let graphicData: [Float]
    
    /// Creates a spatial coordinates content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - graphicType: The type of graphic (point, polyline, etc.)
    ///   - graphicData: The coordinate data as [col1, row1, col2, row2, ...]
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        graphicType: GraphicType,
        graphicData: [Float],
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.graphicType = graphicType
        self.graphicData = graphicData
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Returns the number of points in the coordinate data
    public var pointCount: Int {
        graphicData.count / 2
    }
    
    /// Returns the coordinates as an array of (column, row) tuples
    public var points: [(column: Float, row: Float)] {
        stride(from: 0, to: graphicData.count, by: 2).map { i in
            (column: graphicData[i], row: graphicData[i + 1])
        }
    }
}

// MARK: - Spatial Coordinates 3D Content Item

/// SCOORD3D content item - contains 3D spatial coordinates
///
/// Reference: PS3.3 Section C.17.3.2.13
public struct SpatialCoordinates3DContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .scoord3D
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The graphic type defining the shape
    public let graphicType: GraphicType3D
    
    /// The coordinate data as triplets of (x, y, z) in patient coordinates
    /// Encoded as Graphic Data (0070,0022)
    public let graphicData: [Float]
    
    /// Frame of Reference UID for the coordinate system
    public let frameOfReferenceUID: String?
    
    /// Creates a 3D spatial coordinates content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - graphicType: The type of graphic (point, polyline, etc.)
    ///   - graphicData: The coordinate data as [x1, y1, z1, x2, y2, z2, ...]
    ///   - frameOfReferenceUID: Optional Frame of Reference UID
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        graphicType: GraphicType3D,
        graphicData: [Float],
        frameOfReferenceUID: String? = nil,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.graphicType = graphicType
        self.graphicData = graphicData
        self.frameOfReferenceUID = frameOfReferenceUID
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Returns the number of points in the coordinate data
    public var pointCount: Int {
        graphicData.count / 3
    }
    
    /// Returns the coordinates as an array of (x, y, z) tuples
    public var points: [(x: Float, y: Float, z: Float)] {
        stride(from: 0, to: graphicData.count, by: 3).map { i in
            (x: graphicData[i], y: graphicData[i + 1], z: graphicData[i + 2])
        }
    }
}

// MARK: - Temporal Coordinates Content Item

/// TCOORD content item - contains temporal coordinates
///
/// Reference: PS3.3 Section C.17.3.2.14
public struct TemporalCoordinatesContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .tcoord
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// The temporal range type
    public let temporalRangeType: TemporalRangeType
    
    /// Sample positions (for waveform data)
    public let referencedSamplePositions: [UInt32]?
    
    /// Time offsets in seconds
    public let referencedTimeOffsets: [Double]?
    
    /// DateTime values
    public let referencedDateTime: [String]?
    
    /// Creates a temporal coordinates content item with sample positions
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - temporalRangeType: The type of temporal range
    ///   - samplePositions: Sample positions for waveform data
    ///   - relationshipType: Relationship to parent
    public init(
        conceptName: CodedConcept? = nil,
        temporalRangeType: TemporalRangeType,
        samplePositions: [UInt32],
        relationshipType: RelationshipType? = nil
    ) {
        self.conceptName = conceptName
        self.temporalRangeType = temporalRangeType
        self.referencedSamplePositions = samplePositions
        self.referencedTimeOffsets = nil
        self.referencedDateTime = nil
        self.relationshipType = relationshipType
        self.observationDateTime = nil
        self.observationUID = nil
    }
    
    /// Creates a temporal coordinates content item with time offsets
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - temporalRangeType: The type of temporal range
    ///   - timeOffsets: Time offsets in seconds
    ///   - relationshipType: Relationship to parent
    public init(
        conceptName: CodedConcept? = nil,
        temporalRangeType: TemporalRangeType,
        timeOffsets: [Double],
        relationshipType: RelationshipType? = nil
    ) {
        self.conceptName = conceptName
        self.temporalRangeType = temporalRangeType
        self.referencedSamplePositions = nil
        self.referencedTimeOffsets = timeOffsets
        self.referencedDateTime = nil
        self.relationshipType = relationshipType
        self.observationDateTime = nil
        self.observationUID = nil
    }
    
    /// Creates a temporal coordinates content item with datetime values
    /// - Parameters:
    ///   - conceptName: The concept name describing this item
    ///   - temporalRangeType: The type of temporal range
    ///   - dateTimes: DateTime values in DICOM DT format
    ///   - relationshipType: Relationship to parent
    public init(
        conceptName: CodedConcept? = nil,
        temporalRangeType: TemporalRangeType,
        dateTimes: [String],
        relationshipType: RelationshipType? = nil
    ) {
        self.conceptName = conceptName
        self.temporalRangeType = temporalRangeType
        self.referencedSamplePositions = nil
        self.referencedTimeOffsets = nil
        self.referencedDateTime = dateTimes
        self.relationshipType = relationshipType
        self.observationDateTime = nil
        self.observationUID = nil
    }
}

// MARK: - Container Content Item

/// CONTAINER content item - groups other content items
///
/// Reference: PS3.3 Section C.17.3.2.15
public struct ContainerContentItem: ContentItem, Sendable, Equatable, Hashable {
    public let valueType: ContentItemValueType = .container
    public let conceptName: CodedConcept?
    public let relationshipType: RelationshipType?
    public let observationDateTime: String?
    public let observationUID: String?
    
    /// Continuity of content within this container
    public let continuityOfContent: ContinuityOfContent
    
    /// Child content items contained in this container
    public let contentItems: [AnyContentItem]
    
    /// Optional template identifier for this container
    public let templateIdentifier: String?
    
    /// Optional mapping resource for template
    public let mappingResource: String?
    
    /// Creates a container content item
    /// - Parameters:
    ///   - conceptName: The concept name describing this container
    ///   - continuityOfContent: Whether items are separate or continuous
    ///   - contentItems: Child content items
    ///   - templateIdentifier: Optional TID
    ///   - mappingResource: Optional mapping resource
    ///   - relationshipType: Relationship to parent
    ///   - observationDateTime: Optional observation date/time
    ///   - observationUID: Optional observation UID
    public init(
        conceptName: CodedConcept? = nil,
        continuityOfContent: ContinuityOfContent = .separate,
        contentItems: [AnyContentItem] = [],
        templateIdentifier: String? = nil,
        mappingResource: String? = nil,
        relationshipType: RelationshipType? = nil,
        observationDateTime: String? = nil,
        observationUID: String? = nil
    ) {
        self.conceptName = conceptName
        self.continuityOfContent = continuityOfContent
        self.contentItems = contentItems
        self.templateIdentifier = templateIdentifier
        self.mappingResource = mappingResource
        self.relationshipType = relationshipType
        self.observationDateTime = observationDateTime
        self.observationUID = observationUID
    }
    
    /// Creates a new container with additional content items
    public func adding(_ items: [AnyContentItem]) -> ContainerContentItem {
        ContainerContentItem(
            conceptName: conceptName,
            continuityOfContent: continuityOfContent,
            contentItems: contentItems + items,
            templateIdentifier: templateIdentifier,
            mappingResource: mappingResource,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        )
    }
    
    /// Returns whether this container is empty
    public var isEmpty: Bool {
        contentItems.isEmpty
    }
    
    /// Returns the count of direct children
    public var childCount: Int {
        contentItems.count
    }
}
