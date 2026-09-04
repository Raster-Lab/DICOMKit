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

    /// Two text lines on one frame, with a header naming SMITH^JOHN / 0012345.
    private func twoLineImage(top: String, bottom: String, columns: Int = 512, rows: Int = 256) throws -> Data {
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: columns, height: rows, bitsPerComponent: 8,
            bytesPerRow: columns, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw XCTSkip("no bitmap context") }
        ctx.setFillColor(gray: 0.2, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: columns, height: rows))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 28, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CGColor(gray: 1, alpha: 1)]
        for (text, y) in [(top, CGFloat(rows) - 50), (bottom, CGFloat(40))] {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
            ctx.textPosition = CGPoint(x: 24, y: y)
            CTLineDraw(line, ctx)
        }
        guard let raw = ctx.data else { throw XCTSkip("no bitmap data") }
        var ds = try DICOMFile.read(from: plainImage(rows: rows, columns: columns, modality: "OT")).dataSet
        ds.setString("SMITH^JOHN", for: .patientName, vr: .PN)
        ds.setString("0012345", for: .patientID, vr: .LO)
        ds.setString("19611203", for: .patientBirthDate, vr: .DA)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: Data(bytes: raw, count: columns * rows))
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

    /// Classify keeps allowlisted clinical text and redacts PHI; `all` blanks both.
    func testClassifyKeepsLateralityWhileAllBlanksIt() throws {
        // Two lines: a PHI banner at the top and a laterality/scale label lower down.
        let data = try twoLineImage(top: "SMITH JOHN 0012345", bottom: "R 10 cm")
        let c = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true, detectText: .classify), dryRun: false)
        XCTAssertEqual(c.detections.count, 2, "\(c.detections.map(\.text))")
        XCTAssertEqual(c.verdicts.filter(\.isRedact).count, 1, "\(zip(c.detections, c.verdicts).map { ($0.text, $1) })")
        XCTAssertEqual(c.outcome?.regions.count, 1)
        XCTAssertTrue(c.detectedButUnredacted.isEmpty, "a kept region is not a leftover")
        XCTAssertTrue(c.residualWarnings.isEmpty)
        let line = AnonConsole.textDetectionLine(report: c)
        XCTAssertTrue(line.contains("1 selected for redaction; 1 kept"), line)
        let after = try TextRegionDetector().detect(in: DICOMFile.read(from: c.data)).map { $0.text.uppercased() }
        XCTAssertFalse(after.contains { $0.contains("SMITH") }, "\(after)")
        XCTAssertTrue(after.contains { $0.contains("CM") }, "clinical label must survive: \(after)")

        let a = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(cleanPixelData: true, detectText: .all), dryRun: false)
        XCTAssertEqual(a.outcome?.regions.count, 2)
        XCTAssertTrue(try TextRegionDetector().detect(in: DICOMFile.read(from: a.data)).isEmpty)

        // Dry-run table shows both verdicts; audit lines never carry the string.
        let table = AnonConsole.pixelPlanTable(report: c, showText: true)
        XCTAssertTrue(table.contains("verdict=keep"), table)
        XCTAssertTrue(table.contains("verdict=redact"), table)
        for l in c.auditLines {
            XCTAssertFalse(l.contains("SMITH"), l)
            XCTAssertTrue(l.contains("verdict="), l)
        }
    }

    /// Classify harvests the ORIGINAL header: a name that is only PHI because the header
    /// says so is redacted; the same word with a different header is uncertain → still redacted.
    func testClassifyUsesTheFilesOwnHeaderTerms() throws {
        let data = try twoLineImage(top: "Patient SMITH", bottom: "R")
        let report = try PixelCleaningWorkflow().run(
            fileData: data, options: Options(detectText: .classify), dryRun: false)
        let byText = Dictionary(uniqueKeysWithValues: zip(report.detections.map { $0.text.uppercased() }, report.verdicts))
        XCTAssertTrue(byText.first { $0.key.contains("SMITH") }?.value.isRedact ?? false)
        XCTAssertTrue(byText.first { $0.key.contains("SMITH") }?.value.reason.contains("identifier") ?? false, "\(byText)")
        XCTAssertFalse(byText["R"]?.isRedact ?? true, "\(byText)")
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

    // MARK: Phase 4 — replace style

    /// Pixels and header tell ONE story: the burned name/ID/date are replaced with the
    /// header engine's own values for the same file, dates only under --shift-dates.
    func testReplaceStyleUsesTheHeaderEnginesOwnValues() throws {
        let data = try twoLineImage(top: "SMITH JOHN", bottom: "R 10 cm")
        let file = try DICOMFile.read(from: data)
        // The header engine, previewed the way the CLI does it (legacy basic profile,
        // shifted dates): name → ANONYMOUS, ID → SHA-256 pseudonym, DOB → +30 days.
        let header = try Anonymizer(profile: .basic, shiftDates: 30).anonymize(file: file, filePath: "preview").0.dataSet
        let mapping = PixelCleaningWorkflow.ReplacementMapping.derive(original: file.dataSet, deidentified: header)
        XCTAssertEqual(mapping.values[.patientName], "ANONYMOUS")
        XCTAssertEqual(mapping.values[.patientID]?.count, 32, "\(String(describing: mapping.values[.patientID]))")
        XCTAssertEqual(mapping.values[.patientBirthDate], "1962-01-02", "19611203 + 30 days, rendered ISO")

        // PS3.15 Basic zeroes name and ID: there the mapping honestly has nothing.
        let ps315 = Anonymizer(profile: .basic).deidentify(file: file, options: .basic).0.dataSet
        let strict = PixelCleaningWorkflow.ReplacementMapping.derive(original: file.dataSet, deidentified: ps315)
        XCTAssertNil(strict.values[.patientName])
        XCTAssertNil(strict.values[.patientID])

        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(cleanPixelData: true, detectText: .classify,
                             style: .replace(fallback: "REDACTED"), replacementMapping: mapping),
            dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.regions.count, 1, "the clinical label is kept, not replaced")
        let drawn = try XCTUnwrap(outcome.replacements.values.first)
        XCTAssertEqual(drawn, "ANONYMOUS", "the header's own value")
        XCTAssertTrue(outcome.replacementFallbackNotes.isEmpty)

        // Detection oracle: the output reads as the replacement and never the original.
        let after = try TextRegionDetector().detect(in: DICOMFile.read(from: report.data)).map { $0.text.uppercased() }
        XCTAssertTrue(after.contains { $0.contains("ANONYMOUS") }, "\(after)")
        XCTAssertFalse(after.contains { $0.contains("SMITH") || $0.contains("0012345") }, "\(after)")
        XCTAssertTrue(after.contains { $0.contains("CM") }, "\(after)")
    }

    /// If the header policy removes dates (no --shift-dates), a burned date is blanked/
    /// labelled — pixels never retain what the header dropped. Uncertain text is never
    /// replaced.
    func testReplaceFallsBackWhenTheHeaderRemovesTheAttributeOrTheTextIsUncertain() throws {
        let data = try twoLineImage(top: "DOB 12/03/1961", bottom: "Zebra 77")
        let file = try DICOMFile.read(from: data)
        // No --shift-dates: the legacy engine REMOVES dates.
        let header = try Anonymizer(profile: .basic).anonymize(file: file, filePath: "preview").0.dataSet
        let mapping = PixelCleaningWorkflow.ReplacementMapping.derive(original: file.dataSet, deidentified: header)
        XCTAssertNil(mapping.values[.patientBirthDate], "a zeroed date has no truthful replacement")
        XCTAssertEqual(mapping.values[.patientName], "ANONYMOUS")

        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(cleanPixelData: true, detectText: .classify,
                             style: .replace(fallback: "REDACTED"), replacementMapping: mapping),
            dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertEqual(outcome.regions.count, 2)
        XCTAssertTrue(outcome.replacements.isEmpty, "nothing truthful to draw: \(outcome.replacements)")
        XCTAssertEqual(outcome.replacementFallbackNotes.count, 2)
        let notes = outcome.replacementFallbackNotes.values.joined(separator: " | ")
        XCTAssertTrue(notes.contains("header policy removed"), notes)
        XCTAssertTrue(notes.contains("uncertain"), notes)
        let after = try TextRegionDetector().detect(in: DICOMFile.read(from: report.data)).map { $0.text.uppercased() }
        XCTAssertFalse(after.contains { $0.contains("1961") || $0.contains("ZEBRA") }, "\(after)")
        XCTAssertTrue(after.allSatisfy { $0.contains("REDACTED") }, "\(after)")
        for l in report.auditLines { XCTAssertFalse(l.contains("1961"), l) }
    }

    func testReplaceInAllModeNeverInventsValues() throws {
        let data = try twoLineImage(top: "SMITH JOHN", bottom: "R")
        let report = try PixelCleaningWorkflow().run(
            fileData: data,
            options: Options(cleanPixelData: true, detectText: .all, style: .replace(fallback: "REDACTED"),
                             replacementMapping: .init(values: [.patientName: "ANONYMOUS"])),
            dryRun: false)
        let outcome = try XCTUnwrap(report.outcome)
        XCTAssertTrue(outcome.replacements.isEmpty, "all mode has no classified matches")
        XCTAssertEqual(outcome.replacementFallbackNotes.count, outcome.regions.count)
    }

    // MARK: Phase 4 — concatenations

    private func concatenationPart(text: String, uid: String, number: Int, total: Int) throws -> Data {
        let data = try bannerImage(text: text, frames: 2)
        var ds = try DICOMFile.read(from: data).dataSet
        ds.setString(uid, for: .concatenationUID, vr: .UI)
        ds.setUInt16(UInt16(number), for: .inConcatenationNumber)
        ds.setUInt16(UInt16(total), for: .inConcatenationTotalNumber)
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        return try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    func testSinglePartWarnsThatCoverageIsIncompleteOnlyWhenOCRRuns() throws {
        let part = try concatenationPart(text: "SMITH JOHN", uid: "1.2.3.9", number: 1, total: 2)
        let withOCR = try PixelCleaningWorkflow().run(
            fileData: part, options: Options(cleanPixelData: true, detectText: .all), dryRun: false)
        XCTAssertEqual(withOCR.warnings.count, 1)
        XCTAssertTrue(withOCR.warnings[0].contains("part 1 of 2") && withOCR.warnings[0].contains("analyzed alone"), withOCR.warnings[0])
        XCTAssertTrue(withOCR.residualWarnings.isEmpty, "a coverage note must never refuse")
        XCTAssertNotNil(withOCR.outcome, "cleaning still happens")

        let noOCR = try PixelCleaningWorkflow().run(
            fileData: part, options: Options(explicitRegions: [Region(x: 0, y: 0, width: 512, height: 60)]), dryRun: false)
        XCTAssertTrue(noOCR.warnings.isEmpty, "no OCR claim, no OCR coverage caveat")

        let swept = try PixelCleaningWorkflow().run(
            fileData: part, options: Options(cleanPixelData: true, detectText: .all, concatenationAnalyzedCompletely: true), dryRun: false)
        XCTAssertTrue(swept.warnings.isEmpty)
    }

    /// Text found only in part 2 must be blanked in part 1 as well (§4.4).
    func testConcatenationSweepUnionsRegionsAcrossParts() throws {
        let uid = "1.2.3.10"
        let part1 = try concatenationPart(text: "", uid: uid, number: 1, total: 2)          // clean-looking
        let part2 = try concatenationPart(text: "DOE JANE 0012345", uid: uid, number: 2, total: 2)
        let wf = PixelCleaningWorkflow()
        var sweep = PixelCleaningWorkflow.ConcatenationSweep()
        for data in [part1, part2] {
            let (info, regions) = try wf.sweep(fileData: data, options: Options(detectText: .all))
            sweep.add(try XCTUnwrap(info), regions: regions)
        }
        XCTAssertTrue(sweep.isComplete(uid))
        XCTAssertFalse(sweep.regions(for: uid).isEmpty)

        // Part 1 alone would be nothingToDo; with the sweep it gets part 2's regions.
        let alone = try wf.run(fileData: part1, options: Options(cleanPixelData: true, detectText: .all), dryRun: false)
        XCTAssertNil(alone.outcome)
        let options = Options(cleanPixelData: true, detectText: .all,
                              presetDetectedRegions: sweep.regions(for: uid), concatenationAnalyzedCompletely: true)
        let r1 = try wf.run(fileData: part1, options: options, dryRun: false)
        let o1 = try XCTUnwrap(r1.outcome)
        XCTAssertEqual(o1.basis, .textDetection)
        XCTAssertEqual(Set(o1.regions), Set(sweep.regions(for: uid)))
        XCTAssertEqual(o1.frameCount, 2)
        XCTAssertTrue(r1.warnings.isEmpty)
        let r2 = try wf.run(fileData: part2, options: options, dryRun: false)
        XCTAssertEqual(Set(try XCTUnwrap(r2.outcome).regions), Set(sweep.regions(for: uid)))
        XCTAssertTrue(try TextRegionDetector().detect(in: DICOMFile.read(from: r2.data), allFrames: true).isEmpty)
    }

    func testSweepCompletenessNeedsEveryDeclaredPart() {
        var sweep = PixelCleaningWorkflow.ConcatenationSweep()
        let a = PixelCleaningWorkflow.ConcatenationInfo(uid: "u", number: 1, total: 3)
        sweep.add(a, regions: [Region(x: 0, y: 0, width: 1, height: 1)])
        XCTAssertFalse(sweep.isComplete("u"))
        sweep.add(PixelCleaningWorkflow.ConcatenationInfo(uid: "u", number: 3, total: 3), regions: [])
        XCTAssertFalse(sweep.isComplete("u"), "part 2 missing")
        sweep.add(PixelCleaningWorkflow.ConcatenationInfo(uid: "u", number: 2, total: 3), regions: [Region(x: 0, y: 0, width: 1, height: 1)])
        XCTAssertTrue(sweep.isComplete("u"))
        XCTAssertEqual(sweep.regions(for: "u").count, 1, "duplicates collapse")
        XCTAssertFalse(sweep.isComplete("other"))
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
