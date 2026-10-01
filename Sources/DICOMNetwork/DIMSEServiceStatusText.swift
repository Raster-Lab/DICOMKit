import Foundation
// NEMA-verified: 2026a, checked 2026-10-01 — the 31 rows of PS3.4 2026a Tables B.2-1 (C-STORE, 7), C.4-1 (C-FIND, 7), C.4-2 (C-MOVE, 9) and C.4-3 (C-GET, 8) (Service Status, Further Meaning, Status Code) generated from the DocBook by Scripts/nema_docbook.py and carried verbatim; the sub-operation counter names are those of PS3.7 2026a Tables 9.3-7 / 9.3-10. Hoisted from the dicom-retrieve / dicom-qr RetrieveStatusText copies (P-QR-STATUS-TEXT, D76).

/// The DIMSE-C service whose response status is being described. The same
/// status code means different things per service (PS3.4 Annex B / C): 0xB000
/// is "Coercion of Data Elements" for C-STORE but "Sub-operations Complete -
/// One or more Failures" for C-MOVE.
public enum DIMSEStatusService: String, Sendable, Hashable, CaseIterable {
    /// Storage Service Class C-STORE — PS3.4 Table B.2-1
    case cStore = "C-STORE"
    /// Query/Retrieve C-FIND — PS3.4 Table C.4-1
    case cFind = "C-FIND"
    /// Query/Retrieve C-MOVE — PS3.4 Table C.4-2
    case cMove = "C-MOVE"
    /// Query/Retrieve C-GET — PS3.4 Table C.4-3
    case cGet = "C-GET"

    /// The PS3.4 table that lists this service's response status values.
    public var statusTable: String {
        switch self {
        case .cStore: return "B.2-1"
        case .cFind:  return "C.4-1"
        case .cMove:  return "C.4-2"
        case .cGet:   return "C.4-3"
        }
    }
}

/// One row of a PS3.4 response status table.
public struct DIMSEServiceStatusRow: Sendable, Hashable {
    /// Four hex digits as printed in the table; `x` is a wildcard hex digit
    /// ("Cxxx" is the 0xC000-0xCFFF range, "A7xx" the 0xA700-0xA7FF range).
    public let code: String
    /// The "Service Status" column: Failure / Cancel / Warning / Success / Pending.
    public let serviceStatus: String
    /// The "Further Meaning" column, verbatim.
    public let furtherMeaning: String

    public init(code: String, serviceStatus: String, furtherMeaning: String) {
        self.code = code
        self.serviceStatus = serviceStatus
        self.furtherMeaning = furtherMeaning
    }

    /// Whether a 16-bit status code matches this row's code pattern.
    public func matches(_ value: UInt16) -> Bool {
        let hex = String(format: "%04X", value)
        guard hex.count == code.count else { return false }
        for (c, p) in zip(hex, code) where p != "x" && p != c { return false }
        return true
    }
}

/// Service-specific response status wording, as PS3.4 2026a spells it.
///
/// ``DIMSEStatus/description`` is service-agnostic; this type looks the code
/// up in the table of the service that produced it so the CLI tools and the
/// DICOMStudio console print the same, standard text. Codes a table does not
/// list fall back to the ``DIMSEStatus`` wording.
public enum DIMSEServiceStatusText {

    /// PS3.4 2026a Table B.2-1
    static let cStoreRows: [DIMSEServiceStatusRow] = [
        DIMSEServiceStatusRow(code: "A7xx", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources"),
        DIMSEServiceStatusRow(code: "A9xx", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        DIMSEServiceStatusRow(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Error: Cannot understand"),
        DIMSEServiceStatusRow(code: "B000", serviceStatus: "Warning", furtherMeaning: "Coercion of Data Elements"),
        DIMSEServiceStatusRow(code: "B007", serviceStatus: "Warning", furtherMeaning: "Data Set does not match SOP Class"),
        DIMSEServiceStatusRow(code: "B006", serviceStatus: "Warning", furtherMeaning: "Elements Discarded"),
        DIMSEServiceStatusRow(code: "0000", serviceStatus: "Success", furtherMeaning: "Success"),
    ]

    /// PS3.4 2026a Table C.4-1
    static let cFindRows: [DIMSEServiceStatusRow] = [
        DIMSEServiceStatusRow(code: "A700", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources"),
        DIMSEServiceStatusRow(code: "A900", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        DIMSEServiceStatusRow(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Failed: Unable to process"),
        DIMSEServiceStatusRow(code: "FE00", serviceStatus: "Cancel", furtherMeaning: "Matching terminated due to Cancel request"),
        DIMSEServiceStatusRow(code: "0000", serviceStatus: "Success", furtherMeaning: "Matching is complete - No final Identifier is supplied."),
        DIMSEServiceStatusRow(code: "FF00", serviceStatus: "Pending", furtherMeaning: "Matches are continuing - Current Match is supplied and any Optional Keys were supported in the same manner as Required Keys."),
        DIMSEServiceStatusRow(code: "FF01", serviceStatus: "Pending", furtherMeaning: "Matches are continuing - Warning that one or more Optional Keys were not supported for existence and/or matching for this Identifier."),
    ]

    /// PS3.4 2026a Table C.4-2
    static let cMoveRows: [DIMSEServiceStatusRow] = [
        DIMSEServiceStatusRow(code: "A701", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to calculate number of matches"),
        DIMSEServiceStatusRow(code: "A702", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to perform sub-operations"),
        DIMSEServiceStatusRow(code: "A801", serviceStatus: "Failure", furtherMeaning: "Refused: Move Destination unknown"),
        DIMSEServiceStatusRow(code: "A900", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        DIMSEServiceStatusRow(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Failed: Unable to process"),
        DIMSEServiceStatusRow(code: "FE00", serviceStatus: "Cancel", furtherMeaning: "Sub-operations terminated due to Cancel Indication"),
        DIMSEServiceStatusRow(code: "B000", serviceStatus: "Warning", furtherMeaning: "Sub-operations Complete - One or more Failures"),
        DIMSEServiceStatusRow(code: "0000", serviceStatus: "Success", furtherMeaning: "Sub-operations Complete - No Failures"),
        DIMSEServiceStatusRow(code: "FF00", serviceStatus: "Pending", furtherMeaning: "Sub-operations are continuing"),
    ]

    /// PS3.4 2026a Table C.4-3
    static let cGetRows: [DIMSEServiceStatusRow] = [
        DIMSEServiceStatusRow(code: "A701", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to calculate number of matches"),
        DIMSEServiceStatusRow(code: "A702", serviceStatus: "Failure", furtherMeaning: "Refused: Out of resources - Unable to perform sub-operations"),
        DIMSEServiceStatusRow(code: "A900", serviceStatus: "Failure", furtherMeaning: "Error: Data Set does not match SOP Class"),
        DIMSEServiceStatusRow(code: "Cxxx", serviceStatus: "Failure", furtherMeaning: "Failed: Unable to process"),
        DIMSEServiceStatusRow(code: "FE00", serviceStatus: "Cancel", furtherMeaning: "Sub-operations terminated due to Cancel Indication"),
        DIMSEServiceStatusRow(code: "B000", serviceStatus: "Warning", furtherMeaning: "Sub-operations Complete - One or more Failures or Warnings"),
        DIMSEServiceStatusRow(code: "0000", serviceStatus: "Success", furtherMeaning: "Sub-operations Complete - No Failures or Warnings"),
        DIMSEServiceStatusRow(code: "FF00", serviceStatus: "Pending", furtherMeaning: "Sub-operations are continuing"),
    ]

    /// The rows of the PS3.4 table for `service`, in table order.
    public static func rows(for service: DIMSEStatusService) -> [DIMSEServiceStatusRow] {
        switch service {
        case .cStore: return cStoreRows
        case .cFind:  return cFindRows
        case .cMove:  return cMoveRows
        case .cGet:   return cGetRows
        }
    }

    /// The table row for a status code, or nil when the table has no row for it.
    /// An exact code wins over a wildcard range ("A900" before "A9xx").
    public static func row(for code: UInt16, service: DIMSEStatusService) -> DIMSEServiceStatusRow? {
        let table = rows(for: service)
        if let exact = table.first(where: { !$0.code.contains("x") && $0.matches(code) }) { return exact }
        return table.first(where: { $0.matches(code) })
    }

    /// "Success (0x0000): Sub-operations Complete - No Failures" — the PS3.4
    /// Service Status, the code, and the Further Meaning. A code outside the
    /// table is rendered with the ``DIMSEStatus`` wording and the table named.
    public static func describe(_ status: DIMSEStatus, service: DIMSEStatusService) -> String {
        let hex = String(format: "%04X", status.rawValue)
        guard let row = row(for: status.rawValue, service: service) else {
            return "\(status) (not listed in PS3.4 Table \(service.statusTable))"
        }
        return "\(row.serviceStatus) (0x\(hex)): \(row.furtherMeaning)"
    }

    /// The final-response counters of a C-MOVE / C-GET under their PS3.7 names
    /// (Tables 9.3-10 / 9.3-7): Number of Completed / Failed / Warning Sub-operations.
    public static func subOperationCounts(_ progress: RetrieveProgress) -> String {
        "Number of Completed Sub-operations: \(progress.completed), "
            + "Number of Failed Sub-operations: \(progress.failed), "
            + "Number of Warning Sub-operations: \(progress.warning)"
    }
}

extension DIMSEStatus {
    /// The status worded per the PS3.4 response status table of `service`
    /// (see ``DIMSEServiceStatusText/describe(_:service:)``).
    public func description(for service: DIMSEStatusService) -> String {
        DIMSEServiceStatusText.describe(self, service: service)
    }
}
