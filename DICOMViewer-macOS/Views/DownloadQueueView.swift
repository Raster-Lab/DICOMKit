//
//  DownloadQueueView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// View showing the PACS download queue with progress
struct DownloadQueueView: View {
    @State private var viewModel = DownloadQueueViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            summaryBar

            Divider()

            // Download items list
            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Downloads from PACS will appear here")
                )
            } else {
                List(viewModel.items) { item in
                    DownloadItemRow(item: item, viewModel: viewModel)
                }
                .listStyle(.inset)
            }

            Divider()

            bottomBar
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 16) {
            Label("Downloads", systemImage: "arrow.down.circle")
                .font(.headline)

            Spacer()

            if viewModel.totalCount > 0 {
                SummaryBadge(
                    label: "Active",
                    count: viewModel.activeCount,
                    color: .blue
                )
                SummaryBadge(
                    label: "Completed",
                    count: viewModel.completedCount,
                    color: .green
                )
                SummaryBadge(
                    label: "Failed",
                    count: viewModel.failedCount,
                    color: .red
                )
            } else {
                Text("No downloads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("Clear Finished") {
                Task { await viewModel.clearFinished() }
            }
            .disabled(viewModel.completedCount + viewModel.failedCount == 0)

            Spacer()

            Button("Close") { dismiss() }
        }
        .padding()
    }
}

// MARK: - Summary Badge

/// Small badge showing a count with a colored indicator
struct SummaryBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Download Item Row

/// Row view for a single download item
struct DownloadItemRow: View {
    let item: DownloadManager.DownloadItem
    let viewModel: DownloadQueueViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.headline)

                    Text(item.serverName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge

                if item.status == .queued || item.status == .downloading {
                    Button {
                        Task { await viewModel.cancelDownload(item) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel Download")
                }
            }

            // Progress bar (downloading only)
            if item.status == .downloading {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)

                    HStack {
                        if item.totalInstances > 0 {
                            Text("\(item.completedInstances) / \(item.totalInstances) instances")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Spacer()

                        Text("\(Int(item.progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Error message (failed only)
            if item.status == .failed, let error = item.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            // Elapsed time for completed items
            if item.status == .completed, let elapsed = item.elapsedTime {
                Text(String(format: "Completed in %.1f seconds", elapsed))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(item.status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch item.status {
        case .queued:
            return .secondary
        case .downloading:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}

#Preview("Download Queue") {
    DownloadQueueView()
}
