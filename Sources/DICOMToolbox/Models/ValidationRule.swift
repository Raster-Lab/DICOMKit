import Foundation

/// Validation rules for parameter values
public struct ValidationRule: Sendable {
    /// Minimum value for numeric parameters
    public let minValue: Int?
    /// Maximum value for numeric parameters
    public let maxValue: Int?
    /// Maximum character count for string parameters
    public let maxLength: Int?
    /// Whether the value must be ASCII-only
    public let asciiOnly: Bool
    /// A regular expression pattern the value must match
    public let pattern: String?

    public init(
        minValue: Int? = nil,
        maxValue: Int? = nil,
        maxLength: Int? = nil,
        asciiOnly: Bool = false,
        pattern: String? = nil
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.maxLength = maxLength
        self.asciiOnly = asciiOnly
        self.pattern = pattern
    }

    /// Validates a string value against this rule
    public func validate(_ value: String) -> Bool {
        if let maxLength, value.count > maxLength {
            return false
        }

        if asciiOnly, !value.allSatisfy({ $0.isASCII }) {
            return false
        }

        if let pattern {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(value.startIndex..., in: value)
            return regex.firstMatch(in: value, range: range) != nil
        }

        if let minValue, let intVal = Int(value), intVal < minValue {
            return false
        }

        if let maxValue, let intVal = Int(value), intVal > maxValue {
            return false
        }

        return true
    }
}
