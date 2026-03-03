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
                    viewModel.performBatchEcho()
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
#endif
