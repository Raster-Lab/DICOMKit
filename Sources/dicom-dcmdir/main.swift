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
        
        // `.inversion` is required by ArgumentParser for a Bool flag whose default is
        // `true` (a plain `@Flag … = true` would always be true and is rejected at
        // validation, breaking the whole `create` command). This keeps recursion ON by
        // default while exposing `--no-recursive` to disable it.
        @Flag(inversion: .prefixedNo, help: "Recursively scan subdirectories (default: on)")
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
            
            // Determine the output DICOMDIR file path. When --output points at a
            // directory (or a trailing-slash path), the DICOMDIR is written INSIDE it;
            // writing onto a directory path otherwise fails ("couldn't be saved in the
            // folder …"). Default: a DICOMDIR inside the input directory.
            let outputPath = DICOMDIRWorkflow.resolvedDICOMDIRPath(output ?? (inputDirectory + "/DICOMDIR"))
            
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
            
            // Build the DICOMDIR via the shared DICOMDIRWorkflow — the single source
            // of truth shared with DICOMStudio's CLI Workshop (file discovery, the
            // build loop, and the relative-path computation), so the produced
            // DICOMDIR cannot drift between the two surfaces.
            let result: DICOMDIRWorkflow.CreateResult
            do {
                result = try DICOMDIRWorkflow.buildDirectory(
                    fromFilesIn: inputURL, recursive: recursive, strict: strict,
                    fileSetID: fsID, profile: dicomProfile,
                    verbose: verbose, progress: { print($0, terminator: "") })
            } catch DICOMDIRWorkflow.WorkflowError.noDICOMFiles {
                throw ValidationError("No DICOM files found in directory: \(inputDirectory)")
            }

            // Write to file (creating intermediate directories so a fresh --output
            // path doesn't fail on a missing parent).
            let outputFileURL = URL(fileURLWithPath: outputPath)
            try? FileManager.default.createDirectory(
                at: outputFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try DICOMDIRWriter.write(result.directory, to: outputFileURL)

            // Print the shared summary block.
            print(DICOMDIRWorkflow.renderCreateSummary(result, outputPath: outputPath), terminator: "")
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
            // Accept either a DICOMDIR file or the media DIRECTORY that contains it.
            let resolvedPath = DICOMDIRWorkflow.resolvedDICOMDIRPath(dicomdirPath)
            let fileURL = URL(fileURLWithPath: resolvedPath)

            guard FileManager.default.fileExists(atPath: resolvedPath) else {
                throw ValidationError(resolvedPath == dicomdirPath
                    ? "DICOMDIR file not found: \(dicomdirPath)"
                    : "No DICOMDIR found in directory: \(dicomdirPath)")
            }

            print("Validating DICOMDIR: \(resolvedPath)")
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
            } catch {
                print("❌ Validation failed: \(error.localizedDescription)")
                throw ExitCode(1)
            }

            // Render the shared validation report — the single source of truth
            // shared with DICOMStudio's CLI Workshop.
            print(DICOMDIRWorkflow.renderValidationReport(directory, detailed: detailed), terminator: "")
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
            // Accept either a DICOMDIR file or the media DIRECTORY that contains it.
            let resolvedPath = DICOMDIRWorkflow.resolvedDICOMDIRPath(dicomdirPath)
            let fileURL = URL(fileURLWithPath: resolvedPath)

            guard FileManager.default.fileExists(atPath: resolvedPath) else {
                throw ValidationError(resolvedPath == dicomdirPath
                    ? "DICOMDIR file not found: \(dicomdirPath)"
                    : "No DICOMDIR found in directory: \(dicomdirPath)")
            }

            // Read DICOMDIR
            let directory: DICOMDirectory
            do {
                directory = try DICOMDIRReader.read(from: fileURL)
            } catch {
                print("Error reading DICOMDIR: \(error.localizedDescription)")
                throw ExitCode(1)
            }
            
            // Render via the shared DICOMDIRDumpFormatter (single source of truth
            // shared with DICOMStudio's CLI Workshop). Empty terminator so the
            // formatter's own trailing newline is not doubled.
            guard let rendered = DICOMDIRDumpFormatter.render(directory, format: format, verbose: verbose) else {
                throw ValidationError("Invalid format: \(format). Use tree, json, or text")
            }
            print(rendered, terminator: "")
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
