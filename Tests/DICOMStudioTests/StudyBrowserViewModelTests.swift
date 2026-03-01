// StudyBrowserViewModelTests.swift
// DICOMStudioTests
//
// Tests for StudyBrowserViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("StudyBrowserViewModel Tests")
struct StudyBrowserViewModelTests {

    @Test("Default state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultState() {
        let vm = StudyBrowserViewModel()
        #expect(vm.library.studyCount == 0)
        #expect(vm.filter == .none)
        #expect(vm.sortField == .date)
        #expect(vm.sortDirection == .descending)
        #expect(vm.displayMode == .list)
        #expect(vm.selectedStudyUID == nil)
        #expect(vm.selectedSeriesUID == nil)
        #expect(!vm.isImporting)
        #expect(vm.lastError == nil)
    }

    @Test("Display studies returns empty for empty library")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDisplayStudiesEmpty() {
        let vm = StudyBrowserViewModel()
        #expect(vm.displayStudies.isEmpty)
    }

    @Test("Display studies returns filtered studies")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDisplayStudiesWithData() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            patientName: "DOE^JOHN",
            modalitiesInStudy: ["CT"]
        ))
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.4",
            studyID: "S2",
            patientName: "SMITH^JANE",
            modalitiesInStudy: ["MR"]
        ))
        let vm = StudyBrowserViewModel(library: library)
        #expect(vm.displayStudies.count == 2)
    }

    @Test("Filter reduces displayed studies")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilterReducesStudies() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.4",
            studyID: "S2",
            modalitiesInStudy: ["MR"]
        ))
        let vm = StudyBrowserViewModel(library: library)
        vm.filter.modalities = ["CT"]
        #expect(vm.displayStudies.count == 1)
    }

    @Test("Selected study series returns correct series")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedStudySeries() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        library.addSeries(SeriesModel(
            seriesInstanceUID: "1.2.3.1",
            studyInstanceUID: "1.2.3",
            modality: "CT"
        ))
        let vm = StudyBrowserViewModel(library: library)
        vm.selectedStudyUID = "1.2.3"
        #expect(vm.selectedStudySeries.count == 1)
    }

    @Test("Selected study series returns empty when no selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedStudySeriesNoSelection() {
        let vm = StudyBrowserViewModel()
        #expect(vm.selectedStudySeries.isEmpty)
    }

    @Test("Selected series instances returns correct instances")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedSeriesInstances() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        library.addSeries(SeriesModel(
            seriesInstanceUID: "1.2.3.1",
            studyInstanceUID: "1.2.3",
            modality: "CT"
        ))
        library.addInstance(InstanceModel(
            sopInstanceUID: "1.2.3.1.1",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm"
        ))
        let vm = StudyBrowserViewModel(library: library)
        vm.selectedSeriesUID = "1.2.3.1"
        #expect(vm.selectedSeriesInstances.count == 1)
    }

    @Test("Available modalities")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAvailableModalities() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        library.addStudy(StudyModel(
            studyInstanceUID: "2",
            studyID: "S2",
            modalitiesInStudy: ["MR"]
        ))
        let vm = StudyBrowserViewModel(library: library)
        #expect(vm.availableModalities.contains("CT"))
        #expect(vm.availableModalities.contains("MR"))
    }

    @Test("Toggle modality filter")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleModalityFilter() {
        let vm = StudyBrowserViewModel()
        vm.toggleModalityFilter("CT")
        #expect(vm.filter.modalities.contains("CT"))
        vm.toggleModalityFilter("CT")
        #expect(!vm.filter.modalities.contains("CT"))
    }

    @Test("Clear filters")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearFilters() {
        let vm = StudyBrowserViewModel()
        vm.filter.modalities = ["CT"]
        vm.filter.searchText = "test"
        vm.clearFilters()
        #expect(!vm.filter.isActive)
    }

    @Test("Toggle sort direction")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleSortDirection() {
        let vm = StudyBrowserViewModel()
        #expect(vm.sortDirection == .descending)
        vm.toggleSortDirection()
        #expect(vm.sortDirection == .ascending)
    }

    @Test("Toggle display mode")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleDisplayMode() {
        let vm = StudyBrowserViewModel()
        #expect(vm.displayMode == .list)
        vm.toggleDisplayMode()
        #expect(vm.displayMode == .grid)
        vm.toggleDisplayMode()
        #expect(vm.displayMode == .list)
    }

    @Test("Remove study clears selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveStudyClearsSelection() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        let vm = StudyBrowserViewModel(library: library)
        vm.selectedStudyUID = "1.2.3"
        vm.selectedSeriesUID = "1.2.3.1"
        vm.removeStudy("1.2.3")
        #expect(vm.selectedStudyUID == nil)
        #expect(vm.selectedSeriesUID == nil)
        #expect(vm.library.studyCount == 0)
    }

    @Test("Dependency injection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDependencyInjection() {
        let importSvc = ImportService()
        let vm = StudyBrowserViewModel(importService: importSvc)
        #expect(vm.importService === importSvc)
    }

    @Test("File importer initially not presented")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFileImporterInitialState() {
        let vm = StudyBrowserViewModel()
        #expect(vm.isFileImporterPresented == false)
    }

    @Test("Show file importer sets presented")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testShowFileImporter() {
        let vm = StudyBrowserViewModel()
        vm.showFileImporter()
        #expect(vm.isFileImporterPresented == true)
    }

    @Test("Toggle favorite on study")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleFavorite() {
        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        let vm = StudyBrowserViewModel(library: library)
        #expect(vm.isFavorite("1.2.3") == false)
        vm.toggleFavorite("1.2.3")
        #expect(vm.isFavorite("1.2.3") == true)
        vm.toggleFavorite("1.2.3")
        #expect(vm.isFavorite("1.2.3") == false)
    }

    @Test("Is favorite returns false for unknown study")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsFavoriteUnknown() {
        let vm = StudyBrowserViewModel()
        #expect(vm.isFavorite("nonexistent") == false)
    }
}

@Suite("TransferSyntaxDescriptions Tests")
struct TransferSyntaxDescriptionsTests {

    @Test("Known transfer syntax descriptions")
    func testKnownTransferSyntax() {
        #expect(TransferSyntaxDescriptions.describe("1.2.840.10008.1.2") == "Implicit VR Little Endian")
        #expect(TransferSyntaxDescriptions.describe("1.2.840.10008.1.2.1") == "Explicit VR Little Endian")
        #expect(TransferSyntaxDescriptions.describe("1.2.840.10008.1.2.4.50") == "JPEG Baseline (Process 1)")
        #expect(TransferSyntaxDescriptions.describe("1.2.840.10008.1.2.5") == "RLE Lossless")
    }

    @Test("Unknown transfer syntax")
    func testUnknownTransferSyntax() {
        let result = TransferSyntaxDescriptions.describe("1.2.3.4.5")
        #expect(result.contains("Unknown"))
        #expect(result.contains("1.2.3.4.5"))
    }

    @Test("Transfer syntax with whitespace trimmed")
    func testTransferSyntaxTrimmed() {
        let result = TransferSyntaxDescriptions.describe("  1.2.840.10008.1.2  ")
        #expect(result == "Implicit VR Little Endian")
    }
}
