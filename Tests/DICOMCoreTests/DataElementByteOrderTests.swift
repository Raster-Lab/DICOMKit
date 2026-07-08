import Testing
import Foundation
@testable import DICOMCore

/// Verifies that `DataElement`'s numeric value accessors honor the element's `byteOrder`.
///
/// Regression: a data element parsed from an Explicit VR Big Endian dataset
/// (1.2.840.10008.1.2.2) stored its raw value bytes big-endian, but every numeric accessor
/// decoded little-endian — so e.g. Bits Allocated `16` (US bytes 0x00 0x10 BE) read back as
/// 0x1000 = 4096. Now the accessors decode according to `byteOrder`. Reference: PS3.5 §7.1.2.
@Suite("DataElement byte order")
struct DataElementByteOrderTests {

    private func element(_ vr: VR, _ bytes: [UInt8], _ byteOrder: ByteOrder) -> DataElement {
        DataElement(tag: Tag(group: 0x0028, element: 0x0100), vr: vr,
                    length: UInt32(bytes.count), valueData: Data(bytes), byteOrder: byteOrder)
    }

    @Test("US 16 decodes as 16 in both byte orders (the Bits Allocated 4096 bug)")
    func uint16BothOrders() {
        // Little endian: 16 = 0x0010 → bytes [0x10, 0x00]
        #expect(element(.US, [0x10, 0x00], .littleEndian).uint16Value == 16)
        // Big endian: 16 → bytes [0x00, 0x10]. Previously mis-read as 0x1000 = 4096.
        #expect(element(.US, [0x00, 0x10], .bigEndian).uint16Value == 16)
        #expect(element(.US, [0x00, 0x10], .bigEndian).uint16Value != 4096)
    }

    @Test("UL / SL 32-bit values honor byte order")
    func uint32BothOrders() {
        // 0x01020304
        #expect(element(.UL, [0x04, 0x03, 0x02, 0x01], .littleEndian).uint32Value == 0x0102_0304)
        #expect(element(.UL, [0x01, 0x02, 0x03, 0x04], .bigEndian).uint32Value == 0x0102_0304)
        #expect(element(.SL, [0xFF, 0xFF, 0xFF, 0xFF], .bigEndian).int32Value == -1)
    }

    @Test("SS 16-bit signed honors byte order")
    func int16BothOrders() {
        // -2 = 0xFFFE
        #expect(element(.SS, [0xFE, 0xFF], .littleEndian).int16Value == -2)
        #expect(element(.SS, [0xFF, 0xFE], .bigEndian).int16Value == -2)
    }

    @Test("FL / FD floats honor byte order")
    func floatsBothOrders() {
        let f: Float32 = 1.5   // 0x3FC00000
        let le = withUnsafeBytes(of: f.bitPattern.littleEndian) { Array($0) }
        let be = withUnsafeBytes(of: f.bitPattern.bigEndian) { Array($0) }
        #expect(element(.FL, le, .littleEndian).float32Value == 1.5)
        #expect(element(.FL, be, .bigEndian).float32Value == 1.5)
        let d: Float64 = -2.25
        let dbe = withUnsafeBytes(of: d.bitPattern.bigEndian) { Array($0) }
        #expect(element(.FD, dbe, .bigEndian).float64Value == -2.25)
    }

    @Test("Multi-valued accessors honor byte order")
    func arraysBothOrders() {
        // Two US values 1 and 258 (0x0102) in big endian
        #expect(element(.US, [0x00, 0x01, 0x01, 0x02], .bigEndian).uint16Values == [1, 258])
        #expect(element(.US, [0x01, 0x00, 0x02, 0x01], .littleEndian).uint16Values == [1, 258])
    }

    @Test("Default byte order is little endian (source compatibility)")
    func defaultsToLittleEndian() {
        let e = DataElement(tag: Tag(group: 0x0028, element: 0x0100), vr: .US, length: 2,
                            valueData: Data([0x10, 0x00]))
        #expect(e.byteOrder == .littleEndian)
        #expect(e.uint16Value == 16)
    }
}
