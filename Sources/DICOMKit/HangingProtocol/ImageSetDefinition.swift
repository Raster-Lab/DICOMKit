// NEMA-verified: 2026a, checked 2026-09-29 — Filter-by Operator, Filter-by Category, Filter-by Attribute Presence, Sort-by Category, Sorting Direction (PS3.3 Table C.23.3-1, C.23.3.1.1), Image Set Selector Usage Flag, Image Set Selector Category, Relative Time (US VM 2), Relative Time Units, Abstract Prior Value (SS VM 2) (Table C.23.1-1, PS3.6 Table 6-1)
//
// ImageSetDefinition.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Image Set Definition for Hanging Protocol
///
/// Defines criteria for selecting images from a study to be displayed together.
///
/// Reference: PS3.3 Table C.23.1-1 - Image Sets Sequence (0072,0020)
public struct ImageSetDefinition: Sendable {
    /// Image Set Number (0072,0032), 1-based
    public let number: Int

    /// Image Set Label (0072,0040)
    public let label: String?

    /// Selectors for filtering images
    public let selectors: [ImageSetSelector]

    /// Sort operations for ordering selected images
    public let sortOperations: [SortOperation]

    /// Image Set Selector Category (0072,0034)
    public let category: ImageSetSelectorCategory?

    /// Time-based selection for prior studies
    public let timeSelection: TimeBasedSelection?

    public init(
        number: Int,
        label: String? = nil,
        selectors: [ImageSetSelector] = [],
        sortOperations: [SortOperation] = [],
        category: ImageSetSelectorCategory? = nil,
        timeSelection: TimeBasedSelection? = nil
    ) {
        self.number = number
        self.label = label
        self.selectors = selectors
        self.sortOperations = sortOperations
        self.category = category
        self.timeSelection = timeSelection
    }
}

// MARK: - Image Set Selector

/// Selector for filtering images based on DICOM attributes
///
/// One item of the Image Set Selector Sequence (0072,0022). The attribute's
/// values are carried in the Selector *xx* Value element that matches
/// Selector Attribute VR (0072,0050), never in the attribute's own tag
/// (PS3.3 Table C.23.4-2). `values` holds every VR as text: numeric VRs as
/// decimal, AT as "(GGGG,EEEE)", the byte VRs (OB/OW/OD/OF/OL/OV/UN) as one
/// hexadecimal string, and SQ as the Code Value of each `codeValues` item.
///
/// `operator`, `filterByCategory` and `attributePresence` are the Filter
/// Operations Sequence (0072,0400) attributes of PS3.3 Table C.23.3-1; DICOMKit
/// carries them in the same selector item so one selector can both select and
/// filter. Their values are always the Table C.23.3-1 terms.
public struct ImageSetSelector: Sendable {
    /// DICOM tag to filter on — Selector Attribute (0072,0026)
    public let attribute: Tag

    /// Selector Attribute VR (0072,0050). `nil` means "look it up in the data
    /// dictionary when serialising", which covers every standard attribute; a
    /// private attribute needs it set explicitly before it can carry values.
    public let attributeVR: VR?

    /// Selector Sequence Pointer (0072,0052): the sequence that contains
    /// `attribute` when it is not a top-level attribute of the instance.
    public let sequencePointer: Tag?

    /// Selector Value Number (0072,0028): which value of a multi-valued
    /// attribute is compared (1 = first). Zero identifies any value.
    public let valueNumber: Int?

    /// Filter-by Operator (0072,0406)
    public let `operator`: FilterOperator?

    /// Filter-by Category (0072,0402). With `.imagePlane` the `values` are
    /// `ImagePlane` terms computed from Image Orientation (Patient) rather
    /// than the value of `attribute` (PS3.3 C.23.3.1.1).
    public let filterByCategory: FilterByCategory?

    /// Filter-by Attribute Presence (0072,0404): include the image according
    /// to whether `attribute` is present, instead of comparing values.
    public let attributePresence: FilterByAttributePresence?

    /// Expected values for the attribute
    public let values: [String]

    /// Selector Code Sequence Value (0072,0080) items, used when the
    /// attribute is a code sequence (`attributeVR == .SQ`).
    public let codeValues: [CodedConcept]

    /// Image Set Selector Usage Flag (0072,0024): what happens when the
    /// attribute is not available in the image.
    public let usageFlag: SelectorUsageFlag

    public init(
        attribute: Tag,
        attributeVR: VR? = nil,
        sequencePointer: Tag? = nil,
        valueNumber: Int? = nil,
        operator: FilterOperator? = nil,
        filterByCategory: FilterByCategory? = nil,
        attributePresence: FilterByAttributePresence? = nil,
        values: [String] = [],
        codeValues: [CodedConcept] = [],
        usageFlag: SelectorUsageFlag = .match
    ) {
        self.attribute = attribute
        self.attributeVR = attributeVR
        self.sequencePointer = sequencePointer
        self.valueNumber = valueNumber
        self.operator = `operator`
        self.filterByCategory = filterByCategory
        self.attributePresence = attributePresence
        self.values = values
        self.codeValues = codeValues
        self.usageFlag = usageFlag
    }
}

/// Image Set Selector Usage Flag (0072,0024)
///
/// PS3.3 Table C.23.1-1: behaviour of matching when Selector Attribute
/// (0072,0026) is not available in the image object.
public enum SelectorUsageFlag: String, Sendable, Codable {
    /// If the Attribute is not in the image object, consider the image to be a match anyway
    case match = "MATCH"

    /// If the Attribute is not in the image object, then do not consider the image to be a match
    case noMatch = "NO_MATCH"
}

/// Filter-by Operator (0072,0406)
///
/// PS3.3 Table C.23.3-1 Enumerated Values. The range and comparison operators
/// apply only to numeric Selector Attribute values; RANGE_INCL and RANGE_EXCL
/// need two selector values, the first less than or equal to the second.
public enum FilterOperator: String, Sendable, Codable {
    /// All values lie within the specified range, or are equal to the endpoints
    case rangeInclusive = "RANGE_INCL"

    /// All values lie outside the specified range, and are not equal to the endpoints
    case rangeExclusive = "RANGE_EXCL"

    /// All values are greater than or equal to the value of the selector
    case greaterThanOrEqual = "GREATER_OR_EQUAL"

    /// All values are less than or equal to the value of the selector
    case lessThanOrEqual = "LESS_OR_EQUAL"

    /// All values are greater than the value of the selector
    case greaterThan = "GREATER_THAN"

    /// All values are less than the value of the selector
    case lessThan = "LESS_THAN"

    /// One of the values in the image is present in the values of the
    /// selector; with one value in each this is an "equal to" operator
    case memberOf = "MEMBER_OF"

    /// None of the values in the image is present in the values of the
    /// selector; with one value in each this is a "not equal to" operator
    case notMemberOf = "NOT_MEMBER_OF"

    /// Not a Filter-by Operator term; serialised as MEMBER_OF.
    @available(*, deprecated, renamed: "memberOf", message: "EQUAL is not a Filter-by Operator (0072,0406) term in PS3.3 2026a Table C.23.3-1; MEMBER_OF with one value is \"equal to\"")
    case equal = "EQUAL"

    /// Not a Filter-by Operator term; serialised as NOT_MEMBER_OF.
    @available(*, deprecated, renamed: "notMemberOf", message: "NOT_EQUAL is not a Filter-by Operator (0072,0406) term in PS3.3 2026a Table C.23.3-1; NOT_MEMBER_OF with one value is \"not equal to\"")
    case notEqual = "NOT_EQUAL"

    /// Not a Filter-by Operator term; serialised as MEMBER_OF (PS3.3 C.23.1.1.3
    /// leaves exact versus partial matching of text implementation dependent).
    @available(*, deprecated, message: "CONTAINS is no Filter-by Operator (0072,0406) term in PS3.3 2026a Table C.23.3-1; use memberOf")
    case contains = "CONTAINS"

    /// Not a Filter-by Operator term; belongs to Filter-by Attribute Presence
    /// (0072,0404), which is where the serializer writes it.
    @available(*, deprecated, message: "PRESENT is a Filter-by Attribute Presence (0072,0404) term, not a Filter-by Operator; use ImageSetSelector.attributePresence = .present")
    case present = "PRESENT"

    /// Not a Filter-by Operator term; belongs to Filter-by Attribute Presence
    /// (0072,0404), which is where the serializer writes it.
    @available(*, deprecated, message: "NOT_PRESENT is a Filter-by Attribute Presence (0072,0404) term, not a Filter-by Operator; use ImageSetSelector.attributePresence = .notPresent")
    case notPresent = "NOT_PRESENT"

    /// The Table C.23.3-1 term written for this case, or nil when the case
    /// is carried by Filter-by Attribute Presence (0072,0404) instead.
    var standardTerm: FilterOperator? {
        switch self {
        case .rangeInclusive, .rangeExclusive, .greaterThanOrEqual, .lessThanOrEqual,
             .greaterThan, .lessThan, .memberOf, .notMemberOf:
            return self
        case .equal, .contains:
            return .memberOf
        case .notEqual:
            return .notMemberOf
        case .present, .notPresent:
            return nil
        }
    }

    /// The Filter-by Attribute Presence (0072,0404) value a deprecated
    /// presence case stands for.
    var presenceTerm: FilterByAttributePresence? {
        switch self {
        case .present: return .present
        case .notPresent: return .notPresent
        default: return nil
        }
    }

    /// Reads a Filter-by Operator value, accepting the spellings earlier
    /// DICOMKit versions wrote (EQUAL, NOT_EQUAL, CONTAINS) and mapping them
    /// to their Table C.23.3-1 equivalents. PRESENT / NOT_PRESENT read as nil
    /// here; see `FilterByAttributePresence`.
    static func reading(_ raw: String) -> FilterOperator? {
        let term = raw.trimmingCharacters(in: .whitespaces)
        switch term {
        case "EQUAL", "CONTAINS": return .memberOf
        case "NOT_EQUAL": return .notMemberOf
        case "PRESENT", "NOT_PRESENT": return nil
        default: return FilterOperator(rawValue: term)
        }
    }

    /// True for the operators PS3.3 Table C.23.3-1 restricts to numeric
    /// Selector Attribute values.
    public var isNumeric: Bool {
        switch self {
        case .rangeInclusive, .rangeExclusive, .greaterThanOrEqual, .lessThanOrEqual,
             .greaterThan, .lessThan:
            return true
        default:
            return false
        }
    }
}

/// Filter-by Category (0072,0402)
///
/// PS3.3 Table C.23.3-1 Defined Terms.
public enum FilterByCategory: String, Sendable, Codable {
    /// Filter on the image plane computed from Image Orientation (Patient);
    /// Selector Attribute VR shall be CS and the Selector CS Value holds
    /// `ImagePlane` terms (PS3.3 C.23.3.1.1).
    case imagePlane = "IMAGE_PLANE"
}

/// Filter-by Attribute Presence (0072,0404)
///
/// PS3.3 Table C.23.3-1 Enumerated Values.
public enum FilterByAttributePresence: String, Sendable, Codable {
    /// Include the image if the Attribute is present
    case present = "PRESENT"

    /// Include the image if the Attribute is not present
    case notPresent = "NOT_PRESENT"
}

/// Image plane category
///
/// PS3.3 C.23.3.1.1: the Enumerated Values of the Selector CS Value
/// (0072,0062) when Filter-by Category (0072,0402) is IMAGE_PLANE, and the
/// Defined Terms of Reformatting Operation Initial View Direction (0072,0516)
/// (Table C.23.3-1).
public enum ImagePlane: String, Sendable, Codable, CaseIterable {
    case transverse = "TRANSVERSE"
    case coronal = "CORONAL"
    case sagittal = "SAGITTAL"
    case oblique = "OBLIQUE"

    /// Reads a plane term, also accepting "AXIAL" (what earlier DICOMKit
    /// callers wrote) as TRANSVERSE.
    static func reading(_ raw: String) -> ImagePlane? {
        let term = raw.trimmingCharacters(in: .whitespaces)
        if term == "AXIAL" { return .transverse }
        return ImagePlane(rawValue: term)
    }

    /// Classifies an Image Orientation (Patient) (0020,0037) value by the
    /// normal-vector method of PS3.3 C.23.3.1.1: the cross product of the
    /// row and column cosines; the component with the largest magnitude
    /// above `threshold` names the plane (x: SAGITTAL, y: CORONAL,
    /// z: TRANSVERSE); all below threshold is OBLIQUE.
    public init?(imageOrientationPatient cosines: [Double], threshold: Double = 0.8) {
        guard cosines.count >= 6 else { return nil }
        let (rx, ry, rz) = (cosines[0], cosines[1], cosines[2])
        let (cx, cy, cz) = (cosines[3], cosines[4], cosines[5])
        let nx = ry * cz - rz * cy
        let ny = rz * cx - rx * cz
        let nz = rx * cy - ry * cx
        let ax = abs(nx), ay = abs(ny), az = abs(nz)
        let largest = max(ax, ay, az)
        guard largest > threshold else {
            self = .oblique
            return
        }
        if largest == ax {
            self = .sagittal
        } else if largest == ay {
            self = .coronal
        } else {
            self = .transverse
        }
    }
}

// MARK: - Image Set Selector Category

/// Image Set Selector Category (0072,0034)
///
/// PS3.3 Table C.23.1-1 Enumerated Values (Time Based Image Sets Sequence).
public enum ImageSetSelectorCategory: String, Sendable, Codable {
    /// Selection by Relative Time (0072,0038) and Relative Time Units
    /// (0072,003A); the pair 0\0 is the current image set.
    case relativeTime = "RELATIVE_TIME"

    /// Selection by Abstract Prior Value (0072,003C) or Abstract Prior Code
    /// Sequence (0072,003E).
    case abstractPrior = "ABSTRACT_PRIOR"

    /// Not a term; serialised as RELATIVE_TIME (the pair 0\0 denotes a
    /// current image set, PS3.3 Table C.23.1-1 Relative Time).
    @available(*, deprecated, message: "CURRENT is not an Image Set Selector Category (0072,0034) term in PS3.3 2026a Table C.23.1-1; use relativeTime with Relative Time 0\\0")
    case current = "CURRENT"

    /// Not a term; serialised as ABSTRACT_PRIOR.
    @available(*, deprecated, renamed: "abstractPrior", message: "PRIOR is not an Image Set Selector Category (0072,0034) term in PS3.3 2026a Table C.23.1-1")
    case prior = "PRIOR"

    /// Not a term; serialised as ABSTRACT_PRIOR.
    @available(*, deprecated, renamed: "abstractPrior", message: "COMPARISON is not an Image Set Selector Category (0072,0034) term in PS3.3 2026a Table C.23.1-1")
    case comparison = "COMPARISON"

    /// The Table C.23.1-1 term written for this case.
    var standardTerm: ImageSetSelectorCategory {
        switch self {
        case .relativeTime, .abstractPrior: return self
        case .current: return .relativeTime
        case .prior, .comparison: return .abstractPrior
        }
    }

    /// Reads a category, mapping the old DICOMKit spellings.
    static func reading(_ raw: String) -> ImageSetSelectorCategory? {
        let term = raw.trimmingCharacters(in: .whitespaces)
        switch term {
        case "CURRENT": return .relativeTime
        case "PRIOR", "COMPARISON": return .abstractPrior
        default: return ImageSetSelectorCategory(rawValue: term)
        }
    }
}

// MARK: - Time-Based Selection

/// Time-based selection for prior studies
///
/// The Relative Time / Abstract Prior attributes of a Time Based Image Sets
/// Sequence (0072,0030) item, PS3.3 Table C.23.1-1.
public struct TimeBasedSelection: Sendable {
    /// Relative Time (0072,0038), US VM 2: the start and end of a prior range
    /// of acquisition times relative to the current image set, in
    /// `relativeTimeUnits`. 0\0 is the current image set; n\n is "prior by n
    /// units". Empty when absent.
    public let relativeTimeRange: [Int]

    /// Relative Time Units (0072,003A)
    public let relativeTimeUnits: RelativeTimeUnits?

    /// Abstract Prior Value (0072,003C), SS VM 2: the range of prior studies
    /// to include, where 1 is the most recent prior, higher values are
    /// successively older priors and -1 is the oldest prior. Empty when
    /// absent.
    public let abstractPriorRange: [Int]

    /// The most-recent-prior end of `abstractPriorRange`.
    public static let mostRecentPrior = 1

    /// The special Abstract Prior Value that indicates the oldest prior.
    public static let oldestPrior = -1

    public init(
        relativeTimeRange: [Int] = [],
        relativeTimeUnits: RelativeTimeUnits? = nil,
        abstractPriorRange: [Int] = []
    ) {
        self.relativeTimeRange = relativeTimeRange
        self.relativeTimeUnits = relativeTimeUnits
        self.abstractPriorRange = abstractPriorRange
    }

    /// A single relative time n is stored as the pair n\n (PS3.3 Table
    /// C.23.1-1: "prior from the current image set by n units").
    @available(*, deprecated, message: "Relative Time (0072,0038) is VM 2 in PS3.3 2026a; use init(relativeTimeRange:relativeTimeUnits:abstractPriorRange:)")
    public init(
        relativeTime: Int,
        relativeTimeUnits: RelativeTimeUnits? = nil,
        abstractPriorValue: String? = nil
    ) {
        self.relativeTimeRange = [relativeTime, relativeTime]
        self.relativeTimeUnits = relativeTimeUnits
        self.abstractPriorRange = Self.abstractPriorRange(from: abstractPriorValue)
    }

    /// Accepts "MOST_RECENT" (1\1), "OLDEST" (-1\-1), "n" (n\n) or "a\b";
    /// any other text has no Abstract Prior Value (0072,003C) encoding and
    /// is dropped.
    @available(*, deprecated, message: "Abstract Prior Value (0072,003C) is SS VM 2 in PS3.3 2026a; use init(relativeTimeRange:relativeTimeUnits:abstractPriorRange:)")
    public init(
        abstractPriorValue: String,
        relativeTimeUnits: RelativeTimeUnits? = nil
    ) {
        self.relativeTimeRange = []
        self.relativeTimeUnits = relativeTimeUnits
        self.abstractPriorRange = Self.abstractPriorRange(from: abstractPriorValue)
    }

    /// The first value of `relativeTimeRange`.
    @available(*, deprecated, renamed: "relativeTimeRange")
    public var relativeTime: Int? { relativeTimeRange.first }

    /// `abstractPriorRange` as text: "MOST_RECENT" for 1\1, "OLDEST" for
    /// -1\-1, otherwise the values joined by a backslash.
    @available(*, deprecated, renamed: "abstractPriorRange")
    public var abstractPriorValue: String? {
        guard !abstractPriorRange.isEmpty else { return nil }
        if abstractPriorRange == [Self.mostRecentPrior, Self.mostRecentPrior] { return "MOST_RECENT" }
        if abstractPriorRange == [Self.oldestPrior, Self.oldestPrior] { return "OLDEST" }
        return abstractPriorRange.map(String.init).joined(separator: "\\")
    }

    /// Maps the text an earlier DICOMKit version wrote to (0072,003C) onto
    /// the SS pair of PS3.3 Table C.23.1-1.
    static func abstractPriorRange(from text: String?) -> [Int] {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return [] }
        switch text {
        case "MOST_RECENT": return [mostRecentPrior, mostRecentPrior]
        case "OLDEST": return [oldestPrior, oldestPrior]
        default:
            let parts = text.split(separator: "\\").map { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return [] }
            let ints = parts.compactMap { $0 }
            return ints.count == 1 ? [ints[0], ints[0]] : ints
        }
    }
}

/// Relative Time Units (0072,003A)
///
/// PS3.3 Table C.23.1-1 Enumerated Values.
public enum RelativeTimeUnits: String, Sendable, Codable {
    case seconds = "SECONDS"
    case minutes = "MINUTES"
    case hours = "HOURS"
    case days = "DAYS"
    case weeks = "WEEKS"
    case months = "MONTHS"
    case years = "YEARS"
}

// MARK: - Sort Operation

/// Sort operation for ordering images in an image set
///
/// One item of the Sorting Operations Sequence (0072,0600), PS3.3 Table
/// C.23.3-1: either a Sort-by Category (0072,0602) or a Selector Attribute
/// (0072,0026) with Selector Value Number (0072,0028), plus the Sorting
/// Direction (0072,0604).
public struct SortOperation: Sendable {
    /// Sort-by Category (0072,0602); nil when sorting by `attribute`
    public let sortByCategory: SortByCategory?

    /// Sorting Direction (0072,0604)
    public let direction: SortDirection

    /// Selector Attribute (0072,0026) to sort by, when no category is used
    public let attribute: Tag?

    /// Selector Value Number (0072,0028): which value of `attribute` is
    /// sorted on (1 = first; shall not be zero)
    public let valueNumber: Int?

    /// Sort by an abstract category.
    public init(
        sortByCategory: SortByCategory,
        direction: SortDirection = .ascending,
        attribute: Tag? = nil
    ) {
        self.sortByCategory = sortByCategory
        self.direction = direction
        self.attribute = attribute
        self.valueNumber = attribute == nil ? nil : 1
    }

    /// Sort by the value of an attribute.
    public init(
        attribute: Tag,
        valueNumber: Int = 1,
        direction: SortDirection = .ascending
    ) {
        self.sortByCategory = nil
        self.direction = direction
        self.attribute = attribute
        self.valueNumber = valueNumber
    }

    /// The (category, attribute, value number) actually written: deprecated
    /// categories that name an attribute become a Selector Attribute sort.
    var standardized: (category: SortByCategory?, attribute: Tag?, valueNumber: Int?) {
        guard let category = sortByCategory else {
            return (nil, attribute, attribute == nil ? nil : (valueNumber ?? 1))
        }
        switch category {
        case .alongAxis, .byAcquisitionTime:
            return (category, nil, nil)
        case .imagePosition:
            return (.alongAxis, nil, nil)
        case .acquisitionTime:
            return (.byAcquisitionTime, nil, nil)
        case .instanceNumber:
            return (nil, .instanceNumber, 1)
        case .sliceLocation:
            return (nil, .sliceLocation, 1)
        case .attribute:
            return (nil, attribute, attribute == nil ? nil : (valueNumber ?? 1))
        }
    }
}

/// Sort-by Category (0072,0602)
///
/// PS3.3 Table C.23.3-1 Defined Terms. Sorting on the value of a specific
/// attribute uses Selector Attribute (0072,0026) instead of a category
/// (`SortOperation.init(attribute:valueNumber:direction:)`).
public enum SortByCategory: String, Sendable, Codable {
    /// For CT, MR, other cross-sectional image sets: along the dominant axis
    /// computed from Image Position (Patient) and Image Orientation (Patient)
    /// (PS3.3 C.23.3.1.2)
    case alongAxis = "ALONG_AXIS"

    /// By acquisition time, from whichever time attribute the instance
    /// carries (PS3.3 C.23.3.1.2)
    case byAcquisitionTime = "BY_ACQ_TIME"

    /// Not a term; serialised as Selector Attribute (0020,0013) with
    /// Selector Value Number 1 and no Sort-by Category.
    @available(*, deprecated, message: "INSTANCE_NUMBER is not a Sort-by Category (0072,0602) term in PS3.3 2026a Table C.23.3-1; use SortOperation(attribute: .instanceNumber)")
    case instanceNumber = "INSTANCE_NUMBER"

    /// Not a term; serialised as BY_ACQ_TIME.
    @available(*, deprecated, renamed: "byAcquisitionTime", message: "ACQUISITION_TIME is not a Sort-by Category (0072,0602) term in PS3.3 2026a Table C.23.3-1")
    case acquisitionTime = "ACQUISITION_TIME"

    /// Not a term; serialised as ALONG_AXIS.
    @available(*, deprecated, renamed: "alongAxis", message: "IMAGE_POSITION is not a Sort-by Category (0072,0602) term in PS3.3 2026a Table C.23.3-1")
    case imagePosition = "IMAGE_POSITION"

    /// Not a term; serialised as Selector Attribute (0020,1041) with
    /// Selector Value Number 1 and no Sort-by Category.
    @available(*, deprecated, message: "SLICE_LOCATION is not a Sort-by Category (0072,0602) term in PS3.3 2026a Table C.23.3-1; use SortOperation(attribute: .sliceLocation)")
    case sliceLocation = "SLICE_LOCATION"

    /// Not a term; serialised as a Selector Attribute sort with no
    /// Sort-by Category.
    @available(*, deprecated, message: "ATTRIBUTE is not a Sort-by Category (0072,0602) term in PS3.3 2026a Table C.23.3-1; use SortOperation(attribute:valueNumber:direction:)")
    case attribute = "ATTRIBUTE"
}

/// Sorting Direction (0072,0604)
///
/// PS3.3 Table C.23.3-1 Enumerated Values.
public enum SortDirection: String, Sendable, Codable {
    case ascending = "INCREASING"
    case descending = "DECREASING"
}
