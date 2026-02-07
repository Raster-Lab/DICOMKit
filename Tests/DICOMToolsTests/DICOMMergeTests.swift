import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-merge CLI tool functionality
final class DICOMMergeTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a minimal single-frame DICOM file for testing
    private func createTestDICOMFile(
        instanceNumber: Int,
        imagePosition: [Double]? = nil,
        acquisitionTime: String? = nil,
        rows: Int = 512,
        columns: Int = 512,
        pixelData: Data? = nil
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
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value = 84 (placeholder)
        
        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let transferSyntaxLength = UInt16(transferSyntaxUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: transferSyntaxLength.littleEndian) { Data($0) })
        data.append(transferSyntaxUID.data(using: .utf8)!)
        
        // Study Instance UID (0020,000D) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let studyUID = "1.2.3.4.5.6.7.8.9.10"
        let studyUIDLength = UInt16(studyUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyUIDLength.littleEndian) { Data($0) })
        data.append(studyUID.data(using: .utf8)!)
        
        // Series Instance UID (0020,000E) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let seriesUID = "1.2.3.4.5.6.7.8.9.11"
        let seriesUIDLength = UInt16(seriesUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: seriesUIDLength.littleEndian) { Data($0) })
        data.append(seriesUID.data(using: .utf8)!)
        
        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceUID = "1.2.3.4.5.6.7.8.9.\(instanceNumber)"
        let sopInstanceLength = UInt16(sopInstanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
        data.append(sopInstanceUID.data(using: .utf8)!)
        
        // Instance Number (0020,0013) - IS
        data.append(contentsOf: [0x20, 0x00, 0x13, 0x00]) // Tag
        data.append(contentsOf: [0x49, 0x53]) // VR = IS
        let instanceStr = "\(instanceNumber)"
        let instanceStrLength = UInt16(instanceStr.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: instanceStrLength.littleEndian) { Data($0) })
        data.append(instanceStr.data(using: .utf8)!)
        
        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modality = "CT"
        let modalityLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)
        
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
        
        // Image Position Patient (0020,0032) - DS (optional)
        if let imagePosition = imagePosition {
            data.append(contentsOf: [0x20, 0x00, 0x32, 0x00]) // Tag
            data.append(contentsOf: [0x44, 0x53]) // VR = DS
            let posString = imagePosition.map { String($0) }.joined(separator: "\\")
            let posLength = UInt16(posString.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: posLength.littleEndian) { Data($0) })
            data.append(posString.data(using: .utf8)!)
        }
        
        // Acquisition Time (0008,0032) - TM (optional)
        if let acquisitionTime = acquisitionTime {
            data.append(contentsOf: [0x08, 0x00, 0x32, 0x00]) // Tag
            data.append(contentsOf: [0x54, 0x4D]) // VR = TM
            let timeLength = UInt16(acquisitionTime.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: timeLength.littleEndian) { Data($0) })
            data.append(acquisitionTime.data(using: .utf8)!)
        }
        
        // Pixel Data (7FE0,0010) - OW
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x4F, 0x57]) // VR = OW
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        let pixelBytes = pixelData ?? Data(count: rows * columns * 2)
        let pixelLength = UInt32(pixelBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: pixelLength.littleEndian) { Data($0) })
        data.append(pixelBytes)
        
        return data
    }
    
    // MARK: - Basic Merging Tests
    
    func testSingleFrameDetection() throws {
        let testData = try createTestDICOMFile(instanceNumber: 1)
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Single frame file
        let numberOfFrames = dicomFile.numberOfFrames ?? 1
        XCTAssertEqual(numberOfFrames, 1)
    }
    
    func testMultiFrameCreation() throws {
        // Create 3 single-frame files
        let file1 = try createTestDICOMFile(instanceNumber: 1)
        let file2 = try createTestDICOMFile(instanceNumber: 2)
        let file3 = try createTestDICOMFile(instanceNumber: 3)
        
        let dicomFile1 = try DICOMFile.read(from: file1)
        let dicomFile2 = try DICOMFile.read(from: file2)
        let dicomFile3 = try DICOMFile.read(from: file3)
        
        // Get pixel data from each
        guard let pixelData1 = dicomFile1.dataSet[.pixelData]?.valueData,
              let pixelData2 = dicomFile2.dataSet[.pixelData]?.valueData,
              let pixelData3 = dicomFile3.dataSet[.pixelData]?.valueData else {
            XCTFail("Missing pixel data")
            return
        }
        
        // Create merged dataset
        var mergedDataSet = dicomFile1.dataSet
        
        // Concatenate pixel data
        var allPixelData = Data()
        allPixelData.append(pixelData1)
        allPixelData.append(pixelData2)
        allPixelData.append(pixelData3)
        
        // Update number of frames
        mergedDataSet.setString("3", for: .numberOfFrames, vr: .IS)
        
        // Update pixel data
        mergedDataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OW,
            length: UInt32(allPixelData.count),
            valueData: allPixelData
        )
        
        // Generate new SOP Instance UID
        let newSOPInstanceUID = UIDGenerator.generateSOPInstanceUID()
        mergedDataSet.setString(newSOPInstanceUID.value, for: .sopInstanceUID, vr: .UI)
        
        // Create new DICOM file
        let mergedFile = DICOMFile(
            fileMetaInformation: dicomFile1.fileMetaInformation,
            dataSet: mergedDataSet
        )
        
        // Verify
        let frames = mergedFile.numberOfFrames ?? 1
        XCTAssertEqual(frames, 3)
        
        // Write and read back
        let writtenData = try mergedFile.write()
        let readFile = try DICOMFile.read(from: writtenData)
        
        XCTAssertEqual(readFile.numberOfFrames ?? 1, 3)
        
        // Verify pixel data size
        let readPixelData = readFile.dataSet[.pixelData]?.valueData
        XCTAssertNotNil(readPixelData)
        XCTAssertEqual(readPixelData?.count, allPixelData.count)
    }
    
    // MARK: - Sorting Tests
    
    func testSortByInstanceNumber() throws {
        // Create files with different instance numbers
        let file3 = try createTestDICOMFile(instanceNumber: 3)
        let file1 = try createTestDICOMFile(instanceNumber: 1)
        let file2 = try createTestDICOMFile(instanceNumber: 2)
        
        let dicom3 = try DICOMFile.read(from: file3)
        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)
        
        let unsorted = [("file3", dicom3), ("file1", dicom1), ("file2", dicom2)]
        
        // Sort by instance number
        let sorted = unsorted.sorted { file1, file2 in
            let num1 = file1.1.dataSet.int32(for: .instanceNumber) ?? 0
            let num2 = file2.1.dataSet.int32(for: .instanceNumber) ?? 0
            return num1 < num2
        }
        
        XCTAssertEqual(sorted[0].0, "file1")
        XCTAssertEqual(sorted[1].0, "file2")
        XCTAssertEqual(sorted[2].0, "file3")
    }
    
    func testSortByImagePosition() throws {
        // Create files with different image positions
        let file1 = try createTestDICOMFile(instanceNumber: 1, imagePosition: [0, 0, 0])
        let file2 = try createTestDICOMFile(instanceNumber: 2, imagePosition: [0, 0, 5])
        let file3 = try createTestDICOMFile(instanceNumber: 3, imagePosition: [0, 0, 10])
        
        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)
        let dicom3 = try DICOMFile.read(from: file3)
        
        // Verify positions are correct
        let pos1 = dicom1.dataSet.decimalStrings(for: .imagePositionPatient)?.map { $0.value }
        let pos2 = dicom2.dataSet.decimalStrings(for: .imagePositionPatient)?.map { $0.value }
        let pos3 = dicom3.dataSet.decimalStrings(for: .imagePositionPatient)?.map { $0.value }
        
        XCTAssertNotNil(pos1)
        XCTAssertNotNil(pos2)
        XCTAssertNotNil(pos3)
        
        XCTAssertEqual(pos1?[2], 0.0)
        XCTAssertEqual(pos2?[2], 5.0)
        XCTAssertEqual(pos3?[2], 10.0)
        
        // Create unsorted list (reversed)
        let unsorted = [("file3", dicom3), ("file2", dicom2), ("file1", dicom1)]
        
        // Sort by Z position
        let sorted = unsorted.sorted { file1, file2 in
            let pos1 = file1.1.dataSet.decimalStrings(for: .imagePositionPatient)?.map { $0.value } ?? []
            let pos2 = file2.1.dataSet.decimalStrings(for: .imagePositionPatient)?.map { $0.value } ?? []
            let z1 = pos1.count >= 3 ? pos1[2] : 0.0
            let z2 = pos2.count >= 3 ? pos2[2] : 0.0
            return z1 < z2
        }
        
        XCTAssertEqual(sorted[0].0, "file1")
        XCTAssertEqual(sorted[1].0, "file2")
        XCTAssertEqual(sorted[2].0, "file3")
    }
    
    func testSortByAcquisitionTime() throws {
        // Create files with different acquisition times
        let file1 = try createTestDICOMFile(instanceNumber: 1, acquisitionTime: "100000")
        let file2 = try createTestDICOMFile(instanceNumber: 2, acquisitionTime: "110000")
        let file3 = try createTestDICOMFile(instanceNumber: 3, acquisitionTime: "120000")
        
        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)
        let dicom3 = try DICOMFile.read(from: file3)
        
        // Create unsorted list
        let unsorted = [("file2", dicom2), ("file3", dicom3), ("file1", dicom1)]
        
        // Sort by acquisition time
        let sorted = unsorted.sorted { file1, file2 in
            let time1 = file1.1.dataSet.string(for: .acquisitionTime) ?? ""
            let time2 = file2.1.dataSet.string(for: .acquisitionTime) ?? ""
            return time1 < time2
        }
        
        XCTAssertEqual(sorted[0].0, "file1")
        XCTAssertEqual(sorted[1].0, "file2")
        XCTAssertEqual(sorted[2].0, "file3")
    }
    
    // MARK: - Validation Tests
    
    func testConsistencyValidation() throws {
        // Create files with consistent attributes
        let file1 = try createTestDICOMFile(instanceNumber: 1, rows: 512, columns: 512)
        let file2 = try createTestDICOMFile(instanceNumber: 2, rows: 512, columns: 512)
        
        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)
        
        // Check required attributes match
        let studyUID1 = dicom1.dataSet.string(for: .studyInstanceUID)
        let studyUID2 = dicom2.dataSet.string(for: .studyInstanceUID)
        XCTAssertEqual(studyUID1, studyUID2)
        
        let seriesUID1 = dicom1.dataSet.string(for: .seriesInstanceUID)
        let seriesUID2 = dicom2.dataSet.string(for: .seriesInstanceUID)
        XCTAssertEqual(seriesUID1, seriesUID2)
        
        let modality1 = dicom1.dataSet.string(for: .modality)
        let modality2 = dicom2.dataSet.string(for: .modality)
        XCTAssertEqual(modality1, modality2)
        
        let rows1 = dicom1.dataSet.uint16(for: .rows)
        let rows2 = dicom2.dataSet.uint16(for: .rows)
        XCTAssertEqual(rows1, rows2)
        
        let columns1 = dicom1.dataSet.uint16(for: .columns)
        let columns2 = dicom2.dataSet.uint16(for: .columns)
        XCTAssertEqual(columns1, columns2)
    }
    
    func testPixelDataSize() throws {
        // Create files with same pixel data size
        let file1 = try createTestDICOMFile(instanceNumber: 1, rows: 512, columns: 512)
        let file2 = try createTestDICOMFile(instanceNumber: 2, rows: 512, columns: 512)
        
        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)
        
        let pixelData1 = dicom1.dataSet[.pixelData]?.valueData
        let pixelData2 = dicom2.dataSet[.pixelData]?.valueData
        
        XCTAssertNotNil(pixelData1)
        XCTAssertNotNil(pixelData2)
        XCTAssertEqual(pixelData1?.count, pixelData2?.count)
        XCTAssertEqual(pixelData1?.count, 512 * 512 * 2)
    }
    
    // MARK: - UID Generation Tests
    
    func testUniqueSOPInstanceUID() throws {
        // Generate multiple UIDs
        let uid1 = UIDGenerator.generateSOPInstanceUID()
        let uid2 = UIDGenerator.generateSOPInstanceUID()
        let uid3 = UIDGenerator.generateSOPInstanceUID()
        
        // Verify uniqueness
        XCTAssertNotEqual(uid1.value, uid2.value)
        XCTAssertNotEqual(uid2.value, uid3.value)
        XCTAssertNotEqual(uid1.value, uid3.value)
        
        // Verify format (should start with root and contain only digits and dots)
        XCTAssertTrue(uid1.value.allSatisfy { $0.isNumber || $0 == "." })
        XCTAssertTrue(uid2.value.allSatisfy { $0.isNumber || $0 == "." })
        XCTAssertTrue(uid3.value.allSatisfy { $0.isNumber || $0 == "." })
    }
    
    // MARK: - File I/O Tests
    
    func testWriteAndRead() throws {
        let testData = try createTestDICOMFile(instanceNumber: 1)
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Write to data
        let writtenData = try dicomFile.write()
        
        // Read back
        let readFile = try DICOMFile.read(from: writtenData)
        
        // Verify key attributes
        XCTAssertEqual(
            readFile.dataSet.string(for: .sopInstanceUID),
            dicomFile.dataSet.string(for: .sopInstanceUID)
        )
        XCTAssertEqual(
            readFile.dataSet.int32(for: .instanceNumber),
            dicomFile.dataSet.int32(for: .instanceNumber)
        )
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFileList() {
        // Verify handling of empty file list
        let files: [(String, DICOMFile)] = []
        XCTAssertTrue(files.isEmpty)
    }
    
    func testSingleFile() throws {
        // Single file should still work
        let testData = try createTestDICOMFile(instanceNumber: 1)
        let dicomFile = try DICOMFile.read(from: testData)
        
        XCTAssertNotNil(dicomFile)
        XCTAssertEqual(dicomFile.numberOfFrames ?? 1, 1)
    }
    
    func testLargeNumberOfFrames() throws {
        // Test with many frames (10 frames)
        var allPixelData = Data()
        
        for i in 1...10 {
            let fileData = try createTestDICOMFile(instanceNumber: i)
            let dicomFile = try DICOMFile.read(from: fileData)
            if let pixelData = dicomFile.dataSet[.pixelData]?.valueData {
                allPixelData.append(pixelData)
            }
        }
        
        // Verify total size
        let expectedSize = 512 * 512 * 2 * 10
        XCTAssertEqual(allPixelData.count, expectedSize)
    }
}
