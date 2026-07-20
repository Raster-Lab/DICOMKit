import Testing
import Foundation
@testable import DICOMWeb

/// Regression tests for C1 (see BUG_REVIEW.md): the STOW-RS server multipart
/// parser used to decode the whole body as UTF-8, which dropped or corrupted
/// binary `application/dicom` Part-10 bodies. The server now delegates to the
/// byte-scanning `MultipartMIME.parse`; these tests guard that parser preserves
/// binary part bodies exactly.
@Suite("STOW Binary Multipart Regression Tests")
struct STOWBinaryMultipartRegressionTests {

    /// A realistic Part-10-ish binary body: a 128-byte zero preamble, the "DICM"
    /// magic, every byte value 0x00...0xFF, and — crucially — leading/trailing
    /// bytes that the old parser's `.whitespacesAndNewlines` trim would have
    /// stripped (0x00, CR, LF, space, tab). Not valid UTF-8.
    private func makeBinaryDICOMBody() -> Data {
        var body = Data(repeating: 0x00, count: 128) // preamble (leading zeros)
        body.append(contentsOf: Array("DICM".utf8))
        body.append(contentsOf: (0...255).map { UInt8($0) })
        body.append(contentsOf: [0x0D, 0x0A, 0x20, 0x09]) // trailing CR LF SP TAB
        return body
    }

    @Test("Binary DICOM part body survives a multipart round-trip byte-for-byte")
    func testBinaryPartRoundTrip() throws {
        let original = makeBinaryDICOMBody()
        let multipart = MultipartMIME(parts: [.dicom(original)])
        let encoded = multipart.encode()

        let parsed = try MultipartMIME.parse(data: encoded, boundary: multipart.boundary)

        #expect(parsed.parts.count == 1)
        // The exact bug: the old parser returned [] (UTF-8 decode failed) or a
        // whitespace-trimmed/re-encoded body. The bytes must match exactly.
        #expect(parsed.parts.first?.body == original)
        #expect(parsed.parts.first?.contentType.subtype == "dicom")
    }

    @Test("Two binary DICOM parts are both preserved")
    func testMultipleBinaryPartsPreserved() throws {
        let a = makeBinaryDICOMBody()
        var b = makeBinaryDICOMBody()
        b.append(contentsOf: [0xFF, 0xD8, 0xFF]) // make the second body distinct

        let multipart = MultipartMIME(parts: [.dicom(a), .dicom(b)])
        let parsed = try MultipartMIME.parse(data: multipart.encode(), boundary: multipart.boundary)

        #expect(parsed.parts.count == 2)
        #expect(parsed.parts[0].body == a)
        #expect(parsed.parts[1].body == b)
    }

    @Test("A body that is not valid UTF-8 is not dropped")
    func testNonUTF8BodyNotDropped() throws {
        // 0xFF/0xFE are invalid as UTF-8 lead bytes; the old String(data:.utf8)
        // path returned nil for the whole body and yielded zero parts.
        let body = Data([0xFF, 0xFE, 0x00, 0x80, 0xC0, 0x01])
        let multipart = MultipartMIME(parts: [.dicom(body)])
        let parsed = try MultipartMIME.parse(data: multipart.encode(), boundary: multipart.boundary)

        #expect(parsed.parts.count == 1)
        #expect(parsed.parts.first?.body == body)
    }
}
