import XCTest
@testable import DICOMKit
import DICOMCore

/// Regression: the shared `DICOMWriter` must serialize encapsulated (compressed)
/// PixelData — the Basic Offset Table + Item-tagged codestream fragments +
/// Sequence Delimitation Item of PS3.5 A.4.
///
/// Previously `serializeElement` only special-cased `.SQ` and otherwise skipped
/// any undefined-length (`0xFFFFFFFF`) value, so the generic `DataSet.write` /
/// `DICOMFile.write` path emitted an *empty* PixelData shell — silently dropping
/// the compressed pixels. That made `DICOMConverter`/dicom-convert fail to
/// transcode ANY compressed source (decode saw zero fragments → the encoder threw
/// "Frame 0 starts beyond data bounds") and would have corrupted any rewrite of a
/// compressed data set. `CompressionManager` only escaped this because it carries
/// its own dedicated encapsulated serializer.
final class EncapsulatedPixelDataWriteTests: XCTestCase {

    private func encapsulated(_ fragments: [Data], offsets: [UInt32] = []) -> DataElement {
        DataElement(
            tag: .pixelData, vr: .OB, length: 0xFFFFFFFF, valueData: Data(),
            encapsulatedFragments: fragments, encapsulatedOffsetTable: offsets)
    }

    /// `DataSet.write` must emit the header, BOT, every fragment item (odd ones
    /// padded to even length), and the delimiter — not an empty shell.
    func testDataSetWriteEmitsEncapsulationStructure() throws {
        let frag1 = Data([0xFF, 0x4F, 0xFF, 0x51, 0x00, 0x10])   // even length (6)
        let frag2 = Data([0x01, 0x02, 0x03])                     // odd length (3) → pad to 4
        var ds = DataSet()
        ds[.pixelData] = encapsulated([frag1, frag2])

        let bytes = ds.write(using: DICOMWriter(byteOrder: .littleEndian, explicitVR: true))

        // PixelData header: (7FE0,0010) "OB" 00 00 FFFFFFFF
        let header = Data([0xE0, 0x7F, 0x10, 0x00]) + Data("OB".utf8) + Data([0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertNotNil(bytes.range(of: header), "encapsulated PixelData header missing")

        // Basic Offset Table item, length 0: (FFFE,E000) 00000000
        XCTAssertNotNil(bytes.range(of: Data([0xFE, 0xFF, 0x00, 0xE0, 0x00, 0x00, 0x00, 0x00])),
                        "empty Basic Offset Table item missing")

        // Fragment 1 item: (FFFE,E000) len=6 + bytes
        XCTAssertNotNil(bytes.range(of: Data([0xFE, 0xFF, 0x00, 0xE0, 0x06, 0x00, 0x00, 0x00]) + frag1),
                        "fragment 1 must be written verbatim with its length")

        // Fragment 2 item: (FFFE,E000) len=4 + 01 02 03 00 (odd padded with 0x00)
        XCTAssertNotNil(bytes.range(of: Data([0xFE, 0xFF, 0x00, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x00])),
                        "odd-length fragment must be padded to even length")

        // Sequence Delimitation Item: (FFFE,E0DD) 00000000
        XCTAssertNotNil(bytes.range(of: Data([0xFE, 0xFF, 0xDD, 0xE0, 0x00, 0x00, 0x00, 0x00])),
                        "Sequence Delimitation Item missing")
    }

    /// Full `DICOMFile.write` → `DICOMFile.read` round-trip under an encapsulated
    /// transfer syntax must preserve the fragments (they were dropped before the fix).
    func testDICOMFileRoundTripPreservesFragments() throws {
        let frag = Data([0xFF, 0x4F, 0xFF, 0x51] + Array(repeating: 0xAB, count: 28))
        var els: [DataElement] = []
        els.append(.uint16(tag: .rows, value: 4))
        els.append(.uint16(tag: .columns, value: 4))
        els.append(.uint16(tag: .bitsAllocated, value: 8))
        els.append(.uint16(tag: .bitsStored, value: 8))
        els.append(.uint16(tag: .highBit, value: 7))
        els.append(.uint16(tag: .pixelRepresentation, value: 0))
        els.append(.uint16(tag: .samplesPerPixel, value: 1))
        els.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        els.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"))
        els.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5"))
        els.append(encapsulated([frag]))

        let data = try DICOMFile.create(
            dataSet: DataSet(elements: els),
            sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            sopInstanceUID: "1.2.3.4.5",
            transferSyntaxUID: TransferSyntax.jpeg2000Lossless.uid   // encapsulated (.90)
        ).write()

        let reread = try DICOMFile.read(from: data)
        let pd = try XCTUnwrap(reread.dataSet[.pixelData], "PixelData lost on write+read")
        let fragments = try XCTUnwrap(pd.encapsulatedFragments,
                                      "encapsulated fragments dropped on write+read")
        XCTAssertEqual(fragments.count, 1)
        XCTAssertEqual(fragments.first, frag, "fragment bytes must survive the round-trip")
    }
}
