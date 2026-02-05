import Foundation

/// Handler for DICOM character set processing according to ISO 2022 standard
///
/// Handles encoding and decoding of DICOM text values with support for:
/// - Single-byte and multi-byte character sets
/// - ISO 2022 escape sequences for character set designation and invocation
/// - Multiple character repertoires (G0, G1, G2, G3)
/// - Character set switching via escape sequences
///
/// Reference: DICOM PS3.5 Section 6.1 - Support of Character Repertoires
/// Reference: DICOM PS3.5 Annex H - ISO 2022 Escape Sequences
/// Reference: DICOM PS3.3 C.12.1.1.2 - Specific Character Set
public struct CharacterSetHandler: Sendable {
    
    /// The character set encodings to use, in order
    /// - First element applies to the default character repertoire (G0)
    /// - Additional elements apply to extended character repertoires
    private let characterSets: [CharacterSetEncoding]
    
    /// Creates a character set handler from a Specific Character Set value
    ///
    /// - Parameter specificCharacterSet: Value from (0008,0005) Specific Character Set
    /// - Returns: A configured CharacterSetHandler
    public static func from(specificCharacterSet: String?) -> CharacterSetHandler {
        guard let specificCharacterSet = specificCharacterSet?.trimmingCharacters(in: .whitespaces),
              !specificCharacterSet.isEmpty else {
            // Default to ISO_IR 6 (ASCII) when no character set is specified
            return CharacterSetHandler(characterSets: [.isoIR6])
        }
        
        // Split by backslash for multi-valued character sets
        let values = specificCharacterSet.split(separator: "\\")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let encodings = values.compactMap { CharacterSetEncoding.from(definedTerm: $0) }
        
        // Use default if no valid encodings found
        return CharacterSetHandler(characterSets: encodings.isEmpty ? [.isoIR6] : encodings)
    }
    
    /// Creates a character set handler with specific character set encodings
    ///
    /// - Parameter characterSets: Array of character set encodings
    public init(characterSets: [CharacterSetEncoding]) {
        self.characterSets = characterSets.isEmpty ? [.isoIR6] : characterSets
    }
    
    /// Decodes data to a string using the configured character sets
    ///
    /// Handles ISO 2022 escape sequences for character set switching.
    /// If no escape sequences are present, uses the primary character set.
    ///
    /// - Parameter data: The raw byte data to decode
    /// - Returns: The decoded string, or nil if decoding fails
    public func decode(_ data: Data) -> String? {
        // Empty data returns empty string
        guard !data.isEmpty else {
            return ""
        }
        
        // If only one character set and it's a simple encoding, use it directly
        if characterSets.count == 1 && !containsEscapeSequences(data) {
            return characterSets[0].decode(data)
        }
        
        // Handle ISO 2022 escape sequences
        return decodeWithEscapeSequences(data)
    }
    
    /// Encodes a string to data using the configured character sets
    ///
    /// When multiple character sets are configured, this method will use the primary
    /// character set (first in the array) for encoding. For ISO 2022 multi-byte character
    /// sets, escape sequences will be added as needed.
    ///
    /// Note: Full ISO 2022 mixed character set encoding (switching between character sets
    /// within a single string) is complex and depends on character repertoire detection.
    /// This implementation uses the primary character set for all characters.
    ///
    /// - Parameter string: The string to encode
    /// - Returns: The encoded data
    public func encode(_ string: String) -> Data {
        guard !string.isEmpty else {
            return Data()
        }
        
        // For simple single-byte character sets, use direct encoding
        if characterSets.count == 1 {
            return characterSets[0].encode(string)
        }
        
        // For multiple character sets, use the first encoding as primary
        // This is appropriate for common cases like ISO_IR 6\ISO_IR 100
        // where the first is the default G0 and second is extension G1
        let primaryEncoding = characterSets[0]
        
        // For UTF-8, no escape sequences needed
        if primaryEncoding == .isoIR192 {
            return primaryEncoding.encode(string)
        }
        
        // For ISO 2022 multi-byte encodings, add initial escape sequence if needed
        var result = Data()
        
        // If primary encoding has an escape sequence, add it at the start
        if let escapeSeq = primaryEncoding.escapeSequenceToG0() ?? primaryEncoding.escapeSequenceToG1() {
            result.append(contentsOf: escapeSeq)
        }
        
        // Encode the string using the primary encoding
        result.append(primaryEncoding.encode(string))
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Checks if data contains ISO 2022 escape sequences
    private func containsEscapeSequences(_ data: Data) -> Bool {
        // ESC = 0x1B
        return data.contains(0x1B)
    }
    
    /// Decodes data with ISO 2022 escape sequences
    private func decodeWithEscapeSequences(_ data: Data) -> String? {
        var result = ""
        var index = 0
        let bytes = Array(data)
        
        // Current character set designations (G0, G1, G2, G3)
        var g0 = characterSets[0]
        var g1 = characterSets.count > 1 ? characterSets[1] : characterSets[0]
        var g2 = characterSets.count > 2 ? characterSets[2] : characterSets[0]
        var g3 = characterSets.count > 3 ? characterSets[3] : characterSets[0]
        
        // Current active character set (initially G0)
        var currentEncoding = g0
        
        while index < bytes.count {
            // Check for escape sequence
            if bytes[index] == 0x1B { // ESC
                // Try to parse escape sequence
                if let (newEncoding, bytesConsumed) = parseEscapeSequence(bytes, startIndex: index,
                                                                          g0: &g0, g1: &g1, g2: &g2, g3: &g3) {
                    currentEncoding = newEncoding
                    index += bytesConsumed
                    continue
                }
            }
            
            // Regular character - determine how many bytes to consume
            let byteCount = currentEncoding.bytesPerCharacter(startingWith: bytes[index])
            let endIndex = min(index + byteCount, bytes.count)
            
            // Decode the character
            let charData = Data(bytes[index..<endIndex])
            if let decoded = currentEncoding.decode(charData) {
                result += decoded
            }
            
            index = endIndex
        }
        
        return result
    }
    
    /// Parses an ISO 2022 escape sequence
    ///
    /// - Parameters:
    ///   - bytes: The byte array containing the escape sequence
    ///   - startIndex: Index where the escape sequence starts (at ESC byte)
    ///   - g0: Current G0 designation (may be updated)
    ///   - g1: Current G1 designation (may be updated)
    ///   - g2: Current G2 designation (may be updated)
    ///   - g3: Current G3 designation (may be updated)
    /// - Returns: Tuple of (active encoding, bytes consumed), or nil if not a valid sequence
    private func parseEscapeSequence(
        _ bytes: [UInt8],
        startIndex: Int,
        g0: inout CharacterSetEncoding,
        g1: inout CharacterSetEncoding,
        g2: inout CharacterSetEncoding,
        g3: inout CharacterSetEncoding
    ) -> (CharacterSetEncoding, Int)? {
        guard startIndex + 2 < bytes.count else {
            return nil
        }
        
        let byte1 = bytes[startIndex + 1]
        let byte2 = bytes[startIndex + 2]
        
        // Check for common ISO 2022 escape sequences
        // Reference: PS3.5 Table 6.2-1 and Annex H
        
        // Two-byte escape sequences
        switch (byte1, byte2) {
        case (0x28, 0x42): // ESC ( B - ASCII to G0
            g0 = .isoIR6
            return (g0, 3)
        case (0x29, 0x49): // ESC ) I - Katakana to G1
            g1 = .isoIR13
            return (g1, 3)
        case (0x28, 0x4A): // ESC ( J - JIS X 0201 Romaji to G0
            g0 = .isoIR14
            return (g0, 3)
        case (0x24, 0x42): // ESC $ B - JIS X 0208 Kanji to G0
            g0 = .isoIR87
            return (g0, 3)
        default:
            break
        }
        
        // Three-byte escape sequences
        if startIndex + 3 < bytes.count {
            let byte3 = bytes[startIndex + 3]
            
            switch (byte1, byte2, byte3) {
            case (0x24, 0x28, 0x44): // ESC $ ( D - JIS X 0212 to G0
                g0 = .isoIR159
                return (g0, 4)
            case (0x2D, 0x41, _): // ESC - A - Latin-1 to G1
                g1 = .isoIR100
                return (g1, 3)
            case (0x2D, 0x42, _): // ESC - B - Latin-2 to G1
                g1 = .isoIR101
                return (g1, 3)
            case (0x2D, 0x43, _): // ESC - C - Latin-3 to G1
                g1 = .isoIR109
                return (g1, 3)
            case (0x2D, 0x44, _): // ESC - D - Latin-4 to G1
                g1 = .isoIR110
                return (g1, 3)
            case (0x2D, 0x46, _): // ESC - F - Greek to G1
                g1 = .isoIR126
                return (g1, 3)
            case (0x2D, 0x47, _): // ESC - G - Arabic to G1
                g1 = .isoIR127
                return (g1, 3)
            case (0x2D, 0x48, _): // ESC - H - Hebrew to G1
                g1 = .isoIR138
                return (g1, 3)
            case (0x2D, 0x4C, _): // ESC - L - Cyrillic to G1
                g1 = .isoIR144
                return (g1, 3)
            case (0x2D, 0x4D, _): // ESC - M - Latin-5 (Turkish) to G1
                g1 = .isoIR148
                return (g1, 3)
            case (0x24, 0x29, 0x43): // ESC $ ) C - Korean to G1
                g1 = .isoIR149
                return (g1, 4)
            case (0x2D, 0x54, _): // ESC - T - Thai to G1
                g1 = .isoIR166
                return (g1, 3)
            default:
                break
            }
        }
        
        // Unknown escape sequence - skip it
        return nil
    }
}

/// Character set encoding definitions for DICOM
///
/// Reference: DICOM PS3.5 Table 6.2-1 - Defined Terms for Specific Character Set
public enum CharacterSetEncoding: Sendable, Hashable {
    /// ISO IR 6 - ASCII (G0 default)
    case isoIR6
    
    /// ISO IR 13 - Japanese Katakana
    case isoIR13
    
    /// ISO IR 14 - Japanese Romaji
    case isoIR14
    
    /// ISO IR 87 - Japanese Kanji (JIS X 0208)
    case isoIR87
    
    /// ISO IR 100 - Latin-1 (Western European)
    case isoIR100
    
    /// ISO IR 101 - Latin-2 (Central European)
    case isoIR101
    
    /// ISO IR 109 - Latin-3 (South European)
    case isoIR109
    
    /// ISO IR 110 - Latin-4 (North European/Baltic)
    case isoIR110
    
    /// ISO IR 126 - Greek
    case isoIR126
    
    /// ISO IR 127 - Arabic
    case isoIR127
    
    /// ISO IR 138 - Hebrew
    case isoIR138
    
    /// ISO IR 144 - Cyrillic
    case isoIR144
    
    /// ISO IR 148 - Latin-5 (Turkish)
    case isoIR148
    
    /// ISO IR 149 - Korean
    case isoIR149
    
    /// ISO IR 159 - Japanese Supplementary Kanji (JIS X 0212)
    case isoIR159
    
    /// ISO IR 166 - Thai
    case isoIR166
    
    /// ISO IR 192 - UTF-8
    case isoIR192
    
    /// Maps DICOM Defined Term to CharacterSetEncoding
    ///
    /// - Parameter definedTerm: The value from Specific Character Set (0008,0005)
    /// - Returns: The corresponding encoding, or nil if unknown
    public static func from(definedTerm: String) -> CharacterSetEncoding? {
        switch definedTerm {
        case "ISO_IR 6", "": // Empty defaults to ISO IR 6
            return .isoIR6
        case "ISO_IR 13", "ISO 2022 IR 13":
            return .isoIR13
        case "ISO_IR 14", "ISO 2022 IR 14":
            return .isoIR14
        case "ISO_IR 87", "ISO 2022 IR 87":
            return .isoIR87
        case "ISO_IR 100", "ISO 2022 IR 100":
            return .isoIR100
        case "ISO_IR 101", "ISO 2022 IR 101":
            return .isoIR101
        case "ISO_IR 109", "ISO 2022 IR 109":
            return .isoIR109
        case "ISO_IR 110", "ISO 2022 IR 110":
            return .isoIR110
        case "ISO_IR 126", "ISO 2022 IR 126":
            return .isoIR126
        case "ISO_IR 127", "ISO 2022 IR 127":
            return .isoIR127
        case "ISO_IR 138", "ISO 2022 IR 138":
            return .isoIR138
        case "ISO_IR 144", "ISO 2022 IR 144":
            return .isoIR144
        case "ISO_IR 148", "ISO 2022 IR 148":
            return .isoIR148
        case "ISO_IR 149", "ISO 2022 IR 149":
            return .isoIR149
        case "ISO_IR 159", "ISO 2022 IR 159":
            return .isoIR159
        case "ISO_IR 166", "ISO 2022 IR 166":
            return .isoIR166
        case "ISO_IR 192":
            return .isoIR192
        default:
            return nil
        }
    }
    
    /// Returns the Foundation String.Encoding for this character set
    ///
    /// Note: Not all DICOM character sets map cleanly to Foundation encodings.
    /// For character sets without direct Foundation support, fallback to UTF-8.
    public var stringEncoding: String.Encoding {
        switch self {
        case .isoIR6, .isoIR14: // ASCII and Japanese Romaji
            return .ascii
        case .isoIR13: // Katakana - use Shift JIS as approximation
            return .shiftJIS
        case .isoIR87, .isoIR159: // Japanese Kanji
            return .iso2022JP
        case .isoIR100: // Latin-1
            return .isoLatin1
        case .isoIR101: // Latin-2
            return .isoLatin2
        case .isoIR109: // Latin-3 (fallback to Latin-1)
            return .isoLatin1
        case .isoIR110: // Latin-4 (fallback to Latin-1)
            return .isoLatin1
        case .isoIR126: // Greek (fallback to UTF-8)
            return .utf8
        case .isoIR127: // Arabic (fallback to UTF-8)
            return .utf8
        case .isoIR138: // Hebrew (fallback to UTF-8)
            return .utf8
        case .isoIR144: // Cyrillic (fallback to UTF-8)
            return .utf8
        case .isoIR148: // Turkish (fallback to UTF-8)
            return .utf8
        case .isoIR149: // Korean (fallback to UTF-8)
            return .utf8
        case .isoIR166: // Thai (fallback to UTF-8)
            return .utf8
        case .isoIR192: // UTF-8
            return .utf8
        }
    }
    
    /// Decodes data using this character set encoding
    ///
    /// - Parameter data: The data to decode
    /// - Returns: The decoded string, or nil if decoding fails
    public func decode(_ data: Data) -> String? {
        return String(data: data, encoding: stringEncoding)
    }
    
    /// Encodes a string using this character set encoding
    ///
    /// - Parameter string: The string to encode
    /// - Returns: The encoded data
    public func encode(_ string: String) -> Data {
        return string.data(using: stringEncoding) ?? Data()
    }
    
    /// Returns the number of bytes per character for this encoding
    ///
    /// - Parameter firstByte: The first byte of the character
    /// - Returns: Number of bytes to read for this character
    public func bytesPerCharacter(startingWith firstByte: UInt8) -> Int {
        switch self {
        case .isoIR6, .isoIR13, .isoIR14, .isoIR100, .isoIR101, .isoIR109, .isoIR110,
             .isoIR126, .isoIR127, .isoIR138, .isoIR144, .isoIR148, .isoIR166:
            // Single-byte encodings
            return 1
            
        case .isoIR87, .isoIR149, .isoIR159:
            // Double-byte encodings (simplified - actual detection is more complex)
            return 2
            
        case .isoIR192:
            // UTF-8 - variable length (1-4 bytes)
            if firstByte & 0x80 == 0 {
                return 1 // 0xxxxxxx
            } else if firstByte & 0xE0 == 0xC0 {
                return 2 // 110xxxxx
            } else if firstByte & 0xF0 == 0xE0 {
                return 3 // 1110xxxx
            } else if firstByte & 0xF8 == 0xF0 {
                return 4 // 11110xxx
            } else {
                return 1 // Invalid, treat as single byte
            }
        }
    }
    
    /// Normalizes a string using NFC (Canonical Decomposition followed by Canonical Composition)
    ///
    /// This normalization is recommended for display purposes to ensure that visually equivalent
    /// characters are represented consistently. For example, "é" can be represented as a single
    /// composed character (U+00E9) or as "e" + combining acute accent (U+0065 U+0301).
    /// NFC normalization ensures consistent representation.
    ///
    /// Reference: Unicode Standard Annex #15 - Unicode Normalization Forms
    /// - Parameter string: The string to normalize
    /// - Returns: The NFC-normalized string
    public static func normalizeForDisplay(_ string: String) -> String {
        return string.precomposedStringWithCanonicalMapping
    }
    
    /// Normalizes a string using NFD (Canonical Decomposition)
    ///
    /// This normalization decomposes characters into their constituent parts.
    /// Useful for certain text processing operations.
    ///
    /// - Parameter string: The string to normalize
    /// - Returns: The NFD-normalized string
    public static func normalizeDecomposed(_ string: String) -> String {
        return string.decomposedStringWithCanonicalMapping
    }
    
    /// Returns the ISO 2022 escape sequence to designate this encoding to G0
    ///
    /// - Returns: Escape sequence bytes, or nil if not applicable (UTF-8, single-byte sets)
    public func escapeSequenceToG0() -> [UInt8]? {
        switch self {
        case .isoIR6:
            return [0x1B, 0x28, 0x42] // ESC ( B
        case .isoIR14:
            return [0x1B, 0x28, 0x4A] // ESC ( J
        case .isoIR87:
            return [0x1B, 0x24, 0x42] // ESC $ B
        case .isoIR159:
            return [0x1B, 0x24, 0x28, 0x44] // ESC $ ( D
        default:
            return nil // No G0 designation for other sets
        }
    }
    
    /// Returns the ISO 2022 escape sequence to designate this encoding to G1
    ///
    /// - Returns: Escape sequence bytes, or nil if not applicable
    public func escapeSequenceToG1() -> [UInt8]? {
        switch self {
        case .isoIR13:
            return [0x1B, 0x29, 0x49] // ESC ) I
        case .isoIR100:
            return [0x1B, 0x2D, 0x41] // ESC - A
        case .isoIR101:
            return [0x1B, 0x2D, 0x42] // ESC - B
        case .isoIR109:
            return [0x1B, 0x2D, 0x43] // ESC - C
        case .isoIR110:
            return [0x1B, 0x2D, 0x44] // ESC - D
        case .isoIR126:
            return [0x1B, 0x2D, 0x46] // ESC - F
        case .isoIR127:
            return [0x1B, 0x2D, 0x47] // ESC - G
        case .isoIR138:
            return [0x1B, 0x2D, 0x48] // ESC - H
        case .isoIR144:
            return [0x1B, 0x2D, 0x4C] // ESC - L
        case .isoIR148:
            return [0x1B, 0x2D, 0x4D] // ESC - M
        case .isoIR149:
            return [0x1B, 0x24, 0x29, 0x43] // ESC $ ) C
        case .isoIR166:
            return [0x1B, 0x2D, 0x54] // ESC - T
        default:
            return nil
        }
    }
}
