// VolumeRenderingViewModelTests.swift
// DICOMViewer macOS - Volume Rendering ViewModel Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

@MainActor
final class VolumeRenderingViewModelTests: XCTestCase {

    private var viewModel: VolumeRenderingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = VolumeRenderingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Test Volume Helper

    private func makeTestVolume() -> Volume {
        let width = 4
        let height = 3
        let depth = 2
        let count = width * height * depth
        var data = [Float](repeating: 0, count: count)
        for i in 0..<count {
            data[i] = Float(i)
        }
        return Volume(
            data: data,
            width: width,
            height: height,
            depth: depth,
            spacingX: 0.5,
            spacingY: 0.5,
            spacingZ: 1.0,
            windowCenter: 12.0,
            windowWidth: 24.0
        )
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(viewModel.volume)
        XCTAssertNil(viewModel.renderedImage)
        XCTAssertEqual(viewModel.renderingMode, .mip)
        XCTAssertEqual(viewModel.transferFunction, .bone)
        XCTAssertEqual(viewModel.rotationX, 0)
        XCTAssertEqual(viewModel.rotationY, 0)
        XCTAssertEqual(viewModel.zoom, 1.0)
        XCTAssertEqual(viewModel.slabThickness, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Rendering Mode Tests

    func testRenderingModeChange() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.renderingMode = .minIP
        XCTAssertEqual(viewModel.renderingMode, .minIP)
        XCTAssertNotNil(viewModel.renderedImage)

        viewModel.renderingMode = .averageIP
        XCTAssertEqual(viewModel.renderingMode, .averageIP)
        XCTAssertNotNil(viewModel.renderedImage)

        viewModel.renderingMode = .volumeRendering
        XCTAssertEqual(viewModel.renderingMode, .volumeRendering)
        XCTAssertNotNil(viewModel.renderedImage)

        viewModel.renderingMode = .mip
        XCTAssertEqual(viewModel.renderingMode, .mip)
        XCTAssertNotNil(viewModel.renderedImage)
    }

    func testRenderingModeAllCases() {
        let allModes = RenderingMode.allCases
        XCTAssertEqual(allModes.count, 4)
        XCTAssertTrue(allModes.contains(.mip))
        XCTAssertTrue(allModes.contains(.minIP))
        XCTAssertTrue(allModes.contains(.averageIP))
        XCTAssertTrue(allModes.contains(.volumeRendering))
    }

    // MARK: - Transfer Function Tests

    func testTransferFunctionChange() {
        viewModel.loadVolume(makeTestVolume())
        viewModel.renderingMode = .volumeRendering

        viewModel.transferFunction = .softTissue
        XCTAssertEqual(viewModel.transferFunction.name, "Soft Tissue")

        viewModel.transferFunction = .lung
        XCTAssertEqual(viewModel.transferFunction.name, "Lung")

        viewModel.transferFunction = .angiography
        XCTAssertEqual(viewModel.transferFunction.name, "Angiography")

        viewModel.transferFunction = .mip
        XCTAssertEqual(viewModel.transferFunction.name, "MIP")

        viewModel.transferFunction = .bone
        XCTAssertEqual(viewModel.transferFunction.name, "Bone")
    }

    func testTransferFunctionDefaultIsBone() {
        XCTAssertEqual(viewModel.transferFunction.name, "Bone")
    }

    // MARK: - Rotation Tests

    func testRotation() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.rotateBy(dx: 45.0, dy: 30.0)
        XCTAssertEqual(viewModel.rotationX, 30.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.rotationY, 45.0, accuracy: 0.001)
    }

    func testRotationAccumulates() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.rotateBy(dx: 10.0, dy: 20.0)
        viewModel.rotateBy(dx: 10.0, dy: 20.0)
        XCTAssertEqual(viewModel.rotationX, 40.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.rotationY, 20.0, accuracy: 0.001)
    }

    func testRotationWraps() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.rotateBy(dx: 400.0, dy: 0)
        // 400 mod 360 = 40
        XCTAssertEqual(viewModel.rotationY, 40.0, accuracy: 0.001)
    }

    func testRotationNegative() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.rotateBy(dx: -90.0, dy: -45.0)
        XCTAssertEqual(viewModel.rotationX, -45.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.rotationY, -90.0, accuracy: 0.001)
    }

    // MARK: - Zoom Tests

    func testZoom() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.zoom = 2.5
        XCTAssertEqual(viewModel.zoom, 2.5, accuracy: 0.001)
    }

    func testZoomClampedMin() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.zoom = 0.01
        XCTAssertEqual(viewModel.zoom, 0.1, accuracy: 0.001)
    }

    func testZoomClampedMax() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.zoom = 20.0
        XCTAssertEqual(viewModel.zoom, 10.0, accuracy: 0.001)
    }

    func testZoomDefaultIsOne() {
        XCTAssertEqual(viewModel.zoom, 1.0, accuracy: 0.001)
    }

    // MARK: - Reset View Tests

    func testResetView() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.rotationX = 45.0
        viewModel.rotationY = 90.0
        viewModel.zoom = 3.0
        viewModel.slabThickness = 10

        viewModel.resetView()

        XCTAssertEqual(viewModel.rotationX, 0)
        XCTAssertEqual(viewModel.rotationY, 0)
        XCTAssertEqual(viewModel.zoom, 1.0)
        XCTAssertEqual(viewModel.slabThickness, 0)
    }

    func testResetViewWithoutVolume() {
        viewModel.rotationX = 45.0
        viewModel.rotationY = 90.0
        viewModel.zoom = 3.0
        viewModel.slabThickness = 10

        viewModel.resetView()

        XCTAssertEqual(viewModel.rotationX, 0)
        XCTAssertEqual(viewModel.rotationY, 0)
        XCTAssertEqual(viewModel.zoom, 1.0)
        XCTAssertEqual(viewModel.slabThickness, 0)
    }

    // MARK: - Load Volume Tests

    func testLoadVolume() {
        let volume = makeTestVolume()
        viewModel.loadVolume(volume)

        XCTAssertNotNil(viewModel.volume)
        XCTAssertNotNil(viewModel.renderedImage)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadVolumeRendersImage() {
        let volume = makeTestVolume()
        viewModel.loadVolume(volume)

        // Should have rendered an image after loading
        XCTAssertNotNil(viewModel.renderedImage)
    }

    // MARK: - Slab Thickness Tests

    func testSlabThicknessDefault() {
        XCTAssertEqual(viewModel.slabThickness, 0)
    }

    func testSlabThicknessChange() {
        viewModel.loadVolume(makeTestVolume())

        viewModel.slabThickness = 5
        XCTAssertEqual(viewModel.slabThickness, 5)
        XCTAssertNotNil(viewModel.renderedImage)
    }

    // MARK: - Error State Tests

    func testErrorMessageClearedOnLoad() {
        viewModel.errorMessage = "Previous error"
        viewModel.loadVolume(makeTestVolume())

        XCTAssertNil(viewModel.errorMessage)
    }

    func testRenderWithoutVolume() {
        viewModel.render()
        XCTAssertNil(viewModel.renderedImage)
    }
}
