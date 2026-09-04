import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit
#if canImport(CoreGraphics)
import CoreGraphics
import CoreText
#endif

/// Pins the option semantics of PIXEL_ANONYMIZATION_PIPELINE.md §2.1 as implemented by
/// ``PixelCleaningWorkflow`` — the contract `dicom-anon` runs, tested at the library so
/// the CLI stays a thin adapter.
final class PixelCleaningWorkflowTests: XCTestCase {

    typealias Region = PixelRedactionPlan.Region
    typealias Options = PixelCleaningWorkflow.Options

    // MARK: - Fixtures

    private func plainImage(rows: Int = 20, columns: Int = 10, frames: Int = 1, modality: String = "XA") throws -> Data {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        ds.setString(modality, for: .modality, vr: .CS)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        if frames > 1 { ds.setString("\(frames)", for: .numberOfFrames, vr: .IS) }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB,
                                          data: Data(repeating: 200, count: rows * columns * frames))
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        return try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    // MARK: - Option semantics (no OCR needed)

    func testRedactRegionImpliesCleaning() {
        XCTAssertTrue(Options(explicitRegions: [Region(x: 0, y: 0, width: 1, height: 1)]).cleaningRequested)
        XCTAssertTrue(Options(cleanPixelData: true).cleaningRequested)
    }

    func testDetectTextDoesNotImplyCleaning() {
        let o = Options(detectText: .classify)
        XCTAssertFalse(o.cleaningRequested)
        XCTAssertTrue(o.isActive)
        XCTAssertFalse(Options().isActive)
    }

    func testModeParsing() {
        XCTAssertEqual(PixelCleaningWorkflow.TextDetectionMode.parse(nil), .classify)
        XCTAssertEqual(PixelCleaningWorkflow.TextDetectionMode.parse(""), .classify)
        XCTAssertEqual(PixelCleaningWorkflow.TextDetectionMode.parse("ALL"), .all)
        XCTAssertNil(PixelCleaningWorkflow.TextDetectionMode.parse("fuzzy"))
    }

    func testDetectTextShorthandIsExpandedForTheParser() {
        XCTAssertEqual(
            AnonArguments.expandDetectText(["in.dcm", "--detect-text=all", "-o", "out.dcm"]),
            ["in.dcm", "--detect-text", "--detect-text-mode", "all", "-o", "out.dcm"])
        XCTAssertEqual(AnonArguments.expandDetectText(["--detect-text"]), ["--detect-text"])
    }

    func testRetainedDetectedTextIsNeverAttestedAsIdentityRemoved() throws {
        var ds = try DICOMFile.read(from: plainImage()).dataSet
        ds.setString("YES", for: Tag(group: 0x0012, element: 0x0062), vr: .CS)
        PixelCleaningWorkflow.markDetectedTextRetained(in: &ds)
        XCTAssertEqual(ds.string(for: Tag(group: 0x0012, element: 0x0062))?.trimmingCharacters(in: .whitespaces), "NO")
        XCTAssertEqual(ds.string(for: .burnedInAnnotation)?.trimmingCharacters(in: .whitespaces), "YES")
    }

    func testNoPixelOptionsPassesBytesThroughUntouched() throws {
        let data = try plainImage()
        let report = try PixelCleaningWorkflow().run(fileData: data, options: Options(), dryRun: false)
        XCTAssertNil(report.plan)
        XCTAssertNil(report.outcome)
        XCTAssertEqual(report.data, data)
        XCTAssertTrue(report.residualWarnings.isEmpty)
    }

    func testExplicitRegionRedactsAndReportsOutcome() throws {
        let data = try plainImage(frames: 3)
        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(explicitRegions: [Region(x: 0, y: 0, width: 10, height: 2)]),
            dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.basis, .explicit)
        XCTAssertEqual(outcome.frameCount, 3)
        XCTAssertNotEqual(report.data, data)
        let cleaned = try DICOMFile.read(from: report.data)
        XCTAssertEqual(cleaned.dataSet.string(for: .burnedInAnnotation)?.trimmingCharacters(in: .whitespaces), "NO")
    }

    func testDryRunBuildsThePlanButNeverModifies() throws {
        let data = try plainImage()
        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(explicitRegions: [Region(x: 0, y: 0, width: 10, height: 2)]),
            dryRun: true)
        XCTAssertNotNil(report.plan)
        XCTAssertNil(report.outcome, "a dry run must not blank anything")
        XCTAssertEqual(report.data, data, "a dry run must hand the input through unchanged")
        let table = AnonConsole.pixelPlanTable(report: report, showText: true)
        XCTAssertTrue(table.contains("1 explicit region = 1 unioned region"), table)
        XCTAssertTrue(table.contains("Pixel modification: YES"), table)
        XCTAssertTrue(table.contains("Frames affected: all (1)"), table)
    }

    func testDryRunStillSurfacesAnUnresolvedRefusal() throws {
        var ds = try DICOMFile.read(from: plainImage()).dataSet
        ds.setString("YES", for: .burnedInAnnotation, vr: .CS)
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        let data = try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
        XCTAssertThrowsError(try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true), dryRun: true)) { error in
            guard case PixelRedactionError.unresolvedRegion = error else {
                return XCTFail("expected unresolvedRegion, got \(error)")
            }
        }
    }

    func testCleanWithNothingDeclaredIsAPassThroughWithoutAttestation() throws {
        let data = try plainImage()
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true), dryRun: false)
        guard case .nothingToDo = try XCTUnwrap(report.plan).decision else {
            return XCTFail("expected nothingToDo")
        }
        XCTAssertNil(report.outcome)
        XCTAssertEqual(report.data, data)
        let table = AnonConsole.pixelPlanTable(report: report, showText: true)
        XCTAssertTrue(table.contains("Pixel modification: NO"), table)
    }

    // MARK: - OCR-driven semantics (Apple platforms)

    #if canImport(Vision) && canImport(CoreGraphics)
    /// 8-bit frame with a white banner drawn at the top.
    private func bannerImage(text: String, frames: Int = 1, columns: Int = 512, rows: Int = 256) throws -> Data {
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: columns, height: rows, bitsPerComponent: 8,
            bytesPerRow: columns, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw XCTSkip("no bitmap context") }
        ctx.setFillColor(gray: 0.2, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: columns, height: rows))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 28, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CGColor(gray: 1, alpha: 1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        ctx.textPosition = CGPoint(x: 24, y: CGFloat(rows) - 50)
        CTLineDraw(line, ctx)
        guard let raw = ctx.data else { throw XCTSkip("no bitmap data") }
        let frame = Data(bytes: raw, count: columns * rows)
        var pixels = Data()
        for _ in 0..<frames { pixels += frame }

        var ds = try DICOMFile.read(from: plainImage(rows: rows, columns: columns, frames: frames, modality: "OT")).dataSet
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        return try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    /// `--detect-text` alone: report, modify nothing, and flag the leftover text so the
    /// caller refuses to write.
    func testDetectionOnlyReportsAndFlagsUnredactedText() throws {
        let data = try bannerImage(text: "SMITH JOHN")
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(detectText: .classify), dryRun: false)
        XCTAssertFalse(report.detections.isEmpty)
        XCTAssertNil(report.plan)
        XCTAssertNil(report.outcome)
        XCTAssertEqual(report.data, data, "detection must never modify pixels")
        XCTAssertEqual(report.detectedButUnredacted.count, report.detections.count)
        XCTAssertEqual(report.residualWarnings.count, 1)
        XCTAssertTrue(report.residualWarnings[0].contains("will not be redacted"), report.residualWarnings[0])

        let line = AnonConsole.textDetectionLine(report: report)
        XCTAssertTrue(line.hasPrefix("OCR: "), line)
        XCTAssertTrue(line.contains("0 selected for redaction across 1 sampled frame."), line)
        XCTAssertFalse(line.lowercased().contains("clean"), "must not claim cleanliness")

        let table = AnonConsole.pixelPlanTable(report: report, showText: false)
        XCTAssertTrue(table.contains("verdict=detected"), table)
        XCTAssertFalse(table.contains("SMITH"), "audit-safe table must not carry the string")
        XCTAssertTrue(table.contains("Pixel modification: NO"), table)
    }

    /// `--clean-pixel-data --detect-text`: every detected region is blanked (interim
    /// `all` semantics) on every frame and nothing is left flagged.
    func testCleanWithDetectionRedactsEverythingDetectedOnEveryFrame() throws {
        let data = try bannerImage(text: "DOE JANE 1961", frames: 4)
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true, detectText: .classify), dryRun: false)
        XCTAssertFalse(report.detections.isEmpty)
        XCTAssertEqual(report.scannedFrames, [0, 1, 3])
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.basis, .textDetection)
        XCTAssertEqual(outcome.frameCount, 4)
        XCTAssertTrue(report.detectedButUnredacted.isEmpty)
        XCTAssertTrue(report.residualWarnings.isEmpty)

        let line = AnonConsole.textDetectionLine(report: report)
        XCTAssertTrue(line.contains("\(report.detections.count) selected for redaction across 3 sampled frames."), line)

        // Oracle: OCR of the output finds nothing on any frame.
        let cleaned = try DICOMFile.read(from: report.data)
        XCTAssertTrue(try TextRegionDetector().detect(in: cleaned, allFrames: true).isEmpty)
    }

    func testAllModeAndClassifyModeBehaveIdenticallyUntilTheClassifierShips() throws {
        let data = try bannerImage(text: "ACC 4521")
        let a = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true, detectText: .all), dryRun: false)
        let c = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true, detectText: .classify), dryRun: false)
        XCTAssertEqual(a.outcome?.regions, c.outcome?.regions)
    }

    func testOcrAllFramesScansEveryFrame() throws {
        let data = try bannerImage(text: "MRN 9", frames: 4)
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(detectText: .all, ocrAllFrames: true), dryRun: false)
        XCTAssertEqual(report.scannedFrames, [0, 1, 2, 3])
    }

    func testDryRunWithDetectionPrintsTheTableAndWritesNothing() throws {
        let data = try bannerImage(text: "SMITH JOHN")
        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(cleanPixelData: true, explicitRegions: [Region(x: 0, y: 250, width: 512, height: 6)],
                             detectText: .classify),
            dryRun: true)
        XCTAssertNil(report.outcome)
        XCTAssertEqual(report.data, data)
        let table = AnonConsole.pixelPlanTable(report: report, showText: true)
        XCTAssertTrue(table.contains("Frame 0:"), table)
        XCTAssertTrue(table.contains("verdict=redact"), table)
        XCTAssertTrue(table.contains("1 explicit region + "), table)
        XCTAssertTrue(table.contains("OCR region"), table)
        XCTAssertTrue(table.contains("Pixel modification: YES"), table)
    }

    /// `label` style end-to-end: OCR of the output finds the stamp and none of the
    /// original strings — the original is 100% gone regardless of style.
    func testLabelStyleOutputReadsAsTheStampAndNeverTheOriginal() throws {
        let data = try bannerImage(text: "SMITH JOHN 0012345")
        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(cleanPixelData: true, detectText: .all, style: .label("REDACTED")),
            dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.style, .label("REDACTED"))
        let cleaned = try DICOMFile.read(from: report.data)
        let after = try TextRegionDetector().detect(in: cleaned)
        let texts = after.map { $0.text.uppercased() }
        XCTAssertTrue(texts.contains { $0.contains("REDACTED") }, "stamp should be legible: \(texts)")
        XCTAssertFalse(texts.contains { $0.contains("SMITH") || $0.contains("0012345") }, "\(texts)")
    }

    /// OCR and explicit rectangles union: the rectangle never suppresses detection.
    func testExplicitAndDetectedRegionsUnion() throws {
        let data = try bannerImage(text: "SMITH JOHN")
        let rect = Region(x: 0, y: 250, width: 512, height: 6)
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(explicitRegions: [rect], detectText: .all), dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.basis, .explicit)
        XCTAssertTrue(outcome.regions.contains(rect))
        XCTAssertGreaterThan(outcome.regions.count, 1, "detected regions must be unioned onto the explicit rectangle")
        XCTAssertTrue(report.detectedButUnredacted.isEmpty)
    }
    #else
    func testDetectTextIsAHardErrorWithoutVision() throws {
        let data = try plainImage()
        XCTAssertThrowsError(try PixelCleaningWorkflow().run(
            fileData: data, options: Options(detectText: .classify), dryRun: false)) { error in
            XCTAssertEqual(error as? TextDetectionError, .unavailable)
        }
    }
    #endif
}
