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
import DICOMWeb

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

/// The scope a `dicom-retrieve` parity scenario retrieves (empty == not set). The
/// Study UID is required; Series/Instance UIDs widen the sweep to those levels;
/// Move Destination AE is required only for the C-MOVE scenarios; `transferSyntax`
/// (a TransferSyntax UID, empty == server decides) is requested by the C-GET scenarios.
public struct RetrieveScope: Sendable, Equatable {
    public var studyUID = ""
    public var seriesUID = ""
    public var instanceUID = ""
    public var moveDest = ""
    public var transferSyntax = ""
    public init() {}
}

/// The filters a `dicom-mwl` parity scenario applies to the worklist C-FIND
/// (empty == not set). These map 1:1 onto the dicom-mwl `query` flags and the
/// shared `WorklistQueryKeys.forQuery` builder. `date` accepts YYYYMMDD or
/// "today"/"tomorrow" (resolved by the shared `WorklistQueryKeys.resolveScheduledDate`).
public struct WorklistFilters: Sendable, Equatable {
    public var date = ""
    public var station = ""
    public var patientName = ""
    public var patientID = ""
    public var modality = ""
    public var spsStatus = ""
    public var accession = ""
    public init() {}
}

/// The inputs a `dicom-mpps` parity scenario drives (empty == not set). The Study
/// UID is required for N-CREATE; the patient/accession/SPS-ID fields are optional
/// N-CREATE attributes; `seriesUID` + `imageUIDs` populate the referenced-image set
/// carried by the completing N-SET (mirroring `dicom-mpps update --study-uid
/// --series-uid --image-uid`).
public struct MPPSScope: Sendable, Equatable {
    public var studyUID = ""
    public var patientName = ""
    public var patientID = ""
    public var accession = ""
    public var spsID = ""
    public var seriesUID = ""
    public var imageUIDs: [String] = []
    public init() {}
}

/// The inputs a `dicom-wado` (DICOMweb) parity scenario drives. The `dicom-wado`
/// binary's four subcommands share one endpoint — the HTTP(S) `baseURL` (+ optional
/// bearer `token`) — resolved at run time like the DIMSE host/port. The rest are the
/// per-subcommand concrete inputs: `query` keys for QIDO-RS (study/series/instance
/// UIDs double as the WADO-RS retrieve scope), and a UPS create label + patient for
/// the read-write UPS claim lifecycle (the label is optional — the harness substitutes a
/// default when it is blank, so the write scenarios always run).
public struct WADOScope: Sendable, Equatable {
    public var query = QueryFilters()      // QIDO-RS keys (studyUID/seriesUID double as the retrieve scope)
    public var instanceUID = ""            // WADO-RS instance-level retrieve (with study + series)
    /// Which subcommand the parity sweep generates scenarios for: "query", "retrieve",
    /// "store", or "ups". Empty means all four. Mirrors the WADO panel's segmented
    /// switch so the sweep focuses on the subcommand the user is testing.
    public var subcommand = ""
    public var upsLabel = ""               // UPS create label; harness substitutes a default when left blank
    public var upsPatientName = ""
    public var upsPatientID = ""
    public var upsAET = ""                 // Requesting AE for the UPS state change (claim)
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

    /// Sends the given file(s) AS-IS using DICOMStorageService.store — the same package
    /// API the dicom-send CLI and the in-app send call — and returns the outcome counts.
    /// `verify` runs a real C-ECHO preflight first (matching both adapters).
    ///
    /// There is intentionally NO transfer-syntax dimension here: dicom-send transmits each
    /// file in its OWN transfer syntax. The CLI's `--transfer-syntax` flag is kept for
    /// completeness but is omitted from the UI and from parity, so the reference always
    /// uses the as-is `store(fileData:to:)` path — matching the UI and the no-flag CLI.
    public static func send(host: String, port: UInt16, callingAET: String, calledAET: String,
                            timeout: TimeInterval, filePaths: [String], priorityName: String,
                            verify: Bool, dryRun: Bool) async -> SendSemantics {
        if dryRun {
            return SendSemantics(dryRun: true, sent: filePaths.count, succeeded: 0, failed: 0)
        }
        let priority: DIMSEPriority = priorityName == "high" ? .high : (priorityName == "low" ? .low : .medium)
        if verify {
            let ok = (try? await DICOMVerificationService.echo(
                host: host, port: port, callingAE: callingAET, calledAE: calledAET, timeout: timeout))?.success ?? false
            if !ok { return SendSemantics(dryRun: false, sent: filePaths.count, succeeded: 0, failed: filePaths.count) }
        }
        var succeeded = 0, failed = 0
        for path in filePaths {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { failed += 1; continue }
            do {
                let r = try await DICOMStorageService.store(
                    fileData: data, to: host, port: port,
                    callingAE: callingAET, calledAE: calledAET, priority: priority, timeout: timeout)
                if r.status.isSuccessOrWarning { succeeded += 1 } else { failed += 1 }
            } catch {
                failed += 1
            }
        }
        return SendSemantics(dryRun: false, sent: filePaths.count, succeeded: succeeded, failed: failed)
    }

    // MARK: dicom-retrieve (C-MOVE / C-GET) — PULLS instances from the PACS

    /// Runs the retrieve scenario against the live PACS using DICOMRetrieveService —
    /// the same package API dicom-retrieve calls — and builds the outcome record.
    ///
    /// C-MOVE asks the PACS to forward the matched instances to `moveDest`; the
    /// counts come from the C-MOVE-RSP. C-GET streams the instances back on the
    /// association: the reference COUNTS them (it doesn't write to disk — the CLI
    /// does), and reads the completed/failed counts from the final C-GET-RSP.
    /// A thrown error or a `.error` stream event is recorded as `success = false`
    /// with zero counts, matching the CLI's non-zero exit with no result block.
    public static func retrieve(host: String, port: UInt16, callingAET: String, calledAET: String,
                                timeout: TimeInterval, method: String, level: String,
                                studyUID: String, seriesUID: String, instanceUID: String,
                                moveDest: String, transferSyntaxName: String) async -> RetrieveSemantics {
        let tsUID: String? = transferSyntaxName.isEmpty ? nil : TransferSyntax.parse(transferSyntaxName)?.uid

        if method == "c-move" {
            do {
                let r: RetrieveResult
                switch level {
                case "instance":
                    r = try await DICOMRetrieveService.moveInstance(
                        host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: studyUID, seriesInstanceUID: seriesUID, sopInstanceUID: instanceUID,
                        moveDestination: moveDest, timeout: timeout)
                case "series":
                    r = try await DICOMRetrieveService.moveSeries(
                        host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: studyUID, seriesInstanceUID: seriesUID,
                        moveDestination: moveDest, timeout: timeout)
                default:
                    r = try await DICOMRetrieveService.moveStudy(
                        host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: studyUID, moveDestination: moveDest, timeout: timeout)
                }
                return RetrieveSemantics(method: "c-move", level: level, success: r.isSuccess,
                                         completed: r.progress.completed, failed: r.progress.failed,
                                         warning: r.progress.warning, filesReceived: 0)
            } catch {
                return RetrieveSemantics(method: "c-move", level: level, success: false,
                                         completed: 0, failed: 0, warning: 0, filesReceived: 0)
            }
        }

        // C-GET
        do {
            let stream: AsyncStream<DICOMRetrieveService.GetEvent>
            switch level {
            case "instance":
                stream = try await DICOMRetrieveService.getInstance(
                    host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                    studyInstanceUID: studyUID, seriesInstanceUID: seriesUID, sopInstanceUID: instanceUID,
                    preferredTransferSyntaxUID: tsUID, timeout: timeout)
            case "series":
                stream = try await DICOMRetrieveService.getSeries(
                    host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                    studyInstanceUID: studyUID, seriesInstanceUID: seriesUID,
                    preferredTransferSyntaxUID: tsUID, timeout: timeout)
            default:
                stream = try await DICOMRetrieveService.getStudy(
                    host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                    studyInstanceUID: studyUID, preferredTransferSyntaxUID: tsUID, timeout: timeout)
            }
            var files = 0, completed = 0, failed = 0
            var success = false, sawCompleted = false
            for await event in stream {
                switch event {
                case .instance:           files += 1
                case .progress:           break
                case .completed(let r):   completed = r.progress.completed; failed = r.progress.failed
                                          success = r.isSuccess; sawCompleted = true
                case .error:              success = false
                }
            }
            // The CLI prints "Files received: N" ONLY inside its C-GET `.completed`
            // block (and throws on a mid-transfer `.error` before reaching it), so it
            // can never report a received-file count on an aborted transfer. Mirror
            // that: surface the count only when `.completed` was seen, otherwise 0 —
            // so an abort after partial instances isn't a false drift (the CLI parses 0).
            return RetrieveSemantics(method: "c-get", level: level, success: sawCompleted && success,
                                     completed: completed, failed: failed, warning: 0,
                                     filesReceived: sawCompleted ? files : 0)
        } catch {
            return RetrieveSemantics(method: "c-get", level: level, success: false,
                                     completed: 0, failed: 0, warning: 0, filesReceived: 0)
        }
    }

    // MARK: dicom-qr (C-FIND review) — read-only

    /// Runs the dicom-qr `--review` C-FIND against the live PACS. dicom-qr builds its
    /// OWN study-level QueryKeys (it does not call DICOMQueryService.buildQueryKeys),
    /// so `qrQueryKeys` replicates that key-building EXACTLY — same study-level return
    /// keys and the same matching keys, including dicom-qr's patient-name uppercasing —
    /// so the matched study set lines up with the CLI's.
    public static func qrReview(host: String, port: UInt16, callingAET: String, calledAET: String,
                                timeout: TimeInterval, filters: QueryFilters) async -> QRSemantics {
        do {
            let config = QueryConfiguration(
                callingAETitle: try AETitle(callingAET),
                calledAETitle: try AETitle(calledAET),
                timeout: timeout,
                informationModel: .studyRoot)
            let results = try await DICOMQueryService.find(
                host: host, port: port, configuration: config, queryKeys: qrQueryKeys(filters: filters))
            let uids = results.compactMap { $0.uid(for: .studyInstanceUID) }
            return CLIParityQRComparator.record(success: true, count: results.count, uids: uids)
        } catch {
            return CLIParityQRComparator.record(success: false, count: 0, uids: [])
        }
    }

    /// Replicates dicom-qr's `buildQueryKeys` exactly (study level): the same fixed
    /// set of return keys, then a matching key per supplied filter, with the patient
    /// name uppercased the way dicom-qr does.
    static func qrQueryKeys(filters f: QueryFilters) -> QueryKeys {
        var keys = QueryKeys(level: .study)
            .requestStudyInstanceUID()
            .requestPatientName()
            .requestPatientID()
            .requestStudyDate()
            .requestStudyDescription()
            .requestAccessionNumber()
            .requestModalitiesInStudy()
            .requestNumberOfStudyRelatedSeries()
            .requestNumberOfStudyRelatedInstances()
        if !f.patientName.isEmpty       { keys = keys.patientName(f.patientName.uppercased()) }
        if !f.patientID.isEmpty         { keys = keys.patientID(f.patientID) }
        if !f.studyDate.isEmpty         { keys = keys.studyDate(f.studyDate) }
        if !f.studyUID.isEmpty          { keys = keys.studyInstanceUID(f.studyUID) }
        if !f.accession.isEmpty         { keys = keys.accessionNumber(f.accession) }
        if !f.modality.isEmpty          { keys = keys.modalitiesInStudy(f.modality) }
        if !f.studyDescription.isEmpty  { keys = keys.studyDescription(f.studyDescription) }
        return keys
    }

    /// Replicates dicom-qr's INTERACTIVE retrieve (the harness auto-answers "all", so
    /// every matched study is retrieved). It queries with the IDENTICAL keys, then —
    /// mirroring the CLI's per-study loop EXACTLY — retrieves each matched study and
    /// tallies the same Total / Success / Failed the CLI prints in its Retrieval Summary:
    ///   • a result lacking a Study UID is a failure (the CLI prints "⚠️ Missing Study UID");
    ///   • C-MOVE / C-GET count as success unless the operation THROWS — dicom-qr's
    ///     `retrieveStudy` discards the C-MOVE result and only fails on a thrown error,
    ///     and its C-GET loop fails only on a `.error` stream event — so warning/partial
    ///     sub-operations still read as "✅ Success" on BOTH sides.
    /// An empty result set returns early with no retrieval block (matching the CLI's
    /// "No studies found …" path), so `retrieval` stays nil and the record equals review's.
    public static func qrInteractive(host: String, port: UInt16, callingAET: String, calledAET: String,
                                     timeout: TimeInterval, filters: QueryFilters,
                                     method: String, moveDest: String) async -> QRSemantics {
        do {
            let config = QueryConfiguration(
                callingAETitle: try AETitle(callingAET),
                calledAETitle: try AETitle(calledAET),
                timeout: timeout,
                informationModel: .studyRoot)
            let results = try await DICOMQueryService.find(
                host: host, port: port, configuration: config, queryKeys: qrQueryKeys(filters: filters))
            let uids = results.compactMap { $0.uid(for: .studyInstanceUID) }
            if results.isEmpty {
                return CLIParityQRComparator.record(success: true, count: 0, uids: [])
            }
            // Select "all" → retrieve every matched study, one association each.
            var succeeded = 0, failed = 0
            for result in results {
                // Honor cancellation (e.g. the raceDeadline backstop firing on a half-dead
                // PACS) so the abandoned op winds down promptly instead of marching through
                // every remaining study. The returned record is discarded once raceDeadline
                // has already yielded its fallback, so a partial tally here is immaterial.
                if Task.isCancelled { break }
                guard let studyUID = result.uid(for: .studyInstanceUID) else { failed += 1; continue }
                do {
                    if method == "c-move" {
                        _ = try await DICOMRetrieveService.moveStudy(
                            host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                            studyInstanceUID: studyUID, moveDestination: moveDest, timeout: timeout)
                    } else {
                        let stream = try await DICOMRetrieveService.getStudy(
                            host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                            studyInstanceUID: studyUID, preferredTransferSyntaxUID: nil, timeout: timeout)
                        for await event in stream {
                            if case .error(let e) = event { throw e }
                        }
                    }
                    succeeded += 1
                } catch {
                    failed += 1
                }
            }
            return CLIParityQRComparator.record(
                success: true, count: results.count, uids: uids,
                retrieval: QRRetrieval(total: results.count, success: succeeded, failed: failed))
        } catch {
            return CLIParityQRComparator.record(success: false, count: 0, uids: [])
        }
    }

    // MARK: dicom-mwl (Modality Worklist C-FIND) — read-only

    /// Runs the worklist C-FIND against the live SCP using
    /// DICOMModalityWorklistService.find — the same package API dicom-mwl calls —
    /// building the IDENTICAL query keys: `WorklistQueryKeys.default()` then the same
    /// filter chain (with the same `today`/`tomorrow` date resolution), so the matched
    /// item set lines up with the CLI's. Each item is reduced to its stable identity
    /// triple (Study UID + SPS ID + Accession).
    public static func worklist(host: String, port: UInt16, callingAET: String, calledAET: String,
                                timeout: TimeInterval, filters: WorklistFilters) async -> MWLSemantics {
        // Build keys via the SHARED package builder — the same mapping the dicom-mwl CLI
        // and DICOMStudio's in-app query use. Mirror the CLI: an unparseable date makes
        // dicom-mwl exit nonzero, so surface that as a failed reference (the builder
        // throws WorklistDateFilterError) and the two agree on the failure path.
        let keys: WorklistQueryKeys
        do {
            keys = try WorklistQueryKeys.forQuery(
                date: filters.date, station: filters.station,
                patientName: filters.patientName, patientID: filters.patientID,
                modality: filters.modality, spsStatus: filters.spsStatus,
                accession: filters.accession)
        } catch {
            return CLIParityMWLComparator.record(success: false, count: 0, keys: [])
        }

        do {
            let items = try await DICOMModalityWorklistService.find(
                host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                matching: keys, timeout: timeout)
            let itemKeys = items.map {
                CLIParityMWLComparator.key(studyUID: $0.studyInstanceUID,
                                           spsID: $0.scheduledProcedureStepID,
                                           accession: $0.accessionNumber)
            }
            return CLIParityMWLComparator.record(success: true, count: items.count, keys: itemKeys)
        } catch {
            return CLIParityMWLComparator.record(success: false, count: 0, keys: [])
        }
    }

    // MARK: dicom-mpps (Modality Performed Procedure Step) — WRITES to the PACS

    /// Drives the FULL MPPS lifecycle against the live server using
    /// DICOMMPPSService.create (N-CREATE) and, for a lifecycle scenario,
    /// DICOMMPPSService.update (N-SET) — the same package API dicom-mpps calls. The
    /// minted SOP Instance UID is internal to this call (never compared); the record
    /// captures only the outcome: create/update success, the final status, and the
    /// referenced-image count. `referencedSOPs` is built the way the CLI's `update`
    /// does — only when both a Series UID and image UID(s) are supplied.
    public static func mpps(host: String, port: UInt16, callingAET: String, calledAET: String,
                            timeout: TimeInterval, scope: MPPSScope,
                            lifecycle: Bool, finalStatus: String) async -> MPPSSemantics {
        func opt(_ s: String) -> String? { s.isEmpty ? nil : s }
        let refs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] =
            (!scope.seriesUID.isEmpty && !scope.imageUIDs.isEmpty)
            ? scope.imageUIDs.map { (scope.studyUID, scope.seriesUID, $0) }
            : []

        let createStatus = "IN PROGRESS"
        do {
            let uid = try await DICOMMPPSService.create(
                host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                studyInstanceUID: scope.studyUID, status: .inProgress, timeout: timeout,
                patientName: opt(scope.patientName), patientID: opt(scope.patientID),
                accessionNumber: opt(scope.accession), scheduledProcedureStepID: opt(scope.spsID))

            guard lifecycle else {
                return CLIParityMPPSComparator.record(lifecycle: false, createOK: true, updateOK: nil,
                                                      finalStatus: createStatus, referencedImages: 0)
            }
            let status: DICOMNetwork.MPPSStatus = finalStatus == "DISCONTINUED" ? .discontinued : .completed
            do {
                try await DICOMMPPSService.update(
                    host: host, port: port, callingAE: callingAET, calledAE: calledAET,
                    mppsInstanceUID: uid, status: status, referencedSOPs: refs, timeout: timeout)
                return CLIParityMPPSComparator.record(lifecycle: true, createOK: true, updateOK: true,
                                                      finalStatus: finalStatus, referencedImages: refs.count)
            } catch {
                return CLIParityMPPSComparator.record(lifecycle: true, createOK: true, updateOK: false,
                                                      finalStatus: finalStatus, referencedImages: refs.count)
            }
        } catch {
            return CLIParityMPPSComparator.record(
                lifecycle: lifecycle, createOK: false, updateOK: lifecycle ? false : nil,
                finalStatus: lifecycle ? finalStatus : createStatus, referencedImages: 0)
        }
    }

    // MARK: dicom-wado (DICOMweb: QIDO-RS / WADO-RS / STOW-RS / UPS-RS)

    /// Builds the DICOMweb client configuration from the base URL (+ optional bearer
    /// token) EXACTLY as the dicom-wado CLI does — via `DICOMwebConfiguration(
    /// baseURLString:authentication:)`, which carries the SDK's default timeouts (the
    /// CLI's per-subcommand `--timeout` flag is not threaded into the config, so the
    /// reference must not apply one either, or the two would diverge on slow servers).
    static func webConfig(baseURL: String, token: String) throws -> DICOMwebConfiguration {
        try DICOMwebConfiguration(
            baseURLString: baseURL,
            authentication: token.isEmpty ? nil : .bearer(token: token))
    }

    /// Runs the QIDO-RS search against the live DICOMweb server using DICOMwebClient —
    /// the same package API `dicom-wado query` calls — building the IDENTICAL QIDOQuery
    /// (same default limit of 100, same filter chain) so the matched set lines up. Each
    /// result is reduced to the SAME JSON object the CLI's `--format json` emits, then
    /// fed through the shared parser so the two records compare equal iff the sets match.
    public static func wadoQuery(baseURL: String, token: String, level: String,
                                 filters: QueryFilters, limit: Int = 100, offset: Int = 0) async -> WADOQuerySemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            var q = QIDOQuery().limit(limit).offset(offset)
            if !filters.patientName.isEmpty      { q = q.patientName(filters.patientName) }
            if !filters.patientID.isEmpty        { q = q.patientID(filters.patientID) }
            if !filters.studyDate.isEmpty        { q = q.studyDate(filters.studyDate) }
            if !filters.studyUID.isEmpty         { q = q.studyInstanceUID(filters.studyUID) }
            if !filters.seriesUID.isEmpty        { q = q.seriesInstanceUID(filters.seriesUID) }
            if !filters.accession.isEmpty        { q = q.accessionNumber(filters.accession) }
            if !filters.modality.isEmpty {
                // Match the level-aware key the app (CLIWorkshopViewModel.executeDicomQIDO)
                // and the dicom-wado CLI use (PS3.18 §10.6):
                //   • series level           → Modality (0008,0060)
                //   • study / instance level → Modalities in Study (0008,0061)
                // Sending Modality (0008,0060) at study level is not a valid study
                // matching key, so the server ignores it and returns ALL studies —
                // which made this reference (count 100, unfiltered) drift from the
                // correctly-filtered CLI.
                if level == "series" {
                    q = q.modality(filters.modality)
                } else {
                    q = q.modalitiesInStudy(filters.modality)
                }
            }
            if !filters.studyDescription.isEmpty { q = q.studyDescription(filters.studyDescription) }

            let json: String
            switch level {
            case "series":
                let r = filters.studyUID.isEmpty
                    ? try await client.searchAllSeries(query: q)
                    : try await client.searchSeries(studyUID: filters.studyUID, query: q)
                json = seriesResultsJSON(r.results)
            case "instance":
                let r: QIDOInstanceResults
                if !filters.studyUID.isEmpty, !filters.seriesUID.isEmpty {
                    r = try await client.searchInstances(studyUID: filters.studyUID, seriesUID: filters.seriesUID, query: q)
                } else if !filters.studyUID.isEmpty {
                    r = try await client.searchInstances(studyUID: filters.studyUID, query: q)
                } else {
                    r = try await client.searchAllInstances(query: q)
                }
                json = instanceResultsJSON(r.results)
            default:
                let r = try await client.searchStudies(query: q)
                json = studyResultsJSON(r.results)
            }
            return CLIParityWADOComparator.parseQuery(json, level: level, success: true)
        } catch {
            return CLIParityWADOComparator.querySemantics(level: level, success: false, objects: [])
        }
    }

    /// Runs the WADO-RS retrieve against the live server using DICOMwebClient — the
    /// same package API `dicom-wado retrieve` calls. The reference COUNTS what it pulls
    /// (instances in memory, or metadata objects) without writing to disk; the runner
    /// compares that against the file count the CLI wrote to its `--output` dir (for
    /// instances) or the JSON-array length it printed (for `--metadata`).
    public static func wadoRetrieve(baseURL: String, token: String, level: String,
                                    studyUID: String, seriesUID: String, instanceUID: String,
                                    metadata: Bool) async -> WADORetrieveSemantics {
        let mode = metadata ? "metadata" : "instances"
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let count: Int
            if metadata {
                switch level {
                case "instance": count = try await client.retrieveInstanceMetadata(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID).count
                case "series":   count = try await client.retrieveSeriesMetadata(studyUID: studyUID, seriesUID: seriesUID).count
                default:         count = try await client.retrieveStudyMetadata(studyUID: studyUID).count
                }
            } else {
                switch level {
                case "instance":
                    _ = try await client.retrieveInstance(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
                    count = 1
                case "series":
                    count = try await client.retrieveSeries(studyUID: studyUID, seriesUID: seriesUID).instances.count
                default:
                    count = try await client.retrieveStudy(studyUID: studyUID).instances.count
                }
            }
            return CLIParityWADOComparator.retrieveRecord(level: level, mode: mode, success: true, count: count)
        } catch {
            return CLIParityWADOComparator.retrieveRecord(level: level, mode: mode, success: false, count: 0)
        }
    }

    /// Runs the WADO-URI (legacy, PS3.18 §8) single-instance retrieve against the live
    /// server using WADOURIClient — the same package API `dicom-wado retrieve --uri`
    /// calls. Returns success + the retrieved BYTE count: both sides issue the IDENTICAL
    /// request (same study/series/instance + content type) to the SAME URL, so the byte
    /// count is deterministic. A server that doesn't speak WADO-URI at this URL throws on
    /// BOTH sides identically (success=false, count=0), so the row stays at parity rather
    /// than false-DIFFERing — exactly like the WADO-RS instance count.
    public static func wadoRetrieveURI(baseURL: String, token: String,
                                       studyUID: String, seriesUID: String, instanceUID: String,
                                       contentType: String) async -> WADORetrieveSemantics {
        do {
            let client = WADOURIClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let result = try await client.retrieve(
                studyUID: studyUID, seriesUID: seriesUID, objectUID: instanceUID,
                contentType: uriContentType(contentType))
            return CLIParityWADOComparator.retrieveRecord(level: "instance", mode: "uri", success: true, count: result.data.count)
        } catch {
            return CLIParityWADOComparator.retrieveRecord(level: "instance", mode: "uri", success: false, count: 0)
        }
    }

    /// Runs a WADO-RS DERIVED retrieve (rendered image / thumbnail / frames) against the
    /// live server using DICOMwebClient — the same package API `dicom-wado retrieve
    /// --rendered | --thumbnail | --frames` calls (with the SAME default render options).
    /// These return transcoded/raw bytes that aren't byte-stable to compare, so parity is
    /// on success + the COUNT of produced outputs (1 image for rendered/thumbnail; one per
    /// requested frame): the CLI writes that many files to its `--output` dir (counted on
    /// disk by the runner), the reference counts what it pulled in memory. A server that
    /// doesn't support rendering/frames throws on BOTH sides identically (success=false,
    /// count=0), so the row stays at parity.
    public static func wadoRetrieveDerived(baseURL: String, token: String, kind: String, level: String,
                                           studyUID: String, seriesUID: String, instanceUID: String,
                                           frames: [Int]) async -> WADORetrieveSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let count: Int
            switch kind {
            case "rendered":
                _ = try await client.retrieveRenderedInstance(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
                count = 1
            case "thumbnail":
                switch level {
                case "instance": _ = try await client.retrieveInstanceThumbnail(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
                case "series":   _ = try await client.retrieveSeriesThumbnail(studyUID: studyUID, seriesUID: seriesUID)
                default:         _ = try await client.retrieveStudyThumbnail(studyUID: studyUID)
                }
                count = 1
            case "frames":
                let f = try await client.retrieveFrames(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID, frames: frames)
                count = f.count
            default:
                count = 0
            }
            return CLIParityWADOComparator.retrieveRecord(level: level, mode: kind, success: true, count: count)
        } catch {
            return CLIParityWADOComparator.retrieveRecord(level: level, mode: kind, success: false, count: 0)
        }
    }

    /// Runs the UPS-RS create → get round-trip against the live server using
    /// DICOMwebClient.createWorkitem (N-CREATE, SCHEDULED) then .retrieveWorkitem — the
    /// same package API `dicom-wado ups --create-workitem` and `ups --get <uid>` call.
    /// The Workitem UID is minted client-side and differs from the CLI's by design, so it
    /// is NEVER compared — each side gets back its OWN just-created workitem. Parity is on
    /// the outcome (createOK, getOK).
    public static func wadoUPSGet(baseURL: String, token: String, scope: WADOScope) async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let builder = WorkitemBuilder(workitemUID: mintUID())
                .setState(.scheduled)
                .setProcedureStepLabel(scope.upsLabel)
            if !scope.upsPatientName.isEmpty { builder.setPatientName(scope.upsPatientName) }
            if !scope.upsPatientID.isEmpty   { builder.setPatientID(scope.upsPatientID) }
            let workitem = try builder.build()
            do {
                let created = try await client.createWorkitem(workitem)
                do {
                    _ = try await client.retrieveWorkitem(uid: created.workitemUID)
                    return CLIParityWADOComparator.getRecord(createOK: true, getOK: true)
                } catch {
                    return CLIParityWADOComparator.getRecord(createOK: true, getOK: false)
                }
            } catch {
                return CLIParityWADOComparator.getRecord(createOK: false, getOK: false)
            }
        } catch {
            return CLIParityWADOComparator.getRecord(createOK: false, getOK: false)
        }
    }

    /// Builds a UPS workitem from the FULL command-line attribute set (the create-workitem
    /// attribute sweep) and N-CREATEs it — mirroring the CLI's createWorkitemFromOptions
    /// glue EXACTLY (same WorkitemBuilder setters, same priority/date/station/performer
    /// mapping), via the SAME package API. The workitem UID is client-minted, so it's never
    /// compared — parity is on whether the rich create succeeded (createOK). `attrs` is keyed
    /// by the CLI flag names (minus `--`): priority, patient-birth-date, patient-sex,
    /// study-uid, accession-number, referring-physician, procedure-id, step-id,
    /// worklist-label, comments, scheduled-start, expected-completion, station-name,
    /// performer-name, performer-organization, admission-id.
    public static func wadoUPSCreate(baseURL: String, token: String, label: String,
                                     patientName: String, patientID: String,
                                     attrs: [String: String]) async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let builder = WorkitemBuilder(workitemUID: mintUID())
                .setState(.scheduled)
                .setProcedureStepLabel(label)
            if !patientName.isEmpty { builder.setPatientName(patientName) }
            if !patientID.isEmpty   { builder.setPatientID(patientID) }
            func a(_ k: String) -> String? { let v = attrs[k]; return (v?.isEmpty == false) ? v : nil }
            // INVALID-INPUT PARITY: the CLI's createWorkitemFromOptions THROWS on an invalid
            // priority / patient-sex / date (ValidationError → non-zero exit → create fails),
            // so the reference must FAIL too — not silently skip the bad attribute. Each guard
            // below returns the failure record so both sides report createOK=false identically
            // for a bad value (the harness only feeds valid values today, but this keeps the
            // reference a faithful mirror for ANY input). Inlined (not a typed helper) so the
            // priority case resolves from setPriority's parameter type — the DICOMWeb module
            // name is shadowed by a same-named type, so it can't be written as a qualifier.
            if let v = a("priority") {
                switch v.uppercased() {
                case "STAT":   builder.setPriority(.stat)
                case "HIGH":   builder.setPriority(.high)
                case "MEDIUM": builder.setPriority(.medium)
                case "LOW":    builder.setPriority(.low)
                default:       return CLIParityWADOComparator.createRecord(createOK: false)  // CLI throws
                }
            }
            if let v = a("patient-birth-date") { builder.setPatientBirthDate(v) }
            if let v = a("patient-sex") {
                let s = v.uppercased()
                guard ["M", "F", "O"].contains(s) else { return CLIParityWADOComparator.createRecord(createOK: false) }  // CLI throws
                builder.setPatientSex(s)
            }
            if let v = a("study-uid")          { builder.setStudyInstanceUID(v) }
            if let v = a("accession-number")   { builder.setAccessionNumber(v) }
            if let v = a("referring-physician"){ builder.setReferringPhysicianName(v) }
            if let v = a("procedure-id")       { builder.setRequestedProcedureID(v) }
            if let v = a("step-id")            { builder.setScheduledProcedureStepID(v) }
            if let v = a("worklist-label")     { builder.setWorklistLabel(v) }
            if let v = a("comments")           { builder.setComments(v) }
            if let v = a("scheduled-start") {
                guard let d = parseUPSDate(v) else { return CLIParityWADOComparator.createRecord(createOK: false) }  // CLI throws
                builder.setScheduledStartDateTime(d)
            }
            if let v = a("expected-completion") {
                guard let d = parseUPSDate(v) else { return CLIParityWADOComparator.createRecord(createOK: false) }  // CLI throws
                builder.setExpectedCompletionDateTime(d)
            }
            if let v = a("station-name") {
                builder.setScheduledStationNameCodes([CodedEntry(codeValue: v, codingSchemeDesignator: "L", codeMeaning: v)])
            }
            let pName = a("performer-name"); let pOrg = a("performer-organization")
            if pName != nil || pOrg != nil {
                builder.addScheduledHumanPerformer(HumanPerformer(performerName: pName, performerOrganization: pOrg))
            }
            if let v = a("admission-id")       { builder.setAdmissionID(v) }
            let workitem = try builder.build()
            do {
                _ = try await client.createWorkitem(workitem)
                return CLIParityWADOComparator.createRecord(createOK: true)
            } catch {
                return CLIParityWADOComparator.createRecord(createOK: false)
            }
        } catch {
            return CLIParityWADOComparator.createRecord(createOK: false)
        }
    }

    /// N-CREATEs a workitem (own minted UID), then subscribes to and unsubscribes from its
    /// events — the same package API `ups --subscribe`/`--unsubscribe` call. The AE title
    /// is harness-picked and the UID is client-minted, so neither is compared — parity is on
    /// the outcome (createOK + the subscribe/unsubscribe round-trip). Many servers don't
    /// enable UPS subscription, in which case BOTH sides fail the round-trip identically.
    public static func wadoUPSSubscribe(baseURL: String, token: String,
                                        label: String, aeTitle: String) async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let builder = WorkitemBuilder(workitemUID: mintUID()).setState(.scheduled).setProcedureStepLabel(label)
            let workitem = try builder.build()
            let created: UPSCreateResponse
            do {
                created = try await client.createWorkitem(workitem)
            } catch {
                return CLIParityWADOComparator.subscribeRecord(createOK: false, roundTripOK: false)
            }
            do {
                try await client.subscribeToWorkitem(workitemUID: created.workitemUID, aeTitle: aeTitle)
                try await client.unsubscribeFromWorkitem(workitemUID: created.workitemUID, aeTitle: aeTitle)
                return CLIParityWADOComparator.subscribeRecord(createOK: true, roundTripOK: true)
            } catch {
                return CLIParityWADOComparator.subscribeRecord(createOK: true, roundTripOK: false)
            }
        } catch {
            return CLIParityWADOComparator.subscribeRecord(createOK: false, roundTripOK: false)
        }
    }

    /// GLOBAL UPS subscription round-trip — the `ups --subscribe --aet <ae>` (no --workitem-uid)
    /// path: subscribe to ALL workitems' events, then unsubscribe. No workitem is created, so
    /// createOK is reported vacuously true and parity is on the round-trip outcome (matching the
    /// CLI runner). Uses the SAME shared client calls the CLI's subscribe/unsubscribe go through.
    public static func wadoUPSSubscribeGlobal(baseURL: String, token: String, aeTitle: String) async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            do {
                try await client.subscribeToAllWorkitems(aeTitle: aeTitle)
                try await client.unsubscribeFromWorkitem(workitemUID: nil, aeTitle: aeTitle)
                return CLIParityWADOComparator.subscribeRecord(createOK: true, roundTripOK: true)
            } catch {
                return CLIParityWADOComparator.subscribeRecord(createOK: true, roundTripOK: false)
            }
        } catch {
            return CLIParityWADOComparator.subscribeRecord(createOK: false, roundTripOK: false)
        }
    }

    /// N-CREATEs a workitem from a DICOM-JSON dict — the SAME path `ups --create <jsonfile>`
    /// uses (client.createWorkitem(workitem: [String:Any])). The reference mints its OWN UID
    /// (distinct from the JSON file the CLI reads, so the two creates don't collide), builds
    /// the same label/patient workitem, serialises it via Workitem.toDICOMJSONForCreate(),
    /// and creates from that dict. Parity is on createOK.
    public static func wadoUPSCreateFromJSON(baseURL: String, token: String,
                                             label: String, patientName: String, patientID: String) async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            guard let dict = buildCreateWorkitem(label: label, patientName: patientName, patientID: patientID)?.toDICOMJSONForCreate() else {
                return CLIParityWADOComparator.createRecord(createOK: false)
            }
            do {
                _ = try await client.createWorkitem(workitem: dict)
                return CLIParityWADOComparator.createRecord(createOK: true)
            } catch {
                return CLIParityWADOComparator.createRecord(createOK: false)
            }
        } catch {
            return CLIParityWADOComparator.createRecord(createOK: false)
        }
    }

    /// The DICOM-JSON string the CLI's `--create <jsonfile>` reads — a minimal SCHEDULED
    /// workitem (own minted UID, label + patient) serialised via Workitem.toDICOMJSONForCreate().
    /// The minted UID here is DISTINCT from the reference's (wadoUPSCreateFromJSON), so the two
    /// creates target different workitems and never conflict. Returns "" on a build failure.
    public static func upsCreateWorkitemJSON(label: String, patientName: String, patientID: String) -> String {
        guard let workitem = buildCreateWorkitem(label: label, patientName: patientName, patientID: patientID) else { return "" }
        let dict = workitem.toDICOMJSONForCreate()
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "" }
        return str
    }

    /// Builds the minimal SCHEDULED workitem shared by the JSON-create reference + file.
    static func buildCreateWorkitem(label: String, patientName: String, patientID: String) -> Workitem? {
        let builder = WorkitemBuilder(workitemUID: mintUID()).setState(.scheduled).setProcedureStepLabel(label)
        if !patientName.isEmpty { builder.setPatientName(patientName) }
        if !patientID.isEmpty   { builder.setPatientID(patientID) }
        return try? builder.build()
    }

    /// Mirrors the dicom-wado CLI's parseISO8601Date (same formatters, same order) so a
    /// scheduled date string parses to the IDENTICAL Date on both sides.
    static func parseUPSDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: value) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: value) { return d }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            fallback.dateFormat = fmt
            if let d = fallback.date(from: value) { return d }
        }
        return nil
    }

    /// Maps a CLI `--content-type` string to a WADOURIClient content type, mirroring the
    /// dicom-wado CLI's mapping EXACTLY so both sides request the identical representation —
    /// it now DELEGATES to the shared `WADOURIClient.ContentType.fromRequestString` factory
    /// that the CLI also calls, so the two can never drift (an unknown/empty value defaults
    /// to application/dicom, like the CLI's `default`).
    static func uriContentType(_ raw: String) -> WADOURIClient.ContentType {
        WADOURIClient.ContentType.fromRequestString(raw)
    }

    /// Stores the given file(s) using DICOMwebClient.storeInstances — the same package
    /// API `dicom-wado store` calls — and returns the upload OUTCOME counts. A file the
    /// reference cannot read is counted as failed (mirroring the CLI's read-error path).
    public static func wadoStore(baseURL: String, token: String, filePaths: [String],
                                 studyUID: String? = nil) async -> WADOStoreSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            var instances: [Data] = []
            var failedReads = 0
            for p in filePaths {
                if let d = try? Data(contentsOf: URL(fileURLWithPath: p)) { instances.append(d) }
                else { failedReads += 1 }
            }
            guard !instances.isEmpty else {
                return WADOStoreSemantics(sent: filePaths.count, succeeded: 0, failed: filePaths.count)
            }
            // studyUID mirrors the CLI's `--study` (targeted STOW-RS): nil → /studies,
            // a value → /studies/{uid}. Both sides pass the SAME value, so the upload
            // OUTCOME counts line up — and an instance whose own StudyInstanceUID doesn't
            // match a targeted study is rejected identically on both sides.
            let resp = try await client.storeInstances(instances: instances, studyUID: studyUID)
            return WADOStoreSemantics(sent: filePaths.count, succeeded: resp.successCount,
                                      failed: resp.failureCount + failedReads)
        } catch {
            return WADOStoreSemantics(sent: filePaths.count, succeeded: 0, failed: filePaths.count)
        }
    }

    /// Runs the UPS-RS worklist search against the live server using
    /// DICOMwebClient.searchWorkitems — the same package API `dicom-wado ups --search`
    /// calls — reducing each matched workitem to its stable Workitem UID (sorted).
    public static func wadoUPSSearch(baseURL: String, token: String, filterState: String = "",
                                     scheduledStation: String = "") async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            // Build the query via the SHARED UPSQuery.workitemSearch builder — the SAME
            // single source of truth the dicom-wado ups CLI and the CLI Workshop's in-app
            // search call, so all three issue an IDENTICAL UPS-RS query and the matched
            // workitem set is comparable. A non-empty invalid --filter-state makes the
            // builder throw (mirroring the CLI's non-zero exit), caught below as a failed
            // search rather than a silently unfiltered query — keeping parity for any input.
            let query = try UPSQuery.workitemSearch(filterState: filterState, scheduledStation: scheduledStation)
            let r = try await client.searchWorkitems(query: query)
            return CLIParityWADOComparator.searchRecord(success: true, count: r.workitems.count,
                                                        uids: r.workitems.map { $0.workitemUID })
        } catch {
            return CLIParityWADOComparator.searchRecord(success: false, count: 0, uids: [])
        }
    }

    /// Drives the UPS-RS create → claim lifecycle against the live server using
    /// DICOMwebClient.createWorkitem (N-CREATE, SCHEDULED) then .changeWorkitemState
    /// (→ IN PROGRESS) — the same package API `dicom-wado ups --create-workitem` and
    /// `--update --state IN_PROGRESS` call. The Workitem UID and the claim's Transaction
    /// UID are minted client-side and differ from the CLI's by design, so they are
    /// NEVER compared — the record captures only the outcome (create / claim success,
    /// final state). When `finalState` is COMPLETED/CANCELED the lifecycle continues past the
    /// claim, REUSING the Transaction UID the IN PROGRESS claim response handed back (the
    /// server's access lock) to authorise the terminal transition — exactly as the CLI reuses
    /// the UID its IN PROGRESS step prints (COMPLETED first sends the required Final State
    /// attributes via the shared client helper — the exact payload the CLI sends).
    public static func wadoUPSLifecycle(baseURL: String, token: String, scope: WADOScope,
                                        finalState: String = "IN_PROGRESS") async -> WADOUPSSemantics {
        do {
            let client = DICOMwebClient(configuration: try webConfig(baseURL: baseURL, token: token))
            let builder = WorkitemBuilder(workitemUID: mintUID())
                .setState(.scheduled)
                .setProcedureStepLabel(scope.upsLabel)
            if !scope.upsPatientName.isEmpty { builder.setPatientName(scope.upsPatientName) }
            if !scope.upsPatientID.isEmpty   { builder.setPatientID(scope.upsPatientID) }
            let workitem = try builder.build()

            let created: UPSCreateResponse
            do {
                created = try await client.createWorkitem(workitem)
            } catch {
                return CLIParityWADOComparator.lifecycleRecord(createOK: false, claimOK: false, finalState: "")
            }

            // Claim the SAME workitem to IN PROGRESS, then REUSE the Transaction UID the claim
            // response hands back (the server's access lock) to authorise the terminal
            // transition — mirroring the CLI, which parses the UID the IN PROGRESS step prints
            // and feeds it back into COMPLETED/CANCELED.
            let claimTxUID = mintUID()
            let requestingAE = scope.upsAET.isEmpty ? nil : scope.upsAET
            let txUID: String
            do {
                let claimResp = try await client.changeWorkitemState(
                    uid: created.workitemUID, state: .inProgress, transactionUID: claimTxUID,
                    requestingAE: requestingAE)
                txUID = claimResp.transactionUID ?? claimTxUID
            } catch {
                // Create succeeded, claim did not → never reached the requested final state.
                return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: false, finalState: "")
            }

            // Claimed (IN PROGRESS). Drive the requested terminal transition, if any.
            switch finalState.uppercased() {
            case "COMPLETED":
                do {
                    // Shared client helper — the same Final State attributes + Change State the CLI sends.
                    _ = try await client.completeWorkitem(
                        uid: created.workitemUID, transactionUID: txUID, requestingAE: requestingAE)
                    return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: true, finalState: "COMPLETED")
                } catch {
                    // Claim held but completion was rejected → final state not reached.
                    return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: true, finalState: "")
                }
            case "CANCELED":
                do {
                    _ = try await client.changeWorkitemState(
                        uid: created.workitemUID, state: .canceled, transactionUID: txUID,
                        requestingAE: requestingAE)
                    return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: true, finalState: "CANCELED")
                } catch {
                    return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: true, finalState: "")
                }
            default: // IN_PROGRESS — the claim is the terminal step.
                return CLIParityWADOComparator.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS")
            }
        } catch {
            // Config invalid or builder.build() threw → nothing created.
            return CLIParityWADOComparator.lifecycleRecord(createOK: false, claimOK: false, finalState: "")
        }
    }

    /// Mints a client-side DICOM UID (never compared — the reference and the CLI each
    /// mint their own Workitem / Transaction UIDs, exactly like dicom-mpps).
    static func mintUID() -> String {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let random = UInt32.random(in: 1...999_999)
        return "1.2.826.0.1.3680043.8.498.\(timestamp).\(random)"
    }

    // The three QIDO-RS result→JSON builders replicate the dicom-wado CLI's
    // `--format json` dict construction EXACTLY (same keys, same value types), so the
    // reference's JSON is byte-comparable (after re-parsing) with the CLI's stdout.

    static func studyResultsJSON(_ studies: [QIDOStudyResult]) -> String {
        let dicts: [[String: Any]] = studies.map { study in
            var dict: [String: Any] = [:]
            if let v = study.studyInstanceUID { dict["StudyInstanceUID"] = v }
            if let v = study.patientName { dict["PatientName"] = v }
            if let v = study.patientID { dict["PatientID"] = v }
            if let v = study.studyDate { dict["StudyDate"] = v }
            if let v = study.studyTime { dict["StudyTime"] = v }
            if let v = study.studyDescription { dict["StudyDescription"] = v }
            if let v = study.accessionNumber { dict["AccessionNumber"] = v }
            if let v = study.studyID { dict["StudyID"] = v }
            if let v = study.referringPhysicianName { dict["ReferringPhysicianName"] = v }
            if let v = study.numberOfStudyRelatedSeries { dict["NumberOfStudyRelatedSeries"] = v }
            if let v = study.numberOfStudyRelatedInstances { dict["NumberOfStudyRelatedInstances"] = v }
            if !study.modalitiesInStudy.isEmpty { dict["ModalitiesInStudy"] = study.modalitiesInStudy }
            if let v = study.patientBirthDate { dict["PatientBirthDate"] = v }
            if let v = study.patientSex { dict["PatientSex"] = v }
            return dict
        }
        return jsonString(dicts)
    }

    static func seriesResultsJSON(_ series: [QIDOSeriesResult]) -> String {
        let dicts: [[String: Any]] = series.map { s in
            var dict: [String: Any] = [:]
            if let v = s.seriesInstanceUID { dict["SeriesInstanceUID"] = v }
            if let v = s.studyInstanceUID { dict["StudyInstanceUID"] = v }
            if let v = s.modality { dict["Modality"] = v }
            if let v = s.seriesNumber { dict["SeriesNumber"] = v }
            if let v = s.seriesDescription { dict["SeriesDescription"] = v }
            if let v = s.bodyPartExamined { dict["BodyPartExamined"] = v }
            if let v = s.performedProcedureStepStartDate { dict["PerformedProcedureStepStartDate"] = v }
            if let v = s.numberOfSeriesRelatedInstances { dict["NumberOfSeriesRelatedInstances"] = v }
            return dict
        }
        return jsonString(dicts)
    }

    static func instanceResultsJSON(_ instances: [QIDOInstanceResult]) -> String {
        let dicts: [[String: Any]] = instances.map { instance in
            var dict: [String: Any] = [:]
            if let v = instance.sopInstanceUID { dict["SOPInstanceUID"] = v }
            if let v = instance.sopClassUID { dict["SOPClassUID"] = v }
            if let v = instance.instanceNumber { dict["InstanceNumber"] = v }
            if let v = instance.numberOfFrames { dict["NumberOfFrames"] = v }
            if let v = instance.rows { dict["Rows"] = v }
            if let v = instance.columns { dict["Columns"] = v }
            if let v = instance.seriesInstanceUID { dict["SeriesInstanceUID"] = v }
            if let v = instance.studyInstanceUID { dict["StudyInstanceUID"] = v }
            return dict
        }
        return jsonString(dicts)
    }

    static func jsonString(_ data: [[String: Any]]) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: jsonData, encoding: .utf8) else { return "[]" }
        return s
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

    /// A human-readable rendering of the retrieve record for the row's "reference" pane.
    public static func renderRetrieve(_ s: RetrieveSemantics) -> String {
        let api = s.method == "c-get" ? "DICOMRetrieveService.get*" : "DICOMRetrieveService.move*"
        return "DICOMKit package API reference (\(api)):\n"
            + CLIParityRetrieveComparator.canonical(s).joined(separator: "\n")
    }

    /// A human-readable rendering of the qr record for the row's "reference" pane. An
    /// interactive run (carrying a retrieval summary) also drives DICOMRetrieveService.
    public static func renderQR(_ s: QRSemantics) -> String {
        let api = s.retrieval == nil
            ? "DICOMQueryService.find"
            : "DICOMQueryService.find → DICOMRetrieveService (select all)"
        return "DICOMKit package API reference (dicom-qr → \(api)):\n"
            + CLIParityQRComparator.canonical(s).joined(separator: "\n")
    }

    /// A human-readable rendering of the worklist record for the row's "reference" pane.
    public static func renderWorklist(_ s: MWLSemantics) -> String {
        "DICOMKit package API reference (DICOMModalityWorklistService.find):\n"
            + CLIParityMWLComparator.canonical(s).joined(separator: "\n")
    }

    /// A human-readable rendering of the MPPS lifecycle record for the row's "reference" pane.
    public static func renderMPPS(_ s: MPPSSemantics) -> String {
        let api = s.lifecycle ? "DICOMMPPSService.create → .update" : "DICOMMPPSService.create"
        return "DICOMKit package API reference (\(api)):\n"
            + CLIParityMPPSComparator.canonical(s).joined(separator: "\n")
    }

    /// Human-readable renderings of the dicom-wado (DICOMweb) records for the row's "reference" pane.
    public static func renderWADOQuery(_ s: WADOQuerySemantics) -> String {
        "DICOMKit package API reference (DICOMwebClient QIDO-RS search):\n"
            + CLIParityWADOComparator.queryCanonical(s).joined(separator: "\n")
    }
    public static func renderWADORetrieve(_ s: WADORetrieveSemantics) -> String {
        "DICOMKit package API reference (DICOMwebClient WADO-RS retrieve):\n"
            + CLIParityWADOComparator.retrieveCanonical(s).joined(separator: "\n")
    }
    public static func renderWADOStore(_ s: WADOStoreSemantics) -> String {
        "DICOMKit package API reference (DICOMwebClient STOW-RS store):\n"
            + CLIParityWADOComparator.storeCanonical(s).joined(separator: "\n")
    }
    public static func renderWADOUPS(_ s: WADOUPSSemantics) -> String {
        let api: String
        switch s.operation {
        case "lifecycle": api = "UPS-RS create → claim"
        case "get":       api = "UPS-RS create → get"
        case "create":    api = "UPS-RS create-workitem"
        case "subscribe": api = "UPS-RS create → subscribe → unsubscribe"
        default:          api = "UPS-RS search"
        }
        return "DICOMKit package API reference (DICOMwebClient \(api)):\n"
            + CLIParityWADOComparator.upsCanonical(s).joined(separator: "\n")
    }

    // MARK: Helpers

    /// "0xNNNN" matching DIMSEStatus.description's hex (and the CLI parser).
    static func hex(_ status: DIMSEStatus) -> String {
        String(format: "0x%04X", status.rawValue)
    }
}
