// BlendingHelpersTests.swift
// DICOMStudioTests
//
// Tests for BlendingHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("BlendingHelpers Grayscale Tests")
struct BlendingGrayscaleTests {

    @Test("Full underlay (alpha = 0)")
    func testFullUnderlay() {
        let result = BlendingHelpers.blendGrayscale(underlay: 0.8, overlay: 0.2, alpha: 0.0)
        #expect(abs(result - 0.8) < 0.001)
    }

    @Test("Full overlay (alpha = 1)")
    func testFullOverlay() {
        let result = BlendingHelpers.blendGrayscale(underlay: 0.8, overlay: 0.2, alpha: 1.0)
        #expect(abs(result - 0.2) < 0.001)
    }

    @Test("50/50 blend")
    func testHalfBlend() {
        let result = BlendingHelpers.blendGrayscale(underlay: 0.0, overlay: 1.0, alpha: 0.5)
        #expect(abs(result - 0.5) < 0.001)
    }

    @Test("Result clamped to [0, 1]")
    func testClamped() {
        let result = BlendingHelpers.blendGrayscale(underlay: 1.5, overlay: 0.5, alpha: 0.0)
        #expect(result <= 1.0)
    }
}

@Suite("BlendingHelpers Color Tests")
struct BlendingColorTests {

    @Test("Full underlay color")
    func testFullUnderlay() {
        let underlay = ColorEntry(red: 255, green: 0, blue: 0)
        let overlay = ColorEntry(red: 0, green: 255, blue: 0)
        let result = BlendingHelpers.blendColor(underlay: underlay, overlay: overlay, alpha: 0.0)
        #expect(result.red == 255)
        #expect(result.green == 0)
    }

    @Test("Full overlay color")
    func testFullOverlay() {
        let underlay = ColorEntry(red: 255, green: 0, blue: 0)
        let overlay = ColorEntry(red: 0, green: 255, blue: 0)
        let result = BlendingHelpers.blendColor(underlay: underlay, overlay: overlay, alpha: 1.0)
        #expect(result.red == 0)
        #expect(result.green == 255)
    }

    @Test("50/50 color blend")
    func testHalfBlend() {
        let underlay = ColorEntry(red: 0, green: 0, blue: 0)
        let overlay = ColorEntry(red: 200, green: 100, blue: 50)
        let result = BlendingHelpers.blendColor(underlay: underlay, overlay: overlay, alpha: 0.5)
        #expect(result.red == 100)
        #expect(result.green == 50)
        #expect(result.blue == 25)
    }
}

@Suite("BlendingHelpers Fusion Tests")
struct BlendingFusionTests {

    @Test("CT/PET fusion with zero opacity shows CT only")
    func testZeroOpacity() {
        let result = BlendingHelpers.fusionBlend(
            ctValue: 0.5,
            petValue: 0.8,
            petPalette: ColorLUTHelpers.hotIronPalette(),
            opacity: 0.0
        )
        // Should be gray (CT only)
        #expect(result.red == result.green)
        #expect(result.green == result.blue)
    }

    @Test("Fusion with grayscale palette and full opacity")
    func testFullOpacityGrayscale() {
        let result = BlendingHelpers.fusionBlend(
            ctValue: 0.5,
            petValue: 0.8,
            petPalette: ColorLUTHelpers.grayscalePalette(),
            opacity: 1.0
        )
        // Should be the PET value as grayscale
        #expect(result.red > 190)
    }
}

@Suite("BlendingHelpers Opacity Tests")
struct BlendingOpacityTests {

    @Test("Clamp opacity to valid range")
    func testClamp() {
        #expect(BlendingHelpers.clampOpacity(-0.5) == 0.0)
        #expect(BlendingHelpers.clampOpacity(1.5) == 1.0)
        #expect(BlendingHelpers.clampOpacity(0.5) == 0.5)
    }

    @Test("Opacity label")
    func testLabel() {
        #expect(BlendingHelpers.opacityLabel(0.5) == "50%")
        #expect(BlendingHelpers.opacityLabel(0.0) == "0%")
        #expect(BlendingHelpers.opacityLabel(1.0) == "100%")
    }

    @Test("Constants are correct")
    func testConstants() {
        #expect(BlendingHelpers.minOpacity == 0.0)
        #expect(BlendingHelpers.maxOpacity == 1.0)
        #expect(BlendingHelpers.defaultOpacity == 0.5)
        #expect(BlendingHelpers.opacityStep == 0.05)
    }
}

@Suite("BlendingHelpers Display Tests")
struct BlendingDisplayTests {

    @Test("Fusion labels")
    func testFusionLabels() {
        #expect(BlendingHelpers.fusionLabel(for: "PET/CT") == "PET/CT Fusion")
        #expect(BlendingHelpers.fusionLabel(for: "SPECT/CT") == "SPECT/CT Fusion")
        #expect(BlendingHelpers.fusionLabel(for: "unknown") == "Image Fusion")
    }
}
