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
    
    @Option(name: .long, help: "Anonymization profile: basic, clinical-trial, research")
    var profile: String = "basic"
    
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
                print("Audit log written to: \(auditLogPath)")
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
        // Try parsing as hex format (0010,0010) or 00100010
        let cleanString = string.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if cleanString.count == 8, let value = UInt32(cleanString, radix: 16) {
            let group = UInt16((value >> 16) & 0xFFFF)
            let element = UInt16(value & 0xFFFF)
            return Tag(group: group, element: element)
        }
        
        // Try well-known tags by name
        if let tag = tagFromKeyword(string) {
            return tag
        }
        
        throw ValidationError("Invalid tag format: \(string)")
    }
    
    private func tagFromKeyword(_ keyword: String) -> Tag? {
        // Map common keywords to tags
        let keywordMap: [String: Tag] = [
            "PatientName": .patientName,
            "PatientID": .patientID,
            "PatientBirthDate": .patientBirthDate,
            "StudyDate": .studyDate,
            "SeriesDate": .seriesDate,
            "Modality": .modality,
            "StudyDescription": .studyDescription,
            "SeriesDescription": .seriesDescription,
            "StudyInstanceUID": .studyInstanceUID,
            "SeriesInstanceUID": .seriesInstanceUID,
            "SOPInstanceUID": .sopInstanceUID
        ]
        
        return keywordMap[keyword] ?? keywordMap[keyword.lowercased()]
    }
    
    private func anonymizeDirectory(
        inputURL: URL,
        outputURL: URL,
        anonymizer: Anonymizer
    ) throws -> [AnonymizationResult] {
        // Create output directory
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw ValidationError("Failed to enumerate directory: \(inputURL.path)")
        }
        
        var results: [AnonymizationResult] = []
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            
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
                    print("✓ \(relativePath)")
                }
            } catch {
                if verbose {
                    print("✗ \(relativePath): \(error.localizedDescription)")
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
        let fileData = try Data(contentsOf: inputURL)
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        
        // Anonymize
        let (anonymizedFile, result) = try anonymizer.anonymize(file: dicomFile, filePath: inputURL.path)
        
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
        let successful = results.filter { $0.success }.count
        let failed = results.filter { !$0.success }.count
        
        print("\nAnonymization Summary:")
        print("  Total files: \(results.count)")
        print("  Successful: \(successful)")
        print("  Failed: \(failed)")
        
        if dryRun {
            print("  (DRY RUN - no files modified)")
        }
        
        // Show warnings if any
        let allWarnings = results.flatMap { $0.warnings }
        if !allWarnings.isEmpty {
            print("\nWarnings:")
            for warning in allWarnings.prefix(10) {
                print("  ⚠️  \(warning)")
            }
            if allWarnings.count > 10 {
                print("  ... and \(allWarnings.count - 10) more warnings")
            }
        }
        
        // Show changed tags summary if verbose
        if verbose && !results.isEmpty {
            let allChangedTags = Set(results.flatMap { $0.changedTags })
            print("\nModified tags (\(allChangedTags.count)):")
            for tag in allChangedTags.sorted().prefix(20) {
                print("  - \(tag)")
            }
        }
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
