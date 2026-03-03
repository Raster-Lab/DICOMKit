// SecurityView.swift
// DICOMStudio
//
// DICOM Studio — Security and privacy center view

#if canImport(SwiftUI)
import SwiftUI

/// Security and privacy view providing TLS management, anonymization,
/// audit logging, and access control.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct SecurityView: View {
    @Bindable var viewModel: SecurityViewModel

    public init(viewModel: SecurityViewModel) {
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
        HStack(spacing: 4) {
            ForEach(SecurityTab.allCases, id: \.self) { tab in
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
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .tlsConfiguration:
            tlsContent
        case .anonymization:
            anonymizationContent
        case .auditLog:
            auditLogContent
        case .accessControl:
            accessControlContent
        }
    }

    // MARK: - TLS Configuration

    private var tlsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TLS Configuration")
                    .font(.headline)
                Spacer()
                Picker("TLS Mode", selection: $viewModel.globalTLSMode) {
                    ForEach(SecurityTLSMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 200)
                .accessibilityLabel("Global TLS mode")
            }
            .padding()

            Divider()

            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Certificates")
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            viewModel.isAddCertificateSheetPresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add certificate")
                    }
                    .padding()

                    if viewModel.certificates.isEmpty {
                        ContentUnavailableView(
                            "No Certificates",
                            systemImage: "lock.shield",
                            description: Text("Add TLS certificates for secure DICOM communications.")
                        )
                    } else {
                        List(viewModel.certificates, id: \.id, selection: $viewModel.selectedCertificateID) { cert in
                            HStack {
                                Image(systemName: cert.status == .expired ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                    .foregroundStyle(cert.status == .expired ? .red : .green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.commonName)
                                        .font(.body)
                                    Text("Expires: \(cert.notAfter.formatted(.dateTime.year().month().day()))")
                                        .font(.caption)
                                        .foregroundStyle(cert.status == .expired ? .red : .secondary)
                                }
                                Spacer()
                            }
                            .accessibilityLabel("Certificate \(cert.commonName)")
                            .accessibilityValue(cert.status == .expired ? "Expired" : "Valid")
                        }
                    }

                    if !viewModel.expiringCertificates.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("\(viewModel.expiringCertificates.count) certificate(s) expiring soon")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(8)
                    }
                }
                .frame(minWidth: 250)

                VStack(spacing: 0) {
                    HStack {
                        Text("Server Security")
                            .font(.subheadline.bold())
                        Spacer()
                    }
                    .padding()

                    if viewModel.serverSecurityEntries.isEmpty {
                        ContentUnavailableView(
                            "No Server Entries",
                            systemImage: "server.rack",
                            description: Text("Configure per-server TLS and security settings.")
                        )
                    } else {
                        List(viewModel.serverSecurityEntries, id: \.id, selection: $viewModel.selectedServerSecurityID) { entry in
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(entry.tlsMode != .development ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.serverName)
                                        .font(.body)
                                    Text("TLS: \(entry.tlsMode.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Anonymization

    private var anonymizationContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DICOM Anonymization")
                    .font(.headline)
                Spacer()
                Picker("Profile", selection: $viewModel.selectedProfile) {
                    ForEach(AnonymizationProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue).tag(profile)
                    }
                }
                .frame(width: 200)
                .accessibilityLabel("Anonymization profile")

                Button {
                    viewModel.isNewJobSheetPresented = true
                } label: {
                    Label("New Job", systemImage: "plus")
                }
                .accessibilityLabel("Create new anonymization job")
            }
            .padding()

            Divider()

            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Tag Rules")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(viewModel.customRules.count) rules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    if viewModel.customRules.isEmpty {
                        ContentUnavailableView(
                            "Default Profile",
                            systemImage: "person.crop.circle.badge.minus",
                            description: Text("Using standard anonymization profile. Add custom rules to modify specific tags.")
                        )
                    } else {
                        List(viewModel.customRules, id: \.id) { rule in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.tagName)
                                        .font(.body)
                                    Text(rule.action.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .frame(minWidth: 250)

                VStack(spacing: 0) {
                    HStack {
                        Text("Anonymization Jobs")
                            .font(.subheadline.bold())
                        Spacer()
                    }
                    .padding()

                    if viewModel.anonymizationJobs.isEmpty {
                        ContentUnavailableView(
                            "No Jobs",
                            systemImage: "briefcase",
                            description: Text("Create anonymization jobs to de-identify DICOM files.")
                        )
                    } else {
                        List(viewModel.anonymizationJobs, id: \.id, selection: $viewModel.selectedJobID) { job in
                            HStack {
                                Image(systemName: job.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(job.status == .completed ? .green : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.profile.rawValue)
                                        .font(.body)
                                    Text("\(job.totalFiles) files • \(job.profile.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if job.progress > 0 && job.progress < 1.0 {
                                    ProgressView(value: job.progress)
                                        .frame(width: 60)
                                }
                            }
                        }
                    }
                }
            }

            if viewModel.isPHIScanRunning || !viewModel.phiDetectionResults.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PHI Detection")
                            .font(.caption.bold())
                        if viewModel.isPHIScanRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Spacer()
                        Text("\(viewModel.phiDetectionResults.count) findings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.phiDetectionResults.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(viewModel.phiDetectionResults.prefix(10), id: \.id) { result in
                                    HStack(spacing: 4) {
                                        Image(systemName: result.hasPHI ? "exclamationmark.triangle" : "checkmark.circle")
                                            .foregroundStyle(result.hasPHI ? .orange : .green)
                                            .font(.caption2)
                                        Text(result.filePath)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(result.hasPHI ? .orange.opacity(0.1) : .green.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Audit Log

    private var auditLogContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Security Audit Log")
                    .font(.headline)
                Spacer()

                Button {
                    viewModel.isAuditExportSheetPresented = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Export audit log")

                Button("Clear") {
                    viewModel.clearAuditEntries()
                }
                .disabled(viewModel.auditEntries.isEmpty)
                .accessibilityLabel("Clear audit log")
            }
            .padding()

            HStack(spacing: 12) {
                TextField("User", text: $viewModel.auditFilterUser)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .accessibilityLabel("Filter by user")

                TextField("Reference", text: $viewModel.auditFilterReference)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .accessibilityLabel("Filter by reference")

                Button("Clear Filters") {
                    viewModel.clearAuditFilters()
                }
                .font(.caption)

                Spacer()

                Text("\(viewModel.filteredAuditEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            if viewModel.filteredAuditEntries.isEmpty {
                ContentUnavailableView(
                    "No Audit Entries",
                    systemImage: "list.clipboard",
                    description: Text("Security audit events will appear here as operations are performed.")
                )
            } else {
                List(viewModel.filteredAuditEntries, id: \.id) { entry in
                    HStack {
                        Image(systemName: auditEventIcon(entry.eventType))
                            .foregroundStyle(auditEventColor(entry.eventType))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.description)
                                .font(.body)
                            HStack(spacing: 8) {
                                Text(entry.userIdentity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(entry.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Access Control

    private var accessControlContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Access Control")
                    .font(.headline)
                Spacer()
                if let session = viewModel.currentSession {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.green)
                        Text(session.userName)
                            .font(.caption)
                        if let remaining = viewModel.remainingSessionTime {
                            Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Button("Lock") {
                            viewModel.lockSession()
                        }
                        .font(.caption)
                        .accessibilityLabel("Lock session")
                    }
                } else {
                    Text("No active session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            HSplitView {
                VStack(spacing: 0) {
                    Text("Permissions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    if viewModel.permissionMatrix.isEmpty {
                        ContentUnavailableView(
                            "No Permissions Configured",
                            systemImage: "person.badge.key",
                            description: Text("Configure role-based access control permissions.")
                        )
                    } else {
                        List(viewModel.permissionMatrix, id: \.id) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.permission)
                                        .font(.body)
                                    Text(entry.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("Break-Glass Events")
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            viewModel.isBreakGlassDialogPresented = true
                        } label: {
                            Label("Break Glass", systemImage: "exclamationmark.shield")
                        }
                        .accessibilityLabel("Initiate break-glass access")
                    }
                    .padding()

                    if viewModel.breakGlassEvents.isEmpty {
                        ContentUnavailableView(
                            "No Break-Glass Events",
                            systemImage: "exclamationmark.shield",
                            description: Text("Emergency access events will be logged here.")
                        )
                    } else {
                        List(viewModel.breakGlassEvents, id: \.id) { event in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.resourceReference)
                                        .font(.body)
                                    Text("\(event.userName) — \(event.reason)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(event.timestamp.formatted())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func auditEventIcon(_ type: SecurityAuditEventType) -> String {
        switch type {
        case .userLogin: return "person.badge.key"
        case .userLogout: return "person.badge.minus"
        case .fileAccess: return "eye"
        case .fileModification: return "pencil"
        case .fileExport: return "square.and.arrow.up"
        case .fileImport: return "square.and.arrow.down"
        case .networkQuery: return "magnifyingglass"
        case .networkRetrieve: return "arrow.down.circle"
        case .networkSend: return "arrow.up.circle"
        case .anonymization: return "person.crop.circle.badge.minus"
        case .settingsChange: return "gearshape"
        case .securityAlert: return "exclamationmark.shield"
        case .breakGlassAccess: return "exclamationmark.triangle.fill"
        }
    }

    private func auditEventColor(_ type: SecurityAuditEventType) -> Color {
        switch type {
        case .userLogin: return .green
        case .userLogout: return .gray
        case .fileAccess, .networkQuery: return .blue
        case .fileModification, .settingsChange: return .orange
        case .fileExport, .fileImport: return .purple
        case .networkRetrieve, .networkSend: return .blue
        case .anonymization: return .indigo
        case .securityAlert, .breakGlassAccess: return .red
        }
    }
}
#endif
