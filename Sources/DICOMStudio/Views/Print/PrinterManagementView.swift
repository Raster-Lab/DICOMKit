// PrinterManagementView.swift
// DICOMStudio
//
// DICOM Studio — add, edit, remove, and test DICOM printers.
//
// Printers are managed the same way PACS servers are, and stored in the app's
// own printer-profiles.json.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PrinterManagementView: View {
    @Bindable var viewModel: PrintViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editing: PrinterProfile?
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Printers")
                    .font(.headline)
                Spacer()
                Button {
                    editing = PrinterProfile(name: "", host: "", remoteAETitle: "")
                    isCreating = true
                } label: {
                    Label("Add Printer", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if viewModel.printers.isEmpty {
                ContentUnavailableView(
                    "No Printers",
                    systemImage: "printer",
                    description: Text("Add a DICOM printer to send film to.")
                )
                .frame(minHeight: 220)
            } else {
                List {
                    ForEach(viewModel.printers) { printer in
                        row(for: printer)
                    }
                }
                .frame(minHeight: 260)
            }

            Divider()

            HStack {
                if let message = viewModel.printerQueryMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(item: $editing) { profile in
            PrinterEditorView(profile: profile, isCreating: isCreating) { saved in
                viewModel.save(saved)
            }
        }
    }

    @ViewBuilder
    private func row(for printer: PrinterProfile) -> some View {
        HStack {
            Image(systemName: printer.status.sfSymbol)
                .foregroundStyle(printer.status == .online ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(printer.name.isEmpty ? "Untitled printer" : printer.name)
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
            Spacer()
            Button("Edit") {
                editing = printer
                isCreating = false
            }
            Menu {
                Button("Make Default") { viewModel.makeDefault(printer) }
                Button("Test Connection") {
                    viewModel.selectedPrinterID = printer.id
                    Task { await viewModel.testConnection() }
                }
                Button("Query Status") {
                    viewModel.selectedPrinterID = printer.id
                    Task { await viewModel.queryPrinterStatus() }
                }
                Divider()
                Button("Remove", role: .destructive) { viewModel.delete(printer) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 40)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct PrinterEditorView: View {
    @State var profile: PrinterProfile
    let isCreating: Bool
    let onSave: (PrinterProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    private var portString: Binding<String> {
        Binding(
            get: { String(profile.port) },
            set: { profile.port = UInt16($0) ?? profile.port }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isCreating ? "Add Printer" : "Edit Printer")
                .font(.headline)
                .padding()

            Divider()

            Form {
                TextField("Name", text: $profile.name)
                TextField("Host", text: $profile.host)
                TextField("Port", text: portString)
                TextField("Called AE (printer)", text: $profile.remoteAETitle)
                TextField("Calling AE (this workstation)", text: $profile.localAETitle)
                Picker("Color mode", selection: $profile.colorMode) {
                    ForEach(PrinterColorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Stepper(value: $profile.timeoutSeconds, in: 5...600, step: 5) {
                    Text("Timeout: \(Int(profile.timeoutSeconds))s")
                }
                Toggle("Default printer", isOn: $profile.isDefault)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(profile)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty
                          || profile.host.trimmingCharacters(in: .whitespaces).isEmpty
                          || profile.remoteAETitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 420)
    }
}
#endif
