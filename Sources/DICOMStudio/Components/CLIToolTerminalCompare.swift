// CLIToolTerminalCompare.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Spawns the REAL `dicom-*` CLI binary for the currently-selected tool as a
// subprocess, so the CLI Workshop can show the terminal output side-by-side with
// the app's in-process output (a parity sanity check while developing).
//
// It only works when the App Sandbox is DISABLED — a sandboxed app cannot launch
// external executables. DICOMStudio.entitlements has therefore been temporarily
// switched to `com.apple.security.app-sandbox = false` for this feature.
//
// TO REMOVE FOR PRODUCTION (see project memory `dicom-info-terminal-compare-testonly`):
//   1. Delete this file.
//   2. Re-enable the sandbox in DICOMStudio.entitlements (app-sandbox = true).
//   3. Remove `runTerminalCompare()` / `clearTerminalCompare()` and the
//      `isRunningTerminalCompare` / `terminalCompareResult` properties from
//      CLIWorkshopViewModel.swift.
//   4. Remove the "Compare CLI (TEST)" button (actionFooter) and `terminalCompareView`
//      from CLIWorkshopView.swift.

import Foundation

/// Result of a TESTING-ONLY terminal-vs-app output comparison for one tool.
/// Plain data (no platform APIs) so it is available on every platform.
struct CLIToolCompareResult: Sendable, Equatable {
    var toolName: String           // e.g. "dicom-info"
    var appOutput: String          // app's in-process render
    var terminalOutput: String     // real CLI binary stdout (or error text)
    var binaryPath: String?        // which binary was executed
    var commandLine: String        // the command that was run (for display)
    var matched: Bool              // normalized outputs are identical
    var differingLineCount: Int    // # of non-matching lines (normalized)
    var note: String               // human-readable status
}

#if os(macOS)

/// TESTING-ONLY helper that locates and runs a `dicom-*` CLI binary.
enum CLIToolTerminalCompare {

    struct Outcome: Sendable {
        var binaryPath: String?
        var stdout: String
        var stderr: String
        var exitCode: Int32
        var launchError: String?
    }

    /// Splits a command string (as produced by `CommandBuilderHelpers.buildCommand`,
    /// which single-quote-escapes values) into argv tokens — WITHOUT a shell.
    /// Handles `'…'` quoting and the `'\''` escaped-quote idiom, so a previewed
    /// command is the single source of truth for what gets executed.
    static func shellSplit(_ command: String) -> [String] {
        var args: [String] = []
        var cur = ""
        var hasToken = false
        var inSingle = false
        var idx = command.startIndex
        while idx < command.endIndex {
            let c = command[idx]
            if inSingle {
                if c == "'" { inSingle = false } else { cur.append(c) }
                hasToken = true
            } else {
                switch c {
                case "'":
                    inSingle = true; hasToken = true
                case "\\":
                    let n = command.index(after: idx)
                    if n < command.endIndex { cur.append(command[n]); idx = n; hasToken = true }
                case " ", "\t", "\n":
                    if hasToken { args.append(cur); cur = ""; hasToken = false }
                default:
                    cur.append(c); hasToken = true
                }
            }
            idx = command.index(after: idx)
        }
        if hasToken { args.append(cur) }
        return args
    }

    /// Locates a `dicom-*` executable. Resolution order:
    ///   0. `preferredDir` (e.g. a freshly-built bin dir) — wins so a stale binary
    ///      elsewhere on disk can never shadow it
    ///   1. `DICOM_CLI_BIN_DIR` env var (directory holding the binaries)
    ///   2. SwiftPM build products under the repo (`.build/release|debug/<tool>`)
    ///   3. `$PATH` and common install locations
    static func locateBinary(tool: String, preferredDir: String? = nil) -> String? {
        let fm = FileManager.default

        if let dir = preferredDir {
            let p = "\(dir)/\(tool)"
            if fm.isExecutableFile(atPath: p) { return p }
        }

        if let dir = ProcessInfo.processInfo.environment["DICOM_CLI_BIN_DIR"] {
            let p = "\(dir)/\(tool)"
            if fm.isExecutableFile(atPath: p) { return p }
        }

        var candidates: [String] = []
        let repoRoots = [
            fm.currentDirectoryPath,
            "/Users/raster/Documents/GitHub_Workspace/DICOMKit"
        ]
        for root in repoRoots {
            candidates.append("\(root)/.build/release/\(tool)")
            candidates.append("\(root)/.build/debug/\(tool)")
        }
        candidates += ["/usr/local/bin/\(tool)", "/opt/homebrew/bin/\(tool)"]

        for c in candidates where fm.isExecutableFile(atPath: c) { return c }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let full = "\(dir)/\(tool)"
                if fm.isExecutableFile(atPath: full) { return full }
            }
        }
        return nil
    }

    /// Runs `<tool> <arguments>` and captures stdout/stderr. `binDir`, when set,
    /// pins the binary to a specific directory (e.g. a freshly-built one).
    static func run(tool: String, arguments: [String], binDir: String? = nil) -> Outcome {
        guard let bin = locateBinary(tool: tool, preferredDir: binDir) else {
            return Outcome(
                binaryPath: nil, stdout: "", stderr: "", exitCode: -1,
                launchError: "\(tool) binary not found. Build it with `swift build --product \(tool)`, or set DICOM_CLI_BIN_DIR to the directory containing the dicom-* binaries.")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return Outcome(
                binaryPath: bin, stdout: "", stderr: "", exitCode: -1,
                launchError: "Failed to launch \(tool): \(error.localizedDescription). Is the App Sandbox disabled?")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        return Outcome(
            binaryPath: bin,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: proc.terminationStatus,
            launchError: nil)
    }
}

#endif
