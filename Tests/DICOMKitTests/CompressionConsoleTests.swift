import XCTest
@testable import DICOMKit
import DICOMCore

/// Locks the exact `dicom-compress` console text produced by the shared
/// `CompressionConsole`. The CLI (`Sources/dicom-compress`) and the DICOMStudio
/// CLI Workshop both render through these functions, so pinning the strings here
/// guarantees the two surfaces stay byte-for-byte identical (no parity drift) and
/// that the strings keep matching the CLI-parity goldens.
final class CompressionConsoleTests: XCTestCase {

    func testByteFormatting() {
        XCTAssertEqual(CompressionConsole.formatBytes(0), "0 B")
        XCTAssertEqual(CompressionConsole.formatBytes(512), "512 B")
        XCTAssertEqual(CompressionConsole.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(CompressionConsole.formatBytes(528_924), "516.5 KB")
        XCTAssertEqual(CompressionConsole.formatBytes(5 * 1024 * 1024), "5.0 MB")
    }

    func testQualityParsing() throws {
        XCTAssertNil(try CompressionConsole.parseQuality(nil))
        XCTAssertNil(try CompressionConsole.parseQuality("   "))
        XCTAssertEqual(try CompressionConsole.parseQuality("high"), .high)
        XCTAssertEqual(try CompressionConsole.parseQuality("MAXIMUM"), .maximum)
        if case .custom(let v)? = try CompressionConsole.parseQuality("0.8") {
            XCTAssertEqual(v, 0.8, accuracy: 1e-9)
        } else { XCTFail("expected .custom(0.8)") }
        XCTAssertThrowsError(try CompressionConsole.parseQuality("nope")) { err in
            XCTAssertEqual("\(err)", "Invalid quality 'nope'. Use maximum, high, medium, low, or a value 0.0-1.0")
        }
    }

    func testBackendPreference() {
        // CodecBackendPreference isn't Equatable; it wraps `forced: CodecBackend?`
        // (nil == auto). Assert the forced backend is reflected in its description.
        XCTAssertTrue(String(describing: CompressionConsole.backendPreference(for: "metal")).contains("metal"))
        XCTAssertTrue(String(describing: CompressionConsole.backendPreference(for: "ACCELERATE")).contains("accelerate"))
        XCTAssertTrue(String(describing: CompressionConsole.backendPreference(for: "scalar")).contains("scalar"))
        XCTAssertTrue(String(describing: CompressionConsole.backendPreference(for: "")).contains("nil"))
        XCTAssertTrue(String(describing: CompressionConsole.backendPreference(for: "weird")).contains("nil"))
    }

    func testCompressLines() {
        XCTAssertEqual(
            CompressionConsole.compressResultLine(input: "/in.dcm", output: "/out.dcm"),
            "Compressed: /in.dcm → /out.dcm\n")
        XCTAssertEqual(
            CompressionConsole.compressPreamble(input: "/in.dcm", codec: "htj2k-lossless",
                                                quality: nil, backendDisplayName: "Metal (GPU)"),
            "Compressing: /in.dcm\nCodec: htj2k-lossless\nBackend: Metal (GPU)\n")
        XCTAssertEqual(
            CompressionConsole.compressPreamble(input: "/in.dcm", codec: "htj2k",
                                                quality: " high ", backendDisplayName: "Scalar (CPU)"),
            "Compressing: /in.dcm\nCodec: htj2k\nQuality: high\nBackend: Scalar (CPU)\n")
        XCTAssertEqual(
            CompressionConsole.compressStats(inputSize: 528_924, outputSize: 174_400),
            "Input size:  516.5 KB\nOutput size: 170.3 KB\nRatio: 33.0%\n")
    }

    func testDecompressLines() {
        XCTAssertEqual(
            CompressionConsole.decompressResultLine(input: "/c.dcm", output: "/u.dcm"),
            "Decompressed: /c.dcm → /u.dcm\n")
        XCTAssertEqual(
            CompressionConsole.decompressPreamble(input: "/c.dcm", targetSyntaxName: "Explicit VR Little Endian"),
            "Decompressing: /c.dcm\nTarget syntax: Explicit VR Little Endian\n")
        XCTAssertEqual(
            CompressionConsole.decompressStats(inputSize: 174_400, outputSize: 528_924),
            "Input size:  170.3 KB\nOutput size: 516.5 KB\n")
    }

    func testBatchLines() {
        XCTAssertEqual(CompressionConsole.batchFoundLine(count: 3), "Found 3 DICOM file(s)\n")
        XCTAssertEqual(CompressionConsole.batchProgressLine(success: true, relativePath: "a/b.dcm", error: nil),
                       "  ✅ a/b.dcm\n")
        XCTAssertEqual(CompressionConsole.batchProgressLine(success: false, relativePath: "a/b.dcm", error: "boom"),
                       "  ❌ a/b.dcm: boom\n")
        XCTAssertEqual(CompressionConsole.batchSummaryLine(decompress: false, success: 2, fail: 1, total: 3),
                       "Compressed: 2 succeeded, 1 failed out of 3 files\n")
        XCTAssertEqual(CompressionConsole.batchSummaryLine(decompress: true, success: 3, fail: 0, total: 3),
                       "Decompressed: 3 succeeded, 0 failed out of 3 files\n")
    }
}
