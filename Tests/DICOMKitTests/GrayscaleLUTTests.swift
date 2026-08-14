// GrayscaleLUTTests.swift
// DICOMKitTests
//
// SRS FR-004: table-form Modality and VOI LUTs.
//
// The decoding rules under test are the classic failure points: a declared
// entry count of 0 means 65536, the first mapped value turns signed with the
// pixels, and 12-bit tables declared as 16 bits per entry must not lose four
// fifths of the film's dynamic range.

import Testing
@testable import DICOMKit
import DICOMCore
import Foundation

@Suite("Grayscale LUT Tests")
struct GrayscaleLUTTests {

    // MARK: Builders

    private func descriptorData(entries: UInt16, first: UInt16, bits: UInt16) -> Data {
        var data = Data()
        for value in [entries, first, bits] {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8(value >> 8))
        }
        return data
    }

    private func wordData(_ values: [UInt16]) -> Data {
        var data = Data(capacity: values.count * 2)
        for value in values {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8(value >> 8))
        }
        return data
    }

    private func element(_ tag: Tag, vr: VR, _ data: Data) -> DataElement {
        DataElement(tag: tag, vr: vr, length: UInt32(data.count), valueData: data)
    }

    private func lutItem(entries: UInt16, first: UInt16, bits: UInt16,
                         data: Data) -> SequenceItem {
        SequenceItem(elements: [
            element(Tag(group: 0x0028, element: 0x3002), vr: .US,
                    descriptorData(entries: entries, first: first, bits: bits)),
            element(Tag(group: 0x0028, element: 0x3006), vr: .OW, data),
        ])
    }

    // MARK: Decoding

    @Test("A word-per-entry table decodes and clamps at both ends")
    func testBasicDecodeAndClamp() throws {
        let lut = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 4, first: 100, bits: 16,
                          data: wordData([10, 20, 30, 40])),
            signedPixels: false))
        #expect(lut.entries == [10, 20, 30, 40])
        #expect(lut.value(for: 100) == 10)
        #expect(lut.value(for: 103) == 40)
        #expect(lut.value(for: 0) == 10, "below the first mapped value clamps low")
        #expect(lut.value(for: 5000) == 40, "past the end clamps high")
    }

    @Test("A declared entry count of zero means 65536, not an empty table")
    func testZeroMeans65536() throws {
        let lut = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 0, first: 0, bits: 16,
                          data: wordData([UInt16](repeating: 7, count: 65536))),
            signedPixels: false))
        #expect(lut.entries.count == 65536)
    }

    @Test("The first mapped value is signed when the pixels are")
    func testSignedFirstMapped() throws {
        // 0xFC00 is −1024 as Int16 — the CT case.
        let signed = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 2, first: 0xFC00, bits: 16, data: wordData([1, 2])),
            signedPixels: true))
        #expect(signed.firstMappedValue == -1024)
        #expect(signed.value(for: -1024) == 1)

        let unsigned = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 2, first: 0xFC00, bits: 16, data: wordData([1, 2])),
            signedPixels: false))
        #expect(unsigned.firstMappedValue == 64512)
    }

    @Test("8-bit entries packed one per byte decode")
    func testBytePackedEntries() throws {
        let lut = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 3, first: 0, bits: 8, data: Data([5, 6, 7])),
            signedPixels: false))
        #expect(lut.entries == [5, 6, 7])
    }

    @Test("Truncated LUT data is rejected, not read past its end")
    func testTruncatedData() {
        #expect(GrayscaleLUT.parse(
            item: lutItem(entries: 100, first: 0, bits: 16, data: wordData([1, 2])),
            signedPixels: false) == nil)
    }

    // MARK: Normalization

    @Test("VOI normalization spans the table's actual range — the 12-in-16 case")
    func testNormalizationUsesActualRange() throws {
        // A 12-bit table declared as 16 bits per entry: peak 4095, not 65535.
        let lut = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 3, first: 0, bits: 16,
                          data: wordData([0, 2048, 4095])),
            signedPixels: false))
        #expect(lut.normalized(0) == 0)
        #expect(lut.normalized(2) == 1, "the film reaches full white")
        #expect(abs(lut.normalized(1) - 2048.0 / 4095.0) < 0.001)
    }

    @Test("A flat table normalizes to zero rather than dividing by nothing")
    func testFlatTable() throws {
        let lut = try #require(GrayscaleLUT.parse(
            item: lutItem(entries: 2, first: 0, bits: 16, data: wordData([9, 9])),
            signedPixels: false))
        #expect(lut.normalized(0) == 0)
        #expect(lut.normalized(1) == 0)
    }

    // MARK: Reading from a data set

    private func sequenceElement(_ tag: Tag, item: SequenceItem) -> DataElement {
        DataElement(tag: tag, vr: .SQ, length: 0, valueData: Data(),
                    sequenceItems: [item])
    }

    private func decimalElement(_ tag: Tag, _ value: String) -> DataElement {
        let padded = value.count % 2 == 0 ? value : value + " "
        return DataElement(tag: tag, vr: .DS, length: UInt32(padded.utf8.count),
                           valueData: Data(padded.utf8))
    }

    @Test("A data set's Modality LUT Sequence is found and decoded")
    func testDataSetModalityLUT() throws {
        let dataSet = DataSet(elements: [
            sequenceElement(Tag(group: 0x0028, element: 0x3000),
                            item: lutItem(entries: 2, first: 0, bits: 16,
                                          data: wordData([100, 200]))),
        ])
        let lut = try #require(dataSet.modalityLUT())
        #expect(lut.value(for: 1) == 200)
        #expect(dataSet.voiLUT() == nil)
    }

    @Test("A VOI LUT after a negative rescale intercept reads its origin as signed")
    func testVOILUTSignedAfterRescale() throws {
        let dataSet = DataSet(elements: [
            decimalElement(Tag(group: 0x0028, element: 0x1052), "-1024"),
            decimalElement(Tag(group: 0x0028, element: 0x1053), "1"),
            sequenceElement(Tag(group: 0x0028, element: 0x3010),
                            item: lutItem(entries: 2, first: 0xFC00, bits: 16,
                                          data: wordData([0, 4095]))),
        ])
        let lut = try #require(dataSet.voiLUT())
        #expect(lut.firstMappedValue == -1024,
                "the VOI input is rescaled output, which starts at the intercept")
    }
}
