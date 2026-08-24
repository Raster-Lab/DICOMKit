import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// Copy-map regression guards (instruction §1.4 / §19 deliverable 5).
///
/// Invariant: any public entry point that takes `Data` must produce identical results
/// for a contiguous buffer and for a slice of a larger buffer (non-zero `startIndex`).
/// Slicing is the natural zero-copy idiom, and the byte-source work (WP-A/WP-D) will
/// make sliced input the *normal* case on the hot path.
///
/// The RLE decoder violated this (fixed 2026-08-11, see `CodecFuzzTests`); these tests
/// pin the same contract at the parser boundary, where `DICOMFile.read(from: Data)` is
/// public and mixes slice-relative reads (`readUInt16LE`, via `ByteOrder`) with
/// absolute indexing (`subdata(in:)`, `data[128..<132]`).
final class SliceIndependenceTests: XCTestCase {

    /// A minimal but complete Part 10 file: preamble + DICM + FMI (group length,
    /// transfer syntax) + a few dataset elements including a small sequence.
    private func minimalPart10File() -> Data {
        var d = Data(count: 128)                                  // preamble
        d.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])            // "DICM"

        func explicitElement(_ group: UInt16, _ element: UInt16, _ vr: String, _ value: [UInt8]) -> [UInt8] {
            var e: [UInt8] = [UInt8(group & 0xFF), UInt8(group >> 8),
                              UInt8(element & 0xFF), UInt8(element >> 8)]
            e += Array(vr.utf8)
            e += [UInt8(value.count & 0xFF), UInt8(value.count >> 8)]
            e += value
            return e
        }

        // File Meta Information (Explicit VR LE, PS3.10)
        let tsUID = Array("1.2.840.10008.1.2.1\0".utf8)           // Explicit VR LE, even length
        let fmiBody = explicitElement(0x0002, 0x0010, "UI", tsUID)
        let fmiLength = UInt32(fmiBody.count)
        d.append(contentsOf: explicitElement(0x0002, 0x0000, "UL",
            [UInt8(fmiLength & 0xFF), UInt8((fmiLength >> 8) & 0xFF),
             UInt8((fmiLength >> 16) & 0xFF), UInt8((fmiLength >> 24) & 0xFF)]))
        d.append(contentsOf: fmiBody)

        // Data set (Explicit VR LE)
        d.append(contentsOf: explicitElement(0x0010, 0x0010, "PN", Array("Slice^Test".utf8)))
        d.append(contentsOf: explicitElement(0x0008, 0x0060, "CS", Array("OT".utf8)))
        return d
    }

    /// `DICOMFile.read(from:)` must parse a slice exactly as it parses the
    /// equivalent contiguous buffer — same elements, same values.
    func testReadIsIndependentOfSliceStartIndex() throws {
        let file = minimalPart10File()

        let contiguous = try DICOMFile.read(from: file)

        // Same bytes reached through a slice with startIndex == 100.
        let padded = Data(count: 100) + file
        let slice = padded[100...]
        XCTAssertEqual(slice.startIndex, 100, "test precondition: slice must not be rebased")

        let fromSlice = try DICOMFile.read(from: slice)

        XCTAssertEqual(fromSlice.dataSet.string(for: Tag(group: 0x0010, element: 0x0010)),
                       contiguous.dataSet.string(for: Tag(group: 0x0010, element: 0x0010)),
                       "PatientName must not depend on the Data's startIndex")
        XCTAssertEqual(fromSlice.dataSet.allElements.count,
                       contiguous.dataSet.allElements.count,
                       "element count must not depend on the Data's startIndex")
    }

    /// `TransferSyntaxConverter.transcode(dataSetData:)` is public and walks the input
    /// with 0-based offsets — same contract.
    func testTranscodeIsIndependentOfSliceStartIndex() throws {
        // Tiny Explicit VR LE dataset: PatientName only.
        var raw = Data()
        raw.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
        raw.append(contentsOf: Array("PN".utf8))
        raw.append(contentsOf: [0x0A, 0x00])
        raw.append(contentsOf: Array("Xcode^Test".utf8))

        let converter = TransferSyntaxConverter()
        let contiguous = try converter.transcode(
            dataSetData: raw,
            from: .explicitVRLittleEndian,
            to: .implicitVRLittleEndian
        )

        let padded = Data(count: 80) + raw
        let slice = padded[80...]
        XCTAssertEqual(slice.startIndex, 80, "test precondition: slice must not be rebased")
        let fromSlice = try converter.transcode(
            dataSetData: slice,
            from: .explicitVRLittleEndian,
            to: .implicitVRLittleEndian
        )

        XCTAssertEqual(fromSlice.data, contiguous.data,
                       "transcode output must not depend on the Data's startIndex")
    }

    /// The `force:` path (no DICM prefix — raw dataset) must hold the same invariant.
    func testForceReadIsIndependentOfSliceStartIndex() throws {
        // Raw Explicit VR LE dataset without preamble.
        var raw = Data()
        raw.append(contentsOf: [0x10, 0x00, 0x10, 0x00])          // (0010,0010)
        raw.append(contentsOf: Array("PN".utf8))
        raw.append(contentsOf: [0x0A, 0x00])
        raw.append(contentsOf: Array("Force^Test".utf8))

        let contiguous = try DICOMFile.read(from: raw, force: true)

        let padded = Data(count: 64) + raw
        let slice = padded[64...]
        let fromSlice = try DICOMFile.read(from: slice, force: true)

        XCTAssertEqual(fromSlice.dataSet.string(for: Tag(group: 0x0010, element: 0x0010)),
                       contiguous.dataSet.string(for: Tag(group: 0x0010, element: 0x0010)))
    }
}
