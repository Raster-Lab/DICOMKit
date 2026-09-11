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
/// Reference: PS3.5 Sections 8.2.5 - 8.2.11
public enum VideoConformanceViolation: Sendable, Hashable {

    /// The coded profile is not permitted by the transfer syntax.
    case profileNotPermitted(observed: String, observedIDC: Int, required: String, requiredIDC: Int)

    /// The coded level exceeds the transfer syntax's ceiling.
    case levelExceedsMaximum(observed: String, maximum: String)

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
        case let .levelExceedsMaximum(observed, maximum):
            return "level \(observed) exceeds the transfer syntax maximum of \(maximum)"
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
    /// while re-encoding degrades diagnostic imagery on every pass.
    public var remedy: String? {
        switch self {
        case let .profileNotPermitted(_, _, required, _):
            let profile = required.lowercased().replacingOccurrences(of: " ", with: "")
            return """
                ffmpeg -i input.mp4 -c:v libx264 -profile:v \(profile) -level 4.1 fixed.mp4
                """
        case .levelExceedsMaximum:
            return "ffmpeg -i input.mp4 -c:v libx264 -profile:v high -level 4.1 fixed.mp4"
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
        case .containerNotPermitted:
            return "ffmpeg -i input -c copy output.mp4"
        case .codecNotSupported, .codecMismatch, .dimensionMismatch, .invalidFrameCount:
            return nil
        }
    }
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
/// Reference: PS3.5 Sections 8.2.5 - 8.2.11
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

        // Level must not exceed the ceiling. MPEG-2 codes levels as descending
        // identifiers (High is 4, Main is 8), so the comparison inverts.
        if stream.codec == .mpeg2 {
            if stream.levelTimesTen != 0, stream.levelTimesTen > constraints.maximumLevelTimesTen {
                violations.append(.levelExceedsMaximum(
                    observed: mpeg2LevelName(stream.levelTimesTen),
                    maximum: mpeg2LevelName(constraints.maximumLevelTimesTen)
                ))
            }
        } else if stream.levelTimesTen > constraints.maximumLevelTimesTen {
            violations.append(.levelExceedsMaximum(
                observed: stream.levelDescription,
                maximum: levelDescription(constraints.maximumLevelTimesTen)
            ))
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

        // Pixels must be square, since Pixel Aspect Ratio must be absent.
        if let sar = stream.sampleAspectRatio, sar.width != sar.height {
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

        return VideoConformanceResult(violations: violations)
    }

    // MARK: - Transfer Syntax Selection

    /// Chooses the transfer syntax that fits a probed bit stream.
    ///
    /// Prefers the non-fragmentable form, which is always legal and simplest to
    /// write. For H.264 it prefers Level 4.1 (.102) and falls back to Level 4.2
    /// (.104), so 1080p60 is accepted rather than rejected — it is legal at 4.2.
    /// The BD-compatible UID (.103) is never chosen automatically, since it adds
    /// constraints without adding capability.
    ///
    /// - Returns: The transfer syntax, or nil when no video transfer syntax can
    ///   carry the stream.
    public static func selectTransferSyntax(for stream: VideoStreamInfo) -> TransferSyntax? {
        switch stream.codec {
        case .mpeg2:
            guard stream.profileIDC == 4 else { return nil }
            // Main Level (8) is the tighter of the two; High Level (4) covers HD.
            if stream.levelTimesTen >= 8 { return .mpeg2MainProfile }
            if stream.levelTimesTen >= 4 { return .mpeg2MainProfileHighLevel }
            return nil

        case .h264:
            if stream.profileIDC == 128 {
                return stream.levelTimesTen <= 42 ? .mpeg4AVCStereoHP42 : nil
            }
            guard stream.profileIDC == 100 else { return nil }
            if stream.levelTimesTen <= 41 { return .mpeg4AVCHP41 }
            if stream.levelTimesTen <= 42 { return .mpeg4AVCHP42For2DVideo }
            return nil

        case .h265:
            guard stream.levelTimesTen <= 51 else { return nil }
            switch stream.bitDepthLuma {
            case 8 where stream.profileIDC == 1: return .hevcH265MainProfile
            case 10 where stream.profileIDC == 2: return .hevcH265Main10Profile
            default: return nil
            }

        case .unknown:
            return nil
        }
    }

    // MARK: - Private

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
