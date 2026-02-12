import Foundation

/// Actor that executes CLI commands via `Process` with real-time output streaming,
/// cancellation support, and exit code reporting.
public actor CommandExecutor {
    /// The currently running process, if any
    private var currentProcess: Process?

    /// Whether a command is currently executing
    public var isRunning: Bool {
        currentProcess?.isRunning ?? false
    }

    public init() {}

    /// Executes a CLI command string asynchronously, streaming output line by line.
    ///
    /// - Parameters:
    ///   - command: The full CLI command string to execute
    ///   - outputHandler: Called with each line of output (stdout and stderr combined)
    /// - Returns: The process exit code
    @discardableResult
    public func execute(
        command: String,
        outputHandler: @Sendable @escaping (String) -> Void
    ) async throws -> Int {
        // Cancel any currently running process
        cancelCurrentProcess()

        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        currentProcess = process

        // Set up output reading
        let outputHandle = pipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        // Read stdout asynchronously
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                outputHandler(str)
            }
        }

        // Read stderr asynchronously
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                outputHandler(str)
            }
        }

        try process.run()

        // Wait for process completion in a non-blocking way
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                // Clean up handlers
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil

                // Read any remaining data
                let remainingOut = outputHandle.readDataToEndOfFile()
                if !remainingOut.isEmpty, let str = String(data: remainingOut, encoding: .utf8) {
                    outputHandler(str)
                }
                let remainingErr = errorHandle.readDataToEndOfFile()
                if !remainingErr.isEmpty, let str = String(data: remainingErr, encoding: .utf8) {
                    outputHandler(str)
                }

                continuation.resume(returning: Int(proc.terminationStatus))
            }
        }
    }

    /// Cancels the currently running process
    public func cancel() {
        cancelCurrentProcess()
    }

    private func cancelCurrentProcess() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }
}
