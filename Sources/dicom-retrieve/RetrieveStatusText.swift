import Foundation
import DICOMNetwork
// NEMA-verified: 2026a, checked 2026-10-01 — the 9 C-MOVE rows of PS3.4 2026a Table C.4-2 and the 8 C-GET rows of Table C.4-3 (Service Status, Further Meaning, Status Code) generated from the DocBook by Scripts/nema_docbook.py, 17 of 17 carried verbatim; the sub-operation counter names are those of PS3.7 2026a Tables 9.3-7 / 9.3-10. Byte-identical copy in Sources/dicom-qr and Sources/dicom-retrieve (pinned by DICOMRetrieveTests).

/// The final-response status wording of the Query/Retrieve Service Class, as
/// PS3.4 2026a spells it: Table C.4-2 for C-MOVE, Table C.4-3 for C-GET.
///
/// `DIMSEStatus.description` (DICOMNetwork) is service-agnostic — it names
/// 0xB000 "Coercion of data elements" (the C-STORE meaning) and 0xA701/0xA702
/// "Failed: Out of resources" — so the CLI looks the code up in the table of
/// the service that produced it. Codes the table does not list fall back to
/// the DICOMNetwork wording.
enum RetrieveStatusText {
    enum Service: String {
        case cMove = "C-MOVE"
        case cGet = "C-GET"
    }

    struct Row: Equatable {
        /// Four hex digits as printed in the table; "Cxxx" is the 0xC000-0xCFFF range.
        let code: String
        /// The "Service Status" column: Failure / Cancel / Warning / Success / Pending.
        let serviceStatus: String
        /// The "Further Meaning" column, verbatim.
        let furtherMeaning: String
    }

    /// PS3.4 2026a Table C.4-2 — C-MOVE Response Status Values
    static let cMoveRows: [Row] = [
        Row(code: "A701", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to calculate number of matches"),
        Row(code: "A702", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to perform sub-operations"),
        Row(code: "A801", serviceStatus: "Failure", furtherMeaning: "Refused: Move Destination unknown"),
        Row(code: "A900", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        Row(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Failed: Unable to process"),
        Row(code: "FE00", serviceStatus: "Cancel", furtherMeaning: "Sub-operations terminated due to Cancel Indication"),
        Row(code: "B000", serviceStatus: "Warning", furtherMeaning: "Sub-operations Complete - One or more Failures"),
        Row(code: "0000", serviceStatus: "Success", furtherMeaning: "Sub-operations Complete - No Failures"),
        Row(code: "FF00", serviceStatus: "Pending", furtherMeaning: "Sub-operations are continuing"),
    ]

    /// PS3.4 2026a Table C.4-3 — C-GET Response Status Values
    static let cGetRows: [Row] = [
        Row(code: "A701", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to calculate number of matches"),
        Row(code: "A702", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to perform sub-operations"),
        Row(code: "A900", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        Row(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Failed: Unable to process"),
        Row(code: "FE00", serviceStatus: "Cancel", furtherMeaning: "Sub-operations terminated due to Cancel Indication"),
        Row(code: "B000", serviceStatus: "Warning", furtherMeaning: "Sub-operations Complete - One or more Failures or Warnings"),
        Row(code: "0000", serviceStatus: "Success", furtherMeaning: "Sub-operations Complete - No Failures or Warnings"),
        Row(code: "FF00", serviceStatus: "Pending", furtherMeaning: "Sub-operations are continuing"),
    ]

    static func rows(for service: Service) -> [Row] {
        service == .cMove ? cMoveRows : cGetRows
    }

    /// The table row for a status code, or nil when the table has no row for it.
    static func row(for code: UInt16, service: Service) -> Row? {
        let hex = String(format: "%04X", code)
        let table = rows(for: service)
        if let exact = table.first(where: { $0.code == hex }) { return exact }
        if code & 0xF000 == 0xC000 { return table.first(where: { $0.code == "Cxxx" }) }
        return nil
    }

    /// "Success (0x0000): Sub-operations Complete - No Failures" — the PS3.4
    /// Service Status, the code, and the Further Meaning. A code outside the
    /// table is rendered with the DICOMNetwork wording.
    static func describe(_ status: DIMSEStatus, service: Service) -> String {
        let hex = String(format: "%04X", status.rawValue)
        guard let row = row(for: status.rawValue, service: service) else {
            return "\(status) (not listed in PS3.4 Table \(service == .cMove ? "C.4-2" : "C.4-3"))"
        }
        return "\(row.serviceStatus) (0x\(hex)): \(row.furtherMeaning)"
    }

    /// The final-response counters under their PS3.7 names (Tables 9.3-7 and
    /// 9.3-10): Number of Completed / Failed / Warning Sub-operations.
    static func subOperationCounts(_ progress: RetrieveProgress) -> String {
        "Number of Completed Sub-operations: \(progress.completed), "
            + "Number of Failed Sub-operations: \(progress.failed), "
            + "Number of Warning Sub-operations: \(progress.warning)"
    }
}
