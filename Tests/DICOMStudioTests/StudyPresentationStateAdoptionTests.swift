// StudyPresentationStateAdoptionTests.swift
// DICOMStudioTests
//
// A study imported with a PR series in it, opened in the viewer.
//
// The library indexes the PR object like any other instance; what these
// tests cover is the step from there to the reader seeing it — adoption into
// the store from the library's index, the viewer listing and applying it,
// and the imported drawings being shown but not editable.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Study Presentation State Adoption Tests")
struct StudyPresentationStateAdoptionTests {

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    private static let sopUID = "1.2.3.4.5.6.7"
    private static let prSeriesUID = "1.2.3.4.5.99"
    private static let prSOPUID = "1.2.3.4.5.99.1"
    private static let ctSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    private struct Fixture {
        let folder: URL
        let library: LibraryModel
        let store: PresentationStateStore
        let imagePath: String
        let imageFile: DICOMFile
    }

    /// A study on disk and in the library: one CT image, and one GSPS another
    /// viewer wrote over it — a ruler with its label.
    private func makeStudy(indexDimensions: Bool = true) throws -> Fixture {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyPRAdoptionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let imageFile = DICOMFile.create(
            dataSet: DataSet(elements: [
                .string(tag: .sopClassUID, vr: .UI, value: Self.ctSOPClass),
                .string(tag: .sopInstanceUID, vr: .UI, value: Self.sopUID),
                .string(tag: .studyInstanceUID, vr: .UI, value: Self.studyUID),
                .string(tag: .seriesInstanceUID, vr: .UI, value: Self.seriesUID),
                .string(tag: .patientName, vr: .PN, value: "DOE^JANE"),
                DataElement.uint16(tag: .rows, value: 512),
                DataElement.uint16(tag: .columns, value: 512),
                .string(tag: .windowCenter, vr: .DS, value: "40"),
                .string(tag: .windowWidth, vr: .DS, value: "400")
            ]),
            sopClassUID: Self.ctSOPClass, sopInstanceUID: Self.sopUID)
        let imagePath = folder.appendingPathComponent("image.dcm")
        try imageFile.write().write(to: imagePath)

        let reference = DICOMKit.ReferencedImage(sopClassUID: Self.ctSOPClass, sopInstanceUID: Self.sopUID)
        let state = DICOMKit.GrayscalePresentationState(
            sopInstanceUID: Self.prSOPUID,
            presentationLabel: "Weasis measurements",
            presentationDescription: "Weasis measurements",
            referencedSeries: [DICOMKit.ReferencedSeries(
                seriesInstanceUID: Self.seriesUID, referencedImages: [reference])],
            voiLUT: .window(center: 300, width: 1500, explanation: nil, function: .linear),
            graphicLayers: [DICOMKit.GraphicLayer(name: "MEASURE", order: 1)],
            graphicAnnotations: [DICOMKit.GraphicAnnotation(
                layer: "MEASURE", referencedImages: [reference],
                graphicObjects: [DICOMKit.GraphicObject(
                    type: .polyline, data: [100, 100, 300, 100], filled: false, units: .pixel)],
                textObjects: [DICOMKit.TextObject(
                    text: "20.0 mm",
                    boundingBoxTopLeft: (column: 310, row: 90),
                    boundingBoxBottomRight: (column: 380, row: 110),
                    anchorPoint: nil, anchorPointVisible: false,
                    boundingBoxUnits: .pixel, anchorPointUnits: .pixel)])])
        let prDataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state,
            patient: PresentationStatePatientContext(
                patientName: "DOE^JANE", studyInstanceUID: Self.studyUID),
            seriesInstanceUID: Self.prSeriesUID, seriesNumber: 99)
        let prPath = folder.appendingPathComponent("pr.dcm")
        try DICOMFile.create(
            dataSet: prDataSet,
            sopClassUID: GrayscalePresentationStateBuilder.sopClassUID,
            sopInstanceUID: Self.prSOPUID,
            transferSyntaxUID: PresentationStateStore.transferSyntaxUID)
            .write().write(to: prPath)

        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: Self.studyUID))
        library.addSeries(SeriesModel(
            seriesInstanceUID: Self.seriesUID, studyInstanceUID: Self.studyUID,
            seriesNumber: 1, modality: "CT"))
        var image = InstanceModel(
            sopInstanceUID: Self.sopUID, sopClassUID: Self.ctSOPClass,
            seriesInstanceUID: Self.seriesUID, instanceNumber: 1, filePath: imagePath.path)
        if indexDimensions {
            image.rows = 512
            image.columns = 512
        }
        library.addInstance(image)
        library.addSeries(SeriesModel(
            seriesInstanceUID: Self.prSeriesUID, studyInstanceUID: Self.studyUID,
            seriesNumber: 99, modality: "PR"))
        library.addInstance(InstanceModel(
            sopInstanceUID: Self.prSOPUID,
            sopClassUID: GrayscalePresentationStateBuilder.sopClassUID,
            seriesInstanceUID: Self.prSeriesUID, instanceNumber: 1, filePath: prPath.path))

        let store = PresentationStateStore(root: folder.appendingPathComponent("Store"))
        return Fixture(folder: folder, library: library, store: store,
                       imagePath: imagePath.path, imageFile: imageFile)
    }

    private func makeViewer(_ fixture: Fixture) -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.dicomFile = fixture.imageFile
        viewModel.filePath = fixture.imagePath
        viewModel.sopInstanceUID = Self.sopUID
        viewModel.imageColumns = 512
        viewModel.imageRows = 512
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.presentationStateStore = fixture.store
        return viewModel
    }

    @Test("the study's PR object is adopted from the library's index")
    func testAdoptsFromLibrary() throws {
        let fixture = try makeStudy()
        defer { try? FileManager.default.removeItem(at: fixture.folder) }

        let result = StudyPresentationStateAdoption.adopt(
            studyUID: Self.studyUID, in: fixture.library, into: fixture.store)

        #expect(result.adopted.count == 1)
        let views = fixture.store.views(forStudy: Self.studyUID, image: Self.sopUID)
        #expect(views.count == 1)
        #expect(views.first?.isImported == true)
        #expect(views.first?.label == "Weasis measurements")
    }

    @Test("an image the index has no size for is measured from its header")
    func testReadsDimensionsWhenUnindexed() throws {
        let fixture = try makeStudy(indexDimensions: false)
        defer { try? FileManager.default.removeItem(at: fixture.folder) }

        let result = StudyPresentationStateAdoption.adopt(
            studyUID: Self.studyUID, in: fixture.library, into: fixture.store)

        #expect(result.adopted.count == 1)
        let stored = fixture.store.views(forStudy: Self.studyUID).first?.state(forImage: Self.sopUID)
        let ruler = stored?.annotationsByFrame(forImage: Self.sopUID)[0]?.first { $0.kind == .polyline }
        #expect(ruler?.points.first?.x ?? 0 == 100.0 / 512)
    }

    @Test("a study without a PR series touches nothing")
    func testNothingToAdopt() throws {
        let fixture = try makeStudy()
        defer { try? FileManager.default.removeItem(at: fixture.folder) }
        var library = fixture.library
        library.removeSeries(Self.prSeriesUID)

        let result = StudyPresentationStateAdoption.adopt(
            studyUID: Self.studyUID, in: library, into: fixture.store)

        #expect(result.adopted.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.store.directory(forStudy: Self.studyUID).path))
    }

    @Test("the viewer lists the imported view and applies it on arrival")
    func testViewerOffersAndAppliesIt() throws {
        let fixture = try makeStudy()
        defer { try? FileManager.default.removeItem(at: fixture.folder) }
        StudyPresentationStateAdoption.adopt(
            studyUID: Self.studyUID, in: fixture.library, into: fixture.store)
        let viewModel = makeViewer(fixture)

        viewModel.loadStudySeries(
            ViewerSeriesCatalog.entries(forStudy: Self.studyUID, in: fixture.library),
            studyUID: Self.studyUID)

        #expect(viewModel.savedViewsForCurrentImage.map(\.label) == ["Weasis measurements"])
        #expect(viewModel.savedViewsForCurrentImage.first?.isImported == true)
        // Applied on arrival, the way Weasis applies it: the state's window
        // is on screen and its drawings are on the image.
        #expect(viewModel.selectedPresentationStateLabel == "Weasis measurements")
        #expect(viewModel.windowCenter == 300)
        #expect(viewModel.windowWidth == 1500)
        let key = ImageAnnotationKey(filePath: fixture.imagePath, frameIndex: 0)
        let drawn = viewModel.printSelection.cellAnnotations[key] ?? []
        #expect(drawn.map(\.kind) == [.polyline, .text])
        #expect(drawn.allSatisfy { $0.isLocked })
        #expect(viewModel.savedViewSeriesUIDs.contains(Self.seriesUID))
    }

    @Test("imported drawings are shown but cannot be moved or reworded")
    func testImportedDrawingsAreLocked() throws {
        let fixture = try makeStudy()
        defer { try? FileManager.default.removeItem(at: fixture.folder) }
        StudyPresentationStateAdoption.adopt(
            studyUID: Self.studyUID, in: fixture.library, into: fixture.store)
        let viewModel = makeViewer(fixture)
        viewModel.loadStudySeries(
            ViewerSeriesCatalog.entries(forStudy: Self.studyUID, in: fixture.library),
            studyUID: Self.studyUID)
        let key = ImageAnnotationKey(filePath: fixture.imagePath, frameIndex: 0)
        let before = viewModel.printSelection.cellAnnotations[key] ?? []
        let label = try #require(before.first { $0.kind == .text })

        viewModel.moveDrawnAnnotation(label.id, dx: 0.2, dy: 0.2)
        viewModel.setDrawnAnnotationText("changed", id: label.id)

        let after = viewModel.printSelection.cellAnnotations[key] ?? []
        #expect(after == before)
    }
}
