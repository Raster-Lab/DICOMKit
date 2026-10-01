// NEMA-verified: 2026a, checked 2026-10-01 — the archive's query and export keys against PS3.4 2026a C.2.2.2 (Single Value, List of UID C.2.2.2.2, Wild Card C.2.2.2.4, Range C.2.2.2.5 matching) and the Q/R key tables C.6-1 / C.6-2 / C.6-3 / C.6-5; the 7 attribute names and tags in the help match PS3.6 Table 6-1; matching that is not DICOM's is documented as tool-specific
import Foundation

/// The DICOM matching of PS3.4 C.2.2.2 that `dicom-archive` does not perform, said out loud.
///
/// The shared ArchiveStore matches `--study-date` and `--study-uid` (and `export
/// --study-uid / --series-uid / --patient-id`) by exact string equality. A DICOM user
/// may pass a Study Date range ("20240101-20240131", C.2.2.2.5) or a UID list
/// ("1.2.3\4.5.6", C.2.2.2.2); those would silently match nothing, so the CLI warns.
enum ArchiveQueryKeys {

    /// A warning when `value` is not a single DA value (PS3.5 Table 6.2-1: YYYYMMDD).
    static func studyDateWarning(_ value: String?) -> String? {
        guard let value else { return nil }
        let isDA = value.count == 8 && value.allSatisfy { $0.isASCII && $0.isNumber }
        if isDA { return nil }
        if value.contains("-") {
            return "warning: --study-date '\(value)' is a range; Range Matching (PS3.4 C.2.2.2.5) "
                + "is not supported, so it matches only a Study Date (0008,0020) equal to the whole string"
        }
        return "warning: --study-date '\(value)' is not a DA value (YYYYMMDD); "
            + "it matches only a Study Date (0008,0020) equal to the whole string"
    }

    /// A warning when a UID option holds a backslash-separated UID list.
    static func uidListWarning(option: String, attribute: String, _ value: String?) -> String? {
        guard let value, value.contains("\\") else { return nil }
        return "warning: \(option) '\(value)' is a UID list; List of UID Matching (PS3.4 C.2.2.2.2) "
            + "is not supported, so it matches only a \(attribute) equal to the whole string"
    }

    static func printWarnings(_ warnings: [String?]) {
        for case let warning? in warnings {
            FileHandle.standardError.write(Data((warning + "\n").utf8))
        }
    }
}
