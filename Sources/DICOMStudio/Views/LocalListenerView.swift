// LocalListenerView.swift
// DICOMStudio
//
// Local SCP listener status panel and event log view.

#if canImport(SwiftUI)
import SwiftUI

/// Displays the local DICOM SCP listener status, configuration, and a
/// real-time event log of all incoming DICOM associations and received files.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct LocalListenerView: View {
    @Bindable var viewModel: CLIWorkshopViewModel
    @State private var showConfig = false

    public init(viewModel: CLIWorkshopViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider()
            configSection
            Divider()
            logSection
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.scpIsRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.scpIsRunning ? "Listener Running" : "Listener Stopped")
                    .font(.headline)
                Text(viewModel.scpStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    if viewModel.scpIsRunning {
                        await viewModel.stopLocalSCP()
                    } else {
                        await viewModel.startLocalSCP()
                    }
                }
            } label: {
                Label(
                    viewModel.scpIsRunning ? "Stop" : "Start",
                    systemImage: viewModel.scpIsRunning ? "stop.circle" : "play.circle"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(viewModel.scpIsRunning ? .red : .green)
            .accessibilityLabel(viewModel.scpIsRunning ? "Stop local SCP listener" : "Start local SCP listener")
        }
        .padding()
    }

    // MARK: - Configuration Row

    private var configSection: some View {
        DisclosureGroup(isExpanded: $showConfig) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Port")
                        .font(.caption.bold())
                        .frame(width: 80, alignment: .leading)
                    TextField("11112", text: $viewModel.scpPort)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(maxWidth: 100)
                        .disabled(viewModel.scpIsRunning)
                        .accessibilityLabel("Listener port")
                }
                HStack {
                    Text("AE Title")
                        .font(.caption.bold())
                        .frame(width: 80, alignment: .leading)
                    TextField("DICOMSTUDIO", text: $viewModel.scpAETitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(maxWidth: 160)
                        .disabled(viewModel.scpIsRunning)
                        .accessibilityLabel("Local AE title")
                }
                HStack {
                    Text("Output Dir")
                        .font(.caption.bold())
                        .frame(width: 80, alignment: .leading)
                    TextField("~/Downloads", text: $viewModel.scpOutputDir)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .disabled(viewModel.scpIsRunning)
                        .accessibilityLabel("Output directory for received DICOM files")
                }
                if viewModel.scpIsRunning {
                    Text("Stop the listener before changing configuration.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
            .padding(.horizontal)
            .padding(.bottom, 8)
        } label: {
            Label("Configuration", systemImage: "gearshape")
                .font(.caption.bold())
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .accessibilityLabel("Listener configuration")
    }

    // MARK: - Event Log

    private var logSection: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Event Log", systemImage: "list.bullet.rectangle")
                    .font(.caption.bold())
                Spacer()
                if !viewModel.appLog.isEmpty {
                    Text("\(viewModel.appLog.count) event\(viewModel.appLog.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Clear") {
                        viewModel.clearAppLog()
                    }
                    .font(.caption)
                    .accessibilityLabel("Clear event log")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if viewModel.appLog.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No events yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Start the listener and connect from another DICOM application.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.appLog) { entry in
                            logEntryRow(entry)
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        }
    }

    private func logEntryRow(_ entry: SCPLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.sfSymbol)
                .font(.system(size: 12))
                .foregroundStyle(levelColor(entry.level))
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(entry.timestamp, style: .time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let ae = entry.remoteAETitle {
                        Text(ae)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let host = entry.remoteHost {
                        Text(host)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.level.rawValue): \(entry.message)")
    }

    private func levelColor(_ level: SCPLogLevel) -> Color {
        switch level {
        case .info:         return .secondary
        case .connection:   return .blue
        case .fileReceived: return .green
        case .warning:      return .orange
        case .error:        return .red
        }
    }
}

#endif
