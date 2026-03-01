// HangingProtocolHelpersTests.swift
// DICOMStudioTests
//
// Tests for HangingProtocolHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("HangingProtocolHelpers Matching Tests")
struct HangingProtocolMatchingTests {

    @Test("Match by modality")
    func testModalityMatch() {
        let criteria = ProtocolMatchingCriteria(modality: "CT")
        let score = HangingProtocolHelpers.matchScore(
            criteria: criteria,
            modality: "CT",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )
        #expect(score == 10)
    }

    @Test("Modality mismatch returns 0")
    func testModalityMismatch() {
        let criteria = ProtocolMatchingCriteria(modality: "CT")
        let score = HangingProtocolHelpers.matchScore(
            criteria: criteria,
            modality: "MR",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )
        #expect(score == 0)
    }

    @Test("Case-insensitive modality match")
    func testCaseInsensitive() {
        let criteria = ProtocolMatchingCriteria(modality: "CT")
        let score = HangingProtocolHelpers.matchScore(
            criteria: criteria,
            modality: "ct",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )
        #expect(score == 10)
    }

    @Test("Multi-criteria matching")
    func testMultiCriteria() {
        let criteria = ProtocolMatchingCriteria(
            modality: "CT",
            bodyPartExamined: "CHEST",
            studyDescriptionPattern: "CT Chest"
        )
        let score = HangingProtocolHelpers.matchScore(
            criteria: criteria,
            modality: "CT",
            bodyPart: "CHEST",
            procedureCode: nil,
            studyDescription: "CT Chest with contrast",
            seriesDescription: nil
        )
        #expect(score == 18) // 10 (modality) + 5 (body part) + 3 (study desc)
    }

    @Test("No criteria matches with score 0")
    func testNoCriteria() {
        let criteria = ProtocolMatchingCriteria()
        let score = HangingProtocolHelpers.matchScore(
            criteria: criteria,
            modality: "CT",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )
        #expect(score == 0)
    }
}

@Suite("HangingProtocolHelpers Selection Tests")
struct HangingProtocolSelectionTests {

    @Test("Select best protocol by match score")
    func testBestProtocol() {
        let protocols = [
            HangingProtocolModel(
                name: "CT Standard",
                matchingCriteria: ProtocolMatchingCriteria(modality: "CT"),
                priority: 1
            ),
            HangingProtocolModel(
                name: "MR Standard",
                matchingCriteria: ProtocolMatchingCriteria(modality: "MR"),
                priority: 1
            )
        ]

        let selected = HangingProtocolHelpers.selectBestProtocol(
            from: protocols,
            modality: "CT",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )

        #expect(selected?.name == "CT Standard")
    }

    @Test("No matching protocol returns nil")
    func testNoMatch() {
        let protocols = [
            HangingProtocolModel(
                name: "CT Standard",
                matchingCriteria: ProtocolMatchingCriteria(modality: "CT")
            )
        ]

        let selected = HangingProtocolHelpers.selectBestProtocol(
            from: protocols,
            modality: "US",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )

        #expect(selected == nil)
    }

    @Test("Priority tiebreaker")
    func testPriorityTiebreaker() {
        let protocols = [
            HangingProtocolModel(
                name: "Low Priority",
                matchingCriteria: ProtocolMatchingCriteria(modality: "CT"),
                priority: 1
            ),
            HangingProtocolModel(
                name: "High Priority",
                matchingCriteria: ProtocolMatchingCriteria(modality: "CT"),
                priority: 10
            )
        ]

        let selected = HangingProtocolHelpers.selectBestProtocol(
            from: protocols,
            modality: "CT",
            bodyPart: nil,
            procedureCode: nil,
            studyDescription: nil,
            seriesDescription: nil
        )

        #expect(selected?.name == "High Priority")
    }
}

@Suite("HangingProtocolHelpers Series Selection Tests")
struct HangingProtocolSeriesTests {

    @Test("Filter series by modality")
    func testFilterByModality() {
        let series = [
            SeriesModel(seriesInstanceUID: "1", studyInstanceUID: "S1", modality: "CT"),
            SeriesModel(seriesInstanceUID: "2", studyInstanceUID: "S1", modality: "MR"),
            SeriesModel(seriesInstanceUID: "3", studyInstanceUID: "S1", modality: "CT")
        ]

        let criteria = ImageSelectionCriteria(modality: "CT")
        let result = HangingProtocolHelpers.matchingSeries(from: series, criteria: criteria)
        #expect(result.count == 2)
    }

    @Test("Filter series by description")
    func testFilterByDescription() {
        let series = [
            SeriesModel(seriesInstanceUID: "1", studyInstanceUID: "S1", modality: "MR", seriesDescription: "T1 SAG"),
            SeriesModel(seriesInstanceUID: "2", studyInstanceUID: "S1", modality: "MR", seriesDescription: "T2 AX"),
            SeriesModel(seriesInstanceUID: "3", studyInstanceUID: "S1", modality: "MR", seriesDescription: "T1 COR")
        ]

        let criteria = ImageSelectionCriteria(seriesDescription: "T1")
        let result = HangingProtocolHelpers.matchingSeries(from: series, criteria: criteria)
        #expect(result.count == 2)
    }

    @Test("No criteria returns all series")
    func testNoCriteria() {
        let series = [
            SeriesModel(seriesInstanceUID: "1", studyInstanceUID: "S1", modality: "CT"),
            SeriesModel(seriesInstanceUID: "2", studyInstanceUID: "S1", modality: "MR")
        ]

        let criteria = ImageSelectionCriteria()
        let result = HangingProtocolHelpers.matchingSeries(from: series, criteria: criteria)
        #expect(result.count == 2)
    }
}

@Suite("HangingProtocolHelpers Display Tests")
struct HangingProtocolDisplayTests {

    @Test("Layout labels")
    func testLayoutLabels() {
        #expect(HangingProtocolHelpers.layoutLabel(for: .single) == "Single")
        #expect(HangingProtocolHelpers.layoutLabel(for: .twoByTwo) == "2×2")
        #expect(HangingProtocolHelpers.layoutLabel(for: .threeByThree) == "3×3")
    }

    @Test("Layout system images are not empty")
    func testLayoutImages() {
        for layout in LayoutType.allCases {
            #expect(!HangingProtocolHelpers.layoutSystemImage(for: layout).isEmpty)
        }
    }
}

@Suite("HangingProtocolHelpers Built-in Protocols Tests")
struct HangingProtocolBuiltInTests {

    @Test("Built-in protocols exist")
    func testBuiltInExist() {
        #expect(!HangingProtocolHelpers.builtInProtocols.isEmpty)
    }

    @Test("CT Standard protocol exists")
    func testCTStandard() {
        let ct = HangingProtocolHelpers.builtInProtocols.first { $0.name == "CT Standard" }
        #expect(ct != nil)
        #expect(ct?.layoutType == .single)
    }

    @Test("MR Multi-Series protocol has 4 viewports")
    func testMRMultiSeries() {
        let mr = HangingProtocolHelpers.builtInProtocols.first { $0.name == "MR Multi-Series" }
        #expect(mr != nil)
        #expect(mr?.layoutType == .twoByTwo)
        #expect(mr?.viewportDefinitions.count == 4)
    }

    @Test("PET/CT Fusion protocol exists")
    func testPETCT() {
        let petct = HangingProtocolHelpers.builtInProtocols.first { $0.name == "PET/CT Fusion" }
        #expect(petct != nil)
        #expect(petct?.layoutType == .twoByOne)
    }
}
