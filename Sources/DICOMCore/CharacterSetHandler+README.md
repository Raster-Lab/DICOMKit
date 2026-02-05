# CharacterSetHandler - DICOM Character Set Support

## Overview

The `CharacterSetHandler` provides comprehensive support for DICOM international character sets according to ISO 2022 standard. It enables proper encoding and decoding of text values in DICOM files that use non-ASCII character sets.

## Supported Character Sets

DICOMKit supports all 17 standard DICOM character repertoires:

| ISO IR Code | Character Set | Region/Language | Encoding |
|-------------|---------------|-----------------|----------|
| ISO IR 6 | ASCII | Default (English) | Single-byte |
| ISO IR 13 | Japanese Katakana | Japan | Single-byte |
| ISO IR 14 | Japanese Romaji | Japan | Single-byte |
| ISO IR 87 | Japanese Kanji (JIS X 0208) | Japan | Double-byte |
| ISO IR 100 | Latin-1 | Western European | Single-byte |
| ISO IR 101 | Latin-2 | Central European | Single-byte |
| ISO IR 109 | Latin-3 | South European | Single-byte |
| ISO IR 110 | Latin-4 | Baltic | Single-byte |
| ISO IR 126 | Greek | Greece | Single-byte |
| ISO IR 127 | Arabic | Arabic countries | Single-byte |
| ISO IR 138 | Hebrew | Israel | Single-byte |
| ISO IR 144 | Cyrillic | Russia, Eastern Europe | Single-byte |
| ISO IR 148 | Latin-5 (Turkish) | Turkey | Single-byte |
| ISO IR 149 | Korean | Korea | Double-byte |
| ISO IR 159 | Japanese Supplementary Kanji (JIS X 0212) | Japan | Double-byte |
| ISO IR 166 | Thai | Thailand | Single-byte |
| ISO IR 192 | UTF-8 | Universal | Multi-byte (1-4 bytes) |

## Usage

### Creating a Character Set Handler

The `CharacterSetHandler` is typically created from the DICOM Specific Character Set (0008,0005) attribute:

```swift
import DICOMCore

// From Specific Character Set value
let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")

// Or create directly
let handler = CharacterSetHandler(characterSets: [.isoIR192])

// Multi-valued character sets (for ideographic/phonetic representations)
let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6\\ISO_IR 87")
```

### Decoding DICOM Text

```swift
// Simple ASCII text
let asciiHandler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
let data = "Hello, World!".data(using: .ascii)!
let decoded = asciiHandler.decode(data) // "Hello, World!"

// UTF-8 text (including emoji and multi-byte characters)
let utf8Handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
let data = "Hello, 世界! 🌍".data(using: .utf8)!
let decoded = utf8Handler.decode(data) // "Hello, 世界! 🌍"

// Text with ISO 2022 escape sequences
// Example: ASCII text followed by Latin-1
var data = Data("Hello ".utf8)
data.append(contentsOf: [0x1B, 0x2D, 0x41]) // ESC - A (switch to Latin-1)
data.append("café".data(using: .isoLatin1)!)

let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6\\ISO_IR 100")
let decoded = handler.decode(data) // "Hello café"
```

### Encoding Text

```swift
// Encode as ASCII
let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 6")
let encoded = handler.encode("Hello, World!")
// Result: Data containing ASCII bytes

// Encode as UTF-8
let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
let encoded = handler.encode("Hello, 世界!")
// Result: Data containing UTF-8 bytes
```

### Character Set Encoding Selection

```swift
// Parse a Specific Character Set Defined Term
let encoding = CharacterSetEncoding.from(definedTerm: "ISO_IR 192")
// Returns: .isoIR192

// Get the Foundation String.Encoding
let stringEncoding = CharacterSetEncoding.isoIR192.stringEncoding
// Returns: .utf8

// Determine bytes per character
let byteCount = CharacterSetEncoding.isoIR192.bytesPerCharacter(startingWith: 0xE4)
// Returns: 3 (for this UTF-8 multi-byte sequence)
```

## ISO 2022 Escape Sequences

The CharacterSetHandler automatically processes ISO 2022 escape sequences to handle character set switching within a single value:

### Common Escape Sequences

| Sequence | Bytes | Description | Designates |
|----------|-------|-------------|------------|
| ESC ( B | 0x1B 0x28 0x42 | Switch to ASCII | G0 ← ASCII |
| ESC ) I | 0x1B 0x29 0x49 | Switch to Katakana | G1 ← Katakana |
| ESC $ B | 0x1B 0x24 0x42 | Switch to Japanese Kanji | G0 ← JIS X 0208 |
| ESC - A | 0x1B 0x2D 0x41 | Switch to Latin-1 | G1 ← Latin-1 |
| ESC - F | 0x1B 0x2D 0x46 | Switch to Greek | G1 ← Greek |

## DICOM Standard References

- **PS3.5 Section 6.1**: Support of Character Repertoires
- **PS3.5 Annex H**: ISO 2022 Escape Sequences
- **PS3.3 C.12.1.1.2**: Specific Character Set Attribute (0008,0005)
- **ISO 2022**: Information technology — Character code structure and extension techniques

## Integration with DICOM Parsing

The CharacterSetHandler is designed to integrate with DICOM parsing workflows:

1. **Parse Specific Character Set**: Read the (0008,0005) element value
2. **Create Handler**: Initialize CharacterSetHandler from the parsed value
3. **Decode Strings**: Use the handler to decode all string-based Value Representations
4. **Handle Person Names**: Apply appropriate encoding for each component group (alphabetic, ideographic, phonetic)

### Future Integration Points

- Integration with `DataElement.stringValue` for automatic character set handling (planned for v1.0.10)
- Support in `DICOMPersonName` for proper multi-byte character parsing
- Automatic encoding selection in `DICOMWriter` for string serialization

## Unicode Normalization

The CharacterSetHandler provides Unicode normalization utilities for consistent text representation:

```swift
// NFC normalization for display (combines decomposed characters)
let decomposed = "e\u{0301}" // e + combining acute accent
let normalized = CharacterSetEncoding.normalizeForDisplay(decomposed)
// Result: "é" (single composed character)

// NFD normalization (decomposes characters)
let composed = "é"
let decomposed = CharacterSetEncoding.normalizeDecomposed(composed)
// Result: "e" + combining acute accent
```

**Use Cases:**
- **NFC (Canonical Composition)**: Recommended for display and storage. Ensures visually equivalent characters have consistent representation.
- **NFD (Canonical Decomposition)**: Useful for text processing, searching, and comparison operations.

## Bidirectional Text Support

The CharacterSetHandler correctly handles bidirectional (BiDi) text for languages like Arabic and Hebrew:

- **Right-to-Left (RTL) Scripts**: Arabic (ISO IR 127), Hebrew (ISO IR 138)
- **Left-to-Right (LTR) Scripts**: Latin, Cyrillic, Greek, etc.
- **Mixed Directionality**: Text containing both LTR and RTL characters

The handler preserves the logical order of characters. Display rendering is handled by the UI framework (UIKit, AppKit) according to Unicode BiDi algorithm.

```swift
// Arabic text (RTL)
let handler = CharacterSetHandler.from(specificCharacterSet: "ISO_IR 192")
let arabicText = "مرحبا بك في عالم DICOM"
let encoded = handler.encode(arabicText)
let decoded = handler.decode(encoded)
// Logical order is preserved; rendering direction handled by UI
```

## Notes

- Default character set is ISO IR 6 (ASCII) when Specific Character Set is absent
- UTF-8 (ISO IR 192) is recommended for modern DICOM implementations
- Some character sets use UTF-8 fallback due to limited platform support
- Multi-valued Specific Character Set enables different encodings for different text components
- The handler maintains separate G0, G1, G2, G3 character set designations per ISO 2022 standard
- ISO 2022 escape sequences are automatically generated when encoding with multi-valued character sets

## Testing

Comprehensive test coverage (95+ tests) validates:
- Character set parsing from Defined Terms (all 17 ISO IR character sets)
- Encoding/decoding for all supported character sets
- ISO 2022 escape sequence processing and generation
- Multi-byte character handling (UTF-8, Japanese, Korean, Thai)
- Round-trip encode/decode validation
- Unicode normalization (NFC/NFD)
- Bidirectional text handling (Arabic, Hebrew)
- Edge cases (empty data, incomplete sequences, null bytes, unknown escape sequences)

See `Tests/DICOMCoreTests/CharacterSetHandlerTests.swift` for detailed test cases.
