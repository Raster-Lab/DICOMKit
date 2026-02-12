/// The type of a CLI parameter, used to determine the appropriate SwiftUI control
public enum ParameterType: String, Sendable {
    /// File path input (uses FileDropZoneView + .fileImporter())
    case file
    /// String option (uses TextField)
    case string
    /// Integer option (uses Stepper or TextField)
    case integer
    /// Boolean flag (uses Toggle)
    case boolean
    /// Enum option with predefined values (uses Picker)
    case enumeration
    /// Repeatable option (uses dynamic List with add/remove)
    case repeatable
    /// Date option (uses DatePicker)
    case date
    /// Secure string (uses SecureField)
    case secure
}
