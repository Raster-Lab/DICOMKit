import XCTest
@testable import DICOMCore

/// Covers the Part-2 multi-component transform decode guard.
///
/// The pinned J2KSwift decoder skips MCT/MCC/MCO marker segments instead of
/// inverting them, so DICOMKit must detect them itself and refuse the frame rather
/// than hand back silently-wrong pixels.
final class J2KCodestreamInspectorTests: XCTestCase {

    // MARK: - Codestream builders

    private static func be16(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xFF)] }
    private static func be32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    /// A marker segment: marker code + 2-byte length (counting itself) + payload.
    private static func segment(_ marker: UInt16, payload: [UInt8]) -> [UInt8] {
        be16(marker) + be16(UInt16(payload.count + 2)) + payload
    }

    /// SIZ is never inspected for content here — only its length must be walkable.
    private static var siz: [UInt8] { segment(0xFF51, payload: [UInt8](repeating: 0x00, count: 36)) }
    private static var cod: [UInt8] { segment(0xFF52, payload: [UInt8](repeating: 0x00, count: 10)) }
    private static var qcd: [UInt8] { segment(0xFF5C, payload: [UInt8](repeating: 0x00, count: 4)) }

    /// SOC + main header + optional extra segments, then a tile-part running to EOC.
    private static func codestream(mainHeaderExtras: [UInt8] = [], tileHeaderExtras: [UInt8] = []) -> Data {
        var bytes: [UInt8] = be16(0xFF4F)          // SOC
        bytes += siz + cod + qcd
        bytes += mainHeaderExtras
        // SOT: Lsot=10, Isot=0, Psot=0 (runs to EOC), TPsot=0, TNsot=1
        bytes += be16(0xFF90) + be16(10) + be16(0) + be32(0) + [0x00, 0x01]
        bytes += tileHeaderExtras
        bytes += be16(0xFF93)                      // SOD
        bytes += [0xDE, 0xAD, 0xBE, 0xEF]          // packet body
        bytes += be16(0xFFD9)                      // EOC
        return Data(bytes)
    }

    private static var mctSegment: [UInt8] { segment(0xFF74, payload: [0x00, 0x00, 0x00, 0x01]) }
    private static var mccSegment: [UInt8] { segment(0xFF75, payload: [0x00, 0x00, 0x03]) }
    private static var mcoSegment: [UInt8] { segment(0xFF77, payload: [0x00, 0x01]) }

    // MARK: - Negative cases: clean codestreams must still decode

    func test_plainPart1Codestream_hasNoPart2Markers() {
        let data = Self.codestream()
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: data), [])
        XCTAssertFalse(J2KCodestreamInspector.containsPart2MultiComponentTransform(in: data))
        XCTAssertNil(J2KRoutePlanner.unsupportedDecodeReason(frameData: data))
    }

    /// The Part-1-compatible codestreams DICOMKit writes under a `.92`/`.93` UID carry
    /// no MCT markers and must keep opening — the guard is codestream-level, not
    /// UID-level.
    func test_part2UIDWithoutMCTMarkers_isNotRejected() {
        XCTAssertNil(J2KRoutePlanner.unsupportedDecodeReason(frameData: Self.codestream()))
    }

    /// A marker whose code merely sits near the Part-2 range must not trip the guard.
    func test_unrelatedMarker_isNotMistakenForMCT() {
        // 0xFF76 is NLT in ISO/IEC 15444-2 — deliberately not in our reject set, and
        // notably the code J2KSwift's own enum mislabels as `mco`.
        let data = Self.codestream(mainHeaderExtras: Self.segment(0xFF76, payload: [0x00, 0x01]))
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: data), [])
    }

    func test_emptyAndGarbageData_areNotRejected() {
        XCTAssertNil(J2KRoutePlanner.unsupportedDecodeReason(frameData: Data()))
        XCTAssertNil(J2KRoutePlanner.unsupportedDecodeReason(frameData: Data([0x00, 0x01, 0x02, 0x03])))
        // Truncated mid-header: scanning must stop cleanly, not trap.
        let truncated = Self.codestream().prefix(9)
        XCTAssertNil(J2KRoutePlanner.unsupportedDecodeReason(frameData: Data(truncated)))
    }

    // MARK: - Positive cases: real Part-2 MCT must be refused

    func test_mctInMainHeader_isDetected() {
        let data = Self.codestream(mainHeaderExtras: Self.mctSegment)
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: data), [.mct])
        XCTAssertTrue(J2KCodestreamInspector.containsPart2MultiComponentTransform(in: data))
    }

    func test_allThreeMarkers_areReportedInOrder() {
        let data = Self.codestream(mainHeaderExtras: Self.mctSegment + Self.mccSegment + Self.mcoSegment)
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: data), [.mct, .mcc, .mco])
        let reason = J2KRoutePlanner.unsupportedDecodeReason(frameData: data)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("MCT, MCC, MCO"), "reason should name every marker found: \(reason!)")
    }

    /// MCT/MCC/MCO are legal in a tile-part header too, not just the main header.
    func test_mctInTilePartHeader_isDetected() {
        let data = Self.codestream(tileHeaderExtras: Self.mccSegment)
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: data), [.mcc])
    }

    func test_rejectionReason_isActionable() {
        let reason = J2KRoutePlanner.unsupportedDecodeReason(frameData: Self.codestream(mainHeaderExtras: Self.mctSegment))
        XCTAssertNotNil(reason)
        // The message must explain the risk and name a way forward.
        XCTAssertTrue(reason!.contains("incorrect pixel"))
        XCTAssertTrue(reason!.contains("Part 1") || reason!.contains("HTJ2K"))
    }

    // MARK: - Marker codes

    /// Regression guard: J2KSwift's `J2KMarker` enum assigns MCT/MCC/MCO to
    /// 0xFF75/0xFF77/0xFF76, which contradicts ISO/IEC 15444-2 and the OpenJPEG
    /// reference (`J2K_MS_MCT 0xff74`, `J2K_MS_MCC 0xff75`, `J2K_MS_MCO 0xff77`).
    /// We must follow the standard so third-party codestreams are recognised.
    func test_markerCodes_matchTheStandardNotJ2KSwift() {
        XCTAssertEqual(J2KCodestreamInspector.Part2MultiComponentMarker.mct.rawValue, 0xFF74)
        XCTAssertEqual(J2KCodestreamInspector.Part2MultiComponentMarker.mcc.rawValue, 0xFF75)
        XCTAssertEqual(J2KCodestreamInspector.Part2MultiComponentMarker.mco.rawValue, 0xFF77)
    }

    // MARK: - JP2 container

    func test_jp2WrappedCodestream_isUnwrappedAndScanned() {
        let inner = [UInt8](Self.codestream(mainHeaderExtras: Self.mctSegment))
        var bytes: [UInt8] = []
        // JP2 signature box.
        bytes += Self.be32(12) + Self.be32(0x6A50_2020) + [0x0D, 0x0A, 0x87, 0x0A]
        // jp2c box carrying the codestream.
        bytes += Self.be32(UInt32(inner.count + 8)) + Self.be32(0x6A70_3263) + inner
        XCTAssertEqual(J2KCodestreamInspector.part2MultiComponentMarkers(in: Data(bytes)), [.mct])
    }

    // MARK: - Codec integration

    func test_decodeFrame_refusesPart2MCT() throws {
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb
        )
        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.jpeg2000Part2.uid)
        let data = Self.codestream(mainHeaderExtras: Self.mctSegment)

        XCTAssertThrowsError(try codec.decodeFrame(data, descriptor: descriptor, frameIndex: 0)) { error in
            guard case DICOMError.unsupportedTransferSyntax(let reason) = error else {
                return XCTFail("expected unsupportedTransferSyntax, got \(error)")
            }
            XCTAssertTrue(reason.contains("multi-component transform"))
        }
    }

    func test_decodeFrameAtResolution_refusesPart2MCTBeforePreview() async {
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb
        )
        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.jpeg2000Part2.uid)
        let data = Self.codestream(mainHeaderExtras: Self.mctSegment)

        do {
            _ = try await codec.decodeFrameAtResolution(data, descriptor: descriptor, level: 1)
            XCTFail("expected reduced-resolution decode to reject Part-2 MCT")
        } catch DICOMError.unsupportedTransferSyntax(let reason) {
            XCTAssertTrue(reason.contains("multi-component transform"))
        } catch {
            XCTFail("expected unsupportedTransferSyntax, got \(error)")
        }
    }
}
