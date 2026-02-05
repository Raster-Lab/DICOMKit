// Measurement.swift
// DICOMViewer iOS - Measurement Data Models
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import CoreGraphics

/// Types of measurements supported by the viewer
enum MeasurementType: String, Codable, CaseIterable, Sendable {
    case length = "length"
    case angle = "angle"
    case ellipse = "ellipse"
    case rectangle = "rectangle"
    case freehand = "freehand"
    
    /// Human-readable name
    var displayName: String {
        switch self {
        case .length: return "Length"
        case .angle: return "Angle"
        case .ellipse: return "Ellipse"
        case .rectangle: return "Rectangle"
        case .freehand: return "Freehand"
        }
    }
    
    /// SF Symbol name for the measurement type
    var symbolName: String {
        switch self {
        case .length: return "ruler"
        case .angle: return "angle"
        case .ellipse: return "circle.dashed"
        case .rectangle: return "rectangle.dashed"
        case .freehand: return "scribble"
        }
    }
}

/// A point in image coordinates (not screen coordinates)
struct ImagePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    /// Distance to another point
    func distance(to other: ImagePoint) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
}

/// A measurement annotation on a DICOM image
struct Measurement: Identifiable, Codable, Sendable {
    /// Unique identifier
    let id: UUID
    
    /// Type of measurement
    let type: MeasurementType
    
    /// Points defining the measurement (in image pixel coordinates)
    var points: [ImagePoint]
    
    /// Frame index where the measurement was made
    let frameIndex: Int
    
    /// Pixel spacing from the DICOM file [row spacing, column spacing] in mm
    var pixelSpacing: (row: Double, column: Double)?
    
    /// When the measurement was created
    let createdAt: Date
    
    /// Optional label/note for the measurement
    var label: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: MeasurementType,
        points: [ImagePoint] = [],
        frameIndex: Int = 0,
        pixelSpacing: (row: Double, column: Double)? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.frameIndex = frameIndex
        self.pixelSpacing = pixelSpacing
        self.createdAt = Date()
        self.label = label
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, type, points, frameIndex
        case pixelSpacingRow, pixelSpacingColumn
        case createdAt, label
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(MeasurementType.self, forKey: .type)
        points = try container.decode([ImagePoint].self, forKey: .points)
        frameIndex = try container.decode(Int.self, forKey: .frameIndex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        
        if let row = try container.decodeIfPresent(Double.self, forKey: .pixelSpacingRow),
           let col = try container.decodeIfPresent(Double.self, forKey: .pixelSpacingColumn) {
            pixelSpacing = (row: row, column: col)
        } else {
            pixelSpacing = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(points, forKey: .points)
        try container.encode(frameIndex, forKey: .frameIndex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(label, forKey: .label)
        
        if let spacing = pixelSpacing {
            try container.encode(spacing.row, forKey: .pixelSpacingRow)
            try container.encode(spacing.column, forKey: .pixelSpacingColumn)
        }
    }
    
    // MARK: - Calculated Values
    
    /// Length in pixels (for length measurements)
    var lengthInPixels: Double? {
        guard type == .length, points.count >= 2 else { return nil }
        return points[0].distance(to: points[1])
    }
    
    /// Length in millimeters (using pixel spacing)
    var lengthInMM: Double? {
        guard let lengthPx = lengthInPixels,
              let spacing = pixelSpacing else {
            return nil
        }
        
        guard points.count >= 2 else { return nil }
        
        let dx = (points[1].x - points[0].x) * spacing.column
        let dy = (points[1].y - points[0].y) * spacing.row
        let _ = lengthPx // silence unused warning
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Angle in degrees (for angle measurements)
    var angleInDegrees: Double? {
        guard type == .angle, points.count >= 3 else { return nil }
        
        // Calculate angle at the vertex (second point)
        let p1 = points[0]
        let vertex = points[1]
        let p2 = points[2]
        
        let v1x = p1.x - vertex.x
        let v1y = p1.y - vertex.y
        let v2x = p2.x - vertex.x
        let v2y = p2.y - vertex.y
        
        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        
        guard mag1 > 0 && mag2 > 0 else { return nil }
        
        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1.0, min(1.0, cosAngle))
        return acos(clampedCos) * 180.0 / .pi
    }
    
    /// Area in pixels squared (for ellipse/rectangle)
    var areaInPixels: Double? {
        switch type {
        case .ellipse:
            guard points.count >= 2 else { return nil }
            let width = abs(points[1].x - points[0].x)
            let height = abs(points[1].y - points[0].y)
            return .pi * (width / 2) * (height / 2)
            
        case .rectangle:
            guard points.count >= 2 else { return nil }
            let width = abs(points[1].x - points[0].x)
            let height = abs(points[1].y - points[0].y)
            return width * height
            
        case .freehand:
            guard points.count >= 3 else { return nil }
            // Shoelace formula for polygon area
            var area = 0.0
            let n = points.count
            for i in 0..<n {
                let j = (i + 1) % n
                area += points[i].x * points[j].y
                area -= points[j].x * points[i].y
            }
            return abs(area) / 2.0
            
        default:
            return nil
        }
    }
    
    /// Area in mm² (using pixel spacing)
    var areaInMM2: Double? {
        guard let areaPx = areaInPixels,
              let spacing = pixelSpacing else {
            return nil
        }
        return areaPx * spacing.row * spacing.column
    }
    
    /// Formatted measurement value for display
    var formattedValue: String {
        switch type {
        case .length:
            if let mm = lengthInMM {
                return String(format: "%.1f mm", mm)
            } else if let px = lengthInPixels {
                return String(format: "%.1f px", px)
            }
            return "—"
            
        case .angle:
            if let deg = angleInDegrees {
                return String(format: "%.1f°", deg)
            }
            return "—"
            
        case .ellipse, .rectangle, .freehand:
            if let mm2 = areaInMM2 {
                return String(format: "%.1f mm²", mm2)
            } else if let px2 = areaInPixels {
                return String(format: "%.1f px²", px2)
            }
            return "—"
        }
    }
}

/// Statistics for a region of interest
struct ROIStatistics: Sendable {
    /// Mean pixel value
    let mean: Double
    
    /// Standard deviation
    let standardDeviation: Double
    
    /// Minimum pixel value
    let minimum: Double
    
    /// Maximum pixel value
    let maximum: Double
    
    /// Number of pixels in the ROI
    let pixelCount: Int
    
    /// Area in mm² (if pixel spacing is available)
    let areaInMM2: Double?
}
