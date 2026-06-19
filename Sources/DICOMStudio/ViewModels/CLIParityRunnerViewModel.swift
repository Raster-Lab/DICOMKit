// CLIParityRunnerViewModel.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Drives the "CLI Parity" screen: a USER-DRIVEN batch parity runner. The user
// selects tool(s) + one input file; for every auto-generated subcommand/flag
// scenario this runs BOTH the app (in-process CLIWorkshopViewModel) AND the real
// `dicom-*` binary (a subprocess via CLIToolTerminalCompare), then scores three
// dimensions (INPUT / PROCESS / OUTPUT) per row and rolls them up into a
// success rate.
//
// Reuses the proven parts wholesale: ToolCatalogHelpers.parameterDefinitions +
// CommandBuilderHelpers.buildCommand (argv), CLIWorkshopViewModel.executeCommand
// (app side), CLIToolTerminalCompare.run (CLI side), and
// CLIParityEngine.normalize/diff/mask + the in-process dicom-info re-dump used by
// the golden harness (the artifact reductions are byte-identical to it).
//
// Like CLIToolTerminalCompare, the live-CLI path requires the App Sandbox to be
// DISABLED and must be removed before production (project memory
// `dicom-info-terminal-compare-testonly`).

import Foundation
import Observation
import DICOMCore

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class CLIParityRunnerViewModel {

    // MARK: Inputs / selection

    /// Whether the screen is sweeping the offline file tools or the network
    /// (DIMSE) tools. Drives which tool pool, controls and runner are used.
    public var mode: ParityMode = .offline

    /// Offline tools this screen can sweep (supported by the generator,
    /// non-network, execute-supported), in catalog order.
    public let availableTools: [CLIToolDefinition]
    /// Network tools that have a parity implementation today (dicom-echo).
    public let availableNetworkTools: [CLIToolDefinition]
    public var selectedToolIDs: Set<String> = []

    // MARK: Network endpoint (editable PACS credentials)

    /// The PACS the network tools echo against. Pre-filled with the team's test
    /// server; every field is user-editable. The CLI requires `--aet`, so the
    /// Calling AE must be non-empty.
    public var networkHost: String = "172.17.1.200"
    public var networkPort: String = "11112"
    public var networkCallingAET: String = "DICOMSTUDIO"
    public var networkCalledAET: String = "TEAMPACS"
    public var networkTimeout: String = "30"

    /// The DICOMweb (HTTP/S) base URL the `dicom-wado` subcommands hit. DICOMweb is a
    /// separate HTTP service from the DIMSE host/port — dcm4chee exposes it under
    /// `/dcm4chee-arc/aets/<AET>/rs`. Pre-filled from the selected server preset; fully
    /// editable. Only used by dicom-wado (the DIMSE tools ignore it).
    public var networkWebBaseURL: String = "http://172.17.1.200:8080/dcm4chee-arc/aets/TEAMPACS/rs"
    /// Optional OAuth2 bearer token for the DICOMweb endpoint (empty == no auth).
    public var networkWebToken: String = ""

    /// A named PACS the user can switch between; selecting one loads its
    /// host/port/called-AE (and DICOMweb base URL) into the (still-editable) endpoint fields.
    public struct PACSServerPreset: Identifiable, Hashable, Sendable {
        public let id: String          // also the display name
        public let host: String
        public let port: String
        public let calledAET: String
        public let webBaseURL: String  // dicom-wado DICOMweb endpoint for this server
    }

    public static let serverPresets: [PACSServerPreset] = [
        .init(id: "DCM4CHEE2", host: "172.17.1.200", port: "11112", calledAET: "TEAMPACS",
              webBaseURL: "http://172.17.1.200:8080/dcm4chee-arc/aets/TEAMPACS/rs"),
        .init(id: "DCM4CHEE5", host: "172.17.1.111", port: "11112", calledAET: "DCM4CHEE",
              webBaseURL: "http://172.17.1.111:8080/dcm4chee-arc/aets/DCM4CHEE/rs"),
        .init(id: "DCM4CHEE5 MWL", host: "172.17.1.111", port: "11112", calledAET: "WORKLIST",
              webBaseURL: "http://172.17.1.111:8080/dcm4chee-arc/aets/WORKLIST/rs"),
    ]

    /// The currently-selected server preset id (DCM4CHEE2 by default → TEAMPACS).
    public var selectedServerID: String = "DCM4CHEE2"

    /// Network tools pinned to a SINGLE server preset. dicom-mpps writes performed
    /// procedure-step state (N-CREATE) and transitions it (N-SET) — in this deployment
    /// only the DCM4CHEE5 worklist AE (WORKLIST) accepts and advances MPPS, so the tool
    /// is locked to the "DCM4CHEE5 MWL" preset. Selecting it forces that endpoint and
    /// disables the server picker; the run() guard rejects any other server.
    private static let toolRequiredServer: [String: String] = ["dicom-mpps": "DCM4CHEE5 MWL"]

    /// The server preset a tool is pinned to, if any (else nil).
    public func requiredServer(for toolId: String) -> String? { Self.toolRequiredServer[toolId] }

    /// When the current network selection includes a server-pinned tool (dicom-mpps),
    /// the preset id the endpoint is locked to; nil when nothing pins the server. While
    /// non-nil the picker is disabled and `selectServer` refuses other presets.
    public var lockedServerID: String? {
        guard mode == .network else { return nil }
        for id in selectedToolIDs { if let required = Self.toolRequiredServer[id] { return required } }
        return nil
    }

    /// Loads a preset's host/port/called-AE (and DICOMweb base URL) into the endpoint
    /// fields. The calling AE (local SCU identity) and timeout are left as-is. A
    /// server-pinned tool (dicom-mpps) locks the picker — switching to any other preset
    /// is ignored while such a tool is selected.
    public func selectServer(_ id: String) {
        guard !isRunning else { return }
        if let locked = lockedServerID, id != locked { return }
        applyServer(id)
    }

    /// Applies a preset's endpoint fields unconditionally (no lock check — the callers
    /// that force a pinned server use this directly).
    private func applyServer(_ id: String) {
        guard let p = Self.serverPresets.first(where: { $0.id == id }) else { return }
        selectedServerID = id
        networkHost = p.host
        networkPort = p.port
        networkCalledAET = p.calledAET
        networkWebBaseURL = p.webBaseURL
    }

    /// Forces the endpoint onto the pinned preset whenever a server-pinned tool
    /// (dicom-mpps → DCM4CHEE5 MWL) is in the selection, so it can never be run against
    /// the wrong PACS. No-op when nothing pins the server.
    private func enforceServerLock() {
        if let locked = lockedServerID, selectedServerID != locked { applyServer(locked) }
    }

    // MARK: Query keys (dicom-query) — read-only C-FIND inputs

    /// The user-supplied C-FIND query keys for dicom-query. Enter values that exist
    /// on the PACS so the query returns real matches; blank fields are skipped. The
    /// matrix sweeps each provided filter individually plus the query levels.
    public var queryPatientName: String = ""
    public var queryPatientID: String = ""
    public var queryStudyDate: String = ""
    public var queryModality: String = ""
    public var queryAccession: String = ""
    public var queryStudyDescription: String = ""
    public var queryStudyUID: String = ""
    public var querySeriesUID: String = ""

    /// The Move Destination AE for dicom-qr's INTERACTIVE C-MOVE retrieve (the PACS must
    /// be configured to forward to it). Only the dicom-qr interactive-c-move row uses it;
    /// the interactive-c-get and read-only review rows ignore it.
    public var qrMoveDest: String = ""

    private func currentQueryFilters() -> QueryFilters {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var f = QueryFilters()
        f.patientName = t(queryPatientName); f.patientID = t(queryPatientID)
        f.studyDate = t(queryStudyDate); f.modality = t(queryModality)
        f.accession = t(queryAccession); f.studyDescription = t(queryStudyDescription)
        f.studyUID = t(queryStudyUID); f.seriesUID = t(querySeriesUID)
        return f
    }

    // MARK: Retrieve scope (dicom-retrieve) — C-MOVE / C-GET inputs

    /// The Study/Series/Instance UIDs dicom-retrieve pulls, plus the Move Destination
    /// AE for C-MOVE. Enter a Study UID that exists on the PACS; Series/Instance UIDs
    /// widen the sweep to those levels; the Move Destination is only needed for C-MOVE.
    public var retrieveStudyUID: String = ""
    public var retrieveSeriesUID: String = ""
    public var retrieveInstanceUID: String = ""
    public var retrieveMoveDest: String = ""
    /// The transfer syntax (a TransferSyntax UID) the C-GET scenarios request from the
    /// PACS; empty == server decides (no `--transfer-syntax`). Chosen from `transferSyntaxOptions`.
    public var retrieveTransferSyntax: String = ""

    /// A selectable transfer-syntax option for the retrieve picker.
    public struct TransferSyntaxOption: Identifiable, Hashable, Sendable {
        public let id: String     // the TransferSyntax UID ("" == server-decides default)
        public let name: String   // display name
    }

    /// The transfer-syntax choices for dicom-retrieve's C-GET — sourced wholesale from
    /// DICOMKit's `TransferSyntax.allKnown`, so the list can never drift from the SDK.
    /// The first entry is the no-`--transfer-syntax` default.
    public let transferSyntaxOptions: [TransferSyntaxOption] =
        [TransferSyntaxOption(id: "", name: "Default (server decides)")]
        + TransferSyntax.allKnown.map { TransferSyntaxOption(id: $0.uid, name: $0.displayName) }

    private func currentRetrieveScope() -> RetrieveScope {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var sc = RetrieveScope()
        sc.studyUID = t(retrieveStudyUID); sc.seriesUID = t(retrieveSeriesUID)
        sc.instanceUID = t(retrieveInstanceUID); sc.moveDest = t(retrieveMoveDest)
        sc.transferSyntax = t(retrieveTransferSyntax)
        return sc
    }

    // MARK: Worklist filters (dicom-mwl) — read-only MWL C-FIND inputs

    /// The user-supplied worklist filters for dicom-mwl. Enter values that match
    /// scheduled procedure steps on your worklist SCP so the query returns real items;
    /// blank fields are skipped. The matrix sweeps each provided filter individually
    /// plus a broad (no-filter) query. `mwlDate` accepts YYYYMMDD or "today"/"tomorrow".
    public var mwlDate: String = ""
    public var mwlStation: String = ""
    public var mwlPatientName: String = ""
    public var mwlPatientID: String = ""
    public var mwlModality: String = ""
    public var mwlSPSStatus: String = ""
    public var mwlAccession: String = ""

    private func currentWorklistFilters() -> WorklistFilters {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var f = WorklistFilters()
        f.date = t(mwlDate); f.station = t(mwlStation)
        f.patientName = t(mwlPatientName); f.patientID = t(mwlPatientID)
        f.modality = t(mwlModality); f.spsStatus = t(mwlSPSStatus)
        f.accession = t(mwlAccession)
        return f
    }

    // MARK: MPPS scope (dicom-mpps) — N-CREATE / N-SET lifecycle inputs (WRITES)

    /// The Study UID and procedure attributes dicom-mpps starts a performed procedure
    /// step for. The Study UID is required; the patient/accession/SPS-ID fields are
    /// optional N-CREATE attributes; the Series UID + Image UIDs (comma/space/newline
    /// separated) populate the referenced-image set carried by the completing N-SET.
    public var mppsStudyUID: String = ""
    public var mppsPatientName: String = ""
    public var mppsPatientID: String = ""
    public var mppsAccession: String = ""
    public var mppsSPSID: String = ""
    public var mppsSeriesUID: String = ""
    public var mppsImageUIDs: String = ""

    private func currentMPPSScope() -> MPPSScope {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var sc = MPPSScope()
        sc.studyUID = t(mppsStudyUID); sc.patientName = t(mppsPatientName)
        sc.patientID = t(mppsPatientID); sc.accession = t(mppsAccession)
        sc.spsID = t(mppsSPSID); sc.seriesUID = t(mppsSeriesUID)
        sc.imageUIDs = mppsImageUIDs
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return sc
    }

    // MARK: dicom-wado scope (DICOMweb — WADO-RS retrieve / UPS-RS lifecycle inputs)

    /// dicom-wado's QIDO-RS keys are the SHARED Query Keys (currentQueryFilters), whose
    /// Study/Series UID double as the WADO-RS retrieve scope. The SOP Instance UID below
    /// widens the retrieve sweep to the instance level. The UPS create → claim lifecycle
    /// is generated only when a Procedure Step Label is supplied (it WRITES); the
    /// patient fields are optional N-CREATE attributes and the Requesting AE is sent on
    /// the claim's state change.
    public var wadoInstanceUID: String = ""
    public var wadoUPSLabel: String = ""
    public var wadoUPSPatientName: String = ""
    public var wadoUPSPatientID: String = ""
    public var wadoUPSAET: String = ""

    private func currentWADOScope() -> WADOScope {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var sc = WADOScope()
        sc.query = currentQueryFilters()
        sc.instanceUID = t(wadoInstanceUID)
        sc.upsLabel = t(wadoUPSLabel)
        sc.upsPatientName = t(wadoUPSPatientName)
        sc.upsPatientID = t(wadoUPSPatientID)
        sc.upsAET = t(wadoUPSAET)
        return sc
    }

    /// Optional user-selected output directory dicom-retrieve writes its C-GET files to
    /// (network mode). When set, the OUTDIR token resolves to it and it is NOT cleaned
    /// up; when nil, a per-scenario scratch dir is used (and removed after the row).
    public private(set) var retrieveOutputPath: String? = nil
    private var retrieveOutputURL: URL? = nil

    public func setRetrieveOutput(url: URL) {
        retrieveOutputURL = url
        retrieveOutputPath = url.path
    }

    public func clearRetrieveOutput() {
        retrieveOutputURL = nil; retrieveOutputPath = nil
    }

    /// The output dir dicom-retrieve writes its C-GET files to, resolved for the OUTDIR
    /// token: the user-selected directory, or a per-scenario scratch dir. Set/cleared
    /// per network scenario (which run sequentially), like `pendingInputUsed`.
    private var pendingNetOutputDir: String = ""

    /// Tool ids for which network parity is implemented.
    private static let networkParitySupported = CLIParityNetworkScenarios.supportedToolIDs

    /// The DICOMweb subcommand aliases the Studio catalog lists as separate tools
    /// (dicom-qido = `wado query`, dicom-stow = `wado store`, dicom-ups = `wado ups`).
    /// They are NOT separate binaries — only `dicom-wado` is — so CLI Parity collapses
    /// them: the single `dicom-wado` tool represents the whole DICOMweb binary and its
    /// QIDO/WADO/STOW/UPS subcommands are swept as scenarios. These aliases are hidden
    /// from the parity picker (and could never build/run as standalone binaries here).
    private static let dicomwebSubcommandAliases: Set<String> = ["dicom-qido", "dicom-stow", "dicom-ups"]

    /// Whether the network tool has a parity reference today (vs. listed "coming
    /// soon"). All DIMSE / DICOMweb tools appear in the picker; only ready ones run.
    public func networkParityReady(_ id: String) -> Bool {
        Self.networkParitySupported.contains(id)
    }

    /// The user's selected input corpus directory (optional). When set, each tool
    /// draws its correct input shape from this corpus; otherwise bundled fixtures
    /// are used.
    public private(set) var inputDirectory: String? = nil
    private var inputDirURL: URL? = nil
    public private(set) var corpus: CorpusIndex? = nil
    public var isScanning: Bool = false
    public var scanMessage: String = ""

    /// Optional user-selected DICOM file OR directory for `dicom-send` (network mode).
    /// When set, both the package-API reference and the CLI send it — a directory is
    /// scanned recursively, a single file is taken as-is; when nil, both fall back to
    /// the bundled synthetic CT.
    public private(set) var sendInputPath: String? = nil
    private var sendInputURL: URL? = nil
    /// Whether the selected send input is a directory (vs a single file).
    public private(set) var sendInputIsDirectory: Bool = false
    /// DICOM-file count of the selected send input (for the picker's status line).
    public private(set) var sendInputFileCount: Int = 0

    // MARK: Run state

    /// When true (default), the selected tools' binaries are rebuilt fresh as the
    /// first step of every run, so the comparison never uses a stale binary.
    public var rebuildBeforeRun: Bool = true

    public var isRunning: Bool = false
    public var isBuilding: Bool = false
    public var buildMessage: String = ""
    public var totalScenarios: Int = 0
    public var completedScenarios: Int = 0
    public var binaryAvailable: Bool = true
    public var errorMessage: String? = nil

    /// Bin dir of the freshly-built products; pinned for the CLI side so a stale
    /// binary elsewhere can't shadow it. nil → fall back to the default search.
    private var freshBinDir: String? = nil

    /// Input label ("file · source") for the scenario currently running; stamped
    /// onto each result row. Safe as state because scenarios run sequentially.
    private var pendingInputUsed: String = ""

    /// When true, run the same command on BOTH its real and synthetic fixtures
    /// (the full parity-test matrix). Default false → one row per unique validated
    /// command (preferring the synthetic fixture).
    public var includeFixtureVariants: Bool = false

    public var results: [BatchScenarioResult] = []
    public var summary: BatchParitySummary = BatchParitySummary()

    /// The bundled validated scenario corpus (goldens.json, or goldens.synthetic.json
    /// on a clean checkout), loaded once.
    private let allGoldens: [GoldenScenario]

    public init() {
        let goldens = CLIParityEngine.loadGoldens()
        self.allGoldens = goldens
        let toolsWithGoldens = Set(goldens.map { $0.toolId })
        let all = ToolCatalogHelpers.allTools()
        self.availableTools = all.filter {
            toolsWithGoldens.contains($0.id) && !$0.requiresNetwork &&
            CLIParityEngine.executeSupported.contains($0.id)
        }
        // Show the DIMSE tools plus the single `dicom-wado` DICOMweb binary; ones
        // without a parity reference yet are listed "coming soon" (not selectable / not
        // run). The DICOMweb subcommand ALIASES (dicom-qido/dicom-stow/dicom-ups) are
        // collapsed into dicom-wado — they're not separate binaries, so they're hidden.
        self.availableNetworkTools = all.filter {
            $0.requiresNetwork && CLIParityEngine.executeSupported.contains($0.id)
                && !Self.dicomwebSubcommandAliases.contains($0.id)
        }
    }

    // MARK: Derived

    /// The tool pool for the active mode.
    public var activeTools: [CLIToolDefinition] {
        mode == .network ? availableNetworkTools : availableTools
    }

    /// Switches mode, scoping the selection to the new pool's tools (and
    /// pre-selecting the first network tool for convenience), and clears stale
    /// results so the two modes' tables never mix.
    public func setMode(_ m: ParityMode) {
        guard m != mode, !isRunning else { return }
        mode = m
        let ids = Set(activeTools.map { $0.id })
        selectedToolIDs = selectedToolIDs.intersection(ids)
        if m == .network, selectedToolIDs.isEmpty,
           let first = availableNetworkTools.first(where: { networkParityReady($0.id) }) {
            selectedToolIDs = [first.id]
        }
        enforceServerLock()   // a carried-over dicom-mpps selection pins DCM4CHEE5 MWL
        results = []
        summary = BatchParitySummary()
        errorMessage = nil
        completedScenarios = 0
        totalScenarios = 0
    }

    /// Results grouped by tool id, preserving discovery order.
    public var groupedResults: [(toolId: String, rows: [BatchScenarioResult])] {
        var order: [String] = []
        var byTool: [String: [BatchScenarioResult]] = [:]
        for r in results {
            if byTool[r.toolId] == nil { order.append(r.toolId) }
            byTool[r.toolId, default: []].append(r)
        }
        return order.map { ($0, byTool[$0] ?? []) }
    }

    public func displayName(for toolId: String) -> String {
        (availableTools + availableNetworkTools).first { $0.id == toolId }?.displayName ?? toolId
    }

    public func inputHint(for toolId: String) -> String {
        if toolId == "dicom-query" { return "PACS endpoint + query keys" }
        if toolId == "dicom-send" { return "PACS endpoint (sends a synthetic CT)" }
        if toolId == "dicom-retrieve" { return "PACS endpoint + retrieve scope" }
        if toolId == "dicom-qr" { return "PACS endpoint + query keys (review + interactive retrieve)" }
        if toolId == "dicom-mwl" { return "PACS endpoint + worklist filters" }
        if toolId == "dicom-mpps" { return "PACS endpoint + MPPS scope (writes)" }
        if toolId == "dicom-wado" { return "DICOMweb endpoint (QIDO/WADO/STOW/UPS)" }
        if Self.networkParitySupported.contains(toolId) { return "PACS endpoint" }
        return CLIParityScenarioGenerator.inputHint(for: toolId)
    }

    public func toggleTool(_ id: String) {
        // "Coming soon" network tools (no parity reference yet) aren't selectable.
        if mode == .network && !networkParityReady(id) { return }
        if selectedToolIDs.contains(id) { selectedToolIDs.remove(id) } else { selectedToolIDs.insert(id) }
        enforceServerLock()   // dicom-mpps pins the endpoint to DCM4CHEE5 MWL
        clearResults()
    }

    public func selectAllTools() {
        let ids = activeTools.map { $0.id }.filter { mode != .network || networkParityReady($0) }
        selectedToolIDs = Set(ids)
        enforceServerLock()   // dicom-mpps pins the endpoint to DCM4CHEE5 MWL
        clearResults()
    }
    public func clearToolSelection() { selectedToolIDs.removeAll(); clearResults() }

    private func clearResults() {
        results = []
        summary = BatchParitySummary()
        errorMessage = nil
        completedScenarios = 0
        totalScenarios = 0
    }

    /// Selects and scans an input corpus directory. Classification runs off the
    /// main actor (it reads file headers); the resulting CorpusIndex drives
    /// per-tool input resolution.
    public func setInputDirectory(url: URL) async {
        inputDirURL = url
        inputDirectory = url.path
        isScanning = true
        scanMessage = "Scanning \((url.path as NSString).lastPathComponent)…"
        defer { isScanning = false }
        let scoped = url.startAccessingSecurityScopedResource()
        let index = await Task.detached { CLIParityCorpusScanner.scan(directory: url) }.value
        if scoped { url.stopAccessingSecurityScopedResource() }
        corpus = index
        scanMessage = index.summary
    }

    public func clearInputDirectory() {
        inputDirURL = nil; inputDirectory = nil; corpus = nil; scanMessage = ""
    }

    /// Selects the DICOM file OR directory `dicom-send` should transmit (network mode).
    /// Counts its DICOM files using the SAME shared gatherer the CLI uses, so the status
    /// line reflects exactly what will be sent — a directory is scanned recursively, a
    /// single file is taken as-is. An empty/non-DICOM directory is allowed — the send
    /// scenario then skips with guidance rather than producing a false result.
    public func setSendInput(url: URL, isDirectory: Bool) async {
        sendInputURL = url
        sendInputPath = url.path
        sendInputIsDirectory = isDirectory
        let scoped = url.startAccessingSecurityScopedResource()
        let count = await Task.detached {
            CLIParityNetworkReference.gatherSendFiles(path: url.path, recursive: true).count
        }.value
        if scoped { url.stopAccessingSecurityScopedResource() }
        sendInputFileCount = count
    }

    public func clearSendInput() {
        sendInputURL = nil; sendInputPath = nil; sendInputIsDirectory = false; sendInputFileCount = 0
    }

    // MARK: Run

    public func run() async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        results = []
        summary = BatchParitySummary()
        completedScenarios = 0
        totalScenarios = 0
        isBuilding = false
        buildMessage = ""
        freshBinDir = nil
        defer { isRunning = false; isBuilding = false }

        #if os(macOS)
        let toolIds = activeTools.map { $0.id }.filter { selectedToolIDs.contains($0) }
        guard !toolIds.isEmpty else { errorMessage = "Select at least one tool to test."; return }

        if mode == .network {
            guard !networkHost.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter the PACS host (e.g. 172.17.1.200)."; return
            }
            guard !networkCallingAET.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter a Calling AE Title — the dicom-echo CLI requires --aet."; return
            }
            // Server-pinned tools (dicom-mpps → DCM4CHEE5 MWL) may run ONLY against
            // their preset — belt-and-suspenders behind the locked picker.
            for t in toolIds {
                if let required = Self.toolRequiredServer[t], selectedServerID != required {
                    errorMessage = "\(t) can only run against the \(required) server preset — select \(required) (or deselect \(t))."
                    return
                }
            }
        }

        // Step 0: build the selected tools' binaries FRESH so the comparison never
        // runs against a stale binary (a CLI built before the latest DICOMKit change).
        if rebuildBeforeRun {
            isBuilding = true
            buildMessage = "Building \(toolIds.count) tool\(toolIds.count == 1 ? "" : "s"): \(toolIds.joined(separator: ", "))…"
            let products = toolIds
            let outcome = await Task.detached { CLIToolBuilder.build(products: products) }.value
            isBuilding = false
            guard outcome.success else {
                binaryAvailable = false
                errorMessage = "Build failed — refusing to run against stale binaries.\n\n"
                    + String(outcome.log.suffix(4000))
                return
            }
            freshBinDir = outcome.binDir
            binaryAvailable = true
        } else {
            // No rebuild: at least confirm the selected tools' binaries exist somewhere.
            guard CLIToolTerminalCompare.locateBinary(tool: toolIds[0]) != nil else {
                binaryAvailable = false
                errorMessage = "\(toolIds[0]) binary not found. Enable “Rebuild binaries first”, run `swift build`, or set DICOM_CLI_BIN_DIR. (The App Sandbox must also be disabled — this is a testing-only feature.)"
                return
            }
            binaryAvailable = true
        }
        #else
        errorMessage = "Live CLI comparison is only available on macOS."
        return
        #endif

        // NETWORK mode: sweep the selected network tools against the live PACS and
        // compare the DICOMKit package-API reference vs the CLI semantically.
        if mode == .network {
            // Hold security-scoped access to the user-picked send file/dir for the WHOLE
            // run, so the package-API reference's in-process reads (Data(contentsOf:))
            // AND the forked dicom-send binary can actually read the selected DICOM.
            // Without this the reads fail silently and NOTHING is transmitted — the bug
            // where dicom-send "works in the CLI Workshop but not in CLI Parity" (the
            // Workshop holds the scope around its send; the offline branch holds it for
            // the corpus dir; the network branch previously held nothing).
            let sendScope = sendInputURL.map { ($0, $0.startAccessingSecurityScopedResource()) }
            defer { if let (u, ok) = sendScope, ok { u.stopAccessingSecurityScopedResource() } }
            // Same for the dicom-retrieve output directory the C-GET files are written to.
            let outScope = retrieveOutputURL.map { ($0, $0.startAccessingSecurityScopedResource()) }
            defer { if let (u, ok) = outScope, ok { u.stopAccessingSecurityScopedResource() } }

            let scenarios = CLIParityNetworkScenarios.scenarios(
                toolIDs: Set(toolIds), queryFilters: currentQueryFilters(),
                retrieveScope: currentRetrieveScope(),
                worklistFilters: currentWorklistFilters(),
                mppsScope: currentMPPSScope(),
                wadoScope: currentWADOScope(),
                qrMoveDest: qrMoveDest.trimmingCharacters(in: .whitespaces))
            totalScenarios = scenarios.count
            guard !scenarios.isEmpty else { errorMessage = "No network scenarios for the selected tools."; return }
            var sum = BatchParitySummary()
            var rows: [BatchScenarioResult] = []
            for s in scenarios {
                let r = await runNetworkScenario(s)
                rows.append(r)
                sum.tally(r)
                completedScenarios += 1
                results = rows
                summary = sum
            }
            results = rows
            summary = sum
            return
        }

        let drift = computeDriftFlags(for: toolIds)
        let scenarios = CLIParityScenarioGenerator.scenarios(
            fromGoldens: allGoldens, toolIDs: Set(toolIds), dedupByCliArgs: !includeFixtureVariants)
        totalScenarios = scenarios.count
        guard !scenarios.isEmpty else { errorMessage = "No scenarios generated for the selected tools."; return }

        // Hold security-scoped access to the corpus dir for the whole run
        // (sandbox-off test build).
        let scoped = inputDirURL.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer {
            if let (u, ok) = scoped, ok { u.stopAccessingSecurityScopedResource() }
        }

        var sum = BatchParitySummary()
        var rows: [BatchScenarioResult] = []
        for s in scenarios {
            let r = await runScenario(s, driftSet: drift[s.toolId] ?? [])
            rows.append(r)
            sum.tally(r)
            completedScenarios += 1
            results = rows            // incremental update for live progress
            summary = sum
        }
        results = rows
        summary = sum
    }

    // MARK: Per-tool input drift (the contract-level INPUT signal)

    /// For each tool, the set of flags the app emits that the CLI contract does
    /// NOT accept (EXTRA_IN_STUDIO). A scenario whose argv contains one is an
    /// INPUT_DRIFT row.
    private func computeDriftFlags(for toolIds: [String]) -> [String: Set<String>] {
        guard let contracts = CLIParityEngine.loadContracts() else { return [:] }
        let tools = ToolCatalogHelpers.allTools()
        var out: [String: Set<String>] = [:]
        for id in toolIds {
            guard let tool = tools.first(where: { $0.id == id }) else { continue }
            let r = CLIParityEngine.compare(tool: tool, contracts: contracts)
            out[id] = Set(r.rows.filter { $0.status == .extraInStudio }.map { $0.flag })
        }
        return out
    }

    // MARK: One scenario

    private func resolve(_ raw: String, file1: String, file2: String, output: String, output2: String) -> String {
        switch raw {
        case "FIXTURE":  return file1
        case "FIXTURE2": return file2
        case "OUTPUT":   return output
        case "OUTPUT2":  return output2
        default:         return raw
        }
    }

    private func result(_ s: BatchScenario, command: String, input: BatchSignal, app: Bool?, cli: Int32?,
                        output: BatchSignal, status: BatchRowStatus, appOut: String = "", cliOut: String = "",
                        diff: [OutputDiffLine] = [], note: String) -> BatchScenarioResult {
        BatchScenarioResult(scenarioId: s.scenarioId, toolId: s.toolId, label: s.label, commandLine: command,
            inputSignal: input, appSucceeded: app, cliExitCode: cli, outputSignal: output, status: status,
            appOutput: appOut, cliOutput: cliOut, diff: diff, note: note, inputUsed: pendingInputUsed)
    }

    private func runScenario(_ s: BatchScenario, driftSet: Set<String>) async -> BatchScenarioResult {
        let fm = FileManager.default

        // Resolve the input(s) HYBRID: use the user's CORPUS when it provides the
        // right shape for this tool (single file, file pair, multiframe, RLE, study
        // dir); else fall back to the bundled synthetic fixture; else skip with a
        // reason. Each tool draws the input shape it actually needs — the same way
        // the manual CLAUDE_PARITY_TEST fed each tool its correct input.
        let bundled1 = s.fixtureName.flatMap { CLIParityEngine.fixtureURL(named: $0)?.path }
        let bundled2 = s.fixture2Name.flatMap { CLIParityEngine.fixtureURL(named: $0)?.path }
        let corpusHit = corpus?.resolve(kind: s.fixtureKind)

        let file1: String
        let file2: String
        let source: String
        if s.needsSecondFile {
            if let c = corpusHit, let f2 = c.file2 { file1 = c.file1; file2 = f2; source = "corpus" }
            else if let b1 = bundled1 { file1 = b1; file2 = bundled2 ?? b1; source = "bundled" }
            else { file1 = ""; file2 = ""; source = "" }
        } else {
            if let c = corpusHit { file1 = c.file1; source = "corpus" }
            else if let b1 = bundled1 { file1 = b1; source = "bundled" }
            else { file1 = ""; source = "" }
            file2 = bundled2 ?? bundled1 ?? file1
        }
        pendingInputUsed = file1.isEmpty ? "" : "\((file1 as NSString).lastPathComponent) · \(source)"

        // Skip only when no valid input could be resolved (the corpus lacks the shape
        // AND no bundled fixture is present) — not a parity defect.
        if s.needsInputFile && file1.isEmpty {
            let want = s.inputHint
            return result(s, command: s.toolId, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: corpus != nil
                            ? "No \(want) found in your corpus, and no bundled fixture available for \(s.toolId)."
                            : "No bundled fixture available for \(s.toolId) (needs \(want)).")
        }

        // INPUT drift is known from the contract — short-circuit before running anything.
        let flagToks = s.cliArgs.filter { $0.hasPrefix("-") }
        if !driftSet.isEmpty && flagToks.contains(where: { driftSet.contains($0) }) {
            let command = ([s.toolId] + s.cliArgs.map {
                resolve($0, file1: file1, file2: file2, output: "<out>", output2: "<out2>")
            }).joined(separator: " ")
            return result(s, command: command, input: .differ, app: nil, cli: nil,
                          output: .notApplicable, status: .inputDrift,
                          note: "The app emits a flag the CLI contract rejects: \(flagToks.filter { driftSet.contains($0) }.joined(separator: ", ")).")
        }

        // Scratch dirs (one per side so the two artifacts don't collide).
        let needScratch = s.artifactName != nil || s.studioParams.values.contains("OUTPUT2")
        var appScratch: URL? = nil
        var cliScratch: URL? = nil
        if needScratch {
            for which in 0..<2 {
                let dir = fm.temporaryDirectory.appendingPathComponent("studio-parity-\(UUID().uuidString)", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                if which == 0 { appScratch = dir } else { cliScratch = dir }
            }
        }
        defer {
            if let d = appScratch { try? fm.removeItem(at: d) }
            if let d = cliScratch { try? fm.removeItem(at: d) }
        }

        let isDir = s.artifactKind == "dicom-multi" || s.artifactKind == "dicom-tree" || s.artifactKind == "image-multi"
        func artURL(_ scratch: URL?) -> URL? {
            guard let scratch, let name = s.artifactName else { return nil }
            let u = scratch.appendingPathComponent(name)
            if isDir { try? fm.createDirectory(at: u, withIntermediateDirectories: true) }
            return u
        }
        let appArt = artURL(appScratch)
        let cliArt = artURL(cliScratch)
        let appOut2 = appScratch?.appendingPathComponent("output2.dat")
        let cliOut2 = cliScratch?.appendingPathComponent("output2.dat")

        // ---- APP side (in-process) ----
        let workshop = CLIWorkshopViewModel()
        workshop.selectTool(id: s.toolId)
        // Clear catalog-default params the scenario didn't set (a leaked default --file
        // would make the app act on a different input than the CLI).
        for def in ToolCatalogHelpers.parameterDefinitions(for: s.toolId)
            where !def.isInternal && s.studioParams[def.id] == nil {
            workshop.updateParameterValue(parameterID: def.id, value: "")
        }
        for (pid, raw) in s.studioParams {
            let v = resolve(raw, file1: file1, file2: file2,
                            output: appArt?.path ?? "", output2: appOut2?.path ?? "")
            workshop.updateParameterValue(parameterID: pid, value: v)
        }
        await workshop.executeCommand()
        let appSuccess = workshop.consoleStatus == .success
        let appConsole = workshop.consoleOutput

        // ---- CLI side (subprocess) ----
        let resolvedArgs = s.cliArgs.map {
            resolve($0, file1: file1, file2: file2, output: cliArt?.path ?? "", output2: cliOut2?.path ?? "")
        }
        let command = ([s.toolId] + resolvedArgs).joined(separator: " ")

        #if os(macOS)
        let toolId = s.toolId
        let binDir = freshBinDir
        let outcome = await Task.detached { CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir) }.value

        if let launchError = outcome.launchError {
            return result(s, command: command, input: .match, app: appSuccess, cli: outcome.exitCode,
                          output: .notApplicable, status: .cliError, note: launchError)
        }
        let cliExit = outcome.exitCode
        // Combined CLI stdout + stderr, shown verbatim in the row's dropdown for
        // non-Pass rows so the user can see exactly why the CLI skipped/errored.
        let cliText: String = {
            let err = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if err.isEmpty { return outcome.stdout }
            return outcome.stdout + (outcome.stdout.isEmpty ? "" : "\n") + "── stderr ──\n" + outcome.stderr
        }()
        let cliProducedFile: Bool = {
            guard let u = cliArt else { return false }
            if isDir {
                let contents = (try? fm.contentsOfDirectory(atPath: u.path)) ?? []
                return !contents.isEmpty
            }
            return fm.fileExists(atPath: u.path)
        }()
        let cliProducedNothing = s.artifactName == nil
            ? outcome.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !cliProducedFile

        // Artifact scenarios with no reference artifact: if the tool was asked to
        // write a file/dir (artifactName != nil) but the CLI produced none — e.g. a
        // flag/fixture combo the tool can't fulfil, like `dicom-export bulk` on a
        // single file, which needs a directory — there is nothing to compare. Skip
        // rather than hashing a non-existent path (which would also make ImageIO log
        // a noisy "can't open" error). A genuine app-side miss (CLI produced the
        // artifact, app did not) still surfaces below as drift.
        if s.artifactName != nil && !cliProducedFile {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .skipped,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI produced no \(s.artifactName ?? "artifact") for this input — nothing to compare (the flag/fixture combination doesn't yield the expected output).")
        }

        // gen-skip net: a combo the CLI rejects (nonzero AND produced nothing).
        // Skipped only when the nonzero exit is NOT an expected result (resultExitOK) —
        // an intentional-failure scenario should be compared, not skipped.
        if cliExit != 0 && cliProducedNothing && !s.resultExitOK {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .skipped,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI rejected this combination (exit \(cliExit)) — not applicable to this input.")
        }
        // Exit-status reconciliation. For most tools any nonzero CLI exit is an
        // error. But "diff-style" tools (dicom-diff) use a nonzero exit as a RESULT
        // (exit 1 = files differ), and the app mirrors it — so when BOTH sides agree
        // on a nonzero result we still compare their outputs (parity is agreement).
        let resultExit = s.resultExitOK
        let cliOK = cliExit == 0
        if !cliOK && !resultExit {
            let stderr = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .cliError,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI exited \(cliExit)" + (stderr.isEmpty ? "." : ": \(String(stderr.prefix(300)))"))
        }
        if cliOK && !appSuccess {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: cliText,
                          note: "The app reported an error while the CLI succeeded.")
        }
        if !cliOK && appSuccess {
            // diff-style tool: CLI signalled a nonzero result (e.g. files differ) but
            // the app reported success — an exit-status divergence (real parity miss).
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI exited \(cliExit) (a nonzero result, e.g. files differ) but the app reported success — exit-status divergence.")
        }
        // Reaching here: both succeeded, OR (diff-style) both agreed on a nonzero
        // result. Either way, compare the outputs.

        // ---- Reduce both produced outputs to comparable strings ----
        let appRaw = await reduce(artifactURL: appArt, stdout: appConsole, kind: s.artifactKind)
        let cliRaw = await reduce(artifactURL: cliArt, stdout: outcome.stdout, kind: s.artifactKind)

        // Determinism probe for stdout tools: run the CLI a second time and compare
        // its OWN two outputs (masked). If unstable, the scenario can't be fairly scored.
        var nonDeterministic = false
        if s.artifactName == nil {
            let outcome2 = await Task.detached { CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir) }.value
            let a = CLIParityEngine.maskUIDs(CLIParityEngine.normalize(outcome.stdout, fixtureBasenames: []))
            let b = CLIParityEngine.maskUIDs(CLIParityEngine.normalize(outcome2.stdout, fixtureBasenames: []))
            if a != b { nonDeterministic = true }
        }

        let basenames = [(file1 as NSString).lastPathComponent, (file2 as NSString).lastPathComponent].filter { !$0.isEmpty }
        var cliLines = CLIParityEngine.normalize(cliRaw, fixtureBasenames: basenames)
        var appLines = CLIParityEngine.normalize(appRaw, fixtureBasenames: basenames)
        if s.artifactKind == "dicom" || s.artifactKind == "dicom-multi" || s.artifactKind == "dicom-tree" {
            cliLines = CLIParityEngine.maskVolatileDumpTags(cliLines)
            appLines = CLIParityEngine.maskVolatileDumpTags(appLines)
        }
        if s.artifactKind == "uid-list" {
            cliLines = CLIParityEngine.maskUIDs(cliLines)
            appLines = CLIParityEngine.maskUIDs(appLines)
        }
        let diff = CLIParityEngine.diff(cli: cliLines, studio: appLines)
        let outputMatch = !diff.contains { $0.kind != .same }

        if nonDeterministic {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .nonDeterministic,
                          appOut: appRaw, cliOut: cliRaw, diff: diff,
                          note: "The CLI's own output varies run-to-run even after masking; excluded from the score.")
        }
        return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                      output: outputMatch ? .match : .differ,
                      status: outputMatch ? .pass : .outputDrift,
                      appOut: appRaw, cliOut: cliRaw, diff: diff,
                      note: outputMatch ? "App output matches the CLI output (normalized)."
                                        : "App and CLI outputs differ (normalized).")
        #else
        return result(s, command: command, input: .match, app: appSuccess, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: Network scenario (semantic, timing-independent)

    /// Resolves an endpoint placeholder against the editable credential fields.
    private func resolveNet(_ raw: String) -> String {
        switch raw {
        case CLIParityNetworkScenarios.hostToken:      return networkHost.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.portToken:      return networkPort.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.aetToken:       return networkCallingAET.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.calledAETToken: return networkCalledAET.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.timeoutToken:   return networkTimeout.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.sendFileToken:
            // User-picked DICOM file or directory if set, else the bundled synthetic CT.
            if let p = sendInputURL?.path, !p.isEmpty { return p }
            return CLIParityEngine.fixtureURL(named: "syn-ct.dcm")?.path ?? ""
        case CLIParityNetworkScenarios.outDirToken:
            // Per-scenario scratch dir for dicom-retrieve's C-GET (and dicom-wado's
            // WADO-RS retrieve) output (set in runNetworkScenario). Empty for tools
            // that don't write retrieved files.
            return pendingNetOutputDir
        case CLIParityNetworkScenarios.webURLToken:    return networkWebBaseURL.trimmingCharacters(in: .whitespaces)
        default:                                       return raw
        }
    }

    #if os(macOS)
    /// Combined CLI stdout + stderr (dicom-echo prints to stderr) for parsing and display.
    private func combinedCLIText(_ outcome: CLIToolTerminalCompare.Outcome) -> String {
        let err = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if err.isEmpty { return outcome.stdout }
        return outcome.stdout + (outcome.stdout.isEmpty ? "" : "\n") + "── stderr ──\n" + outcome.stderr
    }
    #endif

    /// Runs an async network op against a wall-clock deadline, returning `fallback`
    /// if it doesn't finish in time. A hung DICOM receive isn't cancellable (it's
    /// blocked in a continuation), so the loser task is abandoned — acceptable for a
    /// testing harness, and far better than freezing the whole run. The deadline is
    /// set longer than the op's own bounded connect timeouts, so it only fires on a
    /// genuine hang (a PACS that accepts TCP but never answers a DIMSE request).
    private func raceDeadline<T: Sendable>(_ seconds: TimeInterval, fallback: T,
                                           _ op: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await op() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(1, seconds) * 1_000_000_000))
                return nil   // timeout sentinel
            }
            // First finished wins: the op yields .some(value); the timer yields nil.
            let result = await group.next()   // T?? — outer nil only if the group were empty
            group.cancelAll()
            if let inner = result, let value = inner { return value }
            return fallback
        }
    }

    /// Runs one network scenario: the app (in-process) and the real CLI both
    /// echo the SAME live PACS, and their outcomes are compared semantically
    /// (success/failure counts, DIMSE status, remote AE) with timing ignored.
    private func runNetworkScenario(_ s: BatchScenario) async -> BatchScenarioResult {
        // dicom-mpps is STATEFUL (N-CREATE mints a UID that N-SET targets) and needs
        // TWO chained CLI invocations per lifecycle, so it has its own dedicated runner
        // rather than the single-invocation generic path below.
        if s.toolId == "dicom-mpps" { return await runMPPSScenario(s) }

        // dicom-wado store (argv must expand SENDFILE → the gathered file list) and the
        // UPS create → claim lifecycle (two chained, stateful invocations) need their
        // own runners; query / retrieve / ups-search go through the generic path below.
        if s.toolId == "dicom-wado" {
            switch s.studioParams["wado-mode"] {
            case "store":         return await runWADOStoreScenario(s)
            case "ups-lifecycle": return await runWADOUPSLifecycleScenario(s)
            default:              break
            }
        }

        // dicom-retrieve writes its C-GET files to the user-selected output directory
        // when set (kept, not cleaned up); otherwise to a fresh scratch dir that is
        // removed after the scenario (the reference itself counts in memory). Resolved
        // for the OUTDIR token. Other network tools don't write retrieved files.
        let fm = FileManager.default
        var netScratch: URL? = nil
        // dicom-wado WADO-RS instance retrieve (not --metadata) writes files to a fresh
        // scratch dir the runner counts (the reference counts in memory); --metadata
        // prints to stdout and writes nothing.
        let wadoRetrieveInstances = s.toolId == "dicom-wado"
            && s.studioParams["wado-mode"] == "retrieve" && s.studioParams["metadata"] != "true"
        // dicom-qr's interactive C-GET writes its pulled files to the OUTDIR scratch dir
        // too (the reference counts in memory); C-MOVE and review write nothing there.
        let qrInteractiveGet = s.toolId == "dicom-qr" && s.studioParams["qr-mode"] == "interactive-get"
        if s.toolId == "dicom-retrieve" {
            if let out = retrieveOutputURL?.path, !out.isEmpty {
                try? fm.createDirectory(atPath: out, withIntermediateDirectories: true)
                pendingNetOutputDir = out
            } else {
                let dir = fm.temporaryDirectory.appendingPathComponent("studio-parity-net-\(UUID().uuidString)", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                netScratch = dir
                pendingNetOutputDir = dir.path
            }
        } else if wadoRetrieveInstances || qrInteractiveGet {
            let dir = fm.temporaryDirectory.appendingPathComponent("studio-parity-out-\(UUID().uuidString)", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            netScratch = dir
            pendingNetOutputDir = dir.path
        } else {
            pendingNetOutputDir = ""
        }
        defer { if let d = netScratch { try? fm.removeItem(at: d) } }

        let command = ([s.toolId] + s.cliArgs.map { resolveNet($0) }).joined(separator: " ")

        #if os(macOS)
        let host = networkHost.trimmingCharacters(in: .whitespaces)
        let portStr = networkPort.trimmingCharacters(in: .whitespaces)
        let port = UInt16(portStr) ?? 11112
        let callingAET = networkCallingAET.trimmingCharacters(in: .whitespaces)
        let calledAET = networkCalledAET.trimmingCharacters(in: .whitespaces)
        let webBaseURL = networkWebBaseURL.trimmingCharacters(in: .whitespaces)
        let webToken = networkWebToken.trimmingCharacters(in: .whitespaces)
        pendingInputUsed = s.toolId == "dicom-wado"
            ? "DICOMweb \(webBaseURL)"
            : "\(callingAET) → \(calledAET) @ \(host):\(portStr)"

        let sp = s.studioParams
        let scTimeout = TimeInterval(resolveNet(sp["timeout"] ?? "")) ?? 30

        // dicom-wado (DICOMweb) needs a base URL; its retrieve / query levels need the
        // scoping UID(s). The scenarios are ALWAYS generated so they're visible; skip
        // here (with guidance) when the required input is absent.
        if s.toolId == "dicom-wado" {
            if webBaseURL.isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a DICOMweb Base URL (e.g. http://host:8080/dcm4chee-arc/aets/AET/rs) to test dicom-wado.")
            }
            let mode = sp["wado-mode"] ?? ""
            let level = sp["level"] ?? "study"
            let hasStudy = !(sp["study-uid"] ?? "").isEmpty
            let hasSeries = !(sp["series-uid"] ?? "").isEmpty
            let hasInstance = !(sp["instance-uid"] ?? "").isEmpty
            if mode == "query" {
                if level == "series" && !hasStudy {
                    return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                                  output: .notApplicable, status: .skipped,
                                  note: "Enter a Study UID in the Query Keys to test the QIDO-RS series level.")
                }
                if level == "instance" && (!hasStudy || !hasSeries) {
                    return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                                  output: .notApplicable, status: .skipped,
                                  note: "Enter a Study UID and a Series UID in the Query Keys to test the QIDO-RS instance level.")
                }
            }
            if mode == "retrieve" {
                if !hasStudy {
                    return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                                  output: .notApplicable, status: .skipped,
                                  note: "Enter a Study UID in the Query Keys to test dicom-wado WADO-RS retrieve.")
                }
                if level == "series" && !hasSeries {
                    return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                                  output: .notApplicable, status: .skipped,
                                  note: "Enter a Series UID in the Query Keys to test the series-level retrieve.")
                }
                if level == "instance" && (!hasSeries || !hasInstance) {
                    return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                                  output: .notApplicable, status: .skipped,
                                  note: "Enter a Series UID (Query Keys) and an Instance UID (dicom-wado scope) to test the instance-level retrieve.")
                }
            }
        }

        // Series/instance query levels need the scoping UID(s). The scenarios are
        // ALWAYS generated so they're visible; skip here (with guidance) when the
        // required UID wasn't supplied, rather than running a meaningless broad query.
        if s.toolId == "dicom-query" {
            let level = sp["level"] ?? "study"
            let hasStudy = !(sp["study-uid"] ?? "").isEmpty
            let hasSeries = !(sp["series-uid"] ?? "").isEmpty
            if level == "series" && !hasStudy {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Study UID in the Query Keys to test the series level.")
            }
            if level == "instance" && (!hasStudy || !hasSeries) {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Study UID and a Series UID in the Query Keys to test the instance level.")
            }
        }

        // dicom-retrieve needs a Study UID; C-MOVE additionally needs a Move
        // Destination AE. The study-level scenarios are ALWAYS generated so they're
        // visible; skip here with guidance when the required input is absent.
        if s.toolId == "dicom-retrieve" {
            if (sp["study-uid"] ?? "").isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Study UID in the Retrieve Scope to test dicom-retrieve.")
            }
            if (sp["method"] ?? "") == "c-move" && (sp["move-dest"] ?? "").isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Move Destination AE in the Retrieve Scope to test C-MOVE (the PACS must be configured to forward to it). The C-GET scenarios need no destination.")
            }
        }

        // dicom-qr's INTERACTIVE rows retrieve EVERY matched study (auto-answer "all"),
        // so they're skipped unless a Query Key bounds the match set — otherwise a broad
        // query would move the entire PACS. C-MOVE additionally needs a Move Destination
        // AE. The read-only review rows have no such requirement.
        if s.toolId == "dicom-qr", let mode = sp["qr-mode"], mode.hasPrefix("interactive") {
            let hasFilter = ["patient-name", "patient-id", "study-date", "modality",
                             "accession", "study-description", "study-uid"]
                .contains { !(sp[$0] ?? "").isEmpty }
            if !hasFilter {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter at least one Query Key to bound the interactive retrieve — it selects \"all\" matched studies and would otherwise retrieve the entire PACS.")
            }
            if mode == "interactive-move" && (sp["move-dest"] ?? "").isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Move Destination AE (dicom-qr scope) to test interactive C-MOVE (the PACS must be configured to forward to it). The interactive C-GET row needs no destination.")
            }
        }

        // ---- REFERENCE side: drive the DICOMKit package API directly (never the CLI
        //      Workshop's in-app code). Tool-specific record + render; the CLI parse +
        //      verdict below are shared. ----
        let refOK: Bool
        let refRender: String
        // Tool-specific CLI parse + compare, deferred until the CLI has run.
        let compareCLI: (_ combined: String, _ stdout: String, _ exitOK: Bool) -> (diff: [OutputDiffLine], match: Bool)
        // Worst-case count of bounded connect-timeouts this scenario can incur, used to
        // size the hang backstop (below) for both the reference and the CLI subprocess.
        var netUnits = 1

        switch s.toolId {
        case "dicom-query":
            let level = sp["level"] ?? "study"
            var f = QueryFilters()
            f.patientName = sp["patient-name"] ?? ""
            f.patientID = sp["patient-id"] ?? ""
            f.studyDate = sp["study-date"] ?? ""
            f.modality = sp["modality"] ?? ""
            f.accession = sp["accession"] ?? ""
            f.studyDescription = sp["study-description"] ?? ""
            f.studyUID = sp["study-uid"] ?? ""
            f.seriesUID = sp["series-uid"] ?? ""
            netUnits = 2
            let q = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: CLIParityQueryComparator.semantics(level: level, success: false, objects: [])) { [f] in
                await CLIParityNetworkReference.query(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                    timeout: scTimeout, level: level, filters: f)
            }
            refOK = q.overallOK
            refRender = CLIParityNetworkReference.renderQuery(q)
            // dicom-query prints results to STDOUT. JSON carries full attributes →
            // full result-set parity; csv/table/compact drop/truncate fields → result
            // COUNT parity.
            let format = sp["format"] ?? "json"
            compareCLI = { _, stdout, exitOK in
                if format == "json" {
                    return CLIParityQueryComparator.compare(
                        reference: q,
                        cli: CLIParityQueryComparator.parse(stdout, level: q.level, success: exitOK))
                }
                let cnt = CLIParityQueryComparator.count(in: stdout, format: format)
                return CLIParityQueryComparator.compareCount(reference: q, cliCount: cnt, format: format)
            }
        case "dicom-send":
            let dryRun = sp["dry-run"] == "true"
            let verify = sp["verify"] == "true"
            let priorityName = sp["priority"] ?? "medium"
            // Expand the send path (picked file/directory, or the bundled CT) into the
            // SAME file list the CLI will transmit — identical enumeration via the
            // shared gatherer, so dry-run "Found N" and the send counts line up.
            let sendPath = resolveNet(CLIParityNetworkScenarios.sendFileToken)
            let recursive = s.cliArgs.contains("--recursive")
            let files = CLIParityNetworkReference.gatherSendFiles(path: sendPath, recursive: recursive)
            if files.isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "No DICOM files found in the selected send file/directory — pick a DICOM file (or a directory that contains DICOM files), or clear it to send the bundled synthetic CT.")
            }
            netUnits = max(1, files.count) + (verify ? 1 : 0)
            let snd = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: SendSemantics(dryRun: dryRun, sent: files.count,
                                        succeeded: 0, failed: dryRun ? 0 : files.count)) {
                await CLIParityNetworkReference.send(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET, timeout: scTimeout,
                    filePaths: files, priorityName: priorityName, transferSyntaxName: "",
                    verify: verify, dryRun: dryRun)
            }
            refOK = snd.overallOK
            refRender = CLIParityNetworkReference.renderSend(snd)
            // dicom-send prints its summary to stdout (dry-run note to stderr) → parse combined.
            compareCLI = { combined, _, _ in
                CLIParitySendComparator.compare(reference: snd, cli: CLIParitySendComparator.parse(combined, dryRun: dryRun))
            }

        case "dicom-retrieve":
            let method = sp["method"] ?? "c-get"
            let level = sp["level"] ?? "study"
            let studyUID = sp["study-uid"] ?? ""
            let seriesUID = sp["series-uid"] ?? ""
            let instanceUID = sp["instance-uid"] ?? ""
            let moveDest = sp["move-dest"] ?? ""
            let tsName = sp["transfer-syntax"] ?? ""
            // A retrieve is one association but can stream many instances; size the
            // hang backstop generously so a real multi-instance pull isn't mistaken
            // for a hang (the per-op connect timeout still bounds a dead endpoint).
            netUnits = 8
            let r = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: RetrieveSemantics(method: method, level: level, success: false,
                                            completed: 0, failed: 0, warning: 0, filesReceived: 0)) {
                await CLIParityNetworkReference.retrieve(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET, timeout: scTimeout,
                    method: method, level: level, studyUID: studyUID, seriesUID: seriesUID,
                    instanceUID: instanceUID, moveDest: moveDest, transferSyntaxName: tsName)
            }
            refOK = r.overallOK
            refRender = CLIParityNetworkReference.renderRetrieve(r)
            // dicom-retrieve prints its result block to STDERR → parse the combined text.
            compareCLI = { combined, _, exitOK in
                CLIParityRetrieveComparator.compare(
                    reference: r,
                    cli: CLIParityRetrieveComparator.parse(combined, method: method, level: level, success: exitOK))
            }

        case "dicom-qr":
            var f = QueryFilters()
            f.patientName = sp["patient-name"] ?? ""
            f.patientID = sp["patient-id"] ?? ""
            f.studyDate = sp["study-date"] ?? ""
            f.modality = sp["modality"] ?? ""
            f.accession = sp["accession"] ?? ""
            f.studyDescription = sp["study-description"] ?? ""
            f.studyUID = sp["study-uid"] ?? ""
            let qrMode = sp["qr-mode"] ?? "review"
            let q: QRSemantics
            if qrMode.hasPrefix("interactive") {
                // Interactive: one C-FIND + one retrieve association PER matched study.
                // Size the hang backstop generously so a real multi-study retrieve isn't
                // mistaken for a hang (each op's own connect timeout still bounds a dead
                // endpoint). The CLI feeds its selection on stdin (resolved below).
                let method = sp["method"] ?? "c-get"
                let moveDest = sp["move-dest"] ?? ""
                netUnits = 16
                q = await raceDeadline(
                    scTimeout * Double(netUnits) + 60,
                    fallback: CLIParityQRComparator.record(success: false, count: 0, uids: [])) { [f] in
                    await CLIParityNetworkReference.qrInteractive(
                        host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                        timeout: scTimeout, filters: f, method: method, moveDest: moveDest)
                }
            } else {
                netUnits = 2
                q = await raceDeadline(
                    scTimeout * Double(netUnits) + 60,
                    fallback: CLIParityQRComparator.record(success: false, count: 0, uids: [])) { [f] in
                    await CLIParityNetworkReference.qrReview(
                        host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                        timeout: scTimeout, filters: f)
                }
            }
            refOK = q.overallOK
            refRender = CLIParityNetworkReference.renderQR(q)
            // dicom-qr prints to STDOUT: "Found N studies" + per-study "UID:" (both modes),
            // plus the interactive "Retrieval Summary" Total/Success/Failed block.
            compareCLI = { _, stdout, exitOK in
                CLIParityQRComparator.compare(reference: q, cli: CLIParityQRComparator.parse(stdout, success: exitOK))
            }

        case "dicom-mwl":
            var f = WorklistFilters()
            f.date = sp["date"] ?? ""
            f.station = sp["station"] ?? ""
            f.patientName = sp["patient-name"] ?? ""
            f.patientID = sp["patient-id"] ?? ""
            f.modality = sp["modality"] ?? ""
            f.spsStatus = sp["sps-status"] ?? ""
            f.accession = sp["accession"] ?? ""
            netUnits = 2
            let w = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: CLIParityMWLComparator.record(success: false, count: 0, keys: [])) { [f] in
                await CLIParityNetworkReference.worklist(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                    timeout: scTimeout, filters: f)
            }
            refOK = w.overallOK
            refRender = CLIParityNetworkReference.renderWorklist(w)
            // dicom-mwl --json prints its item array to STDOUT.
            compareCLI = { _, stdout, exitOK in
                CLIParityMWLComparator.compare(reference: w, cli: CLIParityMWLComparator.parse(stdout, success: exitOK))
            }

        case "dicom-wado":
            // The store + ups-lifecycle modes are dispatched to dedicated runners
            // above; here we handle query (QIDO-RS), retrieve (WADO-RS) and ups-search.
            switch sp["wado-mode"] ?? "query" {
            case "retrieve":
                let level = sp["level"] ?? "study"
                let metadata = sp["metadata"] == "true"
                let studyUID = sp["study-uid"] ?? ""
                let seriesUID = sp["series-uid"] ?? ""
                let instanceUID = sp["instance-uid"] ?? ""
                netUnits = 8
                let r = await raceDeadline(
                    scTimeout * Double(netUnits) + 60,
                    fallback: CLIParityWADOComparator.retrieveRecord(
                        level: level, mode: metadata ? "metadata" : "instances", success: false, count: 0)) {
                    await CLIParityNetworkReference.wadoRetrieve(
                        baseURL: webBaseURL, token: webToken, level: level,
                        studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID, metadata: metadata)
                }
                refOK = r.overallOK
                refRender = CLIParityNetworkReference.renderWADORetrieve(r)
                // WADO-RS: --metadata prints a JSON array to STDOUT; an instances pull
                // writes files to the output dir (counted on disk by the runner).
                let outDir = pendingNetOutputDir
                compareCLI = { _, stdout, exitOK in
                    let cliCount = metadata
                        ? CLIParityWADOComparator.parseMetadataCount(stdout)
                        : Self.countDICOMFiles(inDir: outDir)
                    let cli = CLIParityWADOComparator.retrieveRecord(
                        level: level, mode: metadata ? "metadata" : "instances", success: exitOK, count: cliCount)
                    return CLIParityWADOComparator.compareRetrieve(reference: r, cli: cli)
                }
            case "ups-search":
                netUnits = 2
                let u = await raceDeadline(
                    scTimeout * Double(netUnits) + 60,
                    fallback: CLIParityWADOComparator.searchRecord(success: false, count: 0, uids: [])) {
                    await CLIParityNetworkReference.wadoUPSSearch(baseURL: webBaseURL, token: webToken)
                }
                refOK = u.overallOK
                refRender = CLIParityNetworkReference.renderWADOUPS(u)
                // dicom-wado ups --search --format json prints a workitem JSON array to STDOUT.
                compareCLI = { _, stdout, exitOK in
                    CLIParityWADOComparator.compareUPS(
                        reference: u, cli: CLIParityWADOComparator.parseSearch(stdout, success: exitOK))
                }
            default:   // "query" (QIDO-RS)
                let level = sp["level"] ?? "study"
                var f = QueryFilters()
                f.patientName = sp["patient-name"] ?? ""
                f.patientID = sp["patient-id"] ?? ""
                f.studyDate = sp["study-date"] ?? ""
                f.modality = sp["modality"] ?? ""
                f.accession = sp["accession"] ?? ""
                f.studyDescription = sp["study-description"] ?? ""
                f.studyUID = sp["study-uid"] ?? ""
                f.seriesUID = sp["series-uid"] ?? ""
                netUnits = 2
                let q = await raceDeadline(
                    scTimeout * Double(netUnits) + 60,
                    fallback: CLIParityWADOComparator.querySemantics(level: level, success: false, objects: [])) { [f] in
                    await CLIParityNetworkReference.wadoQuery(
                        baseURL: webBaseURL, token: webToken, level: level, filters: f)
                }
                refOK = q.overallOK
                refRender = CLIParityNetworkReference.renderWADOQuery(q)
                // QIDO-RS prints to STDOUT. JSON carries full attributes → full
                // result-set parity; csv/table drop fields → result COUNT parity.
                let format = sp["format"] ?? "json"
                compareCLI = { _, stdout, exitOK in
                    if format == "json" {
                        return CLIParityWADOComparator.compareQuery(
                            reference: q,
                            cli: CLIParityWADOComparator.parseQuery(stdout, level: level, success: exitOK))
                    }
                    let cnt = CLIParityWADOComparator.count(in: stdout, format: format)
                    return CLIParityWADOComparator.compareCount(reference: q, cliCount: cnt, format: format)
                }
            }

        default:   // dicom-echo
            let count = max(1, Int(sp["count"] ?? "") ?? 1)
            let verbose = sp["verbose"] == "true"
            let diagnose = sp["diagnose"] == "true"
            netUnits = diagnose ? 6 : max(1, count)
            let e = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: EchoSemantics(mode: diagnose ? "diagnose" : "echo",
                                        sent: 0, succeeded: 0, failed: max(1, count),
                                        statusCodes: [], remoteAEs: [],
                                        diagBasicOK: diagnose ? false : nil, diagStability: nil,
                                        diagResult: diagnose ? "FAILED" : nil)) {
                await CLIParityNetworkReference.echo(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                    timeout: scTimeout, count: count, verbose: verbose, diagnose: diagnose)
            }
            refOK = e.overallOK
            refRender = CLIParityNetworkReference.render(e)
            // dicom-echo prints to STDERR; parse the combined text.
            compareCLI = { combined, _, _ in
                CLIParityEchoComparator.compare(reference: e, cli: CLIParityEchoComparator.parse(combined))
            }
        }

        // ---- CLI side: the real binary (same hang backstop as the reference) ----
        let resolvedArgs = s.cliArgs.map { resolveNet($0) }
        let toolId = s.toolId
        let binDir = freshBinDir
        let cliDeadline = scTimeout * Double(netUnits) + 60
        // An interactive scenario auto-answers its prompt: the selection string is fed to
        // the CLI's stdin (newline-terminated for readLine()), identical to the answer the
        // SDK reference replicates above. Non-interactive scenarios carry no stdin.
        let cliStdin = s.studioParams["stdin"].map { $0 + "\n" }
        let outcome = await Task.detached {
            CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir,
                                       timeout: cliDeadline, stdin: cliStdin)
        }.value
        if let launchError = outcome.launchError {
            return result(s, command: command, input: .notApplicable, app: refOK, cli: outcome.exitCode,
                          output: .notApplicable, status: .cliError, appOut: refRender, note: launchError)
        }
        let cliExit = outcome.exitCode
        let cliText = combinedCLIText(outcome)

        // Semantic comparison (timing/ordering-independent): SDK reference vs CLI.
        let cmp = compareCLI(cliText, outcome.stdout, cliExit == 0)

        // PROCESS parity: the package API and the CLI must agree on success/failure.
        let cliOK = cliExit == 0
        let processMatch = (refOK == cliOK)
        let bothFailed = !refOK && !cliOK

        if !processMatch {
            return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                          output: cmp.match ? .match : .differ, status: .appError,
                          appOut: refRender, cliOut: cliText, diff: cmp.diff,
                          note: "Process divergence: the DICOMKit package API \(refOK ? "succeeded" : "failed") but the \(s.toolId) CLI exited \(cliExit). The CLI and the package API must agree on the outcome.")
        }

        // Both agree on success/failure → the semantic record decides parity.
        // A both-failed-identically row is recorded as .failureAgreement (parity held
        // on the failure path, no successful operation compared) and is EXCLUDED from
        // the score so an unreachable server can't inflate the rate.
        let bothFailedIdentically = bothFailed && cmp.match
        let status: BatchRowStatus = bothFailedIdentically ? .failureAgreement
                                   : (cmp.match ? .pass : .outputDrift)
        let note: String
        switch status {
        case .failureAgreement:
            note = "The package API and the CLI both reported failure identically (e.g. server unreachable or AE not recognised) — parity held on the failure path, but no successful operation occurred, so this row is excluded from the score."
        case .pass:
            note = "The \(s.toolId) CLI matches the DICOMKit package API reference (semantic outcome; timing/ordering ignored)."
        default:
            note = "The \(s.toolId) CLI diverges from the DICOMKit package API reference (see diff; timing/ordering ignored)."
        }
        return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                      output: cmp.match ? .match : .differ,
                      status: status,
                      appOut: refRender, cliOut: cliText, diff: cmp.diff, note: note)
        #else
        return result(s, command: command, input: .match, app: nil, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: MPPS lifecycle scenario (stateful, two-phase, WRITES)

    /// Runs one dicom-mpps lifecycle scenario. The package-API reference
    /// (DICOMMPPSService.create → .update) and the real CLI (`dicom-mpps create` →
    /// `dicom-mpps update`) each run an INDEPENDENT create-then-update against the
    /// live server. The minted MPPS SOP Instance UID is generated client-side and
    /// differs between the two by design, so it is never compared — parity is on the
    /// outcome (create/update success, final status, referenced-image count). The CLI
    /// side threads the UID parsed from its own `create` output into its `update` run.
    private func runMPPSScenario(_ s: BatchScenario) async -> BatchScenarioResult {
        let command = ([s.toolId] + s.cliArgs.map { resolveNet($0) }).joined(separator: " ")

        #if os(macOS)
        let host = networkHost.trimmingCharacters(in: .whitespaces)
        let portStr = networkPort.trimmingCharacters(in: .whitespaces)
        let port = UInt16(portStr) ?? 11112
        let callingAET = networkCallingAET.trimmingCharacters(in: .whitespaces)
        let calledAET = networkCalledAET.trimmingCharacters(in: .whitespaces)
        pendingInputUsed = "\(callingAET) → \(calledAET) @ \(host):\(portStr)"

        let sp = s.studioParams
        let scTimeout = TimeInterval(resolveNet(sp["timeout"] ?? "")) ?? 30
        let lifecycle = (sp["operation"] ?? "create") == "lifecycle"
        let finalStatus = sp["final-status"] ?? ""
        let studyUID = sp["study-uid"] ?? ""

        // N-CREATE requires a Study UID. The scenarios are ALWAYS generated so they're
        // visible; skip here with guidance when it's absent.
        if studyUID.isEmpty {
            return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: "Enter a Study UID in the MPPS Scope to test dicom-mpps (N-CREATE requires it).")
        }

        var scope = MPPSScope()
        scope.studyUID = studyUID
        scope.patientName = sp["patient-name"] ?? ""
        scope.patientID = sp["patient-id"] ?? ""
        scope.accession = sp["accession"] ?? ""
        scope.spsID = sp["sps-id"] ?? ""
        scope.seriesUID = sp["series-uid"] ?? ""
        scope.imageUIDs = (sp["image-uids"] ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty }

        // ---- REFERENCE side: drive DICOMMPPSService.create (→ .update) directly. ----
        let netUnits = lifecycle ? 2 : 1
        let ref = await raceDeadline(
            scTimeout * Double(netUnits) + 60,
            fallback: CLIParityMPPSComparator.record(
                lifecycle: lifecycle, createOK: false, updateOK: lifecycle ? false : nil,
                finalStatus: lifecycle ? finalStatus : "IN PROGRESS", referencedImages: 0)) { [scope] in
            await CLIParityNetworkReference.mpps(
                host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                timeout: scTimeout, scope: scope, lifecycle: lifecycle, finalStatus: finalStatus)
        }
        let refRender = CLIParityNetworkReference.renderMPPS(ref)

        // ---- CLI side: `dicom-mpps create`, parse the minted UID, then (for a
        //      lifecycle row) `dicom-mpps update --mpps-uid <UID> --status <final>`. ----
        let toolId = s.toolId
        let binDir = freshBinDir
        let cliDeadline = scTimeout * Double(netUnits) + 60

        let createArgs = s.cliArgs.map { resolveNet($0) }
        let createOutcome = await Task.detached {
            CLIToolTerminalCompare.run(tool: toolId, arguments: createArgs, binDir: binDir, timeout: cliDeadline)
        }.value
        if let launchError = createOutcome.launchError {
            return result(s, command: command, input: .notApplicable, app: ref.overallOK, cli: createOutcome.exitCode,
                          output: .notApplicable, status: .cliError, appOut: refRender, note: launchError)
        }
        let createText = combinedCLIText(createOutcome)
        let parsedCreate = CLIParityMPPSComparator.parseCreate(createText, exitOK: createOutcome.exitCode == 0)

        var updateText = ""
        var lastExit = createOutcome.exitCode
        var cliUpdateOK: Bool? = nil
        var cliRefImages = 0
        var cliFinalStatus = "IN PROGRESS"
        if lifecycle {
            if parsedCreate.ok, let uid = parsedCreate.uid {
                var updateArgs = ["update", host, "--port", portStr, "--aet", callingAET,
                                  "--called-aet", calledAET, "--mpps-uid", uid, "--status", finalStatus]
                // Referenced images: only the with-images row carries a Series UID + image UIDs.
                if !scope.seriesUID.isEmpty, !scope.imageUIDs.isEmpty {
                    updateArgs += ["--study-uid", studyUID, "--series-uid", scope.seriesUID]
                    for img in scope.imageUIDs { updateArgs += ["--image-uid", img] }
                }
                updateArgs += ["--timeout", String(Int(scTimeout))]
                let updateOutcome = await Task.detached {
                    CLIToolTerminalCompare.run(tool: toolId, arguments: updateArgs, binDir: binDir, timeout: cliDeadline)
                }.value
                updateText = combinedCLIText(updateOutcome)
                lastExit = updateOutcome.exitCode
                let pu = CLIParityMPPSComparator.parseUpdate(updateText, exitOK: updateOutcome.exitCode == 0)
                cliUpdateOK = pu.ok
                cliRefImages = pu.refImages
                cliFinalStatus = pu.status ?? finalStatus
            } else {
                // Create failed → no N-SET attempted; the update did not succeed.
                cliUpdateOK = false
                cliFinalStatus = finalStatus
            }
        }

        let cli = CLIParityMPPSComparator.record(
            lifecycle: lifecycle, createOK: parsedCreate.ok, updateOK: cliUpdateOK,
            finalStatus: lifecycle ? cliFinalStatus : "IN PROGRESS",
            referencedImages: cliRefImages)

        // Combined CLI text for the row's output pane: both phases.
        let cliText: String = {
            var t = "── create ──\n" + createText
            if lifecycle { t += "\n\n── update ──\n" + (updateText.isEmpty ? "(not run — create failed)" : updateText) }
            return t
        }()

        let cmp = CLIParityMPPSComparator.compare(reference: ref, cli: cli)

        // PROCESS parity + verdict — same shape as the generic network path.
        let refOK = ref.overallOK
        let cliOK = cli.overallOK
        let processMatch = (refOK == cliOK)
        let bothFailed = !refOK && !cliOK

        if !processMatch {
            return result(s, command: command, input: .match, app: refOK, cli: lastExit,
                          output: cmp.match ? .match : .differ, status: .appError,
                          appOut: refRender, cliOut: cliText, diff: cmp.diff,
                          note: "Process divergence: the DICOMKit package API \(refOK ? "succeeded" : "failed") but the dicom-mpps CLI lifecycle \(cliOK ? "succeeded" : "failed"). The CLI and the package API must agree on the outcome.")
        }
        let bothFailedIdentically = bothFailed && cmp.match
        let status: BatchRowStatus = bothFailedIdentically ? .failureAgreement
                                   : (cmp.match ? .pass : .outputDrift)
        let note: String
        switch status {
        case .failureAgreement:
            note = "The package API and the CLI both failed the MPPS lifecycle identically (e.g. the server does not accept MPPS, or the AE is not recognised) — parity held on the failure path, but no successful operation occurred, so this row is excluded from the score."
        case .pass:
            note = "The dicom-mpps CLI lifecycle matches the DICOMKit package API reference (create/update outcome, final status and referenced-image count; client-minted UIDs ignored)."
        default:
            note = "The dicom-mpps CLI lifecycle diverges from the DICOMKit package API reference (see diff; client-minted UIDs ignored)."
        }
        return result(s, command: command, input: .match, app: refOK, cli: lastExit,
                      output: cmp.match ? .match : .differ, status: status,
                      appOut: refRender, cliOut: cliText, diff: cmp.diff, note: note)
        #else
        return result(s, command: command, input: .match, app: nil, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: dicom-wado store (STOW-RS) scenario (WRITES — argv expands to a file list)

    /// Runs one `dicom-wado store` scenario. STOW-RS takes file ARGUMENTS (no directory
    /// recursion in the CLI), so the runner expands the selected send file/dir into the
    /// SAME explicit DICOM file list via the shared gatherer, and both the package-API
    /// reference (DICOMwebClient.storeInstances) and the CLI transmit exactly that list.
    private func runWADOStoreScenario(_ s: BatchScenario) async -> BatchScenarioResult {
        #if os(macOS)
        let baseURL = networkWebBaseURL.trimmingCharacters(in: .whitespaces)
        let token = networkWebToken.trimmingCharacters(in: .whitespaces)
        pendingInputUsed = "DICOMweb \(baseURL)"
        let sp = s.studioParams
        let scTimeout = TimeInterval(resolveNet(sp["timeout"] ?? "")) ?? 30

        let sendPath = resolveNet(CLIParityNetworkScenarios.sendFileToken)
        let files = CLIParityNetworkReference.gatherSendFiles(path: sendPath, recursive: true)
        // NOTE: no --verbose — the CLI's "Upload Summary" (Total files / Successful /
        // Failed) prints unconditionally, while --verbose ALSO prints per-failure
        // "    Failed: <SOPUID> - <reason>" detail lines whose "Failed:" prefix would be
        // matched first by parseStore (reading a digit from the SOP UID, not the count).
        let command = (["dicom-wado", "store", baseURL] + files).joined(separator: " ")

        if baseURL.isEmpty {
            return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: "Enter a DICOMweb Base URL to test dicom-wado store (STOW-RS).")
        }
        if files.isEmpty {
            return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: "No DICOM files found in the selected store file/directory — pick a DICOM file (or a directory that contains DICOM files), or clear it to store the bundled synthetic CT.")
        }

        let netUnits = max(1, files.count)
        let snd = await raceDeadline(
            scTimeout * Double(netUnits) + 60,
            fallback: WADOStoreSemantics(sent: files.count, succeeded: 0, failed: files.count)) {
            await CLIParityNetworkReference.wadoStore(baseURL: baseURL, token: token, filePaths: files)
        }
        let refOK = snd.overallOK
        let refRender = CLIParityNetworkReference.renderWADOStore(snd)

        let toolId = s.toolId
        let binDir = freshBinDir
        let cliDeadline = scTimeout * Double(netUnits) + 60
        let cliArgs = ["store", baseURL] + files
        let outcome = await Task.detached {
            CLIToolTerminalCompare.run(tool: toolId, arguments: cliArgs, binDir: binDir, timeout: cliDeadline)
        }.value
        if let launchError = outcome.launchError {
            return result(s, command: command, input: .notApplicable, app: refOK, cli: outcome.exitCode,
                          output: .notApplicable, status: .cliError, appOut: refRender, note: launchError)
        }
        let cliText = combinedCLIText(outcome)
        let cmp = CLIParityWADOComparator.compareStore(
            reference: snd, cli: CLIParityWADOComparator.parseStore(outcome.stdout))
        return networkVerdict(
            s, command: command, refOK: refOK, refRender: refRender,
            cliExit: outcome.exitCode, cliText: cliText, cmp: cmp,
            processNote: "Process divergence: the DICOMKit package API \(refOK ? "succeeded" : "failed") but the dicom-wado store CLI exited \(outcome.exitCode). The CLI and the package API must agree on the outcome.",
            passNote: "The dicom-wado store (STOW-RS) CLI matches the DICOMKit package API reference (upload outcome counts).",
            driftNote: "The dicom-wado store (STOW-RS) CLI diverges from the DICOMKit package API reference (see diff).",
            failAgreeNote: "The package API and the CLI both failed the STOW-RS store identically (e.g. the DICOMweb endpoint is unreachable or rejects the store) — parity held on the failure path, but no successful operation occurred, so this row is excluded from the score.")
        #else
        return result(s, command: "dicom-wado store", input: .match, app: nil, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: dicom-wado UPS-RS create → claim lifecycle (stateful, two-phase, WRITES)

    /// Runs one `dicom-wado ups` create → claim lifecycle. The package-API reference
    /// (createWorkitem → changeWorkitemState IN PROGRESS) and the CLI (`ups
    /// --create-workitem` → `ups --update --state IN_PROGRESS`) each run an INDEPENDENT
    /// claim. The Workitem UID is minted client-side and differs between the two by
    /// design, so it's never compared — the CLI side threads the UID parsed from its own
    /// create output into its claim. Parity is on the outcome (create / claim success,
    /// final state).
    private func runWADOUPSLifecycleScenario(_ s: BatchScenario) async -> BatchScenarioResult {
        let command = (["dicom-wado"] + s.cliArgs.map { resolveNet($0) }).joined(separator: " ")
        #if os(macOS)
        let baseURL = networkWebBaseURL.trimmingCharacters(in: .whitespaces)
        let token = networkWebToken.trimmingCharacters(in: .whitespaces)
        pendingInputUsed = "DICOMweb \(baseURL)"
        let sp = s.studioParams
        let scTimeout = TimeInterval(resolveNet(sp["timeout"] ?? "")) ?? 30
        let label = sp["label"] ?? ""
        let aet = sp["aet"] ?? ""

        if baseURL.isEmpty {
            return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: "Enter a DICOMweb Base URL to test the dicom-wado UPS-RS lifecycle.")
        }

        var scope = WADOScope()
        scope.upsLabel = label
        scope.upsPatientName = sp["patient-name"] ?? ""
        scope.upsPatientID = sp["patient-id"] ?? ""
        scope.upsAET = aet

        let netUnits = 2
        let ref = await raceDeadline(
            scTimeout * Double(netUnits) + 60,
            fallback: CLIParityWADOComparator.lifecycleRecord(createOK: false, claimOK: false, finalState: "")) { [scope] in
            await CLIParityNetworkReference.wadoUPSLifecycle(baseURL: baseURL, token: token, scope: scope)
        }
        let refRender = CLIParityNetworkReference.renderWADOUPS(ref)

        let toolId = s.toolId
        let binDir = freshBinDir
        let cliDeadline = scTimeout * Double(netUnits) + 60

        // Phase 1: create the workitem (SCHEDULED).
        let createArgs = s.cliArgs.map { resolveNet($0) }
        let createOutcome = await Task.detached {
            CLIToolTerminalCompare.run(tool: toolId, arguments: createArgs, binDir: binDir, timeout: cliDeadline)
        }.value
        if let launchError = createOutcome.launchError {
            return result(s, command: command, input: .notApplicable, app: ref.overallOK, cli: createOutcome.exitCode,
                          output: .notApplicable, status: .cliError, appOut: refRender, note: launchError)
        }
        let createText = combinedCLIText(createOutcome)
        let parsedCreate = CLIParityWADOComparator.parseCreate(createText, exitOK: createOutcome.exitCode == 0)

        // Phase 2: claim the workitem (SCHEDULED → IN PROGRESS) using the minted UID.
        var claimText = ""
        var lastExit = createOutcome.exitCode
        var cliClaimOK: Bool? = nil
        var cliFinalState = ""
        if parsedCreate.ok, let uid = parsedCreate.uid {
            var claimArgs = ["ups", baseURL, "--update", uid, "--state", "IN_PROGRESS"]
            if !aet.isEmpty { claimArgs += ["--aet", aet] }
            let claimOutcome = await Task.detached {
                CLIToolTerminalCompare.run(tool: toolId, arguments: claimArgs, binDir: binDir, timeout: cliDeadline)
            }.value
            claimText = combinedCLIText(claimOutcome)
            lastExit = claimOutcome.exitCode
            let pc = CLIParityWADOComparator.parseClaim(claimText, exitOK: claimOutcome.exitCode == 0)
            cliClaimOK = pc.ok
            cliFinalState = pc.ok ? "IN PROGRESS" : ""
        } else {
            // Create failed → no claim attempted; the claim did not succeed.
            cliClaimOK = false
        }

        let cli = CLIParityWADOComparator.lifecycleRecord(
            createOK: parsedCreate.ok, claimOK: cliClaimOK, finalState: cliFinalState)
        let cliText: String = {
            var t = "── create-workitem ──\n" + createText
            t += "\n\n── claim (IN_PROGRESS) ──\n" + (claimText.isEmpty ? "(not run — create failed)" : claimText)
            return t
        }()
        let cmp = CLIParityWADOComparator.compareUPS(reference: ref, cli: cli)
        return networkVerdict(
            s, command: command, refOK: ref.overallOK, refRender: refRender,
            cliExit: lastExit, cliText: cliText, cmp: cmp,
            processNote: "Process divergence: the DICOMKit package API \(ref.overallOK ? "succeeded" : "failed") but the dicom-wado UPS create → claim lifecycle \(cli.overallOK ? "succeeded" : "failed"). The CLI and the package API must agree on the outcome.",
            passNote: "The dicom-wado UPS create → claim lifecycle matches the DICOMKit package API reference (create / claim outcome and final state; client-minted UIDs ignored).",
            driftNote: "The dicom-wado UPS create → claim lifecycle diverges from the DICOMKit package API reference (see diff; client-minted UIDs ignored).",
            failAgreeNote: "The package API and the CLI both failed the UPS lifecycle identically (e.g. UPS-RS is not enabled on the server) — parity held on the failure path, but no successful operation occurred, so this row is excluded from the score.")
        #else
        return result(s, command: command, input: .match, app: nil, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    /// The standard network-row verdict (shared by the dicom-wado store / UPS-lifecycle
    /// runners): PROCESS parity on success/failure, then the semantic record decides
    /// pass / drift, with a both-failed-identically row recorded as .failureAgreement
    /// (excluded from the score so an unreachable endpoint can't inflate the rate).
    private func networkVerdict(_ s: BatchScenario, command: String, refOK: Bool, refRender: String,
                                cliExit: Int32, cliText: String,
                                cmp: (diff: [OutputDiffLine], match: Bool),
                                processNote: String, passNote: String, driftNote: String,
                                failAgreeNote: String) -> BatchScenarioResult {
        let cliOK = cliExit == 0
        let processMatch = (refOK == cliOK)
        if !processMatch {
            return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                          output: cmp.match ? .match : .differ, status: .appError,
                          appOut: refRender, cliOut: cliText, diff: cmp.diff, note: processNote)
        }
        let bothFailedIdentically = (!refOK && !cliOK) && cmp.match
        let status: BatchRowStatus = bothFailedIdentically ? .failureAgreement
                                   : (cmp.match ? .pass : .outputDrift)
        let note = status == .failureAgreement ? failAgreeNote : (status == .pass ? passNote : driftNote)
        return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                      output: cmp.match ? .match : .differ, status: status,
                      appOut: refRender, cliOut: cliText, diff: cmp.diff, note: note)
    }

    /// Counts the DICOM (.dcm) files the dicom-wado CLI wrote into its WADO-RS output
    /// dir — the CLI side of an instances retrieve (the reference counts in memory).
    nonisolated static func countDICOMFiles(inDir dir: String) -> Int {
        guard !dir.isEmpty else { return 0 }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return 0 }
        return items.filter { $0.lowercased().hasSuffix(".dcm") }.count
    }

    // MARK: Output reduction (byte-identical to the golden harness)

    /// Reduces a produced artifact (or stdout) to a comparable string, matching
    /// CLIAutomationTestingViewModel.compareOutput's per-artifactKind handling.
    private func reduce(artifactURL: URL?, stdout: String, kind: String) async -> String {
        guard let u = artifactURL else { return stdout }     // pure stdout tool
        let fm = FileManager.default
        switch kind {
        case "dicom-multi":
            let files = ((try? fm.contentsOfDirectory(atPath: u.path)) ?? [])
                .filter { $0.hasSuffix(".dcm") }.sorted()
            var combined = "Frames: \(files.count)\n"
            for (i, f) in files.enumerated() {
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(f)), fixtureBasenames: [])
                combined += "=== frame \(i) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            return combined
        case "dicom-tree":
            var rels: [String] = []
            if let en = fm.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String { if p.hasSuffix(".dcm") { rels.append(p) } }
            }
            rels.sort()
            var combined = "Files: \(rels.count)\n"
            for rel in rels {
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(rel)), fixtureBasenames: [])
                combined += "=== \(rel) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            return combined
        case "image-multi":   // a DIRECTORY of exported images (dicom-export bulk)
            var rels: [String] = []
            if let en = fm.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String {
                    let lp = p.lowercased()
                    if lp.hasSuffix(".png") || lp.hasSuffix(".jpg") || lp.hasSuffix(".jpeg")
                        || lp.hasSuffix(".tif") || lp.hasSuffix(".tiff") { rels.append(p) }
                }
            }
            rels.sort()
            var combined = "Images: \(rels.count)\n"
            for rel in rels {
                let h = CLIParityEngine.imageRasterHash(fileURL: u.appendingPathComponent(rel)) ?? "<image-decode-failed>"
                combined += "\(rel)\t\(h)\n"
            }
            return combined
        case "decoded-pixel-hash":
            return CLIParityEngine.decodedPixelHash(fileURL: u) ?? "<pixel-decode-failed>"
        case "image-raster-hash":
            return CLIParityEngine.imageRasterHash(fileURL: u) ?? "<image-decode-failed>"
        case "text", "uid-list":
            return (try? String(contentsOf: u, encoding: .utf8)) ?? ""
        default:   // "dicom" and "auto" → re-dump via the shared in-process dicom-info
            return await dump(u)
        }
    }

    /// Re-dumps a produced .dcm via the in-process dicom-info (shared
    /// MetadataPresenter) — the same reduction the golden harness uses, applied
    /// identically to both the app and CLI artifacts.
    private func dump(_ url: URL) async -> String {
        let info = CLIWorkshopViewModel()
        info.selectTool(id: "dicom-info")
        info.updateParameterValue(parameterID: "inputPath", value: url.path)
        await info.executeCommand()
        return info.consoleOutput
    }
}
