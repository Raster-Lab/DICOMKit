// PrintProgressView.swift
// DICOMStudio
//
// DICOM Studio — live progress of a running print job, the printer's own
// N-EVENT-REPORT notifications, and the outcome with per-film job UIDs.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PrintProgressView: View {
    @Bindable var viewModel: PrintViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressHeader
            console
            if case .finished = viewModel.phase {
                outcome
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressHeader: some View {
        if viewModel.isRunning {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: viewModel.progress) {
                    Text(headerMessage)
                }
                .font(.callout)
                .progressViewStyle(.linear)
                .accessibilityLabel("Print progress")
                .accessibilityValue(headerMessage)
            }
        }
    }

    /// What the progress bar calls the current state.
    ///
    /// "Working…" is only true once the job is actually running: a job waiting
    /// behind a paused queue makes no progress, and labelling that as work makes
    /// a stalled queue look like a slow printer.
    private var headerMessage: String {
        if !viewModel.progressMessage.isEmpty { return viewModel.progressMessage }
        return viewModel.isWaitingOnQueue ? "Waiting in the print queue…" : "Working…"
    }

    // MARK: - Console

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.consoleLines) { line in
                        Text(line.text)
                            // Body size, not caption: this is the record of what
                            // was sent to the printer and it is read across a
                            // room, not squinted at.
                            .font(.system(size: StudioTypography.bodySize, design: .monospaced))
                            .foregroundStyle(color(for: line.level))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .background(.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxHeight: .infinity)
            .onChange(of: viewModel.consoleLines.count) { _, _ in
                if let last = viewModel.consoleLines.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func color(for level: PrintViewModel.ConsoleLine.Level) -> Color {
        switch level {
        case .info:    return .green
        case .notice:  return .white
        case .warning: return .yellow
        case .failure: return .red
        case .success: return .green
        }
    }

    // MARK: - Outcome

    @ViewBuilder
    private var outcome: some View {
        if let result = viewModel.result, result.success {
            VStack(alignment: .leading, spacing: 8) {
                if result.printJobUIDs.isEmpty {
                    Text("The printer did not return a print job UID, so job status cannot be polled.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(result.printJobUIDs.enumerated()), id: \.offset) { index, uid in
                        HStack {
                            Text(result.printJobUIDs.count > 1
                                 ? "Film \(index + 1): \(uid)" : uid)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Button("Check Status") {
                                Task { await viewModel.refreshJobStatus(printJobUID: uid) }
                            }
                            .controlSize(.small)
                        }
                    }
                }

                if let status = viewModel.jobStatus {
                    Label(
                        "Execution status: \(status.executionStatus)"
                            + (status.executionStatusInfo.map { " (\($0))" } ?? ""),
                        systemImage: status.isFailed
                            ? "exclamationmark.triangle.fill"
                            : (status.isCompleted ? "checkmark.circle.fill" : "clock")
                    )
                    .font(.callout)
                }
            }
        }
    }
}
#endif
