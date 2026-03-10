// NetworkingView.swift
// DICOMStudio
//
// DICOM Studio — Networking hub view for DICOM network operations

#if canImport(SwiftUI)
import SwiftUI

/// Networking hub view providing C-ECHO, C-FIND, C-MOVE/GET, C-STORE,
/// MWL, MPPS, Print Management, and connection monitoring.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct NetworkingView: View {
    @Bindable var viewModel: NetworkingViewModel

    public init(viewModel: NetworkingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $viewModel.isAddServerSheetPresented) {
            ServerProfileFormSheet(mode: .add) { newProfile in
                viewModel.addServerProfile(newProfile)
            }
        }
        .sheet(isPresented: $viewModel.isEditServerSheetPresented) {
            if let profile = viewModel.selectedServerProfile {
                ServerProfileFormSheet(mode: .edit(profile)) { updatedProfile in
                    viewModel.updateServerProfile(updatedProfile)
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreateMPPSSheetPresented) {
            CreateMPPSSheet { item in
                viewModel.createMPPS(item)
            }
        }
        .sheet(isPresented: $viewModel.isNewPrintJobSheetPresented) {
            NewPrintJobSheet(serverProfiles: viewModel.serverProfiles) { job in
                viewModel.addPrintJob(job)
            }
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(NetworkingTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.activeTab = tab
                    } label: {
                        Label(tab.displayName, systemImage: tab.sfSymbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .serverConfig:
            serverConfigContent
        case .cEcho:
            echoContent
        case .cFind:
            queryContent
        case .cMoveGet:
            transferContent
        case .cStore:
            storeContent
        case .mwl:
            worklistContent
        case .mpps:
            mppsContent
        case .printManagement:
            printContent
        case .monitoring:
            monitoringContent
        }
    }

    // MARK: - Server Configuration

    private var serverConfigContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PACS Server Profiles")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddServerSheetPresented = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .accessibilityLabel("Add new PACS server profile")
            }
            .padding()

            if viewModel.serverProfiles.isEmpty {
                ContentUnavailableView(
                    "No Server Profiles",
                    systemImage: "server.rack",
                    description: Text("Add a PACS server profile to get started with DICOM networking.")
                )
            } else {
                List(viewModel.serverProfiles, id: \.id, selection: $viewModel.selectedServerProfileID) { profile in
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body)
                            Text("\(profile.host):\(profile.port) — AE: \(profile.remoteAETitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .accessibilityLabel("Server \(profile.name)")
                    .accessibilityValue("\(profile.host) port \(profile.port)")
                    .contextMenu {
                        Button {
                            viewModel.selectedServerProfileID = profile.id
                            viewModel.isEditServerSheetPresented = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            Task { await viewModel.performEcho(profileID: profile.id) }
                        } label: {
                            Label("Test Connection", systemImage: "network")
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.removeServerProfile(id: profile.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - C-ECHO

    private var echoContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("C-ECHO Verification")
                    .font(.headline)
                Spacer()
                if viewModel.isBatchEchoInProgress {
                    ProgressView(value: Double(viewModel.batchEchoProgress),
                                 total: Double(viewModel.serverProfiles.count))
                        .frame(width: 100)
                }
                Button("Batch Echo All") {
                    Task { await viewModel.performBatchEcho() }
                }
                .disabled(viewModel.serverProfiles.isEmpty || viewModel.isBatchEchoInProgress)
                .accessibilityLabel("Perform batch echo on all servers")

                Button("Clear History") {
                    viewModel.clearEchoHistory()
                }
                .disabled(viewModel.echoHistory.isEmpty)
                .accessibilityLabel("Clear echo history")
            }
            .padding()

            Divider()

            if viewModel.echoHistory.isEmpty {
                ContentUnavailableView(
                    "No Echo Results",
                    systemImage: "network",
                    description: Text("Select a server and perform a C-ECHO to verify connectivity.")
                )
            } else {
                List(viewModel.echoHistory, id: \.id) { result in
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.serverName)
                                .font(.body)
                            if let latency = result.latencyMs {
                                Text(String(format: "%.1f ms", latency))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let error = result.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Text(result.timestamp.formatted(.dateTime.hour().minute().second()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("\(result.serverName) echo \(result.success ? "succeeded" : "failed")")
                }
            }
        }
    }

    // MARK: - C-FIND Query

    private var queryContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("C-FIND Query")
                    .font(.headline)
                Spacer()
                if viewModel.isQueryRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Clear Results") {
                    viewModel.clearQueryResults()
                }
                .disabled(viewModel.queryResults.isEmpty)
                .accessibilityLabel("Clear query results")
            }
            .padding()

            Divider()

            if viewModel.queryResults.isEmpty && !viewModel.isQueryRunning {
                ContentUnavailableView(
                    "No Query Results",
                    systemImage: "magnifyingglass",
                    description: Text("Configure query parameters and run a C-FIND to search for studies.")
                )
            } else {
                List(viewModel.queryResults, id: \.id, selection: $viewModel.selectedQueryResultID) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.patientName)
                            .font(.body)
                        HStack(spacing: 12) {
                            Label(result.modality, systemImage: "camera.metering.unknown")
                            Label(result.studyDate, systemImage: "calendar")
                            Label(result.studyDescription, systemImage: "doc.text")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - C-MOVE/GET Transfer

    private var transferContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("C-MOVE / C-GET Transfer Queue")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.transferQueue.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if viewModel.transferQueue.isEmpty {
                ContentUnavailableView(
                    "No Transfers",
                    systemImage: "arrow.down.circle",
                    description: Text("Initiate a C-MOVE or C-GET from query results to begin transferring studies.")
                )
            } else {
                List(viewModel.prioritizedTransferQueue, id: \.id, selection: $viewModel.selectedTransferItemID) { item in
                    HStack {
                        Image(systemName: statusIcon(for: item.status.displayName))
                            .foregroundStyle(statusColor(for: item.status.displayName))
                        Text(item.label)
                            .font(.body)
                        Spacer()
                        if item.progress > 0 && item.progress < 1.0 {
                            ProgressView(value: item.progress)
                                .frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    // MARK: - C-STORE

    private var storeContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("C-STORE Send Queue")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.sendQueue.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if viewModel.sendQueue.isEmpty {
                ContentUnavailableView(
                    "No Send Items",
                    systemImage: "arrow.up.circle",
                    description: Text("Add DICOM files to send to a remote PACS server via C-STORE.")
                )
            } else {
                List(viewModel.sendQueue, id: \.id) { item in
                    HStack {
                        Image(systemName: statusIcon(for: item.status.displayName))
                            .foregroundStyle(statusColor(for: item.status.displayName))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.sourceIdentifier)
                                .font(.body)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Modality Worklist

    private var worklistContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Modality Worklist (MWL)")
                    .font(.headline)
                Spacer()
                if viewModel.isMWLQueryRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("\(viewModel.filteredMWLItems.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if viewModel.mwlItems.isEmpty {
                ContentUnavailableView(
                    "No Worklist Items",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Query a PACS server for scheduled procedure steps.")
                )
            } else {
                List(viewModel.filteredMWLItems, id: \.id, selection: $viewModel.selectedMWLItemID) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.patientName)
                            .font(.body)
                        HStack(spacing: 12) {
                            Label(item.modality, systemImage: "camera.metering.unknown")
                            Label(item.scheduledProcedureStepStartDate, systemImage: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(item.requestedProcedureDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - MPPS

    private var mppsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Modality Performed Procedure Step")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isCreateMPPSSheetPresented = true
                } label: {
                    Label("Create MPPS", systemImage: "plus")
                }
                .accessibilityLabel("Create new MPPS")
            }
            .padding()

            Divider()

            if viewModel.mppsItems.isEmpty {
                ContentUnavailableView(
                    "No MPPS Items",
                    systemImage: "checkmark.circle",
                    description: Text("Create an MPPS to track performed procedures.")
                )
            } else {
                List(viewModel.mppsItems, id: \.id, selection: $viewModel.selectedMPPSItemID) { item in
                    HStack {
                        Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.status == .completed ? .green : .orange)
                        Text(item.performedProcedureStepDescription)
                            .font(.body)
                        Spacer()
                        Text(item.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Print Management

    private var printContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DICOM Print Management")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isNewPrintJobSheetPresented = true
                } label: {
                    Label("New Print Job", systemImage: "plus")
                }
                .accessibilityLabel("Create new print job")
            }
            .padding()

            Divider()

            if viewModel.printJobs.isEmpty {
                ContentUnavailableView(
                    "No Print Jobs",
                    systemImage: "printer",
                    description: Text("Create a print job to send images to a DICOM printer.")
                )
            } else {
                List(viewModel.printJobs, id: \.id, selection: $viewModel.selectedPrintJobID) { job in
                    HStack {
                        Image(systemName: "printer")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.label)
                                .font(.body)
                            Text("\(job.numberOfCopies) copies")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(job.status.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Monitoring

    private var monitoringContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Network Monitoring")
                    .font(.headline)
                Spacer()
                Toggle("Active", isOn: $viewModel.isMonitoringActive)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Toggle network monitoring")
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        statCard(title: "Active Associations",
                                 value: "\(viewModel.monitoringStats.activeAssociationCount)",
                                 icon: "link")
                        statCard(title: "Bytes Sent",
                                 value: formatBytes(viewModel.monitoringStats.totalBytesSent),
                                 icon: "arrow.up")
                        statCard(title: "Bytes Received",
                                 value: formatBytes(viewModel.monitoringStats.totalBytesReceived),
                                 icon: "arrow.down")
                    }

                    GroupBox("Recent Activity") {
                        if viewModel.auditLog.isEmpty {
                            Text("No recent activity")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.filteredAuditLog.prefix(20), id: \.id) { entry in
                                    HStack {
                                        Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                        Text(entry.detail)
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.networkErrors.isEmpty {
                        GroupBox("Network Errors") {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.networkErrors.prefix(10), id: \.id) { error in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                        Text(error.message)
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "completed", "success": return "checkmark.circle.fill"
        case "failed", "error": return "xmark.circle.fill"
        case "pending", "queued": return "clock"
        case "in progress", "running": return "arrow.triangle.2.circlepath"
        default: return "circle"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "completed", "success": return .green
        case "failed", "error": return .red
        case "pending", "queued": return .orange
        case "in progress", "running": return .blue
        default: return .secondary
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Server Profile Form Sheet

/// A sheet for adding or editing a PACS server profile.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ServerProfileFormSheet: View {

    enum Mode {
        case add
        case edit(PACSServerProfile)

        var title: String {
            switch self {
            case .add: return "Add Server Profile"
            case .edit: return "Edit Server Profile"
            }
        }

        var buttonLabel: String {
            switch self {
            case .add: return "Add"
            case .edit: return "Save"
            }
        }
    }

    let mode: Mode
    let onSave: (PACSServerProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "11112"
    @State private var remoteAETitle: String = ""
    @State private var localAETitle: String = "DICOMSTUDIO"
    @State private var tlsMode: TLSMode = .none
    @State private var certificatePinningEnabled: Bool = false
    @State private var allowSelfSignedCertificates: Bool = false
    @State private var timeoutSeconds: String = "30"
    @State private var isDefault: Bool = false
    @State private var validationErrors: [String] = []

    private var editingID: UUID? {
        if case .edit(let profile) = mode { return profile.id }
        return nil
    }

    init(mode: Mode, onSave: @escaping (PACSServerProfile) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Information") {
                    TextField("Profile Name", text: $name)
                        .accessibilityLabel("Server profile name")
                    TextField("Hostname or IP", text: $host)
                        .accessibilityLabel("Server hostname or IP address")
                    #if os(iOS)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("DICOM port number")
                    #else
                    TextField("Port", text: $port)
                        .accessibilityLabel("DICOM port number")
                    #endif
                }

                Section("AE Titles") {
                    TextField("Remote AE Title", text: $remoteAETitle)
                        .accessibilityLabel("Remote AE title")
                    TextField("Local AE Title", text: $localAETitle)
                        .accessibilityLabel("Local AE title")
                }

                Section("Security") {
                    Picker("TLS Mode", selection: $tlsMode) {
                        ForEach(TLSMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .accessibilityLabel("TLS encryption mode")

                    if tlsMode.isEnabled {
                        Toggle("Certificate Pinning", isOn: $certificatePinningEnabled)
                            .accessibilityLabel("Enable certificate pinning")
                        Toggle("Allow Self-Signed Certificates", isOn: $allowSelfSignedCertificates)
                            .accessibilityLabel("Allow self-signed certificates")
                    }
                }

                Section("Options") {
                    TextField("Timeout (seconds)", text: $timeoutSeconds)
                        .accessibilityLabel("Connection timeout in seconds")
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Toggle("Default Server", isOn: $isDefault)
                        .accessibilityLabel("Set as default server")
                }

                if !validationErrors.isEmpty {
                    Section("Validation Errors") {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(mode.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonLabel) {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              host.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadFromMode()
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    private func loadFromMode() {
        if case .edit(let profile) = mode {
            name = profile.name
            host = profile.host
            port = String(profile.port)
            remoteAETitle = profile.remoteAETitle
            localAETitle = profile.localAETitle
            tlsMode = profile.tlsMode
            certificatePinningEnabled = profile.certificatePinningEnabled
            allowSelfSignedCertificates = profile.allowSelfSignedCertificates
            timeoutSeconds = String(format: "%.0f", profile.timeoutSeconds)
            isDefault = profile.isDefault
        }
    }

    private func saveProfile() {
        let parsedPort = UInt16(port) ?? 11112
        let parsedTimeout = Double(timeoutSeconds) ?? 30.0

        let profile = PACSServerProfile(
            id: editingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: parsedPort,
            remoteAETitle: remoteAETitle.trimmingCharacters(in: .whitespaces),
            localAETitle: localAETitle.trimmingCharacters(in: .whitespaces),
            tlsMode: tlsMode,
            certificatePinningEnabled: certificatePinningEnabled,
            allowSelfSignedCertificates: allowSelfSignedCertificates,
            timeoutSeconds: parsedTimeout,
            isDefault: isDefault
        )

        let errors = ServerProfileValidation.validate(profile)
        if !errors.isEmpty {
            validationErrors = errors
            return
        }

        onSave(profile)
        dismiss()
    }
}

// MARK: - Create MPPS Sheet

/// Sheet for creating a new Modality Performed Procedure Step (N-CREATE).
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct CreateMPPSSheet: View {
    let onSave: (MPPSItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var patientName: String = ""
    @State private var patientID: String = ""
    @State private var procedureStepID: String = ""
    @State private var procedureDescription: String = ""
    @State private var stationAETitle: String = "DICOMSTUDIO"
    @State private var modality: String = "CT"

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient") {
                    TextField("Patient Name", text: $patientName)
                        .accessibilityLabel("Patient name")
                    TextField("Patient ID", text: $patientID)
                        .accessibilityLabel("Patient ID")
                }

                Section("Procedure") {
                    TextField("Procedure Step ID", text: $procedureStepID)
                        .accessibilityLabel("Performed procedure step ID")
                    TextField("Description", text: $procedureDescription)
                        .accessibilityLabel("Procedure step description")
                }

                Section("Station") {
                    TextField("Station AE Title", text: $stationAETitle)
                        .accessibilityLabel("Performing station AE title")
                    TextField("Modality", text: $modality)
                        .accessibilityLabel("Modality type")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create MPPS")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let item = MPPSItem(
                            patientName: patientName.trimmingCharacters(in: .whitespaces),
                            patientID: patientID.trimmingCharacters(in: .whitespaces),
                            performedProcedureStepID: procedureStepID.trimmingCharacters(in: .whitespaces),
                            performedProcedureStepDescription: procedureDescription.trimmingCharacters(in: .whitespaces),
                            performedStationAETitle: stationAETitle.trimmingCharacters(in: .whitespaces),
                            modality: modality.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(item)
                        dismiss()
                    }
                    .disabled(patientName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              procedureDescription.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
}

// MARK: - New Print Job Sheet

/// Sheet for creating a new DICOM print job.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct NewPrintJobSheet: View {
    let serverProfiles: [PACSServerProfile]
    let onSave: (PrintJob) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var selectedServerID: UUID?
    @State private var numberOfCopies: Int = 1
    @State private var priority: PrintPriority = .med
    @State private var mediumType: PrintMediumType = .clearFilm
    @State private var filmLayout: FilmLayout = .standard2x2

    var body: some View {
        NavigationStack {
            Form {
                Section("Job Information") {
                    TextField("Job Label", text: $label)
                        .accessibilityLabel("Print job label")
                }

                Section("Printer") {
                    Picker("Printer Server", selection: $selectedServerID) {
                        Text("Select a server").tag(nil as UUID?)
                        ForEach(serverProfiles, id: \.id) { profile in
                            Text(profile.name).tag(profile.id as UUID?)
                        }
                    }
                    .accessibilityLabel("Select printer server")
                }

                Section("Print Settings") {
                    Stepper("Copies: \(numberOfCopies)", value: $numberOfCopies, in: 1...99)
                        .accessibilityLabel("Number of copies")
                    Picker("Priority", selection: $priority) {
                        ForEach(PrintPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .accessibilityLabel("Print priority")
                    Picker("Medium", selection: $mediumType) {
                        ForEach(PrintMediumType.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .accessibilityLabel("Print medium type")
                    Picker("Film Layout", selection: $filmLayout) {
                        ForEach(FilmLayout.allCases, id: \.self) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .accessibilityLabel("Film layout")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Print Job")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let serverID = selectedServerID else { return }
                        let job = PrintJob(
                            label: label.trimmingCharacters(in: .whitespaces),
                            printerServerProfileID: serverID,
                            numberOfCopies: numberOfCopies,
                            priority: priority,
                            mediumType: mediumType,
                            filmLayout: filmLayout
                        )
                        onSave(job)
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || selectedServerID == nil)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 440)
    }
}
#endif
