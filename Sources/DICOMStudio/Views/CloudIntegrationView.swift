// CloudIntegrationView.swift
// DICOMStudio
//
// DICOM Studio — Cloud Integration view (dicom-cloud)
// Supports AWS S3, Google Cloud Storage, Azure Blob Storage

#if canImport(SwiftUI)
import SwiftUI

/// Cloud Integration view providing upload, download, and sync operations
/// for DICOM files across AWS S3, Google Cloud Storage, and Azure Blob Storage.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CloudIntegrationView: View {
    @Bindable var viewModel: CloudIntegrationViewModel

    public init(viewModel: CloudIntegrationViewModel) {
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
                ProgressView("Working…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .sheet(isPresented: $viewModel.isAddProfileSheetPresented) {
            addProfileSheet
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(CloudIntegrationTab.allCases) { tab in
                    Button { viewModel.activeTab = tab } label: {
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

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .serverConfig: connectionContent
        case .upload:       uploadContent
        case .download:     downloadContent
        case .sync:         syncContent
        case .jobs:         jobsContent
        }
    }

    // MARK: - Connection

    private var connectionContent: some View {
        HSplitView {
            // Profile list
            VStack(spacing: 0) {
                HStack {
                    Text("Cloud Profiles")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.isAddProfileSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add cloud profile")
                }
                .padding()
                Divider()

                if viewModel.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "cloud",
                        description: Text("Add a cloud storage profile to get started.")
                    )
                } else {
                    List(selection: $viewModel.selectedProfileID) {
                        ForEach(viewModel.profiles) { profile in
                            HStack {
                                Image(systemName: profile.provider.sfSymbol)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name).font(.subheadline).bold()
                                    Text(profile.provider.displayName).font(.caption).foregroundStyle(.secondary)
                                    Text("\(profile.provider.urlScheme)\(profile.bucket)").font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if profile.isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .tag(profile.id)
                        }
                    }
                }
            }
            .frame(minWidth: 220, idealWidth: 260)

            // Profile detail
            if let profile = viewModel.selectedProfile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(profile.name)
                            .font(.title2).bold()

                        GroupBox("Provider") {
                            LabeledContent("Type") { Text(profile.provider.displayName) }
                            LabeledContent("Bucket") { Text(profile.bucket.isEmpty ? "—" : profile.bucket) }
                            LabeledContent("Region") { Text(profile.region.isEmpty ? "—" : profile.region) }
                            if !profile.endpoint.isEmpty {
                                LabeledContent("Endpoint") { Text(profile.endpoint) }
                            }
                        }

                        GroupBox("Credentials") {
                            LabeledContent("Access Key") {
                                Text(profile.accessKey.isEmpty ? "—" : String(repeating: "•", count: min(profile.accessKey.count, 12)))
                            }
                        }

                        Button("Remove Profile") {
                            viewModel.removeProfile(id: profile.id)
                        }
                        .foregroundStyle(.red)
                        .accessibilityLabel("Remove cloud profile")
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Select a Profile",
                    systemImage: "cloud",
                    description: Text("Select a cloud profile to view its configuration.")
                )
            }
        }
    }

    // MARK: - Upload

    private var uploadContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Upload to Cloud")
                    .font(.title2).bold()

                if let profile = viewModel.selectedProfile {
                    Text("Provider: **\(profile.provider.displayName)** — \(profile.provider.urlScheme)\(profile.bucket)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No cloud profile selected. Configure one in the Connection tab.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                GroupBox("Source") {
                    TextField("Local file or directory path", text: $viewModel.uploadLocalPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Local upload path")
                }

                GroupBox("Destination") {
                    TextField("Cloud remote path (e.g. studies/study1/)", text: $viewModel.uploadRemotePath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Cloud remote path")
                    Toggle("Recursive (upload directory contents)", isOn: $viewModel.uploadRecursive)
                        .accessibilityLabel("Upload recursively")
                }

                Button("Start Upload") {
                    viewModel.startUpload()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start upload")

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Download

    private var downloadContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Download from Cloud")
                    .font(.title2).bold()

                GroupBox("Source") {
                    TextField("Cloud remote path", text: $viewModel.downloadRemotePath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Cloud remote path")
                    Toggle("Recursive (download directory contents)", isOn: $viewModel.downloadRecursive)
                        .accessibilityLabel("Download recursively")
                }

                GroupBox("Destination") {
                    TextField("Local output directory", text: $viewModel.downloadLocalPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Local output directory")
                }

                Button("Start Download") {
                    viewModel.startDownload()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start download")
            }
            .padding()
        }
    }

    // MARK: - Sync

    private var syncContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sync with Cloud")
                    .font(.title2).bold()

                GroupBox("Local") {
                    TextField("Local archive or directory path", text: $viewModel.syncLocalPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Local sync path")
                }

                GroupBox("Cloud") {
                    TextField("Cloud remote path", text: $viewModel.syncRemotePath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Cloud sync remote path")
                    Toggle("Bidirectional sync", isOn: $viewModel.syncBidirectional)
                        .accessibilityLabel("Bidirectional sync")
                }

                Button("Start Sync") {
                    viewModel.startSync()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start sync")
            }
            .padding()
        }
    }

    // MARK: - Jobs

    private var jobsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transfer Jobs")
                    .font(.headline)
                Spacer()
                if !viewModel.jobs.isEmpty {
                    Button("Clear Completed") {
                        viewModel.clearCompleted()
                    }
                    .font(.caption)
                    .accessibilityLabel("Clear completed jobs")
                }
            }
            .padding()
            Divider()

            if viewModel.jobs.isEmpty {
                ContentUnavailableView(
                    "No Jobs",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Upload, download, or sync jobs will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.jobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: job.direction.sfSymbol)
                                    .foregroundStyle(Color.accentColor)
                                Text(job.direction.displayName)
                                    .font(.subheadline).bold()
                                Spacer()
                                Text(job.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    viewModel.cancelJob(id: job.id)
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Cancel job")
                            }
                            Text(job.localPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(job.remotePath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            if job.status == .running {
                                ProgressView(value: job.progressFraction)
                                    .accessibilityLabel("Transfer progress")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Add Profile Sheet

    private var addProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Profile name", text: $viewModel.newProfile.name)
                        .accessibilityLabel("Profile name")
                    Picker("Provider", selection: $viewModel.newProfile.provider) {
                        ForEach(CloudProvider.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .accessibilityLabel("Cloud provider")
                }
                Section("Connection") {
                    TextField("Bucket / Container name", text: $viewModel.newProfile.bucket)
                        .accessibilityLabel("Bucket name")
                    TextField("Region (e.g. us-east-1)", text: $viewModel.newProfile.region)
                        .accessibilityLabel("Region")
                    TextField("Endpoint URL (custom S3 only)", text: $viewModel.newProfile.endpoint)
                        .accessibilityLabel("Custom endpoint URL")
                }
                Section("Credentials") {
                    TextField("Access key ID", text: $viewModel.newProfile.accessKey)
                        .accessibilityLabel("Access key ID")
                }
            }
            .navigationTitle("Add Cloud Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isAddProfileSheetPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { viewModel.addProfile() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 350)
    }
}
#endif
