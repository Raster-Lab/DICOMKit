import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// PS3.3 C.11.1: when a Modality LUT Sequence (0028,3000) is present it defines the
/// modality transformation; Rescale Slope/Intercept must not be applied on top of or
/// instead of it. Before 2026-08-11 no consumer in the main pixel pipeline checked the
/// sequence — every path applied slope/intercept unconditionally, corrupting output for
/// files that carry a LUT (the analogue of fo-dicom #1986; ECOSYSTEM_COMPARISON.md §5).
final class ModalityLUTPrecedenceTests: XCTestCase {

    /// A dataset carrying BOTH a Modality LUT Sequence and (non-conformantly)
    /// Rescale Slope/Intercept — the case where wrong precedence corrupts pixels.
    /// LUT: 4 entries, first mapped stored value = 10, 16-bit entries.
    private func datasetWithLUTAndRescale() -> DataSet {
        var dataSet = DataSet()

        // Bogus linear transform that must be IGNORED once the LUT is present.
        dataSet[.rescaleSlope] = DataElement(
            tag: .rescaleSlope, vr: .DS, length: 2, valueData: Data("10".utf8))
        dataSet[.rescaleIntercept] = DataElement(
            tag: .rescaleIntercept, vr: .DS, length: 6, valueData: Data("-1000 ".utf8))

        // Descriptor [entries=4, firstMapped=10, bits=16] as US.
        var descriptor = Data()
        for v in [UInt16(4), UInt16(10), UInt16(16)] {
            descriptor.append(UInt8(v & 0xFF)); descriptor.append(UInt8(v >> 8))
        }
        // Table [100, 200, 300, 400] as US.
        var table = Data()
        for v in [UInt16(100), UInt16(200), UInt16(300), UInt16(400)] {
            table.append(UInt8(v & 0xFF)); table.append(UInt8(v >> 8))
        }
        let item = SequenceItem(elements: [
            DataElement(tag: .lutDescriptor, vr: .US,
                        length: UInt32(descriptor.count), valueData: descriptor),
            DataElement(tag: .lutData, vr: .OW,
                        length: UInt32(table.count), valueData: table),
        ])
        dataSet.setSequence([item], for: .modalityLUTSequence)
        return dataSet
    }

    // MARK: - Precedence

    func testLUTSequenceSuppressesSlopeAndIntercept() {
        let dataSet = datasetWithLUTAndRescale()
        XCTAssertNotNil(dataSet.modalityLUT(), "test precondition: LUT must parse")
        XCTAssertEqual(dataSet.rescaleSlope(), 1.0,
                       "slope must be identity when a Modality LUT Sequence is present")
        XCTAssertEqual(dataSet.rescaleIntercept(), 0.0,
                       "intercept must be identity when a Modality LUT Sequence is present")
    }

    func testRescaleMapsThroughLUTNotLinear() {
        let dataSet = datasetWithLUTAndRescale()
        // Stored 11 → index 1 → 200. The bogus linear transform would give 10*11-1000 = -890.
        XCTAssertEqual(dataSet.rescale(11), 200.0)
        XCTAssertEqual(dataSet.rescale(10), 100.0, "first mapped value → first entry")
        XCTAssertEqual(dataSet.rescale(13), 400.0, "last mapped value → last entry")
    }

    func testLUTClampsBelowAndAboveRange() {
        let dataSet = datasetWithLUTAndRescale()
        // PS3.3 C.11.1.1.1: inputs below/above the mapped range clamp to first/last entry.
        XCTAssertEqual(dataSet.rescale(0), 100.0, "below range clamps to first entry")
        XCTAssertEqual(dataSet.rescale(9999), 400.0, "above range clamps to last entry")
    }

    // MARK: - No-LUT behaviour unchanged

    func testLinearRescaleUnchangedWithoutLUT() {
        var dataSet = DataSet()
        dataSet[.rescaleSlope] = DataElement(
            tag: .rescaleSlope, vr: .DS, length: 2, valueData: Data("2 ".utf8))
        dataSet[.rescaleIntercept] = DataElement(
            tag: .rescaleIntercept, vr: .DS, length: 6, valueData: Data("-1024".utf8).padded())

        XCTAssertNil(dataSet.modalityLUT())
        XCTAssertEqual(dataSet.rescaleSlope(), 2.0)
        XCTAssertEqual(dataSet.rescaleIntercept(), -1024.0)
        XCTAssertEqual(dataSet.rescale(100), 2.0 * 100 - 1024)
    }

    func testMalformedLUTFallsBackToLinear() {
        var dataSet = datasetWithLUTAndRescale()
        // Break the descriptor (2 values instead of 3): the LUT must be rejected and
        // the linear transform apply again — fail open to the legacy behaviour rather
        // than producing an identity transform from a half-parsed sequence.
        var badDescriptor = Data()
        for v in [UInt16(4), UInt16(10)] {
            badDescriptor.append(UInt8(v & 0xFF)); badDescriptor.append(UInt8(v >> 8))
        }
        let item = SequenceItem(elements: [
            DataElement(tag: .lutDescriptor, vr: .US,
                        length: UInt32(badDescriptor.count), valueData: badDescriptor),
        ])
        dataSet.setSequence([item], for: .modalityLUTSequence)

        XCTAssertNil(dataSet.modalityLUT())
        XCTAssertEqual(dataSet.rescaleSlope(), 10.0)
        XCTAssertEqual(dataSet.rescale(11), 10.0 * 11 - 1000)
    }
}

private extension Data {
    /// Even-pads a DS value the way a writer would.
    func padded() -> Data {
        count % 2 == 0 ? self : self + Data(" ".utf8)
    }
}
