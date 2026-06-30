import XCTest
import Foundation
@testable import DICOMKit
import DICOMCore

/// Regression tests for compressing Implicit VR Little Endian sources.
///
/// `CompressionManager` used to re-serialize the data set with a bespoke writer
/// that dumped each element's raw `valueData` under the *target* (Explicit VR)
/// framing. For an Implicit VR source that mis-framed two kinds of element:
///
///   1. Sequences — their `valueData` was captured by the parser in *implicit*
///      encoding, so re-emitting it verbatim under an Explicit VR sequence header
///      produced a corrupt sequence.
///   2. 16-bit-length VRs larger than 0xFFFF (legal under Implicit VR's 32-bit
///      length) — the declared length was truncated to 0xFFFF while the full
///      value was still written.
///
/// Either desynced the byte stream, so re-reading the compressed file stopped
/// before (7FE0,0010) and `decompress` failed with "No pixel data found in DICOM
/// file". The fix routes serialization through the shared `DICOMWriter` (which
/// re-encodes sequences from their parsed items) plus a sanitizer that promotes
/// oversized short-VR values to UN. These tests pin that behaviour.
final class CompressionManagerImplicitVRTests: XCTestCase {

    /// Lossless encapsulated codecs available in-process (pure-Swift reference
    /// encoders for JPEG 2000 / JPEG / JPEG-LS / JPEG XL).
    private let losslessCodecs = ["jpeg2000-lossless", "jpeg-lossless", "jpeg-ls-lossless", "jpeg-xl"]

    private let requestAttributesSequence = Tag(group: 0x0040, element: 0x0275)
    private let institutionName = Tag(group: 0x0008, element: 0x0080)   // dictionary VR LO (16-bit length)

    /// 8×8, 16-bit, 12-bit-stored MONOCHROME2 frame. Sample values stay within
    /// the 12-bit range so lossless encoders validate their round-trip.
    private func baseImageElements() -> [DataElement] {
        var els: [DataElement] = []
        els.append(.uint16(tag: .rows, value: 8))
        els.append(.uint16(tag: .columns, value: 8))
        els.append(.uint16(tag: .bitsAllocated, value: 16))
        els.append(.uint16(tag: .bitsStored, value: 12))
        els.append(.uint16(tag: .highBit, value: 11))
        els.append(.uint16(tag: .pixelRepresentation, value: 0))
        els.append(.uint16(tag: .samplesPerPixel, value: 1))
        els.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        els.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"))
        els.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9"))
        var pixels = Data()
        for i in 0..<64 {
            let v = UInt16((i * 60) % 4096)
            pixels.append(UInt8(v & 0xFF))
            pixels.append(UInt8((v >> 8) & 0xFF))
        }
        els.append(DataElement(tag: .pixelData, vr: .OW, length: UInt32(pixels.count), valueData: pixels))
        return els
    }

    private func makeImplicitFile(_ extraElements: [DataElement]) throws -> Data {
        let ds = DataSet(elements: baseImageElements() + extraElements)
        return try DICOMFile.create(dataSet: ds,
                                    transferSyntaxUID: TransferSyntax.implicitVRLittleEndian.uid).write()
    }

    // MARK: - Sequence preservation

    func testImplicitVRWithSequenceRoundTripsThroughAllCodecs() throws {
        let item = SequenceItem(elements: [
            .string(tag: Tag(group: 0x0008, element: 0x1150), vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"),
            .string(tag: Tag(group: 0x0008, element: 0x1155), vr: .UI, value: "9.8.7.6.5.4.3.2.1"),
            .string(tag: Tag(group: 0x0040, element: 0x0254), vr: .LO, value: "STEP DESCRIPTION"),
        ])
        let seq = DataElement(tag: requestAttributesSequence, vr: .SQ,
                              length: 0xFFFFFFFF, valueData: Data(), sequenceItems: [item, item])
        let implicit = try makeImplicitFile([seq])

        // Sanity: the source itself is well-formed.
        let src = try DICOMFile.read(from: implicit)
        XCTAssertNotNil(src.dataSet[.pixelData])
        XCTAssertEqual(src.dataSet.sequence(for: requestAttributesSequence)?.count, 2)

        let mgr = CompressionManager()
        for codec in losslessCodecs {
            let compressed = try mgr.compressData(implicit, codec: codec, quality: nil)

            // The compressed file must still expose encapsulated pixel data…
            let comp = try DICOMFile.read(from: compressed)
            XCTAssertNotNil(comp.dataSet[.pixelData], "\(codec): compressed file lost pixel data")
            XCTAssertNotNil(comp.dataSet[.pixelData]?.encapsulatedFragments,
                            "\(codec): compressed pixel data is not encapsulated")
            // …and the sequence carried over must survive intact (was corrupted before).
            XCTAssertEqual(comp.dataSet.sequence(for: requestAttributesSequence)?.count, 2,
                           "\(codec): sequence not preserved through compression")

            // Decompressing back to Implicit VR must succeed and restore pixels.
            let back = try mgr.decompressData(compressed, syntax: .implicitVRLittleEndian)
            let restored = try DICOMFile.read(from: back)
            XCTAssertNotNil(restored.dataSet[.pixelData], "\(codec): decompressed file lost pixel data")
            XCTAssertNil(restored.dataSet[.pixelData]?.encapsulatedFragments,
                         "\(codec): decompressed pixel data should be native")
            XCTAssertEqual(restored.dataSet.sequence(for: requestAttributesSequence)?.count, 2,
                           "\(codec): sequence not preserved through decompression")
        }
    }

    // MARK: - Oversized 16-bit-length VR element (exact original reproduction)

    func testImplicitVROversizedShortVRElementRoundTrips() throws {
        // (0008,0080) Institution Name — dictionary VR LO (16-bit length) — at
        // 70 KB it cannot be represented under Explicit VR's 16-bit length field.
        // This is the element that previously desynced the reader past the pixels.
        let huge = String(repeating: "A", count: 70_000)
        let implicit = try makeImplicitFile([.string(tag: institutionName, vr: .LO, value: huge)])

        let mgr = CompressionManager()
        let compressed = try mgr.compressData(implicit, codec: "jpeg2000-lossless", quality: nil)

        let comp = try DICOMFile.read(from: compressed)
        XCTAssertNotNil(comp.dataSet[.pixelData],
                        "compressed file lost pixel data — short-VR overflow desynced the writer")
        XCTAssertNotNil(comp.dataSet[.pixelData]?.encapsulatedFragments)

        // The previous bug surfaced here as CompressionError.noPixelData.
        let back = try mgr.decompressData(compressed, syntax: .implicitVRLittleEndian)
        let restored = try DICOMFile.read(from: back)
        XCTAssertNotNil(restored.dataSet[.pixelData], "decompressed file lost pixel data")
        XCTAssertEqual(restored.dataSet[.pixelData]?.valueData.count, 128, "frame bytes not restored")
    }
}
