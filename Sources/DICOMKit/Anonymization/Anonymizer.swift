import Foundation
import DICOMCore
import DICOMDictionary

/// Result of anonymizing one file.
public struct AnonymizationResult: Sendable {
    public let filePath: String
    public let success: Bool
    public let changedTags: [Tag]
    public let warnings: [String]

    public init(filePath: String, success: Bool, changedTags: [Tag], warnings: [String]) {
        self.filePath = filePath
        self.success = success
        self.changedTags = changedTags
        self.warnings = warnings
    }
}

/// Audit log entry. Carries no attribute values: an audit log that stored the
/// original identifiers would itself be a PHI store.
public struct AuditLogEntry {
    public let timestamp: Date
    public let filePath: String
    public let action: String
    public let tag: Tag
    public let note: String?

    public init(timestamp: Date, filePath: String, action: String, tag: Tag, note: String? = nil) {
        self.timestamp = timestamp
        self.filePath = filePath
        self.action = action
        self.tag = tag
        self.note = note
    }
}

/// One `dicom-anon` run's de-identification state: the PS3.15 Annex E options, the
/// UID map shared by every file of the run (so a study's instances keep referencing
/// each other after their UIDs are regenerated) and the audit log.
///
/// The profile applied is always the Basic Application Level Confidentiality
/// Profile (``ConfidentialityEngine``); ``ConfidentialityProfile/Options`` are the
/// only knobs.
public final class Anonymizer {
    public let options: ConfidentialityProfile.Options

    private var uidMap: [String: String] = [:]
    private var auditLog: [AuditLogEntry] = []

    public init(options: ConfidentialityProfile.Options = .basic) {
        self.options = options
    }

    /// De-identifies one file's data set, extending the run-wide UID map and audit log.
    ///
    /// Pixels are out of scope here (the pixel pass runs first), so a declared
    /// burned-in annotation or overlay plane surfaces as a warning and (0012,0062) NO
    /// rather than being silently certified as removed.
    public func deidentify(file: DICOMFile, filePath: String) -> (DICOMFile, AnonymizationResult) {
        var engine = ConfidentialityEngine(options: options, uidMap: uidMap)
        let (scrubbed, changed, warnings) = engine.deidentifyReportingResidualPHI(file.dataSet)
        uidMap = engine.uidMap
        for change in engine.changes {
            auditLog.append(AuditLogEntry(
                timestamp: Date(), filePath: filePath,
                action: Self.actionName(change.action), tag: change.tag))
        }
        let newFile = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: scrubbed)
        return (newFile, AnonymizationResult(
            filePath: filePath, success: true, changedTags: changed, warnings: warnings))
    }

    /// The header pass on a copy — nothing recorded, the run's UID map untouched.
    /// Used to learn the engine's own replacement values for `--redact-style replace`.
    public func preview(file: DICOMFile) -> DICOMFile {
        var engine = ConfidentialityEngine(options: options, uidMap: uidMap)
        let (scrubbed, _) = engine.deidentify(file.dataSet)
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: scrubbed)
    }

    /// Table E.1-1 action code names as they appear in the audit log.
    static func actionName(_ action: ConfidentialityProfile.Action) -> String {
        switch action {
        case .remove, .removePreferred: return "X remove"
        case .zero:                     return "Z zero"
        case .zeroOrDummy:              return "Z/D zero-or-shift"
        case .replaceDummy:             return "D dummy"
        case .clean:                    return "C clean"
        case .replaceUID:               return "U replace-uid"
        case .keep:                     return "K keep"
        }
    }

    public func getAuditLog() -> [AuditLogEntry] {
        auditLog
    }

    /// Records pixel-work audit lines (PHI-safe — callers pass
    /// `PixelCleaningWorkflow.Report.auditLines`, never raw OCR strings).
    public func recordPixelAudit(filePath: String, lines: [String]) {
        for line in lines {
            auditLog.append(AuditLogEntry(
                timestamp: Date(), filePath: filePath, action: "pixel-data",
                tag: .pixelData, note: line))
        }
    }

    public func writeAuditLog(to url: URL) throws {
        let dateFormatter = ISO8601DateFormatter()
        var logText = "DICOM De-identification Audit Log (PS3.15 Annex E)\n"
        logText += "Generated: \(dateFormatter.string(from: Date()))\n\n"

        // Sort by file then tag so the audit log is deterministic.
        let sorted = auditLog.sorted {
            ($0.filePath, $0.tag.group, $0.tag.element) < ($1.filePath, $1.tag.group, $1.tag.element)
        }
        for entry in sorted {
            logText += "[\(dateFormatter.string(from: entry.timestamp))] "
            logText += "\(entry.filePath) - \(entry.action) - \(entry.tag)\n"
            if let note = entry.note {
                logText += "  \(note)\n"
            }
        }

        try logText.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Shared console output (dicom-anon CLI ⇄ Workshop Security executor)

/// Builds every console line `dicom-anon` prints. The CLI text is canonical and the
/// Workshop executor renders the identical strings, so the two surfaces cannot drift.
public enum AnonConsole {
    /// Per-file verbose line in directory mode (success).
    public static func fileSuccessLine(relativePath: String) -> String {
        "✓ \(relativePath)"
    }

    /// Per-file verbose line in directory mode (failure).
    public static func fileFailureLine(relativePath: String, message: String) -> String {
        "✗ \(relativePath): \(message)"
    }

    /// Verbose confirmation after the audit log is written.
    public static func auditLogLine(path: String) -> String {
        "Audit log written to: \(path)"
    }

    /// The operator's Burned In Annotation policy took the file past the pixel pass:
    /// the declaration was trusted, nothing was inspected. Console (verbose) and audit.
    public static let burnedInAnnotationTrustedNote =
        "Pixel data: Burned In Annotation (0028,0301) = NO — trusted; pixels were not inspected or modified."

    /// Verbose report of a pixel-redaction pass. States the basis for the region
    /// choice, not just the rectangle — an operator has to be able to judge whether
    /// the region was the right one, since no test can verify that for them.
    public static func pixelRedactionLines(outcome: PixelRedactor.Outcome) -> String {
        var out = "Cleaned pixel data (\(outcome.basis.rawValue)): \(outcome.note)\n"
        let fallback = Set(outcome.labelFallbackRegions)
        for r in outcome.regions {
            let verb: String
            switch outcome.style {
            case .blank: verb = "blanked"
            case .label(let text):
                verb = fallback.contains(r)
                    ? "blanked (too small for label \"\(text)\" — blank only)"
                    : "blanked + labelled \"\(text)\""
            case .replace(let fallbackLabel):
                if let value = outcome.replacements[r] {
                    verb = "blanked + replaced with header value \"\(value)\""
                } else if fallback.contains(r) {
                    verb = "blanked (\(outcome.replacementFallbackNotes[r] ?? "too small") — blank only)"
                } else {
                    verb = "blanked + labelled \"\(fallbackLabel)\" (\(outcome.replacementFallbackNotes[r] ?? "no replacement"))"
                }
            }
            out += "  \(verb) (\(r.x),\(r.y)) \(r.width)x\(r.height)"
            out += outcome.frameCount > 1 ? " on all \(outcome.frameCount) frames\n" : "\n"
        }
        if outcome.removedIconImage {
            out += "  removed Icon Image Sequence (derived before cleaning)\n"
        }
        if outcome.removedOverlays {
            out += "  removed overlay plane data (burned in by renderers)\n"
        }
        out += "  recorded DCM 113101 Clean Pixel Data Option; Burned In Annotation = NO\n"
        out += "  ⚠️  Verify visually before release — region selection is not verifiable by test.\n"
        return out
    }

    /// `--recompress` console lines: what was re-encoded to, and every caveat.
    public static func recompressionLines(_ r: PixelCleaningWorkflow.Recompression) -> String {
        var out: String
        if r.transferSyntaxUID == r.sourceTransferSyntaxUID {
            out = "Re-encoded to source syntax \(r.transferSyntaxUID) (\(r.codec), \(r.lossy ? "lossy" : "lossless"))\n"
        } else {
            out = "Re-encoded to \(r.transferSyntaxUID) (\(r.codec), \(r.lossy ? "lossy" : "lossless")); source was \(r.sourceTransferSyntaxUID)\n"
        }
        for n in r.notes { out += "  ⚠️  \(n)\n" }
        out += "  verified: redacted regions still blank after the codec round-trip\n"
        return out
    }

    /// One-line OCR summary. Reports what was done — never that the image is clean.
    public static func textDetectionLine(report: PixelCleaningWorkflow.Report) -> String {
        let n = report.detections.count
        let selected: Int
        if let plan = report.plan, case .redact(let regions, _) = plan.decision {
            selected = report.detections.filter { regions.contains($0.region) }.count
        } else {
            selected = 0
        }
        let kept = report.verdicts.filter { !$0.isRedact }.count
        let frames = report.scannedFrames.count
        var line = "OCR: \(n) candidate region\(n == 1 ? "" : "s"); \(selected) selected for redaction"
        if kept > 0 {
            let why = report.mode == .header ? "no header match" : "allowlisted clinical text"
            line += "; \(kept) kept (\(why)"
            // A keep verdict never shrinks another source's region: say how many of the
            // kept regions are blanked anyway, so "kept" is never read as "survives".
            let buried = kept - report.keptAndSurviving.count
            if buried > 0 { line += "; \(buried) of them inside blanked regions anyway" }
            line += ")"
        }
        line += " across \(frames) sampled frame\(frames == 1 ? "" : "s").\n"
        return line
    }

    /// The `--dry-run` region table (§7). Recognized text is shown on the console
    /// (`showText`) but must be passed as `false` for anything persisted.
    public static func pixelPlanTable(report: PixelCleaningWorkflow.Report, showText: Bool) -> String {
        var out = "Pixel redaction plan:\n"
        let indexed = Array(zip(report.detections, report.verdicts))
        let byFrame = Dictionary(grouping: indexed, by: { $0.0.frameIndex })
        let redacted: Set<PixelRedactionPlan.Region>
        if let plan = report.plan, case .redact(let regions, _) = plan.decision {
            redacted = Set(regions)
        } else {
            redacted = []
        }
        for frame in byFrame.keys.sorted() {
            out += "Frame \(frame):\n"
            for (d, v) in byFrame[frame]! {
                let verdict: String
                if v.isRedact {
                    verdict = redacted.contains(d.region) ? "redact" : "detected"
                } else {
                    verdict = "keep"
                }
                let reason = (v.isRedact && !redacted.contains(d.region))
                    ? "\(v.reason) — cleaning not requested" : v.reason
                let text = showText ? d.text : d.redactedForAudit
                out += "  OCR  rect=\(d.region.x),\(d.region.y),\(d.region.width),\(d.region.height)"
                    + "  verdict=\(verdict)  reason=\(reason)  conf=\(String(format: "%.2f", d.confidence))"
                    + "  text=\"\(text)\"\n"
            }
        }
        out += "Final:\n"
        guard let plan = report.plan else {
            out += "  detection only — no cleaning requested\n"
            out += "  Pixel modification: NO\n"
            return out
        }
        switch plan.decision {
        case .redact(let regions, _):
            let parts = plan.sources.map { source -> String in
                let n = source.regions.count
                let label: String
                switch source.basis {
                case .explicit: label = "explicit"
                case .keepRegionInversion: label = "keep-region"
                case .deviceTemplate: label = "template"
                case .textDetection: label = "OCR"
                }
                return "\(n) \(label) region\(n == 1 ? "" : "s")"
            }
            out += "  \(parts.joined(separator: " + ")) = \(regions.count) unioned region\(regions.count == 1 ? "" : "s")\n"
            for r in regions {
                out += "    (\(r.x),\(r.y)) \(r.width)x\(r.height)\n"
            }
            out += "  Frames affected: all (\(report.frameCount))\n"
            out += "  Pixel modification: YES\n"
        case .nothingToDo:
            out += "  nothing declared, nothing detected — no pixel work\n"
            out += "  Pixel modification: NO\n"
        case .unresolved(let reason):
            out += "  UNRESOLVED: \(reason)\n"
            out += "  Pixel modification: REFUSED\n"
        }
        return out
    }

    /// The end-of-run summary block (leading blank line, every line newline-terminated).
    /// The "Modified tags" section appears whenever verbose ran over at least one file,
    /// even with zero modified tags — matching the CLI.
    public static func summary(
        totalFiles: Int,
        successful: Int,
        failed: Int,
        dryRun: Bool,
        warnings: [String],
        modifiedTags: Set<String>,
        verbose: Bool
    ) -> String {
        var out = "\nAnonymization Summary:\n"
        out += "  Total files: \(totalFiles)\n"
        out += "  Successful: \(successful)\n"
        out += "  Failed: \(failed)\n"
        if dryRun { out += "  (DRY RUN - no files modified)\n" }
        if !warnings.isEmpty {
            out += "\nWarnings:\n"
            for warning in warnings.prefix(10) { out += "  ⚠️  \(warning)\n" }
            if warnings.count > 10 { out += "  ... and \(warnings.count - 10) more warnings\n" }
        }
        if verbose && totalFiles > 0 {
            out += "\nModified tags (\(modifiedTags.count)):\n"
            for tag in modifiedTags.sorted().prefix(20) { out += "  - \(tag)\n" }
        }
        return out
    }
}
