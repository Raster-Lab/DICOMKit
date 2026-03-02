// VolumeVisualizationService.swift
// DICOMStudio
//
// DICOM Studio — Service for 3D visualization state management

import Foundation

/// Thread-safe service managing 3D visualization state including MPR planes,
/// projection settings, volume rendering parameters, surface configurations,
/// and crosshair synchronization.
public final class VolumeVisualizationService: @unchecked Sendable {

    /// Lock for thread-safe access.
    private let lock = NSLock()

    // MARK: - Volume State

    /// Volume dimensions and spacing (nil if no volume loaded).
    private var _volumeDimensions: VolumeDimensionsModel?

    /// Current axial slice index.
    private var _axialSlice: Int = 0

    /// Current sagittal slice index.
    private var _sagittalSlice: Int = 0

    /// Current coronal slice index.
    private var _coronalSlice: Int = 0

    /// Current 3D crosshair position.
    private var _crosshairPosition: CrosshairPosition3D = .origin

    // MARK: - Configuration State

    /// MPR configurations keyed by plane.
    private var _mprConfigurations: [MPRPlane: MPRSliceConfiguration]

    /// Active oblique plane (nil if none).
    private var _obliquePlane: ObliquePlaneConfiguration?

    /// Current projection configuration.
    private var _projectionConfiguration: ProjectionConfiguration

    /// Volume rendering configuration.
    private var _volumeRenderingConfiguration: VolumeRenderingConfiguration

    /// Surface configurations.
    private var _surfaceConfigurations: [SurfaceConfiguration]

    /// Active visualization mode.
    private var _activeMode: VisualizationMode

    /// Mesh statistics keyed by surface ID.
    private var _meshStatistics: [UUID: MeshStatistics]

    // MARK: - Initialization

    /// Creates a new volume visualization service with default settings.
    public init() {
        _mprConfigurations = [
            .axial: MPRSliceConfiguration(plane: .axial),
            .sagittal: MPRSliceConfiguration(plane: .sagittal),
            .coronal: MPRSliceConfiguration(plane: .coronal),
        ]
        _projectionConfiguration = ProjectionConfiguration(mode: .mip)
        _volumeRenderingConfiguration = VolumeRenderingConfiguration()
        _surfaceConfigurations = []
        _activeMode = .mpr
        _meshStatistics = [:]
    }

    // MARK: - Volume Dimensions

    /// Sets the volume dimensions.
    public func setVolumeDimensions(_ dimensions: VolumeDimensionsModel) {
        lock.lock()
        defer { lock.unlock() }
        _volumeDimensions = dimensions
        // Reset slices to center
        _axialSlice = dimensions.depth / 2
        _sagittalSlice = dimensions.width / 2
        _coronalSlice = dimensions.height / 2
        // Update MPR configs
        _mprConfigurations[.axial] = _mprConfigurations[.axial]?.withSliceIndex(_axialSlice)
        _mprConfigurations[.sagittal] = _mprConfigurations[.sagittal]?.withSliceIndex(_sagittalSlice)
        _mprConfigurations[.coronal] = _mprConfigurations[.coronal]?.withSliceIndex(_coronalSlice)
    }

    /// Returns the current volume dimensions.
    public func volumeDimensions() -> VolumeDimensionsModel? {
        lock.lock()
        defer { lock.unlock() }
        return _volumeDimensions
    }

    /// Whether a volume is loaded.
    public func isVolumeLoaded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _volumeDimensions != nil
    }

    // MARK: - Slice Navigation

    /// Returns the current slice index for a plane.
    public func sliceIndex(for plane: MPRPlane) -> Int {
        lock.lock()
        defer { lock.unlock() }
        switch plane {
        case .axial: return _axialSlice
        case .sagittal: return _sagittalSlice
        case .coronal: return _coronalSlice
        }
    }

    /// Sets the slice index for a plane (clamped to valid range).
    public func setSliceIndex(_ index: Int, for plane: MPRPlane) {
        lock.lock()
        defer { lock.unlock() }
        guard let dims = _volumeDimensions else { return }
        let clamped = MPRHelpers.clampSliceIndex(index, plane: plane, dimensions: dims)
        switch plane {
        case .axial: _axialSlice = clamped
        case .sagittal: _sagittalSlice = clamped
        case .coronal: _coronalSlice = clamped
        }
        _mprConfigurations[plane] = _mprConfigurations[plane]?.withSliceIndex(clamped)
    }

    /// Navigates to a 3D crosshair position, updating all slice indices.
    ///
    /// - Parameters:
    ///   - clickX: X coordinate in the clicked plane's image.
    ///   - clickY: Y coordinate in the clicked plane's image.
    ///   - plane: The plane that was clicked.
    /// - Returns: The new crosshair position, or nil if no volume loaded.
    @discardableResult
    public func navigateCrosshair(clickX: Int, clickY: Int, plane: MPRPlane) -> CrosshairPosition3D? {
        lock.lock()
        defer { lock.unlock() }
        guard let dims = _volumeDimensions else { return nil }

        let currentSlice: Int
        switch plane {
        case .axial: currentSlice = _axialSlice
        case .sagittal: currentSlice = _sagittalSlice
        case .coronal: currentSlice = _coronalSlice
        }

        let result = MPRHelpers.synchronizeCrosshair(
            clickX: clickX, clickY: clickY,
            plane: plane, currentSlice: currentSlice,
            dimensions: dims
        )

        _axialSlice = result.axialSlice
        _sagittalSlice = result.sagittalSlice
        _coronalSlice = result.coronalSlice
        _crosshairPosition = result.crosshair

        // Update MPR configs
        _mprConfigurations[.axial] = _mprConfigurations[.axial]?.withSliceIndex(_axialSlice)
        _mprConfigurations[.sagittal] = _mprConfigurations[.sagittal]?.withSliceIndex(_sagittalSlice)
        _mprConfigurations[.coronal] = _mprConfigurations[.coronal]?.withSliceIndex(_coronalSlice)

        return _crosshairPosition
    }

    /// Returns the current crosshair position.
    public func crosshairPosition() -> CrosshairPosition3D {
        lock.lock()
        defer { lock.unlock() }
        return _crosshairPosition
    }

    // MARK: - MPR Configuration

    /// Returns the MPR configuration for a plane.
    public func mprConfiguration(for plane: MPRPlane) -> MPRSliceConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return _mprConfigurations[plane] ?? MPRSliceConfiguration(plane: plane)
    }

    /// Sets the interpolation quality for a plane.
    public func setInterpolation(_ quality: InterpolationQuality, for plane: MPRPlane) {
        lock.lock()
        defer { lock.unlock() }
        _mprConfigurations[plane] = _mprConfigurations[plane]?.withInterpolation(quality)
    }

    /// Sets the slice thickness for a plane.
    public func setSliceThickness(_ thickness: Double?, for plane: MPRPlane) {
        lock.lock()
        defer { lock.unlock() }
        _mprConfigurations[plane] = _mprConfigurations[plane]?.withSliceThickness(thickness)
    }

    // MARK: - Oblique Plane

    /// Sets an oblique plane configuration.
    public func setObliquePlane(_ config: ObliquePlaneConfiguration?) {
        lock.lock()
        defer { lock.unlock() }
        _obliquePlane = config
    }

    /// Returns the current oblique plane configuration.
    public func obliquePlane() -> ObliquePlaneConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        return _obliquePlane
    }

    // MARK: - Projection Configuration

    /// Sets the projection configuration.
    public func setProjectionConfiguration(_ config: ProjectionConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        _projectionConfiguration = config
    }

    /// Returns the current projection configuration.
    public func projectionConfiguration() -> ProjectionConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return _projectionConfiguration
    }

    // MARK: - Volume Rendering

    /// Sets the volume rendering configuration.
    public func setVolumeRenderingConfiguration(_ config: VolumeRenderingConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        _volumeRenderingConfiguration = config
    }

    /// Returns the current volume rendering configuration.
    public func volumeRenderingConfiguration() -> VolumeRenderingConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return _volumeRenderingConfiguration
    }

    /// Applies a transfer function preset.
    public func applyPreset(_ preset: TransferFunctionPreset) {
        lock.lock()
        defer { lock.unlock() }
        let tf = VolumeRenderingHelpers.transferFunction(for: preset)
        _volumeRenderingConfiguration = VolumeRenderingConfiguration(
            transferFunction: tf,
            preset: preset,
            shadingModel: _volumeRenderingConfiguration.shadingModel,
            ambientCoefficient: _volumeRenderingConfiguration.ambientCoefficient,
            diffuseCoefficient: _volumeRenderingConfiguration.diffuseCoefficient,
            specularCoefficient: _volumeRenderingConfiguration.specularCoefficient,
            specularExponent: _volumeRenderingConfiguration.specularExponent,
            rotationX: _volumeRenderingConfiguration.rotationX,
            rotationY: _volumeRenderingConfiguration.rotationY,
            rotationZ: _volumeRenderingConfiguration.rotationZ,
            zoom: _volumeRenderingConfiguration.zoom,
            clipPlanes: _volumeRenderingConfiguration.clipPlanes,
            isEnabled: _volumeRenderingConfiguration.isEnabled
        )
    }

    // MARK: - Surface Configurations

    /// Returns all surface configurations.
    public func surfaceConfigurations() -> [SurfaceConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        return _surfaceConfigurations
    }

    /// Adds a surface configuration.
    public func addSurface(_ config: SurfaceConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        _surfaceConfigurations.append(config)
    }

    /// Removes a surface configuration by ID.
    @discardableResult
    public func removeSurface(id: UUID) -> SurfaceConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = _surfaceConfigurations.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let removed = _surfaceConfigurations.remove(at: index)
        _meshStatistics.removeValue(forKey: id)
        return removed
    }

    /// Updates a surface configuration.
    public func updateSurface(_ config: SurfaceConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = _surfaceConfigurations.firstIndex(where: { $0.id == config.id }) else {
            return
        }
        _surfaceConfigurations[index] = config
    }

    /// Stores mesh statistics for a surface.
    public func setMeshStatistics(_ stats: MeshStatistics, for surfaceID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        _meshStatistics[surfaceID] = stats
    }

    /// Returns mesh statistics for a surface.
    public func meshStatistics(for surfaceID: UUID) -> MeshStatistics? {
        lock.lock()
        defer { lock.unlock() }
        return _meshStatistics[surfaceID]
    }

    // MARK: - Active Mode

    /// Sets the active visualization mode.
    public func setActiveMode(_ mode: VisualizationMode) {
        lock.lock()
        defer { lock.unlock() }
        _activeMode = mode
    }

    /// Returns the active visualization mode.
    public func activeMode() -> VisualizationMode {
        lock.lock()
        defer { lock.unlock() }
        return _activeMode
    }

    // MARK: - Reset

    /// Resets all state to defaults.
    public func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        _volumeDimensions = nil
        _axialSlice = 0
        _sagittalSlice = 0
        _coronalSlice = 0
        _crosshairPosition = .origin
        _mprConfigurations = [
            .axial: MPRSliceConfiguration(plane: .axial),
            .sagittal: MPRSliceConfiguration(plane: .sagittal),
            .coronal: MPRSliceConfiguration(plane: .coronal),
        ]
        _obliquePlane = nil
        _projectionConfiguration = ProjectionConfiguration(mode: .mip)
        _volumeRenderingConfiguration = VolumeRenderingConfiguration()
        _surfaceConfigurations = []
        _activeMode = .mpr
        _meshStatistics = [:]
    }
}
