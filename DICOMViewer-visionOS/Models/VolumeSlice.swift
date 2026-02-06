// VolumeSlice.swift
// DICOMViewer visionOS - Volume Slice for MPR
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// Orientation of a volume slice
enum SliceOrientation: String, Codable, Sendable {
    case axial      // Transverse (XY plane)
    case sagittal   // Side view (YZ plane)
    case coronal    // Front view (XZ plane)
    case oblique    // Custom orientation
}

/// 2D slice extracted from 3D volume for MPR display
struct VolumeSlice: Identifiable, Sendable {
    let id = UUID()
    
    /// Slice orientation
    let orientation: SliceOrientation
    
    /// Slice index in volume
    let sliceIndex: Int
    
    /// Width in pixels
    let width: Int
    
    /// Height in pixels
    let height: Int
    
    /// Pixel data (16-bit intensity values)
    let data: [UInt16]
    
    /// Pixel spacing in mm (x, y)
    let spacing: simd_float2
    
    /// Position in 3D space (mm)
    let position: simd_float3
    
    /// Compute min/max values
    var valueRange: (min: UInt16, max: UInt16) {
        guard !data.isEmpty else { return (0, 0) }
        return (data.min()!, data.max()!)
    }
}
