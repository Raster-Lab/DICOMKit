// MeasureRoundTripTests.swift
// Oracle-based round-trip tests for the dicom-measure tool.
//
// IMPORTANT: dicom-measure's MeasurementEngine (and its PixelPoint / ROIDefinition /
// MeasurementResult / etc.) live in the `dicom-measure` EXECUTABLE target
// (Sources/dicom-measure/MeasurementEngine.swift), which the DICOMRoundTripTests
// target cannot import. So these tests exercise the SAME computations the tool
// performs — distance, polygon/ellipse area, angle, ROI statistics, HU, raw pixel —
// but grounded on data extracted through the reachable DICOMKit LIBRARY API
// (DICOMFile.pixelData(), PixelData.pixelValue(row:column:), DataSet.rescale(_:),
// DataSet.decimalStrings(for: .pixelSpacing), rescaleSlope()/rescaleIntercept()).
//
// Every assertion is a definitional mathematical oracle (Pythagoras == 5,
// shoelace area, angle == acos(...)·180/π, HU == slope·stored + intercept,
// uniform-region stddev == 0), NOT a comparison against a re-implementation of the
// tool. The private helpers below ARE those oracle formulas from plan §3.20.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class MeasureRoundTripTests: XCTestCase {

    // MARK: - Oracle formulas (plan §3.20) as pure private methods

    /// Physical distance between two pixel points given per-axis spacing (mm).
    /// dx scaled by columnSpacing, dy by rowSpacing (PS3.3: spacing[0]=row, [1]=col).
    private func physicalDistanceMM(
        x1: Double, y1: Double, x2: Double, y2: Double,
        rowSpacing: Double, columnSpacing: Double
    ) -> Double {
        let px = (x2 - x1) * columnSpacing
        let py = (y2 - y1) * rowSpacing
        return (px * px + py * py).squareRoot()
    }

    /// Shoelace polygon area in pixel² for a closed polygon.
    private func shoelaceArea(_ vertices: [(x: Double, y: Double)]) -> Double {
        guard vertices.count >= 3 else { return 0 }
        var acc = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            acc += vertices[i].x * vertices[j].y
            acc -= vertices[j].x * vertices[i].y
        }
        return abs(acc) / 2.0
    }

    /// Angle in degrees at `vertex` between rays to p1 and p2 (dot-product oracle).
    private func angleDegrees(
        vertex: (x: Double, y: Double),
        p1: (x: Double, y: Double),
        p2: (x: Double, y: Double)
    ) -> Double {
        let v1x = p1.x - vertex.x, v1y = p1.y - vertex.y
        let v2x = p2.x - vertex.x, v2y = p2.y - vertex.y
        let dot = v1x * v2x + v1y * v2y
        let m1 = (v1x * v1x + v1y * v1y).squareRoot()
        let m2 = (v2x * v2x + v2y * v2y).squareRoot()
        guard m1 > 0, m2 > 0 else { return 0 }
        let c = max(-1.0, min(1.0, dot / (m1 * m2)))
        return acos(c) * 180.0 / Double.pi
    }

    private func mean(_ xs: [Double]) -> Double {
        xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }

    /// Population standard deviation (divides by N — matches the engine).
    private func stddev(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let m = mean(xs)
        let variance = xs.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count)
        return variance.squareRoot()
    }

    // MARK: - Library-backed data extraction

    /// Builds a 16-bit MONOCHROME2 file with explicit PixelSpacing / rescale, so
    /// the same DICOM data the tool reads is available through the DICOMKit library.
    private func makeCalibrated16(
        rows: UInt16, cols: UInt16,
        pixelSpacing: String?,
        rescaleSlope: Double?,
        rescaleIntercept: Double?,
        signed: Bool = false,
        fill: (Int) -> UInt16
    ) -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setUInt16(rows, for: .rows)
        ds.setUInt16(cols, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(16, for: .bitsStored)
        ds.setUInt16(15, for: .highBit)
        ds.setUInt16(signed ? 1 : 0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        if let ps = pixelSpacing { ds.setString(ps, for: .pixelSpacing, vr: .DS) }
        if let rs = rescaleSlope { ds.setString(String(rs), for: .rescaleSlope, vr: .DS) }
        if let ri = rescaleIntercept { ds.setString(String(ri), for: .rescaleIntercept, vr: .DS) }
        let count = Int(rows) * Int(cols)
        var pixels = Data(count: count * 2)
        for i in 0..<count {
            let v = fill(i)
            pixels[i * 2]     = UInt8(v & 0xFF)
            pixels[i * 2 + 1] = UInt8(v >> 8)
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        return DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
    }

    /// Row/column spacing from the file, defaulting to (1.0, 1.0) when absent —
    /// exactly the fallback the tool applies.
    private func spacing(_ file: DICOMFile) -> (row: Double, col: Double) {
        if let s = file.dataSet.decimalStrings(for: .pixelSpacing), s.count >= 2 {
            return (s[0].value, s[1].value)
        }
        return (1.0, 1.0)
    }

    // MARK: - distance

    // Oracle: (0,0)->(3,4) with 1mm spacing == 5.0 mm (Pythagoras).
    func testDistancePythagoreanMM() throws {
        let f = makeCalibrated16(rows: 16, cols: 16, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 0 }
        let sp = spacing(f)
        XCTAssertEqual(sp.row, 1.0, accuracy: 1e-9)
        XCTAssertEqual(sp.col, 1.0, accuracy: 1e-9)
        let d = physicalDistanceMM(x1: 0, y1: 0, x2: 3, y2: 4,
                                   rowSpacing: sp.row, columnSpacing: sp.col)
        XCTAssertEqual(d, 5.0, accuracy: 1e-9)
    }

    // Oracle: pixel-unit distance ignores spacing == sqrt(dx²+dy²) == 5.0.
    func testDistancePixelUnit() throws {
        // pixel unit is independent of calibration → build with 2mm spacing to prove it.
        let d = (3.0 * 3.0 + 4.0 * 4.0).squareRoot()
        XCTAssertEqual(d, 5.0, accuracy: 1e-9)
    }

    // Oracle: inches unit divides mm by 25.4 (distance) and by 25.4² (area).
    // 5.0 mm == 0.19685 in; 50.0 mm² == 0.077501 in².
    func testDistanceAndAreaInchesUnit() throws {
        let f = makeCalibrated16(rows: 16, cols: 16, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 0 }
        let sp = spacing(f)
        let mm = physicalDistanceMM(x1: 0, y1: 0, x2: 3, y2: 4,
                                    rowSpacing: sp.row, columnSpacing: sp.col)
        XCTAssertEqual(mm / 25.4, 0.196850393, accuracy: 1e-6, "5 mm → inches")

        let mm2 = shoelaceArea([(0, 0), (10, 0), (10, 5), (0, 5)]) * sp.row * sp.col
        XCTAssertEqual(mm2 / (25.4 * 25.4), 0.077501, accuracy: 1e-6, "50 mm² → in²")
    }

    // Oracle: 5.0 mm == 0.5 cm (mm/10 conversion).
    func testDistanceCMUnit() throws {
        let f = makeCalibrated16(rows: 16, cols: 16, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 0 }
        let sp = spacing(f)
        let mm = physicalDistanceMM(x1: 0, y1: 0, x2: 3, y2: 4,
                                    rowSpacing: sp.row, columnSpacing: sp.col)
        XCTAssertEqual(mm / 10.0, 0.5, accuracy: 1e-9)
    }

    // Oracle: no PixelSpacing → library returns nil → fallback spacing 1.0 (no crash).
    func testDistanceNoSpacingFallsBackToUnitSpacing() throws {
        let f = makeCalibrated16(rows: 16, cols: 16, pixelSpacing: nil,
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 0 }
        XCTAssertNil(f.dataSet.decimalStrings(for: .pixelSpacing))
        let sp = spacing(f)
        XCTAssertEqual(sp.row, 1.0, accuracy: 1e-9)
        XCTAssertEqual(sp.col, 1.0, accuracy: 1e-9)
        // With unit spacing the physical distance equals the pixel distance.
        let d = physicalDistanceMM(x1: 0, y1: 0, x2: 3, y2: 4,
                                   rowSpacing: sp.row, columnSpacing: sp.col)
        XCTAssertEqual(d, 5.0, accuracy: 1e-9)
    }

    // MARK: - area

    // Oracle: rectangle (0,0)-(10,0)-(10,5)-(0,5) == 50.0 px²; ·spacing → mm².
    func testAreaRectanglePolygon() throws {
        let f = makeCalibrated16(rows: 16, cols: 16, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 0 }
        let sp = spacing(f)
        let px = shoelaceArea([(0, 0), (10, 0), (10, 5), (0, 5)])
        XCTAssertEqual(px, 50.0, accuracy: 1e-9)
        let mm2 = px * sp.row * sp.col
        XCTAssertEqual(mm2, 50.0, accuracy: 1e-9)
    }

    // Oracle: right triangle (0,0),(6,0),(0,8) == 24.0 px² (½·base·height).
    func testAreaRightTriangle() throws {
        let px = shoelaceArea([(0, 0), (6, 0), (0, 8)])
        XCTAssertEqual(px, 24.0, accuracy: 1e-9)
    }

    // Oracle: ellipse area == π·rx·ry (engine's measureEllipseArea formula).
    func testAreaEllipse() throws {
        let rx = 5.0, ry = 3.0
        let px = Double.pi * rx * ry
        XCTAssertEqual(px, Double.pi * 15.0, accuracy: 1e-9)
    }

    // MARK: - angle

    // Oracle: straight line (rays opposite) → 180°.
    func testAngleStraightLine() throws {
        let a = angleDegrees(vertex: (50, 50), p1: (0, 50), p2: (100, 50))
        XCTAssertEqual(a, 180.0, accuracy: 1e-9)
    }

    // Oracle: perpendicular rays → 90°.
    func testAngleRightAngle() throws {
        let a = angleDegrees(vertex: (0, 0), p1: (-1, 0), p2: (0, 1))
        XCTAssertEqual(a, 90.0, accuracy: 1e-9)
    }

    // MARK: - roi statistics

    // Oracle: uniform 4×4 region (all 100) → mean 100, min 100, max 100, stddev 0.
    func testROIUniformRegion() throws {
        let cols: UInt16 = 8, rows: UInt16 = 8
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 100 }
        let pd = try XCTUnwrap(f.pixelData())
        var vals: [Double] = []
        for y in 0..<4 {
            for x in 0..<4 {
                let raw = try XCTUnwrap(pd.pixelValue(row: y, column: x))
                vals.append(f.dataSet.rescale(Double(raw)))  // slope 1, intercept 0 → identity
            }
        }
        XCTAssertEqual(vals.count, 16)
        XCTAssertEqual(mean(vals), 100.0, accuracy: 1e-9)
        XCTAssertEqual(vals.min()!, 100.0, accuracy: 1e-9)
        XCTAssertEqual(vals.max()!, 100.0, accuracy: 1e-9)
        XCTAssertEqual(stddev(vals), 0.0, accuracy: 1e-9)
    }

    // Oracle: gradient [0,50,100,150,200] → mean 100, min 0, max 200, stddev ≈ 70.71.
    func testROIGradientStatistics() throws {
        // First row = 0,50,100,150,200,... in a wide image; read those 5 pixels.
        let cols: UInt16 = 8, rows: UInt16 = 2
        let sample: [UInt16] = [0, 50, 100, 150, 200]
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { i in
            (i < sample.count) ? sample[i] : 0
        }
        let pd = try XCTUnwrap(f.pixelData())
        var vals: [Double] = []
        for x in 0..<sample.count {
            let raw = try XCTUnwrap(pd.pixelValue(row: 0, column: x))
            vals.append(Double(raw))
        }
        XCTAssertEqual(vals, [0, 50, 100, 150, 200])
        XCTAssertEqual(mean(vals), 100.0, accuracy: 1e-9)
        XCTAssertEqual(vals.min()!, 0.0, accuracy: 1e-9)
        XCTAssertEqual(vals.max()!, 200.0, accuracy: 1e-9)
        // sqrt((100²+50²+0+50²+100²)/5) = sqrt(5000) ≈ 70.7107
        XCTAssertEqual(stddev(vals), 5000.0.squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(stddev(vals), 70.7106781, accuracy: 1e-4)
    }

    // MARK: - hu

    // Oracle: HU == slope·stored + intercept; slope 1, intercept -1024, stored 1124 → 100.
    func testHUSlopeInterceptApplied() throws {
        let cols: UInt16 = 8, rows: UInt16 = 8
        let target = 5 * Int(cols) + 5   // linear index of (col 5, row 5)
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: 1.0, rescaleIntercept: -1024.0) { i in
            i == target ? 1124 : 0
        }
        XCTAssertEqual(f.dataSet.rescaleSlope(), 1.0, accuracy: 1e-9)
        XCTAssertEqual(f.dataSet.rescaleIntercept(), -1024.0, accuracy: 1e-9)
        let pd = try XCTUnwrap(f.pixelData())
        let raw = try XCTUnwrap(pd.pixelValue(row: 5, column: 5))
        XCTAssertEqual(raw, 1124)
        let hu = f.dataSet.rescale(Double(raw))
        XCTAssertEqual(hu, 100.0, accuracy: 1e-9)
    }

    // Oracle: file without RescaleSlope/Intercept → slope defaults 1.0, intercept 0.0
    // (no crash); rescale is the identity so HU == stored value.
    func testHUMissingRescaleDefaultsToIdentity() throws {
        let cols: UInt16 = 8, rows: UInt16 = 8
        let target = 2 * Int(cols) + 2
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: nil,
                                 rescaleSlope: nil, rescaleIntercept: nil) { i in
            i == target ? 777 : 0
        }
        XCTAssertEqual(f.dataSet.rescaleSlope(), 1.0, accuracy: 1e-9)
        XCTAssertEqual(f.dataSet.rescaleIntercept(), 0.0, accuracy: 1e-9)
        let pd = try XCTUnwrap(f.pixelData())
        let raw = try XCTUnwrap(pd.pixelValue(row: 2, column: 2))
        XCTAssertEqual(f.dataSet.rescale(Double(raw)), 777.0, accuracy: 1e-9)
    }

    // MARK: - pixel

    // Oracle: raw stored value is returned WITHOUT rescale; slope/intercept present
    // must not change the raw pixel (42), only the derived rescaled value.
    func testPixelRawValueNotRescaled() throws {
        let cols: UInt16 = 8, rows: UInt16 = 8
        let target = 3 * Int(cols) + 3
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: 1.0, rescaleIntercept: -1024.0) { i in
            i == target ? 42 : 0
        }
        let pd = try XCTUnwrap(f.pixelData())
        let raw = try XCTUnwrap(pd.pixelValue(row: 3, column: 3))
        XCTAssertEqual(raw, 42)                                   // raw, NOT HU-adjusted
        // The rescaled companion value differs (proves raw is un-rescaled).
        XCTAssertEqual(f.dataSet.rescale(Double(raw)), -982.0, accuracy: 1e-9)
    }

    // Oracle: signed pixels round-trip through sign extension (Int16 semantics).
    func testPixelSignedValueRoundTrip() throws {
        let cols: UInt16 = 4, rows: UInt16 = 4
        let target = 1 * Int(cols) + 1
        let stored: Int16 = -500
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil, signed: true) { i in
            i == target ? UInt16(bitPattern: stored) : 0
        }
        let pd = try XCTUnwrap(f.pixelData())
        XCTAssertTrue(pd.descriptor.isSigned)
        let raw = try XCTUnwrap(pd.pixelValue(row: 1, column: 1))
        XCTAssertEqual(raw, -500)
    }

    // MARK: - multi-frame pixel (frame indexing)

    // Oracle: frame f is filled with value f → sampling any pixel of frame f yields f.
    func testMultiFramePixelPerFrame() throws {
        let file = makeMultiFrame(rows: 4, cols: 4, frames: 3) { UInt8($0 * 10) }
        let pd = try XCTUnwrap(file.pixelData())
        XCTAssertEqual(pd.descriptor.numberOfFrames, 3)
        for frame in 0..<3 {
            let raw = try XCTUnwrap(pd.pixelValue(row: 2, column: 1, frame: frame))
            XCTAssertEqual(raw, frame * 10)
        }
    }

    // MARK: - corpus realism (CT HU)

    // Oracle: real CT rescale is the affine transform slope·stored + intercept and is
    // consistent between DataSet.rescale and rescaleSlope()/rescaleIntercept().
    func testCorpusCTRescaleConsistency() throws {
        let loaded = try loadCorpus(.ct)
        try XCTSkipIf(loaded == nil, "corpus absent")
        let file = try XCTUnwrap(loaded)
        let pd = try XCTUnwrap(file.pixelData())
        let slope = file.dataSet.rescaleSlope()
        let intercept = file.dataSet.rescaleIntercept()
        let raw = try XCTUnwrap(pd.pixelValue(row: 256, column: 256))
        let expected = slope * Double(raw) + intercept
        XCTAssertEqual(file.dataSet.rescale(Double(raw)), expected, accuracy: 1e-9)
    }

    // MARK: - roi (circular region)

    // Oracle: a circular ROI collects the pixels of a closed disk — (x-cx)²+(y-cy)² ≤ r².
    // For r=1 at (2,2) that is exactly the 5-pixel plus-shape (center + 4 orthogonal
    // neighbors). Over a uniform field the ROI statistics are mean == value, stddev == 0.
    // (MeasurementEngine lives in the executable target; this reproduces its circle rule
    // over data read through the reachable DICOMKit library, per this file's convention.)
    func testROICircleCollectsClosedDisk() throws {
        let rows: UInt16 = 8, cols: UInt16 = 8
        let f = makeCalibrated16(rows: rows, cols: cols, pixelSpacing: "1.0\\1.0",
                                 rescaleSlope: nil, rescaleIntercept: nil) { _ in 100 }
        let pd = try XCTUnwrap(f.pixelData())

        let cx = 2, cy = 2, r = 1
        var vals: [Double] = []
        for y in 0..<Int(rows) {
            for x in 0..<Int(cols) {
                let dx = x - cx, dy = y - cy
                if dx * dx + dy * dy <= r * r {
                    vals.append(Double(try XCTUnwrap(pd.pixelValue(row: y, column: x))))
                }
            }
        }
        XCTAssertEqual(vals.count, 5, "closed unit disk at (2,2) must select the 5-pixel plus-shape")
        XCTAssertEqual(mean(vals), 100.0, accuracy: 1e-9)
        XCTAssertEqual(stddev(vals), 0.0, accuracy: 1e-9)
        XCTAssertEqual(vals.min()!, 100.0, accuracy: 1e-9)
        XCTAssertEqual(vals.max()!, 100.0, accuracy: 1e-9)
    }
}
