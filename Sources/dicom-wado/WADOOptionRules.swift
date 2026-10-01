import Foundation
import ArgumentParser
import DICOMWeb

// NEMA-verified: 2026a, checked 2026-10-01 — WADO-URI rules read against PS3.18 2026a 9.1.2.2.1, 9.4.1.2.1, 9.4.1.2.3, 9.5.1.2.1, 9.5.1.2.4 and Tables 9.4.1-1 / 9.5.1-1 / 8.7.4-1 (7 contentType values); limit/offset against 8.3.4.4; UPS states against PS3.3 2026a Table C.30.1-1 (4 Enumerated Values) and PS3.18 11.7.1.4 (3 Change State targets)

/// Standard-derived rules for the values `dicom-wado` options accept. Kept apart from the
/// command structs so the tests can pin each rule to its clause.
enum WADOOptionRules {

    // MARK: - WADO-URI (PS3.18 Section 9)

    /// The `--content-type` values the URI service accepts and `WADOURIClient` carries:
    /// application/dicom (Retrieve DICOM Instance, 9.4) or a Rendered Media Type of
    /// Table 8.7.4-1 (Retrieve Rendered Instance, 9.5), per 9.1.2.2.1.
    static let uriContentTypes = [
        "application/dicom", "image/jpeg", "image/gif", "image/png", "image/jp2", "image/jph", "video/mpeg",
    ]

    /// Maps `--content-type` to the request representation. An absent value is the
    /// WADO-URI default, application/dicom. A value the client cannot request is
    /// rejected rather than silently fetched as application/dicom.
    static func uriContentType(_ raw: String?) throws -> WADOURIClient.ContentType {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return .dicom }
        let mapped = WADOURIClient.ContentType.fromRequestString(raw)
        if mapped == .dicom && !["application/dicom", "dicom"].contains(raw.lowercased()) {
            throw ValidationError(
                "--content-type '\(raw)' cannot be requested over WADO-URI. Use one of: "
                + uriContentTypes.joined(separator: ", ")
                + " (PS3.18 9.1.2.2.1: application/dicom or a Rendered Media Type of Table 8.7.4-1)")
        }
        return mapped
    }

    /// `frameNumber` (PS3.18 9.5.1.2.1) names a single Frame and is a positive integer.
    /// Returns the frame to send and how many further list entries were not sent.
    static func uriFrameNumber(_ raw: String?) throws -> (frame: Int, notSent: Int)? {
        guard let raw = raw else { return nil }
        let items = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = items.first, let frame = Int(first), frame >= 1 else {
            throw ValidationError(
                "--frames with --uri takes a positive frame number (PS3.18 9.5.1.2.1: frameNumber "
                + "is a single positive integer, starting at 1); got '\(raw)'")
        }
        return (frame, items.count - 1)
    }

    /// Warnings for parameters sent with a representation whose transaction does not
    /// define them: Table 9.4.1-1 (application/dicom) has anonymize, annotation and
    /// transferSyntax; Table 9.5.1-1 (rendered) has frameNumber, rows, columns and others.
    static func uriParameterWarnings(contentType: WADOURIClient.ContentType, frame: Int?,
                                     rows: Int?, columns: Int?,
                                     transferSyntax: String?, anonymize: Bool) -> [String] {
        var out: [String] = []
        if contentType == .dicom {
            var rendered: [String] = []
            if frame != nil { rendered.append("frameNumber (--frames)") }
            if rows != nil { rendered.append("rows (--rows)") }
            if columns != nil { rendered.append("columns (--columns)") }
            if !rendered.isEmpty {
                out.append("\(rendered.joined(separator: ", ")) \(rendered.count == 1 ? "is a" : "are") "
                    + "Retrieve Rendered Instance parameter\(rendered.count == 1 ? "" : "s") (PS3.18 Table 9.5.1-1), "
                    + "not defined for application/dicom (Table 9.4.1-1); the server may ignore "
                    + "\(rendered.count == 1 ? "it" : "them")")
            }
        } else {
            var dicomOnly: [String] = []
            if transferSyntax != nil { dicomOnly.append("transferSyntax (--transfer-syntax)") }
            if anonymize { dicomOnly.append("anonymize (--anonymize)") }
            if !dicomOnly.isEmpty {
                out.append("\(dicomOnly.joined(separator: ", ")) \(dicomOnly.count == 1 ? "is a" : "are") "
                    + "Retrieve DICOM Instance parameter\(dicomOnly.count == 1 ? "" : "s") (PS3.18 Table 9.4.1-1), "
                    + "not defined for \(contentType.rawValue) (Table 9.5.1-1); the server may ignore "
                    + "\(dicomOnly.count == 1 ? "it" : "them")")
            }
        }
        return out
    }

    // MARK: - QIDO-RS (PS3.18 8.3.4.4)

    /// `limit` and `offset` are uint (PS3.18 Table 8.3.4-1, 8.3.4.4).
    static func validatePaging(limit: Int, offset: Int) throws {
        if limit < 0 {
            throw ValidationError("--limit must be 0 or more (PS3.18 8.3.4.4: limit is an unsigned integer)")
        }
        if offset < 0 {
            throw ValidationError("--offset must be 0 or more (PS3.18 8.3.4.4: offset is an unsigned integer)")
        }
    }

    // MARK: - UPS-RS

    /// Procedure Step State (0074,1000), PS3.3 Table C.30.1-1 Enumerated Values. The
    /// standard spelling "IN PROGRESS" and the CLI spellings IN_PROGRESS / INPROGRESS
    /// are accepted (case-insensitive).
    static func upsState(_ raw: String) -> UPSState? {
        switch raw.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "_", with: " ") {
        case "SCHEDULED":                  return .scheduled
        case "IN PROGRESS", "INPROGRESS":  return .inProgress
        case "COMPLETED":                  return .completed
        case "CANCELED":                   return .canceled
        default:                           return nil
        }
    }

    /// The Procedure Step State values a Change State request may carry
    /// (PS3.18 11.7.1.4: "IN PROGRESS", "COMPLETED", or "CANCELED").
    static let changeStateTargets: [UPSState] = [.inProgress, .completed, .canceled]

    /// `--filter-state` in the spelling `UPSQuery.workitemSearch` accepts (it does not
    /// take the standard "IN PROGRESS"); other values pass through unchanged so the
    /// shared builder still rejects them.
    static func searchFilterState(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        return upsState(raw) == .inProgress ? "IN_PROGRESS" : raw
    }

    // MARK: - Plumbing

    /// `--timeout` drives the per-request timeout (URLSession timeoutIntervalForRequest,
    /// i.e. `readTimeout`); the whole-resource timeout is never shorter than it.
    static func timeouts(seconds: Int) -> DICOMwebConfiguration.TimeoutConfiguration {
        let t = TimeInterval(max(1, seconds))
        let defaults = DICOMwebConfiguration.TimeoutConfiguration.default
        return DICOMwebConfiguration.TimeoutConfiguration(
            connectTimeout: t,
            readTimeout: t,
            resourceTimeout: max(defaults.resourceTimeout, t),
            operationTimeout: max(defaults.operationTimeout, t))
    }
}
