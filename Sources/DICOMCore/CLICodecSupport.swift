// CLICodecSupport.swift
// DICOMCore
//
// Shared helpers for codec adapters that shell out to locally-installed
// CLI binaries (Kakadu, Grok). macOS-only.

#if os(macOS)
import Foundation

enum CLICodecError: Error, LocalizedError {
    case binaryNotFound(String)
    case launchFailed(String)
    case nonZeroExit(Int32, String)
    case outputSizeMismatch(expected: Int, got: Int)
    case unsupportedConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "\(name): binary not found on PATH or standard install locations"
        case .launchFailed(let msg):
            return "Failed to launch codec binary: \(msg)"
        case .nonZeroExit(let code, let stderr):
            return "Codec exited with status \(code)\(stderr.isEmpty ? "" : ": \(stderr.prefix(200))")"
        case .outputSizeMismatch(let expected, let got):
            return "Codec output size mismatch: expected \(expected) bytes, got \(got)"
        case .unsupportedConfiguration(let reason):
            return "Codec configuration not supported: \(reason)"
        }
    }
}

/// Searches a name on $PATH and a small list of common install locations.
func locateBinary(name: String) -> String? {
    let candidates: [String] = [
        "/usr/local/bin/\(name)",
        "/opt/homebrew/bin/\(name)",
        "/usr/bin/\(name)"
    ]
    for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
        return c
    }
    // PATH fallback.
    if let path = ProcessInfo.processInfo.environment["PATH"] {
        for dir in path.split(separator: ":") {
            let full = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
    }
    return nil
}

/// Launches `executable` with the given arguments and waits for exit.
/// Throws on launch failure or non-zero exit; stdout/stderr are captured and surfaced on failure.
func runProcess(executable: String, arguments: [String]) throws {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = arguments
    let stderrPipe = Pipe()
    let stdoutPipe = Pipe()
    proc.standardError = stderrPipe
    proc.standardOutput = stdoutPipe
    do {
        try proc.run()
    } catch {
        throw CLICodecError.launchFailed(error.localizedDescription)
    }
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let msg = String(data: err.isEmpty ? out : err, encoding: .utf8) ?? "<no output>"
        throw CLICodecError.nonZeroExit(proc.terminationStatus, msg)
    }
}

/// A throwaway temp directory under NSTemporaryDirectory().
final class TempWorkDir {
    let url: URL

    init(prefix: String) throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
