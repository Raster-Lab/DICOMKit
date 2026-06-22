// CLIParityRunnerView.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// The "CLI Parity" screen: pick tool(s) + one input file, then auto-sweep every
// subcommand/flag scenario, running the app AND the real dicom-* binary for each
// and tabulating INPUT / PROCESS / OUTPUT parity with a success rate.

import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CLIParityRunnerView: View {
    @Bindable var viewModel: CLIParityRunnerViewModel

    // Each directory picker is a SEPARATE fileImporter attached to its OWN button.
    // Two pitfalls this avoids: (1) SwiftUI honours only the LAST of several
    // .fileImporter modifiers stacked on the SAME view — so they must live on
    // different views (the offline and send buttons are never on screen at once);
    // (2) a single importer driven by a shared discriminator races on dismiss — the
    // binding that clears the discriminator fires before onCompletion reads it, so
    // the picked directory went unscanned. Plain booleans on separate views fix both.
    // The dicom-wado `store` tab reuses the Send Source picker but gets its OWN pair
    // of booleans (showWadoStore*Importer) so it never collides with dicom-send's even
    // when both forms are on screen — same rule: distinct booleans on distinct buttons.
    @State private var showInputDirImporter = false
    @State private var showSendDirImporter = false
    @State private var showSendFileImporter = false
    @State private var showWadoStoreFileImporter = false
    @State private var showWadoStoreDirImporter = false
    @State private var showRetrieveOutputImporter = false
    @State private var expandedRows: Set<String> = []

    /// Which dicom-wado subcommand's inputs the WADO panel is showing — and the one the
    /// parity sweep runs. Backed by the view model (a String) so `run()` can read it;
    /// the segmented control binds to it through `wadoSubcommandBinding`.
    private var wadoSubcommandBinding: Binding<WADOSubcommand> {
        Binding(
            get: { WADOSubcommand(rawValue: viewModel.wadoSubcommand) ?? .query },
            set: { viewModel.wadoSubcommand = $0.rawValue }
        )
    }

    public init(viewModel: CLIParityRunnerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            warningBanner
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    controls
                    if let msg = viewModel.errorMessage { errorBox(msg) }
                    if viewModel.isBuilding { buildingBar }
                    else if viewModel.isRunning { progressBar }
                    if !viewModel.results.isEmpty {
                        summaryHeader
                        resultsTable
                    } else if !viewModel.isRunning {
                        emptyState
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("CLI Parity")
    }

    // MARK: Banner

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout.weight(.bold))
            Text("Testing-only — runs the real dicom-* binaries and requires the App Sandbox disabled. Not for production.")
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(
            LinearGradient(colors: [Color.orange.opacity(0.22), Color.orange.opacity(0.12)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .overlay(alignment: .bottom) { Rectangle().fill(Color.orange.opacity(0.35)).frame(height: 1) }
        .foregroundStyle(.orange)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mode", selection: Binding(
                get: { viewModel.mode },
                set: { viewModel.setMode($0) }
            )) {
                ForEach(ParityMode.allCases) { m in Text(m.displayName).tag(m) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .disabled(viewModel.isRunning)

            if viewModel.mode == .offline {
                offlineControls
            } else {
                networkControls
            }
        }
    }

    // MARK: Offline-mode controls

    private var offlineControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button { showInputDirImporter = true } label: {
                    Label(viewModel.inputDirectory == nil ? "Input Directory (optional)…" : "Change Directory…",
                          systemImage: "folder.badge.plus")
                        .font(.body)
                }
                .controlSize(.large)
                .disabled(viewModel.isScanning || viewModel.isRunning)
                .fileImporter(isPresented: $showInputDirImporter,
                              allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    guard case let .success(urls) = result, let url = urls.first else { return }
                    Task { await viewModel.setInputDirectory(url: url) }
                }
                if viewModel.inputDirectory != nil {
                    Button { viewModel.clearInputDirectory() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
            }

            corpusStatus

            rebuildToggle

            Toggle(isOn: $viewModel.includeFixtureVariants) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include real + synthetic fixture variants").font(.body)
                    Text("Off: one row per unique validated command. On: also runs each command on its real fixture (the full parity-test matrix).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(viewModel.isRunning)

            toolSelection
        }
    }

    // MARK: Network-mode controls

    private var networkControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            networkEndpointForm
            // dicom-wado is self-contained: its query/retrieve/store/ups inputs all live
            // in the segmented WADO panel below, so it no longer triggers these shared forms.
            if viewModel.selectedToolIDs.contains("dicom-query")
                || viewModel.selectedToolIDs.contains("dicom-qr") {
                queryKeysForm
            }
            // dicom-qr's interactive retrieve adds a Move Destination AE (C-MOVE).
            if viewModel.selectedToolIDs.contains("dicom-qr") {
                qrScopeForm
            }
            if viewModel.selectedToolIDs.contains("dicom-send") {
                sendInput
            }
            if viewModel.selectedToolIDs.contains("dicom-retrieve") {
                retrieveScopeForm
            }
            if viewModel.selectedToolIDs.contains("dicom-mwl") {
                worklistKeysForm
            }
            if viewModel.selectedToolIDs.contains("dicom-mpps") {
                mppsScopeForm
            }
            if viewModel.selectedToolIDs.contains("dicom-wado") {
                wadoForm
            }
            rebuildToggle
            toolSelection
        }
    }

    private var networkEndpointForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "network").foregroundStyle(.blue).font(.title3)
                Text("PACS Endpoint").font(.title3.bold())
                Spacer()
            }
            HStack(spacing: 8) {
                Text("Server").font(.callout).foregroundStyle(.secondary)
                Picker("Server", selection: Binding(
                    get: { viewModel.selectedServerID },
                    set: { viewModel.selectServer($0) }
                )) {
                    ForEach(CLIParityRunnerViewModel.serverPresets) { Text($0.id).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                // dicom-mpps pins the endpoint to one preset — lock the picker while it's selected.
                .disabled(viewModel.isRunning || viewModel.lockedServerID != nil)
                if let locked = viewModel.lockedServerID {
                    Label("Locked to \(locked) (dicom-mpps)", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Host", text: $viewModel.networkHost)
                labeledField("Port", text: $viewModel.networkPort)
                labeledField("Calling AE (--aet)", text: $viewModel.networkCallingAET)
                labeledField("Called AE (--called-aet)", text: $viewModel.networkCalledAET)
                labeledField("Timeout (s)", text: $viewModel.networkTimeout)
            }
            Text("Pick a server preset, or edit any field. These credentials drive BOTH the DICOMKit package-API reference and the dicom-* CLI; each selected network tool is swept and compared semantically against the live server.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private var queryKeysForm: some View {
        var consumers: [String] = []
        if viewModel.selectedToolIDs.contains("dicom-query") { consumers.append("dicom-query") }
        if viewModel.selectedToolIDs.contains("dicom-qr") { consumers.append("dicom-qr") }
        let title = "Query Keys (" + (consumers.isEmpty ? "dicom-query" : consumers.joined(separator: " · ")) + ")"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.blue).font(.title3)
                Text(title).font(.title3.bold())
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Patient Name", text: $viewModel.queryPatientName)
                labeledField("Patient ID", text: $viewModel.queryPatientID)
                labeledField("Study Date (YYYYMMDD / range)", text: $viewModel.queryStudyDate)
                labeledField("Modality", text: $viewModel.queryModality)
                labeledField("Accession #", text: $viewModel.queryAccession)
                labeledField("Study Description", text: $viewModel.queryStudyDescription)
                labeledField("Study UID (series / instance)", text: $viewModel.queryStudyUID)
                labeledField("Series UID (instance)", text: $viewModel.querySeriesUID)
            }
            Text("C-FIND query keys. Enter values that exist on your PACS so the query returns real matches; blank fields are skipped. dicom-query sweeps a broad study query, each provided filter, the four --format renderings, the patient level, and the series / instance levels (once you supply the matching Study UID / Series UID). dicom-qr uses these same study-level keys for its read-only --review sweep and its interactive select-all retrieve (see the dicom-qr scope below). Results are compared app-vs-CLI, ordering ignored.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    /// dicom-qr input: the Move Destination AE for the interactive C-MOVE retrieve,
    /// plus a note on the review + interactive (select-all) sweep and its write warning.
    /// The query keys themselves come from the shared Query Keys form above.
    private var qrScopeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.on.square").foregroundStyle(.blue).font(.title3)
                Text("Query-Retrieve Scope (dicom-qr)").font(.title3.bold())
                Spacer()
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Move Destination AE (interactive C-MOVE)", text: $viewModel.qrMoveDest)
            }
            Text("dicom-qr is the integrated query-retrieve tool. The sweep runs its read-only --review C-FIND (a broad query + one per supplied filter), then two --interactive rows that exercise the full query → select → retrieve flow: the study-selection prompt is auto-answered \"all\" on BOTH sides, and every matched study is retrieved — once by C-GET (pulls files to a scratch folder) and once by C-MOVE (forwards them to the Move Destination AE). Parity compares the matched set and the retrieve outcome (Total / Success / Failed), ordering ignored.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("The interactive rows RETRIEVE every matched study, so enter at least one Query Key above to bound the match set (otherwise they're skipped to avoid moving the whole PACS). C-GET writes pulled files to a temporary scratch folder (removed after the run); C-MOVE asks the PACS to forward the instances to the Move Destination AE.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    /// dicom-retrieve input: the Study/Series/Instance UIDs to pull and the C-MOVE
    /// destination AE, plus the pull/write warning.
    private var retrieveScopeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle").foregroundStyle(.blue).font(.title3)
                Text("Retrieve Scope (dicom-retrieve)").font(.title3.bold())
                Spacer()
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Study UID (required)", text: $viewModel.retrieveStudyUID)
                labeledField("Series UID (optional)", text: $viewModel.retrieveSeriesUID)
                labeledField("Instance UID (optional)", text: $viewModel.retrieveInstanceUID)
                labeledField("Move Destination AE (C-MOVE)", text: $viewModel.retrieveMoveDest)
                transferSyntaxPicker
            }
            Text("Enter a Study UID that exists on your PACS. The sweep runs C-GET and C-MOVE at the study level (plus series / instance once you supply those UIDs), comparing the retrieved sub-operation counts app-vs-CLI. C-MOVE rows need a Move Destination AE the PACS is configured to forward to; C-GET rows need none and are skipped with guidance when a destination is missing. The transfer syntax (all DICOMKit-supported syntaxes) is requested by the C-GET rows; the PACS may honour it or fall back.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Output directory the C-GET files are written to.
            HStack(spacing: 12) {
                Button { showRetrieveOutputImporter = true } label: {
                    Label(viewModel.retrieveOutputPath == nil ? "Select Output Folder…" : "Change Output Folder…",
                          systemImage: "folder.badge.gearshape").font(.body)
                }
                .controlSize(.large)
                .disabled(viewModel.isRunning)
                .fileImporter(isPresented: $showRetrieveOutputImporter,
                              allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    guard case let .success(urls) = result, let url = urls.first else { return }
                    viewModel.setRetrieveOutput(url: url)
                }
                if viewModel.retrieveOutputPath != nil {
                    Button { viewModel.clearRetrieveOutput() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Clear — retrieve into a temporary scratch folder instead")
                        .disabled(viewModel.isRunning)
                }
                Spacer()
            }
            if let out = viewModel.retrieveOutputPath {
                Label("\((out as NSString).lastPathComponent) — retrieved C-GET files are kept here.", systemImage: "folder")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No output folder selected — C-GET retrieves into a temporary scratch folder that's removed after the run. Pick a folder to keep the retrieved files.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("dicom-retrieve PULLS data: the C-GET scenarios write the retrieved files to the output folder above (a scratch folder when none is selected); the C-MOVE scenarios ask the PACS to send the instances to the Move Destination AE.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    /// Transfer-syntax dropdown for C-GET, populated from DICOMKit's TransferSyntax.allKnown.
    private var transferSyntaxPicker: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Transfer Syntax (C-GET)").font(.callout).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
            Picker("Transfer Syntax", selection: $viewModel.retrieveTransferSyntax) {
                ForEach(viewModel.transferSyntaxOptions) { opt in
                    Text(opt.name).tag(opt.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(viewModel.isRunning)
        }
    }

    /// dicom-mwl input: the worklist C-FIND filters (all optional — a broad query runs
    /// with none). Read-only, so no write warning.
    private var worklistKeysForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard").foregroundStyle(.blue).font(.title3)
                Text("Worklist Filters (dicom-mwl)").font(.title3.bold())
                Spacer()
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Date (YYYYMMDD / today / tomorrow)", text: $viewModel.mwlDate)
                labeledField("Scheduled Station AE", text: $viewModel.mwlStation)
                labeledField("Patient Name (wildcards *)", text: $viewModel.mwlPatientName)
                labeledField("Patient ID", text: $viewModel.mwlPatientID)
                labeledField("Modality (CT, MR, US…)", text: $viewModel.mwlModality)
                labeledField("SPS Status", text: $viewModel.mwlSPSStatus)
                labeledField("Accession #", text: $viewModel.mwlAccession)
            }
            Text("Read-only Modality Worklist C-FIND. Enter values that match scheduled procedure steps on your worklist SCP so the query returns real items; blank fields are skipped. The sweep runs a broad query, one query per provided filter, and a combined query when ≥2 filters are given. Matched worklist items are compared app-vs-CLI by Study UID + SPS ID + Accession, ordering ignored.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    /// dicom-mpps input: the Study UID + procedure attributes for the performed
    /// procedure step lifecycle, plus the write-to-server warning.
    private var mppsScopeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.2.circlepath").foregroundStyle(.blue).font(.title3)
                Text("MPPS Scope (dicom-mpps)").font(.title3.bold())
                Spacer()
            }
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Study UID (required)", text: $viewModel.mppsStudyUID)
                labeledField("Patient Name", text: $viewModel.mppsPatientName)
                labeledField("Patient ID", text: $viewModel.mppsPatientID)
                labeledField("Accession #", text: $viewModel.mppsAccession)
                labeledField("Scheduled Proc. Step ID", text: $viewModel.mppsSPSID)
                labeledField("Series UID (referenced images)", text: $viewModel.mppsSeriesUID)
                labeledField("Image UIDs (comma-separated)", text: $viewModel.mppsImageUIDs)
            }
            Text("Enter a Study UID that exists on your PACS/RIS. The sweep runs the full MPPS lifecycle: a create-only (N-CREATE, stays IN PROGRESS), a create → complete, and a create → discontinue. Supply a Series UID + Image UIDs to add a create → complete with referenced images. The update (N-SET) reuses the SOP Instance UID minted by its own create to transition the step. Each side mints its own MPPS instance, so the client-generated SOP Instance UID is ignored; parity compares the create/update outcome, the final status and the referenced-image count.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("dicom-mpps runs only against the DCM4CHEE5 MWL server (172.17.1.111 · WORKLIST) — selecting it locks the endpoint above to that preset.", systemImage: "lock.fill")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("dicom-mpps WRITES to the server: every scenario creates a performed procedure step (N-CREATE) and the lifecycle rows transition it to COMPLETED / DISCONTINUED (N-SET). Real MPPS instances are created on the PACS/RIS.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    /// The four dicom-wado subcommands, used to drive the WADO panel's segmented switch.
    /// The selected subcommand both shows its inputs AND scopes the parity sweep — only
    /// that subcommand's scenarios run (its value lives in the view model so `run()`
    /// reads it). Other subcommands' inputs are retained, just not swept.
    private enum WADOSubcommand: String, CaseIterable, Identifiable {
        case query, retrieve, store, ups
        var id: String { rawValue }
        /// Short verb shown in the segmented control.
        var verb: String { rawValue }
        /// The DICOMweb protocol the verb maps to, shown in the section header.
        var proto: String {
            switch self {
            case .query: return "QIDO-RS"
            case .retrieve: return "WADO-RS"
            case .store: return "STOW-RS"
            case .ups: return "UPS-RS"
            }
        }
    }

    /// dicom-wado (DICOMweb) input: the shared Base URL + bearer token (Connection), then a
    /// segmented switch that shows ONE subcommand's inputs at a time so each is easy to read
    /// and edit while testing — query (QIDO-RS) reuses the C-FIND/QIDO query keys, retrieve
    /// (WADO-RS) the Study/Series/Instance scope, store (STOW-RS) the Send Source picker, and
    /// ups (UPS-RS) the create → claim lifecycle. The sweep runs the SELECTED subcommand only.
    private var wadoForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe").foregroundStyle(.blue).font(.title3)
                Text("DICOMweb Endpoint (dicom-wado)").font(.title3.bold())
                Spacer()
            }

            // Connection — shared by all four subcommands. Base URL gets its OWN full-width
            // row (not the compact ~300pt grid cell) so the whole …/aets/<AET>/rs path shows.
            labeledField("Base URL (…/dcm4chee-arc/aets/AET/rs)", text: $viewModel.networkWebBaseURL)
            labeledField("Bearer Token (optional)", text: $viewModel.networkWebToken)

            Text("dicom-wado is ONE binary with four subcommands, all hitting the Base URL above (a separate HTTP service from the DIMSE host/port; dcm4chee exposes it under /dcm4chee-arc/aets/<AET>/rs). Pick a subcommand below to edit its inputs and run its scenarios — the parity sweep runs the SELECTED subcommand only, comparing the DICOMKit package-API reference app-vs-CLI per scenario (ordering ignored). Switch tabs to test another; your inputs for the others are kept.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Picker("WADO subcommand", selection: wadoSubcommandBinding) {
                ForEach(WADOSubcommand.allCases) { Text($0.verb).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(viewModel.isRunning)

            switch wadoSubcommandBinding.wrappedValue {
            case .query:    wadoQuerySection
            case .retrieve: wadoRetrieveSection
            case .store:    wadoStoreSection
            case .ups:      wadoUPSSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    /// Header (verb · protocol) + explanatory note shown atop each WADO subcommand section.
    private func wadoSectionHeader(_ sub: WADOSubcommand, systemImage: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).foregroundStyle(.blue)
                Text(sub.verb).font(.callout.bold())
                Text("· \(sub.proto)").font(.callout).foregroundStyle(.secondary)
            }
            Text(note).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// query (QIDO-RS) — read-only, reuses the C-FIND/QIDO query keys (same bindings the
    /// dicom-query / dicom-qr Query Keys form uses).
    private var wadoQuerySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            wadoSectionHeader(.query, systemImage: "magnifyingglass",
                "Read-only search. Sweeps a broad study query, one query per provided filter, a combined query (≥2 filters), the study / series / instance levels (once Study / Series UID are supplied), and the --format renderings. Blank fields are skipped.")
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Patient Name", text: $viewModel.queryPatientName)
                labeledField("Patient ID", text: $viewModel.queryPatientID)
                labeledField("Study Date (YYYYMMDD / range)", text: $viewModel.queryStudyDate)
                labeledField("Modality", text: $viewModel.queryModality)
                labeledField("Accession #", text: $viewModel.queryAccession)
                labeledField("Study Description", text: $viewModel.queryStudyDescription)
                labeledField("Study UID (series / instance)", text: $viewModel.queryStudyUID)
                labeledField("Series UID (instance)", text: $viewModel.querySeriesUID)
            }
        }
    }

    /// retrieve (WADO-RS) — pulls a Study / Series / Instance scope. Study & Series UID are
    /// the SAME bindings as the query tab; only the SOP Instance UID is WADO-retrieve specific.
    private var wadoRetrieveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            wadoSectionHeader(.retrieve, systemImage: "arrow.down.circle",
                "Pulls the Study / Series / Instance scope and writes the files to a temporary scratch folder (removed after the run). Study & Series UID are shared with the query tab; supply the next-level UID to deepen the retrieve.")
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Study UID", text: $viewModel.queryStudyUID)
                labeledField("Series UID (series / instance level)", text: $viewModel.querySeriesUID)
                labeledField("SOP Instance UID (instance level)", text: $viewModel.wadoInstanceUID)
            }
        }
    }

    /// store (STOW-RS) — uploads the Send Source over HTTP. Reuses the dicom-send picker but
    /// with its OWN importer booleans so the two .fileImporters never collide.
    private var wadoStoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            wadoSectionHeader(.store, systemImage: "arrow.up.doc",
                "WRITES to the server: uploads the selected DICOM file/directory via DICOMweb STOW-RS (deduplicated on repeats — a file with the same SOP Instance UID won't create a new instance). Falls back to the bundled synthetic CT when nothing is picked.")
            sendSourcePicker(fileImporter: $showWadoStoreFileImporter, dirImporter: $showWadoStoreDirImporter)
        }
    }

    /// ups (UPS-RS) — read-only search by default; a Procedure Step Label adds the
    /// create → claim write lifecycle.
    private var wadoUPSSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            wadoSectionHeader(.ups, systemImage: "checklist",
                "Leave the label blank to sweep only the read-only ups --search. Supplying a Procedure Step Label adds a create → claim lifecycle (WRITES): it N-CREATEs a workitem (SCHEDULED) then claims it (→ IN PROGRESS). Each side mints its own Workitem UID, so it's ignored; parity compares the create / claim outcome and final state.")
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                labeledField("Procedure Step Label (enables claim)", text: $viewModel.wadoUPSLabel)
                labeledField("Patient Name", text: $viewModel.wadoUPSPatientName)
                labeledField("Patient ID", text: $viewModel.wadoUPSPatientID)
                labeledField("Requesting AE (claim)", text: $viewModel.wadoUPSAET)
            }
        }
    }

    /// dicom-send input: an optional DICOM FILE or DIRECTORY to transmit (falls back to
    /// the bundled synthetic CT when empty), plus the write-to-server warning. The
    /// dicom-wado `store` tab renders the same picker (see `sendSourcePicker`) under the
    /// WADO panel, so this standalone form is now dicom-send only.
    private var sendInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane").foregroundStyle(.blue).font(.title3)
                Text("Send Source (dicom-send)").font(.title3.bold())
                Spacer()
            }

            sendSourcePicker(fileImporter: $showSendFileImporter, dirImporter: $showSendDirImporter)

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("WRITES to the server: the real-send scenarios upload the selected file(s) via DIMSE C-STORE to the PACS. dicom-send includes a --dry-run scenario that writes nothing.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    /// The Send Source picker buttons + selected-file status, shared by the dicom-send
    /// `sendInput` form and the dicom-wado `store` tab. Each caller passes its OWN pair
    /// of importer booleans so the two .fileImporters never collide (see the note at the
    /// top of this type); both write to the same `viewModel.sendInput*` state.
    @ViewBuilder
    private func sendSourcePicker(fileImporter: Binding<Bool>, dirImporter: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Button { fileImporter.wrappedValue = true } label: {
                Label("Select DICOM File…", systemImage: "doc.badge.plus").font(.body)
            }
            .controlSize(.large)
            .disabled(viewModel.isRunning)
            .fileImporter(isPresented: fileImporter,
                          allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                Task { await viewModel.setSendInput(url: url, isDirectory: false) }
            }

            Button { dirImporter.wrappedValue = true } label: {
                Label("Select Directory…", systemImage: "folder.badge.plus").font(.body)
            }
            .controlSize(.large)
            .disabled(viewModel.isRunning)
            .fileImporter(isPresented: dirImporter,
                          allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                Task { await viewModel.setSendInput(url: url, isDirectory: true) }
            }

            if viewModel.sendInputPath != nil {
                Button { viewModel.clearSendInput() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Clear — fall back to the bundled synthetic CT")
                    .disabled(viewModel.isRunning)
            }
            Spacer()
        }

        if let path = viewModel.sendInputPath {
            let kind = viewModel.sendInputIsDirectory ? "directory" : "file"
            let recursiveNote = viewModel.sendInputIsDirectory ? " (recursive)" : ""
            Label {
                Text("\((path as NSString).lastPathComponent) — \(kind), \(viewModel.sendInputFileCount) DICOM file(s) will be sent\(recursiveNote).")
                    .font(.callout).foregroundStyle(viewModel.sendInputFileCount == 0 ? .orange : .secondary)
            } icon: {
                Image(systemName: viewModel.sendInputFileCount == 0 ? "exclamationmark.triangle.fill"
                                : (viewModel.sendInputIsDirectory ? "folder" : "doc"))
                    .foregroundStyle(viewModel.sendInputFileCount == 0 ? .orange : .secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("No file or directory selected — sends the bundled synthetic CT (syn-ct.dcm). Pick a single DICOM file or a directory to send your own DICOM instead (C-STORE for dicom-send, STOW-RS for dicom-wado store).")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.callout).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: width ?? .infinity)
                .disabled(viewModel.isRunning)
        }
    }

    /// Adaptive grid: compact field boxes (~min width) that fill the row and wrap.
    private let fieldColumns = [GridItem(.adaptive(minimum: 190, maximum: 300), spacing: 14, alignment: .leading)]

    private var rebuildToggle: some View {
        Toggle(isOn: $viewModel.rebuildBeforeRun) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rebuild binaries first").font(.body)
                Text("Builds the selected tools fresh (swift build) so results are never stale.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(viewModel.isRunning)
    }

    @ViewBuilder
    private var corpusStatus: some View {
        if viewModel.isScanning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(viewModel.scanMessage).font(.callout).foregroundStyle(.secondary)
            }
        } else if let dir = viewModel.inputDirectory, let c = viewModel.corpus {
            VStack(alignment: .leading, spacing: 2) {
                Text((dir as NSString).lastPathComponent)
                    .font(.callout.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Text(c.summary).font(.callout).foregroundStyle(.secondary)
            }
        } else {
            Text("No directory — each tool uses its bundled synthetic fixture. Pick a directory to test your own corpus: the app draws the right shape per tool (single file, two files, multiframe, RLE, study folder), falling back to bundled where your corpus lacks one.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var toolSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tools (\(viewModel.selectedToolIDs.count)/\(viewModel.activeTools.count) selected)")
                    .font(.headline)
                Spacer()
                Button("Select All") { viewModel.selectAllTools() }
                Button("Clear") { viewModel.clearToolSelection() }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 8) {
                ForEach(viewModel.activeTools) { tool in
                    let ready = viewModel.mode != .network || viewModel.networkParityReady(tool.id)
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedToolIDs.contains(tool.id) },
                        set: { _ in viewModel.toggleTool(tool.id) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                if tool.requiresNetwork {
                                    Image(systemName: "network").font(.caption2).foregroundStyle(.blue)
                                }
                                Text(tool.id).font(.body.monospaced())
                                if !ready {
                                    Text("coming soon").font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(Color.secondary.opacity(0.18)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(ready ? viewModel.inputHint(for: tool.id) : "Parity reference not implemented yet")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.55)
                }
            }
            if viewModel.mode == .network {
                Text("The DIMSE tools plus the single dicom-wado DICOMweb binary are listed (its QIDO / WADO-RS / STOW / UPS subcommands are swept as scenarios — not as separate tools). Greyed “coming soon” tools don't have a parity reference yet; echo, query, send, retrieve, query-retrieve, worklist, MPPS and dicom-wado are ready to run.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.run() }
            } label: {
                Label("Run Parity Test", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning || viewModel.isScanning || viewModel.selectedToolIDs.isEmpty)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func errorBox(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
            Text(msg).font(.body).textSelection(.enabled)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
    }

    private var buildingBar: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(viewModel.buildMessage.isEmpty ? "Building binaries…" : viewModel.buildMessage)
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(viewModel.completedScenarios),
                         total: Double(max(viewModel.totalScenarios, 1)))
            Text("Running \(viewModel.completedScenarios)/\(viewModel.totalScenarios) scenarios…")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.mode == .network ? "network" : "rectangle.split.2x1")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Select tools and run.").font(.title3).foregroundStyle(.secondary)
            Text(viewModel.mode == .network
                 ? "Enter your PACS credentials above, then run. Each selected tool is swept flag-by-flag against the live server and the DICOMKit package-API reference vs the real CLI is compared per scenario, with timing ignored: echo (C-ECHO flags), query (C-FIND keys/levels/formats), send (C-STORE), retrieve (C-MOVE/C-GET by level), query-retrieve (C-FIND review + interactive select-all C-MOVE/C-GET), worklist (MWL C-FIND filters), MPPS (N-CREATE / N-SET lifecycle), and dicom-wado (DICOMweb QIDO-RS query, WADO-RS retrieve, STOW-RS store, UPS-RS worklist). Supply query keys / a retrieve scope / worklist filters / an MPPS scope / a DICOMweb base URL for the tools that need them."
                 : "Each tool runs against the correct input shape (CT, multiframe, study dir, two files, …); its subcommands & flags are swept one by one and App vs CLI is compared per scenario. Pick an input directory to test your own corpus, or leave it empty to use bundled fixtures.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
    }

    // MARK: Summary

    private var summaryHeader: some View {
        let s = viewModel.summary
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                metric("Overall", s.overallPercent, "\(s.passed)/\(s.denominator)", .accentColor, big: true)
                metric("Input", s.inputPercent, "\(s.inputMatched)/\(s.denominator)", .blue)
                metric("Process", s.processPercent, "\(s.processMatched)/\(s.denominator)", .purple)
                metric("Output", s.outputPercent, "\(s.outputMatched)/\(s.outputComparable)", .green)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Skipped \(s.skipped)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Non-det \(s.nonDeterministic)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    if s.failureAgreement > 0 {
                        Text("Both-failed \(s.failureAgreement)").font(.caption.monospaced().weight(.semibold)).foregroundStyle(.orange)
                    }
                }
                .padding(.top, 4)
            }
            Text("Denominator excludes Skipped, Non-deterministic and Both-failed rows. A row passes only if Input, Process and Output all match.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.12), lineWidth: 0.5))
    }

    private func metric(_ label: String, _ pct: Double, _ count: String, _ color: Color, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f%%", pct))
                .font((big ? Font.largeTitle : Font.title).weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(count).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(minWidth: big ? 116 : 96, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.18), lineWidth: 0.5))
    }

    // MARK: Results table

    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(viewModel.groupedResults, id: \.toolId) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3, height: 18)
                        Image(systemName: "terminal").font(.body).foregroundStyle(Color.accentColor)
                        Text(group.toolId).font(.title3.weight(.bold).monospaced())
                        let passed = group.rows.filter { $0.status == .pass }.count
                        Text("\(passed)/\(group.rows.count) pass")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    columnHeader
                    ForEach(group.rows) { row in
                        rowView(row)
                        Divider()
                    }
                }
            }
        }
    }

    // Shared column widths (header + rows must match).
    private let wInput: CGFloat = 70
    private let wProcess: CGFloat = 110
    private let wOutput: CGFloat = 70
    private let wStatus: CGFloat = 160

    private var columnHeader: some View {
        HStack(spacing: 10) {
            Text("Scenario").frame(maxWidth: .infinity, alignment: .leading)
            Text("Input").frame(width: wInput, alignment: .center)
            Text("Process").frame(width: wProcess, alignment: .center)
            Text("Output").frame(width: wOutput, alignment: .center)
            Text("Status").frame(width: wStatus, alignment: .leading)
        }
        .font(.caption.weight(.bold)).tracking(0.5).textCase(.uppercase)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
    }

    @ViewBuilder
    private func rowView(_ row: BatchScenarioResult) -> some View {
        let expanded = expandedRows.contains(row.scenarioId)
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if expanded { expandedRows.remove(row.scenarioId) } else { expandedRows.insert(row.scenarioId) }
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.callout).foregroundStyle(.secondary)
                        Text(row.label).font(.body.monospaced()).lineLimit(1).truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    signalCell(row.inputSignal).frame(width: wInput)
                    Text(processText(row)).font(.callout.monospaced()).frame(width: wProcess, alignment: .center)
                    signalCell(row.outputSignal).frame(width: wOutput)
                    statusChip(row.status).frame(width: wStatus, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                expandedDetail(row)
            }
        }
        .padding(.vertical, 3)
    }

    private func processText(_ row: BatchScenarioResult) -> String {
        let app = row.appSucceeded == nil ? "—" : (row.appSucceeded! ? "ok" : "err")
        let cli = row.cliExitCode == nil ? "—" : String(row.cliExitCode!)
        return "\(app)/\(cli)"
    }

    private func signalCell(_ s: BatchSignal) -> some View {
        switch s {
        case .match:         return Text("✓").font(.title3).foregroundStyle(.green).bold()
        case .differ:        return Text("✗").font(.title3).foregroundStyle(.red).bold()
        case .notApplicable: return Text("—").font(.title3).foregroundStyle(.secondary)
        }
    }

    private func statusChip(_ status: BatchRowStatus) -> some View {
        let color = statusColor(status)
        return HStack(spacing: 5) {
            Image(systemName: status.sfSymbol).font(.caption.weight(.semibold))
            Text(status.displayName).font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 0.5))
    }

    private func statusColor(_ status: BatchRowStatus) -> Color {
        switch status {
        case .pass:             return .green
        case .outputDrift:      return .orange
        case .inputDrift:       return .red
        case .appError:         return .red
        case .cliError:         return .secondary
        case .skipped:          return .secondary
        case .nonDeterministic: return .purple
        case .failureAgreement: return .orange
        }
    }

    @ViewBuilder
    private func expandedDetail(_ row: BatchScenarioResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.commandLine).font(.callout.monospaced())
                .foregroundStyle(.secondary).textSelection(.enabled)
            if !row.inputUsed.isEmpty {
                Label("input: \(row.inputUsed)", systemImage: "doc")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !row.note.isEmpty {
                Text(row.note).font(.callout).foregroundStyle(.secondary)
            }
            if !row.diff.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(row.diff) { line in
                        diffLine(line)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
            }
            // For any non-Pass row, show the exact CLI (and app) output so the user
            // can see precisely what happened (the error/usage text, etc.).
            if row.status != .pass {
                if !row.cliOutput.isEmpty { outputPane("CLI output", row.cliOutput, .orange) }
                if !row.appOutput.isEmpty { outputPane("App output", row.appOutput, .blue) }
            }
        }
        .padding(.leading, 22).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outputPane(_ title: String, _ text: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.bold()).foregroundStyle(accent)
            ScrollView(.vertical) {
                Text(text)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.05)))
        }
    }

    private func diffLine(_ line: OutputDiffLine) -> some View {
        let (prefix, color): (String, Color) = {
            switch line.kind {
            case .same:       return ("  ", .secondary)
            case .cliOnly:    return ("- ", .red)        // present in CLI, missing from app
            case .studioOnly: return ("+ ", .blue)       // present in app, missing from CLI
            }
        }()
        return Text(prefix + line.text)
            .font(.callout.monospaced())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1).truncationMode(.middle)
            .textSelection(.enabled)
    }
}
