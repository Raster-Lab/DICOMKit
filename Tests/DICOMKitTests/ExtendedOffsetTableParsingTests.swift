import Foundation
import Testing
@testable import DICOMKit
import DICOMCore

/// Contract tests for the 64-bit Value Representations (PS3.5 2026d Table 6.2-1:
/// OV, SV, UV) and for the Extended Offset Table elements (PS3.3 C.7.6.3.1.8).
/// Before 2.2.16 `VR` had no OV/SV/UV case, so an explicit "OV" element was read
/// as UN and the dictionary listed (7FE0,0001)/(7FE0,0002) as UN.
@Suite("Extended Offset Table and 64-bit VR parsing")
struct ExtendedOffsetTableParsingTests {
    private static let explicitLE = "1.2.840.10008.1.2.1"
    private static let implicitLE = "1.2.840.10008.1.2"
    private static let jpegLSLossless = "1.2.840.10008.1.2.4.80"

    private func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8)] }
    private func le32(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } }
    private func le64(_ value: UInt64) -> [UInt8] { (0..<8).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } }

    /// Hand-authored element header; `nil` VR writes the implicit form.
    private func element(_ group: UInt16, _ element: UInt16, vr: String?, _ payload: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = le16(group)
        bytes += le16(element)
        if let vr {
            bytes += Array(vr.utf8)
            if ["OB", "OW", "OV", "SV", "UV", "UN", "SQ", "UT", "UC", "UR", "OD", "OF", "OL"].contains(vr) {
                bytes += [0, 0]
                bytes += le32(UInt32(payload.count))
            } else {
                bytes += le16(UInt16(payload.count))
            }
        } else {
            bytes += le32(UInt32(payload.count))
        }
        return bytes + payload
    }

    private func uid(_ value: String) -> [UInt8] {
        let bytes = Array(value.utf8)
        return bytes + (bytes.count.isMultiple(of: 2) ? [] : [0])
    }

    private func part10(transferSyntax: String, body: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: 128)
        bytes += [0x44, 0x49, 0x43, 0x4D]
        bytes += element(0x0002, 0x0010, vr: "UI", uid(transferSyntax))
        return Data(bytes + body)
    }

    private func item(_ payload: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = [0xFE, 0xFF, 0x00, 0xE0]
        bytes += le32(UInt32(payload.count))
        return bytes + payload
    }

    @Test("OV, SV and UV are Value Representations with the 32-bit length form")
    func sixtyFourBitRepresentations() {
        #expect(VR(rawValue: "OV") == .OV)
        #expect(VR(rawValue: "SV") == .SV)
        #expect(VR(rawValue: "UV") == .UV)
        #expect(VR.OV.uses32BitLength)
        #expect(VR.SV.uses32BitLength)
        #expect(VR.UV.uses32BitLength)
        #expect(VR.OV.characterRepertoire == nil)
        #expect(VR.allCases.count == 34)
    }

    @Test("An explicit VR OV element is retained with its VR, 32-bit length and exact bytes")
    func explicitOVElementIsRetained() throws {
        let offsets: [UInt8] = le64(0) + le64(0x1_0000_0008)
        let lengths: [UInt8] = le64(1379) + le64(0xFFFF_FFFF_FFFF_FFFF)
        // A value longer than UInt16.max proves the 2 reserved + 4-byte length form.
        let long = [UInt8](repeating: 0x5A, count: 65_544)
        let fragment: [UInt8] = [0xFF, 0xD8, 0xFF, 0xD9]
        var body: [UInt8] = []
        body += element(0x0008, 0x0016, vr: "UI", uid("1.2.840.10008.5.1.4.1.1.66.7"))
        body += element(0x0008, 0x0018, vr: "UI", uid("2.25.1"))
        body += element(0x0072, 0x0081, vr: "OV", long)
        body += element(0x7FE0, 0x0001, vr: "OV", offsets)
        body += element(0x7FE0, 0x0002, vr: "OV", lengths)
        body += [0xE0, 0x7F, 0x10, 0x00, 0x4F, 0x42, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]
        body += item([])
        body += item(fragment)
        body += [0xFE, 0xFF, 0xDD, 0xE0, 0, 0, 0, 0]
        let file = try DICOMFile.read(from: part10(transferSyntax: Self.jpegLSLossless, body: body))
        let table = try #require(file.dataSet[.extendedOffsetTable])
        #expect(table.vr == .OV)
        #expect(table.length == 16)
        #expect(Array(table.valueData) == offsets)
        let tableLengths = try #require(file.dataSet[.extendedOffsetTableLengths])
        #expect(tableLengths.vr == .OV)
        #expect(Array(tableLengths.valueData) == lengths)
        let selector = try #require(file.dataSet[Tag(group: 0x0072, element: 0x0081)])
        #expect(selector.vr == .OV)
        #expect(selector.length == 65_544)
        #expect(selector.valueData == Data(long))
        let pixel = try #require(file.dataSet[.pixelData])
        #expect(pixel.isEncapsulated)
        #expect(pixel.encapsulatedOffsetTable == [])
        #expect(pixel.encapsulatedFragments == [Data(fragment)])
    }

    @Test("Implicit VR elements resolve OV, SV and UV from the dictionary")
    func implicitVRUsesDictionary() throws {
        var body: [UInt8] = []
        body += element(0x0008, 0x0016, vr: nil, uid("1.2.840.10008.5.1.4.1.1.7"))
        body += element(0x0008, 0x0428, vr: nil, le64(12))
        body += element(0x0072, 0x0082, vr: nil, le64(UInt64(bitPattern: -5)))
        body += element(0x7FE0, 0x0001, vr: nil, le64(0))
        body += element(0x7FE0, 0x0002, vr: nil, le64(7))
        body += element(0x7FE0, 0x0003, vr: nil, le64(15))
        let file = try DICOMFile.read(from: part10(transferSyntax: Self.implicitLE, body: body))
        #expect(file.dataSet[Tag(group: 0x0008, element: 0x0428)]?.vr == .UV)
        #expect(file.dataSet[Tag(group: 0x0072, element: 0x0082)]?.vr == .SV)
        #expect(file.dataSet[.extendedOffsetTable]?.vr == .OV)
        #expect(file.dataSet[.extendedOffsetTableLengths]?.vr == .OV)
        #expect(file.dataSet[Tag(group: 0x7FE0, element: 0x0003)]?.vr == .UV)
        #expect(file.dataSet[Tag(group: 0x7FE0, element: 0x0003)]?.valueData == Data(le64(15)))
    }

    @Test("The writer encodes OV with two reserved bytes and a 32-bit length, and the reader round-trips it")
    func writerRoundTrip() throws {
        let writer = DICOMWriter()
        let header: [UInt8] = Array(writer.serializeElementHeader(tag: .extendedOffsetTable, vr: .OV, length: 70_000))
        let expectedHeader: [UInt8] = [0xE0, 0x7F, 0x01, 0x00, 0x4F, 0x56, 0x00, 0x00] + le32(70_000)
        #expect(header == expectedHeader)
        let lengthsHeader: [UInt8] = Array(writer.serializeElementHeader(tag: .extendedOffsetTableLengths, vr: .UV, length: 8))
        let expectedLengthsHeader: [UInt8] = [0xE0, 0x7F, 0x02, 0x00, 0x55, 0x56, 0x00, 0x00, 8, 0, 0, 0]
        #expect(lengthsHeader == expectedLengthsHeader)

        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("2.25.2", for: .sopInstanceUID, vr: .UI)
        let offsets = Data(le64(0) + le64(0x1_0000_0000) as [UInt8])
        let lengths = Data(le64(65_535) + le64(3) as [UInt8])
        dataSet[.extendedOffsetTable] = DataElement.data(tag: .extendedOffsetTable, vr: .OV, data: offsets)
        dataSet[.extendedOffsetTableLengths] = DataElement.data(tag: .extendedOffsetTableLengths, vr: .OV, data: lengths)
        let written = try DICOMFile.create(dataSet: dataSet).write()
        let file = try DICOMFile.read(from: written)
        #expect(file.dataSet[.extendedOffsetTable]?.vr == .OV)
        #expect(file.dataSet[.extendedOffsetTable]?.valueData == offsets)
        #expect(file.dataSet[.extendedOffsetTableLengths]?.vr == .OV)
        #expect(file.dataSet[.extendedOffsetTableLengths]?.valueData == lengths)
        // The serialized header carries the VR literally.
        let range = try #require(written.range(of: Data([0xE0, 0x7F, 0x01, 0x00])))
        let serializedHeader: [UInt8] = Array(written[range.upperBound..<range.upperBound + 8])
        let expectedSerializedHeader: [UInt8] = [0x4F, 0x56, 0x00, 0x00, 16, 0, 0, 0]
        #expect(serializedHeader == expectedSerializedHeader)
    }
}
