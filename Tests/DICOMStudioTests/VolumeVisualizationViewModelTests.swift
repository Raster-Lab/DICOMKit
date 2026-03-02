// VolumeVisualizationViewModelTests.swift
// DICOMStudioTests
//
// Tests for VolumeVisualizationViewModel (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Initial State Tests

@Suite("VolumeVisualizationViewModel Initial State Tests")
struct VolumeVisualizationViewModelInitialTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial state defaults")
    func testInitialState() {
        let vm = VolumeVisualizationViewModel()
        #expect(vm.activeMode == .mpr)
        #expect(vm.axialSlice == 0)
        #expect(vm.sagittalSlice == 0)
        #expect(vm.coronalSlice == 0)
        #expect(vm.crosshairPosition == .origin)
        #expect(vm.crosshairLinkingEnabled)
        #expect(vm.showReferenceLines)
        #expect(!vm.isVolumeLoaded)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial projection state")
    func testInitialProjectionState() {
        let vm = VolumeVisualizationViewModel()
        #expect(vm.projectionMode == .mip)
        #expect(vm.projectionDirection == .axial)
        #expect(vm.projectionSlabThickness == nil)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial volume rendering state")
    func testInitialVolumeRenderingState() {
        let vm = VolumeVisualizationViewModel()
        #expect(vm.transferFunctionPreset == .bone)
        #expect(vm.shadingModel == .phong)
        #expect(vm.rotationX == 0)
        #expect(vm.zoom == 1.0)
        #expect(!vm.showTransferFunctionEditor)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial surface state")
    func testInitialSurfaceState() {
        let vm = VolumeVisualizationViewModel()
        #expect(vm.surfaceConfigurations.isEmpty)
        #expect(vm.selectedSurfaceID == nil)
        #expect(vm.exportFormat == .stl)
    }
}

// MARK: - Volume Loading Tests

@Suite("VolumeVisualizationViewModel Volume Loading Tests")
struct VolumeVisualizationViewModelLoadingTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Load volume sets dimensions and center slices")
    func testLoadVolume() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        vm.loadVolume(dimensions: dims)

        #expect(vm.isVolumeLoaded)
        #expect(vm.axialSlice == 50)
        #expect(vm.sagittalSlice == 256)
        #expect(vm.coronalSlice == 128)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Load volume updates crosshair to center")
    func testLoadVolumeUpdatesCrosshair() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 100, height: 100, depth: 100, spacingX: 1.0, spacingY: 1.0, spacingZ: 1.0)
        vm.loadVolume(dimensions: dims)

        #expect(vm.crosshairPosition.voxelX == 50)
        #expect(vm.crosshairPosition.voxelY == 50)
        #expect(vm.crosshairPosition.voxelZ == 50)
    }
}

// MARK: - Slice Navigation Tests

@Suite("VolumeVisualizationViewModel Slice Navigation Tests")
struct VolumeVisualizationViewModelNavigationTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Scroll forward")
    func testScrollForward() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)

        vm.scroll(plane: .axial, delta: 5)
        #expect(vm.axialSlice == 55)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Scroll backward")
    func testScrollBackward() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)

        vm.scroll(plane: .axial, delta: -100)
        #expect(vm.axialSlice == 0)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Scroll without volume does nothing")
    func testScrollNoVolume() {
        let vm = VolumeVisualizationViewModel()
        vm.scroll(plane: .axial, delta: 5)
        #expect(vm.axialSlice == 0)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set slice index directly")
    func testSetSliceIndex() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)

        vm.setSliceIndex(75, for: .axial)
        #expect(vm.axialSlice == 75)
    }
}

// MARK: - Crosshair Interaction Tests

@Suite("VolumeVisualizationViewModel Crosshair Tests")
struct VolumeVisualizationViewModelCrosshairTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Click in plane updates crosshair")
    func testClickInPlane() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)

        vm.clickInPlane(.axial, x: 128, y: 64)
        #expect(vm.sagittalSlice == 128)
        #expect(vm.coronalSlice == 64)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Click with linking disabled does nothing")
    func testClickLinkingDisabled() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)

        vm.crosshairLinkingEnabled = false
        vm.clickInPlane(.axial, x: 10, y: 10)
        // Should not change from center slices
        #expect(vm.sagittalSlice == 128)
        #expect(vm.coronalSlice == 128)
    }
}

// MARK: - Mode Selection Tests

@Suite("VolumeVisualizationViewModel Mode Selection Tests")
struct VolumeVisualizationViewModelModeTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set mode")
    func testSetMode() {
        let vm = VolumeVisualizationViewModel()
        vm.setMode(.volumeRendering)
        #expect(vm.activeMode == .volumeRendering)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Mode persists in service")
    func testModeInService() {
        let vm = VolumeVisualizationViewModel()
        vm.setMode(.projection)
        #expect(vm.visualizationService.activeMode() == .projection)
    }
}

// MARK: - Projection Control Tests

@Suite("VolumeVisualizationViewModel Projection Tests")
struct VolumeVisualizationViewModelProjectionTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Update projection mode")
    func testUpdateMode() {
        let vm = VolumeVisualizationViewModel()
        vm.updateProjection(mode: .minIP)
        #expect(vm.projectionMode == .minIP)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Update projection direction")
    func testUpdateDirection() {
        let vm = VolumeVisualizationViewModel()
        vm.updateProjection(direction: .coronal)
        #expect(vm.projectionDirection == .coronal)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Update projection slab")
    func testUpdateSlab() {
        let vm = VolumeVisualizationViewModel()
        vm.updateProjection(slabThickness: 15.0)
        #expect(vm.projectionSlabThickness == 15.0)
    }
}

// MARK: - Volume Rendering Tests

@Suite("VolumeVisualizationViewModel Volume Rendering Tests")
struct VolumeVisualizationViewModelVolumeRenderingTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Apply preset updates state")
    func testApplyPreset() {
        let vm = VolumeVisualizationViewModel()
        vm.applyPreset(.vascular)
        #expect(vm.transferFunctionPreset == .vascular)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set rotation")
    func testSetRotation() {
        let vm = VolumeVisualizationViewModel()
        vm.setRotation(x: 30, y: 45, z: 0)
        #expect(vm.rotationX == 30)
        #expect(vm.rotationY == 45)
        #expect(vm.rotationZ == 0)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set zoom clamped")
    func testSetZoom() {
        let vm = VolumeVisualizationViewModel()
        vm.setZoom(2.5)
        #expect(vm.zoom == 2.5)

        vm.setZoom(0.01)
        #expect(vm.zoom == 0.1)
    }
}

// MARK: - Surface Management Tests

@Suite("VolumeVisualizationViewModel Surface Tests")
struct VolumeVisualizationViewModelSurfaceTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Add surface")
    func testAddSurface() {
        let vm = VolumeVisualizationViewModel()
        vm.addSurface(label: "Bone", threshold: 300)
        #expect(vm.surfaceConfigurations.count == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Remove surface")
    func testRemoveSurface() {
        let vm = VolumeVisualizationViewModel()
        vm.addSurface(label: "Bone", threshold: 300)
        let id = vm.surfaceConfigurations[0].id
        vm.removeSurface(id: id)
        #expect(vm.surfaceConfigurations.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Remove surface clears selection")
    func testRemoveSurfaceClearsSelection() {
        let vm = VolumeVisualizationViewModel()
        vm.addSurface(label: "Bone", threshold: 300)
        let id = vm.surfaceConfigurations[0].id
        vm.selectedSurfaceID = id
        vm.removeSurface(id: id)
        #expect(vm.selectedSurfaceID == nil)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Toggle surface visibility")
    func testToggleVisibility() {
        let vm = VolumeVisualizationViewModel()
        vm.addSurface(label: "Bone", threshold: 300)
        let id = vm.surfaceConfigurations[0].id
        #expect(vm.surfaceConfigurations[0].isVisible)

        vm.toggleSurfaceVisibility(id: id)
        #expect(!vm.surfaceConfigurations[0].isVisible)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Visible surface count")
    func testVisibleSurfaceCount() {
        let vm = VolumeVisualizationViewModel()
        vm.addSurface(label: "Bone", threshold: 300)
        vm.addSurface(label: "Skin", threshold: -200)
        #expect(vm.visibleSurfaceCount == 2)

        let id = vm.surfaceConfigurations[0].id
        vm.toggleSurfaceVisibility(id: id)
        #expect(vm.visibleSurfaceCount == 1)
    }
}

// MARK: - Interpolation Tests

@Suite("VolumeVisualizationViewModel Interpolation Tests")
struct VolumeVisualizationViewModelInterpolationTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set interpolation quality")
    func testSetInterpolation() {
        let vm = VolumeVisualizationViewModel()
        vm.setInterpolation(.bicubic)
        #expect(vm.interpolationQuality == .bicubic)
    }
}

// MARK: - Reset Tests

@Suite("VolumeVisualizationViewModel Reset Tests")
struct VolumeVisualizationViewModelResetTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Reset clears all state")
    func testReset() {
        let vm = VolumeVisualizationViewModel()
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1, spacingY: 1, spacingZ: 1)
        vm.loadVolume(dimensions: dims)
        vm.addSurface(label: "Bone", threshold: 300)
        vm.setMode(.volumeRendering)
        vm.setRotation(x: 30, y: 45, z: 60)

        vm.resetVisualization()

        #expect(!vm.isVolumeLoaded)
        #expect(vm.activeMode == .mpr)
        #expect(vm.axialSlice == 0)
        #expect(vm.surfaceConfigurations.isEmpty)
        #expect(vm.rotationX == 0)
        #expect(vm.zoom == 1.0)
    }
}
