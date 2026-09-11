//
// H264ParserTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit

/// SPS parsing against hand-built bit-exact vectors.
///
/// Each vector is assembled from the syntax in ITU-T H.264 Section 7.3.2.1.1, so
/// the expected values are derivable from the specification rather than from
/// whatever a particular encoder happened to emit. The 1080p vectors carry real
/// emulation prevention bytes, so they also exercise the RBSP stripper.
///
/// Reference: ITU-T H.264 Section 7.3.2.1.1
final class H264ParserTests: XCTestCase {

    // MARK: - Vectors

    /// High Profile, Level 4.1, 1920x1080 at 30 fps.
    ///
    /// The coded height is 1088 (68 macroblock rows); frame cropping removes the
    /// last 8 luma rows. A parser that ignores cropping reports 1088.
    private static let sps1080pHigh41: [UInt8] = [
        0x67, 0x64, 0x00, 0x29, 0xAC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x2C, 0x20,
        0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x07, 0x98,
    ]

    /// High Profile, Level 3.1, 1280x720 at 25 fps. No cropping: 720 is 45 whole
    /// macroblock rows.
    private static let sps720pHigh31: [UInt8] = [
        0x67, 0x64, 0x00, 0x1F, 0xAC, 0xB4, 0x02, 0x80, 0x2D, 0xD0, 0x80, 0x00,
        0x00, 0x03, 0x00, 0x80, 0x00, 0x00, 0x19, 0x60,
    ]

    /// Baseline Profile, Level 3.0, 640x480. Baseline omits the chroma/bit-depth
    /// block entirely, so this vector checks that branch is skipped correctly.
    private static let spsBaseline640x480: [UInt8] = [
        0x67, 0x42, 0x00, 0x1E, 0xDA, 0x02, 0x80, 0xF6, 0x40,
    ]

    /// High 4:2:2 Profile, 1920x1080. Not DICOM-legal, but must parse so the
    /// rejection can name the observed chroma format.
    private static let spsHigh422: [UInt8] = [
        0x67, 0x7A, 0x00, 0x29, 0xBC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x12, 0x80,
    ]

    /// High Profile, Level 4.2, 1920x1080 at 60 fps — the case Level 4.1 cannot
    /// represent, and the reason transfer syntax .104 matters.
    private static let sps1080pHigh42: [UInt8] = [
        0x67, 0x64, 0x00, 0x2A, 0xAC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x2C, 0x20,
        0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x0F, 0x18,
    ]

    /// High Profile, 1440x1080 with a 4:3 sample aspect ratio — anamorphic video,
    /// which DICOM cannot represent because Pixel Aspect Ratio must be absent.
    private static let spsAnamorphic: [UInt8] = [
        0x67, 0x64, 0x00, 0x28, 0xAC, 0xB4, 0x02, 0xD0, 0x11, 0x3F, 0x2F, 0xFE,
        0x00, 0x08, 0x00, 0x06, 0x10,
    ]

    /// High 10 Profile, 1920x1080, 10-bit.
    private static let spsHigh10: [UInt8] = [
        0x67, 0x6E, 0x00, 0x28, 0xA6, 0xCB, 0x40, 0x3C, 0x01, 0x13, 0xF2, 0xA0,
    ]

    // MARK: - The cropping trap

    func test_sps1080p_reports1080Not1088() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh41)))

        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080,
                       "frame cropping must be subtracted; 1088 means the crop offsets were skipped")
    }

    func test_sps720p_noCroppingNeeded() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps720pHigh31)))
        XCTAssertEqual(sps.width, 1280)
        XCTAssertEqual(sps.height, 720)
    }

    // MARK: - Profile and level

    func test_sps1080p_profileAndLevel() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh41)))
        XCTAssertEqual(sps.profileIDC, 100, "High Profile")
        XCTAssertEqual(sps.levelIDC, 41, "Level 4.1 is coded as 41")
        XCTAssertEqual(sps.chromaFormatIDC, 1, "4:2:0")
        XCTAssertEqual(sps.bitDepthLuma, 8)
        XCTAssertEqual(sps.bitDepthChroma, 8)
        XCTAssertTrue(sps.frameMBSOnly, "progressive")
    }

    func test_spsLevel42_isDistinguishedFrom41() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh42)))
        XCTAssertEqual(sps.levelIDC, 42)
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    func test_spsBaseline_parsesWithoutChromaBlock() throws {
        // profile_idc 66 has no chroma/bit-depth block. Reading one anyway would
        // desynchronize the dimensions.
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsBaseline640x480)))
        XCTAssertEqual(sps.profileIDC, 66, "Baseline")
        XCTAssertEqual(sps.levelIDC, 30)
        XCTAssertEqual(sps.width, 640)
        XCTAssertEqual(sps.height, 480)
        XCTAssertEqual(sps.chromaFormatIDC, 1, "4:2:0 is inferred when not coded")
        XCTAssertEqual(sps.bitDepthLuma, 8)
    }

    func test_spsHigh422_reportsChromaFormatTwo() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsHigh422)))
        XCTAssertEqual(sps.profileIDC, 122)
        XCTAssertEqual(sps.chromaFormatIDC, 2, "4:2:2")
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080,
                       "4:2:2 crop units differ from 4:2:0; the height must still be 1080")
    }

    func test_spsHigh10_reportsTenBitDepth() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsHigh10)))
        XCTAssertEqual(sps.profileIDC, 110, "High 10")
        XCTAssertEqual(sps.bitDepthLuma, 10)
        XCTAssertEqual(sps.bitDepthChroma, 10)
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    // MARK: - VUI

    func test_sps1080p_frameRateFromVUI() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh41)))
        let frameRate = try XCTUnwrap(sps.frameRate, "the vector carries VUI timing")
        XCTAssertEqual(frameRate, 30.0, accuracy: 0.001,
                       "time_scale / (2 * num_units_in_tick)")
    }

    func test_sps720p_frameRateFromVUI() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps720pHigh31)))
        XCTAssertEqual(try XCTUnwrap(sps.frameRate), 25.0, accuracy: 0.001)
    }

    func test_spsLevel42_sixtyFramesPerSecond() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh42)))
        XCTAssertEqual(try XCTUnwrap(sps.frameRate), 60.0, accuracy: 0.001)
    }

    func test_spsWithoutVUI_hasNoFrameRate() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsBaseline640x480)))
        XCTAssertNil(sps.frameRate, "no VUI means no declared frame rate")
    }

    func test_spsAnamorphic_reportsNonSquareSampleAspectRatio() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsAnamorphic)))
        let sar = try XCTUnwrap(sps.sampleAspectRatio)
        XCTAssertEqual(sar.width, 4)
        XCTAssertEqual(sar.height, 3)
        XCTAssertFalse(sps.streamInfo.hasSquarePixels,
                       "4:3 SAR is anamorphic and cannot be represented in DICOM")
    }

    func test_squarePixels_whenNoAspectRatioDeclared() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh41)))
        XCTAssertNil(sps.sampleAspectRatio)
        XCTAssertTrue(sps.streamInfo.hasSquarePixels,
                      "an undeclared SAR is read as 1:1")
    }

    // MARK: - Stream info projection

    func test_streamInfo_carriesParsedValues() throws {
        let sps = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.sps1080pHigh41)))
        let info = sps.streamInfo

        XCTAssertEqual(info.codec, .h264)
        XCTAssertEqual(info.width, 1920)
        XCTAssertEqual(info.height, 1080)
        XCTAssertEqual(info.profileIDC, 100)
        XCTAssertEqual(info.levelTimesTen, 41)
        XCTAssertEqual(info.level, 4.1, accuracy: 0.001)
        XCTAssertEqual(info.levelDescription, "4.1")
        XCTAssertEqual(info.chromaFormat, .yuv420)
        XCTAssertEqual(info.bitDepthLuma, 8)
        XCTAssertEqual(info.profileName, "High")
        XCTAssertTrue(info.isProgressive)
    }

    func test_profileName_namesCommonProfiles() throws {
        let baseline = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsBaseline640x480)))
        XCTAssertEqual(baseline.streamInfo.profileName, "Baseline",
                       "rejections must name the profile, not just its number")

        let high422 = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsHigh422)))
        XCTAssertEqual(high422.streamInfo.profileName, "High 4:2:2")

        let high10 = try XCTUnwrap(H264Parser.parseSPS(nalUnit: Data(Self.spsHigh10)))
        XCTAssertEqual(high10.streamInfo.profileName, "High 10")
    }

    // MARK: - Annex B handling

    func test_parseFirstSPS_findsSPSAmongOtherNALUnits() throws {
        var stream = Data([0x00, 0x00, 0x00, 0x01, 0x09, 0x10])  // access unit delimiter
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: Self.sps1080pHigh41)
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x68, 0xEE, 0x3C, 0x80])  // PPS

        let sps = try XCTUnwrap(H264Parser.parseFirstSPS(annexB: stream))
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    func test_parseFirstSPS_returnsNilWhenAbsent() {
        let stream = Data([0x00, 0x00, 0x00, 0x01, 0x68, 0xEE, 0x3C, 0x80])
        XCTAssertNil(H264Parser.parseFirstSPS(annexB: stream))
    }

    // MARK: - Malformed input

    func test_parseSPS_rejectsWrongNALType() {
        // A PPS (type 8) is not an SPS.
        XCTAssertNil(H264Parser.parseSPS(nalUnit: Data([0x68, 0xEE, 0x3C, 0x80])))
    }

    func test_parseSPS_rejectsForbiddenZeroBitSet() {
        var corrupt = Self.sps1080pHigh41
        corrupt[0] |= 0x80
        XCTAssertNil(H264Parser.parseSPS(nalUnit: Data(corrupt)))
    }

    func test_parseSPS_rejectsEmptyAndTruncated() {
        XCTAssertNil(H264Parser.parseSPS(nalUnit: Data()))
        XCTAssertNil(H264Parser.parseSPS(nalUnit: Data([0x67])))
        XCTAssertNil(H264Parser.parseSPS(nalUnit: Data([0x67, 0x64, 0x00])))
    }

    func test_parseSPS_truncatedMidStream_doesNotCrash() {
        // Every prefix of a valid SPS must either parse or fail cleanly.
        for length in 1..<Self.sps1080pHigh41.count {
            let truncated = Data(Self.sps1080pHigh41.prefix(length))
            _ = H264Parser.parseSPS(nalUnit: truncated)
        }
    }

    func test_parseSPS_randomBytesDoNotCrash() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            var bytes: [UInt8] = [0x67]
            for _ in 0..<32 {
                bytes.append(UInt8.random(in: 0...255, using: &generator))
            }
            _ = H264Parser.parseSPS(nalUnit: Data(bytes))
        }
    }

    // MARK: - Frame counting

    func test_countFrames_countsFirstSliceOfEachPicture() {
        // Three pictures, the middle one split across two slices. Only slices with
        // first_mb_in_slice == 0 start a new picture.
        //
        // first_mb_in_slice is ue(v): 0 encodes as the single bit 1 (0x80 with the
        // remaining bits as slice payload), while a non-zero value does not begin
        // with a set bit.
        var stream = Data()
        // IDR slice, first_mb_in_slice = 0
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00])
        // non-IDR slice, first_mb_in_slice = 0
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x41, 0x9A, 0x00, 0x00])
        // non-IDR slice, first_mb_in_slice = 1 (continuation: ue(v) "010")
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x41, 0x42, 0x00, 0x00])
        // non-IDR slice, first_mb_in_slice = 0
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x41, 0x9A, 0x00, 0x00])

        XCTAssertEqual(H264Parser.countFrames(annexB: stream), 3,
                       "a continuation slice must not count as a new picture")
    }

    func test_countFrames_ignoresNonVCLUnits() {
        var stream = Data()
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: Self.sps1080pHigh41)                    // SPS
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x68, 0xEE])   // PPS
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00])  // IDR

        XCTAssertEqual(H264Parser.countFrames(annexB: stream), 1,
                       "parameter sets are not coded pictures")
    }

    func test_countFrames_emptyStreamIsZero() {
        XCTAssertEqual(H264Parser.countFrames(annexB: Data()), 0)
    }
}
