// MPRViewModelTests.swift
// DICOMViewer macOS - MPR ViewModel Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

@MainActor
final class MPRViewModelTests: XCTestCase {

    private var viewModel: MPRViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MPRViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(viewModel.volume)
        XCTAssertEqual(viewModel.axialIndex, 0)
        XCTAssertEqual(viewModel.sagittalIndex, 0)
        XCTAssertEqual(viewModel.coronalIndex, 0)
        XCTAssertNil(viewModel.axialImage)
        XCTAssertNil(viewModel.sagittalImage)
        XCTAssertNil(viewModel.coronalImage)
        XCTAssertEqual(viewModel.windowCenter, 40.0)
        XCTAssertEqual(viewModel.windowWidth, 400.0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.maxAxialIndex, 0)
        XCTAssertEqual(viewModel.maxSagittalIndex, 0)
        XCTAssertEqual(viewModel.maxCoronalIndex, 0)
    }

    // MARK: - Window/Level Defaults Tests

    func testWindowLevelDefaults() {
        XCTAssertEqual(viewModel.windowCenter, 40.0)
        XCTAssertEqual(viewModel.windowWidth, 400.0)
    }

    func testWindowLevelCanBeModified() {
        viewModel.windowCenter = 300.0
        viewModel.windowWidth = 1500.0

        XCTAssertEqual(viewModel.windowCenter, 300.0)
        XCTAssertEqual(viewModel.windowWidth, 1500.0)
    }

    // MARK: - Reference Line Calculation Tests

    func testReferenceLineCalculationDefaultState() {
        // With maxIndices = 0, reference lines should return 0.5
        XCTAssertEqual(viewModel.axialReferenceH, 0.5)
        XCTAssertEqual(viewModel.axialReferenceV, 0.5)
        XCTAssertEqual(viewModel.sagittalReferenceH, 0.5)
        XCTAssertEqual(viewModel.sagittalReferenceV, 0.5)
        XCTAssertEqual(viewModel.coronalReferenceH, 0.5)
        XCTAssertEqual(viewModel.coronalReferenceV, 0.5)
    }

    // MARK: - Slice Index Clamping Tests

    func testSliceIndexClampingNoVolume() {
        // Without a volume, indices should stay at 0
        viewModel.axialIndex = 100
        XCTAssertEqual(viewModel.axialIndex, 0)

        viewModel.sagittalIndex = 100
        XCTAssertEqual(viewModel.sagittalIndex, 0)

        viewModel.coronalIndex = 100
        XCTAssertEqual(viewModel.coronalIndex, 0)
    }

    func testSliceIndexNegativeClamping() {
        viewModel.axialIndex = -5
        XCTAssertEqual(viewModel.axialIndex, 0)

        viewModel.sagittalIndex = -10
        XCTAssertEqual(viewModel.sagittalIndex, 0)

        viewModel.coronalIndex = -1
        XCTAssertEqual(viewModel.coronalIndex, 0)
    }

    // MARK: - Reset To Center Tests

    func testResetToCenterNoVolume() {
        viewModel.axialIndex = 5
        viewModel.sagittalIndex = 5
        viewModel.coronalIndex = 5

        viewModel.resetToCenter()

        // Without volume, resetToCenter should not change anything
        // But indices were already clamped to 0
        XCTAssertEqual(viewModel.axialIndex, 0)
        XCTAssertEqual(viewModel.sagittalIndex, 0)
        XCTAssertEqual(viewModel.coronalIndex, 0)
    }

    // MARK: - Loading State Tests

    func testLoadingStateInitiallyFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }

    func testErrorMessageInitiallyNil() {
        XCTAssertNil(viewModel.errorMessage)
    }

    func testErrorMessageCanBeSet() {
        viewModel.errorMessage = "Test error"
        XCTAssertEqual(viewModel.errorMessage, "Test error")
    }

    func testErrorMessageCanBeCleared() {
        viewModel.errorMessage = "Test error"
        viewModel.errorMessage = nil
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Update Methods Without Volume

    func testUpdateAxialSliceNoVolume() {
        viewModel.updateAxialSlice()
        XCTAssertNil(viewModel.axialImage)
    }

    func testUpdateSagittalSliceNoVolume() {
        viewModel.updateSagittalSlice()
        XCTAssertNil(viewModel.sagittalImage)
    }

    func testUpdateCoronalSliceNoVolume() {
        viewModel.updateCoronalSlice()
        XCTAssertNil(viewModel.coronalImage)
    }

    func testUpdateAllSlicesNoVolume() {
        viewModel.updateAllSlices()
        XCTAssertNil(viewModel.axialImage)
        XCTAssertNil(viewModel.sagittalImage)
        XCTAssertNil(viewModel.coronalImage)
    }
}
