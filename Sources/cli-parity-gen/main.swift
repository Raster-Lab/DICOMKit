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
    guard let pick = candidates.randomElement() else { return [] }
    errln("   (chose 1 random file out of \(candidates.count) DICOM files)")
    return [(bundledName: pick.lastPathComponent, source: pick)]
}

// MARK: - Golden scenario templates (per fixture file)

struct Template { let tool: String; let label: String; let cliArgs: [String]; let studioParams: [String: String] }
let templates: [Template] = [
    Template(tool: "dicom-info", label: "text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"]),
    Template(tool: "dicom-info", label: "json", cliArgs: ["--format", "json", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "json"]),
    Template(tool: "dicom-info", label: "csv", cliArgs: ["--format", "csv", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "csv"]),
    Template(tool: "dicom-validate", label: "text", cliArgs: ["FIXTURE"], studioParams: ["inputPath": "FIXTURE"]),
    Template(tool: "dicom-validate", label: "json", cliArgs: ["--format", "json", "FIXTURE"], studioParams: ["inputPath": "FIXTURE", "format": "json"]),
]

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

// MARK: - 1) Fixtures (real input from the folder, or synthetic fallback)

// clear old fixtures
if let old = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil) {
    for f in old { try? FileManager.default.removeItem(at: f) }
}

var fixtures: [(bundledName: String, source: URL)] = selectInputFixtures()
if fixtures.isEmpty {
    errln("→ no DICOM files found in \(inputDir.path); using synthetic fixture")
    let synthURL = fixturesDir.appendingPathComponent("fixture.dcm")
    try? makeSyntheticFixture().write(to: synthURL)
    fixtures = [("fixture.dcm", synthURL)]
} else {
    errln("→ selected \(fixtures.count) input file(s) from \(inputDir.path):")
    for f in fixtures {
        let dest = fixturesDir.appendingPathComponent(f.bundledName)
        try? FileManager.default.copyItem(at: f.source, to: dest)
        errln("   • \(f.bundledName)")
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

// MARK: - 3) Golden outputs (per fixture × template)

var goldenEntries: [[String: Any]] = []
for fx in fixtures {
    let srcPath = fixturesDir.appendingPathComponent(fx.bundledName).path
    for t in templates {
        let bin = binDir.appendingPathComponent(t.tool)
        guard FileManager.default.isExecutableFile(atPath: bin.path) else { continue }
        let resolved = t.cliArgs.map { $0 == "FIXTURE" ? srcPath : $0 }
        let r = run(bin, resolved)
        let base = (fx.bundledName as NSString).deletingPathExtension
        goldenEntries.append([
            "id": "\(base)__\(t.tool)-\(t.label)",
            "toolId": t.tool, "label": "\(fx.bundledName) · \(t.label)",
            "fixtureFile": fx.bundledName,
            "cliArgs": t.cliArgs, "studioParams": t.studioParams,
            "stdout": r.out, "stderr": r.err, "exitCode": Int(r.code),
        ])
    }
    errln("  • goldens for \(fx.bundledName)")
}
do {
    let goldens: [String: Any] = ["schemaVersion": 2, "scenarios": goldenEntries]
    let d = try JSONSerialization.data(withJSONObject: goldens, options: [.prettyPrinted, .sortedKeys])
    try d.write(to: outDir.appendingPathComponent("goldens.json"))
    errln("✓ wrote goldens.json (\(goldenEntries.count) scenarios over \(fixtures.count) fixtures)")
} catch { errln("✗ goldens.json: \(error)"); exit(1) }

errln("cli-parity-gen: done.")
