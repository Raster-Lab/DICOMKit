//
// PseudoColorPresentationStateStoreTests.swift
// DICOMPrintKit
//
// The store-level half of the Pseudo-Color work: which IOD a saved view is
// written as, and — the scenario the whole feature exists for — whether the
// palette survives when only the DICOM travels.
//
// The sidecar cannot be assumed. A study exported to another system carries
// its .dcm files and nothing else, so these tests delete the sidecar on
// purpose and demand the palette back from the object alone. Before this work
// that read returned grey, which is exactly the bug being fixed.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PseudoColorPresentationStateStoreTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!

    private let studyUID = "1.2.3.4.5"
    private let seriesUID = "1.2.3.4.5.6"
    private let imageSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PseudoColorPSStoreTests-\(UUID().uuidString)")
        store = PresentationStateStore(root: root)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func context() -> PresentationStatePatientContext {
        PresentationStatePatientContext(
            patientName: "DOE^JANE",
            patientID: "12345",
            studyInstanceUID: studyUID)
    }

    private func image(
        _ sopInstanceUID: String,
        palette: PseudoColorPalette? = nil,
        invert: Bool = false,
        bitsStored: Int = 0,
        isSigned: Bool = false
    ) -> PresentationStateStore.ImageToSave {
        let presentation = ViewerPresentation(
            zoom: 1, viewportWidth: 800, viewportHeight: 600, invert: invert)
        let display = ViewerPresentationStateBridge.capture(
            presentation: presentation,
            windowCenter: 40,
            windowWidth: 400,
            imageWidth: 512,
            imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: imageSOPClass,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: seriesUID,
            display: display,
            palette: palette,
            bitsStored: bitsStored,
            isSigned: isSigned)
    }

    /// Every presentation state the store has on disk, wherever its per-study
    /// folder is — walked rather than assuming the exact layout.
    private func savedFiles() throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil)
        var urls: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "dcm" { urls.append(url) }
        }
        return urls
    }

    // MARK: - Which IOD gets written

    /// The save path must hand the image's depth to the builder: a 12-bit CT's
    /// coloured view needs a 4096-entry table (one entry per storable value)
    /// or a conforming viewer clamps nearly every pixel to the last entry and
    /// the export renders as a single colour. And the full-range table must
    /// still restore by name.
    func test_save_sizesThePaletteTableToTheImage() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .hotIron, bitsStored: 12)],
            label: "Deep", patient: context())

        let url = try XCTUnwrap(savedFiles().first)
        let file = try DICOMFile.read(from: url)
        let element = try XCTUnwrap(
            file.dataSet[.redPaletteColorLookupTableDescriptor])
        XCTAssertEqual(element.valueData, Data([0x00, 0x10, 0, 0, 8, 0]))
        XCTAssertEqual(
            try XCTUnwrap(file.dataSet[.redPaletteColorLookupTableData])
                .valueData.count,
            4096)
        // Not the Annex B table any more, so not the Annex B name.
        XCTAssertNil(file.dataSet.string(for: .paletteColorLookupTableUID))

        // Strip the sidecar so the palette can only come back from the DICOM.
        try? FileManager.default.removeItem(
            at: AnnotationSidecar.url(forStateAt: url))
        XCTAssertEqual(
            store.views(forStudy: studyUID).first?.states.first?.palette, .hotIron)
    }


    /// A coloured view leaves as Pseudo-Color (…11.3) — the class that can
    /// carry the table — and a plain view stays GSPS, the file every viewer
    /// already reads.
    func test_save_choosesTheIODPerImage() throws {
        try store.save(
            images: [
                image("1.2.3.4.5.6.1", palette: .hotIron),
                image("1.2.3.4.5.6.2"),
            ],
            label: "Mixed", patient: context())

        var classes: Set<String> = []
        for url in try savedFiles() {
            let file = try DICOMFile.read(from: url)
            classes.insert(file.dataSet.string(for: .sopClassUID) ?? "")
        }
        XCTAssertEqual(classes, [
            "1.2.840.10008.5.1.4.1.1.11.3",
            "1.2.840.10008.5.1.4.1.1.11.1",
        ])
    }

    /// An explicit grey palette is the absence of colour: it must not produce
    /// a Pseudo-Color object whose palette module says "grey, in colour".
    func test_save_greyPalettesStayGSPS() throws {
        try store.save(
            images: [
                image("1.2.3.4.5.6.1", palette: .grayscale),
                image("1.2.3.4.5.6.2", palette: .inverseGrayscale),
            ],
            label: "Grey", patient: context())

        for url in try savedFiles() {
            let file = try DICOMFile.read(from: url)
            XCTAssertEqual(
                file.dataSet.string(for: .sopClassUID),
                "1.2.840.10008.5.1.4.1.1.11.1")
        }
    }

    /// The written object satisfies our own IOD validator — the same standard
    /// another system will hold it to.
    func test_save_writesAValidPseudoColorObject() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .pet)],
            label: "PET", patient: context())

        let url = try XCTUnwrap(try savedFiles().first)
        let file = try DICOMFile.read(from: url)
        XCTAssertNotNil(file.dataSet[.iccProfile], "ICC Profile module is mandatory")
        XCTAssertNotNil(file.dataSet[.redPaletteColorLookupTableData])
        XCTAssertEqual(
            file.dataSet.string(for: .paletteColorLookupTableUID),
            "1.2.840.10008.1.5.2", "PET is a well-known palette and carries its UID")
        XCTAssertNil(
            file.dataSet[.presentationLUTShape],
            "the Softcopy Presentation LUT module is not part of this IOD")
    }

    // MARK: - Restoring without the sidecar

    /// The exported-study scenario, and the reason …11.3 is written at all:
    /// the sidecar did not travel, and the palette must come back from the
    /// object's own Palette Color LUT.
    func test_views_restorePaletteFromDICOMAlone() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .hotIron)],
            label: "Hot", patient: context())

        // Simulate the export: only the .dcm survives.
        for url in try savedFiles() {
            let sidecar = AnnotationSidecar.url(forStateAt: url)
            try? FileManager.default.removeItem(at: sidecar)
        }

        let views = store.views(forStudy: studyUID)
        XCTAssertEqual(views.count, 1)
        XCTAssertEqual(views.first?.states.first?.palette, .hotIron)
    }

    /// Same journey for a palette with no well-known UID: Viridis has only its
    /// table to be recognised by, which is what `PseudoColorPalette.matching`
    /// exists for.
    func test_views_restoreComputedPaletteFromTableAlone() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .viridis)],
            label: "Viridis", patient: context())

        for url in try savedFiles() {
            try? FileManager.default.removeItem(
                at: AnnotationSidecar.url(forStateAt: url))
        }

        XCTAssertEqual(
            store.views(forStudy: studyUID).first?.states.first?.palette, .viridis)
    }

    /// An inverted coloured view has its inversion baked into the table (the
    /// IOD has no INVERSE to send). The DICOM-only read must restore both the
    /// palette and the flip, or the view comes back a different picture.
    func test_views_restoreBakedInversionFromDICOMAlone() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .hotIron, invert: true)],
            label: "Hot inverted", patient: context())

        for url in try savedFiles() {
            try? FileManager.default.removeItem(
                at: AnnotationSidecar.url(forStateAt: url))
        }

        let state = try XCTUnwrap(store.views(forStudy: studyUID).first?.states.first)
        XCTAssertEqual(state.palette, .hotIron)
        XCTAssertEqual(state.state.presentationLUT, .inverse)
    }

    /// With the sidecar present it stays authoritative — it records the
    /// reader's actual choice, and must not be second-guessed by table
    /// recognition.
    func test_views_preferSidecarWhenPresent() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .jet)],
            label: "Jet", patient: context())

        XCTAssertEqual(
            store.views(forStudy: studyUID).first?.states.first?.palette, .jet)
    }

    // MARK: - Publishing

    /// The record of a published coloured view names the class actually
    /// written; calling it GSPS would misfile it in every index built on it.
    func test_publish_carriesThePseudoColorClass() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .hotIron)],
            label: "Hot", patient: context())

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PseudoColorPublish-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let series = try XCTUnwrap(store.publish(
            label: "Hot", studyInstanceUID: studyUID, into: folder))
        XCTAssertEqual(
            series.instances.first?.sopClassUID, "1.2.840.10008.5.1.4.1.1.11.3")

        // And the published object itself still carries its table.
        let published = try XCTUnwrap(series.instances.first?.url)
        let file = try DICOMFile.read(from: published)
        XCTAssertNotNil(file.dataSet.paletteColorLUT())
    }
}
