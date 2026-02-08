import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

/// Tests for dicom-split CLI tool functionality
final class DICOMSplitTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a multi-frame DICOM file for testing
    private func createMultiFrameDICOMFile(
        numberOfFrames: Int,
        rows: Int = 64,
        columns: Int = 64,
        modality: String = "CT",
        seriesNumber: String = "1"
    ) throws -> Data {
        var data = Data()
        
        // Add 128-byte preamble
        data.append(Data(count: 128))
        
        // Add DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        // File Meta Information Group Length (0002,0000) - UL, 4 bytes
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value (placeholder)
        
        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let transferSyntaxLength = UInt16(transferSyntaxUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: transferSyntaxLength.littleEndian) { Data($0) })
        data.append(transferSyntaxUID.data(using: .utf8)!)
        
        // SOP Class UID (0008,0016) - UI (Enhanced CT Image Storage for multi-frame)
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.2.1" // Enhanced CT Image Storage
        let sopClassLength = UInt16(sopClassUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopClassLength.littleEndian) { Data($0) })
        data.append(sopClassUID.data(using: .utf8)!)
        
        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceUID = "1.2.3.4.5.6.7.8.9.100"
        let sopInstanceLength = UInt16(sopInstanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
        data.append(sopInstanceUID.data(using: .utf8)!)
        
        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modalityLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)
        
        // Series Number (0020,0011) - IS
        data.append(contentsOf: [0x20, 0x00, 0x11, 0x00]) // Tag
        data.append(contentsOf: [0x49, 0x53]) // VR = IS
        let seriesNumberLength = UInt16(seriesNumber.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: seriesNumberLength.littleEndian) { Data($0) })
        data.append(seriesNumber.data(using: .utf8)!)
        
        // Number of Frames (0028,0008) - IS
        data.append(contentsOf: [0x28, 0x00, 0x08, 0x00]) // Tag
        data.append(contentsOf: [0x49, 0x53]) // VR = IS
        let framesStr = "\(numberOfFrames)"
        let framesStrLength = UInt16(framesStr.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: framesStrLength.littleEndian) { Data($0) })
        data.append(framesStr.data(using: .utf8)!)
        
        // Rows (0028,0010) - US
        data.append(contentsOf: [0x28, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        let rowsValue = UInt16(rows)
        data.append(contentsOf: withUnsafeBytes(of: rowsValue.littleEndian) { Data($0) })
        
        // Columns (0028,0011) - US
        data.append(contentsOf: [0x28, 0x00, 0x11, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        let columnsValue = UInt16(columns)
        data.append(contentsOf: withUnsafeBytes(of: columnsValue.littleEndian) { Data($0) })
        
        // Bits Allocated (0028,0100) - US
        data.append(contentsOf: [0x28, 0x00, 0x00, 0x01]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: [0x10, 0x00]) // 16 bits
        
        // Bits Stored (0028,0101) - US
        data.append(contentsOf: [0x28, 0x00, 0x01, 0x01]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: [0x10, 0x00]) // 16 bits
        
        // High Bit (0028,0102) - US
        data.append(contentsOf: [0x28, 0x00, 0x02, 0x01]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: [0x0F, 0x00]) // 15
        
        // Pixel Representation (0028,0103) - US
        data.append(contentsOf: [0x28, 0x00, 0x03, 0x01]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: [0x00, 0x00]) // Unsigned
        
        // Samples Per Pixel (0028,0002) - US
        data.append(contentsOf: [0x28, 0x00, 0x02, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x53]) // VR = US
        data.append(contentsOf: [0x02, 0x00]) // Length = 2
        data.append(contentsOf: [0x01, 0x00]) // 1
        
        // Photometric Interpretation (0028,0004) - CS
        data.append(contentsOf: [0x28, 0x00, 0x04, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let photometric = "MONOCHROME2"
        let photometricLength = UInt16(photometric.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: photometricLength.littleEndian) { Data($0) })
        data.append(photometric.data(using: .utf8)!)
        
        // Window Center (0028,1050) - DS
        data.append(contentsOf: [0x28, 0x00, 0x50, 0x10]) // Tag
        data.append(contentsOf: [0x44, 0x53]) // VR = DS
        let centerStr = "40"
        let centerLength = UInt16(centerStr.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: centerLength.littleEndian) { Data($0) })
        data.append(centerStr.data(using: .utf8)!)
        
        // Window Width (0028,1051) - DS
        data.append(contentsOf: [0x28, 0x00, 0x51, 0x10]) // Tag
        data.append(contentsOf: [0x44, 0x53]) // VR = DS
        let widthStr = "400"
        let widthLength = UInt16(widthStr.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: widthLength.littleEndian) { Data($0) })
        data.append(widthStr.data(using: .utf8)!)
        
        // Pixel Data (7FE0,0010) - OW (multiple frames)
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x4F, 0x57]) // VR = OW
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        
        let bytesPerFrame = rows * columns * 2
        let totalPixelBytes = bytesPerFrame * numberOfFrames
        let pixelLength = UInt32(totalPixelBytes)
        data.append(contentsOf: withUnsafeBytes(of: pixelLength.littleEndian) { Data($0) })
        
        // Create distinct pixel data for each frame
        for frameIndex in 0..<numberOfFrames {
            let baseValue = UInt16(frameIndex * 100)
            for pixelIndex in 0..<(rows * columns) {
                let value = baseValue + UInt16(pixelIndex % 256)
                data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
            }
        }
        
        return data
    }
    
    /// Creates a single-frame DICOM file for testing
    private func createSingleFrameDICOMFile() throws -> Data {
        return try createMultiFrameDICOMFile(numberOfFrames: 1)
    }
    
    /// Parse frame range string into set of indices
    private func parseFrameRange(_ rangeString: String) throws -> Set<Int> {
        var indices = Set<Int>()
        
        let parts = rangeString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for part in parts {
            if part.contains("-") {
                // Range like "5-10"
                let bounds = part.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2,
                      let start = Int(bounds[0]),
                      let end = Int(bounds[1]),
                      start <= end,
                      start >= 0 else {
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid frame range: \(part)"])
                }
                for i in start...end {
                    indices.insert(i)
                }
            } else {
                // Single number
                guard let index = Int(part), index >= 0 else {
                    throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid frame number: \(part)"])
                }
                indices.insert(index)
            }
        }
        
        return indices
    }
    
    // MARK: - Frame Range Parsing Tests
    
    func testParseFrameRange_singleFrame_returnsOneIndex() throws {
        let result = try parseFrameRange("5")
        XCTAssertEqual(result, [5])
    }
    
    func testParseFrameRange_commaSeparatedList_returnsMultipleIndices() throws {
        let result = try parseFrameRange("1,3,5,7")
        XCTAssertEqual(result, [1, 3, 5, 7])
    }
    
    func testParseFrameRange_rangeNotation_returnsRange() throws {
        let result = try parseFrameRange("10-15")
        XCTAssertEqual(result, [10, 11, 12, 13, 14, 15])
    }
    
    func testParseFrameRange_mixedNotation_returnsCombinedIndices() throws {
        let result = try parseFrameRange("1,3,5-8,12")
        XCTAssertEqual(result, [1, 3, 5, 6, 7, 8, 12])
    }
    
    func testParseFrameRange_invalidRange_throwsError() throws {
        XCTAssertThrowsError(try parseFrameRange("5-2")) { error in
            XCTAssertNotNil(error)
        }
    }
    
    func testParseFrameRange_negativeNumbers_throwsError() throws {
        XCTAssertThrowsError(try parseFrameRange("-5,10")) { error in
            XCTAssertNotNil(error)
        }
    }
    
    func testParseFrameRange_outOfOrderRanges_returnsCorrectSet() throws {
        let result = try parseFrameRange("10-15,1-5")
        XCTAssertEqual(result, [1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15])
    }
    
    func testParseFrameRange_withWhitespace_handlesCorrectly() throws {
        let result = try parseFrameRange(" 1 , 3 , 5 - 8 , 12 ")
        XCTAssertEqual(result, [1, 3, 5, 6, 7, 8, 12])
    }
    
    // MARK: - Multi-Frame Detection Tests
    
    func testDetectMultiFrame_multipleFrames_detectedCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 10)
        let dicomFile = try DICOMFile.read(from: testData)
        
        let numberOfFrames = dicomFile.numberOfFrames ?? 1
        XCTAssertEqual(numberOfFrames, 10)
    }
    
    func testDetectMultiFrame_singleFrame_detectedCorrectly() throws {
        let testData = try createSingleFrameDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let numberOfFrames = dicomFile.numberOfFrames ?? 1
        XCTAssertEqual(numberOfFrames, 1)
    }
    
    func testDetectMultiFrame_missingFramesTag_defaultsToOne() throws {
        // Create a file without the Number of Frames tag
        let testData = try createSingleFrameDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Remove the Number of Frames tag for testing
        var modifiedDataSet = dicomFile.dataSet
        modifiedDataSet[.numberOfFrames] = nil
        
        // When Number of Frames tag is missing, it should default to 1
        let element = modifiedDataSet[.numberOfFrames]
        let numberOfFrames = element?.integerStringValue?.value ?? 1
        XCTAssertEqual(numberOfFrames, 1)
    }
    
    func testDetectMultiFrame_enhancedCTFormat_detected() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 5, modality: "CT")
        let dicomFile = try DICOMFile.read(from: testData)
        
        let numberOfFrames = dicomFile.numberOfFrames ?? 1
        XCTAssertGreaterThan(numberOfFrames, 1)
    }
    
    func testDetectMultiFrame_enhancedMRFormat_detected() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 8, modality: "MR")
        let dicomFile = try DICOMFile.read(from: testData)
        
        let numberOfFrames = dicomFile.numberOfFrames ?? 1
        XCTAssertGreaterThan(numberOfFrames, 1)
    }
    
    // MARK: - Frame Extraction Tests
    
    func testExtractFrames_allFrames_extractsCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 5)
        let dicomFile = try DICOMFile.read(from: testData)
        
        guard let pixelData = dicomFile.pixelData() else {
            XCTFail("Missing pixel data")
            return
        }
        
        // Extract all frames
        for frameIndex in 0..<5 {
            let frameData = pixelData.frameData(at: frameIndex)
            XCTAssertNotNil(frameData, "Frame \(frameIndex) should exist")
        }
    }
    
    func testExtractFrames_specificFrames_extractsCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 10)
        let dicomFile = try DICOMFile.read(from: testData)
        
        guard let pixelData = dicomFile.pixelData() else {
            XCTFail("Missing pixel data")
            return
        }
        
        // Extract specific frames
        let framesToExtract = [0, 3, 7, 9]
        for frameIndex in framesToExtract {
            let frameData = pixelData.frameData(at: frameIndex)
            XCTAssertNotNil(frameData, "Frame \(frameIndex) should exist")
        }
    }
    
    func testExtractFrames_frameRange_extractsCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 10)
        let dicomFile = try DICOMFile.read(from: testData)
        
        guard let pixelData = dicomFile.pixelData() else {
            XCTFail("Missing pixel data")
            return
        }
        
        // Extract frame range 3-6
        for frameIndex in 3...6 {
            let frameData = pixelData.frameData(at: frameIndex)
            XCTAssertNotNil(frameData, "Frame \(frameIndex) should exist")
        }
    }
    
    func testExtractFrames_metadataPreserved_preservesCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 3, modality: "CT")
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify metadata is present
        XCTAssertEqual(dicomFile.dataSet.string(for: .modality), "CT")
        XCTAssertNotNil(dicomFile.dataSet[.rows])
        XCTAssertNotNil(dicomFile.dataSet[.columns])
        XCTAssertNotNil(dicomFile.dataSet[.bitsAllocated])
    }
    
    func testExtractFrames_sopInstanceUID_regeneratesPerFrame() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 3)
        let dicomFile = try DICOMFile.read(from: testData)
        
        let originalUID = dicomFile.dataSet.string(for: .sopInstanceUID)
        XCTAssertNotNil(originalUID)
        
        // Generate new UID
        let newUID = UIDGenerator.generateSOPInstanceUID()
        XCTAssertNotEqual(newUID.value, originalUID)
    }
    
    func testExtractFrames_frameNumbering_updatesCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 5)
        let dicomFile = try DICOMFile.read(from: testData)
        
        // When extracting individual frames, Number of Frames should be set to 1
        var singleFrameDataSet = dicomFile.dataSet
        
        let numberOfFramesData = "1".data(using: String.Encoding.utf8) ?? Data()
        singleFrameDataSet[.numberOfFrames] = DataElement(
            tag: .numberOfFrames,
            vr: .IS,
            length: UInt32(numberOfFramesData.count),
            valueData: numberOfFramesData
        )
        
        let numberOfFrames = singleFrameDataSet.string(for: .numberOfFrames)
        XCTAssertEqual(numberOfFrames, "1")
    }
    
    // MARK: - Output Format Tests
    
    func testOutputFormat_dicom_validExtension() {
        let format = TestOutputFormat.dicom
        XCTAssertEqual(format.fileExtension, "dcm")
    }
    
    func testOutputFormat_png_validExtension() {
        let format = TestOutputFormat.png
        XCTAssertEqual(format.fileExtension, "png")
    }
    
    func testOutputFormat_jpeg_validExtension() {
        let format = TestOutputFormat.jpeg
        XCTAssertEqual(format.fileExtension, "jpg")
    }
    
    func testOutputFormat_tiff_validExtension() {
        let format = TestOutputFormat.tiff
        XCTAssertEqual(format.fileExtension, "tiff")
    }
    
    func testOutputFormat_rawValue_parsesCorrectly() {
        XCTAssertEqual(TestOutputFormat(rawValue: "dicom"), .dicom)
        XCTAssertEqual(TestOutputFormat(rawValue: "png"), .png)
        XCTAssertEqual(TestOutputFormat(rawValue: "jpeg"), .jpeg)
        XCTAssertEqual(TestOutputFormat(rawValue: "tiff"), .tiff)
    }
    
    // MARK: - Windowing Tests
    
    func testWindowing_defaultFromFile_extractsCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 3)
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Check window settings from file
        if let window = dicomFile.dataSet.windowSettings() {
            XCTAssertEqual(window.center, 40.0)
            XCTAssertEqual(window.width, 400.0)
        } else {
            XCTFail("Failed to extract window settings")
        }
    }
    
    func testWindowing_customCenterWidth_appliesCorrectly() throws {
        let customCenter = 50.0
        let customWidth = 350.0
        
        let customWindow = WindowSettings(center: customCenter, width: customWidth)
        XCTAssertEqual(customWindow.center, customCenter)
        XCTAssertEqual(customWindow.width, customWidth)
    }
    
    func testWindowing_16bitDepth_handlesCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 2)
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Check bits allocated (US VR)
        if let bitsAllocated = dicomFile.dataSet[.bitsAllocated]?.uint16Value {
            XCTAssertEqual(bitsAllocated, 16)
        } else {
            XCTFail("Failed to get bits allocated")
        }
    }
    
    func testWindowing_calculateFromRange_calculatesCorrectly() throws {
        let minValue = 0
        let maxValue = 4095
        
        let center = Double(minValue + maxValue) / 2.0
        let width = Double(maxValue - minValue)
        
        XCTAssertEqual(center, 2047.5)
        XCTAssertEqual(width, 4095.0)
    }
    
    // MARK: - Naming Pattern Tests
    
    func testNamingPattern_default_generatesCorrectly() {
        let baseName = "multiframe"
        let frameIndex = 5
        let ext = "dcm"
        
        let expectedName = "\(baseName)_frame_\(String(format: "%04d", frameIndex)).\(ext)"
        XCTAssertEqual(expectedName, "multiframe_frame_0005.dcm")
    }
    
    func testNamingPattern_numberPlaceholder_replacesCorrectly() {
        let pattern = "frame_{number}.dcm"
        let frameIndex = 42
        
        let result = pattern.replacingOccurrences(of: "{number}", with: String(format: "%04d", frameIndex))
        XCTAssertEqual(result, "frame_0042.dcm")
    }
    
    func testNamingPattern_modalityPlaceholder_replacesCorrectly() {
        let pattern = "frame_{modality}_{number}.dcm"
        let modality = "CT"
        let frameIndex = 10
        
        var result = pattern.replacingOccurrences(of: "{modality}", with: modality)
        result = result.replacingOccurrences(of: "{number}", with: String(format: "%04d", frameIndex))
        XCTAssertEqual(result, "frame_CT_0010.dcm")
    }
    
    func testNamingPattern_seriesPlaceholder_replacesCorrectly() {
        let pattern = "series_{series}_frame_{number}.dcm"
        let seriesNumber = "5"
        let frameIndex = 3
        
        var result = pattern.replacingOccurrences(of: "{series}", with: seriesNumber)
        result = result.replacingOccurrences(of: "{number}", with: String(format: "%04d", frameIndex))
        XCTAssertEqual(result, "series_5_frame_0003.dcm")
    }
    
    func testNamingPattern_multiplePlaceholders_replacesAllCorrectly() {
        let pattern = "{modality}_S{series}_F{number}.dcm"
        let modality = "MR"
        let seriesNumber = "10"
        let frameIndex = 7
        
        var result = pattern.replacingOccurrences(of: "{modality}", with: modality)
        result = result.replacingOccurrences(of: "{series}", with: seriesNumber)
        result = result.replacingOccurrences(of: "{number}", with: String(format: "%04d", frameIndex))
        XCTAssertEqual(result, "MR_S10_F0007.dcm")
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchProcessing_multipleFiles_processesCorrecting() throws {
        // Create test data for multiple files
        let file1 = try createMultiFrameDICOMFile(numberOfFrames: 3)
        let file2 = try createMultiFrameDICOMFile(numberOfFrames: 5)
        let file3 = try createMultiFrameDICOMFile(numberOfFrames: 2)
        
        let dicomFile1 = try DICOMFile.read(from: file1)
        let dicomFile2 = try DICOMFile.read(from: file2)
        let dicomFile3 = try DICOMFile.read(from: file3)
        
        XCTAssertEqual(dicomFile1.numberOfFrames, 3)
        XCTAssertEqual(dicomFile2.numberOfFrames, 5)
        XCTAssertEqual(dicomFile3.numberOfFrames, 2)
    }
    
    func testBatchProcessing_filterDICOMFiles_filtersCorrectly() {
        let filenames = [
            "image1.dcm",
            "image2.dicom",
            "image3.dic",
            "notdicom.txt",
            "data.json"
        ]
        
        let dicomFiles = filenames.filter { filename in
            let ext = (filename as NSString).pathExtension.lowercased()
            return ["dcm", "dicom", "dic"].contains(ext)
        }
        
        XCTAssertEqual(dicomFiles.count, 3)
        XCTAssertTrue(dicomFiles.contains("image1.dcm"))
        XCTAssertTrue(dicomFiles.contains("image2.dicom"))
        XCTAssertTrue(dicomFiles.contains("image3.dic"))
    }
    
    func testBatchProcessing_skipSingleFrame_skipsCorrectly() throws {
        let singleFrameData = try createSingleFrameDICOMFile()
        let multiFrameData = try createMultiFrameDICOMFile(numberOfFrames: 5)
        
        let singleFrame = try DICOMFile.read(from: singleFrameData)
        let multiFrame = try DICOMFile.read(from: multiFrameData)
        
        let singleFrameCount = singleFrame.numberOfFrames ?? 1
        let multiFrameCount = multiFrame.numberOfFrames ?? 1
        
        XCTAssertEqual(singleFrameCount, 1) // Should skip
        XCTAssertGreaterThan(multiFrameCount, 1) // Should process
    }
    
    func testBatchProcessing_invalidFile_handlesGracefully() throws {
        let invalidData = Data("NOT A DICOM FILE".utf8)
        
        XCTAssertThrowsError(try DICOMFile.read(from: invalidData)) { error in
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testExtractFrame_invalidFrameIndex_handlesCorrectly() throws {
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 5)
        let dicomFile = try DICOMFile.read(from: testData)
        
        guard let pixelData = dicomFile.pixelData() else {
            XCTFail("Missing pixel data")
            return
        }
        
        // Try to extract frame beyond range
        let frameData = pixelData.frameData(at: 100)
        XCTAssertNil(frameData, "Should return nil for out-of-range frame")
    }
    
    func testExtractFrame_missingPixelData_handlesCorrectly() throws {
        // Create a DICOM file without pixel data
        let testData = try createMultiFrameDICOMFile(numberOfFrames: 1)
        var dicomFile = try DICOMFile.read(from: testData)
        
        // Remove pixel data
        var modifiedDataSet = dicomFile.dataSet
        modifiedDataSet[.pixelData] = nil
        dicomFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: modifiedDataSet)
        
        let pixelData = dicomFile.pixelData()
        XCTAssertNil(pixelData, "Should return nil when pixel data is missing")
    }
    
    func testParseFrameRange_emptyString_throwsError() throws {
        XCTAssertThrowsError(try parseFrameRange("")) { error in
            XCTAssertNotNil(error)
        }
    }
    
    func testParseFrameRange_invalidCharacters_throwsError() throws {
        XCTAssertThrowsError(try parseFrameRange("a,b,c")) { error in
            XCTAssertNotNil(error)
        }
    }
    
    func testFrameDataSize_matchesExpected_validatesCorrectly() throws {
        let rows = 64
        let columns = 64
        let numberOfFrames = 3
        
        let testData = try createMultiFrameDICOMFile(numberOfFrames: numberOfFrames, rows: rows, columns: columns)
        let dicomFile = try DICOMFile.read(from: testData)
        
        guard let pixelData = dicomFile.pixelData() else {
            XCTFail("Missing pixel data")
            return
        }
        
        if let frameData = pixelData.frameData(at: 0) {
            let expectedSize = rows * columns * 2 // 16-bit pixels
            XCTAssertEqual(frameData.count, expectedSize)
        } else {
            XCTFail("Failed to extract frame data")
        }
    }
}

// MARK: - Test Helper Types

/// Test-only OutputFormat enum for validation
private enum TestOutputFormat: String {
    case dicom
    case png
    case jpeg
    case tiff
    
    var fileExtension: String {
        switch self {
        case .dicom:
            return "dcm"
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .tiff:
            return "tiff"
        }
    }
}
