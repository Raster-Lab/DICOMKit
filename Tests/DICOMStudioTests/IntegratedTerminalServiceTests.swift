// IntegratedTerminalServiceTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Integrated Terminal service (Milestone 20)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Integrated Terminal Service Tests")
struct IntegratedTerminalServiceTests {

    // MARK: - Initialization

    @Test("Service initializes with idle executionState")
    func test_init_executionState_isIdle() {
        let service = IntegratedTerminalService()
        #expect(service.getExecutionState() == .idle)
    }

    @Test("Service initializes with empty output buffer")
    func test_init_outputBuffer_isEmpty() {
        let service = IntegratedTerminalService()
        #expect(service.getOutputBuffer().lineCount == 0)
        #expect(service.getOutputBuffer().lines.isEmpty)
    }

    // MARK: - Execution State

    @Test("setExecutionState(.running(pid:)) sets state correctly")
    func test_setExecutionState_running_setsCorrectly() {
        let service = IntegratedTerminalService()
        service.setExecutionState(.running(pid: 1234))
        #expect(service.getExecutionState() == .running(pid: 1234))
    }

    @Test("setExecutionState(.completed(exitCode:)) sets state correctly")
    func test_setExecutionState_completed_setsCorrectly() {
        let service = IntegratedTerminalService()
        service.setExecutionState(.completed(exitCode: 0))
        #expect(service.getExecutionState() == .completed(exitCode: 0))
    }

    // MARK: - Output Buffer

    @Test("appendOutputLine increases lineCount by 1")
    func test_appendOutputLine_increasesLineCount() {
        let service = IntegratedTerminalService()
        let line = TerminalOutputLine(content: "test output")
        service.appendOutputLine(line)
        #expect(service.getOutputBuffer().lineCount == 1)
    }

    @Test("appendOutputLine beyond maxLines does not exceed maxLines (ring buffer)")
    func test_appendOutputLine_beyondMaxLines_doesNotExceedMaxLines() {
        let service = IntegratedTerminalService()
        var buffer = TerminalOutputBuffer(maxLines: 3)
        service.setOutputBuffer(buffer)
        _ = buffer  // suppress unused warning

        for i in 0..<5 {
            service.appendOutputLine(TerminalOutputLine(content: "line \(i)"))
        }
        let finalBuffer = service.getOutputBuffer()
        #expect(finalBuffer.lineCount <= 3)
        #expect(finalBuffer.isTruncated == true)
    }

    @Test("clearOutput resets buffer to 0 lines")
    func test_clearOutput_resetsLineCountToZero() {
        let service = IntegratedTerminalService()
        service.appendOutputLine(TerminalOutputLine(content: "line 1"))
        service.appendOutputLine(TerminalOutputLine(content: "line 2"))
        service.clearOutput()
        #expect(service.getOutputBuffer().lineCount == 0)
    }

    @Test("clearOutput preserves maxLines setting")
    func test_clearOutput_preservesMaxLines() {
        let service = IntegratedTerminalService()
        var buffer = TerminalOutputBuffer(maxLines: 500)
        service.setOutputBuffer(buffer)
        _ = buffer
        service.appendOutputLine(TerminalOutputLine(content: "line"))
        service.clearOutput()
        #expect(service.getOutputBuffer().maxLines == 500)
    }

    // MARK: - Command History

    @Test("addHistoryEntry increases history count by 1")
    func test_addHistoryEntry_increasesCount() {
        let service = IntegratedTerminalService()
        let entry = CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0)
        service.addHistoryEntry(entry)
        #expect(service.getHistoryState().entries.count == 1)
    }

    @Test("clearHistory resets history to 0 entries")
    func test_clearHistory_resetsToZero() {
        let service = IntegratedTerminalService()
        service.addHistoryEntry(CommandHistoryEntry(toolName: "dicom-echo", command: "cmd", exitCode: 0, duration: 0.1))
        service.addHistoryEntry(CommandHistoryEntry(toolName: "dicom-query", command: "cmd2", exitCode: 0, duration: 0.2))
        service.clearHistory()
        #expect(service.getHistoryState().entries.count == 0)
    }

    @Test("clearHistory preserves maxEntries setting")
    func test_clearHistory_preservesMaxEntries() {
        let service = IntegratedTerminalService()
        var state = CommandHistoryState(maxEntries: 50)
        service.setHistoryState(state)
        _ = state
        service.addHistoryEntry(CommandHistoryEntry(toolName: "t", command: "c", exitCode: 0, duration: 0.1))
        service.clearHistory()
        #expect(service.getHistoryState().maxEntries == 50)
    }

    // MARK: - Command Preview

    @Test("updateCommandPreview(command:) sets rawCommand correctly")
    func test_updateCommandPreview_setsRawCommand() {
        let service = IntegratedTerminalService()
        service.updateCommandPreview(command: "dicom-echo --host 10.0.0.1")
        #expect(service.getCommandPreview().rawCommand == "dicom-echo --host 10.0.0.1")
    }

    @Test("updateCommandPreview tokenizes: tokens not empty for non-empty command")
    func test_updateCommandPreview_nonEmptyCommand_producesTokens() {
        let service = IntegratedTerminalService()
        service.updateCommandPreview(command: "dicom-echo --host 10.0.0.1")
        #expect(!service.getCommandPreview().tokens.isEmpty)
    }

    // MARK: - Thread Safety (basic same-thread test)

    @Test("Service is thread-safe: set and get on same thread returns consistent state")
    func test_service_threadSafe_setAndGetConsistent() {
        let service = IntegratedTerminalService()
        service.setExecutionState(.running(pid: 99))
        let retrieved = service.getExecutionState()
        #expect(retrieved == .running(pid: 99))
    }
}
