// HangingProtocolServiceTests.swift
// DICOMStudioTests
//
// Tests for HangingProtocolService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("HangingProtocolService Matching Tests")
struct HangingProtocolServiceMatchingTests {

    @Test("Select CT protocol")
    func testSelectCT() {
        let service = HangingProtocolService()
        let result = service.selectProtocol(userProtocols: [], modality: "CT")
        #expect(result != nil)
        #expect(result?.matchingCriteria.modality == "CT")
    }

    @Test("Select MR protocol")
    func testSelectMR() {
        let service = HangingProtocolService()
        let result = service.selectProtocol(userProtocols: [], modality: "MR")
        #expect(result != nil)
    }

    @Test("No match for unknown modality")
    func testNoMatch() {
        let service = HangingProtocolService()
        let result = service.selectProtocol(userProtocols: [], modality: "XA")
        #expect(result == nil)
    }

    @Test("User protocols take priority")
    func testUserPriority() {
        let service = HangingProtocolService()
        let userProto = HangingProtocolModel(
            name: "My CT",
            layoutType: .twoByTwo,
            matchingCriteria: ProtocolMatchingCriteria(modality: "CT"),
            priority: 100,
            isUserDefined: true
        )
        let result = service.selectProtocol(userProtocols: [userProto], modality: "CT")
        #expect(result?.name == "My CT")
    }
}

@Suite("HangingProtocolService List Tests")
struct HangingProtocolServiceListTests {

    @Test("All protocols includes built-in")
    func testAllProtocols() {
        let service = HangingProtocolService()
        let all = service.allProtocols(userProtocols: [])
        #expect(!all.isEmpty)
    }

    @Test("Filter by modality")
    func testFilterByModality() {
        let service = HangingProtocolService()
        let all = service.allProtocols(userProtocols: [])
        let ctProtos = service.protocols(from: all, forModality: "CT")
        #expect(!ctProtos.isEmpty)
        #expect(ctProtos.allSatisfy { $0.matchingCriteria.modality?.uppercased() == "CT" })
    }
}

@Suite("HangingProtocolService Creation Tests")
struct HangingProtocolServiceCreationTests {

    @Test("Create user protocol")
    func testCreateUserProtocol() {
        let service = HangingProtocolService()
        let proto = service.createUserProtocol(
            name: "My Protocol",
            layoutType: .twoByTwo,
            modality: "CT",
            description: "Test protocol"
        )

        #expect(proto.name == "My Protocol")
        #expect(proto.layoutType == .twoByTwo)
        #expect(proto.isUserDefined)
        #expect(proto.priority == 100)
        #expect(proto.viewportDefinitions.count == 4)
        #expect(proto.matchingCriteria.modality == "CT")
    }

    @Test("Created protocol has correct viewport count")
    func testViewportCount() {
        let service = HangingProtocolService()
        let proto = service.createUserProtocol(name: "3x3", layoutType: .threeByThree, modality: "MR")
        #expect(proto.viewportDefinitions.count == 9)
    }
}

@Suite("HangingProtocolService Assignment Tests")
struct HangingProtocolServiceAssignmentTests {

    @Test("Assign series to viewports")
    func testAssignment() {
        let service = HangingProtocolService()
        let proto = HangingProtocolModel(
            name: "Test",
            layoutType: .twoByOne,
            viewportDefinitions: [
                ViewportDefinition(position: 0, selectionCriteria: ImageSelectionCriteria(modality: "CT")),
                ViewportDefinition(position: 1, selectionCriteria: ImageSelectionCriteria(modality: "MR"))
            ]
        )

        let series = [
            SeriesModel(seriesInstanceUID: "1", studyInstanceUID: "S1", modality: "CT"),
            SeriesModel(seriesInstanceUID: "2", studyInstanceUID: "S1", modality: "MR"),
            SeriesModel(seriesInstanceUID: "3", studyInstanceUID: "S1", modality: "US")
        ]

        let assignments = service.assignSeries(hangingProtocol: proto, availableSeries: series)
        #expect(assignments.count == 2)
        #expect(assignments[0].series?.modality == "CT")
        #expect(assignments[1].series?.modality == "MR")
    }

    @Test("Unmatched viewport gets nil")
    func testUnmatched() {
        let service = HangingProtocolService()
        let proto = HangingProtocolModel(
            name: "Test",
            layoutType: .single,
            viewportDefinitions: [
                ViewportDefinition(position: 0, selectionCriteria: ImageSelectionCriteria(modality: "NM"))
            ]
        )

        let series = [
            SeriesModel(seriesInstanceUID: "1", studyInstanceUID: "S1", modality: "CT")
        ]

        let assignments = service.assignSeries(hangingProtocol: proto, availableSeries: series)
        #expect(assignments[0].series == nil)
    }
}
