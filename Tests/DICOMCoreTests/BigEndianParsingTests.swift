import Testing
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// End-to-end regression for Explicit VR Big Endian (1.2.840.10008.1.2.2, retired) parsing.
///
/// Bug: the parser read the element structure (tag/length) with the correct byte order but
/// did not carry the byte order onto the produced `DataElement`, so numeric value accessors
/// decoded little-endian — Bits Allocated `16` came back as `4096`, and native 16-bit pixel
/// samples were byte-swapped (noise). Now the byte order is threaded through and native
/// pixels are normalized to little endian. Reference: PS3.5 §7.1.2.
@Suite("Explicit VR Big Endian parsing")
struct BigEndianParsingTests {

    /// Encodes one Explicit-VR short-form element (US/SS/CS/… 2-byte length) in a byte order.
    private func shortElement(group: UInt16, element: UInt16, vr: String, value: [UInt8],
                              byteOrder: ByteOrder) -> [UInt8] {
        func u16(_ v: UInt16) -> [UInt8] {
            byteOrder == .bigEndian ? [UInt8(v >> 8), UInt8(v & 0xFF)]
                                    : [UInt8(v & 0xFF), UInt8(v >> 8)]
        }
        return u16(group) + u16(element) + Array(vr.utf8) + u16(UInt16(value.count)) + value
    }

    private func u16Value(_ v: UInt16, _ byteOrder: ByteOrder) -> [UInt8] {
        byteOrder == .bigEndian ? [UInt8(v >> 8), UInt8(v & 0xFF)] : [UInt8(v & 0xFF), UInt8(v >> 8)]
    }

    /// A minimal Image Pixel module (Bits Allocated / Rows / Columns) in the given byte order.
    private func imagePixelModule(byteOrder bo: ByteOrder) -> Data {
        var bytes: [UInt8] = []
        bytes += shortElement(group: 0x0028, element: 0x0010, vr: "US", value: u16Value(4, bo), byteOrder: bo) // Rows = 4
        bytes += shortElement(group: 0x0028, element: 0x0011, vr: "US", value: u16Value(5, bo), byteOrder: bo) // Columns = 5
        bytes += shortElement(group: 0x0028, element: 0x0100, vr: "US", value: u16Value(16, bo), byteOrder: bo) // Bits Allocated = 16
        bytes += shortElement(group: 0x0028, element: 0x0101, vr: "US", value: u16Value(12, bo), byteOrder: bo) // Bits Stored = 12
        return Data(bytes)
    }

    @Test("Big-endian Bits Allocated 16 parses as 16, not 4096")
    func bitsAllocatedNotByteSwapped() throws {
        var parser = DICOMParser(data: imagePixelModule(byteOrder: .bigEndian))
        let ds = try parser.parseDataSet(startOffset: 0,
                                         transferSyntaxUID: TransferSyntax.explicitVRBigEndian.uid)
        let bitsAllocated = ds[Tag(group: 0x0028, element: 0x0100)]?.uint16Value
        #expect(bitsAllocated == 16)
        #expect(bitsAllocated != 4096)
        // The element itself carries the big-endian byte order.
        #expect(ds[Tag(group: 0x0028, element: 0x0100)]?.byteOrder == .bigEndian)
    }

    @Test("Little- and big-endian encodings of the same values parse identically")
    func crossOrderEquivalence() throws {
        var le = DICOMParser(data: imagePixelModule(byteOrder: .littleEndian))
        var be = DICOMParser(data: imagePixelModule(byteOrder: .bigEndian))
        let dsLE = try le.parseDataSet(startOffset: 0, transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid)
        let dsBE = try be.parseDataSet(startOffset: 0, transferSyntaxUID: TransferSyntax.explicitVRBigEndian.uid)
        for (g, e) in [(UInt16(0x0028), UInt16(0x0010)), (0x0028, 0x0011), (0x0028, 0x0100), (0x0028, 0x0101)] {
            #expect(dsLE[Tag(group: g, element: e)]?.uint16Value == dsBE[Tag(group: g, element: e)]?.uint16Value)
        }
    }

    @Test("Native 16-bit pixel bytes are byte-swapped to little endian only for big endian")
    func nativePixelNormalization() {
        // Four 16-bit samples 1,2,3,4 stored big-endian.
        let bigEndianSamples = Data([0x00, 0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04])
        let normalized = DataSet.nativePixelBytesLittleEndian(bigEndianSamples, byteOrder: .bigEndian, bitsAllocated: 16)
        // Expect little-endian bytes for 1,2,3,4.
        #expect(Array(normalized) == [0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04, 0x00])
        // Little-endian input is returned unchanged.
        #expect(DataSet.nativePixelBytesLittleEndian(bigEndianSamples, byteOrder: .littleEndian, bitsAllocated: 16) == bigEndianSamples)
        // 8-bit samples are byte-order independent — unchanged even for big endian.
        let eightBit = Data([0x01, 0x02, 0x03])
        #expect(DataSet.nativePixelBytesLittleEndian(eightBit, byteOrder: .bigEndian, bitsAllocated: 8) == eightBit)
    }
}
