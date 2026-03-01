// LibraryFilter.swift
// DICOMStudio
//
// DICOM Studio — Filter criteria for library browsing

import Foundation

/// Filter criteria for browsing the DICOM library.
public struct LibraryFilter: Sendable, Equatable {
    /// Filter by modality (empty means all modalities).
    public var modalities: Set<String>

    /// Filter by date range start.
    public var dateFrom: Date?

    /// Filter by date range end.
    public var dateTo: Date?

    /// Filter by patient name (case-insensitive substring match).
    public var patientName: String

    /// Full-text search across all metadata fields.
    public var searchText: String

    /// Whether any filter is active.
    public var isActive: Bool {
        !modalities.isEmpty || dateFrom != nil || dateTo != nil ||
        !patientName.isEmpty || !searchText.isEmpty
    }

    /// Creates a filter with default (no filter) values.
    public init(
        modalities: Set<String> = [],
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        patientName: String = "",
        searchText: String = ""
    ) {
        self.modalities = modalities
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.patientName = patientName
        self.searchText = searchText
    }

    /// A filter with no constraints (shows everything).
    public static let none = LibraryFilter()
}

/// Sort criteria for study listing.
public enum StudySortField: String, Sendable, CaseIterable {
    case date
    case patientName
    case modality
    case studyDescription

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .date: return "Study Date"
        case .patientName: return "Patient Name"
        case .modality: return "Modality"
        case .studyDescription: return "Description"
        }
    }
}

/// Sort direction for study listing.
public enum SortDirection: String, Sendable {
    case ascending
    case descending

    /// Toggled direction.
    public var toggled: SortDirection {
        self == .ascending ? .descending : .ascending
    }
}

/// Display mode for study listing.
public enum BrowseDisplayMode: String, Sendable, CaseIterable {
    case list
    case grid

    /// System image name for the mode toggle button.
    public var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }

    /// Accessibility label.
    public var accessibilityLabel: String {
        switch self {
        case .list: return "List view"
        case .grid: return "Grid view"
        }
    }
}
