//
// BitstreamReaderTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit

/// Exp-Golomb and emulation-prevention vectors.
///
/// These primitives sit under every SPS/VPS field, so an error here misreports
/// dimensions and profiles rather than failing outright.
///
/// Reference: ITU-T H.264 Section 9.1, Section 7.3.1
final class BitstreamReaderTests: XCTestCase {

    // MARK: - Fixed-width reads

    func test_readBit_walksMostSignificantBitFirst() {
        var reader = BitstreamReader(bytes: [0b1011_0010])
        XCTAssertEqual(reader.readBit(), true)
        XCTAssertEqual(reader.readBit(), false)
        XCTAssertEqual(reader.readBit(), true)
        XCTAssertEqual(reader.readBit(), true)
        XCTAssertEqual(reader.readBit(), false)
        XCTAssertEqual(reader.readBit(), false)
        XCTAssertEqual(reader.readBit(), true)
        XCTAssertEqual(reader.readBit(), false)
        XCTAssertNil(reader.readBit(), "past the end")
    }

    func test_readBits_acrossByteBoundary() {
        var reader = BitstreamReader(bytes: [0b1010_1010, 0b1100_0011])
        XCTAssertEqual(reader.readBits(4), 0b1010)
        XCTAssertEqual(reader.readBits(8), 0b1010_1100)
        XCTAssertEqual(reader.readBits(4), 0b0011)
        XCTAssertNil(reader.readBits(1))
    }

    func test_readBits_zeroLengthIsZero() {
        var reader = BitstreamReader(bytes: [0xFF])
        XCTAssertEqual(reader.readBits(0), 0)
        XCTAssertEqual(reader.bitPosition, 0, "a zero-width read consumes nothing")
    }

    func test_readBits_rejectsOverWideRequest() {
        var reader = BitstreamReader(bytes: [UInt8](repeating: 0xFF, count: 16))
        XCTAssertNil(reader.readBits(33), "u(n) is capped at 32 bits")
        XCTAssertNil(reader.readBits(-1))
    }

    func test_readBits_returnsNilRatherThanShortValue() {
        var reader = BitstreamReader(bytes: [0xFF])
        XCTAssertNil(reader.readBits(9), "a truncated read must fail, not pad")
        XCTAssertEqual(reader.bitPosition, 0, "a failed read leaves the position put")
    }

    func test_readBits64_widerThanThirtyTwo() {
        var reader = BitstreamReader(bytes: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(reader.readBits64(48), 0xFFFF_FFFF_FFFF)
    }

    func test_skipBits_andAlignToByte() {
        var reader = BitstreamReader(bytes: [0b1111_0000, 0b1010_1010])
        XCTAssertTrue(reader.skipBits(3))
        XCTAssertEqual(reader.bitPosition, 3)
        reader.alignToByte()
        XCTAssertEqual(reader.bitPosition, 8)
        XCTAssertEqual(reader.readBits(8), 0b1010_1010)
        XCTAssertFalse(reader.skipBits(1), "cannot skip past the end")
    }

    func test_alignToByte_isNoOpWhenAlreadyAligned() {
        var reader = BitstreamReader(bytes: [0xAA, 0xBB])
        reader.alignToByte()
        XCTAssertEqual(reader.bitPosition, 0)
        _ = reader.readBits(8)
        reader.alignToByte()
        XCTAssertEqual(reader.bitPosition, 8)
    }

    func test_bitsRemaining_tracksConsumption() {
        var reader = BitstreamReader(bytes: [0x00, 0x00])
        XCTAssertEqual(reader.bitCount, 16)
        XCTAssertEqual(reader.bitsRemaining, 16)
        _ = reader.readBits(5)
        XCTAssertEqual(reader.bitsRemaining, 11)
        XCTAssertTrue(reader.canRead(11))
        XCTAssertFalse(reader.canRead(12))
    }

    // MARK: - Unsigned Exp-Golomb, ue(v)

    func test_readUE_knownVectors() {
        // Code words from ITU-T H.264 Table 9-1:
        //   1        -> 0
        //   010      -> 1
        //   011      -> 2
        //   00100    -> 3
        //   00101    -> 4
        //   00110    -> 5
        //   00111    -> 6
        //   0001000  -> 7
        let bits = "1" + "010" + "011" + "00100" + "00101" + "00110" + "00111" + "0001000"
        var reader = BitstreamReader(bytes: Self.packBits(bits))

        for expected in UInt32(0)...UInt32(7) {
            XCTAssertEqual(reader.readUE(), expected, "ue(v) for code number \(expected)")
        }
    }

    func test_readUE_largeValue() {
        // 2^16 - 1 + 0 = 65535: sixteen zeros, a one, then sixteen zeros.
        let bits = String(repeating: "0", count: 16) + "1" + String(repeating: "0", count: 16)
        var reader = BitstreamReader(bytes: Self.packBits(bits))
        XCTAssertEqual(reader.readUE(), 65535)
    }

    func test_readUE_truncatedCodeReturnsNil() {
        // A leading-zero run with no terminating one bit.
        var reader = BitstreamReader(bytes: [0x00, 0x00])
        XCTAssertNil(reader.readUE())
    }

    func test_readUE_rejectsImplausiblyLongZeroRun() {
        // 33+ leading zeros cannot encode a legal 32-bit value; the reader must
        // give up rather than overflow.
        var reader = BitstreamReader(bytes: [UInt8](repeating: 0x00, count: 8) + [0x01])
        XCTAssertNil(reader.readUE())
    }

    func test_readUE_emptyBuffer() {
        var reader = BitstreamReader(bytes: [])
        XCTAssertNil(reader.readUE())
    }

    // MARK: - Signed Exp-Golomb, se(v)

    func test_readSE_knownVectors() {
        // ITU-T H.264 Table 9-3: code 0 -> 0, 1 -> 1, 2 -> -1, 3 -> 2, 4 -> -2,
        // 5 -> 3, 6 -> -3.
        let bits = "1" + "010" + "011" + "00100" + "00101" + "00110" + "00111"
        var reader = BitstreamReader(bytes: Self.packBits(bits))

        let expected: [Int32] = [0, 1, -1, 2, -2, 3, -3]
        for value in expected {
            XCTAssertEqual(reader.readSE(), value, "se(v) for \(value)")
        }
    }

    func test_readSE_truncatedReturnsNil() {
        var reader = BitstreamReader(bytes: [0x00])
        XCTAssertNil(reader.readSE())
    }

    // MARK: - Emulation prevention

    func test_removeEmulationPrevention_stripsInsertedByte() {
        // 00 00 03 01 -> 00 00 01
        let input = Data([0x00, 0x00, 0x03, 0x01, 0xAB])
        let output = NALUnit.removeEmulationPrevention(input)
        XCTAssertEqual(Array(output), [0x00, 0x00, 0x01, 0xAB])
    }

    func test_removeEmulationPrevention_stripsEveryOccurrence() {
        let input = Data([0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x03, 0x02, 0xFF])
        let output = NALUnit.removeEmulationPrevention(input)
        XCTAssertEqual(Array(output), [0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xFF])
    }

    func test_removeEmulationPrevention_keepsUnrelatedThreeBytes() {
        // 0x03 not preceded by 00 00 is ordinary payload data.
        let input = Data([0x01, 0x03, 0x02, 0x03])
        XCTAssertEqual(NALUnit.removeEmulationPrevention(input), input)
    }

    func test_removeEmulationPrevention_keepsThreeAfterNonEmulationSequence() {
        // 00 00 03 followed by a byte above 0x03 is not an emulation prevention
        // sequence, so the 0x03 stays.
        let input = Data([0x00, 0x00, 0x03, 0xFF])
        XCTAssertEqual(NALUnit.removeEmulationPrevention(input), input)
    }

    func test_removeEmulationPrevention_shortBufferUnchanged() {
        XCTAssertEqual(NALUnit.removeEmulationPrevention(Data([0x00, 0x00])),
                       Data([0x00, 0x00]))
        XCTAssertEqual(NALUnit.removeEmulationPrevention(Data()), Data())
    }

    func test_removeEmulationPrevention_isRequiredForCorrectParsing() {
        // Without stripping, the inserted 0x03 shifts every following field by a
        // byte. This is the failure mode the helper exists to prevent.
        //
        // 0x03 here follows 00 00 and is itself followed by 0x01 (<= 0x03), so it
        // is a genuine emulation prevention byte and must be removed.
        let raw = Data([0x00, 0x00, 0x03, 0x01, 0xEF])
        let stripped = NALUnit.removeEmulationPrevention(raw)
        XCTAssertEqual(Array(stripped), [0x00, 0x00, 0x01, 0xEF])

        var strippedReader = BitstreamReader(stripped)
        XCTAssertTrue(strippedReader.skipBits(16))
        XCTAssertEqual(strippedReader.readBits(8), 0x01,
                       "after stripping, the third byte is the real payload 0x01")

        // Reading the raw bytes instead would have yielded the 0x03 filler and
        // desynchronized every subsequent field.
        var rawReader = BitstreamReader(raw)
        XCTAssertTrue(rawReader.skipBits(16))
        XCTAssertEqual(rawReader.readBits(8), 0x03)
    }

    // MARK: - Annex B splitting

    func test_splitAnnexB_threeByteStartCodes() {
        let stream = Data([
            0x00, 0x00, 0x01, 0x67, 0xAA,
            0x00, 0x00, 0x01, 0x68, 0xBB, 0xCC,
        ])
        let units = NALUnit.splitAnnexB(stream)
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(Array(units[0]), [0x67, 0xAA])
        XCTAssertEqual(Array(units[1]), [0x68, 0xBB, 0xCC])
    }

    func test_splitAnnexB_fourByteStartCodes() {
        let stream = Data([
            0x00, 0x00, 0x00, 0x01, 0x67, 0xAA,
            0x00, 0x00, 0x00, 0x01, 0x65, 0xBB,
        ])
        let units = NALUnit.splitAnnexB(stream)
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(Array(units[0]), [0x67, 0xAA])
        XCTAssertEqual(Array(units[1]), [0x65, 0xBB])
    }

    func test_splitAnnexB_mixedStartCodeLengths() {
        let stream = Data([
            0x00, 0x00, 0x00, 0x01, 0x67, 0x01,
            0x00, 0x00, 0x01, 0x68, 0x02,
        ])
        let units = NALUnit.splitAnnexB(stream)
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(Array(units[0]), [0x67, 0x01])
        XCTAssertEqual(Array(units[1]), [0x68, 0x02])
    }

    func test_splitAnnexB_noStartCodeYieldsNothing() {
        XCTAssertTrue(NALUnit.splitAnnexB(Data([0x67, 0x42, 0x00, 0x1F])).isEmpty)
        XCTAssertTrue(NALUnit.splitAnnexB(Data()).isEmpty)
    }

    func test_hasAnnexBStartCode() {
        XCTAssertTrue(NALUnit.hasAnnexBStartCode(Data([0x00, 0x00, 0x01, 0x67])))
        XCTAssertTrue(NALUnit.hasAnnexBStartCode(Data([0x00, 0x00, 0x00, 0x01])))
        XCTAssertFalse(NALUnit.hasAnnexBStartCode(Data([0x00, 0x00, 0x02, 0x67])))
        XCTAssertFalse(NALUnit.hasAnnexBStartCode(Data([0x67, 0x42])))
        XCTAssertFalse(NALUnit.hasAnnexBStartCode(Data()))
    }

    // MARK: - Helpers

    /// Packs a string of '0'/'1' characters into bytes, zero-padding the tail.
    private static func packBits(_ bits: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var current: UInt8 = 0
        var filled = 0
        for character in bits {
            current = (current << 1) | (character == "1" ? 1 : 0)
            filled += 1
            if filled == 8 {
                bytes.append(current)
                current = 0
                filled = 0
            }
        }
        if filled > 0 {
            bytes.append(current << UInt8(8 - filled))
        }
        return bytes
    }
}
