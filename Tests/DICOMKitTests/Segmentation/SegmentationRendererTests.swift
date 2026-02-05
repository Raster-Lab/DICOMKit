//
// SegmentationRendererTests.swift
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
#endif

final class SegmentationRendererTests: XCTestCase {
    
    // MARK: - CIELab to RGB Conversion Tests
    
    #if canImport(CoreGraphics)
    func test_cielabToRGB_pureRed_approximatelyCorrect() {
        // Given: CIELab values approximating pure red
        // L*=50, a*=+80, b*=+70 (in DICOM 16-bit unsigned format)
        let cielab = CIELabColor(
            l: 32768,  // Mid lightness
            a: 45000,  // Positive a* (red)
            b: 45000   // Positive b* (yellow)
        )
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: Should have strong red component
        XCTAssertGreaterThan(rgb.r, 100)
    }
    
    func test_cielabToRGB_pureGreen_approximatelyCorrect() {
        // Given: CIELab values approximating green
        let cielab = CIELabColor(
            l: 32768,  // Mid lightness
            a: 20000,  // Negative a* (green)
            b: 45000   // Positive b* (yellow)
        )
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: Should have green component
        XCTAssertGreaterThan(rgb.g, 50)
    }
    
    func test_cielabToRGB_pureBlue_approximatelyCorrect() {
        // Given: CIELab values approximating blue
        let cielab = CIELabColor(
            l: 32768,  // Mid lightness
            a: 32768,  // Neutral a*
            b: 20000   // Negative b* (blue)
        )
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: Should have blue component
        XCTAssertGreaterThan(rgb.b, 50)
    }
    
    func test_cielabToRGB_black_convertsCorrectly() {
        // Given: CIELab black (L*=0)
        let cielab = CIELabColor(l: 0, a: 32768, b: 32768)
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: Should be close to black
        XCTAssertLessThan(rgb.r, 10)
        XCTAssertLessThan(rgb.g, 10)
        XCTAssertLessThan(rgb.b, 10)
    }
    
    func test_cielabToRGB_white_convertsCorrectly() {
        // Given: CIELab white (L*=100)
        let cielab = CIELabColor(l: 65535, a: 32768, b: 32768)
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: Should be close to white
        XCTAssertGreaterThan(rgb.r, 245)
        XCTAssertGreaterThan(rgb.g, 245)
        XCTAssertGreaterThan(rgb.b, 245)
    }
    
    func test_cielabToRGB_neutralGray_convertsCorrectly() {
        // Given: CIELab neutral gray (L*=50, a*=0, b*=0)
        let cielab = CIELabColor(l: 32768, a: 32768, b: 32768)
        
        // When: Converting to RGB
        let rgb = SegmentationRenderer.cielabToRGB(cielab)
        
        // Then: RGB values should be similar (gray)
        let avg = (Int(rgb.r) + Int(rgb.g) + Int(rgb.b)) / 3
        XCTAssertLessThan(abs(Int(rgb.r) - avg), 20)
        XCTAssertLessThan(abs(Int(rgb.g) - avg), 20)
        XCTAssertLessThan(abs(Int(rgb.b) - avg), 20)
    }
    
    // MARK: - RenderOptions Tests
    
    func test_renderOptions_defaultInitialization() {
        let options = SegmentationRenderer.RenderOptions()
        
        XCTAssertEqual(options.opacity, 0.5)
        XCTAssertNil(options.visibleSegments)
        XCTAssertNil(options.customColors)
    }
    
    func test_renderOptions_customInitialization() {
        let visibleSegments: Set<Int> = [1, 2, 3]
        let customColors: [Int: (r: UInt8, g: UInt8, b: UInt8)] = [
            1: (255, 0, 0),
            2: (0, 255, 0)
        ]
        
        let options = SegmentationRenderer.RenderOptions(
            opacity: 0.75,
            visibleSegments: visibleSegments,
            customColors: customColors
        )
        
        XCTAssertEqual(options.opacity, 0.75)
        XCTAssertEqual(options.visibleSegments, visibleSegments)
        XCTAssertEqual(options.customColors?.count, 2)
    }
    
    func test_renderOptions_opacityClampingLow() {
        let options = SegmentationRenderer.RenderOptions(opacity: -0.5)
        XCTAssertEqual(options.opacity, 0.0)
    }
    
    func test_renderOptions_opacityClampingHigh() {
        let options = SegmentationRenderer.RenderOptions(opacity: 1.5)
        XCTAssertEqual(options.opacity, 1.0)
    }
    
    // MARK: - Render Overlay Tests
    
    func test_renderOverlay_singleSegment_succeeds() {
        // Given: Segmentation with one segment
        let color = CIELabColor(l: 32768, a: 45000, b: 45000)
        let segment = Segment(
            segmentNumber: 1,
            segmentLabel: "Test",
            recommendedDisplayCIELabValue: color
        )
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        // Segment mask: half filled
        let masks: [Int: [UInt8]] = [1: [255, 255, 0, 0]]
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should create overlay image
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.width, 2)
        XCTAssertEqual(overlay?.height, 2)
    }
    
    func test_renderOverlay_withCustomColors_succeeds() {
        // Given: Segmentation and custom colors
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [1: [255, 255, 0, 0]]
        
        let customColors: [Int: (r: UInt8, g: UInt8, b: UInt8)] = [
            1: (255, 0, 0)  // Pure red
        ]
        
        let options = SegmentationRenderer.RenderOptions(
            opacity: 1.0,
            customColors: customColors
        )
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks,
            options: options
        )
        
        // Then: Should create overlay with custom colors
        XCTAssertNotNil(overlay)
    }
    
    func test_renderOverlay_multipleSegments_succeeds() {
        // Given: Segmentation with multiple segments
        let segment1 = Segment(segmentNumber: 1, segmentLabel: "Segment 1")
        let segment2 = Segment(segmentNumber: 2, segmentLabel: "Segment 2")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 2,
            segments: [segment1, segment2],
            numberOfFrames: 2,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [
            1: [255, 0, 0, 0],
            2: [0, 255, 0, 0]
        ]
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should create overlay with both segments
        XCTAssertNotNil(overlay)
    }
    
    func test_renderOverlay_withVisibilityFiltering_succeeds() {
        // Given: Segmentation with 2 segments, only 1 visible
        let segment1 = Segment(segmentNumber: 1, segmentLabel: "Visible")
        let segment2 = Segment(segmentNumber: 2, segmentLabel: "Hidden")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 2,
            segments: [segment1, segment2],
            numberOfFrames: 2,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [
            1: [255, 255, 0, 0],
            2: [0, 0, 255, 255]
        ]
        
        let options = SegmentationRenderer.RenderOptions(
            visibleSegments: [1]  // Only segment 1 visible
        )
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks,
            options: options
        )
        
        // Then: Should create overlay with only visible segment
        XCTAssertNotNil(overlay)
    }
    
    func test_renderOverlay_emptyMasks_returnsImage() {
        // Given: Segmentation with no masks
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [:]
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should still create image (fully transparent)
        XCTAssertNotNil(overlay)
    }
    
    func test_renderOverlay_invalidDimensions_returnsNil() {
        // Given: Segmentation with zero dimensions
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 0,
            columns: 0,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [1: []]
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should return nil
        XCTAssertNil(overlay)
    }
    
    func test_renderOverlay_wrongMaskSize_skipsSegment() {
        // Given: Segmentation with mismatched mask size
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        // Wrong size mask (2 pixels instead of 4)
        let masks: [Int: [UInt8]] = [1: [255, 255]]
        
        // When: Rendering overlay
        let overlay = SegmentationRenderer.renderOverlay(
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should create empty overlay (skips bad segment)
        XCTAssertNotNil(overlay)
    }
    
    // MARK: - Composite with Base Image Tests
    
    func test_compositeWithImage_matchingDimensions_succeeds() {
        // Given: Base image and segmentation with same dimensions
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 4,
            columns: 4,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [
            1: [UInt8](repeating: 128, count: 16)
        ]
        
        // Create a simple base image (4x4 grayscale)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var basePixels = [UInt8](repeating: 128, count: 16)
        
        guard let dataProvider = CGDataProvider(data: Data(basePixels) as CFData),
              let baseImage = CGImage(
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            XCTFail("Failed to create base image")
            return
        }
        
        // When: Compositing
        let composite = SegmentationRenderer.compositeWithImage(
            baseImage: baseImage,
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should create composite image
        XCTAssertNotNil(composite)
        XCTAssertEqual(composite?.width, 4)
        XCTAssertEqual(composite?.height, 4)
    }
    
    func test_compositeWithImage_dimensionMismatch_returnsNil() {
        // Given: Base image and segmentation with different dimensions
        let segment = Segment(segmentNumber: 1, segmentLabel: "Test")
        
        let segmentation = Segmentation(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            studyInstanceUID: "1.2.3.4.5",
            segmentationType: .binary,
            numberOfSegments: 1,
            segments: [segment],
            numberOfFrames: 1,
            rows: 2,
            columns: 2,
            bitsAllocated: 1,
            bitsStored: 1,
            highBit: 0
        )
        
        let masks: [Int: [UInt8]] = [1: [255, 255, 0, 0]]
        
        // Create a 4x4 base image (different from 2x2 segmentation)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var basePixels = [UInt8](repeating: 128, count: 16)
        
        guard let dataProvider = CGDataProvider(data: Data(basePixels) as CFData),
              let baseImage = CGImage(
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            XCTFail("Failed to create base image")
            return
        }
        
        // When: Compositing
        let composite = SegmentationRenderer.compositeWithImage(
            baseImage: baseImage,
            segmentation: segmentation,
            segmentMasks: masks
        )
        
        // Then: Should return nil (dimension mismatch)
        XCTAssertNil(composite)
    }
    #endif
}
