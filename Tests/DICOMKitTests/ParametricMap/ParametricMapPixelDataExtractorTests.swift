//
// ParametricMapPixelDataExtractorTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class ParametricMapPixelDataExtractorTests: XCTestCase {
    
    // MARK: - Integer Pixel Data Extraction Tests
    
    func test_extractIntegerFrame_unsigned8bit_withLinearMapping_succeeds() {
        // Create test data: 2x2 image with values [0, 64, 128, 255]
        let pixelData = Data([0, 64, 128, 255])
        let mapping = RealWorldValueMapping(
            measurementUnits: .millisecond,
            mapping: .linear(slope: 2.0, intercept: 100.0)
        )
        
        let values = ParametricMapPixelDataExtractor.extractIntegerFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2,
            bitsAllocated: 8,
            pixelRepresentation: 0,
            mapping: mapping
        )
        
        XCTAssertNotNil(values)
        XCTAssertEqual(values?.count, 4)
        XCTAssertEqual(values?[0], 100.0, accuracy: 0.001)  // 2.0 * 0 + 100
        XCTAssertEqual(values?[1], 228.0, accuracy: 0.001)  // 2.0 * 64 + 100
        XCTAssertEqual(values?[2], 356.0, accuracy: 0.001)  // 2.0 * 128 + 100
        XCTAssertEqual(values?[3], 610.0, accuracy: 0.001)  // 2.0 * 255 + 100
    }
    
    func test_extractIntegerFrame_unsigned16bit_withLinearMapping_succeeds() {
        // Create test data: 2x2 image with values [0, 1000, 2000, 3000]
        var pixelData = Data()
        pixelData.append(contentsOf: [0, 0])      // 0 (little endian)
        pixelData.append(contentsOf: [232, 3])    // 1000
        pixelData.append(contentsOf: [208, 7])    // 2000
        pixelData.append(contentsOf: [184, 11])   // 3000
        
        let mapping = RealWorldValueMapping(
            measurementUnits: .millisecond,
            mapping: .linear(slope: 0.5, intercept: 0.0)
        )
        
        let values = ParametricMapPixelDataExtractor.extractIntegerFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2,
            bitsAllocated: 16,
            pixelRepresentation: 0,
            mapping: mapping
        )
        
        XCTAssertNotNil(values)
        XCTAssertEqual(values?.count, 4)
        XCTAssertEqual(values?[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(values?[1], 500.0, accuracy: 0.001)
        XCTAssertEqual(values?[2], 1000.0, accuracy: 0.001)
        XCTAssertEqual(values?[3], 1500.0, accuracy: 0.001)
    }
    
    // MARK: - Float Pixel Data Extraction Tests
    
    func test_extractFloatFrame_withoutMapping_succeeds() {
        // Create test data: 2x2 image with float values
        let floats: [Float] = [0.5, 1.0, 1.5, 2.0]
        var pixelData = Data()
        for value in floats {
            var v = value
            pixelData.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        
        let values = ParametricMapPixelDataExtractor.extractFloatFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2
        )
        
        XCTAssertNotNil(values)
        XCTAssertEqual(values?.count, 4)
        XCTAssertEqual(values?[0], 0.5, accuracy: 0.0001)
        XCTAssertEqual(values?[1], 1.0, accuracy: 0.0001)
        XCTAssertEqual(values?[2], 1.5, accuracy: 0.0001)
        XCTAssertEqual(values?[3], 2.0, accuracy: 0.0001)
    }
    
    func test_extractFloatFrame_withLinearMapping_succeeds() {
        let floats: [Float] = [1.0, 2.0, 3.0, 4.0]
        var pixelData = Data()
        for value in floats {
            var v = value
            pixelData.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        
        let mapping = RealWorldValueMapping(
            measurementUnits: .mm2PerSecond,
            mapping: .linear(slope: 0.001, intercept: 0.0)
        )
        
        let values = ParametricMapPixelDataExtractor.extractFloatFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2,
            mapping: mapping
        )
        
        XCTAssertNotNil(values)
        XCTAssertEqual(values?[0], 0.001, accuracy: 0.00001)
        XCTAssertEqual(values?[1], 0.002, accuracy: 0.00001)
        XCTAssertEqual(values?[2], 0.003, accuracy: 0.00001)
        XCTAssertEqual(values?[3], 0.004, accuracy: 0.00001)
    }
    
    // MARK: - Double Pixel Data Extraction Tests
    
    func test_extractDoubleFrame_succeeds() {
        let doubles: [Double] = [0.123, 0.456, 0.789, 1.234]
        var pixelData = Data()
        for value in doubles {
            var v = value
            pixelData.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        
        let values = ParametricMapPixelDataExtractor.extractDoubleFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2
        )
        
        XCTAssertNotNil(values)
        XCTAssertEqual(values?.count, 4)
        XCTAssertEqual(values?[0], 0.123, accuracy: 0.000001)
        XCTAssertEqual(values?[1], 0.456, accuracy: 0.000001)
        XCTAssertEqual(values?[2], 0.789, accuracy: 0.000001)
        XCTAssertEqual(values?[3], 1.234, accuracy: 0.000001)
    }
    
    // MARK: - Multi-frame Extraction Tests
    
    func test_extractIntegerFrame_multipleFrames_succeeds() {
        // Create 2 frames of 2x2 pixels each
        let frame1Data = Data([10, 20, 30, 40])
        let frame2Data = Data([50, 60, 70, 80])
        let pixelData = frame1Data + frame2Data
        
        let mapping = RealWorldValueMapping(
            measurementUnits: .millisecond,
            mapping: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let values1 = ParametricMapPixelDataExtractor.extractIntegerFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2,
            bitsAllocated: 8,
            pixelRepresentation: 0,
            mapping: mapping
        )
        
        let values2 = ParametricMapPixelDataExtractor.extractIntegerFrame(
            from: pixelData,
            frameIndex: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 8,
            pixelRepresentation: 0,
            mapping: mapping
        )
        
        XCTAssertNotNil(values1)
        XCTAssertNotNil(values2)
        XCTAssertEqual(values1?[0], 10.0)
        XCTAssertEqual(values2?[0], 50.0)
    }
    
    // MARK: - Error Cases
    
    func test_extractIntegerFrame_invalidFrameIndex_returnsNil() {
        let pixelData = Data([0, 1, 2, 3])
        let mapping = RealWorldValueMapping(
            measurementUnits: .millisecond,
            mapping: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let values = ParametricMapPixelDataExtractor.extractIntegerFrame(
            from: pixelData,
            frameIndex: -1,
            rows: 2,
            columns: 2,
            bitsAllocated: 8,
            pixelRepresentation: 0,
            mapping: mapping
        )
        
        XCTAssertNil(values)
    }
    
    func test_extractFloatFrame_insufficientData_returnsNil() {
        let pixelData = Data([0, 1])  // Too small for a 2x2 float frame
        
        let values = ParametricMapPixelDataExtractor.extractFloatFrame(
            from: pixelData,
            frameIndex: 0,
            rows: 2,
            columns: 2
        )
        
        XCTAssertNil(values)
    }
}
