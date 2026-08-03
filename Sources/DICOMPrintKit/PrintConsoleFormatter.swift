// PrintConsoleFormatter.swift
// DICOMPrintKit
//
// Every line the print surfaces render — printer status, send result, job
// status, film plan — is built here, so the DICOMStudio console and the
// dicom-print terminal output stay identical. Mirrors the role
// NetworkConsoleFormatter plays for query/send/retrieve.
//
// The functions return strings; routing (stdout vs stderr, view vs terminal)
// is the caller's job.

import Foundation
import DICOMNetwork

public enum PrintConsoleFormatter {

    // MARK: - Printer status

    /// Human-readable printer status block.
    public static func printerStatusText(_ status: PrinterStatus) -> [String] {
        var lines: [String] = []
        lines.append("Printer Status")
        lines.append("==============")
        lines.append("Name: \(status.printerName ?? "Unknown")")
        lines.append("Status: \(status.status)")
        if let info = status.statusInfo {
            lines.append("Status Info: \(info)")
        }
        if let manufacturer = status.manufacturer {
            lines.append("Manufacturer: \(manufacturer)")
        }
        if let model = status.manufacturerModelName {
            lines.append("Model: \(model)")
        }
        lines.append("Is Normal: \(status.isNormal ? "Yes" : "No")")
        return lines
    }

    /// Machine-readable printer status.
    public static func printerStatusJSON(_ status: PrinterStatus) -> String? {
        var dict: [String: Any] = [
            "status": status.status,
            "isNormal": status.isNormal
        ]
        if let name = status.printerName { dict["name"] = name }
        if let info = status.statusInfo { dict["statusInfo"] = info }
        if let manufacturer = status.manufacturer { dict["manufacturer"] = manufacturer }
        if let model = status.manufacturerModelName { dict["model"] = model }
        return json(from: dict)
    }

    // MARK: - Print result

    /// Human-readable outcome of a print job.
    public static func printResultText(_ result: PrintResult) -> [String] {
        var lines: [String] = []
        if result.success {
            lines.append("✓ Print job submitted successfully")
            if let jobUID = result.printJobUID {
                lines.append("  Print Job UID: \(jobUID)")
            }
            if let sessionUID = result.filmSessionUID {
                lines.append("  Film Session UID: \(sessionUID)")
            }
        } else {
            lines.append("✗ Print failed")
            if let error = result.errorMessage {
                lines.append("  Error: \(error)")
            }
        }
        return lines
    }

    /// Machine-readable outcome. Multi-film jobs also list every film box and
    /// print job UID; the singular keys stay for existing consumers.
    public static func printResultJSON(_ result: PrintResult) -> String? {
        var dict: [String: Any] = [
            "success": result.success
        ]
        if let jobUID = result.printJobUID { dict["printJobUID"] = jobUID }
        if let sessionUID = result.filmSessionUID { dict["filmSessionUID"] = sessionUID }
        if let filmBoxUID = result.filmBoxUID { dict["filmBoxUID"] = filmBoxUID }
        if result.filmBoxUIDs.count > 1 { dict["filmBoxUIDs"] = result.filmBoxUIDs }
        if result.printJobUIDs.count > 1 { dict["printJobUIDs"] = result.printJobUIDs }
        if let error = result.errorMessage { dict["error"] = error }
        return json(from: dict)
    }

    // MARK: - Print job status

    /// Human-readable print job status block.
    public static func jobStatusText(_ status: PrintJobStatus) -> [String] {
        var lines: [String] = []
        lines.append("Print Job Status")
        lines.append("================")
        lines.append("Job UID: \(status.printJobUID)")
        lines.append("Status: \(status.executionStatus)")
        if let info = status.executionStatusInfo {
            lines.append("Status Info: \(info)")
        }
        if let creationDate = status.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            lines.append("Created: \(formatter.string(from: creationDate))")
        }
        return lines
    }

    /// Machine-readable print job status.
    public static func jobStatusJSON(_ status: PrintJobStatus) -> String? {
        var dict: [String: Any] = [
            "jobUID": status.printJobUID,
            "status": status.executionStatus
        ]
        if let info = status.executionStatusInfo { dict["statusInfo"] = info }
        if let creationDate = status.creationDate {
            dict["creationDate"] = ISO8601DateFormatter().string(from: creationDate)
        }
        return json(from: dict)
    }

    // MARK: - Film plan

    /// One-line film plan summary: "12 image(s) → 3 film(s) (2×2, 14INX17IN, PORTRAIT)".
    public static func planSummary(_ plan: PrintPlan) -> String {
        let grid = "\(plan.layout.rows)×\(plan.layout.columns)"
        var line = "\(plan.imageCount) image(s) → \(plan.filmCount) film(s) "
            + "(\(grid), \(plan.filmSize.rawValue), \(plan.filmOrientation.rawValue))"
        if plan.copies > 1 {
            line += " × \(plan.copies) copies = \(plan.totalSheets) sheets"
        }
        return line
    }

    /// Per-film breakdown, e.g. "Film 3 of 3: images 9-12 (4 of 4 cells)".
    public static func planDetail(_ plan: PrintPlan) -> [String] {
        (0..<plan.filmCount).map { filmIndex in
            let range = plan.imageIndices(onFilm: filmIndex)
            let used = range.count
            return "Film \(filmIndex + 1) of \(plan.filmCount): "
                + "images \(range.lowerBound + 1)-\(range.upperBound) "
                + "(\(used) of \(plan.cellsPerFilm) cells)"
        }
    }

    // MARK: - Helpers

    private static func json(from dict: Any) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}
