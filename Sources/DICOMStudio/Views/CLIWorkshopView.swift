// CLIWorkshopView.swift
// DICOMStudio
//
// DICOM Studio — Interactive CLI tools workshop view

#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// CLI Workshop view providing an interactive GUI for all DICOMKit
/// command-line tools with command builder, console, and educational features.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CLIWorkshopView: View {
    @Bindable var viewModel: CLIWorkshopViewModel
    @State private var showFileImporter = false
    @State private var fileImporterParamID: String = ""
    @State private var fileImporterIsDirectory = false

    public init(viewModel: CLIWorkshopViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()

            if viewModel.activeTab == .listener {
                // Listener tab: full-width panel, no command/console area
                LocalListenerView(viewModel: viewModel)
            } else {
                HSplitView {
                    toolSelectionPanel
                        .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
                    commandAndConsolePanel
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(CLIWorkshopTab.allCases) { tab in
                    Button {
                        viewModel.activeTab = tab
                    } label: {
                        VStack(spacing: 2) {
                            Label(tab.displayName, systemImage: tab.sfSymbol)
                                .font(.caption)
                            Text(tab.tabDescription)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.displayName)
                    .accessibilityHint(tab.tabDescription)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Tool Selection Panel

    private var toolSelectionPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tools")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.toggleExperienceMode()
                } label: {
                    Label(
                        viewModel.experienceMode == .beginner ? "Beginner" : "Advanced",
                        systemImage: viewModel.experienceMode == .beginner ? "graduationcap" : "wrench.and.screwdriver"
                    )
                    .font(.caption)
                }
                .accessibilityLabel("Toggle experience mode")
            }
            .padding()

            Divider()

            let tools = viewModel.toolsForActiveTab()
            if tools.isEmpty {
                ContentUnavailableView(
                    "No Tools",
                    systemImage: "terminal",
                    description: Text("No CLI tools available for this category.")
                )
            } else if viewModel.activeTab == .networkOperations {
                List(selection: $viewModel.selectedToolID) {
                    ForEach(viewModel.groupedNetworkTools(), id: \.group) { section in
                        Section {
                            ForEach(section.tools) { tool in
                                toolRow(tool)
                            }
                        } header: {
                            Label(section.group.displayName, systemImage: section.group.sfSymbol)
                        }
                    }
                }
                .onChange(of: viewModel.selectedToolID) { _, newValue in
                    viewModel.selectTool(id: newValue)
                }
            } else {
                List(tools, id: \.id, selection: $viewModel.selectedToolID) { tool in
                    toolRow(tool)
                }
                .onChange(of: viewModel.selectedToolID) { _, newValue in
                    viewModel.selectTool(id: newValue)
                }
            }
        }
    }

    // MARK: - Tool Row

    private func toolRow(_ tool: CLIToolDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.green)
                Text(tool.name)
                    .font(.body.monospaced())
            }
            Text(tool.briefDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .accessibilityLabel(tool.name)
        .accessibilityHint(tool.briefDescription)
    }

    // MARK: - Command and Console Panel

    private var commandAndConsolePanel: some View {
        VStack(spacing: 0) {
            // Server list and parameter input fields above the command preview
            if viewModel.selectedTool() != nil {
                VStack(alignment: .leading, spacing: 8) {
                    // Server selection for network tools
                    if viewModel.isNetworkToolSelected {
                        serverSelectionSection
                        Divider()
                    }

                    Text("Parameters")
                        .font(.subheadline.bold())

                    manualParameterFields
                }
                .padding()

                Divider()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Command Preview")
                            .font(.caption.bold())
                        Spacer()
                        if viewModel.isCommandValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        Button {
                            Task { await viewModel.executeCommand() }
                        } label: {
                            Label("Run", systemImage: "play.fill")
                                .font(.caption)
                        }
                        .disabled(!viewModel.isCommandValid || viewModel.consoleStatus == .running)
                        .accessibilityLabel("Run command")
                        .accessibilityHint("Executes the constructed DICOM command")
                    }

                    HStack {
                        Text("$")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.green)
                        Text(viewModel.commandPreview.isEmpty ? "Select a tool to build a command" : viewModel.commandPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(viewModel.commandPreview.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                        Spacer()
                        if !viewModel.commandPreview.isEmpty {
                            Button {
                                copyCommandToClipboard()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Copy command")
                            .accessibilityHint("Copies the command to the clipboard")
                        }
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Console", systemImage: "terminal")
                        .font(.caption.bold())
                    Spacer()

                    consoleStatusBadge

                    if !viewModel.consoleOutput.isEmpty {
                        Button {
                            copyConsoleToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Copy console output")
                        .accessibilityHint("Copies the console output to the clipboard")
                    }

                    if !viewModel.lastRetrievedFiles.isEmpty {
                        Button {
                            viewModel.openRetrievedFileInViewer()
                        } label: {
                            Label("Open in Viewer", systemImage: "eye")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Open retrieved file in viewer")
                        .accessibilityHint("Opens the first retrieved DICOM file in the image viewer")
                    }

                    Button("Clear") {
                        viewModel.clearConsoleOutput()
                    }
                    .font(.caption)
                    .disabled(viewModel.consoleOutput.isEmpty)
                    .accessibilityLabel("Clear console output")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if viewModel.consoleOutput.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Console output will appear here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(viewModel.consoleOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(.black.opacity(0.05))
                }
            }

            Divider()

            if !viewModel.commandHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("History")
                            .font(.caption.bold())
                        Spacer()
                        Button("Clear") { viewModel.clearHistory() }
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(viewModel.commandHistory.suffix(10), id: \.id) { entry in
                                Text(entry.toolName)
                                    .font(.caption2.monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(entry.exitCode == 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Parameter Input Views

    /// Manual parameter entry fields for the selected tool.
    private var manualParameterFields: some View {
        let params = viewModel.visibleParameters()
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return Group {
            if params.isEmpty {
                Text("No configurable parameters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(params, id: \.id) { param in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(param.displayName)
                                    .font(.caption.bold())
                                if param.parameterType == .enumPicker && !param.allowedValues.isEmpty {
                                    enumPickerField(param: param)
                                } else if param.parameterType == .filePath || param.parameterType == .outputPath {
                                    filePathField(param: param)
                                } else if param.parameterType == .booleanToggle {
                                    booleanToggleField(param: param)
                                } else {
                                    TextField(param.placeholder, text: parameterBinding(for: param.id))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                        .accessibilityLabel(param.displayName)
                                }
                                if !param.helpText.isEmpty {
                                    Text(param.helpText)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// A file/directory path field with a Browse button and file importer.
    private func filePathField(param: CLIParameterDefinition) -> some View {
        HStack(spacing: 4) {
            TextField(param.placeholder, text: parameterBinding(for: param.id))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .accessibilityLabel(param.displayName)
            Button {
                fileImporterParamID = param.id
                fileImporterIsDirectory = (param.parameterType == .outputPath)
                showFileImporter = true
            } label: {
                Label("Browse", systemImage: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Browse for \(param.displayName)")
            .accessibilityHint("Opens a file picker dialog")
        }
        .fileImporter(
            isPresented: Binding(
                get: { showFileImporter && fileImporterParamID == param.id },
                set: { newValue in
                    if !newValue { showFileImporter = false }
                }
            ),
            allowedContentTypes: param.parameterType == .outputPath ? [.folder] : [.data, .folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Store the security-scoped URL for later file access
                    viewModel.setSecurityScopedURL(url, forParameterID: param.id)
                }
            case .failure:
                break
            }
        }
    }

    /// A boolean toggle field rendered as a toggle switch.
    private func booleanToggleField(param: CLIParameterDefinition) -> some View {
        let isOn = Binding<Bool>(
            get: {
                let val = viewModel.parameterValues.first(where: { $0.parameterID == param.id })?.stringValue ?? "false"
                return val == "true"
            },
            set: { newValue in
                viewModel.updateParameterValue(parameterID: param.id, value: newValue ? "true" : "false")
            }
        )
        return Toggle(isOn: isOn) {
            EmptyView()
        }
        .toggleStyle(.switch)
        .accessibilityLabel(param.displayName)
    }

    /// A picker that offers preset values.
    private func enumPickerField(param: CLIParameterDefinition) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Picker("", selection: parameterBinding(for: param.id)) {
                    ForEach(param.allowedValues, id: \.self) { value in
                        Text(value.isEmpty ? "Any" : value).tag(value)
                    }
                }
                .labelsHidden()
                .font(.caption)
                .accessibilityLabel(param.displayName)
            }
        }
    }

    // MARK: - Server Selection

    /// Server selection section with saved servers list, add/save buttons.
    private var serverSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Server", systemImage: "server.rack")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    // Pre-fill from current parameters
                    let host = viewModel.parameterValues.first(where: { $0.parameterID == "host" })?.stringValue ?? ""
                    let port = viewModel.parameterValues.first(where: { $0.parameterID == "port" })?.stringValue ?? "11112"
                    let calledAET = viewModel.parameterValues.first(where: { $0.parameterID == "called-aet" })?.stringValue ?? ""
                    let callingAET = viewModel.parameterValues.first(where: { $0.parameterID == "calling-aet" })?.stringValue ?? "DICOMSTUDIO"
                    viewModel.newServerHost = host
                    viewModel.newServerPort = port
                    viewModel.newServerCalledAET = calledAET
                    viewModel.newServerCallingAET = callingAET
                    viewModel.newServerName = host.isEmpty ? "" : "\(calledAET)@\(host)"
                    viewModel.showAddServerSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add new server")

                Button {
                    viewModel.saveCurrentServerAsDefault()
                } label: {
                    Label("Save as Default", systemImage: "star")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Save current server as default")
                .accessibilityHint("Persists hostname, port, and AE titles as defaults for all network tools")
            }

            if viewModel.savedServerProfiles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("No saved servers. Enter parameters manually or add a server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // "Manual" chip to deselect any server
                        Button {
                            viewModel.selectedSavedServerID = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 9))
                                Text("Manual")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.selectedSavedServerID == nil ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    viewModel.selectedSavedServerID == nil ? Color.accentColor.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use manual server entry")

                        ForEach(viewModel.savedServerProfiles) { server in
                            let isSelected = viewModel.selectedSavedServerID == server.id
                            Button {
                                viewModel.applySavedServer(id: server.id)
                            } label: {
                                HStack(spacing: 4) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(server.name)
                                            .font(.caption2.bold())
                                        Text("\(server.host):\(server.port)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6).stroke(
                                        isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeSavedServer(id: server.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel("Select server \(server.name)")
                            .accessibilityHint("\(server.host) port \(server.port)")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddServerSheet) {
            addServerSheet
        }
    }

    /// Sheet for adding a new server profile.
    private var addServerSheet: some View {
        VStack(spacing: 16) {
            Text("Add Server")
                .font(.headline)

            Form {
                TextField("Server Name", text: $viewModel.newServerName)
                    .accessibilityLabel("Server name")
                TextField("Hostname / IP", text: $viewModel.newServerHost)
                    .accessibilityLabel("Hostname")
                TextField("Port", text: $viewModel.newServerPort)
                    .accessibilityLabel("Port")
                TextField("Called AE Title", text: $viewModel.newServerCalledAET)
                    .accessibilityLabel("Called AE Title")
                TextField("Calling AE Title", text: $viewModel.newServerCallingAET)
                    .accessibilityLabel("Calling AE Title")
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    viewModel.showAddServerSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    viewModel.addNewServerFromForm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    viewModel.newServerName.trimmingCharacters(in: .whitespaces).isEmpty ||
                    viewModel.newServerHost.trimmingCharacters(in: .whitespaces).isEmpty ||
                    viewModel.newServerCalledAET.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 380, idealWidth: 420, minHeight: 320)
    }

    /// Picker for choosing from saved Networking server profiles.
    private var savedServerPicker: some View {
        Group {
            if viewModel.savedServerProfiles.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No saved servers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Add servers in the Networking tab first.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.savedServerProfiles) { server in
                            Button {
                                viewModel.applySavedServer(id: server.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                        Text("\(server.host):\(server.port)")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                        Text("AE: \(server.remoteAETitle)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if viewModel.selectedSavedServerID == server.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(8)
                                .background(
                                    viewModel.selectedSavedServerID == server.id
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            viewModel.selectedSavedServerID == server.id
                                                ? Color.accentColor.opacity(0.4)
                                                : Color.secondary.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select server \(server.name)")
                            .accessibilityHint("\(server.host) port \(server.port)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var consoleStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(consoleStatusColor)
                .frame(width: 6, height: 6)
            Text(viewModel.consoleStatus.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var consoleStatusColor: Color {
        switch viewModel.consoleStatus {
        case .idle: return .gray
        case .running: return .green
        case .success: return .blue
        case .error: return .red
        }
    }

    private func parameterBinding(for paramID: String) -> Binding<String> {
        Binding(
            get: {
                viewModel.parameterValues.first(where: { $0.parameterID == paramID })?.stringValue ?? ""
            },
            set: { newValue in
                viewModel.updateParameterValue(parameterID: paramID, value: newValue)
            }
        )
    }

    private func copyCommandToClipboard() {
        copyToClipboard(viewModel.commandPreview)
    }

    private func copyConsoleToClipboard() {
        copyToClipboard(viewModel.consoleOutput)
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

}
#endif
