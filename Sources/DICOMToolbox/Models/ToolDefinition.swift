import Foundation

/// Defines a subcommand for tools that have them (e.g., dicom-compress compress|decompress|info|batch)
public struct SubcommandDefinition: Identifiable, Sendable {
    public let id: String
    /// Display name
    public let name: String
    /// Brief description
    public let description: String
    /// Parameters specific to this subcommand
    public let parameters: [ParameterDefinition]

    public init(
        id: String,
        name: String,
        description: String,
        parameters: [ParameterDefinition]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Defines a CLI tool and its metadata for UI representation
public struct ToolDefinition: Identifiable, Sendable {
    public let id: String
    /// Display name (e.g., "DICOM Info")
    public let name: String
    /// SF Symbol name for the icon
    public let icon: String
    /// Tab category
    public let category: ToolCategory
    /// One-line description
    public let description: String
    /// Extended help text
    public let discussion: String
    /// Parameters for this tool
    public let parameters: [ParameterDefinition]
    /// Subcommands (if any)
    public let subcommands: [SubcommandDefinition]?
    /// Whether this tool requires network configuration
    public let requiresNetwork: Bool
    /// Whether this tool requires an output path
    public let requiresOutput: Bool

    public init(
        id: String,
        name: String,
        icon: String,
        category: ToolCategory,
        description: String,
        discussion: String = "",
        parameters: [ParameterDefinition] = [],
        subcommands: [SubcommandDefinition]? = nil,
        requiresNetwork: Bool = false,
        requiresOutput: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.description = description
        self.discussion = discussion
        self.parameters = parameters
        self.subcommands = subcommands
        self.requiresNetwork = requiresNetwork
        self.requiresOutput = requiresOutput
    }
}
