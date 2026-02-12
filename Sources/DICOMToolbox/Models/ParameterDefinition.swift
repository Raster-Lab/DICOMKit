import Foundation

/// A value option for enum-type parameters
public struct EnumValue: Identifiable, Sendable {
    public let id: String
    /// Display label
    public let label: String
    /// CLI value
    public let value: String
    /// Brief description
    public let description: String

    public init(id: String? = nil, label: String, value: String, description: String = "") {
        self.id = id ?? value
        self.label = label
        self.value = value
        self.description = description
    }
}

/// Defines a single CLI parameter and its UI representation
public struct ParameterDefinition: Identifiable, Sendable {
    public let id: String
    /// The CLI flag (e.g., "--format")
    public let cliFlag: String
    /// Optional short flag (e.g., "-f")
    public let shortFlag: String?
    /// Display label (e.g., "Output Format")
    public let label: String
    /// Brief help text shown on hover
    public let help: String
    /// Extended help text shown in popover
    public let discussion: String?
    /// The parameter type determining the UI control
    public let type: ParameterType
    /// Whether this parameter is required
    public let isRequired: Bool
    /// Default value as a string
    public let defaultValue: String?
    /// Available values for enum-type parameters
    public let enumValues: [EnumValue]?
    /// Validation rule for the parameter value
    public let validation: ValidationRule?

    public init(
        id: String,
        cliFlag: String,
        shortFlag: String? = nil,
        label: String,
        help: String,
        discussion: String? = nil,
        type: ParameterType,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        enumValues: [EnumValue]? = nil,
        validation: ValidationRule? = nil
    ) {
        self.id = id
        self.cliFlag = cliFlag
        self.shortFlag = shortFlag
        self.label = label
        self.help = help
        self.discussion = discussion
        self.type = type
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.enumValues = enumValues
        self.validation = validation
    }
}
