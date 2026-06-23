import Foundation
import DICOMCore

/// Shared console rendering for the network CLIs (`dicom-query`, `dicom-send`,
/// `dicom-retrieve`, `dicom-qr`) AND the DICOMStudio CLI Workshop in-process
/// equivalents.
///
/// The whole point of this type is parity: the Studio "Compare CLI" harness runs
/// the real binary and diffs its `stdout + stderr` against the app's in-process
/// console output. The results *table* was already shared (``DICOMQueryResultFormatter``),
/// but the surrounding chrome — headers, per-item progress, summaries — used to be
/// hand-rolled on each side and drifted (different wording, padding, streams, and
/// ordering). Routing every such line through one formatter makes drift impossible
/// by construction.
///
/// Conventions both sides MUST follow for the diff to be clean:
///  - Emit these strings in the SAME order (header → body → summary).
///  - The CLI prints them to STDOUT (stderr is reserved for pre-flight
///    `ValidationError`s), so the combined-stream order matches the app's
///    single-stream append order.
///  - Volatile timing (round-trip time, duration, throughput) is rendered here in a
///    fixed format and then masked by `CLIParityEngine.normalize`, since two
///    separate network operations never take the exact same wall-clock time. Byte
///    *counts* are deterministic (same files / same datasets) and are NOT masked.
public enum NetworkConsole {

    // MARK: - Shared value formatting

    /// Human byte count, e.g. `512 B`, `1.23 MB`. Deterministic — compared verbatim.
    public static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var i = 0
        while value >= 1024 && i < units.count - 1 { value /= 1024; i += 1 }
        return i == 0 ? "\(bytes) \(units[0])" : String(format: "%.2f %@", value, units[i])
    }

    /// Human duration, e.g. `950 ms`, `1.2 s`, `2m 5s`. Masked by the parity engine.
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return String(format: "%.0f ms", seconds * 1000) }
        if seconds < 60 { return String(format: "%.1f s", seconds) }
        if seconds < 3600 {
            return "\(Int(seconds / 60))m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s"
        }
        return "\(Int(seconds / 3600))h \(Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60))m"
    }

    /// Round-trip time as `123 ms`. Masked by the parity engine.
    public static func formatRTT(_ seconds: TimeInterval) -> String {
        String(format: "%.0f ms", seconds * 1000)
    }

    /// A `"  Label:        value"` field line with the value column aligned. Leading
    /// indentation is irrelevant (the parity engine trims line ends) but the internal
    /// padding must match on both sides, hence it lives here.
    private static func field(_ label: String, _ value: String) -> String {
        let padded = (label as NSString).length >= labelWidth
            ? label
            : label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        return "  \(padded)\(value)\n"
    }
    private static let labelWidth = 19

    private static func rule(_ title: String) -> String {
        title + "\n" + String(repeating: "=", count: title.count) + "\n"
    }

    /// A wider `"  Label:        value"` field line for the MWL/MPPS blocks, whose
    /// labels (e.g. `Requested Proc. Desc:`) overflow the 19-col header column the
    /// other tools use. As with ``field(_:_:)``, leading indentation is trimmed by the
    /// parity engine but the internal padding must match on both sides, so it lives here.
    private static func mwlField(_ label: String, _ value: String) -> String {
        let width = 23
        let padded = (label as NSString).length >= width
            ? label
            : label.padding(toLength: width, withPad: " ", startingAt: 0)
        return "  \(padded)\(value)\n"
    }

    // MARK: - Query (C-FIND)

    /// Verbose header for `dicom-query`. Both sides gate this on `--verbose`; without
    /// it the output is just the shared results table, keeping piped output clean.
    /// `filters` is the ordered list of applied, non-empty match keys.
    public static func queryHeader(
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        level: QueryLevel,
        informationModel: String,
        timeout: Int,
        filters: [(label: String, value: String)]
    ) -> String {
        var out = rule("DICOM Query (C-FIND)")
        out += field("Server:", "\(host):\(port)")
        out += field("Calling AE Title:", callingAE)
        out += field("Called AE Title:", calledAE)
        out += field("Query Level:", levelName(level))
        out += field("Information Model:", informationModel)
        out += field("Timeout:", "\(timeout)s")
        if filters.isEmpty {
            out += field("Filters:", "(none)")
        } else {
            out += "  Filters:\n"
            for f in filters {
                out += "    " + f.label.padding(toLength: 17, withPad: " ", startingAt: 0) + f.value + "\n"
            }
        }
        out += "\n"
        return out
    }

    // MARK: - Send (C-STORE)

    public static func sendHeader(
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        priority: String, timeout: Int, fileCount: Int,
        retryAttempts: Int, transferSyntax: String?, dryRun: Bool
    ) -> String {
        var out = rule("DICOM Send (C-STORE)")
        out += field("Server:", "\(host):\(port)")
        out += field("Calling AE Title:", callingAE)
        out += field("Called AE Title:", calledAE)
        out += field("Priority:", priority)
        out += field("Timeout:", "\(timeout)s")
        out += field("Files:", "\(fileCount)")
        if retryAttempts > 0 { out += field("Retry attempts:", "\(retryAttempts)") }
        if let ts = transferSyntax, !ts.isEmpty { out += field("Transfer Syntax:", ts) }
        if dryRun { out += field("Mode:", "DRY RUN") }
        out += "\n"
        return out
    }

    /// The `[i/total] Sending: name (size)...` prefix, printed before the store so the
    /// user sees progress. No trailing newline — the result suffix completes the line.
    public static func sendFilePrefix(index: Int, total: Int, filename: String, size: Int) -> String {
        "[\(index)/\(total)] Sending: \(filename) (\(formatBytes(size)))..."
    }

    /// Completes a `sendFilePrefix` line with the outcome (and a trailing newline).
    public static func sendFileResultSuffix(success: Bool, rtt: TimeInterval, error: String?) -> String {
        if success {
            return " ✅ (\(formatRTT(rtt)))\n"
        }
        return " ❌ \(error ?? "Unknown error")\n"
    }

    /// A dry-run listing line: `  [i/total] name (size)`.
    public static func sendDryRunLine(index: Int, total: Int, filename: String, size: Int) -> String {
        "  [\(index)/\(total)] \(filename) (\(formatBytes(size)))\n"
    }

    public static func sendSummary(total: Int, succeeded: Int, failed: Int, bytes: Int, duration: TimeInterval) -> String {
        var out = "\n" + rule("Transfer Summary")
        out += field("Total files:", "\(total)")
        out += field("Succeeded:", "\(succeeded)")
        out += field("Failed:", "\(failed)")
        out += field("Bytes sent:", formatBytes(bytes))
        out += field("Duration:", formatDuration(duration))
        if failed == 0 {
            out += "\n✅ All files sent successfully\n"
        } else if succeeded == 0 {
            out += "\n❌ All files failed to send\n"
        } else {
            out += "\n⚠️ Partial success: \(succeeded) succeeded, \(failed) failed\n"
        }
        return out
    }

    // MARK: - Retrieve (C-MOVE / C-GET)

    public static func retrieveHeader(
        method: String,                 // "C-MOVE" or "C-GET"
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        moveDestination: String?,
        level: String,                  // "Study" / "Series" / "Instance"
        studyUID: String, seriesUID: String?, instanceUID: String?,
        output: String, hierarchical: Bool, timeout: Int,
        transferSyntax: String?
    ) -> String {
        var out = rule("DICOM Retrieve (\(method))")
        out += field("Server:", "\(host):\(port)")
        out += field("Calling AE Title:", callingAE)
        out += field("Called AE Title:", calledAE)
        out += field("Method:", method)
        if let dest = moveDestination, !dest.isEmpty { out += field("Move Destination:", dest) }
        out += field("Level:", level)
        out += field("Study UID:", studyUID)
        if let s = seriesUID, !s.isEmpty { out += field("Series UID:", s) }
        if let i = instanceUID, !i.isEmpty { out += field("Instance UID:", i) }
        out += field("Output:", output)
        out += field("Organization:", hierarchical ? "Hierarchical" : "Flat")
        out += field("Timeout:", "\(timeout)s")
        if let ts = transferSyntax, !ts.isEmpty {
            out += field("Transfer Syntax:", transferSyntaxDisplay(ts, isCMove: method == "C-MOVE"))
        }
        out += "\n"
        return out
    }

    /// Method-aware transfer-syntax description, computed identically on both sides:
    /// C-MOVE is advisory (the destination AE negotiates); C-GET proposes the resolved
    /// UID for the C-STORE sub-operations.
    public static func transferSyntaxDisplay(_ raw: String, isCMove: Bool) -> String {
        if isCMove {
            return "\(raw) (advisory — negotiated by destination AE)"
        }
        let resolved = TransferSyntax.parse(raw)?.uid ?? "unrecognised, using default"
        return "\(raw) → \(resolved) (proposed for C-STORE sub-ops)"
    }

    /// A received-instance line for C-GET: `  Received [N]: <uid> (<size>)`.
    /// The on-disk path is deliberately omitted — the in-app output directory may be a
    /// sandbox-resolved path that differs from the CLI's literal `--output`.
    public static func retrieveInstanceLine(index: Int, sopInstanceUID: String, size: Int) -> String {
        "  Received [\(index)]: \(sopInstanceUID) (\(formatBytes(size)))\n"
    }

    /// C-MOVE result block.
    public static func cMoveResult(status: String, completed: Int, failed: Int, warning: Int, isSuccess: Bool) -> String {
        var out = "C-MOVE Result:\n"
        out += field("Status:", status)
        out += field("Completed:", "\(completed)")
        out += field("Failed:", "\(failed)")
        out += field("Warnings:", "\(warning)")
        out += isSuccess ? "\n✅ Retrieval successful\n" : "\n❌ Retrieval returned non-success status\n"
        return out
    }

    /// C-GET completion summary.
    public static func cGetSummary(received: Int) -> String {
        if received == 0 {
            return "\n⚠️ C-GET completed but received 0 instances. "
                + "The SCP matched the request but sent no images — likely no storage "
                + "presentation context was negotiated for this study's SOP Class or transfer syntax.\n"
        }
        return "\n✅ C-GET completed — \(received) file(s) received\n"
    }

    // MARK: - Query-Retrieve (dicom-qr)

    public static func qrHeader(
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        mode: String,                   // "Automatic" / "Review"
        method: String, isReview: Bool, moveDestination: String?,
        output: String, timeout: Int,
        transferSyntax: String?,
        filters: [(label: String, value: String)]
    ) -> String {
        var out = rule("DICOM Query-Retrieve")
        out += field("Server:", "\(host):\(port)")
        out += field("Calling AE Title:", callingAE)
        out += field("Called AE Title:", calledAE)
        out += field("Mode:", mode)
        if !isReview {
            out += field("Method:", method)
            if let dest = moveDestination, !dest.isEmpty { out += field("Move Destination:", dest) }
        }
        out += field("Output:", output)
        out += field("Timeout:", "\(timeout)s")
        if let ts = transferSyntax, !ts.isEmpty, !isReview {
            out += field("Transfer Syntax:", transferSyntaxDisplay(ts, isCMove: method == "C-MOVE"))
        }
        if filters.isEmpty {
            out += field("Filters:", "(none)")
        } else {
            out += "  Filters:\n"
            for f in filters {
                out += "    " + f.label.padding(toLength: 17, withPad: " ", startingAt: 0) + f.value + "\n"
            }
        }
        out += "\n"
        return out
    }

    /// A compact study entry for the query phase of `dicom-qr`.
    public static func qrStudyEntry(
        index: Int, patientName: String?, patientID: String?,
        studyDescription: String?, studyDate: String?, modality: String?, studyUID: String?
    ) -> String {
        var out = "  [\(index)] \(patientName ?? "Unknown") (ID: \(patientID ?? "N/A"))\n"
        out += "      Study: \(studyDescription ?? "No description")\n"
        out += "      Date: \(studyDate ?? "N/A")  Modality: \(modality ?? "N/A")\n"
        if let uid = studyUID { out += "      UID: \(uid)\n" }
        out += "\n"
        return out
    }

    /// `[i/total] Retrieving: name — uid` line.
    public static func qrRetrieveLine(index: Int, total: Int, patientName: String?, studyUID: String) -> String {
        "[\(index)/\(total)] Retrieving: \(patientName ?? "Unknown") — \(studyUID)\n"
    }

    public static func qrRetrieveOutcome(success: Bool, error: String?) -> String {
        success ? "  ✅ Success\n" : "  ❌ Failed: \(error ?? "Unknown error")\n"
    }

    public static func qrSummary(total: Int, success: Int, failed: Int) -> String {
        var out = "\nRetrieval Summary:\n"
        out += "  Total: \(total)\n"
        out += "  Success: \(success)\n"
        out += "  Failed: \(failed)\n"
        return out
    }

    // MARK: - Modality Worklist (dicom-mwl query — MWL C-FIND)

    /// Header for `dicom-mwl query`: the title rule, connection fields, applied
    /// filters, and the "Querying…" progress line. Both the CLI (gated on `--verbose`)
    /// and the Studio MWL panel build it here so the chrome can't drift. `filters` is
    /// the ordered list of applied, non-empty match keys.
    public static func mwlQueryHeader(
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        timeout: Int,
        filters: [(label: String, value: String)]
    ) -> String {
        var out = rule("DICOM Modality Worklist (C-FIND)")
        out += mwlField("Server:", "\(host):\(port)")
        out += mwlField("Calling AE Title:", callingAE)
        out += mwlField("Called AE Title:", calledAE)
        out += mwlField("Timeout:", "\(timeout)s")
        for f in filters { out += mwlField(f.label, f.value) }
        out += "\nQuerying Modality Worklist...\n\n"
        return out
    }

    /// The `Found N worklist item(s):` lead-in printed before the item list.
    public static func mwlFound(count: Int) -> String {
        "Found \(count) worklist item(s):\n\n"
    }

    /// The empty-result line.
    public static func mwlNoResults() -> String { "No worklist items found.\n" }

    /// One worklist item block: `[N] Worklist Item`, a rule, then the present fields.
    /// `verbose` appends the raw-attribute dump (used by the CLI's `--verbose`).
    public static func mwlItem(index: Int, item: WorklistItem, verbose: Bool) -> String {
        var out = "[\(index)] Worklist Item\n"
        out += String(repeating: "─", count: 60) + "\n"
        // Patient
        if let v = item.patientName       { out += mwlField("Patient Name:", v) }
        if let v = item.patientID         { out += mwlField("Patient ID:", v) }
        if let v = item.patientBirthDate  { out += mwlField("Date of Birth:", v) }
        if let v = item.patientSex        { out += mwlField("Sex:", v) }
        // Study / order
        if let v = item.accessionNumber   { out += mwlField("Accession Number:", v) }
        if let v = item.referringPhysicianName        { out += mwlField("Referring Physician:", v) }
        if let v = item.requestedProcedureID          { out += mwlField("Requested Proc. ID:", v) }
        if let v = item.requestedProcedureDescription { out += mwlField("Requested Proc. Desc:", v) }
        if let v = item.studyInstanceUID  { out += mwlField("Study UID:", v) }
        // Scheduled Procedure Step
        if let v = item.modality          { out += mwlField("Modality:", v) }
        if let d = item.scheduledProcedureStepStartDate {
            let dt = item.scheduledProcedureStepStartTime.map { "\(d)  \($0)" } ?? d
            out += mwlField("Scheduled Date/Time:", dt)
        }
        if let v = item.scheduledProcedureStepStatus      { out += mwlField("SPS Status:", v) }
        if let v = item.scheduledProcedureStepID          { out += mwlField("SPS ID:", v) }
        if let v = item.scheduledProcedureStepDescription { out += mwlField("SPS Description:", v) }
        if let v = item.scheduledStationAETitle           { out += mwlField("Station AE Title:", v) }
        if let v = item.scheduledStationName              { out += mwlField("Station Name:", v) }
        if let v = item.scheduledPerformingPhysicianName  { out += mwlField("Performing Physician:", v) }
        if verbose {
            out += "  Raw Attributes:\n"
            for (tag, data) in item.attributes.sorted(by: { $0.key < $1.key }) {
                let value = String(data: data, encoding: .ascii) ??
                    data.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
                out += "    (\(String(format: "%04X", tag.group)),\(String(format: "%04X", tag.element))): \(value)\n"
            }
        }
        out += "\n"
        return out
    }

    /// Completion summary line for a successful worklist query.
    public static func mwlCompleted(count: Int) -> String {
        "✅ Worklist query completed — \(count) item(s) returned\n"
    }

    /// Returns the server-side result-limit caution when `count` matches a common cap
    /// (50/100/200/…), empty string otherwise — the single source of truth for the
    /// heuristic so the CLI and the app warn (or stay silent) identically.
    public static func mwlLimitWarning(count: Int) -> String {
        let commonLimits: Set<Int> = [50, 100, 200, 250, 500, 1000, 2000, 5000]
        guard commonLimits.contains(count) else { return "" }
        return "⚠️  The result count (\(count)) may be capped by a server-side limit.\n"
            + "    Check your PACS server configuration (e.g., LimitFindResults in Orthanc,\n"
            + "    or max_worklist_results in dcm4chee) to increase or remove the limit.\n"
    }

    /// The worklist items as a pretty-printed JSON array. The keys (notably
    /// `StudyInstanceUID` / `SPSID` / `AccessionNumber`) are the contract the
    /// CLI-parity MWL comparator parses, so both sides emit them identically from here.
    public static func mwlJSON(items: [WorklistItem]) -> String {
        var jsonItems: [[String: Any]] = []
        for item in items {
            var jsonItem: [String: Any] = [:]
            if let v = item.patientName                       { jsonItem["PatientName"] = v }
            if let v = item.patientID                         { jsonItem["PatientID"] = v }
            if let v = item.patientBirthDate                  { jsonItem["PatientBirthDate"] = v }
            if let v = item.patientSex                        { jsonItem["PatientSex"] = v }
            if let v = item.accessionNumber                   { jsonItem["AccessionNumber"] = v }
            if let v = item.studyInstanceUID                  { jsonItem["StudyInstanceUID"] = v }
            if let v = item.referringPhysicianName            { jsonItem["ReferringPhysicianName"] = v }
            if let v = item.requestedProcedureID              { jsonItem["RequestedProcedureID"] = v }
            if let v = item.requestedProcedureDescription     { jsonItem["RequestedProcedureDescription"] = v }
            if let v = item.modality                          { jsonItem["Modality"] = v }
            if let v = item.scheduledStationAETitle           { jsonItem["ScheduledStationAETitle"] = v }
            if let v = item.scheduledStationName              { jsonItem["ScheduledStationName"] = v }
            if let v = item.scheduledProcedureStepStartDate   { jsonItem["SPSStartDate"] = v }
            if let v = item.scheduledProcedureStepStartTime   { jsonItem["SPSStartTime"] = v }
            if let v = item.scheduledProcedureStepStatus      { jsonItem["SPSStatus"] = v }
            if let v = item.scheduledProcedureStepID          { jsonItem["SPSID"] = v }
            if let v = item.scheduledProcedureStepDescription { jsonItem["SPSDescription"] = v }
            if let v = item.scheduledPerformingPhysicianName  { jsonItem["ScheduledPerformingPhysician"] = v }
            jsonItems.append(jsonItem)
        }
        let data = (try? JSONSerialization.data(withJSONObject: jsonItems,
                                                options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return (String(data: data, encoding: .utf8) ?? "") + "\n"
    }

    // MARK: - Modality Performed Procedure Step (dicom-mpps — N-CREATE / N-SET)

    /// Header for `dicom-mpps create`/`update`: the title rule, the standard
    /// connection/status fields, then the operation-specific `fields` (study/patient/…
    /// for N-CREATE, mpps-uid/series/… for N-SET) in display order. Both the CLI and
    /// the Studio MPPS panel build it here.
    public static func mppsHeader(
        isCreate: Bool,
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        status: String, timeout: Int,
        fields: [(label: String, value: String)]
    ) -> String {
        var out = rule("DICOM MPPS (\(isCreate ? "N-CREATE" : "N-SET"))")
        out += mwlField("Operation:", isCreate ? "Create (N-CREATE)" : "Update (N-SET)")
        out += mwlField("Server:", "\(host):\(port)")
        out += mwlField("Calling AE Title:", callingAE)
        out += mwlField("Called AE Title:", calledAE)
        out += mwlField("Status:", status)
        out += mwlField("Timeout:", "\(timeout)s")
        for f in fields { out += mwlField(f.label, f.value) }
        out += "\n"
        return out
    }

    /// The in-flight progress line printed before the N-CREATE / N-SET round-trip.
    public static func mppsProgress(isCreate: Bool) -> String {
        isCreate ? "Creating MPPS instance (N-CREATE)...\n"
                 : "Updating MPPS instance (N-SET)...\n"
    }

    /// N-CREATE success block. The `MPPS Instance UID:` line is the contract the
    /// CLI-parity MPPS comparator parses to thread the minted UID into the N-SET, so
    /// it must stay verbatim. Any context-specific "next step" hint is appended by the
    /// caller (the CLI prints the `dicom-mpps update …` command; the app prints the UI
    /// instruction), since that guidance is legitimately different per side.
    public static func mppsCreateResult(uid: String) -> String {
        "✅ MPPS instance created\n  MPPS Instance UID: \(uid)\n"
    }

    /// N-SET success block. `New Status:` and `Referenced Images:` (the latter only
    /// when ≥1 image is referenced) are the contract the CLI-parity MPPS comparator
    /// parses, so they must stay verbatim.
    public static func mppsUpdateResult(uid: String, status: String, referencedImages: Int) -> String {
        var out = "✅ MPPS instance updated\n"
        out += "  MPPS Instance UID: \(uid)\n"
        out += "  New Status: \(status)\n"
        if referencedImages > 0 { out += "  Referenced Images: \(referencedImages)\n" }
        return out
    }

    // MARK: - Verification (dicom-echo — C-ECHO)

    /// Verbose header for `dicom-echo`. Both sides gate this on `--verbose`; without
    /// it the output is just the per-echo result lines (and optional summary), keeping
    /// piped output clean — the same convention as ``queryHeader(host:port:callingAE:calledAE:level:informationModel:timeout:filters:)``.
    public static func echoHeader(
        host: String, port: UInt16,
        callingAE: String, calledAE: String,
        timeout: Int, count: Int
    ) -> String {
        var out = rule("DICOM Echo (C-ECHO)")
        out += field("Server:", "\(host):\(port)")
        out += field("Calling AE Title:", callingAE)
        out += field("Called AE Title:", calledAE)
        out += field("Timeout:", "\(timeout)s")
        out += field("Count:", "\(count)")
        out += "\n"
        return out
    }

    /// The `[i/total] Sending C-ECHO...` progress line — emitted by both sides only
    /// when `--verbose` is set AND more than one echo is requested.
    public static func echoProgress(index: Int, total: Int) -> String {
        "[\(index)/\(total)] Sending C-ECHO...\n"
    }

    /// Per-echo success block. Printed for a single echo or in `--verbose`; for a
    /// silent multi-echo run the caller emits ``echoProgressDot()`` instead. The
    /// round-trip time is rendered via ``formatRTT(_:)`` and then masked by the parity
    /// engine (two echoes never take the exact same wall-clock time).
    public static func echoSuccess(remoteAE: String, status: DIMSEStatus, rtt: TimeInterval) -> String {
        var out = "✅ C-ECHO successful\n"
        out += "  Remote AE: \(remoteAE)\n"
        out += "  Status: \(status)\n"
        out += "  Round-trip time: \(formatRTT(rtt))\n"
        return out
    }

    /// A single progress dot for a silent (non-verbose) multi-echo run. No newline —
    /// the caller emits one after the loop (see ``echoDotsTerminator()``).
    public static func echoProgressDot() -> String { "." }

    /// The newline that terminates a row of ``echoProgressDot()`` marks.
    public static func echoDotsTerminator() -> String { "\n" }

    /// Per-echo block when the SCP responded with a non-success DIMSE status.
    public static func echoStatusFailure(status: DIMSEStatus) -> String {
        "❌ C-ECHO failed\n  Status: \(status)\n"
    }

    /// The multi-echo / `--stats` summary block. Leading blank line included so it is
    /// visually separated from the per-echo output above it.
    public static func echoSummary(sent: Int, succeeded: Int, failed: Int) -> String {
        let rate = sent > 0 ? Double(succeeded) / Double(sent) * 100 : 0
        var out = "\nSummary:\n"
        out += "  Sent: \(sent)\n"
        out += "  Successful: \(succeeded)\n"
        out += "  Failed: \(failed)\n"
        out += "  Success rate: \(String(format: "%.1f", rate))%\n"
        return out
    }

    /// The `--stats` round-trip-time block. Returns empty when no successful echo
    /// produced a sample. All three values are masked by the parity engine.
    public static func echoStats(roundTripTimes: [TimeInterval]) -> String {
        guard !roundTripTimes.isEmpty else { return "" }
        let minRTT = roundTripTimes.min() ?? 0
        let maxRTT = roundTripTimes.max() ?? 0
        let avgRTT = roundTripTimes.reduce(0, +) / Double(roundTripTimes.count)
        var out = "\nRound-trip time statistics:\n"
        out += "  Min: \(formatRTT(minRTT))\n"
        out += "  Avg: \(formatRTT(avgRTT))\n"
        out += "  Max: \(formatRTT(maxRTT))\n"
        return out
    }

    /// A detailed, actionable C-ECHO failure block for a network-layer error (as
    /// opposed to a non-success DIMSE status, which uses ``echoStatusFailure(status:)``).
    /// Lives here so the CLI and the Studio panel surface the SAME diagnosis and hints
    /// instead of drifting — the app used to be the only side with these hints.
    public static func echoFailureDetail(
        _ error: DICOMNetworkError,
        host: String, port: UInt16,
        callingAE: String, calledAE: String, timeout: Int
    ) -> String {
        var out = "❌ C-ECHO failed\n"
        switch error {
        case .associationRejected(let result, let source, let reason):
            out += "  Reason: Association rejected (\(result))\n"
            out += "  Source: \(source)\n"
            out += "  Code  : \(reason) — \(associateRejectReasonDescription(source: source, reason: reason))\n"
            out += "\n"
            // Actionable hints for the most common dcm4chee2 / legacy-PACS rejections.
            switch (source, reason) {
            case (.serviceUser, 3):
                out += "  💡 Hint: The remote SCP does not recognise the Called AE Title\n"
                out += "           (\"\(calledAE)\"). Register it in the remote AE Manager\n"
                out += "           (e.g. dcm4chee AE Management → Add AE Title) or change the\n"
                out += "           Called AE Title to match the server's configured AE.\n"
            case (.serviceUser, 7):
                out += "  💡 Hint: The remote SCP does not recognise the Calling AE Title\n"
                out += "           (\"\(callingAE)\"). Add it to the remote server's list of\n"
                out += "           permitted calling AE titles, or change the Calling AE Title.\n"
            case (.serviceUser, 2):
                out += "  💡 Hint: The remote SCP reports the application context is not supported.\n"
                out += "           Make sure the server has DICOM networking enabled.\n"
            case (.serviceProviderACSE, 2):
                out += "  💡 Hint: Protocol version mismatch. Try switching to Implicit VR transfer\n"
                out += "           syntax for legacy server compatibility.\n"
            case (.serviceProviderPresentation, 1):
                out += "  💡 Hint: Server temporarily busy. Wait a moment and retry.\n"
            default:
                out += "  💡 Hint: Verify the host, port, and AE titles. For dcm4chee2, ensure\n"
                out += "           both the Calling and Called AE Titles are registered in the\n"
                out += "           server's AE Management console.\n"
            }
        case .connectionFailed(let msg):
            out += "  Error: \(msg)\n"
            out += "  💡 Hint: Check host (\(host)), port (\(port)), and that the DICOM server is running.\n"
        case .timeout, .artimTimerExpired:
            out += "  Error: Connection timed out after \(timeout)s\n"
            out += "  💡 Hint: Verify host/port are reachable. Try increasing the Timeout value.\n"
        case .connectionClosed:
            out += "  Error: Connection closed unexpectedly by remote peer\n"
            out += "  💡 Hint: The server may have rejected the connection silently.\n"
            out += "           Check that the Called AE Title is registered on the server.\n"
        default:
            out += "  Error: \(error.description)\n"
        }
        return out
    }

    /// A C-ECHO error block for a non-`DICOMNetworkError` thrown error.
    public static func echoError(_ message: String) -> String {
        "❌ C-ECHO error: \(message)\n"
    }

    // MARK: - Verification diagnostics (dicom-echo --diagnose)

    public static func echoDiagnoseHeader() -> String {
        "Running DICOM network diagnostics...\n\n"
    }

    public static func echoDiagnoseTest1Header(host: String, port: UInt16) -> String {
        "Test 1: Basic C-ECHO connectivity\n  Testing connection to \(host):\(port)...\n"
    }

    public static func echoDiagnoseBasicResult(success: Bool, status: DIMSEStatus, rtt: TimeInterval) -> String {
        if success {
            return "  Basic connectivity: PASS\n    Round-trip time: \(formatRTT(rtt))\n"
        }
        return "  Basic connectivity: FAIL\n    Status: \(status)\n"
    }

    public static func echoDiagnoseBasicError(_ message: String) -> String {
        "  Basic connectivity: ERROR\n    Error: \(message)\n"
    }

    public static func echoDiagnoseTest2Header() -> String {
        "\nTest 2: Connection stability (5 requests)\n"
    }

    public static func echoDiagnoseStabilitySuccess(index: Int, total: Int, rtt: TimeInterval) -> String {
        "  [\(index)/\(total)] RTT: \(formatRTT(rtt))\n"
    }

    public static func echoDiagnoseStabilityFailure(index: Int, total: Int, status: DIMSEStatus) -> String {
        "  [\(index)/\(total)] Status: \(status)\n"
    }

    public static func echoDiagnoseStabilityError(index: Int, total: Int, message: String) -> String {
        "  [\(index)/\(total)] Error: \(message)\n"
    }

    /// The stability tally plus, when at least one probe succeeded, a min/avg/max line
    /// (all masked by the parity engine).
    public static func echoDiagnoseStabilitySummary(successes: Int, total: Int, roundTripTimes: [TimeInterval]) -> String {
        var out = "  Connection stability: \(successes)/\(total) successful\n"
        if !roundTripTimes.isEmpty {
            let minRTT = roundTripTimes.min() ?? 0
            let maxRTT = roundTripTimes.max() ?? 0
            let avgRTT = roundTripTimes.reduce(0, +) / Double(roundTripTimes.count)
            out += "  RTT min/avg/max: \(formatRTT(minRTT))/\(formatRTT(avgRTT))/\(formatRTT(maxRTT))\n"
        }
        return out
    }

    /// The "association parameters" probe (Test 3). Reads the verification defaults
    /// directly so the implementation-class/version strings can't drift between sides.
    public static func echoDiagnoseAssociationParams() -> String {
        var out = "\nTest 3: Association parameters\n"
        out += "  Implementation Class UID: \(VerificationConfiguration.defaultImplementationClassUID)\n"
        out += "  Implementation Version: \(VerificationConfiguration.defaultImplementationVersionName)\n"
        out += "  SOP Class: Verification (1.2.840.10008.1.1)\n"
        out += "  Transfer Syntaxes: Explicit VR Little Endian, Implicit VR Little Endian\n"
        return out
    }

    /// The closing verdict for `--diagnose`. `total` defaults to the 5-probe stability
    /// test the diagnostics run.
    public static func echoDiagnoseResult(stabilitySuccesses: Int, total: Int = 5) -> String {
        var out = "\nDiagnostics complete.\n"
        if stabilitySuccesses == total {
            out += "Result: All tests PASSED ✓\n"
        } else if stabilitySuccesses > 0 {
            out += "Result: Partial success (some tests failed) ⚠\n"
        } else {
            out += "Result: All tests FAILED ✗\n"
        }
        return out
    }

    /// Translates an A-ASSOCIATE-RJ reason byte into a human-readable string.
    ///
    /// Reference: PS3.8 Tables 9-20, 9-21, 9-22.
    public static func associateRejectReasonDescription(source: AssociateRejectSource, reason: UInt8) -> String {
        switch source {
        case .serviceUser:
            switch reason {
            case 1: return "No reason given"
            case 2: return "Application context name not supported"
            case 3: return "Called AE Title not recognised"
            case 7: return "Calling AE Title not recognised"
            default: return "Unknown reason"
            }
        case .serviceProviderACSE:
            switch reason {
            case 1: return "No reason given"
            case 2: return "Protocol version not supported"
            default: return "Unknown reason"
            }
        case .serviceProviderPresentation:
            switch reason {
            case 0: return "No reason given"
            case 1: return "Temporary congestion"
            case 2: return "Local limit exceeded"
            default: return "Unknown reason"
            }
        }
    }

    // MARK: - Helpers

    public static func levelName(_ level: QueryLevel) -> String {
        switch level {
        case .patient: return "patient"
        case .study:   return "study"
        case .series:  return "series"
        case .image:   return "instance"
        }
    }
}
