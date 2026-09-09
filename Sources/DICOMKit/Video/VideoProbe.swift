//
// VideoProbe.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Everything known about a video input before deciding whether to encapsulate it.
public struct VideoProbeResult: Sendable {
    /// The container the payload arrived in.
    public let container: VideoContainer
    /// What the coded bit stream says about itself.
    public let stream: VideoStreamInfo
    /// Frame count: exact from a container's sample table, counted from access
    /// units for a raw elementary stream.
    public let frameCount: Int
    /// How the frame count was obtained, which matters because one source is
    /// exact and the other is a scan.
    public let frameCountSource: FrameCountSource
    /// The number of audio tracks, which DICOM video IODs cannot carry.
    public let audioTrackCount: Int
    /// The transfer syntax that fits this stream, when one does.
    public let suggestedTransferSyntax: TransferSyntax?

    /// Where a frame count came from.
    public enum FrameCountSource: String, Sendable {
        /// The container's sample table: exact and cheap.
        case sampleTable
        /// Counted access units in the bit stream: the raw-stream fallback.
        case accessUnitScan
        /// No reliable count was available.
        case unavailable
    }

    /// The effective frame rate, preferring the bit stream's own declaration over
    /// the container's, since the container's is derived from durations.
    public let frameRate: Double?
}

/// Why an input could not be probed.
public enum VideoProbeError: Error, Sendable, Equatable {
    /// The bytes match no container or elementary stream this toolkit reads.
    case unrecognizedFormat
    /// The container holds no video track.
    case noVideoTrack
    /// The container holds more than one video track, so picking one silently
    /// would be a guess.
    case multipleVideoTracks(count: Int)
    /// The codec is not one DICOM video carries.
    case unsupportedCodec(String)
    /// Parameter sets were missing or unreadable, so nothing can be validated.
    case parameterSetsUnreadable
    /// A transport stream was given without `--trust-input`, and TS demuxing is
    /// not implemented, so it cannot be validated.
    case transportStreamNotValidatable
    /// The input is multi-frame but not video, and belongs to a different tool.
    case notVideo(detected: String)

    /// A message naming the problem and, where one exists, the remedy.
    public var message: String {
        switch self {
        case .unrecognizedFormat:
            return """
                error: the input is not a recognized video container or elementary stream.
                       dicom-video reads MP4, MOV, MPEG-TS, and raw H.264/HEVC/MPEG-2 streams.
                """
        case .noVideoTrack:
            return "error: the container holds no video track."
        case let .multipleVideoTracks(count):
            return """
                error: the container holds \(count) video tracks; \
                dicom-video will not guess which one to convert.

                       Extract the track you want first:
                         ffmpeg -i input.mp4 -map 0:v:0 -c copy track0.mp4
                """
        case let .unsupportedCodec(name):
            return """
                error: \(name) is not a DICOM video codec.
                       dicom-video handles H.264, HEVC and MPEG-2 only.
                """
        case .parameterSetsUnreadable:
            return """
                error: the video track's parameter sets could not be read, so the \
                stream cannot be validated.
                """
        case .transportStreamNotValidatable:
            return """
                error: MPEG-2 Transport Stream input cannot be validated in this release
                       (TS demuxing is deferred). Either convert to MP4:
                         ffmpeg -i input.ts -c copy output.mp4
                       or re-run with --trust-input to encapsulate the TS unvalidated.
                """
        case let .notVideo(detected):
            return """
                error: the input is \(detected), not a video bitstream.
                       dicom-video handles H.264/HEVC/MPEG-2 only. Use dicom-image instead.
                """
        }
    }
}

/// Probes a video input, deriving every DICOM attribute from the bytes rather
/// than from the caller.
///
/// This is deliberately free of any platform framework: identifying, validating
/// and passing through an already-conformant payload works everywhere. Rewriting
/// a container is the only part that needs more.
public enum VideoProbe {

    /// File signatures for formats that are multi-frame but are not video, so the
    /// rejection can name what was actually supplied.
    ///
    /// These belong to a different DICOM storage path entirely.
    private static let nonVideoSignatures: [(bytes: [UInt8], name: String)] = [
        ([0x89, 0x50, 0x4E, 0x47], "a PNG image"),
        ([0xFF, 0xD8, 0xFF], "a JPEG image"),
        ([0x47, 0x49, 0x46, 0x38], "an animated GIF"),
        ([0x49, 0x49, 0x2A, 0x00], "a TIFF image"),
        ([0x4D, 0x4D, 0x00, 0x2A], "a TIFF image"),
        ([0x42, 0x4D], "a BMP image"),
        ([0x52, 0x49, 0x46, 0x46], "a RIFF/AVI file"),
        ([0x1A, 0x45, 0xDF, 0xA3], "a Matroska/WebM file"),
        ([0x44, 0x49, 0x43, 0x4D], "a DICOM file"),
    ]

    /// Identifies a non-video input by signature, so the caller can redirect to
    /// the right tool rather than attempting a conversion.
    public static func detectNonVideo(_ data: Data) -> String? {
        // A DICOM file's magic sits at offset 128, after the preamble.
        if data.count > 132 {
            let magic = [UInt8](data[(data.startIndex + 128)..<(data.startIndex + 132)])
            if magic == [0x44, 0x49, 0x43, 0x4D] { return "a DICOM file" }
        }
        let prefix = [UInt8](data.prefix(8))
        for signature in nonVideoSignatures {
            guard prefix.count >= signature.bytes.count else { continue }
            if Array(prefix.prefix(signature.bytes.count)) == signature.bytes {
                return signature.name
            }
        }
        return nil
    }

    /// Probes an input.
    ///
    /// - Parameters:
    ///   - data: The input bytes.
    ///   - trustInput: Skip deep validation for a transport stream, encapsulating
    ///     it on the caller's assertion that it is conformant.
    /// - Returns: What was found.
    /// - Throws: ``VideoProbeError`` when the input cannot be probed at all.
    public static func probe(_ data: Data, trustInput: Bool = false) throws -> VideoProbeResult {
        // Reject non-video input first, so the message names the real format
        // rather than complaining about a missing start code.
        if let detected = detectNonVideo(data) {
            throw VideoProbeError.notVideo(detected: detected)
        }

        let container = MP4ContainerParser.detectContainer(data)
        switch container {
        case .mp4, .quickTime:
            return try probeISOBMFF(data, container: container)
        case .mpegTS:
            guard trustInput else { throw VideoProbeError.transportStreamNotValidatable }
            return try probeTrustedTransportStream(data)
        case .elementaryStream:
            return try probeElementaryStream(data)
        case .unknown:
            throw VideoProbeError.unrecognizedFormat
        }
    }

    // MARK: - ISO-BMFF

    private static func probeISOBMFF(
        _ data: Data,
        container: VideoContainer
    ) throws -> VideoProbeResult {
        guard let info = MP4ContainerParser.inspect(data) else {
            throw VideoProbeError.unrecognizedFormat
        }
        guard !info.videoTracks.isEmpty else { throw VideoProbeError.noVideoTrack }
        guard info.videoTracks.count == 1 else {
            throw VideoProbeError.multipleVideoTracks(count: info.videoTracks.count)
        }

        let track = info.videoTracks[0]
        guard track.codec != .unknown else {
            throw VideoProbeError.unsupportedCodec("this track's codec")
        }
        guard !track.parameterSets.isEmpty else {
            throw VideoProbeError.parameterSetsUnreadable
        }

        // Parse the parameter sets from the sample description. This is read-only:
        // the bytes written are the container's own.
        let stream: VideoStreamInfo
        switch track.codec {
        case .h264:
            // avcC stores parameter sets without their NAL headers.
            guard let sps = track.parameterSets.compactMap({ H264Parser.parseSPSPayload($0) }).first
            else { throw VideoProbeError.parameterSetsUnreadable }
            stream = sps.streamInfo
        case .h265:
            // hvcC keeps the two-byte NAL header on each stored unit.
            guard let sps = track.parameterSets.compactMap({ HEVCParser.parseSPS(nalUnit: $0) }).first
            else { throw VideoProbeError.parameterSetsUnreadable }
            stream = sps.streamInfo
        case .mpeg2:
            guard let header = track.parameterSets.compactMap({ MPEG2Parser.parseSequenceHeader($0) }).first
            else { throw VideoProbeError.parameterSetsUnreadable }
            stream = header.streamInfo
        case .unknown:
            throw VideoProbeError.unsupportedCodec("this track's codec")
        }

        // Prefer the bit stream's own frame rate; fall back to the container's,
        // which is derived from sample durations.
        let frameRate = stream.frameRate ?? track.frameRate
        let resolved = withFrameRate(stream, frameRate: frameRate)

        return VideoProbeResult(
            container: container,
            stream: resolved,
            frameCount: track.frameCount,
            frameCountSource: track.frameCount > 0 ? .sampleTable : .unavailable,
            audioTrackCount: info.audioTrackCount,
            suggestedTransferSyntax: VideoConformanceValidator.selectTransferSyntax(for: resolved),
            frameRate: frameRate
        )
    }

    // MARK: - Elementary Streams

    private static func probeElementaryStream(_ data: Data) throws -> VideoProbeResult {
        // Try each codec's parameter set in turn. Detection is by content, since
        // an extension is a claim rather than evidence.
        if let sps = H264Parser.parseFirstSPS(annexB: data) {
            let stream = sps.streamInfo
            let count = H264Parser.countFrames(annexB: data)
            return VideoProbeResult(
                container: .elementaryStream,
                stream: stream,
                frameCount: count,
                frameCountSource: count > 0 ? .accessUnitScan : .unavailable,
                audioTrackCount: 0,
                suggestedTransferSyntax: VideoConformanceValidator.selectTransferSyntax(for: stream),
                frameRate: stream.frameRate
            )
        }

        if let sps = HEVCParser.parseFirstSPS(annexB: data) {
            let stream = sps.streamInfo
            let count = HEVCParser.countFrames(annexB: data)
            return VideoProbeResult(
                container: .elementaryStream,
                stream: stream,
                frameCount: count,
                frameCountSource: count > 0 ? .accessUnitScan : .unavailable,
                audioTrackCount: 0,
                suggestedTransferSyntax: VideoConformanceValidator.selectTransferSyntax(for: stream),
                frameRate: stream.frameRate
            )
        }

        if let header = MPEG2Parser.parseSequenceHeader(data) {
            let stream = header.streamInfo
            let count = MPEG2Parser.countFrames(data)
            return VideoProbeResult(
                container: .elementaryStream,
                stream: stream,
                frameCount: count,
                frameCountSource: count > 0 ? .accessUnitScan : .unavailable,
                audioTrackCount: 0,
                suggestedTransferSyntax: VideoConformanceValidator.selectTransferSyntax(for: stream),
                frameRate: stream.frameRate
            )
        }

        throw VideoProbeError.unrecognizedFormat
    }

    // MARK: - Transport Streams

    /// Accepts a transport stream on the caller's assertion, without validating it.
    ///
    /// MPEG-TS is one of the two containers PS3.5 blesses, so passing a conformant
    /// one through is legal. Demuxing it — which is what validation would require —
    /// is a separate piece of work.
    private static func probeTrustedTransportStream(_ data: Data) throws -> VideoProbeResult {
        // Nothing is claimed about the stream's geometry, because nothing was read.
        // The caller supplies those attributes and takes responsibility for them.
        let unknownStream = VideoStreamInfo(
            codec: .unknown, width: 0, height: 0,
            profileIDC: 0, levelTimesTen: 0,
            chromaFormat: .yuv420, bitDepthLuma: 8, bitDepthChroma: 8,
            frameRate: nil, isProgressive: true
        )
        return VideoProbeResult(
            container: .mpegTS,
            stream: unknownStream,
            frameCount: 0,
            frameCountSource: .unavailable,
            audioTrackCount: 0,
            suggestedTransferSyntax: nil,
            frameRate: nil
        )
    }

    // MARK: - Private

    /// Returns a copy of a stream summary carrying a different frame rate.
    private static func withFrameRate(
        _ stream: VideoStreamInfo,
        frameRate: Double?
    ) -> VideoStreamInfo {
        guard stream.frameRate != frameRate else { return stream }
        return VideoStreamInfo(
            codec: stream.codec,
            width: stream.width,
            height: stream.height,
            profileIDC: stream.profileIDC,
            levelTimesTen: stream.levelTimesTen,
            chromaFormat: stream.chromaFormat,
            bitDepthLuma: stream.bitDepthLuma,
            bitDepthChroma: stream.bitDepthChroma,
            frameRate: frameRate,
            isProgressive: stream.isProgressive,
            sampleAspectRatio: stream.sampleAspectRatio
        )
    }
}
