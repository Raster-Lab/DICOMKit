//
// AnonymizationWorkflow.swift
// DICOMKit
//
// The whole `dicom-anon` run, shared by the CLI and DICOMStudio's CLI Workshop.
//
// Both surfaces build a `Request` in the CLI's own vocabulary (flag values as
// typed), hand it to `run(_:emit:)`, and print whatever the sink receives. Input
// parsing (profile / tag / region / style / mode / codec), validation messages,
// the pixel-first ordering, the refusal contract, the PS3.15 vs legacy engine
// choice, and every console line therefore come from ONE place — the two
// surfaces cannot drift. The CLI is a thin ArgumentParser adapter; the app adds
// only sandbox plumbing (security-scoped URLs, a writable-output fallback).
//

import Foundation
import DICOMCore

public struct AnonymizationWorkflow: Sendable {

    // MARK: - Errors

    /// A fatal input or run error. The CLI prints `Error: <message>` and exits 1;
    /// the app prints the identical line.
    public struct ValidationError: Error, LocalizedError, Equatable, Sendable {
        public let message: String
        public init(_ message: String) { self.message = message }
        public var errorDescription: String? { message }
    }

    // MARK: - Request (dicom-anon's inputs, verbatim)

    /// Every `dicom-anon` input, named after its flag and carrying the raw value the
    /// operator gave. Nothing here is parsed yet — ``resolve(_:)`` does that, so a
    /// bad value produces the same error on every surface.
    public struct Request: Sendable, Equatable {
        /// Positional path to a DICOM file or directory.
        public var inputPath: String
        /// `--output`
        public var output: String?
        /// `--profile basic|clinical-trial|research|ps315`
        public var profile: String = "basic"

        // PS3.15 Annex E retention options (only apply to --profile ps315).
        public var retainDates = false
        public var retainCharacteristics = false
        public var retainDevice = false
        public var retainInstitution = false
        public var retainUids = false
        public var cleanDescriptors = false

        // Pixel pipeline.
        public var cleanPixelData = false
        /// `--redact-region x,y,w,h` (repeatable)
        public var redactRegion: [String] = []
        /// `--redact-fill`
        public var redactFill: Int?
        /// `--redact-style blank|label|replace`
        public var redactStyle: String = "blank"
        /// `--redact-label`
        public var redactLabel: String?
        /// `--recompress source|<codec>`
        public var recompress: String?
        /// `--detect-text`
        public var detectText = false
        /// `--detect-text-mode classify|all`
        public var detectTextMode: String = "classify"
        /// `--ocr-all-frames`
        public var ocrAllFrames = false

        // Legacy engine options.
        public var shiftDates: Int?
        public var regenerateUids = false
        /// `--remove` (repeatable)
        public var remove: [String] = []
        /// `--replace TAG=VALUE` (repeatable)
        public var replace: [String] = []
        /// `--keep` (repeatable)
        public var keep: [String] = []

        // Run control.
        public var recursive = false
        public var dryRun = false
        public var backup = false
        /// `--audit-log`
        public var auditLog: String?
        public var force = false
        public var allowBurnedInPHI = false
        public var verbose = false

        /// DICOMStudio Security screen only — its "Custom Rules" profile removes
        /// exactly these tags and nothing else. The CLI has no such profile (it
        /// previews as `--profile basic --remove …`); leave `nil` everywhere else.
        public var customProfileTags: [Tag]? = nil

        public init(inputPath: String) {
            self.inputPath = inputPath
        }

        /// The de-identification engine this request selects.
        public var usesPS315: Bool { profile.lowercased() == "ps315" }
    }

    // MARK: - Resolved (typed inputs the engines consume)

    /// What ``resolve(_:)`` produces: the request with every string parsed and
    /// every cross-flag rule checked.
    public struct Resolved: Sendable {
        public let profile: AnonymizationProfile
        public let ps315Options: ConfidentialityProfile.Options?
        public let customActions: [Tag: AnonymizationAction]
        public let preserveTags: Set<Tag>
        public let pixelOptions: PixelCleaningWorkflow.Options
    }

    /// Parses and validates every input. Messages are the CLI's, verbatim.
    public static func resolve(_ r: Request) throws -> Resolved {
        let profile = try parseProfile(r)
        let customActions = try parseCustomActions(r)
        let preserveTags = try parsePreserveTags(r)
        let pixel = try pixelCleaningOptions(r)
        let ps315: ConfidentialityProfile.Options? = r.usesPS315 ? ConfidentialityProfile.Options(
            retainLongitudinalTemporal: r.retainDates,
            retainPatientCharacteristics: r.retainCharacteristics,
            retainDeviceIdentity: r.retainDevice,
            retainInstitutionIdentity: r.retainInstitution,
            retainUIDs: r.retainUids,
            cleanDescriptors: r.cleanDescriptors,
            dateOffsetDays: r.shiftDates) : nil
        return Resolved(profile: profile, ps315Options: ps315, customActions: customActions,
                        preserveTags: preserveTags, pixelOptions: pixel)
    }

    // MARK: - Hooks

    /// Writes one output file. Surfaces that cannot write wherever they like (the
    /// sandboxed app) substitute their own writer; a returned note is appended to
    /// that file's warnings so the summary shows where the bytes actually went.
    public typealias FileWriter = @Sendable (Data, URL) throws -> String?

    private let writeFile: FileWriter

    public init(writeFile: @escaping FileWriter = { data, url in try data.write(to: url); return nil }) {
        self.writeFile = writeFile
    }

    // MARK: - Run

    /// Everything the run produced besides console text.
    public struct Outcome: Sendable {
        public let results: [AnonymizationResult]
        /// CLI rule: any failed file → 1.
        public var exitCode: Int32 { results.contains(where: { !$0.success }) ? 1 : 0 }
    }

    /// Runs `dicom-anon` end to end. `emit` receives every console line in order,
    /// newline-terminated, exactly as the CLI prints it. Throws a
    /// ``ValidationError`` (or an engine error) for a fatal failure — the caller
    /// renders it as `Error: <localizedDescription>`.
    public func run(_ request: Request, emit: (String) -> Void) throws -> Outcome {
        let inputURL = URL(fileURLWithPath: request.inputPath)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: request.inputPath, isDirectory: &isDirectory) else {
            throw ValidationError("File not found")
        }

        let resolved = try Self.resolve(request)

        // Build the shared engine ONCE for the whole run so UID remapping stays
        // consistent across every file in a directory.
        let anonymizer = Anonymizer(
            profile: resolved.profile,
            shiftDates: request.shiftDates,
            regenerateUIDs: request.regenerateUids,
            preserveTags: resolved.preserveTags,
            customActions: resolved.customActions)

        var results: [AnonymizationResult] = []
        if isDirectory.boolValue {
            guard request.recursive else {
                throw ValidationError("Directory anonymization requires --recursive flag")
            }
            guard let outputPath = request.output else {
                throw ValidationError("Directory anonymization requires --output directory")
            }
            results = try anonymizeDirectory(
                request, resolved, inputURL: inputURL,
                outputURL: URL(fileURLWithPath: outputPath), anonymizer: anonymizer, emit: emit)
        } else {
            // Writing back over the input is never implied. Without --output there is
            // nowhere to write, so anonymizing would silently discard its result and
            // still report success — require --output unless this is a --dry-run preview.
            // --detect-text without --output is pure inspection: report and exit.
            guard request.dryRun || request.output != nil || request.detectText else {
                throw ValidationError("Anonymization requires --output (or use --dry-run to preview without writing)")
            }
            let result = try anonymizeFile(
                request, resolved, inputURL: inputURL,
                outputURL: request.output.map { URL(fileURLWithPath: $0) },
                anonymizer: anonymizer, sweep: nil, emit: emit)
            results = [result]
        }

        emit(AnonConsole.summary(
            totalFiles: results.count,
            successful: results.filter { $0.success }.count,
            failed: results.filter { !$0.success }.count,
            dryRun: request.dryRun,
            warnings: results.flatMap { $0.warnings },
            modifiedTags: Set(results.flatMap { $0.changedTags }.map { "\($0)" }),
            verbose: request.verbose))

        // The audit log is written even under --dry-run: dry-run auditing is a primary use case.
        if let auditLogPath = request.auditLog, !auditLogPath.isEmpty {
            try anonymizer.writeAuditLog(to: URL(fileURLWithPath: auditLogPath))
            if request.verbose {
                emit(AnonConsole.auditLogLine(path: auditLogPath) + "\n")
            }
        }

        return Outcome(results: results)
    }

    // MARK: - Directory

    private func anonymizeDirectory(
        _ request: Request, _ resolved: Resolved,
        inputURL: URL, outputURL: URL, anonymizer: Anonymizer, emit: (String) -> Void
    ) throws -> [AnonymizationResult] {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        guard let fileURLs = FileGatherer.regularFiles(under: inputURL) else {
            throw ValidationError("Failed to enumerate directory: \(inputURL.path)")
        }

        var results: [AnonymizationResult] = []

        // Concatenation pre-pass (§4.4): with OCR on, sweep every part first so text
        // found in one part is blanked in all of them.
        var sweep = PixelCleaningWorkflow.ConcatenationSweep()
        if resolved.pixelOptions.detectText != nil {
            for fileURL in fileURLs {
                guard let data = try? Data(contentsOf: fileURL),
                      let file = try? DICOMFile.read(from: data, force: request.force),
                      MultiframeConcatenation.isPart(file.dataSet)
                else { continue }
                if let swept = try? PixelCleaningWorkflow().sweep(fileData: data, options: resolved.pixelOptions),
                   let info = swept.info {
                    sweep.add(info, regions: swept.regions)
                }
            }
        }

        // Relative paths are computed on symlink-resolved paths: the gatherer yields
        // resolved URLs, so an input given through a symlink (e.g. /var → /private/var
        // on macOS) would otherwise leak the resolved prefix into the output tree.
        let basePath = inputURL.resolvingSymlinksInPath().path
        for fileURL in fileURLs {
            let filePath = fileURL.resolvingSymlinksInPath().path
            guard filePath.hasPrefix(basePath + "/") else { continue }
            let relativePath = String(filePath.dropFirst(basePath.count + 1))
            guard !relativePath.isEmpty else { continue }

            let outputFileURL = outputURL.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: outputFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            do {
                let result = try anonymizeFile(
                    request, resolved, inputURL: fileURL, outputURL: outputFileURL,
                    anonymizer: anonymizer, sweep: sweep, emit: emit)
                results.append(result)
                if request.verbose {
                    emit(AnonConsole.fileSuccessLine(relativePath: relativePath) + "\n")
                }
            } catch {
                if request.verbose {
                    emit(AnonConsole.fileFailureLine(relativePath: relativePath, message: error.localizedDescription) + "\n")
                }
                results.append(AnonymizationResult(
                    filePath: fileURL.path, success: false, changedTags: [],
                    warnings: [error.localizedDescription]))
            }
        }
        return results
    }

    // MARK: - One file

    private func anonymizeFile(
        _ request: Request, _ resolved: Resolved,
        inputURL: URL, outputURL: URL?, anonymizer: Anonymizer,
        sweep: PixelCleaningWorkflow.ConcatenationSweep?, emit: (String) -> Void
    ) throws -> AnonymizationResult {
        var fileData = try Data(contentsOf: inputURL)
        var dicomFile = try DICOMFile.read(from: fileData, force: request.force)

        // --- Pixel work runs FIRST, before any header de-identification. ---
        // The region decision reads Modality / Manufacturer / model, which
        // de-identification removes; planning afterwards would see a scrubbed data set
        // and match nothing. Both CTP and Presidio document this same ordering
        // dependency, so the order here is a correctness requirement, not a preference.
        var pixelWarnings: [String] = []
        var pixelNotes: [String] = []
        var pixelOptions = resolved.pixelOptions
        if let sweep, let info = PixelCleaningWorkflow.concatenationInfo(of: dicomFile.dataSet) {
            pixelOptions.presetDetectedRegions = sweep.regions(for: info.uid)
            pixelOptions.concatenationAnalyzedCompletely = sweep.isComplete(info.uid)
        }
        // `replace` draws the header engine's OWN values: preview the header pass on the
        // original data set (in memory, nothing written) and read what it produces.
        if case .replace = pixelOptions.style {
            guard pixelOptions.detectText == .classify else {
                throw ValidationError("--redact-style replace needs --detect-text with mode classify (replacement values come from classified matches).")
            }
            let preview = try previewHeaderPass(request, resolved, file: dicomFile, anonymizer: anonymizer)
            pixelOptions.replacementMapping = PixelCleaningWorkflow.ReplacementMapping.derive(
                original: dicomFile.dataSet, deidentified: preview.dataSet)
        }
        if pixelOptions.isActive {
            let report = try PixelCleaningWorkflow().run(
                fileData: fileData, options: pixelOptions, dryRun: request.dryRun)
            if pixelOptions.detectText != nil {
                emit(AnonConsole.textDetectionLine(report: report))
                anonymizer.recordPixelAudit(filePath: inputURL.path, lines: report.auditLines)
            }
            if request.dryRun {
                emit(AnonConsole.pixelPlanTable(report: report, showText: true))
            }
            if let outcome = report.outcome {
                fileData = report.data
                dicomFile = try DICOMFile.read(from: report.data, force: request.force)
                if request.verbose {
                    emit(AnonConsole.pixelRedactionLines(outcome: outcome))
                }
                if let r = report.recompression {
                    // Always shown: the lossy/fallback caveats are not optional information.
                    emit(AnonConsole.recompressionLines(r))
                }
            }
            // Coverage notes are reported, never used to refuse.
            pixelNotes = report.warnings
            // Detection feeds the refusal contract: text the tool KNOWS is there and
            // will not blank must block an output file unless the operator accepts it.
            pixelWarnings = report.residualWarnings
            if !pixelWarnings.isEmpty && outputURL != nil && !request.dryRun && !request.allowBurnedInPHI {
                throw ValidationError(
                    """
                    Refusing to anonymize \(inputURL.lastPathComponent): OCR found burned-in \
                    text that this run would leave in the pixels.

                    \(pixelWarnings.map { "  ⚠️  \($0)" }.joined(separator: "\n"))

                    Pass --clean-pixel-data to blank the detected regions, or \
                    --allow-burned-in-phi to write the metadata-scrubbed file anyway \
                    (it will be marked Patient Identity Removed = NO).
                    """)
            }
        }

        // Anonymize — PS3.15 Annex E engine or legacy profile.
        var anonymizedFile: DICOMFile
        let result: AnonymizationResult
        if let options = resolved.ps315Options {
            let (file, res, _) = anonymizer.deidentify(file: dicomFile, options: options)
            // Refuse to emit a file whose pixels may still identify the patient unless
            // the operator explicitly accepts that. Writing it silently is the harmful
            // case: the metadata looks clean, so the file reads as safe to release.
            if !res.warnings.isEmpty && !request.allowBurnedInPHI && !request.dryRun {
                throw ValidationError(
                    """
                    Refusing to anonymize \(inputURL.lastPathComponent): the pixel data may \
                    still contain PHI.

                    \(res.warnings.map { "  ⚠️  \($0)" }.joined(separator: "\n"))

                    Without --clean-pixel-data this tool de-identifies the DATASET ONLY, \
                    so burned-in text survives unchanged.

                    Pass --clean-pixel-data to blank it (add --redact-region x,y,w,h or \
                    --detect-text if the automatic region selection cannot resolve this \
                    device), or --allow-burned-in-phi to write the metadata-scrubbed file \
                    anyway (it will be marked Patient Identity Removed = NO).
                    """)
            }
            anonymizedFile = file
            result = AnonymizationResult(
                filePath: inputURL.path, success: res.success,
                changedTags: res.changedTags, warnings: res.warnings + pixelWarnings + pixelNotes)
        } else {
            let (file, res) = try anonymizer.anonymize(file: dicomFile, filePath: inputURL.path)
            anonymizedFile = file
            result = AnonymizationResult(
                filePath: res.filePath, success: res.success,
                changedTags: res.changedTags, warnings: res.warnings + pixelWarnings + pixelNotes)
        }

        // The operator accepted detected-but-unredacted text: the output must say so.
        // A YES here would be the false attestation this whole pipeline exists to avoid.
        if !pixelWarnings.isEmpty {
            var ds = anonymizedFile.dataSet
            PixelCleaningWorkflow.markDetectedTextRetained(in: &ds)
            anonymizedFile = DICOMFile(fileMetaInformation: anonymizedFile.fileMetaInformation, dataSet: ds)
        }

        // Write output if not dry-run
        var writeNotes: [String] = []
        if !request.dryRun, let outputURL {
            if request.backup {
                let backupURL = outputURL.appendingPathExtension("backup")
                try? FileManager.default.copyItem(at: inputURL, to: backupURL)
            }
            let outputData = try anonymizedFile.write()
            if let note = try writeFile(outputData, outputURL) {
                writeNotes.append(note)
            }
        }

        guard !writeNotes.isEmpty else { return result }
        return AnonymizationResult(
            filePath: result.filePath, success: result.success,
            changedTags: result.changedTags, warnings: result.warnings + writeNotes)
    }

    /// Runs the configured header de-identification on a copy, for `replace` values.
    /// Uses a throwaway engine so the real pass's audit log and UID map are untouched.
    private func previewHeaderPass(
        _ request: Request, _ resolved: Resolved, file: DICOMFile, anonymizer: Anonymizer
    ) throws -> DICOMFile {
        if let options = resolved.ps315Options {
            return anonymizer.deidentify(file: file, options: options).0
        }
        let throwaway = Anonymizer(
            profile: resolved.profile, shiftDates: request.shiftDates, regenerateUIDs: false,
            preserveTags: resolved.preserveTags, customActions: resolved.customActions)
        return try throwaway.anonymize(file: file, filePath: "preview").0
    }

    // MARK: - Input parsing (the CLI's, verbatim)

    private static func parseProfile(_ r: Request) throws -> AnonymizationProfile {
        if let custom = r.customProfileTags { return .custom(custom) }
        switch r.profile.lowercased() {
        case "basic":
            return .basic
        case "clinical-trial", "clinicaltrial":
            return .clinicalTrial
        case "research":
            return .research
        case "ps315":
            // The ps315 path bypasses the legacy engine (see anonymizeFile); this
            // value is only used to build the shared Anonymizer instance.
            return .basic
        default:
            throw ValidationError("Invalid anonymization profile")
        }
    }

    private static func parseCustomActions(_ r: Request) throws -> [Tag: AnonymizationAction] {
        var actions: [Tag: AnonymizationAction] = [:]
        for tagString in r.remove {
            actions[try parseTag(tagString)] = .remove
        }
        for replaceString in r.replace {
            let parts = replaceString.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid replace format: \(replaceString). Use TAG=VALUE")
            }
            actions[try parseTag(String(parts[0]))] = .replaceWithDummy(String(parts[1]))
        }
        return actions
    }

    private static func parsePreserveTags(_ r: Request) throws -> Set<Tag> {
        var tags = Set<Tag>()
        for tagString in r.keep {
            tags.insert(try parseTag(tagString))
        }
        return tags
    }

    private static func parseTag(_ string: String) throws -> Tag {
        guard let tag = Anonymizer.parseFlexibleTag(string) else {
            throw ValidationError("Invalid tag format: \(string)")
        }
        return tag
    }

    /// Translates the pixel-related flags into the shared pixel workflow options.
    private static func pixelCleaningOptions(_ r: Request) throws -> PixelCleaningWorkflow.Options {
        let editor = PixelEditor(verbose: false)
        let explicit = try r.redactRegion.map { spec -> PixelRedactionPlan.Region in
            let region = try editor.parseRegion(spec)
            return PixelRedactionPlan.Region(x: region.x, y: region.y, width: region.width, height: region.height)
        }
        var mode: PixelCleaningWorkflow.TextDetectionMode?
        if r.detectText {
            guard let parsed = PixelCleaningWorkflow.TextDetectionMode.parse(r.detectTextMode) else {
                throw ValidationError(
                    "Invalid --detect-text-mode '\(r.detectTextMode)'. Use 'classify' (default) or 'all'.")
            }
            mode = parsed
        }
        guard let style = PixelRedactor.Style.parse(r.redactStyle, label: r.redactLabel) else {
            throw ValidationError("Invalid --redact-style '\(r.redactStyle)'. Use 'blank', 'label' or 'replace'.")
        }
        var recompressTarget: PixelCleaningWorkflow.Recompress?
        if let raw = r.recompress {
            guard let parsed = PixelCleaningWorkflow.Recompress.parse(raw) else {
                throw ValidationError("Invalid --recompress '\(raw)'. Use 'source' or a dicom-compress codec name.")
            }
            guard r.cleanPixelData || !r.redactRegion.isEmpty else {
                throw ValidationError("--recompress only applies after pixel cleaning; add --clean-pixel-data or --redact-region.")
            }
            recompressTarget = parsed
        }
        return PixelCleaningWorkflow.Options(
            cleanPixelData: r.cleanPixelData, explicitRegions: explicit,
            detectText: mode, ocrAllFrames: r.ocrAllFrames, fillValue: r.redactFill, style: style,
            recompress: recompressTarget)
    }
}
