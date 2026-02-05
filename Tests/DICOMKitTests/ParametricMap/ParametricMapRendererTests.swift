//
// ParametricMapRendererTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics

final class ParametricMapRendererTests: XCTestCase {
    
    // MARK: - ColorMap Tests
    
    func test_colorMap_grayscale_mapsCorrectly() {
        let colorMap = ParametricMapRenderer.ColorMap.grayscale
        
        let black = colorMap.color(for: 0.0)
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)
        
        let mid = colorMap.color(for: 0.5)
        XCTAssertEqual(mid.r, 127, accuracy: 1)
        XCTAssertEqual(mid.g, 127, accuracy: 1)
        XCTAssertEqual(mid.b, 127, accuracy: 1)
        
        let white = colorMap.color(for: 1.0)
        XCTAssertEqual(white.r, 255)
        XCTAssertEqual(white.g, 255)
        XCTAssertEqual(white.b, 255)
    }
    
    func test_colorMap_hot_mapsCorrectly() {
        let colorMap = ParametricMapRenderer.ColorMap.hot
        
        let black = colorMap.color(for: 0.0)
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)
        
        let red = colorMap.color(for: 0.5)
        XCTAssertGreaterThan(red.r, 200)  // Should be mostly red
        
        let white = colorMap.color(for: 1.0)
        XCTAssertGreaterThan(white.r, 200)  // Should be bright
        XCTAssertGreaterThan(white.g, 200)
    }
    
    func test_colorMap_jet_mapsCorrectly() {
        let colorMap = ParametricMapRenderer.ColorMap.jet
        
        let blue = colorMap.color(for: 0.0)
        XCTAssertGreaterThan(blue.b, 100)  // Should have blue component
        
        let green = colorMap.color(for: 0.5)
        XCTAssertGreaterThan(green.g, 100)  // Should have green component
        
        let red = colorMap.color(for: 1.0)
        XCTAssertGreaterThan(red.r, 100)  // Should have red component
    }
    
    func test_colorMap_custom_mapsCorrectly() {
        let lut = [
            (r: 0.0, g: 0.0, b: 0.0),
            (r: 1.0, g: 0.0, b: 0.0),
            (r: 1.0, g: 1.0, b: 0.0),
            (r: 1.0, g: 1.0, b: 1.0)
        ]
        let colorMap = ParametricMapRenderer.ColorMap.custom(lut)
        
        let black = colorMap.color(for: 0.0)
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)
        
        let white = colorMap.color(for: 1.0)
        XCTAssertEqual(white.r, 255)
        XCTAssertEqual(white.g, 255)
        XCTAssertEqual(white.b, 255)
    }
    
    // MARK: - RenderOptions Tests
    
    func test_renderOptions_defaultValues_succeed() {
        let options = ParametricMapRenderer.RenderOptions()
        
        if case .hot = options.colorMap {
            // Success
        } else {
            XCTFail("Expected hot color map as default")
        }
        
        XCTAssertEqual(options.windowCenter, 0.0)
        XCTAssertEqual(options.windowWidth, 1.0)
        XCTAssertNil(options.minimumThreshold)
        XCTAssertNil(options.maximumThreshold)
        XCTAssertEqual(options.backgroundColor.r, 0)
    }
    
    func test_renderOptions_autoWindow_calculatesCorrectly() {
        let values = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 100.0]  // Outlier at 100
        let options = ParametricMapRenderer.RenderOptions.autoWindow(
            from: values,
            colorMap: .jet,
            percentile: 0.99
        )
        
        // Should exclude the outlier
        XCTAssertLessThan(options.windowCenter, 50.0)
        XCTAssertGreaterThan(options.windowWidth, 0.0)
        XCTAssertNotNil(options.minimumThreshold)
    }
    
    // MARK: - Rendering Tests
    
    func test_render_simpleValues_succeeds() {
        let values = [0.0, 0.5, 1.0, 1.5]
        let options = ParametricMapRenderer.RenderOptions(
            colorMap: .grayscale,
            windowCenter: 0.75,
            windowWidth: 1.5
        )
        
        let image = ParametricMapRenderer.render(
            values: values,
            width: 2,
            height: 2,
            options: options
        )
        
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 2)
        XCTAssertEqual(image?.height, 2)
    }
    
    func test_render_withThreshold_masksValues() {
        let values = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
        let options = ParametricMapRenderer.RenderOptions(
            colorMap: .hot,
            windowCenter: 1.25,
            windowWidth: 2.5,
            minimumThreshold: 0.5,
            backgroundColor: (r: 0, g: 0, b: 255)  // Blue background
        )
        
        let image = ParametricMapRenderer.render(
            values: values,
            width: 3,
            height: 2,
            options: options
        )
        
        XCTAssertNotNil(image)
    }
    
    func test_render_invalidDimensions_returnsNil() {
        let values = [1.0, 2.0, 3.0, 4.0]
        
        let image1 = ParametricMapRenderer.render(values: values, width: 0, height: 2)
        XCTAssertNil(image1)
        
        let image2 = ParametricMapRenderer.render(values: values, width: 2, height: 0)
        XCTAssertNil(image2)
    }
    
    func test_render_mismatchedPixelCount_returnsNil() {
        let values = [1.0, 2.0, 3.0]  // Only 3 values
        
        let image = ParametricMapRenderer.render(
            values: values,
            width: 2,
            height: 2  // Expects 4 values
        )
        
        XCTAssertNil(image)
    }
    
    // MARK: - Integration Tests
    
    func test_renderFrame_integration_succeeds() {
        // Create a parametric map
        let mapping = RealWorldValueMapping(
            measurementUnits: .millisecond,
            mapping: .linear(slope: 1.0, intercept: 0.0)
        )
        
        let parametricMap = ParametricMap(
            sopInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3",
            realWorldValueMappings: [mapping],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7
        )
        
        // Create pixel data
        let pixelData = Data([50, 100, 150, 200])
        
        // Render
        let image = ParametricMapRenderer.renderFrame(
            from: parametricMap,
            pixelData: pixelData,
            frameIndex: 0
        )
        
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 2)
        XCTAssertEqual(image?.height, 2)
    }
    
    func test_renderFrame_withCustomOptions_succeeds() {
        let mapping = RealWorldValueMapping(
            measurementUnits: .mm2PerSecond,
            mapping: .linear(slope: 0.001, intercept: 0.0)
        )
        
        let parametricMap = ParametricMap(
            sopInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3",
            realWorldValueMappings: [mapping],
            numberOfFrames: 1,
            rows: 4,
            columns: 4,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7
        )
        
        let pixelData = Data(0..<16)  // 0 to 15
        
        let options = ParametricMapRenderer.RenderOptions(
            colorMap: .jet,
            windowCenter: 0.0075,
            windowWidth: 0.015
        )
        
        let image = ParametricMapRenderer.renderFrame(
            from: parametricMap,
            pixelData: pixelData,
            frameIndex: 0,
            options: options
        )
        
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 4)
        XCTAssertEqual(image?.height, 4)
    }
}

#endif
