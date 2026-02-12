import SwiftUI

/// Root content view with PACS configuration bar, category tabs, tool list, and console
struct ContentView: View {

    @State private var viewModel = ToolboxViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - PACS Configuration Bar (always visible)
            PACSConfigurationView(
                config: $viewModel.pacsConfig,
                isExpanded: $viewModel.isPACSConfigExpanded,
                isNetworkTool: viewModel.isNetworkTool
            )

            Divider()

            // MARK: - Main Content
            HSplitView {
                // Left sidebar: category tabs + tool list
                toolSidebar
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

                // Right content: parameter form + console
                VStack(spacing: 0) {
                    if let tool = viewModel.selectedTool {
                        ToolDetailView(
                            tool: tool,
                            selectedSubcommand: $viewModel.selectedSubcommand,
                            parameterValues: $viewModel.parameterValues,
                            pacsConfig: viewModel.pacsConfig,
                            onSubcommandChanged: { sub in
                                viewModel.selectSubcommand(sub)
                            }
                        )
                    } else {
                        welcomeView
                    }

                    Divider()

                    // MARK: - Console
                    ConsoleView(
                        commandString: viewModel.commandString,
                        output: viewModel.executor.output,
                        isRunning: viewModel.executor.isRunning,
                        isValid: viewModel.isCommandValid,
                        missingParams: viewModel.missingParameters,
                        onExecute: {
                            Task { await viewModel.executeCommand() }
                        },
                        onCancel: { viewModel.cancelCommand() },
                        onClear: { viewModel.clearConsole() }
                    )
                    .frame(minHeight: 150, idealHeight: 200)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sidebar

    private var toolSidebar: some View {
        VStack(spacing: 0) {
            // Category picker
            Picker("Category", selection: $viewModel.selectedCategory) {
                ForEach(ToolCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Tool list for selected category
            List(selection: Binding<String?>(
                get: { viewModel.selectedTool?.id },
                set: { newID in
                    if let id = newID,
                       let tool = viewModel.currentTools.first(where: { $0.id == id }) {
                        viewModel.selectTool(tool)
                    }
                }
            )) {
                ForEach(viewModel.currentTools) { tool in
                    ToolListRow(tool: tool)
                        .tag(tool.id)
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "stethoscope")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("DICOMKit Toolbox")
                .font(.title)
                .fontWeight(.semibold)

            Text("Select a tool from the sidebar to get started")
                .foregroundStyle(.secondary)

            Text("29 CLI tools for DICOM medical imaging")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tool List Row

struct ToolListRow: View {
    let tool: ToolDefinition

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.icon)
                .frame(width: 20)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(tool.abstract)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
