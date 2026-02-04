//
// SpatialTransformation.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Spatial transformation for image display
///
/// Defines rotation and horizontal flip to apply to the image.
///
/// Reference: PS3.3 Section C.10.6 - Spatial Transformation Module
public struct SpatialTransformation: Sendable, Hashable {
    /// Image rotation in degrees (clockwise)
    ///
    /// Valid values: 0, 90, 180, 270
    public let rotation: Int
    
    /// Whether to flip the image horizontally
    public let horizontalFlip: Bool
    
    /// Initialize a spatial transformation
    ///
    /// - Parameters:
    ///   - rotation: Rotation angle in degrees (0, 90, 180, or 270)
    ///   - horizontalFlip: Whether to flip horizontally
    public init(rotation: Int = 0, horizontalFlip: Bool = false) {
        // Normalize rotation to 0-359 degrees
        let normalizedRotation = rotation % 360
        
        // Ensure rotation is one of the valid values
        switch normalizedRotation {
        case 0, 90, 180, 270:
            self.rotation = normalizedRotation
        case -270:
            self.rotation = 90
        case -180:
            self.rotation = 180
        case -90:
            self.rotation = 270
        default:
            // Round to nearest 90-degree increment
            self.rotation = ((normalizedRotation + 45) / 90) * 90
        }
        
        self.horizontalFlip = horizontalFlip
    }
    
    /// Whether the image is rotated
    public var isRotated: Bool {
        rotation != 0
    }
    
    /// Whether the image is flipped
    public var isFlipped: Bool {
        horizontalFlip
    }
    
    /// Whether any transformation is applied
    public var hasTransformation: Bool {
        isRotated || isFlipped
    }
}

/// Displayed area selection
///
/// Defines the portion of the image to display and how to size it.
///
/// Reference: PS3.3 Section C.10.4 - Displayed Area Module
public struct DisplayedArea: Sendable, Hashable {
    /// Top-left corner of the displayed area (column, row)
    public let topLeft: (column: Int, row: Int)
    
    /// Bottom-right corner of the displayed area (column, row)
    public let bottomRight: (column: Int, row: Int)
    
    /// Presentation size mode
    public let sizeMode: PresentationSizeMode
    
    /// Initialize a displayed area
    ///
    /// - Parameters:
    ///   - topLeft: Top-left corner (column, row)
    ///   - bottomRight: Bottom-right corner (column, row)
    ///   - sizeMode: How to size the displayed area
    public init(
        topLeft: (column: Int, row: Int),
        bottomRight: (column: Int, row: Int),
        sizeMode: PresentationSizeMode = .scaleToFit
    ) {
        self.topLeft = topLeft
        self.bottomRight = bottomRight
        self.sizeMode = sizeMode
    }
    
    /// Width of the displayed area in pixels
    public var width: Int {
        bottomRight.column - topLeft.column + 1
    }
    
    /// Height of the displayed area in pixels
    public var height: Int {
        bottomRight.row - topLeft.row + 1
    }
}

/// Presentation size mode
///
/// Defines how the displayed area should be sized on the display.
///
/// Reference: PS3.3 Section C.10.4.1 - Presentation Size Mode
public enum PresentationSizeMode: String, Sendable, Hashable {
    /// Scale to fit the display
    case scaleToFit = "SCALE TO FIT"
    
    /// True size - 1:1 pixel mapping
    case trueSize = "TRUE SIZE"
    
    /// Magnify to a specific size
    case magnify = "MAGNIFY"
}

// MARK: - Hashable conformance for tuples

extension DisplayedArea {
    public static func == (lhs: DisplayedArea, rhs: DisplayedArea) -> Bool {
        lhs.topLeft.column == rhs.topLeft.column &&
        lhs.topLeft.row == rhs.topLeft.row &&
        lhs.bottomRight.column == rhs.bottomRight.column &&
        lhs.bottomRight.row == rhs.bottomRight.row &&
        lhs.sizeMode == rhs.sizeMode
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(topLeft.column)
        hasher.combine(topLeft.row)
        hasher.combine(bottomRight.column)
        hasher.combine(bottomRight.row)
        hasher.combine(sizeMode)
    }
}
