// CloudIntegrationViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Cloud Integration feature (dicom-cloud)

import Foundation
import Observation

/// ViewModel for the Cloud Integration feature.
///
/// Manages cloud storage profiles and upload/download/sync jobs
/// for AWS S3, Google Cloud Storage, and Azure Blob Storage.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class CloudIntegrationViewModel {
    private let service: CloudIntegrationService

    // MARK: - Navigation

    public var activeTab: CloudIntegrationTab = .serverConfig

    // MARK: - Connection

    public var profiles: [CloudProfile] = []
    public var selectedProfileID: UUID? = nil
    public var newProfile: CloudProfile = CloudProfile(name: "")
    public var isAddProfileSheetPresented: Bool = false
    public var isEditProfileSheetPresented: Bool = false

    // MARK: - Upload

    public var uploadLocalPath: String = ""
    public var uploadRemotePath: String = ""
    public var uploadRecursive: Bool = false

    // MARK: - Download

    public var downloadRemotePath: String = ""
    public var downloadLocalPath: String = ""
    public var downloadRecursive: Bool = false

    // MARK: - Sync

    public var syncLocalPath: String = ""
    public var syncRemotePath: String = ""
    public var syncBidirectional: Bool = true

    // MARK: - Jobs

    public var jobs: [CloudTransferJob] = []

    // MARK: - UI State

    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var statusMessage: String = ""

    public init(service: CloudIntegrationService = CloudIntegrationService()) {
        self.service = service
        self.profiles = service.profiles
        self.jobs = service.jobs
    }

    // MARK: - Profile Actions

    public var selectedProfile: CloudProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    public func addProfile() {
        guard !newProfile.name.isEmpty else {
            errorMessage = "Profile name is required."
            return
        }
        service.addProfile(newProfile)
        profiles = service.profiles
        newProfile = CloudProfile(name: "")
        isAddProfileSheetPresented = false
    }

    public func updateProfile(_ updated: CloudProfile) {
        service.updateProfile(updated)
        profiles = service.profiles
        isEditProfileSheetPresented = false
    }

    public func removeProfile(id: UUID) {
        service.removeProfile(id: id)
        profiles = service.profiles
        if selectedProfileID == id { selectedProfileID = profiles.first?.id }
    }

    // MARK: - Transfer Actions

    public func startUpload() {
        guard !uploadLocalPath.isEmpty, !uploadRemotePath.isEmpty else {
            errorMessage = "Local path and remote path are required."
            return
        }
        let job = CloudTransferJob(
            localPath: uploadLocalPath,
            remotePath: uploadRemotePath,
            direction: .upload,
            isRecursive: uploadRecursive,
            status: .pending
        )
        service.addJob(job)
        jobs = service.jobs
        statusMessage = "Upload job queued."
        activeTab = .jobs
    }

    public func startDownload() {
        guard !downloadRemotePath.isEmpty, !downloadLocalPath.isEmpty else {
            errorMessage = "Remote path and local path are required."
            return
        }
        let job = CloudTransferJob(
            localPath: downloadLocalPath,
            remotePath: downloadRemotePath,
            direction: .download,
            isRecursive: downloadRecursive,
            status: .pending
        )
        service.addJob(job)
        jobs = service.jobs
        statusMessage = "Download job queued."
        activeTab = .jobs
    }

    public func startSync() {
        guard !syncLocalPath.isEmpty, !syncRemotePath.isEmpty else {
            errorMessage = "Local path and remote path are required."
            return
        }
        let job = CloudTransferJob(
            localPath: syncLocalPath,
            remotePath: syncRemotePath,
            direction: syncBidirectional ? .bidirectional : .upload,
            isRecursive: true,
            status: .pending
        )
        service.addJob(job)
        jobs = service.jobs
        statusMessage = "Sync job queued."
        activeTab = .jobs
    }

    public func cancelJob(id: UUID) {
        service.removeJob(id: id)
        jobs = service.jobs
    }

    public func clearCompleted() {
        service.clearCompleted()
        jobs = service.jobs
    }
}
