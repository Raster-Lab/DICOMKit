import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMDCMDIR: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-dcmdir",
        abstract: "DICOMDIR management tool for media storage directories",
        discussion: """
            Create, update, validate, and manage DICOMDIR files for CD/DVD/USB media.
            
            DICOMDIR is a special DICOM file that provides an index of all DICOM files
            on removable media, enabling efficient browsing without reading all files.
            
            Examples:
              # Create DICOMDIR for a directory of DICOM files
              dicom-dcmdir create study_folder/ --output DICOMDIR
              
              # Validate an existing DICOMDIR
              dicom-dcmdir validate /media/cdrom/DICOMDIR
              
              # Display DICOMDIR structure
              dicom-dcmdir dump DICOMDIR --format tree
              
              # Update DICOMDIR with new files
              dicom-dcmdir update DICOMDIR --add new_series/
            """,
        version: "1.2.0",
        subcommands: [
            Create.self,
            Validate.self,
            Dump.self,
            Update.self
        ]
    )
}

// MARK: - Create Subcommand

extension DICOMDCMDIR {
    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a DICOMDIR from a directory of DICOM files"
        )
        
        @Argument(help: "Directory containing DICOM files")
        var inputDirectory: String
        
        @Option(name: .shortAndLong, help: "Output DICOMDIR path (default: DICOMDIR in input directory)")
        var output: String?
        
        @Option(name: .long, help: "File-set ID (default: derived from directory name)")
        var fileSetID: String?
        
        @Option(name: .long, help: "Application profile (STD-GEN-CD, STD-GEN-DVD, STD-GEN-USB)")
        var profile: String = "STD-GEN-CD"
        
        @Flag(name: .long, help: "Recursive scan of subdirectories")
        var recursive: Bool = true
        
        @Flag(name: .long, help: "Include only valid DICOM files")
        var strict: Bool = false
        
        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false
        
        mutating func run() throws {
            let inputURL = URL(fileURLWithPath: inputDirectory)
            
            guard FileManager.default.fileExists(atPath: inputDirectory) else {
                throw ValidationError("Input directory not found: \(inputDirectory)")
            }
            
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: inputDirectory, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ValidationError("Input path is not a directory: \(inputDirectory)")
            }
            
            // Determine output path
            let outputPath: String
            if let output = output {
                outputPath = output
            } else {
                outputPath = inputDirectory + "/DICOMDIR"
            }
            
            // Determine file-set ID
            let fsID: String
            if let id = fileSetID {
                fsID = id
            } else {
                fsID = inputURL.lastPathComponent
            }
            
            // Parse profile
            guard let dicomProfile = DICOMDIRProfile(rawValue: profile) else {
                throw ValidationError("Invalid profile: \(profile). Use STD-GEN-CD, STD-GEN-DVD, or STD-GEN-USB")
            }
            
            if verbose {
                print("Creating DICOMDIR...")
                print("  Input directory: \(inputDirectory)")
                print("  Output file: \(outputPath)")
                print("  File-set ID: \(fsID)")
                print("  Profile: \(profile)")
                print("  Recursive: \(recursive)")
                print("")
            }
            
            // Create DICOMDIR builder
            var builder = DICOMDirectory.Builder(fileSetID: fsID, profile: dicomProfile)
            
            // Find all DICOM files
            let dicomFiles = try findDICOMFiles(in: inputURL, recursive: recursive, verbose: verbose)
            
            if dicomFiles.isEmpty {
                throw ValidationError("No DICOM files found in directory: \(inputDirectory)")
            }
            
            if verbose {
                print("Found \(dicomFiles.count) DICOM files")
                print("")
            }
            
            // Add files to builder
            var successCount = 0
            var failureCount = 0
            
            for (index, fileURL) in dicomFiles.enumerated() {
                if verbose {
                    print("[\(index + 1)/\(dicomFiles.count)] Processing \(fileURL.lastPathComponent)...")
                }
                
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let dicomFile = try DICOMFile.read(from: fileData, force: !strict)
                    
                    // Calculate relative path from input directory to this file
                    let relativePath = fileURL.path.replacingOccurrences(of: inputURL.path + "/", with: "")
                    let pathComponents = relativePath.components(separatedBy: "/")
                    
                    try builder.addFile(dicomFile, relativePath: pathComponents)
                    successCount += 1
                } catch {
                    failureCount += 1
                    if verbose {
                        print("  ⚠️  Failed: \(error.localizedDescription)")
                    }
                }
            }
            
            // Build DICOMDIR
            let directory = builder.build()
            
            // Write to file
            try DICOMDIRWriter.write(directory, to: URL(fileURLWithPath: outputPath))
            
            // Print summary
            print("")
            print("✅ DICOMDIR created successfully")
            print("")
            print("Summary:")
            print("  Files processed: \(successCount)/\(dicomFiles.count)")
            if failureCount > 0 {
                print("  Failed: \(failureCount)")
            }
            
            let stats = directory.statistics()
            print("  Patients: \(stats.patientCount)")
            print("  Studies: \(stats.studyCount)")
            print("  Series: \(stats.seriesCount)")
            print("  Images: \(stats.imageCount)")
            print("")
            print("Output: \(outputPath)")
        }
        
        private func findDICOMFiles(in directory: URL, recursive: Bool, verbose: Bool) throws -> [URL] {
            var files: [URL] = []
            
            let fileManager = FileManager.default
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
            
            if recursive {
                guard let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles]
                ) else {
                    throw ValidationError("Cannot enumerate directory: \(directory.path)")
                }
                
                for case let fileURL as URL in enumerator {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if resourceValues.isRegularFile == true {
                        // Skip DICOMDIR files
                        if fileURL.lastPathComponent == "DICOMDIR" {
                            continue
                        }
                        
                        files.append(fileURL)
                    }
                }
            } else {
                let contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles]
                )
                
                for fileURL in contents {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if resourceValues.isRegularFile == true {
                        // Skip DICOMDIR files
                        if fileURL.lastPathComponent == "DICOMDIR" {
                            continue
                        }
                        
                        files.append(fileURL)
                    }
                }
            }
            
            return files.sorted { $0.path < $1.path }
        }
    }
}

// MARK: - Validate Subcommand

extension DICOMDCMDIR {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "Validate a DICOMDIR file"
        )
        
        @Argument(help: "Path to DICOMDIR file")
        var dicomdirPath: String
        
        @Flag(name: .long, help: "Check if referenced files exist")
        var checkFiles: Bool = false
        
        @Flag(name: .long, help: "Detailed validation output")
        var detailed: Bool = false
        
        mutating func run() throws {
            let fileURL = URL(fileURLWithPath: dicomdirPath)
            
            guard FileManager.default.fileExists(atPath: dicomdirPath) else {
                throw ValidationError("DICOMDIR file not found: \(dicomdirPath)")
            }
            
            print("Validating DICOMDIR: \(dicomdirPath)")
            print("")
            
            // Read DICOMDIR
            let directory: DICOMDirectory
            do {
                directory = try DICOMDIRReader.read(from: fileURL)
            } catch {
                print("❌ Failed to read DICOMDIR: \(error.localizedDescription)")
                throw ExitCode(1)
            }
            
            // Validate structure
            do {
                try directory.validate(checkFileExistence: checkFiles)
                print("✅ DICOMDIR structure is valid")
            } catch {
                print("❌ Validation failed: \(error.localizedDescription)")
                throw ExitCode(1)
            }
            
            // Print statistics
            print("")
            print("Statistics:")
            let stats = directory.statistics()
            print("  Patients: \(stats.patientCount)")
            print("  Studies: \(stats.studyCount)")
            print("  Series: \(stats.seriesCount)")
            print("  Images: \(stats.imageCount)")
            print("  Total records: \(stats.totalRecordCount)")
            print("  Active records: \(stats.activeRecordCount)")
            print("  Inactive records: \(stats.inactiveRecordCount)")
            print("")
            print("File-set:")
            print("  ID: \(directory.fileSetID.isEmpty ? "<none>" : directory.fileSetID)")
            print("  Profile: \(directory.profile.rawValue)")
            print("  Consistent: \(directory.isConsistent ? "Yes" : "No")")
            
            if detailed {
                print("")
                print("Records by type:")
                let allRecords = directory.allRecords()
                let recordTypes = Set(allRecords.map { $0.recordType })
                for recordType in recordTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                    let count = allRecords.filter { $0.recordType == recordType }.count
                    print("  \(recordType.rawValue): \(count)")
                }
            }
            
            print("")
            print("✅ Validation complete")
        }
    }
}

// MARK: - Dump Subcommand

extension DICOMDCMDIR {
    struct Dump: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dump",
            abstract: "Display DICOMDIR structure"
        )
        
        @Argument(help: "Path to DICOMDIR file")
        var dicomdirPath: String
        
        @Option(name: .shortAndLong, help: "Output format: tree, json, text")
        var format: String = "tree"
        
        @Flag(name: .long, help: "Show all attributes for each record")
        var verbose: Bool = false
        
        mutating func run() throws {
            let fileURL = URL(fileURLWithPath: dicomdirPath)
            
            guard FileManager.default.fileExists(atPath: dicomdirPath) else {
                throw ValidationError("DICOMDIR file not found: \(dicomdirPath)")
            }
            
            // Read DICOMDIR
            let directory: DICOMDirectory
            do {
                directory = try DICOMDIRReader.read(from: fileURL)
            } catch {
                print("Error reading DICOMDIR: \(error.localizedDescription)")
                throw ExitCode(1)
            }
            
            // Output based on format
            switch format.lowercased() {
            case "tree":
                printTree(directory, verbose: verbose)
            case "json":
                printJSON(directory)
            case "text":
                printText(directory, verbose: verbose)
            default:
                throw ValidationError("Invalid format: \(format). Use tree, json, or text")
            }
        }
        
        private func printTree(_ directory: DICOMDirectory, verbose: Bool) {
            print("DICOMDIR: \(directory.fileSetID)")
            print("├─ Profile: \(directory.profile.rawValue)")
            print("├─ Consistent: \(directory.isConsistent)")
            print("└─ Records:")
            
            for (index, patient) in directory.rootRecords.enumerated() {
                let isLast = index == directory.rootRecords.count - 1
                printRecord(patient, prefix: isLast ? "    " : "│   ", isLast: true, verbose: verbose)
            }
        }
        
        private func printRecord(_ record: DirectoryRecord, prefix: String, isLast: Bool, verbose: Bool) {
            let connector = isLast ? "└── " : "├── "
            let name = formatRecordName(record)
            print("\(prefix)\(connector)\(name)")
            
            if verbose {
                // Show attributes
                for (tag, element) in record.attributes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    if let stringValue = element.stringValue {
                        let attrPrefix = isLast ? "    " : "│   "
                        print("\(prefix)\(attrPrefix)    \(tag): \(stringValue)")
                    }
                }
            }
            
            // Print children
            let childPrefix = prefix + (isLast ? "    " : "│   ")
            for (index, child) in record.children.enumerated() {
                let childIsLast = index == record.children.count - 1
                printRecord(child, prefix: childPrefix, isLast: childIsLast, verbose: verbose)
            }
        }
        
        private func formatRecordName(_ record: DirectoryRecord) -> String {
            var name = record.recordType.rawValue
            
            switch record.recordType {
            case .patient:
                if let patientName = record.attribute(for: .patientName)?.stringValue {
                    name += " - \(patientName)"
                }
                if let patientID = record.attribute(for: .patientID)?.stringValue {
                    name += " (ID: \(patientID))"
                }
            case .study:
                if let studyDesc = record.attribute(for: .studyDescription)?.stringValue {
                    name += " - \(studyDesc)"
                }
                if let studyDate = record.attribute(for: .studyDate)?.stringValue {
                    name += " [\(studyDate)]"
                }
            case .series:
                if let modality = record.attribute(for: .modality)?.stringValue {
                    name += " - \(modality)"
                }
                if let seriesDesc = record.attribute(for: .seriesDescription)?.stringValue {
                    name += " - \(seriesDesc)"
                }
            case .image:
                if let instanceNum = record.attribute(for: .instanceNumber)?.stringValue {
                    name += " #\(instanceNum)"
                }
                if let filePath = record.referencedFilePath() {
                    name += " (\(filePath))"
                }
            default:
                break
            }
            
            return name
        }
        
        private func printJSON(_ directory: DICOMDirectory) {
            // Simple JSON representation
            print("{")
            print("  \"fileSetID\": \"\(directory.fileSetID)\",")
            print("  \"profile\": \"\(directory.profile.rawValue)\",")
            print("  \"isConsistent\": \(directory.isConsistent),")
            
            let stats = directory.statistics()
            print("  \"statistics\": {")
            print("    \"patients\": \(stats.patientCount),")
            print("    \"studies\": \(stats.studyCount),")
            print("    \"series\": \(stats.seriesCount),")
            print("    \"images\": \(stats.imageCount)")
            print("  },")
            print("  \"recordCount\": \(stats.totalRecordCount)")
            print("}")
        }
        
        private func printText(_ directory: DICOMDirectory, verbose: Bool) {
            print("DICOMDIR Information")
            print("====================")
            print("")
            print("File-set ID: \(directory.fileSetID.isEmpty ? "<none>" : directory.fileSetID)")
            print("Profile: \(directory.profile.rawValue)")
            print("Consistent: \(directory.isConsistent)")
            print("")
            
            let stats = directory.statistics()
            print("Statistics:")
            print("  Patients: \(stats.patientCount)")
            print("  Studies: \(stats.studyCount)")
            print("  Series: \(stats.seriesCount)")
            print("  Images: \(stats.imageCount)")
            print("  Total records: \(stats.totalRecordCount)")
            print("")
            
            if verbose {
                print("All Records:")
                print("------------")
                for record in directory.allRecords() {
                    print("")
                    print("Type: \(record.recordType.rawValue)")
                    if let filePath = record.referencedFilePath() {
                        print("File: \(filePath)")
                    }
                    for (tag, element) in record.attributes {
                        if let value = element.stringValue {
                            print("  \(tag): \(value)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Update Subcommand

extension DICOMDCMDIR {
    struct Update: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update an existing DICOMDIR with new files"
        )
        
        @Argument(help: "Path to existing DICOMDIR file")
        var dicomdirPath: String
        
        @Option(name: .long, help: "Directory with new DICOM files to add")
        var add: String?
        
        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false
        
        mutating func run() throws {
            print("⚠️  Update functionality not yet implemented")
            print("")
            print("To update a DICOMDIR:")
            print("  1. Extract its structure")
            print("  2. Add new files")
            print("  3. Recreate the DICOMDIR")
            print("")
            print("For now, use 'dicom-dcmdir create' to recreate from scratch.")
            throw ExitCode(1)
        }
    }
}

DICOMDCMDIR.main()
