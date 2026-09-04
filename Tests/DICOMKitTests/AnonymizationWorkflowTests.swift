//
// AnonymizationWorkflowTests.swift
// DICOMKitTests
//
// The shared `dicom-anon` run: the CLI and DICOMStudio's CLI Workshop both hand a
// `Request` to `AnonymizationWorkflow.run`. These tests pin the contract both
// surfaces rely on — input parsing and its messages, the output/recursive rules,
// the pixel-first refusal, and the console text — without either surface present.
//

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class AnonymizationWorkflowTests: XCTestCase {

    private typealias Request = AnonymizationWorkflow.Request
    private typealias ValidationError = AnonymizationWorkflow.ValidationError

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnonymizationWorkflowTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    /// 16×8 MONOCHROME2 8-bit image with PHI in the header. Every pixel is 200 so
    /// a blanked region is unmistakable.
    private func phiFile(burnedIn: Bool = false, modality: String = "OT") -> Data {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        ds.setString(modality, for: .modality, vr: .CS)
        ds.setString("Smith^John", for: .patientName, vr: .PN)
        ds.setString("MRN-123", for: .patientID, vr: .LO)
        ds.setString("19800101", for: .patientBirthDate, vr: .DA)
        ds.setString("20200101", for: .studyDate, vr: .DA)
        ds.setString("General Hospital", for: .institutionName, vr: .LO)
        if burnedIn { ds.setString("YES", for: .burnedInAnnotation, vr: .CS) }
        ds.setUInt16(8, for: .rows)
        ds.setUInt16(16, for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: Data(repeating: 200, count: 16 * 8))
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        return try! DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    @discardableResult
    private func write(_ data: Data, _ relative: String) throws -> String {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url.path
    }

    private func path(_ relative: String) -> String { root.appendingPathComponent(relative).path }

    private func run(_ r: Request, workflow: AnonymizationWorkflow = AnonymizationWorkflow()) throws
        -> (console: String, outcome: AnonymizationWorkflow.Outcome) {
        var console = ""
        let outcome = try workflow.run(r) { console += $0 }
        return (console, outcome)
    }

    private func assertValidationError(_ r: Request, _ expected: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try run(r), file: file, line: line) { error in
            XCTAssertEqual((error as? ValidationError)?.message, expected, file: file, line: line)
        }
    }

    // MARK: - Input parsing (messages are the CLI's)

    func testResolveRejectsUnknownProfile() {
        var r = Request(inputPath: "x"); r.profile = "hipaa"
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message, "Invalid anonymization profile")
        }
    }

    func testResolveProfileSpellings() throws {
        for (raw, expectPS315) in [("basic", false), ("Clinical-Trial", false), ("clinicaltrial", false),
                                   ("research", false), ("PS315", true)] {
            var r = Request(inputPath: "x"); r.profile = raw
            let resolved = try AnonymizationWorkflow.resolve(r)
            XCTAssertEqual(resolved.ps315Options != nil, expectPS315, raw)
        }
    }

    func testResolveTagListMessages() {
        var r = Request(inputPath: "x"); r.remove = ["not-a-tag"]
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message, "Invalid tag format: not-a-tag")
        }
        r = Request(inputPath: "x"); r.replace = ["0010,0010"]
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message, "Invalid replace format: 0010,0010. Use TAG=VALUE")
        }
        r = Request(inputPath: "x"); r.keep = ["??"]
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message, "Invalid tag format: ??")
        }
    }

    func testResolveTagListsAcceptHexAndKeywords() throws {
        var r = Request(inputPath: "x")
        r.remove = ["0010,0040"]; r.replace = ["PatientName=ANON"]; r.keep = ["Modality"]
        let resolved = try AnonymizationWorkflow.resolve(r)
        XCTAssertEqual(resolved.customActions.count, 2)
        XCTAssertEqual(resolved.preserveTags, [.modality])
        if case .replaceWithDummy(let v)? = resolved.customActions[.patientName] {
            XCTAssertEqual(v, "ANON")
        } else {
            XCTFail("expected replace action for PatientName")
        }
    }

    func testResolvePixelFlagMessages() {
        var r = Request(inputPath: "x"); r.redactStyle = "stripe"
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message,
                           "Invalid --redact-style 'stripe'. Use 'blank', 'label' or 'replace'.")
        }
        r = Request(inputPath: "x"); r.detectText = true; r.detectTextMode = "fuzzy"
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message,
                           "Invalid --detect-text-mode 'fuzzy'. Use 'classify' (default) or 'all'.")
        }
        r = Request(inputPath: "x"); r.recompress = "rle"
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message,
                           "--recompress only applies after pixel cleaning; add --clean-pixel-data or --redact-region.")
        }
        r = Request(inputPath: "x"); r.cleanPixelData = true; r.recompress = "webp"
        XCTAssertThrowsError(try AnonymizationWorkflow.resolve(r)) {
            XCTAssertEqual(($0 as? ValidationError)?.message,
                           "Invalid --recompress 'webp'. Use 'source' or a dicom-compress codec name.")
        }
    }

    func testResolvePixelOptions() throws {
        var r = Request(inputPath: "x")
        r.redactRegion = ["0,0,16,2"]; r.redactFill = 7; r.redactStyle = "label"; r.redactLabel = "X"
        r.detectText = true; r.detectTextMode = "all"; r.ocrAllFrames = true; r.recompress = "source"
        let p = try AnonymizationWorkflow.resolve(r).pixelOptions
        XCTAssertEqual(p.explicitRegions, [PixelRedactionPlan.Region(x: 0, y: 0, width: 16, height: 2)])
        XCTAssertEqual(p.fillValue, 7)
        XCTAssertEqual(p.style, .label("X"))
        XCTAssertEqual(p.detectText, .all)
        XCTAssertTrue(p.ocrAllFrames)
        XCTAssertEqual(p.recompress, .source)
        XCTAssertTrue(p.cleaningRequested)
        // An unspecified mode with OCR on is `classify`; OCR off is nil.
        r.detectTextMode = "classify"
        XCTAssertEqual(try AnonymizationWorkflow.resolve(r).pixelOptions.detectText, .classify)
        r.detectText = false
        XCTAssertNil(try AnonymizationWorkflow.resolve(r).pixelOptions.detectText)
    }

    func testResolvePS315RetentionOptionsOnlyForPS315() throws {
        var r = Request(inputPath: "x")
        r.retainDates = true; r.retainUids = true; r.shiftDates = 10
        XCTAssertNil(try AnonymizationWorkflow.resolve(r).ps315Options)
        r.profile = "ps315"
        let o = try XCTUnwrap(try AnonymizationWorkflow.resolve(r).ps315Options)
        XCTAssertTrue(o.retainLongitudinalTemporal)
        XCTAssertTrue(o.retainUIDs)
        XCTAssertEqual(o.dateOffsetDays, 10)
    }

    // MARK: - Run rules

    func testMissingInputIsFileNotFound() {
        assertValidationError(Request(inputPath: path("nope.dcm")), "File not found")
    }

    func testSingleFileNeedsOutputUnlessDryRunOrDetectOnly() throws {
        let input = try write(phiFile(), "in.dcm")
        assertValidationError(Request(inputPath: input),
                              "Anonymization requires --output (or use --dry-run to preview without writing)")
        var dry = Request(inputPath: input); dry.dryRun = true
        let (console, outcome) = try run(dry)
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertTrue(console.contains("(DRY RUN - no files modified)"), console)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["in.dcm"])
    }

    func testDirectoryRules() throws {
        try write(phiFile(), "dir/a.dcm")
        assertValidationError(Request(inputPath: path("dir")), "Directory anonymization requires --recursive flag")
        var r = Request(inputPath: path("dir")); r.recursive = true
        assertValidationError(r, "Directory anonymization requires --output directory")
    }

    func testBasicRunWritesAnonymizedFileAndSummary() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm"); r.verbose = true
        let (console, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(outcome.results.count, 1)
        let out = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: path("out.dcm"))))
        XCTAssertEqual(out.dataSet.string(for: .patientName), "ANONYMOUS")
        XCTAssertNil(out.dataSet[.institutionName])
        // The console is AnonConsole's summary — the CLI's text, verbatim.
        let expected = AnonConsole.summary(
            totalFiles: 1, successful: 1, failed: 0, dryRun: false,
            warnings: outcome.results[0].warnings,
            modifiedTags: Set(outcome.results[0].changedTags.map { "\($0)" }), verbose: true)
        XCTAssertEqual(console, expected)
        XCTAssertTrue(console.contains("Modified tags ("))
    }

    func testCustomProfileTagsRemoveExactlyThoseTags() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm")
        r.customProfileTags = [.institutionName]
        _ = try run(r)
        let out = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: path("out.dcm"))))
        XCTAssertNil(out.dataSet[.institutionName])
        XCTAssertEqual(out.dataSet.string(for: .patientName), "Smith^John")
    }

    func testDirectoryRunMirrorsTreeAndVerboseLines() throws {
        try write(phiFile(), "src/a.dcm")
        try write(phiFile(), "src/nested/b.dcm")
        try write(Data("junk".utf8), "src/readme.txt")
        var r = Request(inputPath: path("src")); r.output = path("dst"); r.recursive = true; r.verbose = true
        let (console, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 1, "the junk file fails, and any failure is exit 1")
        XCTAssertEqual(outcome.results.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path("dst/a.dcm")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path("dst/nested/b.dcm")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path("dst/readme.txt")))
        XCTAssertTrue(console.contains(AnonConsole.fileSuccessLine(relativePath: "a.dcm") + "\n"), console)
        XCTAssertTrue(console.contains(AnonConsole.fileSuccessLine(relativePath: "nested/b.dcm") + "\n"), console)
        XCTAssertTrue(console.contains("✗ readme.txt: "), console)
        XCTAssertTrue(console.contains("  Failed: 1\n"), console)
    }

    func testBackupLandsNextToOutput() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out/anon.dcm"); r.backup = true
        try FileManager.default.createDirectory(at: root.appendingPathComponent("out"), withIntermediateDirectories: true)
        _ = try run(r)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path("out/anon.dcm.backup"))), phiFile())
    }

    func testAuditLogWrittenAndAnnouncedWhenVerbose() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.dryRun = true; r.auditLog = path("audit.log"); r.verbose = true
        let (console, _) = try run(r)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path("audit.log")), "audit log is written even on a dry run")
        XCTAssertTrue(console.hasSuffix(AnonConsole.auditLogLine(path: path("audit.log")) + "\n"), console)
    }

    func testWriterHookNoteReachesWarnings() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm")
        let written = WrittenURLs()
        let workflow = AnonymizationWorkflow(writeFile: { data, url in
            try data.write(to: url.appendingPathExtension("redirected"))
            written.append(url)
            return "redirected to \(url.lastPathComponent).redirected"
        })
        let (console, outcome) = try run(r, workflow: workflow)
        XCTAssertEqual(written.paths, [path("out.dcm")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path("out.dcm.redirected")))
        XCTAssertEqual(outcome.results[0].warnings.last, "redirected to out.dcm.redirected")
        XCTAssertTrue(console.contains("⚠️  redirected to out.dcm.redirected"), console)
    }

    // MARK: - Refusal contract

    func testPS315RefusesBurnedInAnnotationUnlessAccepted() throws {
        let input = try write(phiFile(burnedIn: true), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm"); r.profile = "ps315"
        XCTAssertThrowsError(try run(r)) { error in
            let message = (error as? ValidationError)?.message ?? ""
            XCTAssertTrue(message.hasPrefix("Refusing to anonymize in.dcm: the pixel data may still contain PHI."), message)
            XCTAssertTrue(message.contains("--allow-burned-in-phi"), message)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: path("out.dcm")))

        // Dry runs report instead of refusing.
        var dry = r; dry.dryRun = true
        let (console, dryOutcome) = try run(dry)
        XCTAssertEqual(dryOutcome.exitCode, 0)
        XCTAssertTrue(console.contains("Burned In Annotation (0028,0301) is YES"), console)

        r.allowBurnedInPHI = true
        let (_, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 0)
        let out = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: path("out.dcm"))))
        XCTAssertEqual(out.dataSet.string(for: Tag(group: 0x0012, element: 0x0062)), "NO",
                       "an accepted residual must never be attested as removed")
    }

    func testReplaceStyleNeedsClassifyMode() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm")
        r.cleanPixelData = true; r.redactStyle = "replace"
        assertValidationError(r, "--redact-style replace needs --detect-text with mode classify (replacement values come from classified matches).")
    }

    // MARK: - Pixel-first cleaning

    func testExplicitRegionBlanksPixelsBeforeHeaderPass() throws {
        let input = try write(phiFile(burnedIn: true), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm"); r.profile = "ps315"
        r.redactRegion = ["0,0,16,2"]; r.redactFill = 5; r.verbose = true
        let (console, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 0, "cleaning the declared burned-in text earns the attestation")
        let out = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: path("out.dcm"))))
        let pixels = try XCTUnwrap(out.dataSet[.pixelData]?.valueData)
        XCTAssertEqual(Array(pixels.prefix(32)), Array(repeating: UInt8(5), count: 32), "the 2 top rows are the fill value")
        XCTAssertEqual(pixels[32], 200, "rows outside the region are untouched")
        XCTAssertEqual(out.dataSet.string(for: .burnedInAnnotation), "NO")
        XCTAssertEqual(out.dataSet.string(for: Tag(group: 0x0012, element: 0x0062)), "YES")
        XCTAssertEqual(out.dataSet.string(for: .patientName), "", "header pass still ran after the pixel pass")
        XCTAssertTrue(console.contains("Cleaned pixel data (explicit): "), console)
        XCTAssertTrue(console.contains("blanked (0,0) 16x2\n"), console)
    }

    func testDryRunPrintsPlanTableAndWritesNothing() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.dryRun = true; r.redactRegion = ["0,0,4,4"]
        let (console, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertTrue(console.hasPrefix("Pixel redaction plan:\n"), console)
        XCTAssertTrue(console.contains("1 explicit region = 1 unioned region\n"), console)
        XCTAssertTrue(console.contains("  Pixel modification: YES\n"), console)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["in.dcm"])
    }

    func testRecompressAfterExplicitRegion() throws {
        let input = try write(phiFile(), "in.dcm")
        var r = Request(inputPath: input); r.output = path("out.dcm")
        r.redactRegion = ["0,0,16,2"]; r.recompress = "rle"
        let (console, outcome) = try run(r)
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertTrue(console.hasPrefix("Re-encoded to 1.2.840.10008.1.2.5 (rle, lossless); source was 1.2.840.10008.1.2.1\n"), console)
        XCTAssertTrue(console.contains("  verified: redacted regions still blank after the codec round-trip\n"), console)
        let out = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: path("out.dcm"))))
        XCTAssertEqual(out.fileMetaInformation.string(for: Tag(group: 0x0002, element: 0x0010)), "1.2.840.10008.1.2.5")
    }
}

/// Thread-safe collector for the `@Sendable` writer hook.
private final class WrittenURLs: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    func append(_ url: URL) { lock.lock(); urls.append(url); lock.unlock() }
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return urls.map(\.path) }
}
