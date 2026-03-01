// ICCProfileHelpersTests.swift
// DICOMStudioTests
//
// Tests for ICCProfileHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ICCColorSpace Tests")
struct ICCColorSpaceTests {

    @Test("All color spaces")
    func testCaseCount() {
        #expect(ICCColorSpace.allCases.count == 6)
    }

    @Test("Raw values")
    func testRawValues() {
        #expect(ICCColorSpace.rgb.rawValue == "RGB")
        #expect(ICCColorSpace.gray.rawValue == "GRAY")
    }
}

@Suite("ICCRenderingIntent Tests")
struct ICCRenderingIntentTests {

    @Test("All rendering intents")
    func testCaseCount() {
        #expect(ICCRenderingIntent.allCases.count == 4)
    }
}

@Suite("ICCProfileInfo Tests")
struct ICCProfileInfoTests {

    @Test("Profile info creation")
    func testCreation() {
        let info = ICCProfileInfo(
            size: 1024,
            version: "4.3.0",
            colorSpace: .rgb,
            description: "sRGB"
        )
        #expect(info.size == 1024)
        #expect(info.version == "4.3.0")
        #expect(info.colorSpace == .rgb)
        #expect(info.description == "sRGB")
    }
}

@Suite("ICCProfileHelpers Validation Tests")
struct ICCProfileValidationTests {

    @Test("Invalid profile - too short")
    func testTooShort() {
        let data = Data(count: 50)
        #expect(!ICCProfileHelpers.isValidProfile(data))
    }

    @Test("Invalid profile - wrong signature")
    func testWrongSignature() {
        var data = Data(count: 128)
        data[36] = 0x00
        data[37] = 0x00
        data[38] = 0x00
        data[39] = 0x00
        #expect(!ICCProfileHelpers.isValidProfile(data))
    }

    @Test("Valid profile with acsp signature")
    func testValidSignature() {
        var data = Data(count: 128)
        // Set 'acsp' at offset 36
        data[36] = 0x61 // 'a'
        data[37] = 0x63 // 'c'
        data[38] = 0x73 // 's'
        data[39] = 0x70 // 'p'
        #expect(ICCProfileHelpers.isValidProfile(data))
    }
}

@Suite("ICCProfileHelpers Parse Tests")
struct ICCProfileParseTests {

    @Test("Parse invalid data returns nil")
    func testInvalidParse() {
        let data = Data(count: 50)
        #expect(ICCProfileHelpers.parseProfileInfo(data) == nil)
    }

    @Test("Parse valid profile header")
    func testValidParse() {
        var data = Data(count: 128)

        // Size (bytes 0-3) = 128
        data[0] = 0
        data[1] = 0
        data[2] = 0
        data[3] = 128

        // Version (bytes 8-9) = 4.3
        data[8] = 4
        data[9] = 0x30

        // Device class (bytes 12-15) = 'mntr' (monitor)
        data[12] = 0x6D // 'm'
        data[13] = 0x6E // 'n'
        data[14] = 0x74 // 't'
        data[15] = 0x72 // 'r'

        // Color space (bytes 16-19) = 'RGB '
        data[16] = 0x52 // 'R'
        data[17] = 0x47 // 'G'
        data[18] = 0x42 // 'B'
        data[19] = 0x20 // ' '

        // PCS (bytes 20-23) = 'XYZ '
        data[20] = 0x58 // 'X'
        data[21] = 0x59 // 'Y'
        data[22] = 0x5A // 'Z'
        data[23] = 0x20 // ' '

        // 'acsp' signature at offset 36
        data[36] = 0x61
        data[37] = 0x63
        data[38] = 0x73
        data[39] = 0x70

        // Rendering intent (bytes 64-67) = 0 (perceptual)
        data[64] = 0
        data[65] = 0
        data[66] = 0
        data[67] = 0

        let info = ICCProfileHelpers.parseProfileInfo(data)
        #expect(info != nil)
        #expect(info?.colorSpace == .rgb)
        #expect(info?.connectionSpace == .xyz)
        #expect(info?.isDisplayProfile == true)
        #expect(info?.renderingIntent == .perceptual)
    }
}

@Suite("ICCProfileHelpers Display Tests")
struct ICCProfileDisplayTests {

    @Test("Color space labels")
    func testColorSpaceLabels() {
        #expect(ICCProfileHelpers.colorSpaceLabel(for: .rgb) == "RGB")
        #expect(ICCProfileHelpers.colorSpaceLabel(for: .gray) == "Grayscale")
        #expect(ICCProfileHelpers.colorSpaceLabel(for: .cmyk) == "CMYK")
    }

    @Test("Rendering intent labels")
    func testIntentLabels() {
        #expect(ICCProfileHelpers.renderingIntentLabel(for: .perceptual) == "Perceptual")
        #expect(ICCProfileHelpers.renderingIntentLabel(for: .saturation) == "Saturation")
    }

    @Test("Profile summary")
    func testSummary() {
        let info = ICCProfileInfo(
            size: 1024,
            version: "4.3.0",
            colorSpace: .rgb,
            isDisplayProfile: true
        )
        let summary = ICCProfileHelpers.profileSummary(info)
        #expect(summary.contains("RGB"))
        #expect(summary.contains("v4.3.0"))
        #expect(summary.contains("Display"))
    }
}
