import Foundation

/// Defines a DICOM CLI tool with its command, parameters, and metadata
struct ToolDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let command: String
    let category: ToolCategory
    let abstract: String
    let discussion: String
    let icon: String
    let parameters: [ToolParameter]
    let subcommands: [SubcommandDefinition]?
    let examples: [String]

    init(
        name: String,
        command: String,
        category: ToolCategory,
        abstract: String,
        discussion: String = "",
        icon: String,
        parameters: [ToolParameter] = [],
        subcommands: [SubcommandDefinition]? = nil,
        examples: [String] = []
    ) {
        self.id = command
        self.name = name
        self.command = command
        self.category = category
        self.abstract = abstract
        self.discussion = discussion
        self.icon = icon
        self.parameters = parameters
        self.subcommands = subcommands
        self.examples = examples
    }

    /// Whether this tool has subcommands
    var hasSubcommands: Bool {
        guard let subs = subcommands else { return false }
        return !subs.isEmpty
    }
}

/// Defines a subcommand within a tool
struct SubcommandDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let abstract: String
    let parameters: [ToolParameter]

    init(name: String, abstract: String, parameters: [ToolParameter] = []) {
        self.id = name.lowercased()
        self.name = name
        self.abstract = abstract
        self.parameters = parameters
    }
}
