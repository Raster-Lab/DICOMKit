// IntegratedTerminalViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Integrated Terminal & Command Execution (Milestone 20)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class IntegratedTerminalViewModel {
    private let service: IntegratedTerminalService

    // 20.1 Terminal Emulator
    public var outputBuffer: TerminalOutputBuffer = TerminalOutputBuffer()
    public var displaySettings: TerminalDisplaySettings = TerminalDisplaySettings()

    // 20.2 Command Preview & Building
    public var commandPreview: CommandPreviewState = CommandPreviewState()

    // 20.3 Command Execution Engine
    public var executionState: ExecutionState = .idle
    public var lastResult: ExecutionResult?

    // 20.4 Execute / Run Button
    public var buttonState: ExecuteButtonDisplayState = .ready

    // 20.5 Text Selection & Copy
    public var selectionState: TerminalSelectionState = TerminalSelectionState(hasSelection: false)

    // 20.6 Command History
    public var historyState: CommandHistoryState = CommandHistoryState()

    // Working Directory
    public var workingDirectory: String = "~"

    public init(service: IntegratedTerminalService = IntegratedTerminalService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        outputBuffer    = service.getOutputBuffer()
        executionState  = service.getExecutionState()
        commandPreview  = service.getCommandPreview()
        historyState    = service.getHistoryState()
        displaySettings = service.getDisplaySettings()
        buttonState     = service.getButtonState()
        selectionState  = service.getSelectionState()
        lastResult      = service.getLastResult()
        workingDirectory = service.getWorkingDirectory()
    }

    // MARK: - 20.3 Execution State

    /// Sets the execution lifecycle state and derives the corresponding button display state.
    ///
    /// - `.idle` maps the button to `.ready`.
    /// - `.running(pid:)` maps the button to `.running`.
    /// - `.completed(exitCode:)` maps the button to `.completedSuccess` or `.completedFailure`
    ///   based on whether the exit code is zero.
    public func setExecutionState(_ state: ExecutionState) {
        executionState = state
        service.setExecutionState(state)

        switch state {
        case .idle, .cancelled:
            buttonState = .ready
            service.setButtonState(.ready)
        case .running:
            buttonState = .running
            service.setButtonState(.running)
        case .completed(let exitCode):
            let newButtonState: ExecuteButtonDisplayState = exitCode == 0
                ? .completedSuccess(exitCode: exitCode)
                : .completedFailure(exitCode: exitCode)
            buttonState = newButtonState
            service.setButtonState(newButtonState)
        case .failed:
            buttonState = .ready
            service.setButtonState(.ready)
        }
    }

    // MARK: - 20.2 Command Preview

    /// Replaces the command preview state entirely.
    public func setCommandPreview(_ preview: CommandPreviewState) {
        commandPreview = preview
        service.setCommandPreview(preview)
    }

    /// Updates the command preview from a raw command string, re-tokenising for syntax highlighting.
    public func updateCommandPreview(command: String) {
        service.updateCommandPreview(command: command)
        commandPreview = service.getCommandPreview()
    }

    // MARK: - 20.1 Display Settings

    /// Replaces the terminal display settings.
    public func setDisplaySettings(_ settings: TerminalDisplaySettings) {
        displaySettings = settings
        service.setDisplaySettings(settings)
    }

    // MARK: - Working Directory

    /// Sets the shell working directory used for command execution.
    public func setWorkingDirectory(_ dir: String) {
        workingDirectory = dir
        service.setWorkingDirectory(dir)
    }

    // MARK: - 20.1 Output Buffer

    /// Appends a single line to the terminal output buffer.
    ///
    /// Delegates eviction and byte-count tracking to the service, then reloads
    /// the observable `outputBuffer`.
    public func appendOutputLine(_ line: TerminalOutputLine) {
        service.appendOutputLine(line)
        outputBuffer = service.getOutputBuffer()
    }

    /// Clears all lines from the terminal output buffer.
    public func clearOutput() {
        service.clearOutput()
        outputBuffer = service.getOutputBuffer()
    }

    // MARK: - 20.6 Command History

    /// Adds an entry to the command history ring buffer.
    ///
    /// Delegates eviction to the service, then reloads the observable `historyState`.
    public func addHistoryEntry(_ entry: CommandHistoryEntry) {
        service.addHistoryEntry(entry)
        historyState = service.getHistoryState()
    }

    /// Clears all entries from the command history, preserving `maxEntries`.
    public func clearHistory() {
        service.clearHistory()
        historyState = service.getHistoryState()
    }

    /// Navigates the command history cursor one step in the given direction.
    ///
    /// Uses ``CommandHistoryHelpers/navigate(history:direction:)`` to compute the
    /// new cursor position, updates `historyState`, and returns the command string
    /// at the new position, or `nil` when the cursor is reset past the newest entry.
    @discardableResult
    public func navigateHistory(direction: NavigationDirection) -> String? {
        let newState = CommandHistoryHelpers.navigate(history: historyState, direction: direction)
        historyState = newState
        service.setHistoryState(newState)

        guard let index = newState.currentIndex,
              newState.entries.indices.contains(index) else { return nil }
        return newState.entries[index].command
    }

    /// Shows or hides the command history side panel.
    public func setHistoryPanelVisible(_ visible: Bool) {
        historyState.isHistoryPanelVisible = visible
        service.setHistoryState(historyState)
    }

    // MARK: - 20.5 Text Selection

    /// Replaces the terminal text-selection state.
    public func setSelectionState(_ state: TerminalSelectionState) {
        selectionState = state
        service.setSelectionState(state)
    }

    // MARK: - Execution Lifecycle Convenience

    /// Transitions the terminal to the running state for the given process identifier.
    public func startExecution(pid: Int32) {
        setExecutionState(.running(pid: pid))
    }

    /// Records a completed execution: persists the result, adds a PHI-redacted history
    /// entry, and transitions the button and execution state to reflect the exit code.
    ///
    /// - Parameters:
    ///   - exitCode: The process exit code.
    ///   - stdout:   Captured standard output.
    ///   - stderr:   Captured standard error.
    ///   - duration: Elapsed wall-clock time in seconds.
    ///   - command:  The verbatim command string that was executed.
    public func completeExecution(
        exitCode: Int32,
        stdout: String,
        stderr: String,
        duration: TimeInterval,
        command: String
    ) {
        let result = ExecutionResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            duration: duration,
            command: command
        )
        service.setLastResult(result)
        lastResult = result

        let toolName = command.components(separatedBy: .whitespaces).first ?? command
        let redactedCommand = CommandHistoryHelpers.redactPHI(from: command)
        let entry = CommandHistoryEntry(
            toolName: toolName,
            command: redactedCommand,
            exitCode: exitCode,
            duration: duration
        )
        addHistoryEntry(entry)

        setExecutionState(.completed(exitCode: exitCode))
    }

    /// Cancels the currently running command and immediately resets the terminal to idle.
    public func cancelExecution() {
        setExecutionState(.cancelled)
        setExecutionState(.idle)
    }

    /// Resets the execution state to idle and the button to ready.
    public func resetToIdle() {
        setExecutionState(.idle)
    }
}
