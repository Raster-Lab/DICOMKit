// MPREngineTests.swift
// DICOMViewer macOS - MPR Engine Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

@MainActor
final class MPREngineTests: XCTestCase {

    private var engine: MPREngine!

    override func setUp() {
        super.setUp()
        engine = MPREngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Test Volume Helper

    /// Create a 4×3×2 test volume with predictable values.
    /// Value at (x, y, z) = Float(z * width * height + y * width + x)
    private func makeTestVolume(
        width: Int = 4,
        height: Int = 3,
        depth: Int = 2,
        spacingX: Double = 0.5,
        spacingY: Double = 0.5,
        spacingZ: Double = 1.0
    ) -> Volume {
        let count = width * height * depth
        var data = [Float](repeating: 0, count: count)
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    data[z * width * height + y * width + x] = Float(z * width * height + y * width + x)
                }
            }
        }
        return Volume(
            data: data,
            width: width,
            height: height,
            depth: depth,
            spacingX: spacingX,
            spacingY: spacingY,
            spacingZ: spacingZ,
            windowCenter: 12.0,
            windowWidth: 24.0
        )
    }

    // MARK: - Volume Creation Tests

    func testVolumeCreation() {
        let volume = makeTestVolume()

        XCTAssertEqual(volume.width, 4)
        XCTAssertEqual(volume.height, 3)
        XCTAssertEqual(volume.depth, 2)
        XCTAssertEqual(volume.data.count, 24)
    }

    func testVoxelAccess() {
        let volume = makeTestVolume()

        // z=0, y=0, x=0 → index 0
        XCTAssertEqual(volume.voxelValue(x: 0, y: 0, z: 0), 0)
        // z=0, y=0, x=3 → index 3
        XCTAssertEqual(volume.voxelValue(x: 3, y: 0, z: 0), 3)
        // z=0, y=1, x=0 → index 4
        XCTAssertEqual(volume.voxelValue(x: 0, y: 1, z: 0), 4)
        // z=1, y=0, x=0 → index 12
        XCTAssertEqual(volume.voxelValue(x: 0, y: 0, z: 1), 12)
        // z=1, y=2, x=3 → 12 + 2*4 + 3 = 23
        XCTAssertEqual(volume.voxelValue(x: 3, y: 2, z: 1), 23)
    }

    func testPhysicalSize() {
        let volume = makeTestVolume()
        let size = volume.physicalSize

        XCTAssertEqual(size.x, 2.0, accuracy: 0.001)   // 4 * 0.5
        XCTAssertEqual(size.y, 1.5, accuracy: 0.001)   // 3 * 0.5
        XCTAssertEqual(size.z, 2.0, accuracy: 0.001)   // 2 * 1.0
    }

    // MARK: - Axial Slice Tests

    func testExtractAxialSlice() {
        let volume = makeTestVolume()

        let slice0 = engine.extractAxialSlice(from: volume, at: 0)
        XCTAssertNotNil(slice0)
        XCTAssertEqual(slice0?.plane, .axial)
        XCTAssertEqual(slice0?.index, 0)
        XCTAssertEqual(slice0?.width, 4)
        XCTAssertEqual(slice0?.height, 3)
        XCTAssertEqual(slice0?.pixelData.count, 12)
        // Values should be 0..11 (first slice)
        XCTAssertEqual(slice0?.pixelData[0], 0)
        XCTAssertEqual(slice0?.pixelData[11], 11)

        let slice1 = engine.extractAxialSlice(from: volume, at: 1)
        XCTAssertNotNil(slice1)
        XCTAssertEqual(slice1?.index, 1)
        // Values should be 12..23 (second slice)
        XCTAssertEqual(slice1?.pixelData[0], 12)
        XCTAssertEqual(slice1?.pixelData[11], 23)
    }

    // MARK: - Sagittal Slice Tests

    func testExtractSagittalSlice() {
        let volume = makeTestVolume()

        // Sagittal at x=0 → depth × height = 2 × 3
        let slice = engine.extractSagittalSlice(from: volume, at: 0)
        XCTAssertNotNil(slice)
        XCTAssertEqual(slice?.plane, .sagittal)
        XCTAssertEqual(slice?.index, 0)
        XCTAssertEqual(slice?.width, 2)  // depth
        XCTAssertEqual(slice?.height, 3) // height
        XCTAssertEqual(slice?.pixelData.count, 6)

        // At x=0, the values are:
        // y=0: z=0→0, z=1→12
        // y=1: z=0→4, z=1→16
        // y=2: z=0→8, z=1→20
        XCTAssertEqual(slice?.pixelData[0 * 2 + 0], 0)  // y=0, z=0
        XCTAssertEqual(slice?.pixelData[0 * 2 + 1], 12) // y=0, z=1
        XCTAssertEqual(slice?.pixelData[1 * 2 + 0], 4)  // y=1, z=0
        XCTAssertEqual(slice?.pixelData[2 * 2 + 1], 20) // y=2, z=1
    }

    // MARK: - Coronal Slice Tests

    func testExtractCoronalSlice() {
        let volume = makeTestVolume()

        // Coronal at y=0 → width × depth = 4 × 2
        let slice = engine.extractCoronalSlice(from: volume, at: 0)
        XCTAssertNotNil(slice)
        XCTAssertEqual(slice?.plane, .coronal)
        XCTAssertEqual(slice?.index, 0)
        XCTAssertEqual(slice?.width, 4)  // width
        XCTAssertEqual(slice?.height, 2) // depth
        XCTAssertEqual(slice?.pixelData.count, 8)

        // At y=0, the values are:
        // z=0: x=0→0, x=1→1, x=2→2, x=3→3
        // z=1: x=0→12, x=1→13, x=2→14, x=3→15
        XCTAssertEqual(slice?.pixelData[0 * 4 + 0], 0)  // z=0, x=0
        XCTAssertEqual(slice?.pixelData[0 * 4 + 3], 3)  // z=0, x=3
        XCTAssertEqual(slice?.pixelData[1 * 4 + 0], 12) // z=1, x=0
        XCTAssertEqual(slice?.pixelData[1 * 4 + 3], 15) // z=1, x=3
    }

    // MARK: - Slice Index Bounds Tests

    func testSliceIndexBoundsAxial() {
        let volume = makeTestVolume()

        XCTAssertNil(engine.extractAxialSlice(from: volume, at: -1))
        XCTAssertNotNil(engine.extractAxialSlice(from: volume, at: 0))
        XCTAssertNotNil(engine.extractAxialSlice(from: volume, at: 1))
        XCTAssertNil(engine.extractAxialSlice(from: volume, at: 2))
    }

    func testSliceIndexBoundsSagittal() {
        let volume = makeTestVolume()

        XCTAssertNil(engine.extractSagittalSlice(from: volume, at: -1))
        XCTAssertNotNil(engine.extractSagittalSlice(from: volume, at: 0))
        XCTAssertNotNil(engine.extractSagittalSlice(from: volume, at: 3))
        XCTAssertNil(engine.extractSagittalSlice(from: volume, at: 4))
    }

    func testSliceIndexBoundsCoronal() {
        let volume = makeTestVolume()

        XCTAssertNil(engine.extractCoronalSlice(from: volume, at: -1))
        XCTAssertNotNil(engine.extractCoronalSlice(from: volume, at: 0))
        XCTAssertNotNil(engine.extractCoronalSlice(from: volume, at: 2))
        XCTAssertNil(engine.extractCoronalSlice(from: volume, at: 3))
    }

    // MARK: - Max Slice Index Tests

    func testMaxSliceIndex() {
        let volume = makeTestVolume() // 4×3×2

        XCTAssertEqual(engine.maxSliceIndex(for: .axial, in: volume), 1)    // depth-1
        XCTAssertEqual(engine.maxSliceIndex(for: .sagittal, in: volume), 3) // width-1
        XCTAssertEqual(engine.maxSliceIndex(for: .coronal, in: volume), 2)  // height-1
    }

    // MARK: - Extract Slice Generic Tests

    func testExtractSliceGeneric() {
        let volume = makeTestVolume()

        let axial = engine.extractSlice(from: volume, plane: .axial, at: 0)
        XCTAssertEqual(axial?.plane, .axial)

        let sagittal = engine.extractSlice(from: volume, plane: .sagittal, at: 0)
        XCTAssertEqual(sagittal?.plane, .sagittal)

        let coronal = engine.extractSlice(from: volume, plane: .coronal, at: 0)
        XCTAssertEqual(coronal?.plane, .coronal)
    }

    // MARK: - MIP Tests

    func testGenerateMIP() {
        // 2×2×3 volume: values increase with z
        let data: [Float] = [
            // z=0
            1, 2, 3, 4,
            // z=1
            5, 6, 7, 8,
            // z=2
            9, 10, 11, 12
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 3,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 6.0,
            windowWidth: 12.0
        )

        let mip = engine.generateMIP(from: volume, along: .axial)
        XCTAssertNotNil(mip)
        XCTAssertEqual(mip?.width, 2)
        XCTAssertEqual(mip?.height, 2)
        // MIP along Z: max of each column
        // (0,0): max(1, 5, 9) = 9
        // (1,0): max(2, 6, 10) = 10
        // (0,1): max(3, 7, 11) = 11
        // (1,1): max(4, 8, 12) = 12
        XCTAssertEqual(mip?.pixelData[0], 9)
        XCTAssertEqual(mip?.pixelData[1], 10)
        XCTAssertEqual(mip?.pixelData[2], 11)
        XCTAssertEqual(mip?.pixelData[3], 12)
    }

    func testGenerateMIPWithSlabThickness() {
        let data: [Float] = [
            // z=0
            1, 2, 3, 4,
            // z=1
            5, 6, 7, 8,
            // z=2
            9, 10, 11, 12
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 3,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 6.0,
            windowWidth: 12.0
        )

        // Only first 2 slices
        let mip = engine.generateMIP(from: volume, along: .axial, slabThickness: 2)
        XCTAssertNotNil(mip)
        // max(1,5)=5, max(2,6)=6, max(3,7)=7, max(4,8)=8
        XCTAssertEqual(mip?.pixelData[0], 5)
        XCTAssertEqual(mip?.pixelData[1], 6)
        XCTAssertEqual(mip?.pixelData[2], 7)
        XCTAssertEqual(mip?.pixelData[3], 8)
    }

    // MARK: - MinIP Tests

    func testGenerateMinIP() {
        let data: [Float] = [
            // z=0
            10, 20, 30, 40,
            // z=1
            5, 15, 25, 35,
            // z=2
            1, 2, 3, 4
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 3,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 20.0,
            windowWidth: 40.0
        )

        let minip = engine.generateMinIP(from: volume, along: .axial)
        XCTAssertNotNil(minip)
        // min along Z
        // (0,0): min(10, 5, 1) = 1
        // (1,0): min(20, 15, 2) = 2
        // (0,1): min(30, 25, 3) = 3
        // (1,1): min(40, 35, 4) = 4
        XCTAssertEqual(minip?.pixelData[0], 1)
        XCTAssertEqual(minip?.pixelData[1], 2)
        XCTAssertEqual(minip?.pixelData[2], 3)
        XCTAssertEqual(minip?.pixelData[3], 4)
    }

    // MARK: - Average IP Tests

    func testGenerateAverageIP() {
        let data: [Float] = [
            // z=0
            3, 6, 9, 12,
            // z=1
            6, 12, 18, 24,
            // z=2
            9, 18, 27, 36
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 3,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 15.0,
            windowWidth: 30.0
        )

        let avgip = engine.generateAverageIP(from: volume, along: .axial)
        XCTAssertNotNil(avgip)
        // avg along Z
        // (0,0): avg(3, 6, 9) = 6
        // (1,0): avg(6, 12, 18) = 12
        // (0,1): avg(9, 18, 27) = 18
        // (1,1): avg(12, 24, 36) = 24
        XCTAssertEqual(avgip?.pixelData[0], 6.0, accuracy: 0.01)
        XCTAssertEqual(avgip?.pixelData[1], 12.0, accuracy: 0.01)
        XCTAssertEqual(avgip?.pixelData[2], 18.0, accuracy: 0.01)
        XCTAssertEqual(avgip?.pixelData[3], 24.0, accuracy: 0.01)
    }

    // MARK: - Render Slice Tests

    func testRenderSlice() {
        let slice = MPRSlice(
            plane: .axial,
            index: 0,
            width: 2,
            height: 2,
            pixelData: [0, 50, 100, 200],
            pixelSpacingX: 1.0,
            pixelSpacingY: 1.0
        )

        let image = engine.renderSlice(slice, windowCenter: 100.0, windowWidth: 200.0)
        XCTAssertNotNil(image)
        XCTAssertEqual(Int(image!.size.width), 2)
        XCTAssertEqual(Int(image!.size.height), 2)
    }

    func testRenderSliceEmptyData() {
        let slice = MPRSlice(
            plane: .axial,
            index: 0,
            width: 0,
            height: 0,
            pixelData: [],
            pixelSpacingX: 1.0,
            pixelSpacingY: 1.0
        )

        let image = engine.renderSlice(slice, windowCenter: 100.0, windowWidth: 200.0)
        XCTAssertNil(image)
    }

    func testRenderSliceMismatchedData() {
        let slice = MPRSlice(
            plane: .axial,
            index: 0,
            width: 3,
            height: 3,
            pixelData: [1, 2],  // Only 2 values for 3×3
            pixelSpacingX: 1.0,
            pixelSpacingY: 1.0
        )

        let image = engine.renderSlice(slice, windowCenter: 100.0, windowWidth: 200.0)
        XCTAssertNil(image)
    }

    // MARK: - Sagittal and Coronal Projection Tests

    func testMIPAlongSagittal() {
        // 2×2×2 volume
        let data: [Float] = [
            // z=0: [[1, 10], [3, 30]]
            1, 10, 3, 30,
            // z=1: [[2, 20], [4, 40]]
            2, 20, 4, 40
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 2,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 20.0,
            windowWidth: 40.0
        )

        let mip = engine.generateMIP(from: volume, along: .sagittal)
        XCTAssertNotNil(mip)
        // Projection along X axis → output is depth(2) × height(2)
        XCTAssertEqual(mip?.width, 2)
        XCTAssertEqual(mip?.height, 2)
        // y=0: max along x: z=0→max(1,10)=10, z=1→max(2,20)=20
        // y=1: max along x: z=0→max(3,30)=30, z=1→max(4,40)=40
        XCTAssertEqual(mip?.pixelData[0 * 2 + 0], 10) // y=0, z=0
        XCTAssertEqual(mip?.pixelData[0 * 2 + 1], 20) // y=0, z=1
        XCTAssertEqual(mip?.pixelData[1 * 2 + 0], 30) // y=1, z=0
        XCTAssertEqual(mip?.pixelData[1 * 2 + 1], 40) // y=1, z=1
    }

    func testMIPAlongCoronal() {
        // 2×2×2 volume
        let data: [Float] = [
            // z=0: [[1, 2], [10, 20]]
            1, 2, 10, 20,
            // z=1: [[3, 4], [30, 40]]
            3, 4, 30, 40
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 2,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            windowCenter: 20.0,
            windowWidth: 40.0
        )

        let mip = engine.generateMIP(from: volume, along: .coronal)
        XCTAssertNotNil(mip)
        // Projection along Y axis → output is width(2) × depth(2)
        XCTAssertEqual(mip?.width, 2)
        XCTAssertEqual(mip?.height, 2)
        // z=0: max along y: x=0→max(1,10)=10, x=1→max(2,20)=20
        // z=1: max along y: x=0→max(3,30)=30, x=1→max(4,40)=40
        XCTAssertEqual(mip?.pixelData[0 * 2 + 0], 10) // z=0, x=0
        XCTAssertEqual(mip?.pixelData[0 * 2 + 1], 20) // z=0, x=1
        XCTAssertEqual(mip?.pixelData[1 * 2 + 0], 30) // z=1, x=0
        XCTAssertEqual(mip?.pixelData[1 * 2 + 1], 40) // z=1, x=1
    }

    // MARK: - Pixel Spacing Tests

    func testSlicePixelSpacing() {
        let volume = makeTestVolume(spacingX: 0.5, spacingY: 0.75, spacingZ: 2.0)

        let axial = engine.extractAxialSlice(from: volume, at: 0)
        XCTAssertEqual(axial?.pixelSpacingX, 0.5)
        XCTAssertEqual(axial?.pixelSpacingY, 0.75)

        let sagittal = engine.extractSagittalSlice(from: volume, at: 0)
        XCTAssertEqual(sagittal?.pixelSpacingX, 2.0)  // spacingZ
        XCTAssertEqual(sagittal?.pixelSpacingY, 0.75)  // spacingY

        let coronal = engine.extractCoronalSlice(from: volume, at: 0)
        XCTAssertEqual(coronal?.pixelSpacingX, 0.5)   // spacingX
        XCTAssertEqual(coronal?.pixelSpacingY, 2.0)    // spacingZ
    }
}
