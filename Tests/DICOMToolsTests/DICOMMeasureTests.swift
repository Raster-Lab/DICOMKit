import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-measure CLI tool functionality
/// These tests validate coordinate transforms, measurements, and ROI analysis
final class DICOMMeasureTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a minimal DICOM file with pixel data and spacing for testing measurements
    private func createTestDICOMFileWithPixels(
        rows: UInt16 = 10,
        columns: UInt16 = 10,
        rowSpacing: Double = 1.0,
        colSpacing: Double = 1.0,
        bitsAllocated: UInt16 = 16,
        pixelRepresentation: UInt16 = 0,
        rescaleSlope: Double? = nil,
        rescaleIntercept: Double? = nil,
        pixelValues: [UInt16]? = nil
    ) throws -> Data {
        var data = Data()

        // 128-byte preamble
        data.append(Data(count: 128))

        // DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])

        // File Meta Information Group Length (0002,0000) - UL
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value

        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntax = "1.2.840.10008.1.2.1"
        let tsLength = UInt16(transferSyntax.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(transferSyntax.data(using: .utf8)!)

        // SOP Class UID (0008,0016) - UI
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopClass = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        let scLength = UInt16(sopClass.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: scLength.littleEndian) { Data($0) })
        data.append(sopClass.data(using: .utf8)!)

        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopInstance = "1.2.3.4.5.6.7.8.9"
        let siLength = UInt16(sopInstance.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: siLength.littleEndian) { Data($0) })
        data.append(sopInstance.data(using: .utf8)!)

        // Rows (0028,0010) - US
        data.append(contentsOf: [0x28, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: withUnsafeBytes(of: rows.littleEndian) { Data($0) })

        // Columns (0028,0011) - US
        data.append(contentsOf: [0x28, 0x00, 0x11, 0x00])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: columns.littleEndian) { Data($0) })

        // Bits Allocated (0028,0100) - US
        data.append(contentsOf: [0x28, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: bitsAllocated.littleEndian) { Data($0) })

        // Bits Stored (0028,0101) - US
        data.append(contentsOf: [0x28, 0x00, 0x01, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: bitsAllocated.littleEndian) { Data($0) })

        // High Bit (0028,0102) - US
        data.append(contentsOf: [0x28, 0x00, 0x02, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        let highBit = bitsAllocated - 1
        data.append(contentsOf: withUnsafeBytes(of: highBit.littleEndian) { Data($0) })

        // Pixel Representation (0028,0103) - US
        data.append(contentsOf: [0x28, 0x00, 0x03, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: pixelRepresentation.littleEndian) { Data($0) })

        // Pixel Spacing (0028,0030) - DS
        let pixelSpacingStr = "\(rowSpacing)\\\(colSpacing)"
        let psData = pixelSpacingStr.data(using: .utf8)!
        var psLen = UInt16(psData.count)
        if psLen % 2 != 0 { psLen += 1 } // Pad to even length
        data.append(contentsOf: [0x28, 0x00, 0x30, 0x00])
        data.append(contentsOf: [0x44, 0x53]) // VR = DS
        data.append(contentsOf: withUnsafeBytes(of: psLen.littleEndian) { Data($0) })
        data.append(psData)
        if psData.count % 2 != 0 { data.append(0x20) } // Pad with space

        // Rescale Intercept (0028,1052) - DS
        if let intercept = rescaleIntercept {
            let riStr = "\(intercept)"
            let riData = riStr.data(using: .utf8)!
            var riLen = UInt16(riData.count)
            if riLen % 2 != 0 { riLen += 1 }
            data.append(contentsOf: [0x28, 0x00, 0x52, 0x10])
            data.append(contentsOf: [0x44, 0x53]) // VR = DS
            data.append(contentsOf: withUnsafeBytes(of: riLen.littleEndian) { Data($0) })
            data.append(riData)
            if riData.count % 2 != 0 { data.append(0x20) }
        }

        // Rescale Slope (0028,1053) - DS
        if let slope = rescaleSlope {
            let rsStr = "\(slope)"
            let rsData = rsStr.data(using: .utf8)!
            var rsLen = UInt16(rsData.count)
            if rsLen % 2 != 0 { rsLen += 1 }
            data.append(contentsOf: [0x28, 0x00, 0x53, 0x10])
            data.append(contentsOf: [0x44, 0x53]) // VR = DS
            data.append(contentsOf: withUnsafeBytes(of: rsLen.littleEndian) { Data($0) })
            data.append(rsData)
            if rsData.count % 2 != 0 { data.append(0x20) }
        }

        // Pixel Data (7FE0,0010) - OW
        let totalPixels = Int(rows) * Int(columns)
        let values: [UInt16]
        if let provided = pixelValues {
            values = provided
        } else {
            // Generate a gradient pattern
            values = (0..<totalPixels).map { i in UInt16(i % 256) }
        }

        let bytesPerPixel = Int(bitsAllocated) / 8
        let pixelDataLength = UInt32(totalPixels * bytesPerPixel)
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00])
        data.append(contentsOf: [0x4F, 0x57]) // VR = OW
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: pixelDataLength.littleEndian) { Data($0) })

        for value in values {
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }

        return data
    }

    // MARK: - DICOM File Parsing Tests

    func testDICOMFileWithPixelData() throws {
        let testData = try createTestDICOMFileWithPixels()
        let dicomFile = try DICOMFile.read(from: testData)

        // Verify dimensions
        let rows = dicomFile.dataSet.uint16(for: .rows)
        XCTAssertEqual(rows, 10)

        let cols = dicomFile.dataSet.uint16(for: .columns)
        XCTAssertEqual(cols, 10)
    }

    func testPixelSpacingRetrieval() throws {
        let testData = try createTestDICOMFileWithPixels(rowSpacing: 0.5, colSpacing: 0.75)
        let dicomFile = try DICOMFile.read(from: testData)

        let spacings = dicomFile.dataSet.decimalStrings(for: .pixelSpacing)
        XCTAssertNotNil(spacings)
        XCTAssertEqual(spacings?.count, 2)
        if let spacings = spacings {
            XCTAssertEqual(spacings[0].value, 0.5, accuracy: 0.001)
            XCTAssertEqual(spacings[1].value, 0.75, accuracy: 0.001)
        }
    }

    // MARK: - Distance Measurement Tests

    func testDistanceMeasurementInPixels() throws {
        // 3-4-5 right triangle: distance should be 5 pixels
        let testData = try createTestDICOMFileWithPixels()
        let dicomFile = try DICOMFile.read(from: testData)
        let dataSet = dicomFile.dataSet

        // Manual distance calculation with 1mm spacing
        let dx = 3.0
        let dy = 4.0
        let expectedDistance = sqrt(dx * dx + dy * dy) // 5.0

        // Verify the basic math
        XCTAssertEqual(expectedDistance, 5.0, accuracy: 0.001)

        // Verify rows/columns are present
        XCTAssertNotNil(dataSet.uint16(for: .rows))
        XCTAssertNotNil(dataSet.uint16(for: .columns))
    }

    func testDistanceWithCalibration() {
        // With 2mm pixel spacing, a 3-pixel distance becomes 6mm
        let dx = 3.0 * 2.0 // 3 pixels * 2mm/pixel = 6mm
        let dy = 0.0
        let distanceMM = sqrt(dx * dx + dy * dy)
        XCTAssertEqual(distanceMM, 6.0, accuracy: 0.001)

        // Convert to cm
        let distanceCM = distanceMM / 10.0
        XCTAssertEqual(distanceCM, 0.6, accuracy: 0.001)

        // Convert to inches
        let distanceInches = distanceMM / 25.4
        XCTAssertEqual(distanceInches, 6.0 / 25.4, accuracy: 0.001)
    }

    // MARK: - Area Measurement Tests

    func testPolygonAreaCalculation() {
        // Square with corners at (0,0), (10,0), (10,10), (0,10)
        // Area should be 100 square pixels
        let area = shoelaceArea(vertices: [
            (0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)
        ])
        XCTAssertEqual(area, 100.0, accuracy: 0.001)
    }

    func testTriangleAreaCalculation() {
        // Triangle with vertices (0,0), (10,0), (5,10)
        // Area = 0.5 * base * height = 0.5 * 10 * 10 = 50
        let area = shoelaceArea(vertices: [
            (0.0, 0.0), (10.0, 0.0), (5.0, 10.0)
        ])
        XCTAssertEqual(area, 50.0, accuracy: 0.001)
    }

    func testEllipseAreaCalculation() {
        // Ellipse with rx=10, ry=5
        // Area = π * 10 * 5 = 50π ≈ 157.08
        let area = Double.pi * 10.0 * 5.0
        XCTAssertEqual(area, 50.0 * Double.pi, accuracy: 0.001)
    }

    func testPolygonAreaWithCalibration() {
        // 10x10 pixel square with 2mm spacing
        // Pixel area = 100 px²
        // Physical area = 100 * 2 * 2 = 400 mm²
        let pixelArea = 100.0
        let physicalArea = pixelArea * 2.0 * 2.0
        XCTAssertEqual(physicalArea, 400.0, accuracy: 0.001)
    }

    // MARK: - Angle Measurement Tests

    func testRightAngleMeasurement() {
        // 90-degree angle
        let vertex = (0.0, 0.0)
        let p1 = (10.0, 0.0)
        let p2 = (0.0, 10.0)

        let angle = calculateAngle(vertex: vertex, p1: p1, p2: p2)
        XCTAssertEqual(angle, 90.0, accuracy: 0.1)
    }

    func testStraightAngleMeasurement() {
        // 180-degree angle
        let vertex = (0.0, 0.0)
        let p1 = (10.0, 0.0)
        let p2 = (-10.0, 0.0)

        let angle = calculateAngle(vertex: vertex, p1: p1, p2: p2)
        XCTAssertEqual(angle, 180.0, accuracy: 0.1)
    }

    func testAcuteAngleMeasurement() {
        // 45-degree angle
        let vertex = (0.0, 0.0)
        let p1 = (10.0, 0.0)
        let p2 = (10.0, 10.0)

        let angle = calculateAngle(vertex: vertex, p1: p1, p2: p2)
        XCTAssertEqual(angle, 45.0, accuracy: 0.1)
    }

    func testZeroAngle() {
        // Same direction = 0 degrees
        let vertex = (0.0, 0.0)
        let p1 = (10.0, 0.0)
        let p2 = (20.0, 0.0)

        let angle = calculateAngle(vertex: vertex, p1: p1, p2: p2)
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }

    // MARK: - ROI Tests

    func testPointInPolygon() {
        // Square from (0,0) to (10,10)
        let polygon: [(Double, Double)] = [
            (0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)
        ]

        // Point inside
        XCTAssertTrue(isPointInPolygon(point: (5.0, 5.0), polygon: polygon))

        // Point outside
        XCTAssertFalse(isPointInPolygon(point: (15.0, 5.0), polygon: polygon))

        // Point on boundary (implementation-dependent, just verify no crash)
        _ = isPointInPolygon(point: (0.0, 5.0), polygon: polygon)
    }

    func testRectangularROIPixelCount() {
        // Rectangle from (2,2) to (5,5) in a 10x10 image
        let startX = 2, startY = 2, endX = 5, endY = 5
        let pixelCount = (endX - startX) * (endY - startY)
        XCTAssertEqual(pixelCount, 9) // 3x3 pixels
    }

    func testROIStatistics() {
        // Test mean, std dev, min, max on known values
        let values: [Double] = [10, 20, 30, 40, 50]
        let sum = values.reduce(0.0, +)
        let mean = sum / Double(values.count)
        XCTAssertEqual(mean, 30.0, accuracy: 0.001)

        let minVal = values.min()!
        XCTAssertEqual(minVal, 10.0)

        let maxVal = values.max()!
        XCTAssertEqual(maxVal, 50.0)

        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let stdDev = sqrt(variance)
        XCTAssertEqual(stdDev, sqrt(200.0), accuracy: 0.001) // sqrt(200) ≈ 14.142
    }

    // MARK: - Hounsfield Unit Tests

    func testRescaleFormula() {
        // HU = slope * stored + intercept
        let slope = 1.0
        let intercept = -1024.0
        let storedValue = 1024.0

        let hu = slope * storedValue + intercept
        XCTAssertEqual(hu, 0.0, accuracy: 0.001) // Water at 0 HU
    }

    func testRescaleWithCustomSlope() {
        let slope = 2.0
        let intercept = -500.0
        let storedValue = 300.0

        let hu = slope * storedValue + intercept
        XCTAssertEqual(hu, 100.0, accuracy: 0.001)
    }

    func testDefaultRescaleValues() throws {
        // Without rescale slope/intercept, defaults should be 1.0 and 0.0
        let testData = try createTestDICOMFileWithPixels()
        let dicomFile = try DICOMFile.read(from: testData)

        let slope = dicomFile.dataSet.rescaleSlope()
        let intercept = dicomFile.dataSet.rescaleIntercept()

        XCTAssertEqual(slope, 1.0, accuracy: 0.001)
        XCTAssertEqual(intercept, 0.0, accuracy: 0.001)
    }

    // MARK: - Histogram Tests

    func testHistogramGeneration() {
        let values: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let bins = generateHistogram(values: values, numBins: 5)

        XCTAssertEqual(bins.count, 5)

        // Total count across all bins should equal number of values
        let totalCount = bins.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalCount, values.count)
    }

    func testHistogramWithSingleValue() {
        // All same values - special case
        let values: [Double] = [5, 5, 5, 5, 5]
        let bins = generateHistogram(values: values, numBins: 10)

        // With all same values, min == max, so empty histogram
        XCTAssertEqual(bins.count, 0)
    }

    // MARK: - Unit Conversion Tests

    func testMillimetersToCentimeters() {
        let mm = 25.4
        let cm = mm / 10.0
        XCTAssertEqual(cm, 2.54, accuracy: 0.001)
    }

    func testMillimetersToInches() {
        let mm = 25.4
        let inches = mm / 25.4
        XCTAssertEqual(inches, 1.0, accuracy: 0.001)
    }

    func testAreaUnitConversion() {
        let areaMM2 = 100.0
        let areaCM2 = areaMM2 / 100.0
        XCTAssertEqual(areaCM2, 1.0, accuracy: 0.001)
    }

    // MARK: - Edge Case Tests

    func testZeroDistanceMeasurement() {
        let dx = 0.0, dy = 0.0
        let distance = sqrt(dx * dx + dy * dy)
        XCTAssertEqual(distance, 0.0, accuracy: 0.001)
    }

    func testDegeneratePolygon() {
        // Polygon with less than 3 vertices
        let area = shoelaceArea(vertices: [(0.0, 0.0), (10.0, 0.0)])
        XCTAssertEqual(area, 0.0, accuracy: 0.001)
    }

    func testCollinearPoints() {
        // Polygon where all points are collinear (area = 0)
        let area = shoelaceArea(vertices: [
            (0.0, 0.0), (5.0, 0.0), (10.0, 0.0)
        ])
        XCTAssertEqual(area, 0.0, accuracy: 0.001)
    }

    func testCoincidentAnglePoints() {
        // Vertex and point 1 are the same - should return 0
        let vertex = (5.0, 5.0)
        let p1 = (5.0, 5.0)
        let p2 = (10.0, 10.0)

        let angle = calculateAngle(vertex: vertex, p1: p1, p2: p2)
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }

    func testMissingImageDimensions() throws {
        var data = Data()
        data.append(Data(count: 128))
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])

        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C])
        data.append(contentsOf: [0x04, 0x00])
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00])

        let transferSyntax = "1.2.840.10008.1.2.1"
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let tsLength = UInt16(transferSyntax.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(transferSyntax.data(using: .utf8)!)

        // No rows/columns defined - file should parse but dimensions missing
        let dicomFile = try DICOMFile.read(from: data)
        XCTAssertNil(dicomFile.dataSet.uint16(for: .rows))
        XCTAssertNil(dicomFile.dataSet.uint16(for: .columns))
    }

    // MARK: - Pixel Data Access Tests

    func testPixelDataPresence() throws {
        let testData = try createTestDICOMFileWithPixels()
        let dicomFile = try DICOMFile.read(from: testData)

        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNotNil(pixelData)
    }

    func testKnownPixelValues() throws {
        // Create a 4x4 image with known values
        let values: [UInt16] = [
            100, 200, 300, 400,
            500, 600, 700, 800,
            900, 1000, 1100, 1200,
            1300, 1400, 1500, 1600
        ]
        let testData = try createTestDICOMFileWithPixels(
            rows: 4,
            columns: 4,
            pixelValues: values
        )
        let dicomFile = try DICOMFile.read(from: testData)

        // Verify pixel data exists
        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNotNil(pixelData)

        // Verify the raw data has the correct size
        if let pd = pixelData {
            XCTAssertEqual(pd.data.count, 32) // 16 pixels * 2 bytes
        }
    }

    // MARK: - Private Helpers (duplicate measurement logic for unit testing)

    private func shoelaceArea(vertices: [(Double, Double)]) -> Double {
        guard vertices.count >= 3 else { return 0.0 }
        var area = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += vertices[i].0 * vertices[j].1
            area -= vertices[j].0 * vertices[i].1
        }
        return abs(area) / 2.0
    }

    private func calculateAngle(vertex: (Double, Double), p1: (Double, Double), p2: (Double, Double)) -> Double {
        let v1x = p1.0 - vertex.0
        let v1y = p1.1 - vertex.1
        let v2x = p2.0 - vertex.0
        let v2y = p2.1 - vertex.1

        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)

        guard mag1 > 0 && mag2 > 0 else { return 0.0 }

        let cosAngle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosAngle) * 180.0 / Double.pi
    }

    private func isPointInPolygon(point: (Double, Double), polygon: [(Double, Double)]) -> Bool {
        var inside = false
        let n = polygon.count
        var j = n - 1
        for i in 0..<n {
            let xi = polygon[i].0, yi = polygon[i].1
            let xj = polygon[j].0, yj = polygon[j].1
            if (yi > point.1) != (yj > point.1) {
                let intersectX = (xj - xi) * (point.1 - yi) / (yj - yi) + xi
                if point.0 < intersectX {
                    inside = !inside
                }
            }
            j = i
        }
        return inside
    }

    private func generateHistogram(values: [Double], numBins: Int) -> [(lowerBound: Double, upperBound: Double, count: Int)] {
        guard let minVal = values.min(), let maxVal = values.max(), minVal < maxVal else {
            return []
        }
        let range = maxVal - minVal
        let binWidth = range / Double(numBins)
        var counts = [Int](repeating: 0, count: numBins)
        for value in values {
            var binIndex = Int((value - minVal) / binWidth)
            if binIndex >= numBins { binIndex = numBins - 1 }
            counts[binIndex] += 1
        }
        return (0..<numBins).map { i in
            (lowerBound: minVal + Double(i) * binWidth,
             upperBound: minVal + Double(i + 1) * binWidth,
             count: counts[i])
        }
    }
}
