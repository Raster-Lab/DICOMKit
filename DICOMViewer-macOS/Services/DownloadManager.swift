//
//  DownloadManager.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import DICOMNetwork

/// Manages a queue of DICOM download operations
actor DownloadManager {
    /// Shared instance
    static let shared = DownloadManager()

    /// Download item representing a pending/active/completed download
    struct DownloadItem: Identifiable, Sendable {
        let id: UUID
        let serverName: String
        let studyDescription: String
        let patientName: String
        let studyInstanceUID: String
        let seriesInstanceUID: String?  // nil means whole study
        var status: DownloadStatus
        var progress: Double  // 0.0 to 1.0
        var completedInstances: Int
        var totalInstances: Int
        var error: String?
        var startTime: Date?
        var endTime: Date?

        init(
            serverName: String,
            studyDescription: String,
            patientName: String,
            studyInstanceUID: String,
            seriesInstanceUID: String? = nil
        ) {
            self.id = UUID()
            self.serverName = serverName
            self.studyDescription = studyDescription
            self.patientName = patientName
            self.studyInstanceUID = studyInstanceUID
            self.seriesInstanceUID = seriesInstanceUID
            self.status = .queued
            self.progress = 0.0
            self.completedInstances = 0
            self.totalInstances = 0
            self.error = nil
            self.startTime = nil
            self.endTime = nil
        }

        var displayTitle: String {
            if seriesInstanceUID != nil {
                return "\(patientName) - Series"
            }
            return "\(patientName) - \(studyDescription)"
        }

        var elapsedTime: TimeInterval? {
            guard let start = startTime else { return nil }
            let end = endTime ?? Date()
            return end.timeIntervalSince(start)
        }
    }

    /// Status of a download item
    enum DownloadStatus: String, Sendable {
        case queued = "Queued"
        case downloading = "Downloading"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }

    // MARK: - Properties

    private var items: [DownloadItem] = []
    private var activeDownloadCount = 0
    private let maxConcurrentDownloads = 2

    // MARK: - Public API

    /// Get all download items
    var allItems: [DownloadItem] { items }

    /// Get active (queued + downloading) items
    var activeItems: [DownloadItem] {
        items.filter { $0.status == .queued || $0.status == .downloading }
    }

    /// Get completed items
    var completedItems: [DownloadItem] {
        items.filter { $0.status == .completed }
    }

    /// Get failed items
    var failedItems: [DownloadItem] {
        items.filter { $0.status == .failed }
    }

    /// Add a download to the queue
    @discardableResult
    func enqueue(
        serverName: String,
        studyDescription: String,
        patientName: String,
        studyInstanceUID: String,
        seriesInstanceUID: String? = nil
    ) -> UUID {
        let item = DownloadItem(
            serverName: serverName,
            studyDescription: studyDescription,
            patientName: patientName,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID
        )
        items.append(item)
        return item.id
    }

    /// Update download progress
    func updateProgress(id: UUID, progress: Double, completed: Int, total: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].progress = progress
        items[index].completedInstances = completed
        items[index].totalInstances = total
    }

    /// Mark download as started
    func markStarted(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .downloading
        items[index].startTime = Date()
        activeDownloadCount += 1
    }

    /// Mark download as completed
    func markCompleted(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .completed
        items[index].progress = 1.0
        items[index].endTime = Date()
        activeDownloadCount -= 1
    }

    /// Mark download as failed
    func markFailed(id: UUID, error: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .failed
        items[index].error = error
        items[index].endTime = Date()
        activeDownloadCount -= 1
    }

    /// Cancel a download
    func cancel(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if items[index].status == .downloading {
            activeDownloadCount -= 1
        }
        items[index].status = .cancelled
        items[index].endTime = Date()
    }

    /// Remove completed/failed/cancelled items
    func clearFinished() {
        items.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }

    /// Remove a specific item
    func remove(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            if items[index].status == .downloading {
                activeDownloadCount -= 1
            }
            items.remove(at: index)
        }
    }

    /// Check if more downloads can be started
    var canStartMore: Bool {
        activeDownloadCount < maxConcurrentDownloads
    }

    /// Get count of total/active/completed items
    var totalCount: Int { items.count }
    var activeCount: Int { activeDownloadCount }
    var queuedCount: Int { items.filter { $0.status == .queued }.count }
    var completedCount: Int { items.filter { $0.status == .completed }.count }
    var failedCount: Int { items.filter { $0.status == .failed }.count }
}
