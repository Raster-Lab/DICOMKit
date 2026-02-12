#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Console window showing command preview and execution output
public struct ConsoleView: View {
    let toolID: String?
    let parameterValues: [String: String]
    let subcommand: String?
    let networkConfig: NetworkConfigModel
    @Binding var output: String
    @Binding var status: ExecutionStatus
    @Binding var historyEntries: [CommandHistoryEntry]

    @State private var executor = CommandExecutor()
    @State private var showHistory = false

    public init(
        toolID: String?,
        parameterValues: [String: String],
        subcommand: String?,
        networkConfig: NetworkConfigModel,
        output: Binding<String>,
        status: Binding<ExecutionStatus>,
        historyEntries: Binding<[CommandHistoryEntry]>
    ) {
        self.toolID = toolID
        self.parameterValues = parameterValues
        self.subcommand = subcommand
        self.networkConfig = networkConfig
        self._output = output
        self._status = status
        self._historyEntries = historyEntries
    }

    private var commandBuilder: CommandBuilder? {
        guard let toolID, let tool = ToolRegistry.tool(withID: toolID) else {
            return nil
        }
        let config = tool.requiresNetwork ? networkConfig.toNetworkConfig() : nil
        return CommandBuilder(tool: tool, networkConfig: config)
    }

    private var commandString: String {
        commandBuilder?.buildCommand(values: parameterValues, subcommand: subcommand) ?? "Select a tool to begin"
    }

    private var isCommandValid: Bool {
        commandBuilder?.isValid(values: parameterValues, subcommand: subcommand) ?? false
    }

    private var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Command preview line
                HStack {
                    Text("$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.green)

                    Text(commandString)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.tail)

                    Spacer()

                    // History button
                    Button(action: { showHistory.toggle() }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("Command History")
                    .popover(isPresented: $showHistory) {
                        historyPopover
                    }

                    // Copy button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commandString, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy command to clipboard")

                    // Cancel button (shown during execution)
                    if isRunning {
                        Button(action: {
                            Task {
                                await executor.cancel()
                                status = .completed(exitCode: -1)
                                output += "\n[Cancelled]"
                            }
                        }) {
                            Label("Cancel", systemImage: "stop.fill")
                                .foregroundStyle(.red)
                        }
                        .help("Cancel running command")
                    }

                    // Execute button
                    Button(action: executeCommand) {
                        Label("Run", systemImage: "play.fill")
                    }
                    .disabled(!isCommandValid || isRunning)
                    .keyboardShortcut(.return, modifiers: .command)

                    // Re-run button (shown when there's history)
                    if !historyEntries.isEmpty && !isRunning {
                        Button(action: {
                            if let last = historyEntries.first {
                                rerunEntry(last)
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .help("Re-run last command")
                    }

                    // Status indicator
                    statusIndicator
                }

                Divider()

                // Output area
                ScrollView {
                    if output.isEmpty {
                        Text("Command output will appear here after execution")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(minHeight: 100, maxHeight: 200)

                // Bottom bar
                HStack {
                    if case .completed(let exitCode) = status {
                        Text("Exit code: \(exitCode)")
                            .font(.caption)
                            .foregroundStyle(exitCode == 0 ? .green : .red)
                    }
                    Spacer()
                    Button("Clear") {
                        output = ""
                        status = .idle
                    }
                    .disabled(output.isEmpty)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed(let exitCode):
            if exitCode == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Command Execution

    private func executeCommand() {
        guard isCommandValid, let toolID else { return }
        let cmd = commandString
        output = ""
        status = .running

        let entry = CommandHistoryEntry(
            toolID: toolID,
            subcommand: subcommand,
            parameterValues: parameterValues,
            commandString: cmd
        )

        Task {
            do {
                let exitCode = try await executor.execute(command: cmd) { line in
                    Task { @MainActor in
                        output += line
                    }
                }
                await MainActor.run {
                    status = .completed(exitCode: exitCode)
                    let completed = entry.withExitCode(exitCode)
                    CommandHistory.addEntry(completed, to: &historyEntries)
                    CommandHistory.save(historyEntries)
                }
            } catch {
                await MainActor.run {
                    output += "\nError: \(error.localizedDescription)"
                    status = .completed(exitCode: -1)
                    let failed = entry.withExitCode(-1)
                    CommandHistory.addEntry(failed, to: &historyEntries)
                    CommandHistory.save(historyEntries)
                }
            }
        }
    }

    private func rerunEntry(_ entry: CommandHistoryEntry) {
        output = ""
        status = .running
        let cmd = entry.commandString

        Task {
            do {
                let exitCode = try await executor.execute(command: cmd) { line in
                    Task { @MainActor in
                        output += line
                    }
                }
                await MainActor.run {
                    status = .completed(exitCode: exitCode)
                    let rerun = CommandHistoryEntry(
                        toolID: entry.toolID,
                        subcommand: entry.subcommand,
                        parameterValues: entry.parameterValues,
                        commandString: cmd,
                        exitCode: exitCode
                    )
                    CommandHistory.addEntry(rerun, to: &historyEntries)
                    CommandHistory.save(historyEntries)
                }
            } catch {
                await MainActor.run {
                    output += "\nError: \(error.localizedDescription)"
                    status = .completed(exitCode: -1)
                }
            }
        }
    }

    // MARK: - History Popover

    @ViewBuilder
    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Command History")
                    .font(.headline)
                Spacer()
                Button("Export as Script") {
                    let script = CommandHistory.exportAsShellScript(historyEntries)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(script, forType: .string)
                }
                .disabled(historyEntries.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if historyEntries.isEmpty {
                Text("No commands in history")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(historyEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let exitCode = entry.exitCode {
                                Image(systemName: exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(exitCode == 0 ? .green : .red)
                                    .font(.caption)
                            }
                            Text(entry.commandString)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Text(entry.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.commandString, forType: .string)
                    }
                }
                .frame(width: 450, height: 300)
            }
        }
    }
}
#endif

