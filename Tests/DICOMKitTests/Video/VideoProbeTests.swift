//
// VideoProbeTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
@testable import DICOMCore

/// End-to-end probing: container detection, parameter-set recovery, frame
/// counting, and the guards that redirect non-video input elsewhere.
final class VideoProbeTests: XCTestCase {

    // MARK: - Fixtures

    /// A 1080p High@4.1 SPS NAL unit, cropped to 1080 and carrying VUI timing.
    private static let spsH264NAL: [UInt8] = [
        0x67, 0x64, 0x00, 0x29, 0xAC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x2C, 0x20,
        0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x07, 0x98,
    ]

    /// A Baseline SPS, which no DICOM transfer syntax accepts.
    private static let spsBaselineNAL: [UInt8] = [
        0x67, 0x42, 0x00, 0x1E, 0xDA, 0x02, 0x80, 0xF6, 0x40,
    ]

    /// An HEVC Main@4.0 SPS NAL unit.
    private static let spsHEVCNAL: [UInt8] = [
        0x42, 0x01, 0x01, 0x01, 0x40, 0x00, 0x00, 0x03, 0x00, 0x80, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x78, 0xA0, 0x03, 0xC0, 0x80, 0x10, 0xE5,
        0x96, 0xB9, 0x24, 0xCA, 0xE0, 0x10, 0x00, 0x00, 0x03, 0x00, 0x10, 0x00,
        0x00, 0x03, 0x01, 0xE1,
    ]

    /// An MPEG-2 MP@ML sequence header, 720x576 at 25 fps.
    private static let mpeg2SequenceHeader: [UInt8] = [
        0x00, 0x00, 0x01, 0xB3, 0x2D, 0x02, 0x40, 0x33, 0x13, 0x88, 0x23, 0x80,
        0x80, 0x00, 0x00, 0x01, 0xB5, 0x14, 0x8A, 0x00, 0x01, 0x00, 0x00, 0x80,
    ]

    /// An Annex B H.264 elementary stream with the given number of coded pictures.
    private func h264ElementaryStream(frames: Int, sps: [UInt8]? = nil) -> Data {
        var stream = Data([0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: sps ?? Self.spsH264NAL)
        stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x68, 0xEE, 0x3C, 0x80])
        for index in 0..<frames {
            // first_mb_in_slice == 0 starts a picture: ue(v) 0 is the bit 1.
            let nalType: UInt8 = index == 0 ? 0x65 : 0x41
            stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, nalType, 0x88, 0x84, 0x00])
        }
        return stream
    }

    private func hevcElementaryStream(frames: Int) -> Data {
        var stream = Data([0x00, 0x00, 0x00, 0x01])
        stream.append(contentsOf: Self.spsHEVCNAL)
        for _ in 0..<frames {
            stream.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x26, 0x01, 0xAF, 0x00])
        }
        return stream
    }

    private func mpeg2ElementaryStream(frames: Int) -> Data {
        var stream = Data(Self.mpeg2SequenceHeader)
        for _ in 0..<frames {
            stream.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x00, 0x0F, 0xFF, 0xF8])
        }
        return stream
    }

    private func transportStream(packets: Int = 8) -> Data {
        var ts = Data()
        for index in 0..<packets {
            ts.append(0x47)
            ts.append(Data(repeating: UInt8(index & 0xFF), count: 187))
        }
        return ts
    }

    // MARK: - Elementary stream probing

    func test_probe_h264ElementaryStream() throws {
        let result = try VideoProbe.probe(h264ElementaryStream(frames: 10))

        XCTAssertEqual(result.container, .elementaryStream)
        XCTAssertEqual(result.stream.codec, .h264)
        XCTAssertEqual(result.stream.width, 1920)
        XCTAssertEqual(result.stream.height, 1080)
        XCTAssertEqual(result.stream.profileIDC, 100)
        XCTAssertEqual(result.stream.levelTimesTen, 41)
        XCTAssertEqual(result.frameCount, 10)
        XCTAssertEqual(result.frameCountSource, .accessUnitScan,
                       "a raw stream has no sample table to consult")
    }

    func test_probe_hevcElementaryStream() throws {
        let result = try VideoProbe.probe(hevcElementaryStream(frames: 5))
        XCTAssertEqual(result.stream.codec, .h265)
        XCTAssertEqual(result.stream.width, 1920)
        XCTAssertEqual(result.frameCount, 5)
    }

    func test_probe_mpeg2ElementaryStream() throws {
        let result = try VideoProbe.probe(mpeg2ElementaryStream(frames: 7))
        XCTAssertEqual(result.stream.codec, .mpeg2)
        XCTAssertEqual(result.stream.width, 720)
        XCTAssertEqual(result.stream.height, 576)
        XCTAssertEqual(result.frameCount, 7)
        XCTAssertEqual(try XCTUnwrap(result.frameRate), 25.0, accuracy: 0.001)
    }

    func test_probe_detectsCodecByContentNotExtension() throws {
        // The same bytes are identified regardless of what a filename claims.
        let h264 = try VideoProbe.probe(h264ElementaryStream(frames: 3))
        let hevc = try VideoProbe.probe(hevcElementaryStream(frames: 3))
        let mpeg2 = try VideoProbe.probe(mpeg2ElementaryStream(frames: 3))

        XCTAssertEqual(h264.stream.codec, .h264)
        XCTAssertEqual(hevc.stream.codec, .h265)
        XCTAssertEqual(mpeg2.stream.codec, .mpeg2)
    }

    // MARK: - Transfer syntax suggestion

    func test_probe_suggestsTransferSyntaxForConformantStream() throws {
        let result = try VideoProbe.probe(h264ElementaryStream(frames: 10))
        XCTAssertEqual(result.suggestedTransferSyntax?.uid, TransferSyntax.mpeg4AVCHP41.uid)
    }

    func test_probe_suggestsNothingForBaselineProfile() throws {
        // Baseline has no DICOM transfer syntax, so no suggestion is possible.
        let result = try VideoProbe.probe(
            h264ElementaryStream(frames: 3, sps: Self.spsBaselineNAL))
        XCTAssertEqual(result.stream.profileIDC, 66)
        XCTAssertNil(result.suggestedTransferSyntax)
    }

    func test_probedStream_validatesAgainstItsSuggestedSyntax() throws {
        // Probing and validation must agree, or the pipeline contradicts itself.
        let result = try VideoProbe.probe(h264ElementaryStream(frames: 10))
        let syntax = try XCTUnwrap(result.suggestedTransferSyntax)
        let conformance = VideoConformanceValidator.validate(
            stream: result.stream,
            transferSyntax: syntax,
            numberOfFrames: result.frameCount
        )
        XCTAssertTrue(conformance.isConformant, conformance.report)
    }

    // MARK: - Non-video guards (decision Q5)

    func test_probe_rejectsPNGWithPointerToDicomImage() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertThrowsError(try VideoProbe.probe(png)) { error in
            guard let probeError = error as? VideoProbeError else {
                return XCTFail("expected a VideoProbeError, got \(error)")
            }
            XCTAssertEqual(probeError, .notVideo(detected: "a PNG image"))
            XCTAssertTrue(probeError.message.contains("dicom-image"),
                          "the rejection must redirect to the right tool")
        }
    }

    func test_probe_rejectsAnimatedGIF() {
        let gif = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00])
        XCTAssertThrowsError(try VideoProbe.probe(gif)) { error in
            XCTAssertEqual(error as? VideoProbeError, .notVideo(detected: "an animated GIF"))
        }
    }

    func test_probe_rejectsTIFF() {
        for magic in [[0x49, 0x49, 0x2A, 0x00], [0x4D, 0x4D, 0x00, 0x2A]] {
            let tiff = Data(magic.map { UInt8($0) } + [0x08, 0x00, 0x00, 0x00])
            XCTAssertThrowsError(try VideoProbe.probe(tiff)) { error in
                XCTAssertEqual(error as? VideoProbeError, .notVideo(detected: "a TIFF image"))
            }
        }
    }

    func test_probe_rejectsJPEGAndBMPAndMatroska() {
        let cases: [([UInt8], String)] = [
            ([0xFF, 0xD8, 0xFF, 0xE0], "a JPEG image"),
            ([0x42, 0x4D, 0x00, 0x00], "a BMP image"),
            ([0x1A, 0x45, 0xDF, 0xA3], "a Matroska/WebM file"),
            ([0x52, 0x49, 0x46, 0x46], "a RIFF/AVI file"),
        ]
        for (magic, expected) in cases {
            XCTAssertThrowsError(try VideoProbe.probe(Data(magic + [0, 0, 0, 0]))) { error in
                XCTAssertEqual(error as? VideoProbeError, .notVideo(detected: expected))
            }
        }
    }

    func test_probe_rejectsDICOMInputByPreambleMagic() {
        // A DICOM file's "DICM" magic sits at offset 128, after the preamble.
        var dicom = Data(repeating: 0x00, count: 128)
        dicom.append(contentsOf: Array("DICM".utf8))
        dicom.append(Data(repeating: 0x00, count: 16))

        XCTAssertThrowsError(try VideoProbe.probe(dicom)) { error in
            XCTAssertEqual(error as? VideoProbeError, .notVideo(detected: "a DICOM file"))
        }
    }

    func test_detectNonVideo_passesRealVideoThrough() {
        XCTAssertNil(VideoProbe.detectNonVideo(h264ElementaryStream(frames: 2)))
        XCTAssertNil(VideoProbe.detectNonVideo(mpeg2ElementaryStream(frames: 2)))
    }

    // MARK: - Transport stream (decision Q2)

    func test_probe_transportStreamRejectedWithoutTrustInput() {
        XCTAssertThrowsError(try VideoProbe.probe(transportStream())) { error in
            guard let probeError = error as? VideoProbeError else {
                return XCTFail("expected a VideoProbeError")
            }
            XCTAssertEqual(probeError, .transportStreamNotValidatable)
            XCTAssertTrue(probeError.message.contains("--trust-input"))
            XCTAssertTrue(probeError.message.contains("ffmpeg"))
        }
    }

    func test_probe_transportStreamAcceptedWithTrustInput() throws {
        // MPEG-TS is one of the two containers PS3.5 blesses, so passing a
        // conformant one through is legal even without demuxing it.
        let result = try VideoProbe.probe(transportStream(), trustInput: true)
        XCTAssertEqual(result.container, .mpegTS)
        XCTAssertEqual(result.frameCountSource, .unavailable,
                       "nothing was read, so nothing is claimed")
        XCTAssertNil(result.suggestedTransferSyntax,
                     "an unvalidated stream gets no automatic transfer syntax")
    }

    // MARK: - Unrecognized input

    func test_probe_rejectsUnrecognizedBytes() {
        XCTAssertThrowsError(try VideoProbe.probe(Data([0x12, 0x34, 0x56, 0x78]))) { error in
            XCTAssertEqual(error as? VideoProbeError, .unrecognizedFormat)
        }
    }

    func test_probe_rejectsEmptyInput() {
        XCTAssertThrowsError(try VideoProbe.probe(Data())) { error in
            XCTAssertEqual(error as? VideoProbeError, .unrecognizedFormat)
        }
    }

    func test_probe_rejectsAnnexBWithNoParameterSet() {
        // Start codes but no SPS: nothing can be validated.
        let stream = Data([0x00, 0x00, 0x00, 0x01, 0x68, 0xEE, 0x3C, 0x80])
        XCTAssertThrowsError(try VideoProbe.probe(stream)) { error in
            XCTAssertEqual(error as? VideoProbeError, .unrecognizedFormat)
        }
    }

    // MARK: - Error messages

    func test_everyProbeError_hasAnActionableMessage() {
        let errors: [VideoProbeError] = [
            .unrecognizedFormat,
            .noVideoTrack,
            .multipleVideoTracks(count: 2),
            .unsupportedCodec("VP9"),
            .parameterSetsUnreadable,
            .transportStreamNotValidatable,
            .notVideo(detected: "a PNG image"),
        ]
        for error in errors {
            XCTAssertFalse(error.message.isEmpty, "\(error) has no message")
            XCTAssertTrue(error.message.hasPrefix("error:"), "\(error) should read as an error")
        }
    }

    func test_multipleVideoTracks_messageNamesTheCount() {
        let error = VideoProbeError.multipleVideoTracks(count: 3)
        XCTAssertTrue(error.message.contains("3 video tracks"), error.message)
        XCTAssertTrue(error.message.contains("ffmpeg"), "a remedy is given")
    }

    // MARK: - Robustness

    func test_probe_truncatedStreamsDoNotCrash() {
        let stream = h264ElementaryStream(frames: 5)
        for length in stride(from: 1, to: stream.count, by: 3) {
            _ = try? VideoProbe.probe(stream.prefix(length))
        }
    }

    func test_probe_randomBytesDoNotCrash() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            var bytes = Data()
            for _ in 0..<96 { bytes.append(UInt8.random(in: 0...255, using: &generator)) }
            _ = try? VideoProbe.probe(bytes)
        }
    }
}
