import Foundation

/// Executes CLI commands and captures their output
@MainActor
@Observable
final class CommandExecutor {

    enum ExecutionState: Sendable {
        case idle
        case running
        case completed(exitCode: Int32)
        case failed(error: String)
    }

    var state: ExecutionState = .idle
    var output: String = ""
    private var runningProcess: Process?

    /// Whether a command is currently running
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Execute the given command string
    /// - Parameter command: The full command line string to execute
    func execute(command: String) async {
        state = .running
        output = "$ \(command)\n\n"

        // Find the executable
        let parts = command.components(separatedBy: " ")
        guard let toolName = parts.first else {
            state = .failed(error: "Empty command")
            return
        }

        // Try to find the tool in the Swift build directory or PATH
        let executablePath = await findExecutable(named: toolName)

        guard let path = executablePath else {
            output += "Error: Could not find executable '\(toolName)'\n"
            output += "\nHint: Build the tools first with:\n"
            output += "  swift build\n"
            state = .failed(error: "Executable not found: \(toolName)")
            return
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = Array(parseArguments(from: command).dropFirst())
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        runningProcess = process

        do {
            try process.run()

            // Read output asynchronously
            let outputData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }

            let errorData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }

            process.waitUntilExit()

            let stdout = String(data: outputData, encoding: .utf8) ?? ""
            let stderr = String(data: errorData, encoding: .utf8) ?? ""

            if !stdout.isEmpty {
                output += stdout
            }
            if !stderr.isEmpty {
                if !stdout.isEmpty { output += "\n" }
                output += stderr
            }

            let exitCode = process.terminationStatus
            if exitCode == 0 {
                output += "\n\n✓ Command completed successfully"
            } else {
                output += "\n\n✗ Command exited with code \(exitCode)"
            }

            state = .completed(exitCode: exitCode)

        } catch {
            output += "\nError: \(error.localizedDescription)"
            state = .failed(error: error.localizedDescription)
        }

        runningProcess = nil
    }

    /// Cancel a running command
    func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
        output += "\n\n⚠ Command cancelled by user"
        state = .idle
    }

    // MARK: - Private

    private func findExecutable(named name: String) async -> String? {
        // Check Swift build directory first (.build/debug/)
        let buildPaths = [
            ".build/debug/\(name)",
            ".build/release/\(name)",
        ]

        let fm = FileManager.default
        for path in buildPaths {
            let fullPath = fm.currentDirectoryPath + "/" + path
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        // Check if it's in PATH
        let whichProcess = Process()
        let pipe = Pipe()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [name]
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let result = result, !result.isEmpty, fm.isExecutableFile(atPath: result) {
                return result
            }
        } catch {
            // Ignore
        }

        return nil
    }

    private func parseArguments(from command: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for char in command {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                escaped = true
                continue
            }

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if char == " " && !inSingleQuote && !inDoubleQuote {
                if !current.isEmpty {
                    args.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            args.append(current)
        }

        return args
    }
}
