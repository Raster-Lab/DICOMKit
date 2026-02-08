import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-pixedit CLI tool functionality
/// Note: Tests focus on DICOMKit/DICOMCore pixel data manipulation functionality,
/// as PixelEditor is in the executable target and not directly testable
final class DICOMPixeditTests: XCTestCase {

    // MARK: - Test Helpers

    /// Region struct for pixel operations
    struct PixelRegion {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    /// Creates a minimal DICOM file with pixel data
    private func createTestDICOMFileWithPixels(
        rows: UInt16,
        columns: UInt16,
        bitsAllocated: UInt16 = 8,
        pixelRepresentation: UInt16 = 0,
        pixelData: Data
    ) -> DICOMFile {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("CT", for: .modality, vr: .CS)

        dataSet.setUInt16(rows, for: .rows)
        dataSet.setUInt16(columns, for: .columns)
        dataSet.setUInt16(bitsAllocated, for: .bitsAllocated)
        dataSet.setUInt16(bitsAllocated, for: .bitsStored)
        dataSet.setUInt16(bitsAllocated - 1, for: .highBit)
        dataSet.setUInt16(pixelRepresentation, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)

        let vr: VR = bitsAllocated <= 8 ? .OB : .OW
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: vr, data: pixelData)

        return DICOMFile.create(dataSet: dataSet)
    }

    /// Creates 8-bit pixel data filled with sequential values
    private func create8BitPixelData(rows: Int, columns: Int, fillValue: UInt8? = nil) -> Data {
        let count = rows * columns
        if let fill = fillValue {
            return Data(repeating: fill, count: count)
        }
        var data = Data(count: count)
        for i in 0..<count {
            data[i] = UInt8(i % 256)
        }
        return data
    }

    /// Creates 16-bit pixel data filled with sequential values (little-endian)
    private func create16BitPixelData(rows: Int, columns: Int, fillValue: UInt16? = nil) -> Data {
        let count = rows * columns
        var data = Data(count: count * 2)
        for i in 0..<count {
            let value: UInt16 = fillValue ?? UInt16(i % 65536)
            data[i * 2] = UInt8(value & 0xFF)
            data[i * 2 + 1] = UInt8(value >> 8)
        }
        return data
    }

    /// Masks a rectangular region in pixel data with a fill value
    private func maskRegion(
        in pixelData: Data,
        rows: Int,
        columns: Int,
        region: PixelRegion,
        fillValue: UInt8,
        bytesPerPixel: Int = 1
    ) -> Data {
        var result = pixelData
        let clampedX = max(0, min(region.x, columns))
        let clampedY = max(0, min(region.y, rows))
        let clampedWidth = min(region.width, columns - clampedX)
        let clampedHeight = min(region.height, rows - clampedY)

        for row in clampedY..<(clampedY + clampedHeight) {
            for col in clampedX..<(clampedX + clampedWidth) {
                let offset = (row * columns + col) * bytesPerPixel
                for b in 0..<bytesPerPixel {
                    if offset + b < result.count {
                        result[offset + b] = fillValue
                    }
                }
            }
        }
        return result
    }

    /// Crops pixel data to a rectangular region
    private func cropRegion(
        from pixelData: Data,
        rows: Int,
        columns: Int,
        region: PixelRegion,
        bytesPerPixel: Int = 1
    ) -> (data: Data, newRows: Int, newColumns: Int) {
        let clampedX = max(0, min(region.x, columns))
        let clampedY = max(0, min(region.y, rows))
        let clampedWidth = min(region.width, columns - clampedX)
        let clampedHeight = min(region.height, rows - clampedY)

        var cropped = Data()
        for row in clampedY..<(clampedY + clampedHeight) {
            let srcOffset = (row * columns + clampedX) * bytesPerPixel
            let length = clampedWidth * bytesPerPixel
            if srcOffset + length <= pixelData.count {
                cropped.append(pixelData[srcOffset..<(srcOffset + length)])
            }
        }
        return (cropped, clampedHeight, clampedWidth)
    }

    /// Applies window/level to 16-bit pixel data, returning 8-bit output
    private func applyWindowLevel(
        to pixelData: Data,
        pixelCount: Int,
        windowCenter: Double,
        windowWidth: Double
    ) -> Data {
        let minVal = windowCenter - windowWidth / 2.0
        let maxVal = windowCenter + windowWidth / 2.0
        var output = Data(count: pixelCount)

        for i in 0..<pixelCount {
            let lo = pixelData[i * 2]
            let hi = pixelData[i * 2 + 1]
            let value = Double(UInt16(lo) | (UInt16(hi) << 8))

            let mapped: UInt8
            if value <= minVal {
                mapped = 0
            } else if value >= maxVal {
                mapped = 255
            } else {
                mapped = UInt8(((value - minVal) / (maxVal - minVal)) * 255.0)
            }
            output[i] = mapped
        }
        return output
    }

    /// Inverts 8-bit pixel data
    private func invert8Bit(_ pixelData: Data) -> Data {
        var result = pixelData
        for i in 0..<result.count {
            result[i] = 255 - result[i]
        }
        return result
    }

    /// Inverts 16-bit pixel data
    private func invert16Bit(_ pixelData: Data, maxValue: UInt16 = 65535) -> Data {
        let pixelCount = pixelData.count / 2
        var result = pixelData
        for i in 0..<pixelCount {
            let lo = pixelData[i * 2]
            let hi = pixelData[i * 2 + 1]
            let value = UInt16(lo) | (UInt16(hi) << 8)
            let inverted = maxValue - value
            result[i * 2] = UInt8(inverted & 0xFF)
            result[i * 2 + 1] = UInt8(inverted >> 8)
        }
        return result
    }

    /// Parses a region string in format "x,y,width,height"
    private func parseRegion(_ str: String) throws -> PixelRegion {
        let parts = str.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4 else {
            throw NSError(domain: "PixelEdit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Region must have 4 components: x,y,width,height"])
        }
        guard let x = Int(parts[0]), let y = Int(parts[1]),
              let width = Int(parts[2]), let height = Int(parts[3]) else {
            throw NSError(domain: "PixelEdit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Region components must be valid integers"])
        }
        guard x >= 0, y >= 0 else {
            throw NSError(domain: "PixelEdit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Region x and y must be non-negative"])
        }
        guard width > 0, height > 0 else {
            throw NSError(domain: "PixelEdit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Region width and height must be positive"])
        }
        return PixelRegion(x: x, y: y, width: width, height: height)
    }

    // MARK: - Pixel Data Access Tests

    func testReadPixelData() throws {
        let pixelData = create8BitPixelData(rows: 4, columns: 4)
        let file = createTestDICOMFileWithPixels(rows: 4, columns: 4, pixelData: pixelData)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        XCTAssertNotNil(readFile.dataSet[.pixelData])
    }

    func testPixelDataDescriptor() throws {
        let pixelData = create8BitPixelData(rows: 10, columns: 20)
        let file = createTestDICOMFileWithPixels(rows: 10, columns: 20, pixelData: pixelData)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        XCTAssertEqual(readFile.dataSet.uint16(for: .rows), 10)
        XCTAssertEqual(readFile.dataSet.uint16(for: .columns), 20)
        XCTAssertEqual(readFile.dataSet.uint16(for: .bitsAllocated), 8)
        XCTAssertEqual(readFile.dataSet.uint16(for: .bitsStored), 8)
        XCTAssertEqual(readFile.dataSet.uint16(for: .highBit), 7)
        XCTAssertEqual(readFile.dataSet.uint16(for: .pixelRepresentation), 0)
        XCTAssertEqual(readFile.dataSet.uint16(for: .samplesPerPixel), 1)
        XCTAssertEqual(readFile.dataSet.string(for: .photometricInterpretation), "MONOCHROME2")
    }

    func testPixelData8Bit() throws {
        let pixelData = create8BitPixelData(rows: 4, columns: 4)
        let file = createTestDICOMFileWithPixels(rows: 4, columns: 4, pixelData: pixelData)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let element = readFile.dataSet[.pixelData]
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.valueData.count, 16) // 4*4*1
    }

    func testPixelData16Bit() throws {
        let pixelData = create16BitPixelData(rows: 4, columns: 4)
        let file = createTestDICOMFileWithPixels(
            rows: 4, columns: 4, bitsAllocated: 16, pixelData: pixelData
        )
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let element = readFile.dataSet[.pixelData]
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.valueData.count, 32) // 4*4*2
    }

    func testPixelDataSize() throws {
        let rows = 8
        let columns = 6
        let pixelData8 = create8BitPixelData(rows: rows, columns: columns)
        XCTAssertEqual(pixelData8.count, rows * columns)

        let pixelData16 = create16BitPixelData(rows: rows, columns: columns)
        XCTAssertEqual(pixelData16.count, rows * columns * 2)
    }

    // MARK: - Mask Operations Tests

    func testMaskRegionAllZeros() throws {
        let rows = 4
        let columns = 4
        var pixelData = create8BitPixelData(rows: rows, columns: columns, fillValue: 100)

        let region = PixelRegion(x: 1, y: 1, width: 2, height: 2)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 0)

        // Check masked pixels are 0
        XCTAssertEqual(pixelData[1 * columns + 1], 0)
        XCTAssertEqual(pixelData[1 * columns + 2], 0)
        XCTAssertEqual(pixelData[2 * columns + 1], 0)
        XCTAssertEqual(pixelData[2 * columns + 2], 0)

        // Check non-masked pixels are still 100
        XCTAssertEqual(pixelData[0], 100)
        XCTAssertEqual(pixelData[3 * columns + 3], 100)
    }

    func testMaskRegionCustomFill() throws {
        let rows = 4
        let columns = 4
        var pixelData = create8BitPixelData(rows: rows, columns: columns, fillValue: 0)

        let region = PixelRegion(x: 0, y: 0, width: 2, height: 2)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 128)

        XCTAssertEqual(pixelData[0], 128)
        XCTAssertEqual(pixelData[1], 128)
        XCTAssertEqual(pixelData[columns], 128)
        XCTAssertEqual(pixelData[columns + 1], 128)

        // Outside region should still be 0
        XCTAssertEqual(pixelData[2], 0)
        XCTAssertEqual(pixelData[columns + 2], 0)
    }

    func testMaskRegionEdge() throws {
        let rows = 4
        let columns = 4
        var pixelData = create8BitPixelData(rows: rows, columns: columns, fillValue: 50)

        // Region extends past edge; should be clipped
        let region = PixelRegion(x: 3, y: 3, width: 5, height: 5)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 0)

        // Only (3,3) should be masked (clipped from 5x5 to 1x1)
        XCTAssertEqual(pixelData[3 * columns + 3], 0)
        XCTAssertEqual(pixelData[3 * columns + 2], 50) // Adjacent should be unchanged
    }

    func testMaskRegionFull() throws {
        let rows = 4
        let columns = 4
        var pixelData = create8BitPixelData(rows: rows, columns: columns, fillValue: 200)

        let region = PixelRegion(x: 0, y: 0, width: columns, height: rows)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 0)

        // All pixels should be 0
        for i in 0..<pixelData.count {
            XCTAssertEqual(pixelData[i], 0)
        }
    }

    func testMaskRegion8Bit() throws {
        let rows = 4
        let columns = 4
        var pixelData = create8BitPixelData(rows: rows, columns: columns, fillValue: 255)

        let region = PixelRegion(x: 0, y: 0, width: 1, height: 1)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 0)

        XCTAssertEqual(pixelData[0], 0)
        XCTAssertEqual(pixelData[1], 255)
    }

    func testMaskRegion16Bit() throws {
        let rows = 4
        let columns = 4
        var pixelData = create16BitPixelData(rows: rows, columns: columns, fillValue: 1000)

        let region = PixelRegion(x: 1, y: 1, width: 2, height: 2)
        pixelData = maskRegion(in: pixelData, rows: rows, columns: columns, region: region, fillValue: 0, bytesPerPixel: 2)

        // Check masked pixel (1,1) - both bytes should be 0
        let offset = (1 * columns + 1) * 2
        XCTAssertEqual(pixelData[offset], 0)
        XCTAssertEqual(pixelData[offset + 1], 0)

        // Check non-masked pixel (0,0) - should still be 1000 (0xE8, 0x03)
        XCTAssertEqual(pixelData[0], 0xE8)
        XCTAssertEqual(pixelData[1], 0x03)
    }

    // MARK: - Crop Operations Tests

    func testCropBasic() throws {
        let rows = 8
        let columns = 8
        let pixelData = create8BitPixelData(rows: rows, columns: columns)

        let region = PixelRegion(x: 2, y: 2, width: 4, height: 4)
        let (cropped, newRows, newCols) = cropRegion(from: pixelData, rows: rows, columns: columns, region: region)

        XCTAssertEqual(newRows, 4)
        XCTAssertEqual(newCols, 4)
        XCTAssertEqual(cropped.count, 16) // 4*4
    }

    func testCropPixelValues() throws {
        let rows = 4
        let columns = 4
        let pixelData = create8BitPixelData(rows: rows, columns: columns)

        let region = PixelRegion(x: 1, y: 1, width: 2, height: 2)
        let (cropped, _, _) = cropRegion(from: pixelData, rows: rows, columns: columns, region: region)

        // Pixel at (1,1) in original = index 1*4+1 = 5
        XCTAssertEqual(cropped[0], pixelData[1 * columns + 1])
        // Pixel at (2,1) in original = index 1*4+2 = 6
        XCTAssertEqual(cropped[1], pixelData[1 * columns + 2])
        // Pixel at (1,2) in original = index 2*4+1 = 9
        XCTAssertEqual(cropped[2], pixelData[2 * columns + 1])
        // Pixel at (2,2) in original = index 2*4+2 = 10
        XCTAssertEqual(cropped[3], pixelData[2 * columns + 2])
    }

    func testCropFullImage() throws {
        let rows = 4
        let columns = 4
        let pixelData = create8BitPixelData(rows: rows, columns: columns)

        let region = PixelRegion(x: 0, y: 0, width: columns, height: rows)
        let (cropped, newRows, newCols) = cropRegion(from: pixelData, rows: rows, columns: columns, region: region)

        XCTAssertEqual(newRows, rows)
        XCTAssertEqual(newCols, columns)
        XCTAssertEqual(cropped, pixelData)
    }

    func testCropEdge() throws {
        let rows = 4
        let columns = 4
        let pixelData = create8BitPixelData(rows: rows, columns: columns)

        // Region extends past edge
        let region = PixelRegion(x: 3, y: 3, width: 10, height: 10)
        let (cropped, newRows, newCols) = cropRegion(from: pixelData, rows: rows, columns: columns, region: region)

        // Should be clipped to 1x1
        XCTAssertEqual(newRows, 1)
        XCTAssertEqual(newCols, 1)
        XCTAssertEqual(cropped.count, 1)
    }

    func testCropSmallRegion() throws {
        let rows = 10
        let columns = 10
        let pixelData = create8BitPixelData(rows: rows, columns: columns)

        let region = PixelRegion(x: 5, y: 5, width: 1, height: 1)
        let (cropped, newRows, newCols) = cropRegion(from: pixelData, rows: rows, columns: columns, region: region)

        XCTAssertEqual(newRows, 1)
        XCTAssertEqual(newCols, 1)
        XCTAssertEqual(cropped.count, 1)
        XCTAssertEqual(cropped[0], pixelData[5 * columns + 5])
    }

    func testCropUpdatesRowsColumns() throws {
        let rows: UInt16 = 8
        let columns: UInt16 = 8
        let pixelData = create8BitPixelData(rows: Int(rows), columns: Int(columns))
        let file = createTestDICOMFileWithPixels(rows: rows, columns: columns, pixelData: pixelData)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)
        var dataSet = readFile.dataSet

        let region = PixelRegion(x: 1, y: 1, width: 4, height: 3)
        let originalPixelData = dataSet[.pixelData]!.valueData
        let (cropped, newRows, newCols) = cropRegion(
            from: originalPixelData,
            rows: Int(rows),
            columns: Int(columns),
            region: region
        )

        // Update the data set with cropped data
        dataSet.setUInt16(UInt16(newRows), for: .rows)
        dataSet.setUInt16(UInt16(newCols), for: .columns)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: cropped)

        XCTAssertEqual(dataSet.uint16(for: .rows), 3)
        XCTAssertEqual(dataSet.uint16(for: .columns), 4)
        XCTAssertEqual(dataSet[.pixelData]?.valueData.count, 12) // 4*3
    }

    // MARK: - Window/Level Operations Tests

    func testWindowLevelBasic() throws {
        let pixelCount = 16
        let pixelData = create16BitPixelData(rows: 4, columns: 4)

        let result = applyWindowLevel(to: pixelData, pixelCount: pixelCount, windowCenter: 8, windowWidth: 16)

        XCTAssertEqual(result.count, pixelCount)
        // All values should be in [0, 255]
        for i in 0..<result.count {
            XCTAssertTrue(result[i] >= 0 && result[i] <= 255)
        }
    }

    func testWindowLevelBelowWindow() throws {
        // All pixel values are 0
        let pixelData = create16BitPixelData(rows: 2, columns: 2, fillValue: 0)

        // Window center at 1000, width 100 -> range [950, 1050]
        let result = applyWindowLevel(to: pixelData, pixelCount: 4, windowCenter: 1000, windowWidth: 100)

        // All values below window -> should be 0
        for i in 0..<result.count {
            XCTAssertEqual(result[i], 0)
        }
    }

    func testWindowLevelAboveWindow() throws {
        // All pixel values are 2000
        let pixelData = create16BitPixelData(rows: 2, columns: 2, fillValue: 2000)

        // Window center at 1000, width 100 -> range [950, 1050]
        let result = applyWindowLevel(to: pixelData, pixelCount: 4, windowCenter: 1000, windowWidth: 100)

        // All values above window -> should be 255
        for i in 0..<result.count {
            XCTAssertEqual(result[i], 255)
        }
    }

    func testWindowLevelCenter() throws {
        // All pixel values at window center
        let pixelData = create16BitPixelData(rows: 2, columns: 2, fillValue: 500)

        let result = applyWindowLevel(to: pixelData, pixelCount: 4, windowCenter: 500, windowWidth: 200)

        // Values at center should be approximately 127-128
        for i in 0..<result.count {
            XCTAssertTrue(result[i] >= 125 && result[i] <= 130,
                          "Expected ~127, got \(result[i])")
        }
    }

    func testWindowLevelNarrowWidth() throws {
        // Create data with spread values
        var pixelData = Data(count: 8) // 4 pixels, 16-bit
        // Pixel 0: value 100
        pixelData[0] = 100; pixelData[1] = 0
        // Pixel 1: value 200
        pixelData[2] = 200; pixelData[3] = 0
        // Pixel 2: value 150 (center)
        pixelData[4] = 150; pixelData[5] = 0
        // Pixel 3: value 250
        pixelData[6] = 250; pixelData[7] = 0

        // Very narrow window at center 150, width 2
        let result = applyWindowLevel(to: pixelData, pixelCount: 4, windowCenter: 150, windowWidth: 2)

        // 100 is way below window -> 0
        XCTAssertEqual(result[0], 0)
        // 200 is above window -> 255
        XCTAssertEqual(result[1], 255)
        // 150 is at center -> ~127
        XCTAssertTrue(result[2] >= 125 && result[2] <= 130)
        // 250 is above window -> 255
        XCTAssertEqual(result[3], 255)
    }

    // MARK: - Invert Operations Tests

    func testInvertBasic() throws {
        let pixelData = Data([0, 50, 100, 200, 255])
        let inverted = invert8Bit(pixelData)

        XCTAssertEqual(inverted[0], 255)
        XCTAssertEqual(inverted[1], 205)
        XCTAssertEqual(inverted[2], 155)
        XCTAssertEqual(inverted[3], 55)
        XCTAssertEqual(inverted[4], 0)
    }

    func testInvertDoubleInvert() throws {
        let original = Data([0, 42, 128, 200, 255])
        let inverted = invert8Bit(original)
        let doubleInverted = invert8Bit(inverted)

        XCTAssertEqual(original, doubleInverted)
    }

    func testInvert8Bit() throws {
        let pixelData = create8BitPixelData(rows: 4, columns: 4)
        let inverted = invert8Bit(pixelData)

        for i in 0..<pixelData.count {
            XCTAssertEqual(inverted[i], 255 - pixelData[i])
        }
    }

    func testInvert16Bit() throws {
        let pixelData = create16BitPixelData(rows: 2, columns: 2, fillValue: 1000)
        let inverted = invert16Bit(pixelData)

        // Original: 1000 (0xE8, 0x03), inverted: 65535 - 1000 = 64535 (0x17, 0xFC)
        let invertedValue = UInt16(inverted[0]) | (UInt16(inverted[1]) << 8)
        XCTAssertEqual(invertedValue, 64535)
    }

    // MARK: - Region Parsing Tests

    func testParseRegionValid() throws {
        let region = try parseRegion("10,20,100,50")

        XCTAssertEqual(region.x, 10)
        XCTAssertEqual(region.y, 20)
        XCTAssertEqual(region.width, 100)
        XCTAssertEqual(region.height, 50)
    }

    func testParseRegionInvalid() throws {
        XCTAssertThrowsError(try parseRegion("invalid")) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("4 components"))
        }
    }

    func testParseRegionTooFewParts() throws {
        XCTAssertThrowsError(try parseRegion("10,20")) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("4 components"))
        }
    }

    func testParseRegionNegativeValues() throws {
        XCTAssertThrowsError(try parseRegion("10,-20,100,50")) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("non-negative"))
        }
    }

    func testParseRegionZeroDimension() throws {
        XCTAssertThrowsError(try parseRegion("10,20,0,50")) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("positive"))
        }
    }

    // MARK: - Edge Cases

    func testEmptyPixelData() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setUInt16(0, for: .rows)
        dataSet.setUInt16(0, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)

        // No pixel data element
        XCTAssertNil(dataSet[.pixelData])
        XCTAssertEqual(dataSet.uint16(for: .rows), 0)
        XCTAssertEqual(dataSet.uint16(for: .columns), 0)
    }

    func testSignedPixelData() throws {
        // Create 16-bit signed pixel data with pixelRepresentation = 1
        let rows: UInt16 = 2
        let columns: UInt16 = 2

        // Signed 16-bit values: -100, 0, 100, 200
        var pixelData = Data(count: 8)
        let signedValues: [Int16] = [-100, 0, 100, 200]
        for (i, val) in signedValues.enumerated() {
            let unsigned = UInt16(bitPattern: val)
            pixelData[i * 2] = UInt8(unsigned & 0xFF)
            pixelData[i * 2 + 1] = UInt8(unsigned >> 8)
        }

        let file = createTestDICOMFileWithPixels(
            rows: rows,
            columns: columns,
            bitsAllocated: 16,
            pixelRepresentation: 1, // signed
            pixelData: pixelData
        )
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        XCTAssertEqual(readFile.dataSet.uint16(for: .pixelRepresentation), 1)
        XCTAssertNotNil(readFile.dataSet[.pixelData])

        // Verify we can read back the signed values from raw data
        let readPixelData = readFile.dataSet[.pixelData]!.valueData
        let firstLo = readPixelData[0]
        let firstHi = readPixelData[1]
        let firstUnsigned = UInt16(firstLo) | (UInt16(firstHi) << 8)
        let firstSigned = Int16(bitPattern: firstUnsigned)
        XCTAssertEqual(firstSigned, -100)
    }
}
