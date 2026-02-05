//
// LUTTransformationTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class LUTTransformationTests: XCTestCase {
    
    // MARK: - ModalityLUT Tests
    
    func test_modalityLUT_rescale() {
        let lut = ModalityLUT.rescale(slope: 1.0, intercept: -1024.0, type: "HU")
        
        // Test transformation: output = input * 1.0 + (-1024.0)
        XCTAssertEqual(lut.apply(to: 0), -1024.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 1024), 0.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 2048), 1024.0, accuracy: 0.01)
    }
    
    func test_modalityLUT_rescale_slope() {
        let lut = ModalityLUT.rescale(slope: 2.0, intercept: 0.0, type: nil)
        
        XCTAssertEqual(lut.apply(to: 0), 0.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 100), 200.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 500), 1000.0, accuracy: 0.01)
    }
    
    func test_modalityLUT_rescale_intercept() {
        let lut = ModalityLUT.rescale(slope: 1.0, intercept: 100.0, type: nil)
        
        XCTAssertEqual(lut.apply(to: 0), 100.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 50), 150.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 100), 200.0, accuracy: 0.01)
    }
    
    func test_modalityLUT_lookupTable() {
        let lutData = LUTData(
            numberOfEntries: 5,
            firstValueMapped: 0,
            bitsPerEntry: 8,
            data: [10, 20, 30, 40, 50]
        )
        let lut = ModalityLUT.lut(lutData)
        
        XCTAssertEqual(lut.apply(to: 0), 10.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 2), 30.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 4), 50.0, accuracy: 0.01)
    }
    
    func test_modalityLUT_equality() {
        let lut1 = ModalityLUT.rescale(slope: 1.0, intercept: -1024.0, type: "HU")
        let lut2 = ModalityLUT.rescale(slope: 1.0, intercept: -1024.0, type: "HU")
        let lut3 = ModalityLUT.rescale(slope: 2.0, intercept: -1024.0, type: "HU")
        
        XCTAssertEqual(lut1, lut2)
        XCTAssertNotEqual(lut1, lut3)
    }
    
    // MARK: - VOILUT Tests
    
    func test_voiLUT_window_linear() {
        let lut = VOILUT.window(center: 40.0, width: 400.0, explanation: "Lung", function: .linear)
        
        // Window center is at 40, width is 400
        // Linear function should map to range [0.0, 1.0]
        // - Values below window min should be 0.0
        // - Values above window max should be 1.0
        // - Center value should be around 0.5
        
        let lowValue = lut.apply(to: -200.0)  // Below window
        let centerValue = lut.apply(to: 40.0)  // At center
        let highValue = lut.apply(to: 300.0)  // Above window
        
        // Low value should be near 0.0
        XCTAssertLessThan(lowValue, 0.1)
        
        // Center should be mid-range (around 0.5)
        XCTAssertGreaterThan(centerValue, 0.4)
        XCTAssertLessThan(centerValue, 0.6)
        
        // High value should be near 1.0
        XCTAssertGreaterThan(highValue, 0.9)
    }
    
    func test_voiLUT_window_sigmoid() {
        let lut = VOILUT.window(center: 40.0, width: 400.0, explanation: nil, function: .sigmoid)
        
        // Sigmoid function should have smoother transitions
        // Output should be in range [0.0, 1.0]
        let value = lut.apply(to: 40.0)
        
        // At center, sigmoid should be at midpoint (around 0.5)
        XCTAssertGreaterThan(value, 0.4)
        XCTAssertLessThan(value, 0.6)
    }
    
    func test_voiLUT_lookupTable() {
        let lutData = LUTData(
            numberOfEntries: 5,
            firstValueMapped: 0,
            bitsPerEntry: 8,
            data: [0, 64, 128, 192, 255]
        )
        let lut = VOILUT.lut(lutData)
        
        XCTAssertEqual(lut.apply(to: 0), 0.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 2), 128.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 4), 255.0, accuracy: 0.01)
    }
    
    func test_voiLUT_equality() {
        let lut1 = VOILUT.window(center: 40.0, width: 400.0, explanation: "Lung", function: .linear)
        let lut2 = VOILUT.window(center: 40.0, width: 400.0, explanation: "Lung", function: .linear)
        let lut3 = VOILUT.window(center: 50.0, width: 400.0, explanation: "Lung", function: .linear)
        
        XCTAssertEqual(lut1, lut2)
        XCTAssertNotEqual(lut1, lut3)
    }
    
    // MARK: - PresentationLUT Tests
    
    func test_presentationLUT_identity() {
        let lut = PresentationLUT.identity
        
        XCTAssertEqual(lut.apply(to: 0.0), 0.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 1.0), 1.0, accuracy: 0.01)
    }
    
    func test_presentationLUT_inverse() {
        let lut = PresentationLUT.inverse
        
        XCTAssertEqual(lut.apply(to: 0.0), 1.0, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(lut.apply(to: 1.0), 0.0, accuracy: 0.01)
    }
    
    func test_presentationLUT_lookupTable() {
        let lutData = LUTData(
            numberOfEntries: 256,
            firstValueMapped: 0,
            bitsPerEntry: 8,
            data: Array(0..<256)
        )
        let lut = PresentationLUT.lut(lutData)
        
        let value = lut.apply(to: 0.5)
        XCTAssertGreaterThan(value, 0.0)
        XCTAssertLessThan(value, 1.0)
    }
    
    func test_presentationLUT_equality() {
        let lut1 = PresentationLUT.identity
        let lut2 = PresentationLUT.identity
        let lut3 = PresentationLUT.inverse
        
        XCTAssertEqual(lut1, lut2)
        XCTAssertNotEqual(lut1, lut3)
    }
    
    // MARK: - LUTData Tests
    
    func test_lutData_initialization() {
        let lut = LUTData(
            numberOfEntries: 256,
            firstValueMapped: 0,
            bitsPerEntry: 8,
            data: Array(0..<256),
            explanation: "Test LUT"
        )
        
        XCTAssertEqual(lut.numberOfEntries, 256)
        XCTAssertEqual(lut.firstValueMapped, 0)
        XCTAssertEqual(lut.bitsPerEntry, 8)
        XCTAssertEqual(lut.data.count, 256)
        XCTAssertEqual(lut.explanation, "Test LUT")
    }
    
    func test_lutData_maxOutputValue() {
        let lut8 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: [])
        XCTAssertEqual(lut8.maxOutputValue, 255)
        
        let lut12 = LUTData(numberOfEntries: 4096, firstValueMapped: 0, bitsPerEntry: 12, data: [])
        XCTAssertEqual(lut12.maxOutputValue, 4095)
        
        let lut16 = LUTData(numberOfEntries: 65536, firstValueMapped: 0, bitsPerEntry: 16, data: [])
        XCTAssertEqual(lut16.maxOutputValue, 65535)
    }
    
    func test_lutData_lookup_exactMatch() {
        let lut = LUTData(
            numberOfEntries: 5,
            firstValueMapped: 10,
            bitsPerEntry: 8,
            data: [100, 110, 120, 130, 140]
        )
        
        // Value 10 maps to index 0 (firstValueMapped)
        XCTAssertEqual(lut.lookup(10), 100.0, accuracy: 0.01)
        
        // Value 12 maps to index 2
        XCTAssertEqual(lut.lookup(12), 120.0, accuracy: 0.01)
        
        // Value 14 maps to index 4 (last entry)
        XCTAssertEqual(lut.lookup(14), 140.0, accuracy: 0.01)
    }
    
    func test_lutData_lookup_belowRange() {
        let lut = LUTData(
            numberOfEntries: 5,
            firstValueMapped: 10,
            bitsPerEntry: 8,
            data: [100, 110, 120, 130, 140]
        )
        
        // Value below firstValueMapped should clamp to first entry
        XCTAssertEqual(lut.lookup(5), 100.0, accuracy: 0.01)
        XCTAssertEqual(lut.lookup(0), 100.0, accuracy: 0.01)
    }
    
    func test_lutData_lookup_aboveRange() {
        let lut = LUTData(
            numberOfEntries: 5,
            firstValueMapped: 10,
            bitsPerEntry: 8,
            data: [100, 110, 120, 130, 140]
        )
        
        // Value above range should clamp to last entry
        XCTAssertEqual(lut.lookup(20), 140.0, accuracy: 0.01)
        XCTAssertEqual(lut.lookup(100), 140.0, accuracy: 0.01)
    }
    
    func test_lutData_parse_validDescriptor() {
        let descriptor = [256, 0, 8]
        let data = Array(0..<256)
        
        let lut = LUTData.parse(descriptor: descriptor, data: data, explanation: "Test")
        
        XCTAssertNotNil(lut)
        XCTAssertEqual(lut?.numberOfEntries, 256)
        XCTAssertEqual(lut?.firstValueMapped, 0)
        XCTAssertEqual(lut?.bitsPerEntry, 8)
        XCTAssertEqual(lut?.explanation, "Test")
    }
    
    func test_lutData_parse_zeroEntries() {
        // Special case: 0 means 65536 entries
        let descriptor = [0, 0, 16]
        let data = Array(0..<65536)
        
        let lut = LUTData.parse(descriptor: descriptor, data: data)
        
        XCTAssertNotNil(lut)
        XCTAssertEqual(lut?.numberOfEntries, 65536)
    }
    
    func test_lutData_parse_invalidDescriptor() {
        // Descriptor must have exactly 3 values
        let descriptor = [256, 0]  // Only 2 values
        let data = Array(0..<256)
        
        let lut = LUTData.parse(descriptor: descriptor, data: data)
        
        XCTAssertNil(lut)
    }
    
    func test_lutData_equality() {
        let lut1 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<256))
        let lut2 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<256))
        let lut3 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<256).reversed())
        
        XCTAssertEqual(lut1, lut2)
        XCTAssertNotEqual(lut1, lut3)
    }
    
    func test_lutData_hashable() {
        let lut1 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<256))
        let lut2 = LUTData(numberOfEntries: 256, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<256))
        let lut3 = LUTData(numberOfEntries: 128, firstValueMapped: 0, bitsPerEntry: 8, data: Array(0..<128))
        
        let set: Set = [lut1, lut2, lut3]
        XCTAssertEqual(set.count, 2)  // lut1 and lut2 are equal
    }
}
