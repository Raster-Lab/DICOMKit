import Testing
import Foundation
@testable import DICOMWeb

/// Locks the shared `QIDOResultFormatter` rendering. This is the SINGLE formatter
/// the `dicom-wado query` CLI and the CLI Workshop's in-app query both call, so these
/// expectations are exactly what the CLI prints — a drift here is a real app↔CLI
/// divergence (the bug that motivated the shared formatter: the app used to ignore
/// `--format table` and dump a verbose per-record block instead of the table).
@Suite("QIDOResultFormatter")
struct QIDOResultFormatterTests {

    private func study() -> QIDOStudyResult {
        QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3"]],
            "00100010": ["vr": "PN", "Value": [["Alphabetic": "DOE^JOHN"]]],
            "00100020": ["vr": "LO", "Value": ["P1"]],
            "00080020": ["vr": "DA", "Value": ["20240101"]],
            "00081030": ["vr": "LO", "Value": ["CHEST"]],
            "00080061": ["vr": "CS", "Value": ["CT"]],
            "00201206": ["vr": "IS", "Value": [2]],
        ])
    }

    @Test("Study table reproduces the CLI's bordered table")
    func studyTable() {
        let out = QIDOResultFormatter().formatStudies([study()], format: .table)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Header + one data row between three 120-wide "=" borders (the format the
        // CLIParityWADOComparator.count(in:format:) parser depends on).
        #expect(lines[0] == String(repeating: "=", count: 120))
        #expect(lines[1].hasPrefix("Study UID"))
        #expect(lines[1].contains("Patient Name"))
        #expect(lines[1].contains("# Series"))
        #expect(lines[2] == String(repeating: "=", count: 120))
        #expect(lines[3].hasPrefix("1.2.3"))
        #expect(lines[3].contains("DOE^JOHN"))
        #expect(lines[3].contains("20240101"))
        #expect(lines[3].contains("CT"))
        #expect(lines[4] == String(repeating: "=", count: 120))
    }

    @Test("Study CSV header + row match the CLI exactly")
    func studyCSV() {
        let out = QIDOResultFormatter().formatStudies([study()], format: .csv)
        let lines = out.split(separator: "\n").map(String.init)
        #expect(lines[0] == "StudyInstanceUID,PatientName,PatientID,StudyDate,StudyDescription,ModalitiesInStudy,NumberOfSeries")
        #expect(lines[1] == "1.2.3,DOE^JOHN,P1,20240101,CHEST,CT,2")
    }

    @Test("Study JSON is pretty-printed with sorted keys")
    func studyJSON() {
        let out = QIDOResultFormatter().formatStudies([study()], format: .json)
        // Valid JSON array carrying the study's attributes.
        let data = out.data(using: .utf8)!
        let arr = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(arr.count == 1)
        #expect(arr[0]["StudyInstanceUID"] as? String == "1.2.3")
        #expect(arr[0]["PatientName"] as? String == "DOE^JOHN")
        #expect(arr[0]["NumberOfStudyRelatedSeries"] as? Int == 2)
        // sortedKeys → PatientID sorts before StudyInstanceUID in the emitted text.
        #expect(out.range(of: "PatientID")!.lowerBound < out.range(of: "StudyInstanceUID")!.lowerBound)
    }

    @Test("Empty study set still prints the bordered (header-only) table, like the CLI")
    func emptyStudyTable() {
        let out = QIDOResultFormatter().formatStudies([], format: .table)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.isEmpty }
        // Top border + header + mid border + bottom border (no data rows), and crucially
        // no "No results" sentinel — the QIDO CLI prints the empty table, unlike the
        // DIMSE formatter which prints "No results found.".
        #expect(lines.count == 4)
        #expect(!out.contains("No results"))
    }
}
