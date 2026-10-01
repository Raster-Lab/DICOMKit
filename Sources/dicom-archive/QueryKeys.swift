// NEMA-verified: 2026a, checked 2026-10-01 — the --study-date key against PS3.4 2026a C.2.2.2.1 / C.2.2.2.5.1 (single DA value or DA range) and PS3.5 2026a Table 6.2-1 (DA: 8 bytes, "0"-"9"); range and UID-list matching are performed by DICOMKit ArchiveMatching, so only a value that is neither form is warned
import Foundation
import DICOMKit

/// Warnings for `dicom-archive` query keys the shared ArchiveStore cannot match as DICOM.
///
/// ArchiveStore performs Single Value and Range Matching of Study Date (PS3.4 C.2.2.2.1,
/// C.2.2.2.5.1) and List of UID Matching (C.2.2.2.2). A Study Date that is neither a DA value
/// (YYYYMMDD) nor a DA range is compared as a literal string, so the CLI warns about it.
enum ArchiveQueryKeys {

    /// A warning when `value` is neither a DA value (PS3.5 Table 6.2-1: YYYYMMDD) nor a DA range
    /// (PS3.4 C.2.2.2.5.1: "<date1>-<date2>", "-<date1>", "<date1>-").
    static func studyDateWarning(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if ArchiveMatching.dateRange(value) != nil { return nil }
        return "warning: --study-date '\(value)' is neither a DA value (YYYYMMDD) nor a DA range "
            + "(PS3.4 C.2.2.2.5.1); it matches only a Study Date (0008,0020) equal to the whole string"
    }

    static func printWarnings(_ warnings: [String?]) {
        for case let warning? in warnings {
            FileHandle.standardError.write(Data((warning + "\n").utf8))
        }
    }
}
