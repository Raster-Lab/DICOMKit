// AIAnalysisService.swift
// DICOMStudio
//
// DICOM Studio — Service for AI Analysis state management

import Foundation

/// Thread-safe service managing AI Analysis state.
public final class AIAnalysisService: @unchecked Sendable {
    private let lock = NSLock()
    private var _models: [AIModelEntry] = []
    private var _jobs: [AIAnalysisJob] = []

    public init() {}

    // MARK: - Model Registry

    public var models: [AIModelEntry] {
        lock.withLock { _models }
    }

    public func addModel(_ model: AIModelEntry) {
        lock.withLock { _models.append(model) }
    }

    public func removeModel(id: UUID) {
        lock.withLock { _models.removeAll { $0.id == id } }
    }

    // MARK: - Jobs

    public var jobs: [AIAnalysisJob] {
        lock.withLock { _jobs }
    }

    public func addJob(_ job: AIAnalysisJob) {
        lock.withLock { _jobs.append(job) }
    }

    public func updateJob(_ updated: AIAnalysisJob) {
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
