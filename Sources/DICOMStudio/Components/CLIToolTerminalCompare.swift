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

        /// stdout + stderr as a real terminal shows them — both streams share one
        /// TTY, so the user sees them together. We can't recover the exact byte
        /// interleaving from two separate pipes, so we append stderr after stdout.
        /// That reproduces the terminal's order whenever stderr is written at
        /// END-OF-RUN, which covers every success path here: `dicom-echo` flushes its
        /// progress dots to stdout *during* the run and writes the `Summary:` / stats
        /// block to stderr at the end (likewise `--verbose` / `--diagnose` / `--stats`,
        /// and `dicom-query` / `dicom-send`, which put data on stdout and logs on
        /// stderr). The one approximate case is a FAILED run (e.g. `dicom-echo
        /// --count N` with a failed echo): its per-attempt `✗` lines go to stderr
        /// *mid-loop*, interleaved with the stdout dots, so the concatenated panel
        /// shows a dots-block then an errors-block rather than true interleaving —
        /// faithful ordering there would need a PTY. The parity VERDICT is unaffected
        /// (CLIParityEngine.normalize canonicalizes blank lines / order). The
        /// Compare-CLI view shows this; the parity engine keeps reading `stdout` /
        /// `stderr` separately for its own semantic comparison.
        var combined: String {
            if stdout.isEmpty { return stderr }
            if stderr.isEmpty { return stdout }
            return stdout + stderr
        }
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
    ///   2. SwiftPM build products under the repo — the **most-recently-built** of
    ///      `.build/release|debug/<tool>` (so a stale config can't shadow a fresh one)
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

        func mtime(_ path: String) -> Date {
            ((try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date) ?? .distantPast
        }

        var candidates: [String] = []
        let repoRoots = [
            fm.currentDirectoryPath,
            "/Users/raster/Documents/GitHub_Workspace/DICOMKit"
        ]
        for root in repoRoots {
            // Prefer whichever of release/debug was built most recently. Otherwise a
            // stale `.build/release` (not rebuilt after a source change, while
            // `swift build` only refreshed debug) silently shadows the fresh binary —
            // which is exactly why the terminal / "Compare CLI" output diverged from
            // the source while the parity (which rebuilds first) stayed correct.
            let rel = "\(root)/.build/release/\(tool)"
            let dbg = "\(root)/.build/debug/\(tool)"
            candidates += [rel, dbg].sorted { mtime($0) > mtime($1) }
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
    /// pins the binary to a specific directory (e.g. a freshly-built one). `timeout`,
    /// when set, is a wall-clock backstop: a network tool can block past its own
    /// connect timeout if the PACS accepts TCP but never answers a DIMSE request, so
    /// past the deadline the child is terminated (then hard-killed) and the outcome is
    /// marked timed-out — otherwise the whole parity run would freeze.
    static func run(tool: String, arguments: [String], binDir: String? = nil,
                    timeout: TimeInterval? = nil) -> Outcome {
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

        // Drain both pipes concurrently. Reading them sequentially can deadlock
        // when the child fills the stderr buffer (~64 KB) while we're still blocked
        // reading stdout — neither side can make progress. A background read of
        // stderr removes that hazard for large outputs.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "dicomkit.cli-compare.pipe-read", attributes: .concurrent)
        queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }

        var timedOut = false
        if let timeout {
            if group.wait(timeout: .now() + timeout) == .timedOut {
                timedOut = true
                proc.terminate()                                  // SIGTERM
                if group.wait(timeout: .now() + 3) == .timedOut {
                    kill(proc.processIdentifier, SIGKILL)         // escalate if it ignores SIGTERM
                    group.wait()
                }
            }
        } else {
            group.wait()
        }
        proc.waitUntilExit()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""
        if timedOut {
            return Outcome(
                binaryPath: bin, stdout: stdout, stderr: stderr, exitCode: -2,
                launchError: "\(tool) exceeded \(Int(timeout ?? 0))s and was terminated — the PACS likely accepted the connection but never answered the DIMSE request.")
        }
        return Outcome(
            binaryPath: bin, stdout: stdout, stderr: stderr,
            exitCode: proc.terminationStatus, launchError: nil)
    }
}

#endif
