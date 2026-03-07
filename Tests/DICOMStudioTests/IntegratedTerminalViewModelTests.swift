// IntegratedTerminalViewModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Integrated Terminal ViewModel (Milestone 20)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Integrated Terminal ViewModel Tests")
struct IntegratedTerminalViewModelTests {

    // MARK: - Initialization

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("ViewModel initializes with idle executionState")
    func test_init_executionState_isIdle() {
        let vm = IntegratedTerminalViewModel()
        #expect(vm.executionState == .idle)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("ViewModel initializes with ready buttonState")
    func test_init_buttonState_isReady() {
        let vm = IntegratedTerminalViewModel()
        #expect(vm.buttonState == .ready)
    }

    // MARK: - startExecution

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("startExecution(pid:) sets executionState to .running")
    func test_startExecution_setsExecutionStateToRunning() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 42)
        #expect(vm.executionState == .running(pid: 42))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("startExecution(pid:) sets buttonState to .running")
    func test_startExecution_setsButtonStateToRunning() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 42)
        #expect(vm.buttonState == .running)
    }

    // MARK: - completeExecution

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution(exitCode: 0) sets executionState to .completed(0)")
    func test_completeExecution_exitCode0_setsCompletedState() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 1)
        vm.completeExecution(exitCode: 0, stdout: "ok", stderr: "", duration: 1.0, command: "dicom-echo")
        #expect(vm.executionState == .completed(exitCode: 0))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution(exitCode: 0) sets buttonState to .completedSuccess")
    func test_completeExecution_exitCode0_setsCompletedSuccessButtonState() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 1)
        vm.completeExecution(exitCode: 0, stdout: "ok", stderr: "", duration: 1.0, command: "dicom-echo")
        #expect(vm.buttonState == .completedSuccess(exitCode: 0))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution(exitCode: 1) sets executionState to .completed(1)")
    func test_completeExecution_exitCode1_setsCompletedState() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 1)
        vm.completeExecution(exitCode: 1, stdout: "", stderr: "err", duration: 0.5, command: "dicom-echo")
        #expect(vm.executionState == .completed(exitCode: 1))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution(exitCode: 1) sets buttonState to .completedFailure")
    func test_completeExecution_exitCode1_setsCompletedFailureButtonState() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 1)
        vm.completeExecution(exitCode: 1, stdout: "", stderr: "err", duration: 0.5, command: "dicom-echo")
        #expect(vm.buttonState == .completedFailure(exitCode: 1))
    }

    // MARK: - cancelExecution

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("cancelExecution() sets executionState back to .idle")
    func test_cancelExecution_setsExecutionStateToIdle() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 5)
        vm.cancelExecution()
        #expect(vm.executionState == .idle)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("cancelExecution() sets buttonState back to .ready")
    func test_cancelExecution_setsButtonStateToReady() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 5)
        vm.cancelExecution()
        #expect(vm.buttonState == .ready)
    }

    // MARK: - appendOutputLine

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("appendOutputLine increases outputBuffer.lineCount by 1")
    func test_appendOutputLine_increasesLineCount() {
        let vm = IntegratedTerminalViewModel()
        let line = TerminalOutputLine(content: "hello")
        vm.appendOutputLine(line)
        #expect(vm.outputBuffer.lineCount == 1)
    }

    // MARK: - clearOutput

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("clearOutput() resets outputBuffer.lineCount to 0")
    func test_clearOutput_resetsLineCountToZero() {
        let vm = IntegratedTerminalViewModel()
        vm.appendOutputLine(TerminalOutputLine(content: "a"))
        vm.appendOutputLine(TerminalOutputLine(content: "b"))
        vm.clearOutput()
        #expect(vm.outputBuffer.lineCount == 0)
    }

    // MARK: - addHistoryEntry

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addHistoryEntry increases historyState.entries.count by 1")
    func test_addHistoryEntry_increasesCount() {
        let vm = IntegratedTerminalViewModel()
        let entry = CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0)
        vm.addHistoryEntry(entry)
        #expect(vm.historyState.entries.count == 1)
    }

    // MARK: - clearHistory

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("clearHistory() resets historyState.entries.count to 0")
    func test_clearHistory_resetsToZero() {
        let vm = IntegratedTerminalViewModel()
        vm.addHistoryEntry(CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0))
        vm.addHistoryEntry(CommandHistoryEntry(toolName: "dicom-query", command: "dicom-query", exitCode: 0, duration: 2.0))
        vm.clearHistory()
        #expect(vm.historyState.entries.count == 0)
    }

    // MARK: - updateCommandPreview

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateCommandPreview sets commandPreview.rawCommand correctly")
    func test_updateCommandPreview_setsRawCommand() {
        let vm = IntegratedTerminalViewModel()
        vm.updateCommandPreview(command: "dicom-echo --host 10.0.0.1")
        #expect(vm.commandPreview.rawCommand == "dicom-echo --host 10.0.0.1")
    }

    // MARK: - setDisplaySettings

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("setDisplaySettings changes fontSize")
    func test_setDisplaySettings_changesFontSize() {
        let vm = IntegratedTerminalViewModel()
        var settings = TerminalDisplaySettings()
        settings.fontSize = 16.0
        vm.setDisplaySettings(settings)
        #expect(vm.displaySettings.fontSize == 16.0)
    }

    // MARK: - setWorkingDirectory

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("setWorkingDirectory changes workingDirectory")
    func test_setWorkingDirectory_changesWorkingDirectory() {
        let vm = IntegratedTerminalViewModel()
        vm.setWorkingDirectory("~/Desktop")
        #expect(vm.workingDirectory == "~/Desktop")
    }

    // MARK: - navigateHistory

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("navigateHistory(.up) on empty history returns nil")
    func test_navigateHistory_upOnEmptyHistory_returnsNil() {
        let vm = IntegratedTerminalViewModel()
        let result = vm.navigateHistory(direction: .up)
        #expect(result == nil)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("navigateHistory(.up) with one entry returns that entry's command")
    func test_navigateHistory_upWithOneEntry_returnsCommand() {
        let vm = IntegratedTerminalViewModel()
        vm.addHistoryEntry(CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo --host x", exitCode: 0, duration: 0.1))
        let result = vm.navigateHistory(direction: .up)
        #expect(result == "dicom-echo --host x")
    }

    // MARK: - completeExecution creates lastResult

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution creates lastResult with correct exitCode")
    func test_completeExecution_createsLastResult_withCorrectExitCode() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 10)
        vm.completeExecution(exitCode: 42, stdout: "out", stderr: "err", duration: 3.0, command: "dicom-info scan.dcm")
        #expect(vm.lastResult != nil)
        #expect(vm.lastResult?.exitCode == 42)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("completeExecution stores correct command in lastResult")
    func test_completeExecution_storesCorrectCommandInLastResult() {
        let vm = IntegratedTerminalViewModel()
        vm.startExecution(pid: 10)
        vm.completeExecution(exitCode: 0, stdout: "ok", stderr: "", duration: 1.5, command: "dicom-info scan.dcm")
        #expect(vm.lastResult?.command == "dicom-info scan.dcm")
    }
}
