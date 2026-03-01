// MeasurementHelpersTests.swift
// DICOMStudioTests
//
// Tests for MeasurementHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MeasurementHelpers Length Tests")
struct MeasurementLengthTests {

    @Test("Length between same points is zero")
    func testZeroLength() {
        let p = AnnotationPoint(x: 100, y: 200)
        #expect(MeasurementHelpers.lengthPixels(from: p, to: p) == 0)
    }

    @Test("Horizontal distance")
    func testHorizontalDistance() {
        let a = AnnotationPoint(x: 0, y: 0)
        let b = AnnotationPoint(x: 100, y: 0)
        #expect(MeasurementHelpers.lengthPixels(from: a, to: b) == 100)
    }

    @Test("Vertical distance")
    func testVerticalDistance() {
        let a = AnnotationPoint(x: 0, y: 0)
        let b = AnnotationPoint(x: 0, y: 200)
        #expect(MeasurementHelpers.lengthPixels(from: a, to: b) == 200)
    }

    @Test("Diagonal distance 3-4-5")
    func testDiagonalDistance() {
        let a = AnnotationPoint(x: 0, y: 0)
        let b = AnnotationPoint(x: 3, y: 4)
        #expect(abs(MeasurementHelpers.lengthPixels(from: a, to: b) - 5) < 0.001)
    }

    @Test("Length with isotropic calibration")
    func testIsotropicCalibration() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let result = MeasurementHelpers.measureLength(
            from: AnnotationPoint(x: 0, y: 0),
            to: AnnotationPoint(x: 100, y: 0),
            calibration: cal
        )
        #expect(result.lengthPixels == 100)
        #expect(abs((result.lengthMM ?? 0) - 50.0) < 0.001)
    }

    @Test("Length with anisotropic calibration")
    func testAnisotropicCalibration() {
        let cal = CalibrationModel(pixelSpacingRow: 1.0, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        // Horizontal: 100 pixels * 0.5 mm/px = 50 mm
        let result = MeasurementHelpers.measureLength(
            from: AnnotationPoint(x: 0, y: 0),
            to: AnnotationPoint(x: 100, y: 0),
            calibration: cal
        )
        #expect(abs((result.lengthMM ?? 0) - 50.0) < 0.001)
    }

    @Test("Length without calibration returns nil mm")
    func testUncalibrated() {
        let result = MeasurementHelpers.measureLength(
            from: AnnotationPoint(x: 0, y: 0),
            to: AnnotationPoint(x: 100, y: 0),
            calibration: .uncalibrated
        )
        #expect(result.lengthMM == nil)
        #expect(result.lengthPixels == 100)
    }
}

@Suite("MeasurementHelpers Angle Tests")
struct MeasurementAngleTests {

    @Test("Right angle (90°)")
    func testRightAngle() {
        let result = MeasurementHelpers.measureAngle(
            vertex: AnnotationPoint(x: 0, y: 0),
            point1: AnnotationPoint(x: 100, y: 0),
            point2: AnnotationPoint(x: 0, y: 100)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 0) - 90) < 0.001)
    }

    @Test("Straight line (180°)")
    func testStraightLine() {
        let result = MeasurementHelpers.measureAngle(
            vertex: AnnotationPoint(x: 50, y: 0),
            point1: AnnotationPoint(x: 0, y: 0),
            point2: AnnotationPoint(x: 100, y: 0)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 0) - 180) < 0.001)
    }

    @Test("Acute angle (45°)")
    func testAcuteAngle() {
        let result = MeasurementHelpers.measureAngle(
            vertex: AnnotationPoint(x: 0, y: 0),
            point1: AnnotationPoint(x: 100, y: 0),
            point2: AnnotationPoint(x: 100, y: 100)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 0) - 45) < 0.001)
    }

    @Test("Degenerate angle returns nil")
    func testDegenerate() {
        let p = AnnotationPoint(x: 0, y: 0)
        let result = MeasurementHelpers.measureAngle(vertex: p, point1: p, point2: p)
        #expect(result == nil)
    }

    @Test("Zero angle (0°)")
    func testZeroAngle() {
        let result = MeasurementHelpers.measureAngle(
            vertex: AnnotationPoint(x: 0, y: 0),
            point1: AnnotationPoint(x: 100, y: 0),
            point2: AnnotationPoint(x: 200, y: 0)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 999) - 0) < 0.001)
    }
}

@Suite("MeasurementHelpers Cobb Angle Tests")
struct MeasurementCobbAngleTests {

    @Test("Parallel lines (0°)")
    func testParallelLines() {
        let result = MeasurementHelpers.measureCobbAngle(
            line1Start: AnnotationPoint(x: 0, y: 0),
            line1End: AnnotationPoint(x: 100, y: 0),
            line2Start: AnnotationPoint(x: 0, y: 100),
            line2End: AnnotationPoint(x: 100, y: 100)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 999) - 0) < 0.001)
    }

    @Test("Perpendicular lines (90°)")
    func testPerpendicularLines() {
        let result = MeasurementHelpers.measureCobbAngle(
            line1Start: AnnotationPoint(x: 0, y: 0),
            line1End: AnnotationPoint(x: 100, y: 0),
            line2Start: AnnotationPoint(x: 50, y: 50),
            line2End: AnnotationPoint(x: 50, y: 150)
        )
        #expect(result != nil)
        #expect(abs((result?.angleDegrees ?? 0) - 90) < 0.001)
    }

    @Test("Cobb angle is always acute (≤90°)")
    func testAcuteResult() {
        // Lines at 120° should return 60° (acute)
        let angle = MeasurementHelpers.cobbAngle(
            line1Start: AnnotationPoint(x: 0, y: 0),
            line1End: AnnotationPoint(x: 100, y: 0),
            line2Start: AnnotationPoint(x: 0, y: 0),
            line2End: AnnotationPoint(x: -50, y: 86.6)
        )
        #expect(angle <= 90)
        #expect(angle >= 0)
    }

    @Test("Degenerate lines return nil")
    func testDegenerate() {
        let p = AnnotationPoint(x: 0, y: 0)
        let result = MeasurementHelpers.measureCobbAngle(
            line1Start: p, line1End: p,
            line2Start: p, line2End: p
        )
        #expect(result == nil)
    }
}

@Suite("MeasurementHelpers Bidirectional Tests")
struct MeasurementBidirectionalTests {

    @Test("Bidirectional measurement uncalibrated")
    func testUncalibrated() {
        let result = MeasurementHelpers.measureBidirectional(
            longStart: AnnotationPoint(x: 0, y: 100),
            longEnd: AnnotationPoint(x: 200, y: 100),
            shortStart: AnnotationPoint(x: 100, y: 50),
            shortEnd: AnnotationPoint(x: 100, y: 150),
            calibration: .uncalibrated
        )
        #expect(result.longAxisPixels == 200)
        #expect(result.shortAxisPixels == 100)
        #expect(result.longAxisMM == nil)
        #expect(result.shortAxisMM == nil)
    }

    @Test("Bidirectional measurement calibrated")
    func testCalibrated() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let result = MeasurementHelpers.measureBidirectional(
            longStart: AnnotationPoint(x: 0, y: 100),
            longEnd: AnnotationPoint(x: 200, y: 100),
            shortStart: AnnotationPoint(x: 100, y: 0),
            shortEnd: AnnotationPoint(x: 100, y: 100),
            calibration: cal
        )
        #expect(result.longAxisPixels == 200)
        #expect(abs((result.longAxisMM ?? 0) - 100) < 0.001)
        #expect(abs((result.shortAxisMM ?? 0) - 50) < 0.001)
    }
}

@Suite("MeasurementHelpers Unit Conversion Tests")
struct MeasurementUnitConversionTests {

    @Test("MM to MM")
    func testMMtoMM() {
        #expect(MeasurementHelpers.convert(mm: 100, to: .millimeters) == 100)
    }

    @Test("MM to CM")
    func testMMtoCM() {
        #expect(MeasurementHelpers.convert(mm: 100, to: .centimeters) == 10)
    }

    @Test("MM to inches")
    func testMMtoInches() {
        #expect(abs(MeasurementHelpers.convert(mm: 25.4, to: .inches) - 1.0) < 0.001)
    }
}

@Suite("MeasurementHelpers Formatting Tests")
struct MeasurementFormattingTests {

    @Test("Format length with mm")
    func testFormatLengthMM() {
        let text = MeasurementHelpers.formatLength(pixels: 100, mm: 50.0, unit: .millimeters)
        #expect(text.contains("50.0"))
        #expect(text.contains("mm"))
    }

    @Test("Format length with cm")
    func testFormatLengthCM() {
        let text = MeasurementHelpers.formatLength(pixels: 100, mm: 50.0, unit: .centimeters)
        #expect(text.contains("5.0"))
        #expect(text.contains("cm"))
    }

    @Test("Format length uncalibrated")
    func testFormatLengthPixels() {
        let text = MeasurementHelpers.formatLength(pixels: 100, mm: nil)
        #expect(text.contains("100.0"))
        #expect(text.contains("px"))
    }

    @Test("Format angle")
    func testFormatAngle() {
        let text = MeasurementHelpers.formatAngle(45.5)
        #expect(text.contains("45.5"))
        #expect(text.contains("°"))
    }
}

@Suite("MeasurementHelpers Tool Info Tests")
struct MeasurementToolInfoTests {

    @Test("Required points for fixed-point tools")
    func testRequiredPoints() {
        #expect(MeasurementHelpers.requiredPoints(for: .length) == 2)
        #expect(MeasurementHelpers.requiredPoints(for: .angle) == 3)
        #expect(MeasurementHelpers.requiredPoints(for: .cobbAngle) == 4)
        #expect(MeasurementHelpers.requiredPoints(for: .bidirectional) == 4)
        #expect(MeasurementHelpers.requiredPoints(for: .marker) == 1)
        #expect(MeasurementHelpers.requiredPoints(for: .arrowAnnotation) == 2)
        #expect(MeasurementHelpers.requiredPoints(for: .circularROI) == 2)
        #expect(MeasurementHelpers.requiredPoints(for: .ellipticalROI) == 4)
        #expect(MeasurementHelpers.requiredPoints(for: .rectangularROI) == 2)
    }

    @Test("Variable-point tools return nil")
    func testVariablePoints() {
        #expect(MeasurementHelpers.requiredPoints(for: .freehandROI) == nil)
        #expect(MeasurementHelpers.requiredPoints(for: .polygonalROI) == nil)
    }

    @Test("Tool labels are non-empty")
    func testToolLabels() {
        for tool in MeasurementToolType.allCases {
            #expect(!MeasurementHelpers.toolLabel(for: tool).isEmpty)
        }
    }

    @Test("Tool system images are non-empty")
    func testToolSystemImages() {
        for tool in MeasurementToolType.allCases {
            #expect(!MeasurementHelpers.toolSystemImage(for: tool).isEmpty)
        }
    }
}

@Suite("MeasurementHelpers Midpoint Tests")
struct MeasurementMidpointTests {

    @Test("Midpoint of horizontal line")
    func testHorizontalMidpoint() {
        let mid = MeasurementHelpers.midpoint(
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0)
        )
        #expect(mid.x == 50)
        #expect(mid.y == 0)
    }

    @Test("Midpoint of diagonal line")
    func testDiagonalMidpoint() {
        let mid = MeasurementHelpers.midpoint(
            AnnotationPoint(x: 10, y: 20),
            AnnotationPoint(x: 30, y: 40)
        )
        #expect(mid.x == 20)
        #expect(mid.y == 30)
    }
}

@Suite("MeasurementHelpers Physical Distance Tests")
struct MeasurementPhysicalDistanceTests {

    @Test("Physical distance with isotropic spacing")
    func testIsotropicPhysical() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let dist = MeasurementHelpers.physicalDistance(pixelDistance: 100, calibration: cal, dx: 100, dy: 0)
        #expect(abs(dist - 50.0) < 0.001)
    }

    @Test("Physical distance uncalibrated returns pixel distance")
    func testUncalibratedPhysical() {
        let dist = MeasurementHelpers.physicalDistance(pixelDistance: 100, calibration: .uncalibrated, dx: 100, dy: 0)
        #expect(dist == 100)
    }
}
