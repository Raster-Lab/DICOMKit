import Foundation

/// DICOM Unique Identifier (UI) value representation
///
/// Represents a DICOM UID with validation and component access.
/// Reference: DICOM PS3.5 Section 6.2 - UI Value Representation
///
/// A DICOM UID is a string of numeric components separated by periods (dots).
/// Each component is a decimal number, and the total UID length must not exceed 64 characters.
///
/// UID Structure:
/// - Consists of numeric components separated by periods
/// - Each component is an unsigned integer (no leading zeros except for component "0")
/// - Maximum total length is 64 characters
///
/// Common UID Roots:
/// - "1.2.840.10008" - DICOM standard UIDs
/// - "1.2.840.113619" - GE Healthcare
/// - "1.3.6.1.4.1" - IANA-assigned private enterprise numbers
///
/// Reference: DICOM PS3.5 Section 9 - Unique Identifiers (UIDs)
///
/// Examples:
/// - "1.2.840.10008.1.2" = Implicit VR Little Endian Transfer Syntax
/// - "1.2.840.10008.5.1.4.1.1.2" = CT Image Storage SOP Class
/// - "1.2.840.113619.2.5.1762583153.215519.978957063.78" = Instance UID
public struct DICOMUniqueIdentifier: Sendable, Hashable {
    /// Maximum allowed length for a UID per DICOM PS3.5 Section 9.1
    public static let maximumLength = 64
    
    /// DICOM standard UID root
    public static let dicomRoot = "1.2.840.10008"
    
    /// The raw UID string value
    public let value: String
    
    /// The numeric components of the UID
    public let components: [String]
    
    /// Creates a DICOM Unique Identifier from a validated UID string
    /// - Parameters:
    ///   - value: The UID string value
    ///   - components: The parsed numeric components
    private init(value: String, components: [String]) {
        self.value = value
        self.components = components
    }
    
    /// Parses a DICOM UID string into a DICOMUniqueIdentifier
    ///
    /// Validates the UID format per DICOM PS3.5 Section 9.1:
    /// - Maximum length of 64 characters
    /// - Contains only digits (0-9) and periods (.)
    /// - Does not start or end with a period
    /// - No consecutive periods
    /// - Each component is a valid unsigned integer
    /// - Leading zeros are not permitted except for the component "0"
    ///
    /// Reference: DICOM PS3.5 Section 9.1 - UID Encoding Rules
    ///
    /// - Parameter string: The UID string to parse
    /// - Returns: A DICOMUniqueIdentifier if parsing succeeds, nil otherwise
    public static func parse(_ string: String) -> DICOMUniqueIdentifier? {
        // Trim whitespace and null padding (common in DICOM)
        let trimmed = string.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        
        // Empty string is invalid
        guard !trimmed.isEmpty else {
            return nil
        }
        
        // Check maximum length per PS3.5 Section 9.1
        guard trimmed.count <= maximumLength else {
            return nil
        }
        
        // Must contain only digits and periods
        let validCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        guard trimmed.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            return nil
        }
        
        // Must not start or end with period
        guard !trimmed.hasPrefix(".") && !trimmed.hasSuffix(".") else {
            return nil
        }
        
        // Must not have consecutive periods
        guard !trimmed.contains("..") else {
            return nil
        }
        
        // Parse components
        let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            .map { String($0) }
        
        // Must have at least one component
        guard !components.isEmpty else {
            return nil
        }
        
        // Validate each component
        for component in components {
            // Must not be empty
            guard !component.isEmpty else {
                return nil
            }
            
            // Leading zeros are not permitted except for "0" itself
            // Reference: PS3.5 Section 9.1
            if component.count > 1 && component.hasPrefix("0") {
                return nil
            }
            
            // Must be a valid unsigned integer (parseable)
            // Note: We allow very large numbers as they're just stored as strings
            guard component.allSatisfy({ $0.isNumber }) else {
                return nil
            }
        }
        
        return DICOMUniqueIdentifier(value: trimmed, components: components)
    }
    
    /// Parses multiple DICOM UID values from a backslash-delimited string
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    ///
    /// - Parameter string: The string containing multiple UIDs
    /// - Returns: Array of parsed UIDs, or nil if any parsing fails
    public static func parseMultiple(_ string: String) -> [DICOMUniqueIdentifier]? {
        let values = string.split(separator: "\\", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let parsed = values.compactMap { parse($0) }
        
        // Return nil if not all values could be parsed
        guard parsed.count == values.count else {
            return nil
        }
        
        return parsed.isEmpty ? nil : parsed
    }
    
    // MARK: - Component Access
    
    /// Returns the UID root (typically the first few components identifying the organization)
    ///
    /// For standard DICOM UIDs, this is "1.2.840.10008"
    /// For other UIDs, this returns the first 4 components if available
    public var root: String {
        if value.hasPrefix(Self.dicomRoot) {
            return Self.dicomRoot
        }
        
        // Return first 4 components as root (common convention)
        let rootComponents = Array(components.prefix(4))
        return rootComponents.joined(separator: ".")
    }
    
    /// Returns the suffix after the root (the unique part of the UID)
    ///
    /// For standard DICOM UIDs, this is everything after "1.2.840.10008."
    public var suffix: String? {
        if value.hasPrefix(Self.dicomRoot + ".") {
            let startIndex = value.index(value.startIndex, offsetBy: Self.dicomRoot.count + 1)
            return String(value[startIndex...])
        }
        
        // For non-DICOM UIDs, return everything after the first 4 components
        if components.count > 4 {
            return components.dropFirst(4).joined(separator: ".")
        }
        
        return nil
    }
    
    /// The number of components in this UID
    public var componentCount: Int {
        return components.count
    }
    
    // MARK: - UID Type Detection
    
    /// Indicates whether this is a standard DICOM UID (starts with 1.2.840.10008)
    ///
    /// Reference: DICOM PS3.5 Section 9 - Standard DICOM UID root
    public var isStandardDICOM: Bool {
        return value.hasPrefix(Self.dicomRoot)
    }
    
    /// Indicates whether this appears to be a Transfer Syntax UID
    ///
    /// Standard DICOM Transfer Syntax UIDs have the prefix "1.2.840.10008.1.2"
    /// followed by either end-of-string or a dot.
    /// Reference: DICOM PS3.6 Part 6 - Registry of DICOM Unique Identifiers
    public var isTransferSyntax: Bool {
        // Must match exactly "1.2.840.10008.1.2" or "1.2.840.10008.1.2.x..."
        let transferSyntaxRoot = "1.2.840.10008.1.2"
        if value == transferSyntaxRoot {
            return true
        }
        return value.hasPrefix(transferSyntaxRoot + ".")
    }
    
    /// Indicates whether this appears to be a SOP Class UID
    ///
    /// Standard DICOM SOP Class UIDs typically start with "1.2.840.10008.5.1.4"
    /// or other specific patterns in the 1.2.840.10008.x range.
    /// Reference: DICOM PS3.6 Part 6 - Registry of DICOM Unique Identifiers
    public var isSOPClass: Bool {
        // Common SOP Class UID prefixes
        let sopClassPrefixes = [
            "1.2.840.10008.5.1.4",   // Storage SOP Classes
            "1.2.840.10008.3.1.2",   // Query/Retrieve SOP Classes
            "1.2.840.10008.1.3",     // Basic Film Session SOP Class
            "1.2.840.10008.1.9",     // Basic Study Content Notification SOP Class
            "1.2.840.10008.1.40"     // Procedural Event Logging SOP Class
        ]
        
        for prefix in sopClassPrefixes {
            if value == prefix || value.hasPrefix(prefix + ".") {
                return true
            }
        }
        return false
    }
    
    /// Returns the DICOM format string (same as value)
    public var dicomString: String {
        return value
    }
}

// MARK: - Protocol Conformances

extension DICOMUniqueIdentifier: CustomStringConvertible {
    public var description: String {
        return value
    }
}

extension DICOMUniqueIdentifier: ExpressibleByStringLiteral {
    /// Creates a UID from a string literal
    ///
    /// - Note: This will crash if the string is not a valid UID. Use `parse(_:)` for safe parsing.
    public init(stringLiteral value: String) {
        guard let uid = DICOMUniqueIdentifier.parse(value) else {
            fatalError("Invalid DICOM UID: \(value)")
        }
        self = uid
    }
}

extension DICOMUniqueIdentifier: Comparable {
    /// Compares UIDs lexicographically by their string value
    public static func < (lhs: DICOMUniqueIdentifier, rhs: DICOMUniqueIdentifier) -> Bool {
        return lhs.value < rhs.value
    }
}

extension DICOMUniqueIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let uid = DICOMUniqueIdentifier.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid DICOM UID format: \(string)"
            )
        }
        self = uid
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
