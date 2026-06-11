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

    @State private var showDirImporter = false
    @State private var expandedRows: Set<String> = []

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
        .fileImporter(isPresented: $showDirImporter,
                      allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            Task { await viewModel.setInputDirectory(url: url) }
        }
    }

    // MARK: Banner

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Testing-only — runs the real dicom-* binaries and requires the App Sandbox disabled. Not for production.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
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

                Spacer()

                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label("Run Parity Test", systemImage: "play.fill").font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isRunning || viewModel.isScanning || viewModel.selectedToolIDs.isEmpty)
            }

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
                Button { showDirImporter = true } label: {
                    Label(viewModel.inputDirectory == nil ? "Input Directory (optional)…" : "Change Directory…",
                          systemImage: "folder.badge.plus")
                        .font(.body)
                }
                .controlSize(.large)
                .disabled(viewModel.isScanning || viewModel.isRunning)
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
            rebuildToggle
            toolSelection
        }
    }

    private var networkEndpointForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "network").foregroundStyle(.blue)
                Text("PACS Endpoint").font(.headline)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 10) {
                    labeledField("Host", text: $viewModel.networkHost, width: 220)
                    labeledField("Port", text: $viewModel.networkPort, width: 90)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    labeledField("Calling AE (--aet)", text: $viewModel.networkCallingAET, width: 180)
                    labeledField("Called AE (--called-aet)", text: $viewModel.networkCalledAET, width: 200)
                    labeledField("Timeout (s)", text: $viewModel.networkTimeout, width: 90)
                }
            }
            Text("These credentials are passed to BOTH the app and the dicom-echo CLI. The screen sweeps every valid echo flag and compares the C-ECHO outcome — success/failure, DIMSE status, remote AE — with round-trip time ignored. Edit any field to match your server.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .disabled(viewModel.isRunning)
        }
    }

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
                            }
                            Text(viewModel.inputHint(for: tool.id)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            if viewModel.mode == .network {
                Text("More network tools (query, send, retrieve…) will appear here as their parity is implemented.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
                 ? "Enter your PACS credentials above, then run. Each valid dicom-echo flag (--count, --stats, --verbose, --diagnose, --timeout, AE titles) is swept against the live server and the app vs CLI C-ECHO outcome is compared per scenario, with round-trip time ignored."
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
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                metric("Overall", s.overallPercent, "\(s.passed)/\(s.denominator)", .accentColor, big: true)
                metric("Input", s.inputPercent, "\(s.inputMatched)/\(s.denominator)", .blue)
                metric("Process", s.processPercent, "\(s.processMatched)/\(s.denominator)", .purple)
                metric("Output", s.outputPercent, "\(s.outputMatched)/\(s.outputComparable)", .green)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Skipped \(s.skipped)").font(.callout).foregroundStyle(.secondary)
                    Text("Non-det \(s.nonDeterministic)").font(.callout).foregroundStyle(.secondary)
                    if s.failureAgreement > 0 {
                        Text("Both-failed \(s.failureAgreement)").font(.callout).foregroundStyle(.orange)
                    }
                }
            }
            Text("Denominator excludes Skipped, Non-deterministic and Both-failed rows. A row passes only if Input, Process and Output all match.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func metric(_ label: String, _ pct: Double, _ count: String, _ color: Color, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            Text(String(format: "%.1f%%", pct)).font(big ? .largeTitle.bold() : .title.weight(.semibold)).foregroundStyle(color)
            Text(count).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Results table

    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(viewModel.groupedResults, id: \.toolId) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.displayName(for: group.toolId))
                        .font(.title3.bold())
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
        .font(.subheadline.bold()).foregroundStyle(.secondary)
        .padding(.vertical, 3)
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
        HStack(spacing: 5) {
            Image(systemName: status.sfSymbol).font(.callout)
            Text(status.displayName).font(.callout)
        }
        .foregroundStyle(statusColor(status))
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
