//
// RealWorldValueRendererTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class RealWorldValueRendererTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_renderer_initWithSingleLUT_succeeds() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let selectedLUT = await renderer.selectedLUT()
        XCTAssertNotNil(selectedLUT)
        XCTAssertEqual(selectedLUT?.measurementUnits.codeValue, "[hnsf'U]")
    }
    
    func test_renderer_initWithMultipleLUTs_succeeds() async {
        let lut1 = RealWorldValueLUT(
            label: "HU",
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let lut2 = RealWorldValueLUT(
            label: "ADC",
            measurementUnits: .mm2PerSecond,
            transformation: .linear(slope: 0.001, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(luts: [lut1, lut2])
        
        let luts = await renderer.availableLUTs()
        XCTAssertEqual(luts.count, 2)
    }
    
    // MARK: - LUT Selection Tests
    
    func test_renderer_selectLUT_changesSelected() async throws {
        let lut1 = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let lut2 = RealWorldValueLUT(
            measurementUnits: .mm2PerSecond,
            transformation: .linear(slope: 0.001, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(luts: [lut1, lut2])
        
        // Initially selected is index 0
        var selected = await renderer.selectedLUT()
        XCTAssertEqual(selected?.measurementUnits.codeValue, "[hnsf'U]")
        
        // Select index 1
        try await renderer.selectLUT(at: 1)
        selected = await renderer.selectedLUT()
        XCTAssertEqual(selected?.measurementUnits.codeValue, "mm2/s")
    }
    
    func test_renderer_selectLUT_withInvalidIndex_throws() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        do {
            try await renderer.selectLUT(at: 5)
            XCTFail("Expected error to be thrown")
        } catch let error as RealWorldValueError {
            if case .invalidLUTIndex(let index, let count) = error {
                XCTAssertEqual(index, 5)
                XCTAssertEqual(count, 1)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Pixel Value Transformation Tests
    
    func test_renderer_applyToIntValue_transformsCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let result = await renderer.apply(to: 1024)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.001)
    }
    
    func test_renderer_applyToDoubleValue_transformsCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .millisecond,
            transformation: .linear(slope: 2.0, intercept: 10.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let result = await renderer.apply(to: 5.5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 21.0, accuracy: 0.001)
    }
    
    func test_renderer_applyToIntArray_transformsCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let values = [0, 512, 1024, 2048]
        let results = await renderer.apply(to: values)
        
        XCTAssertNotNil(results)
        XCTAssertEqual(results!.count, 4)
        XCTAssertEqual(results![0], -1024.0, accuracy: 0.001)
        XCTAssertEqual(results![1], -512.0, accuracy: 0.001)
        XCTAssertEqual(results![2], 0.0, accuracy: 0.001)
        XCTAssertEqual(results![3], 1024.0, accuracy: 0.001)
    }
    
    func test_renderer_applyToDoubleArray_transformsCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .mm2PerSecond,
            transformation: .linear(slope: 0.001, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let values = [0.0, 500.0, 1000.0, 2000.0]
        let results = await renderer.apply(to: values)
        
        XCTAssertNotNil(results)
        XCTAssertEqual(results!.count, 4)
        XCTAssertEqual(results![0], 0.0, accuracy: 0.0001)
        XCTAssertEqual(results![1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(results![2], 1.0, accuracy: 0.0001)
        XCTAssertEqual(results![3], 2.0, accuracy: 0.0001)
    }
    
    // MARK: - Frame-Specific Transformation Tests
    
    func test_renderer_applyForFrame_withAllFramesScope_usesLUT() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0),
            frameScope: .allFrames
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let result0 = await renderer.apply(to: 1024, forFrame: 0)
        let result10 = await renderer.apply(to: 1024, forFrame: 10)
        
        XCTAssertNotNil(result0)
        XCTAssertNotNil(result10)
        XCTAssertEqual(result0!, 0.0, accuracy: 0.001)
        XCTAssertEqual(result10!, 0.0, accuracy: 0.001)
    }
    
    func test_renderer_applyForFrame_withFirstFrameScope_usesLUTOnlyForFirstFrame() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0),
            frameScope: .firstFrame
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let result0 = await renderer.apply(to: 1024, forFrame: 0)
        let result1 = await renderer.apply(to: 1024, forFrame: 1)
        
        XCTAssertNotNil(result0)
        XCTAssertNotNil(result1)
        XCTAssertEqual(result0!, 0.0, accuracy: 0.001)
        XCTAssertEqual(result1!, 0.0, accuracy: 0.001) // Falls back to selected LUT
    }
    
    func test_renderer_applyForFrame_withSpecificFrames_usesLUTForMatchingFrames() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0),
            frameScope: .specificFrames([1, 3, 5])
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let result0 = await renderer.apply(to: 1024, forFrame: 0) // Frame 1 in DICOM
        let result2 = await renderer.apply(to: 1024, forFrame: 2) // Frame 3 in DICOM
        
        XCTAssertNotNil(result0)
        XCTAssertNotNil(result2)
    }
    
    // MARK: - Statistics Tests
    
    func test_renderer_statistics_calculatesCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let values = [0, 512, 1024, 1536, 2048]
        let stats = await renderer.statistics(for: values)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.min, -1024.0, accuracy: 0.001)
        XCTAssertEqual(stats!.max, 1024.0, accuracy: 0.001)
        XCTAssertEqual(stats!.mean, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats!.median, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats!.count, 5)
        XCTAssertEqual(stats!.units?.codeValue, "[hnsf'U]")
    }
    
    func test_renderer_statistics_withEmptyArray_returnsNil() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .hounsfield,
            transformation: .linear(slope: 1.0, intercept: -1024.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let stats = await renderer.statistics(for: [])
        XCTAssertNil(stats)
    }
    
    func test_renderer_statistics_withOddNumberOfValues_calculatesMedianCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .ratio,
            transformation: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let values = [1, 2, 3, 4, 5]
        let stats = await renderer.statistics(for: values)
        
        XCTAssertEqual(stats!.median, 3.0, accuracy: 0.001)
    }
    
    func test_renderer_statistics_withEvenNumberOfValues_calculatesMedianCorrectly() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .ratio,
            transformation: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        let values = [1, 2, 3, 4]
        let stats = await renderer.statistics(for: values)
        
        XCTAssertEqual(stats!.median, 2.5, accuracy: 0.001)
    }
    
    func test_renderer_statistics_calculatesStandardDeviation() async {
        let lut = RealWorldValueLUT(
            measurementUnits: .ratio,
            transformation: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let renderer = RealWorldValueRenderer(lut: lut)
        
        // Values: 0, 1, 2, 3, 4
        // Mean: 2.0
        // Variance: ((0-2)² + (1-2)² + (2-2)² + (3-2)² + (4-2)²) / 5 = (4 + 1 + 0 + 1 + 4) / 5 = 2.0
        // StdDev: sqrt(2.0) ≈ 1.414
        let values = [0, 1, 2, 3, 4]
        let stats = await renderer.statistics(for: values)
        
        XCTAssertEqual(stats!.standardDeviation, 1.414, accuracy: 0.01)
    }
    
    // MARK: - Error Handling Tests
    
    func test_realWorldValueError_description_isCorrect() {
        let error1 = RealWorldValueError.invalidLUTIndex(5, count: 3)
        XCTAssertTrue(error1.description.contains("Invalid LUT index 5"))
        
        let error2 = RealWorldValueError.noLUTSelected
        XCTAssertTrue(error2.description.contains("No Real World Value LUT"))
        
        let error3 = RealWorldValueError.incompatibleUnits("HU", "mm2/s")
        XCTAssertTrue(error3.description.contains("Incompatible units"))
    }
}
