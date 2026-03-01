// ROIModel.swift
// DICOMStudio
//
// DICOM Studio — Region of Interest models for Milestone 5

import Foundation

// MARK: - ROI Type

/// Type of Region of Interest.
public enum ROIType: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Elliptical ROI.
    case elliptical = "ELLIPTICAL"
    /// Rectangular ROI.
    case rectangular = "RECTANGULAR"
    /// Freehand-drawn ROI.
    case freehand = "FREEHAND"
    /// Polygonal ROI (click to place vertices).
    case polygonal = "POLYGONAL"
    /// Circular ROI (center + radius).
    case circular = "CIRCULAR"
}

// MARK: - ROI Statistics

/// Computed statistics for pixel values within an ROI.
public struct ROIStatistics: Sendable, Equatable, Hashable {
    /// Mean pixel value.
    public let mean: Double

    /// Standard deviation of pixel values.
    public let standardDeviation: Double

    /// Minimum pixel value.
    public let minimum: Double

    /// Maximum pixel value.
    public let maximum: Double

    /// Area in pixels (number of pixels inside ROI).
    public let areaPixels: Int

    /// Area in physical units (mm²), if calibrated.
    public let areaMM2: Double?

    /// Perimeter in pixels.
    public let perimeterPixels: Double

    /// Perimeter in physical units (mm), if calibrated.
    public let perimeterMM: Double?

    /// Creates new ROI statistics.
    public init(
        mean: Double = 0.0,
        standardDeviation: Double = 0.0,
        minimum: Double = 0.0,
        maximum: Double = 0.0,
        areaPixels: Int = 0,
        areaMM2: Double? = nil,
        perimeterPixels: Double = 0.0,
        perimeterMM: Double? = nil
    ) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.minimum = minimum
        self.maximum = maximum
        self.areaPixels = areaPixels
        self.areaMM2 = areaMM2
        self.perimeterPixels = perimeterPixels
        self.perimeterMM = perimeterMM
    }

    /// Empty statistics.
    public static let empty = ROIStatistics()
}

// MARK: - ROI Entry

/// A persisted ROI with shape, statistics, and metadata.
public struct ROIEntry: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// Type of ROI.
    public let roiType: ROIType

    /// Points defining the ROI boundary (image coordinates).
    public let points: [AnnotationPoint]

    /// Computed statistics for this ROI.
    public let statistics: ROIStatistics

    /// Display label.
    public let label: String

    /// Visual style.
    public let style: AnnotationStyle

    /// Whether this ROI is visible.
    public let isVisible: Bool

    /// Whether this ROI is locked.
    public let isLocked: Bool

    /// SOP Instance UID of the associated image.
    public let sopInstanceUID: String

    /// Frame number.
    public let frameNumber: Int

    /// Creation timestamp.
    public let createdAt: Date

    /// Creates a new ROI entry.
    public init(
        id: UUID = UUID(),
        roiType: ROIType,
        points: [AnnotationPoint],
        statistics: ROIStatistics = .empty,
        label: String = "",
        style: AnnotationStyle = .defaultStyle,
        isVisible: Bool = true,
        isLocked: Bool = false,
        sopInstanceUID: String = "",
        frameNumber: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.roiType = roiType
        self.points = points
        self.statistics = statistics
        self.label = label
        self.style = style
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.sopInstanceUID = sopInstanceUID
        self.frameNumber = frameNumber
        self.createdAt = createdAt
    }

    /// Returns a copy with updated statistics.
    public func withStatistics(_ stats: ROIStatistics) -> ROIEntry {
        ROIEntry(
            id: id, roiType: roiType, points: points, statistics: stats,
            label: label, style: style, isVisible: isVisible, isLocked: isLocked,
            sopInstanceUID: sopInstanceUID, frameNumber: frameNumber, createdAt: createdAt
        )
    }

    /// Returns a copy with updated visibility.
    public func withVisibility(_ visible: Bool) -> ROIEntry {
        ROIEntry(
            id: id, roiType: roiType, points: points, statistics: statistics,
            label: label, style: style, isVisible: visible, isLocked: isLocked,
            sopInstanceUID: sopInstanceUID, frameNumber: frameNumber, createdAt: createdAt
        )
    }

    /// Returns a copy with updated lock state.
    public func withLocked(_ locked: Bool) -> ROIEntry {
        ROIEntry(
            id: id, roiType: roiType, points: points, statistics: statistics,
            label: label, style: style, isVisible: isVisible, isLocked: locked,
            sopInstanceUID: sopInstanceUID, frameNumber: frameNumber, createdAt: createdAt
        )
    }
}
