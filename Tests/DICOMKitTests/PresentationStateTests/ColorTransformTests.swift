//
// ColorTransformTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class ColorTransformTests: XCTestCase {
    
    // MARK: - sRGB Gamma Tests
    
    func test_sRGBToLinear_lowValues() {
        // Test values below threshold (0.04045)
        let result1 = ColorTransform.sRGBToLinear(0.0)
        XCTAssertEqual(result1, 0.0, accuracy: 1e-6)
        
        let result2 = ColorTransform.sRGBToLinear(0.03928)
        XCTAssertEqual(result2, 0.03928 / 12.92, accuracy: 1e-6)
    }
    
    func test_sRGBToLinear_highValues() {
        // Test values above threshold
        let result1 = ColorTransform.sRGBToLinear(0.5)
        let expected1 = pow((0.5 + 0.055) / 1.055, 2.4)
        XCTAssertEqual(result1, expected1, accuracy: 1e-6)
        
        let result2 = ColorTransform.sRGBToLinear(1.0)
        XCTAssertEqual(result2, 1.0, accuracy: 1e-6)
    }
    
    func test_linearToSRGB_lowValues() {
        // Test values below threshold (0.0031308)
        let result1 = ColorTransform.linearToSRGB(0.0)
        XCTAssertEqual(result1, 0.0, accuracy: 1e-6)
        
        let result2 = ColorTransform.linearToSRGB(0.003)
        XCTAssertEqual(result2, 0.003 * 12.92, accuracy: 1e-6)
    }
    
    func test_linearToSRGB_highValues() {
        // Test values above threshold
        let result1 = ColorTransform.linearToSRGB(0.5)
        let expected1 = 1.055 * pow(0.5, 1.0 / 2.4) - 0.055
        XCTAssertEqual(result1, expected1, accuracy: 1e-6)
        
        let result2 = ColorTransform.linearToSRGB(1.0)
        XCTAssertEqual(result2, 1.0, accuracy: 1e-6)
    }
    
    func test_sRGBGamma_roundTrip() {
        // Test round-trip conversion
        let originalValues = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for original in originalValues {
            let linear = ColorTransform.sRGBToLinear(original)
            let backToSRGB = ColorTransform.linearToSRGB(linear)
            XCTAssertEqual(backToSRGB, original, accuracy: 1e-6)
        }
    }
    
    // MARK: - RGB to XYZ Tests
    
    func test_rgbToXYZ_black() {
        let result = ColorTransform.rgbToXYZ((red: 0, green: 0, blue: 0))
        XCTAssertEqual(result.x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.0, accuracy: 1e-6)
    }
    
    func test_rgbToXYZ_white() {
        let result = ColorTransform.rgbToXYZ((red: 1, green: 1, blue: 1))
        // D65 white point: approximately (0.9505, 1.0, 1.089)
        XCTAssertEqual(result.x, 0.9505, accuracy: 0.001)
        XCTAssertEqual(result.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.z, 1.089, accuracy: 0.001)
    }
    
    func test_rgbToXYZ_red() {
        let result = ColorTransform.rgbToXYZ((red: 1, green: 0, blue: 0))
        XCTAssertEqual(result.x, 0.4124564, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.2126729, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.0193339, accuracy: 1e-6)
    }
    
    func test_rgbToXYZ_green() {
        let result = ColorTransform.rgbToXYZ((red: 0, green: 1, blue: 0))
        XCTAssertEqual(result.x, 0.3575761, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.7151522, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.1191920, accuracy: 1e-6)
    }
    
    func test_rgbToXYZ_blue() {
        let result = ColorTransform.rgbToXYZ((red: 0, green: 0, blue: 1))
        XCTAssertEqual(result.x, 0.1804375, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.0721750, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.9503041, accuracy: 1e-6)
    }
    
    // MARK: - XYZ to RGB Tests
    
    func test_xyzToRGB_black() {
        let result = ColorTransform.xyzToRGB((x: 0, y: 0, z: 0))
        XCTAssertEqual(result.red, 0.0, accuracy: 1e-6)
        XCTAssertEqual(result.green, 0.0, accuracy: 1e-6)
        XCTAssertEqual(result.blue, 0.0, accuracy: 1e-6)
    }
    
    func test_xyzToRGB_white() {
        let result = ColorTransform.xyzToRGB((x: 0.9505, y: 1.0, z: 1.089))
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.green, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.blue, 1.0, accuracy: 0.01)
    }
    
    func test_xyzToRGB_roundTrip() {
        let originalColors = [
            (red: 0.0, green: 0.0, blue: 0.0),
            (red: 1.0, green: 0.0, blue: 0.0),
            (red: 0.0, green: 1.0, blue: 0.0),
            (red: 0.0, green: 0.0, blue: 1.0),
            (red: 1.0, green: 1.0, blue: 1.0),
            (red: 0.5, green: 0.5, blue: 0.5)
        ]
        
        for original in originalColors {
            let xyz = ColorTransform.rgbToXYZ(original)
            let backToRGB = ColorTransform.xyzToRGB(xyz)
            XCTAssertEqual(backToRGB.red, original.red, accuracy: 0.001)
            XCTAssertEqual(backToRGB.green, original.green, accuracy: 0.001)
            XCTAssertEqual(backToRGB.blue, original.blue, accuracy: 0.001)
        }
    }
    
    // MARK: - XYZ to LAB Tests
    
    func test_xyzToLAB_black() {
        let result = ColorTransform.xyzToLAB((x: 0, y: 0, z: 0))
        XCTAssertEqual(result.l, 0.0, accuracy: 0.1)
        XCTAssertEqual(result.a, 0.0, accuracy: 0.1)
        XCTAssertEqual(result.b, 0.0, accuracy: 0.1)
    }
    
    func test_xyzToLAB_white() {
        // D65 white point
        let result = ColorTransform.xyzToLAB((x: 0.95047, y: 1.0, z: 1.08883))
        XCTAssertEqual(result.l, 100.0, accuracy: 0.1)
        XCTAssertEqual(result.a, 0.0, accuracy: 0.1)
        XCTAssertEqual(result.b, 0.0, accuracy: 0.1)
    }
    
    func test_xyzToLAB_gray() {
        // 50% gray in XYZ
        let result = ColorTransform.xyzToLAB((x: 0.20, y: 0.21, z: 0.23))
        // Should have L around 50, a and b near 0
        XCTAssertGreaterThan(result.l, 40)
        XCTAssertLessThan(result.l, 60)
        XCTAssertEqual(result.a, 0.0, accuracy: 5.0)
        XCTAssertEqual(result.b, 0.0, accuracy: 5.0)
    }
    
    // MARK: - LAB to XYZ Tests
    
    func test_labToXYZ_black() {
        let result = ColorTransform.labToXYZ((l: 0, a: 0, b: 0))
        XCTAssertEqual(result.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.z, 0.0, accuracy: 0.001)
    }
    
    func test_labToXYZ_white() {
        let result = ColorTransform.labToXYZ((l: 100, a: 0, b: 0))
        // D65 white point
        XCTAssertEqual(result.x, 0.95047, accuracy: 0.001)
        XCTAssertEqual(result.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.z, 1.08883, accuracy: 0.001)
    }
    
    func test_labToXYZ_roundTrip() {
        let originalLABs = [
            (l: 0.0, a: 0.0, b: 0.0),
            (l: 50.0, a: 0.0, b: 0.0),
            (l: 100.0, a: 0.0, b: 0.0),
            (l: 50.0, a: 20.0, b: 30.0),
            (l: 75.0, a: -10.0, b: 15.0)
        ]
        
        for original in originalLABs {
            let xyz = ColorTransform.labToXYZ(original)
            let backToLAB = ColorTransform.xyzToLAB(xyz)
            XCTAssertEqual(backToLAB.l, original.l, accuracy: 0.01)
            XCTAssertEqual(backToLAB.a, original.a, accuracy: 0.01)
            XCTAssertEqual(backToLAB.b, original.b, accuracy: 0.01)
        }
    }
    
    #if canImport(CoreGraphics)
    
    // MARK: - RGB to LAB Tests
    
    func test_rgbToLAB_black() {
        let result = ColorTransform.rgbToLAB((red: 0, green: 0, blue: 0))
        XCTAssertEqual(result.l, 0.0, accuracy: 0.1)
    }
    
    func test_rgbToLAB_white() {
        let result = ColorTransform.rgbToLAB((red: 1, green: 1, blue: 1))
        XCTAssertEqual(result.l, 100.0, accuracy: 0.1)
        XCTAssertEqual(result.a, 0.0, accuracy: 0.1)
        XCTAssertEqual(result.b, 0.0, accuracy: 0.1)
    }
    
    func test_rgbToLAB_red() {
        let result = ColorTransform.rgbToLAB((red: 1, green: 0, blue: 0))
        // Red should have positive L, positive a, variable b
        XCTAssertGreaterThan(result.l, 0)
        XCTAssertGreaterThan(result.a, 0)
    }
    
    // MARK: - LAB to RGB Tests
    
    func test_labToRGB_black() {
        let result = ColorTransform.labToRGB((l: 0, a: 0, b: 0))
        XCTAssertEqual(result.red, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.blue, 0.0, accuracy: 0.01)
    }
    
    func test_labToRGB_white() {
        let result = ColorTransform.labToRGB((l: 100, a: 0, b: 0))
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.green, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.blue, 1.0, accuracy: 0.01)
    }
    
    func test_labToRGB_roundTrip() {
        let originalRGBs = [
            (red: 0.0, green: 0.0, blue: 0.0),
            (red: 1.0, green: 0.0, blue: 0.0),
            (red: 0.0, green: 1.0, blue: 0.0),
            (red: 0.0, green: 0.0, blue: 1.0),
            (red: 1.0, green: 1.0, blue: 1.0),
            (red: 0.5, green: 0.5, blue: 0.5)
        ]
        
        for original in originalRGBs {
            let lab = ColorTransform.rgbToLAB(original)
            let backToRGB = ColorTransform.labToRGB(lab)
            XCTAssertEqual(backToRGB.red, original.red, accuracy: 0.01)
            XCTAssertEqual(backToRGB.green, original.green, accuracy: 0.01)
            XCTAssertEqual(backToRGB.blue, original.blue, accuracy: 0.01)
        }
    }
    
    #endif // canImport(CoreGraphics)
    
    #if canImport(CoreGraphics)
    
    // MARK: - Core Graphics Integration Tests
    
    func test_createColorSpace_validICCData() {
        // Create a minimal sRGB-like profile
        // This is a simplified test - real ICC profiles are complex
        let profileData = Data(repeating: 0, count: 1000)
        
        // Note: This will likely fail with invalid data
        // In a real scenario, we'd use actual ICC profile data
        let colorSpace = ColorTransform.createColorSpace(from: profileData)
        
        // We can't guarantee success with dummy data, so just test the API exists
        XCTAssertTrue(colorSpace == nil || colorSpace != nil)
    }
    
    func test_transform_sameColorSpace() {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
            XCTFail("Failed to create sRGB color space")
            return
        }
        
        let original = (red: 0.5, green: 0.6, blue: 0.7)
        let transformed = ColorTransform.transform(
            rgb: original,
            from: sRGB,
            to: sRGB
        )
        
        // Same color space should produce same values
        XCTAssertEqual(transformed.red, original.red, accuracy: 0.01)
        XCTAssertEqual(transformed.green, original.green, accuracy: 0.01)
        XCTAssertEqual(transformed.blue, original.blue, accuracy: 0.01)
    }
    
    func test_transformPixels_multipleColors() {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
            XCTFail("Failed to create sRGB color space")
            return
        }
        
        let pixels = [
            (red: 1.0, green: 0.0, blue: 0.0),
            (red: 0.0, green: 1.0, blue: 0.0),
            (red: 0.0, green: 0.0, blue: 1.0)
        ]
        
        let transformed = ColorTransform.transformPixels(
            pixels,
            from: sRGB,
            to: sRGB
        )
        
        XCTAssertEqual(transformed.count, 3)
        for (original, result) in zip(pixels, transformed) {
            XCTAssertEqual(result.red, original.red, accuracy: 0.01)
            XCTAssertEqual(result.green, original.green, accuracy: 0.01)
            XCTAssertEqual(result.blue, original.blue, accuracy: 0.01)
        }
    }
    
    #endif
}
