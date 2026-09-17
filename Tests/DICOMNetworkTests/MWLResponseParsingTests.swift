import XCTest
import DICOMCore
@testable import DICOMNetwork

/// Parsing of MWL C-FIND responses, including SPS-sequence attributes.
final class MWLResponseParsingTests: XCTestCase {

    /// Builds an implicit-VR little-endian MWL response containing a top-level
    /// PatientName and an SPS sequence carrying SPS Start Date/Time.
    private func buildResponse() -> Data {
        func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func le32(_ v: UInt32) -> Data {
            Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                  UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
        }
        func elem(_ g: UInt16, _ e: UInt16, _ value: String) -> Data {
            var v = value.data(using: .ascii)!
            if v.count % 2 != 0 { v.append(0x20) }
            var d = Data()
            d.append(le16(g)); d.append(le16(e))
            d.append(le32(UInt32(v.count)))
            d.append(v)
            return d
        }

        var sps = Data()
        sps.append(elem(0x0040, 0x0002, "20211210"))
        sps.append(elem(0x0040, 0x0003, "161100"))

        var data = Data()
        data.append(elem(0x0010, 0x0010, "AMUDHA.N"))
        // (0040,0100) SQ, undefined length
        data.append(le16(0x0040)); data.append(le16(0x0100))
        data.append(le32(0xFFFFFFFF))
        data.append(Data([0xFE, 0xFF, 0x00, 0xE0]))   // item, undefined length
        data.append(le32(0xFFFFFFFF))
        data.append(sps)
        data.append(Data([0xFE, 0xFF, 0x0D, 0xE0]))   // item delimiter
        data.append(le32(0))
        data.append(Data([0xFE, 0xFF, 0xDD, 0xE0]))   // sequence delimiter
        data.append(le32(0))
        return data
    }

    private func parse(_ data: Data) -> [Tag: Data] {
        var offset = 0
        var out: [Tag: Data] = [:]
        DICOMModalityWorklistService.parseMWLDataSet(
            data: data, offset: &offset, end: data.count,
            isExplicitVR: false, into: &out)
        return out
    }

    private func string(_ attrs: [Tag: Data], _ g: UInt16, _ e: UInt16) -> String? {
        guard let d = attrs[Tag(group: g, element: e)] else { return nil }
        return String(data: d, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
    }

    func testParse_zeroBasedData() {
        let attrs = parse(buildResponse())
        XCTAssertEqual(string(attrs, 0x0010, 0x0010), "AMUDHA.N")
        XCTAssertEqual(string(attrs, 0x0040, 0x0002), "20211210")
        XCTAssertEqual(string(attrs, 0x0040, 0x0003), "161100")
    }

    /// Explicit VR little-endian is what dcm4chee negotiates in practice, and the
    /// SPS date/time must come back from inside the (0040,0100) sequence.
    func testParse_explicitVRSequenceAttributes() {
        func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func le32(_ v: UInt32) -> Data {
            Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                  UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
        }
        func elem(_ g: UInt16, _ e: UInt16, _ vr: String, _ value: String) -> Data {
            var v = value.data(using: .ascii)!
            if v.count % 2 != 0 { v.append(0x20) }
            var d = Data()
            d.append(le16(g)); d.append(le16(e))
            d.append(vr.data(using: .ascii)!)
            d.append(le16(UInt16(v.count)))
            d.append(v)
            return d
        }

        var sps = Data()
        sps.append(elem(0x0008, 0x0060, "CS", "CT"))
        sps.append(elem(0x0040, 0x0002, "DA", "20211210"))
        sps.append(elem(0x0040, 0x0003, "TM", "161100"))

        var data = Data()
        data.append(elem(0x0010, 0x0010, "PN", "AMUDHA.N"))
        data.append(le16(0x0040)); data.append(le16(0x0100))
        data.append("SQ".data(using: .ascii)!)
        data.append(Data([0x00, 0x00]))
        data.append(le32(0xFFFFFFFF))
        data.append(Data([0xFE, 0xFF, 0x00, 0xE0]))
        data.append(le32(0xFFFFFFFF))
        data.append(sps)
        data.append(Data([0xFE, 0xFF, 0x0D, 0xE0]))
        data.append(le32(0))
        data.append(Data([0xFE, 0xFF, 0xDD, 0xE0]))
        data.append(le32(0))

        var offset = 0
        var attrs: [Tag: Data] = [:]
        DICOMModalityWorklistService.parseMWLDataSet(
            data: data, offset: &offset, end: data.count,
            isExplicitVR: true, into: &attrs)

        XCTAssertEqual(string(attrs, 0x0010, 0x0010), "AMUDHA.N")
        XCTAssertEqual(string(attrs, 0x0008, 0x0060), "CT")
        XCTAssertEqual(string(attrs, 0x0040, 0x0002), "20211210")
        XCTAssertEqual(string(attrs, 0x0040, 0x0003), "161100")
    }

    /// Guards against indexing a Data slice (startIndex != 0), which traps.
    func testParse_sliceWithNonZeroStartIndex() {
        let padded = Data(repeating: 0xAB, count: 64) + buildResponse()
        let slice = padded.dropFirst(64)   // startIndex == 64
        XCTAssertNotEqual(slice.startIndex, 0, "precondition: slice must be offset")

        let attrs = parse(slice)
        XCTAssertEqual(string(attrs, 0x0010, 0x0010), "AMUDHA.N")
        XCTAssertEqual(string(attrs, 0x0040, 0x0002), "20211210")
        XCTAssertEqual(string(attrs, 0x0040, 0x0003), "161100")
    }
}
