// ViewportModel.swift
// DICOMStudio
//
// DICOM Studio — Multi-viewport state model

import Foundation

/// Synchronization mode for linked viewports.
public enum ViewportSyncMode: String, Sendable, Equatable, Hashable, CaseIterable {
    /// No synchronization.
    case none = "NONE"
    /// Synchronized scrolling (frame advancement).
    case scroll = "SCROLL"
    /// Synchronized window/level.
    case windowLevel = "WINDOW_LEVEL"
    /// Synchronized scrolling and window/level.
    case all = "ALL"
}

/// Viewport tool mode.
public enum ViewportToolMode: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Default scroll/browse mode.
    case scroll = "SCROLL"
    /// Window/level adjustment mode.
    case windowLevel = "WINDOW_LEVEL"
    /// Zoom mode.
    case zoom = "ZOOM"
    /// Pan mode.
    case pan = "PAN"
}

/// State of a single viewport within a multi-viewport layout.
public struct ViewportState: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier for this viewport.
    public let id: UUID

    /// Position index in the grid (0-based, row-major).
    public let position: Int

    /// SOP Instance UID of the displayed image.
    public var sopInstanceUID: String?

    /// Series Instance UID of the displayed series.
    public var seriesInstanceUID: String?

    /// File path of the displayed DICOM file.
    public var filePath: String?

    /// Current frame index (0-based).
    public var currentFrameIndex: Int

    /// Total number of frames.
    public var numberOfFrames: Int

    /// Window center.
    public var windowCenter: Double

    /// Window width.
    public var windowWidth: Double

    /// Zoom level.
    public var zoomLevel: Double

    /// Pan offset X.
    public var panOffsetX: Double

    /// Pan offset Y.
    public var panOffsetY: Double

    /// Rotation angle in degrees.
    public var rotationAngle: Double

    /// Whether this viewport is the active (focused) one.
    public var isActive: Bool

    /// Creates a new viewport state.
    public init(
        id: UUID = UUID(),
        position: Int,
        sopInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        filePath: String? = nil,
        currentFrameIndex: Int = 0,
        numberOfFrames: Int = 1,
        windowCenter: Double = 128.0,
        windowWidth: Double = 256.0,
        zoomLevel: Double = 1.0,
        panOffsetX: Double = 0.0,
        panOffsetY: Double = 0.0,
        rotationAngle: Double = 0.0,
        isActive: Bool = false
    ) {
        self.id = id
        self.position = position
        self.sopInstanceUID = sopInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.filePath = filePath
        self.currentFrameIndex = currentFrameIndex
        self.numberOfFrames = numberOfFrames
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.zoomLevel = zoomLevel
        self.panOffsetX = panOffsetX
        self.panOffsetY = panOffsetY
        self.rotationAngle = rotationAngle
        self.isActive = isActive
    }

    /// Whether this viewport has an image loaded.
    public var hasImage: Bool {
        filePath != nil
    }

    /// Whether this viewport is multi-frame.
    public var isMultiFrame: Bool {
        numberOfFrames > 1
    }
}

/// Cross-reference line between two viewports.
public struct CrossReferenceLine: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// Source viewport ID.
    public let sourceViewportID: UUID

    /// Target viewport ID.
    public let targetViewportID: UUID

    /// Start point of the reference line (in target viewport image coordinates).
    public let startPoint: AnnotationPoint

    /// End point of the reference line (in target viewport image coordinates).
    public let endPoint: AnnotationPoint

    /// Creates a new cross-reference line.
    public init(
        id: UUID = UUID(),
        sourceViewportID: UUID,
        targetViewportID: UUID,
        startPoint: AnnotationPoint,
        endPoint: AnnotationPoint
    ) {
        self.id = id
        self.sourceViewportID = sourceViewportID
        self.targetViewportID = targetViewportID
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}
