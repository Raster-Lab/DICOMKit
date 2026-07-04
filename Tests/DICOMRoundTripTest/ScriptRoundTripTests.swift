// ScriptRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-script` tool.
// Tests call the DICOMKit scripting library directly (ScriptExecutor / ScriptValidator /
// TemplateGenerator) with an INJECTED mock command runner — never spawning any CLI process.
// Oracles are semantic facts about parsing, variable substitution, ordered execution,
// fail-fast, dry-run, and validation — verified against Sources/DICOMKit/Scripting/ScriptEngine.swift.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class ScriptRoundTripTests: XCTestCase {

    // MARK: - Private helpers (class-scoped, never global)

    /// Writes a script body to a temp `.dcmscript` file and returns its path.
    private func writeScript(_ body: String, name: String = "rt.dcmscript") throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMScriptRT-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// A recording command runner: appends every (tool, args) call and returns a fixed result.
    private final class Recorder {
        private(set) var calls: [(tool: String, args: [String])] = []
        var runner: ScriptExecutor.CommandRunner {
            { [weak self] tool, args in
                self?.calls.append((tool, args))
                return ("", 0)
            }
        }
    }

    // MARK: - Oracle: variable substitution replaces ${VAR}/$VAR with the injected value

    func testVariableSubstitutionExpandsInjectedVariable() throws {
        // Script references ${PATIENT_ID} but never assigns it; the value is injected
        // via the executor's `variables` map (models a CLI --var override).
        let body = "dicom-info /data/${PATIENT_ID}/scan.dcm"
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path,
            variables: ["PATIENT_ID": "12345"],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: exactly one call to dicom-info whose argument contains the substituted
        // value and no longer contains the placeholder token.
        XCTAssertEqual(rec.calls.count, 1)
        XCTAssertEqual(rec.calls.first?.tool, "dicom-info")
        let joined = rec.calls.first?.args.joined(separator: " ") ?? ""
        XCTAssertTrue(joined.contains("12345"), "expected substituted value, got \(joined)")
        XCTAssertFalse(joined.contains("${PATIENT_ID}"), "placeholder must be expanded")
        XCTAssertFalse(joined.contains("$PATIENT_ID"), "placeholder must be expanded")
    }

    // MARK: - Oracle: injected variable overrides / seeds substitution ($VAR short form)

    func testVariableOverrideShortFormExpands() throws {
        // Uses the $VAR (no-brace) form; injected ENV=production must appear in the call.
        let body = "dicom-info --env $ENV"
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path,
            variables: ["ENV": "production"],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        XCTAssertEqual(rec.calls.count, 1)
        XCTAssertTrue(rec.calls.first?.args.contains("production") ?? false)
        XCTAssertFalse(rec.calls.first?.args.contains("$ENV") ?? true)
    }

    // MARK: - Oracle: steps execute in file order

    func testStepsExecuteInOrder() throws {
        let body = """
        dicom-validate a.dcm
        dicom-info b.dcm
        dicom-dump c.dcm
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: call log preserves the order the steps appear in the script.
        XCTAssertEqual(rec.calls.map { $0.tool },
                       ["dicom-validate", "dicom-info", "dicom-dump"])
    }

    // MARK: - Oracle: a failing step (non-zero exit) stops execution; later steps never run

    func testStepFailureStopsExecution() throws {
        let body = """
        dicom-info step1.dcm
        dicom-info step2.dcm
        dicom-info step3.dcm
        """
        let path = try writeScript(body)

        var observed: [String] = []
        // Runner fails (exit 2) on the 2nd invocation.
        let runner: ScriptExecutor.CommandRunner = { tool, args in
            observed.append(args.first ?? "")
            let code: Int32 = observed.count == 2 ? 2 : 0
            return ("", code)
        }
        let executor = ScriptExecutor(runCommand: runner)

        // Oracle: executor throws when a command returns non-zero, and the 3rd step
        // is never reached (only 2 invocations recorded).
        XCTAssertThrowsError(try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil))
        XCTAssertEqual(observed.count, 2, "execution must stop at the failing step")
        XCTAssertFalse(observed.contains("step3.dcm"), "step after failure must not run")
    }

    // MARK: - Oracle: a throwing runner propagates and halts execution

    func testRunnerThrowHalts() throws {
        let body = """
        dicom-info one.dcm
        dicom-info two.dcm
        """
        let path = try writeScript(body)
        struct Boom: Error {}
        var count = 0
        let runner: ScriptExecutor.CommandRunner = { _, _ in
            count += 1
            throw Boom()
        }
        let executor = ScriptExecutor(runCommand: runner)

        XCTAssertThrowsError(try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil))
        // Oracle: the first throwing call halts; the second step is never attempted.
        XCTAssertEqual(count, 1)
    }

    // MARK: - Oracle: --dry-run never invokes the command runner

    func testDryRunExecutesNoCommands() throws {
        let body = """
        dicom-info a.dcm
        dicom-convert a.dcm --format png
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: true, logPath: nil)

        // Oracle: with dryRun the runner is never called.
        XCTAssertTrue(rec.calls.isEmpty)
    }

    // MARK: - Oracle: local SET-VARIABLE line drives later substitution

    func testSetVariableLineSubstitutedInLaterCommand() throws {
        // `KEY=VALUE` assigns a variable; a later command referencing it must expand.
        let body = """
        PATIENT_ID=99887
        dicom-info /data/${PATIENT_ID}.dcm
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: assignment line is not a tool call; only the dicom-info runs, with the
        // assigned value substituted.
        XCTAssertEqual(rec.calls.count, 1)
        XCTAssertTrue(rec.calls.first?.args.joined().contains("99887") ?? false)
    }

    // MARK: - Oracle: comments and blank lines are skipped (no tool calls)

    func testCommentsAndBlankLinesSkipped() throws {
        let body = """
        # this is a comment
        \n
        # another comment
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: a script of only comments/blanks yields zero tool invocations.
        XCTAssertTrue(rec.calls.isEmpty)
    }

    // MARK: - Oracle: pipeline runs each stage as a sequential tool call

    func testPipelineExecutesEachStage() throws {
        let body = "dicom-info a.dcm | dicom-convert a.dcm --format png"
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: both pipeline stages invoke the runner, in order.
        XCTAssertEqual(rec.calls.map { $0.tool }, ["dicom-info", "dicom-convert"])
    }

    // MARK: - Oracle: conditional `equals` true branch runs then-commands

    func testConditionalEqualsTrueRunsThenBranch() throws {
        let body = """
        if equals go go
        dicom-info then.dcm
        else
        dicom-info else.dcm
        endif
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: `equals go go` is true → only the then-branch command executes.
        XCTAssertEqual(rec.calls.count, 1)
        XCTAssertEqual(rec.calls.first?.args.first, "then.dcm")
    }

    // MARK: - Oracle: conditional `equals` false branch runs else-commands

    func testConditionalEqualsFalseRunsElseBranch() throws {
        let body = """
        if equals a b
        dicom-info then.dcm
        else
        dicom-info else.dcm
        endif
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: nil)

        // Oracle: `equals a b` is false → only the else-branch command executes.
        XCTAssertEqual(rec.calls.count, 1)
        XCTAssertEqual(rec.calls.first?.args.first, "else.dcm")
    }

    // MARK: - Oracle: validate — a well-formed script (all known tools) has no issues

    func testValidateWellFormedScriptNoIssues() throws {
        let body = """
        # valid
        INPUT=/tmp/x.dcm
        dicom-validate ${INPUT} --level 2
        dicom-info ${INPUT}
        """
        let path = try writeScript(body)
        let validator = ScriptValidator()

        let issues = try validator.validate(scriptPath: path, verbose: false)

        // Oracle: every referenced tool is in the known-tools list → no issues.
        XCTAssertTrue(issues.isEmpty, "unexpected issues: \(issues)")
    }

    // MARK: - Oracle: validate — an unknown tool is flagged with its name

    func testValidateUnknownToolFlagged() throws {
        let body = "not-a-real-tool foo.dcm"
        let path = try writeScript(body)
        let validator = ScriptValidator()

        let issues = try validator.validate(scriptPath: path, verbose: false)

        // Oracle: unknown tool produces exactly one issue naming the bad tool.
        XCTAssertEqual(issues.count, 1)
        XCTAssertTrue(issues.first?.contains("not-a-real-tool") ?? false,
                      "issue should name the unknown tool: \(issues)")
    }

    // MARK: - Oracle: validate — empty variable value is flagged

    func testValidateEmptyVariableValueFlagged() throws {
        // `KEY=` (empty value) is a setVariable with an empty value → flagged.
        let body = "MYVAR="
        let path = try writeScript(body)
        let validator = ScriptValidator()

        let issues = try validator.validate(scriptPath: path, verbose: false)

        // Oracle: at least one issue is reported for the empty variable value.
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.contains("MYVAR") || $0.lowercased().contains("value") },
                      "issue should reference the empty value: \(issues)")
    }

    // MARK: - Oracle: template generation is non-empty and re-validates cleanly

    func testTemplateGeneratesAndRevalidatesCleanly() throws {
        let generator = TemplateGenerator()
        for name in ["workflow", "pipeline", "query", "archive", "anonymize"] {
            let template = try generator.generate(templateName: name)

            // Oracle 1: generated template is non-empty and references a real DICOM tool.
            XCTAssertFalse(template.isEmpty, "\(name) template empty")
            XCTAssertTrue(template.contains("dicom-"), "\(name) template lacks a dicom-* command")

            // Oracle 2: round-trip — writing the template to disk and validating it
            // produces no issues (all tools known, conditions/variables non-empty).
            let path = try writeScript(template, name: "\(name).dcmscript")
            let issues = try ScriptValidator().validate(scriptPath: path, verbose: false)
            XCTAssertTrue(issues.isEmpty, "\(name) template failed re-validation: \(issues)")
        }
    }

    // MARK: - Oracle: template generation is case-insensitive on the name

    func testTemplateNameCaseInsensitive() throws {
        let generator = TemplateGenerator()
        // Source lowercases the name before matching.
        let lower = try generator.generate(templateName: "workflow")
        let upper = try generator.generate(templateName: "WORKFLOW")
        // Oracle: same content regardless of case.
        XCTAssertEqual(lower, upper)
    }

    // MARK: - Oracle: unknown template name throws

    func testUnknownTemplateThrows() {
        let generator = TemplateGenerator()
        // Oracle: an unrecognized template name throws (ScriptError.invalidTemplate).
        XCTAssertThrowsError(try generator.generate(templateName: "does-not-exist"))
    }

    // MARK: - Oracle: --parallel is currently inert but must still run every step

    // Characterization oracle: the `parallel` flag is accepted but currently inert —
    // ScriptExecutor runs steps sequentially regardless (ScriptEngine.executePipeline:
    // "parallel flag is accepted but treated the same"). This locks that parallel:true
    // still executes every step exactly once (completeness). It deliberately does NOT
    // assert execution order, so a future real-parallel implementation stays green here.
    func testParallelFlagExecutesEveryStepOnce() throws {
        let body = """
        dicom-info a.dcm
        dicom-validate b.dcm
        dicom-dump c.dcm
        """
        let path = try writeScript(body)
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: true, verbose: false, dryRun: false, logPath: nil)

        XCTAssertEqual(rec.calls.count, 3, "every step must run exactly once under --parallel")
        XCTAssertEqual(Set(rec.calls.map { $0.tool }),
                       ["dicom-info", "dicom-validate", "dicom-dump"])
    }

    // MARK: - Oracle: --parallel runs a pipeline's commands concurrently with ordered output

    // A pipeline's commands are independent by construction (no variable writes can
    // occur between them), so --parallel executes them concurrently and replays
    // their log lines in source order. Oracle: (a) both commands rendezvous — each
    // observes the other running before returning, proving overlap; (b) every
    // command runs exactly once; (c) the verbose log preserves source order.
    func testParallelPipelineRunsConcurrentlyWithOrderedOutput() throws {
        let body = "dicom-info a.dcm | dicom-validate b.dcm"
        let path = try writeScript(body)

        // Thread-safe recorder + two-way rendezvous with a generous timeout so a
        // regression to sequential execution fails fast instead of deadlocking.
        let lock = NSLock()
        var tools: [String] = []
        var rendezvousOK = true
        let firstArrived = DispatchSemaphore(value: 0)
        let secondArrived = DispatchSemaphore(value: 0)
        let runner: ScriptExecutor.CommandRunner = { tool, _ in
            lock.lock(); tools.append(tool); let arrivalIndex = tools.count; lock.unlock()
            if arrivalIndex == 1 {
                firstArrived.signal()
                if secondArrived.wait(timeout: .now() + 10) == .timedOut {
                    lock.lock(); rendezvousOK = false; lock.unlock()
                }
            } else {
                secondArrived.signal()
                if firstArrived.wait(timeout: .now() + 10) == .timedOut {
                    lock.lock(); rendezvousOK = false; lock.unlock()
                }
            }
            return ("", 0)
        }

        var logLines: [String] = []
        let executor = ScriptExecutor(runCommand: runner, log: { logLines.append($0) })
        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: true, verbose: true, dryRun: false, logPath: nil)

        XCTAssertTrue(rendezvousOK, "pipeline commands must overlap under --parallel (rendezvous timed out)")
        XCTAssertEqual(tools.count, 2, "each pipeline command runs exactly once")
        XCTAssertEqual(Set(tools), ["dicom-info", "dicom-validate"])

        // Output replay preserves SOURCE order regardless of completion order.
        // (ScriptLogger may prefix each line, so match by substring.)
        let executing = logLines.filter { $0.contains("Executing: dicom-") }
        XCTAssertEqual(executing.count, 2, "two Executing lines expected, log: \(logLines)")
        guard executing.count == 2 else { return }
        XCTAssertTrue(executing[0].contains("dicom-info"), "source-order replay: dicom-info first, got \(executing)")
        XCTAssertTrue(executing[1].contains("dicom-validate"), "source-order replay: dicom-validate second")
    }

    // MARK: - Oracle: --parallel pipeline surfaces a command failure

    func testParallelPipelineFailurePropagates() throws {
        let body = "dicom-info ok.dcm | dicom-validate bad.dcm"
        let path = try writeScript(body)
        let lock = NSLock()
        var count = 0
        let runner: ScriptExecutor.CommandRunner = { tool, _ in
            lock.lock(); count += 1; lock.unlock()
            return tool == "dicom-validate" ? ("boom", 3) : ("", 0)
        }
        let executor = ScriptExecutor(runCommand: runner)
        XCTAssertThrowsError(try executor.execute(
            scriptPath: path, variables: [:],
            parallel: true, verbose: false, dryRun: false, logPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("status 3"), "failure exit code must surface, got \(error)")
        }
        XCTAssertEqual(count, 2, "both commands still run (no early cancel inside one batch)")
    }

    // MARK: - Oracle: --log writes an execution log file

    // Oracle: passing a logPath makes the executor persist a log that records each
    // executed command; the file exists and names the tools that ran.
    func testLogPathWritesExecutionLog() throws {
        let body = """
        dicom-info a.dcm
        dicom-validate b.dcm
        """
        let path = try writeScript(body)
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMScriptRT-\(UUID().uuidString).log")
        let rec = Recorder()
        let executor = ScriptExecutor(runCommand: rec.runner)

        try executor.execute(
            scriptPath: path, variables: [:],
            parallel: false, verbose: false, dryRun: false, logPath: logURL.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path),
                      "logPath must produce a log file")
        let log = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(log.contains("dicom-info"), "log must record executed commands")
        XCTAssertTrue(log.contains("dicom-validate"))
    }
}

