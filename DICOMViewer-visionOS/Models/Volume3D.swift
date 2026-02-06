// Volume3D.swift
// DICOMViewer visionOS - 3D Volume Data Structure
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// 3D Volume Data Structure for visionOS
///
/// Represents a volumetric DICOM dataset for 3D rendering in RealityKit.
/// Stores voxel data and spatial metadata for volume rendering.
@Observable
final class Volume3D: Identifiable, Sendable {
    // MARK: - Identity
    
    let id: UUID
    
    // MARK: - Volume Dimensions
    
    /// Width (columns) in voxels
    let width: Int
    
    /// Height (rows) in voxels
    let height: Int
    
    /// Depth (slices) in voxels
    let depth: Int
    
    /// Total number of voxels
    var voxelCount: Int {
        width * height * depth
    }
    
    // MARK: - Voxel Data
    
    /// Raw voxel data (16-bit intensity values)
    let voxelData: [UInt16]
    
    /// Minimum voxel value in dataset
    let minValue: UInt16
    
    /// Maximum voxel value in dataset
    let maxValue: UInt16
    
    // MARK: - Spatial Information
    
    /// Voxel spacing in mm (x, y, z)
    let spacing: simd_float3
    
    /// Volume origin in patient coordinate system (mm)
    let origin: simd_float3
    
    /// Image orientation (direction cosines for x, y, z axes)
    let orientation: simd_float3x3
    
    // MARK: - Physical Dimensions
    
    /// Physical width in mm
    var physicalWidth: Float {
        Float(width) * spacing.x
    }
    
    /// Physical height in mm
    var physicalHeight: Float {
        Float(height) * spacing.y
    }
    
    /// Physical depth in mm
    var physicalDepth: Float {
        Float(depth) * spacing.z
    }
    
    // MARK: - DICOM Metadata
    
    /// Patient name
    let patientName: String
    
    /// Study description
    let studyDescription: String?
    
    /// Modality (CT, MR, etc.)
    let modality: String
    
    /// Body part examined
    let bodyPart: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        width: Int,
        height: Int,
        depth: Int,
        voxelData: [UInt16],
        minValue: UInt16,
        maxValue: UInt16,
        spacing: simd_float3,
        origin: simd_float3 = .zero,
        orientation: simd_float3x3 = matrix_identity_float3x3,
        patientName: String,
        studyDescription: String? = nil,
        modality: String,
        bodyPart: String? = nil
    ) {
        precondition(voxelData.count == width * height * depth, "Voxel data size mismatch")
        
        self.id = id
        self.width = width
        self.height = height
        self.depth = depth
        self.voxelData = voxelData
        self.minValue = minValue
        self.maxValue = maxValue
        self.spacing = spacing
        self.origin = origin
        self.orientation = orientation
        self.patientName = patientName
        self.studyDescription = studyDescription
        self.modality = modality
        self.bodyPart = bodyPart
    }
}

// MARK: - Voxel Access

extension Volume3D {
    /// Get voxel value at (x, y, z)
    func voxel(at x: Int, y: Int, z: Int) -> UInt16? {
        guard x >= 0, x < width,
              y >= 0, y < height,
              z >= 0, z < depth else {
            return nil
        }
        let index = z * (width * height) + y * width + x
        return voxelData[index]
    }
    
    /// Sample volume at normalized coordinates (0...1)
    func sample(u: Float, v: Float, w: Float) -> UInt16? {
        let x = Int(u * Float(width - 1))
        let y = Int(v * Float(height - 1))
        let z = Int(w * Float(depth - 1))
        return voxel(at: x, y: y, z: z)
    }
}

// MARK: - Slice Extraction

extension Volume3D {
    /// Extract axial (transverse) slice at given z index
    func axialSlice(at z: Int) -> VolumeSlice? {
        guard z >= 0, z < depth else { return nil }
        
        let startIndex = z * width * height
        let endIndex = startIndex + width * height
        let sliceData = Array(voxelData[startIndex..<endIndex])
        
        return VolumeSlice(
            orientation: .axial,
            sliceIndex: z,
            width: width,
            height: height,
            data: sliceData,
            spacing: simd_float2(spacing.x, spacing.y),
            position: origin + simd_float3(0, 0, Float(z) * spacing.z)
        )
    }
    
    /// Extract sagittal slice at given x index
    func sagittalSlice(at x: Int) -> VolumeSlice? {
        guard x >= 0, x < width else { return nil }
        
        var sliceData = [UInt16]()
        sliceData.reserveCapacity(height * depth)
        
        for z in 0..<depth {
            for y in 0..<height {
                if let value = voxel(at: x, y: y, z: z) {
                    sliceData.append(value)
                }
            }
        }
        
        return VolumeSlice(
            orientation: .sagittal,
            sliceIndex: x,
            width: height,
            height: depth,
            data: sliceData,
            spacing: simd_float2(spacing.y, spacing.z),
            position: origin + simd_float3(Float(x) * spacing.x, 0, 0)
        )
    }
    
    /// Extract coronal slice at given y index
    func coronalSlice(at y: Int) -> VolumeSlice? {
        guard y >= 0, y < height else { return nil }
        
        var sliceData = [UInt16]()
        sliceData.reserveCapacity(width * depth)
        
        for z in 0..<depth {
            for x in 0..<width {
                if let value = voxel(at: x, y: y, z: z) {
                    sliceData.append(value)
                }
            }
        }
        
        return VolumeSlice(
            orientation: .coronal,
            sliceIndex: y,
            width: width,
            height: depth,
            data: sliceData,
            spacing: simd_float2(spacing.x, spacing.z),
            position: origin + simd_float3(0, Float(y) * spacing.y, 0)
        )
    }
}

// MARK: - Statistics

extension Volume3D {
    /// Compute histogram of voxel values
    func histogram(bins: Int = 256) -> [Int] {
        var histogram = Array(repeating: 0, count: bins)
        let range = Float(maxValue - minValue)
        
        for voxel in voxelData {
            let normalized = Float(voxel - minValue) / range
            let bin = min(Int(normalized * Float(bins - 1)), bins - 1)
            histogram[bin] += 1
        }
        
        return histogram
    }
    
    /// Compute memory usage in bytes
    var memoryUsage: Int64 {
        Int64(voxelData.count * MemoryLayout<UInt16>.size)
    }
    
    /// Formatted memory usage
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}

// MARK: - Factory Methods

extension Volume3D {
    /// Create volume from DICOM series
    static func from(series: DICOMSeries) async throws -> Volume3D {
        // This would integrate with DICOMKit to load actual pixel data
        // For now, return a placeholder implementation
        
        guard series.isVolumetric else {
            throw VolumeError.notVolumetric
        }
        
        let width = series.imageColumns ?? 512
        let height = series.imageRows ?? 512
        let depth = series.instanceCount
        
        // Create synthetic data (in real implementation, load from DICOM files)
        let voxelCount = width * height * depth
        let voxelData = (0..<voxelCount).map { _ in UInt16.random(in: 0...4095) }
        
        let spacing = simd_float3(
            Float(series.pixelSpacing?[0] ?? 1.0),
            Float(series.pixelSpacing?[1] ?? 1.0),
            Float(series.sliceSpacing ?? 1.0)
        )
        
        return Volume3D(
            width: width,
            height: height,
            depth: depth,
            voxelData: voxelData,
            minValue: 0,
            maxValue: 4095,
            spacing: spacing,
            patientName: series.study?.patientName ?? "Unknown",
            studyDescription: series.study?.studyDescription,
            modality: series.modality,
            bodyPart: series.bodyPartExamined
        )
    }
}

// MARK: - Errors

enum VolumeError: Error, LocalizedError {
    case notVolumetric
    case invalidDimensions
    case dataMismatch
    
    var errorDescription: String? {
        switch self {
        case .notVolumetric:
            return "Series is not suitable for 3D volume reconstruction"
        case .invalidDimensions:
            return "Invalid volume dimensions"
        case .dataMismatch:
            return "Voxel data size does not match dimensions"
        }
    }
}
