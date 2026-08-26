import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// ECOSYSTEM_COMPARISON.md §5 — behaviours that shipped as real bugs in DCMTK / dcm4che /
/// fo-dicom, added here as regression/characterization tests against DICOMKit's own code.
/// Each references the upstream issue that motivates it. Modality LUT precedence (fo-dicom
/// #1986) has its own file, `ModalityLUTPrecedenceTests`.
final class CrossToolkitMatrixTests: XCTestCase {

    private func element(_ tag: Tag, _ vr: VR, _ value: String) -> DataElement {
        DataElement(tag: tag, vr: vr, length: UInt32(value.utf8.count), valueData: Data(value.utf8))
    }

    // MARK: - Windowing

    /// fo-dicom #1905: a window width < 1 must not crash or produce NaN. DICOM leaves
    /// LINEAR undefined for width < 1 (its denominator is width-1 ≤ 0); DICOMKit clamps
    /// width to ≥ 1 in the initializer, so the transform stays finite and monotonic.
    func testWindowWidthBelowOneStaysFinite() {
        let w = WindowSettings(center: 40, width: 0.5, function: .linear)
        for v in stride(from: -100.0, through: 100.0, by: 5.0) {
            let out = w.apply(to: v)
            XCTAssertFalse(out.isNaN, "windowing must not produce NaN at width < 1 (v=\(v))")
            XCTAssertTrue(out >= 0.0 && out <= 1.0, "windowed output must stay in [0,1] (v=\(v))")
        }
    }

    /// LINEAR_EXACT (PS3.3 C.11.2.1.3.1) must also stay finite for small widths.
    func testLinearExactSmallWidthStaysFinite() {
        let w = WindowSettings(center: 40, width: 0.5, function: .linearExact)
        for v in stride(from: -100.0, through: 100.0, by: 5.0) {
            let out = w.apply(to: v)
            XCTAssertFalse(out.isNaN)
            XCTAssertTrue(out >= 0.0 && out <= 1.0)
        }
    }

    /// dcm4che #1513: 1/0 windowing of an 8-bit image (width 1) must map monotonically —
    /// values at/below center-0.5 → 0, above → 1 — not collapse to a single value.
    func testUnitWidthWindowIsAThreshold() {
        let w = WindowSettings(center: 128, width: 1, function: .linear)
        XCTAssertEqual(w.apply(to: 0), 0.0, "below threshold → black")
        XCTAssertEqual(w.apply(to: 255), 1.0, "above threshold → white")
        XCTAssertNotEqual(w.apply(to: 0), w.apply(to: 255),
                          "a unit-width window must still discriminate low from high")
    }

    // MARK: - Rescale / Modality

    /// fo-dicom #1975: an image with no rescale information must still be usable —
    /// `rescale(_:)` acts as identity, never crashes.
    func testEmptyRescaleInfoIsIdentity() {
        let ds = DataSet()   // no slope, no intercept, no LUT
        XCTAssertEqual(ds.rescaleSlope(), 1.0)
        XCTAssertEqual(ds.rescaleIntercept(), 0.0)
        XCTAssertEqual(ds.rescale(1234), 1234)
    }

    /// dcm4che #1499: a very small (but non-zero) Rescale Slope must not blow up any
    /// table sizing. DICOMKit's `rescale(_:)` is arithmetic, not a materialized LUT, so a
    /// tiny slope simply scales — pinning that we never size an allocation from the slope.
    func testTinyRescaleSlopeDoesNotAllocate() {
        var ds = DataSet()
        ds[.rescaleSlope] = element(.rescaleSlope, .DS, "0.0000001")
        ds[.rescaleIntercept] = element(.rescaleIntercept, .DS, "0")
        XCTAssertEqual(ds.rescale(1_000_000), 0.1, accuracy: 1e-9)
    }

    // MARK: - Parsing edge cases

    /// fo-dicom #1958: a file with stray delimiter items at the end must still open.
    func testTrailingDelimiterItemsParse() throws {
        var d = Data(count: 128)
        d.append(contentsOf: Array("DICM".utf8))
        // Minimal FMI: transfer syntax = Explicit VR LE.
        func explicit(_ g: UInt16, _ e: UInt16, _ vr: String, _ v: [UInt8]) -> [UInt8] {
            [UInt8(g & 0xFF), UInt8(g >> 8), UInt8(e & 0xFF), UInt8(e >> 8)]
                + Array(vr.utf8) + [UInt8(v.count & 0xFF), UInt8(v.count >> 8)] + v
        }
        let ts = Array("1.2.840.10008.1.2.1\0".utf8)
        let fmi = explicit(0x0002, 0x0010, "UI", ts)
        let len = UInt32(fmi.count)
        d.append(contentsOf: explicit(0x0002, 0x0000, "UL",
            [UInt8(len & 0xFF), UInt8((len >> 8) & 0xFF), UInt8((len >> 16) & 0xFF), UInt8((len >> 24) & 0xFF)]))
        d.append(contentsOf: fmi)
        d.append(contentsOf: explicit(0x0010, 0x0010, "PN", Array("Trailing^Test".utf8)))
        // Stray Item Delimitation + Sequence Delimitation at the very end.
        d.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0, 0x00, 0x00, 0x00, 0x00])
        d.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0, 0x00, 0x00, 0x00, 0x00])

        let file = try DICOMFile.read(from: d)
        XCTAssertEqual(file.dataSet.string(for: .patientName), "Trailing^Test",
                       "elements before stray delimiters must still parse")
    }

    /// fo-dicom #2043: an empty Pixel Spacing tag present in the dataset must not crash
    /// value access — a decimal accessor returns nil, not a trap.
    func testEmptyPixelSpacingDoesNotCrash() {
        var ds = DataSet()
        let pixelSpacing = Tag(group: 0x0028, element: 0x0030)
        ds[pixelSpacing] = DataElement(tag: pixelSpacing, vr: .DS, length: 0, valueData: Data())
        // Must return nil / empty rather than trap.
        _ = ds.decimalStrings(for: pixelSpacing)
        _ = ds.string(for: pixelSpacing)
        XCTAssertNotNil(ds[pixelSpacing], "the empty element itself is still present")
    }

    // MARK: - Character sets

    /// dcm4che #1503: ISO 2022 code extensions must reset to the default repertoire after
    /// a value delimiter. A person name whose components use escape sequences must decode
    /// without leaking the escaped state — pin that decoding does not crash and round-trips
    /// the ASCII backbone.
    func testISO2022DecodeDoesNotLeakState() {
        let handler = CharacterSetHandler.from(specificCharacterSet: "ISO 2022 IR 87")
        // "Yamada^Tarou" backbone with an ESC-to-G0 sequence between components.
        var bytes = Data("Yamada".utf8)
        bytes.append(contentsOf: [0x1B, 0x28, 0x42])   // ESC ( B — designate ASCII to G0
        bytes.append(contentsOf: Data("^Tarou".utf8))
        let decoded = handler.decode(bytes)
        XCTAssertNotNil(decoded, "ISO 2022 decode must not fail on an embedded escape")
        XCTAssertTrue(decoded?.contains("Yamada") ?? false)
        XCTAssertTrue(decoded?.contains("Tarou") ?? false)
    }
}
