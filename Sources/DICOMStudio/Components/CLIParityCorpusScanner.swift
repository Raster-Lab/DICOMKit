// CLIParityCorpusScanner.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Scans a user-selected input DIRECTORY and classifies its files so the CLI
// Parity runner can pick the CORRECT input shape per tool (single file, a file
// pair, a multiframe, a study directory, an RLE-compressed file, a PDF, a
// .dcmscript) — exactly as the manual CLAUDE_PARITY_TEST did, but derived live
// from the user's own corpus. Where the corpus lacks a shape, the runner falls
// back to the bundled synthetic fixture (hybrid).

import Foundation
import DICOMKit
import DICOMCore

/// Classified view of a user's input directory. Plain data (Sendable) so it can
/// be built off the main actor.
public struct CorpusIndex: Sendable, Hashable {
    public let rootDir: String
    public let dicomFiles: [String]        // absolute paths, sorted (DICM-preamble match)
    public let multiframeFiles: [String]   // NumberOfFrames > 1
    public let rleFiles: [String]          // RLE Lossless transfer syntax
    public let studyDirs: [String]         // dirs containing ≥1 DICOM (root + subfolders)
    public let pdfFiles: [String]
    public let scriptFiles: [String]
    public let totalFiles: Int             // regular files seen
    public let classifyCappedAt: Int?      // non-nil if the multiframe/RLE probe was capped

    public init(rootDir: String, dicomFiles: [String], multiframeFiles: [String],
                rleFiles: [String], studyDirs: [String], pdfFiles: [String],
                scriptFiles: [String], totalFiles: Int, classifyCappedAt: Int?) {
        self.rootDir = rootDir; self.dicomFiles = dicomFiles
        self.multiframeFiles = multiframeFiles; self.rleFiles = rleFiles
        self.studyDirs = studyDirs; self.pdfFiles = pdfFiles; self.scriptFiles = scriptFiles
        self.totalFiles = totalFiles; self.classifyCappedAt = classifyCappedAt
    }

    /// Resolves a tool's `fixtureKind` to a concrete corpus input, or nil when the
    /// corpus can't satisfy that shape (→ caller falls back to the bundled fixture).
    public func resolve(kind: String) -> (file1: String, file2: String?)? {
        switch kind {
        case "ct":        return dicomFiles.first.map { ($0, nil) }
        case "ctpair":    return dicomFiles.count >= 2 ? (dicomFiles[0], dicomFiles[1]) : nil
        case "mf":        return multiframeFiles.first.map { ($0, nil) }
        case "ctrle":     return rleFiles.first.map { ($0, nil) }
        case "studyset", "series":
            return studyDirs.first.map { ($0, nil) }
        case "studypair":
            guard let first = studyDirs.first else { return nil }
            return (first, studyDirs.count >= 2 ? studyDirs[1] : nil)
        case "archive":   return nil   // an archive structure can't be derived from loose files
        case "pdf":       return pdfFiles.first.map { ($0, nil) }
        case "script":    return scriptFiles.first.map { ($0, nil) }
        // No input, or a format-specific shape the corpus can't safely supply
        // (json/xml/png/tiff/dirs) — use the bundled fixture instead.
        default:          return nil
        }
    }

    /// One-line summary for the UI.
    public var summary: String {
        var parts = ["\(dicomFiles.count) DICOM"]
        if !multiframeFiles.isEmpty { parts.append("\(multiframeFiles.count) multiframe") }
        parts.append("\(studyDirs.count) study folder\(studyDirs.count == 1 ? "" : "s")")
        parts.append("RLE \(rleFiles.isEmpty ? "✗" : "✓")")
        parts.append("PDF \(pdfFiles.isEmpty ? "✗" : "✓")")
        parts.append("script \(scriptFiles.isEmpty ? "✗" : "✓")")
        return parts.joined(separator: " · ")
    }
}

public enum CLIParityCorpusScanner {

    /// True if the file begins with the 128-byte preamble + "DICM" magic.
    static func isDICOM(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        guard let head = try? fh.read(upToCount: 132), head.count == 132 else { return false }
        return head[128] == 0x44 && head[129] == 0x49 && head[130] == 0x43 && head[131] == 0x4D
    }

    /// Reads a DICOM file's header to determine frame count and RLE-ness.
    static func classify(_ url: URL) -> (frames: Int, isRLE: Bool)? {
        guard let data = try? Data(contentsOf: url),
              let file = try? DICOMFile.read(from: data, force: true) else { return nil }
        let frames = Int(file.dataSet.string(for: .numberOfFrames)?
            .trimmingCharacters(in: .whitespaces) ?? "1") ?? 1
        let isRLE = file.transferSyntaxUID == TransferSyntax.rleLossless.uid
        return (frames, isRLE)
    }

    /// Scans `root` recursively and builds a CorpusIndex. The multiframe/RLE probe
    /// reads file headers and is bounded by `maxClassify` (early-exits once one of
    /// each is found). Run this off the main actor.
    public static func scan(directory root: URL, maxClassify: Int = 300) -> CorpusIndex {
        let fm = FileManager.default
        var files: [URL] = []
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey],
                                  options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            while let u = en.nextObject() as? URL {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue {
                    files.append(u)
                }
            }
        }
        files.sort { $0.path < $1.path }

        var dicom: [String] = []
        var pdf: [String] = []
        var script: [String] = []
        var dirsWithDicom: Set<String> = []
        for u in files {
            let ext = u.pathExtension.lowercased()
            if ext == "pdf" { pdf.append(u.path); continue }
            if ext == "dcmscript" { script.append(u.path); continue }
            if isDICOM(u) {
                dicom.append(u.path)
                dirsWithDicom.insert(u.deletingLastPathComponent().path)
            }
        }

        // Bounded multiframe / RLE probe (early-exit once one of each is found).
        var mf: [String] = []
        var rle: [String] = []
        var classified = 0
        var capped: Int? = nil
        for p in dicom {
            if !mf.isEmpty && !rle.isEmpty { break }
            if classified >= maxClassify { capped = maxClassify; break }
            classified += 1
            if let c = classify(URL(fileURLWithPath: p)) {
                if c.frames > 1 && mf.isEmpty { mf.append(p) }
                if c.isRLE && rle.isEmpty { rle.append(p) }
            }
        }

        // Study/archive candidates: the root (if it directly holds DICOMs) plus any
        // subfolder that contains DICOMs — matching how DICOM_Input was structured.
        var studyDirs: [String] = []
        if dirsWithDicom.contains(root.path) { studyDirs.append(root.path) }
        studyDirs += dirsWithDicom.filter { $0 != root.path }.sorted()
        if studyDirs.isEmpty && !dicom.isEmpty { studyDirs.append(root.path) }

        return CorpusIndex(
            rootDir: root.path, dicomFiles: dicom, multiframeFiles: mf, rleFiles: rle,
            studyDirs: studyDirs, pdfFiles: pdf, scriptFiles: script,
            totalFiles: files.count, classifyCappedAt: capped)
    }
}
