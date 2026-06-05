// OutputAccess.swift
// DICOMStudio
//
// Shared, sandbox/TCC-resilient output writer for CLI Workshop tools.
//
// WHY: tools that write a report/output file used to do `try? data.write(to:
// URL(fileURLWithPath: typedPath))`. On macOS, writing to a typed path under
// ~/Desktop, ~/Documents, etc. is blocked by **TCC (privacy)** — even when the
// App Sandbox is off, and even though POSIX reports the directory writable. The
// old code either silently swallowed the failure (no file, no message) or
// errored, which surfaced to users as an "access issue" when saving a report.
//
// FIX: a single helper that (1) prefers the security-scoped URL the Browse
// picker grants (always writable), (2) else tries the typed path, and (3) on
// failure falls back to ~/Downloads/DICOMStudio/<subfolder>/<filename> (the
// Downloads entitlement is always granted) and returns a user-facing note so the
// redirect is visible, never silent. The headless parity harness is unaffected:
// it writes to a genuinely-writable temp path, so step (2) succeeds and there is
// no redirect.

import Foundation

/// Sandbox/TCC-resilient writer for tool output files. See file header.
public enum OutputAccess {

    /// Writes `data` to the user's chosen output location, resilient to sandbox/TCC denials.
    /// - Parameters:
    ///   - data: the bytes to write.
    ///   - path: the typed/destination path (may be empty if only `scopedURL` is set).
    ///   - scopedURL: the security-scoped URL from the Browse picker, if any (preferred).
    ///   - subfolder: the `~/Downloads/DICOMStudio/<subfolder>/` bucket used only on fallback.
    /// - Returns: the URL actually written, plus a non-nil note when the write was redirected.
    /// - Throws: only if even the Downloads fallback write fails.
    @discardableResult
    public static func write(_ data: Data, toPath path: String, scopedURL: URL?,
                             subfolder: String = "Output") throws -> (url: URL, note: String?) {
        // 1. Security-scoped URL from the picker — always granted for writing.
        if let scoped = scopedURL {
            let accessing = scoped.startAccessingSecurityScopedResource()
            defer { if accessing { scoped.stopAccessingSecurityScopedResource() } }
            try writeCreatingParents(data, to: scoped)
            return (scoped, nil)
        }

        guard !path.isEmpty else {
            // No destination at all → fall straight to the Downloads bucket.
            let fallback = fallbackURL(forName: "output.dat", subfolder: subfolder)
            try writeCreatingParents(data, to: fallback)
            return (fallback, redirectNote(from: nil, to: fallback, reason: "no output path was provided"))
        }

        // 2. Try the typed path as-is.
        let target = URL(fileURLWithPath: path)
        do {
            try writeCreatingParents(data, to: target)
            return (target, nil)
        } catch {
            // 3. Fall back to ~/Downloads/DICOMStudio/<subfolder>/<filename>.
            let fallback = fallbackURL(forName: target.lastPathComponent, subfolder: subfolder)
            try writeCreatingParents(data, to: fallback)
            return (fallback, redirectNote(from: target, to: fallback, reason: error.localizedDescription))
        }
    }

    /// Convenience for text output (UTF-8).
    @discardableResult
    public static func writeString(_ string: String, toPath path: String, scopedURL: URL?,
                                   subfolder: String = "Output") throws -> (url: URL, note: String?) {
        try write(Data(string.utf8), toPath: path, scopedURL: scopedURL, subfolder: subfolder)
    }

    /// Resolves a writable destination URL up front, for producers that can't route
    /// their write through `write(_:toPath:…)` — e.g. `CGImageDestination` (writes to a
    /// URL) or directory producers (fill a folder with many files). Prefers the picker's
    /// scoped URL; else PROBES the typed path's parent (TCC only fails at write time, so
    /// a create+write+delete probe is the reliable detector); on failure returns a
    /// ~/Downloads/DICOMStudio/<subfolder>/ destination + a note. The headless harness's
    /// temp path passes the probe, so it is never redirected.
    /// - Parameter isDirectory: probe the path itself (true) vs its parent (false).
    public static func resolveWritableURL(forPath path: String, scopedURL: URL?,
                                          subfolder: String = "Output",
                                          isDirectory: Bool = false) -> (url: URL, note: String?) {
        if let scoped = scopedURL { return (scoped, nil) }
        guard !path.isEmpty else {
            let fb = fallbackURL(forName: "output.dat", subfolder: subfolder)
            return (fb, redirectNote(from: nil, to: fb, reason: "no output path was provided"))
        }
        let target = URL(fileURLWithPath: path)
        let probeDir = isDirectory ? target : target.deletingLastPathComponent()
        if canWrite(into: probeDir) { return (target, nil) }
        let fb = isDirectory
            ? fallbackDir(named: target.lastPathComponent, subfolder: subfolder)
            : fallbackURL(forName: target.lastPathComponent, subfolder: subfolder)
        return (fb, redirectNote(from: target, to: fb, reason: "destination is not writable (sandbox/TCC)"))
    }

    /// True if a probe file can be created+removed in `dir` (creating `dir` if needed).
    private static func canWrite(into dir: URL) -> Bool {
        let fm = FileManager.default
        do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) } catch { return false }
        let probe = dir.appendingPathComponent(".dicomstudio-write-probe-\(ProcessInfo.processInfo.processIdentifier)")
        do { try Data().write(to: probe, options: .atomic); try? fm.removeItem(at: probe); return true }
        catch { return false }
    }

    private static func fallbackDir(named name: String, subfolder: String) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        return downloads.appendingPathComponent("DICOMStudio")
            .appendingPathComponent(subfolder)
            .appendingPathComponent(name.isEmpty ? "output" : name)
    }

    // MARK: - Helpers

    private static func writeCreatingParents(_ data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private static func fallbackURL(forName name: String, subfolder: String) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        let fileName = name.isEmpty ? "output.dat" : name
        return downloads.appendingPathComponent("DICOMStudio")
            .appendingPathComponent(subfolder)
            .appendingPathComponent(fileName)
    }

    private static func redirectNote(from target: URL?, to fallback: URL, reason: String) -> String {
        var note = "⚠ "
        if let target { note += "Could not write to \(target.path) (\(reason)). " }
        else { note += "\(reason). " }
        note += "Redirected to: \(fallback.path)\n"
        note += "  Tip: use the Browse button next to the output field to grant write access to a custom location."
        return note
    }
}
