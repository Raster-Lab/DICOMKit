// ProjectionHelpersTests.swift
// DICOMStudioTests
//
// Tests for intensity projection helpers (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Projection Label Tests

@Suite("ProjectionHelpers Label Tests")
struct ProjectionHelpersLabelTests {

    @Test("Projection labels")
    func testLabels() {
        #expect(ProjectionHelpers.projectionLabel(.mip) == "Maximum Intensity Projection")
        #expect(ProjectionHelpers.projectionLabel(.minIP) == "Minimum Intensity Projection")
        #expect(ProjectionHelpers.projectionLabel(.avgIP) == "Average Intensity Projection")
    }

    @Test("Projection abbreviations")
    func testAbbreviations() {
        #expect(ProjectionHelpers.projectionAbbreviation(.mip) == "MIP")
        #expect(ProjectionHelpers.projectionAbbreviation(.minIP) == "MinIP")
        #expect(ProjectionHelpers.projectionAbbreviation(.avgIP) == "AvgIP")
    }

    @Test("Projection symbols are non-empty")
    func testSymbols() {
        for mode in ProjectionMode.allCases {
            #expect(!ProjectionHelpers.projectionSymbol(mode).isEmpty)
        }
    }

    @Test("Clinical use descriptions are non-empty")
    func testClinicalUse() {
        for mode in ProjectionMode.allCases {
            #expect(!ProjectionHelpers.clinicalUse(mode).isEmpty)
        }
    }
}

// MARK: - Slab Validation Tests

@Suite("ProjectionHelpers Slab Validation Tests")
struct ProjectionHelpersSlabTests {

    @Test("Clamp slab thickness within range")
    func testClampNormal() {
        let clamped = ProjectionHelpers.clampSlabThickness(10.0, maxThickness: 50.0)
        #expect(clamped == 10.0)
    }

    @Test("Clamp slab thickness below minimum")
    func testClampBelowMin() {
        let clamped = ProjectionHelpers.clampSlabThickness(0.01, maxThickness: 50.0)
        #expect(clamped == 0.1)
    }

    @Test("Clamp slab thickness above maximum")
    func testClampAboveMax() {
        let clamped = ProjectionHelpers.clampSlabThickness(100.0, maxThickness: 50.0)
        #expect(clamped == 50.0)
    }

    @Test("Slice count for slab")
    func testSliceCount() {
        let count = ProjectionHelpers.sliceCountForSlab(thicknessMM: 10.0, sliceSpacing: 2.0)
        #expect(count == 5)
    }

    @Test("Slice count for zero spacing")
    func testSliceCountZeroSpacing() {
        let count = ProjectionHelpers.sliceCountForSlab(thicknessMM: 10.0, sliceSpacing: 0.0)
        #expect(count == 1)
    }

    @Test("Maximum slab thickness")
    func testMaxSlabThickness() {
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 2.0)
        let maxAxial = ProjectionHelpers.maximumSlabThickness(direction: .axial, dimensions: dims)
        #expect(maxAxial == 200.0) // 100 * 2.0
        let maxSag = ProjectionHelpers.maximumSlabThickness(direction: .sagittal, dimensions: dims)
        #expect(maxSag == 128.0) // 256 * 0.5
    }
}

// MARK: - Projection Summary Tests

@Suite("ProjectionHelpers Summary Tests")
struct ProjectionHelpersSummaryTests {

    @Test("Full volume summary")
    func testFullVolumeSummary() {
        let config = ProjectionConfiguration(mode: .mip, direction: .axial)
        let summary = ProjectionHelpers.formatProjectionSummary(config)
        #expect(summary.contains("MIP"))
        #expect(summary.contains("Axial"))
        #expect(summary.contains("full volume"))
    }

    @Test("Slab summary includes thickness")
    func testSlabSummary() {
        let config = ProjectionConfiguration(mode: .minIP, direction: .coronal, slabThickness: 15.0)
        let summary = ProjectionHelpers.formatProjectionSummary(config)
        #expect(summary.contains("MinIP"))
        #expect(summary.contains("Coronal"))
        #expect(summary.contains("15.0 mm"))
    }
}

// MARK: - Value Aggregation Tests

@Suite("ProjectionHelpers Value Aggregation Tests")
struct ProjectionHelpersAggregationTests {

    @Test("MIP returns maximum")
    func testMIP() {
        let result = ProjectionHelpers.projectValues(mode: .mip, values: [10, 50, 30, 20, 40])
        #expect(result == 50.0)
    }

    @Test("MinIP returns minimum")
    func testMinIP() {
        let result = ProjectionHelpers.projectValues(mode: .minIP, values: [10, 50, 30, 20, 40])
        #expect(result == 10.0)
    }

    @Test("AvgIP returns average")
    func testAvgIP() {
        let result = ProjectionHelpers.projectValues(mode: .avgIP, values: [10, 50, 30, 20, 40])
        #expect(result == 30.0)
    }

    @Test("Empty values return 0")
    func testEmpty() {
        #expect(ProjectionHelpers.projectValues(mode: .mip, values: []) == 0.0)
        #expect(ProjectionHelpers.projectValues(mode: .minIP, values: []) == 0.0)
        #expect(ProjectionHelpers.projectValues(mode: .avgIP, values: []) == 0.0)
    }

    @Test("Single value returns itself")
    func testSingleValue() {
        #expect(ProjectionHelpers.projectValues(mode: .mip, values: [42.0]) == 42.0)
        #expect(ProjectionHelpers.projectValues(mode: .minIP, values: [42.0]) == 42.0)
        #expect(ProjectionHelpers.projectValues(mode: .avgIP, values: [42.0]) == 42.0)
    }

    @Test("Negative values handled correctly")
    func testNegativeValues() {
        let result = ProjectionHelpers.projectValues(mode: .mip, values: [-100, -50, -200])
        #expect(result == -50.0)
    }
}
