//
// GraphicAnnotation.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Graphic layer for organizing annotations
///
/// Layers are stacked in order, with higher order numbers displayed on top.
///
/// Reference: PS3.3 Section C.10.7 - Graphic Layer Module
public struct GraphicLayer: Sendable, Hashable {
    /// Layer name
    public let name: String
    
    /// Layer order (higher numbers are displayed on top)
    public let order: Int
    
    /// Description of the layer
    public let description: String?
    
    /// Recommended display grayscale value (0-65535)
    public let recommendedGrayscaleValue: Int?
    
    /// Recommended display RGB value
    public let recommendedRGBValue: (red: Int, green: Int, blue: Int)?
    
    /// Initialize a graphic layer
    public init(
        name: String,
        order: Int,
        description: String? = nil,
        recommendedGrayscaleValue: Int? = nil,
        recommendedRGBValue: (red: Int, green: Int, blue: Int)? = nil
    ) {
        self.name = name
        self.order = order
        self.description = description
        self.recommendedGrayscaleValue = recommendedGrayscaleValue
        self.recommendedRGBValue = recommendedRGBValue
    }
}

// MARK: - Hashable conformance for RGB tuple

extension GraphicLayer {
    public static func == (lhs: GraphicLayer, rhs: GraphicLayer) -> Bool {
        lhs.name == rhs.name &&
        lhs.order == rhs.order &&
        lhs.description == rhs.description &&
        lhs.recommendedGrayscaleValue == rhs.recommendedGrayscaleValue &&
        lhs.recommendedRGBValue?.red == rhs.recommendedRGBValue?.red &&
        lhs.recommendedRGBValue?.green == rhs.recommendedRGBValue?.green &&
        lhs.recommendedRGBValue?.blue == rhs.recommendedRGBValue?.blue
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(order)
        hasher.combine(description)
        hasher.combine(recommendedGrayscaleValue)
        hasher.combine(recommendedRGBValue?.red)
        hasher.combine(recommendedRGBValue?.green)
        hasher.combine(recommendedRGBValue?.blue)
    }
}

/// Graphic annotation
///
/// Contains graphic and text objects associated with referenced images.
///
/// Reference: PS3.3 Section C.10.5 - Graphic Annotation Module
public struct GraphicAnnotation: Sendable, Hashable {
    /// Layer this annotation belongs to
    public let layer: String
    
    /// Referenced images this annotation applies to
    public let referencedImages: [ReferencedImage]
    
    /// Graphic objects in this annotation
    public let graphicObjects: [GraphicObject]
    
    /// Text objects in this annotation
    public let textObjects: [TextObject]
    
    /// Initialize a graphic annotation
    public init(
        layer: String,
        referencedImages: [ReferencedImage],
        graphicObjects: [GraphicObject] = [],
        textObjects: [TextObject] = []
    ) {
        self.layer = layer
        self.referencedImages = referencedImages
        self.graphicObjects = graphicObjects
        self.textObjects = textObjects
    }
}

/// Graphic object in an annotation
///
/// Represents geometric shapes like points, lines, circles, etc.
///
/// Reference: PS3.3 Section C.10.5.1.2 - Graphic Object Sequence
public struct GraphicObject: Sendable, Hashable {
    /// Type of graphic
    public let type: PresentationGraphicType
    
    /// Graphic data points (column, row pairs)
    public let data: [Double]
    
    /// Whether the graphic is filled
    public let filled: Bool
    
    /// Units for the graphic data
    public let units: AnnotationUnits
    
    /// Initialize a graphic object
    public init(
        type: PresentationGraphicType,
        data: [Double],
        filled: Bool = false,
        units: AnnotationUnits = .pixel
    ) {
        self.type = type
        self.data = data
        self.filled = filled
        self.units = units
    }
    
    /// Number of points in the graphic
    public var pointCount: Int {
        data.count / 2
    }
    
    /// Get a specific point from the graphic data
    ///
    /// - Parameter index: Point index (0-based)
    /// - Returns: (column, row) coordinate, or nil if index is invalid
    public func point(at index: Int) -> (column: Double, row: Double)? {
        guard index >= 0 && index < pointCount else {
            return nil
        }
        
        let offset = index * 2
        return (data[offset], data[offset + 1])
    }
}

/// Type of graphic object for presentation state annotations
///
/// Reference: PS3.3 Section C.10.5.1.2.1 - Graphic Type
public enum PresentationGraphicType: String, Sendable, Hashable {
    /// Single point
    case point = "POINT"
    
    /// Polyline (multiple connected line segments)
    case polyline = "POLYLINE"
    
    /// Interpolated smooth curve
    case interpolated = "INTERPOLATED"
    
    /// Circle (center + radius point)
    case circle = "CIRCLE"
    
    /// Ellipse (4 corner points of bounding box)
    case ellipse = "ELLIPSE"
}

/// Text object in an annotation
///
/// Represents text labels with positioning information.
///
/// Reference: PS3.3 Section C.10.5.1.3 - Text Object Sequence
public struct TextObject: Sendable, Hashable {
    /// Text to display
    public let text: String
    
    /// Bounding box top-left corner (column, row)
    public let boundingBoxTopLeft: (column: Double, row: Double)
    
    /// Bounding box bottom-right corner (column, row)
    public let boundingBoxBottomRight: (column: Double, row: Double)
    
    /// Anchor point for the text (column, row)
    public let anchorPoint: (column: Double, row: Double)?
    
    /// Whether the anchor point is visible
    public let anchorPointVisible: Bool
    
    /// Units for bounding box coordinates
    public let boundingBoxUnits: AnnotationUnits
    
    /// Units for anchor point coordinates
    public let anchorPointUnits: AnnotationUnits
    
    /// Initialize a text object
    public init(
        text: String,
        boundingBoxTopLeft: (column: Double, row: Double),
        boundingBoxBottomRight: (column: Double, row: Double),
        anchorPoint: (column: Double, row: Double)? = nil,
        anchorPointVisible: Bool = false,
        boundingBoxUnits: AnnotationUnits = .pixel,
        anchorPointUnits: AnnotationUnits = .pixel
    ) {
        self.text = text
        self.boundingBoxTopLeft = boundingBoxTopLeft
        self.boundingBoxBottomRight = boundingBoxBottomRight
        self.anchorPoint = anchorPoint
        self.anchorPointVisible = anchorPointVisible
        self.boundingBoxUnits = boundingBoxUnits
        self.anchorPointUnits = anchorPointUnits
    }
}

// MARK: - Hashable conformance for tuples

extension TextObject {
    public static func == (lhs: TextObject, rhs: TextObject) -> Bool {
        lhs.text == rhs.text &&
        lhs.boundingBoxTopLeft.column == rhs.boundingBoxTopLeft.column &&
        lhs.boundingBoxTopLeft.row == rhs.boundingBoxTopLeft.row &&
        lhs.boundingBoxBottomRight.column == rhs.boundingBoxBottomRight.column &&
        lhs.boundingBoxBottomRight.row == rhs.boundingBoxBottomRight.row &&
        lhs.anchorPoint?.column == rhs.anchorPoint?.column &&
        lhs.anchorPoint?.row == rhs.anchorPoint?.row &&
        lhs.anchorPointVisible == rhs.anchorPointVisible &&
        lhs.boundingBoxUnits == rhs.boundingBoxUnits &&
        lhs.anchorPointUnits == rhs.anchorPointUnits
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(boundingBoxTopLeft.column)
        hasher.combine(boundingBoxTopLeft.row)
        hasher.combine(boundingBoxBottomRight.column)
        hasher.combine(boundingBoxBottomRight.row)
        hasher.combine(anchorPoint?.column)
        hasher.combine(anchorPoint?.row)
        hasher.combine(anchorPointVisible)
        hasher.combine(boundingBoxUnits)
        hasher.combine(anchorPointUnits)
    }
}

/// Units for annotation coordinates
///
/// Reference: PS3.3 Section C.10.5.1 - Graphic Annotation Module Attributes
public enum AnnotationUnits: String, Sendable, Hashable {
    /// Pixel coordinates
    case pixel = "PIXEL"
    
    /// Display coordinates (normalized 0.0-1.0)
    case display = "DISPLAY"
}
