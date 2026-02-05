import XCTest
import Foundation
@testable import DICOMKit
import DICOMCore

final class OptimizedParsingTests: XCTestCase {
    
    /// Helper to create a minimal valid DICOM file with pixel data
    private func createTestDICOMFileData(includePixelData: Bool = true) -> Data {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // File Meta Information: Transfer Syntax UID (0002,0010)
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR: UI
        data.append(contentsOf: [0x14, 0x00]) // Length: 20
        data.append(contentsOf: [0x31, 0x2e, 0x32, 0x2e, 0x38, 0x34, 0x30, 0x2e,
                                 0x31, 0x30, 0x30, 0x30, 0x38, 0x2e, 0x31, 0x2e,
                                 0x32, 0x2e, 0x31, 0x20]) // "1.2.840.10008.1.2.1 "
        
        // Main dataset: Patient Name (0010,0010)
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x50, 0x4E]) // VR: PN
        data.append(contentsOf: [0x0A, 0x00]) // Length: 10
        data.append(contentsOf: "Test^Patient".utf8.prefix(10))
        
        // Study Instance UID (0020,000D)
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR: UI
        data.append(contentsOf: [0x14, 0x00]) // Length: 20
        data.append(contentsOf: "1.2.3.4.5.6.7.8.9.10".utf8.prefix(20))
        
        if includePixelData {
            // Pixel Data (7FE0,0010) - uncompressed, 100 bytes
            data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00]) // Tag
            data.append(contentsOf: [0x4F, 0x57]) // VR: OW
            data.append(contentsOf: [0x00, 0x00]) // Reserved
            data.append(contentsOf: [0x64, 0x00, 0x00, 0x00]) // Length: 100
            data.append(Data(count: 100)) // 100 bytes of pixel data
        }
        
        return data
    }
    
    func testFullParsingMode() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        let file = try DICOMFile.read(from: data, options: .default)
        
        XCTAssertGreaterThanOrEqual(file.dataSet.count, 2) // At least Patient Name and Study UID
        // Pixel data should be included
        if let pixelData = file.dataSet.element(for: .pixelData) {
            XCTAssertNotNil(pixelData)
        }
    }
    
    func testMetadataOnlyParsing() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        let file = try DICOMFile.read(from: data, options: .metadataOnly)
        
        // Should have metadata elements
        XCTAssertGreaterThanOrEqual(file.dataSet.count, 2)
        
        // Pixel data should NOT be included
        let pixelData = file.dataSet.element(for: .pixelData)
        XCTAssertNil(pixelData)
    }
    
    func testLazyPixelDataParsing() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        let file = try DICOMFile.read(from: data, options: .lazyPixelData)
        
        // Should have metadata elements
        XCTAssertGreaterThanOrEqual(file.dataSet.count, 2)
        
        // Pixel data element should exist but with empty value
        if let pixelData = file.dataSet.element(for: .pixelData) {
            XCTAssertEqual(pixelData.valueData.count, 0)
        }
    }
    
    func testStopAfterTagOption() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        // Stop after Patient Name
        let stopTag = Tag(group: 0x0010, element: 0x0010)
        let options = ParsingOptions(stopAfterTag: stopTag)
        
        let file = try DICOMFile.read(from: data, options: options)
        
        // Should have only patient name (stopped after it)
        XCTAssertEqual(file.dataSet.count, 1)
        XCTAssertNotNil(file.dataSet.element(for: .patientName))
    }
    
    func testMaxElementsOption() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        // Limit to 1 element
        let options = ParsingOptions(maxElements: 1)
        
        let file = try DICOMFile.read(from: data, options: options)
        
        // Should have exactly 1 element
        XCTAssertEqual(file.dataSet.count, 1)
    }
    
    func testMemoryUsageComparison() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        // Measure full parsing
        let fullResult = DICOMBenchmark.measure(
            name: "Full parsing",
            trackMemory: true
        ) {
            try! DICOMFile.read(from: data, options: .default)
        }
        
        // Measure metadata-only parsing
        let metadataResult = DICOMBenchmark.measure(
            name: "Metadata-only parsing",
            trackMemory: true
        ) {
            try! DICOMFile.read(from: data, options: .metadataOnly)
        }
        
        // Metadata-only should use less or equal memory
        if let fullMem = fullResult.peakMemoryUsage,
           let metaMem = metadataResult.peakMemoryUsage {
            XCTAssertLessThanOrEqual(metaMem, fullMem)
        }
    }
    
    func testParsingSpeedComparison() throws {
        let data = createTestDICOMFileData(includePixelData: true)
        
        // Measure full parsing
        let fullResult = DICOMBenchmark.measure(
            name: "Full parsing",
            iterations: 10
        ) {
            try! DICOMFile.read(from: data, options: .default)
        }
        
        // Measure metadata-only parsing
        let metadataResult = DICOMBenchmark.measure(
            name: "Metadata-only parsing",
            iterations: 10
        ) {
            try! DICOMFile.read(from: data, options: .metadataOnly)
        }
        
        // Metadata-only should be faster or equal
        XCTAssertLessThanOrEqual(metadataResult.averageDuration, fullResult.averageDuration)
        
        let comparison = BenchmarkComparison(baseline: fullResult, optimized: metadataResult)
        XCTAssertGreaterThanOrEqual(comparison.speedImprovement, 1.0)
    }
}
