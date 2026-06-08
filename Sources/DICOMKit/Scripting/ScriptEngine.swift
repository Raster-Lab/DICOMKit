import Foundation

// Shared scripting engine for the `dicom-script` CLI and DICOMStudio. Parser,
// validator, template generator, and executor live here. The executor never
// shells out itself — it calls an injected `CommandRunner`, so the library stays
// free of `Process` (the CLI supplies a real runner; a sandboxed app can supply a
// dry-run/no-op runner). Verbose output flows through an injected `log` closure.

// MARK: - Errors

public enum ScriptError: Error, LocalizedError {
    case scriptNotFound(String)
    case parseError(String, Int)
    case invalidVariable(String)
    case invalidCommand(String)
    case executionError(String)
    case conditionError(String)
    case invalidTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path): return "Script not found: \(path)"
        case .parseError(let message, let line): return "Parse error at line \(line): \(message)"
        case .invalidVariable(let varStr): return "Invalid variable format: \(varStr). Use KEY=VALUE"
        case .invalidCommand(let cmd): return "Invalid command: \(cmd)"
        case .executionError(let message): return "Execution error: \(message)"
        case .conditionError(let message): return "Condition error: \(message)"
        case .invalidTemplate(let name): return "Invalid template name: \(name)"
        }
    }
}

// MARK: - Script Models

public enum ScriptCommand {
    case toolCommand(ToolCommand)
    case conditional(ConditionalCommand)
    case pipeline(PipelineCommand)
    case setVariable(String, String)
}

public struct ToolCommand {
    public let tool: String
    public let arguments: [String]
    public let inputVariable: String?
    public let outputVariable: String?
}

public struct ConditionalCommand {
    public let condition: String
    public let thenCommands: [ScriptCommand]
    public let elseCommands: [ScriptCommand]?
}

public struct PipelineCommand {
    public let commands: [ToolCommand]
}

struct ScriptContext {
    var variables: [String: String]
    var logger: ScriptLogger
    var dryRun: Bool
    var parallel: Bool
}

// MARK: - Script Parser

public struct ScriptParser {
    public init() {}

    public func parse(content: String) throws -> [ScriptCommand] {
        var commands: [ScriptCommand] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix("#") {
                i += 1
                continue
            }

            if line.contains("=") && !line.hasPrefix("if ") {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let varName = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let varValue = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    commands.append(.setVariable(varName, varValue))
                    i += 1
                    continue
                }
            }

            if line.hasPrefix("if ") {
                let (conditional, linesConsumed) = try parseConditional(lines: Array(lines), startIndex: i)
                commands.append(.conditional(conditional))
                i += linesConsumed
                continue
            }

            if line.contains("|") {
                let pipeline = try parsePipeline(line: line)
                commands.append(.pipeline(pipeline))
                i += 1
                continue
            }

            let toolCmd = try parseToolCommand(line: line)
            commands.append(.toolCommand(toolCmd))
            i += 1
        }

        return commands
    }

    private func parseToolCommand(line: String) throws -> ToolCommand {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard !parts.isEmpty else {
            throw ScriptError.parseError("Empty command", 0)
        }

        let tool = String(parts[0])
        let arguments = Array(parts[1...]).map { String($0) }

        return ToolCommand(tool: tool, arguments: arguments, inputVariable: nil, outputVariable: nil)
    }

    private func parsePipeline(line: String) throws -> PipelineCommand {
        let commandStrings = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        var commands: [ToolCommand] = []
        for cmdStr in commandStrings {
            let cmd = try parseToolCommand(line: cmdStr)
            commands.append(cmd)
        }
        return PipelineCommand(commands: commands)
    }

    private func parseConditional(lines: [Substring], startIndex: Int) throws -> (ConditionalCommand, Int) {
        let line = String(lines[startIndex]).trimmingCharacters(in: .whitespaces)

        guard line.hasPrefix("if ") else {
            throw ScriptError.parseError("Invalid conditional", startIndex + 1)
        }

        let condition = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        var thenCommands: [ScriptCommand] = []
        var elseCommands: [ScriptCommand]? = nil
        var i = startIndex + 1
        var inElse = false

        while i < lines.count {
            let blockLine = String(lines[i]).trimmingCharacters(in: .whitespaces)

            if blockLine == "else" {
                inElse = true
                i += 1
                continue
            }

            if blockLine == "endif" || blockLine == "fi" {
                i += 1
                break
            }

            if blockLine.isEmpty || blockLine.hasPrefix("#") {
                i += 1
                continue
            }

            let cmd = try parseToolCommand(line: blockLine)
            if inElse {
                if elseCommands == nil { elseCommands = [] }
                elseCommands?.append(.toolCommand(cmd))
            } else {
                thenCommands.append(.toolCommand(cmd))
            }

            i += 1
        }

        let conditional = ConditionalCommand(condition: condition, thenCommands: thenCommands, elseCommands: elseCommands)
        return (conditional, i - startIndex)
    }
}

// MARK: - Script Executor

public struct ScriptExecutor {
    /// Runs a single tool with arguments and returns its combined output + exit
    /// code. The CLI supplies a `Process`-based runner; a sandboxed app supplies a
    /// no-op/dry-run runner (never invoked when `dryRun` is true).
    public typealias CommandRunner = (_ tool: String, _ arguments: [String]) throws -> (output: String, exitCode: Int32)

    private let runCommand: CommandRunner
    private let log: (String) -> Void

    public init(runCommand: @escaping CommandRunner, log: @escaping (String) -> Void = { _ in }) {
        self.runCommand = runCommand
        self.log = log
    }

    public func execute(
        scriptPath: String,
        variables: [String: String],
        parallel: Bool,
        verbose: Bool,
        dryRun: Bool,
        logPath: String?
    ) throws {
        let content = try String(contentsOfFile: scriptPath, encoding: .utf8)
        let parser = ScriptParser()
        let commands = try parser.parse(content: content)

        var logger = ScriptLogger(logPath: logPath, verbose: verbose, emit: log)
        logger.log("Starting script execution: \(scriptPath)")
        logger.log("Variables: \(variables)")

        var context = ScriptContext(variables: variables, logger: logger, dryRun: dryRun, parallel: parallel)

        for command in commands {
            try executeCommand(command, context: &context)
        }

        context.logger.log("Script execution completed successfully")

        if dryRun {
            log("Dry run completed - no commands were actually executed")
        } else {
            log("Script execution completed successfully")
        }
    }

    private func executeCommand(_ command: ScriptCommand, context: inout ScriptContext) throws {
        switch command {
        case .toolCommand(let toolCmd):
            try executeToolCommand(toolCmd, context: &context)
        case .conditional(let condCmd):
            try executeConditional(condCmd, context: &context)
        case .pipeline(let pipeCmd):
            try executePipeline(pipeCmd, context: &context)
        case .setVariable(let name, let value):
            let expandedValue = expandVariables(value, context: context)
            context.variables[name] = expandedValue
            context.logger.log("Set variable: \(name) = \(expandedValue)")
        }
    }

    private func executeToolCommand(_ command: ToolCommand, context: inout ScriptContext) throws {
        let expandedArgs = command.arguments.map { expandVariables($0, context: context) }
        let fullCommand = ([command.tool] + expandedArgs).joined(separator: " ")

        context.logger.log("Executing: \(fullCommand)")

        if context.dryRun {
            context.logger.log("[DRY RUN] Would execute: \(fullCommand)")
            return
        }

        // Run via the injected command runner (no Process in the library itself).
        let result = try runCommand(command.tool, expandedArgs)
        if !result.output.isEmpty {
            context.logger.log("Output: \(result.output)")
        }
        if result.exitCode != 0 {
            throw ScriptError.executionError("Command failed with status \(result.exitCode): \(fullCommand)")
        }
    }

    private func executeConditional(_ command: ConditionalCommand, context: inout ScriptContext) throws {
        let conditionResult = try evaluateCondition(command.condition, context: context)
        context.logger.log("Condition '\(command.condition)' evaluated to: \(conditionResult)")

        if conditionResult {
            for cmd in command.thenCommands {
                try executeCommand(cmd, context: &context)
            }
        } else if let elseCommands = command.elseCommands {
            for cmd in elseCommands {
                try executeCommand(cmd, context: &context)
            }
        }
    }

    private func executePipeline(_ command: PipelineCommand, context: inout ScriptContext) throws {
        context.logger.log("Executing pipeline with \(command.commands.count) commands")
        // Sequential execution (parallel flag is accepted but treated the same as
        // in the original engine).
        for toolCmd in command.commands {
            try executeToolCommand(toolCmd, context: &context)
        }
    }

    private func evaluateCondition(_ condition: String, context: ScriptContext) throws -> Bool {
        let expanded = expandVariables(condition, context: context)

        let parts = expanded.split(separator: " ", omittingEmptySubsequences: true)
        guard !parts.isEmpty else {
            throw ScriptError.conditionError("Empty condition")
        }

        let operatorName = String(parts[0])

        switch operatorName {
        case "exists":
            guard parts.count == 2 else {
                throw ScriptError.conditionError("'exists' requires a path argument")
            }
            return FileManager.default.fileExists(atPath: String(parts[1]))

        case "empty":
            guard parts.count == 2 else {
                throw ScriptError.conditionError("'empty' requires a variable name")
            }
            let varValue = context.variables[String(parts[1])] ?? ""
            return varValue.isEmpty

        case "equals":
            guard parts.count == 3 else {
                throw ScriptError.conditionError("'equals' requires two arguments")
            }
            return String(parts[1]) == String(parts[2])

        default:
            throw ScriptError.conditionError("Unknown operator: \(operatorName)")
        }
    }

    private func expandVariables(_ string: String, context: ScriptContext) -> String {
        var result = string
        for (key, value) in context.variables {
            result = result.replacingOccurrences(of: "${\(key)}", with: value)
            result = result.replacingOccurrences(of: "$\(key)", with: value)
        }
        return result
    }
}

// MARK: - Script Validator

public struct ScriptValidator {
    private let log: (String) -> Void

    public init(log: @escaping (String) -> Void = { _ in }) {
        self.log = log
    }

    public func validate(scriptPath: String, verbose: Bool) throws -> [String] {
        let content = try String(contentsOfFile: scriptPath, encoding: .utf8)
        let parser = ScriptParser()

        var issues: [String] = []

        do {
            let commands = try parser.parse(content: content)

            for (index, command) in commands.enumerated() {
                let commandIssues = validateCommand(command, index: index)
                issues.append(contentsOf: commandIssues)
            }

            if verbose && issues.isEmpty {
                log("Parsed \(commands.count) commands successfully")
            }

        } catch let error as ScriptError {
            issues.append(error.localizedDescription)
        } catch {
            issues.append("Unknown error: \(error.localizedDescription)")
        }

        return issues
    }

    private func validateCommand(_ command: ScriptCommand, index: Int) -> [String] {
        var issues: [String] = []

        switch command {
        case .toolCommand(let toolCmd):
            let knownTools = [
                "dicom-info", "dicom-convert", "dicom-validate", "dicom-anon",
                "dicom-dump", "dicom-query", "dicom-send", "dicom-diff",
                "dicom-retrieve", "dicom-split", "dicom-merge", "dicom-json",
                "dicom-xml", "dicom-pdf", "dicom-image", "dicom-dcmdir",
                "dicom-archive", "dicom-export", "dicom-qr", "dicom-wado",
                "dicom-echo", "dicom-mwl", "dicom-mpps", "dicom-pixedit",
                "dicom-tags", "dicom-uid", "dicom-compress", "dicom-study"
            ]

            if !knownTools.contains(toolCmd.tool) {
                issues.append("Command \(index + 1): Unknown DICOM tool '\(toolCmd.tool)'")
            }

        case .conditional(let condCmd):
            if condCmd.condition.isEmpty {
                issues.append("Command \(index + 1): Empty condition")
            }

            for (subIndex, subCmd) in condCmd.thenCommands.enumerated() {
                let subIssues = validateCommand(subCmd, index: subIndex)
                issues.append(contentsOf: subIssues.map { "Command \(index + 1) (then): \($0)" })
            }

            if let elseCommands = condCmd.elseCommands {
                for (subIndex, subCmd) in elseCommands.enumerated() {
                    let subIssues = validateCommand(subCmd, index: subIndex)
                    issues.append(contentsOf: subIssues.map { "Command \(index + 1) (else): \($0)" })
                }
            }

        case .pipeline(let pipeCmd):
            if pipeCmd.commands.isEmpty {
                issues.append("Command \(index + 1): Empty pipeline")
            }

        case .setVariable(let name, let value):
            if name.isEmpty {
                issues.append("Command \(index + 1): Empty variable name")
            }
            if value.isEmpty {
                issues.append("Command \(index + 1): Empty variable value for '\(name)'")
            }
        }

        return issues
    }
}

// MARK: - Template Generator

public struct TemplateGenerator {
    public init() {}

    public func generate(templateName: String) throws -> String {
        switch templateName.lowercased() {
        case "workflow": return workflowTemplate
        case "pipeline": return pipelineTemplate
        case "query": return queryTemplate
        case "archive": return archiveTemplate
        case "anonymize": return anonymizeTemplate
        default: throw ScriptError.invalidTemplate(templateName)
        }
    }

    private var workflowTemplate: String {
        """
        # DICOM Workflow Script
        # Generated by dicom-script v1.3.5

        # Define variables
        INPUT_DIR=/path/to/input
        OUTPUT_DIR=/path/to/output

        # Validate input files
        dicom-validate ${INPUT_DIR}/*.dcm --level 2

        # Process files
        dicom-convert ${INPUT_DIR}/*.dcm --output ${OUTPUT_DIR} --format png

        # Generate summary
        dicom-study summary ${INPUT_DIR} --format json > ${OUTPUT_DIR}/summary.json
        """
    }

    private var pipelineTemplate: String {
        """
        # DICOM Pipeline Script
        # Generated by dicom-script v1.3.5

        # Pipeline: query -> retrieve -> validate -> anonymize -> archive

        PACS_HOST=pacs.example.com
        PACS_PORT=11112
        PACS_AET=PACS
        LOCAL_AET=WORKSTATION
        PATIENT_ID=12345

        # Query PACS
        dicom-query --host ${PACS_HOST} --port ${PACS_PORT} \\
            --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \\
            --patient-id ${PATIENT_ID} --level STUDY

        # Retrieve studies
        dicom-retrieve --host ${PACS_HOST} --port ${PACS_PORT} \\
            --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \\
            --patient-id ${PATIENT_ID} --output studies/

        # Validate retrieved files
        dicom-validate studies/*.dcm --level 2

        # Anonymize
        dicom-anon studies/*.dcm --profile basic --output anon/

        # Archive
        dicom-archive create archive.db --input anon/
        """
    }

    private var queryTemplate: String {
        """
        # DICOM Query Script
        # Generated by dicom-script v1.3.5

        PACS_HOST=pacs.example.com
        PACS_PORT=11112
        PACS_AET=PACS
        LOCAL_AET=WORKSTATION

        # Query by patient name
        dicom-query --host ${PACS_HOST} --port ${PACS_PORT} \\
            --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \\
            --patient-name "DOE*" --level PATIENT

        # Query by date range
        dicom-query --host ${PACS_HOST} --port ${PACS_PORT} \\
            --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \\
            --study-date-from 20240101 --study-date-to 20241231 \\
            --level STUDY
        """
    }

    private var archiveTemplate: String {
        """
        # DICOM Archive Script
        # Generated by dicom-script v1.3.5

        ARCHIVE_DB=archive.db
        INPUT_DIR=/path/to/dicoms

        # Create archive
        dicom-archive create ${ARCHIVE_DB} --input ${INPUT_DIR}

        # Query archive
        dicom-archive query ${ARCHIVE_DB} --patient-id "12345"

        # Export from archive
        dicom-archive export ${ARCHIVE_DB} --patient-id "12345" --output exported/
        """
    }

    private var anonymizeTemplate: String {
        """
        # DICOM Anonymization Script
        # Generated by dicom-script v1.3.5

        INPUT_DIR=/path/to/input
        OUTPUT_DIR=/path/to/anonymized

        # Anonymize with basic profile
        dicom-anon ${INPUT_DIR}/*.dcm --profile basic --output ${OUTPUT_DIR}

        # Conditional anonymization
        if exists ${INPUT_DIR}/sensitive.dcm
            dicom-anon ${INPUT_DIR}/sensitive.dcm --profile strict --output ${OUTPUT_DIR}
        endif

        # Validate anonymized files
        dicom-validate ${OUTPUT_DIR}/*.dcm --level 2
        """
    }
}

// MARK: - Script Logger

struct ScriptLogger {
    let logPath: String?
    let verbose: Bool
    let emit: (String) -> Void
    private let dateFormatter: DateFormatter

    init(logPath: String?, verbose: Bool, emit: @escaping (String) -> Void) {
        self.logPath = logPath
        self.verbose = verbose
        self.emit = emit
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    mutating func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"

        if verbose {
            emit(logMessage)
        }

        if let logPath = logPath {
            do {
                let fileHandle: FileHandle
                if FileManager.default.fileExists(atPath: logPath) {
                    fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
                    try fileHandle.seekToEnd()
                } else {
                    _ = FileManager.default.createFile(atPath: logPath, contents: nil)
                    fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
                }

                if let data = (logMessage + "\n").data(using: .utf8) {
                    fileHandle.write(data)
                }
                try fileHandle.close()
            } catch {
                emit("Warning: Failed to write to log file: \(error.localizedDescription)")
            }
        }
    }
}
