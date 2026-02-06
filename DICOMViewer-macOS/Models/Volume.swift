//
//  Volume.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation

/// Represents an orthogonal slice plane for Multi-Planar Reconstruction
enum MPRPlane: String, CaseIterable, Identifiable, Sendable {
    case axial
    case sagittal
    case coronal

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .axial: return "Axial"
        case .sagittal: return "Sagittal"
        case .coronal: return "Coronal"
        }
    }
}

/// A slice extracted from a 3D volume along one of the orthogonal planes
struct MPRSlice: Identifiable, Sendable {
    let id: UUID
    let plane: MPRPlane
    let index: Int
    let width: Int
    let height: Int
    let pixelData: [Float]
    let pixelSpacingX: Double
    let pixelSpacingY: Double

    init(
        id: UUID = UUID(),
        plane: MPRPlane,
        index: Int,
        width: Int,
        height: Int,
        pixelData: [Float],
        pixelSpacingX: Double,
        pixelSpacingY: Double
    ) {
        self.id = id
        self.plane = plane
        self.index = index
        self.width = width
        self.height = height
        self.pixelData = pixelData
        self.pixelSpacingX = pixelSpacingX
        self.pixelSpacingY = pixelSpacingY
    }
}

/// Transfer function control point for volume rendering
struct TransferFunction: Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let controlPoints: [ControlPoint]

    /// A single control point mapping a normalized value to an opacity and color
    struct ControlPoint: Sendable, Equatable {
        let value: Double
        let opacity: Double
        let color: RGBColor
    }

    /// Simple RGB color representation
    struct RGBColor: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    init(id: UUID = UUID(), name: String, controlPoints: [ControlPoint]) {
        self.id = id
        self.name = name
        self.controlPoints = controlPoints
    }

    // MARK: - Presets

    /// Bone window transfer function
    static let bone = TransferFunction(
        name: "Bone",
        controlPoints: [
            ControlPoint(value: 0.0, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.3, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.5, opacity: 0.3, color: RGBColor(red: 0.8, green: 0.7, blue: 0.6)),
            ControlPoint(value: 0.7, opacity: 0.7, color: RGBColor(red: 1.0, green: 0.9, blue: 0.8)),
            ControlPoint(value: 1.0, opacity: 1.0, color: RGBColor(red: 1.0, green: 1.0, blue: 1.0))
        ]
    )

    /// Soft tissue transfer function
    static let softTissue = TransferFunction(
        name: "Soft Tissue",
        controlPoints: [
            ControlPoint(value: 0.0, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.3, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.4, opacity: 0.2, color: RGBColor(red: 0.8, green: 0.4, blue: 0.3)),
            ControlPoint(value: 0.5, opacity: 0.5, color: RGBColor(red: 0.9, green: 0.6, blue: 0.5)),
            ControlPoint(value: 0.7, opacity: 0.3, color: RGBColor(red: 1.0, green: 0.8, blue: 0.7)),
            ControlPoint(value: 1.0, opacity: 0.0, color: RGBColor(red: 1.0, green: 1.0, blue: 1.0))
        ]
    )

    /// Lung window transfer function
    static let lung = TransferFunction(
        name: "Lung",
        controlPoints: [
            ControlPoint(value: 0.0, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.15, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.2)),
            ControlPoint(value: 0.25, opacity: 0.3, color: RGBColor(red: 0.2, green: 0.3, blue: 0.6)),
            ControlPoint(value: 0.4, opacity: 0.1, color: RGBColor(red: 0.5, green: 0.5, blue: 0.5)),
            ControlPoint(value: 0.7, opacity: 0.5, color: RGBColor(red: 0.9, green: 0.8, blue: 0.7)),
            ControlPoint(value: 1.0, opacity: 1.0, color: RGBColor(red: 1.0, green: 1.0, blue: 1.0))
        ]
    )

    /// Angiography transfer function
    static let angiography = TransferFunction(
        name: "Angiography",
        controlPoints: [
            ControlPoint(value: 0.0, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.4, opacity: 0.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.5, opacity: 0.3, color: RGBColor(red: 0.8, green: 0.1, blue: 0.1)),
            ControlPoint(value: 0.65, opacity: 0.7, color: RGBColor(red: 1.0, green: 0.3, blue: 0.2)),
            ControlPoint(value: 0.8, opacity: 0.9, color: RGBColor(red: 1.0, green: 0.6, blue: 0.4)),
            ControlPoint(value: 1.0, opacity: 1.0, color: RGBColor(red: 1.0, green: 0.9, blue: 0.8))
        ]
    )

    /// Maximum Intensity Projection — fully opaque everywhere
    static let mip = TransferFunction(
        name: "MIP",
        controlPoints: [
            ControlPoint(value: 0.0, opacity: 1.0, color: RGBColor(red: 0.0, green: 0.0, blue: 0.0)),
            ControlPoint(value: 0.5, opacity: 1.0, color: RGBColor(red: 0.5, green: 0.5, blue: 0.5)),
            ControlPoint(value: 1.0, opacity: 1.0, color: RGBColor(red: 1.0, green: 1.0, blue: 1.0))
        ]
    )

    /// All available presets
    static let allPresets: [TransferFunction] = [
        .bone, .softTissue, .lung, .angiography, .mip
    ]
}

/// 3D Volume data built from a stack of DICOM slices
struct Volume: Identifiable, Sendable {
    let id: UUID
    let data: [Float]
    let width: Int
    let height: Int
    let depth: Int
    let spacingX: Double
    let spacingY: Double
    let spacingZ: Double
    let origin: (x: Double, y: Double, z: Double)
    let rescaleSlope: Double
    let rescaleIntercept: Double
    let windowCenter: Double
    let windowWidth: Double

    init(
        id: UUID = UUID(),
        data: [Float],
        width: Int,
        height: Int,
        depth: Int,
        spacingX: Double,
        spacingY: Double,
        spacingZ: Double,
        origin: (x: Double, y: Double, z: Double) = (0, 0, 0),
        rescaleSlope: Double = 1.0,
        rescaleIntercept: Double = 0.0,
        windowCenter: Double = 40.0,
        windowWidth: Double = 400.0
    ) {
        self.id = id
        self.data = data
        self.width = width
        self.height = height
        self.depth = depth
        self.spacingX = spacingX
        self.spacingY = spacingY
        self.spacingZ = spacingZ
        self.origin = origin
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
    }

    /// Get voxel value at the given integer position
    func voxelValue(x: Int, y: Int, z: Int) -> Float? {
        guard x >= 0, x < width, y >= 0, y < height, z >= 0, z < depth else {
            return nil
        }
        return data[z * width * height + y * width + x]
    }

    /// Total number of voxels in the volume
    var voxelCount: Int { width * height * depth }

    /// Physical dimensions in millimeters
    var physicalSize: (x: Double, y: Double, z: Double) {
        (Double(width) * spacingX, Double(height) * spacingY, Double(depth) * spacingZ)
    }
}

/// Rendering mode for 3D visualization
enum RenderingMode: String, CaseIterable, Identifiable, Sendable {
    case mip
    case minIP
    case averageIP
    case volumeRendering

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .mip: return "Maximum Intensity (MIP)"
        case .minIP: return "Minimum Intensity (MinIP)"
        case .averageIP: return "Average Intensity (AIP)"
        case .volumeRendering: return "Volume Rendering"
        }
    }
}
