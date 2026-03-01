// CalibrationServiceTests.swift
// DICOMStudioTests
//
// Tests for CalibrationService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("CalibrationService Basic Tests")
struct CalibrationServiceBasicTests {

    @Test("Default calibration is uncalibrated")
    func testDefaultUncalibrated() {
        let service = CalibrationService()
        let cal = service.calibration(for: "1.2.3")
        #expect(!cal.isCalibrated)
    }

    @Test("Set and get calibration")
    func testSetAndGet() {
        let service = CalibrationService()
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        service.setCalibration(cal, for: "1.2.3")

        let retrieved = service.calibration(for: "1.2.3")
        #expect(retrieved.isCalibrated)
        #expect(retrieved.pixelSpacingRow == 0.5)
    }

    @Test("Remove calibration")
    func testRemove() {
        let service = CalibrationService()
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        service.setCalibration(cal, for: "1.2.3")
        service.removeCalibration(for: "1.2.3")
        #expect(!service.calibration(for: "1.2.3").isCalibrated)
    }

    @Test("Clear all calibrations")
    func testClearAll() {
        let service = CalibrationService()
        service.setCalibration(
            CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing),
            for: "1.2.3"
        )
        service.setCalibration(
            CalibrationModel(pixelSpacingRow: 0.3, pixelSpacingColumn: 0.3, source: .pixelSpacing),
            for: "1.2.4"
        )
        service.clearAll()
        #expect(service.calibratedImages().isEmpty)
    }
}

@Suite("CalibrationService Extract Tests")
struct CalibrationServiceExtractTests {

    @Test("Extract from DICOM headers")
    func testExtract() {
        let service = CalibrationService()
        let cal = service.extractCalibration(
            for: "1.2.3",
            pixelSpacing: "0.5\\0.5",
            imagerPixelSpacing: nil,
            nominalScannedPixelSpacing: nil
        )
        #expect(cal.isCalibrated)
        #expect(cal.source == .pixelSpacing)

        // Should be stored
        let retrieved = service.calibration(for: "1.2.3")
        #expect(retrieved.isCalibrated)
    }

    @Test("Extract with fallback to imager pixel spacing")
    func testExtractFallback() {
        let service = CalibrationService()
        let cal = service.extractCalibration(
            for: "1.2.3",
            pixelSpacing: nil,
            imagerPixelSpacing: "0.15\\0.15",
            nominalScannedPixelSpacing: nil
        )
        #expect(cal.source == .imagerPixelSpacing)
    }

    @Test("Extract with no valid headers")
    func testExtractNone() {
        let service = CalibrationService()
        let cal = service.extractCalibration(
            for: "1.2.3",
            pixelSpacing: nil,
            imagerPixelSpacing: nil,
            nominalScannedPixelSpacing: nil
        )
        #expect(!cal.isCalibrated)
    }
}

@Suite("CalibrationService Manual Calibration Tests")
struct CalibrationServiceManualTests {

    @Test("Set manual calibration")
    func testManual() {
        let service = CalibrationService()
        let cal = service.setManualCalibration(
            for: "1.2.3",
            pixelDistance: 200,
            knownDistanceMM: 100
        )
        #expect(cal.isCalibrated)
        #expect(cal.source == .manual)
        #expect(abs(cal.pixelSpacingRow - 0.5) < 0.001)
    }

    @Test("Invalid manual calibration")
    func testInvalidManual() {
        let service = CalibrationService()
        let cal = service.setManualCalibration(
            for: "1.2.3",
            pixelDistance: 0,
            knownDistanceMM: 100
        )
        #expect(!cal.isCalibrated)
    }
}

@Suite("CalibrationService Query Tests")
struct CalibrationServiceQueryTests {

    @Test("Calibrated images list")
    func testCalibratedImages() {
        let service = CalibrationService()
        service.setCalibration(
            CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing),
            for: "1.2.3"
        )
        service.setCalibration(.uncalibrated, for: "1.2.4")
        service.setCalibration(
            CalibrationModel(pixelSpacingRow: 0.3, pixelSpacingColumn: 0.3, source: .manual),
            for: "1.2.5"
        )

        let calibrated = service.calibratedImages()
        #expect(calibrated.count == 2)
        #expect(calibrated.contains("1.2.3"))
        #expect(calibrated.contains("1.2.5"))
        #expect(!calibrated.contains("1.2.4"))
    }
}
