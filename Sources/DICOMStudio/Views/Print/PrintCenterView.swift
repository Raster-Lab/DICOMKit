// PrintCenterView.swift
// DICOMStudio
//
// DICOM Studio — the standalone Print screen: manage printers and review
// submitted jobs. Printing itself starts in the viewer, where images are marked.

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct PrintCenterView: View {
    @Bindable var viewModel: PrintViewModel

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init(viewModel: PrintViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        // Pinned to the top of the detail column. Without this the VStack takes
        // only the height its content needs and the split view centres what is
        // left over, which on a tall window drops the whole screen — title and
        // all — into the middle with a band of empty space above it. An empty
        // queue makes it worst, since that is when the content is shortest.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(navigationTitle)
        .onAppear {
            viewModel.loadPrinters()
            viewModel.startMonitoring()
        }
        // Polling opens associations on someone's printer, so it stops with the
        // screen rather than running for the life of the app.
        .onDisappear { viewModel.stopMonitoring() }
    }

    /// The pane's title — what the screen is currently doing, not just what it
    /// is. Shares its wording with the sidebar row via `activitySummary`.
    private var navigationTitle: String {
        guard let state = viewModel.queue.activitySummary else { return "Print" }
        return "Print — \(state)"
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DICOM Print")
                    .font(.title2.bold())
                Text("Manage printers and review submitted jobs. "
                     + "To print, mark images in the viewer and press ⌘P.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            #if os(macOS)
            Spacer()
            // The preview is a window of its own, so it can be raised from here
            // as well — and raised again after it has been closed, without
            // going back to the viewer to re-press ⌘P.
            Button {
                openWindow(id: StudioWindowID.printPreview)
            } label: {
                Label("Print Preview", systemImage: "macwindow")
            }
            .disabled(viewModel.selection.isEmpty)
            .help(viewModel.selection.isEmpty
                  ? "Mark images in the viewer to compose a film"
                  : "Open the film preview in its own window")
            #endif
        }
        .padding()
    }

    private var content: some View {
        HSplitView {
            // The printer list is a few short rows; the queue is the working
            // area. An even split gives the sidebar width it has no use for, so
            // it opens narrow — still draggable, since the user may want to read
            // a long printer line in full.
            printersPane
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 420,
                       maxHeight: .infinity, alignment: .top)
            activityPane
                .frame(minWidth: 420, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Activity

    /// What the right-hand pane shows.
    private enum ActivityTab: String, CaseIterable, Identifiable {
        case queue, history, audit

        var id: String { rawValue }

        var title: String {
            switch self {
            case .queue:   return "Queue"
            case .history: return "History"
            case .audit:   return "Audit Trail"
            }
        }
    }

    @State private var activityTab: ActivityTab = .queue

    private var activityPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Activity", selection: $activityTab) {
                ForEach(ActivityTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 8)

            switch activityTab {
            case .queue:
                PrintQueueView(queue: viewModel.queue)
            case .history:
                historyPane
            case .audit:
                AuditTrailView(trail: viewModel.auditTrail)
            }
        }
    }

    // MARK: - Printers

    private var printersPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Printers").font(.headline)
                Spacer()
                Button("Manage…") { isManagingPrinters = true }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if viewModel.printers.isEmpty {
                ContentUnavailableView(
                    "No Printers",
                    systemImage: "printer",
                    description: Text("Add a DICOM printer to send film to.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.printers) { printer in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: printer.status.sfSymbol)
                                .foregroundStyle(printer.status == .online ? .green : .secondary)
                            Text(printer.name)
                            if printer.isDefault {
                                Text("Default")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.tint.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(printer.host):\(printer.port) · \(printer.remoteAETitle) · \(printer.colorMode.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $isManagingPrinters) {
            PrinterManagementView(viewModel: viewModel)
        }
    }

    @State private var isManagingPrinters = false

    // MARK: - History

    private var historyPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Jobs")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(PrintRecordExportFormat.allCases) { format in
                        Button {
                            historyExportFormat = format
                            isExportingHistory = true
                        } label: {
                            Label(format.menuTitle, systemImage: format.symbolName)
                        }
                    }
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(viewModel.history.isEmpty)
                .help("Save the job history as JSON data or a PDF report")
                Button(role: .destructive) {
                    isConfirmingClearHistory = true
                } label: {
                    Label("Clear…", systemImage: "trash")
                }
                .disabled(viewModel.history.isEmpty)
                .help("Remove all recorded jobs")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if viewModel.history.isEmpty {
                ContentUnavailableView(
                    "No Jobs Yet",
                    systemImage: "clock",
                    description: Text("Submitted print jobs appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.history) { entry in
                    historyRow(entry)
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingHistory,
            document: PrintHistoryExportDocument(
                data: historyExportData, format: historyExportFormat),
            contentType: historyExportFormat.contentType,
            defaultFilename: "print-job-history"
        ) { _ in }
        .confirmationDialog(
            "Clear the print job history?",
            isPresented: $isConfirmingClearHistory
        ) {
            Button("Clear History", role: .destructive) { viewModel.clearHistory() }
        } message: {
            Text("All \(viewModel.history.count) recorded job(s) will be removed. "
                 + "This cannot be undone.")
        }
    }

    private func historyRow(_ entry: PrintJobHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: entry.success
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(entry.success ? .green : .red)
                Text(entry.summary)
                    .lineLimit(1)
                Spacer()
                if !entry.printJobUIDs.isEmpty {
                    Button("Check Status") {
                        Task { await viewModel.refreshHistoryStatus(for: entry) }
                    }
                    .font(.caption)
                    .controlSize(.small)
                    .disabled(viewModel.historyStatusChecks[entry.id] == .running)
                    .help("Ask the printer for this job's execution status (N-GET)")
                }
            }
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = entry.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            historyStatus(for: entry)
        }
        .help(historyRowHelp(entry))
    }

    @ViewBuilder
    private func historyStatus(for entry: PrintJobHistoryEntry) -> some View {
        switch viewModel.historyStatusChecks[entry.id] {
        case .running:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Querying the printer…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .checked(let lines, _):
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label(line.text, systemImage: statusSymbol(for: line.kind))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: line.kind))
            }
        case .unavailable(let reason):
            Label(reason, systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }

    private func statusSymbol(for kind: PrintViewModel.HistoryJobStatusLine.Kind) -> String {
        switch kind {
        case .completed:  "checkmark.circle.fill"
        case .inProgress: "clock"
        case .failed:     "exclamationmark.triangle.fill"
        }
    }

    private func statusColor(for kind: PrintViewModel.HistoryJobStatusLine.Kind) -> Color {
        switch kind {
        case .completed:  .green
        case .inProgress: .secondary
        case .failed:     .red
        }
    }

    /// Tooltip carrying the DICOM UIDs, which are too long for the row itself.
    private func historyRowHelp(_ entry: PrintJobHistoryEntry) -> String {
        var parts: [String] = []
        if let session = entry.filmSessionUID {
            parts.append("Film Session UID: \(session)")
        }
        if !entry.printJobUIDs.isEmpty {
            parts.append("Print Job UID(s): \(entry.printJobUIDs.joined(separator: ", "))")
        }
        return parts.isEmpty ? "The printer reported no UIDs for this job." : parts.joined(separator: "\n")
    }

    @State private var isExportingHistory = false
    @State private var isConfirmingClearHistory = false
    @State private var historyExportFormat: PrintRecordExportFormat = .json

    /// The bytes the chosen format writes.
    private var historyExportData: Data {
        switch historyExportFormat {
        case .json:
            return (try? viewModel.historyExportData()) ?? Data()
        case .csv:
            return viewModel.historyCSVData()
        case .pdf:
            #if canImport(CoreGraphics) && canImport(CoreText)
            return (try? viewModel.historyPDFData()) ?? Data()
            #else
            return Data()
            #endif
        }
    }
}

/// Which form an exported record takes.
///
/// JSON is for another program to read — it is byte-identical to the on-disk
/// store, so an export and the live file are interchangeable. CSV is for a
/// spreadsheet (§11.3 names it for the audit trail). PDF is for a person: a
/// paginated report to file or hand over.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
enum PrintRecordExportFormat: String, Identifiable, CaseIterable {
    case json
    case csv
    case pdf

    var id: String { rawValue }

    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv:  return .commaSeparatedText
        case .pdf:  return .pdf
        }
    }

    var menuTitle: String {
        switch self {
        case .json: return "JSON…"
        case .csv:  return "CSV…"
        case .pdf:  return "PDF…"
        }
    }

    var symbolName: String {
        switch self {
        case .json: return "curlybraces"
        case .csv:  return "tablecells"
        case .pdf:  return "doc.richtext"
        }
    }
}

/// The job history as a savable file — JSON matching the on-disk store, or a
/// paginated PDF report.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PrintHistoryExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText, .pdf]

    let data: Data
    let format: PrintRecordExportFormat

    init(data: Data, format: PrintRecordExportFormat = .json) {
        self.data = data
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        format = .json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
