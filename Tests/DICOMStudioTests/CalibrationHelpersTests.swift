// CalibrationHelpersTests.swift
// DICOMStudioTests
//
// Tests for CalibrationHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("CalibrationHelpers Parsing Tests")
struct CalibrationParsingTests {

    @Test("Parse valid pixel spacing")
    func testValidPixelSpacing() {
        let result = CalibrationHelpers.parsePixelSpacing("0.5\\0.5")
        #expect(result != nil)
        #expect(result?.row == 0.5)
        #expect(result?.column == 0.5)
    }

    @Test("Parse anisotropic pixel spacing")
    func testAnisotropicSpacing() {
        let result = CalibrationHelpers.parsePixelSpacing("0.4\\0.6")
        #expect(result != nil)
        #expect(result?.row == 0.4)
        #expect(result?.column == 0.6)
    }

    @Test("Parse pixel spacing with whitespace")
    func testWhitespace() {
        let result = CalibrationHelpers.parsePixelSpacing(" 0.5 \\ 0.5 ")
        #expect(result != nil)
        #expect(result?.row == 0.5)
    }

    @Test("Parse invalid pixel spacing - empty")
    func testEmptyString() {
        #expect(CalibrationHelpers.parsePixelSpacing("") == nil)
    }

    @Test("Parse invalid pixel spacing - single value")
    func testSingleValue() {
        #expect(CalibrationHelpers.parsePixelSpacing("0.5") == nil)
    }

    @Test("Parse invalid pixel spacing - non-numeric")
    func testNonNumeric() {
        #expect(CalibrationHelpers.parsePixelSpacing("abc\\def") == nil)
    }

    @Test("Parse invalid pixel spacing - zero values")
    func testZeroValues() {
        #expect(CalibrationHelpers.parsePixelSpacing("0\\0") == nil)
    }

    @Test("Parse invalid pixel spacing - negative")
    func testNegativeValues() {
        #expect(CalibrationHelpers.parsePixelSpacing("-0.5\\0.5") == nil)
    }
}

@Suite("CalibrationHelpers Calibration Creation Tests")
struct CalibrationCreationTests {

    @Test("Calibration from Pixel Spacing")
    func testFromPixelSpacing() {
        let cal = CalibrationHelpers.calibrationFromPixelSpacing("0.5\\0.5")
        #expect(cal.isCalibrated)
        #expect(cal.source == .pixelSpacing)
        #expect(cal.pixelSpacingRow == 0.5)
        #expect(cal.pixelSpacingColumn == 0.5)
    }

    @Test("Calibration from Imager Pixel Spacing")
    func testFromImagerPixelSpacing() {
        let cal = CalibrationHelpers.calibrationFromImagerPixelSpacing("0.15\\0.15")
        #expect(cal.isCalibrated)
        #expect(cal.source == .imagerPixelSpacing)
    }

    @Test("Calibration from Nominal Scanned Pixel Spacing")
    func testFromNominalScanned() {
        let cal = CalibrationHelpers.calibrationFromNominalScannedPixelSpacing("0.3\\0.3")
        #expect(cal.isCalibrated)
        #expect(cal.source == .nominalScannedPixelSpacing)
    }

    @Test("Invalid string returns uncalibrated")
    func testInvalidString() {
        let cal = CalibrationHelpers.calibrationFromPixelSpacing("invalid")
        #expect(!cal.isCalibrated)
        #expect(cal.source == .unknown)
    }
}

@Suite("CalibrationHelpers Manual Calibration Tests")
struct CalibrationManualTests {

    @Test("Manual calibration from known distance")
    func testManualCalibration() {
        let cal = CalibrationHelpers.calibrationFromManual(pixelDistance: 200, knownDistanceMM: 100)
        #expect(cal.isCalibrated)
        #expect(cal.source == .manual)
        #expect(abs(cal.pixelSpacingRow - 0.5) < 0.001)
        #expect(abs(cal.pixelSpacingColumn - 0.5) < 0.001)
    }

    @Test("Manual calibration with zero pixel distance")
    func testZeroPixelDistance() {
        let cal = CalibrationHelpers.calibrationFromManual(pixelDistance: 0, knownDistanceMM: 100)
        #expect(!cal.isCalibrated)
    }

    @Test("Manual calibration with zero known distance")
    func testZeroKnownDistance() {
        let cal = CalibrationHelpers.calibrationFromManual(pixelDistance: 200, knownDistanceMM: 0)
        #expect(!cal.isCalibrated)
    }

    @Test("Manual calibration with negative values")
    func testNegativeValues() {
        let cal = CalibrationHelpers.calibrationFromManual(pixelDistance: -100, knownDistanceMM: 50)
        #expect(!cal.isCalibrated)
    }
}

@Suite("CalibrationHelpers Resolution Tests")
struct CalibrationResolutionTests {

    @Test("Priority: Pixel Spacing first")
    func testPriorityPixelSpacing() {
        let cal = CalibrationHelpers.resolveCalibration(
            pixelSpacing: "0.5\\0.5",
            imagerPixelSpacing: "0.15\\0.15",
            nominalScannedPixelSpacing: "0.3\\0.3"
        )
        #expect(cal.source == .pixelSpacing)
    }

    @Test("Fallback to Imager Pixel Spacing")
    func testFallbackImager() {
        let cal = CalibrationHelpers.resolveCalibration(
            pixelSpacing: nil,
            imagerPixelSpacing: "0.15\\0.15",
            nominalScannedPixelSpacing: "0.3\\0.3"
        )
        #expect(cal.source == .imagerPixelSpacing)
    }

    @Test("Fallback to Nominal Scanned")
    func testFallbackNominal() {
        let cal = CalibrationHelpers.resolveCalibration(
            pixelSpacing: nil,
            imagerPixelSpacing: nil,
            nominalScannedPixelSpacing: "0.3\\0.3"
        )
        #expect(cal.source == .nominalScannedPixelSpacing)
    }

    @Test("No calibration available")
    func testNone() {
        let cal = CalibrationHelpers.resolveCalibration(
            pixelSpacing: nil,
            imagerPixelSpacing: nil,
            nominalScannedPixelSpacing: nil
        )
        #expect(!cal.isCalibrated)
    }

    @Test("Invalid Pixel Spacing falls through")
    func testInvalidFallthrough() {
        let cal = CalibrationHelpers.resolveCalibration(
            pixelSpacing: "invalid",
            imagerPixelSpacing: "0.15\\0.15",
            nominalScannedPixelSpacing: nil
        )
        #expect(cal.source == .imagerPixelSpacing)
    }
}

@Suite("CalibrationHelpers Magnification Tests")
struct CalibrationMagnificationTests {

    @Test("Apply magnification correction")
    func testMagnification() {
        let cal = CalibrationModel(pixelSpacingRow: 0.3, pixelSpacingColumn: 0.3, source: .imagerPixelSpacing)
        let corrected = CalibrationHelpers.applyMagnificationCorrection(calibration: cal, magnificationFactor: 1.5)
        #expect(abs(corrected.pixelSpacingRow - 0.2) < 0.001)
        #expect(abs(corrected.pixelSpacingColumn - 0.2) < 0.001)
    }

    @Test("No magnification factor")
    func testNoMagnification() {
        let cal = CalibrationModel(pixelSpacingRow: 0.3, pixelSpacingColumn: 0.3, source: .imagerPixelSpacing)
        let corrected = CalibrationHelpers.applyMagnificationCorrection(calibration: cal, magnificationFactor: 0)
        #expect(corrected.pixelSpacingRow == 0.3)
    }

    @Test("Uncalibrated returns same")
    func testUncalibratedMagnification() {
        let corrected = CalibrationHelpers.applyMagnificationCorrection(calibration: .uncalibrated, magnificationFactor: 1.5)
        #expect(!corrected.isCalibrated)
    }
}

@Suite("CalibrationHelpers Display Tests")
struct CalibrationDisplayTests {

    @Test("Format isotropic calibration")
    func testFormatIsotropic() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let text = CalibrationHelpers.formatCalibration(cal)
        #expect(text.contains("0.5000"))
        #expect(text.contains("Pixel Spacing"))
    }

    @Test("Format anisotropic calibration")
    func testFormatAnisotropic() {
        let cal = CalibrationModel(pixelSpacingRow: 0.4, pixelSpacingColumn: 0.6, source: .pixelSpacing)
        let text = CalibrationHelpers.formatCalibration(cal)
        #expect(text.contains("0.4000"))
        #expect(text.contains("0.6000"))
    }

    @Test("Format uncalibrated")
    func testFormatUncalibrated() {
        let text = CalibrationHelpers.formatCalibration(.uncalibrated)
        #expect(text == "Uncalibrated")
    }

    @Test("Calibration source labels")
    func testSourceLabels() {
        for source in CalibrationSource.allCases {
            #expect(!CalibrationHelpers.calibrationSourceLabel(source).isEmpty)
        }
    }

    @Test("Calibration indicator - calibrated")
    func testIndicatorCalibrated() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let indicator = CalibrationHelpers.calibrationIndicator(cal)
        #expect(indicator.contains("✓"))
    }

    @Test("Calibration indicator - uncalibrated")
    func testIndicatorUncalibrated() {
        let indicator = CalibrationHelpers.calibrationIndicator(.uncalibrated)
        #expect(indicator.contains("⚠️"))
    }

    @Test("Calibration indicator - manual")
    func testIndicatorManual() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .manual)
        let indicator = CalibrationHelpers.calibrationIndicator(cal)
        #expect(indicator.contains("Manual"))
    }
}
