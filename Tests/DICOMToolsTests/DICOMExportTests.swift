import XCTest
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary
import Foundation

/// Tests for dicom-export tool
///
/// Tests export format parsing, EXIF metadata mapping, contact sheet layout,
/// animation parameters, bulk export organization, and DICOM file operations.
final class DICOMExportTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMExportTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Test-local Types

    /// Export image format (mirrors the CLI tool's enum)
    private enum TestExportImageFormat: String, CaseIterable {
        case png
        case jpeg
        case tiff

        var fileExtension: String { rawValue }
    }

    /// Organization scheme (mirrors the CLI tool's enum)
    private enum TestOrganizationScheme: String, CaseIterable {
        case flat
        case patient
        case study
        case series
    }

    // MARK: - Test-local Helper Methods

    /// Sanitize a path component (mirrors the CLI tool's logic)
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

    /// Builds the output path (mirrors the CLI tool's logic)
    private func buildOrganizedPath(
        baseOutput: String,
        scheme: TestOrganizationScheme,
        patientName: String?,
        studyUID: String?,
        seriesUID: String?,
        filename: String
    ) -> String {
        switch scheme {
        case .flat:
            return (baseOutput as NSString).appendingPathComponent(filename)
        case .patient:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            return (baseOutput as NSString)
                .appendingPathComponent(patient)
                .appending("/\(filename)")
        case .study:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
            return (baseOutput as NSString)
                .appendingPathComponent(patient)
                .appending("/\(study)/\(filename)")
        case .series:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
            let series = sanitizePathComponent(seriesUID ?? "UNKNOWN")
            return (baseOutput as NSString)
                .appendingPathComponent(patient)
                .appending("/\(study)/\(series)/\(filename)")
        }
    }

    /// Computes contact sheet layout (mirrors the CLI tool's logic)
    private func contactSheetLayout(
        imageCount: Int,
        columns: Int,
        thumbnailSize: Int,
        spacing: Int,
        includeLabels: Bool
    ) -> (rows: Int, totalWidth: Int, totalHeight: Int) {
        let rows = max(1, (imageCount + columns - 1) / columns)
        let labelHeight = includeLabels ? 20 : 0
        let totalWidth = columns * thumbnailSize + (columns + 1) * spacing
        let totalHeight = rows * (thumbnailSize + labelHeight) + (rows + 1) * spacing
        return (rows, totalWidth, totalHeight)
    }

    /// Returns thumbnail position (mirrors the CLI tool's logic)
    private func thumbnailPosition(
        index: Int,
        columns: Int,
        thumbnailSize: Int,
        spacing: Int,
        includeLabels: Bool
    ) -> (x: Int, y: Int) {
        let col = index % columns
        let row = index / columns
        let labelHeight = includeLabels ? 20 : 0
        let x = spacing + col * (thumbnailSize + spacing)
        let y = spacing + row * (thumbnailSize + labelHeight + spacing)
        return (x, y)
    }

    /// GIF frame delay from FPS (mirrors the CLI tool's logic)
    private func gifFrameDelay(fps: Double) -> Double {
        guard fps > 0 else { return 0.1 }
        return 1.0 / fps
    }

    /// Validates and clamps frame range (mirrors the CLI tool's logic)
    private func validatedFrameRange(start: Int, end: Int?, totalFrames: Int) -> (start: Int, end: Int)? {
        guard totalFrames > 0 else { return nil }
        let clampedStart = max(0, min(start, totalFrames - 1))
        let clampedEnd: Int
        if let end = end {
            clampedEnd = max(clampedStart, min(end, totalFrames - 1))
        } else {
            clampedEnd = totalFrames - 1
        }
        return (clampedStart, clampedEnd)
    }

    /// Maps DICOM field to EXIF dictionary key (mirrors the CLI tool's logic)
    private func mapDICOMFieldToEXIF(_ field: String) -> (dictionary: String, key: String)? {
        switch field.lowercased() {
        case "patientname":
            return ("tiff", "ImageDescription")
        case "studydate":
            return ("exif", "DateTimeOriginal")
        case "modality":
            return ("exif", "Software")
        case "studydescription":
            return ("tiff", "DocumentName")
        case "seriesdescription":
            return ("exif", "UserComment")
        case "institutionname":
            return ("tiff", "Artist")
        case "manufacturer":
            return ("tiff", "Make")
        case "manufacturermodelname":
            return ("tiff", "Model")
        case "stationname":
            return ("tiff", "HostComputer")
        default:
            return nil
        }
    }

    /// Create a minimal DICOM file for testing
    private func createMinimalDICOMFile(
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

    // MARK: - Export Format Tests

    func testExportFormatParsing() {
        XCTAssertEqual(TestExportImageFormat(rawValue: "png"), .png)
        XCTAssertEqual(TestExportImageFormat(rawValue: "jpeg"), .jpeg)
        XCTAssertEqual(TestExportImageFormat(rawValue: "tiff"), .tiff)
        XCTAssertNil(TestExportImageFormat(rawValue: "bmp"))
        XCTAssertNil(TestExportImageFormat(rawValue: "gif"))
    }

    func testExportFormatFileExtension() {
        XCTAssertEqual(TestExportImageFormat.png.fileExtension, "png")
        XCTAssertEqual(TestExportImageFormat.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(TestExportImageFormat.tiff.fileExtension, "tiff")
    }

    func testExportFormatAllCases() {
        let allCases = TestExportImageFormat.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.png))
        XCTAssertTrue(allCases.contains(.jpeg))
        XCTAssertTrue(allCases.contains(.tiff))
    }

    func testExportFormatRawValues() {
        XCTAssertEqual(TestExportImageFormat.png.rawValue, "png")
        XCTAssertEqual(TestExportImageFormat.jpeg.rawValue, "jpeg")
        XCTAssertEqual(TestExportImageFormat.tiff.rawValue, "tiff")
    }

    func testExportFormatCaseInsensitivity() {
        // Raw value parsing is case-sensitive for enum
        XCTAssertNil(TestExportImageFormat(rawValue: "PNG"))
        XCTAssertNil(TestExportImageFormat(rawValue: "JPEG"))
        XCTAssertNil(TestExportImageFormat(rawValue: "TIFF"))
    }

    // MARK: - EXIF Metadata Mapping Tests

    func testEXIFMappingPatientName() {
        let mapping = mapDICOMFieldToEXIF("PatientName")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.dictionary, "tiff")
        XCTAssertEqual(mapping?.key, "ImageDescription")
    }

    func testEXIFMappingStudyDate() {
        let mapping = mapDICOMFieldToEXIF("StudyDate")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.dictionary, "exif")
        XCTAssertEqual(mapping?.key, "DateTimeOriginal")
    }

    func testEXIFMappingModality() {
        let mapping = mapDICOMFieldToEXIF("Modality")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.dictionary, "exif")
        XCTAssertEqual(mapping?.key, "Software")
    }

    func testEXIFMappingManufacturer() {
        let mapping = mapDICOMFieldToEXIF("Manufacturer")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.dictionary, "tiff")
        XCTAssertEqual(mapping?.key, "Make")
    }

    func testEXIFMappingUnknownField() {
        let mapping = mapDICOMFieldToEXIF("UnknownField")
        XCTAssertNil(mapping)
    }

    func testEXIFMappingCaseInsensitive() {
        let mapping1 = mapDICOMFieldToEXIF("patientname")
        let mapping2 = mapDICOMFieldToEXIF("PATIENTNAME")
        XCTAssertNotNil(mapping1)
        XCTAssertNotNil(mapping2)
        XCTAssertEqual(mapping1?.key, mapping2?.key)
    }

    func testEXIFMappingAllFields() {
        let fields = ["PatientName", "StudyDate", "Modality", "StudyDescription",
                       "SeriesDescription", "InstitutionName", "Manufacturer",
                       "ManufacturerModelName", "StationName"]
        for field in fields {
            XCTAssertNotNil(mapDICOMFieldToEXIF(field), "Expected mapping for \(field)")
        }
    }

    // MARK: - Contact Sheet Layout Tests

    func testContactSheetLayoutBasic() {
        let layout = contactSheetLayout(imageCount: 8, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.totalWidth, 4 * 256 + 5 * 4)  // 1044
        XCTAssertEqual(layout.totalHeight, 2 * 256 + 3 * 4)  // 524
    }

    func testContactSheetLayoutWithLabels() {
        let layout = contactSheetLayout(imageCount: 4, columns: 2, thumbnailSize: 128, spacing: 2, includeLabels: true)
        XCTAssertEqual(layout.rows, 2)
        let expectedWidth = 2 * 128 + 3 * 2  // 262
        let expectedHeight = 2 * (128 + 20) + 3 * 2  // 302
        XCTAssertEqual(layout.totalWidth, expectedWidth)
        XCTAssertEqual(layout.totalHeight, expectedHeight)
    }

    func testContactSheetLayoutSingleImage() {
        let layout = contactSheetLayout(imageCount: 1, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(layout.rows, 1)
    }

    func testContactSheetLayoutPartialRow() {
        let layout = contactSheetLayout(imageCount: 5, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(layout.rows, 2)
    }

    func testContactSheetLayoutExactRows() {
        let layout = contactSheetLayout(imageCount: 12, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(layout.rows, 3)
    }

    func testThumbnailPositionFirstItem() {
        let pos = thumbnailPosition(index: 0, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(pos.x, 4)
        XCTAssertEqual(pos.y, 4)
    }

    func testThumbnailPositionSecondRow() {
        let pos = thumbnailPosition(index: 4, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: false)
        XCTAssertEqual(pos.x, 4)  // First column
        XCTAssertEqual(pos.y, 4 + 256 + 4)  // Second row
    }

    func testThumbnailPositionWithLabels() {
        let pos = thumbnailPosition(index: 4, columns: 4, thumbnailSize: 256, spacing: 4, includeLabels: true)
        XCTAssertEqual(pos.x, 4)
        XCTAssertEqual(pos.y, 4 + (256 + 20) + 4)  // Includes label height
    }

    // MARK: - Animation Parameter Tests

    func testGifFrameDelayDefault() {
        let delay = gifFrameDelay(fps: 10)
        XCTAssertEqual(delay, 0.1, accuracy: 0.001)
    }

    func testGifFrameDelayHighFps() {
        let delay = gifFrameDelay(fps: 30)
        XCTAssertEqual(delay, 1.0 / 30.0, accuracy: 0.001)
    }

    func testGifFrameDelayZeroFps() {
        let delay = gifFrameDelay(fps: 0)
        XCTAssertEqual(delay, 0.1)
    }

    func testGifFrameDelayNegativeFps() {
        let delay = gifFrameDelay(fps: -5)
        XCTAssertEqual(delay, 0.1)
    }

    func testValidatedFrameRangeBasic() {
        let range = validatedFrameRange(start: 0, end: 9, totalFrames: 20)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 0)
        XCTAssertEqual(range?.end, 9)
    }

    func testValidatedFrameRangeNoEnd() {
        let range = validatedFrameRange(start: 5, end: nil, totalFrames: 20)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 5)
        XCTAssertEqual(range?.end, 19)
    }

    func testValidatedFrameRangeClampStart() {
        let range = validatedFrameRange(start: -5, end: 10, totalFrames: 20)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 0)
    }

    func testValidatedFrameRangeClampEnd() {
        let range = validatedFrameRange(start: 0, end: 100, totalFrames: 20)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.end, 19)
    }

    func testValidatedFrameRangeZeroFrames() {
        let range = validatedFrameRange(start: 0, end: nil, totalFrames: 0)
        XCTAssertNil(range)
    }

    // MARK: - Bulk Export Organization Tests

    func testBuildOrganizedPathFlat() {
        let path = buildOrganizedPath(
            baseOutput: "/output",
            scheme: .flat,
            patientName: "John",
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            filename: "image.png"
        )
        XCTAssertEqual(path, "/output/image.png")
    }

    func testBuildOrganizedPathPatient() {
        let path = buildOrganizedPath(
            baseOutput: "/output",
            scheme: .patient,
            patientName: "John Doe",
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            filename: "image.png"
        )
        XCTAssertTrue(path.contains("John_Doe"))
        XCTAssertTrue(path.hasSuffix("/image.png"))
    }

    func testBuildOrganizedPathStudy() {
        let path = buildOrganizedPath(
            baseOutput: "/output",
            scheme: .study,
            patientName: "Jane",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.6",
            filename: "image.png"
        )
        XCTAssertTrue(path.contains("Jane"))
        XCTAssertTrue(path.contains("1.2.3.4.5"))
        XCTAssertTrue(path.hasSuffix("/image.png"))
    }

    func testBuildOrganizedPathSeries() {
        let path = buildOrganizedPath(
            baseOutput: "/output",
            scheme: .series,
            patientName: "Patient",
            studyUID: "1.2.3",
            seriesUID: "4.5.6",
            filename: "image.png"
        )
        XCTAssertTrue(path.contains("Patient"))
        XCTAssertTrue(path.contains("1.2.3"))
        XCTAssertTrue(path.contains("4.5.6"))
        XCTAssertTrue(path.hasSuffix("/image.png"))
    }

    func testBuildOrganizedPathNilPatient() {
        let path = buildOrganizedPath(
            baseOutput: "/output",
            scheme: .patient,
            patientName: nil,
            studyUID: nil,
            seriesUID: nil,
            filename: "image.png"
        )
        XCTAssertTrue(path.contains("UNKNOWN"))
    }

    func testSanitizePathComponentSpecialChars() {
        let sanitized = sanitizePathComponent("John^Doe / CT*Study")
        XCTAssertFalse(sanitized.contains("^"))
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains("*"))
        XCTAssertFalse(sanitized.contains(" "))
    }

    func testSanitizePathComponentEmpty() {
        let sanitized = sanitizePathComponent("")
        XCTAssertEqual(sanitized, "UNKNOWN")
    }

    func testSanitizePathComponentValidChars() {
        let sanitized = sanitizePathComponent("Valid-Name_123.txt")
        XCTAssertEqual(sanitized, "Valid-Name_123.txt")
    }

    // MARK: - DICOM File Reading Tests

    func testCreateAndReadDICOMFile() throws {
        let data = try createMinimalDICOMFile()
        let file = try DICOMFile.read(from: data)
        XCTAssertNotNil(file)
    }

    func testReadDICOMFilePatientName() throws {
        let data = try createMinimalDICOMFile(patientName: "EXPORT^TEST")
        let file = try DICOMFile.read(from: data)
        let name = file.dataSet.string(for: .patientName)
        XCTAssertEqual(name, "EXPORT^TEST")
    }

    func testReadDICOMFileModality() throws {
        let data = try createMinimalDICOMFile(modality: "MR")
        let file = try DICOMFile.read(from: data)
        let modality = file.dataSet.string(for: .modality)
        XCTAssertEqual(modality, "MR")
    }

    func testReadDICOMFileStudyDate() throws {
        let data = try createMinimalDICOMFile(studyDate: "20240615")
        let file = try DICOMFile.read(from: data)
        let date = file.dataSet.string(for: .studyDate)
        XCTAssertEqual(date, "20240615")
    }

    func testReadDICOMFileStudyUID() throws {
        let data = try createMinimalDICOMFile(studyUID: "1.2.840.113619.2.1")
        let file = try DICOMFile.read(from: data)
        let uid = file.dataSet.string(for: .studyInstanceUID)
        XCTAssertEqual(uid, "1.2.840.113619.2.1")
    }

    func testWriteDICOMFileToTempDirectory() throws {
        let data = try createMinimalDICOMFile()
        let fileURL = tempDirectory.appendingPathComponent("test.dcm")
        try data.write(to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let readData = try Data(contentsOf: fileURL)
        let file = try DICOMFile.read(from: readData)
        XCTAssertNotNil(file)
    }

    func testReadDICOMFileSeriesUID() throws {
        let data = try createMinimalDICOMFile(seriesUID: "1.2.3.9.8.7")
        let file = try DICOMFile.read(from: data)
        let uid = file.dataSet.string(for: .seriesInstanceUID)
        XCTAssertEqual(uid, "1.2.3.9.8.7")
    }

    // MARK: - Organization Scheme Tests

    func testOrganizationSchemeAllCases() {
        let allCases = TestOrganizationScheme.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.flat))
        XCTAssertTrue(allCases.contains(.patient))
        XCTAssertTrue(allCases.contains(.study))
        XCTAssertTrue(allCases.contains(.series))
    }

    func testOrganizationSchemeRawValues() {
        XCTAssertEqual(TestOrganizationScheme.flat.rawValue, "flat")
        XCTAssertEqual(TestOrganizationScheme.patient.rawValue, "patient")
        XCTAssertEqual(TestOrganizationScheme.study.rawValue, "study")
        XCTAssertEqual(TestOrganizationScheme.series.rawValue, "series")
    }

    // MARK: - Additional Edge Case Tests

    func testContactSheetLayoutLargeGrid() {
        let layout = contactSheetLayout(imageCount: 100, columns: 10, thumbnailSize: 64, spacing: 2, includeLabels: false)
        XCTAssertEqual(layout.rows, 10)
        XCTAssertEqual(layout.totalWidth, 10 * 64 + 11 * 2)  // 662
        XCTAssertEqual(layout.totalHeight, 10 * 64 + 11 * 2)  // 662
    }

    func testValidatedFrameRangeSingleFrame() {
        let range = validatedFrameRange(start: 0, end: 0, totalFrames: 1)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 0)
        XCTAssertEqual(range?.end, 0)
    }

    func testValidatedFrameRangeStartBeyondTotal() {
        let range = validatedFrameRange(start: 50, end: nil, totalFrames: 10)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, 9)
        XCTAssertEqual(range?.end, 9)
    }

    func testGifFrameDelayLowFps() {
        let delay = gifFrameDelay(fps: 1)
        XCTAssertEqual(delay, 1.0, accuracy: 0.001)
    }

    func testBuildOrganizedPathSpecialCharsInPatient() {
        let path = buildOrganizedPath(
            baseOutput: "/export",
            scheme: .patient,
            patientName: "DOE^JOHN/III",
            studyUID: nil,
            seriesUID: nil,
            filename: "scan.png"
        )
        XCTAssertFalse(path.contains("^"))
    }
}
