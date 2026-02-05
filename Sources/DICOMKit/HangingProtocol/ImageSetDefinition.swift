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
public struct ImageSetSelector: Sendable {
    /// DICOM tag to filter on
    public let attribute: Tag
    
    /// Value number for multi-valued attributes (1-based)
    public let valueNumber: Int?
    
    /// Filter operator
    public let `operator`: FilterOperator?
    
    /// Expected values for the attribute
    public let values: [String]
    
    /// Usage flag (MATCH, NO_MATCH)
    public let usageFlag: SelectorUsageFlag
    
    public init(
        attribute: Tag,
        valueNumber: Int? = nil,
        operator: FilterOperator? = nil,
        values: [String] = [],
        usageFlag: SelectorUsageFlag = .match
    ) {
        self.attribute = attribute
        self.valueNumber = valueNumber
        self.operator = `operator`
        self.values = values
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
