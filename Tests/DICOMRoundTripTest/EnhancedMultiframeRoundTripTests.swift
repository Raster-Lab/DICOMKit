// EnhancedMultiframeRoundTripTests.swift
// Oracle-based round-trip tests for the enhanced-multiframe split/merge engine
// (ENHANCED_MULTIFRAME_SPLIT_MERGE_PLAN.md).
//
// Drives the DICOMKit library engines (`FrameSplitter`, `FrameMerger` and the
// shared `Multiframe/` types) exactly as the `dicom-split` / `dicom-merge` CLIs
// and the Studio Workshop do. Every assertion is a semantic fact about the
// DICOM standard (PS3.3 C.7.6.16 / C.7.6.17, Sup 157) — never a comparison
// against a re-implementation.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class EnhancedMultiframeRoundTripTests: XCTestCase {

    private typealias U = MultiframeSOPClassMap.UID
    private let forTag = Tag(group: 0x0020, element: 0x0052)

    // MARK: - Builders

    private func mutate(_ file: DICOMFile, _ body: (inout DataSet) -> Void) -> DICOMFile {
        var ds = file.dataSet
        body(&ds)
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
    }

    private func seq(_ tag: Tag, _ elements: [DataElement]) -> DataElement {
        FunctionalGroupBuilder.sequenceElement(tag, items: [SequenceItem(elements: elements)], writer: DICOMWriter())
    }

    private func str(_ tag: Tag, _ vr: VR, _ value: String) -> DataElement {
        DataElement.string(tag: tag, vr: vr, value: value)
    }

    /// Enhanced CT, 16-bit, `frames` frames, frame f filled with value 100 + f,
    /// with Shared (PixelMeasures / PlaneOrientation / FrameVOILUT /
    /// PixelValueTransformation / CT frame type) and Per-frame (FrameContent /
    /// PlanePosition) functional groups and a Multi-frame Dimension module.
    private func makeEnhancedCT(frames: Int, rows: UInt16 = 4, cols: UInt16 = 4) -> DICOMFile {
        var ds = DataSet()
        ds.setString(U.enhancedCT, for: .sopClassUID, vr: .UI)
        ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.201", for: .seriesInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.900", for: forTag, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString("RoundTrip^Patient", for: .patientName, vr: .PN)
        ds.setString("RT001", for: .patientID, vr: .LO)
        ds.setString("7", for: .seriesNumber, vr: .IS)
        ds.setString("1", for: .instanceNumber, vr: .IS)
        ds.setStrings(["ORIGINAL", "PRIMARY", "VOLUME", "NONE"], for: .imageType, vr: .CS)
        ds.setUInt16(rows, for: .rows)
        ds.setUInt16(cols, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(12, for: .bitsStored)
        ds.setUInt16(11, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setString("\(frames)", for: .numberOfFrames, vr: .IS)

        ds.setSequence([SequenceItem(elements: [
            seq(.pixelMeasuresSequence, [str(.pixelSpacing, .DS, "0.5\\0.5"), str(.sliceThickness, .DS, "1")]),
            seq(.planeOrientationSequence, [str(.imageOrientationPatient, .DS, "1\\0\\0\\0\\1\\0")]),
            seq(.frameVOILUTSequence, [str(.windowCenter, .DS, "40"), str(.windowWidth, .DS, "400")]),
            seq(.pixelValueTransformationSequence, [str(.rescaleIntercept, .DS, "-1024"), str(.rescaleSlope, .DS, "1"), str(.rescaleType, .LO, "HU")]),
            seq(.ctImageFrameTypeSequence, [DataElement.strings(tag: .frameType, vr: .CS, values: ["ORIGINAL", "PRIMARY", "AXIAL", "NONE"])]),
        ])], for: .sharedFunctionalGroupsSequence)

        var perFrame: [SequenceItem] = []
        for f in 0..<frames {
            perFrame.append(SequenceItem(elements: [
                seq(.frameContentSequence, [
                    str(.stackID, .SH, "1"),
                    DataElement.uint32(tag: .inStackPositionNumber, value: UInt32(f + 1)),
                    DataElement.uint32s(tag: .dimensionIndexValues, values: [1, UInt32(f + 1)]),
                ]),
                seq(.planePositionSequence, [str(.imagePositionPatient, .DS, "0\\0\\\(Double(f) * 1.5)")]),
            ]))
        }
        ds.setSequence(perFrame, for: .perFrameFunctionalGroupsSequence)

        let orgUID = "1.2.3.4.5.777"
        ds.setSequence([SequenceItem(elements: [str(.dimensionOrganizationUID, .UI, orgUID)])], for: .dimensionOrganizationSequence)
        ds.setSequence([
            SequenceItem(elements: [str(.dimensionOrganizationUID, .UI, orgUID),
                                    FunctionalGroupBuilder.attributeTagElement(.dimensionIndexPointer, value: .stackID, writer: DICOMWriter()),
                                    FunctionalGroupBuilder.attributeTagElement(.functionalGroupPointer, value: .frameContentSequence, writer: DICOMWriter())]),
            SequenceItem(elements: [str(.dimensionOrganizationUID, .UI, orgUID),
                                    FunctionalGroupBuilder.attributeTagElement(.dimensionIndexPointer, value: .inStackPositionNumber, writer: DICOMWriter()),
                                    FunctionalGroupBuilder.attributeTagElement(.functionalGroupPointer, value: .frameContentSequence, writer: DICOMWriter())]),
        ], for: .dimensionIndexSequence)

        let frameSize = Int(rows) * Int(cols)
        var pixels = Data(count: frameSize * frames * 2)
        for f in 0..<frames {
            let v = UInt16(100 + f)
            for i in 0..<frameSize {
                pixels[(f * frameSize + i) * 2] = UInt8(v & 0xFF)
                pixels[(f * frameSize + i) * 2 + 1] = UInt8(v >> 8)
            }
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        return DICOMFile.create(dataSet: ds, sopClassUID: U.enhancedCT)
    }

    /// Classic CT slice with the attributes an Enhanced merge lifts.
    private func makeClassicCT(index: Int, value: UInt16, orientation: String = "1\\0\\0\\0\\1\\0",
                               position: String? = nil, sopClass: String = U.ctImage, modality: String = "CT") -> DICOMFile {
        mutate(makeGrayscale16(rows: 4, cols: 4, fillPattern: { _ in value })) { ds in
            ds.setString(sopClass, for: .sopClassUID, vr: .UI)
            ds.setString(modality, for: .modality, vr: .CS)
            ds.setString("\(index + 1)", for: .instanceNumber, vr: .IS)
            ds.setString("1.2.3.4.5.900", for: forTag, vr: .UI)
            ds.setString("0.5\\0.5", for: .pixelSpacing, vr: .DS)
            ds.setString("1", for: .sliceThickness, vr: .DS)
            ds.setString(orientation, for: .imageOrientationPatient, vr: .DS)
            ds.setString(position ?? "0\\0\\\(Double(index) * 1.5)", for: .imagePositionPatient, vr: .DS)
            ds.setString("40", for: .windowCenter, vr: .DS)
            ds.setString("400", for: .windowWidth, vr: .DS)
            ds.setString("-1024", for: .rescaleIntercept, vr: .DS)
            ds.setString("1", for: .rescaleSlope, vr: .DS)
            ds.setString("HU", for: .rescaleType, vr: .LO)
            ds.setStrings(["ORIGINAL", "PRIMARY", "AXIAL"], for: .imageType, vr: .CS)
        }
    }

    private func write(_ files: [DICOMFile], dir: URL, prefix: String = "in") throws -> [String] {
        try files.enumerated().map { i, f in
            let url = dir.appendingPathComponent(String(format: "\(prefix)_%03d.dcm", i))
            try f.write().write(to: url)
            return url.path
        }
    }

    private func split(_ file: DICOMFile, options: SplitOptions = SplitOptions(),
                       log: @escaping (String) -> Void = { _ in }) async throws -> (SplitResult, [DICOMFile]) {
        let inDir = try makeTempDir()
        let inURL = inDir.appendingPathComponent("input.dcm")
        try file.write().write(to: inURL)
        let outDir = try makeTempDir()
        let splitter = FrameSplitter(outputPath: outDir.path, format: .dicom, applyWindow: false,
                                     windowCenter: nil, windowWidth: nil, namingPattern: nil,
                                     verbose: false, options: options, log: log)
        var result = SplitResult()
        await splitter.processFile(inURL.path, frameIndices: nil, into: &result)
        let files = try result.writtenPaths.sorted().map { try DICOMFile.read(from: URL(fileURLWithPath: $0)) }
        return (result, files)
    }

    private func merge(_ files: [DICOMFile], format: MergeFormat, sortBy: MergeSortCriteria = .instanceNumber,
                       options: MergeOptions = MergeOptions(), validate: Bool = false,
                       log: @escaping (String) -> Void = { _ in }) async throws -> DICOMFile {
        let dir = try makeTempDir()
        let paths = try write(files, dir: dir)
        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: format, level: .file, sortBy: sortBy, order: .ascending,
                                 validate: validate, verbose: true, options: options, log: log)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)
        return try DICOMFile.read(from: out)
    }

    private func uid(_ ds: DataSet, _ tag: Tag) -> String? {
        ds.string(for: tag).map(MultiframeSOPClassMap.normalize)
    }

    private func trimmed(_ ds: DataSet, _ tag: Tag) -> String? {
        ds.string(for: tag)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
    }

    private func frameValue(_ file: DICOMFile) -> UInt16? {
        guard let px = file.pixelData()?.data, px.count >= 2 else { return nil }
        return UInt16(px[0]) | (UInt16(px[1]) << 8)
    }

    // MARK: - Split: Enhanced CT → CT Image Storage

    // Oracle (PS3.3 A.3 vs A.38): the classic CT IOD has no functional groups and no
    // NumberOfFrames; the per-frame plane position and the shared measures/VOI/rescale
    // must appear at the top level of each single-frame instance.
    func testSplitEnhancedCTBecomesClassicCTWithFlattenedFunctionalGroups() async throws {
        let src = makeEnhancedCT(frames: 3)
        let (result, files) = try await split(src)
        XCTAssertEqual(result.extracted, 3)
        XCTAssertEqual(files.count, 3)

        for (i, out) in files.enumerated() {
            let ds = out.dataSet
            XCTAssertEqual(uid(ds, .sopClassUID), U.ctImage, "Enhanced CT → CT Image Storage")
            XCTAssertEqual(uid(out.fileMetaInformation, .mediaStorageSOPClassUID), U.ctImage)
            XCTAssertNil(ds[.sharedFunctionalGroupsSequence])
            XCTAssertNil(ds[.perFrameFunctionalGroupsSequence])
            XCTAssertNil(ds[.dimensionIndexSequence])
            XCTAssertNil(ds[.dimensionOrganizationSequence])
            XCTAssertNil(ds[.numberOfFrames], "classic CT has no NumberOfFrames")
            XCTAssertEqual(trimmed(ds, .imagePositionPatient), "0\\0\\\(Double(i) * 1.5)")
            XCTAssertEqual(trimmed(ds, .imageOrientationPatient), "1\\0\\0\\0\\1\\0")
            XCTAssertEqual(trimmed(ds, .pixelSpacing), "0.5\\0.5")
            XCTAssertEqual(trimmed(ds, .windowCenter), "40")
            XCTAssertEqual(trimmed(ds, .rescaleIntercept), "-1024")
            XCTAssertEqual(trimmed(ds, .rescaleType), "HU")
            XCTAssertEqual(ds.strings(for: .imageType)?.map { $0.trimmingCharacters(in: .whitespaces) },
                           ["ORIGINAL", "PRIMARY", "AXIAL", "NONE"], "Frame Type becomes Image Type")
            XCTAssertNil(ds[.frameType])
            XCTAssertNil(ds[.stackID])
            XCTAssertNil(ds[.inStackPositionNumber])
            XCTAssertNil(ds[.dimensionIndexValues])
            XCTAssertEqual(trimmed(ds, .instanceNumber), "\(i + 1)")
            XCTAssertEqual(trimmed(ds, .seriesInstanceUID), "1.2.3.4.5.201", "series preserved by default")
            XCTAssertEqual(frameValue(out), UInt16(100 + i))
        }
        XCTAssertEqual(Set(files.map { uid($0.dataSet, .sopInstanceUID) }).count, 3)
    }

    // Oracle: --target same keeps the Enhanced SOP class, NumberOfFrames = 1, and a
    // Per-frame Functional Groups Sequence holding exactly this frame's item.
    func testSplitTargetSameKeepsEnhancedClassWithOneFrameItem() async throws {
        var options = SplitOptions()
        options.target = .same
        let (_, files) = try await split(makeEnhancedCT(frames: 2), options: options)
        XCTAssertEqual(files.count, 2)
        for (i, out) in files.enumerated() {
            let ds = out.dataSet
            XCTAssertEqual(uid(ds, .sopClassUID), U.enhancedCT)
            XCTAssertEqual(trimmed(ds, .numberOfFrames), "1")
            let perFrame = ds[.perFrameFunctionalGroupsSequence]?.sequenceItems
            XCTAssertEqual(perFrame?.count, 1)
            let pos = perFrame?.first?[.planePositionSequence]?.sequenceItems?.first?.string(for: .imagePositionPatient)
            XCTAssertEqual(pos?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "0\\0\\\(Double(i) * 1.5)")
            XCTAssertNotNil(ds[.sharedFunctionalGroupsSequence])
            XCTAssertNotNil(ds[.dimensionIndexSequence], "dimension module kept for the Enhanced IOD")
        }
    }

    // Oracle: --target classic on an IOD without a classic counterpart skips the file.
    func testSplitClassicPolicyRejectsSameClassOnlyIOD() async throws {
        let src = mutate(makeEnhancedCT(frames: 2)) { $0.setString(U.breastTomosynthesis, for: .sopClassUID, vr: .UI) }
        var options = SplitOptions()
        options.target = .classic
        var lines: [String] = []
        let (result, files) = try await split(src, options: options, log: { lines.append($0) })
        XCTAssertEqual(result.skippedFiles, 1)
        XCTAssertEqual(files.count, 0)
        XCTAssertTrue(lines.contains { $0.contains("no classic single-frame SOP Class") }, "\(lines)")
    }

    // Oracle: Segmentation is inherently multi-frame and is refused (skipped, not failed).
    func testSplitRefusesSegmentation() async throws {
        let src = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 2)) { $0.setString(U.segmentation, for: .sopClassUID, vr: .UI) }
        let (result, files) = try await split(src)
        XCTAssertEqual(result.skippedFiles, 1)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(files.count, 0)
    }

    // Oracle: --split-by stack writes one series per Stack ID with distinct UIDs.
    func testSplitByStackWritesOneSeriesPerStack() async throws {
        let src = mutate(makeEnhancedCT(frames: 4)) { ds in
            var items = ds[.perFrameFunctionalGroupsSequence]?.sequenceItems ?? []
            for i in items.indices {
                var elements = items[i].allElements.filter { $0.tag != .frameContentSequence }
                elements.append(self.seq(.frameContentSequence, [
                    self.str(.stackID, .SH, i < 2 ? "1" : "2"),
                    DataElement.uint32(tag: .inStackPositionNumber, value: UInt32(i % 2 + 1)),
                ]))
                items[i] = SequenceItem(elements: elements)
            }
            ds.setSequence(items, for: .perFrameFunctionalGroupsSequence)
        }
        var options = SplitOptions()
        options.seriesGrouping = .stack
        options.instanceNumbering = .instack
        let (_, files) = try await split(src, options: options)
        let series = files.map { uid($0.dataSet, .seriesInstanceUID) ?? "" }
        XCTAssertEqual(Set(series).count, 2, "two stacks → two series")
        XCTAssertEqual(series[0], series[1])
        XCTAssertEqual(series[2], series[3])
        XCTAssertEqual(files.map { trimmed($0.dataSet, .instanceNumber) }, ["1", "2", "1", "2"], "InstanceNumber := In-Stack Position")
        XCTAssertEqual(trimmed(files[2].dataSet, .seriesNumber), "702")
    }

    // MARK: - Split: legacy multi-frame vectors

    // Oracle (PS3.3 C.7.6.5): a classic US Image has no Cine module, so the Frame Time
    // Vector collapses to this frame's Frame Time and the Frame Increment Pointer goes.
    func testSplitUSMultiframeResolvesFrameTimeVector() async throws {
        let src = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 3)) { ds in
            ds.setString(U.usMultiframe, for: .sopClassUID, vr: .UI)
            ds.setString("US", for: .modality, vr: .CS)
            ds.setStrings(["10", "20", "30"], for: .frameTimeVector, vr: .DS)
            ds[.frameIncrementPointer] = DataElement(tag: .frameIncrementPointer, vr: .AT, length: 4,
                                                     valueData: DICOMWriter().serializeTag(.frameTimeVector))
        }
        let (_, files) = try await split(src)
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(uid(files[1].dataSet, .sopClassUID), U.usImage)
        XCTAssertEqual(trimmed(files[1].dataSet, .frameTime), "20")
        XCTAssertNil(files[1].dataSet[.frameTimeVector])
        XCTAssertNil(files[1].dataSet[.frameIncrementPointer])
        XCTAssertNil(files[1].dataSet[.numberOfFrames])
    }

    // Oracle (PS3.3 C.8.4.8): NM keeps its SOP class; each index vector is sliced to the
    // frame's own value and NumberOfFrames becomes 1.
    func testSplitNMSlicesIndexVectors() async throws {
        let src = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 3)) { ds in
            ds.setString(U.nmImage, for: .sopClassUID, vr: .UI)
            ds.setString("NM", for: .modality, vr: .CS)
            ds.setUInt16s([1, 2, 3], for: .sliceVector)
            ds.setUInt16s([1, 1, 1], for: .energyWindowVector)
            ds.setUInt16(3, for: .numberOfSlices)
            ds[.frameIncrementPointer] = DataElement(tag: .frameIncrementPointer, vr: .AT, length: 8,
                                                     valueData: DICOMWriter().serializeTag(.energyWindowVector) + DICOMWriter().serializeTag(.sliceVector))
        }
        let (_, files) = try await split(src)
        XCTAssertEqual(files.count, 3)
        for (i, out) in files.enumerated() {
            XCTAssertEqual(uid(out.dataSet, .sopClassUID), U.nmImage)
            XCTAssertEqual(trimmed(out.dataSet, .numberOfFrames), "1")
            XCTAssertEqual(out.dataSet.uint16s(for: .sliceVector), [UInt16(i + 1)])
            XCTAssertEqual(out.dataSet.uint16s(for: .energyWindowVector), [1])
            XCTAssertNotNil(out.dataSet[.frameIncrementPointer], "same-class output keeps the pointer")
        }
    }

    // MARK: - Split/merge: encapsulated pixel data

    // Oracle (PS3.5 A.4): preserving the transfer syntax means each output carries its
    // frame's fragment untouched under the source TS; merging them back yields one
    // fragment per frame with a Basic Offset Table, and the file meta keeps the TS.
    func testEncapsulatedFramesArePreservedThroughSplitAndMerge() async throws {
        let fragments = [Data("frame-zero!!".utf8), Data("frame-one!!!".utf8), Data("frame-two!!!".utf8)]
        let src: DICOMFile = {
            var ds = makeMultiFrame(rows: 4, cols: 4, frames: 3).dataSet
            ds.setString(U.multiframeGrayscaleByteSC, for: .sopClassUID, vr: .UI)
            ds[.pixelData] = DataElement(tag: .pixelData, vr: .OB, length: 0xFFFFFFFF, valueData: Data(),
                                         encapsulatedFragments: fragments, encapsulatedOffsetTable: [])
            return DICOMFile.create(dataSet: ds, sopClassUID: U.multiframeGrayscaleByteSC,
                                    transferSyntaxUID: TransferSyntax.rleLossless.uid)
        }()

        let (_, files) = try await split(src)
        XCTAssertEqual(files.count, 3)
        for (i, out) in files.enumerated() {
            XCTAssertEqual(uid(out.fileMetaInformation, .transferSyntaxUID), TransferSyntax.rleLossless.uid)
            XCTAssertEqual(out.dataSet[.pixelData]?.encapsulatedFragments, [fragments[i]])
            XCTAssertEqual(uid(out.dataSet, .sopClassUID), U.secondaryCapture)
        }

        let merged = try await merge(files, format: .scMultiframe, sortBy: .none)
        XCTAssertEqual(uid(merged.fileMetaInformation, .transferSyntaxUID), TransferSyntax.rleLossless.uid)
        XCTAssertEqual(merged.dataSet[.pixelData]?.encapsulatedFragments, fragments)
        XCTAssertEqual(merged.dataSet[.pixelData]?.encapsulatedOffsetTable, [0, 20, 40], "BOT: 8-byte item header + 12-byte fragment")
        XCTAssertEqual(uid(merged.dataSet, .sopClassUID), U.multiframeGrayscaleByteSC)
        XCTAssertEqual(trimmed(merged.dataSet, .numberOfFrames), "3")
    }

    // Oracle: mixed transfer syntaxes cannot be concatenated in preserve mode; decode
    // mode transcodes both to Explicit VR Little Endian.
    func testMergeRejectsMixedTransferSyntaxUnlessDecoding() async throws {
        let a = makeClassicCT(index: 0, value: 1)
        let bDS = makeClassicCT(index: 1, value: 2).dataSet
        let b = DICOMFile.create(dataSet: bDS, sopClassUID: U.ctImage, transferSyntaxUID: TransferSyntax.implicitVRLittleEndian.uid)

        do {
            _ = try await merge([a, b], format: .standard)
            XCTFail("expected a TransferSyntaxUID mismatch")
        } catch let error as MergeError {
            guard case .inconsistentAttribute(let tag, _, _, _, _) = error, tag == "TransferSyntaxUID" else {
                return XCTFail("unexpected \(error)")
            }
        }

        var options = MergeOptions()
        options.pixelHandling = .decode
        let merged = try await merge([a, b], format: .standard, options: options)
        XCTAssertEqual(uid(merged.fileMetaInformation, .transferSyntaxUID), TransferSyntax.explicitVRLittleEndian.uid)
        XCTAssertEqual(trimmed(merged.dataSet, .numberOfFrames), "2")
    }

    // MARK: - Merge: classic CT → Enhanced CT

    // Oracle (PS3.3 C.7.6.16 / C.7.6.17): attributes identical in every frame factor into
    // the Shared item, varying ones into Per-frame items; lifted attributes leave the top
    // level; Dimension Index Values point at a real Dimension Index Sequence.
    func testMergeClassicCTIntoEnhancedCTFactorsFunctionalGroups() async throws {
        let slices = (0..<3).map { makeClassicCT(index: $0, value: UInt16(200 + $0)) }
        var lines: [String] = []
        let merged = try await merge(slices, format: .enhancedCt, log: { lines.append($0) })
        let ds = merged.dataSet

        XCTAssertEqual(uid(ds, .sopClassUID), U.enhancedCT)
        XCTAssertEqual(uid(merged.fileMetaInformation, .mediaStorageSOPClassUID), U.enhancedCT)
        XCTAssertEqual(trimmed(ds, .numberOfFrames), "3")

        let shared = try XCTUnwrap(ds[.sharedFunctionalGroupsSequence]?.sequenceItems?.first)
        XCTAssertNotNil(shared[.pixelMeasuresSequence])
        XCTAssertNotNil(shared[.planeOrientationSequence])
        XCTAssertNotNil(shared[.frameVOILUTSequence])
        XCTAssertNotNil(shared[.pixelValueTransformationSequence])
        XCTAssertNotNil(shared[.ctImageFrameTypeSequence])
        XCTAssertNil(shared[.planePositionSequence], "positions vary → per-frame, not shared")
        let frameType = shared[.ctImageFrameTypeSequence]?.sequenceItems?.first
        XCTAssertEqual(frameType?.strings(for: .frameType)?.map { $0.trimmingCharacters(in: .whitespaces) },
                       ["ORIGINAL", "PRIMARY", "AXIAL", "NONE"], "Frame Type padded to 4 values")

        let perFrame = try XCTUnwrap(ds[.perFrameFunctionalGroupsSequence]?.sequenceItems)
        XCTAssertEqual(perFrame.count, 3)
        for (i, item) in perFrame.enumerated() {
            let fc = try XCTUnwrap(item[.frameContentSequence]?.sequenceItems?.first)
            XCTAssertEqual(fc.string(for: .stackID)?.trimmingCharacters(in: .whitespaces), "1")
            XCTAssertEqual(fc[.inStackPositionNumber]?.uint32Value, UInt32(i + 1))
            XCTAssertEqual(fc[.dimensionIndexValues]?.uint32Values, [1, UInt32(i + 1)])
            let pos = item[.planePositionSequence]?.sequenceItems?.first?.string(for: .imagePositionPatient)
            XCTAssertEqual(pos?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "0\\0\\\(Double(i) * 1.5)")
        }

        // Lifted attributes no longer sit at the top level.
        for tag in [Tag.imagePositionPatient, .imageOrientationPatient, .pixelSpacing, .windowCenter, .rescaleIntercept] {
            XCTAssertNil(ds[tag], "\(tag) lifted into a functional group")
        }

        // Multi-frame Dimension module.
        let orgUID = ds[.dimensionOrganizationSequence]?.sequenceItems?.first?.string(for: .dimensionOrganizationUID)
        XCTAssertNotNil(orgUID)
        let index = try XCTUnwrap(ds[.dimensionIndexSequence]?.sequenceItems)
        XCTAssertEqual(index.count, 2)
        XCTAssertEqual(index[0].string(for: .dimensionOrganizationUID), orgUID)
        XCTAssertEqual(LegacyVectorResolver.attributeTags(of: try XCTUnwrap(index[0][.dimensionIndexPointer])), [.stackID])
        XCTAssertEqual(LegacyVectorResolver.attributeTags(of: try XCTUnwrap(index[1][.dimensionIndexPointer])), [.inStackPositionNumber])
        XCTAssertEqual(trimmed(ds, .dimensionOrganizationType), "3D", "single regularly spaced stack")

        // Enhanced image module requirements.
        XCTAssertEqual(ds.strings(for: .imageType)?.count, 4)
        XCTAssertEqual(trimmed(ds, .pixelPresentation), "MONOCHROME")
        XCTAssertEqual(trimmed(ds, .volumetricProperties), "VOLUME")
        XCTAssertNotNil(ds[.contentDate])
        XCTAssertEqual(trimmed(ds, forTag), "1.2.3.4.5.900")
        XCTAssertTrue(lines.contains { $0.hasPrefix("Functional groups:") }, "\(lines)")
    }

    // Oracle (Sup 157): a Legacy Converted object references every source instance
    // per frame (Conversion Source Attributes) and in the Referenced Series Sequence.
    func testMergeLegacyConvertedCTCarriesConversionSources() async throws {
        let slices = (0..<2).map { makeClassicCT(index: $0, value: 5) }
        let merged = try await merge(slices, format: .legacyConvertedCt)
        XCTAssertEqual(uid(merged.dataSet, .sopClassUID), U.legacyConvertedEnhancedCT)
        let perFrame = try XCTUnwrap(merged.dataSet[.perFrameFunctionalGroupsSequence]?.sequenceItems)
        for (i, item) in perFrame.enumerated() {
            let cs = try XCTUnwrap(item[.conversionSourceAttributesSequence]?.sequenceItems?.first)
            XCTAssertEqual(cs.string(for: .referencedSOPInstanceUID).map(MultiframeSOPClassMap.normalize),
                           uid(slices[i].dataSet, .sopInstanceUID))
            XCTAssertEqual(cs.string(for: .referencedSOPClassUID).map(MultiframeSOPClassMap.normalize), U.ctImage)
        }
        let series = try XCTUnwrap(merged.dataSet[.referencedSeriesSequence]?.sequenceItems)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0][.referencedInstanceSequence]?.sequenceItems?.count, 2)
    }

    // Oracle: the source gate refuses MR Image Storage into Enhanced CT unless overridden.
    func testMergeGateRejectsForeignSourceSOPClass() async throws {
        let mr = (0..<2).map { makeClassicCT(index: $0, value: 1, sopClass: U.mrImage, modality: "MR") }
        do {
            _ = try await merge(mr, format: .enhancedCt)
            XCTFail("expected unsupportedSourceSOPClass")
        } catch let error as MergeError {
            guard case .unsupportedSourceSOPClass = error else { return XCTFail("unexpected \(error)") }
        }
        var options = MergeOptions()
        options.allowAnySource = true
        let merged = try await merge(mr, format: .enhancedCt, options: options)
        XCTAssertEqual(uid(merged.dataSet, .sopClassUID), U.enhancedCT)

        let asMR = try await merge(mr, format: .enhancedMr)
        XCTAssertEqual(uid(asMR.dataSet, .sopClassUID), U.enhancedMR)
        let shared = try XCTUnwrap(asMR.dataSet[.sharedFunctionalGroupsSequence]?.sequenceItems?.first)
        XCTAssertNotNil(shared[.mrImageFrameTypeSequence])
        XCTAssertEqual(trimmed(asMR.dataSet, .complexImageComponent), "MAGNITUDE")
    }

    // Oracle: --format auto derives the container from the source SOP class.
    func testMergeAutoPicksContainerFromSource() async throws {
        let ct = try await merge((0..<2).map { makeClassicCT(index: $0, value: 1) }, format: .auto)
        XCTAssertEqual(uid(ct.dataSet, .sopClassUID), U.legacyConvertedEnhancedCT)

        let sc = try await merge([makeGrayscale8(rows: 4, cols: 4), makeGrayscale8(rows: 4, cols: 4)].map {
            mutate($0) { $0.setString(U.secondaryCapture, for: .sopClassUID, vr: .UI) }
        }, format: .auto, sortBy: .none)
        XCTAssertEqual(uid(sc.dataSet, .sopClassUID), U.multiframeGrayscaleByteSC)

        let rgb = try await merge([makeRGB8(rows: 4, cols: 4), makeRGB8(rows: 4, cols: 4)], format: .scMultiframe, sortBy: .none)
        XCTAssertEqual(uid(rgb.dataSet, .sopClassUID), U.multiframeTrueColorSC)
    }

    // Oracle: --format standard on a classic IOD still merges but warns (always, not
    // only in verbose mode).
    func testMergeStandardWarnsOnNonMultiframeSOPClass() async throws {
        var lines: [String] = []
        let merged = try await merge((0..<2).map { makeClassicCT(index: $0, value: 1) }, format: .standard, log: { lines.append($0) })
        XCTAssertEqual(uid(merged.dataSet, .sopClassUID), U.ctImage)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Warning:") && $0.contains("not a multi-frame IOD") }, "\(lines)")
    }

    // Oracle: --make-stacks groups by orientation; the dimension organisation is no
    // longer a single 3D volume.
    func testMergeMakeStacksGroupsByOrientation() async throws {
        let axial = (0..<2).map { makeClassicCT(index: $0, value: 1) }
        let sagittal = (2..<4).map { makeClassicCT(index: $0, value: 2, orientation: "0\\1\\0\\0\\0\\1", position: "\(Double($0) * 1.5)\\0\\0") }
        var options = MergeOptions()
        options.makeStacks = true
        let merged = try await merge(axial + sagittal, format: .enhancedCt, options: options)
        let perFrame = try XCTUnwrap(merged.dataSet[.perFrameFunctionalGroupsSequence]?.sequenceItems)
        let stacks = perFrame.map { $0[.frameContentSequence]?.sequenceItems?.first?.string(for: .stackID)?.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(stacks, ["1", "1", "2", "2"])
        let inStack = perFrame.map { $0[.frameContentSequence]?.sequenceItems?.first?[.inStackPositionNumber]?.uint32Value }
        XCTAssertEqual(inStack, [1, 2, 1, 2])
        XCTAssertNil(merged.dataSet[.dimensionOrganizationType], "two stacks are not a single 3D volume")
        XCTAssertNotNil(perFrame[0][.planeOrientationSequence], "orientation varies → per-frame")
    }

    // Oracle: sorting by Image Position (Patient) orders along the slice normal, not Z.
    func testMergeSortByPositionUsesSliceNormal() async throws {
        let sagittal = [3.0, 1.0, 2.0].enumerated().map { i, x in
            makeClassicCT(index: i, value: UInt16(x), orientation: "0\\1\\0\\0\\0\\1", position: "\(x)\\0\\0")
        }
        let merged = try await merge(sagittal, format: .standard, sortBy: .imagePositionPatient)
        let px = try XCTUnwrap(merged.pixelData()?.data)
        let frameBytes = 4 * 4 * 2
        let firstValues = (0..<3).map { UInt16(px[$0 * frameBytes]) }
        XCTAssertEqual(firstValues, [1, 2, 3], "frames ordered by X (the normal for a sagittal plane)")
    }

    // MARK: - Split → merge → split identity

    // Oracle: converting an Enhanced CT to classic slices and back, then splitting again,
    // reproduces the same per-frame geometry, VOI, rescale and pixels.
    func testSplitMergeSplitRoundTripIsStable() async throws {
        let src = makeEnhancedCT(frames: 4)
        let (_, first) = try await split(src)
        let merged = try await merge(first, format: .enhancedCt)
        let (_, second) = try await split(merged)

        XCTAssertEqual(second.count, first.count)
        for (a, b) in zip(first, second) {
            for tag in [Tag.imagePositionPatient, .imageOrientationPatient, .pixelSpacing, .sliceThickness,
                        .windowCenter, .windowWidth, .rescaleIntercept, .rescaleSlope, .rescaleType,
                        .instanceNumber, .sopClassUID, forTag] {
                XCTAssertEqual(trimmed(a.dataSet, tag), trimmed(b.dataSet, tag), "\(tag) survives split→merge→split")
            }
            XCTAssertEqual(a.pixelData()?.data, b.pixelData()?.data)
        }

        // The merged object itself round-trips its own dimension bookkeeping.
        let mergedInfo = (0..<4).map { FunctionalGroupFlattener.frameInfo(in: merged.dataSet, frameIndex: $0) }
        XCTAssertEqual(mergedInfo.map { $0.inStackPositionNumber }, [1, 2, 3, 4])
        XCTAssertEqual(mergedInfo.map { $0.positionAlongNormal ?? -1 }, [0, 1.5, 3.0, 4.5])
    }

    // MARK: - P2: concatenations

    // Oracle (PS3.3 C.7.6.16.2.2.4): parts keep the SOP class, carry the same
    // Concatenation UID, consecutive In-concatenation Numbers, the frame offset of
    // their first frame and the source SOP Instance UID; reassembling them (in any
    // order) restores the original frame count, Per-frame items, pixels and UID.
    func testConcatenationSplitAndReassembly() async throws {
        let src = makeEnhancedCT(frames: 5)
        let sourceUID = uid(src.dataSet, .sopInstanceUID)
        var options = SplitOptions()
        options.framesPerInstance = 2
        let (result, parts) = try await split(src, options: options)
        XCTAssertEqual(result.extracted, 3)
        XCTAssertEqual(parts.count, 3)

        let concatUID = trimmed(parts[0].dataSet, .concatenationUID)
        XCTAssertFalse(concatUID?.isEmpty ?? true)
        for (i, part) in parts.enumerated() {
            let ds = part.dataSet
            XCTAssertEqual(uid(ds, .sopClassUID), U.enhancedCT, "concatenation keeps the SOP class")
            XCTAssertEqual(trimmed(ds, .concatenationUID), concatUID)
            XCTAssertEqual(ds.uint16(for: .inConcatenationNumber), UInt16(i + 1))
            XCTAssertEqual(ds.uint16(for: .inConcatenationTotalNumber), 3)
            XCTAssertEqual(ds.uint32(for: .concatenationFrameOffsetNumber), UInt32(i * 2))
            XCTAssertEqual(trimmed(ds, .sopInstanceUIDOfConcatenationSource), sourceUID)
            XCTAssertEqual(trimmed(ds, .numberOfFrames), i == 2 ? "1" : "2")
            XCTAssertEqual(ds[.perFrameFunctionalGroupsSequence]?.sequenceItems?.count, i == 2 ? 1 : 2)
            XCTAssertNotNil(ds[.sharedFunctionalGroupsSequence])
            XCTAssertNotNil(ds[.dimensionIndexSequence])
            XCTAssertNotEqual(uid(ds, .sopInstanceUID), sourceUID)
            XCTAssertEqual(part.pixelData()?.data.count, (i == 2 ? 1 : 2) * 4 * 4 * 2)
        }
        XCTAssertEqual(Set(parts.map { uid($0.dataSet, .sopInstanceUID) }).count, 3)

        // Reassemble from a shuffled order, with --format enhanced-ct (ignored for parts).
        let merged = try await merge([parts[2], parts[0], parts[1]], format: .enhancedCt, sortBy: .none)
        let ds = merged.dataSet
        XCTAssertEqual(uid(ds, .sopInstanceUID), sourceUID, "source SOP Instance UID restored")
        XCTAssertEqual(uid(ds, .sopClassUID), U.enhancedCT)
        XCTAssertEqual(trimmed(ds, .numberOfFrames), "5")
        for tag in MultiframeConcatenation.partTags { XCTAssertNil(ds[tag], "\(tag) removed") }
        let perFrame = try XCTUnwrap(ds[.perFrameFunctionalGroupsSequence]?.sequenceItems)
        XCTAssertEqual(perFrame.count, 5)
        let positions = perFrame.map { $0[.planePositionSequence]?.sequenceItems?.first?.string(for: .imagePositionPatient)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) }
        XCTAssertEqual(positions, (0..<5).map { "0\\0\\\(Double($0) * 1.5)" })
        XCTAssertEqual(merged.pixelData()?.data, src.pixelData()?.data)
    }

    // Oracle: Segmentation may be split into a concatenation (the one legal split);
    // Ophthalmic Tomography may not.
    func testConcatenationPolicyPerIOD() async throws {
        var options = SplitOptions()
        options.framesPerInstance = 2
        let seg = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 3)) { $0.setString(U.segmentation, for: .sopClassUID, vr: .UI) }
        let (segResult, segParts) = try await split(seg, options: options)
        XCTAssertEqual(segResult.extracted, 2)
        XCTAssertEqual(segParts.map { trimmed($0.dataSet, .numberOfFrames) }, ["2", "1"])
        XCTAssertEqual(uid(segParts[0].dataSet, .sopClassUID), U.segmentation)

        let opt = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 3)) { $0.setString(U.ophthalmicTomography, for: .sopClassUID, vr: .UI) }
        let (optResult, optParts) = try await split(opt, options: options)
        XCTAssertEqual(optResult.skippedFiles, 1)
        XCTAssertTrue(optParts.isEmpty)
    }

    // Oracle: a legacy cine loop chunked into parts keeps the right Frame Time Vector slice.
    func testConcatenationSlicesLegacyVectors() async throws {
        let src = mutate(makeMultiFrame(rows: 4, cols: 4, frames: 5)) { ds in
            ds.setString(U.usMultiframe, for: .sopClassUID, vr: .UI)
            ds.setStrings(["10", "20", "30", "40", "50"], for: .frameTimeVector, vr: .DS)
            ds[.frameIncrementPointer] = DataElement(tag: .frameIncrementPointer, vr: .AT, length: 4,
                                                     valueData: DICOMWriter().serializeTag(.frameTimeVector))
        }
        var options = SplitOptions()
        options.framesPerInstance = 2
        let (_, parts) = try await split(src, options: options)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[1].dataSet.strings(for: .frameTimeVector)?.map { $0.trimmingCharacters(in: .whitespaces) }, ["30", "40"])
        XCTAssertEqual(parts[2].dataSet.strings(for: .frameTimeVector)?.map { $0.trimmingCharacters(in: .whitespaces) }, ["50"])
        XCTAssertNotNil(parts[1].dataSet[.frameIncrementPointer])
        XCTAssertEqual(uid(parts[1].dataSet, .sopClassUID), U.usMultiframe)

        let merged = try await merge(parts, format: .standard, sortBy: .none)
        XCTAssertEqual(merged.dataSet.strings(for: .frameTimeVector)?.map { $0.trimmingCharacters(in: .whitespaces) },
                       ["10", "20", "30", "40", "50"])
        XCTAssertEqual(merged.pixelData()?.data, src.pixelData()?.data)
    }

    // MARK: - P2: provenance

    // Oracle: derived UIDs make a split reproducible (same source → same UIDs) and
    // are valid UIDs; random mode differs between runs.
    func testDeterministicUIDsAreReproducible() async throws {
        let src = makeEnhancedCT(frames: 2)
        let (_, a) = try await split(src)
        let (_, b) = try await split(src)
        XCTAssertEqual(a.map { uid($0.dataSet, .sopInstanceUID) }, b.map { uid($0.dataSet, .sopInstanceUID) })
        for out in a {
            let sop = try XCTUnwrap(uid(out.dataSet, .sopInstanceUID))
            XCTAssertTrue(sop.hasPrefix("2.25."))
            XCTAssertLessThanOrEqual(sop.count, 64)
            XCTAssertEqual(sop, MultiframeInstanceUIDs.derived(from: uid(src.dataSet, .sopInstanceUID)!, frame: a.firstIndex { uid($0.dataSet, .sopInstanceUID) == sop }!))
        }

        var options = SplitOptions()
        options.deterministicUIDs = false
        let (_, c) = try await split(src, options: options)
        let (_, d) = try await split(src, options: options)
        XCTAssertNotEqual(c.map { uid($0.dataSet, .sopInstanceUID) }, d.map { uid($0.dataSet, .sopInstanceUID) })
    }

    // Oracle (dcm4che adjustReferencedImages): a reference to frames of another
    // multi-frame instance becomes one reference per frame, naming the derived
    // single-frame UIDs and the split target's SOP class.
    func testSplitExpandsFrameReferencesToDerivedInstances() async throws {
        let otherMR = "1.2.3.4.5.4242"
        let src = mutate(makeEnhancedCT(frames: 1)) { ds in
            ds.setSequence([SequenceItem(elements: [
                self.str(.referencedSOPClassUID, .UI, U.enhancedMR),
                self.str(.referencedSOPInstanceUID, .UI, otherMR),
                DataElement.strings(tag: .referencedFrameNumber, vr: .IS, values: ["2", "3"]),
            ])], for: .referencedImageSequence)
        }
        // A one-frame Enhanced object still splits (NumberOfFrames must be > 1 to be processed).
        let src2 = mutate(src) { $0.setString("2", for: .numberOfFrames, vr: .IS) }
        let two = mutate(makeEnhancedCT(frames: 2)) { ds in
            ds[.referencedImageSequence] = src2.dataSet[.referencedImageSequence]
        }
        let (_, files) = try await split(two)
        let refs = try XCTUnwrap(files[0].dataSet[.referencedImageSequence]?.sequenceItems)
        XCTAssertEqual(refs.count, 2)
        XCTAssertEqual(refs.map { $0.string(for: .referencedSOPClassUID).map(MultiframeSOPClassMap.normalize) }, [U.mrImage, U.mrImage])
        XCTAssertEqual(refs.map { $0.string(for: .referencedSOPInstanceUID).map(MultiframeSOPClassMap.normalize) },
                       [MultiframeInstanceUIDs.derived(from: otherMR, frame: 1), MultiframeInstanceUIDs.derived(from: otherMR, frame: 2)])
        XCTAssertTrue(refs.allSatisfy { $0[.referencedFrameNumber] == nil })
    }

    // MARK: - P2: multi-frame inputs and volume geometry

    // Oracle: multi-frame inputs contribute every frame; Enhanced chunks are
    // re-factored into one Enhanced object with all Per-frame items.
    func testMergeMultiframeInputsContributeAllFrames() async throws {
        let a = makeMultiFrame(rows: 4, cols: 4, frames: 2, fill: { UInt8(10 + $0) })
        let b = makeMultiFrame(rows: 4, cols: 4, frames: 3, fill: { UInt8(20 + $0) })
        let merged = try await merge([a, b], format: .standard, sortBy: .none)
        XCTAssertEqual(trimmed(merged.dataSet, .numberOfFrames), "5")
        var expected = a.pixelData()!.data
        expected.append(b.pixelData()!.data)
        XCTAssertEqual(merged.pixelData()?.data, expected)

        let e1 = makeEnhancedCT(frames: 2)
        let e2 = mutate(makeEnhancedCT(frames: 2)) { ds in
            var items = ds[.perFrameFunctionalGroupsSequence]!.sequenceItems!
            for i in items.indices {
                var elements = items[i].allElements.filter { $0.tag != .planePositionSequence }
                elements.append(self.seq(.planePositionSequence, [self.str(.imagePositionPatient, .DS, "0\\0\\\(Double(i + 2) * 1.5)")]))
                items[i] = SequenceItem(elements: elements)
            }
            ds.setSequence(items, for: .perFrameFunctionalGroupsSequence)
        }
        let enhanced = try await merge([e1, e2], format: .enhancedCt, sortBy: .none)
        XCTAssertEqual(trimmed(enhanced.dataSet, .numberOfFrames), "4")
        let perFrame = try XCTUnwrap(enhanced.dataSet[.perFrameFunctionalGroupsSequence]?.sequenceItems)
        XCTAssertEqual(perFrame.count, 4)
        let positions = perFrame.map { $0[.planePositionSequence]?.sequenceItems?.first?.string(for: .imagePositionPatient)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) }
        XCTAssertEqual(positions, (0..<4).map { "0\\0\\\(Double($0) * 1.5)" })
        XCTAssertEqual(trimmed(enhanced.dataSet, .dimensionOrganizationType), "3D")
    }

    // Oracle: the (Volume) plane macros position frames of volume IODs.
    func testFrameInfoReadsVolumeGeometry() {
        var ds = DataSet()
        ds.setSequence([SequenceItem(elements: [
            seq(.planePositionVolumeSequence, [DataElement.float64s(tag: .imagePositionVolume, values: [1, 2, 3])]),
            seq(.planeOrientationVolumeSequence, [DataElement.float64s(tag: .imageOrientationVolume, values: [1, 0, 0, 0, 1, 0])]),
        ])], for: .perFrameFunctionalGroupsSequence)
        let info = FunctionalGroupFlattener.frameInfo(in: ds, frameIndex: 0)
        XCTAssertEqual(info.imagePositionPatient, [1, 2, 3])
        XCTAssertEqual(info.positionAlongNormal, 3)
    }

    // Oracle: window and rescale accessors see the Enhanced functional groups, so
    // the viewer/export path renders Enhanced CT like classic CT.
    func testWindowAndRescaleFallBackToFunctionalGroups() {
        let ds = makeEnhancedCT(frames: 2).dataSet
        XCTAssertEqual(ds.windowSettings()?.center, 40)
        XCTAssertEqual(ds.windowSettings()?.width, 400)
        XCTAssertEqual(ds.rescaleIntercept(), -1024)
        XCTAssertEqual(ds.rescaleSlope(), 1)
        let frame1 = ds.flattenedFrame(1)
        XCTAssertEqual(frame1.string(for: .imagePositionPatient)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "0\\0\\1.5")
        XCTAssertNotNil(frame1[.pixelData])
    }

    /// The synthetic Enhanced CT with its window and rescale moved from the Shared
    /// item into every Per-frame item: frame f windows at centre 100·(f+1) /
    /// width 200·(f+1) and rescales with intercept −1000−f.
    private func makeEnhancedCTWithPerFrameWindow(frames: Int) -> DICOMFile {
        mutate(makeEnhancedCT(frames: frames)) { ds in
            var shared = ds[.sharedFunctionalGroupsSequence]!.sequenceItems!.first!.elements
            shared[.frameVOILUTSequence] = nil
            shared[.pixelValueTransformationSequence] = nil
            ds.setSequence([SequenceItem(elements: shared)], for: .sharedFunctionalGroupsSequence)
            let perFrame = ds[.perFrameFunctionalGroupsSequence]!.sequenceItems!.enumerated().map { f, item in
                var elements = item.elements
                let voi = seq(.frameVOILUTSequence, [str(.windowCenter, .DS, "\(100 * (f + 1))"),
                                                     str(.windowWidth, .DS, "\(200 * (f + 1))")])
                let pvt = seq(.pixelValueTransformationSequence, [str(.rescaleIntercept, .DS, "\(-1000 - f)"),
                                                                  str(.rescaleSlope, .DS, "1")])
                elements[.frameVOILUTSequence] = voi
                elements[.pixelValueTransformationSequence] = pvt
                return SequenceItem(elements: elements)
            }
            ds.setSequence(perFrame, for: .perFrameFunctionalGroupsSequence)
        }
    }

    // Oracle: per-frame Frame VOI LUT / Pixel Value Transformation are read per
    // frame — the accessors, the one window policy the viewer/export/tiles share,
    // and the split output each see the frame's own window, not frame 0's.
    func testPerFrameWindowAndRescaleFollowTheFrame() async throws {
        let file = makeEnhancedCTWithPerFrameWindow(frames: 3)
        let ds = file.dataSet
        XCTAssertTrue(ds.hasPerFrameWindowOrRescale)
        XCTAssertFalse(makeEnhancedCT(frames: 2).dataSet.hasPerFrameWindowOrRescale,
                       "a shared window is not a per-frame window")

        // Accessors: frame-indexed → that frame; unindexed → first frame.
        XCTAssertEqual(ds.windowSettings(frameIndex: 2)?.center, 300)
        XCTAssertEqual(ds.windowSettings(frameIndex: 2)?.width, 600)
        XCTAssertEqual(ds.allWindowSettings(frameIndex: 1).first?.center, 200)
        XCTAssertEqual(ds.rescaleIntercept(frameIndex: 1), -1001)
        XCTAssertEqual(ds.windowSettings()?.center, 100)
        XCTAssertEqual(ds.rescaleIntercept(), -1000)
        XCTAssertEqual(ds.windowSettings(frameIndex: 99)?.center, nil,
                       "an out-of-range frame has no window of its own and there is no shared one")

        // The shared window policy converts each frame's HU window through that
        // frame's own rescale pair.
        let pixels = try XCTUnwrap(file.pixelData())
        let w0 = DICOMImageExporter.determineWindowSettings(from: file, pixelData: pixels, frameIndex: 0,
                                                            windowCenter: nil, windowWidth: nil)
        let w2 = DICOMImageExporter.determineWindowSettings(from: file, pixelData: pixels, frameIndex: 2,
                                                            windowCenter: nil, windowWidth: nil)
        XCTAssertEqual(w0.center, 100 + 1000)
        XCTAssertEqual(w0.width, 200)
        XCTAssertEqual(w2.center, 300 + 1002)
        XCTAssertEqual(w2.width, 600)

        // Split: every classic frame carries its own window and rescale.
        let (_, outputs) = try await split(file)
        XCTAssertEqual(outputs.count, 3)
        for (f, out) in outputs.enumerated() {
            let frameDS = out.dataSet
            XCTAssertEqual(frameDS.windowSettings()?.center, Double(100 * (f + 1)))
            XCTAssertEqual(frameDS.rescaleIntercept(), Double(-1000 - f))
        }
    }

    // Oracle: the {number:04d} width spec the help text advertises is honoured.
    func testNamingPatternWidthSpec() {
        XCTAssertEqual(FrameSplitter.expandPattern("f_{number:03d}_{modality}_{stack}_{instance}.dcm",
                                                   frameIndex: 7, instance: "8", stack: "2", modality: "CT", series: "1"),
                       "f_007_CT_2_8.dcm")
        XCTAssertEqual(FrameSplitter.expandPattern("{number}.dcm", frameIndex: 3, instance: "4", stack: "1", modality: "MR", series: "1"),
                       "0003.dcm")
    }

    // MARK: - Review-fix regressions (PR #207)

    // Oracle (PS3.3 C.11.2): a window needs BOTH center and width. A top-level
    // Window Center without a Window Width must not shadow the Frame VOI LUT
    // functional group.
    func testWindowCenterWithoutWidthFallsBackToFrameVOILUT() {
        var ds = makeEnhancedCT(frames: 1).dataSet
        ds.setString("100", for: .windowCenter, vr: .DS)
        ds[.windowWidth] = nil
        let settings = ds.allWindowSettings(frameIndex: 0)
        XCTAssertEqual(settings.map { $0.center }, [40], "shared Frame VOI LUT window")
        XCTAssertEqual(settings.map { $0.width }, [400])

        // A classic image with center-but-no-width (and no functional groups)
        // still has no usable window.
        var classic = makeGrayscale16(rows: 4, cols: 4, fillPattern: { _ in 1 }).dataSet
        classic.setString("100", for: .windowCenter, vr: .DS)
        classic[.windowWidth] = nil
        XCTAssertTrue(classic.allWindowSettings().isEmpty)
    }

    // Oracle (PS3.3 C.7.6.16): a concatenation part's Per-frame sequence has one
    // item per part frame. A source whose sequence is shorter than NumberOfFrames
    // must not leave the full-length sequence in a smaller part.
    func testConcatenationPartNeverKeepsOversizedPerFrameSequence() {
        var src = makeEnhancedCT(frames: 5).dataSet
        let items = Array(src[.perFrameFunctionalGroupsSequence]!.sequenceItems!.prefix(3))
        src.setSequence(items, for: .perFrameFunctionalGroupsSequence) // malformed: 3 items, 5 frames
        let parts = MultiframeConcatenation.parts(frameCount: 5, framesPerInstance: 2)
        for part in parts {
            let ds = MultiframeConcatenation.partDataSet(source: src, part: part,
                                                         concatenationUID: "1.2.3.4", vectorKind: .none)
            let count = ds[.perFrameFunctionalGroupsSequence]?.sequenceItems?.count ?? 0
            XCTAssertLessThanOrEqual(count, part.frames.count,
                                     "part \(part.index) must not describe more frames than it has")
        }
        // Last part (frame 4) has no item at all left: sequence removed, not oversized.
        let last = MultiframeConcatenation.partDataSet(source: src, part: parts[2],
                                                       concatenationUID: "1.2.3.4", vectorKind: .none)
        XCTAssertNil(last[.perFrameFunctionalGroupsSequence])
    }

    // Oracle: a merged object's Per-frame sequence length must equal NumberOfFrames.
    // When that cannot be built (mixed enhanced + classic inputs), the sequence is
    // dropped with a warning rather than left describing only the template's frames.
    func testStandardMergeDropsMismatchedPerFrameSequence() async throws {
        let enhanced = makeEnhancedCT(frames: 2)
        let classic = mutate(makeClassicCT(index: 2, value: 300, position: "0\\0\\3.0")) { ds in
            ds.setUInt16(12, for: .bitsStored)   // match makeEnhancedCT's Image Pixel module
            ds.setUInt16(11, for: .highBit)
        }
        var lines: [String] = []
        let merged = try await merge([enhanced, classic], format: .standard, sortBy: .none) { lines.append($0) }
        XCTAssertEqual(trimmed(merged.dataSet, .numberOfFrames), "3")
        XCTAssertNil(merged.dataSet[.perFrameFunctionalGroupsSequence],
                     "a 2-item sequence must not survive in a 3-frame object")
        XCTAssertTrue(lines.contains { $0.contains("dropped Per-frame Functional Groups") }, "warning emitted")
    }

    // Oracle: Acquisition Time is time-of-day; a cine crossing midnight has one
    // wrapped delta and still yields the true Frame Time. A genuinely out-of-order
    // sequence must abandon the derivation, not fabricate a day-long Frame Time.
    func testDerivedFrameTimeUnwrapsMidnightButNotDisorder() async throws {
        var options = MergeOptions()
        options.allowAnySource = true
        let midnight = ["235958", "235959", "000000"].enumerated().map { i, t in
            mutate(makeClassicCT(index: i, value: UInt16(100 + i), position: "0\\0\\\(Double(i))")) {
                $0.setString(t, for: .acquisitionTime, vr: .TM)
            }
        }
        let merged = try await merge(midnight, format: .scMultiframe, sortBy: .none, options: options)
        XCTAssertEqual(merged.dataSet[.frameTime]?.decimalStringValue?.value, 1000, "1 s steps across midnight")

        let disordered = ["100005", "100000", "100001"].enumerated().map { i, t in
            mutate(makeClassicCT(index: i, value: UInt16(100 + i), position: "0\\0\\\(Double(i))")) {
                $0.setString(t, for: .acquisitionTime, vr: .TM)
            }
        }
        let mergedDisordered = try await merge(disordered, format: .scMultiframe, sortBy: .none, options: options)
        XCTAssertNil(mergedDisordered.dataSet[.frameTime], "no plausible cine timing to derive")
    }

    // Oracle: a legacy vector shorter than the frame range is malformed; the
    // resolved frame must carry no value rather than another frame's value.
    func testLegacyVectorOutOfRangeDropsAttributeInsteadOfClamping() {
        var ds = DataSet()
        ds.setStrings(["10", "20", "30"], for: .frameTimeVector, vr: .DS)
        ds[.frameIncrementPointer] = DataElement(tag: .frameIncrementPointer, vr: .AT, length: 4,
                                                 valueData: DICOMWriter().serializeTag(.frameTimeVector))
        LegacyVectorResolver.resolve(&ds, frameIndex: 5, kind: .cine, mode: .classic)
        XCTAssertNil(ds[.frameTime], "frame 5 has no time in a 3-value vector")
        XCTAssertNil(ds[.frameTimeVector])
    }

    // Oracle: Series Number is study-scoped. Series minted for a source without
    // one must not take the low ordinals (1, 2, ...) existing series already use.
    func testMintedSeriesNumbersAvoidLowOrdinals() async throws {
        let src = mutate(makeEnhancedCT(frames: 2)) { $0[.seriesNumber] = nil }
        var options = SplitOptions()
        options.seriesGrouping = .stack
        let (_, files) = try await split(src, options: options)
        XCTAssertFalse(files.isEmpty)
        for out in files {
            let number = Int(trimmed(out.dataSet, .seriesNumber) ?? "") ?? 0
            XCTAssertGreaterThan(number, 100, "minted number must sit far from existing ordinals")
        }
    }

    // Oracle: merging parts that cover overlapping frame ranges of one
    // concatenation source duplicates frames; the standard path must say so.
    func testStandardMergeWarnsOnOverlappingConcatenationParts() async throws {
        let sourceUID = "1.2.3.4.5.999"
        func part(_ n: Int, offset: Int) -> DICOMFile {
            mutate(makeMultiFrame(rows: 4, cols: 4, frames: 2)) { ds in
                ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
                ds.setString("1.2.3.4.888", for: .concatenationUID, vr: .UI)
                ds.setUInt16(UInt16(n), for: .inConcatenationNumber)
                ds.setUInt16(3, for: .inConcatenationTotalNumber)
                ds.setUInt32(UInt32(offset), for: .concatenationFrameOffsetNumber)
                ds.setString(sourceUID, for: .sopInstanceUIDOfConcatenationSource, vr: .UI)
            }
        }
        // Two overlapping parts plus a non-part, so the standard path (not
        // concatenation reassembly) handles them.
        let files = [part(1, offset: 0), part(2, offset: 1),
                     mutate(makeMultiFrame(rows: 4, cols: 4, frames: 2)) { $0.setString(rtUID(), for: .sopInstanceUID, vr: .UI) }]
        var lines: [String] = []
        _ = try await merge(files, format: .standard, sortBy: .none) { lines.append($0) }
        XCTAssertTrue(lines.contains { $0.contains("overlapping frame ranges") }, "got: \(lines)")
    }
}

