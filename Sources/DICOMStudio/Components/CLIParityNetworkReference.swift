// CLIParityNetworkReference.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// The "reference side" for the CLI Parity screen's NETWORK tools.
//
// Unlike the offline tools — whose parity reference is the app's own in-process
// CLIWorkshopViewModel — the network reference drives the DICOMKit package API
// (DICOMNetwork) DIRECTLY, exactly the way the dicom-* CLIs do internally. It does
// NOT touch the CLI Workshop's network execution code. The parity test therefore
// answers: "does the dicom-echo binary behave identically to a direct, intended
// use of the DICOMKit package API?" (SDK ↔ CLI conformance).
//
// The reference builds the timing-independent EchoSemantics record DIRECTLY from
// the API results (no text rendering), so only the CLI side is text-parsed. To
// keep the two records comparable, the pure record builder replicates the CLI's
// output GATING (which per-echo detail lines dicom-echo prints for a given flag
// combination) — see echoRecord(_:verbose:).

import Foundation
import DICOMCore
import DICOMNetwork

/// The query keys a `dicom-query` parity scenario applies (empty == not set).
public struct QueryFilters: Sendable, Equatable {
    public var patientName = ""
    public var patientID = ""
    public var studyDate = ""
    public var modality = ""
    public var accession = ""
    public var studyDescription = ""
    public var studyUID = ""
    public var seriesUID = ""
    public init() {}
}

public enum CLIParityNetworkReference {

    /// One C-ECHO attempt reduced to the fields that matter for parity. `responded
    /// == false` models a thrown error (connection failure / association reject):
    /// the CLI's `catch` branch prints no DIMSE status, so neither does the record.
    public struct EchoCallOutcome: Sendable, Equatable {
        public let responded: Bool
        public let success: Bool
        public let statusHex: String   // "0x0000" … (meaningful only when responded)
        public let remoteAE: String
        public init(responded: Bool, success: Bool, statusHex: String, remoteAE: String) {
            self.responded = responded; self.success = success
            self.statusHex = statusHex; self.remoteAE = remoteAE
        }
    }

    // MARK: Pure record builders (testable without a server)

    /// Builds the echo-mode record from the per-attempt outcomes, replicating the
    /// dicom-echo CLI's print gating so the record matches what `parse()` extracts
    /// from the CLI text:
    ///   • SUCCESS detail (Status + Remote AE) is shown only when `--verbose` or a
    ///     single echo (`count == 1`).
    ///   • A DIMSE FAILURE always prints its Status (regardless of verbosity).
    ///   • A thrown error prints neither.
    public static func echoRecord(_ calls: [EchoCallOutcome], verbose: Bool) -> EchoSemantics {
        let count = calls.count
        let succeeded = calls.filter { $0.responded && $0.success }.count
        let failed = count - succeeded
        let showsSuccessDetail = verbose || count == 1
        var statuses: [String] = []
        var aes: [String] = []
        for c in calls where c.responded {
            if c.success {
                if showsSuccessDetail {
                    statuses.append(c.statusHex)
                    if !c.remoteAE.isEmpty { aes.append(c.remoteAE) }
                }
            } else {
                statuses.append(c.statusHex)   // CLI prints Status on every DIMSE failure
            }
        }
        return EchoSemantics(
            mode: "echo", sent: count, succeeded: succeeded, failed: failed,
            statusCodes: Array(Set(statuses)).sorted(),
            remoteAEs: Array(Set(aes)).sorted(),
            diagBasicOK: nil, diagStability: nil, diagResult: nil)
    }

    /// Builds the diagnose-mode record. `test1Responded == false` models the CLI's
    /// early `ExitCode(1)` when basic connectivity throws (no stability/result lines).
    public static func diagnoseRecord(test1Responded: Bool, test1Success: Bool,
                                      stabilitySuccesses: Int?) -> EchoSemantics {
        guard test1Responded else {
            return EchoSemantics(mode: "diagnose", sent: 0, succeeded: 0, failed: 0,
                                 statusCodes: [], remoteAEs: [],
                                 diagBasicOK: false, diagStability: nil, diagResult: nil)
        }
        let stable = stabilitySuccesses ?? 0
        let result = stable == 5 ? "PASSED" : (stable > 0 ? "PARTIAL" : "FAILED")
        return EchoSemantics(mode: "diagnose", sent: 0, succeeded: 0, failed: 0,
                             statusCodes: [], remoteAEs: [],
                             diagBasicOK: test1Success, diagStability: stable, diagResult: result)
    }

    // MARK: Live reference (drives the DICOMKit package API)

    /// Runs the C-ECHO scenario against the live PACS using DICOMVerificationService
    /// — the same package API dicom-echo calls — and returns the semantic record.
    public static func echo(host: String, port: UInt16, callingAET: String, calledAET: String,
                            timeout: TimeInterval, count: Int, verbose: Bool, diagnose: Bool) async -> EchoSemantics {
        func attempt() async -> EchoCallOutcome {
            do {
                let r = try await DICOMVerificationService.echo(
                    host: host, port: port, callingAE: callingAET, calledAE: calledAET, timeout: timeout)
                return EchoCallOutcome(responded: true, success: r.success,
                                       statusHex: hex(r.status), remoteAE: r.remoteAETitle)
            } catch {
                return EchoCallOutcome(responded: false, success: false, statusHex: "", remoteAE: "")
            }
        }

        if diagnose {
            // Test 1: basic connectivity (a thrown error aborts early, like the CLI).
            let t1 = await attempt()
            guard t1.responded else {
                return diagnoseRecord(test1Responded: false, test1Success: false, stabilitySuccesses: nil)
            }
            // Test 2: 5-request stability probe.
            var stable = 0
            for i in 0..<5 {
                if (await attempt()).success { stable += 1 }
                if i < 4 { try? await Task.sleep(nanoseconds: 100_000_000) }
            }
            return diagnoseRecord(test1Responded: true, test1Success: t1.success, stabilitySuccesses: stable)
        }

        var calls: [EchoCallOutcome] = []
        let n = max(1, count)
        for i in 0..<n {
            calls.append(await attempt())
            if i < n - 1 { try? await Task.sleep(nanoseconds: 100_000_000) }
        }
        return echoRecord(calls, verbose: verbose)
    }

    // MARK: dicom-query (C-FIND) — read-only

    /// Runs the C-FIND scenario against the live PACS using DICOMQueryService — the
    /// same package API dicom-query calls — building the IDENTICAL QueryKeys as the
    /// CLI (same return keys + filters) so the matched results line up.
    public static func query(host: String, port: UInt16, callingAET: String, calledAET: String,
                             timeout: TimeInterval, level: String, filters: QueryFilters) async -> QuerySemantics {
        let qLevel = queryLevel(level)
        do {
            let config = QueryConfiguration(
                callingAETitle: try AETitle(callingAET),
                calledAETitle: try AETitle(calledAET),
                timeout: timeout,
                informationModel: qLevel == .patient ? .patientRoot : .studyRoot)
            let keys = DICOMQueryService.buildQueryKeys(
                level: qLevel,
                patientName: filters.patientName, patientID: filters.patientID,
                studyDate: filters.studyDate, modality: filters.modality,
                accession: filters.accession, studyDescription: filters.studyDescription,
                studyUID: filters.studyUID, seriesUID: filters.seriesUID)
            let results = try await DICOMQueryService.find(
                host: host, port: port, configuration: config, queryKeys: keys)
            // Build [tag.description: value] per result — identical to dicom-query's
            // QueryFormatter.formatJSON, so the records compare equal.
            let objects: [[String: String]] = results.map { result in
                var obj: [String: String] = [:]
                for (tag, data) in result.attributes {
                    if let s = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
                        if !trimmed.isEmpty { obj[tag.description] = trimmed }
                    }
                }
                return obj
            }
            return CLIParityQueryComparator.semantics(level: level, success: true, objects: objects)
        } catch {
            return CLIParityQueryComparator.semantics(level: level, success: false, objects: [])
        }
    }

    static func queryLevel(_ s: String) -> QueryLevel {
        switch s {
        case "patient":  return .patient
        case "series":   return .series
        case "instance": return .image
        default:         return .study
        }
    }
    // Query keys are built by the SHARED DICOMQueryService.buildQueryKeys (DICOMNetwork) —
    // the same mapping the CLI and the app use — so the reference cannot drift from them.

    // MARK: dicom-send (C-STORE) — WRITES to the PACS

    /// Expands a send path (a file, or a directory the user picked) into the exact
    /// DICOM file list `dicom-send` would transmit, via the SHARED
    /// `DICOMSendFileGatherer` the CLI itself uses — so the reference's file set
    /// can never drift from the binary's (the dry-run "Found N" and the real-send
    /// counts both depend on identical enumeration). Empty path → no files.
    public static func gatherSendFiles(path: String, recursive: Bool) -> [String] {
        path.isEmpty ? [] : DICOMSendFileGatherer.gather(paths: [path], recursive: recursive)
    }

    /// Sends the given file(s) using DICOMStorageService.store — the same package API
    /// the dicom-send CLI and the in-app send call — and returns the outcome counts.
    /// `verify` runs a real C-ECHO preflight first (matching both adapters).
    public static func send(host: String, port: UInt16, callingAET: String, calledAET: String,
                            timeout: TimeInterval, filePaths: [String], priorityName: String,
                            transferSyntaxName: String, verify: Bool, dryRun: Bool) async -> SendSemantics {
        if dryRun {
            return SendSemantics(dryRun: true, sent: filePaths.count, succeeded: 0, failed: 0)
        }
        let priority: DIMSEPriority = priorityName == "high" ? .high : (priorityName == "low" ? .low : .medium)
        if verify {
            let ok = (try? await DICOMVerificationService.echo(
                host: host, port: port, callingAE: callingAET, calledAE: calledAET, timeout: timeout))?.success ?? false
            if !ok { return SendSemantics(dryRun: false, sent: filePaths.count, succeeded: 0, failed: filePaths.count) }
        }
        let tsUID: String? = transferSyntaxName.isEmpty ? nil : TransferSyntax.parse(transferSyntaxName)?.uid
        var succeeded = 0, failed = 0
        for path in filePaths {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { failed += 1; continue }
            do {
                let r: StoreResult
                if let ts = tsUID, !ts.isEmpty {
                    r = try await DICOMStorageService.store(
                        fileData: data, preferredTransferSyntaxUID: ts, to: host, port: port,
                        callingAE: callingAET, calledAE: calledAET, priority: priority, timeout: timeout)
                } else {
                    r = try await DICOMStorageService.store(
                        fileData: data, to: host, port: port,
                        callingAE: callingAET, calledAE: calledAET, priority: priority, timeout: timeout)
                }
                if r.status.isSuccessOrWarning { succeeded += 1 } else { failed += 1 }
            } catch {
                failed += 1
            }
        }
        return SendSemantics(dryRun: false, sent: filePaths.count, succeeded: succeeded, failed: failed)
    }

    // MARK: Display

    /// A human-readable rendering of the echo record for the row's "reference" pane.
    public static func render(_ s: EchoSemantics) -> String {
        "DICOMKit package API reference (DICOMVerificationService.echo):\n"
            + CLIParityEchoComparator.canonical(s).joined(separator: "\n")
    }

    /// A human-readable rendering of the query record for the row's "reference" pane.
    public static func renderQuery(_ s: QuerySemantics) -> String {
        "DICOMKit package API reference (DICOMQueryService.find):\n"
            + CLIParityQueryComparator.canonical(s).joined(separator: "\n")
    }

    /// A human-readable rendering of the send record for the row's "reference" pane.
    public static func renderSend(_ s: SendSemantics) -> String {
        "DICOMKit package API reference (DICOMStorageService.store):\n"
            + CLIParitySendComparator.canonical(s).joined(separator: "\n")
    }

    // MARK: Helpers

    /// "0xNNNN" matching DIMSEStatus.description's hex (and the CLI parser).
    static func hex(_ status: DIMSEStatus) -> String {
        String(format: "0x%04X", status.rawValue)
    }
}
