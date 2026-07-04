// DiffRoundTripTests.swift
// Round-trip oracle tests for the `dicom-diff` tool.
// Exercises the DICOMKit comparison engine (DICOMComparer / ComparisonResult)
// and renderer (ComparisonReport) directly — never spawns the CLI.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class DiffRoundTripTests: XCTestCase {

    // MARK: - Private helpers (do NOT collide with shared free functions)

    /// Build a comparer with sensible metadata-only defaults, overridable per case.
    private func comparer(
        _ f1: DICOMFile,
        _ f2: DICOMFile,
        ignore: Set<Tag> = [],
        ignorePrivate: Bool = false,
        comparePixels: Bool = false,
        tolerance: Double = 0.0
    ) -> DICOMComparer {
        DICOMComparer(
            file1: f1,
            file2: f2,
            tagsToIgnore: ignore,
            ignorePrivate: ignorePrivate,
            comparePixels: comparePixels,
            pixelTolerance: tolerance,
            showIdentical: false
        )
    }

    /// Return a copy of a file with one string element set/overwritten in its dataSet.
    private func withString(
        _ file: DICOMFile, _ value: String, for tag: Tag, vr: VR
    ) -> DICOMFile {
        var ds = file.dataSet
        ds.setString(value, for: tag, vr: vr)
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
    }

    /// Return a copy of a file with one element removed from its dataSet.
    private func removing(_ file: DICOMFile, _ tag: Tag) -> DICOMFile {
        var ds = file.dataSet
        ds[tag] = nil
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
    }

    // MARK: - Tests

    // Oracle: diff(A, A) has zero differences and hasDifferences == false.
    func testIdenticalFilesZeroDiffs() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let result = try comparer(file, file).compare()
        XCTAssertEqual(result.differenceCount, 0)
        XCTAssertTrue(result.onlyInFile1.isEmpty)
        XCTAssertTrue(result.onlyInFile2.isEmpty)
        XCTAssertTrue(result.modified.isEmpty)
        XCTAssertFalse(result.hasDifferences)
    }

    // Oracle: a single changed tag yields exactly one modification, naming that tag.
    func testSingleTagChangedOneModification() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Original", for: .patientName, vr: .PN)
        let b = withString(a, "Changed", for: .patientName, vr: .PN)
        let result = try comparer(a, b).compare()

        XCTAssertEqual(result.differenceCount, 1)
        XCTAssertEqual(result.modified.count, 1)
        XCTAssertTrue(result.onlyInFile1.isEmpty)
        XCTAssertTrue(result.onlyInFile2.isEmpty)
        let mod = try XCTUnwrap(result.modified.first)
        XCTAssertEqual(mod.tag, .patientName)
        XCTAssertEqual(mod.value1.stringValue, "Original")
        XCTAssertEqual(mod.value2.stringValue, "Changed")
    }

    // Oracle: a tag present only in file 2 is reported as "only in file 2" (added).
    func testAddedTagReportedInFile2Only() throws {
        let a = makeGrayscale8(rows: 8, cols: 8)
        XCTAssertNil(a.dataSet[.studyDescription], "fixture must not already carry StudyDescription")
        let b = withString(a, "Round Trip Study", for: .studyDescription, vr: .LO)

        let result = try comparer(a, b).compare()
        XCTAssertEqual(result.differenceCount, 1)
        XCTAssertTrue(result.modified.isEmpty)
        XCTAssertTrue(result.onlyInFile1.isEmpty)
        XCTAssertEqual(result.onlyInFile2.count, 1)
        let added = try XCTUnwrap(result.onlyInFile2[.studyDescription])
        XCTAssertEqual(added.stringValue, "Round Trip Study")
    }

    // Oracle: a tag present only in file 1 is reported as "only in file 1" (removed).
    func testRemovedTagReportedInFile1Only() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Round Trip Study", for: .studyDescription, vr: .LO)
        let b = removing(a, .studyDescription)

        let result = try comparer(a, b).compare()
        XCTAssertEqual(result.differenceCount, 1)
        XCTAssertTrue(result.modified.isEmpty)
        XCTAssertTrue(result.onlyInFile2.isEmpty)
        XCTAssertEqual(result.onlyInFile1.count, 1)
        XCTAssertNotNil(result.onlyInFile1[.studyDescription])
    }

    // Oracle: hasDifferences == (differenceCount > 0 || pixelsDifferent) across paths.
    func testHasDifferencesInvariant() throws {
        // Identical, no pixel compare.
        let same = makeGrayscale8(rows: 8, cols: 8)
        let r1 = try comparer(same, same).compare()
        XCTAssertEqual(r1.hasDifferences, r1.differenceCount > 0 || r1.pixelsDifferent)

        // Metadata differs.
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "A", for: .patientName, vr: .PN)
        let b = withString(a, "B", for: .patientName, vr: .PN)
        let r2 = try comparer(a, b).compare()
        XCTAssertEqual(r2.hasDifferences, r2.differenceCount > 0 || r2.pixelsDifferent)

        // Pixels differ (comparePixels on).
        let p1 = makeGrayscale8(rows: 8, cols: 8, fillPattern: { UInt8($0 % 256) })
        let p2 = makeGrayscale8(rows: 8, cols: 8, fillPattern: { _ in 0 })
        let r3 = try comparer(p1, p2, comparePixels: true).compare()
        XCTAssertEqual(r3.hasDifferences, r3.differenceCount > 0 || r3.pixelsDifferent)
    }

    // Oracle: ignoring the sole differing tag suppresses the difference entirely.
    func testIgnoreTagSuppressesDifference() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Original", for: .patientName, vr: .PN)
        let b = withString(a, "Changed", for: .patientName, vr: .PN)

        // Baseline: one diff.
        XCTAssertEqual(try comparer(a, b).compare().differenceCount, 1)

        // Ignoring PatientName removes it.
        let ignored = try comparer(a, b, ignore: [.patientName]).compare()
        XCTAssertEqual(ignored.differenceCount, 0)
        XCTAssertTrue(ignored.modified.isEmpty)
        XCTAssertFalse(ignored.hasDifferences)
    }

    // Oracle: --ignore-private drops all odd-group (private) tag differences.
    func testIgnorePrivateSuppressesPrivateTagDiff() throws {
        let privateTag = Tag(group: 0x0009, element: 0x0010) // odd group => private
        XCTAssertTrue(privateTag.isPrivate)

        var dsA = makeGrayscale8(rows: 8, cols: 8).dataSet
        dsA.setString("PrivValA", for: privateTag, vr: .LO)
        let base = makeGrayscale8(rows: 8, cols: 8)
        let a = DICOMFile(fileMetaInformation: base.fileMetaInformation, dataSet: dsA)

        var dsB = dsA
        dsB.setString("PrivValB", for: privateTag, vr: .LO)
        let b = DICOMFile(fileMetaInformation: base.fileMetaInformation, dataSet: dsB)

        // Baseline: private tag difference is counted.
        XCTAssertEqual(try comparer(a, b).compare().differenceCount, 1)

        // With ignorePrivate: suppressed.
        let ignored = try comparer(a, b, ignorePrivate: true).compare()
        XCTAssertEqual(ignored.differenceCount, 0)
        XCTAssertFalse(ignored.hasDifferences)
    }

    // Oracle: identical pixels => pixelsCompared true, maxDifference 0, pixelsDifferent false.
    func testComparePixelsIdentical() throws {
        let file = makeGrayscale8(rows: 16, cols: 16)
        let result = try comparer(file, file, comparePixels: true).compare()
        XCTAssertTrue(result.pixelsCompared)
        let diff = try XCTUnwrap(result.pixelDifference)
        XCTAssertEqual(diff.maxDifference, 0)
        XCTAssertEqual(diff.differentPixelCount, 0)
        XCTAssertEqual(diff.totalPixels, 16 * 16)
        XCTAssertFalse(result.pixelsDifferent)
    }

    // Oracle: pixel maxDifference equals the exact max byte-level |a-b|; totalPixels == byte count.
    func testComparePixelsMaxDifferenceExact() throws {
        // File A: byte i == i%256. File B: same but every byte == 0.
        // => byte-level diff at position i is (i % 256); max over 0..255 is 255.
        let a = makeGrayscale8(rows: 16, cols: 16, fillPattern: { UInt8($0 % 256) })
        let b = makeGrayscale8(rows: 16, cols: 16, fillPattern: { _ in 0 })
        let result = try comparer(a, b, comparePixels: true).compare()

        let diff = try XCTUnwrap(result.pixelDifference)
        XCTAssertEqual(diff.maxDifference, 255)                 // max |i%256 - 0| = 255
        XCTAssertEqual(diff.totalPixels, 256)                   // 16*16 bytes
        XCTAssertEqual(diff.differentPixelCount, 255)           // only byte 0 is equal (0 vs 0)
        XCTAssertTrue(result.pixelsDifferent)
    }

    // Oracle: tolerance gates pixelsDifferent — maxDifference <= tolerance => not different.
    func testToleranceGatesPixelDifference() throws {
        // Uniform difference of exactly 5 at every byte.
        let a = makeGrayscale8(rows: 8, cols: 8, fillPattern: { _ in 5 })
        let b = makeGrayscale8(rows: 8, cols: 8, fillPattern: { _ in 0 })

        // tolerance 0 => flagged different (maxDifference 5 > 0).
        let strict = try comparer(a, b, comparePixels: true, tolerance: 0).compare()
        XCTAssertEqual(try XCTUnwrap(strict.pixelDifference).maxDifference, 5)
        XCTAssertTrue(strict.pixelsDifferent)

        // tolerance 5 => within tolerance (maxDifference 5 not > 5).
        let loose = try comparer(a, b, comparePixels: true, tolerance: 5).compare()
        XCTAssertEqual(try XCTUnwrap(loose.pixelDifference).maxDifference, 5)
        XCTAssertFalse(loose.pixelsDifferent)
    }

    // Oracle: when comparePixels is on, PixelData is excluded from the tag loop
    // (differing pixels never inflate differenceCount / modified).
    func testPixelDataExcludedFromTagLoopWhenComparingPixels() throws {
        // Metadata identical, pixels differ.
        let a = makeGrayscale8(rows: 8, cols: 8, fillPattern: { UInt8($0 % 256) })
        var dsB = a.dataSet
        dsB[.pixelData] = DataElement.data(
            tag: .pixelData, vr: .OB, data: Data(repeating: 0, count: 8 * 8))
        let b = DICOMFile(fileMetaInformation: a.fileMetaInformation, dataSet: dsB)

        let result = try comparer(a, b, comparePixels: true).compare()
        // No metadata modification; PixelData is not in modified/onlyIn maps.
        XCTAssertEqual(result.differenceCount, 0)
        XCTAssertNil(result.modified.first { $0.tag == .pixelData })
        XCTAssertNil(result.onlyInFile1[.pixelData])
        XCTAssertNil(result.onlyInFile2[.pixelData])
        // But pixels themselves are flagged different.
        XCTAssertTrue(result.pixelsDifferent)
        // And overall difference is driven purely by the pixel comparison.
        XCTAssertTrue(result.hasDifferences)
    }

    // Oracle: totalTags counts each shared/unique tag once; identical tags land in
    // .identical (not differenceCount), and totalTags == identical + differenceCount.
    func testTotalTagsPartition() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Original", for: .patientName, vr: .PN)
        let b = withString(a, "Changed", for: .patientName, vr: .PN)
        // No pixel comparison => PixelData participates as an identical tag.
        let result = try comparer(a, b).compare()

        XCTAssertEqual(result.differenceCount, 1)
        XCTAssertEqual(result.identical.count + result.differenceCount, result.totalTags)
        XCTAssertFalse(result.identical.contains(.patientName))
    }

    // Oracle: JSON render is valid JSON and always carries the diff-array keys;
    // pixelData key present iff pixels were compared.
    func testJSONRenderKeys() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Original", for: .patientName, vr: .PN)
        let b = withString(a, "Changed", for: .patientName, vr: .PN)

        // Without pixel comparison.
        let reportNoPix = ComparisonReport(
            result: try comparer(a, b).compare(),
            file1Name: "a.dcm", file2Name: "b.dcm", showIdentical: false)
        let jsonNoPix = try reportNoPix.render(format: .json)
        let objNoPix = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(jsonNoPix.utf8)) as? [String: Any])
        XCTAssertNotNil(objNoPix["onlyInFile1"])
        XCTAssertNotNil(objNoPix["onlyInFile2"])
        XCTAssertNotNil(objNoPix["modified"])
        XCTAssertNil(objNoPix["pixelData"])
        let modified = try XCTUnwrap(objNoPix["modified"] as? [[String: Any]])
        XCTAssertEqual(modified.count, 1)

        // With pixel comparison => pixelData key appears.
        let reportPix = ComparisonReport(
            result: try comparer(a, b, comparePixels: true).compare(),
            file1Name: "a.dcm", file2Name: "b.dcm", showIdentical: false)
        let jsonPix = try reportPix.render(format: .json)
        let objPix = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(jsonPix.utf8)) as? [String: Any])
        XCTAssertNotNil(objPix["pixelData"])
    }

    // Oracle: summary render reports IDENTICAL for equal files, DIFFERENT otherwise.
    func testSummaryRenderReflectsDifferences() throws {
        let same = makeGrayscale8(rows: 8, cols: 8)
        let identicalReport = ComparisonReport(
            result: try comparer(same, same).compare(),
            file1Name: "a.dcm", file2Name: "a.dcm", showIdentical: false)
        XCTAssertTrue(try identicalReport.render(format: .summary).contains("IDENTICAL"))

        let a = withString(makeGrayscale8(rows: 8, cols: 8), "A", for: .patientName, vr: .PN)
        let b = withString(a, "B", for: .patientName, vr: .PN)
        let diffReport = ComparisonReport(
            result: try comparer(a, b).compare(),
            file1Name: "a.dcm", file2Name: "b.dcm", showIdentical: false)
        XCTAssertTrue(try diffReport.render(format: .summary).contains("DIFFERENT"))
    }

    // Oracle: comparison is symmetric — swapping files swaps onlyIn maps and keeps
    // differenceCount / modified count invariant.
    func testComparisonSymmetry() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Study", for: .studyDescription, vr: .LO)
        let b = removing(a, .studyDescription) // b lacks StudyDescription

        let ab = try comparer(a, b).compare()
        let ba = try comparer(b, a).compare()

        XCTAssertEqual(ab.differenceCount, ba.differenceCount)
        XCTAssertEqual(ab.modified.count, ba.modified.count)
        // onlyInFile1 of (a,b) corresponds to onlyInFile2 of (b,a).
        XCTAssertEqual(Set(ab.onlyInFile1.keys), Set(ba.onlyInFile2.keys))
        XCTAssertEqual(Set(ab.onlyInFile2.keys), Set(ba.onlyInFile1.keys))
    }

    // Oracle (corpus realism): a real file compared with itself has zero differences,
    // even for implicit-VR / compressed / multi-frame sources.
    func testCorpusSelfCompareZeroDiffs() throws {
        for kind in [Corpus.ct, .mr, .j2kLossless, .ctMultiframe] {
            let f = try loadCorpus(kind)
            if f == nil { continue } // corpus optional in CI
            let file = try XCTUnwrap(f)
            let result = try comparer(file, file, comparePixels: true).compare()
            XCTAssertEqual(result.differenceCount, 0, "\(kind.rawValue) self-diff metadata")
            XCTAssertFalse(result.pixelsDifferent, "\(kind.rawValue) self-diff pixels")
            XCTAssertFalse(result.hasDifferences, "\(kind.rawValue) self-diff overall")
        }
    }

    // MARK: - Oracle: --format text renderer (the CLI default) reports counts + detail

    // Oracle: the text renderer (dicom-diff's default --format) carries the results
    // header, the difference/modified counts, a Modified-Tags section listing each
    // changed tag's File 1 / File 2 values, and the closing marker.
    func testTextRenderReportsCountsAndModifiedValues() throws {
        let a = withString(makeGrayscale8(rows: 8, cols: 8), "Original", for: .patientName, vr: .PN)
        let b = withString(a, "Changed", for: .patientName, vr: .PN)
        let report = ComparisonReport(
            result: try comparer(a, b).compare(),
            file1Name: "a.dcm", file2Name: "b.dcm", showIdentical: false)
        let text = try report.render(format: .text)

        XCTAssertTrue(text.contains("=== DICOM Comparison Results ==="), "missing header")
        XCTAssertTrue(text.contains("Differences found: 1"), "missing difference count")
        XCTAssertTrue(text.contains("Modified tags: 1"), "missing modified count")
        XCTAssertTrue(text.contains("--- Modified Tags ---"), "missing modified section")
        // The one modified tag lists both old and new values.
        XCTAssertTrue(text.contains("Original"), "text must show File 1 value")
        XCTAssertTrue(text.contains("Changed"), "text must show File 2 value")
        XCTAssertTrue(text.contains("=== End of Comparison ==="), "missing footer")
    }

    // Oracle: --show-identical gates the "Identical Tags" section in the text render —
    // absent when false, present (with the identical count) when true. The comparer's
    // identical set is populated regardless; only rendering is gated.
    func testTextRenderShowIdenticalTogglesIdenticalSection() throws {
        let same = makeGrayscale8(rows: 8, cols: 8)
        let result = try comparer(same, same).compare()
        XCTAssertGreaterThan(result.identical.count, 0, "self-compare must have identical tags")

        let hidden = ComparisonReport(
            result: result, file1Name: "a.dcm", file2Name: "a.dcm", showIdentical: false)
        XCTAssertFalse(try hidden.render(format: .text).contains("--- Identical Tags"),
                       "identical section must be absent when showIdentical is false")

        let shown = ComparisonReport(
            result: result, file1Name: "a.dcm", file2Name: "a.dcm", showIdentical: true)
        XCTAssertTrue(try shown.render(format: .text).contains("--- Identical Tags (\(result.identical.count)) ---"),
                      "showIdentical must render the identical-tags section with its count")
    }
}

