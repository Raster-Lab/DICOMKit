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
    public let imageFiles: [String]        // standard images (png/jpg/tif/…) — input for dicom-image
    public let imageDirs: [String]         // dirs containing ≥1 image (root + subfolders) — dicom-image --recursive
    public let multipageTiffs: [String]    // TIFFs with >1 page — dicom-image --split-pages
    public let totalFiles: Int             // regular files seen
    public let classifyCappedAt: Int?      // non-nil if the multiframe/RLE probe was capped

    public init(rootDir: String, dicomFiles: [String], multiframeFiles: [String],
                rleFiles: [String], studyDirs: [String], pdfFiles: [String],
                scriptFiles: [String], totalFiles: Int, classifyCappedAt: Int?,
                imageFiles: [String] = [], imageDirs: [String] = [], multipageTiffs: [String] = []) {
        self.rootDir = rootDir; self.dicomFiles = dicomFiles
        self.multiframeFiles = multiframeFiles; self.rleFiles = rleFiles
        self.studyDirs = studyDirs; self.pdfFiles = pdfFiles; self.scriptFiles = scriptFiles
        self.imageFiles = imageFiles; self.imageDirs = imageDirs; self.multipageTiffs = multipageTiffs
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
        // dicom-image inputs (kind names per CLIParityScenarioGenerator.fixtureKind):
        // a single image (`framepng`), a directory of images (`pngdir`, --recursive),
        // or a multi-page TIFF (`multitiff`, --split-pages). Drawn from the user's own
        // corpus when present; nil → the runner falls back to the bundled image.
        case "framepng":  return imageFiles.first.map { ($0, nil) }
        case "pngdir":    return imageDirs.first.map { ($0, nil) }
        case "multitiff": return multipageTiffs.first.map { ($0, nil) }
        // No input, or a format-specific shape the corpus can't safely supply
        // (json/xml derived fixtures, etc.) — use the bundled fixture instead.
        default:          return nil
        }
    }

    /// One-line summary for the UI.
    public var summary: String {
        var parts = ["\(dicomFiles.count) DICOM"]
        if !multiframeFiles.isEmpty { parts.append("\(multiframeFiles.count) multiframe") }
        if !imageFiles.isEmpty {
            let mp = multipageTiffs.isEmpty ? "" : ", \(multipageTiffs.count) multipage TIFF"
            parts.append("\(imageFiles.count) image\(imageFiles.count == 1 ? "" : "s")\(mp)")
        }
        parts.append("\(studyDirs.count) study folder\(studyDirs.count == 1 ? "" : "s")")
        parts.append("RLE \(rleFiles.isEmpty ? "✗" : "✓")")
        parts.append("image \(imageFiles.isEmpty ? "✗" : "✓")")
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
        var image: [String] = []
        var dirsWithDicom: Set<String> = []
        var dirsWithImage: Set<String> = []
        // Matches DICOMKit.ImageConverter.isImageFile so the corpus classifies an
        // image exactly the way dicom-image would accept it.
        let imageExts: Set<String> = ["jpg", "jpeg", "png", "tif", "tiff", "bmp", "gif"]
        for u in files {
            let ext = u.pathExtension.lowercased()
            if ext == "pdf" { pdf.append(u.path); continue }
            if ext == "dcmscript" { script.append(u.path); continue }
            if imageExts.contains(ext) {
                image.append(u.path)
                dirsWithImage.insert(u.deletingLastPathComponent().path)
                continue
            }
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

        // Image directories (root + any subfolder holding images) — the input shape
        // for dicom-image --recursive (batch image → Secondary Capture).
        var imageDirs: [String] = []
        if dirsWithImage.contains(root.path) { imageDirs.append(root.path) }
        imageDirs += dirsWithImage.filter { $0 != root.path }.sorted()

        // Multi-page TIFF probe (dicom-image --split-pages): first TIFF with >1 page,
        // bounded by the same maxClassify budget and early-exiting on the first hit.
        var multipageTiffs: [String] = []
        #if canImport(CoreGraphics)
        var imgClassified = 0
        for p in image where ["tif", "tiff"].contains((p as NSString).pathExtension.lowercased()) {
            if imgClassified >= maxClassify { break }
            imgClassified += 1
            if let n = try? ImageConverter.pageCount(of: URL(fileURLWithPath: p)), n > 1 {
                multipageTiffs.append(p); break
            }
        }
        #endif

        return CorpusIndex(
            rootDir: root.path, dicomFiles: dicom, multiframeFiles: mf, rleFiles: rle,
            studyDirs: studyDirs, pdfFiles: pdf, scriptFiles: script,
            totalFiles: files.count, classifyCappedAt: capped,
            imageFiles: image, imageDirs: imageDirs, multipageTiffs: multipageTiffs)
    }
}
