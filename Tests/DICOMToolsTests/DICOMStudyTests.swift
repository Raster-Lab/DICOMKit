import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-study CLI tool functionality
/// Note: Tests focus on DICOMKit/DICOMCore functionality used by the tool
final class DICOMStudyTests: XCTestCase {

    // MARK: - Test Helpers
    
    private var testDirectory: String!
    
    override func setUp() {
        super.setUp()
        testDirectory = NSTemporaryDirectory().appending("/dicom-study-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: testDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        if let testDir = testDirectory {
            try? FileManager.default.removeItem(atPath: testDir)
        }
        super.tearDown()
    }
    
    /// Creates a minimal valid DICOM file for testing
    private func createTestDICOMFile(
        studyUID: String = "1.2.3.4.5",
        seriesUID: String = "1.2.3.4.5.1",
        instanceUID: String = "1.2.3.4.5.1.1",
        studyDescription: String = "Test Study",
        seriesDescription: String = "Test Series",
        patientName: String = "DOE^JOHN",
        patientID: String = "12345",
        modality: String = "CT",
        instanceNumber: String = "1"
    ) throws -> Data {
        var data = Data()

        // Add 128-byte preamble
        data.append(Data(count: 128))

        // Add DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"

        // File Meta Information Group Length (0002,0000)
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x80, 0x00, 0x00, 0x00]) // Value = 128

        // Transfer Syntax UID (0002,0010)
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1"
        let tsBytes = transferSyntaxUID.data(using: .utf8)!
        let tsLength = UInt16(tsBytes.count % 2 == 0 ? tsBytes.count : tsBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(tsBytes)
        if tsBytes.count % 2 != 0 { data.append(0x00) }

        // Study Instance UID (0020,000D)
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let studyUIDBytes = studyUID.data(using: .utf8)!
        let studyUIDLength = UInt16(studyUIDBytes.count % 2 == 0 ? studyUIDBytes.count : studyUIDBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: studyUIDLength.littleEndian) { Data($0) })
        data.append(studyUIDBytes)
        if studyUIDBytes.count % 2 != 0 { data.append(0x00) }

        // Series Instance UID (0020,000E)
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let seriesUIDBytes = seriesUID.data(using: .utf8)!
        let seriesUIDLength = UInt16(seriesUIDBytes.count % 2 == 0 ? seriesUIDBytes.count : seriesUIDBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: seriesUIDLength.littleEndian) { Data($0) })
        data.append(seriesUIDBytes)
        if seriesUIDBytes.count % 2 != 0 { data.append(0x00) }

        // SOP Instance UID (0008,0018)
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceUIDBytes = instanceUID.data(using: .utf8)!
        let sopInstanceUIDLength = UInt16(sopInstanceUIDBytes.count % 2 == 0 ? sopInstanceUIDBytes.count : sopInstanceUIDBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: sopInstanceUIDLength.littleEndian) { Data($0) })
        data.append(sopInstanceUIDBytes)
        if sopInstanceUIDBytes.count % 2 != 0 { data.append(0x00) }

        // Study Description (0008,1030)
        data.append(contentsOf: [0x08, 0x00, 0x30, 0x10])
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let studyDescBytes = studyDescription.data(using: .utf8)!
        let studyDescLength = UInt16(studyDescBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: studyDescLength.littleEndian) { Data($0) })
        data.append(studyDescBytes)

        // Series Description (0008,103E)
        data.append(contentsOf: [0x08, 0x00, 0x3E, 0x10])
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let seriesDescBytes = seriesDescription.data(using: .utf8)!
        let seriesDescLength = UInt16(seriesDescBytes.count % 2 == 0 ? seriesDescBytes.count : seriesDescBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: seriesDescLength.littleEndian) { Data($0) })
        data.append(seriesDescBytes)
        if seriesDescBytes.count % 2 != 0 { data.append(0x20) }

        // Patient Name (0010,0010)
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x50, 0x4E]) // VR = PN
        let patientNameBytes = patientName.data(using: .utf8)!
        let patientNameLength = UInt16(patientNameBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: patientNameLength.littleEndian) { Data($0) })
        data.append(patientNameBytes)

        // Patient ID (0010,0020)
        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00])
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let patientIDBytes = patientID.data(using: .utf8)!
        let patientIDLength = UInt16(patientIDBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: patientIDLength.littleEndian) { Data($0) })
        data.append(patientIDBytes)

        // Modality (0008,0060)
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00])
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modalityBytes = modality.data(using: .utf8)!
        let modalityLength = UInt16(modalityBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modalityBytes)

        // Instance Number (0020,0013)
        data.append(contentsOf: [0x20, 0x00, 0x13, 0x00])
        data.append(contentsOf: [0x49, 0x53]) // VR = IS
        let instanceNumberBytes = instanceNumber.data(using: .utf8)!
        let instanceNumberLength = UInt16(instanceNumberBytes.count)
        data.append(contentsOf: withUnsafeBytes(of: instanceNumberLength.littleEndian) { Data($0) })
        data.append(instanceNumberBytes)

        return data
    }

    // MARK: - Study Organization Tests

    func testStudyOrganizationBasic() throws {
        // Create test files with different study UIDs
        let study1File1 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.1")
        let study1File2 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.2")
        let study2File1 = try createTestDICOMFile(studyUID: "1.2.3.4.6", seriesUID: "1.2.3.4.6.1", instanceUID: "1.2.3.4.6.1.1")

        let inputDir = testDirectory + "/input"
        try FileManager.default.createDirectory(atPath: inputDir, withIntermediateDirectories: true, attributes: nil)
        
        try study1File1.write(to: URL(fileURLWithPath: "\(inputDir)/file1.dcm"))
        try study1File2.write(to: URL(fileURLWithPath: "\(inputDir)/file2.dcm"))
        try study2File1.write(to: URL(fileURLWithPath: "\(inputDir)/file3.dcm"))

        // Test that files are DICOM files
        let file1Data = try Data(contentsOf: URL(fileURLWithPath: "\(inputDir)/file1.dcm"))
        let dicomFile1 = try DICOMFile.read(from: file1Data)
        
        let studyUID1 = dicomFile1.dataSet.string(for: Tag.studyInstanceUID)
        XCTAssertEqual(studyUID1, "1.2.3.4.5")
    }

    func testStudyMetadataExtraction() throws {
        let testData = try createTestDICOMFile(
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.1",
            studyDescription: "Test Study",
            patientName: "DOE^JOHN",
            patientID: "12345"
        )

        let file = try DICOMFile.read(from: testData)
        
        XCTAssertEqual(file.dataSet.string(for: Tag.studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(file.dataSet.string(for: Tag.seriesInstanceUID), "1.2.3.4.5.1")
        XCTAssertEqual(file.dataSet.string(for: Tag.studyDescription), "Test Study")
        XCTAssertEqual(file.dataSet.string(for: Tag.patientName), "DOE^JOHN")
        XCTAssertEqual(file.dataSet.string(for: Tag.patientID), "12345")
    }

    func testMultipleSeriesInStudy() throws {
        let series1File1 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.1", instanceNumber: "1")
        let series1File2 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.2", instanceNumber: "2")
        let series2File1 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.2", instanceUID: "1.2.3.4.5.2.1", instanceNumber: "1")

        let file1 = try DICOMFile.read(from: series1File1)
        let file2 = try DICOMFile.read(from: series1File2)
        let file3 = try DICOMFile.read(from: series2File1)

        XCTAssertEqual(file1.dataSet.string(for: Tag.studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(file2.dataSet.string(for: Tag.studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(file3.dataSet.string(for: Tag.studyInstanceUID), "1.2.3.4.5")

        XCTAssertEqual(file1.dataSet.string(for: Tag.seriesInstanceUID), "1.2.3.4.5.1")
        XCTAssertEqual(file2.dataSet.string(for: Tag.seriesInstanceUID), "1.2.3.4.5.1")
        XCTAssertEqual(file3.dataSet.string(for: Tag.seriesInstanceUID), "1.2.3.4.5.2")
    }

    // MARK: - Metadata Summary Tests

    func testMetadataStringExtraction() throws {
        let testData = try createTestDICOMFile()
        let file = try DICOMFile.read(from: testData)
        
        XCTAssertNotNil(file.dataSet.string(for: Tag.studyInstanceUID))
        XCTAssertNotNil(file.dataSet.string(for: Tag.seriesInstanceUID))
        XCTAssertNotNil(file.dataSet.string(for: Tag.sopInstanceUID))
        XCTAssertNotNil(file.dataSet.string(for: Tag.modality))
    }

    func testModalityExtraction() throws {
        let ctData = try createTestDICOMFile(modality: "CT")
        let mrData = try createTestDICOMFile(modality: "MR")
        let usData = try createTestDICOMFile(modality: "US")

        let ctFile = try DICOMFile.read(from: ctData)
        let mrFile = try DICOMFile.read(from: mrData)
        let usFile = try DICOMFile.read(from: usData)

        XCTAssertEqual(ctFile.dataSet.string(for: Tag.modality), "CT")
        XCTAssertEqual(mrFile.dataSet.string(for: Tag.modality), "MR")
        XCTAssertEqual(usFile.dataSet.string(for: Tag.modality), "US")
    }

    // MARK: - Instance Numbering Tests

    func testInstanceNumberExtraction() throws {
        let instance1 = try createTestDICOMFile(instanceNumber: "1")
        let instance10 = try createTestDICOMFile(instanceNumber: "10")
        let instance100 = try createTestDICOMFile(instanceNumber: "100")

        let file1 = try DICOMFile.read(from: instance1)
        let file10 = try DICOMFile.read(from: instance10)
        let file100 = try DICOMFile.read(from: instance100)

        XCTAssertEqual(file1.dataSet.string(for: Tag.instanceNumber), "1")
        XCTAssertEqual(file10.dataSet.string(for: Tag.instanceNumber), "10")
        XCTAssertEqual(file100.dataSet.string(for: Tag.instanceNumber), "100")
    }

    func testInstanceNumberSequence() throws {
        var files: [DICOMFile] = []
        for i in 1...5 {
            let data = try createTestDICOMFile(instanceNumber: "\(i)")
            let file = try DICOMFile.read(from: data)
            files.append(file)
        }

        for (index, file) in files.enumerated() {
            let instanceNumber = file.dataSet.string(for: Tag.instanceNumber)
            XCTAssertEqual(instanceNumber, "\(index + 1)")
        }
    }

    // MARK: - Completeness Check Tests

    func testCompleteSeriesDetection() throws {
        var instances: [Data] = []
        for i in 1...10 {
            let data = try createTestDICOMFile(
                studyUID: "1.2.3.4.5",
                seriesUID: "1.2.3.4.5.1",
                instanceNumber: "\(i)"
            )
            instances.append(data)
        }

        // Verify all instances have sequential numbers
        var instanceNumbers: [Int] = []
        for data in instances {
            let file = try DICOMFile.read(from: data)
            if let numStr = file.dataSet.string(for: Tag.instanceNumber),
               let num = Int(numStr) {
                instanceNumbers.append(num)
            }
        }

        instanceNumbers.sort()
        XCTAssertEqual(instanceNumbers.count, 10)
        XCTAssertEqual(instanceNumbers.first, 1)
        XCTAssertEqual(instanceNumbers.last, 10)
    }

    func testMissingInstanceDetection() throws {
        // Create instances with gap in numbering (missing 5)
        let instanceNumbers = [1, 2, 3, 4, 6, 7, 8, 9, 10]
        var instances: [Data] = []
        
        for num in instanceNumbers {
            let data = try createTestDICOMFile(
                studyUID: "1.2.3.4.5",
                seriesUID: "1.2.3.4.5.1",
                instanceNumber: "\(num)"
            )
            instances.append(data)
        }

        var extractedNumbers: [Int] = []
        for data in instances {
            let file = try DICOMFile.read(from: data)
            if let numStr = file.dataSet.string(for: Tag.instanceNumber),
               let num = Int(numStr) {
                extractedNumbers.append(num)
            }
        }

        extractedNumbers.sort()
        
        // Check that 5 is missing
        let expectedRange = Set(1...10)
        let actualSet = Set(extractedNumbers)
        let missing = expectedRange.subtracting(actualSet)
        
        XCTAssertEqual(missing, [5])
    }

    // MARK: - Statistics Tests

    func testFileMetadataExtraction() throws {
        let data = try createTestDICOMFile()
        let file = try DICOMFile.read(from: data)
        
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertNotNil(file.dataSet.string(for: Tag.studyInstanceUID))
    }

    func testMultipleModalityCounting() throws {
        let modalities = ["CT", "MR", "US", "CT", "MR", "CT"]
        var modalityCount: [String: Int] = [:]
        
        for modality in modalities {
            modalityCount[modality, default: 0] += 1
        }
        
        XCTAssertEqual(modalityCount["CT"], 3)
        XCTAssertEqual(modalityCount["MR"], 2)
        XCTAssertEqual(modalityCount["US"], 1)
    }

    // MARK: - Comparison Tests

    func testStudyComparison() throws {
        let study1Series1 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.1")
        let study1Series2 = try createTestDICOMFile(studyUID: "1.2.3.4.5", seriesUID: "1.2.3.4.5.2")
        
        let study2Series1 = try createTestDICOMFile(studyUID: "1.2.3.4.6", seriesUID: "1.2.3.4.6.1")

        let file1 = try DICOMFile.read(from: study1Series1)
        let file2 = try DICOMFile.read(from: study1Series2)
        let file3 = try DICOMFile.read(from: study2Series1)

        let study1UID = file1.dataSet.string(for: Tag.studyInstanceUID)
        let study2UID = file3.dataSet.string(for: Tag.studyInstanceUID)

        XCTAssertNotEqual(study1UID, study2UID)
        XCTAssertEqual(file1.dataSet.string(for: Tag.studyInstanceUID), file2.dataSet.string(for: Tag.studyInstanceUID))
    }

    func testSeriesComparison() throws {
        let series1Instance1 = try createTestDICOMFile(seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.1")
        let series1Instance2 = try createTestDICOMFile(seriesUID: "1.2.3.4.5.1", instanceUID: "1.2.3.4.5.1.2")
        let series2Instance1 = try createTestDICOMFile(seriesUID: "1.2.3.4.5.2", instanceUID: "1.2.3.4.5.2.1")

        let file1 = try DICOMFile.read(from: series1Instance1)
        let file2 = try DICOMFile.read(from: series1Instance2)
        let file3 = try DICOMFile.read(from: series2Instance1)

        XCTAssertEqual(file1.dataSet.string(for: Tag.seriesInstanceUID), file2.dataSet.string(for: Tag.seriesInstanceUID))
        XCTAssertNotEqual(file1.dataSet.string(for: Tag.seriesInstanceUID), file3.dataSet.string(for: Tag.seriesInstanceUID))
    }

    // MARK: - File Handling Tests

    func testFileCreationAndReading() throws {
        let data = try createTestDICOMFile()
        let tempFile = "\(testDirectory!)/test.dcm"
        
        try data.write(to: URL(fileURLWithPath: tempFile))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile))
        
        let readData = try Data(contentsOf: URL(fileURLWithPath: tempFile))
        XCTAssertEqual(data, readData)
        
        let file = try DICOMFile.read(from: readData)
        XCTAssertNotNil(file.dataSet.string(for: Tag.studyInstanceUID))
    }

    func testDirectoryCreation() throws {
        let subDir = "\(testDirectory!)/subdir"
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true, attributes: nil)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: subDir))
    }

    // MARK: - Edge Cases

    func testEmptyStudyDescription() throws {
        let data = try createTestDICOMFile(studyDescription: "")
        let file = try DICOMFile.read(from: data)
        
        let desc = file.dataSet.string(for: Tag.studyDescription)
        XCTAssertEqual(desc, "")
    }

    func testLongStudyDescription() throws {
        let longDesc = String(repeating: "A", count: 64)
        let data = try createTestDICOMFile(studyDescription: longDesc)
        let file = try DICOMFile.read(from: data)
        
        XCTAssertEqual(file.dataSet.string(for: Tag.studyDescription), longDesc)
    }

    func testSpecialCharactersInPatientName() throws {
        let data = try createTestDICOMFile(patientName: "O'BRIEN^MARY-JANE")
        let file = try DICOMFile.read(from: data)
        
        XCTAssertEqual(file.dataSet.string(for: Tag.patientName), "O'BRIEN^MARY-JANE")
    }
}
