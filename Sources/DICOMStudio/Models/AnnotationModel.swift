// AnnotationModel.swift
// DICOMStudio
//
// DICOM Studio — GSPS graphic and text annotation models

import Foundation

/// Types of GSPS graphic annotations per DICOM PS3.3 C.10.5.
public enum GraphicType: String, Sendable, Equatable, Hashable, CaseIterable {
    case point = "POINT"
    case polyline = "POLYLINE"
    case interpolated = "INTERPOLATED"
    case circle = "CIRCLE"
    case ellipse = "ELLIPSE"
}

/// A 2D point in DICOM image coordinates.
public struct AnnotationPoint: Sendable, Equatable, Hashable {
    /// Column coordinate (X).
    public let x: Double

    /// Row coordinate (Y).
    public let y: Double

    /// Creates a new annotation point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Anchor point type for text annotations per DICOM PS3.3 C.10.5.1.
public enum TextAnchorType: String, Sendable, Equatable, Hashable {
    /// Text is anchored to a specific image location.
    case imageRelative = "IMAGE"
    /// Text is anchored relative to the display.
    case displayRelative = "DISPLAY"
}

/// A graphic annotation object (polyline, circle, ellipse, point).
///
/// Corresponds to DICOM Graphic Object Sequence (0070,0009).
public struct GraphicAnnotation: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// The type of graphic.
    public let graphicType: GraphicType

    /// Data points defining the graphic (image coordinates).
    public let points: [AnnotationPoint]

    /// Whether the graphic is filled.
    public let filled: Bool

    /// Layer name this annotation belongs to.
    public let layerName: String

    /// Creates a new graphic annotation.
    public init(
        id: UUID = UUID(),
        graphicType: GraphicType,
        points: [AnnotationPoint],
        filled: Bool = false,
        layerName: String = "LAYER0"
    ) {
        self.id = id
        self.graphicType = graphicType
        self.points = points
        self.filled = filled
        self.layerName = layerName
    }
}

/// A text annotation object.
///
/// Corresponds to DICOM Text Object Sequence (0070,0008).
public struct TextAnnotation: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// The text string to display.
    public let text: String

    /// Bounding box top-left corner (display coordinates).
    public let boundingBoxTopLeft: AnnotationPoint?

    /// Bounding box bottom-right corner (display coordinates).
    public let boundingBoxBottomRight: AnnotationPoint?

    /// Anchor point (image or display coordinates).
    public let anchorPoint: AnnotationPoint?

    /// Type of anchor point reference.
    public let anchorType: TextAnchorType?

    /// Whether the anchor point is visible (e.g., arrow drawn).
    public let anchorPointVisible: Bool

    /// Layer name this annotation belongs to.
    public let layerName: String

    /// Creates a new text annotation.
    public init(
        id: UUID = UUID(),
        text: String,
        boundingBoxTopLeft: AnnotationPoint? = nil,
        boundingBoxBottomRight: AnnotationPoint? = nil,
        anchorPoint: AnnotationPoint? = nil,
        anchorType: TextAnchorType? = nil,
        anchorPointVisible: Bool = true,
        layerName: String = "LAYER0"
    ) {
        self.id = id
        self.text = text
        self.boundingBoxTopLeft = boundingBoxTopLeft
        self.boundingBoxBottomRight = boundingBoxBottomRight
        self.anchorPoint = anchorPoint
        self.anchorType = anchorType
        self.anchorPointVisible = anchorPointVisible
        self.layerName = layerName
    }
}

/// Graphic layer properties per DICOM PS3.3 C.10.7.
public struct GraphicLayer: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public var id: String { name }

    /// Layer name (0070,0002).
    public let name: String

    /// Layer order (0070,0062), lower = behind.
    public let order: Int

    /// Layer description (0070,0068).
    public let description: String?

    /// Recommended display grayscale value (0070,0066).
    public let grayscaleValue: Int?

    /// Creates a new graphic layer.
    public init(
        name: String,
        order: Int = 0,
        description: String? = nil,
        grayscaleValue: Int? = nil
    ) {
        self.name = name
        self.order = order
        self.description = description
        self.grayscaleValue = grayscaleValue
    }
}
