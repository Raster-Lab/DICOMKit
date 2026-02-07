import XCTest
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary
import Foundation

/// Tests for dicom-archive tool
///
/// Tests the DICOM file creation, reading, metadata extraction,
/// file organization, wildcard matching, and archive workflow
/// functionality that the dicom-archive CLI tool relies on.
final class DICOMArchiveTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMArchiveTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Test-local Archive Types

    private struct TestArchiveInstance: Codable, Equatable {
        let sopInstanceUID: String
        let sopClassUID: String
        let filePath: String
        let fileSize: Int64
        let importDate: String
        let instanceNumber: String?
    }

    private struct TestArchiveSeries: Codable, Equatable {
        let seriesInstanceUID: String
        let modality: String
        let seriesDescription: String?
        let seriesNumber: String?
        var instances: [TestArchiveInstance]
    }

    private struct TestArchiveStudy: Codable, Equatable {
        let studyInstanceUID: String
        let studyDate: String?
        let studyDescription: String?
        let modality: String?
        let accessionNumber: String?
        var series: [TestArchiveSeries]
    }

    private struct TestArchivePatient: Codable, Equatable {
        let patientName: String
        let patientID: String
        var studies: [TestArchiveStudy]
    }

    private struct TestArchiveIndex: Codable, Equatable {
        let version: String
        let creationDate: String
        var lastModified: String
        var fileCount: Int
        var patients: [TestArchivePatient]
    }

    // MARK: - Helper Methods

    /// Create a minimal DICOM file for testing
    func createMinimalDICOMFile(
        patientName: String = "TEST^PATIENT",
        patientID: String = "12345",
        studyUID: String = "1.2.3.4.5",
        seriesUID: String = "1.2.3.4.5.6",
        instanceUID: String? = nil,
        modality: String = "CT",
        studyDate: String = "20240101",
        instanceNumber: String = "1"
    ) throws -> Data {
        let instanceUIDValue = instanceUID ?? "1.2.3.4.5.6.7.\(UUID().uuidString)"

        var fileMeta = DataSet()
        var versionData = Data(count: 2)
        versionData[0] = 0x00
        versionData[1] = 0x01
        fileMeta[.fileMetaInformationVersion] = DataElement.data(tag: .fileMetaInformationVersion, vr: .OB, data: versionData)
        fileMeta[.mediaStorageSOPClassUID] = DataElement.string(tag: .mediaStorageSOPClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        fileMeta[.mediaStorageSOPInstanceUID] = DataElement.string(tag: .mediaStorageSOPInstanceUID, vr: .UI, value: instanceUIDValue)
        fileMeta[.transferSyntaxUID] = DataElement.string(tag: .transferSyntaxUID, vr: .UI, value: TransferSyntax.explicitVRLittleEndian.uid)
        fileMeta[.implementationClassUID] = DataElement.string(tag: .implementationClassUID, vr: .UI, value: "1.2.826.0.1.3680043.10.1")

        var dataSet = DataSet()
        dataSet[.sopClassUID] = DataElement.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        dataSet[.sopInstanceUID] = DataElement.string(tag: .sopInstanceUID, vr: .UI, value: instanceUIDValue)
        dataSet[.modality] = DataElement.string(tag: .modality, vr: .CS, value: modality)
        dataSet[.patientName] = DataElement.string(tag: .patientName, vr: .PN, value: patientName)
        dataSet[.patientID] = DataElement.string(tag: .patientID, vr: .LO, value: patientID)
        dataSet[.studyInstanceUID] = DataElement.string(tag: .studyInstanceUID, vr: .UI, value: studyUID)
        dataSet[.seriesInstanceUID] = DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: seriesUID)
        dataSet[.studyDate] = DataElement.string(tag: .studyDate, vr: .DA, value: studyDate)
        dataSet[.studyTime] = DataElement.string(tag: .studyTime, vr: .TM, value: "120000")
        dataSet[.seriesNumber] = DataElement.string(tag: .seriesNumber, vr: .IS, value: "1")
        dataSet[.instanceNumber] = DataElement.string(tag: .instanceNumber, vr: .IS, value: instanceNumber)

        let file = DICOMFile(fileMetaInformation: fileMeta, dataSet: dataSet)
        return try file.write()
    }

    /// Sanitize a path component (mirrors the archive tool's logic)
    private func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var result = ""
        for char in value.unicodeScalars {
            if allowed.contains(char) {
                result.append(Character(char))
            } else {
                result.append("_")
            }
        }
        if result.isEmpty { result = "UNKNOWN" }
        return result
    }

    /// Wildcard matching (mirrors the archive tool's logic)
    private func wildcardMatch(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern.uppercased())
        let t = Array(text.uppercased())
        return wildcardMatchHelper(p, 0, t, 0)
    }

    private func wildcardMatchHelper(_ pattern: [Character], _ pi: Int, _ text: [Character], _ ti: Int) -> Bool {
        var pi = pi
        var ti = ti

        while pi < pattern.count {
            let pc = pattern[pi]
            if pc == "*" {
                pi += 1
                while pi < pattern.count && pattern[pi] == "*" {
                    pi += 1
                }
                if pi == pattern.count {
                    return true
                }
                while ti <= text.count {
                    if wildcardMatchHelper(pattern, pi, text, ti) {
                        return true
                    }
                    ti += 1
                }
                return false
            } else if pc == "?" {
                guard ti < text.count else { return false }
                pi += 1
                ti += 1
            } else {
                guard ti < text.count, pc == text[ti] else { return false }
                pi += 1
                ti += 1
            }
        }
        return ti == text.count
    }

    /// Create a test archive index and save to disk
    private func createTestArchiveIndex(
        patients: [TestArchivePatient] = [],
        fileCount: Int = 0
    ) -> TestArchiveIndex {
        return TestArchiveIndex(
            version: "1.2.1",
            creationDate: "2024-01-01T00:00:00Z",
            lastModified: "2024-01-01T00:00:00Z",
            fileCount: fileCount,
            patients: patients
        )
    }

    /// Save a test archive index to disk
    private func saveTestArchiveIndex(_ index: TestArchiveIndex, to archivePath: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        let indexURL = archivePath.appendingPathComponent("archive_index.json")
        try data.write(to: indexURL)
    }

    /// Load a test archive index from disk
    private func loadTestArchiveIndex(from archivePath: URL) throws -> TestArchiveIndex {
        let indexURL = archivePath.appendingPathComponent("archive_index.json")
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode(TestArchiveIndex.self, from: data)
    }

    // MARK: - Archive Index Serialization Tests

    func testArchiveIndexEncodeDecode() throws {
        let index = createTestArchiveIndex()
        let encoder = JSONEncoder()
        let data = try encoder.encode(index)
        let decoded = try JSONDecoder().decode(TestArchiveIndex.self, from: data)
        XCTAssertEqual(decoded, index)
    }

    func testArchiveIndexWithPatients() throws {
        let instance = TestArchiveInstance(
            sopInstanceUID: "1.2.3.4.5.6.7.1",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "P001/study1/series1/instance1.dcm",
            fileSize: 1024,
            importDate: "2024-01-01T00:00:00Z",
            instanceNumber: "1"
        )
        let series = TestArchiveSeries(
            seriesInstanceUID: "1.2.3.4.5.6",
            modality: "CT",
            seriesDescription: "Chest CT",
            seriesNumber: "1",
            instances: [instance]
        )
        let study = TestArchiveStudy(
            studyInstanceUID: "1.2.3.4.5",
            studyDate: "20240101",
            studyDescription: "Annual Checkup",
            modality: "CT",
            accessionNumber: "ACC001",
            series: [series]
        )
        let patient = TestArchivePatient(
            patientName: "DOE^JOHN",
            patientID: "P001",
            studies: [study]
        )
        let index = createTestArchiveIndex(patients: [patient], fileCount: 1)

        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(TestArchiveIndex.self, from: data)

        XCTAssertEqual(decoded.patients.count, 1)
        XCTAssertEqual(decoded.patients[0].patientName, "DOE^JOHN")
        XCTAssertEqual(decoded.patients[0].studies.count, 1)
        XCTAssertEqual(decoded.patients[0].studies[0].series[0].instances.count, 1)
        XCTAssertEqual(decoded.fileCount, 1)
    }

    func testArchiveIndexWithMultipleStudies() throws {
        let study1 = TestArchiveStudy(
            studyInstanceUID: "1.2.3.1",
            studyDate: "20240101",
            studyDescription: "Study One",
            modality: "CT",
            accessionNumber: nil,
            series: []
        )
        let study2 = TestArchiveStudy(
            studyInstanceUID: "1.2.3.2",
            studyDate: "20240202",
            studyDescription: "Study Two",
            modality: "MR",
            accessionNumber: nil,
            series: []
        )
        let patient = TestArchivePatient(
            patientName: "DOE^JANE",
            patientID: "P002",
            studies: [study1, study2]
        )
        let index = createTestArchiveIndex(patients: [patient])

        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(TestArchiveIndex.self, from: data)

        XCTAssertEqual(decoded.patients[0].studies.count, 2)
        XCTAssertEqual(decoded.patients[0].studies[0].studyInstanceUID, "1.2.3.1")
        XCTAssertEqual(decoded.patients[0].studies[1].studyInstanceUID, "1.2.3.2")
    }

    func testArchiveInstanceEncodeDecode() throws {
        let instance = TestArchiveInstance(
            sopInstanceUID: "1.2.3.4.5.6.7.99",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "data/P001/study/series/instance.dcm",
            fileSize: 2048,
            importDate: "2024-06-15T10:30:00Z",
            instanceNumber: "5"
        )
        let data = try JSONEncoder().encode(instance)
        let decoded = try JSONDecoder().decode(TestArchiveInstance.self, from: data)
        XCTAssertEqual(decoded, instance)
    }

    func testArchiveSeriesEncodeDecode() throws {
        let instance1 = TestArchiveInstance(
            sopInstanceUID: "1.2.3.1", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "f1.dcm", fileSize: 100, importDate: "2024-01-01T00:00:00Z", instanceNumber: "1"
        )
        let instance2 = TestArchiveInstance(
            sopInstanceUID: "1.2.3.2", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "f2.dcm", fileSize: 200, importDate: "2024-01-01T00:00:00Z", instanceNumber: "2"
        )
        let series = TestArchiveSeries(
            seriesInstanceUID: "1.2.3.4.5.6",
            modality: "MR",
            seriesDescription: "Brain MRI",
            seriesNumber: "2",
            instances: [instance1, instance2]
        )
        let data = try JSONEncoder().encode(series)
        let decoded = try JSONDecoder().decode(TestArchiveSeries.self, from: data)
        XCTAssertEqual(decoded, series)
        XCTAssertEqual(decoded.instances.count, 2)
    }

    func testArchiveStudyEncodeDecode() throws {
        let series = TestArchiveSeries(
            seriesInstanceUID: "1.2.3.4.5.6",
            modality: "CT",
            seriesDescription: nil,
            seriesNumber: nil,
            instances: []
        )
        let study = TestArchiveStudy(
            studyInstanceUID: "1.2.3.4.5",
            studyDate: "20240315",
            studyDescription: "Follow-up",
            modality: "CT",
            accessionNumber: "ACC999",
            series: [series]
        )
        let data = try JSONEncoder().encode(study)
        let decoded = try JSONDecoder().decode(TestArchiveStudy.self, from: data)
        XCTAssertEqual(decoded, study)
        XCTAssertEqual(decoded.accessionNumber, "ACC999")
    }

    func testArchivePatientEncodeDecode() throws {
        let study = TestArchiveStudy(
            studyInstanceUID: "1.2.3",
            studyDate: nil,
            studyDescription: nil,
            modality: nil,
            accessionNumber: nil,
            series: []
        )
        let patient = TestArchivePatient(
            patientName: "SMITH^ALICE",
            patientID: "PAT_42",
            studies: [study]
        )
        let data = try JSONEncoder().encode(patient)
        let decoded = try JSONDecoder().decode(TestArchivePatient.self, from: data)
        XCTAssertEqual(decoded, patient)
        XCTAssertEqual(decoded.patientName, "SMITH^ALICE")
    }

    func testEmptyArchiveIndex() throws {
        let index = createTestArchiveIndex()
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(TestArchiveIndex.self, from: data)
        XCTAssertEqual(decoded.patients.count, 0)
        XCTAssertEqual(decoded.fileCount, 0)
        XCTAssertEqual(decoded.version, "1.2.1")
    }

    // MARK: - DICOM File Metadata Extraction Tests

    func testExtractPatientName() throws {
        let fileData = try createMinimalDICOMFile(patientName: "EXTRACT^PATIENT")
        let dicomFile = try DICOMFile.read(from: fileData)
        let name = dicomFile.dataSet.string(for: .patientName)
        XCTAssertEqual(name, "EXTRACT^PATIENT")
    }

    func testExtractPatientID() throws {
        let fileData = try createMinimalDICOMFile(patientID: "PID_999")
        let dicomFile = try DICOMFile.read(from: fileData)
        let pid = dicomFile.dataSet.string(for: .patientID)
        XCTAssertEqual(pid, "PID_999")
    }

    func testExtractStudyInstanceUID() throws {
        let fileData = try createMinimalDICOMFile(studyUID: "1.2.3.99.88")
        let dicomFile = try DICOMFile.read(from: fileData)
        let uid = dicomFile.dataSet.string(for: .studyInstanceUID)
        XCTAssertEqual(uid, "1.2.3.99.88")
    }

    func testExtractSeriesInstanceUID() throws {
        let fileData = try createMinimalDICOMFile(seriesUID: "1.2.3.99.88.77")
        let dicomFile = try DICOMFile.read(from: fileData)
        let uid = dicomFile.dataSet.string(for: .seriesInstanceUID)
        XCTAssertEqual(uid, "1.2.3.99.88.77")
    }

    func testExtractSOPInstanceUID() throws {
        let sopUID = "1.2.3.4.5.6.7.42"
        let fileData = try createMinimalDICOMFile(instanceUID: sopUID)
        let dicomFile = try DICOMFile.read(from: fileData)
        let uid = dicomFile.dataSet.string(for: .sopInstanceUID)
        XCTAssertEqual(uid, sopUID)
    }

    func testExtractModality() throws {
        let fileData = try createMinimalDICOMFile(modality: "MR")
        let dicomFile = try DICOMFile.read(from: fileData)
        let mod = dicomFile.dataSet.string(for: .modality)
        XCTAssertEqual(mod, "MR")
    }

    func testExtractStudyDate() throws {
        let fileData = try createMinimalDICOMFile(studyDate: "20230715")
        let dicomFile = try DICOMFile.read(from: fileData)
        let date = dicomFile.dataSet.string(for: .studyDate)
        XCTAssertEqual(date, "20230715")
    }

    func testExtractAllArchiveMetadata() throws {
        let sopUID = "1.2.3.4.5.6.7.100"
        let fileData = try createMinimalDICOMFile(
            patientName: "META^FULL",
            patientID: "META001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.6",
            instanceUID: sopUID,
            modality: "US",
            studyDate: "20240601"
        )
        let dicomFile = try DICOMFile.read(from: fileData)
        let ds = dicomFile.dataSet

        XCTAssertEqual(ds.string(for: .patientName), "META^FULL")
        XCTAssertEqual(ds.string(for: .patientID), "META001")
        XCTAssertEqual(ds.string(for: .studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(ds.string(for: .seriesInstanceUID), "1.2.3.4.5.6")
        XCTAssertEqual(ds.string(for: .sopInstanceUID), sopUID)
        XCTAssertEqual(ds.string(for: .sopClassUID), "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(ds.string(for: .modality), "US")
        XCTAssertEqual(ds.string(for: .studyDate), "20240601")
        XCTAssertEqual(ds.string(for: .instanceNumber), "1")
    }

    // MARK: - File Organization Tests

    func testCreateArchiveDirectoryStructure() throws {
        let archiveDir = tempDirectory.appendingPathComponent("archive")
        let dataDir = archiveDir.appendingPathComponent("data")
        let fm = FileManager.default

        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let index = createTestArchiveIndex()
        try saveTestArchiveIndex(index, to: archiveDir)

        XCTAssertTrue(fm.fileExists(atPath: archiveDir.path))
        XCTAssertTrue(fm.fileExists(atPath: dataDir.path))
        XCTAssertTrue(fm.fileExists(atPath: archiveDir.appendingPathComponent("archive_index.json").path))
    }

    func testWriteDICOMFileToOrganizedPath() throws {
        let dataDir = tempDirectory.appendingPathComponent("data")
        let patientDir = dataDir.appendingPathComponent("P001")
            .appendingPathComponent("1.2.3.4.5")
            .appendingPathComponent("1.2.3.4.5.6")
        let fm = FileManager.default
        try fm.createDirectory(at: patientDir, withIntermediateDirectories: true)

        let fileData = try createMinimalDICOMFile(instanceUID: "1.2.3.4.5.6.7.1")
        let filePath = patientDir.appendingPathComponent("1.2.3.4.5.6.7.1.dcm")
        try fileData.write(to: filePath)

        XCTAssertTrue(fm.fileExists(atPath: filePath.path))
        let readBack = try Data(contentsOf: filePath)
        let dicomFile = try DICOMFile.read(from: readBack)
        XCTAssertEqual(dicomFile.dataSet.string(for: .sopInstanceUID), "1.2.3.4.5.6.7.1")
    }

    func testSanitizePathComponent() {
        XCTAssertEqual(sanitizePathComponent("simple"), "simple")
        XCTAssertEqual(sanitizePathComponent("hello world"), "hello_world")
        XCTAssertEqual(sanitizePathComponent("file/name"), "file_name")
        XCTAssertEqual(sanitizePathComponent("path\\to\\file"), "path_to_file")
        XCTAssertEqual(sanitizePathComponent("DOE^JOHN"), "DOE_JOHN")
        XCTAssertEqual(sanitizePathComponent("name@host.com"), "name_host.com")
        XCTAssertEqual(sanitizePathComponent("a-b_c.d"), "a-b_c.d")
        XCTAssertEqual(sanitizePathComponent(""), "UNKNOWN")
    }

    func testDuplicateDetectionBySOPInstanceUID() throws {
        let sopUID = "1.2.3.4.5.6.7.DUPLICATE"
        let file1 = try createMinimalDICOMFile(instanceUID: sopUID)
        let file2 = try createMinimalDICOMFile(instanceUID: sopUID)

        let dicom1 = try DICOMFile.read(from: file1)
        let dicom2 = try DICOMFile.read(from: file2)

        let uid1 = dicom1.dataSet.string(for: .sopInstanceUID)
        let uid2 = dicom2.dataSet.string(for: .sopInstanceUID)
        XCTAssertEqual(uid1, uid2)

        // Simulate deduplication set
        var existingSOPs = Set<String>()
        existingSOPs.insert(uid1!)
        XCTAssertTrue(existingSOPs.contains(uid2!))
    }

    func testMultiplePatientDirectories() throws {
        let dataDir = tempDirectory.appendingPathComponent("data")
        let fm = FileManager.default

        for pid in ["P001", "P002", "P003"] {
            let patientDir = dataDir.appendingPathComponent(pid)
            try fm.createDirectory(at: patientDir, withIntermediateDirectories: true)
        }

        let contents = try fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(contents.count, 3)
    }

    func testMultipleStudyDirectories() throws {
        let dataDir = tempDirectory.appendingPathComponent("data").appendingPathComponent("P001")
        let fm = FileManager.default

        for i in 1...4 {
            let studyDir = dataDir.appendingPathComponent("study_\(i)")
            try fm.createDirectory(at: studyDir, withIntermediateDirectories: true)
        }

        let contents = try fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(contents.count, 4)
    }

    func testMultipleSeriesDirectories() throws {
        let studyDir = tempDirectory.appendingPathComponent("data")
            .appendingPathComponent("P001")
            .appendingPathComponent("study_1")
        let fm = FileManager.default

        for i in 1...3 {
            let seriesDir = studyDir.appendingPathComponent("series_\(i)")
            try fm.createDirectory(at: seriesDir, withIntermediateDirectories: true)
        }

        let contents = try fm.contentsOfDirectory(at: studyDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(contents.count, 3)
    }

    func testOrganizedFileRoundTrip() throws {
        let sopUID = "1.2.3.4.5.6.7.ROUNDTRIP"
        let safeSOP = sanitizePathComponent(sopUID)
        let seriesDir = tempDirectory.appendingPathComponent("data")
            .appendingPathComponent("P001")
            .appendingPathComponent("1.2.3.4.5")
            .appendingPathComponent("1.2.3.4.5.6")
        try FileManager.default.createDirectory(at: seriesDir, withIntermediateDirectories: true)

        let fileData = try createMinimalDICOMFile(
            patientName: "ROUND^TRIP",
            patientID: "P001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.6",
            instanceUID: sopUID
        )

        let filePath = seriesDir.appendingPathComponent("\(safeSOP).dcm")
        try fileData.write(to: filePath)

        let readData = try Data(contentsOf: filePath)
        let dicomFile = try DICOMFile.read(from: readData)
        XCTAssertEqual(dicomFile.dataSet.string(for: .patientName), "ROUND^TRIP")
        XCTAssertEqual(dicomFile.dataSet.string(for: .patientID), "P001")
        XCTAssertEqual(dicomFile.dataSet.string(for: .sopInstanceUID), sopUID)
    }

    // MARK: - Wildcard Matching Tests

    func testExactMatch() {
        XCTAssertTrue(wildcardMatch("DOE^JOHN", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("hello", "hello"))
    }

    func testAsteriskWildcard() {
        XCTAssertTrue(wildcardMatch("DOE*", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("*JOHN", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("*OE*", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("*", "anything"))
        XCTAssertTrue(wildcardMatch("**", "anything"))
    }

    func testQuestionMarkWildcard() {
        XCTAssertTrue(wildcardMatch("DOE?JOHN", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("D??", "DOE"))
        XCTAssertFalse(wildcardMatch("D?", "DOE"))
        XCTAssertFalse(wildcardMatch("D???", "DOE"))
    }

    func testCombinedWildcards() {
        XCTAssertTrue(wildcardMatch("D*?N", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("?OE*", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("*?", "A"))
        XCTAssertTrue(wildcardMatch("?*?", "AB"))
        XCTAssertFalse(wildcardMatch("?*?", "A"))
    }

    func testCaseInsensitiveMatch() {
        XCTAssertTrue(wildcardMatch("doe^john", "DOE^JOHN"))
        XCTAssertTrue(wildcardMatch("DOE^JOHN", "doe^john"))
        XCTAssertTrue(wildcardMatch("Doe*", "DOE^JOHN"))
    }

    func testNoMatch() {
        XCTAssertFalse(wildcardMatch("SMITH", "DOE^JOHN"))
        XCTAssertFalse(wildcardMatch("DOE", "DOE^JOHN"))
        XCTAssertFalse(wildcardMatch("JOHN", "DOE^JOHN"))
    }

    func testEmptyPattern() {
        XCTAssertTrue(wildcardMatch("", ""))
        XCTAssertFalse(wildcardMatch("", "text"))
    }

    func testEmptyText() {
        XCTAssertFalse(wildcardMatch("pattern", ""))
        XCTAssertTrue(wildcardMatch("*", ""))
        XCTAssertTrue(wildcardMatch("", ""))
    }

    // MARK: - Archive Workflow Tests

    func testInitializeArchive() throws {
        let archiveDir = tempDirectory.appendingPathComponent("new_archive")
        let dataDir = archiveDir.appendingPathComponent("data")
        let fm = FileManager.default

        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let index = createTestArchiveIndex()
        try saveTestArchiveIndex(index, to: archiveDir)

        XCTAssertTrue(fm.fileExists(atPath: archiveDir.appendingPathComponent("archive_index.json").path))
        XCTAssertTrue(fm.fileExists(atPath: dataDir.path))

        let loaded = try loadTestArchiveIndex(from: archiveDir)
        XCTAssertEqual(loaded.version, "1.2.1")
        XCTAssertEqual(loaded.patients.count, 0)
        XCTAssertEqual(loaded.fileCount, 0)
    }

    func testImportSingleFile() throws {
        let archiveDir = tempDirectory.appendingPathComponent("import_test")
        let dataDir = archiveDir.appendingPathComponent("data")
        let fm = FileManager.default
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let sopUID = "1.2.3.4.5.6.7.SINGLE"
        let fileData = try createMinimalDICOMFile(
            patientName: "IMPORT^TEST",
            patientID: "IMP001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.6",
            instanceUID: sopUID,
            modality: "CT"
        )
        let dicomFile = try DICOMFile.read(from: fileData)
        let ds = dicomFile.dataSet

        // Simulate import: write file to organized path
        let safePID = sanitizePathComponent(ds.string(for: .patientID) ?? "UNKNOWN")
        let safeStudy = sanitizePathComponent(ds.string(for: .studyInstanceUID) ?? "UNKNOWN")
        let safeSeries = sanitizePathComponent(ds.string(for: .seriesInstanceUID) ?? "UNKNOWN")
        let fileName = sanitizePathComponent(sopUID) + ".dcm"

        let destDir = dataDir
            .appendingPathComponent(safePID)
            .appendingPathComponent(safeStudy)
            .appendingPathComponent(safeSeries)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        try fileData.write(to: destDir.appendingPathComponent(fileName))

        // Create index entry
        let instance = TestArchiveInstance(
            sopInstanceUID: sopUID,
            sopClassUID: ds.string(for: .sopClassUID) ?? "",
            filePath: "\(safePID)/\(safeStudy)/\(safeSeries)/\(fileName)",
            fileSize: Int64(fileData.count),
            importDate: "2024-01-01T00:00:00Z",
            instanceNumber: ds.string(for: .instanceNumber)
        )
        let series = TestArchiveSeries(
            seriesInstanceUID: ds.string(for: .seriesInstanceUID) ?? "",
            modality: ds.string(for: .modality) ?? "",
            seriesDescription: nil,
            seriesNumber: ds.string(for: .seriesNumber),
            instances: [instance]
        )
        let study = TestArchiveStudy(
            studyInstanceUID: ds.string(for: .studyInstanceUID) ?? "",
            studyDate: ds.string(for: .studyDate),
            studyDescription: nil,
            modality: ds.string(for: .modality),
            accessionNumber: nil,
            series: [series]
        )
        let patient = TestArchivePatient(
            patientName: ds.string(for: .patientName) ?? "UNKNOWN",
            patientID: ds.string(for: .patientID) ?? "UNKNOWN",
            studies: [study]
        )
        let index = createTestArchiveIndex(patients: [patient], fileCount: 1)
        try saveTestArchiveIndex(index, to: archiveDir)

        // Verify
        let loaded = try loadTestArchiveIndex(from: archiveDir)
        XCTAssertEqual(loaded.fileCount, 1)
        XCTAssertEqual(loaded.patients.count, 1)
        XCTAssertEqual(loaded.patients[0].patientName, "IMPORT^TEST")
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent(fileName).path))
    }

    func testImportMultipleFiles() throws {
        let archiveDir = tempDirectory.appendingPathComponent("multi_import")
        let dataDir = archiveDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        var instances: [TestArchiveInstance] = []
        for i in 1...5 {
            let sopUID = "1.2.3.4.5.6.7.\(i)"
            let fileData = try createMinimalDICOMFile(
                patientName: "MULTI^IMPORT",
                patientID: "MI001",
                studyUID: "1.2.3.4.5",
                seriesUID: "1.2.3.4.5.6",
                instanceUID: sopUID
            )
            let safeSeries = "1.2.3.4.5.6"
            let destDir = dataDir.appendingPathComponent("MI001")
                .appendingPathComponent("1.2.3.4.5")
                .appendingPathComponent(safeSeries)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let fileName = "\(sopUID).dcm"
            try fileData.write(to: destDir.appendingPathComponent(fileName))

            instances.append(TestArchiveInstance(
                sopInstanceUID: sopUID,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                filePath: "MI001/1.2.3.4.5/\(safeSeries)/\(fileName)",
                fileSize: Int64(fileData.count),
                importDate: "2024-01-01T00:00:00Z",
                instanceNumber: "\(i)"
            ))
        }

        let series = TestArchiveSeries(
            seriesInstanceUID: "1.2.3.4.5.6",
            modality: "CT",
            seriesDescription: nil,
            seriesNumber: "1",
            instances: instances
        )
        let study = TestArchiveStudy(
            studyInstanceUID: "1.2.3.4.5",
            studyDate: "20240101",
            studyDescription: nil,
            modality: "CT",
            accessionNumber: nil,
            series: [series]
        )
        let patient = TestArchivePatient(
            patientName: "MULTI^IMPORT",
            patientID: "MI001",
            studies: [study]
        )
        let index = createTestArchiveIndex(patients: [patient], fileCount: 5)
        try saveTestArchiveIndex(index, to: archiveDir)

        let loaded = try loadTestArchiveIndex(from: archiveDir)
        XCTAssertEqual(loaded.fileCount, 5)
        XCTAssertEqual(loaded.patients[0].studies[0].series[0].instances.count, 5)
    }

    func testImportDuplicateSkipped() throws {
        let sopUID = "1.2.3.4.5.6.7.DUP"
        var existingSOPs = Set<String>()

        // First import
        let file1 = try createMinimalDICOMFile(instanceUID: sopUID)
        let dicom1 = try DICOMFile.read(from: file1)
        let uid1 = dicom1.dataSet.string(for: .sopInstanceUID)!
        existingSOPs.insert(uid1)

        // Second import attempt
        let file2 = try createMinimalDICOMFile(instanceUID: sopUID)
        let dicom2 = try DICOMFile.read(from: file2)
        let uid2 = dicom2.dataSet.string(for: .sopInstanceUID)!

        // Should be detected as duplicate
        XCTAssertTrue(existingSOPs.contains(uid2))
    }

    func testExportByStudyUID() throws {
        let archiveDir = tempDirectory.appendingPathComponent("export_test")
        let dataDir = archiveDir.appendingPathComponent("data")
        let exportDir = tempDirectory.appendingPathComponent("export_output")
        let fm = FileManager.default

        // Set up archive with file
        let sopUID = "1.2.3.4.5.6.7.EXPORT"
        let fileData = try createMinimalDICOMFile(
            patientName: "EXPORT^TEST",
            patientID: "EXP001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.6",
            instanceUID: sopUID
        )

        let safeSOP = sanitizePathComponent(sopUID)
        let seriesDir = dataDir.appendingPathComponent("EXP001")
            .appendingPathComponent("1.2.3.4.5")
            .appendingPathComponent("1.2.3.4.5.6")
        try fm.createDirectory(at: seriesDir, withIntermediateDirectories: true)
        try fileData.write(to: seriesDir.appendingPathComponent("\(safeSOP).dcm"))

        let instance = TestArchiveInstance(
            sopInstanceUID: sopUID,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "EXP001/1.2.3.4.5/1.2.3.4.5.6/\(safeSOP).dcm",
            fileSize: Int64(fileData.count),
            importDate: "2024-01-01T00:00:00Z",
            instanceNumber: "1"
        )
        let series = TestArchiveSeries(
            seriesInstanceUID: "1.2.3.4.5.6", modality: "CT",
            seriesDescription: nil, seriesNumber: "1", instances: [instance]
        )
        let study = TestArchiveStudy(
            studyInstanceUID: "1.2.3.4.5", studyDate: "20240101",
            studyDescription: nil, modality: "CT", accessionNumber: nil, series: [series]
        )
        let patient = TestArchivePatient(
            patientName: "EXPORT^TEST", patientID: "EXP001", studies: [study]
        )
        let index = createTestArchiveIndex(patients: [patient], fileCount: 1)

        // Simulate export: filter by study UID and copy matching files
        let targetStudyUID = "1.2.3.4.5"
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        var exported = 0
        for p in index.patients {
            for st in p.studies {
                guard st.studyInstanceUID == targetStudyUID else { continue }
                for se in st.series {
                    for inst in se.instances {
                        let sourceFile = dataDir.appendingPathComponent(inst.filePath)
                        let destFile = exportDir.appendingPathComponent(sanitizePathComponent(inst.sopInstanceUID) + ".dcm")
                        try fm.copyItem(at: sourceFile, to: destFile)
                        exported += 1
                    }
                }
            }
        }

        XCTAssertEqual(exported, 1)
        let exportedFiles = try fm.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(exportedFiles.count, 1)

        // Verify exported file is valid DICOM
        let exportedData = try Data(contentsOf: exportedFiles[0])
        let exportedDicom = try DICOMFile.read(from: exportedData)
        XCTAssertEqual(exportedDicom.dataSet.string(for: .sopInstanceUID), sopUID)
    }

    func testIntegrityCheckAllPresent() throws {
        let archiveDir = tempDirectory.appendingPathComponent("integrity_ok")
        let dataDir = archiveDir.appendingPathComponent("data")
        let fm = FileManager.default

        let sopUID = "1.2.3.4.5.6.7.INTEG"
        let fileData = try createMinimalDICOMFile(instanceUID: sopUID)
        let safeSOP = sanitizePathComponent(sopUID)
        let relativePath = "P001/1.2.3.4.5/1.2.3.4.5.6/\(safeSOP).dcm"

        let destDir = dataDir.appendingPathComponent("P001")
            .appendingPathComponent("1.2.3.4.5")
            .appendingPathComponent("1.2.3.4.5.6")
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        try fileData.write(to: destDir.appendingPathComponent("\(safeSOP).dcm"))

        let instance = TestArchiveInstance(
            sopInstanceUID: sopUID,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: relativePath,
            fileSize: Int64(fileData.count),
            importDate: "2024-01-01T00:00:00Z",
            instanceNumber: "1"
        )

        // Check integrity: file exists and size matches
        let filePath = dataDir.appendingPathComponent(instance.filePath).path
        XCTAssertTrue(fm.fileExists(atPath: filePath))

        let attrs = try fm.attributesOfItem(atPath: filePath)
        let fileSize = attrs[.size] as? Int64 ?? (attrs[.size] as? UInt64).map { Int64($0) } ?? 0
        XCTAssertEqual(fileSize, instance.fileSize)
    }

    func testIntegrityCheckMissingFile() throws {
        let archiveDir = tempDirectory.appendingPathComponent("integrity_missing")
        let dataDir = archiveDir.appendingPathComponent("data")
        let fm = FileManager.default
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let instance = TestArchiveInstance(
            sopInstanceUID: "1.2.3.MISSING",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "P001/study/series/missing.dcm",
            fileSize: 999,
            importDate: "2024-01-01T00:00:00Z",
            instanceNumber: "1"
        )

        let filePath = dataDir.appendingPathComponent(instance.filePath).path
        XCTAssertFalse(fm.fileExists(atPath: filePath))
    }

    func testStatisticsComputation() throws {
        // Build an index with known structure
        var patients: [TestArchivePatient] = []

        // Patient 1: 2 studies, 1 series each, 3 + 2 instances
        let instances1 = (1...3).map { i in
            TestArchiveInstance(
                sopInstanceUID: "1.1.\(i)", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                filePath: "f\(i).dcm", fileSize: Int64(100 * i),
                importDate: "2024-01-01T00:00:00Z", instanceNumber: "\(i)"
            )
        }
        let instances2 = (1...2).map { i in
            TestArchiveInstance(
                sopInstanceUID: "1.2.\(i)", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                filePath: "f\(i).dcm", fileSize: Int64(200 * i),
                importDate: "2024-01-01T00:00:00Z", instanceNumber: "\(i)"
            )
        }
        let s1 = TestArchiveSeries(seriesInstanceUID: "1.1.1.1", modality: "CT", seriesDescription: nil, seriesNumber: "1", instances: instances1)
        let s2 = TestArchiveSeries(seriesInstanceUID: "1.2.1.1", modality: "MR", seriesDescription: nil, seriesNumber: "1", instances: instances2)
        let st1 = TestArchiveStudy(studyInstanceUID: "1.1", studyDate: "20240101", studyDescription: nil, modality: "CT", accessionNumber: nil, series: [s1])
        let st2 = TestArchiveStudy(studyInstanceUID: "1.2", studyDate: "20240202", studyDescription: nil, modality: "MR", accessionNumber: nil, series: [s2])
        patients.append(TestArchivePatient(patientName: "STATS^ONE", patientID: "S001", studies: [st1, st2]))

        // Patient 2: 1 study, 2 series, 1 instance each
        let instances3 = [TestArchiveInstance(
            sopInstanceUID: "2.1.1", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "f3.dcm", fileSize: 300,
            importDate: "2024-01-01T00:00:00Z", instanceNumber: "1"
        )]
        let instances4 = [TestArchiveInstance(
            sopInstanceUID: "2.2.1", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            filePath: "f4.dcm", fileSize: 400,
            importDate: "2024-01-01T00:00:00Z", instanceNumber: "1"
        )]
        let s3 = TestArchiveSeries(seriesInstanceUID: "2.1.1.1", modality: "US", seriesDescription: nil, seriesNumber: "1", instances: instances3)
        let s4 = TestArchiveSeries(seriesInstanceUID: "2.2.1.1", modality: "US", seriesDescription: nil, seriesNumber: "2", instances: instances4)
        let st3 = TestArchiveStudy(studyInstanceUID: "2.1", studyDate: "20240303", studyDescription: nil, modality: "US", accessionNumber: nil, series: [s3, s4])
        patients.append(TestArchivePatient(patientName: "STATS^TWO", patientID: "S002", studies: [st3]))

        let index = createTestArchiveIndex(patients: patients, fileCount: 7)

        // Compute statistics (mirrors the archive tool's stats logic)
        var totalSeries = 0
        var totalInstances = 0
        var totalSize: Int64 = 0
        var modalities = [String: Int]()

        for patient in index.patients {
            for study in patient.studies {
                for series in study.series {
                    totalSeries += 1
                    totalInstances += series.instances.count
                    modalities[series.modality, default: 0] += series.instances.count
                    for instance in series.instances {
                        totalSize += instance.fileSize
                    }
                }
            }
        }
        let totalStudies = index.patients.reduce(0) { $0 + $1.studies.count }

        XCTAssertEqual(index.patients.count, 2)
        XCTAssertEqual(totalStudies, 3)
        XCTAssertEqual(totalSeries, 4)
        XCTAssertEqual(totalInstances, 7)
        XCTAssertEqual(totalSize, 100 + 200 + 300 + 200 + 400 + 300 + 400)
        XCTAssertEqual(modalities["CT"], 3)
        XCTAssertEqual(modalities["MR"], 2)
        XCTAssertEqual(modalities["US"], 2)
    }

    // MARK: - Edge Case Tests

    func testMissingPatientName() throws {
        // Create DICOM without patient name
        var fileMeta = DataSet()
        var versionData = Data(count: 2)
        versionData[0] = 0x00
        versionData[1] = 0x01
        fileMeta[.fileMetaInformationVersion] = DataElement.data(tag: .fileMetaInformationVersion, vr: .OB, data: versionData)
        fileMeta[.mediaStorageSOPClassUID] = DataElement.string(tag: .mediaStorageSOPClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        fileMeta[.mediaStorageSOPInstanceUID] = DataElement.string(tag: .mediaStorageSOPInstanceUID, vr: .UI, value: "1.2.3.NONAME")
        fileMeta[.transferSyntaxUID] = DataElement.string(tag: .transferSyntaxUID, vr: .UI, value: TransferSyntax.explicitVRLittleEndian.uid)
        fileMeta[.implementationClassUID] = DataElement.string(tag: .implementationClassUID, vr: .UI, value: "1.2.826.0.1.3680043.10.1")

        var dataSet = DataSet()
        dataSet[.sopClassUID] = DataElement.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        dataSet[.sopInstanceUID] = DataElement.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.NONAME")
        dataSet[.patientID] = DataElement.string(tag: .patientID, vr: .LO, value: "NOPAT")
        dataSet[.studyInstanceUID] = DataElement.string(tag: .studyInstanceUID, vr: .UI, value: "1.2.3.4.5")
        dataSet[.seriesInstanceUID] = DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: "1.2.3.4.5.6")
        // No patientName set

        let file = DICOMFile(fileMetaInformation: fileMeta, dataSet: dataSet)
        let fileData = try file.write()
        let dicomFile = try DICOMFile.read(from: fileData)

        // The archive tool defaults to "UNKNOWN" when patientName is nil
        let patientName = dicomFile.dataSet.string(for: .patientName) ?? "UNKNOWN"
        XCTAssertEqual(patientName, "UNKNOWN")
    }

    func testMissingModality() throws {
        var fileMeta = DataSet()
        var versionData = Data(count: 2)
        versionData[0] = 0x00
        versionData[1] = 0x01
        fileMeta[.fileMetaInformationVersion] = DataElement.data(tag: .fileMetaInformationVersion, vr: .OB, data: versionData)
        fileMeta[.mediaStorageSOPClassUID] = DataElement.string(tag: .mediaStorageSOPClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        fileMeta[.mediaStorageSOPInstanceUID] = DataElement.string(tag: .mediaStorageSOPInstanceUID, vr: .UI, value: "1.2.3.NOMOD")
        fileMeta[.transferSyntaxUID] = DataElement.string(tag: .transferSyntaxUID, vr: .UI, value: TransferSyntax.explicitVRLittleEndian.uid)
        fileMeta[.implementationClassUID] = DataElement.string(tag: .implementationClassUID, vr: .UI, value: "1.2.826.0.1.3680043.10.1")

        var dataSet = DataSet()
        dataSet[.sopClassUID] = DataElement.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2")
        dataSet[.sopInstanceUID] = DataElement.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.NOMOD")
        dataSet[.patientName] = DataElement.string(tag: .patientName, vr: .PN, value: "NOMOD^TEST")
        dataSet[.patientID] = DataElement.string(tag: .patientID, vr: .LO, value: "NM001")
        dataSet[.studyInstanceUID] = DataElement.string(tag: .studyInstanceUID, vr: .UI, value: "1.2.3.4.5")
        dataSet[.seriesInstanceUID] = DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: "1.2.3.4.5.6")
        // No modality set

        let file = DICOMFile(fileMetaInformation: fileMeta, dataSet: dataSet)
        let fileData = try file.write()
        let dicomFile = try DICOMFile.read(from: fileData)

        // The archive tool defaults to "" when modality is nil
        let modality = dicomFile.dataSet.string(for: .modality) ?? ""
        XCTAssertEqual(modality, "")
    }

    func testEmptyArchiveQuery() throws {
        let index = createTestArchiveIndex()

        // Simulate query with wildcard on empty archive
        let results = index.patients.filter { wildcardMatch("DOE*", $0.patientName) }
        XCTAssertTrue(results.isEmpty)
    }

    func testLargePatientIDSanitization() {
        let longID = String(repeating: "A", count: 1000)
        let sanitized = sanitizePathComponent(longID)
        XCTAssertEqual(sanitized.count, 1000)
        XCTAssertEqual(sanitized, longID)
    }

    func testSpecialCharactersInPaths() {
        XCTAssertEqual(sanitizePathComponent("日本語テスト"), "______")
        XCTAssertEqual(sanitizePathComponent("DOE^JOHN M.D."), "DOE_JOHN_M.D.")
        XCTAssertEqual(sanitizePathComponent("test (copy)"), "test__copy_")
        XCTAssertEqual(sanitizePathComponent("file<>:\"|?*"), "file_______")
        XCTAssertEqual(sanitizePathComponent("1.2.3.4.5"), "1.2.3.4.5")
    }
}