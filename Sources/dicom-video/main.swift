import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

// The conversion, probing, validation and extraction logic all live in the
// DICOMKit library (Sources/DICOMKit/Video/) so this CLI and DICOMStudio run the
// same code. This file is a thin adapter: parse argv, call the library, print.

// MARK: - Exit Codes

/// Exit codes, so scripts can tell "broken" from "not DICOM-legal".
///
/// 0 success, 1 I/O or usage error, 2 conformance rejection.
private enum VideoExit {
    static let conformanceRejection = ExitCode(2)
}

// MARK: - Shared Output Helpers

private func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

private func printWarning(_ message: String) {
    FileHandle.standardError.write(Data(("warning: " + message + "\n").utf8))
}

private func printNote(_ message: String) {
    FileHandle.standardError.write(Data(("note: " + message + "\n").utf8))
}

// MARK: - Main Command

struct DICOMVideo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-video",
        abstract: "Convert H.264/HEVC/MPEG-2 video to and from DICOM Video IODs",
        discussion: """
            Wraps an already-conformant video bitstream in a DICOM Video IOD without
            re-encoding it, and extracts it back out. Remuxing preserves the camera's
            pixel data bit-for-bit; non-conformant input is rejected with the specific
            violated constraint rather than silently re-encoded.

            Examples:
              # Convert a clip, letting the transfer syntax be detected
              dicom-video convert clip.mp4 --output clip.dcm

              # Inspect a clip without writing anything
              dicom-video probe clip.mp4

              # Check conformance without producing an object
              dicom-video convert clip.mp4 --output clip.dcm --dry-run

              # Convert a folder of clips as one series
              dicom-video batch clips/ --output-dir out/ --patient-name "Doe^Jane"

              # Extract the bitstream back out
              dicom-video extract clip.dcm --output clip.mp4

            Exit codes: 0 success, 1 I/O or usage error, 2 conformance rejection.
            """,
        version: "1.0.0",
        subcommands: [
            Convert.self,
            Batch.self,
            Extract.self,
            Probe.self
        ]
    )
}

// MARK: - Shared Options

/// Patient, study and series attributes shared by convert and batch.
struct MetadataOptions: ParsableArguments {
    @Option(name: .long, help: "Patient Name, in DICOM caret form (e.g. Doe^Jane)")
    var patientName: String?

    @Option(name: .long, help: "Patient ID")
    var patientID: String?

    @Option(name: .long, help: "Patient's Birth Date (YYYYMMDD)")
    var patientBirthDate: String?

    @Option(name: .long, help: "Patient's Sex (M, F or O)")
    var patientSex: String?

    @Option(name: .long, help: "Study Instance UID (generated if not given)")
    var studyUID: String?

    @Option(name: .long, help: "Series Instance UID (generated if not given)")
    var seriesUID: String?

    @Option(name: .long, help: "Accession Number")
    var accessionNumber: String?

    @Option(name: .long, help: "Study ID")
    var studyID: String?

    @Option(name: .long, help: "Referring Physician's Name")
    var referringPhysician: String?

    @Option(name: .long, help: "Series Description")
    var seriesDescription: String?

    @Option(name: .long, help: "Modality (overrides the video type's default)")
    var modality: String?

    @Option(name: .long, help: "Manufacturer")
    var manufacturer: String?

    @Option(name: .long, help: "Institution Name")
    var institutionName: String?
}

/// The video type, which selects the SOP class.
enum VideoTypeArgument: String, ExpressibleByArgument, CaseIterable {
    case endoscopic
    case microscopic
    case photographic

    var videoType: VideoType {
        switch self {
        case .endoscopic: return .endoscopic
        case .microscopic: return .microscopic
        case .photographic: return .photographic
        }
    }

    /// The SOP class's human-readable name, for the default-type notice.
    var sopClassName: String {
        switch self {
        case .endoscopic: return "Video Endoscopic Image Storage"
        case .microscopic: return "Video Microscopic Image Storage"
        case .photographic: return "Video Photographic Image Storage"
        }
    }
}

// MARK: - Conversion Engine

/// Everything the CLI needs to write one object, shared by convert and batch.
struct VideoConversionPlan {
    let probe: VideoProbeResult
    let transferSyntax: TransferSyntax
    let bitstream: Data
}

private enum ConversionFailure: Error {
    /// The input could not be read or understood at all.
    case inputError(String)
    /// The input is understood but is not DICOM-legal.
    case conformance(String)

    var message: String {
        switch self {
        case let .inputError(text): return text
        case let .conformance(text): return text
        }
    }
}

/// Probes an input and selects a transfer syntax, rejecting non-conformant input.
private func planConversion(
    bitstream: Data,
    explicitTransferSyntax: String?,
    trustInput: Bool,
    frameRateOverride: Double?
) throws -> VideoConversionPlan {
    let probe: VideoProbeResult
    do {
        probe = try VideoProbe.probe(bitstream, trustInput: trustInput)
    } catch let error as VideoProbeError {
        // A non-video or unreadable input is an input problem, except the
        // conformance-shaped cases, which scripts should see as rejections.
        switch error {
        case .notVideo, .unsupportedCodec, .multipleVideoTracks:
            throw ConversionFailure.conformance(error.message)
        default:
            throw ConversionFailure.inputError(error.message)
        }
    }

    // The container itself must be one DICOM blesses.
    guard probe.container.isPermittedByDICOM else {
        let violation = VideoConformanceViolation.containerNotPermitted(
            observed: probe.container.displayName)
        var text = "error: \(violation.message)"
        if let remedy = violation.remedy { text += "\n\n       \(remedy)" }
        throw ConversionFailure.conformance(text)
    }

    // A trusted transport stream skips validation by definition: nothing was read.
    if trustInput, probe.container == .mpegTS {
        guard let uidString = explicitTransferSyntax,
              let syntax = TransferSyntax.from(uid: uidString), syntax.isVideo else {
            throw ConversionFailure.inputError("""
                error: --trust-input requires an explicit --transfer-syntax, because \
                an unvalidated transport stream declares nothing about itself.
                """)
        }
        return VideoConversionPlan(probe: probe, transferSyntax: syntax, bitstream: bitstream)
    }

    // An explicit transfer syntax is honoured but still validated: a mislabelled
    // object is worse than a rejected one.
    let transferSyntax: TransferSyntax
    if let uidString = explicitTransferSyntax {
        guard let syntax = TransferSyntax.from(uid: uidString) else {
            throw ConversionFailure.inputError(
                "error: '\(uidString)' is not a recognized transfer syntax UID.")
        }
        guard syntax.isVideo else {
            throw ConversionFailure.inputError("""
                error: transfer syntax \(uidString) is not a video transfer syntax.
                """)
        }
        transferSyntax = syntax
    } else {
        guard let selected = probe.suggestedTransferSyntax else {
            // Nothing fits, so report why against the closest candidate rather
            // than a bare "unsupported".
            let candidate = candidateSyntax(for: probe.stream)
            let result = VideoConformanceValidator.validate(
                stream: probe.stream,
                transferSyntax: candidate,
                numberOfFrames: probe.frameCount
            )
            throw ConversionFailure.conformance(
                result.isConformant
                    ? "error: no DICOM video transfer syntax can carry this stream."
                    : result.report)
        }
        transferSyntax = selected
    }

    var stream = probe.stream
    if let override = frameRateOverride {
        guard override > 0, override < 1000 else {
            throw ConversionFailure.inputError(
                "error: --frame-rate \(override) is not a plausible frame rate.")
        }
        stream = VideoStreamInfo(
            codec: stream.codec, width: stream.width, height: stream.height,
            profileIDC: stream.profileIDC, levelTimesTen: stream.levelTimesTen,
            chromaFormat: stream.chromaFormat,
            bitDepthLuma: stream.bitDepthLuma, bitDepthChroma: stream.bitDepthChroma,
            frameRate: override, isProgressive: stream.isProgressive,
            sampleAspectRatio: stream.sampleAspectRatio
        )
    }

    let result = VideoConformanceValidator.validate(
        stream: stream,
        transferSyntax: transferSyntax,
        numberOfFrames: probe.frameCount
    )
    guard result.isConformant else {
        throw ConversionFailure.conformance(result.report)
    }

    let resolved = VideoProbeResult(
        container: probe.container,
        stream: stream,
        frameCount: probe.frameCount,
        frameCountSource: probe.frameCountSource,
        audioTrackCount: probe.audioTrackCount,
        suggestedTransferSyntax: transferSyntax,
        frameRate: stream.frameRate
    )
    return VideoConversionPlan(probe: resolved, transferSyntax: transferSyntax, bitstream: bitstream)
}

/// The transfer syntax whose constraints best explain a rejection.
private func candidateSyntax(for stream: VideoStreamInfo) -> TransferSyntax {
    switch stream.codec {
    case .h264: return .mpeg4AVCHP41
    case .h265: return stream.bitDepthLuma == 10 ? .hevcH265Main10Profile : .hevcH265MainProfile
    case .mpeg2: return .mpeg2MainProfile
    case .unknown: return .mpeg4AVCHP41
    }
}

/// The current date and time as DICOM values.
private func currentDateAndTime() -> (DICOMDate, DICOMTime) {
    let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: Date())
    let date = DICOMDate(
        year: components.year ?? 1970,
        month: components.month ?? 1,
        day: components.day ?? 1
    )
    let time = DICOMTime(
        hour: components.hour ?? 0,
        minute: components.minute ?? 0,
        second: components.second ?? 0
    )
    return (date, time)
}

/// Builds the DICOM object for a planned conversion.
private func buildVideo(
    plan: VideoConversionPlan,
    videoType: VideoType,
    metadata: MetadataOptions,
    studyUID: String,
    seriesUID: String,
    seriesNumber: Int,
    instanceNumber: Int
) throws -> Video {
    let stream = plan.probe.stream
    let builder = VideoBuilder(
        videoType: videoType,
        rows: stream.height,
        columns: stream.width,
        numberOfFrames: max(1, plan.probe.frameCount),
        studyInstanceUID: studyUID,
        seriesInstanceUID: seriesUID
    )

    builder.setSeriesNumber(seriesNumber)
    builder.setInstanceNumber(instanceNumber)
    builder.setPixelData(plan.bitstream)
    builder.setLossyCompression(codec: plan.probe.stream.codec)

    // Bit depth follows the bitstream, so a Main 10 source gets 16/10/9.
    builder.setBitDepthForLumaBitDepth(stream.bitDepthLuma)

    if let frameRate = plan.probe.frameRate, frameRate > 0 {
        builder.setFrameTime(1000.0 / frameRate)
        builder.setCineRate(Int(frameRate.rounded()))
        builder.setRecommendedDisplayFrameRate(Int(frameRate.rounded()))
    }

    if let value = metadata.patientName { builder.setPatientName(value) }
    if let value = metadata.patientID { builder.setPatientID(value) }
    if let value = metadata.patientSex { builder.setPatientSex(value) }
    if let value = metadata.accessionNumber { builder.setAccessionNumber(value) }
    if let value = metadata.studyID { builder.setStudyID(value) }
    if let value = metadata.referringPhysician { builder.setReferringPhysicianName(value) }
    if let value = metadata.seriesDescription { builder.setSeriesDescription(value) }
    if let value = metadata.modality { builder.setModality(value) }
    if let value = metadata.manufacturer { builder.setManufacturer(value) }
    if let value = metadata.institutionName { builder.setInstitutionName(value) }
    if let value = metadata.patientBirthDate, let date = DICOMDate.parse(value) {
        builder.setPatientBirthDate(date)
    }

    let (today, now) = currentDateAndTime()
    builder.setContentDate(today)
    builder.setContentTime(now)
    builder.setStudyDateTime(date: today, time: now)
    builder.setAcquisitionDateTime(date: today, time: now)

    return try builder.build()
}

/// Renders a probe result as a human-readable report.
private func describe(_ probe: VideoProbeResult, transferSyntax: TransferSyntax?) -> String {
    var lines: [String] = []
    lines.append("Container:        \(probe.container.displayName)")
    lines.append("Codec:            \(probe.stream.codec.displayName)")
    if probe.stream.codec != .unknown {
        lines.append("Profile:          \(probe.stream.profileName)")
        lines.append("Level:            \(probe.stream.levelDescription)")
        lines.append("Resolution:       \(probe.stream.width)x\(probe.stream.height)")
        lines.append("Chroma:           \(probe.stream.chromaFormat.displayName)")
        lines.append("Bit depth:        \(probe.stream.bitDepthLuma)-bit")
        lines.append("Scan:             \(probe.stream.isProgressive ? "progressive" : "interlaced")")
    }
    if let frameRate = probe.frameRate {
        lines.append("Frame rate:       \(String(format: "%.3f", frameRate)) fps")
    } else {
        lines.append("Frame rate:       not declared")
    }
    lines.append("Frames:           \(probe.frameCount) (\(probe.frameCountSource.rawValue))")
    if probe.audioTrackCount > 0 {
        lines.append("Audio tracks:     \(probe.audioTrackCount) (discarded; DICOM video has no audio)")
    }
    if let syntax = transferSyntax {
        lines.append("Transfer syntax:  \(syntax.uid)")
        lines.append("                  \(syntax.displayName)")
    }
    return lines.joined(separator: "\n")
}

// MARK: - Convert Subcommand

extension DICOMVideo {
    struct Convert: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "convert",
            abstract: "Wrap a video bitstream in a DICOM Video IOD"
        )

        @Argument(help: "Input video file (MP4, MOV, TS, or a raw elementary stream)")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .long, help: "Video type: endoscopic, microscopic or photographic")
        var type: VideoTypeArgument?

        @Option(name: .long, help: "Transfer Syntax UID (auto-detected by default)")
        var transferSyntax: String?

        @Option(name: .long, help: "Override the probed frame rate (validated)")
        var frameRate: Double?

        @Option(name: .long, help: "Instance Number (default: 1)")
        var instanceNumber: Int = 1

        @Option(name: .long, help: "Series Number (default: 1)")
        var seriesNumber: Int = 1

        @Flag(name: .long, help: "Probe and validate only; write nothing")
        var dryRun: Bool = false

        @Flag(name: .long, help: "Encapsulate a transport stream without validating it")
        var trustInput: Bool = false

        @Flag(name: .long, help: "Overwrite the output file if it exists")
        var force: Bool = false

        @OptionGroup var metadata: MetadataOptions

        mutating func run() throws {
            let inputURL = URL(fileURLWithPath: input)
            guard let bitstream = FileManager.default.contents(atPath: inputURL.path) else {
                printError("error: cannot read '\(input)'.")
                throw ExitCode(1)
            }

            // A wrong --type yields a valid but mislabelled object, so the default
            // is announced rather than applied silently.
            let resolvedType = type ?? .endoscopic
            if type == nil {
                printNote("""
                    Using SOP class \(resolvedType.sopClassName) \
                    (modality \(resolvedType.videoType.defaultModality)).
                          Override with --type microscopic|photographic.
                    """)
            }

            let plan: VideoConversionPlan
            do {
                plan = try planConversion(
                    bitstream: bitstream,
                    explicitTransferSyntax: transferSyntax,
                    trustInput: trustInput,
                    frameRateOverride: frameRate
                )
            } catch let failure as ConversionFailure {
                printError(failure.message)
                switch failure {
                case .conformance: throw VideoExit.conformanceRejection
                case .inputError: throw ExitCode(1)
                }
            }

            if plan.probe.audioTrackCount > 0 {
                printWarning("""
                    input has \(plan.probe.audioTrackCount) audio track\
                    \(plan.probe.audioTrackCount == 1 ? "" : "s"); \
                    DICOM video has no audio, discarding.
                    """)
            }

            if dryRun {
                print(describe(plan.probe, transferSyntax: plan.transferSyntax))
                print("\nDry run: conformant, nothing written.")
                return
            }

            let outputURL = URL(fileURLWithPath: output)
            if FileManager.default.fileExists(atPath: outputURL.path), !force {
                printError("error: '\(output)' already exists. Pass --force to overwrite.")
                throw ExitCode(1)
            }

            let video = try buildVideo(
                plan: plan,
                videoType: resolvedType.videoType,
                metadata: metadata,
                studyUID: metadata.studyUID ?? UIDGenerator.generateStudyInstanceUID().value,
                seriesUID: metadata.seriesUID ?? UIDGenerator.generateSeriesInstanceUID().value,
                seriesNumber: seriesNumber,
                instanceNumber: instanceNumber
            )

            let file = DICOMFile.create(
                dataSet: video.toDataSet(),
                sopClassUID: video.sopClassUID,
                sopInstanceUID: video.sopInstanceUID,
                transferSyntaxUID: plan.transferSyntax.uid
            )

            do {
                try file.write().write(to: outputURL)
            } catch {
                printError("error: cannot write '\(output)': \(error.localizedDescription)")
                throw ExitCode(1)
            }

            print("Wrote \(output)")
            print(describe(plan.probe, transferSyntax: plan.transferSyntax))
        }
    }
}

// MARK: - Probe Subcommand

extension DICOMVideo {
    struct Probe: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "probe",
            abstract: "Report a video's geometry, profile, level and conformance"
        )

        @Argument(help: "Input video file")
        var input: String

        @Flag(name: .long, help: "Treat a transport stream as conformant without validating it")
        var trustInput: Bool = false

        mutating func run() throws {
            guard let bitstream = FileManager.default.contents(
                atPath: URL(fileURLWithPath: input).path) else {
                printError("error: cannot read '\(input)'.")
                throw ExitCode(1)
            }

            let probe: VideoProbeResult
            do {
                probe = try VideoProbe.probe(bitstream, trustInput: trustInput)
            } catch let error as VideoProbeError {
                printError(error.message)
                throw ExitCode(1)
            }

            print(describe(probe, transferSyntax: probe.suggestedTransferSyntax))

            guard let syntax = probe.suggestedTransferSyntax else {
                print("\nConformance:      no DICOM video transfer syntax carries this stream")
                let result = VideoConformanceValidator.validate(
                    stream: probe.stream,
                    transferSyntax: candidateSyntax(for: probe.stream),
                    numberOfFrames: probe.frameCount
                )
                if !result.isConformant {
                    print("")
                    print(result.report)
                }
                throw VideoExit.conformanceRejection
            }

            let result = VideoConformanceValidator.validate(
                stream: probe.stream, transferSyntax: syntax, numberOfFrames: probe.frameCount)
            if result.isConformant {
                print("\nConformance:      OK")
            } else {
                print("")
                print(result.report)
                throw VideoExit.conformanceRejection
            }
        }
    }
}

// MARK: - Extract Subcommand

extension DICOMVideo {
    struct Extract: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "extract",
            abstract: "Recover the video bitstream from a DICOM Video object"
        )

        @Argument(help: "Input DICOM file")
        var input: String

        @Option(name: .shortAndLong, help: "Output video file path")
        var output: String

        @Flag(name: .long, help: "Overwrite the output file if it exists")
        var force: Bool = false

        mutating func run() throws {
            guard let data = FileManager.default.contents(
                atPath: URL(fileURLWithPath: input).path) else {
                printError("error: cannot read '\(input)'.")
                throw ExitCode(1)
            }

            let file: DICOMFile
            do {
                file = try DICOMFile.read(from: data)
            } catch {
                printError("error: '\(input)' is not a readable DICOM file.")
                throw ExitCode(1)
            }

            let extracted: ExtractedVideo
            do {
                extracted = try VideoExtractor.extract(from: file)
            } catch let error as VideoExtractionError {
                printError(error.message)
                throw ExitCode(1)
            }

            let outputURL = URL(fileURLWithPath: output)
            if FileManager.default.fileExists(atPath: outputURL.path), !force {
                printError("error: '\(output)' already exists. Pass --force to overwrite.")
                throw ExitCode(1)
            }

            // A mismatched extension is a warning, not an error: the user may
            // have a reason, but a .mp4 holding an elementary stream will not play.
            let givenExtension = outputURL.pathExtension.lowercased()
            if !givenExtension.isEmpty, givenExtension != extracted.suggestedFileExtension {
                printWarning("""
                    payload is \(extracted.container.displayName); \
                    '.\(extracted.suggestedFileExtension)' would suit it better than \
                    '.\(givenExtension)'.
                    """)
            }

            do {
                try extracted.bitstream.write(to: outputURL)
            } catch {
                printError("error: cannot write '\(output)': \(error.localizedDescription)")
                throw ExitCode(1)
            }

            print("Wrote \(output) (\(extracted.bitstream.count) bytes)")
            print("Codec:            \(extracted.codec.displayName)")
            print("Container:        \(extracted.container.displayName)")
            print("Transfer syntax:  \(extracted.transferSyntax.uid)")
        }
    }
}

// MARK: - Batch Subcommand

/// How a batch run groups its outputs into series.
enum SeriesMode: String, ExpressibleByArgument, CaseIterable {
    /// One series for every clip. IHE ENDO 3.10.4.1.1.1 makes this the correct
    /// default: one procedure step on one piece of equipment is one series, and
    /// that holds even when the endoscope is swapped mid-procedure.
    case single
    /// A fresh series per clip, for clips from different procedure steps or
    /// different equipment, where IHE requires separate series.
    case perFile = "per-file"
}

extension DICOMVideo {
    struct Batch: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "batch",
            abstract: "Convert a directory of clips into DICOM Video objects",
            discussion: """
                Clips are converted in natural-sort order, so clip2 precedes clip10.

                --series-mode single (the default) puts every clip in one series,
                which is what IHE Endoscopy Image Archiving 3.10.4.1.1.1 requires of
                clips from one procedure step on one piece of equipment.

                --series-mode per-file gives each clip its own series, for clips from
                different procedure steps or different equipment, where IHE requires
                separate series.
                """
        )

        @Argument(help: "Directory of video files")
        var inputDirectory: String

        @Option(name: .long, help: "Directory to write DICOM files into")
        var outputDir: String

        @Option(name: .long, help: "Series grouping: single (default) or per-file")
        var seriesMode: SeriesMode = .single

        @Option(name: .long, help: "Video type: endoscopic, microscopic or photographic")
        var type: VideoTypeArgument?

        @Option(name: .long, help: "Transfer Syntax UID (auto-detected by default)")
        var transferSyntax: String?

        @Flag(name: .long, help: "Descend into subdirectories")
        var recursive: Bool = false

        @Flag(name: .long, help: "Skip failures and convert the rest")
        var continueOnError: Bool = false

        @Flag(name: .long, help: "Overwrite existing output files")
        var force: Bool = false

        @Flag(name: .long, help: "Probe and validate only; write nothing")
        var dryRun: Bool = false

        @OptionGroup var metadata: MetadataOptions

        /// Extensions worth attempting. Content is sniffed afterwards, so a stray
        /// file with a video extension is still rejected on its bytes.
        private static let videoExtensions: Set<String> = [
            "mp4", "m4v", "mov", "ts", "m2ts", "mts",
            "264", "h264", "265", "hevc", "h265", "m2v", "mpv", "mpg", "mpeg",
        ]

        mutating func run() throws {
            let inputURL = URL(fileURLWithPath: inputDirectory)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                printError("error: '\(inputDirectory)' is not a directory.")
                throw ExitCode(1)
            }

            // An explicit --series-uid contradicts per-file, which mints a new UID
            // per clip. Rejecting beats silently ignoring the flag.
            if seriesMode == .perFile, metadata.seriesUID != nil {
                printError("""
                    error: --series-uid cannot be combined with --series-mode per-file, \
                    which generates a new Series Instance UID for every clip.
                    """)
                throw ExitCode(1)
            }

            let files = try discoverInputs(in: inputURL)
            guard !files.isEmpty else {
                printError("error: no video files found in '\(inputDirectory)'.")
                throw ExitCode(1)
            }

            let outputURL = URL(fileURLWithPath: outputDir)
            if !dryRun {
                try FileManager.default.createDirectory(
                    at: outputURL, withIntermediateDirectories: true)
            }

            let resolvedType = type ?? .endoscopic
            if type == nil {
                printNote("""
                    Using SOP class \(resolvedType.sopClassName) \
                    (modality \(resolvedType.videoType.defaultModality)).
                          Override with --type microscopic|photographic.
                    """)
            }

            // Both modes share one Study Instance UID: a batch is one patient visit.
            let studyUID = metadata.studyUID ?? UIDGenerator.generateStudyInstanceUID().value
            let sharedSeriesUID = metadata.seriesUID ?? UIDGenerator.generateSeriesInstanceUID().value

            var converted = 0
            var skipped: [(name: String, reason: String)] = []

            for url in files {
                let name = url.lastPathComponent
                do {
                    guard let bitstream = FileManager.default.contents(atPath: url.path) else {
                        throw ConversionFailure.inputError("cannot read the file")
                    }

                    let plan = try planConversion(
                        bitstream: bitstream,
                        explicitTransferSyntax: transferSyntax,
                        trustInput: false,
                        frameRateOverride: nil
                    )

                    guard !dryRun else {
                        converted += 1
                        print("\(name): OK (\(plan.transferSyntax.uid))")
                        continue
                    }

                    // Numbering follows successful conversions, so a skipped clip
                    // leaves no gap in InstanceNumber.
                    let instanceNumber = seriesMode == .single ? converted + 1 : 1
                    let seriesNumber = seriesMode == .single ? 1 : converted + 1
                    let seriesUID = seriesMode == .single
                        ? sharedSeriesUID
                        : UIDGenerator.generateSeriesInstanceUID().value

                    let video = try buildVideo(
                        plan: plan,
                        videoType: resolvedType.videoType,
                        metadata: metadata,
                        studyUID: studyUID,
                        seriesUID: seriesUID,
                        seriesNumber: seriesNumber,
                        instanceNumber: instanceNumber
                    )

                    let destination = outputURL.appendingPathComponent(
                        url.deletingPathExtension().lastPathComponent + ".dcm")
                    if FileManager.default.fileExists(atPath: destination.path), !force {
                        throw ConversionFailure.inputError(
                            "'\(destination.lastPathComponent)' already exists; pass --force")
                    }

                    let file = DICOMFile.create(
                        dataSet: video.toDataSet(),
                        sopClassUID: video.sopClassUID,
                        sopInstanceUID: video.sopInstanceUID,
                        transferSyntaxUID: plan.transferSyntax.uid
                    )
                    try file.write().write(to: destination)

                    converted += 1
                    print("\(name) -> \(destination.lastPathComponent)")
                } catch let failure as ConversionFailure {
                    // Fail-fast by default, so a half-populated series is never
                    // left behind.
                    guard continueOnError else {
                        printError(failure.message)
                        printError("")
                        printError("Stopped at '\(name)'. \(converted) file(s) already written.")
                        switch failure {
                        case .conformance: throw VideoExit.conformanceRejection
                        case .inputError: throw ExitCode(1)
                        }
                    }
                    skipped.append((name, firstLine(of: failure.message)))
                }
            }

            print("")
            if skipped.isEmpty {
                print("Converted \(converted) of \(files.count) clips.")
            } else {
                print("Converted \(converted) of \(files.count) clips (\(skipped.count) skipped).")
                for entry in skipped {
                    print("  skipped: \(entry.name) — \(entry.reason)")
                }
                throw VideoExit.conformanceRejection
            }
        }

        /// Lists candidate inputs in deterministic, natural-sort order.
        private func discoverInputs(in directory: URL) throws -> [URL] {
            let manager = FileManager.default
            var urls: [URL] = []

            if recursive {
                guard let walker = manager.enumerator(
                    at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
                    return []
                }
                for case let url as URL in walker {
                    if isCandidate(url) { urls.append(url) }
                }
            } else {
                let entries = try manager.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: [.isRegularFileKey])
                urls = entries.filter(isCandidate)
            }

            return urls.sorted { naturalCompare($0.lastPathComponent, $1.lastPathComponent) }
        }

        private func isCandidate(_ url: URL) -> Bool {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { return false }
            return Self.videoExtensions.contains(url.pathExtension.lowercased())
        }

        private func firstLine(of message: String) -> String {
            let trimmed = message
                .split(separator: "\n", omittingEmptySubsequences: false)
                .first.map(String.init) ?? message
            return trimmed.replacingOccurrences(of: "error: ", with: "")
        }
    }
}

/// Compares filenames so that embedded numbers sort numerically: clip2 precedes
/// clip10, which a plain lexicographic sort gets backwards.
func naturalCompare(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs)
    let right = Array(rhs)
    var leftIndex = 0
    var rightIndex = 0

    while leftIndex < left.count, rightIndex < right.count {
        let leftCharacter = left[leftIndex]
        let rightCharacter = right[rightIndex]

        if leftCharacter.isNumber, rightCharacter.isNumber {
            var leftDigits = ""
            while leftIndex < left.count, left[leftIndex].isNumber {
                leftDigits.append(left[leftIndex])
                leftIndex += 1
            }
            var rightDigits = ""
            while rightIndex < right.count, right[rightIndex].isNumber {
                rightDigits.append(right[rightIndex])
                rightIndex += 1
            }
            let leftValue = Int(leftDigits) ?? 0
            let rightValue = Int(rightDigits) ?? 0
            if leftValue != rightValue { return leftValue < rightValue }
            continue
        }

        if leftCharacter != rightCharacter {
            return String(leftCharacter).localizedStandardCompare(String(rightCharacter))
                == .orderedAscending
        }
        leftIndex += 1
        rightIndex += 1
    }

    return left.count - leftIndex < right.count - rightIndex
}

DICOMVideo.main()
