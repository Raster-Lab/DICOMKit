//
// HEVCParserTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit

/// HEVC SPS parsing against hand-built bit-exact vectors.
///
/// Reference: ITU-T H.265 Sections 7.3.2.2.1, 7.3.3, E.2.1
final class HEVCParserTests: XCTestCase {

    // MARK: - Vectors

    /// Main Profile, Level 4.0, 1920x1080 at 30 fps.
    private static let spsMain1080p: [UInt8] = [
        0x42, 0x01, 0x01, 0x01, 0x40, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x78, 0xA0, 0x03, 0xC0, 0x80, 0x10, 0xE5,
        0x96, 0xB9, 0x24, 0xCA, 0xE0, 0x10, 0x00, 0x00, 0x03, 0x00, 0x10, 0x00,
        0x00, 0x03, 0x01, 0xE1,
    ]

    /// Main 10 Profile, Level 4.1, 1920x1080 at 25 fps, 10-bit.
    private static let spsMain10_1080p: [UInt8] = [
        0x42, 0x01, 0x01, 0x02, 0x20, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x7B, 0xA0, 0x03, 0xC0, 0x80, 0x10, 0xE4,
        0xD9, 0x6B, 0x92, 0x4C, 0xAE, 0x01, 0x00, 0x00, 0x03, 0x00, 0x01, 0x00,
        0x00, 0x03, 0x00, 0x19, 0x10,
    ]

    /// Main Profile, Level 5.1, 3840x2160 at 30 fps — the level ceiling of the
    /// HEVC DICOM transfer syntaxes.
    private static let spsMain4K: [UInt8] = [
        0x42, 0x01, 0x01, 0x01, 0x40, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x99, 0xA0, 0x01, 0xE0, 0x20, 0x02, 0x1C,
        0x59, 0x6B, 0x92, 0x4C, 0xAE, 0x01, 0x00, 0x00, 0x03, 0x00, 0x01, 0x00,
        0x00, 0x03, 0x00, 0x1E, 0x10,
    ]

    /// Main Profile, Level 3.1, 1280x720, no VUI timing.
    private static let spsMain720pNoVUI: [UInt8] = [
        0x42, 0x01, 0x01, 0x01, 0x40, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x5D, 0xA0, 0x02, 0x80, 0x80, 0x2D, 0x16,
        0x5A, 0xE4, 0x93, 0x2B, 0x20,
    ]

    /// Main 10, 1440x1080 with a 4:3 sample aspect ratio — anamorphic.
    private static let spsMain10Anamorphic: [UInt8] = [
        0x42, 0x01, 0x01, 0x02, 0x20, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x78, 0xA0, 0x02, 0xD0, 0x80, 0x10, 0xE4,
        0xD9, 0x6B, 0x92, 0x4C, 0xAF, 0xFF, 0x00, 0x04, 0x00, 0x03, 0x00, 0x40,
    ]

    /// Format Range Extensions profile with 4:4:4 chroma — not DICOM-legal, but
    /// must parse so the rejection can name the chroma format.
    private static let spsMain444: [UInt8] = [
        0x42, 0x01, 0x01, 0x04, 0x08, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x78, 0x90, 0x00, 0x78, 0x10, 0x02, 0x1C,
        0xB2, 0xD7, 0x24, 0x99, 0x59,
    ]

    // MARK: - Geometry

    func test_spsMain1080p_dimensions() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    func test_spsMain4K_dimensions() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain4K)))
        XCTAssertEqual(sps.width, 3840)
        XCTAssertEqual(sps.height, 2160)
    }

    func test_spsMain720p_dimensions() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain720pNoVUI)))
        XCTAssertEqual(sps.width, 1280)
        XCTAssertEqual(sps.height, 720)
    }

    // MARK: - Profile, tier and level

    func test_spsMain1080p_profileAndLevel() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        XCTAssertEqual(sps.profileIDC, 1, "Main Profile")
        XCTAssertEqual(sps.levelTimesTen, 40,
                       "general_level_idc 120 is level 4.0 (level times 30)")
        XCTAssertFalse(sps.isHighTier, "Main tier")
        XCTAssertEqual(sps.chromaFormatIDC, 1, "4:2:0")
        XCTAssertEqual(sps.bitDepthLuma, 8)
    }

    func test_spsMain4K_levelFiveOne() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain4K)))
        XCTAssertEqual(sps.levelTimesTen, 51,
                       "general_level_idc 153 is level 5.1")
        XCTAssertEqual(sps.streamInfo.levelDescription, "5.1")
    }

    func test_spsMain720p_levelThreeOne() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain720pNoVUI)))
        XCTAssertEqual(sps.levelTimesTen, 31, "general_level_idc 93 is level 3.1")
    }

    // MARK: - Bit depth: the Main 10 selector

    func test_spsMain10_reportsTenBitLumaDepth() throws {
        // bit_depth_luma_minus8 of 2 is what selects transfer syntax .108 over .107.
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10_1080p)))
        XCTAssertEqual(sps.profileIDC, 2, "Main 10 Profile")
        XCTAssertEqual(sps.bitDepthLuma, 10)
        XCTAssertEqual(sps.bitDepthChroma, 10)
        XCTAssertEqual(sps.levelTimesTen, 41)
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    func test_spsMain_reportsEightBitLumaDepth() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        XCTAssertEqual(sps.bitDepthLuma, 8)
    }

    func test_main10BitDepth_mapsToDICOMTriple() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10_1080p)))
        let depth = try XCTUnwrap(VideoBitDepth.forLumaBitDepth(sps.bitDepthLuma))
        XCTAssertEqual(depth, .tenBit)
        XCTAssertEqual(depth.bitsAllocated, 16, "DICOM allocates on byte boundaries")
        XCTAssertEqual(depth.bitsStored, 10)
        XCTAssertEqual(depth.highBit, 9)
    }

    // MARK: - Chroma format

    func test_sps444_reportsChromaFormatThree() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain444)))
        XCTAssertEqual(sps.chromaFormatIDC, 3, "4:4:4")
        XCTAssertEqual(sps.streamInfo.chromaFormat, .yuv444)
        XCTAssertEqual(sps.streamInfo.chromaFormat.displayName, "4:4:4")
    }

    // MARK: - VUI

    func test_spsMain1080p_frameRateFromVUI() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        let frameRate = try XCTUnwrap(sps.frameRate)
        // HEVC time_scale counts frame ticks directly, unlike H.264's field ticks.
        XCTAssertEqual(frameRate, 30.0, accuracy: 0.001)
    }

    func test_spsMain10_frameRateFromVUI() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10_1080p)))
        XCTAssertEqual(try XCTUnwrap(sps.frameRate), 25.0, accuracy: 0.001)
    }

    func test_spsWithoutVUI_hasNoFrameRate() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain720pNoVUI)))
        XCTAssertNil(sps.frameRate)
    }

    func test_spsAnamorphic_reportsNonSquareSampleAspectRatio() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10Anamorphic)))
        let sar = try XCTUnwrap(sps.sampleAspectRatio)
        XCTAssertEqual(sar.width, 4)
        XCTAssertEqual(sar.height, 3)
        XCTAssertFalse(sps.streamInfo.hasSquarePixels)
    }

    func test_squarePixels_whenNoAspectRatioDeclared() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        XCTAssertTrue(sps.streamInfo.hasSquarePixels)
    }

    // MARK: - Stream info projection

    func test_streamInfo_carriesParsedValues() throws {
        let sps = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10_1080p)))
        let info = sps.streamInfo

        XCTAssertEqual(info.codec, .h265)
        XCTAssertEqual(info.width, 1920)
        XCTAssertEqual(info.height, 1080)
        XCTAssertEqual(info.profileIDC, 2)
        XCTAssertEqual(info.profileName, "Main 10")
        XCTAssertEqual(info.levelTimesTen, 41)
        XCTAssertEqual(info.bitDepthLuma, 10)
        XCTAssertEqual(info.chromaFormat, .yuv420)
    }

    func test_profileName_namesHEVCProfiles() throws {
        let main = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p)))
        XCTAssertEqual(main.streamInfo.profileName, "Main")

        let main10 = try XCTUnwrap(HEVCParser.parseSPS(nalUnit: Data(Self.spsMain10_1080p)))
        XCTAssertEqual(main10.streamInfo.profileName, "Main 10")
    }

    // MARK: - Annex B handling

    func test_parseFirstSPS_findsSPSAmongOtherNALUnits() throws {
        // A VPS (type 32) precedes the SPS in a real stream.
        var stream = Data([0x00, 0x00, 0x00, 0x01, 0x40, 0x01, 0x0C, 0x01])
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: Self.spsMain1080p)
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x44, 0x01, 0xC0])  // PPS

        let sps = try XCTUnwrap(HEVCParser.parseFirstSPS(annexB: stream))
        XCTAssertEqual(sps.width, 1920)
        XCTAssertEqual(sps.height, 1080)
    }

    func test_parseFirstSPS_returnsNilWhenAbsent() {
        let stream = Data([0x00, 0x00, 0x00, 0x01, 0x40, 0x01, 0x0C, 0x01])
        XCTAssertNil(HEVCParser.parseFirstSPS(annexB: stream))
    }

    // MARK: - Malformed input

    func test_parseSPS_rejectsWrongNALType() {
        // A VPS (type 32) is not an SPS.
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data([0x40, 0x01, 0x0C, 0x01])))
        // A PPS (type 34).
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data([0x44, 0x01, 0xC0, 0x00])))
    }

    func test_parseSPS_rejectsForbiddenZeroBitSet() {
        var corrupt = Self.spsMain1080p
        corrupt[0] |= 0x80
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data(corrupt)))
    }

    func test_parseSPS_rejectsEmptyAndTruncated() {
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data()))
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data([0x42])))
        XCTAssertNil(HEVCParser.parseSPS(nalUnit: Data([0x42, 0x01, 0x01])))
    }

    func test_parseSPS_truncatedMidStream_doesNotCrash() {
        for length in 1..<Self.spsMain1080p.count {
            _ = HEVCParser.parseSPS(nalUnit: Data(Self.spsMain1080p.prefix(length)))
        }
    }

    func test_parseSPS_randomBytesDoNotCrash() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            var bytes: [UInt8] = [0x42, 0x01]
            for _ in 0..<40 {
                bytes.append(UInt8.random(in: 0...255, using: &generator))
            }
            _ = HEVCParser.parseSPS(nalUnit: Data(bytes))
        }
    }

    // MARK: - Frame counting

    func test_countFrames_countsFirstSliceSegments() {
        // first_slice_segment_in_pic_flag is the first bit of the slice header,
        // so 0x80 starts a picture and 0x00 continues one.
        var stream = Data()
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x26, 0x01, 0xAF, 0x00])  // IDR, first
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x02, 0x01, 0xD0, 0x00])  // TRAIL, first
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x02, 0x01, 0x40, 0x00])  // TRAIL, continuation
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x02, 0x01, 0xD0, 0x00])  // TRAIL, first

        XCTAssertEqual(HEVCParser.countFrames(annexB: stream), 3)
    }

    func test_countFrames_ignoresParameterSets() {
        var stream = Data()
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x40, 0x01, 0x0C, 0x01])  // VPS
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: Self.spsMain1080p)                                  // SPS
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x26, 0x01, 0xAF, 0x00])  // IDR

        XCTAssertEqual(HEVCParser.countFrames(annexB: stream), 1,
                       "VPS/SPS are not coded pictures")
    }

    func test_countFrames_emptyStreamIsZero() {
        XCTAssertEqual(HEVCParser.countFrames(annexB: Data()), 0)
    }
}
