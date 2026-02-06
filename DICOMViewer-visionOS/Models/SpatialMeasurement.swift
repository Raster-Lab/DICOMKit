// SpatialMeasurement.swift
// DICOMViewer visionOS - 3D Spatial Measurements
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// Type of spatial measurement
enum MeasurementType: String, Codable, Sendable {
    case length    // Distance between two points
    case angle     // Angle between three points
    case volume    // Volume of 3D ROI
    case area      // Surface area
}

/// 3D spatial measurement in volume space
@Observable
final class SpatialMeasurement: Identifiable, Sendable {
    let id: UUID
    let type: MeasurementType
    let points: [simd_float3]  // Points in 3D space (mm)
    let value: Double          // Measurement value
    let unit: String           // Unit (mm, degrees, mm³, etc.)
    let label: String?         // Optional label
    let createdAt: Date
    var isVisible: Bool
    
    init(
        id: UUID = UUID(),
        type: MeasurementType,
        points: [simd_float3],
        value: Double,
        unit: String,
        label: String? = nil,
        createdAt: Date = Date(),
        isVisible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.value = value
        self.unit = unit
        self.label = label
        self.createdAt = createdAt
        self.isVisible = isVisible
    }
    
    /// Formatted measurement value
    var formattedValue: String {
        String(format: "%.2f %@", value, unit)
    }
}

// MARK: - Factory Methods

extension SpatialMeasurement {
    /// Create length measurement between two points
    static func length(from start: simd_float3, to end: simd_float3, label: String? = nil) -> SpatialMeasurement {
        let distance = simd_distance(start, end)
        return SpatialMeasurement(
            type: .length,
            points: [start, end],
            value: Double(distance),
            unit: "mm",
            label: label
        )
    }
    
    /// Create angle measurement from three points
    static func angle(point1: simd_float3, vertex: simd_float3, point2: simd_float3, label: String? = nil) -> SpatialMeasurement {
        let vec1 = simd_normalize(point1 - vertex)
        let vec2 = simd_normalize(point2 - vertex)
        let cosAngle = simd_dot(vec1, vec2)
        let angleRadians = acos(cosAngle)
        let angleDegrees = angleRadians * 180.0 / .pi
        
        return SpatialMeasurement(
            type: .angle,
            points: [point1, vertex, point2],
            value: Double(angleDegrees),
            unit: "°",
            label: label
        )
    }
}
