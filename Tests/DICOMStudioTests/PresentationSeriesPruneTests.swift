// PresentationSeriesPruneTests.swift
// DICOMStudioTests
//
// Whether deleting a study's saved views takes the "PR" series off the pane.
//
// The delete path removes the objects from the study's folder and tells the
// shell which SOP Instance UIDs went. The shell's job is to stop the library
// claiming a series is there — a card whose files are gone opens nothing, which
// is exactly what the reader saw: two "Presentation States" series listed after
// every saved view had been deleted.

import Testing
@testable import DICOMStudio
import DICOMKit
import Foundation

@Suite("Presentation Series Prune Tests")
@MainActor
struct PresentationSeriesPruneTests {

    private static let studyUID = "1.2.3.100"
    private static let imageSeriesUID = "1.2.3.100.1"
    private static let prSeriesUID = "1.2.3.100.9001"
    private static let otherPRSeriesUID = "1.2.3.100.9002"

    private static let gspsClass = GrayscalePresentationStateBuilder.sopClassUID
    private static let imageClass = "1.2.840.10008.5.1.4.1.1.2"

    private func makeViewModel() -> (MainViewModel, URL) {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("PRPrune-\(UUID().uuidString)", isDirectory: true)
        let storage = StorageService(baseDirectory: temp)
        let viewModel = MainViewModel(
            settingsService: SettingsService(),
            storageService: storage,
            libraryStorageService: LibraryStorageService(storageService: storage))
        return (viewModel, temp)
    }

    /// A library holding one image series and one or two PR series, with every
    /// PR object pointed at a file that does not exist — which is the state the
    /// index is in the moment after the delete path removes them.
    private func makeLibrary(extraPRSeries: Bool) -> LibraryModel {
        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: Self.studyUID))

        library.addSeries(SeriesModel(
            seriesInstanceUID: Self.imageSeriesUID,
            studyInstanceUID: Self.studyUID,
            seriesNumber: 1,
            modality: "CT"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "image-1",
            sopClassUID: Self.imageClass,
            seriesInstanceUID: Self.imageSeriesUID,
            instanceNumber: 1,
            filePath: "/nowhere/image-1.dcm"))

        library.addSeries(SeriesModel(
            seriesInstanceUID: Self.prSeriesUID,
            studyInstanceUID: Self.studyUID,
            seriesNumber: 9001,
            modality: "PR",
            seriesDescription: "Presentation States"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "pr-1",
            sopClassUID: Self.gspsClass,
            seriesInstanceUID: Self.prSeriesUID,
            instanceNumber: 1,
            filePath: "/nowhere/pr-1.dcm"))

        if extraPRSeries {
            // A second PR series of the same study — objects imported with the
            // study rather than published here. The delete names none of these,
            // which is precisely why the old prune left them standing.
            library.addSeries(SeriesModel(
                seriesInstanceUID: Self.otherPRSeriesUID,
                studyInstanceUID: Self.studyUID,
                seriesNumber: 9001,
                modality: "PR",
                seriesDescription: "Presentation States"))
            library.addInstance(InstanceModel(
                sopInstanceUID: "pr-2",
                sopClassUID: Self.gspsClass,
                seriesInstanceUID: Self.otherPRSeriesUID,
                instanceNumber: 1,
                filePath: "/nowhere/pr-2.dcm"))
        }

        return library
    }

    @Test("Deleting the last saved view removes its PR series")
    func deletingRemovesThePRSeries() throws {
        let (viewModel, temp) = makeViewModel()
        defer { try? FileManager.default.removeItem(at: temp) }
        viewModel.library = makeLibrary(extraPRSeries: false)

        viewModel.unregisterPresentationStates(sopInstanceUIDs: ["pr-1"])

        #expect(viewModel.library.series[Self.prSeriesUID] == nil,
                "an empty PR series is not a card the reader can open")
        #expect(viewModel.library.series[Self.imageSeriesUID] != nil,
                "the images it described are untouched")
    }

    @Test("Every emptied PR series of the study goes, not only the named one")
    func prunesEveryEmptiedPRSeries() throws {
        let (viewModel, temp) = makeViewModel()
        defer { try? FileManager.default.removeItem(at: temp) }
        viewModel.library = makeLibrary(extraPRSeries: true)

        // The delete names only the series it published into. The other PR
        // series' files are gone too — this is the study whose pane showed two
        // "Presentation States" cards after everything had been deleted.
        viewModel.unregisterPresentationStates(sopInstanceUIDs: ["pr-1"])

        #expect(viewModel.library.series[Self.prSeriesUID] == nil)
        #expect(viewModel.library.series[Self.otherPRSeriesUID] == nil,
                "a PR series with no files behind it is not shown either")
        #expect(viewModel.library.seriesForStudy(Self.studyUID).count == 1,
                "leaving the study its images and nothing else")
    }

    @Test("An image series with a missing file is not silently removed")
    func imageSeriesSurvivesAMissingFile() throws {
        let (viewModel, temp) = makeViewModel()
        defer { try? FileManager.default.removeItem(at: temp) }
        viewModel.library = makeLibrary(extraPRSeries: false)

        viewModel.unregisterPresentationStates(sopInstanceUIDs: ["pr-1"])

        // The image's file is missing too, and deliberately left alone: a study
        // whose images have gone is a fault to report, not a pane to quietly
        // empty.
        #expect(viewModel.library.instances["image-1"] != nil)
        #expect(viewModel.library.series[Self.imageSeriesUID] != nil)
    }

    @Test("A PR series whose files are still there stays")
    func presentPRSeriesStays() throws {
        let (viewModel, temp) = makeViewModel()
        defer { try? FileManager.default.removeItem(at: temp) }

        // A second PR series that really is on disk — the reader deleted one
        // saved view, not all of them.
        let present = temp.appendingPathComponent("pr-2.dcm")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try Data("not a real dcm".utf8).write(to: present)

        var library = makeLibrary(extraPRSeries: true)
        library.addInstance(InstanceModel(
            sopInstanceUID: "pr-2",
            sopClassUID: Self.gspsClass,
            seriesInstanceUID: Self.otherPRSeriesUID,
            instanceNumber: 1,
            filePath: present.path))
        viewModel.library = library

        viewModel.unregisterPresentationStates(sopInstanceUIDs: ["pr-1"])

        #expect(viewModel.library.series[Self.prSeriesUID] == nil,
                "the deleted view's series goes")
        #expect(viewModel.library.series[Self.otherPRSeriesUID] != nil,
                "the one still on disk stays")
    }
}
