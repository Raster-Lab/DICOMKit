import Foundation

/// Builds CLI command strings from tool definitions and user-provided parameter values
enum CommandBuilder {

    /// Builds the complete command line string from a tool definition, selected subcommand, and parameter values
    /// - Parameters:
    ///   - tool: The tool definition
    ///   - subcommand: The selected subcommand (if any)
    ///   - values: Dictionary mapping parameter IDs to their current values
    ///   - pacsConfig: The global PACS configuration for auto-filling network parameters
    /// - Returns: The complete command line string
    static func buildCommand(
        tool: ToolDefinition,
        subcommand: SubcommandDefinition?,
        values: [String: String],
        pacsConfig: PACSConfiguration
    ) -> String {
        var parts: [String] = [tool.command]

        // Add subcommand if present
        if let sub = subcommand {
            parts.append(sub.name.lowercased())
        }

        let parameters = subcommand?.parameters ?? tool.parameters
        var positionalArgs: [String] = []

        for param in parameters {
            let value = resolvedValue(for: param, values: values, pacsConfig: pacsConfig)

            guard let val = value, !val.isEmpty else { continue }

            switch param.type {
            case .flag:
                if val == "true" {
                    parts.append(param.cliFlag)
                }
            case .positionalArgument, .positionalFile, .positionalDirectory, .positionalFiles:
                positionalArgs.append(shellEscape(val))
            case .multiText:
                let items = val.components(separatedBy: "\n").filter { !$0.isEmpty }
                for item in items {
                    parts.append(param.cliFlag)
                    parts.append(shellEscape(item))
                }
            default:
                if !param.cliFlag.isEmpty {
                    parts.append(param.cliFlag)
                    parts.append(shellEscape(val))
                }
            }
        }

        // Positional arguments go at the end (or mixed as appropriate)
        // Actually for most tools, positional args come right after the command/subcommand
        // We'll insert them after command+subcommand
        if !positionalArgs.isEmpty {
            let insertIdx = subcommand != nil ? 2 : 1
            for (i, arg) in positionalArgs.enumerated() {
                parts.insert(arg, at: insertIdx + i)
            }
        }

        return parts.joined(separator: " ")
    }

    /// Checks whether all required parameters have valid values
    static func isValid(
        tool: ToolDefinition,
        subcommand: SubcommandDefinition?,
        values: [String: String],
        pacsConfig: PACSConfiguration
    ) -> Bool {
        let parameters = subcommand?.parameters ?? tool.parameters
        for param in parameters where param.isRequired {
            let value = resolvedValue(for: param, values: values, pacsConfig: pacsConfig)
            if value == nil || value!.isEmpty {
                return false
            }
        }
        return true
    }

    /// Returns missing required parameters
    static func missingRequired(
        tool: ToolDefinition,
        subcommand: SubcommandDefinition?,
        values: [String: String],
        pacsConfig: PACSConfiguration
    ) -> [ToolParameter] {
        let parameters = subcommand?.parameters ?? tool.parameters
        return parameters.filter { param in
            guard param.isRequired else { return false }
            let value = resolvedValue(for: param, values: values, pacsConfig: pacsConfig)
            return value == nil || value!.isEmpty
        }
    }

    // MARK: - Private

    private static func resolvedValue(
        for param: ToolParameter,
        values: [String: String],
        pacsConfig: PACSConfiguration
    ) -> String? {
        // Check user-provided value first
        if let userValue = values[param.id], !userValue.isEmpty {
            return userValue
        }

        // Auto-fill from PACS configuration for network parameters
        if param.isPACSParameter {
            return pacsValue(for: param, config: pacsConfig)
        }

        return nil
    }

    private static func pacsValue(for param: ToolParameter, config: PACSConfiguration) -> String? {
        let flag = param.cliFlag.lowercased()
        if flag == "--aet" || param.name.lowercased().contains("ae title") && !flag.contains("called") {
            return config.localAETitle.isEmpty ? nil : config.localAETitle
        }
        if flag == "--called-aet" {
            return config.remoteAETitle.isEmpty ? nil : config.remoteAETitle
        }
        if flag == "--move-dest" {
            return config.moveDestination.isEmpty ? nil : config.moveDestination
        }
        // Positional argument for PACS URL
        if case .positionalArgument = param.type {
            if param.name.lowercased().contains("url") || param.help.lowercased().contains("pacs") {
                // Check if this looks like a DICOMweb URL parameter
                if param.help.lowercased().contains("dicomweb") || param.help.lowercased().contains("https") {
                    return config.dicomwebBaseURL.isEmpty ? nil : config.dicomwebBaseURL
                }
                return config.pacsURL.isEmpty ? nil : config.pacsURL
            }
        }
        return nil
    }

    private static func shellEscape(_ value: String) -> String {
        if value.contains(" ") || value.contains("*") || value.contains("'") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return value
    }
}
