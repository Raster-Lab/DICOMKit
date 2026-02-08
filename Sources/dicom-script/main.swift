import Foundation
import ArgumentParser

@available(macOS 10.15, *)
struct DICOMScript: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-script",
        abstract: "Execute DICOM workflow scripts and pipelines",
        discussion: """
            Execute workflow scripts written in the DICOM Script Language (DSL).
            Supports pipeline operations, conditional logic, variable substitution,
            parallel execution, and error handling.
            
            Examples:
              dicom-script run workflow.dcmscript
              dicom-script run pipeline.dcmscript --var PATIENT_ID=12345
              dicom-script validate workflow.dcmscript
              dicom-script template workflow > workflow.dcmscript
            """,
        version: "1.3.5",
        subcommands: [Run.self, Validate.self, Template.self]
    )
}

// MARK: - Run Command

@available(macOS 10.15, *)
extension DICOMScript {
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Execute a DICOM workflow script"
        )
        
        @Argument(help: "Script file path")
        var scriptPath: String
        
        @Option(name: .long, parsing: .upToNextOption, help: "Variables in KEY=VALUE format")
        var variables: [String] = []
        
        @Flag(name: .long, help: "Enable parallel execution where possible")
        var parallel: Bool = false
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        @Flag(name: .long, help: "Dry run - show what would be executed")
        var dryRun: Bool = false
        
        @Option(name: .long, help: "Log file path")
        var log: String?
        
        mutating func run() throws {
            guard FileManager.default.fileExists(atPath: scriptPath) else {
                throw ScriptError.scriptNotFound(scriptPath)
            }
            
            let parsedVariables = try parseVariables(variables)
            
            let executor = ScriptExecutor()
            try executor.execute(
                scriptPath: scriptPath,
                variables: parsedVariables,
                parallel: parallel,
                verbose: verbose,
                dryRun: dryRun,
                logPath: log
            )
        }
        
        private func parseVariables(_ vars: [String]) throws -> [String: String] {
            var result: [String: String] = [:]
            for varStr in vars {
                let parts = varStr.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else {
                    throw ScriptError.invalidVariable(varStr)
                }
                result[String(parts[0])] = String(parts[1])
            }
            return result
        }
    }
}

// MARK: - Validate Command

@available(macOS 10.15, *)
extension DICOMScript {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate a DICOM workflow script"
        )
        
        @Argument(help: "Script file path")
        var scriptPath: String
        
        @Flag(name: .shortAndLong, help: "Show verbose validation output")
        var verbose: Bool = false
        
        mutating func run() throws {
            guard FileManager.default.fileExists(atPath: scriptPath) else {
                throw ScriptError.scriptNotFound(scriptPath)
            }
            
            let validator = ScriptValidator()
            let issues = try validator.validate(scriptPath: scriptPath, verbose: verbose)
            
            if issues.isEmpty {
                fprintln("✓ Script is valid")
            } else {
                fprintln("✗ Script has \(issues.count) issue(s):")
                for issue in issues {
                    fprintln("  - \(issue)")
                }
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Template Command

@available(macOS 10.15, *)
extension DICOMScript {
    struct Template: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate workflow script templates"
        )
        
        @Argument(help: "Template name: 'workflow', 'pipeline', 'query', 'archive', 'anonymize'")
        var templateName: String
        
        mutating func run() throws {
            let generator = TemplateGenerator()
            let template = try generator.generate(templateName: templateName)
            print(template)
        }
    }
}

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMScript.main()
