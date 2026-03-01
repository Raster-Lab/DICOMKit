// ImageMetadataHelpersTests.swift
// DICOMStudioTests
//
// Tests for ImageMetadataHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ImageMetadataHelpers Tests")
struct ImageMetadataHelpersTests {

    // MARK: - dimensionsText

    @Test("Dimensions text for square image")
    func testDimensionsSquare() {
        #expect(ImageMetadataHelpers.dimensionsText(columns: 512, rows: 512) == "512 × 512")
    }

    @Test("Dimensions text for rectangular image")
    func testDimensionsRectangular() {
        #expect(ImageMetadataHelpers.dimensionsText(columns: 1024, rows: 768) == "1024 × 768")
    }

    @Test("Dimensions text for small image")
    func testDimensionsSmall() {
        #expect(ImageMetadataHelpers.dimensionsText(columns: 64, rows: 64) == "64 × 64")
    }

    // MARK: - bitDepthText

    @Test("Bit depth for 16/12/11")
    func testBitDepth16_12() {
        #expect(ImageMetadataHelpers.bitDepthText(bitsAllocated: 16, bitsStored: 12, highBit: 11) == "16 / 12 / 11")
    }

    @Test("Bit depth for 8/8/7")
    func testBitDepth8_8() {
        #expect(ImageMetadataHelpers.bitDepthText(bitsAllocated: 8, bitsStored: 8, highBit: 7) == "8 / 8 / 7")
    }

    @Test("Bit depth for 16/16/15")
    func testBitDepth16_16() {
        #expect(ImageMetadataHelpers.bitDepthText(bitsAllocated: 16, bitsStored: 16, highBit: 15) == "16 / 16 / 15")
    }

    // MARK: - pixelRepresentationText

    @Test("Signed pixel representation")
    func testPixelRepSigned() {
        #expect(ImageMetadataHelpers.pixelRepresentationText(isSigned: true) == "Signed")
    }

    @Test("Unsigned pixel representation")
    func testPixelRepUnsigned() {
        #expect(ImageMetadataHelpers.pixelRepresentationText(isSigned: false) == "Unsigned")
    }

    // MARK: - samplesText

    @Test("Single sample text")
    func testSamplesSingle() {
        #expect(ImageMetadataHelpers.samplesText(samplesPerPixel: 1, planarConfiguration: 0) == "1")
    }

    @Test("Three samples color-by-pixel")
    func testSamplesColorByPixel() {
        #expect(ImageMetadataHelpers.samplesText(samplesPerPixel: 3, planarConfiguration: 0) == "3 (color-by-pixel)")
    }

    @Test("Three samples color-by-plane")
    func testSamplesColorByPlane() {
        #expect(ImageMetadataHelpers.samplesText(samplesPerPixel: 3, planarConfiguration: 1) == "3 (color-by-plane)")
    }

    // MARK: - photometricLabel

    @Test("MONOCHROME1 label")
    func testPhotometricMono1() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "MONOCHROME1") == "Monochrome 1 (inverted)")
    }

    @Test("MONOCHROME2 label")
    func testPhotometricMono2() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "MONOCHROME2") == "Monochrome 2")
    }

    @Test("RGB label")
    func testPhotometricRGB() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "RGB") == "RGB Color")
    }

    @Test("PALETTE COLOR label")
    func testPhotometricPalette() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "PALETTE COLOR") == "Palette Color")
    }

    @Test("YBR_FULL label")
    func testPhotometricYBR() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_FULL") == "YBR Full")
    }

    @Test("YBR_FULL_422 label")
    func testPhotometricYBR422() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_FULL_422") == "YBR Full 4:2:2")
    }

    @Test("YBR_PARTIAL_422 label")
    func testPhotometricYBRPartial422() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_PARTIAL_422") == "YBR Partial 4:2:2")
    }

    @Test("YBR_PARTIAL_420 label")
    func testPhotometricYBRPartial420() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_PARTIAL_420") == "YBR Partial 4:2:0")
    }

    @Test("YBR_ICT label")
    func testPhotometricYBRICT() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_ICT") == "YBR ICT (JPEG 2000)")
    }

    @Test("YBR_RCT label")
    func testPhotometricYBRRCT() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "YBR_RCT") == "YBR RCT (JPEG 2000 Lossless)")
    }

    @Test("Unknown interpretation returns as-is")
    func testPhotometricUnknown() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "CUSTOM") == "CUSTOM")
    }

    @Test("Case insensitive photometric label")
    func testPhotometricCaseInsensitive() {
        #expect(ImageMetadataHelpers.photometricLabel(for: "monochrome2") == "Monochrome 2")
        #expect(ImageMetadataHelpers.photometricLabel(for: "rgb") == "RGB Color")
    }

    // MARK: - windowLevelText

    @Test("Window level text integer values")
    func testWindowLevelInteger() {
        #expect(ImageMetadataHelpers.windowLevelText(center: 40, width: 400) == "C: 40 W: 400")
    }

    @Test("Window level text decimal values")
    func testWindowLevelDecimal() {
        #expect(ImageMetadataHelpers.windowLevelText(center: 40.5, width: 400.2) == "C: 40.5 W: 400.2")
    }

    @Test("Window level text negative center")
    func testWindowLevelNegative() {
        let text = ImageMetadataHelpers.windowLevelText(center: -600, width: 1500)
        #expect(text == "C: -600 W: 1500")
    }

    // MARK: - frameText

    @Test("Frame text single frame")
    func testFrameTextSingle() {
        #expect(ImageMetadataHelpers.frameText(current: 1, total: 1) == "Frame 1 / 1")
    }

    @Test("Frame text multi-frame")
    func testFrameTextMulti() {
        #expect(ImageMetadataHelpers.frameText(current: 45, total: 120) == "Frame 45 / 120")
    }

    // MARK: - memorySizeText

    @Test("Memory size zero bytes")
    func testMemorySizeZero() {
        let text = ImageMetadataHelpers.memorySizeText(totalBytes: 0)
        #expect(text.contains("0") || text.contains("Zero"))
    }

    @Test("Memory size large")
    func testMemorySizeLarge() {
        let text = ImageMetadataHelpers.memorySizeText(totalBytes: 50 * 1024 * 1024)
        #expect(!text.isEmpty)
    }
}
