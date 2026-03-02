// MPRHelpersTests.swift
// DICOMStudioTests
//
// Tests for MPR calculation helpers (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Slice Index Tests

@Suite("MPRHelpers Slice Index Tests")
struct MPRHelpersSliceIndexTests {

    let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)

    @Test("Clamp within range")
    func testClampWithinRange() {
        let clamped = MPRHelpers.clampSliceIndex(50, plane: .axial, dimensions: dims)
        #expect(clamped == 50)
    }

    @Test("Clamp negative to 0")
    func testClampNegative() {
        let clamped = MPRHelpers.clampSliceIndex(-10, plane: .axial, dimensions: dims)
        #expect(clamped == 0)
    }

    @Test("Clamp above max")
    func testClampAboveMax() {
        let clamped = MPRHelpers.clampSliceIndex(200, plane: .axial, dimensions: dims)
        #expect(clamped == 99)
    }

    @Test("Clamp sagittal")
    func testClampSagittal() {
        let clamped = MPRHelpers.clampSliceIndex(600, plane: .sagittal, dimensions: dims)
        #expect(clamped == 511)
    }

    @Test("Clamp coronal")
    func testClampCoronal() {
        let clamped = MPRHelpers.clampSliceIndex(300, plane: .coronal, dimensions: dims)
        #expect(clamped == 255)
    }
}

// MARK: - Slice Position Tests

@Suite("MPRHelpers Slice Position Tests")
struct MPRHelpersSlicePositionTests {

    let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 2.0)

    @Test("Axial slice position")
    func testAxialPosition() {
        let pos = MPRHelpers.slicePosition(index: 10, plane: .axial, dimensions: dims)
        #expect(pos == 20.0) // 10 * 2.0
    }

    @Test("Sagittal slice position")
    func testSagittalPosition() {
        let pos = MPRHelpers.slicePosition(index: 20, plane: .sagittal, dimensions: dims)
        #expect(pos == 10.0) // 20 * 0.5
    }

    @Test("Coronal slice position")
    func testCoronalPosition() {
        let pos = MPRHelpers.slicePosition(index: 30, plane: .coronal, dimensions: dims)
        #expect(pos == 15.0) // 30 * 0.5
    }

    @Test("Slice index from position")
    func testSliceIndexFromPosition() {
        let index = MPRHelpers.sliceIndexFromPosition(20.0, plane: .axial, dimensions: dims)
        #expect(index == 10)
    }

    @Test("Slice index from position clamped")
    func testSliceIndexFromPositionClamped() {
        let index = MPRHelpers.sliceIndexFromPosition(1000.0, plane: .axial, dimensions: dims)
        #expect(index == 99)
    }

    @Test("Slice index from zero spacing returns 0")
    func testZeroSpacing() {
        let zeroDims = VolumeDimensionsModel(width: 10, height: 10, depth: 10, spacingX: 0, spacingY: 0, spacingZ: 0)
        let index = MPRHelpers.sliceIndexFromPosition(50.0, plane: .axial, dimensions: zeroDims)
        #expect(index == 0)
    }
}

// MARK: - Crosshair Synchronization Tests

@Suite("MPRHelpers Crosshair Tests")
struct MPRHelpersCrosshairTests {

    let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1.0, spacingY: 1.0, spacingZ: 2.0)

    @Test("Axial click updates all planes")
    func testAxialClick() {
        let result = MPRHelpers.synchronizeCrosshair(
            clickX: 128, clickY: 64, plane: .axial, currentSlice: 50, dimensions: dims
        )
        #expect(result.axialSlice == 50)
        #expect(result.sagittalSlice == 128)
        #expect(result.coronalSlice == 64)
        #expect(result.crosshair.voxelX == 128)
        #expect(result.crosshair.voxelY == 64)
        #expect(result.crosshair.voxelZ == 50)
    }

    @Test("Sagittal click updates all planes")
    func testSagittalClick() {
        let result = MPRHelpers.synchronizeCrosshair(
            clickX: 100, clickY: 40, plane: .sagittal, currentSlice: 200, dimensions: dims
        )
        #expect(result.sagittalSlice == 200)
        #expect(result.coronalSlice == 100)
        #expect(result.axialSlice == 40)
    }

    @Test("Coronal click updates all planes")
    func testCoronalClick() {
        let result = MPRHelpers.synchronizeCrosshair(
            clickX: 50, clickY: 30, plane: .coronal, currentSlice: 128, dimensions: dims
        )
        #expect(result.coronalSlice == 128)
        #expect(result.sagittalSlice == 50)
        #expect(result.axialSlice == 30)
    }

    @Test("Click out of bounds is clamped")
    func testClickClamped() {
        let result = MPRHelpers.synchronizeCrosshair(
            clickX: 1000, clickY: -10, plane: .axial, currentSlice: 50, dimensions: dims
        )
        #expect(result.sagittalSlice == 255)
        #expect(result.coronalSlice == 0)
    }

    @Test("Crosshair physical coordinates correct")
    func testPhysicalCoordinates() {
        let result = MPRHelpers.synchronizeCrosshair(
            clickX: 10, clickY: 20, plane: .axial, currentSlice: 5, dimensions: dims
        )
        #expect(result.crosshair.x == 10.0) // 10 * 1.0
        #expect(result.crosshair.y == 20.0) // 20 * 1.0
        #expect(result.crosshair.z == 10.0) // 5 * 2.0
    }
}

// MARK: - Reference Line Tests

@Suite("MPRHelpers Reference Line Tests")
struct MPRHelpersReferenceLineTests {

    let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1.0, spacingY: 1.0, spacingZ: 1.0)

    @Test("Same plane returns nil")
    func testSamePlane() {
        let result = MPRHelpers.referenceLinePosition(
            referencePlane: .axial, referenceSlice: 50, displayPlane: .axial, dimensions: dims
        )
        #expect(result == nil)
    }

    @Test("Sagittal in axial view")
    func testSagittalInAxial() {
        let result = MPRHelpers.referenceLinePosition(
            referencePlane: .sagittal, referenceSlice: 128, displayPlane: .axial, dimensions: dims
        )
        #expect(result != nil)
        // 128 / 255 ≈ 0.502
        #expect(abs(result! - 128.0 / 255.0) < 0.01)
    }

    @Test("Axial in sagittal view")
    func testAxialInSagittal() {
        let result = MPRHelpers.referenceLinePosition(
            referencePlane: .axial, referenceSlice: 50, displayPlane: .sagittal, dimensions: dims
        )
        #expect(result != nil)
        #expect(abs(result! - 50.0 / 99.0) < 0.01)
    }
}

// MARK: - Slab Range Tests

@Suite("MPRHelpers Slab Range Tests")
struct MPRHelpersSlabRangeTests {

    let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 1.0, spacingY: 1.0, spacingZ: 2.0)

    @Test("Slab range centered")
    func testCentered() {
        let range = MPRHelpers.slabRange(centerSlice: 50, thicknessMM: 10.0, plane: .axial, dimensions: dims)
        // 10mm / 2.0mm spacing = 5 slices → ±3
        #expect(range.start == 47)
        #expect(range.end == 53)
    }

    @Test("Slab range clamped at start")
    func testClampedStart() {
        let range = MPRHelpers.slabRange(centerSlice: 1, thicknessMM: 20.0, plane: .axial, dimensions: dims)
        #expect(range.start == 0)
    }

    @Test("Slab range clamped at end")
    func testClampedEnd() {
        let range = MPRHelpers.slabRange(centerSlice: 98, thicknessMM: 20.0, plane: .axial, dimensions: dims)
        #expect(range.end == 99)
    }
}

// MARK: - Slice Dimensions Tests

@Suite("MPRHelpers Slice Dimensions Tests")
struct MPRHelpersSliceDimensionsTests {

    let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)

    @Test("Axial slice dimensions")
    func testAxial() {
        let (w, h) = MPRHelpers.sliceDimensions(plane: .axial, dimensions: dims)
        #expect(w == 512)
        #expect(h == 256)
    }

    @Test("Sagittal slice dimensions")
    func testSagittal() {
        let (w, h) = MPRHelpers.sliceDimensions(plane: .sagittal, dimensions: dims)
        #expect(w == 256)
        #expect(h == 100)
    }

    @Test("Coronal slice dimensions")
    func testCoronal() {
        let (w, h) = MPRHelpers.sliceDimensions(plane: .coronal, dimensions: dims)
        #expect(w == 512)
        #expect(h == 100)
    }
}

// MARK: - Pixel Spacing Tests

@Suite("MPRHelpers Pixel Spacing Tests")
struct MPRHelpersPixelSpacingTests {

    let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.7, spacingZ: 2.0)

    @Test("Axial pixel spacing")
    func testAxial() {
        let (sx, sy) = MPRHelpers.slicePixelSpacing(plane: .axial, dimensions: dims)
        #expect(sx == 0.5)
        #expect(sy == 0.7)
    }

    @Test("Sagittal pixel spacing")
    func testSagittal() {
        let (sx, sy) = MPRHelpers.slicePixelSpacing(plane: .sagittal, dimensions: dims)
        #expect(sx == 0.7)
        #expect(sy == 2.0)
    }

    @Test("Coronal pixel spacing")
    func testCoronal() {
        let (sx, sy) = MPRHelpers.slicePixelSpacing(plane: .coronal, dimensions: dims)
        #expect(sx == 0.5)
        #expect(sy == 2.0)
    }
}

// MARK: - Display Label Tests

@Suite("MPRHelpers Display Label Tests")
struct MPRHelpersLabelTests {

    @Test("Plane labels")
    func testPlaneLabels() {
        #expect(MPRHelpers.planeLabel(.axial) == "Axial")
        #expect(MPRHelpers.planeLabel(.sagittal) == "Sagittal")
        #expect(MPRHelpers.planeLabel(.coronal) == "Coronal")
    }

    @Test("Plane symbols")
    func testPlaneSymbols() {
        #expect(!MPRHelpers.planeSymbol(.axial).isEmpty)
        #expect(!MPRHelpers.planeSymbol(.sagittal).isEmpty)
        #expect(!MPRHelpers.planeSymbol(.coronal).isEmpty)
    }
}
