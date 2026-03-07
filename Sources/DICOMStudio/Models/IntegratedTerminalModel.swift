// IntegratedTerminalModel.swift
// DICOMStudio
//
// DICOM Studio — Data models for Integrated Terminal & Command Execution (Milestone 20)

import Foundation

// MARK: - 20.1 Terminal Emulator

/// Point size for terminal output text.
public typealias TerminalFontSize = Double

/// The visual color scheme applied to the terminal display.
public enum TerminalColorScheme: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case dark  = "DARK"
    case light = "LIGHT"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .dark:  return "Dark"
        case .light: return "Light"
        }
    }
}

/// Standard 4-bit ANSI terminal color palette.
public enum ANSIColor: Int, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case black         = 0
    case red           = 1
    case green         = 2
    case yellow        = 3
    case blue          = 4
    case magenta       = 5
    case cyan          = 6
    case white         = 7
    case brightBlack   = 8
    case brightRed     = 9
    case brightGreen   = 10
    case brightYellow  = 11
    case brightBlue    = 12
    case brightMagenta = 13
    case brightCyan    = 14
    case brightWhite   = 15

    public var id: Int { rawValue }
}

/// A single line of text in the terminal output buffer.
public struct TerminalOutputLine: Sendable, Identifiable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// The text content of the line (may include ANSI escape sequences).
    public let content: String

    /// Whether this line was written to stderr.
    public let isStderr: Bool

    /// Timestamp when this line was received.
    public let timestamp: Date

    /// Optional ANSI foreground color for this line.
    public let ansiColor: ANSIColor?

    /// Creates a new terminal output line.
    public init(
        id: UUID = UUID(),
        content: String,
        isStderr: Bool = false,
        timestamp: Date = Date(),
        ansiColor: ANSIColor? = nil
    ) {
        self.id = id
        self.content = content
        self.isStderr = isStderr
        self.timestamp = timestamp
        self.ansiColor = ansiColor
    }
}

/// Visual and layout settings for the embedded terminal panel.
public struct TerminalDisplaySettings: Sendable, Hashable {
    /// Font size in points for terminal output text.
    public var fontSize: Double

    /// Color scheme applied to the terminal.
    public var colorScheme: TerminalColorScheme

    /// Whether per-line timestamps are rendered alongside output.
    public var showTimestamps: Bool

    /// Whether long lines wrap within the panel width.
    public var wordWrap: Bool

    /// Minimum height of the terminal panel in points.
    public var minHeight: Double

    /// Maximum height of the terminal panel as a fraction of the available window height.
    public var maxHeightFraction: Double

    /// Current user-adjusted height of the terminal panel in points.
    public var terminalHeight: Double

    /// Creates terminal display settings with sensible defaults.
    public init(
        fontSize: Double = 12.0,
        colorScheme: TerminalColorScheme = .dark,
        showTimestamps: Bool = false,
        wordWrap: Bool = true,
        minHeight: Double = 120.0,
        maxHeightFraction: Double = 0.6,
        terminalHeight: Double = 200.0
    ) {
        self.fontSize = fontSize
        self.colorScheme = colorScheme
        self.showTimestamps = showTimestamps
        self.wordWrap = wordWrap
        self.minHeight = minHeight
        self.maxHeightFraction = maxHeightFraction
        self.terminalHeight = terminalHeight
    }
}

/// A bounded ring-buffer of terminal output lines.
public struct TerminalOutputBuffer: Sendable, Hashable {
    /// Ordered list of output lines, oldest first.
    public var lines: [TerminalOutputLine]

    /// Maximum number of lines retained before oldest are evicted.
    /// - Note: Memory usage scales with line length and ANSI content.
    ///   At the default of 10 000 lines, typical terminal output occupies
    ///   roughly 1–5 MB. Reduce this value on memory-constrained devices.
    public var maxLines: Int

    /// Cumulative number of raw bytes received from the process.
    public var totalBytesReceived: Int

    /// Whether older lines were dropped due to the line limit being reached.
    public var isTruncated: Bool

    /// Number of lines currently in the buffer.
    public var lineCount: Int { lines.count }

    /// Creates an empty output buffer.
    public init(
        lines: [TerminalOutputLine] = [],
        maxLines: Int = 10_000,
        totalBytesReceived: Int = 0,
        isTruncated: Bool = false
    ) {
        self.lines = lines
        self.maxLines = maxLines
        self.totalBytesReceived = totalBytesReceived
        self.isTruncated = isTruncated
    }
}

// MARK: - 20.2 Command Preview & Building

/// The semantic role of a token within a CLI command string.
public enum SyntaxTokenType: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case toolName       = "TOOL_NAME"
    case flag           = "FLAG"
    case value          = "VALUE"
    case filePath       = "FILE_PATH"
    case pipeOrRedirect = "PIPE_OR_REDIRECT"
    case subcommand     = "SUBCOMMAND"
    case plain          = "PLAIN"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .toolName:       return "Tool Name"
        case .flag:           return "Flag"
        case .value:          return "Value"
        case .filePath:       return "File Path"
        case .pipeOrRedirect: return "Pipe / Redirect"
        case .subcommand:     return "Subcommand"
        case .plain:          return "Plain Text"
        }
    }
}

/// A single syntax-highlighted fragment of a CLI command.
public struct SyntaxToken: Sendable, Equatable, Hashable {
    /// The raw text of this token.
    public let text: String

    /// The semantic type used for syntax highlighting.
    public let type: SyntaxTokenType

    /// Creates a new syntax token.
    public init(text: String, type: SyntaxTokenType) {
        self.text = text
        self.type = type
    }
}

/// The current state of the command preview panel.
public struct CommandPreviewState: Sendable, Hashable {
    /// The complete, unmodified CLI command string.
    public var rawCommand: String

    /// Tokenised, syntax-highlighted representation of the command.
    public var tokens: [SyntaxToken]

    /// Whether syntax highlighting is currently active.
    public var isHighlighted: Bool

    /// Timestamp of the most recent preview update.
    public var lastUpdated: Date

    /// Creates a command preview state with sensible defaults.
    public init(
        rawCommand: String = "",
        tokens: [SyntaxToken] = [],
        isHighlighted: Bool = true,
        lastUpdated: Date = Date()
    ) {
        self.rawCommand = rawCommand
        self.tokens = tokens
        self.isHighlighted = isHighlighted
        self.lastUpdated = lastUpdated
    }
}

// MARK: - 20.3 Command Execution Engine

/// The lifecycle state of a command execution.
public enum ExecutionState: Sendable, Equatable, Hashable {
    /// No command is running.
    case idle
    /// A command is running with the given process identifier.
    case running(pid: Int32)
    /// The command finished with the given exit code.
    case completed(exitCode: Int32)
    /// The command was cancelled by the user.
    case cancelled
    /// The command failed to launch or was terminated abnormally.
    case failed(error: String)

    /// Whether a command is currently in progress.
    public var isActive: Bool {
        if case .running = self { return true }
        return false
    }

    /// Human-readable display name for the current state.
    public var displayName: String {
        switch self {
        case .idle:                    return "Idle"
        case .running(let pid):        return "Running (PID \(pid))"
        case .completed(let code):     return "Completed (exit \(code))"
        case .cancelled:               return "Cancelled"
        case .failed(let error):       return "Failed: \(error)"
        }
    }
}

/// The captured output and metadata from a finished command execution.
public struct ExecutionResult: Sendable, Identifiable, Hashable, Codable {
    /// Unique identifier for this execution result.
    public let id: UUID

    /// Process exit code.
    public let exitCode: Int32

    /// Captured standard output.
    public let stdout: String

    /// Captured standard error.
    public let stderr: String

    /// Elapsed wall-clock time in seconds.
    public let duration: TimeInterval

    /// The verbatim command string that was executed.
    public let command: String

    /// Timestamp when the command was launched.
    public let timestamp: Date

    /// Whether the command exited successfully (exit code 0).
    public var isSuccess: Bool { exitCode == 0 }

    /// Creates a new execution result.
    public init(
        id: UUID = UUID(),
        exitCode: Int32,
        stdout: String,
        stderr: String,
        duration: TimeInterval,
        command: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.command = command
        self.timestamp = timestamp
    }
}

/// Timeout configuration for a specific tool execution.
public struct ExecutionTimeout: Sendable, Hashable {
    /// Maximum number of seconds before the process is forcibly terminated.
    public var seconds: Double

    /// The CLI tool name this timeout applies to.
    public var toolName: String

    /// Creates an execution timeout.
    public init(
        seconds: Double = 60.0,
        toolName: String
    ) {
        self.seconds = seconds
        self.toolName = toolName
    }
}

/// Environment variables and shell settings applied to every executed command.
public struct ExecutorEnvironment: Sendable, Hashable {
    /// Extra directories prepended to the process `PATH`.
    /// - Note: Tilde (`~`) in this string is **not** expanded automatically.
    ///   Callers must resolve it (e.g. via `NSString.expandingTildeInPath`)
    ///   before constructing the actual `PATH` value passed to the subprocess.
    public var additionalPath: String

    /// Value of the `TERM` environment variable.
    public var termType: String

    /// Terminal column width passed to the process.
    public var columns: Int

    /// Creates an executor environment with sensible defaults.
    public init(
        additionalPath: String = "~/.dicomstudio/tools/",
        termType: String = "xterm-256color",
        columns: Int = 80
    ) {
        self.additionalPath = additionalPath
        self.termType = termType
        self.columns = columns
    }
}

// MARK: - 20.4 Execute / Run Button

/// Visual presentation state for the Execute / Run button.
public enum ExecuteButtonDisplayState: Sendable, Equatable, Hashable {
    /// Ready to run; no command is executing.
    case ready
    /// A command is currently executing.
    case running
    /// The last command finished successfully with the given exit code.
    case completedSuccess(exitCode: Int32)
    /// The last command finished with a non-zero exit code.
    case completedFailure(exitCode: Int32)
    /// The button is disabled for the specified reason.
    case disabled(reason: String)

    /// Button label text.
    public var label: String {
        switch self {
        case .ready:                       return "Run"
        case .running:                     return "Running…"
        case .completedSuccess(let code):  return "Done (\(code))"
        case .completedFailure(let code):  return "Failed (\(code))"
        case .disabled:                    return "Run"
        }
    }

    /// SF Symbol name for the button icon.
    public var sfSymbol: String {
        switch self {
        case .ready:                return "play.fill"
        case .running:              return "stop.fill"
        case .completedSuccess:     return "checkmark.circle.fill"
        case .completedFailure:     return "xmark.circle.fill"
        case .disabled:             return "play.fill"
        }
    }

    /// Whether the button should accept user interaction.
    public var isEnabled: Bool {
        switch self {
        case .ready, .running, .completedSuccess, .completedFailure: return true
        case .disabled:                                               return false
        }
    }
}

// MARK: - 20.5 Text Selection & Copy

/// Current text-selection state within the terminal output panel.
public struct TerminalSelectionState: Sendable, Hashable {
    /// Whether any text is currently selected.
    public var hasSelection: Bool

    /// The currently selected text, or an empty string when nothing is selected.
    public var selectedText: String

    /// Start offset of the selection within the full output string, if any.
    public var selectionStart: Int?

    /// End offset (exclusive) of the selection within the full output string, if any.
    public var selectionEnd: Int?

    /// Creates a terminal selection state.
    public init(
        hasSelection: Bool = false,
        selectedText: String = "",
        selectionStart: Int? = nil,
        selectionEnd: Int? = nil
    ) {
        self.hasSelection = hasSelection
        self.selectedText = selectedText
        self.selectionStart = selectionStart
        self.selectionEnd = selectionEnd
    }
}

// MARK: - 20.6 Command History

/// A single entry in the command execution history.
public struct CommandHistoryEntry: Sendable, Identifiable, Hashable, Codable {
    /// Unique identifier.
    public let id: UUID

    /// The CLI tool that was invoked (e.g. "dicom-query").
    public let toolName: String

    /// The verbatim command string that was executed.
    public let command: String

    /// Process exit code of the completed execution.
    public let exitCode: Int32

    /// Timestamp when the command was launched.
    public let timestamp: Date

    /// Elapsed wall-clock time in seconds.
    public let duration: TimeInterval

    /// Whether the command exited successfully (exit code 0).
    public var isSuccess: Bool { exitCode == 0 }

    /// Creates a new command history entry.
    public init(
        id: UUID = UUID(),
        toolName: String,
        command: String,
        exitCode: Int32,
        timestamp: Date = Date(),
        duration: TimeInterval
    ) {
        self.id = id
        self.toolName = toolName
        self.command = command
        self.exitCode = exitCode
        self.timestamp = timestamp
        self.duration = duration
    }
}

/// Filter criteria applied to the command history list.
public struct CommandHistoryFilter: Sendable, Hashable {
    /// Restrict results to entries from this tool name, or `nil` for all tools.
    public var toolName: String?

    /// Free-text search applied to the command string.
    public var searchText: String

    /// When `true`, only successful (exit code 0) entries are shown.
    public var showSuccessOnly: Bool

    /// Creates a command history filter.
    public init(
        toolName: String? = nil,
        searchText: String = "",
        showSuccessOnly: Bool = false
    ) {
        self.toolName = toolName
        self.searchText = searchText
        self.showSuccessOnly = showSuccessOnly
    }
}

/// The overall state of the command history panel.
public struct CommandHistoryState: Sendable, Hashable {
    /// Ordered list of past executions, most recent last.
    public var entries: [CommandHistoryEntry]

    /// Maximum number of entries retained before oldest are evicted.
    public var maxEntries: Int

    /// Index into `entries` pointing at the entry currently browsed via Up/Down, if any.
    public var currentIndex: Int?

    /// Whether the history side-panel is currently visible.
    public var isHistoryPanelVisible: Bool

    /// Active filter applied to the visible history list.
    public var filter: CommandHistoryFilter

    /// Creates a command history state with sensible defaults.
    public init(
        entries: [CommandHistoryEntry] = [],
        maxEntries: Int = 100,
        currentIndex: Int? = nil,
        isHistoryPanelVisible: Bool = false,
        filter: CommandHistoryFilter = CommandHistoryFilter()
    ) {
        self.entries = entries
        self.maxEntries = maxEntries
        self.currentIndex = currentIndex
        self.isHistoryPanelVisible = isHistoryPanelVisible
        self.filter = filter
    }
}

// MARK: - Overall Terminal State

/// Aggregated state for the Integrated Terminal & Command Execution panel (Milestone 20).
public struct IntegratedTerminalState: Sendable, Hashable {
    /// Buffered lines of terminal output.
    public var outputBuffer: TerminalOutputBuffer

    /// Lifecycle state of the currently running (or last-run) command.
    public var executionState: ExecutionState

    /// Current command preview and syntax-highlighting state.
    public var commandPreview: CommandPreviewState

    /// Command history panel state.
    public var historyState: CommandHistoryState

    /// Terminal visual and layout settings.
    public var displaySettings: TerminalDisplaySettings

    /// Presentation state of the Execute / Run button.
    public var buttonState: ExecuteButtonDisplayState

    /// Text-selection state within the terminal output.
    public var selectionState: TerminalSelectionState

    /// Result of the most recently completed execution, if any.
    public var lastResult: ExecutionResult?

    /// The shell working directory for command execution.
    /// - Note: The default value `"~"` is a shell shorthand and is **not**
    ///   expanded automatically.  Callers must resolve it (e.g. via
    ///   `NSString.expandingTildeInPath`) before passing it to a `Process`.
    public var workingDirectory: String

    /// Creates an integrated terminal state with sensible defaults.
    public init(
        outputBuffer: TerminalOutputBuffer = TerminalOutputBuffer(),
        executionState: ExecutionState = .idle,
        commandPreview: CommandPreviewState = CommandPreviewState(),
        historyState: CommandHistoryState = CommandHistoryState(),
        displaySettings: TerminalDisplaySettings = TerminalDisplaySettings(),
        buttonState: ExecuteButtonDisplayState = .ready,
        selectionState: TerminalSelectionState = TerminalSelectionState(),
        lastResult: ExecutionResult? = nil,
        workingDirectory: String = "~"
    ) {
        self.outputBuffer = outputBuffer
        self.executionState = executionState
        self.commandPreview = commandPreview
        self.historyState = historyState
        self.displaySettings = displaySettings
        self.buttonState = buttonState
        self.selectionState = selectionState
        self.lastResult = lastResult
        self.workingDirectory = workingDirectory
    }
}
