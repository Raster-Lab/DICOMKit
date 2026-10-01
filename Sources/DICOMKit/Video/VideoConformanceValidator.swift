//
// VideoConformanceValidator.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Why a bit stream cannot be encapsulated as a given DICOM video transfer syntax.
///
/// Each case carries the observed value and the expected one, because a rejection
/// is only actionable if it names what was wrong. Video DICOM is unusually strict,
/// and silently "fixing" non-conformant input would mean re-encoding diagnostic
/// pixel data.
///
/// Reference: PS3.5 Sections 8.2.5 - 8.2.12
public enum VideoConformanceViolation: Sendable, Hashable {

    /// The coded profile is not permitted by the transfer syntax.
    case profileNotPermitted(observed: String, observedIDC: Int, required: String, requiredIDC: Int)

    /// The coded level exceeds the transfer syntax's ceiling.
    ///
    /// `pictureFitsMaximum` says whether the stream's actual geometry and frame
    /// rate would fit the ceiling - in which case only the signalled level is too
    /// high and re-encoding at the lower level loses nothing - or not, in which
    /// case the picture has to shrink or the codec has to change.
    case levelExceedsMaximum(
        observed: String,
        maximum: String,
        codec: VideoCodec = .h264,
        pictureFitsMaximum: Bool = true
    )

    /// The coded picture size or throughput exceeds the transfer syntax's level,
    /// whatever level the stream signals.
    case levelLimitsExceeded(
        codec: VideoCodec,
        width: Int,
        height: Int,
        frameRate: Double?,
        level: String,
        excesses: [VideoLevelLimits.Excess]
    )

    /// HEVC High tier, where PS3.5 requires Main tier.
    case highTierNotPermitted(transferSyntax: String)

    /// Chroma subsampling other than 4:2:0.
    case chromaFormatNotPermitted(observed: String)

    /// A coded bit depth no DICOM video transfer syntax can carry.
    case bitDepthNotRepresentable(observed: Int)

    /// The bit depth does not match the transfer syntax: Main is 8-bit and
    /// Main 10 is 10-bit, and they are not interchangeable.
    case bitDepthMismatch(observed: Int, expected: Int, transferSyntax: String)

    /// Non-square pixels, which cannot be expressed because Pixel Aspect Ratio
    /// must be absent.
    case anamorphicPixels(width: Int, height: Int)

    /// The declared Rows/Columns disagree with the bit stream.
    case dimensionMismatch(declaredColumns: Int, declaredRows: Int, actualWidth: Int, actualHeight: Int)

    /// The stream is not one of the three codecs DICOM video carries.
    case codecNotSupported(observed: String)

    /// The codec does not match the chosen transfer syntax.
    case codecMismatch(observed: String, expected: String, transferSyntax: String)

    /// The frame count is not positive.
    case invalidFrameCount(observed: Int)

    /// The resolution and frame rate combination is not in the BD-compatible
    /// table of PS3.5 Table 8-4.
    case notBluRayCompatible(width: Int, height: Int, frameRate: Double, isProgressive: Bool)

    /// An MPEG-2 picture size or frame rate outside PS3.5 Table 8-1 (Main
    /// Level) or 8.2.6 / Table 8-2 (High Level).
    case mpeg2FormatNotPermitted(detail: String, transferSyntax: String, isHighLevel: Bool)

    /// MPEG-2 Main Profile / High Level with a display aspect ratio other than
    /// 16:9 (`aspect_ratio_information` 0011, PS3.5 8.2.6).
    case mpeg2AspectRatioNotPermitted(observed: Int)

    /// The "For 3D Video" transfer syntax without a frame packing arrangement
    /// SEI (PS3.5 Table 8-8).
    case framePackingRequired(transferSyntax: String)

    /// The "For 2D Video" transfer syntax with a frame packing arrangement SEI
    /// (PS3.5 Table 8-8).
    case framePackingNotPermitted(transferSyntax: String)

    /// An audio track that breaks PS3.5 8.2.5 or 8.2.12.
    case audioNotPermitted(track: Int, summary: String, problem: String, videoCodec: VideoCodec)

    /// The payload is too large for the single fragment a non-fragmentable
    /// transfer syntax allows.
    case payloadExceedsSingleFragment(byteCount: Int, transferSyntax: String, fragmentableAlternative: String?)

    /// The payload is in a container DICOM does not bless.
    case containerNotPermitted(observed: String)

    /// A human-readable description naming the constraint, the observed value and
    /// the expected value.
    public var message: String {
        switch self {
        case let .profileNotPermitted(observed, observedIDC, required, requiredIDC):
            return """
                profile_idc \(observedIDC) (\(observed)) is not permitted, \
                which requires \(required) Profile (\(requiredIDC))
                """
        case let .levelExceedsMaximum(observed, maximum, _, _):
            return "level \(observed) exceeds the transfer syntax maximum of \(maximum)"
        case let .levelLimitsExceeded(_, width, height, frameRate, level, excesses):
            let rate = frameRate.map { " at " + String(format: "%.3f", $0) + " fps" } ?? ""
            return """
                \(width)x\(height)\(rate) does not fit Level \(level): \
                \(excesses.map(\.description).joined(separator: "; "))
                """
        case let .highTierNotPermitted(transferSyntax):
            return """
                HEVC High tier is not permitted; transfer syntax \(transferSyntax) \
                requires Main tier (PS3.5 8.2.10 - 8.2.11)
                """
        case let .chromaFormatNotPermitted(observed):
            return """
                chroma format \(observed) is not permitted; DICOM video requires \
                4:2:0 (PS3.5 8.2.7)
                """
        case let .bitDepthNotRepresentable(observed):
            return """
                \(observed)-bit video cannot be represented; DICOM video carries \
                8-bit or 10-bit only
                """
        case let .bitDepthMismatch(observed, expected, transferSyntax):
            return """
                \(observed)-bit video does not match transfer syntax \
                \(transferSyntax), which requires \(expected)-bit
                """
        case let .anamorphicPixels(width, height):
            return """
                sample aspect ratio \(width):\(height) is not 1:1; DICOM video \
                requires square pixels because Pixel Aspect Ratio (0028,0034) \
                must be absent (PS3.5 8.2.7)
                """
        case let .dimensionMismatch(declaredColumns, declaredRows, actualWidth, actualHeight):
            return """
                declared \(declaredColumns)x\(declaredRows) does not match the \
                bit stream's \(actualWidth)x\(actualHeight)
                """
        case let .codecNotSupported(observed):
            return "\(observed) is not a DICOM video codec (H.264, HEVC and MPEG-2 only)"
        case let .codecMismatch(observed, expected, transferSyntax):
            return """
                \(observed) does not match transfer syntax \(transferSyntax), \
                which carries \(expected)
                """
        case let .invalidFrameCount(observed):
            return "Number of Frames must be at least 1, got \(observed)"
        case let .notBluRayCompatible(width, height, frameRate, isProgressive):
            let scan = isProgressive ? "progressive" : "interlaced"
            return """
                \(width)x\(height) at \(String(format: "%.3f", frameRate)) fps \
                (\(scan)) is not in the BD-compatible table of PS3.5 Table 8-4
                """
        case let .mpeg2FormatNotPermitted(detail, transferSyntax, isHighLevel):
            let source = isHighLevel ? "PS3.5 8.2.6 and Table 8-2" : "PS3.5 Table 8-1"
            return "\(detail), which transfer syntax \(transferSyntax) does not permit (\(source))"
        case let .mpeg2AspectRatioNotPermitted(observed):
            return """
                aspect_ratio_information \(observed) (\(Self.mpeg2AspectName(observed))) \
                is not permitted; MPEG-2 Main Profile / High Level requires 0011 \
                (16:9) (PS3.5 8.2.6)
                """
        case let .framePackingRequired(transferSyntax):
            return """
                transfer syntax \(transferSyntax) is for 3D video, but the stream \
                carries no frame packing arrangement SEI (PS3.5 Table 8-8)
                """
        case let .framePackingNotPermitted(transferSyntax):
            return """
                the stream packs two views per frame (frame packing arrangement \
                SEI), which transfer syntax \(transferSyntax) for 2D video does not \
                permit (PS3.5 Table 8-8)
                """
        case let .audioNotPermitted(track, summary, problem, _):
            return "audio track \(track) (\(summary)) \(problem)"
        case let .payloadExceedsSingleFragment(byteCount, transferSyntax, _):
            return """
                the \(byteCount)-byte bit stream exceeds the 4294967294-byte \
                fragment that transfer syntax \(transferSyntax) requires it to fit \
                in (PS3.5 8.2.5 - 8.2.8)
                """
        case let .containerNotPermitted(observed):
            return """
                \(observed) is not a permitted container; the video bit stream \
                shall be in an MPEG-2 Transport Stream or MP4 container \
                (PS3.5 8.2.7)
                """
        }
    }

    /// A copy-pasteable remedy, where one exists.
    ///
    /// Re-encoding is the user's decision to make, never something this toolkit
    /// does implicitly: remuxing preserves the camera's pixel data bit-for-bit,
    /// while re-encoding degrades diagnostic imagery on every pass. Where only the
    /// audio is at fault, the remedy copies the video untouched.
    ///
    /// Multi-line remedies are joined with the report's indentation, so they
    /// render as one aligned block.
    public var remedy: String? {
        switch self {
        case let .profileNotPermitted(_, _, required, _):
            let profile = required.lowercased().replacingOccurrences(of: " ", with: "")
            return Remedy.h264(profile: profile, level: "4.1")
        case let .levelExceedsMaximum(_, maximum, codec, fits):
            switch codec {
            case .h264 where fits:
                return Remedy.lines([
                    "The picture fits Level \(maximum); re-encode with that level signalled:",
                    Remedy.h264(level: maximum),
                ])
            case .h264:
                return Remedy.h264TooLarge
            case .h265:
                return Remedy.hevcTooLarge
            case .mpeg2, .unknown:
                return Remedy.mpeg2ToH264
            }
        case let .levelLimitsExceeded(codec, _, _, _, _, _):
            switch codec {
            case .h264: return Remedy.h264TooLarge
            case .h265: return Remedy.hevcTooLarge
            case .mpeg2, .unknown: return Remedy.mpeg2ToH264
            }
        case .highTierNotPermitted:
            return Remedy.hevc(filter: nil)
        case .chromaFormatNotPermitted:
            return "ffmpeg -i input.mp4 -c:v libx264 -pix_fmt yuv420p fixed.mp4"
        case .bitDepthNotRepresentable, .bitDepthMismatch:
            return "ffmpeg -i input.mp4 -c:v libx264 -pix_fmt yuv420p fixed.mp4"
        case .anamorphicPixels:
            return "ffmpeg -i input.mp4 -vf scale=iw*sar:ih -setsar 1:1 fixed.mp4"
        case .notBluRayCompatible:
            return """
                Use transfer syntax 1.2.840.10008.1.2.4.102 (H.264 HP@4.1) or \
                1.2.840.10008.1.2.4.104 (HP@4.2) instead of the BD-compatible UID.
                """
        case let .mpeg2FormatNotPermitted(_, _, isHighLevel):
            return Remedy.lines([
                isHighLevel
                    ? "Re-encode at 1920x1080 or 1280x720, 16:9, 25-60 fps:"
                    : "Re-encode within 720x576 at 25 fps or 720x480 at 30 fps:",
                isHighLevel ? Remedy.mpeg2HighLevel : Remedy.mpeg2MainLevel,
                "or convert to H.264, which has no fixed picture sizes:",
                Remedy.h264(level: "4.2", filter: Remedy.fitWithin1080p),
            ])
        case .mpeg2AspectRatioNotPermitted:
            return Remedy.mpeg2HighLevel
        case .framePackingRequired:
            return """
                Use transfer syntax 1.2.840.10008.1.2.4.104 for 2D video, or encode the \
                3D pair with a frame packing SEI (x264: -x264-params frame-packing=3).
                """
        case .framePackingNotPermitted:
            return "Use transfer syntax 1.2.840.10008.1.2.4.105 (For 3D Video) instead."
        case let .audioNotPermitted(_, _, _, videoCodec):
            let audio = videoCodec == .mpeg2 ? Remedy.mp3Audio : Remedy.aacAudio
            return Remedy.lines([
                "Re-encode only the audio; the video is copied bit-for-bit:",
                "ffmpeg -i input.mp4 -map 0:v:0 -map 0:a -c:v copy \(audio) fixed.mp4",
                "or drop the audio:",
                "ffmpeg -i input.mp4 -map 0:v:0 -c copy fixed.mp4",
            ])
        case let .payloadExceedsSingleFragment(_, _, alternative):
            guard let alternative = alternative else { return nil }
            return "Use the fragmentable transfer syntax: --transfer-syntax \(alternative)"
        case .containerNotPermitted:
            return "ffmpeg -i input.mov -map 0:v:0 -map '0:a?' -c copy output.mp4"
        case .codecNotSupported, .codecMismatch, .dimensionMismatch, .invalidFrameCount:
            return nil
        }
    }

    /// Names an MPEG-2 `aspect_ratio_information` value (ITU-T H.262 Table 6-3).
    static func mpeg2AspectName(_ value: Int) -> String {
        switch value {
        case 1: return "square samples"
        case 2: return "4:3"
        case 3: return "16:9"
        case 4: return "2.21:1"
        default: return "reserved"
        }
    }
}

/// The ffmpeg command lines the remedies are built from, kept in one place so
/// that every suggestion produces audio and video DICOM accepts.
enum Remedy {
    /// Indentation of a continuation line inside a violation report.
    static let indent = "\n       "

    static func lines(_ lines: [String]) -> String {
        lines.joined(separator: indent)
    }

    /// AAC at the 48 kHz stereo PS3.5 8.2.12 requires.
    static let aacAudio = "-c:a aac -ar 48000 -ac 2 -b:a 192k"

    /// CBR MP3, the only audio PS3.5 8.2.5 permits beside MPEG-2 video.
    static let mp3Audio = "-c:a libmp3lame -ar 48000 -b:a 192k"

    /// A scale filter that fits the picture inside 1920x1080 - or 1080x1920
    /// for a portrait clip - without changing its shape, so the result fits
    /// H.264 Level 4.1 / 4.2 picture sizes either way up.
    static let fitWithin1080p = fit(long: 1920, short: 1080)

    /// The same for 3840x2160 and HEVC Level 5.1.
    static let fitWithin2160p = fit(long: 3840, short: 2160)

    private static func fit(long: Int, short: Int) -> String {
        "scale='if(gte(iw,ih),\(long),\(short))':'if(gte(iw,ih),\(short),\(long))'"
            + ":force_original_aspect_ratio=decrease:force_divisible_by=2"
    }

    static func h264(profile: String = "high", level: String, filter: String? = nil) -> String {
        let vf = filter.map { "-vf \"\($0)\" " } ?? ""
        return "ffmpeg -i input.mp4 \(vf)-c:v libx264 -profile:v \(profile) -level \(level) "
            + "-pix_fmt yuv420p \(aacAudio) fixed.mp4"
    }

    static func hevc(filter: String?) -> String {
        let vf = filter.map { "-vf \"\($0)\" " } ?? ""
        return "ffmpeg -i input.mp4 \(vf)-c:v libx265 -tag:v hvc1 -profile:v main "
            + "-x265-params level-idc=5.1:high-tier=0 -pix_fmt yuv420p \(aacAudio) fixed.mp4"
    }

    static let h264TooLarge = lines([
        "Keep the resolution by re-encoding as HEVC Main @ Level 5.1 (1.2.840.10008.1.2.4.107):",
        hevc(filter: nil),
        "or scale down to fit H.264 Level 4.2 (1.2.840.10008.1.2.4.104):",
        h264(level: "4.2", filter: fitWithin1080p),
    ])

    static let hevcTooLarge = lines([
        "Scale down to fit HEVC Level 5.1 (at most 4K at 60 fps):",
        hevc(filter: fitWithin2160p),
    ])

    static let mpeg2MainLevel =
        "ffmpeg -i input.mpg -vf scale=720:576 -c:v mpeg2video -profile:v 4 -level:v 8 "
        + "-b:v 8M -maxrate 15M -bufsize 1835k \(mp3Audio) -f mpegts fixed.ts"

    static let mpeg2HighLevel =
        "ffmpeg -i input.mpg -vf scale=1920:1080 -aspect 16:9 -c:v mpeg2video -profile:v 4 "
        + "-level:v 4 -b:v 40M -maxrate 80M -bufsize 9781k \(mp3Audio) -f mpegts fixed.ts"

    static let mpeg2ToH264 = lines([
        "Convert to H.264, which has no fixed picture sizes:",
        h264(level: "4.2", filter: fitWithin1080p),
    ])
}

/// The outcome of validating a bit stream against a transfer syntax.
public struct VideoConformanceResult: Sendable {
    /// Violations found, in the order they were checked. Empty means conformant.
    public let violations: [VideoConformanceViolation]

    /// Whether the stream may be encapsulated as the chosen transfer syntax.
    public var isConformant: Bool { violations.isEmpty }

    /// A multi-line report naming every violated constraint and its remedy.
    public var report: String {
        violations.map { violation in
            var text = "error: \(violation.message)"
            if let remedy = violation.remedy {
                text += "\n\n       \(remedy)"
            }
            return text
        }.joined(separator: "\n\n")
    }

    public init(violations: [VideoConformanceViolation]) {
        self.violations = violations
    }
}

/// Enforces the encoding constraints the DICOM video transfer syntaxes impose.
///
/// Non-conformant input is rejected and reported, never silently re-encoded.
///
/// Reference: PS3.5 Sections 8.2.5 - 8.2.12
public enum VideoConformanceValidator {

    // MARK: - Transfer Syntax Constraints

    /// What a given video transfer syntax requires of a bit stream.
    public struct Constraints: Sendable {
        /// The codec the transfer syntax carries.
        public let codec: VideoCodec
        /// The required profile identifier, when the transfer syntax fixes one.
        public let requiredProfileIDC: Int?
        /// A human-readable name for the required profile.
        public let requiredProfileName: String
        /// The maximum level, in level-times-ten units.
        public let maximumLevelTimesTen: Int
        /// The required coded luma bit depth.
        public let requiredBitDepth: Int
        /// Whether the extra Blu-ray Disc constraints of PS3.5 Table 8-4 apply.
        public let requiresBluRayCompatibility: Bool
    }

    /// The constraints a transfer syntax imposes, or nil if it is not a video one.
    public static func constraints(for transferSyntax: TransferSyntax) -> Constraints? {
        let uid = transferSyntax.uid
        // The fragmentable variants impose the same encoding constraints as their
        // non-fragmentable twins; only the fragmentation rule differs.
        let base = uid.hasSuffix(".1") && transferSyntax.isVideo
            ? String(uid.dropLast(2))
            : uid

        switch base {
        case "1.2.840.10008.1.2.4.100":
            return Constraints(
                codec: .mpeg2,
                requiredProfileIDC: 4,          // Main Profile
                requiredProfileName: "Main",
                maximumLevelTimesTen: 8,        // Main Level, per H.262 Table 8-11
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.101":
            return Constraints(
                codec: .mpeg2,
                requiredProfileIDC: 4,
                requiredProfileName: "Main",
                maximumLevelTimesTen: 4,        // High Level
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.102":
            return Constraints(
                codec: .h264,
                requiredProfileIDC: 100,        // High Profile
                requiredProfileName: "High",
                maximumLevelTimesTen: 41,
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.103":
            return Constraints(
                codec: .h264,
                requiredProfileIDC: 100,
                requiredProfileName: "High",
                maximumLevelTimesTen: 41,
                requiredBitDepth: 8,
                requiresBluRayCompatibility: true
            )
        case "1.2.840.10008.1.2.4.104", "1.2.840.10008.1.2.4.105":
            return Constraints(
                codec: .h264,
                requiredProfileIDC: 100,
                requiredProfileName: "High",
                maximumLevelTimesTen: 42,
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.106":
            return Constraints(
                codec: .h264,
                requiredProfileIDC: 128,        // Stereo High Profile
                requiredProfileName: "Stereo High",
                maximumLevelTimesTen: 42,
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.107":
            return Constraints(
                codec: .h265,
                requiredProfileIDC: 1,          // Main
                requiredProfileName: "Main",
                maximumLevelTimesTen: 51,
                requiredBitDepth: 8,
                requiresBluRayCompatibility: false
            )
        case "1.2.840.10008.1.2.4.108":
            return Constraints(
                codec: .h265,
                requiredProfileIDC: 2,          // Main 10
                requiredProfileName: "Main 10",
                maximumLevelTimesTen: 51,
                requiredBitDepth: 10,
                requiresBluRayCompatibility: false
            )
        default:
            return nil
        }
    }

    // MARK: - Blu-ray Compatibility

    /// One permitted BD-compatible resolution and frame rate.
    public struct BluRayFormat: Sendable, Hashable {
        public let rows: Int
        public let columns: Int
        public let frameRate: Double
        public let isProgressive: Bool
    }

    /// The BD-compatible combinations of PS3.5 Table 8-4.
    ///
    /// 1920x1080 is permitted only interlaced at 25 and 29.97, so progressive
    /// 1080p25 belongs on transfer syntax .102 or .104 rather than .103.
    public static let bluRayFormats: [BluRayFormat] = [
        BluRayFormat(rows: 1080, columns: 1920, frameRate: 25.0, isProgressive: false),
        BluRayFormat(rows: 1080, columns: 1920, frameRate: 30000.0 / 1001.0, isProgressive: false),
        BluRayFormat(rows: 1080, columns: 1920, frameRate: 24.0, isProgressive: true),
        BluRayFormat(rows: 1080, columns: 1920, frameRate: 24000.0 / 1001.0, isProgressive: true),
        BluRayFormat(rows: 720, columns: 1280, frameRate: 50.0, isProgressive: true),
        BluRayFormat(rows: 720, columns: 1280, frameRate: 60000.0 / 1001.0, isProgressive: true),
        BluRayFormat(rows: 720, columns: 1280, frameRate: 24.0, isProgressive: true),
        BluRayFormat(rows: 720, columns: 1280, frameRate: 24000.0 / 1001.0, isProgressive: true),
    ]

    /// Whether a geometry and frame rate appear in PS3.5 Table 8-4.
    public static func isBluRayCompatible(
        width: Int,
        height: Int,
        frameRate: Double,
        isProgressive: Bool
    ) -> Bool {
        return bluRayFormats.contains { format in
            format.columns == width
                && format.rows == height
                && format.isProgressive == isProgressive
                && abs(format.frameRate - frameRate) < 0.01
        }
    }

    // MARK: - Validation

    /// The largest fragment PS3.5 allows: an Item's length is a 32-bit value and
    /// must be even, and 0xFFFFFFFF is reserved for undefined length.
    public static let maximumFragmentLength = 0xFFFF_FFFE

    /// Validates a probed bit stream against a transfer syntax.
    ///
    /// - Parameters:
    ///   - stream: What the bit stream says about itself.
    ///   - transferSyntax: The transfer syntax the caller intends to write.
    ///   - numberOfFrames: The frame count, when known.
    ///   - declaredRows: Rows the caller intends to write, when cross-checking.
    ///   - declaredColumns: Columns the caller intends to write, when cross-checking.
    /// - Returns: The violations found; empty means conformant.
    public static func validate(
        stream: VideoStreamInfo,
        transferSyntax: TransferSyntax,
        numberOfFrames: Int? = nil,
        declaredRows: Int? = nil,
        declaredColumns: Int? = nil
    ) -> VideoConformanceResult {
        var violations: [VideoConformanceViolation] = []

        guard let constraints = constraints(for: transferSyntax) else {
            violations.append(.codecNotSupported(observed: transferSyntax.uid))
            return VideoConformanceResult(violations: violations)
        }

        // Codec must match the transfer syntax.
        if stream.codec != constraints.codec {
            violations.append(.codecMismatch(
                observed: stream.codec.displayName,
                expected: constraints.codec.displayName,
                transferSyntax: transferSyntax.uid
            ))
            // Every remaining check is meaningless against the wrong codec.
            return VideoConformanceResult(violations: violations)
        }

        // Profile must match exactly. Baseline and Main H.264 are rejected in
        // remux mode rather than transcoded.
        if let requiredIDC = constraints.requiredProfileIDC, stream.profileIDC != requiredIDC {
            violations.append(.profileNotPermitted(
                observed: stream.profileName,
                observedIDC: stream.profileIDC,
                required: constraints.requiredProfileName,
                requiredIDC: requiredIDC
            ))
        }

        // HEVC: Main tier only.
        if stream.codec == .h265, stream.isHighTier {
            violations.append(.highTierNotPermitted(transferSyntax: transferSyntax.uid))
        }

        // Level. The signalled level must not exceed the ceiling, and - since
        // PS3.5 requires Rows, Columns and frame rate to be *compliant with* the
        // level - what the stream actually codes must fit the ceiling too.
        switch stream.codec {
        case .mpeg2:
            violations += mpeg2Violations(stream, constraints: constraints, transferSyntax: transferSyntax)
        case .h264, .h265:
            let excesses = VideoLevelLimits.excesses(
                of: stream, levelTimesTen: constraints.maximumLevelTimesTen)
            if stream.levelTimesTen > constraints.maximumLevelTimesTen {
                violations.append(.levelExceedsMaximum(
                    observed: stream.levelDescription,
                    maximum: levelDescription(constraints.maximumLevelTimesTen),
                    codec: stream.codec,
                    pictureFitsMaximum: excesses.isEmpty
                ))
            } else if !excesses.isEmpty {
                violations.append(.levelLimitsExceeded(
                    codec: stream.codec,
                    width: stream.width,
                    height: stream.height,
                    frameRate: stream.frameRate,
                    level: levelDescription(constraints.maximumLevelTimesTen),
                    excesses: excesses
                ))
            }
        case .unknown:
            break
        }

        // Chroma must be 4:2:0.
        if stream.chromaFormat != .yuv420 {
            violations.append(.chromaFormatNotPermitted(observed: stream.chromaFormat.displayName))
        }

        // Bit depth must be representable and must match the transfer syntax.
        if VideoBitDepth.forLumaBitDepth(stream.bitDepthLuma) == nil {
            violations.append(.bitDepthNotRepresentable(observed: stream.bitDepthLuma))
        } else if stream.bitDepthLuma != constraints.requiredBitDepth {
            violations.append(.bitDepthMismatch(
                observed: stream.bitDepthLuma,
                expected: constraints.requiredBitDepth,
                transferSyntax: transferSyntax.uid
            ))
        }

        // Pixels must be square, since Pixel Aspect Ratio must be absent. MPEG-2
        // Main Level is the exception (PS3.5 8.2.5 permits every aspect ratio
        // Main Level does), and High Level is checked by its own 16:9 rule.
        if stream.codec != .mpeg2, let sar = stream.sampleAspectRatio, sar.width != sar.height {
            violations.append(.anamorphicPixels(width: sar.width, height: sar.height))
        }

        // Declared geometry must match the bit stream.
        if let rows = declaredRows, let columns = declaredColumns,
           rows != stream.height || columns != stream.width {
            violations.append(.dimensionMismatch(
                declaredColumns: columns,
                declaredRows: rows,
                actualWidth: stream.width,
                actualHeight: stream.height
            ))
        }

        // Frame count must be positive.
        if let frames = numberOfFrames, frames < 1 {
            violations.append(.invalidFrameCount(observed: frames))
        }

        // The BD-compatible UID adds the Table 8-4 constraints.
        if constraints.requiresBluRayCompatibility {
            let frameRate = stream.frameRate ?? 0
            if !isBluRayCompatible(
                width: stream.width,
                height: stream.height,
                frameRate: frameRate,
                isProgressive: stream.isProgressive
            ) {
                violations.append(.notBluRayCompatible(
                    width: stream.width,
                    height: stream.height,
                    frameRate: frameRate,
                    isProgressive: stream.isProgressive
                ))
            }
        }

        // PS3.5 Table 8-8: frame packing is required for 3D and forbidden for 2D.
        // Nil means the pictures were not inspected; only "For 3D" then fails,
        // because its requirement is positive.
        switch baseUID(transferSyntax) {
        case TransferSyntax.mpeg4AVCHP42For3DVideo.uid where stream.hasFramePacking != true:
            violations.append(.framePackingRequired(transferSyntax: transferSyntax.uid))
        case TransferSyntax.mpeg4AVCHP42For2DVideo.uid where stream.hasFramePacking == true:
            violations.append(.framePackingNotPermitted(transferSyntax: transferSyntax.uid))
        default:
            break
        }

        return VideoConformanceResult(violations: violations)
    }

    /// Validates everything PS3.5 constrains about an input: the container, the
    /// video bit stream, any audio interleaved with it, and whether the payload
    /// fits the fragmentation the transfer syntax allows.
    ///
    /// - Parameters:
    ///   - probe: The probed input.
    ///   - transferSyntax: The transfer syntax the caller intends to write.
    ///   - payloadByteCount: The size of the bit stream to be encapsulated.
    public static func validate(
        probe: VideoProbeResult,
        transferSyntax: TransferSyntax,
        payloadByteCount: Int? = nil
    ) -> VideoConformanceResult {
        var violations: [VideoConformanceViolation] = []

        if !probe.container.isPermittedByDICOM {
            violations.append(.containerNotPermitted(observed: probe.container.displayName))
        }

        violations += validate(
            stream: probe.stream,
            transferSyntax: transferSyntax,
            numberOfFrames: probe.frameCount
        ).violations

        for (index, audio) in probe.audioTracks.enumerated() {
            for problem in VideoAudioRules.problems(
                with: audio, videoCodec: probe.stream.codec, container: probe.container
            ) {
                violations.append(.audioNotPermitted(
                    track: index + 1,
                    summary: audio.summary,
                    problem: problem,
                    videoCodec: probe.stream.codec
                ))
            }
        }

        if let bytes = payloadByteCount, bytes + bytes % 2 > maximumFragmentLength,
           !transferSyntax.allowsMultipleFragments {
            violations.append(.payloadExceedsSingleFragment(
                byteCount: bytes,
                transferSyntax: transferSyntax.uid,
                fragmentableAlternative: fragmentableVariant(of: transferSyntax)?.uid
            ))
        }

        return VideoConformanceResult(violations: violations)
    }

    /// The MPEG-2 rules: level ceiling, then the picture size, frame rate and
    /// aspect ratio tables of PS3.5 8.2.5 and 8.2.6.
    private static func mpeg2Violations(
        _ stream: VideoStreamInfo,
        constraints: Constraints,
        transferSyntax: TransferSyntax
    ) -> [VideoConformanceViolation] {
        var violations: [VideoConformanceViolation] = []

        // Level identifiers *descend* as levels rise (High is 4, Main is 8, Low
        // is 10), so a numerically smaller identifier is the higher level.
        let level = stream.levelTimesTen
        if level != 0, level < constraints.maximumLevelTimesTen {
            violations.append(.levelExceedsMaximum(
                observed: mpeg2LevelName(level),
                maximum: mpeg2LevelName(constraints.maximumLevelTimesTen),
                codec: .mpeg2,
                pictureFitsMaximum: false
            ))
        }

        let width = stream.width
        let height = stream.height
        let rate = stream.frameRate
        let rateText = rate.map { String(format: "%.3f", $0) + " fps" } ?? "an undeclared frame rate"
        let isHighLevel = constraints.maximumLevelTimesTen == 4
        func reject(_ detail: String) {
            violations.append(.mpeg2FormatNotPermitted(
                detail: detail, transferSyntax: transferSyntax.uid, isHighLevel: isHighLevel))
        }

        if isHighLevel {
            // Rows 720 or 1080, with Columns 1280 or 1920 to match.
            let geometryOK = (height == 720 && width == 1280) || (height == 1080 && width == 1920)
            if !geometryOK {
                reject("\(width)x\(height) is neither 1280x720 nor 1920x1080")
            }
            if let rate = rate {
                let permitted: [Double] = [25, 30000.0 / 1001.0, 30, 50, 60000.0 / 1001.0, 60]
                if !permitted.contains(where: { abs($0 - rate) < 0.01 }) {
                    reject("a frame rate of \(rateText) is not 25, 29.97, 30, 50, 59.94 or 60")
                } else if height == 1080, stream.isProgressive, rate > 30.01 {
                    reject("1920x1080 progressive at \(rateText) exceeds Main Profile / High Level")
                }
            }
            if let aspect = stream.mpeg2AspectRatioInformation, aspect != 3 {
                violations.append(.mpeg2AspectRatioNotPermitted(observed: aspect))
            }
        } else {
            // Table 8-1: 720 columns, and 576 rows at 25 Hz or 480 at 30 Hz.
            let maxRows = (rate ?? 25) > 25.01 ? 480 : 576
            if width > 720 || height > maxRows {
                reject("\(width)x\(height) at \(rateText) exceeds 720x\(maxRows)")
            }
            if let rate = rate, rate > 30.01 {
                reject("a frame rate of \(rateText) exceeds 30 fps")
            }
        }
        return violations
    }

    // MARK: - Transfer Syntax Selection

    /// The transfer syntaxes that could carry a stream, in preference order.
    ///
    /// Non-fragmentable forms first: they are always legal when the payload fits
    /// one fragment and are the simplest to write. For H.264, Level 4.1 (.102)
    /// before Level 4.2 (.104). The BD-compatible UID (.103) is never offered,
    /// since it adds constraints without adding capability.
    static func candidates(for stream: VideoStreamInfo) -> [TransferSyntax] {
        switch stream.codec {
        case .mpeg2:
            return [.mpeg2MainProfile, .mpeg2MainProfileHighLevel]
        case .h264:
            if stream.profileIDC == H264Parser.stereoHighProfileIDC { return [.mpeg4AVCStereoHP42] }
            if stream.hasFramePacking == true { return [.mpeg4AVCHP42For3DVideo] }
            return [.mpeg4AVCHP41, .mpeg4AVCHP42For2DVideo]
        case .h265:
            return stream.bitDepthLuma == 10 ? [.hevcH265Main10Profile] : [.hevcH265MainProfile]
        case .unknown:
            return []
        }
    }

    /// Chooses the transfer syntax that fits a probed bit stream.
    ///
    /// The first candidate the stream validates against wins, so a selection is
    /// always one the validator accepts: 1080p60 lands on Level 4.2 (.104), a
    /// frame-packed stream on "For 3D Video" (.105), an MVC stream on Stereo High
    /// (.106).
    ///
    /// - Returns: The transfer syntax, or nil when no video transfer syntax can
    ///   carry the stream.
    public static func selectTransferSyntax(for stream: VideoStreamInfo) -> TransferSyntax? {
        candidates(for: stream).first { candidate in
            validate(stream: stream, transferSyntax: candidate).isConformant
        }
    }

    /// Chooses the transfer syntax for a stream and payload size, moving to the
    /// fragmentable variant when the payload cannot fit one fragment.
    public static func selectTransferSyntax(
        for stream: VideoStreamInfo,
        payloadByteCount: Int
    ) -> TransferSyntax? {
        guard let selected = selectTransferSyntax(for: stream) else { return nil }
        guard payloadByteCount + payloadByteCount % 2 > maximumFragmentLength,
              !selected.allowsMultipleFragments
        else { return selected }
        return fragmentableVariant(of: selected)
    }

    /// The transfer syntax whose constraints best explain a rejection: the one
    /// the stream comes closest to fitting.
    public static func closestCandidate(for stream: VideoStreamInfo) -> TransferSyntax {
        switch stream.codec {
        case .h264:
            if stream.profileIDC == H264Parser.stereoHighProfileIDC { return .mpeg4AVCStereoHP42 }
            if stream.hasFramePacking == true { return .mpeg4AVCHP42For3DVideo }
            let fitsLevel41 = stream.levelTimesTen <= 41
                && VideoLevelLimits.excesses(of: stream, levelTimesTen: 41).isEmpty
            return fitsLevel41 ? .mpeg4AVCHP41 : .mpeg4AVCHP42For2DVideo
        case .h265:
            return stream.bitDepthLuma == 10 ? .hevcH265Main10Profile : .hevcH265MainProfile
        case .mpeg2:
            return stream.levelTimesTen == 4 || stream.height > 576
                ? .mpeg2MainProfileHighLevel : .mpeg2MainProfile
        case .unknown:
            return .mpeg4AVCHP41
        }
    }

    /// The "….1" twin of a non-fragmentable MPEG-2 or H.264 transfer syntax.
    /// HEVC has none; it is fragmentable already.
    public static func fragmentableVariant(of transferSyntax: TransferSyntax) -> TransferSyntax? {
        guard transferSyntax.isVideo, !transferSyntax.allowsMultipleFragments else { return nil }
        return TransferSyntax.from(uid: transferSyntax.uid + ".1")
    }

    // MARK: - Private

    /// The UID with any fragmentable ".1" suffix removed.
    private static func baseUID(_ transferSyntax: TransferSyntax) -> String {
        let uid = transferSyntax.uid
        return transferSyntax.isVideo && !transferSyntax.isH265 && uid.hasSuffix(".1")
            ? String(uid.dropLast(2)) : uid
    }

    /// Renders a level-times-ten value as "4.1".
    private static func levelDescription(_ levelTimesTen: Int) -> String {
        "\(levelTimesTen / 10).\(levelTimesTen % 10)"
    }

    /// Names an MPEG-2 level identifier, per ITU-T H.262 Table 8-11.
    private static func mpeg2LevelName(_ identifier: Int) -> String {
        switch identifier {
        case 10: return "Low"
        case 8: return "Main"
        case 6: return "High 1440"
        case 4: return "High"
        default: return "level \(identifier)"
        }
    }
}
