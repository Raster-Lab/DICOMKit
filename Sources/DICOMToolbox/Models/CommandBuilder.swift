import Foundation

/// Execution status for the console display
public enum ExecutionStatus: Sendable {
    case idle
    case running
    case completed(exitCode: Int)

    /// Whether the execution completed successfully (exit code 0)
    public var isSuccess: Bool {
        if case .completed(let code) = self { return code == 0 }
        return false
    }
}

/// Builds CLI command strings from tool definitions and parameter values,
/// validates required parameters, and executes commands.
public final class CommandBuilder: Sendable {
    /// The tool definition this builder is configured for
    public let tool: ToolDefinition

    /// Network configuration for network-aware tools
    public let networkConfig: NetworkConfig?

    public init(tool: ToolDefinition, networkConfig: NetworkConfig? = nil) {
        self.tool = tool
        self.networkConfig = networkConfig
    }

    /// Builds the full CLI command string from the provided parameter values.
    ///
    /// - Parameters:
    ///   - values: Dictionary mapping parameter IDs to their string values
    ///   - subcommand: Optional subcommand name for tools with subcommands
    /// - Returns: The complete CLI command string
    public func buildCommand(values: [String: String], subcommand: String? = nil) -> String {
        var parts: [String] = [tool.id]

        // Add subcommand if specified
        if let subcommand {
            parts.append(subcommand)
        }

        // Determine which parameters to use
        let parameters: [ParameterDefinition]
        if let subcommand, let subcommands = tool.subcommands,
           let sub = subcommands.first(where: { $0.id == subcommand }) {
            parameters = sub.parameters
        } else {
            parameters = tool.parameters
        }

        // Add network config parameters for network tools if not overridden
        if tool.requiresNetwork, let config = networkConfig {
            // Add URL as the first argument if not already provided
            if !values.keys.contains("url"), !values.keys.contains("base-url") {
                parts.append(config.serverURL)
            }

            // Add AE Title if not overridden
            if !values.keys.contains("aet") {
                parts.append("--aet")
                parts.append(config.aeTitle)
            }

            // Add Called AET if not overridden
            if !values.keys.contains("called-aet") {
                parts.append("--called-aet")
                parts.append(config.calledAET)
            }

            // Add timeout if not overridden
            if !values.keys.contains("timeout") {
                parts.append("--timeout")
                parts.append(String(config.timeout))
            }
        }

        // Build parameter arguments
        for param in parameters {
            guard let value = values[param.id], !value.isEmpty else {
                continue
            }

            switch param.type {
            case .boolean:
                // Only add the flag if the value is "true"
                if value == "true" {
                    parts.append(param.cliFlag)
                }

            case .file:
                if param.cliFlag.isEmpty || param.cliFlag == "@argument" {
                    // Positional argument - add value directly
                    parts.append(value)
                } else {
                    parts.append(param.cliFlag)
                    parts.append(value)
                }

            case .repeatable:
                // Split comma-separated values into individual flag instances,
                // preserving DICOM tag notation (GGGG,EEEE) where commas are
                // part of the tag identifier.
                let rawItems = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var items: [String] = []
                var idx = 0
                while idx < rawItems.count {
                    let current = rawItems[idx]
                    // If current is exactly a 4-hex-digit group, try to pair it
                    // with the next item to form a DICOM tag (GGGG,EEEE)
                    if idx + 1 < rawItems.count,
                       current.count == 4,
                       current.allSatisfy({ $0.isHexDigit }) {
                        let next = rawItems[idx + 1]
                        let nextPrefix = next.prefix(4)
                        if nextPrefix.count == 4, nextPrefix.allSatisfy({ $0.isHexDigit }) {
                            items.append("\(current),\(next)")
                            idx += 2
                            continue
                        }
                    }
                    items.append(current)
                    idx += 1
                }
                for item in items {
                    parts.append(param.cliFlag)
                    parts.append(item)
                }

            default:
                parts.append(param.cliFlag)
                parts.append(value)
            }
        }

        // Add values for parameters not in the definition (e.g. URL, extra args)
        let definedIDs = Set(parameters.map(\.id))
        let networkIDs: Set<String> = ["url", "base-url", "aet", "called-aet", "timeout"]
        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            if !definedIDs.contains(key) && !networkIDs.contains(key) && !value.isEmpty {
                // If the key looks like a positional argument, add value directly
                if key.hasPrefix("arg_") {
                    parts.append(value)
                }
                // Otherwise skip unknown parameters
            }
        }

        // Add overridden network values
        if tool.requiresNetwork {
            for key in ["url", "base-url", "aet", "called-aet", "timeout"] {
                if let value = values[key], !value.isEmpty {
                    if key == "url" || key == "base-url" {
                        // URL is a positional argument, but only if we haven't already added it
                        // Insert after tool name and optional subcommand
                        let insertIndex = subcommand != nil ? 2 : 1
                        if parts.count > insertIndex, parts[insertIndex] != value {
                            parts.insert(value, at: insertIndex)
                        } else if parts.count <= insertIndex {
                            parts.append(value)
                        }
                    } else {
                        parts.append("--\(key)")
                        parts.append(value)
                    }
                }
            }
        }

        return parts.joined(separator: " ")
    }

    /// Checks whether all required parameters have values.
    ///
    /// - Parameters:
    ///   - values: Dictionary mapping parameter IDs to their string values
    ///   - subcommand: Optional subcommand name
    /// - Returns: `true` if all required parameters are satisfied
    public func isValid(values: [String: String], subcommand: String? = nil) -> Bool {
        let parameters: [ParameterDefinition]
        if let subcommand, let subcommands = tool.subcommands,
           let sub = subcommands.first(where: { $0.id == subcommand }) {
            parameters = sub.parameters
        } else {
            parameters = tool.parameters
        }

        for param in parameters where param.isRequired {
            guard let value = values[param.id], !value.isEmpty else {
                return false
            }

            // Validate against validation rules
            if let rule = param.validation, !rule.validate(value) {
                return false
            }
        }

        return true
    }

    /// Returns the list of missing required parameter labels.
    ///
    /// - Parameters:
    ///   - values: Dictionary mapping parameter IDs to their string values
    ///   - subcommand: Optional subcommand name
    /// - Returns: Array of missing required parameter labels
    public func missingRequiredParameters(values: [String: String], subcommand: String? = nil) -> [String] {
        let parameters: [ParameterDefinition]
        if let subcommand, let subcommands = tool.subcommands,
           let sub = subcommands.first(where: { $0.id == subcommand }) {
            parameters = sub.parameters
        } else {
            parameters = tool.parameters
        }

        return parameters
            .filter { param in
                guard param.isRequired else { return false }
                guard let value = values[param.id], !value.isEmpty else { return true }
                if let rule = param.validation {
                    return !rule.validate(value)
                }
                return false
            }
            .map(\.label)
    }

    /// Validates a specific parameter value.
    ///
    /// - Parameters:
    ///   - parameterID: The parameter ID to validate
    ///   - value: The value to validate
    /// - Returns: `true` if the value is valid or no validation rule exists
    public func validateParameter(_ parameterID: String, value: String) -> Bool {
        let allParams = tool.parameters + (tool.subcommands?.flatMap(\.parameters) ?? [])
        guard let param = allParams.first(where: { $0.id == parameterID }) else {
            return true
        }
        guard let rule = param.validation else {
            return true
        }
        return rule.validate(value)
    }
}
