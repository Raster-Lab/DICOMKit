// PresentationLUTTableTests.swift
// DICOMNetworkTests
//
// The custom Presentation LUT (PS3.3 C.11.4): validation of what may be sent,
// and the exact Presentation LUT Sequence (2050,0010) element it becomes.

import XCTest
import DICOMCore
@testable import DICOMNetwork

final class PresentationLUTTableTests: XCTestCase {

    // MARK: Validation

    func testRejectsWhatTheStandardDoesNotAllow() {
        XCTAssertNil(PresentationLUTTable(entries: []), "no entries")
        XCTAssertNil(PresentationLUTTable(entries: [0], bitsPerEntry: 7), "too shallow")
        XCTAssertNil(PresentationLUTTable(entries: [0], bitsPerEntry: 17), "too deep")
        XCTAssertNil(PresentationLUTTable(entries: [4096], bitsPerEntry: 12),
                     "entry does not fit its declared depth")
        XCTAssertNotNil(PresentationLUTTable(entries: [0, 2048, 4095], bitsPerEntry: 12))
    }

    // MARK: The element

    func testSequenceElementCarriesDescriptorAndData() throws {
        let table = try XCTUnwrap(
            PresentationLUTTable(entries: [0, 100, 4095], bitsPerEntry: 12))
        let element = table.sequenceElement()

        XCTAssertEqual(element.tag, Tag(group: 0x2050, element: 0x0010))
        XCTAssertEqual(element.vr, .SQ)
        let item = try XCTUnwrap(element.sequenceItems?.first)

        let descriptor = try XCTUnwrap(
            item.allElements.first { $0.tag == Tag(group: 0x0028, element: 0x3002) })
        // Three US values, little endian: entries, first mapped (always 0), bits.
        XCTAssertEqual([UInt8](descriptor.valueData), [3, 0, 0, 0, 12, 0])

        let data = try XCTUnwrap(
            item.allElements.first { $0.tag == Tag(group: 0x0028, element: 0x3006) })
        XCTAssertEqual(data.vr, .OW)
        XCTAssertEqual([UInt8](data.valueData), [0, 0, 100, 0, 0xFF, 0x0F])
    }

    func testFullDepthTableDescribesItselfAsZeroEntries() throws {
        // 2^16 entries cannot be said in a US, so the descriptor says 0 —
        // DICOM's one deliberate wrap (PS3.3 C.11.4).
        let table = try XCTUnwrap(PresentationLUTTable(
            entries: [UInt16](repeating: 0, count: 65536), bitsPerEntry: 16))
        let descriptor = try XCTUnwrap(
            table.sequenceElement().sequenceItems?.first?.allElements
                .first { $0.tag == Tag(group: 0x0028, element: 0x3002) })
        XCTAssertEqual([UInt8](descriptor.valueData.prefix(2)), [0, 0])
    }
}
