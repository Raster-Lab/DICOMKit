import Foundation

/// DICOM Application Entity (AE) Title for network communication
///
/// An AE Title identifies an application entity in DICOM networking.
/// It must be 1-16 ASCII characters, padded with spaces if necessary.
///
/// Reference: PS3.8 Section 9.3.2 - A-ASSOCIATE-RQ PDU
public struct AETitle: Sendable, Hashable {
    /// The raw AE Title value (1-16 characters)
    public let value: String
    
    /// Maximum length for an AE Title
    public static let maxLength = 16
    
    /// Creates an AE Title from a string value
    ///
    /// - Parameter value: The AE Title string (1-16 ASCII characters)
    /// - Throws: `DICOMNetworkError.invalidAETitle` if the value is invalid
    public init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            throw DICOMNetworkError.invalidAETitle(value)
        }
        
        guard trimmed.count <= Self.maxLength else {
            throw DICOMNetworkError.invalidAETitle(value)
        }
        
        // Check for ASCII characters only
        guard trimmed.allSatisfy({ $0.isASCII && !$0.isNewline }) else {
            throw DICOMNetworkError.invalidAETitle(value)
        }
        
        self.value = trimmed
    }
    
    /// The AE Title padded to 16 characters with trailing spaces
    ///
    /// Used for network transmission where fixed-length fields are required.
    public var paddedValue: String {
        value.padding(toLength: Self.maxLength, withPad: " ", startingAt: 0)
    }
    
    /// The AE Title as Data for network transmission (16 bytes, ASCII)
    public var data: Data {
        Data(paddedValue.utf8)
    }
    
    /// Creates an AE Title from padded network data
    ///
    /// - Parameter data: 16 bytes of ASCII data
    /// - Returns: An AE Title, or nil if the data is invalid
    public static func from(data: Data) -> AETitle? {
        guard data.count == maxLength else { return nil }
        guard let string = String(data: data, encoding: .ascii) else { return nil }
        return try? AETitle(string)
    }
}

// MARK: - CustomStringConvertible
extension AETitle: CustomStringConvertible {
    public var description: String {
        value
    }
}

// MARK: - ExpressibleByStringLiteral
extension AETitle: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        // For string literals, we assume they are valid and crash if not
        // This is acceptable since string literals are compile-time constants
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid AE Title string literal: '\(value)'")
        }
    }
}
