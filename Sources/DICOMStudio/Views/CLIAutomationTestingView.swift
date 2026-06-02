// CLIAutomationTestingView.swift
// DICOMStudio
//
// In-app CLI Automation Testing screen: list every DICOMKit CLI tool, run the
// Swift-native parity check (param mismatch) against bundled CLI contracts, and
// verify input/output data for local-file tools (Studio in-process vs golden
// CLI output). No external processes.

import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CLIAutomationTestingView: View {
    @Bindable var viewModel: CLIAutomationTestingViewModel

    public init(viewModel: CLIAutomationTestingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if !viewModel.contractsAvailable {
                missingDataView
            } else {
                HSplitView {
                    sidebar
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                    detail
                        .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { viewModel.loadIfNeeded() }
        .navigationTitle("CLI Automation Testing")
    }

    // MARK: - Missing data

    private var missingDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No bundled CLI parity data").font(.headline)
            Text(viewModel.errorMessage ?? "Regenerate with: swift run cli-parity-gen")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("swift run cli-parity-gen")
                .font(.system(.caption, design: .monospaced))
                .padding(6).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader
            TextField("Filter tools…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
            List(selection: Binding(
                get: { viewModel.selectedToolID },
                set: { if let id = $0 { viewModel.selectTool(id) } }
            )) {
                // Grouped by CLI Workshop tab, in the same order as the CLI
                // Workshop screen, for easy cross-reference.
                ForEach(viewModel.groupedResults, id: \.tab) { group in
                    Section {
                        ForEach(group.tools) { result in
                            toolRow(result).tag(result.toolId)
                        }
                    } header: {
                        Label(group.tab.displayName, systemImage: group.tab.sfSymbol)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .padding(.top, 8)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(viewModel.totalTools) tools")
                    .font(.headline)
                Spacer()
                if viewModel.isAnalyzing { ProgressView().controlSize(.small) }
                Button {
                    viewModel.runParityAnalysis()
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Re-run parity analysis")
            }
            let s = viewModel.summary
            HStack(spacing: 6) {
                summaryChip("\(s.ok)", .green, "OK")
                summaryChip("\(s.drift)", .red, "Drift")
                summaryChip("\(s.incomplete)", .orange, "Incomplete")
                summaryChip("\(s.noParams)", .yellow, "No params")
                summaryChip("\(s.noCli)", .gray, "No CLI")
            }
        }
        .padding(.horizontal, 8)
    }

    private func summaryChip(_ count: String, _ color: Color, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(count).font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func toolRow(_ result: ToolParityResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.status.sfSymbol)
                .foregroundStyle(color(for: result.status))
            VStack(alignment: .leading, spacing: 1) {
                Text(result.displayName).font(.body)
                Text(result.toolId).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(result.parityPercent))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(color(for: result.status))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let result = viewModel.selectedResult {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeader(result)
                    Divider()
                    paramMismatchSection(result)
                    Divider()
                    outputSection(result)
                }
                .padding()
            }
        } else {
            Text("Select a tool to see its parity report.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(_ result: ToolParityResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: result.status.sfSymbol).foregroundStyle(color(for: result.status))
                Text(result.displayName).font(.title2.bold())
                statusBadge(result.status)
                Spacer()
                Text("\(Int(result.parityPercent))% parity")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(color(for: result.status))
            }
            Text(result.status.explanation).font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                metaBadge("binary: \(result.binary)")
                if !result.subcommand.isEmpty { metaBadge("subcmd: \(result.subcommand)") }
                metaBadge("mode: \(result.matchMode)")
                if result.requiresNetwork { metaBadge("network", .blue) }
                metaBadge(result.executeSupported ? "execCmd ✓" : "execCmd ✗",
                          result.executeSupported ? .green : .secondary)
            }
            HStack(spacing: 14) {
                countLabel("Studio flags", result.studioFlagCount, .primary)
                countLabel("CLI flags", result.cliFlagCount, .primary)
                countLabel("Matched", result.matchCount, .green)
                countLabel("Missing", result.missingCount, .orange)
                countLabel("Extra", result.extraCount, .red)
            }
            .font(.caption)
        }
    }

    // MARK: Param mismatch

    private func paramMismatchSection(_ result: ToolParityResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Parameter Mismatch", systemImage: "list.bullet.rectangle")
                .font(.headline)
            if result.rows.isEmpty {
                Text(result.status == .noCliData
                     ? "No bundled CLI contract for this tool."
                     : "No parameters to compare.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Table(result.rows) {
                    TableColumn("Flag") { row in
                        Text(row.flag).font(.system(.body, design: .monospaced))
                    }.width(min: 140, ideal: 180)
                    TableColumn("CLI") { row in symbol(row.inCLI) }.width(36)
                    TableColumn("Studio") { row in symbol(row.inStudio) }.width(46)
                    TableColumn("Status") { row in
                        Text(row.status.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(color(for: row.status))
                    }.width(min: 120, ideal: 140)
                    TableColumn("CLI default") { row in
                        Text(row.cliDefault).font(.caption).foregroundStyle(.secondary)
                    }
                    TableColumn("Studio default") { row in
                        Text(row.studioDefault).font(.caption).foregroundStyle(.secondary)
                    }
                    TableColumn("CLI help") { row in
                        Text(row.cliHelp).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 180, idealHeight: CGFloat(min(result.rows.count, 12) * 28 + 30))
            }
        }
    }

    // MARK: Output verification

    @ViewBuilder
    private func outputSection(_ result: ToolParityResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Input / Output Verification", systemImage: "arrow.left.arrow.right.square")
                    .font(.headline)
                Spacer()
                if viewModel.isRunningOutput { ProgressView().controlSize(.small) }
                Button {
                    let id = result.toolId
                    Task { await viewModel.runOutputVerification(for: id) }
                } label: {
                    Label("Run Output Test", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isRunningOutput || !viewModel.hasOutputScenarios(for: result.toolId))
            }

            if !viewModel.hasOutputScenarios(for: result.toolId) {
                Text("No bundled output scenarios for this tool. Output verification covers local-file tools (dicom-info, dicom-validate) run on the DICOM files in /Users/raster/Desktop/DICOM_Input. Regenerate with: swift run cli-parity-gen")
                    .font(.callout).foregroundStyle(.secondary)
            } else if viewModel.outputComparisons.isEmpty {
                Text("Click “Run Output Test” to run \(result.displayName) on the bundled fixture and compare against the captured CLI output.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.outputComparisons) { comparison in
                    outputComparisonCard(comparison)
                }
            }
        }
    }

    private func outputComparisonCard(_ comparison: OutputComparison) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comparison.inputDescription)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Text(comparison.status.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(outputColor(comparison.status))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(outputColor(comparison.status).opacity(0.15),
                                in: Capsule())
            }
            Text(comparison.note).font(.caption2).foregroundStyle(.secondary)

            if comparison.status == .differs || comparison.status == .match {
                diffView(comparison.diff)
                DisclosureGroup("Raw outputs") {
                    HStack(alignment: .top, spacing: 8) {
                        rawColumn("CLI (golden)", comparison.cliOutput)
                        rawColumn("Studio", comparison.studioOutput)
                    }
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func diffView(_ lines: [OutputDiffLine]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    HStack(alignment: .top, spacing: 4) {
                        Text(prefix(for: line.kind))
                            .frame(width: 14, alignment: .leading)
                        Text(line.text.isEmpty ? " " : line.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(diffColor(line.kind))
                    .background(diffBackground(line.kind))
                    .textSelection(.enabled)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 260)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    private func rawColumn(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.bold()).foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? "(empty)" : text)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 160)
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Small helpers

    private func symbol(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "minus.circle")
            .foregroundStyle(on ? Color.green : Color.secondary)
    }

    private func statusBadge(_ status: ParityStatus) -> some View {
        Text(status.displayName)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color(for: status), in: Capsule())
    }

    private func metaBadge(_ text: String, _ tint: Color = .secondary) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private func countLabel(_ title: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(value)").font(.caption.bold().monospacedDigit()).foregroundStyle(tint)
            Text(title).foregroundStyle(.secondary)
        }
    }

    private func color(for status: ParityStatus) -> Color {
        switch status {
        case .ok: return .green
        case .drift: return .red
        case .incomplete: return .orange
        case .noParams: return .yellow
        case .noCliData: return .gray
        }
    }

    private func color(for status: FlagParityStatus) -> Color {
        switch status {
        case .match: return .green
        case .missingInStudio: return .orange
        case .extraInStudio: return .red
        }
    }

    private func outputColor(_ status: OutputParityStatus) -> Color {
        switch status {
        case .match: return .green
        case .differs: return .red
        case .unavailable: return .secondary
        case .error: return .red
        }
    }

    private func prefix(for kind: DiffLineKind) -> String {
        switch kind {
        case .same: return " "
        case .cliOnly: return "−"
        case .studioOnly: return "+"
        }
    }
    private func diffColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .same: return .primary
        case .cliOnly: return .red
        case .studioOnly: return .blue
        }
    }
    private func diffBackground(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .same: return .clear
        case .cliOnly: return Color.red.opacity(0.10)
        case .studioOnly: return Color.blue.opacity(0.10)
        }
    }
}
