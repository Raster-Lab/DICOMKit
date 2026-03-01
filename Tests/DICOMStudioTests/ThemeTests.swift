// ThemeTests.swift
// DICOMStudioTests
//
// Tests for StudioColors and StudioTypography

import Testing
@testable import DICOMStudio
import Foundation

@Suite("StudioColors Tests")
struct StudioColorsTests {

    @Test("Primary color values are valid")
    func testPrimaryColorValues() {
        #expect(StudioColors.primaryRed >= 0 && StudioColors.primaryRed <= 1)
        #expect(StudioColors.primaryGreen >= 0 && StudioColors.primaryGreen <= 1)
        #expect(StudioColors.primaryBlue >= 0 && StudioColors.primaryBlue <= 1)
    }

    @Test("Background color values are valid")
    func testBackgroundColorValues() {
        #expect(StudioColors.backgroundRed >= 0 && StudioColors.backgroundRed <= 1)
        #expect(StudioColors.backgroundGreen >= 0 && StudioColors.backgroundGreen <= 1)
        #expect(StudioColors.backgroundBlue >= 0 && StudioColors.backgroundBlue <= 1)
    }

    @Test("Status color values are valid")
    func testStatusColorValues() {
        #expect(StudioColors.successRed >= 0 && StudioColors.successRed <= 1)
        #expect(StudioColors.warningRed >= 0 && StudioColors.warningRed <= 1)
        #expect(StudioColors.errorRed >= 0 && StudioColors.errorRed <= 1)
    }

    @Test("Modality color for CT")
    func testModalityColorCT() {
        let (r, g, b) = StudioColors.modalityColor(for: "CT")
        #expect(r == StudioColors.ctRed)
        #expect(g == StudioColors.ctGreen)
        #expect(b == StudioColors.ctBlue)
    }

    @Test("Modality color for MR")
    func testModalityColorMR() {
        let (r, g, b) = StudioColors.modalityColor(for: "MR")
        #expect(r == StudioColors.mrRed)
        #expect(g == StudioColors.mrGreen)
        #expect(b == StudioColors.mrBlue)
    }

    @Test("Modality color for MRI alias")
    func testModalityColorMRI() {
        let (r, g, b) = StudioColors.modalityColor(for: "MRI")
        #expect(r == StudioColors.mrRed)
    }

    @Test("Modality color for US")
    func testModalityColorUS() {
        let (r, g, b) = StudioColors.modalityColor(for: "US")
        #expect(r == StudioColors.usRed)
        #expect(g == StudioColors.usGreen)
        #expect(b == StudioColors.usBlue)
    }

    @Test("Modality color for XR variants")
    func testModalityColorXR() {
        let variants = ["CR", "DX", "XR"]
        for variant in variants {
            let (r, _, _) = StudioColors.modalityColor(for: variant)
            #expect(r == StudioColors.xrRed, "Expected XR color for \(variant)")
        }
    }

    @Test("Modality color for unknown returns primary")
    func testModalityColorUnknown() {
        let (r, g, b) = StudioColors.modalityColor(for: "ZZ")
        #expect(r == StudioColors.primaryRed)
        #expect(g == StudioColors.primaryGreen)
        #expect(b == StudioColors.primaryBlue)
    }

    @Test("Modality color is case insensitive")
    func testModalityColorCaseInsensitive() {
        let (r1, _, _) = StudioColors.modalityColor(for: "ct")
        let (r2, _, _) = StudioColors.modalityColor(for: "CT")
        #expect(r1 == r2)
    }
}

@Suite("StudioTypography Tests")
struct StudioTypographyTests {

    @Test("Typography scale is ordered")
    func testTypographyScale() {
        #expect(StudioTypography.displaySize > StudioTypography.headerSize)
        #expect(StudioTypography.headerSize > StudioTypography.bodySize)
        #expect(StudioTypography.bodySize > StudioTypography.captionSize)
    }

    @Test("Typography values are positive")
    func testTypographyPositive() {
        #expect(StudioTypography.displaySize > 0)
        #expect(StudioTypography.headerSize > 0)
        #expect(StudioTypography.bodySize > 0)
        #expect(StudioTypography.captionSize > 0)
        #expect(StudioTypography.monoSize > 0)
    }
}

@Suite("ConnectionStatus Tests")
struct ConnectionStatusTests {

    @Test("All statuses have system images")
    func testAllStatusesHaveSystemImages() {
        for status in ConnectionStatus.allCases {
            #expect(!status.systemImage.isEmpty, "Missing system image for \(status.rawValue)")
        }
    }

    @Test("All statuses have valid color components")
    func testAllStatusesHaveValidColors() {
        for status in ConnectionStatus.allCases {
            let (r, g, b) = status.colorComponents
            #expect(r >= 0 && r <= 1, "Invalid red for \(status.rawValue)")
            #expect(g >= 0 && g <= 1, "Invalid green for \(status.rawValue)")
            #expect(b >= 0 && b <= 1, "Invalid blue for \(status.rawValue)")
        }
    }

    @Test("Connected status is green")
    func testConnectedColor() {
        let (r, g, b) = ConnectionStatus.connected.colorComponents
        #expect(r == StudioColors.successRed)
        #expect(g == StudioColors.successGreen)
        #expect(b == StudioColors.successBlue)
    }

    @Test("Error status is red")
    func testErrorColor() {
        let (r, _, _) = ConnectionStatus.error.colorComponents
        #expect(r == StudioColors.errorRed)
    }

    @Test("All status raw values")
    func testStatusRawValues() {
        #expect(ConnectionStatus.connected.rawValue == "Connected")
        #expect(ConnectionStatus.disconnected.rawValue == "Disconnected")
        #expect(ConnectionStatus.connecting.rawValue == "Connecting")
        #expect(ConnectionStatus.error.rawValue == "Error")
        #expect(ConnectionStatus.transferring.rawValue == "Transferring")
        #expect(ConnectionStatus.idle.rawValue == "Idle")
    }
}
