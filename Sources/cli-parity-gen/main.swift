// cli-parity-gen
//
// Developer tool (NOT shipped). Regenerates the bundled data the in-app
// "CLI Automation Testing" screen reads at runtime, so the app stays 100%
// Swift-native (no Process / no Python at runtime):
//
//   Sources/DICOMStudio/Resources/CLIParity/
//     ├─ CLIContracts.json     all dicom-* `--experimental-dump-help` (committed; no PHI)
//     ├─ fixtures/<file>.dcm    real DICOM inputs used for testing (git-ignored — may be PHI)
//     └─ goldens.json           real CLI stdout per (file, scenario) (git-ignored — may be PHI)
//
// Input DICOM files are taken from (in priority order):
//   1) $DICOM_INPUT_DIR
//   2) arg[3]
//   3) /Users/raster/Desktop/DICOM_Input        (default)
//   4) a deterministic synthetic fixture          (fallback if none found)
//
// It DOES shell out (Process) — fine, it's a normal non-sandboxed CLI.
//   swift run cli-parity-gen
//   swift run cli-parity-gen <outDir> <binDir> <inputDir>

import Foundation
import DICOMKit
import DICOMCore
import DICOMStudio
import CryptoKit

#if canImport(ImageIO)
import ImageIO
import CoreGraphics
#endif

// MARK: - Config

let MAX_BYTES = 5 * 1024 * 1024 // skip files larger than 5 MB

let cliArgs = CommandLine.arguments
let outDir = cliArgs.count > 1
    ? URL(fileURLWithPath: cliArgs[1], isDirectory: true)
    : URL(fileURLWithPath: "Sources/DICOMStudio/Resources/CLIParity", isDirectory: true)

let binDir: URL = {
    if cliArgs.count > 2 { return URL(fileURLWithPath: cliArgs[2], isDirectory: true) }
    if let exe = Bundle.main.executableURL { return exe.deletingLastPathComponent() }
    return URL(fileURLWithPath: ".build/debug", isDirectory: true)
}()

let inputDir: URL = {
    if let env = ProcessInfo.processInfo.environment["DICOM_INPUT_DIR"], !env.isEmpty {
        return URL(fileURLWithPath: env, isDirectory: true)
    }
    if cliArgs.count > 3 { return URL(fileURLWithPath: cliArgs[3], isDirectory: true) }
    return URL(fileURLWithPath: "/Users/raster/Desktop/DICOM_Input", isDirectory: true)
}()

let fixturesDir = outDir.appendingPathComponent("fixtures", isDirectory: true)
try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)

func errln(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
errln("cli-parity-gen: binDir=\(binDir.path)")
errln("cli-parity-gen: inputDir=\(inputDir.path)")
errln("cli-parity-gen: outDir=\(outDir.path)")

// MARK: - Process helper

@discardableResult
func run(_ launch: URL, _ arguments: [String]) -> (out: String, err: String, code: Int32) {
    let p = Process()
    p.executableURL = launch
    p.arguments = arguments
    let o = Pipe(), e = Pipe()
    p.standardOutput = o
    p.standardError = e
    do { try p.run() } catch { return ("", "spawn failed: \(error)", -1) }
    let od = o.fileHandleForReading.readDataToEndOfFile()
    let ed = e.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(decoding: od, as: UTF8.self), String(decoding: ed, as: UTF8.self), p.terminationStatus)
}

// MARK: - Synthetic fixture fallback (deterministic Part-10 bytes, Explicit VR LE)

func makeSyntheticFixture() -> Data {
    var data = Data()
    data.append(Data(count: 128))
    data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
    func tagBytes(_ g: UInt16, _ e: UInt16) -> [UInt8] { [UInt8(g & 0xFF), UInt8(g >> 8), UInt8(e & 0xFF), UInt8(e >> 8)] }
    func appendUL(_ g: UInt16, _ e: UInt16, _ v: UInt32) {
        data.append(contentsOf: tagBytes(g, e)); data.append(contentsOf: [0x55, 0x4C, 0x04, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: v.littleEndian) { Data($0) })
    }
    func appendStr(_ g: UInt16, _ e: UInt16, _ vr: String, _ value: String) {
        var v = value
        if v.utf8.count % 2 == 1 { v += (vr == "UI") ? "\u{0}" : " " }
        data.append(contentsOf: tagBytes(g, e)); data.append(contentsOf: Array(vr.utf8))
        let len = UInt16(v.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: len.littleEndian) { Data($0) })
        data.append(contentsOf: Array(v.utf8))
    }
    appendUL(0x0002, 0x0000, 0)
    appendStr(0x0002, 0x0010, "UI", "1.2.840.10008.1.2.1")
    appendStr(0x0002, 0x0002, "UI", "1.2.840.10008.5.1.4.1.1.2")
    appendStr(0x0002, 0x0003, "UI", "1.2.3.4.5.6.7.8.9")
    appendStr(0x0008, 0x0016, "UI", "1.2.840.10008.5.1.4.1.1.2")
    appendStr(0x0008, 0x0018, "UI", "1.2.3.4.5.6.7.8.9")
    appendStr(0x0008, 0x0020, "DA", "20200101")
    appendStr(0x0008, 0x0060, "CS", "CT")
    appendStr(0x0008, 0x1030, "LO", "PARITY TEST STUDY")
    appendStr(0x0010, 0x0010, "PN", "Test^Patient")
    appendStr(0x0010, 0x0020, "LO", "PARITY-0001")
    appendStr(0x0020, 0x000D, "UI", "1.2.3.4.5.6.7.8.10")
    appendStr(0x0020, 0x000E, "UI", "1.2.3.4.5.6.7.8.11")
    return data
}

// MARK: - Discover input DICOM files (one random file from the input directory)

func isDICOM(_ url: URL) -> Bool {
    guard let h = try? FileHandle(forReadingFrom: url) else { return false }
    defer { try? h.close() }
    guard let d = try? h.read(upToCount: 132), d.count == 132 else { return false }
    return Array(d[128..<132]) == [0x44, 0x49, 0x43, 0x4D]
}

func selectInputFixtures() -> [(bundledName: String, source: URL)] {
    let fm = FileManager.default
    guard let en = fm.enumerator(at: inputDir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return [] }
    // Collect every valid DICOM file (<= MAX_BYTES), then pick ONE at random.
    var candidates: [URL] = []
    while let url = en.nextObject() as? URL {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
        if url.lastPathComponent.hasPrefix(".") { continue }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? Int.max
        if size > MAX_BYTES || size <= 0 { continue }
        guard isDICOM(url) else { continue }
        candidates.append(url)
    }
    // Deterministic selection (was randomElement) so regenerated goldens are
    // reproducible run-to-run — a prerequisite for committable Tier-2 goldens.
    guard let pick = candidates.sorted(by: { $0.path < $1.path }).first else { return [] }
    errln("   (chose 1 deterministic file out of \(candidates.count) DICOM files: \(pick.lastPathComponent))")
    return [(bundledName: pick.lastPathComponent, source: pick)]
}

// MARK: - Golden scenario templates (per fixture file)

// `fixture` is the logical input a template needs; the generator expands it to
// concrete fixture file(s): "ct" (single-frame CT — synthetic + any real file),
// "mf" (synthetic multiframe), "ctpair" (two synthetic CTs for diff), "none"
// (no input file). FIXTURE / FIXTURE2 placeholders are substituted accordingly.
struct Template {
    let tool: String; let label: String
    let cliArgs: [String]; let studioParams: [String: String]
    var fixture: String = "ct"
    /// false = output depends on the host (e.g. available hardware backends), so it
    /// is deterministic per-machine but NOT portable dev↔CI → kept out of the
    /// committed goldens that drive the CI gate.
    var portable: Bool = true
    /// Wave 2: when set, the tool writes a file at the `OUTPUT` placeholder; the
    /// harness compares the produced file instead of stdout.
    var artifactName: String? = nil
    /// "text" = compare the file bytes as text (json/xml). "dicom" = re-dump the
    /// produced .dcm via dicom-info and compare the dump (volatile tags masked).
    var artifactKind: String = "text"
}

// Tier-2 Wave 1: deterministic, stdout-comparable scenarios (single-file or
// no-file tools). studioParams keys MUST match ToolCatalogHelpers
// .parameterDefinitions(for:) ids; "FIXTURE" is substituted with the input path.
// Flag coverage is one-flag-at-a-time over the deterministic stdout flags.
let curatedTemplates: [Template] = [
    // dicom-info — format enum coverage
    Template(tool: "dicom-info", label: "text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"]),
    Template(tool: "dicom-info", label: "json", cliArgs: ["--format", "json", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "json"]),
    Template(tool: "dicom-info", label: "csv", cliArgs: ["--format", "csv", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "csv"]),

    // dicom-validate — format enum + detailed flag
    Template(tool: "dicom-validate", label: "text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"]),
    Template(tool: "dicom-validate", label: "json", cliArgs: ["--format", "json", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "json"]),
    Template(tool: "dicom-validate", label: "detailed", cliArgs: ["--detailed", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "detailed": "true"]),

    // dicom-dump — length-bounded (avoids Studio's 65 535-byte default cap diverging
    // from the uncapped CLI); shared DICOMKit.HexDumper so bytes should match.
    Template(tool: "dicom-dump", label: "head256", cliArgs: ["--offset", "0", "--length", "256", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "offset": "0", "length": "256"]),
    Template(tool: "dicom-dump", label: "head256-nocolor-bpl8", cliArgs: ["--offset", "0", "--length", "256", "--no-color", "--bytes-per-line", "8", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "offset": "0", "length": "256", "no-color": "true", "bytes-per-line": "8"]),
    Template(tool: "dicom-dump", label: "tag-modality", cliArgs: ["--tag", "0008,0060", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "tag": "0008,0060"]),

    // NOTE: dicom-json / dicom-xml write a default output FILE (no stdout) when
    // --output is omitted — they are artifact-comparable (Wave 2), not stdout.

    // dicom-info — boolean flag coverage
    Template(tool: "dicom-info", label: "statistics", cliArgs: ["--statistics", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "statistics": "true"]),
    Template(tool: "dicom-info", label: "show-private", cliArgs: ["--show-private", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "show-private": "true"]),

    // dicom-dump — annotate / verbose / wider line (all length-bounded)
    Template(tool: "dicom-dump", label: "annotate", cliArgs: ["--offset", "0", "--length", "512", "--annotate", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "offset": "0", "length": "512", "annotate": "true"]),
    Template(tool: "dicom-dump", label: "annotate-verbose", cliArgs: ["--offset", "0", "--length", "512", "--annotate", "--verbose", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "offset": "0", "length": "512", "annotate": "true", "verbose": "true"]),
    Template(tool: "dicom-dump", label: "bpl32", cliArgs: ["--offset", "0", "--length", "256", "--bytes-per-line", "32", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "offset": "0", "length": "256", "bytes-per-line": "32"]),

    // dicom-validate — level + strict
    Template(tool: "dicom-validate", label: "level5", cliArgs: ["--level", "5", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "level": "5"]),
    Template(tool: "dicom-validate", label: "strict", cliArgs: ["--strict", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "strict": "true"]),

    // dicom-compress info (uses fixture) / backends (no fixture)
    Template(tool: "dicom-compress", label: "info", cliArgs: ["info", "FIXTURE"], studioParams: ["operation": "info", "input": "FIXTURE"]),
    Template(tool: "dicom-compress", label: "info-json", cliArgs: ["info", "--json", "FIXTURE"], studioParams: ["operation": "info", "input": "FIXTURE", "json": "true"]),
    Template(tool: "dicom-compress", label: "backends", cliArgs: ["backends"], studioParams: ["operation": "backends"], fixture: "none", portable: false),
    Template(tool: "dicom-compress", label: "backends-json", cliArgs: ["backends", "--json"], studioParams: ["operation": "backends", "json": "true"], fixture: "none", portable: false),
    // dicom-compress compress→RLE and decompress→explicit-le. RLE is pure-Swift
    // (deterministic, host-independent) so these are committable. Compared via
    // decoded-pixel hash (sha256 of decoded PixelData), robust to encapsulation.
    Template(tool: "dicom-compress", label: "compress-rle", cliArgs: ["compress", "FIXTURE", "-c", "rle", "--output", "OUTPUT"], studioParams: ["operation": "compress", "input": "FIXTURE", "codec": "rle", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "decoded-pixel-hash"),
    Template(tool: "dicom-compress", label: "decompress-rle", cliArgs: ["decompress", "FIXTURE", "--output", "OUTPUT", "--syntax", "explicit-le"], studioParams: ["operation": "decompress", "input": "FIXTURE", "output": "OUTPUT", "syntax": "explicit-le"], fixture: "ctrle", artifactName: "out.dcm", artifactKind: "decoded-pixel-hash"),
    // dicom-export single → PNG. The image FILE carries non-deterministic encoder
    // metadata (EXIF timestamps), so we compare the decoded RASTER (image-raster-hash:
    // sha256 of normalized 8-bit gray pixels). Marked local-only (portable:false) until
    // cross-machine CoreGraphics raster determinism is validated; runs + verifies locally.
    Template(tool: "dicom-export", label: "single-png", cliArgs: ["single", "FIXTURE", "--format", "png", "--output", "OUTPUT"], studioParams: ["operation": "single", "inputPath": "FIXTURE", "format": "png", "output": "OUTPUT"], portable: false, artifactName: "out.png", artifactKind: "image-raster-hash"),
    // dicom-pixedit — edits pixel data (mask a region) and rewrites the DICOM.
    // Deterministic (preserves UIDs/dates); compared via the DICOM-semantic re-dump.
    Template(tool: "dicom-pixedit", label: "mask-region", cliArgs: ["FIXTURE", "--output", "OUTPUT", "--mask-region", "0,0,4,4", "--fill-value", "0"], studioParams: ["inputPath": "FIXTURE", "output": "OUTPUT", "mask-region": "0,0,4,4", "fill-value": "0"], artifactName: "out.dcm", artifactKind: "dicom"),
    // dicom-pdf encapsulate — wraps a PDF into an Encapsulated PDF DICOM. Study/Series
    // UIDs fixed via args; the auto SOP Instance UID is volatile → masked at compare
    // (so this lands local-only via the determinism probe). DICOM-semantic re-dump.
    Template(tool: "dicom-pdf", label: "encapsulate", cliArgs: ["FIXTURE", "--output", "OUTPUT", "--patient-name", "PARITY^PDF", "--patient-id", "SYN-PDF", "--study-uid", "1.2.826.0.1.3680043.10.999.2.1", "--series-uid", "1.2.826.0.1.3680043.10.999.2.2"], studioParams: ["inputPath": "FIXTURE", "output": "OUTPUT", "patient-name": "PARITY^PDF", "patient-id": "SYN-PDF", "study-uid": "1.2.826.0.1.3680043.10.999.2.1", "series-uid": "1.2.826.0.1.3680043.10.999.2.2"], fixture: "pdf", artifactName: "out.dcm", artifactKind: "dicom"),

    // dicom-script template — no fixture; canned starter scripts to stdout
    Template(tool: "dicom-script", label: "template-workflow", cliArgs: ["template", "workflow"], studioParams: ["operation": "template", "templateName": "workflow"], fixture: "none"),
    Template(tool: "dicom-script", label: "template-anonymize", cliArgs: ["template", "anonymize"], studioParams: ["operation": "template", "templateName": "anonymize"], fixture: "none"),

    // dicom-uid validate/lookup — no fixture (except validate-file); deterministic stdout.
    Template(tool: "dicom-uid", label: "validate", cliArgs: ["validate", "1.2.840.10008.1.2.1"], studioParams: ["subcommand": "validate", "uids": "1.2.840.10008.1.2.1"], fixture: "none"),
    Template(tool: "dicom-uid", label: "validate-registry", cliArgs: ["validate", "--check-registry", "1.2.840.10008.1.2.1"], studioParams: ["subcommand": "validate", "uids": "1.2.840.10008.1.2.1", "check-registry": "true"], fixture: "none"),
    Template(tool: "dicom-uid", label: "validate-invalid", cliArgs: ["validate", "not-a-valid-uid"], studioParams: ["subcommand": "validate", "uids": "not-a-valid-uid"], fixture: "none"),
    Template(tool: "dicom-uid", label: "validate-file", cliArgs: ["validate", "--file", "FIXTURE"], studioParams: ["subcommand": "validate", "file": "FIXTURE"]),
    Template(tool: "dicom-uid", label: "lookup", cliArgs: ["lookup", "1.2.840.10008.1.2.1"], studioParams: ["subcommand": "lookup", "lookup-uid": "1.2.840.10008.1.2.1"], fixture: "none"),
    Template(tool: "dicom-uid", label: "lookup-listall", cliArgs: ["lookup", "--list-all"], studioParams: ["subcommand": "lookup", "list-all": "true"], fixture: "none"),

    // --- multiframe coverage (synthetic multiframe CT) ---
    Template(tool: "dicom-info", label: "mf-text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"], fixture: "mf"),
    Template(tool: "dicom-info", label: "mf-json", cliArgs: ["--format", "json", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "json"], fixture: "mf"),
    Template(tool: "dicom-dump", label: "mf-tag-frames", cliArgs: ["--tag", "0028,0008", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "tag": "0028,0008"], fixture: "mf"),
    Template(tool: "dicom-validate", label: "mf-text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"], fixture: "mf"),

    // --- dicom-diff (2-file, stdout) — two synthetic CTs ---
    Template(tool: "dicom-diff", label: "text", cliArgs: ["FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2"], fixture: "ctpair"),
    Template(tool: "dicom-diff", label: "json", cliArgs: ["--format", "json", "FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2", "format": "json"], fixture: "ctpair"),
    Template(tool: "dicom-diff", label: "summary", cliArgs: ["--format", "summary", "FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2", "format": "summary"], fixture: "ctpair"),
    Template(tool: "dicom-diff", label: "ignore-private", cliArgs: ["--ignore-private", "FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2", "ignore-private": "true"], fixture: "ctpair"),
    // Phase 0: --show-identical lists the identical tags WITH their values. Was a silent
    // gap (untemplated) where Studio printed only the tag name; now fixed to match the CLI.
    Template(tool: "dicom-diff", label: "show-identical", cliArgs: ["--show-identical", "FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2", "show-identical": "true"], fixture: "ctpair"),
    Template(tool: "dicom-diff", label: "show-identical-json", cliArgs: ["--format", "json", "--show-identical", "FIXTURE", "FIXTURE2"], studioParams: ["file1": "FIXTURE", "file2": "FIXTURE2", "format": "json", "show-identical": "true"], fixture: "ctpair"),

    // --- dicom-study (directory input, stdout) — synthetic multi-file study sets ---
    Template(tool: "dicom-study", label: "summary", cliArgs: ["summary", "FIXTURE"], studioParams: ["operation": "summary", "path": "FIXTURE"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "summary-json", cliArgs: ["summary", "--format", "json", "FIXTURE"], studioParams: ["operation": "summary", "path": "FIXTURE", "summary-format": "json"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "summary-csv", cliArgs: ["summary", "--format", "csv", "FIXTURE"], studioParams: ["operation": "summary", "path": "FIXTURE", "summary-format": "csv"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "stats", cliArgs: ["stats", "FIXTURE"], studioParams: ["operation": "stats", "path": "FIXTURE"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "stats-detailed", cliArgs: ["stats", "--detailed", "FIXTURE"], studioParams: ["operation": "stats", "path": "FIXTURE", "detailed": "true"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "stats-json", cliArgs: ["stats", "--format", "json", "FIXTURE"], studioParams: ["operation": "stats", "path": "FIXTURE", "stats-format": "json"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "check", cliArgs: ["check", "FIXTURE"], studioParams: ["operation": "check", "path": "FIXTURE"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "check-expected", cliArgs: ["check", "--expected-series", "2", "--expected-instances", "2", "FIXTURE"], studioParams: ["operation": "check", "path": "FIXTURE", "expected-series": "2", "expected-instances": "2"], fixture: "studyset"),
    Template(tool: "dicom-study", label: "compare", cliArgs: ["compare", "FIXTURE", "FIXTURE2"], studioParams: ["operation": "compare", "path1": "FIXTURE", "path2": "FIXTURE2"], fixture: "studypair"),
    Template(tool: "dicom-study", label: "compare-json", cliArgs: ["compare", "--format", "json", "FIXTURE", "FIXTURE2"], studioParams: ["operation": "compare", "path1": "FIXTURE", "path2": "FIXTURE2", "compare-format": "json"], fixture: "studypair"),

    // --- dicom-archive (read ops over a populated archive) — local-only fixture.
    // stats is omitted: its output carries a creation timestamp (Wave-4 masking).
    Template(tool: "dicom-archive", label: "query", cliArgs: ["query", "--archive", "FIXTURE"], studioParams: ["subcommand": "query", "archive": "FIXTURE"], fixture: "archive"),
    Template(tool: "dicom-archive", label: "query-modality", cliArgs: ["query", "--modality", "CT", "--archive", "FIXTURE"], studioParams: ["subcommand": "query", "archive": "FIXTURE", "modality": "CT"], fixture: "archive"),
    Template(tool: "dicom-archive", label: "query-json", cliArgs: ["query", "--format", "json", "--archive", "FIXTURE"], studioParams: ["subcommand": "query", "archive": "FIXTURE", "format": "json"], fixture: "archive"),
    Template(tool: "dicom-archive", label: "list", cliArgs: ["list", "--archive", "FIXTURE"], studioParams: ["subcommand": "list", "archive": "FIXTURE"], fixture: "archive"),
    Template(tool: "dicom-archive", label: "list-instances", cliArgs: ["list", "--show-instances", "--archive", "FIXTURE"], studioParams: ["subcommand": "list", "archive": "FIXTURE", "show-instances": "true"], fixture: "archive"),
    Template(tool: "dicom-archive", label: "check", cliArgs: ["check", "--archive", "FIXTURE"], studioParams: ["subcommand": "check", "archive": "FIXTURE"], fixture: "archive"),

    // === Wave 2: file-producer tools — compare the WRITTEN FILE, not stdout. ===
    // Text artifacts (json/xml). --metadata-only keeps PixelData out so the file is
    // small + deterministic. OUTPUT resolves to a scratch path on each side.
    Template(tool: "dicom-json", label: "file-meta", cliArgs: ["--metadata-only", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "metadata-only": "true", "output": "OUTPUT"], artifactName: "out.json"),
    Template(tool: "dicom-json", label: "file-meta-pretty", cliArgs: ["--metadata-only", "--pretty", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "metadata-only": "true", "pretty": "true", "output": "OUTPUT"], artifactName: "out.json"),
    Template(tool: "dicom-xml", label: "file-meta", cliArgs: ["--metadata-only", "--output", "OUTPUT", "FIXTURE"], studioParams: ["input": "FIXTURE", "metadata-only": "true", "output": "OUTPUT"], artifactName: "out.xml"),
    Template(tool: "dicom-xml", label: "file-meta-pretty", cliArgs: ["--metadata-only", "--pretty", "--output", "OUTPUT", "FIXTURE"], studioParams: ["input": "FIXTURE", "metadata-only": "true", "pretty": "true", "output": "OUTPUT"], artifactName: "out.xml"),

    // DICOM artifacts: produce a .dcm, re-dump via dicom-info, diff tags (volatile masked).
    // dicom-tags write mode — deterministic (no UID/timestamp regeneration).
    Template(tool: "dicom-tags", label: "set-name", cliArgs: ["--set", "PatientName=PARITY^EDIT", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "set": "PatientName=PARITY^EDIT", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),
    Template(tool: "dicom-tags", label: "set-studydesc", cliArgs: ["--set", "StudyDescription=PARITY EDITED STUDY", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "set": "StudyDescription=PARITY EDITED STUDY", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),
    Template(tool: "dicom-tags", label: "delete-tag", cliArgs: ["--delete", "StudyDescription", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "delete": "StudyDescription", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),
    Template(tool: "dicom-tags", label: "delete-private", cliArgs: ["--delete-private", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "delete-private": "true", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),

    // dicom-anon — basic/clinical-trial profiles are deterministic (no UID regen by default).
    Template(tool: "dicom-anon", label: "basic", cliArgs: ["--profile", "basic", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "profile": "basic", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),
    Template(tool: "dicom-anon", label: "clinical-trial", cliArgs: ["--profile", "clinical-trial", "--output", "OUTPUT", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "profile": "clinical-trial", "output": "OUTPUT"], artifactName: "out.dcm", artifactKind: "dicom"),

    // dicom-convert — uncompressed↔uncompressed transfer-syntax change keeps pixel bytes identical.
    Template(tool: "dicom-convert", label: "implicit-le", cliArgs: ["FIXTURE", "--output", "OUTPUT", "--transfer-syntax", "ImplicitVRLittleEndian"], studioParams: ["inputPath": "FIXTURE", "output": "OUTPUT", "transfer-syntax": "ImplicitVRLittleEndian"], artifactName: "out.dcm", artifactKind: "dicom"),

    // dicom-split — multiframe → MULTIPLE single-frame files (multi-file artifact).
    // Each produced frame is re-dumped and compared (volatile SOP UIDs masked).
    Template(tool: "dicom-split", label: "all-frames", cliArgs: ["FIXTURE", "--output", "OUTPUT"], studioParams: ["inputPath": "FIXTURE", "output": "OUTPUT"], fixture: "mf", artifactName: "frames", artifactKind: "dicom-multi"),
    Template(tool: "dicom-split", label: "frames-subset", cliArgs: ["FIXTURE", "--frames", "1,3", "--output", "OUTPUT"], studioParams: ["inputPath": "FIXTURE", "frames": "1,3", "output": "OUTPUT"], fixture: "mf", artifactName: "frames", artifactKind: "dicom-multi"),

    // dicom-merge — a directory of single-frame files → one multiframe (multi-input
    // via a directory fixture; fresh SOP UID masked).
    Template(tool: "dicom-merge", label: "studyset", cliArgs: ["FIXTURE", "--output", "OUTPUT"], studioParams: ["inputPath": "FIXTURE", "output": "OUTPUT"], fixture: "studyset", artifactName: "out.dcm", artifactKind: "dicom"),
]

// MARK: - Phase 2: contract-driven auto-generation of output scenarios
//
// For each UNCOVERED flag of a wired tool, emit one stdout-parity scenario derived from the
// SAME source of truth Studio uses live — ToolCatalogHelpers.parameterDefinitions +
// CommandBuilderHelpers.buildCommand — so cliArgs and studioParams cannot skew. One flag at a
// time, enum-expanded (NOT Cartesian). Curated templates above WIN (auto only fills the gap).
//
// Scoped incrementally; this first wave covers flat, deterministic STDOUT tools. Artifact
// producers (file output) + subcommand tools widen the scope in follow-ups.

/// (toolId, fixture id, positional input param ids in order, optional subcommand param).
/// For subcommand tools the generator iterates the subcommand param's allowedValues; flags
/// not visible under a given subcommand simply aren't emitted (buildCommand's visibleWhen),
/// and subcommands that need a different fixture / an --output we don't set fail the binary
/// and are auto-skipped (see the gen-skip net) — so one fixture per tool is fine.
private struct AutoTool {
    let id: String; let fixture: String; let inputKeys: [String]
    var subcommandParam: String? = nil
    /// Always-set params (e.g. a required `--profile`) so a one-flag-at-a-time scenario
    /// runs on top of a working baseline instead of being rejected for a missing arg.
    var baselineParams: [String: String] = [:]
    /// Set → artifact producer: the scenario sets this output param to OUTPUT and the
    /// produced FILE is compared (not stdout), via `artifactKind`.
    var outputParam: String? = nil
    var artifactKind: String = "dicom"
    var artifactExt: String = "dcm"
    /// false → not committed (e.g. image-raster-hash, whose CoreGraphics raster isn't yet
    /// validated as cross-machine deterministic); still runs + verifies in the local superset.
    var portable: Bool = true
    /// Distinguishes multiple configs of the SAME tool (e.g. convert in dicom vs image mode)
    /// so their auto-labels don't collide. Empty for single-config tools.
    var configLabel: String = ""
    /// Restrict subcommand iteration to these (e.g. only `extract` for dicom-pdf because
    /// `encapsulate` regenerates UIDs → non-deterministic). nil → iterate all allowedValues.
    var onlySubcommands: [String]? = nil
}
private let autoTools: [AutoTool] = [
    AutoTool(id: "dicom-diff", fixture: "ctpair", inputKeys: ["file1", "file2"]),
    AutoTool(id: "dicom-info", fixture: "ct", inputKeys: ["inputPath"]),
    AutoTool(id: "dicom-dump", fixture: "ct", inputKeys: ["inputPath"]),
    AutoTool(id: "dicom-validate", fixture: "ct", inputKeys: ["inputPath"]),
    AutoTool(id: "dicom-compress", fixture: "ct", inputKeys: ["input"], subcommandParam: "operation"),
    AutoTool(id: "dicom-study", fixture: "studyset", inputKeys: ["path"], subcommandParam: "operation"),
    // Archive read subcommands (query/list/check/stats) are stdout against a populated
    // archive fixture; write subcommands (init/import) need other inputs → auto-skip.
    AutoTool(id: "dicom-archive", fixture: "archive", inputKeys: ["archive"], subcommandParam: "subcommand"),
    // --- Artifact producers (compare the produced FILE, not stdout) ---
    // dicom-anon: one flag at a time on top of a baseline --profile basic; output .dcm
    // compared via dicom re-dump+mask (so volatile UIDs/group-length don't false-positive).
    AutoTool(id: "dicom-anon", fixture: "ct", inputKeys: ["inputPath"],
             baselineParams: ["profile": "basic"], outputParam: "output",
             artifactKind: "dicom", artifactExt: "dcm"),
    AutoTool(id: "dicom-pixedit", fixture: "ct", inputKeys: ["inputPath"],
             outputParam: "output", artifactKind: "dicom", artifactExt: "dcm"),
    AutoTool(id: "dicom-json", fixture: "ct", inputKeys: ["inputPath"],
             outputParam: "output", artifactKind: "text", artifactExt: "json"),
    AutoTool(id: "dicom-xml", fixture: "ct", inputKeys: ["input"],
             outputParam: "output", artifactKind: "text", artifactExt: "xml"),
    // dicom-export: image producer. Baseline --format png so single/contact-sheet emit a
    // PNG compared by decoded-raster hash (local-only). bulk (dir) / animate (gif) and other
    // ops auto-skip or land as their own ops via the subcommand iteration + ERROR net.
    AutoTool(id: "dicom-export", fixture: "ct", inputKeys: ["inputPath"], subcommandParam: "operation",
             baselineParams: ["format": "png"], outputParam: "output",
             artifactKind: "image-raster-hash", artifactExt: "png", portable: false),
    // dicom-convert: output type depends on --format (dicom vs png/jpeg/tiff), so artifactKind
    // is "auto" — the generator sniffs the produced file and routes the comparator per scenario.
    // Image outputs land local-only (image-raster-hash is portable:false); .dcm outputs commit.
    AutoTool(id: "dicom-convert", fixture: "ct", inputKeys: ["inputPath"],
             outputParam: "output", artifactKind: "auto", artifactExt: "dcm", portable: false),
    // dicom-convert SECOND config — image mode (baseline --format png) exposes the visibleWhen-gated
    // image flags (--frame/--quality/--window-center/--window-width/--apply-window) the dicom-mode
    // config can't reach. Output is a PNG → raster hash (local-only).
    AutoTool(id: "dicom-convert", fixture: "ct", inputKeys: ["inputPath"],
             baselineParams: ["format": "png"], outputParam: "output",
             artifactKind: "image-raster-hash", artifactExt: "png", portable: false, configLabel: "img-"),
    // NOTE: dicom-merge file-mode is intentionally NOT auto-gen'd. The only multi-file dir
    // fixture (`studyset`) spans 2 series, so merging it into one file picks a template frame
    // whose SeriesNumber depends on gather/tie-break order — the CLI itself isn't deterministic
    // here (F14). Every scenario would be the same SeriesNumber drift, which (per-scenario
    // allowlisting) would also mask real merge regressions. Needs a single-series dir fixture.
    // dicom-split frame mode: split a multiframe into per-frame .dcm files in a directory
    // (dicom-multi compare). Deterministic frame content.
    AutoTool(id: "dicom-split", fixture: "mf", inputKeys: ["inputPath"],
             outputParam: "output", artifactKind: "dicom-multi", artifactExt: "dcm", portable: false),
    // dicom-tags write mode: one flag at a time over the produced .dcm (curated covers
    // --set/--delete/--delete-private; this fills --tags/--verbose/etc.). A flag that needs
    // a write op to produce output (or a second file, e.g. --copy-from) auto-skips.
    AutoTool(id: "dicom-tags", fixture: "ct", inputKeys: ["inputPath"],
             outputParam: "output", artifactKind: "dicom", artifactExt: "dcm"),
    // dicom-compress artifact mode: the compress op writes a .dcm, so flags that only make
    // sense WITH an output (--quality/--verbose/--backend on top of a baseline --codec rle)
    // get exercised here. Compressed (RLE) bytes are deterministic but the wrapper carries
    // volatile UIDs masked by the dicom comparator; kept local-only (portable:false).
    AutoTool(id: "dicom-compress", fixture: "ct", inputKeys: ["input"], subcommandParam: "operation",
             baselineParams: ["codec": "rle"], outputParam: "output", artifactKind: "dicom",
             artifactExt: "dcm", portable: false, configLabel: "art-", onlySubcommands: ["compress"]),
]

/// A representative value for a one-flag-at-a-time scenario, or [] if no safe generic value
/// (text/array/flagPicker without allowedValues are skipped this wave — they need a per-flag value).
private func autoValues(_ def: CLIParameterDefinition) -> [String] {
    if def.parameterType == .booleanToggle { return ["true"] }
    if !def.allowedValues.isEmpty { return def.allowedValues }   // enum: cover each value
    switch def.parameterType {
    case .integerField, .slider: return [String(def.minValue ?? 1)]
    case .textField, .arrayField:
        // Semantic value heuristics for common value-bearing options so they get exercised.
        // A wrong guess just fails the binary and auto-skips (gen-skip net), so this only
        // adds coverage, never breakage. Ordered most-specific first.
        let key = (def.id + " " + def.flag).lowercased()
        if key.contains("tag") || key.contains("highlight") { return ["0008,0060"] }  // a tag in every fixture (Modality)
        if key.contains("replace")         { return ["0010,0010=ANONYMIZED"] }   // tag=value (before keep/remove)
        if key.contains("keep") || key.contains("remove") { return ["0010,0010"] }  // tag list
        if key.contains("window-center")  { return ["40"] }
        if key.contains("window-width")   { return ["400"] }
        if key.contains("shift") || key.contains("days") { return ["30"] }
        if key.contains("quality")         { return ["85"] }
        if key.contains("scale")           { return ["0.5"] }
        if key.contains("fps")             { return ["10"] }
        if key.contains("frame")           { return ["0"] }
        if key.contains("crop")            { return ["0,0,8,8"] }   // x,y,w,h on the 8×8 synthetic CT
        if key.contains("url")             { return ["https://example.org/{uid}"] }
        if key.contains("codec")           { return ["rle"] }        // RLE: lossless + deterministic
        if key.contains("syntax")          { return ["explicit-le"] } // decompress target
        if key.contains("exif")            { return ["PatientName"] } // dicom-export embed field
        if key.contains("variable")        { return ["VAR=value"] }   // dicom-script KEY=VALUE
        if key.contains("title")           { return ["Parity Doc"] }  // dicom-pdf document title
        return []   // genuinely tool-specific free-text (patterns, AE titles, …) — left to curated
    default: return []
    }
}

private func autoTemplates(curated: [Template]) -> [Template] {
    var out: [Template] = []
    for at in autoTools {
        let defs = ToolCatalogHelpers.parameterDefinitions(for: at.id)
        // Flags any curated scenario already exercises — skip them (auto fills only the gap).
        let coveredFlags = Set(curated.filter { $0.tool == at.id }.flatMap { $0.cliArgs }.filter { $0.hasPrefix("-") })
        // Subcommands to iterate (flat tool → [nil]).
        let subcommands: [String?]
        if let scParam = at.subcommandParam,
           let scDef = defs.first(where: { $0.id == scParam }), !scDef.allowedValues.isEmpty {
            let allowed = at.onlySubcommands.map { only in scDef.allowedValues.filter { only.contains($0) } } ?? scDef.allowedValues
            subcommands = allowed.map { Optional($0) }
        } else {
            subcommands = [nil]
        }
        for sc in subcommands {
            for def in defs {
                if def.isInternal || def.flag.isEmpty { continue }       // skip internal + positionals
                if def.parameterType == .subcommand || def.id == at.subcommandParam { continue }
                if def.parameterType == .filePath || def.parameterType == .outputPath { continue }
                if def.id == at.outputParam || at.baselineParams[def.id] != nil { continue }  // baseline/output, not varied
                // Artifact producers: skip "preview/no-write" flags (e.g. --dry-run). They
                // suppress the file write, so comparing a produced file is meaningless — they
                // belong to a future stdout-routed wave, not the artifact comparator.
                if at.outputParam != nil && (def.id.lowercased().contains("dry") || def.flag.contains("dry-run")) { continue }
                if coveredFlags.contains(def.flag) { continue }          // already covered by a curated scenario
                for value in autoValues(def) {
                    // pv = inputs (FIXTURE) + subcommand + baseline params + OUTPUT (artifact) + the one varied flag.
                    var pv: [CLIParameterValue] = at.inputKeys.enumerated().map {
                        CLIParameterValue(parameterID: $1, stringValue: $0 == 0 ? "FIXTURE" : "FIXTURE2")
                    }
                    if let scParam = at.subcommandParam, let sc { pv.append(CLIParameterValue(parameterID: scParam, stringValue: sc)) }
                    for (k, v) in at.baselineParams { pv.append(CLIParameterValue(parameterID: k, stringValue: v)) }
                    if let op = at.outputParam { pv.append(CLIParameterValue(parameterID: op, stringValue: "OUTPUT")) }
                    pv.append(CLIParameterValue(parameterID: def.id, stringValue: value))
                    // Derive cliArgs from buildCommand (same call Studio uses) and drop the tool name.
                    let cmd = CommandBuilderHelpers.buildCommand(toolName: at.id, parameterValues: pv, parameterDefinitions: defs)
                    var toks = cmd.split(separator: " ").map(String.init)
                    if !toks.isEmpty { toks.removeFirst() }
                    // Self-check: the flag must actually be emitted (else it isn't visible under `sc`).
                    guard toks.contains(def.flag) || toks.contains("--\(value)") else { continue }
                    var studioParams: [String: String] = [:]
                    for (i, key) in at.inputKeys.enumerated() { studioParams[key] = i == 0 ? "FIXTURE" : "FIXTURE2" }
                    if let scParam = at.subcommandParam, let sc { studioParams[scParam] = sc }
                    for (k, v) in at.baselineParams { studioParams[k] = v }
                    if let op = at.outputParam { studioParams[op] = "OUTPUT" }
                    studioParams[def.id] = value
                    let scPrefix = sc.map { "\($0)-" } ?? ""
                    let suffix = def.allowedValues.count > 1 ? "-\(value)" : ""
                    out.append(Template(tool: at.id, label: "auto-\(at.configLabel)\(scPrefix)\(def.id)\(suffix)",
                                        cliArgs: toks, studioParams: studioParams, fixture: at.fixture,
                                        portable: at.portable,
                                        artifactName: at.outputParam != nil ? "out.\(at.artifactExt)" : nil,
                                        artifactKind: at.artifactKind))
                }
            }
        }
    }
    return out
}

let templates: [Template] = curatedTemplates + autoTemplates(curated: curatedTemplates)

// MARK: - Discover dicom-* binaries

func discoverBinaries() -> [String] {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(atPath: binDir.path) else { return [] }
    return items.filter { name in
        guard name.hasPrefix("dicom-"), !name.contains(".") else { return false }
        let full = binDir.appendingPathComponent(name).path
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: full, isDirectory: &isDir) && !isDir.boolValue && fm.isExecutableFile(atPath: full)
    }.sorted()
}

// MARK: - 1) Fixtures: deterministic synthetic (committed) + optional real (git-ignored)

struct ConcreteFixture { let bundledName: String; let path: String; let phiSafe: Bool }

// 1a. Synthetic fixtures — byte-deterministic, PHI-free, COMMITTED under synthetic/.
let syntheticDir = outDir.appendingPathComponent("synthetic", isDirectory: true)
try? FileManager.default.createDirectory(at: syntheticDir, withIntermediateDirectories: true)
func writeSynthetic(_ name: String, _ data: Data) -> ConcreteFixture {
    let url = syntheticDir.appendingPathComponent(name)
    try? data.write(to: url)
    return ConcreteFixture(bundledName: name, path: url.path, phiSafe: true)
}
let synCT  = writeSynthetic("syn-ct.dcm",  SyntheticFixtures.singleFrameCT())
let synCT2 = writeSynthetic("syn-ct2.dcm", SyntheticFixtures.singleFrameCT2())
let synMF  = writeSynthetic("syn-mf.dcm",  SyntheticFixtures.multiFrameCT())
errln("→ wrote 3 synthetic fixtures to \(syntheticDir.path)")

// Minimal deterministic PDF — the input document for the dicom-pdf encapsulate
// scenario. PHI-free, fixed bytes → committable; logical fixture id `pdf`.
let synDoc = writeSynthetic("syn-doc.pdf", Data("""
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>
endobj
trailer
<< /Root 1 0 R >>
%%EOF
""".utf8))

// RLE-compressed copy of syn-ct, the input for the dicom-compress `decompress`
// scenario. Built by the real dicom-compress binary so it round-trips the same
// codec path; pure-Swift RLE is deterministic → committable (phiSafe). Skipped
// if dicom-compress isn't built (the committed fixture then stays as-is).
let synCtRLE: ConcreteFixture? = {
    let compressBin = binDir.appendingPathComponent("dicom-compress")
    guard FileManager.default.isExecutableFile(atPath: compressBin.path) else {
        errln("→ dicom-compress not built; skipping syn-ct-rle.dcm fixture")
        return nil
    }
    let dest = syntheticDir.appendingPathComponent("syn-ct-rle.dcm")
    try? FileManager.default.removeItem(at: dest)
    _ = run(compressBin, ["compress", synCT.path, "-c", "rle", "--output", dest.path])
    guard FileManager.default.fileExists(atPath: dest.path) else {
        errln("→ failed to build syn-ct-rle.dcm"); return nil
    }
    errln("→ wrote synthetic RLE fixture: syn-ct-rle.dcm")
    return ConcreteFixture(bundledName: "syn-ct-rle.dcm", path: dest.path, phiSafe: true)
}()

/// SHA-256 (hex) of a produced DICOM file's fully-decoded PixelData (all frames).
/// Mirrors `CLIParityEngine.decodedPixelHash` byte-for-byte so the committed golden
/// hash matches what the Studio reimplementation computes at test time.
func decodedPixelHash(ofFileAt path: String) -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let file = try? DICOMFile.read(from: data),
          let px = file.pixelData() else { return nil }
    return SHA256.hash(data: px.data).map { String(format: "%02x", $0) }.joined()
}

/// SHA-256 (hex) of a produced raster image's NORMALIZED pixels (8-bit device-gray).
/// Mirrors `CLIParityEngine.imageRasterHash` byte-for-byte so the committed golden
/// hash matches what the Studio reimplementation computes at test time.
func imageRasterHash(ofFileAt path: String) -> String? {
    #if canImport(ImageIO)
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let width = image.width, height = image.height
    guard width > 0, height > 0 else { return nil }
    var raster = Data(count: width * height)
    let ok: Bool = raster.withUnsafeMutableBytes { buf in
        guard let base = buf.baseAddress,
              let ctx = CGContext(data: base, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard ok else { return nil }
    var hasher = SHA256()
    hasher.update(data: Data("\(width)x\(height):".utf8))
    hasher.update(data: raster)
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    #else
    return nil
    #endif
}

// Synthetic directory fixtures (multi-file studies) for dicom-study.
func writeSyntheticSet(_ dirName: String, _ files: [(name: String, data: Data)]) -> ConcreteFixture {
    let dir = syntheticDir.appendingPathComponent(dirName, isDirectory: true)
    try? FileManager.default.removeItem(at: dir)   // clear stale → deterministic rewrite
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for f in files { try? f.data.write(to: dir.appendingPathComponent(f.name)) }
    return ConcreteFixture(bundledName: dirName, path: dir.path, phiSafe: true)
}
let synStudy  = writeSyntheticSet("syn-studyset",  SyntheticFixtures.studySet(studyIndex: 1))
let synStudy2 = writeSyntheticSet("syn-studyset2", SyntheticFixtures.studySet(studyIndex: 2))
errln("→ wrote 2 synthetic study-set directories")

// Clear git-ignored fixtures/ once, before writing the archive + real fixtures.
if let old = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil) {
    for f in old { try? FileManager.default.removeItem(at: f) }
}

// A populated archive for dicom-archive query/list/check. Built at gen time by
// running the real binary (init + import of syn-studyset). NON-committable: the
// archive index carries absolute paths + a creation timestamp, so it lives in
// git-ignored fixtures/ and its goldens stay local-only (phiSafe: false).
let archiveFixture: ConcreteFixture? = {
    let archiveBin = binDir.appendingPathComponent("dicom-archive")
    guard FileManager.default.isExecutableFile(atPath: archiveBin.path) else { return nil }
    let archiveDir = fixturesDir.appendingPathComponent("syn-archive", isDirectory: true)
    try? FileManager.default.removeItem(at: archiveDir)
    _ = run(archiveBin, ["init", "--path", archiveDir.path])
    let files = ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: synStudy.path),
                  includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "dcm" }.map { $0.path }.sorted()
    _ = run(archiveBin, ["import"] + files + ["--archive", archiveDir.path])
    errln("→ built populated archive fixture (local-only): syn-archive (\(files.count) instances)")
    return ConcreteFixture(bundledName: "syn-archive", path: archiveDir.path, phiSafe: false)
}()

// 1b. Optional real augmentation — one deterministic file, git-ignored (may be PHI).
// (fixtures/ was already cleared above, before the archive build.)
// `let` (not `var`) so the free `expandFixture` function can reference it
// (top-level `var` would be main-actor-isolated and unreachable from a free func).
let realCT: ConcreteFixture? = {
    if let pick = selectInputFixtures().first {
        let dest = fixturesDir.appendingPathComponent(pick.bundledName)
        try? FileManager.default.copyItem(at: pick.source, to: dest)
        errln("→ real augmentation fixture (PHI, git-ignored): \(pick.bundledName)")
        return ConcreteFixture(bundledName: pick.bundledName, path: dest.path, phiSafe: false)
    }
    errln("→ no real input fixture found; synthetic only")
    return nil
}()

// 1c. Resolve a template's logical fixture into concrete (primary, secondary) runs.
func expandFixture(_ id: String) -> [(primary: ConcreteFixture?, secondary: ConcreteFixture?)] {
    switch id {
    case "ct":
        var runs: [(primary: ConcreteFixture?, secondary: ConcreteFixture?)] = [(synCT, nil)]
        if let r = realCT { runs.append((r, nil)) }   // augment locally; not committed
        return runs
    case "mf":       return [(synMF, nil)]
    case "ctrle":    return synCtRLE.map { [($0, ConcreteFixture?.none)] } ?? []
    case "pdf":      return [(synDoc, nil)]
    case "ctpair":   return [(synCT, synCT2)]
    case "studyset": return [(synStudy, nil)]
    case "studypair":return [(synStudy, synStudy2)]
    case "archive":  return archiveFixture.map { [($0, ConcreteFixture?.none)] } ?? []
    case "none":     return [(nil, nil)]
    default:         return [(synCT, nil)]
    }
}

// MARK: - 2) CLI contracts (no PHI)

let binaries = discoverBinaries()
errln("→ \(binaries.count) dicom-* binaries found")
var tools: [String: Any] = [:]
var broken: [String: String] = [:]
for name in binaries {
    let r = run(binDir.appendingPathComponent(name), ["--experimental-dump-help"])
    if r.code == 0, let d = r.out.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) {
        tools[name] = obj
    } else {
        let firstLine = r.err.split(separator: "\n").first(where: { $0.contains(where: { $0.isLetter }) }).map(String.init) ?? "no dump-help output"
        broken[name] = String(firstLine.prefix(200))
        errln("  ! \(name): \(broken[name]!)")
    }
}
do {
    let contracts: [String: Any] = ["schemaVersion": 1, "toolCount": tools.count, "tools": tools, "broken": broken]
    let d = try JSONSerialization.data(withJSONObject: contracts, options: [.prettyPrinted, .sortedKeys])
    try d.write(to: outDir.appendingPathComponent("CLIContracts.json"))
    errln("✓ wrote CLIContracts.json (\(tools.count) tools, \(broken.count) broken)")
} catch { errln("✗ CLIContracts.json: \(error)"); exit(1) }

// MARK: - 3) Golden outputs (per template × resolved fixture)

// Canonicalize whole-stdout JSON (sorted keys) so goldens are byte-deterministic:
// some CLIs (dicom-compress backends --json, dicom-diff --format json) emit
// JSON with non-deterministic key order. Non-JSON output is returned unchanged.
// The Studio side applies the same canonicalization in CLIParityEngine.normalize.
func canonicalJSON(_ s: String) -> String {
    guard let d = s.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: d),
          let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
          let str = String(data: out, encoding: .utf8) else { return s }
    return str
}

/// Sniff a produced file's type from its magic bytes, so a tool whose output type
/// depends on a flag (e.g. dicom-convert --format) can be routed per scenario:
/// "dicom" (Part-10 "DICM" at offset 128), "image-raster-hash" (PNG/JPEG/GIF/TIFF),
/// else "text" (json/xml/plain). nil if the file is missing/empty (producer failed).
func detectArtifactKind(_ path: String) -> String? {
    guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { return nil }
    let b = [UInt8](data.prefix(132))
    if b.count >= 132, b[128] == 0x44, b[129] == 0x49, b[130] == 0x43, b[131] == 0x4D { return "dicom" }
    if b.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image-raster-hash" }   // PNG
    if b.starts(with: [0xFF, 0xD8, 0xFF])       { return "image-raster-hash" }   // JPEG
    if b.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image-raster-hash" }   // GIF
    if b.starts(with: [0x49, 0x49, 0x2A, 0x00]) || b.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) { return "image-raster-hash" } // TIFF
    return "text"
}

// Produce the comparable output for one (template, fixture) run: stdout for
// stdout tools, or the written-file content for artifact (file-producer) tools.
// OUTPUT resolves to a scratch file the binary writes; we read it back. Returns the
// effective artifactKind so the caller stamps it (matters when artifactKind == "auto").
func produce(_ bin: URL, _ t: Template, _ rf: (primary: ConcreteFixture?, secondary: ConcreteFixture?)) -> (out: String, err: String, code: Int32, kind: String) {
    func resolve(_ outputPath: String) -> [String] {
        t.cliArgs.map { tok in
            if tok == "FIXTURE"  { return rf.primary?.path ?? "" }
            if tok == "FIXTURE2" { return rf.secondary?.path ?? "" }
            if tok == "OUTPUT"   { return outputPath }
            return tok
        }
    }
    guard let artifact = t.artifactName else {
        let r = run(bin, resolve(""))
        return (canonicalJSON(r.out), r.err, r.code, "stdout")
    }
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cpg-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let info = binDir.appendingPathComponent("dicom-info")
    let fm = FileManager.default

    if t.artifactKind == "dicom-multi" {
        // OUTPUT is a DIRECTORY the producer fills with .dcm files (e.g. dicom-split).
        // Dump each (sorted) and concatenate with index headers — name-independent.
        let dir = tmp.appendingPathComponent(artifact, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let r = run(bin, resolve(dir.path))
        let files = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".dcm") }.sorted()
        var combined = "Frames: \(files.count)\n"
        for (i, f) in files.enumerated() {
            let d = run(info, [dir.appendingPathComponent(f).path]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            combined += "=== frame \(i) ===\n" + d + "\n"
        }
        return (combined, r.err.replacingOccurrences(of: tmp.path, with: "<tmp>"), r.code, "dicom-multi")
    }

    let outPath = tmp.appendingPathComponent(artifact).path
    let r = run(bin, resolve(outPath))
    // Stderr often echoes the (random) temp output path ("Output written to: …"),
    // which would make the stored golden non-deterministic. Canonicalize it.
    let cleanErr = r.err.replacingOccurrences(of: tmp.path, with: "<tmp>")
    // "auto" → detect the produced type from the file (the type depends on a flag, e.g.
    // dicom-convert --format dicom|png|jpeg). Fall back to text if the file is absent.
    let kind = t.artifactKind == "auto" ? (detectArtifactKind(outPath) ?? "text") : t.artifactKind
    if kind == "decoded-pixel-hash" {
        // Compress/decompress: the golden is sha256(decoded PixelData) so the
        // comparison is on pixel content, not encapsulated bytes (plan §4b).
        return (decodedPixelHash(ofFileAt: outPath) ?? "<pixel-decode-failed>", cleanErr, r.code, kind)
    }
    if kind == "image-raster-hash" {
        // Image producers (dicom-export/convert): the golden is sha256(decoded raster) so the
        // comparison is on pixel content, not the metadata-bearing image file (plan §4b).
        return (imageRasterHash(ofFileAt: outPath) ?? "<image-decode-failed>", cleanErr, r.code, kind)
    }
    if kind == "dicom" {
        // Re-dump the produced DICOM via dicom-info (shared MetadataPresenter) so the
        // comparison is tag-by-tag, not raw bytes. Volatile tags are masked at compare time.
        return (run(info, [outPath]).out, cleanErr, r.code, kind)
    }
    let content = (try? String(contentsOf: URL(fileURLWithPath: outPath), encoding: .utf8)) ?? ""
    return (canonicalJSON(content), cleanErr, r.code, kind)
}

var goldenEntries: [[String: Any]] = []
var autoSkipped = 0
for t in templates {
    let bin = binDir.appendingPathComponent(t.tool)
    guard FileManager.default.isExecutableFile(atPath: bin.path) else { continue }
    let isAuto = t.label.hasPrefix("auto-")
    for rf in expandFixture(t.fixture) {
        let result = produce(bin, t, rf)
        let stdout = result.out
        // Robustness for auto-generated scenarios: if the binary REJECTS the args
        // (nonzero exit AND no stdout — bad args, wrong/missing fixture, or a flag that
        // needs --output we didn't set), don't write a broken golden that would fail the
        // gate. Surface it as a gen-warning (it may be a real Tier-1 drift or a fixture
        // gap to fill later) and skip. Curated scenarios are never skipped.
        if isAuto && result.code != 0 && stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            autoSkipped += 1
            errln("  ⚠ gen-skip (auto) \(t.tool)-\(t.label): exit \(result.code) / no stdout — \(result.err.split(separator: "\n").first.map(String.init) ?? "")")
            continue
        }
        let primaryName = rf.primary?.bundledName ?? ""
        let idBase = primaryName.isEmpty ? "none" : (primaryName as NSString).deletingPathExtension
        let phiSafe = (rf.primary?.phiSafe ?? true) && (rf.secondary?.phiSafe ?? true)
        // Determinism probe: only committable (phiSafe) scenarios need to be
        // byte-stable. Re-run once; if the (canonicalized) output differs the CLI
        // itself is non-deterministic → exclude from committed, keep in local superset.
        var deterministic = true
        if phiSafe {
            deterministic = (stdout == produce(bin, t, rf).out)
            if !deterministic { errln("  ~ non-deterministic output, excluded from committed goldens: \(t.tool)-\(t.label)") }
        }
        var entry: [String: Any] = [
            "id": "\(idBase)__\(t.tool)-\(t.label)",
            "toolId": t.tool,
            "label": "\(primaryName.isEmpty ? t.tool : primaryName) · \(t.label)",
            "fixtureFile": primaryName,
            "cliArgs": t.cliArgs, "studioParams": t.studioParams,
            "stdout": stdout, "stderr": result.err, "exitCode": Int(result.code),
            "phiSafe": phiSafe, "deterministic": deterministic, "portable": t.portable,
        ]
        if let sec = rf.secondary { entry["fixtureFile2"] = sec.bundledName }
        // Stamp the EFFECTIVE artifactKind (result.kind) — for "auto" tools it's the type
        // detected from the produced file, so the harness compares the same way.
        if let art = t.artifactName { entry["artifactName"] = art; entry["artifactKind"] = result.kind }
        goldenEntries.append(entry)
    }
}

func writeGoldens(_ entries: [[String: Any]], to name: String) {
    do {
        let obj: [String: Any] = ["schemaVersion": 3, "scenarios": entries]
        let d = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try d.write(to: outDir.appendingPathComponent(name))
        errln("✓ wrote \(name) (\(entries.count) scenarios)")
    } catch { errln("✗ \(name): \(error)") }
}
// goldens.json = everything (synthetic + real); git-ignored; local dev superset.
// goldens.synthetic.json = PHI-free subset; COMMITTED; drives CI from a clean checkout.
writeGoldens(goldenEntries, to: "goldens.json")
// Committed gate set: PHI-free, deterministic, AND host-portable (dev↔CI).
writeGoldens(goldenEntries.filter {
    ($0["phiSafe"] as? Bool) == true && ($0["deterministic"] as? Bool) == true && ($0["portable"] as? Bool) == true
}, to: "goldens.synthetic.json")

if autoSkipped > 0 { errln("cli-parity-gen: \(autoSkipped) auto-scenario(s) skipped (binary rejected args / fixture gap — see gen-skip lines above)") }
errln("cli-parity-gen: done.")
