//
//  DownloadQueueViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI

/// ViewModel for managing the download queue UI
@MainActor
@Observable
final class DownloadQueueViewModel {
    // MARK: - State

    /// All download items
    private(set) var items: [DownloadManager.DownloadItem] = []

    /// Total number of items in the queue
    private(set) var totalCount = 0

    /// Number of actively downloading items
    private(set) var activeCount = 0

    /// Number of completed items
    private(set) var completedCount = 0

    /// Number of failed items
    private(set) var failedCount = 0

    // MARK: - Private Properties

    private var refreshTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Refresh items from the DownloadManager
    func refresh() async {
        let manager = DownloadManager.shared
        items = await manager.allItems
        totalCount = await manager.totalCount
        activeCount = await manager.activeCount
        completedCount = await manager.completedCount
        failedCount = await manager.failedCount
    }

    /// Start periodic refresh of download status
    func startRefreshing() {
        stopRefreshing()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Stop periodic refresh
    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Cancel a specific download
    func cancelDownload(_ item: DownloadManager.DownloadItem) async {
        await DownloadManager.shared.cancel(id: item.id)
        await refresh()
    }

    /// Clear all finished (completed, failed, cancelled) items
    func clearFinished() async {
        await DownloadManager.shared.clearFinished()
        await refresh()
    }

    /// Remove a specific item from the queue
    func removeItem(_ item: DownloadManager.DownloadItem) async {
        await DownloadManager.shared.remove(id: item.id)
        await refresh()
    }
}
