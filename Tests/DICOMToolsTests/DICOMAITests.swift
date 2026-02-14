import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-ai CLI tool functionality
/// These tests validate AI model loading, preprocessing, and inference operations
final class DICOMAITests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a minimal DICOM file with pixel data for testing
    private func createTestDICOMFile(
        rows: UInt16 = 512,
        columns: UInt16 = 512,
        bitsAllocated: UInt16 = 16,
        samplesPerPixel: UInt16 = 1
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
        
        // SOP Class UID (0008,0016) - UI - CT Image Storage
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopClass = "1.2.840.10008.5.1.4.1.1.2"
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
        
        // Pixel Representation (0028,0103) - US (0 = unsigned)
        data.append(contentsOf: [0x28, 0x00, 0x03, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: [0x00, 0x00])
        
        // Samples Per Pixel (0028,0002) - US
        data.append(contentsOf: [0x28, 0x00, 0x02, 0x00])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: samplesPerPixel.littleEndian) { Data($0) })
        
        // Photometric Interpretation (0028,0004) - CS
        data.append(contentsOf: [0x28, 0x00, 0x04, 0x00])
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let photometric = "MONOCHROME2 "
        let pmLength = UInt16(photometric.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: pmLength.littleEndian) { Data($0) })
        data.append(photometric.data(using: .utf8)!)
        
        // Pixel Data (7FE0,0010) - OW
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00])
        data.append(contentsOf: [0x4F, 0x57]) // VR = OW
        let pixelCount = Int(rows) * Int(columns)
        let pixelDataSize = pixelCount * Int(bitsAllocated) / 8
        let pixelLength = UInt16(pixelDataSize & 0xFFFF)
        data.append(contentsOf: withUnsafeBytes(of: pixelLength.littleEndian) { Data($0) })
        
        // Simple gradient pixel data
        for i in 0..<pixelCount {
            let value = UInt16(i % 4096)
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }
        
        return data
    }
    
    // MARK: - Model Loading Tests
    
    func test_modelLoadingErrors_invalidPath() throws {
        // Test that attempting to load a non-existent model fails appropriately
        let invalidPath = "/nonexistent/model.mlmodel"
        
        #if canImport(CoreML)
        XCTAssertThrowsError(try AIEngine(modelURL: URL(fileURLWithPath: invalidPath))) { error in
            XCTAssertTrue(error is AIError, "Expected AIError")
        }
        #endif
    }
    
    func test_modelLoadingErrors_invalidExtension() throws {
        // Test that invalid model file extensions are rejected
        let invalidPath = "/tmp/model.txt"
        
        #if canImport(CoreML)
        XCTAssertThrowsError(try AIEngine(modelURL: URL(fileURLWithPath: invalidPath))) { error in
            if let aiError = error as? AIError {
                switch aiError {
                case .invalidModelFormat:
                    break // Expected
                default:
                    XCTFail("Expected invalidModelFormat error")
                }
            }
        }
        #endif
    }
    
    // MARK: - Image Preprocessing Tests
    
    func test_preprocessImage_extractsDimensions() throws {
        let dicomData = try createTestDICOMFile(rows: 256, columns: 256)
        let reader = DICOMFileReader(data: dicomData)
        let dataSet = try reader.readDataSet()
        
        #if canImport(CoreML)
        // Note: We can't actually create an AIEngine without a real model,
        // so this test validates the DICOM parsing part
        XCTAssertEqual(dataSet.uint16(for: .rows), 256)
        XCTAssertEqual(dataSet.uint16(for: .columns), 256)
        XCTAssertNotNil(dataSet.element(for: .pixelData))
        #endif
    }
    
    func test_preprocessImage_handlesMonochrome() throws {
        let dicomData = try createTestDICOMFile(samplesPerPixel: 1)
        let reader = DICOMFileReader(data: dicomData)
        let dataSet = try reader.readDataSet()
        
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "MONOCHROME2")
        XCTAssertEqual(dataSet.uint16(for: .samplesPerPixel), 1)
    }
    
    func test_preprocessImage_extracts16BitPixelData() throws {
        let dicomData = try createTestDICOMFile(bitsAllocated: 16)
        let reader = DICOMFileReader(data: dicomData)
        let dataSet = try reader.readDataSet()
        
        XCTAssertEqual(dataSet.uint16(for: .bitsAllocated), 16)
        XCTAssertNotNil(dataSet.element(for: .pixelData))
    }
    
    // MARK: - Error Handling Tests
    
    func test_processedImage_missingPixelData() throws {
        var data = Data()
        data.append(Data(count: 128))
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Minimal meta info without pixel data
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C])
        data.append(contentsOf: [0x04, 0x00])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        
        let reader = DICOMFileReader(data: data)
        let dataSet = try reader.readDataSet()
        
        // Verify pixel data is missing
        XCTAssertNil(dataSet.element(for: .pixelData))
    }
    
    // MARK: - Output Format Tests
    
    func test_formatClassificationResults_json() {
        let predictions = [
            Prediction(label: "pneumonia", confidence: 0.87),
            Prediction(label: "normal", confidence: 0.13)
        ]
        
        let output = formatClassificationResults(
            predictions: predictions,
            format: .json,
            filePath: "test.dcm"
        )
        
        XCTAssertTrue(output.contains("pneumonia"))
        XCTAssertTrue(output.contains("0.87"))
        XCTAssertTrue(output.contains("test.dcm"))
    }
    
    func test_formatClassificationResults_text() {
        let predictions = [
            Prediction(label: "lesion", confidence: 0.92),
            Prediction(label: "normal", confidence: 0.08)
        ]
        
        let output = formatClassificationResults(
            predictions: predictions,
            format: .text,
            filePath: "brain.dcm"
        )
        
        XCTAssertTrue(output.contains("lesion"))
        XCTAssertTrue(output.contains("92.00%"))
        XCTAssertTrue(output.contains("brain.dcm"))
    }
    
    func test_formatClassificationResults_csv() {
        let predictions = [
            Prediction(label: "abnormal", confidence: 0.75)
        ]
        
        let output = formatClassificationResults(
            predictions: predictions,
            format: .csv,
            filePath: "scan.dcm"
        )
        
        XCTAssertTrue(output.contains("file,label,confidence"))
        XCTAssertTrue(output.contains("scan.dcm,abnormal,0.75"))
    }
    
    func test_formatDetectionResults_json() {
        let detections = [
            Detection(
                label: "nodule",
                confidence: 0.88,
                bbox: BoundingBox(x: 100, y: 150, width: 50, height: 45)
            )
        ]
        
        let output = formatDetectionResults(
            detections: detections,
            format: .json,
            filePath: "chest.dcm"
        )
        
        XCTAssertTrue(output.contains("nodule"))
        XCTAssertTrue(output.contains("0.88"))
        XCTAssertTrue(output.contains("100"))
        XCTAssertTrue(output.contains("150"))
    }
    
    func test_formatDetectionResults_csv() {
        let detections = [
            Detection(
                label: "lesion",
                confidence: 0.92,
                bbox: BoundingBox(x: 200, y: 250, width: 30, height: 28)
            )
        ]
        
        let output = formatDetectionResults(
            detections: detections,
            format: .csv,
            filePath: "mri.dcm"
        )
        
        XCTAssertTrue(output.contains("file,label,confidence,x,y,width,height"))
        XCTAssertTrue(output.contains("mri.dcm,lesion,0.92,200.0,250.0,30.0,28.0"))
    }
    
    func test_formatSegmentationResults_json() {
        let mask = SegmentationMask(
            width: 512,
            height: 512,
            data: Data(count: 512 * 512),
            numClasses: 3
        )
        
        let output = formatSegmentationResults(
            mask: mask,
            format: .json,
            filePath: "ct.dcm"
        )
        
        XCTAssertTrue(output.contains("512x512"))
        XCTAssertTrue(output.contains("3"))
        XCTAssertTrue(output.contains("ct.dcm"))
    }
    
    func test_formatSegmentationResults_text() {
        let mask = SegmentationMask(
            width: 256,
            height: 256,
            data: Data(count: 256 * 256),
            numClasses: 2
        )
        
        let output = formatSegmentationResults(
            mask: mask,
            format: .text,
            filePath: "liver.dcm"
        )
        
        XCTAssertTrue(output.contains("256x256"))
        XCTAssertTrue(output.contains("Classes: 2"))
    }
    
    // MARK: - Batch Processing Tests
    
    func test_formatBatchResultsAsCSV_singleFile() {
        let results: [[String: Any]] = [
            [
                "file": "test1.dcm",
                "predictions": [
                    ["label": "positive", "confidence": 0.85]
                ]
            ]
        ]
        
        let csv = formatBatchResultsAsCSV(results)
        
        XCTAssertTrue(csv.contains("file,label,confidence"))
        XCTAssertTrue(csv.contains("test1.dcm,positive,0.85"))
    }
    
    func test_formatBatchResultsAsCSV_multipleFiles() {
        let results: [[String: Any]] = [
            [
                "file": "test1.dcm",
                "predictions": [
                    ["label": "positive", "confidence": 0.85],
                    ["label": "negative", "confidence": 0.15]
                ]
            ],
            [
                "file": "test2.dcm",
                "predictions": [
                    ["label": "positive", "confidence": 0.22]
                ]
            ]
        ]
        
        let csv = formatBatchResultsAsCSV(results)
        
        XCTAssertTrue(csv.contains("test1.dcm,positive,0.85"))
        XCTAssertTrue(csv.contains("test1.dcm,negative,0.15"))
        XCTAssertTrue(csv.contains("test2.dcm,positive,0.22"))
    }
    
    func test_formatBatchResultsAsCSV_withErrors() {
        let results: [[String: Any]] = [
            [
                "file": "test1.dcm",
                "predictions": [
                    ["label": "positive", "confidence": 0.85]
                ]
            ],
            [
                "file": "test2.dcm",
                "error": "Failed to load model"
            ]
        ]
        
        let csv = formatBatchResultsAsCSV(results)
        
        XCTAssertTrue(csv.contains("test1.dcm,positive,0.85"))
        XCTAssertTrue(csv.contains("test2.dcm,ERROR"))
    }
    
    // MARK: - Labels File Tests
    
    func test_loadLabels_arrayFormat() throws {
        let json = """
        ["background", "liver", "kidney"]
        """
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("labels-\(UUID().uuidString).json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let labels = try loadLabels(from: tempFile.path)
        
        XCTAssertEqual(labels.count, 3)
        XCTAssertEqual(labels[0], "background")
        XCTAssertEqual(labels[1], "liver")
        XCTAssertEqual(labels[2], "kidney")
    }
    
    func test_loadLabels_dictionaryFormat() throws {
        let json = """
        {
          "labels": ["class1", "class2", "class3"]
        }
        """
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("labels-\(UUID().uuidString).json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let labels = try loadLabels(from: tempFile.path)
        
        XCTAssertEqual(labels.count, 3)
        XCTAssertEqual(labels[0], "class1")
    }
    
    func test_loadLabels_nilPath() throws {
        let labels = try loadLabels(from: nil)
        XCTAssertEqual(labels.count, 0)
    }
    
    func test_loadLabels_invalidFormat() throws {
        let json = """
        {"invalid": "format"}
        """
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("labels-\(UUID().uuidString).json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        XCTAssertThrowsError(try loadLabels(from: tempFile.path)) { error in
            XCTAssertTrue(error is AIError)
        }
    }
    
    // MARK: - Data Structure Tests
    
    func test_processedImage_initialization() {
        let image = ProcessedImage(
            width: 512,
            height: 512,
            bitsPerPixel: 16,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2",
            pixelData: Data(count: 512 * 512 * 2)
        )
        
        XCTAssertEqual(image.width, 512)
        XCTAssertEqual(image.height, 512)
        XCTAssertEqual(image.bitsPerPixel, 16)
        XCTAssertEqual(image.samplesPerPixel, 1)
    }
    
    func test_prediction_initialization() {
        let pred = Prediction(label: "pneumonia", confidence: 0.87)
        
        XCTAssertEqual(pred.label, "pneumonia")
        XCTAssertEqual(pred.confidence, 0.87, accuracy: 0.001)
    }
    
    func test_detection_initialization() {
        let detection = Detection(
            label: "nodule",
            confidence: 0.92,
            bbox: BoundingBox(x: 100, y: 150, width: 50, height: 45)
        )
        
        XCTAssertEqual(detection.label, "nodule")
        XCTAssertEqual(detection.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(detection.bbox.x, 100, accuracy: 0.001)
        XCTAssertEqual(detection.bbox.width, 50, accuracy: 0.001)
    }
    
    func test_segmentationMask_initialization() {
        let mask = SegmentationMask(
            width: 256,
            height: 256,
            data: Data(count: 256 * 256),
            numClasses: 3
        )
        
        XCTAssertEqual(mask.width, 256)
        XCTAssertEqual(mask.height, 256)
        XCTAssertEqual(mask.numClasses, 3)
        XCTAssertEqual(mask.data.count, 256 * 256)
    }
    
    // MARK: - Error Description Tests
    
    func test_aiError_descriptions() {
        let errors: [AIError] = [
            .platformNotSupported("test"),
            .modelLoadFailed("test"),
            .modelNotLoaded("test"),
            .invalidModelFormat("test"),
            .invalidModelOutput("test"),
            .noPixelData("test"),
            .missingMetadata("test"),
            .missingOutput("test"),
            .invalidLabelsFile("test"),
            .notImplemented("test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertTrue(error.errorDescription!.contains("test"))
        }
    }
}
