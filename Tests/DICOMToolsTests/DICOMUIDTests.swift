import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

/// Tests for dicom-uid CLI tool functionality
/// Tests focus on DICOMKit/DICOMCore functionality used by the tool
final class DICOMUIDTests: XCTestCase {

    // MARK: - UID Generation Tests

    func testGenerateSingleUID() throws {
        let generator = UIDGenerator()
        let uid = generator.generate()

        XCTAssertFalse(uid.value.isEmpty)
        XCTAssertLessThanOrEqual(uid.value.count, 64)
        XCTAssertTrue(uid.value.hasPrefix(UIDGenerator.defaultRoot))
    }

    func testGenerateMultipleUIDs() throws {
        let generator = UIDGenerator()
        var uids = Set<String>()

        for _ in 0..<10 {
            let uid = generator.generate()
            uids.insert(uid.value)
        }

        // All UIDs should be unique
        XCTAssertEqual(uids.count, 10)
    }

    func testGenerateStudyInstanceUID() throws {
        let generator = UIDGenerator()
        let uid = generator.generateStudyInstanceUID()

        XCTAssertFalse(uid.value.isEmpty)
        XCTAssertLessThanOrEqual(uid.value.count, 64)
        // Study UIDs use type 1
        XCTAssertTrue(uid.value.contains("\(UIDGenerator.defaultRoot).1."))
    }

    func testGenerateSeriesInstanceUID() throws {
        let generator = UIDGenerator()
        let uid = generator.generateSeriesInstanceUID()

        XCTAssertFalse(uid.value.isEmpty)
        XCTAssertLessThanOrEqual(uid.value.count, 64)
        // Series UIDs use type 2
        XCTAssertTrue(uid.value.contains("\(UIDGenerator.defaultRoot).2."))
    }

    func testGenerateSOPInstanceUID() throws {
        let generator = UIDGenerator()
        let uid = generator.generateSOPInstanceUID()

        XCTAssertFalse(uid.value.isEmpty)
        XCTAssertLessThanOrEqual(uid.value.count, 64)
        // SOP Instance UIDs use type 3
        XCTAssertTrue(uid.value.contains("\(UIDGenerator.defaultRoot).3."))
    }

    func testGenerateWithCustomRoot() throws {
        let customRoot = "1.2.826.0.1.3680043.9.1234"
        let generator = UIDGenerator(root: customRoot)
        let uid = generator.generate()

        XCTAssertTrue(uid.value.hasPrefix(customRoot))
        XCTAssertLessThanOrEqual(uid.value.count, 64)
    }

    // MARK: - UID Validation Tests

    func testValidUIDParsing() throws {
        let uid = DICOMUniqueIdentifier.parse("1.2.840.10008.1.2.1")
        XCTAssertNotNil(uid)
        XCTAssertEqual(uid?.value, "1.2.840.10008.1.2.1")
    }

    func testUIDMaxLength() throws {
        // Maximum 64 characters
        let longUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14.15.16.17.18.19.20.21.22.23.24"
        XCTAssertLessThanOrEqual(longUID.count, 64)
        let uid = DICOMUniqueIdentifier.parse(longUID)
        XCTAssertNotNil(uid)
    }

    func testUIDTooLong() throws {
        // Over 64 characters should fail
        let tooLongUID = String(repeating: "1.", count: 33) + "1" // > 64 chars
        let uid = DICOMUniqueIdentifier.parse(tooLongUID)
        XCTAssertNil(uid)
    }

    func testUIDWithLeadingPeriod() throws {
        let uid = DICOMUniqueIdentifier.parse(".1.2.3")
        XCTAssertNil(uid)
    }

    func testUIDWithTrailingPeriod() throws {
        let uid = DICOMUniqueIdentifier.parse("1.2.3.")
        XCTAssertNil(uid)
    }

    func testUIDWithConsecutivePeriods() throws {
        let uid = DICOMUniqueIdentifier.parse("1.2..3")
        XCTAssertNil(uid)
    }

    func testUIDWithInvalidCharacters() throws {
        let uid = DICOMUniqueIdentifier.parse("1.2.3a.4")
        XCTAssertNil(uid)
    }

    // MARK: - UID Registry Lookup Tests

    func testLookupTransferSyntax() throws {
        let entry = UIDDictionary.lookup(uid: "1.2.840.10008.1.2.1")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "Explicit VR Little Endian")
        XCTAssertEqual(entry?.type, .transferSyntax)
    }

    func testLookupSOPClass() throws {
        let entry = UIDDictionary.lookup(uid: "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "CT Image Storage")
        XCTAssertEqual(entry?.type, .sopClass)
    }

    func testLookupUnknownUID() throws {
        let entry = UIDDictionary.lookup(uid: "1.2.3.4.5.6.7.8.9.999")
        XCTAssertNil(entry)
    }

    func testListAllUIDs() throws {
        let entries = UIDDictionary.allEntries
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testFilterTransferSyntaxes() throws {
        let transferSyntaxes = UIDDictionary.transferSyntaxes
        XCTAssertGreaterThan(transferSyntaxes.count, 0)
        for entry in transferSyntaxes {
            XCTAssertEqual(entry.type, .transferSyntax)
        }
    }

    func testFilterSOPClasses() throws {
        let sopClasses = UIDDictionary.sopClasses
        XCTAssertGreaterThan(sopClasses.count, 0)
        for entry in sopClasses {
            XCTAssertEqual(entry.type, .sopClass)
        }
    }

    // MARK: - UID in DICOM DataSet Tests

    func testSetAndGetUID() throws {
        var dataSet = DataSet()
        let uidValue = "1.2.3.4.5.6.7.8.9"
        dataSet.setString(uidValue, for: .sopInstanceUID, vr: .UI)

        let retrieved = dataSet.string(for: .sopInstanceUID)
        XCTAssertEqual(retrieved, uidValue)
    }

    func testRegenerateUIDInDataSet() throws {
        var dataSet = DataSet()
        let oldUID = "1.2.3.4.5.6.7.8.9"
        dataSet.setString(oldUID, for: .sopInstanceUID, vr: .UI)

        // Generate a new UID
        let generator = UIDGenerator()
        let newUID = generator.generateSOPInstanceUID()
        dataSet.setString(newUID.value, for: .sopInstanceUID, vr: .UI)

        let retrieved = dataSet.string(for: .sopInstanceUID)
        XCTAssertNotEqual(retrieved, oldUID)
        XCTAssertEqual(retrieved, newUID.value)
    }

    func testMultipleUIDsInDataSet() throws {
        var dataSet = DataSet()
        let studyUID = "1.2.3.4.5.100"
        let seriesUID = "1.2.3.4.5.200"
        let sopUID = "1.2.3.4.5.300"

        dataSet.setString(studyUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(seriesUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString(sopUID, for: .sopInstanceUID, vr: .UI)

        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), studyUID)
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), seriesUID)
        XCTAssertEqual(dataSet.string(for: .sopInstanceUID), sopUID)
    }

    // MARK: - UID Relationship Tests

    func testUIDRelationshipMaintenance() throws {
        // Simulate maintaining UID relationships across multiple files
        var uidMap: [String: String] = [:]
        let generator = UIDGenerator()

        let oldStudyUID = "1.2.3.4.5.100"
        let oldSeriesUID = "1.2.3.4.5.200"

        // First file maps the study UID
        let newStudyUID = generator.generate().value
        uidMap[oldStudyUID] = newStudyUID

        // Second file should use the same mapping
        if let mappedStudyUID = uidMap[oldStudyUID] {
            XCTAssertEqual(mappedStudyUID, newStudyUID)
        } else {
            XCTFail("Study UID mapping should exist")
        }

        // Series UID gets a new mapping
        let newSeriesUID = generator.generate().value
        uidMap[oldSeriesUID] = newSeriesUID

        XCTAssertEqual(uidMap.count, 2)
        XCTAssertNotEqual(newStudyUID, newSeriesUID)
    }

    // MARK: - UID Round-Trip Tests

    func testUIDRoundTrip() throws {
        var dataSet = DataSet()
        let originalStudyUID = "1.2.3.4.5.100"
        let originalSeriesUID = "1.2.3.4.5.200"
        let originalSOPUID = "1.2.3.4.5.300"

        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString(originalSOPUID, for: .sopInstanceUID, vr: .UI)
        dataSet.setString(originalStudyUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(originalSeriesUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)

        // Write and read back
        let file = DICOMFile.create(dataSet: dataSet)
        let data = try file.write()
        let readFile = try DICOMFile.read(from: data)

        XCTAssertEqual(readFile.dataSet.string(for: .studyInstanceUID), originalStudyUID)
        XCTAssertEqual(readFile.dataSet.string(for: .seriesInstanceUID), originalSeriesUID)
        XCTAssertEqual(readFile.dataSet.string(for: .sopInstanceUID), originalSOPUID)
    }

    func testRegenerateUIDsRoundTrip() throws {
        // Create a DICOM file with known UIDs
        var dataSet = DataSet()
        let originalStudyUID = "1.2.3.4.5.100"
        let originalSeriesUID = "1.2.3.4.5.200"
        let originalSOPUID = "1.2.3.4.5.300"

        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString(originalSOPUID, for: .sopInstanceUID, vr: .UI)
        dataSet.setString(originalStudyUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(originalSeriesUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)

        let file = DICOMFile.create(dataSet: dataSet)
        let data = try file.write()

        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dicom-uid-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let inputPath = tempDir.appendingPathComponent("input.dcm").path
        let outputPath = tempDir.appendingPathComponent("output.dcm").path
        try data.write(to: URL(fileURLWithPath: inputPath))

        // Regenerate UIDs
        let generator = UIDGenerator()
        let readFile = try DICOMFile.read(from: data)
        var modDataSet = readFile.dataSet

        // Replace instance UIDs (not well-known ones)
        let newStudyUID = generator.generateStudyInstanceUID().value
        let newSeriesUID = generator.generateSeriesInstanceUID().value
        let newSOPUID = generator.generateSOPInstanceUID().value

        modDataSet.setString(newStudyUID, for: .studyInstanceUID, vr: .UI)
        modDataSet.setString(newSeriesUID, for: .seriesInstanceUID, vr: .UI)
        modDataSet.setString(newSOPUID, for: .sopInstanceUID, vr: .UI)

        let newFile = DICOMFile.create(
            dataSet: modDataSet,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2"
        )
        let newData = try newFile.write()
        try newData.write(to: URL(fileURLWithPath: outputPath))

        // Read back and verify
        let finalFile = try DICOMFile.read(from: newData)

        // UIDs should be new
        XCTAssertNotEqual(finalFile.dataSet.string(for: .studyInstanceUID), originalStudyUID)
        XCTAssertNotEqual(finalFile.dataSet.string(for: .seriesInstanceUID), originalSeriesUID)
        XCTAssertNotEqual(finalFile.dataSet.string(for: .sopInstanceUID), originalSOPUID)

        // Non-UID data should be preserved
        XCTAssertEqual(finalFile.dataSet.string(for: .patientName), "DOE^JOHN")

        // SOP Class UID (well-known) should be preserved
        XCTAssertEqual(finalFile.dataSet.string(for: .sopClassUID), "1.2.840.10008.5.1.4.1.1.2")
    }

    // MARK: - UID Properties Tests

    func testUIDComponents() throws {
        let uid = DICOMUniqueIdentifier.parse("1.2.840.10008.1.2.1")
        XCTAssertNotNil(uid)
        XCTAssertEqual(uid?.componentCount, 7)
    }

    func testUIDIsStandardDICOM() throws {
        let standardUID = DICOMUniqueIdentifier.parse("1.2.840.10008.1.2.1")
        XCTAssertNotNil(standardUID)
        XCTAssertTrue(standardUID?.isStandardDICOM ?? false)

        let nonStandardUID = DICOMUniqueIdentifier.parse("1.2.3.4.5.6")
        XCTAssertNotNil(nonStandardUID)
        XCTAssertFalse(nonStandardUID?.isStandardDICOM ?? true)
    }

    func testUIDComparable() throws {
        let uid1 = DICOMUniqueIdentifier.parse("1.2.3")!
        let uid2 = DICOMUniqueIdentifier.parse("1.2.4")!

        XCTAssertLessThan(uid1, uid2)
    }

    func testUIDEquality() throws {
        let uid1 = DICOMUniqueIdentifier.parse("1.2.840.10008.1.2.1")
        let uid2 = DICOMUniqueIdentifier.parse("1.2.840.10008.1.2.1")

        XCTAssertEqual(uid1, uid2)
    }

    // MARK: - UID Mapping Export Tests

    func testUIDMappingCodable() throws {
        let mapping = [
            "oldUID": "1.2.3.4.5.100",
            "newUID": "1.2.276.0.7230010.3.1.123456.789",
            "tagName": "StudyInstanceUID",
            "tagHex": "0020,000D"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: [mapping], options: [.prettyPrinted])
        XCTAssertGreaterThan(jsonData.count, 0)

        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [[String: String]]
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.first?["oldUID"], "1.2.3.4.5.100")
        XCTAssertEqual(decoded?.first?["tagName"], "StudyInstanceUID")
    }

    func testDefaultRoot() throws {
        XCTAssertEqual(UIDGenerator.defaultRoot, "1.2.276.0.7230010.3")
    }

    func testGeneratedUIDIsValidDICOM() throws {
        let generator = UIDGenerator()

        for _ in 0..<20 {
            let uid = generator.generate()
            // Must parse successfully
            let parsed = DICOMUniqueIdentifier.parse(uid.value)
            XCTAssertNotNil(parsed, "Generated UID should be valid: \(uid.value)")
            // Must be <= 64 chars
            XCTAssertLessThanOrEqual(uid.value.count, 64)
            // Must not have invalid chars
            let allowedChars = CharacterSet(charactersIn: "0123456789.")
            XCTAssertTrue(uid.value.unicodeScalars.allSatisfy { allowedChars.contains($0) })
        }
    }
}
