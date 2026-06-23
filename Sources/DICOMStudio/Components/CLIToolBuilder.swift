// CLIToolBuilder.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Builds the real `dicom-*` CLI products fresh (via `swift build`) so the CLI
// Parity screen never compares against a STALE binary (a binary built before the
// latest DICOMKit change — see project memory `rebuild-tool-after-dicomkit-change`).
//
// Like CLIToolTerminalCompare it spawns subprocesses and so requires the App
// Sandbox to be DISABLED; it must be removed before production.

import Foundation

#if os(macOS)

enum CLIToolBuilder {

    struct BuildOutcome: Sendable {
        var success: Bool
        /// The exact bin dir of the freshly-built products (from `--show-bin-path`),
        /// passed to CLIToolTerminalCompare so it cannot pick up a stale binary
        /// elsewhere on disk.
        var binDir: String?
        var log: String
    }

    /// Resolves the DICOMKit SwiftPM package root (the dir holding Package.swift).
    static func repoRoot() -> String? {
        let fm = FileManager.default
        if let dir = ProcessInfo.processInfo.environment["DICOM_REPO_DIR"],
           fm.fileExists(atPath: "\(dir)/Package.swift") { return dir }
        let cwd = fm.currentDirectoryPath
        if fm.fileExists(atPath: "\(cwd)/Package.swift") { return cwd }
        let hard = "/Users/raster/Documents/GitHub_Workspace/DICOMKit"
        if fm.fileExists(atPath: "\(hard)/Package.swift") { return hard }
        return nil
    }

    /// Locates the `swift` toolchain driver.
    static func swiftPath() -> String? {
        let fm = FileManager.default
        if let p = ProcessInfo.processInfo.environment["DICOM_SWIFT_PATH"], fm.isExecutableFile(atPath: p) { return p }
        for c in ["/usr/bin/swift", "/usr/local/bin/swift", "/opt/homebrew/bin/swift"]
            where fm.isExecutableFile(atPath: c) { return c }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let full = "\(dir)/swift"
                if fm.isExecutableFile(atPath: full) { return full }
            }
        }
        return nil
    }

    private static func runProcess(_ exe: String, _ args: [String]) -> (exitCode: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do { try proc.run() } catch {
            return (-1, "Failed to launch \(exe): \(error.localizedDescription)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    /// Builds the given products (RELEASE by default) and returns the exact bin dir to
    /// run them from. On failure the caller MUST NOT fall back to a stale binary.
    ///
    /// Release — not debug — is the default on purpose: release is the configuration that
    /// actually ships (Homebrew / installers), so the parity & Compare-CLI screens must
    /// rebuild and compare against the *shipped* artifact, and keeping `.build/release`
    /// fresh means a later `swift build -c release` or install can't pick up a stale
    /// binary. (The incremental rebuild is near-instant when nothing changed.)
    static func build(products: [String], configuration: String = "release") -> BuildOutcome {
        guard let swift = swiftPath() else {
            return BuildOutcome(success: false, binDir: nil,
                log: "Could not locate the `swift` toolchain. Set DICOM_SWIFT_PATH to the swift driver.")
        }
        guard let root = repoRoot() else {
            return BuildOutcome(success: false, binDir: nil,
                log: "Could not locate the DICOMKit package (Package.swift). Set DICOM_REPO_DIR to the repo root.")
        }
        var args = ["build", "--package-path", root, "-c", configuration]
        for p in products { args += ["--product", p] }
        let build = runProcess(swift, args)
        guard build.exitCode == 0 else {
            return BuildOutcome(success: false, binDir: nil, log: build.output)
        }
        // Resolve the exact bin dir (handles the arch-triple subdir / symlink).
        let show = runProcess(swift, ["build", "--package-path", root, "-c", configuration, "--show-bin-path"])
        let binDir = show.exitCode == 0
            ? show.output.trimmingCharacters(in: .whitespacesAndNewlines)
            : "\(root)/.build/\(configuration)"
        return BuildOutcome(success: true, binDir: binDir, log: build.output)
    }
}

#endif
