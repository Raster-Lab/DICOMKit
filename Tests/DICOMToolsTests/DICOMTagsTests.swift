import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-tags CLI tool functionality
/// Note: Tests focus on DICOMKit/DICOMCore functionality used by the tool,
/// as TagEditor is in the executable target and not directly testable
final class DICOMTagsTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a minimal valid DICOM file for testing
    private func createTestDICOMFile() throws -> Data {
        var data = Data()

        // Add 128-byte preamble
        data.append(Data(count: 128))

        // Add DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"

        // File Meta Information Group Length (0002,0000) - UL, 4 bytes
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x80, 0x00, 0x00, 0x00]) // Value = 128

        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let tsBytes = transferSyntaxUID.data(using: .utf8)!
        let tsLength = UInt16(tsBytes.count % 2 == 0 ? tsBytes.count : tsBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(tsBytes)
        if tsBytes.count % 2 != 0 { data.append(0x00) }

        // Study Date (0008,0020) - DA
        data.append(contentsOf: [0x08, 0x00, 0x20, 0x00]) // Tag
        data.append(contentsOf: [0x44, 0x41]) // VR = DA
        let studyDate = "20240101"
        let sdLength = UInt16(studyDate.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sdLength.littleEndian) { Data($0) })
        data.append(studyDate.data(using: .utf8)!)

        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modality = "CT"
        let modLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)

        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceUID = "1.2.3.4.5.6.7.8.9"
        let sopiBytes = sopInstanceUID.data(using: .utf8)!
        let sopiLength = UInt16(sopiBytes.count % 2 == 0 ? sopiBytes.count : sopiBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: sopiLength.littleEndian) { Data($0) })
        data.append(sopiBytes)
        if sopiBytes.count % 2 != 0 { data.append(0x00) }

        // Study Description (0008,1030) - LO
        data.append(contentsOf: [0x08, 0x00, 0x30, 0x10]) // Tag
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let studyDesc = "Test Study"
        let studyDescLength = UInt16(studyDesc.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyDescLength.littleEndian) { Data($0) })
        data.append(studyDesc.data(using: .utf8)!)

        // Series Description (0008,103E) - LO
        data.append(contentsOf: [0x08, 0x00, 0x3E, 0x10]) // Tag
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let seriesDesc = "Test Series"
        let seriesDescBytes = seriesDesc.data(using: .utf8)!
        let seriesDescLength = UInt16(seriesDescBytes.count % 2 == 0 ? seriesDescBytes.count : seriesDescBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: seriesDescLength.littleEndian) { Data($0) })
        data.append(seriesDescBytes)
        if seriesDescBytes.count % 2 != 0 { data.append(0x20) } // pad with space for LO

        // Private Tag (0009,0010) - LO
        data.append(contentsOf: [0x09, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let privateValue = "PRIVATE_DATA"
        let privateLength = UInt16(privateValue.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: privateLength.littleEndian) { Data($0) })
        data.append(privateValue.data(using: .utf8)!)

        // Patient Name (0010,0010) - PN
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x50, 0x4E]) // VR = PN
        let patientName = "DOE^JOHN"
        let pnLength = UInt16(patientName.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: pnLength.littleEndian) { Data($0) })
        data.append(patientName.data(using: .utf8)!)

        // Patient ID (0010,0020) - LO
        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00]) // Tag
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let patientID = "12345"
        let pidBytes = patientID.data(using: .utf8)!
        let pidLength = UInt16(pidBytes.count % 2 == 0 ? pidBytes.count : pidBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: pidLength.littleEndian) { Data($0) })
        data.append(pidBytes)
        if pidBytes.count % 2 != 0 { data.append(0x20) } // pad with space for LO

        // Study Instance UID (0020,000D) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let studyUID = "1.2.3.4.5.100"
        let studyUIDBytes = studyUID.data(using: .utf8)!
        let studyUIDLength = UInt16(studyUIDBytes.count % 2 == 0 ? studyUIDBytes.count : studyUIDBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: studyUIDLength.littleEndian) { Data($0) })
        data.append(studyUIDBytes)
        if studyUIDBytes.count % 2 != 0 { data.append(0x00) }

        // Series Instance UID (0020,000E) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let seriesUID = "1.2.3.4.5.200"
        let seriesUIDBytes = seriesUID.data(using: .utf8)!
        let seriesUIDLength = UInt16(seriesUIDBytes.count % 2 == 0 ? seriesUIDBytes.count : seriesUIDBytes.count + 1)
        data.append(contentsOf: withUnsafeBytes(of: seriesUIDLength.littleEndian) { Data($0) })
        data.append(seriesUIDBytes)
        if seriesUIDBytes.count % 2 != 0 { data.append(0x00) }

        return data
    }

    /// Creates a DICOMFile using the high-level API
    private func createTestDICOMFileUsingAPI(
        patientName: String = "DOE^JOHN",
        patientID: String = "12345",
        modality: String = "CT"
    ) -> DICOMFile {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(patientName, for: .patientName, vr: .PN)
        dataSet.setString(patientID, for: .patientID, vr: .LO)
        dataSet.setString(modality, for: .modality, vr: .CS)
        dataSet.setString("20240101", for: .studyDate, vr: .DA)
        dataSet.setString("Test Study", for: .studyDescription, vr: .LO)
        dataSet.setString("Test Series", for: .seriesDescription, vr: .LO)
        dataSet.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)

        // Add a private tag
        let privateTag = Tag(group: 0x0009, element: 0x0010)
        dataSet.setString("PRIVATE_DATA", for: privateTag, vr: .LO)

        return DICOMFile.create(dataSet: dataSet)
    }

    // MARK: - DICOM File Read/Write Tests

    func testReadDICOMFile() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        XCTAssertNotNil(readFile.dataSet[.patientName])
        XCTAssertNotNil(readFile.dataSet[.patientID])
        XCTAssertNotNil(readFile.dataSet[.modality])
        XCTAssertNotNil(readFile.dataSet[.studyDate])
        XCTAssertNotNil(readFile.dataSet[.sopInstanceUID])
    }

    func testReadPatientName() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let patientName = readFile.dataSet.string(for: .patientName)
        XCTAssertEqual(patientName, "DOE^JOHN")
    }

    func testReadPatientID() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let patientID = readFile.dataSet.string(for: .patientID)
        XCTAssertEqual(patientID, "12345")
    }

    func testReadModality() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let modality = readFile.dataSet.string(for: .modality)
        XCTAssertEqual(modality, "CT")
    }

    func testReadStudyDate() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        let studyDate = readFile.dataSet.string(for: .studyDate)
        XCTAssertEqual(studyDate, "20240101")
    }

    // MARK: - Tag Set Operations

    func testSetPatientName() throws {
        var dataSet = DataSet()
        dataSet.setString("SMITH^JANE", for: .patientName, vr: .PN)

        XCTAssertEqual(dataSet.string(for: .patientName), "SMITH^JANE")
    }

    func testSetMultipleTags() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("CT", for: .modality, vr: .CS)
        dataSet.setString("20240101", for: .studyDate, vr: .DA)

        XCTAssertEqual(dataSet.string(for: .patientName), "DOE^JOHN")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(dataSet.string(for: .modality), "CT")
        XCTAssertEqual(dataSet.string(for: .studyDate), "20240101")
    }

    func testSetOverwriteExisting() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        XCTAssertEqual(dataSet.string(for: .patientName), "DOE^JOHN")

        dataSet.setString("SMITH^JANE", for: .patientName, vr: .PN)
        XCTAssertEqual(dataSet.string(for: .patientName), "SMITH^JANE")
    }

    func testSetNewTag() throws {
        var dataSet = DataSet()
        XCTAssertNil(dataSet[.patientName])

        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        XCTAssertNotNil(dataSet[.patientName])
        XCTAssertEqual(dataSet.string(for: .patientName), "DOE^JOHN")
    }

    func testSetTagByHex() throws {
        var dataSet = DataSet()
        let tag = Tag(group: 0x0010, element: 0x0010)
        dataSet.setString("DOE^JOHN", for: tag, vr: .PN)

        XCTAssertEqual(dataSet.string(for: .patientName), "DOE^JOHN")
        XCTAssertEqual(tag, Tag.patientName)
    }

    func testSetTagVRPreserved() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)

        let element = dataSet[.patientName]
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.vr, .PN)
    }

    // MARK: - Tag Delete Operations

    func testDeleteTag() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        XCTAssertNotNil(dataSet[.patientName])

        dataSet.remove(tag: .patientName)
        XCTAssertNil(dataSet[.patientName])
        XCTAssertNil(dataSet.string(for: .patientName))
    }

    func testDeleteNonExistentTag() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)

        // Removing a tag that doesn't exist should not error
        dataSet.remove(tag: .modality)
        XCTAssertNotNil(dataSet[.patientName])
        XCTAssertNil(dataSet[.modality])
    }

    func testDeletePrivateTags() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)
        var dataSet = readFile.dataSet

        // Verify private tag exists
        let privateTag = Tag(group: 0x0009, element: 0x0010)
        XCTAssertNotNil(dataSet[privateTag])

        // Remove all private tags (those with odd group numbers)
        let privateTags = dataSet.tags.filter { $0.isPrivate }
        for tag in privateTags {
            dataSet.remove(tag: tag)
        }

        // Verify private tags are removed
        let remainingPrivateTags = dataSet.tags.filter { $0.isPrivate }
        XCTAssertTrue(remainingPrivateTags.isEmpty)

        // Verify non-private tags are preserved
        XCTAssertNotNil(dataSet[.patientName])
    }

    func testDeleteMultipleTags() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("CT", for: .modality, vr: .CS)

        dataSet.remove(tag: .patientName)
        dataSet.remove(tag: .patientID)

        XCTAssertNil(dataSet[.patientName])
        XCTAssertNil(dataSet[.patientID])
        XCTAssertNotNil(dataSet[.modality])
    }

    func testDataSetTagsList() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("CT", for: .modality, vr: .CS)

        let tags = dataSet.tags
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains(.patientName))
        XCTAssertTrue(tags.contains(.patientID))
        XCTAssertTrue(tags.contains(.modality))
    }

    // MARK: - Tag Copy Operations

    func testCopyTagBetweenDataSets() throws {
        var source = DataSet()
        source.setString("DOE^JOHN", for: .patientName, vr: .PN)

        var destination = DataSet()
        if let element = source[.patientName] {
            destination[.patientName] = element
        }

        XCTAssertEqual(destination.string(for: .patientName), "DOE^JOHN")
    }

    func testCopyMultipleTags() throws {
        var source = DataSet()
        source.setString("DOE^JOHN", for: .patientName, vr: .PN)
        source.setString("12345", for: .patientID, vr: .LO)
        source.setString("CT", for: .modality, vr: .CS)

        var destination = DataSet()
        let tagsToCopy: [Tag] = [.patientName, .patientID]
        for tag in tagsToCopy {
            if let element = source[tag] {
                destination[tag] = element
            }
        }

        XCTAssertEqual(destination.string(for: .patientName), "DOE^JOHN")
        XCTAssertEqual(destination.string(for: .patientID), "12345")
        XCTAssertNil(destination[.modality])
    }

    func testCopyPreservesVR() throws {
        var source = DataSet()
        source.setString("DOE^JOHN", for: .patientName, vr: .PN)
        source.setString("CT", for: .modality, vr: .CS)

        var destination = DataSet()
        if let pnElement = source[.patientName] {
            destination[.patientName] = pnElement
        }
        if let modElement = source[.modality] {
            destination[.modality] = modElement
        }

        XCTAssertEqual(destination[.patientName]?.vr, .PN)
        XCTAssertEqual(destination[.modality]?.vr, .CS)
    }

    func testCopyAllTags() throws {
        var source = DataSet()
        source.setString("DOE^JOHN", for: .patientName, vr: .PN)
        source.setString("12345", for: .patientID, vr: .LO)
        source.setString("CT", for: .modality, vr: .CS)
        source.setString("20240101", for: .studyDate, vr: .DA)

        var destination = DataSet()
        for element in source.allElements {
            destination[element.tag] = element
        }

        XCTAssertEqual(destination.tags.count, source.tags.count)
        XCTAssertEqual(destination.string(for: .patientName), "DOE^JOHN")
        XCTAssertEqual(destination.string(for: .patientID), "12345")
        XCTAssertEqual(destination.string(for: .modality), "CT")
        XCTAssertEqual(destination.string(for: .studyDate), "20240101")
    }

    // MARK: - Round-trip Tests

    func testRoundTripReadWrite() throws {
        let file = createTestDICOMFileUsingAPI()
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)
        var dataSet = readFile.dataSet

        // Modify a tag
        dataSet.setString("MODIFIED^NAME", for: .patientName, vr: .PN)

        // Write again
        let modifiedFile = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2"
        )
        let modifiedData = try modifiedFile.write()

        // Read back and verify
        let finalFile = try DICOMFile.read(from: modifiedData)
        XCTAssertEqual(finalFile.dataSet.string(for: .patientName), "MODIFIED^NAME")
        XCTAssertEqual(finalFile.dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(finalFile.dataSet.string(for: .modality), "CT")
    }

    func testWriteDICOMFile() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("CT", for: .modality, vr: .CS)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)

        let file = DICOMFile.create(dataSet: dataSet)
        let data = try file.write()

        XCTAssertGreaterThan(data.count, 132) // At least preamble + DICM
        // Verify DICM prefix
        let dicmPrefix = String(data: data[128..<132], encoding: .utf8)
        XCTAssertEqual(dicmPrefix, "DICM")
    }

    func testModifyAndWrite() throws {
        var dataSet = DataSet()
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)

        let file = DICOMFile.create(dataSet: dataSet)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)
        var modDataSet = readFile.dataSet

        // Modify multiple tags
        modDataSet.setString("SMITH^JANE", for: .patientName, vr: .PN)
        modDataSet.setString("67890", for: .patientID, vr: .LO)
        modDataSet.setString("MR", for: .modality, vr: .CS)

        let modFile = DICOMFile.create(
            dataSet: modDataSet,
            sopClassUID: modDataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2"
        )
        let modData = try modFile.write()
        let finalFile = try DICOMFile.read(from: modData)

        XCTAssertEqual(finalFile.dataSet.string(for: .patientName), "SMITH^JANE")
        XCTAssertEqual(finalFile.dataSet.string(for: .patientID), "67890")
        XCTAssertEqual(finalFile.dataSet.string(for: .modality), "MR")
    }

    // MARK: - Edge Cases

    func testEmptyDataSet() throws {
        let dataSet = DataSet()

        XCTAssertEqual(dataSet.count, 0)
        XCTAssertTrue(dataSet.tags.isEmpty)
        XCTAssertTrue(dataSet.allElements.isEmpty)
        XCTAssertNil(dataSet.string(for: .patientName))
        XCTAssertNil(dataSet[.patientName])
    }

    func testTagEquality() throws {
        let tag1 = Tag(group: 0x0010, element: 0x0010)
        let tag2 = Tag.patientName
        let tag3 = Tag(group: 0x0010, element: 0x0020)

        XCTAssertEqual(tag1, tag2)
        XCTAssertNotEqual(tag1, tag3)
    }

    func testPrivateTagDetection() throws {
        // Even group - standard tag
        let standardTag = Tag(group: 0x0010, element: 0x0010)
        XCTAssertFalse(standardTag.isPrivate)

        // Odd group - private tag
        let privateTag1 = Tag(group: 0x0009, element: 0x0010)
        XCTAssertTrue(privateTag1.isPrivate)

        let privateTag2 = Tag(group: 0x0011, element: 0x0020)
        XCTAssertTrue(privateTag2.isPrivate)

        // Group 0x0001 is also private (odd)
        let privateTag3 = Tag(group: 0x0001, element: 0x0001)
        XCTAssertTrue(privateTag3.isPrivate)

        // Group 0x7FE0 is standard (even)
        let pixelDataTag = Tag.pixelData
        XCTAssertFalse(pixelDataTag.isPrivate)
    }
}
