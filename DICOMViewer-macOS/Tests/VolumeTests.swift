// VolumeTests.swift
// DICOMViewer macOS - Volume Model Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

final class VolumeTests: XCTestCase {

    // MARK: - Volume Init Tests

    func testVolumeInit() {
        let data: [Float] = [Float](repeating: 0, count: 8)
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 2,
            spacingX: 0.5,
            spacingY: 0.5,
            spacingZ: 1.0
        )

        XCTAssertEqual(volume.width, 2)
        XCTAssertEqual(volume.height, 2)
        XCTAssertEqual(volume.depth, 2)
        XCTAssertEqual(volume.spacingX, 0.5)
        XCTAssertEqual(volume.spacingY, 0.5)
        XCTAssertEqual(volume.spacingZ, 1.0)
        XCTAssertEqual(volume.rescaleSlope, 1.0)
        XCTAssertEqual(volume.rescaleIntercept, 0.0)
        XCTAssertEqual(volume.windowCenter, 40.0)
        XCTAssertEqual(volume.windowWidth, 400.0)
    }

    func testVolumeInitWithCustomValues() {
        let data: [Float] = [1, 2, 3, 4, 5, 6, 7, 8]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 2,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 2.0,
            origin: (10.0, 20.0, 30.0),
            rescaleSlope: 1.5,
            rescaleIntercept: -1024.0,
            windowCenter: 300.0,
            windowWidth: 1500.0
        )

        XCTAssertEqual(volume.origin.x, 10.0)
        XCTAssertEqual(volume.origin.y, 20.0)
        XCTAssertEqual(volume.origin.z, 30.0)
        XCTAssertEqual(volume.rescaleSlope, 1.5)
        XCTAssertEqual(volume.rescaleIntercept, -1024.0)
        XCTAssertEqual(volume.windowCenter, 300.0)
        XCTAssertEqual(volume.windowWidth, 1500.0)
    }

    // MARK: - Voxel Access Tests

    func testVoxelValue() {
        // 2×2×2 volume with known values
        let data: [Float] = [
            // z=0: [[10, 20], [30, 40]]
            10, 20, 30, 40,
            // z=1: [[50, 60], [70, 80]]
            50, 60, 70, 80
        ]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 2,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        XCTAssertEqual(volume.voxelValue(x: 0, y: 0, z: 0), 10)
        XCTAssertEqual(volume.voxelValue(x: 1, y: 0, z: 0), 20)
        XCTAssertEqual(volume.voxelValue(x: 0, y: 1, z: 0), 30)
        XCTAssertEqual(volume.voxelValue(x: 1, y: 1, z: 0), 40)
        XCTAssertEqual(volume.voxelValue(x: 0, y: 0, z: 1), 50)
        XCTAssertEqual(volume.voxelValue(x: 1, y: 0, z: 1), 60)
        XCTAssertEqual(volume.voxelValue(x: 0, y: 1, z: 1), 70)
        XCTAssertEqual(volume.voxelValue(x: 1, y: 1, z: 1), 80)
    }

    func testVoxelValueOutOfBounds() {
        let data: [Float] = [1, 2, 3, 4]
        let volume = Volume(
            data: data,
            width: 2,
            height: 2,
            depth: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        XCTAssertNil(volume.voxelValue(x: -1, y: 0, z: 0))
        XCTAssertNil(volume.voxelValue(x: 0, y: -1, z: 0))
        XCTAssertNil(volume.voxelValue(x: 0, y: 0, z: -1))
        XCTAssertNil(volume.voxelValue(x: 2, y: 0, z: 0))
        XCTAssertNil(volume.voxelValue(x: 0, y: 2, z: 0))
        XCTAssertNil(volume.voxelValue(x: 0, y: 0, z: 1))
    }

    // MARK: - Voxel Count Tests

    func testVoxelCount() {
        let data: [Float] = [Float](repeating: 0, count: 24)
        let volume = Volume(
            data: data,
            width: 4,
            height: 3,
            depth: 2,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        XCTAssertEqual(volume.voxelCount, 24)
    }

    func testVoxelCountSingleVoxel() {
        let volume = Volume(
            data: [42],
            width: 1,
            height: 1,
            depth: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        XCTAssertEqual(volume.voxelCount, 1)
    }

    // MARK: - Physical Size Tests

    func testPhysicalSize() {
        let data: [Float] = [Float](repeating: 0, count: 60)
        let volume = Volume(
            data: data,
            width: 5,
            height: 4,
            depth: 3,
            spacingX: 0.5,
            spacingY: 0.75,
            spacingZ: 2.0
        )

        let size = volume.physicalSize
        XCTAssertEqual(size.x, 2.5, accuracy: 0.001)   // 5 * 0.5
        XCTAssertEqual(size.y, 3.0, accuracy: 0.001)   // 4 * 0.75
        XCTAssertEqual(size.z, 6.0, accuracy: 0.001)   // 3 * 2.0
    }

    func testPhysicalSizeIsotropic() {
        let data: [Float] = [Float](repeating: 0, count: 27)
        let volume = Volume(
            data: data,
            width: 3,
            height: 3,
            depth: 3,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        let size = volume.physicalSize
        XCTAssertEqual(size.x, 3.0, accuracy: 0.001)
        XCTAssertEqual(size.y, 3.0, accuracy: 0.001)
        XCTAssertEqual(size.z, 3.0, accuracy: 0.001)
    }

    // MARK: - MPRPlane Tests

    func testMPRPlane() {
        XCTAssertEqual(MPRPlane.axial.displayName, "Axial")
        XCTAssertEqual(MPRPlane.sagittal.displayName, "Sagittal")
        XCTAssertEqual(MPRPlane.coronal.displayName, "Coronal")

        XCTAssertEqual(MPRPlane.axial.id, "axial")
        XCTAssertEqual(MPRPlane.sagittal.id, "sagittal")
        XCTAssertEqual(MPRPlane.coronal.id, "coronal")

        XCTAssertEqual(MPRPlane.allCases.count, 3)
    }

    // MARK: - MPRSlice Tests

    func testMPRSlice() {
        let pixelData: [Float] = [1, 2, 3, 4, 5, 6]
        let slice = MPRSlice(
            plane: .axial,
            index: 5,
            width: 3,
            height: 2,
            pixelData: pixelData,
            pixelSpacingX: 0.5,
            pixelSpacingY: 0.75
        )

        XCTAssertEqual(slice.plane, .axial)
        XCTAssertEqual(slice.index, 5)
        XCTAssertEqual(slice.width, 3)
        XCTAssertEqual(slice.height, 2)
        XCTAssertEqual(slice.pixelData.count, 6)
        XCTAssertEqual(slice.pixelSpacingX, 0.5)
        XCTAssertEqual(slice.pixelSpacingY, 0.75)
    }

    func testMPRSliceIdentifiable() {
        let slice1 = MPRSlice(
            plane: .axial,
            index: 0,
            width: 1,
            height: 1,
            pixelData: [0],
            pixelSpacingX: 1.0,
            pixelSpacingY: 1.0
        )
        let slice2 = MPRSlice(
            plane: .axial,
            index: 0,
            width: 1,
            height: 1,
            pixelData: [0],
            pixelSpacingX: 1.0,
            pixelSpacingY: 1.0
        )

        // Each slice should have a unique ID
        XCTAssertNotEqual(slice1.id, slice2.id)
    }

    // MARK: - TransferFunction Tests

    func testTransferFunction() {
        let tf = TransferFunction(
            name: "Test",
            controlPoints: [
                TransferFunction.ControlPoint(
                    value: 0.0,
                    opacity: 0.0,
                    color: TransferFunction.RGBColor(red: 0, green: 0, blue: 0)
                ),
                TransferFunction.ControlPoint(
                    value: 1.0,
                    opacity: 1.0,
                    color: TransferFunction.RGBColor(red: 1, green: 1, blue: 1)
                )
            ]
        )

        XCTAssertEqual(tf.name, "Test")
        XCTAssertEqual(tf.controlPoints.count, 2)
        XCTAssertEqual(tf.controlPoints[0].value, 0.0)
        XCTAssertEqual(tf.controlPoints[0].opacity, 0.0)
        XCTAssertEqual(tf.controlPoints[1].value, 1.0)
        XCTAssertEqual(tf.controlPoints[1].opacity, 1.0)
    }

    func testTransferFunctionEquality() {
        let cp1 = TransferFunction.ControlPoint(
            value: 0.5,
            opacity: 0.5,
            color: TransferFunction.RGBColor(red: 1, green: 0, blue: 0)
        )
        let cp2 = TransferFunction.ControlPoint(
            value: 0.5,
            opacity: 0.5,
            color: TransferFunction.RGBColor(red: 1, green: 0, blue: 0)
        )

        XCTAssertEqual(cp1, cp2)
    }

    func testTransferFunctionPresets() {
        XCTAssertEqual(TransferFunction.bone.name, "Bone")
        XCTAssertEqual(TransferFunction.softTissue.name, "Soft Tissue")
        XCTAssertEqual(TransferFunction.lung.name, "Lung")
        XCTAssertEqual(TransferFunction.angiography.name, "Angiography")
        XCTAssertEqual(TransferFunction.mip.name, "MIP")

        XCTAssertFalse(TransferFunction.bone.controlPoints.isEmpty)
        XCTAssertFalse(TransferFunction.softTissue.controlPoints.isEmpty)
        XCTAssertFalse(TransferFunction.lung.controlPoints.isEmpty)
        XCTAssertFalse(TransferFunction.angiography.controlPoints.isEmpty)
        XCTAssertFalse(TransferFunction.mip.controlPoints.isEmpty)

        XCTAssertEqual(TransferFunction.allPresets.count, 5)
    }

    func testTransferFunctionMIPFullyOpaque() {
        let mip = TransferFunction.mip
        for point in mip.controlPoints {
            XCTAssertEqual(point.opacity, 1.0, "MIP transfer function should be fully opaque at all points")
        }
    }

    // MARK: - RenderingMode Tests

    func testRenderingMode() {
        XCTAssertEqual(RenderingMode.mip.displayName, "Maximum Intensity (MIP)")
        XCTAssertEqual(RenderingMode.minIP.displayName, "Minimum Intensity (MinIP)")
        XCTAssertEqual(RenderingMode.averageIP.displayName, "Average Intensity (AIP)")
        XCTAssertEqual(RenderingMode.volumeRendering.displayName, "Volume Rendering")

        XCTAssertEqual(RenderingMode.mip.id, "mip")
        XCTAssertEqual(RenderingMode.minIP.id, "minIP")
        XCTAssertEqual(RenderingMode.averageIP.id, "averageIP")
        XCTAssertEqual(RenderingMode.volumeRendering.id, "volumeRendering")

        XCTAssertEqual(RenderingMode.allCases.count, 4)
    }

    // MARK: - Volume Identifiable Tests

    func testVolumeIdentifiable() {
        let volume1 = Volume(
            data: [0],
            width: 1,
            height: 1,
            depth: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )
        let volume2 = Volume(
            data: [0],
            width: 1,
            height: 1,
            depth: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0
        )

        XCTAssertNotEqual(volume1.id, volume2.id)
    }

    // MARK: - RGBColor Tests

    func testRGBColor() {
        let color = TransferFunction.RGBColor(red: 0.5, green: 0.3, blue: 0.8)
        XCTAssertEqual(color.red, 0.5)
        XCTAssertEqual(color.green, 0.3)
        XCTAssertEqual(color.blue, 0.8)
    }

    func testRGBColorEquality() {
        let color1 = TransferFunction.RGBColor(red: 1.0, green: 0.0, blue: 0.0)
        let color2 = TransferFunction.RGBColor(red: 1.0, green: 0.0, blue: 0.0)
        let color3 = TransferFunction.RGBColor(red: 0.0, green: 1.0, blue: 0.0)

        XCTAssertEqual(color1, color2)
        XCTAssertNotEqual(color1, color3)
    }
}
