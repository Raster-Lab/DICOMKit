// NEMA-verified: 2026a, checked 2026-10-01 — profile, level and BD flag of every video transfer syntax diffed by Scripts/diff_kit.py against the PS3.6 2026a Table A-1 names; BD formats per PS3.5 Table 8-4; MPEG-2 level ceiling compared as a level_identification (smaller is higher: MP@ML rejects High / High 1440); container rejection cites PS3.5 8.2.7-8.2.11 (H.264/HEVC only, D177); MPEG2 MP@HL Rows/Columns 720x1280 or 1080x1920 and aspect_ratio_information 0011 per PS3.5 2026a 8.2.6, MP@H-14 not offered .101 (D226); MPEG2 frame rate / maximum Rows x Columns per PS3.5 2026a Table 8-1 (2 rows), Table 8-2 (4 frame rates), Table 8-3 (1080 rows at 25 / 30 only), diffed by Scripts/diff_kit.py mpeg2-frame-rates (D238)
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

    /// MPEG2 Main Profile / High Level geometry outside PS3.5 2026a 8.2.6: "Rows (0028,0010)
    /// shall be either 720 or 1080", "Columns (0028,0011) shall be 1280 if Rows is 720, or
    /// shall be 1920 if Rows is 1080".
    case mpeg2HighLevelGeometryNotPermitted(rows: Int, columns: Int)

    /// MPEG2 Main Profile / High Level `aspect_ratio_information` other than 0011 (16:9),
    /// PS3.5 2026a 8.2.6: "The value of MPEG2 aspect_ratio_information shall be 0011".
    case mpeg2AspectRatioNotPermitted(observed: Int)

    /// MPEG2 frame rate outside PS3.5 2026a Table 8-1 (Main Level: 25, or 30 / 29.97) or
    /// Table 8-2 (High Level: 25, 30 / 29.97, 50, 60 / 59.94), or, at High Level with
    /// Rows 1080, other than 25 or 30 / 29.97 (8.2.6 Note 4, Table 8-3).
    /// `maximumLevel` is "Main" or "High".
    case mpeg2FrameRateNotPermitted(frameRate: Double, rows: Int, columns: Int, maximumLevel: String)

    /// MPEG2 Main Profile / Main Level Rows / Columns above the maximum PS3.5 2026a
    /// Table 8-1 gives for the frame rate (525-line NTSC 30: 480 x 720; 625-line PAL 25: 576 x 720).
    case mpeg2MainLevelGeometryExceedsMaximum(
        rows: Int, columns: Int, frameRate: Double, maximumRows: Int, maximumColumns: Int)

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
        case let .mpeg2HighLevelGeometryNotPermitted(rows, columns):
            return """
                \(columns)x\(rows) is not permitted for MPEG2 Main Profile / High Level: Rows \
                shall be 720 or 1080, Columns 1280 if Rows is 720 or 1920 if Rows is 1080 \
                (PS3.5 8.2.6)
                """
        case let .mpeg2AspectRatioNotPermitted(observed):
            let bits = String(observed, radix: 2)
            return """
                MPEG2 aspect_ratio_information is \(String(repeating: "0", count: max(0, 4 - bits.count)) + bits); \
                MPEG2 Main Profile / High Level requires 0011, a 16:9 display aspect ratio (PS3.5 8.2.6)
                """
        case let .mpeg2FrameRateNotPermitted(frameRate, rows, columns, maximumLevel):
            let rate = String(format: "%.3f", frameRate)
            if maximumLevel == "High" {
                if rows == 1080 {
                    return """
                        \(columns)x\(rows) at \(rate) fps is not permitted for MPEG2 Main Profile / High Level: \
                        at 1080 rows the frame rate shall be 25 or 30 (29.97) (PS3.5 8.2.6, Table 8-3)
                        """
                }
                return """
                    \(rate) fps is not permitted for MPEG2 Main Profile / High Level: the frame rate \
                    shall be 25, 30 (29.97), 50 or 60 (59.94) (PS3.5 Table 8-2)
                    """
            }
            return """
                \(rate) fps is not permitted for MPEG2 Main Profile / Main Level: the frame rate \
                shall be 30 (29.97, 525-line NTSC) or 25 (625-line PAL) (PS3.5 Table 8-1)
                """
        case let .mpeg2MainLevelGeometryExceedsMaximum(rows, columns, frameRate, maximumRows, maximumColumns):
            return """
                \(columns)x\(rows) at \(String(format: "%.3f", frameRate)) fps exceeds the MPEG2 Main Profile / \
                Main Level maximum of \(maximumColumns)x\(maximumRows) for that frame rate (PS3.5 Table 8-1)
                """
        case let .containerNotPermitted(observed):
            return """
                \(observed) is not a permitted container; an H.264 or HEVC video \
                bit stream shall be in an MPEG-2 Transport Stream or MP4 container \
                (PS3.5 8.2.7-8.2.11)
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
        case .mpeg2HighLevelGeometryNotPermitted, .mpeg2AspectRatioNotPermitted:
            return """
                ffmpeg -i input -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1" \
                -aspect 16:9 -c:v mpeg2video -profile:v main -level:v high fixed.mpg
                """
        case let .mpeg2FrameRateNotPermitted(_, rows, _, maximumLevel):
            if maximumLevel == "High" {
                let rate = rows == 1080 ? "25" : "50"
                return "ffmpeg -i input -r \(rate) -aspect 16:9 -c:v mpeg2video -profile:v main -level:v high fixed.mpg"
            }
            return "ffmpeg -i input -r 25 -vf scale=720:576 -c:v mpeg2video -profile:v main -level:v main fixed.mpg"
        case .mpeg2MainLevelGeometryExceedsMaximum:
            return """
                ffmpeg -i input -vf "scale=720:576:force_original_aspect_ratio=decrease,pad=720:576:(ow-iw)/2:(oh-ih)/2" \
                -r 25 -c:v mpeg2video -profile:v main -level:v main fixed.mpg
                """
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

    // MARK: - MPEG2 Frame Rates (PS3.5 2026a Tables 8-1, 8-2, 8-3)

    /// A row of PS3.5 2026a Table 8-1 "MPEG2 Main Profile / Main Level Image Transfer Syntax
    /// Rows and Columns Attributes".
    public struct MPEG2MainLevelFormat: Sendable, Equatable {
        public let videoType: String
        /// The nominal frame rate; 30 also admits 30/1.001 (Table 8-1 Note 4).
        public let frameRate: Double
        public let maximumRows: Int
        public let maximumColumns: Int
    }

    /// PS3.5 2026a Table 8-1 (checked by Scripts/diff_kit.py, check "mpeg2-frame-rates").
    public static let mpeg2MainLevelFormats: [MPEG2MainLevelFormat] = [
        MPEG2MainLevelFormat(videoType: "525-line NTSC", frameRate: 30, maximumRows: 480, maximumColumns: 720),
        MPEG2MainLevelFormat(videoType: "625-line PAL", frameRate: 25, maximumRows: 576, maximumColumns: 720),
    ]

    /// PS3.5 2026a Table 8-2 "MPEG2 Main Profile / High Level Image Transfer Syntax Frame Rate
    /// Attributes": video type and nominal frame rate; 30 and 60 also admit 30/1.001 and
    /// 60/1.001 (8.2.6 Note 2).
    public static let mpeg2HighLevelFrameRates: [(videoType: String, frameRate: Double)] = [
        (videoType: "30 Hz HD", frameRate: 30),
        (videoType: "25 Hz HD", frameRate: 25),
        (videoType: "60 Hz HD", frameRate: 60),
        (videoType: "50 Hz HD", frameRate: 50),
    ]

    /// Nominal frame rates PS3.5 2026a Table 8-3 lists for Rows 1080 / Columns 1920 (progressive
    /// or interlaced); 8.2.6 Note 4: "Frame rates of 50 Hz and 60 Hz (progressive) at the maximum
    /// resolution of 1080 by 1920 are not supported by Main Profile / High Level".
    public static let mpeg2HighLevel1080FrameRates: [Double] = [25, 30]

    /// Whether an observed frame rate is the nominal one, or 1/1.001 of a nominal 30 or 60
    /// (PS3.5 2026a 8.2.5 Note 4, 8.2.6 Note 2).
    static func mpeg2FrameRate(_ observed: Double, matches nominal: Double) -> Bool {
        if abs(observed - nominal) < 0.01 { return true }
        return (nominal == 30 || nominal == 60) && abs(observed - nominal / 1.001) < 0.01
    }

    /// The Table 8-1 / 8-2 / 8-3 violations of an MPEG2 stream, or none when the frame rate is
    /// unknown. `highLevel` selects MP@HL (Tables 8-2, 8-3) over MP@ML (Table 8-1).
    static func mpeg2FrameRateViolations(
        frameRate: Double?, rows: Int, columns: Int, highLevel: Bool
    ) -> [VideoConformanceViolation] {
        guard let rate = frameRate, rate > 0 else { return [] }
        if highLevel {
            let permitted = rows == 1080
                ? mpeg2HighLevel1080FrameRates
                : mpeg2HighLevelFrameRates.map(\.frameRate)
            if permitted.contains(where: { mpeg2FrameRate(rate, matches: $0) }) { return [] }
            return [.mpeg2FrameRateNotPermitted(frameRate: rate, rows: rows, columns: columns, maximumLevel: "High")]
        }
        guard let format = mpeg2MainLevelFormats.first(where: { mpeg2FrameRate(rate, matches: $0.frameRate) }) else {
            return [.mpeg2FrameRateNotPermitted(frameRate: rate, rows: rows, columns: columns, maximumLevel: "Main")]
        }
        if rows > format.maximumRows || columns > format.maximumColumns {
            return [.mpeg2MainLevelGeometryExceedsMaximum(
                rows: rows, columns: columns, frameRate: rate,
                maximumRows: format.maximumRows, maximumColumns: format.maximumColumns)]
        }
        return []
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
        // identifiers (ISO/IEC 13818-2 Table 8-11: High 4, High 1440 6, Main 8, Low 10),
        // so a higher level is a *smaller* identifier and the comparison inverts.
        if stream.codec == .mpeg2 {
            if stream.levelTimesTen != 0, stream.levelTimesTen < constraints.maximumLevelTimesTen {
                violations.append(.levelExceedsMaximum(
                    observed: VideoStreamInfo.mpeg2LevelName(stream.levelTimesTen),
                    maximum: VideoStreamInfo.mpeg2LevelName(constraints.maximumLevelTimesTen)
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

        // MPEG2 MP@HL (PS3.5 2026a 8.2.6): Rows 720 with Columns 1280, or Rows 1080 with
        // Columns 1920, and aspect_ratio_information 0011 (16:9). A Main Level stream offered
        // under .101 passes the level ceiling (a decoder of a higher level decodes it) but
        // not this geometry rule.
        if stream.codec == .mpeg2, constraints.maximumLevelTimesTen == 4 {
            let rows = declaredRows ?? stream.height
            let columns = declaredColumns ?? stream.width
            if !((rows == 720 && columns == 1280) || (rows == 1080 && columns == 1920)) {
                violations.append(.mpeg2HighLevelGeometryNotPermitted(rows: rows, columns: columns))
            }
            if let aspect = stream.mpeg2AspectRatioInformation, aspect != 0b0011 {
                violations.append(.mpeg2AspectRatioNotPermitted(observed: aspect))
            }
        }

        // MPEG2 frame rate / geometry (PS3.5 2026a Table 8-1 for MP@ML; Table 8-2, 8.2.6
        // Note 4 and Table 8-3 for MP@HL): "Rows, Columns, Cine Rate and Frame Time ... shall be
        // consistent with the limitations of Main Profile / Main Level" / "High Level".
        if stream.codec == .mpeg2 {
            violations += mpeg2FrameRateViolations(
                frameRate: stream.frameRate,
                rows: declaredRows ?? stream.height,
                columns: declaredColumns ?? stream.width,
                highLevel: constraints.maximumLevelTimesTen == 4)
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
            if stream.levelTimesTen >= 8 {
                // PS3.5 2026a Table 8-1: 25 or 30 (29.97) fps within that rate's maximum geometry.
                return mpeg2FrameRateViolations(frameRate: stream.frameRate, rows: stream.height,
                                                columns: stream.width, highLevel: false).isEmpty
                    ? .mpeg2MainProfile : nil
            }
            // High Level (4) only; MP@H-14 (6) "is not supported by this Transfer Syntax"
            // (PS3.5 2026a 8.2.6), and neither is a geometry other than 1280x720 / 1920x1080
            // nor a frame rate outside Table 8-2 / Table 8-3.
            if stream.levelTimesTen == 4,
               (stream.height == 720 && stream.width == 1280) || (stream.height == 1080 && stream.width == 1920),
               mpeg2FrameRateViolations(frameRate: stream.frameRate, rows: stream.height,
                                        columns: stream.width, highLevel: true).isEmpty {
                return .mpeg2MainProfileHighLevel
            }
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

}
