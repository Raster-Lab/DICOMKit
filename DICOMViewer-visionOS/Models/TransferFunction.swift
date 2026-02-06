// TransferFunction.swift
// DICOMViewer visionOS - Volume Rendering Transfer Function
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// Transfer function for volume rendering
///
/// Maps voxel intensity values to color and opacity for visualization.
@Observable
final class TransferFunction: Identifiable, Sendable {
    let id: UUID
    
    /// Transfer function name
    let name: String
    
    /// Opacity control points (intensity: 0-1, opacity: 0-1)
    let opacityPoints: [ControlPoint]
    
    /// Color control points (intensity: 0-1, color: RGB)
    let colorPoints: [ColorControlPoint]
    
    /// Whether this is a preset or custom function
    let isPreset: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        opacityPoints: [ControlPoint],
        colorPoints: [ColorControlPoint],
        isPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.opacityPoints = opacityPoints.sorted { $0.intensity < $1.intensity }
        self.colorPoints = colorPoints.sorted { $0.intensity < $1.intensity }
        self.isPreset = isPreset
    }
    
    /// Control point for opacity curve
    struct ControlPoint: Sendable {
        let intensity: Float  // 0-1
        let opacity: Float    // 0-1
    }
    
    /// Control point for color mapping
    struct ColorControlPoint: Sendable {
        let intensity: Float     // 0-1
        let color: simd_float3   // RGB (0-1)
    }
}

// MARK: - Presets

extension TransferFunction {
    /// Bone visualization (CT)
    static let bone = TransferFunction(
        name: "Bone",
        opacityPoints: [
            ControlPoint(intensity: 0.0, opacity: 0.0),
            ControlPoint(intensity: 0.3, opacity: 0.0),
            ControlPoint(intensity: 0.5, opacity: 0.3),
            ControlPoint(intensity: 0.7, opacity: 0.8),
            ControlPoint(intensity: 1.0, opacity: 1.0)
        ],
        colorPoints: [
            ColorControlPoint(intensity: 0.0, color: simd_float3(0, 0, 0)),
            ColorControlPoint(intensity: 0.5, color: simd_float3(0.8, 0.7, 0.6)),
            ColorControlPoint(intensity: 1.0, color: simd_float3(1.0, 1.0, 1.0))
        ],
        isPreset: true
    )
    
    /// Soft tissue visualization
    static let softTissue = TransferFunction(
        name: "Soft Tissue",
        opacityPoints: [
            ControlPoint(intensity: 0.0, opacity: 0.0),
            ControlPoint(intensity: 0.2, opacity: 0.1),
            ControlPoint(intensity: 0.4, opacity: 0.5),
            ControlPoint(intensity: 0.6, opacity: 0.8),
            ControlPoint(intensity: 1.0, opacity: 0.9)
        ],
        colorPoints: [
            ColorControlPoint(intensity: 0.0, color: simd_float3(0, 0, 0)),
            ColorControlPoint(intensity: 0.3, color: simd_float3(0.6, 0.3, 0.3)),
            ColorControlPoint(intensity: 0.7, color: simd_float3(0.9, 0.6, 0.5)),
            ColorControlPoint(intensity: 1.0, color: simd_float3(1.0, 0.9, 0.8))
        ],
        isPreset: true
    )
    
    /// Vascular (angio) visualization
    static let vascular = TransferFunction(
        name: "Vascular",
        opacityPoints: [
            ControlPoint(intensity: 0.0, opacity: 0.0),
            ControlPoint(intensity: 0.4, opacity: 0.0),
            ControlPoint(intensity: 0.6, opacity: 0.7),
            ControlPoint(intensity: 0.8, opacity: 1.0),
            ControlPoint(intensity: 1.0, opacity: 1.0)
        ],
        colorPoints: [
            ColorControlPoint(intensity: 0.0, color: simd_float3(0, 0, 0)),
            ColorControlPoint(intensity: 0.5, color: simd_float3(0.8, 0.1, 0.1)),
            ColorControlPoint(intensity: 0.8, color: simd_float3(1.0, 0.3, 0.2)),
            ColorControlPoint(intensity: 1.0, color: simd_float3(1.0, 0.6, 0.5))
        ],
        isPreset: true
    )
    
    /// Lung visualization
    static let lung = TransferFunction(
        name: "Lung",
        opacityPoints: [
            ControlPoint(intensity: 0.0, opacity: 0.0),
            ControlPoint(intensity: 0.1, opacity: 0.1),
            ControlPoint(intensity: 0.3, opacity: 0.4),
            ControlPoint(intensity: 0.5, opacity: 0.6),
            ControlPoint(intensity: 1.0, opacity: 0.8)
        ],
        colorPoints: [
            ColorControlPoint(intensity: 0.0, color: simd_float3(0, 0, 0)),
            ColorControlPoint(intensity: 0.2, color: simd_float3(0.2, 0.3, 0.5)),
            ColorControlPoint(intensity: 0.6, color: simd_float3(0.6, 0.7, 0.9)),
            ColorControlPoint(intensity: 1.0, color: simd_float3(1.0, 1.0, 1.0))
        ],
        isPreset: true
    )
    
    /// All available presets
    static let presets: [TransferFunction] = [bone, softTissue, vascular, lung]
}

// MARK: - Sampling

extension TransferFunction {
    /// Sample opacity at normalized intensity
    func opacity(at intensity: Float) -> Float {
        guard !opacityPoints.isEmpty else { return 0 }
        
        // Find surrounding control points
        if intensity <= opacityPoints.first!.intensity {
            return opacityPoints.first!.opacity
        }
        if intensity >= opacityPoints.last!.intensity {
            return opacityPoints.last!.opacity
        }
        
        // Linear interpolation between points
        for i in 0..<opacityPoints.count - 1 {
            let p0 = opacityPoints[i]
            let p1 = opacityPoints[i + 1]
            
            if intensity >= p0.intensity && intensity <= p1.intensity {
                let t = (intensity - p0.intensity) / (p1.intensity - p0.intensity)
                return p0.opacity + t * (p1.opacity - p0.opacity)
            }
        }
        
        return 0
    }
    
    /// Sample color at normalized intensity
    func color(at intensity: Float) -> simd_float3 {
        guard !colorPoints.isEmpty else { return .zero }
        
        if intensity <= colorPoints.first!.intensity {
            return colorPoints.first!.color
        }
        if intensity >= colorPoints.last!.intensity {
            return colorPoints.last!.color
        }
        
        // Linear interpolation
        for i in 0..<colorPoints.count - 1 {
            let c0 = colorPoints[i]
            let c1 = colorPoints[i + 1]
            
            if intensity >= c0.intensity && intensity <= c1.intensity {
                let t = (intensity - c0.intensity) / (c1.intensity - c0.intensity)
                return c0.color + t * (c1.color - c0.color)
            }
        }
        
        return .zero
    }
}
