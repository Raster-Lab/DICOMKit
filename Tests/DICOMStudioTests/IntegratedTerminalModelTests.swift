// IntegratedTerminalModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Integrated Terminal models (Milestone 20)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Integrated Terminal Model Tests")
struct IntegratedTerminalModelTests {

    // MARK: - TerminalColorScheme

    @Test("TerminalColorScheme has exactly 2 cases")
    func test_terminalColorScheme_allCases_has2Cases() {
        #expect(TerminalColorScheme.allCases.count == 2)
    }

    @Test("TerminalColorScheme all cases have non-empty displayNames")
    func test_terminalColorScheme_displayName_nonEmpty() {
        for scheme in TerminalColorScheme.allCases {
            #expect(!scheme.displayName.isEmpty)
        }
    }

    @Test("TerminalColorScheme id equals rawValue")
    func test_terminalColorScheme_id_equalsRawValue() {
        for scheme in TerminalColorScheme.allCases {
            #expect(scheme.id == scheme.rawValue)
        }
    }

    // MARK: - ANSIColor

    @Test("ANSIColor has exactly 16 cases")
    func test_ansiColor_allCases_has16Cases() {
        #expect(ANSIColor.allCases.count == 16)
    }

    @Test("ANSIColor all cases have unique rawValues")
    func test_ansiColor_rawValues_areUnique() {
        let rawValues = ANSIColor.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == ANSIColor.allCases.count)
    }

    // MARK: - TerminalOutputLine

    @Test("TerminalOutputLine initializer sets correct id, content, isStderr, timestamp")
    func test_terminalOutputLine_init_setsFields() {
        let id = UUID()
        let now = Date()
        let line = TerminalOutputLine(id: id, content: "hello stderr", isStderr: true, timestamp: now)
        #expect(line.id == id)
        #expect(line.content == "hello stderr")
        #expect(line.isStderr == true)
        #expect(line.timestamp == now)
    }

    @Test("TerminalOutputLine initializer defaults: isStderr false, ansiColor nil")
    func test_terminalOutputLine_defaults_isStderrFalseAnsiColorNil() {
        let line = TerminalOutputLine(content: "stdout line")
        #expect(line.isStderr == false)
        #expect(line.ansiColor == nil)
    }

    // MARK: - TerminalDisplaySettings

    @Test("TerminalDisplaySettings defaults: fontSize=12.0, colorScheme=.dark, showTimestamps=false, minHeight=120.0")
    func test_terminalDisplaySettings_defaults() {
        let settings = TerminalDisplaySettings()
        #expect(settings.fontSize == 12.0)
        #expect(settings.colorScheme == .dark)
        #expect(settings.showTimestamps == false)
        #expect(settings.minHeight == 120.0)
    }

    // MARK: - TerminalOutputBuffer

    @Test("TerminalOutputBuffer starts with empty lines and lineCount 0")
    func test_terminalOutputBuffer_init_emptyLinesAndZeroCount() {
        let buffer = TerminalOutputBuffer()
        #expect(buffer.lines.isEmpty)
        #expect(buffer.lineCount == 0)
    }

    // MARK: - SyntaxTokenType

    @Test("SyntaxTokenType has exactly 7 cases")
    func test_syntaxTokenType_allCases_has7Cases() {
        #expect(SyntaxTokenType.allCases.count == 7)
    }

    @Test("SyntaxTokenType all cases have non-empty displayNames")
    func test_syntaxTokenType_displayName_nonEmpty() {
        for tokenType in SyntaxTokenType.allCases {
            #expect(!tokenType.displayName.isEmpty)
        }
    }

    // MARK: - SyntaxToken

    @Test("SyntaxToken equality is based on text and type")
    func test_syntaxToken_equality_basedOnTextAndType() {
        let t1 = SyntaxToken(text: "dicom-info", type: .toolName)
        let t2 = SyntaxToken(text: "dicom-info", type: .toolName)
        let t3 = SyntaxToken(text: "dicom-info", type: .flag)
        let t4 = SyntaxToken(text: "--verbose", type: .toolName)
        #expect(t1 == t2)
        #expect(t1 != t3)
        #expect(t1 != t4)
    }

    // MARK: - CommandPreviewState

    @Test("CommandPreviewState defaults to empty rawCommand")
    func test_commandPreviewState_defaults_emptyRawCommand() {
        let state = CommandPreviewState()
        #expect(state.rawCommand.isEmpty)
    }

    // MARK: - ExecutionState

    @Test("ExecutionState isActive: idle=false, running=true, completed=false, cancelled=false, failed=false")
    func test_executionState_isActive_correctForEachCase() {
        #expect(ExecutionState.idle.isActive == false)
        #expect(ExecutionState.running(pid: 42).isActive == true)
        #expect(ExecutionState.completed(exitCode: 0).isActive == false)
        #expect(ExecutionState.cancelled.isActive == false)
        #expect(ExecutionState.failed(error: "oops").isActive == false)
    }

    // MARK: - ExecutionResult

    @Test("ExecutionResult isSuccess: exitCode 0 = true, non-zero = false")
    func test_executionResult_isSuccess_exitCode0TrueOtherwiseFalse() {
        let success = ExecutionResult(exitCode: 0, stdout: "", stderr: "", duration: 1.0, command: "cmd")
        let failure = ExecutionResult(exitCode: 1, stdout: "", stderr: "err", duration: 0.5, command: "cmd")
        #expect(success.isSuccess == true)
        #expect(failure.isSuccess == false)
    }

    @Test("ExecutionResult is Codable: encode then decode roundtrip preserves fields")
    func test_executionResult_codable_roundtrip() throws {
        let original = ExecutionResult(
            exitCode: 0,
            stdout: "output text",
            stderr: "",
            duration: 3.14,
            command: "dicom-info scan.dcm"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExecutionResult.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.exitCode == original.exitCode)
        #expect(decoded.stdout == original.stdout)
        #expect(decoded.stderr == original.stderr)
        #expect(decoded.command == original.command)
    }

    // MARK: - ExecuteButtonDisplayState

    @Test("ExecuteButtonDisplayState isEnabled: ready=true, running=true, completedSuccess=true, disabled=false")
    func test_executeButtonDisplayState_isEnabled_correctForEachCase() {
        #expect(ExecuteButtonDisplayState.ready.isEnabled == true)
        #expect(ExecuteButtonDisplayState.running.isEnabled == true)
        #expect(ExecuteButtonDisplayState.completedSuccess(exitCode: 0).isEnabled == true)
        #expect(ExecuteButtonDisplayState.completedFailure(exitCode: 1).isEnabled == true)
        #expect(ExecuteButtonDisplayState.disabled(reason: "no command").isEnabled == false)
    }

    // MARK: - CommandHistoryEntry

    @Test("CommandHistoryEntry isSuccess: exitCode 0 = true, non-zero = false")
    func test_commandHistoryEntry_isSuccess_exitCode0TrueOtherwiseFalse() {
        let success = CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0)
        let failure = CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 2, duration: 0.5)
        #expect(success.isSuccess == true)
        #expect(failure.isSuccess == false)
    }

    @Test("CommandHistoryEntry is Codable: encode then decode roundtrip preserves fields")
    func test_commandHistoryEntry_codable_roundtrip() throws {
        let original = CommandHistoryEntry(
            toolName: "dicom-query",
            command: "dicom-query --host 10.0.0.1",
            exitCode: 0,
            duration: 2.5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CommandHistoryEntry.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.toolName == original.toolName)
        #expect(decoded.command == original.command)
        #expect(decoded.exitCode == original.exitCode)
        #expect(decoded.duration == original.duration)
    }

    // MARK: - CommandHistoryState

    @Test("CommandHistoryState maxEntries default is 100")
    func test_commandHistoryState_maxEntries_default100() {
        let state = CommandHistoryState()
        #expect(state.maxEntries == 100)
    }

    // MARK: - IntegratedTerminalState

    @Test("IntegratedTerminalState default workingDirectory is ~")
    func test_integratedTerminalState_workingDirectory_defaultIsTilde() {
        let state = IntegratedTerminalState()
        #expect(state.workingDirectory == "~")
    }
}
