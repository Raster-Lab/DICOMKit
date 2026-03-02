// VolumeVisualizationServiceTests.swift
// DICOMStudioTests
//
// Tests for VolumeVisualizationService (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Volume Dimensions Tests

@Suite("VolumeVisualizationService Dimensions Tests")
struct VolumeVisualizationServiceDimensionsTests {

    @Test("Initial state has no volume")
    func testInitialState() {
        let service = VolumeVisualizationService()
        #expect(!service.isVolumeLoaded())
        #expect(service.volumeDimensions() == nil)
    }

    @Test("Set volume dimensions")
    func testSetDimensions() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        service.setVolumeDimensions(dims)
        #expect(service.isVolumeLoaded())
        #expect(service.volumeDimensions()?.width == 256)
    }

    @Test("Setting dimensions resets to center slices")
    func testDimensionsResetCenter() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        service.setVolumeDimensions(dims)
        #expect(service.sliceIndex(for: .axial) == 50)
        #expect(service.sliceIndex(for: .sagittal) == 256)
        #expect(service.sliceIndex(for: .coronal) == 128)
    }
}

// MARK: - Slice Navigation Tests

@Suite("VolumeVisualizationService Slice Navigation Tests")
struct VolumeVisualizationServiceSliceTests {

    @Test("Set slice index")
    func testSetSliceIndex() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        service.setVolumeDimensions(dims)
        service.setSliceIndex(25, for: .axial)
        #expect(service.sliceIndex(for: .axial) == 25)
    }

    @Test("Set slice index clamped")
    func testSetSliceIndexClamped() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        service.setVolumeDimensions(dims)
        service.setSliceIndex(200, for: .axial)
        #expect(service.sliceIndex(for: .axial) == 99)
    }

    @Test("Set slice without volume does nothing")
    func testSetSliceNoVolume() {
        let service = VolumeVisualizationService()
        service.setSliceIndex(50, for: .axial)
        #expect(service.sliceIndex(for: .axial) == 0)
    }
}

// MARK: - Crosshair Navigation Tests

@Suite("VolumeVisualizationService Crosshair Tests")
struct VolumeVisualizationServiceCrosshairTests {

    @Test("Navigate crosshair updates all slices")
    func testNavigateCrosshair() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        service.setVolumeDimensions(dims)

        let crosshair = service.navigateCrosshair(clickX: 128, clickY: 64, plane: .axial)
        #expect(crosshair != nil)
        #expect(crosshair!.voxelX == 128)
        #expect(crosshair!.voxelY == 64)

        #expect(service.sliceIndex(for: .sagittal) == 128)
        #expect(service.sliceIndex(for: .coronal) == 64)
    }

    @Test("Navigate without volume returns nil")
    func testNavigateNoVolume() {
        let service = VolumeVisualizationService()
        let result = service.navigateCrosshair(clickX: 50, clickY: 50, plane: .axial)
        #expect(result == nil)
    }

    @Test("Crosshair position")
    func testCrosshairPosition() {
        let service = VolumeVisualizationService()
        let initial = service.crosshairPosition()
        #expect(initial == CrosshairPosition3D.origin)
    }
}

// MARK: - MPR Configuration Tests

@Suite("VolumeVisualizationService MPR Config Tests")
struct VolumeVisualizationServiceMPRConfigTests {

    @Test("Default MPR configuration")
    func testDefaultConfig() {
        let service = VolumeVisualizationService()
        let config = service.mprConfiguration(for: .axial)
        #expect(config.plane == .axial)
        #expect(config.interpolation == .bilinear)
    }

    @Test("Set interpolation quality")
    func testSetInterpolation() {
        let service = VolumeVisualizationService()
        service.setInterpolation(.bicubic, for: .axial)
        let config = service.mprConfiguration(for: .axial)
        #expect(config.interpolation == .bicubic)
    }

    @Test("Set slice thickness")
    func testSetSliceThickness() {
        let service = VolumeVisualizationService()
        service.setSliceThickness(5.0, for: .axial)
        let config = service.mprConfiguration(for: .axial)
        #expect(config.sliceThickness == 5.0)
    }
}

// MARK: - Oblique Plane Tests

@Suite("VolumeVisualizationService Oblique Plane Tests")
struct VolumeVisualizationServiceObliqueTests {

    @Test("Initial oblique is nil")
    func testInitialNil() {
        let service = VolumeVisualizationService()
        #expect(service.obliquePlane() == nil)
    }

    @Test("Set and get oblique plane")
    func testSetOblique() {
        let service = VolumeVisualizationService()
        let oblique = ObliquePlaneConfiguration(normalX: 0, normalY: 0, normalZ: 1, centerX: 0, centerY: 0, centerZ: 50)
        service.setObliquePlane(oblique)
        #expect(service.obliquePlane() != nil)
    }

    @Test("Clear oblique plane")
    func testClearOblique() {
        let service = VolumeVisualizationService()
        let oblique = ObliquePlaneConfiguration(normalX: 0, normalY: 0, normalZ: 1, centerX: 0, centerY: 0, centerZ: 50)
        service.setObliquePlane(oblique)
        service.setObliquePlane(nil)
        #expect(service.obliquePlane() == nil)
    }
}

// MARK: - Projection Configuration Tests

@Suite("VolumeVisualizationService Projection Tests")
struct VolumeVisualizationServiceProjectionTests {

    @Test("Default projection is MIP axial")
    func testDefault() {
        let service = VolumeVisualizationService()
        let config = service.projectionConfiguration()
        #expect(config.mode == .mip)
    }

    @Test("Set projection configuration")
    func testSetProjection() {
        let service = VolumeVisualizationService()
        let config = ProjectionConfiguration(mode: .minIP, direction: .coronal, slabThickness: 20.0)
        service.setProjectionConfiguration(config)
        let result = service.projectionConfiguration()
        #expect(result.mode == .minIP)
        #expect(result.direction == .coronal)
        #expect(result.slabThickness == 20.0)
    }
}

// MARK: - Volume Rendering Tests

@Suite("VolumeVisualizationService Volume Rendering Tests")
struct VolumeVisualizationServiceVolumeRenderingTests {

    @Test("Default volume rendering config")
    func testDefault() {
        let service = VolumeVisualizationService()
        let config = service.volumeRenderingConfiguration()
        #expect(config.shadingModel == .phong)
        #expect(!config.isEnabled)
    }

    @Test("Apply preset")
    func testApplyPreset() {
        let service = VolumeVisualizationService()
        service.applyPreset(.bone)
        let config = service.volumeRenderingConfiguration()
        #expect(config.preset == .bone)
        #expect(!config.transferFunction.isEmpty)
    }

    @Test("Set volume rendering configuration")
    func testSetConfig() {
        let service = VolumeVisualizationService()
        let tf = VolumeRenderingHelpers.transferFunction(for: .vascular)
        let config = VolumeRenderingConfiguration(transferFunction: tf, preset: .vascular, isEnabled: true)
        service.setVolumeRenderingConfiguration(config)
        let result = service.volumeRenderingConfiguration()
        #expect(result.isEnabled)
        #expect(result.preset == .vascular)
    }
}

// MARK: - Surface Configuration Tests

@Suite("VolumeVisualizationService Surface Tests")
struct VolumeVisualizationServiceSurfaceTests {

    @Test("Initial surfaces are empty")
    func testInitialEmpty() {
        let service = VolumeVisualizationService()
        #expect(service.surfaceConfigurations().isEmpty)
    }

    @Test("Add surface")
    func testAddSurface() {
        let service = VolumeVisualizationService()
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        service.addSurface(surface)
        #expect(service.surfaceConfigurations().count == 1)
    }

    @Test("Remove surface")
    func testRemoveSurface() {
        let service = VolumeVisualizationService()
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        service.addSurface(surface)
        let removed = service.removeSurface(id: surface.id)
        #expect(removed != nil)
        #expect(service.surfaceConfigurations().isEmpty)
    }

    @Test("Remove non-existent surface returns nil")
    func testRemoveNonExistent() {
        let service = VolumeVisualizationService()
        let removed = service.removeSurface(id: UUID())
        #expect(removed == nil)
    }

    @Test("Update surface")
    func testUpdateSurface() {
        let service = VolumeVisualizationService()
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        service.addSurface(surface)
        let updated = surface.withThreshold(500)
        service.updateSurface(updated)
        let surfaces = service.surfaceConfigurations()
        #expect(surfaces[0].threshold == 500)
    }

    @Test("Mesh statistics")
    func testMeshStatistics() {
        let service = VolumeVisualizationService()
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        service.addSurface(surface)
        let stats = MeshStatistics(vertexCount: 1000, triangleCount: 2000, threshold: 300)
        service.setMeshStatistics(stats, for: surface.id)
        let result = service.meshStatistics(for: surface.id)
        #expect(result?.vertexCount == 1000)
    }
}

// MARK: - Active Mode Tests

@Suite("VolumeVisualizationService Active Mode Tests")
struct VolumeVisualizationServiceModeTests {

    @Test("Default mode is MPR")
    func testDefaultMode() {
        let service = VolumeVisualizationService()
        #expect(service.activeMode() == .mpr)
    }

    @Test("Set active mode")
    func testSetMode() {
        let service = VolumeVisualizationService()
        service.setActiveMode(.volumeRendering)
        #expect(service.activeMode() == .volumeRendering)
    }
}

// MARK: - Reset Tests

@Suite("VolumeVisualizationService Reset Tests")
struct VolumeVisualizationServiceResetTests {

    @Test("Reset clears all state")
    func testReset() {
        let service = VolumeVisualizationService()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        service.setVolumeDimensions(dims)
        service.setSliceIndex(50, for: .axial)
        service.addSurface(SurfaceConfiguration(label: "Bone", threshold: 300))
        service.setActiveMode(.volumeRendering)

        service.resetAll()

        #expect(!service.isVolumeLoaded())
        #expect(service.sliceIndex(for: .axial) == 0)
        #expect(service.surfaceConfigurations().isEmpty)
        #expect(service.activeMode() == .mpr)
    }
}
