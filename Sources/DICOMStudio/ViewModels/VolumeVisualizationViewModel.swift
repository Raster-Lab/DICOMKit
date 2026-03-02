// VolumeVisualizationViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for 3D visualization and MPR

import Foundation
import Observation

/// ViewModel for 3D visualization, managing MPR planes, projection modes,
/// volume rendering, surface extraction, and crosshair synchronization.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class VolumeVisualizationViewModel {

    // MARK: - Active Mode

    /// Active visualization mode.
    public var activeMode: VisualizationMode = .mpr

    // MARK: - MPR State

    /// Current axial slice index.
    public var axialSlice: Int = 0

    /// Current sagittal slice index.
    public var sagittalSlice: Int = 0

    /// Current coronal slice index.
    public var coronalSlice: Int = 0

    /// Interpolation quality for MPR reconstruction.
    public var interpolationQuality: InterpolationQuality = .bilinear

    /// Slab thickness in mm (nil = single slice).
    public var slabThickness: Double?

    /// Whether the oblique plane editor is visible.
    public var showObliqueEditor: Bool = false

    // MARK: - 3D Crosshair

    /// Current 3D crosshair position.
    public var crosshairPosition: CrosshairPosition3D = .origin

    /// Whether crosshair linkage is enabled.
    public var crosshairLinkingEnabled: Bool = true

    /// Whether reference lines are visible.
    public var showReferenceLines: Bool = true

    // MARK: - Projection State

    /// Current projection mode.
    public var projectionMode: ProjectionMode = .mip

    /// Projection direction.
    public var projectionDirection: MPRPlane = .axial

    /// Projection slab thickness in mm (nil = full volume).
    public var projectionSlabThickness: Double?

    // MARK: - Volume Rendering State

    /// Active transfer function preset.
    public var transferFunctionPreset: TransferFunctionPreset = .bone

    /// Shading model.
    public var shadingModel: ShadingModel = .phong

    /// Volume rotation X in degrees.
    public var rotationX: Double = 0.0

    /// Volume rotation Y in degrees.
    public var rotationY: Double = 0.0

    /// Volume rotation Z in degrees.
    public var rotationZ: Double = 0.0

    /// Volume zoom level.
    public var zoom: Double = 1.0

    /// Whether the transfer function editor panel is visible.
    public var showTransferFunctionEditor: Bool = false

    // MARK: - Surface State

    /// Surface configurations.
    public var surfaceConfigurations: [SurfaceConfiguration] = []

    /// Selected surface ID.
    public var selectedSurfaceID: UUID?

    /// Whether the surface extraction panel is visible.
    public var showSurfacePanel: Bool = false

    /// Export format for mesh.
    public var exportFormat: SurfaceExportFormat = .stl

    // MARK: - Volume Info

    /// Volume dimensions (nil if no volume loaded).
    public var volumeDimensions: VolumeDimensionsModel?

    /// Whether a volume is loaded.
    public var isVolumeLoaded: Bool {
        volumeDimensions != nil
    }

    // MARK: - Services

    /// Volume visualization service.
    public let visualizationService: VolumeVisualizationService

    // MARK: - Initialization

    /// Creates a volume visualization ViewModel with dependency-injected service.
    public init(
        visualizationService: VolumeVisualizationService = VolumeVisualizationService()
    ) {
        self.visualizationService = visualizationService
    }

    // MARK: - Volume Loading

    /// Sets the volume dimensions and resets view to center.
    public func loadVolume(dimensions: VolumeDimensionsModel) {
        visualizationService.setVolumeDimensions(dimensions)
        volumeDimensions = dimensions
        axialSlice = dimensions.depth / 2
        sagittalSlice = dimensions.width / 2
        coronalSlice = dimensions.height / 2
        crosshairPosition = CrosshairPosition3D(
            x: Double(dimensions.width / 2) * dimensions.spacingX,
            y: Double(dimensions.height / 2) * dimensions.spacingY,
            z: Double(dimensions.depth / 2) * dimensions.spacingZ,
            voxelX: dimensions.width / 2,
            voxelY: dimensions.height / 2,
            voxelZ: dimensions.depth / 2
        )
    }

    // MARK: - Slice Navigation

    /// Scrolls a plane by a delta (positive or negative).
    public func scroll(plane: MPRPlane, delta: Int) {
        guard let dims = volumeDimensions else { return }
        let current: Int
        switch plane {
        case .axial: current = axialSlice
        case .sagittal: current = sagittalSlice
        case .coronal: current = coronalSlice
        }
        let newIndex = MPRHelpers.clampSliceIndex(current + delta, plane: plane, dimensions: dims)
        setSliceIndex(newIndex, for: plane)
    }

    /// Sets the slice index for a specific plane.
    public func setSliceIndex(_ index: Int, for plane: MPRPlane) {
        guard let dims = volumeDimensions else { return }
        let clamped = MPRHelpers.clampSliceIndex(index, plane: plane, dimensions: dims)
        visualizationService.setSliceIndex(clamped, for: plane)
        switch plane {
        case .axial: axialSlice = clamped
        case .sagittal: sagittalSlice = clamped
        case .coronal: coronalSlice = clamped
        }
    }

    // MARK: - Crosshair Navigation

    /// Handles a click in a plane, updating crosshair and synchronized slices.
    public func clickInPlane(_ plane: MPRPlane, x: Int, y: Int) {
        guard crosshairLinkingEnabled else { return }
        guard let crosshair = visualizationService.navigateCrosshair(clickX: x, clickY: y, plane: plane) else { return }

        crosshairPosition = crosshair
        axialSlice = visualizationService.sliceIndex(for: .axial)
        sagittalSlice = visualizationService.sliceIndex(for: .sagittal)
        coronalSlice = visualizationService.sliceIndex(for: .coronal)
    }

    // MARK: - Mode Selection

    /// Sets the active visualization mode.
    public func setMode(_ mode: VisualizationMode) {
        activeMode = mode
        visualizationService.setActiveMode(mode)
    }

    // MARK: - Projection Controls

    /// Updates projection configuration.
    public func updateProjection(mode: ProjectionMode? = nil, direction: MPRPlane? = nil, slabThickness: Double? = nil) {
        if let mode = mode { projectionMode = mode }
        if let direction = direction { projectionDirection = direction }
        projectionSlabThickness = slabThickness

        let config = ProjectionConfiguration(
            mode: projectionMode,
            direction: projectionDirection,
            slabThickness: projectionSlabThickness
        )
        visualizationService.setProjectionConfiguration(config)
    }

    // MARK: - Volume Rendering Controls

    /// Applies a transfer function preset.
    public func applyPreset(_ preset: TransferFunctionPreset) {
        transferFunctionPreset = preset
        visualizationService.applyPreset(preset)
    }

    /// Updates volume rotation.
    public func setRotation(x: Double, y: Double, z: Double) {
        rotationX = x
        rotationY = y
        rotationZ = z
    }

    /// Updates zoom level.
    public func setZoom(_ newZoom: Double) {
        zoom = max(0.1, newZoom)
    }

    // MARK: - Surface Management

    /// Adds a new surface configuration.
    public func addSurface(label: String, threshold: Double, red: Double = 1.0, green: Double = 1.0, blue: Double = 1.0, opacity: Double = 1.0) {
        let config = SurfaceConfiguration(
            label: label,
            threshold: threshold,
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
        visualizationService.addSurface(config)
        surfaceConfigurations = visualizationService.surfaceConfigurations()
    }

    /// Removes a surface by ID.
    public func removeSurface(id: UUID) {
        visualizationService.removeSurface(id: id)
        surfaceConfigurations = visualizationService.surfaceConfigurations()
        if selectedSurfaceID == id {
            selectedSurfaceID = nil
        }
    }

    /// Toggles surface visibility.
    public func toggleSurfaceVisibility(id: UUID) {
        guard let surface = surfaceConfigurations.first(where: { $0.id == id }) else { return }
        let updated = surface.withVisible(!surface.isVisible)
        visualizationService.updateSurface(updated)
        surfaceConfigurations = visualizationService.surfaceConfigurations()
    }

    /// Returns the count of active (visible) surfaces.
    public var visibleSurfaceCount: Int {
        surfaceConfigurations.filter(\.isVisible).count
    }

    // MARK: - Interpolation

    /// Sets the MPR interpolation quality.
    public func setInterpolation(_ quality: InterpolationQuality) {
        interpolationQuality = quality
        for plane in MPRPlane.allCases {
            visualizationService.setInterpolation(quality, for: plane)
        }
    }

    // MARK: - Reset

    /// Resets all visualization state.
    public func resetVisualization() {
        visualizationService.resetAll()
        activeMode = .mpr
        axialSlice = 0
        sagittalSlice = 0
        coronalSlice = 0
        crosshairPosition = .origin
        interpolationQuality = .bilinear
        slabThickness = nil
        projectionMode = .mip
        projectionDirection = .axial
        projectionSlabThickness = nil
        transferFunctionPreset = .bone
        shadingModel = .phong
        rotationX = 0
        rotationY = 0
        rotationZ = 0
        zoom = 1.0
        surfaceConfigurations = []
        selectedSurfaceID = nil
        volumeDimensions = nil
    }
}
