//
// VideoWorkflow.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// The end-to-end `dicom-video` operations, shared by the CLI and DICOMStudio's
/// CLI Workshop.
///
/// This is the engine half of the adapter pattern: it probes, validates, selects
/// a transfer syntax, builds the object and **returns the bytes**. It never
/// writes a file, never prints and never parses argv — the CLI writes with
/// `Data.write(to:)`, the sandboxed app writes through `OutputAccess`, and both
/// render text through ``VideoConsole``.
///
/// Reference: `APP_CLI_SHARED_API.md` §4 — the in-memory variant pattern.
public enum VideoWorkflow {

    // MARK: - Failure

    /// Why an operation could not complete, carrying the CLI-exact message and
    /// the exit code the CLI would return.
    public enum Failure: Error, Sendable {
        /// The input could not be read or understood at all.
        case inputError(String)
        /// The input is understood but is not DICOM-legal.
        case conformance(String)

        /// The message, already formatted the way both surfaces print it.
        public var message: String {
            switch self {
            case let .inputError(text): return text
            case let .conformance(text): return text
            }
        }

        /// The process exit code this failure maps to.
        public var exitCode: VideoConsole.ExitCode {
            switch self {
            case .inputError: return .inputError
            case .conformance: return .conformanceRejection
            }
        }
    }

    /// A ``Failure`` that also carries the `--verbose` commentary gathered
    /// before it was raised.
    ///
    /// Thrown only when verbose is on, so the ordinary `catch let failure as
    /// Failure` in either adapter keeps working unchanged; an adapter that wants
    /// the commentary catches this first. `failure` is the identical value that
    /// would otherwise have been thrown, so the message and exit code do not
    /// depend on whether verbose was asked for.
    public struct VerboseFailure: Error, Sendable {
        /// The failure that would have been thrown without `--verbose`.
        public let failure: Failure
        /// The verbose lines gathered before the failure, already prefixed.
        public let commentary: String

        public init(failure: Failure, commentary: String) {
            self.failure = failure
            self.commentary = commentary
        }

        /// The commentary followed by the failure message, in printing order.
        public var combinedMessage: String {
            commentary.isEmpty ? failure.message : commentary + "\n" + failure.message
        }

        /// The exit code the underlying failure maps to.
        public var exitCode: VideoConsole.ExitCode { failure.exitCode }
    }

    // MARK: - Conversion Plan

    /// Everything needed to write one object, shared by convert and batch.
    public struct ConversionPlan: Sendable {
        /// What the input turned out to be, with any frame-rate override applied.
        public let probe: VideoProbeResult
        /// The transfer syntax the object will declare.
        public let transferSyntax: TransferSyntax
        /// The payload, passed through unchanged.
        public let bitstream: Data
        /// The decisions taken while planning, already prefixed, for `--verbose`.
        ///
        /// Collected even when verbose is off — planning is where the container,
        /// transfer syntax and frame count are decided, and gathering a few
        /// strings costs nothing next to probing the bitstream. The adapters
        /// decide whether to print them.
        public let verboseLines: [String]

        public init(
            probe: VideoProbeResult,
            transferSyntax: TransferSyntax,
            bitstream: Data,
            verboseLines: [String] = []
        ) {
            self.probe = probe
            self.transferSyntax = transferSyntax
            self.bitstream = bitstream
            self.verboseLines = verboseLines
        }
    }

    /// The patient, study and series attributes `convert` and `batch` accept.
    ///
    /// Every field is optional: the DICOM Type 2 attributes are emitted
    /// zero-length when absent, which is what the standard expects of an unknown
    /// value.
    public struct Metadata: Sendable {
        public var patientName: String?
        public var patientID: String?
        public var patientBirthDate: String?
        public var patientSex: String?
        public var studyUID: String?
        public var seriesUID: String?
        public var accessionNumber: String?
        public var studyID: String?
        public var referringPhysician: String?
        public var seriesDescription: String?
        public var modality: String?
        public var manufacturer: String?
        public var institutionName: String?

        public init(
            patientName: String? = nil,
            patientID: String? = nil,
            patientBirthDate: String? = nil,
            patientSex: String? = nil,
            studyUID: String? = nil,
            seriesUID: String? = nil,
            accessionNumber: String? = nil,
            studyID: String? = nil,
            referringPhysician: String? = nil,
            seriesDescription: String? = nil,
            modality: String? = nil,
            manufacturer: String? = nil,
            institutionName: String? = nil
        ) {
            self.patientName = patientName
            self.patientID = patientID
            self.patientBirthDate = patientBirthDate
            self.patientSex = patientSex
            self.studyUID = studyUID
            self.seriesUID = seriesUID
            self.accessionNumber = accessionNumber
            self.studyID = studyID
            self.referringPhysician = referringPhysician
            self.seriesDescription = seriesDescription
            self.modality = modality
            self.manufacturer = manufacturer
            self.institutionName = institutionName
        }
    }

    // MARK: - Planning

    /// Probes an input and selects a transfer syntax, rejecting non-conformant
    /// input with the specific violated constraint.
    ///
    /// - Parameters:
    ///   - bitstream: The input bytes.
    ///   - explicitTransferSyntax: A `--transfer-syntax` UID, when given.
    ///   - trustInput: Encapsulate a transport stream without validating it.
    ///   - frameRateOverride: A `--frame-rate` value, when given.
    ///   - verboseSink: Receives the verbose lines gathered so far even when the
    ///     plan throws. A rejection is exactly where "which container did you
    ///     read?" matters most, and the successful path returns those lines on
    ///     the plan — so without this they would be available only when nothing
    ///     went wrong.
    /// - Returns: The plan a build needs.
    /// - Throws: ``Failure`` naming the problem.
    public static func planConversion(
        bitstream: Data,
        explicitTransferSyntax: String? = nil,
        trustInput: Bool = false,
        frameRateOverride: Double? = nil,
        verboseSink: (([String]) -> Void)? = nil
    ) throws -> ConversionPlan {
        let probe: VideoProbeResult
        do {
            probe = try VideoProbe.probe(bitstream, trustInput: trustInput)
        } catch let error as VideoProbeError {
            // A non-video or unreadable input is an input problem, except the
            // conformance-shaped cases, which scripts should see as rejections.
            switch error {
            case .notVideo, .unsupportedCodec, .multipleVideoTracks:
                throw Failure.conformance(error.message)
            default:
                throw Failure.inputError(error.message)
            }
        }

        // Recorded as the plan proceeds; only printed when --verbose is on.
        var verbose = VideoConsole.verboseReadLines(
            byteCount: bitstream.count, container: probe.container)
        // Hands the caller what was learned before a rejection, which is the
        // case the commentary is most useful in.
        func reject(_ failure: Failure) -> Failure {
            verboseSink?(verbose)
            return failure
        }

        // The container itself must be one DICOM blesses.
        guard probe.container.isPermittedByDICOM else {
            let violation = VideoConformanceViolation.containerNotPermitted(
                observed: probe.container.displayName)
            throw reject(.conformance(VideoConsole.violationReport(violation)))
        }

        // A trusted transport stream skips validation by definition: nothing was
        // read, so the caller must name the transfer syntax and own the claim.
        if trustInput, probe.container == .mpegTS {
            guard let uidString = explicitTransferSyntax,
                  let syntax = TransferSyntax.from(uid: uidString), syntax.isVideo else {
                throw reject(.inputError(VideoConsole.trustInputNeedsTransferSyntaxLine))
            }
            verbose += VideoConsole.verboseTransferSyntaxLines(
                syntax, wasExplicit: true, trusted: true)
            return ConversionPlan(
                probe: probe, transferSyntax: syntax, bitstream: bitstream,
                verboseLines: verbose)
        }

        // An explicit transfer syntax is honoured but still validated: a
        // mislabelled object is worse than a rejected one.
        let transferSyntax: TransferSyntax
        if let uidString = explicitTransferSyntax {
            guard let syntax = TransferSyntax.from(uid: uidString) else {
                throw reject(.inputError(VideoConsole.unknownTransferSyntaxLine(uidString)))
            }
            guard syntax.isVideo else {
                throw reject(.inputError(VideoConsole.notAVideoTransferSyntaxLine(uidString)))
            }
            transferSyntax = syntax
        } else {
            guard let selected = probe.suggestedTransferSyntax else {
                // Nothing fits, so report why against the closest candidate
                // rather than a bare "unsupported".
                let candidate = candidateSyntax(for: probe.stream)
                let result = VideoConformanceValidator.validate(
                    stream: probe.stream,
                    transferSyntax: candidate,
                    numberOfFrames: probe.frameCount
                )
                verbose.append(VideoConsole.verboseNoCandidateSyntaxLine(candidate))
                throw reject(.conformance(
                    result.isConformant
                        ? VideoConsole.noCarryingTransferSyntaxLine
                        : result.report))
            }
            transferSyntax = selected
        }

        var stream = probe.stream
        if let override = frameRateOverride {
            guard override > 0, override < 1000 else {
                throw reject(.inputError(VideoConsole.implausibleFrameRateLine(override)))
            }
            verbose.append(VideoConsole.verboseFrameRateOverrideLine(
                from: stream.frameRate, to: override))
            stream = withFrameRate(stream, frameRate: override)
        }

        let result = VideoConformanceValidator.validate(
            stream: stream,
            transferSyntax: transferSyntax,
            numberOfFrames: probe.frameCount
        )
        guard result.isConformant else {
            verbose.append(VideoConsole.verboseSelectedSyntaxLine(
                transferSyntax, wasExplicit: explicitTransferSyntax != nil))
            throw reject(.conformance(result.report))
        }

        // Reported after validation, so the "conformant" claim is one the run
        // has actually established rather than one it intends to check.
        verbose += VideoConsole.verboseTransferSyntaxLines(
            transferSyntax, wasExplicit: explicitTransferSyntax != nil, trusted: false)
        verbose.append(VideoConsole.verboseFrameCountLine(
            probe.frameCount, source: probe.frameCountSource))

        let resolved = VideoProbeResult(
            container: probe.container,
            stream: stream,
            frameCount: probe.frameCount,
            frameCountSource: probe.frameCountSource,
            audioTrackCount: probe.audioTrackCount,
            suggestedTransferSyntax: transferSyntax,
            frameRate: stream.frameRate
        )
        return ConversionPlan(
            probe: resolved, transferSyntax: transferSyntax, bitstream: bitstream,
            verboseLines: verbose)
    }

    /// The transfer syntax whose constraints best explain a rejection.
    public static func candidateSyntax(for stream: VideoStreamInfo) -> TransferSyntax {
        switch stream.codec {
        case .h264: return .mpeg4AVCHP41
        case .h265: return stream.bitDepthLuma == 10 ? .hevcH265Main10Profile : .hevcH265MainProfile
        case .mpeg2: return .mpeg2MainProfile
        case .unknown: return .mpeg4AVCHP41
        }
    }

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

    // MARK: - Building

    /// Builds the DICOM object for a planned conversion.
    ///
    /// - Parameters:
    ///   - now: The clock reading used for Content / Study / Acquisition date and
    ///     time. Injected so a test can pin it; both adapters pass `Date()`.
    public static func buildVideo(
        plan: ConversionPlan,
        videoType: VideoType,
        metadata: Metadata,
        studyUID: String,
        seriesUID: String,
        seriesNumber: Int,
        instanceNumber: Int,
        now: Date = Date()
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
        builder.setLossyCompression(codec: stream.codec)

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

        let (today, time) = dicomDateAndTime(from: now)
        builder.setContentDate(today)
        builder.setContentTime(time)
        builder.setStudyDateTime(date: today, time: time)
        builder.setAcquisitionDateTime(date: today, time: time)

        return try builder.build()
    }

    /// Splits a `Date` into the DICOM date and time values the builder wants.
    public static func dicomDateAndTime(from date: Date) -> (DICOMDate, DICOMTime) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        let dicomDate = DICOMDate(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
        let dicomTime = DICOMTime(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0
        )
        return (dicomDate, dicomTime)
    }

    /// Encodes a built video as a complete DICOM file, ready to be written.
    ///
    /// Returning bytes rather than writing them is what lets the sandboxed app
    /// route the same output through `OutputAccess`.
    public static func encode(video: Video, transferSyntax: TransferSyntax) throws -> Data {
        let file = DICOMFile.create(
            dataSet: video.toDataSet(),
            sopClassUID: video.sopClassUID,
            sopInstanceUID: video.sopInstanceUID,
            transferSyntaxUID: transferSyntax.uid
        )
        return try file.write()
    }

    // MARK: - Convert

    /// The outcome of a `convert` run.
    public struct ConvertOutcome: Sendable {
        /// The console text, in the order it is printed.
        public let output: String
        /// The encoded object, or nil for a `--dry-run`.
        public let data: Data?
        /// The built object, so a caller can report its UIDs.
        public let video: Video?
        /// The plan, for callers that want the probe detail.
        public let plan: ConversionPlan

        public init(output: String, data: Data?, video: Video?, plan: ConversionPlan) {
            self.output = output
            self.data = data
            self.video = video
            self.plan = plan
        }
    }

    /// Runs everything `convert` does except reading the input and writing the
    /// output: probe, validate, build and encode.
    ///
    /// The returned `output` holds the notices and warnings that precede the
    /// write; the caller appends ``VideoConsole/wroteLine(_:)`` and the probe
    /// report after it has written the bytes, because only the caller knows the
    /// final path (the app may redirect it).
    ///
    /// - Parameter typeWasExplicit: Whether the user named `--type`. When false,
    ///   the default-type notice is emitted, because a wrong type yields a valid
    ///   but mislabelled object.
    /// - Parameter verbose: Explain each decision — container, transfer syntax,
    ///   frame count, the UIDs minted and the encoded size. The extra lines join
    ///   the notices, which both adapters route to stderr, so `--verbose` never
    ///   changes what a script reading stdout sees.
    public static func convert(
        bitstream: Data,
        type: VideoConsole.TypeArgument,
        typeWasExplicit: Bool,
        explicitTransferSyntax: String? = nil,
        trustInput: Bool = false,
        frameRateOverride: Double? = nil,
        dryRun: Bool = false,
        verbose: Bool = false,
        metadata: Metadata = Metadata(),
        seriesNumber: Int = 1,
        instanceNumber: Int = 1,
        now: Date = Date()
    ) throws -> ConvertOutcome {
        var notices: [String] = []
        if !typeWasExplicit {
            notices.append(VideoConsole.defaultTypeNote(type))
        }

        // On a rejection the plan throws, so its commentary is delivered here
        // and re-thrown attached to the failure — otherwise --verbose would go
        // quiet in the one case it is most wanted.
        let plan: ConversionPlan
        do {
            plan = try planConversion(
                bitstream: bitstream,
                explicitTransferSyntax: explicitTransferSyntax,
                trustInput: trustInput,
                frameRateOverride: frameRateOverride,
                verboseSink: verbose ? { notices.append(VideoConsole.verboseBlock($0)) } : nil
            )
        } catch let failure as Failure {
            // Only a verbose run gets the wrapper: every existing caller catches
            // `Failure`, and asking for commentary must not change what is
            // thrown at them.
            guard verbose else { throw failure }
            throw VerboseFailure(
                failure: failure, commentary: notices.joined(separator: "\n"))
        }

        if verbose {
            notices.append(VideoConsole.verboseBlock(plan.verboseLines))
        }

        if plan.probe.audioTrackCount > 0 {
            notices.append(VideoConsole.audioDiscardedLine(
                trackCount: plan.probe.audioTrackCount))
        }

        guard !dryRun else {
            return ConvertOutcome(
                output: notices.joined(separator: "\n"), data: nil, video: nil, plan: plan)
        }

        let studyUID = metadata.studyUID ?? UIDGenerator.generateStudyInstanceUID().value
        let seriesUID = metadata.seriesUID ?? UIDGenerator.generateSeriesInstanceUID().value

        let video = try buildVideo(
            plan: plan,
            videoType: type.videoType,
            metadata: metadata,
            studyUID: studyUID,
            seriesUID: seriesUID,
            seriesNumber: seriesNumber,
            instanceNumber: instanceNumber,
            now: now
        )
        let data = try encode(video: video, transferSyntax: plan.transferSyntax)

        if verbose {
            notices.append(VideoConsole.verboseBlock(
                VideoConsole.verboseIdentityLines(
                    sopClassName: type.sopClassName,
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    sopInstanceUID: video.sopInstanceUID,
                    generatedStudyUID: metadata.studyUID == nil,
                    generatedSeriesUID: metadata.seriesUID == nil
                )
                + VideoConsole.verboseEncodedLines(
                    payloadBytes: plan.bitstream.count, encodedBytes: data.count)
            ))
        }

        return ConvertOutcome(
            output: notices.joined(separator: "\n"), data: data, video: video, plan: plan)
    }

    // MARK: - Probe

    /// The outcome of a `probe` run.
    public struct ProbeOutcome: Sendable {
        /// The full console text, report and verdict together.
        public let output: String
        /// The probe result.
        public let probe: VideoProbeResult
        /// The exit code the verdict maps to.
        public let exitCode: VideoConsole.ExitCode
        /// The `--verbose` commentary, empty unless verbose was asked for.
        ///
        /// Kept apart from `output` because the report is the result and goes to
        /// stdout, while the commentary goes to stderr — so `dicom-video probe
        /// clip.mp4 --verbose > report.txt` still captures a clean report.
        public let diagnostics: String

        public init(
            output: String,
            probe: VideoProbeResult,
            exitCode: VideoConsole.ExitCode,
            diagnostics: String = ""
        ) {
            self.output = output
            self.probe = probe
            self.exitCode = exitCode
            self.diagnostics = diagnostics
        }
    }

    /// Probes an input and renders the report and conformance verdict.
    ///
    /// A non-conformant stream is not an error here — `probe` reports it and
    /// exits 2, so the text comes back with the rejecting exit code rather than
    /// as a thrown failure.
    public static func probe(
        bitstream: Data,
        trustInput: Bool = false,
        verbose: Bool = false
    ) throws -> ProbeOutcome {
        let result: VideoProbeResult
        do {
            result = try VideoProbe.probe(bitstream, trustInput: trustInput)
        } catch let error as VideoProbeError {
            throw Failure.inputError(error.message)
        }

        // Commentary, not report: kept out of `lines` so stdout stays parseable.
        var commentary: [String] = []
        if verbose {
            commentary += VideoConsole.verboseReadLines(
                byteCount: bitstream.count, container: result.container)
            commentary.append(VideoConsole.verboseFrameCountLine(
                result.frameCount, source: result.frameCountSource))
            // Only the selection line: probe prints its own conformance verdict
            // below, so claiming "conformant" here would pre-empt and sometimes
            // contradict it.
            if let syntax = result.suggestedTransferSyntax {
                commentary.append(VideoConsole.verboseSelectedSyntaxLine(syntax))
            } else {
                commentary.append(VideoConsole.verboseNoCandidateSyntaxLine(
                    candidateSyntax(for: result.stream)))
            }
        }
        let diagnostics = VideoConsole.verboseBlock(commentary)

        var lines = [VideoConsole.describe(result, transferSyntax: result.suggestedTransferSyntax)]

        guard let syntax = result.suggestedTransferSyntax else {
            lines.append(VideoConsole.noCarryingSyntaxVerdictLine)
            let conformance = VideoConformanceValidator.validate(
                stream: result.stream,
                transferSyntax: candidateSyntax(for: result.stream),
                numberOfFrames: result.frameCount
            )
            if !conformance.isConformant {
                lines.append("")
                lines.append(conformance.report)
            }
            return ProbeOutcome(
                output: lines.joined(separator: "\n"),
                probe: result,
                exitCode: .conformanceRejection,
                diagnostics: diagnostics
            )
        }

        let conformance = VideoConformanceValidator.validate(
            stream: result.stream, transferSyntax: syntax, numberOfFrames: result.frameCount)
        if conformance.isConformant {
            lines.append(VideoConsole.conformanceOKLine)
            return ProbeOutcome(
                output: lines.joined(separator: "\n"), probe: result, exitCode: .success,
                diagnostics: diagnostics)
        }

        lines.append("")
        lines.append(conformance.report)
        return ProbeOutcome(
            output: lines.joined(separator: "\n"),
            probe: result,
            exitCode: .conformanceRejection,
            diagnostics: diagnostics
        )
    }

    // MARK: - Extract

    /// Recovers the payload from a DICOM object's bytes.
    ///
    /// - Parameter data: The DICOM file's bytes.
    /// - Returns: The payload, for the caller to write.
    /// - Throws: ``Failure`` when the file is unreadable or carries no video.
    public static func extract(fileData data: Data, inputPath: String) throws -> ExtractedVideo {
        let file: DICOMFile
        do {
            file = try DICOMFile.read(from: data)
        } catch {
            throw Failure.inputError(VideoConsole.notReadableDICOMLine(inputPath))
        }

        do {
            return try VideoExtractor.extract(from: file)
        } catch let error as VideoExtractionError {
            throw Failure.inputError(error.message)
        }
    }

    /// The extension warning for an output path, or nil when it suits the payload.
    ///
    /// An empty extension is accepted silently: the user asked for no extension.
    public static func extensionWarning(
        for extracted: ExtractedVideo,
        outputPath: String
    ) -> String? {
        let given = URL(fileURLWithPath: outputPath).pathExtension.lowercased()
        guard !given.isEmpty, given != extracted.suggestedFileExtension else { return nil }
        return VideoConsole.extensionMismatchLine(
            container: extracted.container,
            suggested: extracted.suggestedFileExtension,
            given: given
        )
    }

    // MARK: - Batch

    /// Extensions worth attempting. Content is sniffed afterwards, so a stray
    /// file with a video extension is still rejected on its bytes.
    public static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "ts", "m2ts", "mts",
        "264", "h264", "265", "hevc", "h265", "m2v", "mpv", "mpg", "mpeg",
    ]

    /// Lists candidate inputs in deterministic, natural-sort order.
    public static func discoverInputs(in directory: URL, recursive: Bool) throws -> [URL] {
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

    /// Whether a URL is a regular file with an extension worth trying.
    public static func isCandidate(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return false }
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    /// One clip's result inside a batch run.
    public struct BatchItem: Sendable {
        /// The input file's name.
        public let name: String
        /// The suggested output file name (`<basename>.dcm`).
        public let outputName: String
        /// The encoded object, or nil for a `--dry-run`.
        public let data: Data?
        /// The transfer syntax selected for this clip.
        public let transferSyntaxUID: String

        public init(name: String, outputName: String, data: Data?, transferSyntaxUID: String) {
            self.name = name
            self.outputName = outputName
            self.data = data
            self.transferSyntaxUID = transferSyntaxUID
        }
    }

    /// How a batch run ended.
    ///
    /// Results and diagnostics are kept apart because the CLI writes them to
    /// different streams: per-clip lines and the summary go to stdout, while
    /// notices and the fail-fast error go to stderr, so `dicom-video batch … >
    /// list.txt` captures the list and not the commentary. The app concatenates
    /// them, diagnostics first, into its single console.
    public struct BatchOutcome: Sendable {
        /// The per-clip lines and the closing summary — the CLI's stdout.
        public let output: String
        /// Notices, warnings and the fail-fast error — the CLI's stderr.
        public let diagnostics: String
        /// The exit code the run maps to.
        public let exitCode: VideoConsole.ExitCode

        /// Both streams in the order a single console shows them.
        public var combined: String {
            [diagnostics, output].filter { !$0.isEmpty }.joined(separator: "\n")
        }

        public init(output: String, diagnostics: String = "", exitCode: VideoConsole.ExitCode) {
            self.output = output
            self.diagnostics = diagnostics
            self.exitCode = exitCode
        }
    }

    /// Validates the flag combination a batch run was given.
    ///
    /// - Throws: ``Failure`` when `--series-uid` is combined with
    ///   `--series-mode per-file`, which mints its own UID per clip; rejecting
    ///   beats silently ignoring the flag.
    public static func validateBatchOptions(
        seriesMode: VideoConsole.SeriesMode,
        metadata: Metadata
    ) throws {
        if seriesMode == .perFile, metadata.seriesUID != nil {
            throw Failure.inputError(VideoConsole.seriesUIDConflictsWithPerFileLine)
        }
    }

    /// Runs a batch conversion, delegating every side effect to the caller.
    ///
    /// The caller supplies `readFile` and `writeFile` so the CLI can use the file
    /// system directly while the sandboxed app reads through security-scoped URLs
    /// and writes through `OutputAccess`. `writeFile` returns the path actually
    /// written, which is what the per-clip line names — so an app redirect shows
    /// the real destination.
    ///
    /// Resolves a user-supplied `--output` into the file to actually write.
    ///
    /// A path naming an existing directory means "put it in here", which is what
    /// a folder picker hands back and what people type. Taking it literally makes
    /// the destination collide with the directory itself: the existence check
    /// reads it as a file that is already there and reports the conversion as a
    /// name clash, and forcing past that fails again inside Foundation, so a
    /// perfectly convertible clip cannot be written at all. Naming the file after
    /// the input, as batch mode already does, keeps single and batch conversions
    /// consistent.
    ///
    /// - Parameters:
    ///   - output: The `--output` path as given.
    ///   - input: The clip being converted, whose base name is reused.
    ///   - fileExtension: Extension for the written file, without a dot.
    ///   - isDirectory: Whether `output` names an existing directory. Injected so
    ///     this stays testable without touching the file system.
    /// - Returns: The URL to write, and whether it was redirected into a folder.
    public static func resolveOutputURL(
        output: String,
        input: URL,
        fileExtension: String,
        isDirectory: (String) -> Bool
    ) -> (url: URL, redirectedIntoDirectory: Bool) {
        let given = URL(fileURLWithPath: output)
        guard isDirectory(given.path) else { return (given, false) }
        let base = input.deletingPathExtension().lastPathComponent
        let name = base.isEmpty ? "output" : base
        return (given.appendingPathComponent(name).appendingPathExtension(fileExtension), true)
    }

    /// - Parameters:
    ///   - inputs: The clips to convert, already ordered.
    ///   - verbose: Explain the grouping and the numbering each clip receives.
    ///     The lines join `diagnostics`, which the CLI writes to stderr, so the
    ///     per-clip list on stdout is unchanged.
    ///   - recursive: Whether `inputs` came from a recursive search. Reported
    ///     under `verbose` only; the caller has already done the searching.
    ///   - readFile: Reads one clip's bytes, or returns nil when unreadable.
    ///   - writeFile: Writes one object and returns the path it landed at, or
    ///     throws ``Failure`` when the destination is taken and `--force` is off.
    public static func runBatch(
        inputs: [URL],
        type: VideoConsole.TypeArgument,
        typeWasExplicit: Bool,
        explicitTransferSyntax: String? = nil,
        seriesMode: VideoConsole.SeriesMode = .single,
        continueOnError: Bool = false,
        dryRun: Bool = false,
        verbose: Bool = false,
        recursive: Bool = false,
        metadata: Metadata = Metadata(),
        now: Date = Date(),
        readFile: (URL) -> Data?,
        writeFile: (BatchItem) throws -> String
    ) -> BatchOutcome {
        // Results go to stdout, commentary to stderr — see ``BatchOutcome``.
        var lines: [String] = []
        var diagnostics: [String] = []
        if !typeWasExplicit {
            diagnostics.append(VideoConsole.defaultTypeNote(type))
        }

        // Both modes share one Study Instance UID: a batch is one patient visit.
        let studyUID = metadata.studyUID ?? UIDGenerator.generateStudyInstanceUID().value
        let sharedSeriesUID = metadata.seriesUID ?? UIDGenerator.generateSeriesInstanceUID().value

        if verbose {
            diagnostics.append(VideoConsole.verboseBlock(
                VideoConsole.verboseBatchPlanLines(
                    fileCount: inputs.count, recursive: recursive, seriesMode: seriesMode)
                + ["Study Instance UID \(studyUID)"
                   + (metadata.studyUID == nil ? " (generated)" : " (given)")]
            ))
        }

        var converted = 0
        var skipped: [(name: String, reason: String)] = []

        for url in inputs {
            let name = url.lastPathComponent
            do {
                guard let bitstream = readFile(url) else {
                    throw Failure.inputError(VideoConsole.batchUnreadableLine)
                }

                let plan = try planConversion(
                    bitstream: bitstream,
                    explicitTransferSyntax: explicitTransferSyntax,
                    trustInput: false,
                    frameRateOverride: nil,
                    // A rejected clip explains itself under --verbose; the skip
                    // list on stdout still carries only its one-line reason.
                    verboseSink: verbose
                        ? { diagnostics.append(VideoConsole.verboseBlock(
                            $0.map { "\(name): \($0)" })) }
                        : nil
                )

                guard !dryRun else {
                    converted += 1
                    lines.append(VideoConsole.batchDryRunLine(
                        input: name, transferSyntaxUID: plan.transferSyntax.uid))
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
                    videoType: type.videoType,
                    metadata: metadata,
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    seriesNumber: seriesNumber,
                    instanceNumber: instanceNumber,
                    now: now
                )
                let data = try encode(video: video, transferSyntax: plan.transferSyntax)
                let outputName = url.deletingPathExtension().lastPathComponent + ".dcm"

                if verbose {
                    diagnostics.append(VideoConsole.verboseLine(
                        VideoConsole.verboseBatchItemLine(
                            name: name,
                            seriesNumber: seriesNumber,
                            instanceNumber: instanceNumber,
                            transferSyntaxUID: plan.transferSyntax.uid)))
                }

                let writtenPath = try writeFile(BatchItem(
                    name: name,
                    outputName: outputName,
                    data: data,
                    transferSyntaxUID: plan.transferSyntax.uid
                ))

                converted += 1
                lines.append(VideoConsole.batchConvertedLine(
                    input: name,
                    output: URL(fileURLWithPath: writtenPath).lastPathComponent))
            } catch let failure as Failure {
                // Fail-fast by default, so a half-populated series is never left
                // behind. The stop report is commentary, not a result, so it
                // joins the notices on stderr.
                guard continueOnError else {
                    // batchStoppedLines already opens with the blank separator
                    // line the CLI printed between the error and the stop report.
                    diagnostics.append(failure.message)
                    diagnostics.append(
                        VideoConsole.batchStoppedLines(at: name, converted: converted))
                    return BatchOutcome(
                        output: lines.joined(separator: "\n"),
                        diagnostics: diagnostics.joined(separator: "\n"),
                        exitCode: failure.exitCode)
                }
                skipped.append((name, VideoConsole.firstLine(of: failure.message)))
            } catch {
                guard continueOnError else {
                    diagnostics.append(error.localizedDescription)
                    diagnostics.append(
                        VideoConsole.batchStoppedLines(at: name, converted: converted))
                    return BatchOutcome(
                        output: lines.joined(separator: "\n"),
                        diagnostics: diagnostics.joined(separator: "\n"),
                        exitCode: .inputError)
                }
                skipped.append((name, VideoConsole.firstLine(of: error.localizedDescription)))
            }
        }

        lines.append(VideoConsole.batchSummary(
            converted: converted, total: inputs.count, skipped: skipped))

        return BatchOutcome(
            output: lines.joined(separator: "\n"),
            diagnostics: diagnostics.joined(separator: "\n"),
            exitCode: skipped.isEmpty ? .success : .conformanceRejection
        )
    }
}

// MARK: - Natural Sort

/// Compares filenames so that embedded numbers sort numerically: clip2 precedes
/// clip10, which a plain lexicographic sort gets backwards.
public func naturalCompare(_ lhs: String, _ rhs: String) -> Bool {
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
