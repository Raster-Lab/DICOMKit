// ColorLUTHelpersTests.swift
// DICOMStudioTests
//
// Tests for ColorLUTHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ColorLUTHelpers Palette Tests")
struct ColorLUTPaletteTests {

    @Test("Hot Iron palette has 256 entries")
    func testHotIronSize() {
        let palette = ColorLUTHelpers.hotIronPalette()
        #expect(palette.count == 256)
    }

    @Test("Hot Iron starts dark, ends bright")
    func testHotIronRange() {
        let palette = ColorLUTHelpers.hotIronPalette()
        // First entry is dark
        #expect(palette[0].red == 0)
        #expect(palette[0].green == 0)
        #expect(palette[0].blue == 0)
        // Last entry is bright
        #expect(palette[255].red == 255)
        #expect(palette[255].green == 255)
    }

    @Test("Rainbow palette has 256 entries")
    func testRainbowSize() {
        let palette = ColorLUTHelpers.rainbowPalette()
        #expect(palette.count == 256)
    }

    @Test("Hot Metal palette has 256 entries")
    func testHotMetalSize() {
        let palette = ColorLUTHelpers.hotMetalPalette()
        #expect(palette.count == 256)
    }

    @Test("PET palette has 256 entries")
    func testPETSize() {
        let palette = ColorLUTHelpers.petPalette()
        #expect(palette.count == 256)
    }

    @Test("PET 20-step palette has 256 entries")
    func testPET20Size() {
        let palette = ColorLUTHelpers.pet20StepPalette()
        #expect(palette.count == 256)
    }

    @Test("Grayscale palette identity")
    func testGrayscale() {
        let palette = ColorLUTHelpers.grayscalePalette()
        #expect(palette.count == 256)
        #expect(palette[0].red == 0)
        #expect(palette[128].red == 128)
        #expect(palette[255].red == 255)
        // All components are equal for grayscale
        for entry in palette {
            #expect(entry.red == entry.green)
            #expect(entry.green == entry.blue)
        }
    }

    @Test("Palette lookup for all types")
    func testPaletteLookup() {
        for paletteType in PseudoColorPalette.allCases {
            let palette = ColorLUTHelpers.palette(for: paletteType)
            #expect(palette.count == 256, "Palette \(paletteType) should have 256 entries")
        }
    }
}

@Suite("ColorLUTHelpers LUT Application Tests")
struct ColorLUTApplicationTests {

    @Test("Apply LUT at 0 returns first entry")
    func testApplyAtZero() {
        let lut = ColorLUTHelpers.grayscalePalette()
        let result = ColorLUTHelpers.applyLUT(grayValue: 0, lut: lut)
        #expect(result.red == 0)
    }

    @Test("Apply LUT at 1 returns last entry")
    func testApplyAtOne() {
        let lut = ColorLUTHelpers.grayscalePalette()
        let result = ColorLUTHelpers.applyLUT(grayValue: 1, lut: lut)
        #expect(result.red == 255)
    }

    @Test("Apply LUT at 0.5 returns middle entry")
    func testApplyAtHalf() {
        let lut = ColorLUTHelpers.grayscalePalette()
        let result = ColorLUTHelpers.applyLUT(grayValue: 0.5, lut: lut)
        #expect(result.red >= 126 && result.red <= 128)
    }

    @Test("Apply LUT with empty table returns black")
    func testEmptyLUT() {
        let result = ColorLUTHelpers.applyLUT(grayValue: 0.5, lut: [])
        #expect(result.red == 0)
        #expect(result.green == 0)
        #expect(result.blue == 0)
    }
}

@Suite("ColorLUTHelpers HSV Tests")
struct ColorLUTHSVTests {

    @Test("Red at hue 0")
    func testRed() {
        let (r, g, b) = ColorLUTHelpers.hsvToRGB(h: 0, s: 1.0, v: 1.0)
        #expect(r == 255)
        #expect(g == 0)
        #expect(b == 0)
    }

    @Test("Green at hue 120")
    func testGreen() {
        let (r, g, b) = ColorLUTHelpers.hsvToRGB(h: 120, s: 1.0, v: 1.0)
        #expect(r == 0)
        #expect(g == 255)
        #expect(b == 0)
    }

    @Test("Blue at hue 240")
    func testBlue() {
        let (r, g, b) = ColorLUTHelpers.hsvToRGB(h: 240, s: 1.0, v: 1.0)
        #expect(r == 0)
        #expect(g == 0)
        #expect(b == 255)
    }

    @Test("White at saturation 0")
    func testWhite() {
        let (r, g, b) = ColorLUTHelpers.hsvToRGB(h: 0, s: 0, v: 1.0)
        #expect(r == 255)
        #expect(g == 255)
        #expect(b == 255)
    }

    @Test("Black at value 0")
    func testBlack() {
        let (r, g, b) = ColorLUTHelpers.hsvToRGB(h: 0, s: 1.0, v: 0)
        #expect(r == 0)
        #expect(g == 0)
        #expect(b == 0)
    }
}

@Suite("ColorLUTHelpers Display Tests")
struct ColorLUTDisplayTests {

    @Test("Palette labels")
    func testLabels() {
        #expect(ColorLUTHelpers.paletteLabel(for: .hotIron) == "Hot Iron")
        #expect(ColorLUTHelpers.paletteLabel(for: .rainbow) == "Rainbow")
        #expect(ColorLUTHelpers.paletteLabel(for: .pet) == "PET")
        #expect(ColorLUTHelpers.paletteLabel(for: .grayscale) == "Grayscale")
    }
}
