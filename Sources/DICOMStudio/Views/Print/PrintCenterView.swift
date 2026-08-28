// PrintCenterView.swift
// DICOMStudio
//
// DICOM Studio — the standalone Print screen: manage printers and review
// submitted jobs. Printing itself starts in the viewer, where images are marked.

#if canImport(SwiftUI)
import SwiftUI

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
        .navigationTitle("Print")
        .onAppear { viewModel.loadPrinters() }
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
            printersPane
                .frame(minWidth: 320)
            historyPane
                .frame(minWidth: 320)
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
            Text("Recent Jobs")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if viewModel.history.isEmpty {
                ContentUnavailableView(
                    "No Jobs Yet",
                    systemImage: "clock",
                    description: Text("Submitted print jobs appear here.")
                )
            } else {
                List(viewModel.history) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.success
                                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(entry.success ? .green : .red)
                            Text(entry.summary)
                                .lineLimit(1)
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
                    }
                }
            }
        }
    }
}
#endif
