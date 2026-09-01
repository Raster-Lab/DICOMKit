//
// WeasisApplyGateTests.swift
// DICOMPrintKit
//
// The store's published objects, run through a reimplementation of the gate
// Weasis puts between a presentation state and the "apply" button.
//
// Weasis shows a PR two ways, and they are gated differently. The
// series-thumbnail badge only needs the PR's Referenced Series Sequence to
// name the series — no patient check — so it appears for almost any PR that
// parses. The centre-panel button that actually *applies* the state is
// stricter (`DicomModel.getPrSpecialElements` → `PRSpecialElement
// .getPRSpecialElements` → `PrDicomObject.isImageFrameApplicable`, verified
// against Weasis master, Aug 2026):
//
//   1. The PR must file under the same patient. Weasis keys patients on
//      trim(PatientID) + trim(IssuerOfPatientID) + trim(upper(PatientName))
//      (`PatientComparator.buildPatientPseudoUID`), so a PR that drops any of
//      the three while the image carries it lands under a different patient —
//      badge on the series, no button on the image. This was a real field
//      failure, and it *looked* modality-correlated (MR and US multi-frame
//      studies broken, XA fine) because it tracked which scanner filled
//      Issuer of Patient ID, not the SOP class.
//   2. Referenced Series Sequence must name the image's series, its item's
//      Referenced Image Sequence must exist (`sequenceRequired=true`) and
//      name the image's SOP Instance UID, and Referenced Frame Number, when
//      present, must name the displayed frame (one-based).
//
// These tests run the store's real output — saved, published, and re-read
// from disk the way any viewer would — through that gate, for the shapes
// that failed in the field: an enhanced-multi-frame MR, a multi-frame US
// (coloured, so it leaves as a Pseudo-Color object), and the XA control.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class WeasisApplyGateTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!
    private var studyFolder: URL!

    private let studyUID = "1.2.3.4.5"

    private enum SOPClass {
        static let enhancedMR = "1.2.840.10008.5.1.4.1.1.4.1"
        static let ultrasoundMultiFrame = "1.2.840.10008.5.1.4.1.1.3.1"
        static let xaImage = "1.2.840.10008.5.1.4.1.1.12.1"
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("WeasisApplyGateTests-\(UUID().uuidString)")
        root = base.appendingPathComponent("store")
        studyFolder = base.appendingPathComponent("study")
        store = PresentationStateStore(root: root)
        try FileManager.default.createDirectory(
            at: studyFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        let base = root.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.removeItem(at: base)
        }
        try super.tearDownWithError()
    }

    // MARK: - The gate, as Weasis implements it

    /// `PatientComparator.buildPatientPseudoUID`, default configuration.
    ///
    /// dcm4che's `Attributes.getString` answers null for an absent *or empty*
    /// element, and Weasis then substitutes NO_VALUE for Patient ID and name
    /// (but the empty string for the issuer) before trimming. The exact
    /// NO_VALUE text does not matter to the gate — only that both sides of a
    /// comparison get the same treatment.
    private func weasisPatientPseudoUID(_ dataSet: DataSet) -> String {
        func read(_ tag: DICOMCore.Tag) -> String? {
            guard let value = dataSet.string(for: tag), !value.isEmpty else {
                return nil
            }
            return value
        }
        let noValue = "UNKNOWN"
        let patientID = (read(.patientID) ?? noValue)
            .trimmingCharacters(in: .whitespaces)
        let issuer = (read(.issuerOfPatientID) ?? "")
            .trimmingCharacters(in: .whitespaces)
        let name = (read(.patientName) ?? noValue)
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
        return patientID + issuer + name
    }

    /// `PrDicomObject.isImageFrameApplicable`: series UID, then SOP UID within
    /// a *required* Referenced Image Sequence, then the one-based frame when
    /// the item names frames at all.
    private func weasisReferenceGate(
        prDataSet: DataSet,
        imageSeriesUID: String,
        imageSOPUID: String,
        frame: Int
    ) -> Bool {
        guard let seriesItems = prDataSet.sequence(for: .referencedSeriesSequence)
        else { return false }
        for item in seriesItems
        where item.string(for: .seriesInstanceUID) == imageSeriesUID {
            // sequenceRequired=true: a series item without a Referenced Image
            // Sequence does not apply to anything in Weasis's reading.
            guard let imageItems = item[.referencedImageSequence]?.sequenceItems
            else { continue }
            for imageItem in imageItems
            where imageItem.string(for: .referencedSOPInstanceUID) == imageSOPUID {
                guard let frames = imageItem[.referencedFrameNumber]?
                    .integerStringValues?.map({ $0.value }),
                    !frames.isEmpty else { return true }
                if frames.contains(frame) { return true }
            }
        }
        return false
    }

    /// The whole gate: same patient, and the reference chain reaches the frame.
    private func weasisWouldOfferApply(
        prDataSet: DataSet,
        imageDataSet: DataSet,
        imageSeriesUID: String,
        imageSOPUID: String,
        frame: Int
    ) -> Bool {
        weasisPatientPseudoUID(prDataSet) == weasisPatientPseudoUID(imageDataSet)
            && weasisReferenceGate(
                prDataSet: prDataSet,
                imageSeriesUID: imageSeriesUID,
                imageSOPUID: imageSOPUID,
                frame: frame)
    }

    // MARK: - Fixtures

    /// The image side of the comparison: the attributes Weasis reads off the
    /// image when it builds the patient key and the applicability question.
    private func imageDataSet(
        sopClassUID: String,
        sopInstanceUID: String,
        seriesInstanceUID: String,
        numberOfFrames: Int,
        issuerOfPatientID: String?
    ) -> DataSet {
        var dataSet = DataSet()
        dataSet.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        dataSet.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        dataSet.setString(studyUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("Doe^Jane", for: .patientName, vr: .PN)
        dataSet.setString("PAT-7", for: .patientID, vr: .LO)
        if let issuerOfPatientID {
            dataSet.setString(issuerOfPatientID, for: .issuerOfPatientID, vr: .LO)
        }
        dataSet.setString(String(numberOfFrames), for: .numberOfFrames, vr: .IS)
        return dataSet
    }

    private func imageToSave(
        from imageDataSet: DataSet,
        seriesInstanceUID: String,
        numberOfFrames: Int,
        palette: PseudoColorPalette? = nil
    ) -> PresentationStateStore.ImageToSave {
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 1.5, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: imageDataSet.string(for: .sopClassUID) ?? "",
            sopInstanceUID: imageDataSet.string(for: .sopInstanceUID) ?? "",
            seriesInstanceUID: seriesInstanceUID,
            display: display,
            palette: palette,
            imageWidth: 512,
            imageHeight: 512,
            bitsStored: 12,
            numberOfFrames: numberOfFrames)
    }

    /// Saves a view of the image and publishes it, exactly the path the
    /// viewer's save takes, then reads the published object back from disk.
    private func publishedState(
        of imageDataSet: DataSet,
        seriesInstanceUID: String,
        numberOfFrames: Int,
        palette: PseudoColorPalette? = nil,
        label: String = "Bone window"
    ) throws -> DataSet {
        // The context the viewer builds: read off the image, as
        // `saveCurrentView` does — this is where the issuer travels or dies.
        let context = PresentationStatePatientContext.make(from: imageDataSet)
        try store.save(
            images: [imageToSave(
                from: imageDataSet,
                seriesInstanceUID: seriesInstanceUID,
                numberOfFrames: numberOfFrames,
                palette: palette)],
            label: label,
            patient: context)
        let series = try XCTUnwrap(try store.publish(
            label: label, studyInstanceUID: studyUID, into: studyFolder))
        let url = try XCTUnwrap(series.instances.first?.url)
        return try DICOMFile.read(from: url).dataSet
    }

    // MARK: - The shapes that failed in the field

    /// An enhanced-multi-frame MR whose scanner fills Issuer of Patient ID —
    /// the exact shape reported as "I can see the PR in Weasis but cannot
    /// apply it". The published state must pass the whole gate, on the first
    /// frame and the last.
    func test_enhancedMRMultiFrame_withIssuer_passesTheApplyGate() throws {
        let seriesUID = "1.2.3.4.5.10"
        let sopUID = "1.2.3.4.5.10.1"
        let image = imageDataSet(
            sopClassUID: SOPClass.enhancedMR,
            sopInstanceUID: sopUID,
            seriesInstanceUID: seriesUID,
            numberOfFrames: 120,
            issuerOfPatientID: "HOSP_A")

        let state = try publishedState(
            of: image, seriesInstanceUID: seriesUID, numberOfFrames: 120)

        for frame in [1, 60, 120] {
            XCTAssertTrue(
                weasisWouldOfferApply(
                    prDataSet: state, imageDataSet: image,
                    imageSeriesUID: seriesUID, imageSOPUID: sopUID, frame: frame),
                "GSPS must be applicable on frame \(frame)")
        }
    }

    /// A multi-frame US read through a colour palette leaves as a
    /// Pseudo-Color object. That builder delegates its patient module to the
    /// grayscale one, and this is the test that keeps it that way — a CSPS
    /// that dropped the issuer would show Weasis's badge and never its button.
    func test_usMultiFrame_colouredView_publishesCSPSThatPassesTheApplyGate() throws {
        let seriesUID = "1.2.3.4.5.20"
        let sopUID = "1.2.3.4.5.20.1"
        let image = imageDataSet(
            sopClassUID: SOPClass.ultrasoundMultiFrame,
            sopInstanceUID: sopUID,
            seriesInstanceUID: seriesUID,
            numberOfFrames: 76,
            issuerOfPatientID: "HOSP_B")

        let state = try publishedState(
            of: image, seriesInstanceUID: seriesUID, numberOfFrames: 76,
            palette: .hotIron)

        XCTAssertEqual(
            state.string(for: .sopClassUID),
            PseudoColorPresentationStateBuilder.sopClassUID,
            "A coloured view must leave as a Pseudo-Color object")
        XCTAssertTrue(
            weasisWouldOfferApply(
                prDataSet: state, imageDataSet: image,
                imageSeriesUID: seriesUID, imageSOPUID: sopUID, frame: 76))
    }

    /// The control: an XA cine from a source that fills no issuer — the case
    /// that always worked, and must keep working with the issuer now copied
    /// only when present (an empty element and an absent one both read back
    /// as no value in dcm4che, but absence keeps old exports byte-identical).
    func test_xaMultiFrame_withoutIssuer_passesTheApplyGate() throws {
        let seriesUID = "1.2.3.4.5.30"
        let sopUID = "1.2.3.4.5.30.1"
        let image = imageDataSet(
            sopClassUID: SOPClass.xaImage,
            sopInstanceUID: sopUID,
            seriesInstanceUID: seriesUID,
            numberOfFrames: 30,
            issuerOfPatientID: nil)

        let state = try publishedState(
            of: image, seriesInstanceUID: seriesUID, numberOfFrames: 30)

        XCTAssertNil(
            state[.issuerOfPatientID],
            "No issuer on the image means none written — absence, not emptiness")
        XCTAssertTrue(
            weasisWouldOfferApply(
                prDataSet: state, imageDataSet: image,
                imageSeriesUID: seriesUID, imageSOPUID: sopUID, frame: 15))
    }

    /// The failure mode itself, pinned: a state whose patient module lacks
    /// the issuer the image carries files under a different Weasis patient,
    /// even though its reference chain is perfect. This is what "I can view
    /// but not apply" looks like, and why the reference tests alone could
    /// never catch it.
    func test_stateWithoutTheImagesIssuer_failsThePatientGate() throws {
        let seriesUID = "1.2.3.4.5.40"
        let sopUID = "1.2.3.4.5.40.1"
        let image = imageDataSet(
            sopClassUID: SOPClass.enhancedMR,
            sopInstanceUID: sopUID,
            seriesInstanceUID: seriesUID,
            numberOfFrames: 12,
            issuerOfPatientID: "HOSP_A")

        // A context built the broken way: everything but the issuer.
        var context = PresentationStatePatientContext.make(from: image)
        context.issuerOfPatientID = nil
        try store.save(
            images: [imageToSave(
                from: image, seriesInstanceUID: seriesUID, numberOfFrames: 12)],
            label: "Legacy",
            patient: context)
        let series = try XCTUnwrap(try store.publish(
            label: "Legacy", studyInstanceUID: studyUID, into: studyFolder))
        let state = try DICOMFile.read(
            from: try XCTUnwrap(series.instances.first?.url)).dataSet

        XCTAssertTrue(
            weasisReferenceGate(
                prDataSet: state, imageSeriesUID: seriesUID,
                imageSOPUID: sopUID, frame: 1),
            "The reference chain is fine — that is exactly why this failure hides")
        XCTAssertFalse(
            weasisWouldOfferApply(
                prDataSet: state, imageDataSet: image,
                imageSeriesUID: seriesUID, imageSOPUID: sopUID, frame: 1),
            "Dropping the issuer must fail the patient gate, as it does in Weasis")
    }
}
