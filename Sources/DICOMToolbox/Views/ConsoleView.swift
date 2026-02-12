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

    public init(
        toolID: String?,
        parameterValues: [String: String],
        subcommand: String?,
        networkConfig: NetworkConfigModel,
        output: Binding<String>,
        status: Binding<ExecutionStatus>
    ) {
        self.toolID = toolID
        self.parameterValues = parameterValues
        self.subcommand = subcommand
        self.networkConfig = networkConfig
        self._output = output
        self._status = status
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

                    // Copy button
                    Button(action: {
                        #if canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commandString, forType: .string)
                        #endif
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy command to clipboard")

                    // Execute button
                    Button(action: {
                        // Execute command via Process
                    }) {
                        Label("Run", systemImage: "play.fill")
                    }
                    .disabled(!isCommandValid)
                    .keyboardShortcut(.return, modifiers: .command)

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
}
#endif
