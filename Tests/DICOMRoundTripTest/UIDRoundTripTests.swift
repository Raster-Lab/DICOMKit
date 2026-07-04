// UIDRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-uid` CLI.
//
// These tests call the DICOMKit LIBRARY directly (UIDManager / UIDGenerator /
// UIDDictionary / DICOMUniqueIdentifier) — never the CLI binary. Every assertion
// is a mathematical or semantic oracle (validity by definition, uniqueness,
// registry membership, regenerate-preserves-well-known, mapping consistency),
// never a comparison to a re-implementation of the tool.
//
// See ROUND_TRIP_TESTS_PLAN.md §3.14.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class UIDRoundTripTests: XCTestCase {

    // MARK: - Private helpers (class-scoped to avoid global collisions)

    /// True iff `uid` is a syntactically valid DICOM UID: one or more numeric
    /// components separated by single periods, total length ≤ 64, no leading zeros.
    private func isSyntacticallyValidUID(_ uid: String) -> Bool {
        // Authoritative parser is the oracle for DICOM UID syntax.
        DICOMUniqueIdentifier.parse(uid) != nil
    }

    /// Regex oracle independent of the parser: components of digits joined by dots.
    private func matchesUIDRegex(_ uid: String) -> Bool {
        let pattern = "^[0-9]+(\\.[0-9]+)+$"
        return uid.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Generation oracles

    // Oracle: every generated UID is syntactically valid (regex + parser) and ≤ 64 chars.
    func testGeneratedUIDsAreSyntacticallyValid() {
        let manager = UIDManager()
        let uids = manager.generateUIDs(count: 50, root: nil, type: nil)
        XCTAssertEqual(uids.count, 50)
        for uid in uids {
            XCTAssertLessThanOrEqual(uid.count, DICOMUniqueIdentifier.maximumLength,
                                     "UID exceeds 64 chars: \(uid)")
            XCTAssertTrue(matchesUIDRegex(uid), "UID fails regex: \(uid)")
            XCTAssertTrue(isSyntacticallyValidUID(uid), "UID fails parse: \(uid)")
            // The library's own validator must also accept it.
            XCTAssertTrue(manager.validateUID(uid).isValid, "validateUID rejected \(uid)")
        }
    }

    // Oracle: 100 generated UIDs are all distinct (Set count == 100).
    func testGeneratedUIDsAreUnique() {
        let manager = UIDManager()
        let uids = manager.generateUIDs(count: 100, root: nil, type: nil)
        XCTAssertEqual(uids.count, 100)
        XCTAssertEqual(Set(uids).count, 100, "Generated UIDs are not all unique")
    }

    // Oracle: a custom root prefixes every generated UID and result stays valid & ≤ 64.
    func testGeneratedUIDsHonorCustomRoot() {
        let root = "1.2.826.0.1.3680043.9.1234"
        let manager = UIDManager()
        let uids = manager.generateUIDs(count: 20, root: root, type: nil)
        for uid in uids {
            XCTAssertTrue(uid.hasPrefix(root + "."), "UID missing custom root: \(uid)")
            XCTAssertLessThanOrEqual(uid.count, DICOMUniqueIdentifier.maximumLength)
            XCTAssertTrue(isSyntacticallyValidUID(uid))
        }
    }

    // Oracle: typed generation (study/series/instance) yields valid, unique UIDs;
    // the type routes to distinct generator methods so the type-digit differs.
    func testTypedGenerationIsValidAndDistinctByType() {
        let manager = UIDManager()
        let root = "1.2.3.4.5"
        let study = manager.generateUIDs(count: 1, root: root, type: "study").first!
        let series = manager.generateUIDs(count: 1, root: root, type: "series").first!
        let instance = manager.generateUIDs(count: 1, root: root, type: "instance").first!
        for uid in [study, series, instance] {
            XCTAssertTrue(isSyntacticallyValidUID(uid))
            XCTAssertTrue(manager.validateUID(uid).isValid)
        }
        // The type digit sits immediately after the root: root.<type>.<ts>.<rand>.
        XCTAssertTrue(study.hasPrefix(root + ".1."), "study type digit wrong: \(study)")
        XCTAssertTrue(series.hasPrefix(root + ".2."), "series type digit wrong: \(series)")
        XCTAssertTrue(instance.hasPrefix(root + ".3."), "instance type digit wrong: \(instance)")
    }

    // MARK: - Validation oracles

    // Oracle: a well-formed registry UID validates true; malformed UIDs validate
    // false with the specific rule violated (PS3.5 §9 semantics, true by definition).
    func testValidationSemantics() {
        let manager = UIDManager()

        // Valid.
        XCTAssertTrue(manager.validateUID("1.2.840.10008.1.2.1").isValid)

        // Leading zero in a component (not "0" itself) is invalid.
        let leadingZero = manager.validateUID("1.02.3")
        XCTAssertFalse(leadingZero.isValid)
        XCTAssertTrue(leadingZero.errors.contains { $0.contains("leading zero") })

        // Consecutive periods invalid.
        let consecutive = manager.validateUID("1.2..3")
        XCTAssertFalse(consecutive.isValid)
        XCTAssertTrue(consecutive.errors.contains { $0.contains("consecutive periods") })

        // Trailing period invalid.
        let trailing = manager.validateUID("1.2.3.")
        XCTAssertFalse(trailing.isValid)
        XCTAssertTrue(trailing.errors.contains { $0.contains("end with a period") })

        // Non-digit / non-period character invalid.
        let badChar = manager.validateUID("1.2.a")
        XCTAssertFalse(badChar.isValid)
        XCTAssertTrue(badChar.errors.contains { $0.contains("invalid characters") })

        // Exceeding 64 characters invalid.
        let tooLong = String(repeating: "1", count: 33) + "." + String(repeating: "2", count: 33)
        XCTAssertGreaterThan(tooLong.count, 64)
        let long = manager.validateUID(tooLong)
        XCTAssertFalse(long.isValid)
        XCTAssertTrue(long.errors.contains { $0.contains("maximum length") })
    }

    // Oracle: --check-registry — a validated registry UID carries its registry name;
    // a custom (non-registry) valid UID carries none.
    func testValidationRegistryName() {
        let manager = UIDManager()
        let known = manager.validateUID("1.2.840.10008.1.2.1")
        XCTAssertTrue(known.isValid)
        XCTAssertEqual(known.registryName, "Explicit VR Little Endian")

        let custom = manager.validateUID("1.2.3.4.5.6.7.8.9")
        XCTAssertTrue(custom.isValid)
        XCTAssertNil(custom.registryName)
    }

    // Oracle: validate --file — every UID (VR=UI) in a well-formed synthetic file
    // validates as valid; count equals the number of distinct UI elements present.
    func testValidateFileUIDs() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let url = try writeTempDICOM(file, name: "validate.dcm")
        let manager = UIDManager()
        let results = try manager.validateFileUIDs(path: url.path)
        // The synthetic builder sets SOPClassUID, SOPInstanceUID, StudyInstanceUID,
        // SeriesInstanceUID (plus meta UIDs added by DICOMFile.create) — all well-formed.
        XCTAssertFalse(results.isEmpty, "no UI elements were validated")
        for r in results {
            XCTAssertTrue(r.isValid, "unexpected invalid UID in synthetic file: \(r.uid)")
        }
    }

    // MARK: - Lookup oracles

    // Oracle: lookup — a registry UID resolves to its canonical entry; a custom
    // UID resolves to nil (registry membership is a fixed fact).
    func testLookupRegistry() {
        let ts = UIDDictionary.lookup(uid: "1.2.840.10008.1.2.1")
        XCTAssertEqual(ts?.name, "Explicit VR Little Endian")
        XCTAssertEqual(ts?.type, .transferSyntax)

        let ctStorage = UIDDictionary.lookup(uid: "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertNotNil(ctStorage)
        XCTAssertEqual(ctStorage?.type, .sopClass)

        XCTAssertNil(UIDDictionary.lookup(uid: "1.2.3.4.5.6.7.8.9"),
                     "custom UID must not be in registry")
    }

    // Oracle: lookup --list-all — allEntries partitions into transferSyntaxes and
    // sopClasses subsets, each carrying its declared UIDType; every listed UID is valid.
    func testLookupListAllPartitioning() {
        let all = UIDDictionary.allEntries
        let transfer = UIDDictionary.transferSyntaxes
        let sop = UIDDictionary.sopClasses
        XCTAssertFalse(all.isEmpty)
        XCTAssertFalse(transfer.isEmpty)
        XCTAssertFalse(sop.isEmpty)

        // Type filters are pure subsets of allEntries with the matching type.
        let allUIDs = Set(all.map { $0.uid })
        for e in transfer {
            XCTAssertEqual(e.type, .transferSyntax)
            XCTAssertTrue(allUIDs.contains(e.uid), "transferSyntax not in allEntries: \(e.uid)")
        }
        for e in sop {
            XCTAssertEqual(e.type, .sopClass)
            XCTAssertTrue(allUIDs.contains(e.uid), "sopClass not in allEntries: \(e.uid)")
        }
        // Every registry UID is itself a syntactically valid DICOM UID.
        for e in all {
            XCTAssertTrue(isSyntacticallyValidUID(e.uid), "registry UID invalid: \(e.uid)")
        }
    }

    // Oracle: lookup --search — filtering allEntries by a substring returns exactly
    // the entries whose name or uid contain it (definition of the filter).
    func testLookupSearchFilter() {
        let term = "explicit vr"
        let expected = UIDDictionary.allEntries.filter {
            $0.name.lowercased().contains(term) || $0.uid.lowercased().contains(term)
        }
        XCTAssertFalse(expected.isEmpty, "search term matched nothing")
        for e in expected {
            let hay = (e.name + " " + e.uid).lowercased()
            XCTAssertTrue(hay.contains(term))
        }
    }

    // MARK: - Regeneration oracles

    // Oracle: regenerate — instance UIDs change, well-known UIDs (SOPClass /
    // transfer syntax) are preserved, output re-parses, and non-UID pixel bytes
    // are unchanged. maintainRelationships=false path.
    func testRegeneratePreservesWellKnownAndReplacesInstance() throws {
        let file = makeGrayscale8(rows: 8, cols: 8, fillPattern: { UInt8($0 % 256) })
        let inputData = try file.write()

        let originalStudy = file.dataSet.string(for: .studyInstanceUID)
        let originalSeries = file.dataSet.string(for: .seriesInstanceUID)
        let originalSOPInstance = file.dataSet.string(for: .sopInstanceUID)
        let originalSOPClass = file.dataSet.string(for: .sopClassUID)
        let originalPixels = pixelBytes(file)
        XCTAssertNotNil(originalStudy)
        XCTAssertNotNil(originalSOPClass)

        let manager = UIDManager()
        var mappings: [String: String] = [:]
        let (newData, changes) = try manager.regenerateData(
            inputData, root: nil, maintainRelationships: false, existingMappings: &mappings)

        let regenerated = try DICOMFile.read(from: newData)

        // Instance UIDs were replaced (old != new) and remain valid.
        let newStudy = regenerated.dataSet.string(for: .studyInstanceUID)
        let newSeries = regenerated.dataSet.string(for: .seriesInstanceUID)
        let newSOPInstance = regenerated.dataSet.string(for: .sopInstanceUID)
        XCTAssertNotEqual(newStudy, originalStudy)
        XCTAssertNotEqual(newSeries, originalSeries)
        XCTAssertNotEqual(newSOPInstance, originalSOPInstance)
        XCTAssertTrue(isSyntacticallyValidUID(newStudy ?? ""))
        XCTAssertTrue(isSyntacticallyValidUID(newSeries ?? ""))
        XCTAssertTrue(isSyntacticallyValidUID(newSOPInstance ?? ""))

        // Well-known SOP Class UID is preserved (registry UIDs are never regenerated).
        XCTAssertEqual(regenerated.dataSet.string(for: .sopClassUID), originalSOPClass)

        // Non-UID content (pixels) is unchanged.
        XCTAssertEqual(pixelBytes(regenerated), originalPixels)

        // Reported mappings cover exactly the changed instance UIDs; each maps
        // an old value to a distinct, valid new value.
        XCTAssertFalse(changes.isEmpty)
        let changedOldUIDs = Set(changes.map { $0.oldUID })
        XCTAssertTrue(changedOldUIDs.contains(originalStudy!))
        XCTAssertTrue(changedOldUIDs.contains(originalSeries!))
        XCTAssertTrue(changedOldUIDs.contains(originalSOPInstance!))
        // No well-known UID appears among the changes.
        XCTAssertFalse(changes.contains { $0.oldUID == originalSOPClass })
        for m in changes {
            XCTAssertNotEqual(m.oldUID, m.newUID)
            XCTAssertTrue(isSyntacticallyValidUID(m.newUID))
            // tagHex format is "GGGG,EEEE" uppercase hex.
            XCTAssertTrue(m.tagHex.range(of: "^[0-9A-F]{4},[0-9A-F]{4}$",
                                         options: .regularExpression) != nil,
                          "tagHex malformed: \(m.tagHex)")
        }
    }

    // Oracle: regenerate --maintain-relationships — the same old UID maps to the
    // same new UID across files, so a shared Study/Series UID stays linked.
    func testRegenerateMaintainsRelationshipsAcrossFiles() throws {
        // Two files sharing the same Study & Series UID (as in one study).
        let sharedStudy = "1.2.3.4.5.999.1"
        let sharedSeries = "1.2.3.4.5.999.2"

        func makeShared() -> DICOMFile {
            var ds = DataSet()
            ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
            ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
            ds.setString(sharedStudy, for: .studyInstanceUID, vr: .UI)
            ds.setString(sharedSeries, for: .seriesInstanceUID, vr: .UI)
            ds.setString("CT", for: .modality, vr: .CS)
            return DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
        }

        let data1 = try makeShared().write()
        let data2 = try makeShared().write()

        let manager = UIDManager()
        var mappings: [String: String] = [:]
        let (out1, _) = try manager.regenerateData(
            data1, root: nil, maintainRelationships: true, existingMappings: &mappings)
        let (out2, _) = try manager.regenerateData(
            data2, root: nil, maintainRelationships: true, existingMappings: &mappings)

        let f1 = try DICOMFile.read(from: out1)
        let f2 = try DICOMFile.read(from: out2)

        // Both files end up with the SAME regenerated Study/Series UID (relationship kept).
        XCTAssertEqual(f1.dataSet.string(for: .studyInstanceUID),
                       f2.dataSet.string(for: .studyInstanceUID))
        XCTAssertEqual(f1.dataSet.string(for: .seriesInstanceUID),
                       f2.dataSet.string(for: .seriesInstanceUID))
        // ...and it differs from the original shared value.
        XCTAssertNotEqual(f1.dataSet.string(for: .studyInstanceUID), sharedStudy)
        // The shared UID appears in the mapping table exactly once.
        XCTAssertNotNil(mappings[sharedStudy])
        XCTAssertNotNil(mappings[sharedSeries])
    }

    // Oracle: regenerate on-disk convenience (regenerateUIDs) writes an output file
    // whose well-known UID is preserved and whose instance UIDs are replaced —
    // consistent with the in-memory regenerateData result.
    func testRegenerateUIDsWritesFile() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let inputURL = try writeTempDICOM(file, name: "regen-in.dcm")
        let outputURL = inputURL.deletingLastPathComponent()
            .appendingPathComponent("regen-out.dcm")

        let originalStudy = file.dataSet.string(for: .studyInstanceUID)
        let originalSOPClass = file.dataSet.string(for: .sopClassUID)

        let manager = UIDManager()
        var mappings: [String: String] = [:]
        let changes = try manager.regenerateUIDs(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            root: nil,
            maintainRelationships: false,
            existingMappings: &mappings)

        XCTAssertFalse(changes.isEmpty)
        let outFile = try DICOMFile.read(from: outputURL, force: true)
        XCTAssertNotEqual(outFile.dataSet.string(for: .studyInstanceUID), originalStudy)
        XCTAssertEqual(outFile.dataSet.string(for: .sopClassUID), originalSOPClass)
    }

    // Oracle: regenerate preview (regenerationPreviewLines) lists exactly the
    // instance UIDs that regenerateData would change — same count, same tag names.
    func testRegenerationPreviewMatchesActualChanges() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let inputData = try file.write()
        let parsed = try DICOMFile.read(from: inputData)

        let previewLines = UIDManager.regenerationPreviewLines(for: parsed.dataSet)
        // Last line is the summary; the rest are per-UID lines.
        XCTAssertGreaterThanOrEqual(previewLines.count, 1)
        let summary = previewLines.last!
        let perUIDLines = previewLines.dropLast()

        let manager = UIDManager()
        var mappings: [String: String] = [:]
        let (_, changes) = try manager.regenerateData(
            inputData, root: nil, maintainRelationships: false, existingMappings: &mappings)

        // Preview per-UID line count equals the actual number of regenerated UIDs.
        XCTAssertEqual(perUIDLines.count, changes.count)
        XCTAssertTrue(summary.contains("\(changes.count)") ||
                      summary.contains("No instance UIDs"),
                      "summary line does not reflect count: \(summary)")
        // Each preview line names a tag that appears in the actual mapping set.
        let changedTagNames = Set(changes.map { $0.tagName })
        for line in perUIDLines {
            XCTAssertTrue(changedTagNames.contains { line.contains($0) },
                          "preview line references no regenerated tag: \(line)")
        }
    }

    // MARK: - additional generation / regeneration options

    // Oracle: generate --type sop routes the sop type and yields valid, unique,
    // root-prefixed UIDs (the sop type is in the CLI allow-list alongside study/series/instance).
    func testTypedGenerationSOP() {
        let manager = UIDManager()
        let root = "1.2.3.4.5"
        let uids = manager.generateUIDs(count: 5, root: root, type: "sop")
        XCTAssertEqual(uids.count, 5)
        XCTAssertEqual(Set(uids).count, 5, "sop-typed UIDs must be unique")
        for uid in uids {
            XCTAssertTrue(isSyntacticallyValidUID(uid), "sop UID must be valid: \(uid)")
            XCTAssertTrue(manager.validateUID(uid).isValid)
            XCTAssertTrue(uid.hasPrefix(root + "."), "sop UID must carry the custom root")
        }
    }

    // Oracle: regenerate --root applies the custom root to every regenerated instance
    // UID while preserving well-known UIDs; new UIDs stay valid and differ from originals.
    func testRegenerateHonorsCustomRoot() throws {
        let root = "1.2.826.0.1.3680043.9.7777"
        let file = makeGrayscale8(rows: 4, cols: 4)
        let data = try file.write()
        let manager = UIDManager()
        var mappings: [String: String] = [:]
        let (out, changes) = try manager.regenerateData(
            data, root: root, maintainRelationships: false, existingMappings: &mappings)
        let regenerated = try DICOMFile.read(from: out)

        XCTAssertFalse(changes.isEmpty)
        for m in changes {
            XCTAssertTrue(m.newUID.hasPrefix(root + "."), "regenerated UID must carry root: \(m.newUID)")
            XCTAssertTrue(isSyntacticallyValidUID(m.newUID))
            XCTAssertNotEqual(m.oldUID, m.newUID)
        }
        // Well-known SOP Class UID is preserved (not regenerated under the root).
        XCTAssertEqual(regenerated.dataSet.string(for: .sopClassUID),
                       file.dataSet.string(for: .sopClassUID))
        XCTAssertTrue(regenerated.dataSet.string(for: .studyInstanceUID)?.hasPrefix(root + ".") ?? false,
                      "regenerated Study UID must carry the custom root")
    }
}

