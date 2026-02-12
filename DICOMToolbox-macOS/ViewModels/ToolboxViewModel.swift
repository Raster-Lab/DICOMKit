import Foundation

/// Main view model managing app-wide state: tool selection, PACS config, and command execution
@MainActor
@Observable
final class ToolboxViewModel {

    // MARK: - Tool Selection

    /// Currently selected tool category tab
    var selectedCategory: ToolCategory = .fileAnalysis

    /// Currently selected tool within the category
    var selectedTool: ToolDefinition?

    /// Currently selected subcommand (if the tool has subcommands)
    var selectedSubcommand: SubcommandDefinition?

    // MARK: - PACS Configuration

    /// Global PACS configuration shared by all network tools
    var pacsConfig = PACSConfiguration()

    /// Whether the PACS configuration panel is expanded
    var isPACSConfigExpanded: Bool = false

    // MARK: - Parameter Values

    /// Current parameter values keyed by parameter ID
    var parameterValues: [String: String] = [:]

    // MARK: - Command Execution

    /// The command executor for running CLI commands
    let executor = CommandExecutor()

    // MARK: - Computed Properties

    /// Tools in the currently selected category
    var currentTools: [ToolDefinition] {
        ToolRegistry.tools(for: selectedCategory)
    }

    /// The active parameters (either from subcommand or tool)
    var activeParameters: [ToolParameter] {
        if let sub = selectedSubcommand {
            return sub.parameters
        }
        return selectedTool?.parameters ?? []
    }

    /// The built command string from current selections
    var commandString: String {
        guard let tool = selectedTool else { return "" }
        return CommandBuilder.buildCommand(
            tool: tool,
            subcommand: selectedSubcommand,
            values: parameterValues,
            pacsConfig: pacsConfig
        )
    }

    /// Whether the current configuration produces a valid command
    var isCommandValid: Bool {
        guard let tool = selectedTool else { return false }
        return CommandBuilder.isValid(
            tool: tool,
            subcommand: selectedSubcommand,
            values: parameterValues,
            pacsConfig: pacsConfig
        )
    }

    /// Missing required parameters
    var missingParameters: [ToolParameter] {
        guard let tool = selectedTool else { return [] }
        return CommandBuilder.missingRequired(
            tool: tool,
            subcommand: selectedSubcommand,
            values: parameterValues,
            pacsConfig: pacsConfig
        )
    }

    /// Whether any network tool is selected
    var isNetworkTool: Bool {
        guard let tool = selectedTool else { return false }
        return tool.category == .networking || tool.category == .dicomweb
    }

    // MARK: - Actions

    /// Select a tool and reset parameter state
    func selectTool(_ tool: ToolDefinition) {
        selectedTool = tool
        selectedSubcommand = tool.subcommands?.first
        parameterValues = [:]

        // Apply default values
        let params = selectedSubcommand?.parameters ?? tool.parameters
        for param in params {
            if let defaultVal = param.defaultValue {
                parameterValues[param.id] = defaultVal
            }
        }
    }

    /// Select a subcommand and reset parameter state
    func selectSubcommand(_ subcommand: SubcommandDefinition) {
        selectedSubcommand = subcommand
        parameterValues = [:]

        for param in subcommand.parameters {
            if let defaultVal = param.defaultValue {
                parameterValues[param.id] = defaultVal
            }
        }
    }

    /// Update a parameter value
    func setValue(_ value: String, for paramID: String) {
        parameterValues[paramID] = value
    }

    /// Execute the current command
    func executeCommand() async {
        let command = commandString
        guard !command.isEmpty else { return }
        await executor.execute(command: command)
    }

    /// Cancel a running command
    func cancelCommand() {
        executor.cancel()
    }

    /// Clear the console output
    func clearConsole() {
        executor.output = ""
        executor.state = .idle
    }
}
