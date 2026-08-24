import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMAnon: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-anon",
        abstract: "Anonymize DICOM files by removing or replacing patient identifiers",
        discussion: """
            Anonymizes DICOM files according to various profiles to protect patient privacy.
            Supports multiple anonymization strategies and batch processing.
            
            Examples:
              dicom-anon file.dcm --output anon.dcm --profile basic
              dicom-anon file.dcm --output anon.dcm --profile basic --shift-dates 100
              dicom-anon input_dir/ --output anon_dir/ --profile clinical-trial --recursive
              dicom-anon file.dcm --output anon.dcm --remove 0010,0010 --replace 0010,0030=19700101
              dicom-anon file.dcm --profile basic --dry-run
              dicom-anon file.dcm --output anon.dcm --profile basic --audit-log anonymization.log
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to DICOM file or directory")
    var inputPath: String
    
    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String?
    
    @Option(name: .long, help: "Anonymization profile: basic, clinical-trial, research, ps315 (PS3.15 Annex E)")
    var profile: String = "basic"

    // PS3.15 Annex E retention options (only apply to --profile ps315).
    @Flag(name: .long, help: "PS3.15: Retain Longitudinal Temporal Information (keep/shift dates)")
    var retainDates: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Patient Characteristics (age/sex/size/weight)")
    var retainCharacteristics: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Device Identity")
    var retainDevice: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Institution Identity")
    var retainInstitution: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain UIDs (do not regenerate)")
    var retainUids: Bool = false

    @Flag(name: .long, help: "PS3.15: Clean Descriptors (retain free-text rather than remove)")
    var cleanDescriptors: Bool = false

    @Flag(name: .long, help: """
        PS3.15: Clean Pixel Data — blank burned-in identifiers out of the image itself. \
        Chooses the region automatically (declared clinical region, else device template) \
        and REFUSES rather than guessing when it cannot. Records code 113101 and sets \
        Burned In Annotation = NO only when pixels were actually blanked.
        """)
    var cleanPixelData: Bool = false

    @Option(name: .long, help: """
        Region to blank as x,y,width,height (repeatable). Implies --clean-pixel-data \
        and overrides automatic region selection.
        """)
    var redactRegion: [String] = []

    @Option(name: .long, help: "Fill value for blanked pixels (default: 0 = black)")
    var redactFill: Int?

    @Option(name: .long, help: "Number of days to shift dates (preserves intervals)")
    var shiftDates: Int?
    
    @Flag(name: .long, help: "Regenerate UIDs while preserving references")
    var regenerateUids: Bool = false
    
    @Option(name: .long, help: "Tags to remove (format: 0010,0010 or name)")
    var remove: [String] = []
    
    @Option(name: .long, help: "Tags to replace (format: 0010,0010=VALUE)")
    var replace: [String] = []
    
    @Option(name: .long, help: "Tags to keep (preserve from anonymization)")
    var keep: [String] = []
    
    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Preview changes without modifying files")
    var dryRun: Bool = false
    
    @Flag(name: .long, help: "Create backup of original files")
    var backup: Bool = false
    
    @Option(name: .long, help: "Path to audit log file")
    var auditLog: String?
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false

    @Flag(name: .long, help: """
        Proceed even when the pixels may still carry PHI (Burned In Annotation = YES, \
        or overlay planes present). Without this, such files are refused unwritten, \
        because this tool de-identifies metadata only and never redacts pixels.
        """)
    var allowBurnedInPHI: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
            throw AnonymizationError.fileNotFound
        }
        
        // Parse profile
        let anonProfile = try parseProfile()
        
        // Parse custom actions
        let customActions = try parseCustomActions()
        let preserveTags = try parsePreserveTags()
        
        // Create anonymizer
        let anonymizer = Anonymizer(
            profile: anonProfile,
            shiftDates: shiftDates,
            regenerateUIDs: regenerateUids,
            preserveTags: preserveTags,
            customActions: customActions
        )
        
        // Process files
        var results: [AnonymizationResult] = []
        
        if isDirectory.boolValue {
            guard recursive else {
                throw ValidationError("Directory anonymization requires --recursive flag")
            }
            guard let outputPath = output else {
                throw ValidationError("Directory anonymization requires --output directory")
            }
            results = try anonymizeDirectory(
                inputURL: inputURL,
                outputURL: URL(fileURLWithPath: outputPath),
                anonymizer: anonymizer
            )
        } else {
            // Writing back over the input is never implied. Without --output there is
            // nowhere to write, so anonymizing would silently discard its result and
            // still report success — require --output unless this is a --dry-run preview.
            guard dryRun || output != nil else {
                throw ValidationError("Anonymization requires --output (or use --dry-run to preview without writing)")
            }
            let result = try anonymizeFile(
                inputURL: inputURL,
                outputURL: output.map { URL(fileURLWithPath: $0) },
                anonymizer: anonymizer
            )
            results = [result]
        }
        
        // Print summary
        printSummary(results: results)
        
        // Write audit log if requested
        if let auditLogPath = auditLog {
            let auditURL = URL(fileURLWithPath: auditLogPath)
            try anonymizer.writeAuditLog(to: auditURL)
            if verbose {
                print(AnonConsole.auditLogLine(path: auditLogPath))
            }
        }
        
        // Exit with error if any failures
        if results.contains(where: { !$0.success }) {
            throw ExitCode.failure
        }
    }
    
    private func parseProfile() throws -> AnonymizationProfile {
        switch profile.lowercased() {
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
            throw AnonymizationError.invalidProfile
        }
    }
    
    private func parseCustomActions() throws -> [Tag: AnonymizationAction] {
        var actions: [Tag: AnonymizationAction] = [:]
        
        // Parse remove tags
        for tagString in remove {
            let tag = try parseTag(tagString)
            actions[tag] = .remove
        }
        
        // Parse replace tags
        for replaceString in replace {
            let parts = replaceString.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid replace format: \(replaceString). Use TAG=VALUE")
            }
            let tag = try parseTag(String(parts[0]))
            let value = String(parts[1])
            actions[tag] = .replaceWithDummy(value)
        }
        
        return actions
    }
    
    private func parsePreserveTags() throws -> Set<Tag> {
        var tags = Set<Tag>()
        
        for tagString in keep {
            let tag = try parseTag(tagString)
            tags.insert(tag)
        }
        
        return tags
    }
    
    private func parseTag(_ string: String) throws -> Tag {
        guard let tag = Anonymizer.parseFlexibleTag(string) else {
            throw ValidationError("Invalid tag format: \(string)")
        }
        return tag
    }
    
    private func anonymizeDirectory(
        inputURL: URL,
        outputURL: URL,
        anonymizer: Anonymizer
    ) throws -> [AnonymizationResult] {
        // Create output directory
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        guard let fileURLs = FileGatherer.regularFiles(under: inputURL) else {
            throw ValidationError("Failed to enumerate directory: \(inputURL.path)")
        }

        var results: [AnonymizationResult] = []

        for fileURL in fileURLs {
            // Calculate relative path
            guard let relativePath = fileURL.path.replacingOccurrences(
                of: inputURL.path,
                with: ""
            ).dropFirst().nilIfEmpty else { continue }
            
            let outputFileURL = outputURL.appendingPathComponent(relativePath)
            
            // Create intermediate directories
            try FileManager.default.createDirectory(
                at: outputFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            do {
                let result = try anonymizeFile(
                    inputURL: fileURL,
                    outputURL: outputFileURL,
                    anonymizer: anonymizer
                )
                results.append(result)
                
                if verbose {
                    print(AnonConsole.fileSuccessLine(relativePath: String(relativePath)))
                }
            } catch {
                if verbose {
                    print(AnonConsole.fileFailureLine(relativePath: String(relativePath), message: error.localizedDescription))
                }
                results.append(AnonymizationResult(
                    filePath: fileURL.path,
                    success: false,
                    changedTags: [],
                    warnings: [error.localizedDescription]
                ))
            }
        }
        
        return results
    }
    
    private func anonymizeFile(
        inputURL: URL,
        outputURL: URL?,
        anonymizer: Anonymizer
    ) throws -> AnonymizationResult {
        // Read DICOM file
        var fileData = try Data(contentsOf: inputURL)
        var dicomFile = try DICOMFile.read(from: fileData, force: force)

        // --- Pixel cleaning runs FIRST, before any header de-identification. ---
        // The region decision reads Modality / Manufacturer / model, which
        // de-identification removes; planning afterwards would see a scrubbed data set
        // and match nothing. Both CTP and Presidio document this same ordering
        // dependency, so the order here is a correctness requirement, not a preference.
        var pixelOutcome: PixelRedactor.Outcome?
        if cleanPixelData || !redactRegion.isEmpty {
            let editor = PixelEditor(verbose: false)
            let explicit = try redactRegion.map { spec -> PixelRedactionPlan.Region in
                let r = try editor.parseRegion(spec)
                return PixelRedactionPlan.Region(x: r.x, y: r.y, width: r.width, height: r.height)
            }
            let plan = PixelRedactionPlan.plan(for: dicomFile.dataSet, explicitRegions: explicit)
            if let (redacted, outcome) = try PixelRedactor().redact(
                fileData: fileData, plan: plan, fillValue: redactFill) {
                fileData = redacted
                dicomFile = try DICOMFile.read(from: redacted, force: force)
                pixelOutcome = outcome
                if verbose {
                    print(AnonConsole.pixelRedactionLines(outcome: outcome), terminator: "")
                }
            }
        }

        // Anonymize — PS3.15 Annex E engine or legacy profile.
        let anonymizedFile: DICOMFile
        let result: AnonymizationResult
        if profile.lowercased() == "ps315" {
            let options = ConfidentialityProfile.Options(
                retainLongitudinalTemporal: retainDates,
                retainPatientCharacteristics: retainCharacteristics,
                retainDeviceIdentity: retainDevice,
                retainInstitutionIdentity: retainInstitution,
                retainUIDs: retainUids,
                cleanDescriptors: cleanDescriptors,
                dateOffsetDays: shiftDates)
            let (file, res, _) = anonymizer.deidentify(file: dicomFile, options: options)
            // Refuse to emit a file whose pixels may still identify the patient unless
            // the operator explicitly accepts that. Writing it silently is the harmful
            // case: the metadata looks clean, so the file reads as safe to release.
            if !res.warnings.isEmpty && !allowBurnedInPHI {
                throw ValidationError(
                    """
                    Refusing to anonymize \(inputURL.lastPathComponent): the pixel data may \
                    still contain PHI.

                    \(res.warnings.map { "  ⚠️  \($0)" }.joined(separator: "\n"))

                    Without --clean-pixel-data this tool de-identifies the DATASET ONLY, \
                    so burned-in text survives unchanged.

                    Pass --clean-pixel-data to blank it (add --redact-region x,y,w,h if \
                    the automatic region selection cannot resolve this device), or \
                    --allow-burned-in-phi to write the metadata-scrubbed file anyway \
                    (it will be marked Patient Identity Removed = NO).
                    """)
            }
            anonymizedFile = file
            result = AnonymizationResult(
                filePath: inputURL.path, success: res.success,
                changedTags: res.changedTags, warnings: res.warnings)
        } else {
            (anonymizedFile, result) = try anonymizer.anonymize(file: dicomFile, filePath: inputURL.path)
        }
        
        // Write output if not dry-run
        if !dryRun, let outputURL = outputURL {
            // Backup if requested
            if backup {
                let backupURL = outputURL.appendingPathExtension("backup")
                try? FileManager.default.copyItem(at: inputURL, to: backupURL)
            }
            
            // Write anonymized file
            let outputData = try anonymizedFile.write()
            try outputData.write(to: outputURL)
        }
        
        return result
    }
    
    private func printSummary(results: [AnonymizationResult]) {
        print(AnonConsole.summary(
            totalFiles: results.count,
            successful: results.filter { $0.success }.count,
            failed: results.filter { !$0.success }.count,
            dryRun: dryRun,
            warnings: results.flatMap { $0.warnings },
            modifiedTags: Set(results.flatMap { $0.changedTags }.map { "\($0)" }),
            verbose: verbose
        ), terminator: "")
    }
}

struct ValidationError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

// CLI-only error type (the shared DICOMKit `Anonymizer` engine never throws it;
// only the command's argument parsing / file checks do).
enum AnonymizationError: Error, LocalizedError {
    case invalidProfile
    case fileNotFound
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfile:
            return "Invalid anonymization profile"
        case .fileNotFound:
            return "File not found"
        case .writeError(let msg):
            return "Write error: \(msg)"
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}

extension Substring {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : String(self)
    }
}

DICOMAnon.main()
