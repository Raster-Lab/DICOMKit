import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// Pixel-redaction (PS3.15 Clean Pixel Data Option) tests.
///
/// **What these tests can and cannot prove.** They pin *mechanism*: that blanked pixels
/// hold the fill value, that every frame is covered, that pixels outside the region are
/// byte-identical, and that code 113101 is recorded only when pixels really changed.
/// They cannot prove *safety* — "no PHI remains" is not a checkable identity, and a
/// correctly-executed mask over the wrong region passes every assertion here while
/// leaving the image identifiable. Region correctness is a human judgement; these
/// tests guard the machine.
final class PixelRedactionTests: XCTestCase {

    // MARK: - Fixtures

    /// An 8-bit single-frame image whose every pixel is 200, so any blanked pixel is
    /// unambiguous.
    private func imageDataSet(
        rows: Int = 20, columns: Int = 10, frames: Int = 1, fill: UInt8 = 200
    ) -> DataSet {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.6.1", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        if frames > 1 { ds.setString("\(frames)", for: .numberOfFrames, vr: .IS) }
        let pixels = Data(repeating: fill, count: rows * columns * frames)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
        return ds
    }

    private func fileBytes(_ ds: DataSet) throws -> Data {
        var meta = DataSet()
        meta.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        return try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    private func pixels(of data: Data) throws -> Data {
        let file = try DICOMFile.read(from: data)
        return try XCTUnwrap(file.dataSet[.pixelData]?.valueData)
    }

    // MARK: - Mechanism: the four checkable facts

    func testBlankedPixelsHoldTheFillValueAndTheRestIsUntouched() throws {
        let ds = imageDataSet(rows: 20, columns: 10)
        let original = try fileBytes(ds)

        // Blank the top 4 rows.
        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 10, height: 4)], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: original, plan: plan))

        let before = try pixels(of: original)
        let after = try pixels(of: out)
        XCTAssertEqual(before.count, after.count, "masking must not resize the image")

        for i in 0..<after.count {
            let row = i / 10
            if row < 4 {
                XCTAssertEqual(after[i], 0, "pixel in the blanked band must be the fill value")
            } else {
                XCTAssertEqual(after[i], before[i],
                    "pixel outside the region must be byte-identical to the original")
            }
        }
        XCTAssertEqual(outcome.basis, .explicit)
    }

    func testEveryFrameIsBlankedNotJustTheFirst() throws {
        let frames = 5
        let ds = imageDataSet(rows: 8, columns: 8, frames: frames)
        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 8, height: 2)], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan))

        XCTAssertEqual(outcome.frameCount, frames)
        let after = try pixels(of: out)
        let frameSamples = 8 * 8
        for frame in 0..<frames {
            for i in 0..<(8 * 2) {          // the 2 blanked rows of this frame
                XCTAssertEqual(after[frame * frameSamples + i], 0,
                    "frame \(frame) must be blanked too — a missed frame is a leak")
            }
        }
    }

    func testNonZeroFillValueIsHonoured() throws {
        let ds = imageDataSet(rows: 6, columns: 6)
        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 6, height: 2)], basis: .explicit))
        let (out, _) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan, fillValue: 255))
        let after = try pixels(of: out)
        XCTAssertEqual(after[0], 255, "explicit fill value must be used, not black")
    }

    // MARK: - Attestation is earned

    func testAttestationRecordedOnlyWhenPixelsWereBlanked() throws {
        let ds = imageDataSet(rows: 10, columns: 10)
        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 10, height: 3)], basis: .explicit))
        let (out, _) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan))

        let result = try DICOMFile.read(from: out).dataSet
        XCTAssertEqual(result.string(for: .burnedInAnnotation), "NO",
            "PS3.15 E.3 requires Burned In Annotation = NO after cleaning")

        let items = try XCTUnwrap(
            result.sequence(for: Tag(group: 0x0012, element: 0x0064)),
            "De-identification Method Code Sequence must be present")
        let codes = items.compactMap {
            DataSet(elements: $0.allElements).string(for: Tag(group: 0x0008, element: 0x0100))
        }
        XCTAssertTrue(codes.contains("113101"), "must record DCM 113101 Clean Pixel Data Option")
    }

    /// The `nothingToDo` path must not stamp an attestation — that would be the same
    /// false claim the (0012,0062) guard prevents.
    func testNothingToDoWritesNoAttestation() throws {
        let redactor = PixelRedactor()
        let result = try redactor.redact(
            fileData: try fileBytes(imageDataSet()),
            plan: PixelRedactionPlan(decision: .nothingToDo))
        XCTAssertNil(result, "no pixel work → no output, so no 113101 can be stamped")
    }

    func testUnresolvedRefusesRatherThanPassingThrough() throws {
        let plan = PixelRedactionPlan(decision: .unresolved(reason: "Burned In Annotation is YES."))
        XCTAssertThrowsError(
            try PixelRedactor().redact(fileData: try fileBytes(imageDataSet()), plan: plan)
        ) { error in
            guard case PixelRedactionError.unresolvedRegion = error else {
                return XCTFail("expected unresolvedRegion, got \(error)")
            }
        }
    }

    // MARK: - Region planning

    func testExplicitRegionsWinOverDerivation() {
        var ds = imageDataSet()
        ds.setString("XA", for: .modality, vr: .CS)   // no template, no declared region
        let plan = PixelRedactionPlan.plan(
            for: ds, explicitRegions: [.init(x: 1, y: 2, width: 3, height: 4)])
        guard case .redact(let regions, let basis) = plan.decision else {
            return XCTFail("expected redact")
        }
        XCTAssertEqual(basis, .explicit, "a human instruction remains the recorded basis")
        XCTAssertEqual(regions[0].x, 1, "the explicit rectangle comes first")
        // XA matches no template and declares no scan region, so nothing is unioned
        // onto the explicit rectangle here.
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(plan.sources.map(\.basis), [.explicit])
    }

    /// Principle: region sources UNION, never override. An explicit rectangle on a
    /// device with a template gets the template band as well — blanking more is the
    /// safe direction, and a false negative leaks PHI.
    func testExplicitAndTemplateRegionsAreUnioned() {
        var ds = imageDataSet(rows: 600, columns: 800)
        ds.setString("US", for: .modality, vr: .CS)
        ds.setString("GE MEDICAL SYSTEMS", for: .manufacturer, vr: .LO)
        ds.setString("LOGIQE9", for: Tag(group: 0x0008, element: 0x1090), vr: .LO)
        let plan = PixelRedactionPlan.plan(
            for: ds, explicitRegions: [.init(x: 1, y: 2, width: 3, height: 4)])
        guard case .redact(let regions, let basis) = plan.decision else {
            return XCTFail("expected redact")
        }
        XCTAssertEqual(basis, .explicit)
        XCTAssertEqual(plan.sources.map(\.basis), [.explicit, .deviceTemplate])
        XCTAssertTrue(regions.contains(.init(x: 1, y: 2, width: 3, height: 4)))
        XCTAssertTrue(regions.contains { $0.y == 0 && $0.width == 800 && $0.height == 60 },
            "the template band must survive alongside the explicit rectangle")
    }

    /// OCR regions are unioned onto whatever the deterministic strategies produced and
    /// never shrink them; duplicates collapse.
    func testDetectedRegionsAreUnionedOntoDeterministicSources() {
        var ds = imageDataSet(rows: 600, columns: 800)
        ds.setString("US", for: .modality, vr: .CS)
        ds.setString("GE MEDICAL SYSTEMS", for: .manufacturer, vr: .LO)
        ds.setString("LOGIQE9", for: Tag(group: 0x0008, element: 0x1090), vr: .LO)
        let band = PixelRedactionPlan.Region(x: 0, y: 0, width: 800, height: 60)
        let ocr = PixelRedactionPlan.Region(x: 10, y: 500, width: 100, height: 20)
        let plan = PixelRedactionPlan.plan(for: ds, detectedRegions: [ocr, band, ocr])
        guard case .redact(let regions, let basis) = plan.decision else {
            return XCTFail("expected redact")
        }
        XCTAssertEqual(basis, .deviceTemplate, "the deterministic source stays primary")
        XCTAssertEqual(plan.sources.map(\.basis), [.deviceTemplate, .textDetection])
        XCTAssertEqual(regions.filter { $0 == band }.count, 1, "duplicates collapse")
        XCTAssertTrue(regions.contains(ocr))
    }

    /// OCR alone (nothing declared, no template) still resolves — this is the blind
    /// spot text detection closes.
    func testDetectedRegionsAloneResolveAnOtherwiseCleanLookingImage() throws {
        var ds = imageDataSet(rows: 20, columns: 10)
        ds.setString("XA", for: .modality, vr: .CS)
        let ocr = PixelRedactionPlan.Region(x: 0, y: 0, width: 10, height: 3)
        let plan = PixelRedactionPlan.plan(for: ds, detectedRegions: [ocr])
        guard case .redact(let regions, let basis) = plan.decision else {
            return XCTFail("expected redact")
        }
        XCTAssertEqual(basis, .textDetection)
        XCTAssertEqual(regions, [ocr])

        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan))
        XCTAssertEqual(outcome.basis, .textDetection)
        XCTAssertTrue(outcome.note.contains("OCR text detection"), outcome.note)
        XCTAssertFalse(outcome.note.lowercased().contains("clean"),
            "the note must not claim the image is clean")
        let after = try pixels(of: out)
        XCTAssertEqual(after[0], 0)
        XCTAssertEqual(after[30], 200, "row 3 is outside the OCR rectangle")
    }

    /// The fail-safe strategy: blank everything outside the vendor-declared scan area.
    func testKeepRegionInversionBlanksOutsideDeclaredUltrasoundRegion() {
        var ds = imageDataSet(rows: 100, columns: 100)
        ds.setString("US", for: .modality, vr: .CS)
        // Declared scan area: x 10..90, y 20..95 → the top 20 rows (the banner) is outside.
        let item = SequenceItem(elements: [
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x6018), value: 10),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601A), value: 20),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601C), value: 90),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601E), value: 95),
        ])
        ds.setSequence([item], for: Tag(group: 0x0018, element: 0x6011))

        let plan = PixelRedactionPlan.plan(for: ds)
        guard case .redact(let regions, let basis) = plan.decision else {
            return XCTFail("expected redact, got \(plan.decision)")
        }
        XCTAssertEqual(basis, .keepRegionInversion)
        // The top band must be present — that is where the banner lives.
        XCTAssertTrue(regions.contains { $0.y == 0 && $0.height == 20 },
            "must blank the band above the declared scan area")
        // Nothing may intrude into the declared clinical area.
        for r in regions {
            let intrudes = r.x < 90 && r.x + r.width > 10 && r.y < 95 && r.y + r.height > 20
            XCTAssertFalse(intrudes, "region \(r) overlaps the declared clinical area")
        }
    }

    /// A declaration covering the whole frame yields nothing to blank; that must fall
    /// through to other strategies rather than reporting a clean image.
    func testFullFrameDeclarationFallsThroughInsteadOfClaimingClean() {
        var ds = imageDataSet(rows: 50, columns: 50)
        ds.setString("US", for: .modality, vr: .CS)
        ds.setString("GE MEDICAL SYSTEMS", for: .manufacturer, vr: .LO)
        let item = SequenceItem(elements: [
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x6018), value: 0),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601A), value: 0),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601C), value: 50),
            DataElement.uint32(tag: Tag(group: 0x0018, element: 0x601E), value: 50),
        ])
        ds.setSequence([item], for: Tag(group: 0x0018, element: 0x6011))

        guard case .redact(_, let basis) = PixelRedactionPlan.plan(for: ds).decision else {
            return XCTFail("expected a template match after inversion yielded nothing")
        }
        XCTAssertEqual(basis, .deviceTemplate, "must fall through, not claim the frame is clean")
    }

    func testDeviceTemplateMatchesUltrasoundVendor() {
        var ds = imageDataSet(rows: 600, columns: 800)
        ds.setString("US", for: .modality, vr: .CS)
        ds.setString("GE MEDICAL SYSTEMS", for: .manufacturer, vr: .LO)
        ds.setString("LOGIQE9", for: Tag(group: 0x0008, element: 0x1090), vr: .LO)

        guard case .redact(let regions, let basis) = PixelRedactionPlan.plan(for: ds).decision else {
            return XCTFail("expected a device-template match")
        }
        XCTAssertEqual(basis, .deviceTemplate)
        XCTAssertEqual(regions.first?.y, 0, "the banner band starts at the top")
        XCTAssertEqual(regions.first?.width, 800, "band spans the full width")
        XCTAssertEqual(regions.first?.height, 60, "10% of 600 rows")
    }

    /// An unmatched device with declared burned-in text must be *unresolved*, never a
    /// silent pass-through — this is the CTP default this design rejects.
    func testUnknownDeviceWithBurnedInTextIsUnresolvedNotSilentlyClean() {
        var ds = imageDataSet()
        ds.setString("XA", for: .modality, vr: .CS)          // no template for XA
        ds.setString("ACME", for: .manufacturer, vr: .LO)
        ds.setString("YES", for: .burnedInAnnotation, vr: .CS)

        guard case .unresolved = PixelRedactionPlan.plan(for: ds).decision else {
            return XCTFail("an unknown device declaring burned-in text must not pass as clean")
        }
    }

    func testCleanImageWithNoDeclarationNeedsNoWork() {
        var ds = imageDataSet()
        ds.setString("MR", for: .modality, vr: .CS)
        ds.setString("NO", for: .burnedInAnnotation, vr: .CS)
        guard case .nothingToDo = PixelRedactionPlan.plan(for: ds).decision else {
            return XCTFail("a clean MR should need no pixel work")
        }
    }

    // MARK: - Redaction styles (blank-then-draw)

    private func styleTestRegionPixels(_ out: Data, region: PixelRedactionPlan.Region, columns: Int, frame: Int = 0, frameSize: Int) throws -> [UInt8] {
        let px = try pixels(of: out)
        var v: [UInt8] = []
        for y in region.y..<(region.y + region.height) {
            for x in region.x..<(region.x + region.width) {
                v.append(px[frame * frameSize + y * columns + x])
            }
        }
        return v
    }

    func testLabelStyleBlanksThenStampsOnEveryFrame() throws {
        guard RedactionLabelRenderer.isAvailable else { throw XCTSkip("no glyph rasterizer") }
        let ds = imageDataSet(rows: 60, columns: 200, frames: 3)
        let region = PixelRedactionPlan.Region(x: 10, y: 5, width: 180, height: 40)
        let plan = PixelRedactionPlan(decision: .redact(regions: [region], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan, style: .label("REDACTED")))
        XCTAssertEqual(outcome.style, .label("REDACTED"))
        XCTAssertTrue(outcome.labelFallbackRegions.isEmpty)
        for frame in 0..<3 {
            let values = try styleTestRegionPixels(out, region: region, columns: 200, frame: frame, frameSize: 60 * 200)
            // Only the fill (0) and the contrasting foreground (255) may appear: the
            // original 200s are gone — blank-then-draw, never draw-over.
            XCTAssertTrue(Set(values).isSubset(of: [0, 255]), "frame \(frame): \(Set(values))")
            XCTAssertTrue(values.contains(255), "frame \(frame) must carry the stamp")
            XCTAssertTrue(values.contains(0), "frame \(frame) must be blanked around the glyphs")
        }
        // Outside the region: untouched.
        let px = try pixels(of: out)
        XCTAssertEqual(px[0], 200)
        XCTAssertEqual(px[59 * 200 + 199], 200)
        // Attestation is earned in every style.
        let file = try DICOMFile.read(from: out)
        XCTAssertEqual(file.dataSet.string(for: .burnedInAnnotation)?.trimmingCharacters(in: .whitespaces), "NO")
    }

    func testLabelStyleFallsBackToBlankOnTooSmallRegionsWithAnAuditNote() throws {
        guard RedactionLabelRenderer.isAvailable else { throw XCTSkip("no glyph rasterizer") }
        let ds = imageDataSet(rows: 20, columns: 10)
        let tiny = PixelRedactionPlan.Region(x: 0, y: 0, width: 10, height: 4)
        let plan = PixelRedactionPlan(decision: .redact(regions: [tiny], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan, style: .label("REDACTED")))
        XCTAssertEqual(outcome.labelFallbackRegions, [tiny])
        let values = try styleTestRegionPixels(out, region: tiny, columns: 10, frameSize: 200)
        XCTAssertEqual(Set(values), [0], "a too-small region is blanked only")
        let lines = AnonConsole.pixelRedactionLines(outcome: outcome)
        XCTAssertTrue(lines.contains("too small for label"), lines)
    }

    func testLabelForegroundContrastsWithTheFillAtTheRealBitDepth() {
        var ds = imageDataSet()
        XCTAssertEqual(PixelRedactor.contrastingStoredValue(to: 0, in: ds), 255)
        XCTAssertEqual(PixelRedactor.contrastingStoredValue(to: 255, in: ds), 0)
        ds.setUInt16(16, for: .bitsAllocated); ds.setUInt16(12, for: .bitsStored)
        XCTAssertEqual(PixelRedactor.contrastingStoredValue(to: 0, in: ds), 4095)
        ds.setUInt16(1, for: .pixelRepresentation)
        XCTAssertEqual(PixelRedactor.contrastingStoredValue(to: -2048, in: ds), 2047)
        XCTAssertEqual(PixelRedactor.contrastingStoredValue(to: 0, in: ds), -2048)
    }

    func testStyleParsing() {
        XCTAssertEqual(PixelRedactor.Style.parse("blank", label: nil), .blank)
        XCTAssertEqual(PixelRedactor.Style.parse("label", label: nil), .label("REDACTED"))
        XCTAssertEqual(PixelRedactor.Style.parse("LABEL", label: "PHI REMOVED"), .label("PHI REMOVED"))
        XCTAssertEqual(PixelRedactor.Style.parse("replace", label: nil), .replace(fallback: "REDACTED"))
        XCTAssertNil(PixelRedactor.Style.parse("fuzzy", label: nil))
    }

    func testReplaceStyleDrawsValuesOnlyWhereSuppliedAndFallsBackAudited() throws {
        guard RedactionLabelRenderer.isAvailable else { throw XCTSkip("no glyph rasterizer") }
        let ds = imageDataSet(rows: 120, columns: 240, frames: 2)
        let named = PixelRedactionPlan.Region(x: 10, y: 5, width: 220, height: 40)
        let unknown = PixelRedactionPlan.Region(x: 10, y: 60, width: 220, height: 40)
        let tiny = PixelRedactionPlan.Region(x: 0, y: 110, width: 240, height: 5)
        let plan = PixelRedactionPlan(decision: .redact(regions: [named, unknown, tiny], basis: .textDetection))
        let (out, outcome) = try XCTUnwrap(PixelRedactor().redact(
            fileData: try fileBytes(ds), plan: plan, style: .replace(fallback: "REDACTED"),
            replacements: [named: .value("ANONYMOUS"), unknown: .unavailable(reason: "uncertain region")]))
        XCTAssertEqual(outcome.replacements, [named: "ANONYMOUS"])
        XCTAssertEqual(outcome.replacementFallbackNotes[unknown], "uncertain region")
        XCTAssertTrue(outcome.replacementFallbackNotes[tiny]?.contains("too small") ?? false, "\(outcome.replacementFallbackNotes)")
        XCTAssertEqual(outcome.labelFallbackRegions, [tiny])
        // Every region is blanked first: no original 200s survive inside any of them.
        for (r, expectInk) in [(named, true), (unknown, true), (tiny, false)] {
            for frame in 0..<2 {
                let values = Set(try styleTestRegionPixels(out, region: r, columns: 240, frame: frame, frameSize: 120 * 240))
                XCTAssertTrue(values.isSubset(of: [0, 255]), "\(r) frame \(frame): \(values)")
                XCTAssertEqual(values.contains(255), expectInk, "\(r) frame \(frame)")
            }
        }
        let lines = AnonConsole.pixelRedactionLines(outcome: outcome)
        XCTAssertTrue(lines.contains("replaced with header value \"ANONYMOUS\""), lines)
        XCTAssertTrue(lines.contains("labelled \"REDACTED\" (uncertain region)"), lines)
    }

    func testGlyphMaskGeometry() {
        guard RedactionLabelRenderer.isAvailable else { return }
        XCTAssertNil(RedactionLabelRenderer.glyphMask(text: "REDACTED", width: 20, height: 10), "too narrow")
        XCTAssertNil(RedactionLabelRenderer.glyphMask(text: "REDACTED", width: 200, height: 6), "too short")
        XCTAssertNil(RedactionLabelRenderer.glyphMask(text: "", width: 200, height: 40))
        let mask = RedactionLabelRenderer.glyphMask(text: "REDACTED", width: 200, height: 40)
        XCTAssertEqual(mask?.count, 200 * 40)
        // Ink is centred: present in the middle rows, absent in the top and bottom rows.
        let m = mask!
        XCTAssertTrue((0..<200).contains { m[20 * 200 + $0] > 127 })
        XCTAssertFalse((0..<200).contains { m[$0] > 127 })
        XCTAssertFalse((0..<200).contains { m[39 * 200 + $0] > 127 })
        // Ink is inset horizontally.
        XCTAssertFalse((0..<40).contains { m[$0 * 200] > 127 })
    }

    // MARK: - Forgotten surfaces

    func testIconImageSequenceIsRemoved() throws {
        var ds = imageDataSet(rows: 10, columns: 10)
        // An icon derived before cleaning still shows the identifiers.
        let icon = SequenceItem(elements: [
            DataElement.data(tag: .pixelData, vr: .OB, data: Data(repeating: 7, count: 4))
        ])
        ds.setSequence([icon], for: .iconImageSequence)

        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 10, height: 2)], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan))

        XCTAssertTrue(outcome.removedIconImage)
        XCTAssertNil(try DICOMFile.read(from: out).dataSet[.iconImageSequence],
            "a stale icon is a classic leak — it must not survive cleaning")
    }

    func testOverlayPlanesAreRemoved() throws {
        var ds = imageDataSet(rows: 10, columns: 10)
        let overlayData = Tag(group: 0x6000, element: 0x3000)
        ds[overlayData] = DataElement.data(tag: overlayData, vr: .OW,
                                           data: Data([0xFF, 0x00]))
        ds.setUInt16(10, for: Tag(group: 0x6000, element: 0x0010))

        let plan = PixelRedactionPlan(decision: .redact(
            regions: [.init(x: 0, y: 0, width: 10, height: 2)], basis: .explicit))
        let (out, outcome) = try XCTUnwrap(
            PixelRedactor().redact(fileData: try fileBytes(ds), plan: plan))

        XCTAssertTrue(outcome.removedOverlays)
        let result = try DICOMFile.read(from: out).dataSet
        XCTAssertTrue(result.tags.allSatisfy { $0.group != 0x6000 },
            "overlay planes are burned in by renderers, so they must go too")
    }
}
