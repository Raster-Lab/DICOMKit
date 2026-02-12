import Foundation

/// Represents a single parameter for a CLI tool
struct ToolParameter: Identifiable, Sendable {
    let id: String
    let name: String
    let cliFlag: String
    let type: ParameterType
    let help: String
    let discussion: String?
    let isRequired: Bool
    let defaultValue: String?
    /// Whether this parameter requires a PACS URL (auto-filled from global config)
    let isPACSParameter: Bool

    init(
        id: String? = nil,
        name: String,
        cliFlag: String,
        type: ParameterType,
        help: String,
        discussion: String? = nil,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        isPACSParameter: Bool = false
    ) {
        self.id = id ?? cliFlag.replacingOccurrences(of: "-", with: "_")
        self.name = name
        self.cliFlag = cliFlag
        self.type = type
        self.help = help
        self.discussion = discussion
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.isPACSParameter = isPACSParameter
    }
}

/// Types of parameter input controls
enum ParameterType: Sendable {
    /// A boolean flag (--verbose, --recursive)
    case flag
    /// A text field for free-form input
    case text
    /// A numeric input field
    case number
    /// A file path input with drag-and-drop and file picker
    case inputFile(allowedTypes: [String])
    /// A directory path input
    case inputDirectory
    /// An output file path (requires save location)
    case outputFile(allowedTypes: [String])
    /// An output directory path
    case outputDirectory
    /// A dropdown selection from predefined options
    case dropdown(options: [DropdownOption])
    /// A multi-value text input (can be specified multiple times)
    case multiText
    /// A positional argument (not prefixed with --)
    case positionalArgument
    /// A positional file argument
    case positionalFile(allowedTypes: [String])
    /// A positional directory argument
    case positionalDirectory
    /// Multiple positional file arguments
    case positionalFiles(allowedTypes: [String])
}

/// An option in a dropdown menu
struct DropdownOption: Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    let help: String?

    init(label: String, value: String, help: String? = nil) {
        self.id = value
        self.label = label
        self.value = value
        self.help = help
    }
}
