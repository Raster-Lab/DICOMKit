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
/// Reference: PS3.3 Section C.23.4 - Image Set Selector Module
public struct ImageSetDefinition: Sendable {
    /// Image set number (1-based)
    public let number: Int
    
    /// Optional label for the image set
    public let label: String?
    
    /// Selectors for filtering images
    public let selectors: [ImageSetSelector]
    
    /// Sort operations for ordering selected images
    public let sortOperations: [SortOperation]
    
    /// Category of image set selector
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
/// (PS3.3 Table C.23.4-1). `values` holds every VR as text: numeric VRs as
/// decimal, AT as "(GGGG,EEEE)", the byte VRs (OB/OW/OD/OF/OL/OV/UN) as one
/// hexadecimal string, and SQ as the Code Value of each `codeValues` item.
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
    
    /// Value number for multi-valued attributes (1-based)
    public let valueNumber: Int?
    
    /// Filter operator
    public let `operator`: FilterOperator?
    
    /// Expected values for the attribute
    public let values: [String]
    
    /// Selector Code Sequence Value (0072,0080) items, used when the
    /// attribute is a code sequence (`attributeVR == .SQ`).
    public let codeValues: [CodedConcept]
    
    /// Usage flag (MATCH, NO_MATCH)
    public let usageFlag: SelectorUsageFlag
    
    public init(
        attribute: Tag,
        attributeVR: VR? = nil,
        sequencePointer: Tag? = nil,
        valueNumber: Int? = nil,
        operator: FilterOperator? = nil,
        values: [String] = [],
        codeValues: [CodedConcept] = [],
        usageFlag: SelectorUsageFlag = .match
    ) {
        self.attribute = attribute
        self.attributeVR = attributeVR
        self.sequencePointer = sequencePointer
        self.valueNumber = valueNumber
        self.operator = `operator`
        self.values = values
        self.codeValues = codeValues
        self.usageFlag = usageFlag
    }
}

/// Selector usage flag
public enum SelectorUsageFlag: String, Sendable, Codable {
    /// Images must match this selector
    case match = "MATCH"
    
    /// Images must NOT match this selector
    case noMatch = "NO_MATCH"
}

/// Filter operator for attribute matching
public enum FilterOperator: String, Sendable, Codable {
    /// Equal to
    case equal = "EQUAL"
    
    /// Not equal to
    case notEqual = "NOT_EQUAL"
    
    /// Less than
    case lessThan = "LESS_THAN"
    
    /// Less than or equal
    case lessThanOrEqual = "LESS_THAN_OR_EQUAL"
    
    /// Greater than
    case greaterThan = "GREATER_THAN"
    
    /// Greater than or equal
    case greaterThanOrEqual = "GREATER_THAN_OR_EQUAL"
    
    /// Contains (for string matching)
    case contains = "CONTAINS"
    
    /// Attribute is present (value doesn't matter)
    case present = "PRESENT"
    
    /// Attribute is not present
    case notPresent = "NOT_PRESENT"
}

// MARK: - Image Set Selector Category

/// Category of image set selector
public enum ImageSetSelectorCategory: String, Sendable, Codable {
    /// Current study
    case current = "CURRENT"
    
    /// Prior study
    case prior = "PRIOR"
    
    /// Comparison study
    case comparison = "COMPARISON"
}

// MARK: - Time-Based Selection

/// Time-based selection for prior studies
public struct TimeBasedSelection: Sendable {
    /// Relative time offset from current study
    public let relativeTime: Int?
    
    /// Units for relative time
    public let relativeTimeUnits: RelativeTimeUnits?
    
    /// Abstract prior value (MOST_RECENT, OLDEST, etc.)
    public let abstractPriorValue: String?
    
    public init(
        relativeTime: Int? = nil,
        relativeTimeUnits: RelativeTimeUnits? = nil,
        abstractPriorValue: String? = nil
    ) {
        self.relativeTime = relativeTime
        self.relativeTimeUnits = relativeTimeUnits
        self.abstractPriorValue = abstractPriorValue
    }
}

/// Units for relative time measurements
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
public struct SortOperation: Sendable {
    /// Category to sort by
    public let sortByCategory: SortByCategory
    
    /// Sort direction
    public let direction: SortDirection
    
    /// DICOM attribute to sort by (when category is ATTRIBUTE)
    public let attribute: Tag?
    
    public init(
        sortByCategory: SortByCategory,
        direction: SortDirection = .ascending,
        attribute: Tag? = nil
    ) {
        self.sortByCategory = sortByCategory
        self.direction = direction
        self.attribute = attribute
    }
}

/// Category for sorting images
public enum SortByCategory: String, Sendable, Codable {
    /// Sort by instance number
    case instanceNumber = "INSTANCE_NUMBER"
    
    /// Sort by acquisition time
    case acquisitionTime = "ACQUISITION_TIME"
    
    /// Sort by image position (patient)
    case imagePosition = "IMAGE_POSITION"
    
    /// Sort by slice location
    case sliceLocation = "SLICE_LOCATION"
    
    /// Sort by specific DICOM attribute
    case attribute = "ATTRIBUTE"
}

/// Sort direction
public enum SortDirection: String, Sendable, Codable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}
