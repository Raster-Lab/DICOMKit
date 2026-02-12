import SwiftUI

/// Console view showing the generated command and execution output
struct ConsoleView: View {

    let commandString: String
    let output: String
    let isRunning: Bool
    let isValid: Bool
    let missingParams: [ToolParameter]
    let onExecute: () -> Void
    let onCancel: () -> Void
    let onClear: () -> Void

    @State private var isShowingMissing = false

    var body: some View {
        VStack(spacing: 0) {
            // Command bar
            commandBar

            Divider()

            // Output area
            outputArea
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Command Bar

    private var commandBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Command display in monospace
            ScrollView(.horizontal, showsIndicators: false) {
                Text(commandString.isEmpty ? "Select a tool to build a command…" : commandString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(commandString.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer()

            // Copy button
            if !commandString.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commandString, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy command to clipboard")
            }

            // Missing parameters indicator
            if !missingParams.isEmpty && !commandString.isEmpty {
                Button {
                    isShowingMissing.toggle()
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Missing required parameters")
                .popover(isPresented: $isShowingMissing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Missing Required Parameters")
                            .font(.headline)

                        ForEach(missingParams) { param in
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                Text(param.name)
                            }
                            .font(.body)
                        }
                    }
                    .padding(12)
                }
            }

            // Execute / Cancel button
            if isRunning {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .tint(.red)
            } else {
                Button("Execute", action: onExecute)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || commandString.isEmpty)
                    .help(isValid ? "Run this command" : "Fill required parameters first")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                Text(output.isEmpty ? "Output will appear here after execution…" : output)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(output.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color(nsColor: .textBackgroundColor))

            // Clear button
            if !output.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(8)
                .help("Clear output")
            }

            // Running indicator
            if isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(8)
            }
        }
    }
}
