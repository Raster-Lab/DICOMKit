// IntegratedTerminalService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Integrated Terminal state (Milestone 20)

import Foundation

/// Thread-safe service that manages state for the Integrated Terminal & Command Execution feature.
public final class IntegratedTerminalService: @unchecked Sendable {
    private let lock = NSLock()

    // 20.1 Terminal Emulator
    private var _outputBuffer: TerminalOutputBuffer = TerminalOutputBuffer()

    // 20.3 Command Execution Engine
    private var _executionState: ExecutionState = .idle

    // 20.2 Command Preview & Building
    private var _commandPreview: CommandPreviewState = CommandPreviewState()

    // 20.6 Command History
    private var _historyState: CommandHistoryState = CommandHistoryState()

    // 20.1 Display Settings
    private var _displaySettings: TerminalDisplaySettings = TerminalDisplaySettings()

    // 20.4 Execute / Run Button
    private var _buttonState: ExecuteButtonDisplayState = .ready

    // 20.5 Text Selection & Copy
    private var _selectionState: TerminalSelectionState = TerminalSelectionState(hasSelection: false)

    // 20.3 Last Execution Result
    private var _lastResult: ExecutionResult? = nil

    // Working Directory
    private var _workingDirectory: String = "~"

    public init() {}

    // MARK: - 20.1 Output Buffer

    /// Returns the current terminal output buffer.
    public func getOutputBuffer() -> TerminalOutputBuffer { lock.withLock { _outputBuffer } }

    /// Replaces the terminal output buffer.
    public func setOutputBuffer(_ v: TerminalOutputBuffer) { lock.withLock { _outputBuffer = v } }

    /// Appends a single output line to the buffer.
    ///
    /// When the buffer has reached `maxLines`, the oldest line is evicted and
    /// `isTruncated` is set to `true`. `totalBytesReceived` is incremented by
    /// the UTF-8 byte length of the new line's content.
    public func appendOutputLine(_ line: TerminalOutputLine) {
        lock.withLock {
            if _outputBuffer.lines.count >= _outputBuffer.maxLines {
                _outputBuffer.lines.removeFirst()
                _outputBuffer.isTruncated = true
            }
            _outputBuffer.lines.append(line)
            _outputBuffer.totalBytesReceived += line.content.utf8.count
        }
    }

    /// Resets the output buffer to an empty state, preserving `maxLines`.
    public func clearOutput() {
        lock.withLock {
            let maxLines = _outputBuffer.maxLines
            _outputBuffer = TerminalOutputBuffer(maxLines: maxLines)
        }
    }

    // MARK: - 20.3 Execution State

    /// Returns the current command execution lifecycle state.
    public func getExecutionState() -> ExecutionState { lock.withLock { _executionState } }

    /// Sets the command execution lifecycle state.
    public func setExecutionState(_ v: ExecutionState) { lock.withLock { _executionState = v } }

    /// Returns the result of the most recently completed execution, if any.
    public func getLastResult() -> ExecutionResult? { lock.withLock { _lastResult } }

    /// Sets the result of the most recently completed execution.
    public func setLastResult(_ v: ExecutionResult?) { lock.withLock { _lastResult = v } }

    // MARK: - 20.2 Command Preview

    /// Returns the current command preview state.
    public func getCommandPreview() -> CommandPreviewState { lock.withLock { _commandPreview } }

    /// Replaces the command preview state.
    public func setCommandPreview(_ v: CommandPreviewState) { lock.withLock { _commandPreview = v } }

    /// Updates the command preview with a new raw command string.
    ///
    /// The command is tokenised via `SyntaxHighlightingHelpers.tokenize(command:)` and
    /// `lastUpdated` is refreshed to the current time.
    public func updateCommandPreview(command: String) {
        lock.withLock {
            _commandPreview.rawCommand = command
            _commandPreview.tokens = SyntaxHighlightingHelpers.tokenize(command: command)
            _commandPreview.lastUpdated = Date()
        }
    }

    // MARK: - 20.6 Command History

    /// Returns the current command history state.
    public func getHistoryState() -> CommandHistoryState { lock.withLock { _historyState } }

    /// Replaces the command history state.
    public func setHistoryState(_ v: CommandHistoryState) { lock.withLock { _historyState = v } }

    /// Adds a history entry to the ring buffer.
    ///
    /// When the buffer has reached `maxEntries`, the oldest entry is evicted before
    /// the new one is appended (FIFO ring-buffer semantics).
    public func addHistoryEntry(_ entry: CommandHistoryEntry) {
        lock.withLock {
            if _historyState.entries.count >= _historyState.maxEntries {
                _historyState.entries.removeFirst()
            }
            _historyState.entries.append(entry)
        }
    }

    /// Resets the history state to an empty state, preserving `maxEntries`.
    public func clearHistory() {
        lock.withLock {
            let maxEntries = _historyState.maxEntries
            _historyState = CommandHistoryState(maxEntries: maxEntries)
        }
    }

    // MARK: - 20.1 Display Settings

    /// Returns the current terminal display settings.
    public func getDisplaySettings() -> TerminalDisplaySettings { lock.withLock { _displaySettings } }

    /// Replaces the terminal display settings.
    public func setDisplaySettings(_ v: TerminalDisplaySettings) { lock.withLock { _displaySettings = v } }

    // MARK: - 20.4 Execute Button State

    /// Returns the current Execute button display state.
    public func getButtonState() -> ExecuteButtonDisplayState { lock.withLock { _buttonState } }

    /// Sets the Execute button display state.
    public func setButtonState(_ v: ExecuteButtonDisplayState) { lock.withLock { _buttonState = v } }

    // MARK: - 20.5 Selection State

    /// Returns the current terminal text-selection state.
    public func getSelectionState() -> TerminalSelectionState { lock.withLock { _selectionState } }

    /// Sets the terminal text-selection state.
    public func setSelectionState(_ v: TerminalSelectionState) { lock.withLock { _selectionState = v } }

    // MARK: - Working Directory

    /// Returns the current shell working directory.
    public func getWorkingDirectory() -> String { lock.withLock { _workingDirectory } }

    /// Sets the shell working directory.
    public func setWorkingDirectory(_ v: String) { lock.withLock { _workingDirectory = v } }
}
