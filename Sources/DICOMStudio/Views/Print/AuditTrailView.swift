// AuditTrailView.swift
// DICOMStudio
//
// DICOM Studio — the print audit trail screen: every recorded print activity,
// newest first, filterable by action and searchable by text. Read-only apart
// from export: SRS §11.2 forbids deleting audit records, so there is no clear
// control — retention policy is the only thing that removes an event.

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct AuditTrailView: View {
    @Bindable var trail: PrintAuditTrail

    @State private var searchText = ""
    /// `nil` means every action.
    @State private var actionFilter: PrintAuditAction?
    @State private var isExporting = false
    @State private var exportFormat: PrintRecordExportFormat = .json

    public init(trail: PrintAuditTrail) {
        self.trail = trail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            controls
            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    trail.events.isEmpty ? "No Activity Yet" : "No Matches",
                    systemImage: "list.bullet.rectangle",
                    description: Text(trail.events.isEmpty
                        ? "Print activity — submissions, starts, stops, completions — is recorded here."
                        : "No recorded activity matches the current filter.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEvents) { event in
                    row(event)
                }
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: AuditTrailExportDocument(data: exportData, format: exportFormat),
            contentType: exportFormat.contentType,
            defaultFilename: "print-audit-trail"
        ) { _ in }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search activity", text: $searchText)
                .textFieldStyle(.plain)

            Picker("Action", selection: $actionFilter) {
                Text("All Actions").tag(PrintAuditAction?.none)
                ForEach(PrintAuditAction.allCases) { action in
                    Text(action.displayName).tag(PrintAuditAction?.some(action))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            Menu {
                ForEach(PrintRecordExportFormat.allCases) { format in
                    Button {
                        exportFormat = format
                        isExporting = true
                    } label: {
                        Label(format.menuTitle, systemImage: format.symbolName)
                    }
                }
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(trail.events.isEmpty)
            .help("Save the audit trail as JSON data, CSV, or a PDF report")

            if let broken = trail.verifyIntegrity() {
                Label("Chain broken at \(broken.date.formatted(date: .abbreviated, time: .shortened))",
                      systemImage: "exclamationmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .help("The audit trail's hash chain does not verify — records were edited or removed outside the app")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// The bytes the chosen format writes.
    ///
    /// The whole trail, not the filtered view: an exported audit record that
    /// silently dropped whatever the search box happened to hold would be a
    /// misleading document to file.
    private var exportData: Data {
        switch exportFormat {
        case .json:
            return (try? trail.exportData()) ?? Data()
        case .csv:
            return trail.csvExportData()
        case .pdf:
            #if canImport(CoreGraphics) && canImport(CoreText)
            return (try? trail.pdfExportData()) ?? Data()
            #else
            return Data()
            #endif
        }
    }

    private var filteredEvents: [PrintAuditEvent] {
        trail.events.filter { event in
            if let actionFilter, event.action != actionFilter { return false }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return true }
            return event.detail.localizedCaseInsensitiveContains(query)
                || event.action.displayName.localizedCaseInsensitiveContains(query)
                || (event.printerName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Rows

    private func row(_ event: PrintAuditEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: event.action.symbolName)
                .foregroundStyle(color(for: event.action))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.action.displayName)
                        .font(.callout.bold())
                    if let printer = event.printerName {
                        Text(printer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(event.action.isFailure ? .red : .secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 2)
        .help(event.jobID.map { "Job ID: \($0.uuidString)" } ?? "")
    }

    private func color(for action: PrintAuditAction) -> Color {
        switch action {
        case .jobCompleted:                 return .green
        case .jobFailed:                    return .red
        case .jobPaused, .queuePaused,
             .jobHeldOffline, .jobRetried:  return .orange
        case .jobStopped, .queueStopped:    return .secondary
        case .jobStarted, .jobResumed,
             .queueResumed, .queueRestored: return .blue
        case .jobSubmitted, .jobResent:     return .primary
        case .jobRemoved, .queueCleared,
             .queueReordered,
             .historyCleared,
             .retentionApplied:             return .secondary
        }
    }
}

/// The audit trail as a savable file — JSON matching the on-disk store, or a
/// paginated PDF report.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct AuditTrailExportDocument: FileDocument {
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

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview {
    AuditTrailView(trail: PrintAuditTrail())
}
#endif
