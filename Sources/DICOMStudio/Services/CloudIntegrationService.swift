// CloudIntegrationService.swift
// DICOMStudio
//
// DICOM Studio — Service for Cloud Integration state management

import Foundation

/// Thread-safe service managing Cloud Integration state.
public final class CloudIntegrationService: @unchecked Sendable {
    private let lock = NSLock()
    private var _profiles: [CloudProfile] = []
    private var _jobs: [CloudTransferJob] = []

    public init() {}

    // MARK: - Profiles

    public var profiles: [CloudProfile] {
        lock.withLock { _profiles }
    }

    public func addProfile(_ profile: CloudProfile) {
        lock.withLock { _profiles.append(profile) }
    }

    public func updateProfile(_ updated: CloudProfile) {
        lock.withLock {
            if let idx = _profiles.firstIndex(where: { $0.id == updated.id }) {
                _profiles[idx] = updated
            }
        }
    }

    public func removeProfile(id: UUID) {
        lock.withLock { _profiles.removeAll { $0.id == id } }
    }

    public var activeProfile: CloudProfile? {
        lock.withLock { _profiles.first { $0.isActive } }
    }

    // MARK: - Jobs

    public var jobs: [CloudTransferJob] {
        lock.withLock { _jobs }
    }

    public func addJob(_ job: CloudTransferJob) {
        lock.withLock { _jobs.append(job) }
    }

    public func updateJob(_ updated: CloudTransferJob) {
        lock.withLock {
            if let idx = _jobs.firstIndex(where: { $0.id == updated.id }) {
                _jobs[idx] = updated
            }
        }
    }

    public func removeJob(id: UUID) {
        lock.withLock { _jobs.removeAll { $0.id == id } }
    }

    public func clearCompleted() {
        lock.withLock { _jobs.removeAll { $0.status == .completed } }
    }
}
