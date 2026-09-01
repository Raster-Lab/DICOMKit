// PrintQueueView.swift
// DICOMStudio
//
// DICOM Studio — the print queue screen: every submitted job with its state
// and progress, and the controls to run the queue — start, stop, pause,
// resume, resend — per job and for the queue as a whole.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct PrintQueueView: View {
    @Bindable var queue: PrintQueueService

    @State private var isConfirmingStopAll = false

    public init(queue: PrintQueueService) {
        self.queue = queue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            controls
            if queue.jobs.isEmpty {
                // Centred in the space the list would have filled, rather than
                // sized to its own text — otherwise the pane above it is pinned
                // to the top and the placeholder rides up under the controls.
                ContentUnavailableView(
                    "Queue Is Empty",
                    systemImage: "tray",
                    description: Text("Jobs submitted from the print sheet line up here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(queue.jobs) { job in
                        row(job)
                    }
                    .onMove { offsets, target in
                        queue.move(fromOffsets: offsets, toOffset: target)
                    }
                }
            }
        }
    }

    // MARK: - Queue-level controls

    private var controls: some View {
        HStack(spacing: 8) {
            if queue.isPaused {
                Label("Queue paused", systemImage: "pause.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if queue.runningJobID != nil {
                Label("Printing", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("Idle", systemImage: "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if queue.isPaused {
                Button {
                    queue.resumeQueue()
                } label: {
                    Label("Resume Queue", systemImage: "play.fill")
                }
                .help("Start working through the waiting jobs again")
            } else {
                Button {
                    queue.pauseQueue()
                } label: {
                    Label("Pause Queue", systemImage: "pause.fill")
                }
                .help("Hold the queue — the running job finishes, no new job starts")
            }

            Button(role: .destructive) {
                isConfirmingStopAll = true
            } label: {
                Label("Stop All", systemImage: "stop.fill")
            }
            .disabled(!hasActiveJobs)
            .help("Cancel the running job and stop every waiting one")

            Button {
                queue.clearFinished()
            } label: {
                Label("Clear Finished", systemImage: "xmark.bin")
            }
            .disabled(!hasFinishedJobs)
            .help("Remove completed, failed and stopped jobs from the list")
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .confirmationDialog(
            "Stop all print jobs?",
            isPresented: $isConfirmingStopAll
        ) {
            Button("Stop All", role: .destructive) { queue.stopAll() }
        } message: {
            Text("The running job is cancelled and every waiting job is stopped.")
        }
    }

    private var hasActiveJobs: Bool {
        queue.jobs.contains { !$0.state.isFinished }
    }

    private var hasFinishedJobs: Bool {
        queue.jobs.contains { $0.state.isFinished }
    }

    // MARK: - Rows

    private func row(_ job: PrintQueueJob) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol(for: job.state))
                    .foregroundStyle(color(for: job.state))
                Text(job.summary)
                    .lineLimit(1)
                if job.attempt > 1 {
                    Text("Attempt \(job.attempt)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.tint.opacity(0.2))
                        .clipShape(Capsule())
                }
                Spacer()
                actions(for: job)
            }

            HStack(spacing: 6) {
                Text(job.state.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(color(for: job.state))
                Text(job.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.state.isActive {
                ProgressView(value: job.progress)
                    .controlSize(.small)
            }
            if !job.progressMessage.isEmpty {
                Text(job.progressMessage)
                    .font(.caption)
                    .foregroundStyle(job.state.isFailure ? .red : .secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    /// The controls a job's state makes meaningful — nothing more.
    @ViewBuilder
    private func actions(for job: PrintQueueJob) -> some View {
        switch job.state {
        case .pending:
            rowButton("Start Now", symbol: "play.fill",
                      help: "Run this job next, ahead of its turn") {
                queue.start(job.id)
            }
            rowButton("Pause", symbol: "pause.fill",
                      help: "Hold this job — the queue skips it until it is resumed") {
                queue.pause(job.id)
            }
            rowButton("Stop", symbol: "stop.fill",
                      help: "Take this job out of the waiting line") {
                queue.stop(job.id)
            }
        case .paused:
            rowButton("Resume", symbol: "play.fill",
                      help: "Put this job back in the waiting line") {
                queue.resume(job.id)
            }
            rowButton("Stop", symbol: "stop.fill",
                      help: "Take this job out of the waiting line") {
                queue.stop(job.id)
            }
        case .retrying:
            rowButton("Stop", symbol: "stop.fill",
                      help: "Give up on this job instead of retrying it") {
                queue.stop(job.id)
            }
        case .submitting, .running:
            rowButton("Stop", symbol: "stop.fill",
                      help: "Cancel this job — the printer's film session is deleted") {
                queue.stop(job.id)
            }
        case .stopped, .failed, .completed:
            rowButton("Resend", symbol: "arrow.clockwise",
                      help: "Send the same job again as a new attempt") {
                queue.resend(job.id)
            }
            rowButton("Remove", symbol: "trash",
                      help: "Remove this job from the list") {
                queue.remove(job.id)
            }
        }
    }

    private func rowButton(
        _ title: String, symbol: String, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .interactiveControl(cornerRadius: 5, horizontal: 4, vertical: 3)
        .help(help)
        .accessibilityLabel(title)
    }

    private func symbol(for state: PrintQueueJob.State) -> String {
        switch state {
        case .pending:    return "clock"
        case .submitting: return "arrow.up.circle"
        case .running:    return "play.circle.fill"
        case .paused:     return "pause.circle.fill"
        case .stopped:    return "stop.circle"
        case .retrying:   return "arrow.triangle.2.circlepath.circle"
        case .failed:     return "xmark.circle.fill"
        case .completed:  return "checkmark.circle.fill"
        }
    }

    private func color(for state: PrintQueueJob.State) -> Color {
        switch state {
        case .pending:              return .secondary
        case .submitting, .running: return .blue
        case .paused, .retrying:    return .orange
        case .stopped:              return .secondary
        case .failed:               return .red
        case .completed:            return .green
        }
    }
}

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintQueueJob.State {
    /// Whether the row's message line should read as an error.
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview {
    PrintQueueView(queue: PrintQueueService(audit: PrintAuditTrail()))
}
#endif
