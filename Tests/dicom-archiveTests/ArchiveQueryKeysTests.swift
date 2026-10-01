import XCTest
@testable import dicom_archive

/// `dicom-archive` query and export keys against PS3.4 2026a C.2.2.2: the archive matches
/// Study Date and UIDs by exact string, so a DICOM range (C.2.2.2.5) or UID list (C.2.2.2.2)
/// gets a warning; the help names the PS3.6 Table 6-1 attribute each key matches.
final class ArchiveQueryKeysTests: XCTestCase {

    func testSingleDAValueHasNoWarning() {
        XCTAssertNil(ArchiveQueryKeys.studyDateWarning(nil))
        XCTAssertNil(ArchiveQueryKeys.studyDateWarning("20240101"))
    }

    /// C.2.2.2.5: "<date1> - <date2>", "- <date1>", "<date1> -" are ranges.
    func testRangeIsWarned() throws {
        for value in ["20240101-20240131", "-20240131", "20240101-"] {
            let warning = try XCTUnwrap(ArchiveQueryKeys.studyDateWarning(value), value)
            XCTAssertTrue(warning.contains("Range Matching (PS3.4 C.2.2.2.5)"), value)
            XCTAssertTrue(warning.contains("Study Date (0008,0020)"))
        }
    }

    func testNonDAValueIsWarned() throws {
        let warning = try XCTUnwrap(ArchiveQueryKeys.studyDateWarning("2024/01/01"))
        XCTAssertTrue(warning.contains("not a DA value (YYYYMMDD)"))
    }

    /// C.2.2.2.2: a list of UIDs is backslash-delimited.
    func testUIDListIsWarned() throws {
        XCTAssertNil(ArchiveQueryKeys.uidListWarning(option: "--study-uid", attribute: "Study Instance UID (0020,000D)", "1.2.3"))
        let warning = try XCTUnwrap(ArchiveQueryKeys.uidListWarning(
            option: "--study-uid", attribute: "Study Instance UID (0020,000D)", "1.2.3\\4.5.6"))
        XCTAssertTrue(warning.contains("List of UID Matching (PS3.4 C.2.2.2.2)"))
    }

    func testQueryHelpNamesTheAttributes() {
        let help = DICOMArchive.Query.helpMessage(columns: 400)
        for name in ["Patient's Name (0010,0010)", "Patient ID (0010,0020)", "Study Instance UID (0020,000D)",
                     "Study Date (0008,0020)", "Modalities in Study (0008,0061)"] {
            XCTAssertTrue(help.contains(name), name)
        }
        XCTAssertTrue(help.contains("case-insensitive (tool-specific"))
    }

    func testExportHelpNamesTheAttributes() {
        let help = DICOMArchive.Export.helpMessage(columns: 400)
        for name in ["Study Instance UID (0020,000D)", "Series Instance UID (0020,000E)", "Patient ID (0010,0020)"] {
            XCTAssertTrue(help.contains(name), name)
        }
    }
}
