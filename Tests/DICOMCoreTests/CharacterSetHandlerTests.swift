import Foundation
import Testing
@testable import DICOMCore

@Suite("CharacterSetHandler Tests")
struct CharacterSetHandlerTests {
    
    // MARK: - CharacterSetEncoding Tests
    
    @Test("Parse ISO IR 6 (ASCII) defined term")
    func testParseISOIR6() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 6")
        #expect(encoding == .isoIR6)
    }
    
    @Test("Parse empty defined term defaults to ISO IR 6")
    func testParseEmptyDefaultsToASCII() {
        let encoding = CharacterSetEncoding.from(definedTerm: "")
        #expect(encoding == .isoIR6)
    }
    
    @Test("Parse ISO IR 100 (Latin-1)")
    func testParseISOIR100() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 100")
        #expect(encoding == .isoIR100)
    }
    
    @Test("Parse ISO 2022 IR 100 (Latin-1 with ISO 2022)")
    func testParseISO2022IR100() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO 2022 IR 100")
        #expect(encoding == .isoIR100)
    }
    
    @Test("Parse ISO IR 192 (UTF-8)")
    func testParseISOIR192() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 192")
        #expect(encoding == .isoIR192)
    }
    
    @Test("Parse ISO IR 87 (Japanese Kanji)")
    func testParseISOIR87() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 87")
        #expect(encoding == .isoIR87)
    }
    
    @Test("Parse ISO IR 149 (Korean)")
    func testParseISOIR149() {
        let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 149")
        #expect(encoding == .isoIR149)
    }
    
    @Test("Parse unknown defined term returns nil")
    func testParseUnknownTerm() {
        let encoding = CharacterSetEncoding.from(definedTerm: "UNKNOWN_CHARSET")
        #expect(encoding == nil)
    }
    
    @Test("Encoding decode ASCII text")
    func testEncodingDecodeASCII() {
        let text = "Hello, World!"
        let data = text.data(using: .ascii)!
        
        let decoded = CharacterSetEncoding.isoIR6.decode(data)
        #expect(decoded == text)
    }
    
    @Test("Encoding decode UTF-8 text")
    func testEncodingDecodeUTF8() {
        let text = "Hello, 世界! 🌍"
        let data = text.data(using: .utf8)!
        
        let decoded = CharacterSetEncoding.isoIR192.decode(data)
        #expect(decoded == text)
    }
    
    @Test("Encoding encode ASCII text")
    func testEncodingEncodeASCII() {
        let text = "Hello, World!"
        let encoded = CharacterSetEncoding.isoIR6.encode(text)
        
        let decoded = String(data: encoded, encoding: .ascii)
        #expect(decoded == text)
    }
    
    @Test("Encoding encode UTF-8 text")
    func testEncodingEncodeUTF8() {
        let text = "Hello, 世界!"
        let encoded = CharacterSetEncoding.isoIR192.encode(text)
        
        let decoded = String(data: encoded, encoding: .utf8)
        #expect(decoded == text)
    }
    
    @Test("UTF-8 bytes per character - single byte")
    func testUTF8BytesPerCharSingleByte() {
        let count = CharacterSetEncoding.isoIR192.bytesPerCharacter(startingWith: 0x41) // 'A'
        #expect(count == 1)
    }
    
    @Test("UTF-8 bytes per character - two bytes")
    func testUTF8BytesPerCharTwoBytes() {
        let count = CharacterSetEncoding.isoIR192.bytesPerCharacter(startingWith: 0xC3) // Latin-1 supplement
        #expect(count == 2)
    }
    
    @Test("UTF-8 bytes per character - three bytes")
    func testUTF8BytesPerCharThreeBytes() {
        let count = CharacterSetEncoding.isoIR192.bytesPerCharacter(startingWith: 0xE4) // CJK
        #expect(count == 3)
    }
    
    @Test("UTF-8 bytes per character - four bytes")
    func testUTF8BytesPerCharFourBytes() {
        let count = CharacterSetEncoding.isoIR192.bytesPerCharacter(startingWith: 0xF0) // Emoji
        #expect(count == 4)
    }
    
    @Test("Single-byte encoding bytes per character")
    func testSingleByteEncodingBytesPerChar() {
        let count = CharacterSetEncoding.isoIR100.bytesPerCharacter(startingWith: 0x41)
        #expect(count == 1)
    }
    
    @Test("Double-byte encoding bytes per character")
    func testDoubleByteEncodingBytesPerChar() {
        let count = CharacterSetEncoding.isoIR87.bytesPerCharacter(startingWith: 0x41)
        #expect(count == 2)
    }
    
    // MARK: - CharacterSetHandler Creation Tests
    
    @Test("Create handler from nil Specific Character Set defaults to ASCII")
    func testCreateFromNilDefaultsToASCII() {
        let handler = CharacterSetHandler.from(specificCharacterSet: nil)
        
        let text = "ASCII Text"
        let data = text.data(using: .ascii)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Create handler from empty Specific Character Set defaults to ASCII")
    func testCreateFromEmptyDefaultsToASCII() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "")
        
        let text = "ASCII Text"
        let data = text.data(using: .ascii)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Create handler from single Specific Character Set value")
    func testCreateFromSingleValue() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let text = "UTF-8 Text: 日本語"
        let data = text.data(using: .utf8)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Create handler from multi-valued Specific Character Set")
    func testCreateFromMultiValue() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6\\ISO_IR 100")
        
        // Should support both ASCII and Latin-1
        let text = "Hello"
        let data = text.data(using: .ascii)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Create handler with whitespace in Specific Character Set")
    func testCreateWithWhitespace() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "  ISO_IR 192  ")
        
        let text = "Test"
        let data = text.data(using: .utf8)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Create handler with unknown character set falls back to empty")
    func testCreateWithUnknownCharset() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "UNKNOWN_CHARSET")
        
        // Should still work with default encoding
        let text = "Test"
        let data = text.data(using: .ascii)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    // MARK: - Decoding Tests
    
    @Test("Decode empty data returns empty string")
    func testDecodeEmptyData() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        let decoded = handler.decode(Data())
        
        #expect(decoded == "")
    }
    
    @Test("Decode ASCII text without escape sequences")
    func testDecodeASCIIWithoutEscapes() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        let text = "Hello, World!"
        let data = text.data(using: .ascii)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Decode UTF-8 text without escape sequences")
    func testDecodeUTF8WithoutEscapes() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let text = "Hello, 世界! Привет! مرحبا"
        let data = text.data(using: .utf8)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Decode Latin-1 text")
    func testDecodeLatin1() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 100")
        
        let text = "Café résumé"
        let data = text.data(using: .isoLatin1)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    @Test("Decode text with ISO 2022 escape sequence to Latin-1")
    func testDecodeWithEscapeToLatin1() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6\\ISO_IR 100")
        
        // ASCII text, then ESC - A to switch to Latin-1, then Latin-1 text
        var data = Data("Test ".utf8)
        data.append(contentsOf: [0x1B, 0x2D, 0x41]) // ESC - A (switch to Latin-1 in G1)
        data.append("café".data(using: .isoLatin1)!)
        
        let decoded = handler.decode(data)
        #expect(decoded != nil)
        #expect(decoded?.contains("Test") == true)
    }
    
    @Test("Decode text with escape sequence to ASCII")
    func testDecodeWithEscapeToASCII() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 100")
        
        // Start with some text, ESC ( B to switch to ASCII
        var data = Data()
        data.append(contentsOf: [0x1B, 0x28, 0x42]) // ESC ( B (switch to ASCII in G0)
        data.append("Hello".data(using: .ascii)!)
        
        let decoded = handler.decode(data)
        #expect(decoded != nil)
        #expect(decoded?.contains("Hello") == true)
    }
    
    @Test("Detect escape sequences in data")
    func testDetectEscapeSequences() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        // Data with ESC character
        var data = Data("Test".utf8)
        data.append(0x1B) // ESC
        data.append(0x28)
        data.append(0x42)
        
        // Should handle escape sequences
        let decoded = handler.decode(data)
        #expect(decoded != nil)
    }
    
    @Test("Decode without escape sequences when not present")
    func testDecodeWithoutEscapeSequencesWhenNotPresent() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let text = "Simple text without escapes"
        let data = text.data(using: .utf8)!
        let decoded = handler.decode(data)
        
        #expect(decoded == text)
    }
    
    // MARK: - Encoding Tests
    
    @Test("Encode empty string returns empty data")
    func testEncodeEmptyString() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        let encoded = handler.encode("")
        
        #expect(encoded.isEmpty)
    }
    
    @Test("Encode ASCII text")
    func testEncodeASCII() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        let text = "Hello, World!"
        let encoded = handler.encode(text)
        
        let decoded = String(data: encoded, encoding: .ascii)
        #expect(decoded == text)
    }
    
    @Test("Encode UTF-8 text")
    func testEncodeUTF8() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let text = "Hello, 世界!"
        let encoded = handler.encode(text)
        
        let decoded = String(data: encoded, encoding: .utf8)
        #expect(decoded == text)
    }
    
    @Test("Encode Latin-1 text")
    func testEncodeLatin1() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 100")
        
        let text = "Café"
        let encoded = handler.encode(text)
        
        let decoded = String(data: encoded, encoding: .isoLatin1)
        #expect(decoded == text)
    }
    
    @Test("Encode with multi-valued character set uses first encoding")
    func testEncodeMultiValuedUsesFirst() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6\\ISO_IR 100")
        
        let text = "Test"
        let encoded = handler.encode(text)
        
        // Should encode as ASCII (first in list)
        let decoded = String(data: encoded, encoding: .ascii)
        #expect(decoded == text)
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Round-trip ASCII text")
    func testRoundTripASCII() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        let original = "Hello, World! 123"
        let encoded = handler.encode(original)
        let decoded = handler.decode(encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Round-trip UTF-8 text")
    func testRoundTripUTF8() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let original = "Hello, 世界! Привет! 😊"
        let encoded = handler.encode(original)
        let decoded = handler.decode(encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Round-trip Latin-1 text")
    func testRoundTripLatin1() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 100")
        
        let original = "Café résumé naïve"
        let encoded = handler.encode(original)
        let decoded = handler.decode(encoded)
        
        #expect(decoded == original)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle data with only escape sequence")
    func testHandleOnlyEscapeSequence() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        // Just an escape sequence, no actual text
        let data = Data([0x1B, 0x28, 0x42])
        let decoded = handler.decode(data)
        
        #expect(decoded == "")
    }
    
    @Test("Handle incomplete escape sequence at end of data")
    func testHandleIncompleteEscapeSequence() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        // Text followed by incomplete escape sequence
        var data = Data("Hello".utf8)
        data.append(0x1B) // ESC but nothing after
        
        let decoded = handler.decode(data)
        #expect(decoded != nil)
        #expect(decoded?.contains("Hello") == true)
    }
    
    @Test("Handle invalid UTF-8 sequence")
    func testHandleInvalidUTF8() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        // Invalid UTF-8 byte sequence
        let data = Data([0xC3, 0x28]) // Invalid continuation byte
        let decoded = handler.decode(data)
        
        // Should still return something (possibly with replacement character)
        #expect(decoded != nil)
    }
    
    @Test("Handle very long text")
    func testHandleVeryLongText() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
        
        let original = String(repeating: "Hello, World! 世界 ", count: 1000)
        let encoded = handler.encode(original)
        let decoded = handler.decode(encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Handle text with null bytes")
    func testHandleTextWithNullBytes() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
        
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x57, 0x6F, 0x72, 0x6C, 0x64]) // "Hello\0World"
        let decoded = handler.decode(data)
        
        #expect(decoded != nil)
    }
}
