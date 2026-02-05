//
// HangingProtocolMatcherTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class HangingProtocolMatcherTests: XCTestCase {
    
    // MARK: - HangingProtocolMatcher Tests
    
    func test_matcher_initialization_empty() async {
        let matcher = HangingProtocolMatcher()
        let protocols = await matcher.allProtocols()
        
        XCTAssertEqual(protocols.count, 0, "Should initialize with no protocols")
    }
    
    func test_matcher_initialization_withProtocols() async {
        let hangingProtocol = HangingProtocol(name: "Test")
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        let protocols = await matcher.allProtocols()
        
        XCTAssertEqual(protocols.count, 1, "Should initialize with provided protocols")
    }
    
    func test_matcher_addProtocol() async {
        let matcher = HangingProtocolMatcher()
        let hangingProtocol = HangingProtocol(name: "Test Protocol")
        
        await matcher.add(protocol: hangingProtocol)
        let protocols = await matcher.allProtocols()
        
        XCTAssertEqual(protocols.count, 1, "Should add protocol")
        XCTAssertEqual(protocols[0].name, "Test Protocol")
    }
    
    func test_matcher_removeProtocol() async {
        let hangingProtocol = HangingProtocol(name: "To Remove")
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        await matcher.remove(protocolNamed: "To Remove")
        let protocols = await matcher.allProtocols()
        
        XCTAssertEqual(protocols.count, 0, "Should remove protocol by name")
    }
    
    func test_matcher_removeNonexistentProtocol() async {
        let hangingProtocol = HangingProtocol(name: "Test")
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        await matcher.remove(protocolNamed: "Nonexistent")
        let protocols = await matcher.allProtocols()
        
        XCTAssertEqual(protocols.count, 1, "Should not remove if name doesn't match")
    }
    
    // MARK: - Protocol Matching Tests
    
    func test_matchProtocol_noEnvironments_matchesAll() async {
        let hangingProtocol = HangingProtocol(name: "Generic")
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["CT"])
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNotNil(match, "Protocol with no environments should match any study")
        XCTAssertEqual(match?.name, "Generic")
    }
    
    func test_matchProtocol_modalityMatch() async {
        let env = HangingProtocolEnvironment(modality: "CT")
        let hangingProtocol = HangingProtocol(name: "CT Protocol", environments: [env])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["CT"])
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNotNil(match, "Should match when modality matches")
        XCTAssertEqual(match?.name, "CT Protocol")
    }
    
    func test_matchProtocol_modalityMismatch() async {
        let env = HangingProtocolEnvironment(modality: "MR")
        let hangingProtocol = HangingProtocol(name: "MR Protocol", environments: [env])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["CT"])
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNil(match, "Should not match when modality doesn't match")
    }
    
    func test_matchProtocol_lateralityMatch() async {
        let env = HangingProtocolEnvironment(modality: "DX", laterality: "L")
        let hangingProtocol = HangingProtocol(name: "Left DX", environments: [env])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["DX"], laterality: "L")
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNotNil(match, "Should match when both modality and laterality match")
    }
    
    func test_matchProtocol_lateralityMismatch() async {
        let env = HangingProtocolEnvironment(modality: "DX", laterality: "R")
        let hangingProtocol = HangingProtocol(name: "Right DX", environments: [env])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["DX"], laterality: "L")
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNil(match, "Should not match when laterality doesn't match")
    }
    
    func test_matchProtocol_multipleEnvironments() async {
        let env1 = HangingProtocolEnvironment(modality: "CT")
        let env2 = HangingProtocolEnvironment(modality: "MR")
        let hangingProtocol = HangingProtocol(name: "Multi-Modal", environments: [env1, env2])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3", modalities: ["MR"])
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertNotNil(match, "Should match if any environment matches")
    }
    
    // MARK: - Priority Ordering Tests
    
    func test_matchProtocol_priorityOrdering_userOverGroup() async {
        let userProtocol = HangingProtocol(name: "User", level: .user)
        let groupProtocol = HangingProtocol(name: "Group", level: .group)
        let matcher = HangingProtocolMatcher(protocols: [groupProtocol, userProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertEqual(match?.name, "User", "User level should have priority over group")
    }
    
    func test_matchProtocol_priorityOrdering_groupOverSite() async {
        let siteProtocol = HangingProtocol(name: "Site", level: .site)
        let groupProtocol = HangingProtocol(name: "Group", level: .group)
        let matcher = HangingProtocolMatcher(protocols: [siteProtocol, groupProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertEqual(match?.name, "Group", "Group level should have priority over site")
    }
    
    func test_matchProtocol_priorityOrdering_userOverSite() async {
        let siteProtocol = HangingProtocol(name: "Site", level: .site)
        let userProtocol = HangingProtocol(name: "User", level: .user)
        let matcher = HangingProtocolMatcher(protocols: [siteProtocol, userProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let match = await matcher.matchProtocol(for: studyInfo)
        
        XCTAssertEqual(match?.name, "User", "User level should have priority over site")
    }
    
    // MARK: - User Group Matching Tests
    
    func test_matchProtocol_userGroupMatch() async {
        let hangingProtocol = HangingProtocol(name: "Radiology", userGroups: ["Radiology"])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let match = await matcher.matchProtocol(for: studyInfo, userGroup: "Radiology")
        
        XCTAssertNotNil(match, "Should match when user group matches")
    }
    
    func test_matchProtocol_userGroupMismatch() async {
        let hangingProtocol = HangingProtocol(name: "Radiology", userGroups: ["Radiology"])
        let matcher = HangingProtocolMatcher(protocols: [hangingProtocol])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let match = await matcher.matchProtocol(for: studyInfo, userGroup: "Cardiology")
        
        XCTAssertNil(match, "Should not match when user group doesn't match")
    }
    
    func test_matchingProtocols_returnsAllMatches() async {
        let `protocol1` = HangingProtocol(name: "Protocol 1", level: .site)
        let `protocol2` = HangingProtocol(name: "Protocol 2", level: .group)
        let matcher = HangingProtocolMatcher(protocols: [`protocol1`, `protocol2`])
        
        let studyInfo = StudyInfo(studyInstanceUID: "1.2.3")
        let matches = await matcher.matchingProtocols(for: studyInfo)
        
        XCTAssertEqual(matches.count, 2, "Should return all matching protocols")
    }
    
    // MARK: - StudyInfo Tests
    
    func test_studyInfo_initialization() {
        let studyInfo = StudyInfo(
            studyInstanceUID: "1.2.3.4",
            modalities: ["CT", "MR"],
            laterality: "L",
            studyDescription: "Chest CT",
            bodyPartExamined: "CHEST",
            attributes: [.patientName: "Doe^John"]
        )
        
        XCTAssertEqual(studyInfo.studyInstanceUID, "1.2.3.4")
        XCTAssertEqual(studyInfo.modalities.count, 2)
        XCTAssertTrue(studyInfo.modalities.contains("CT"))
        XCTAssertEqual(studyInfo.laterality, "L")
        XCTAssertEqual(studyInfo.studyDescription, "Chest CT")
        XCTAssertEqual(studyInfo.bodyPartExamined, "CHEST")
        XCTAssertEqual(studyInfo.attributes[.patientName], "Doe^John")
    }
    
    func test_studyInfo_fromDataSet() {
        var dataSet = DataSet()
        dataSet[.studyInstanceUID] = DataElement.string(tag: .studyInstanceUID, vr: .UI, value: "1.2.3.4")
        dataSet[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "CT")
        dataSet[.laterality] = DataElement.string(tag: .laterality, vr: .CS, value: "R")
        dataSet[.studyDescription] = DataElement.string(tag: .studyDescription, vr: .LO, value: "Brain MRI")
        
        let studyInfo = StudyInfo(from: dataSet)
        
        XCTAssertNotNil(studyInfo)
        XCTAssertEqual(studyInfo?.studyInstanceUID, "1.2.3.4")
        XCTAssertTrue(studyInfo?.modalities.contains("CT") ?? false)
        XCTAssertEqual(studyInfo?.laterality, "R")
        XCTAssertEqual(studyInfo?.studyDescription, "Brain MRI")
    }
    
    func test_studyInfo_fromDataSet_missingStudyUID() {
        let dataSet = DataSet()
        
        let studyInfo = StudyInfo(from: dataSet)
        
        XCTAssertNil(studyInfo, "Should return nil if Study Instance UID is missing")
    }
    
    // MARK: - ImageSetMatcher Tests
    
    func test_imageSetMatcher_matches_simpleSelector() {
        let selector = ImageSetSelector(attribute: .modality, values: ["CT"])
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.modality: "CT"]
        )
        
        XCTAssertTrue(matcher.matches(instance: instance), "Should match when attribute matches")
    }
    
    func test_imageSetMatcher_matches_mismatch() {
        let selector = ImageSetSelector(attribute: .modality, values: ["MR"])
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.modality: "CT"]
        )
        
        XCTAssertFalse(matcher.matches(instance: instance), "Should not match when attribute doesn't match")
    }
    
    func test_imageSetMatcher_matches_noMatchFlag() {
        let selector = ImageSetSelector(attribute: .modality, values: ["DX"], usageFlag: .noMatch)
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.modality: "CT"]
        )
        
        XCTAssertTrue(matcher.matches(instance: instance), "Should match when NO_MATCH flag and doesn't match")
    }
    
    func test_imageSetMatcher_matches_presentOperator() {
        let selector = ImageSetSelector(attribute: .sliceLocation, operator: .present, values: [])
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.sliceLocation: "100.5"]
        )
        
        XCTAssertTrue(matcher.matches(instance: instance), "Should match when attribute is present")
    }
    
    func test_imageSetMatcher_matches_notPresentOperator() {
        let selector = ImageSetSelector(attribute: .sliceLocation, operator: .notPresent, values: [])
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.modality: "CT"]
        )
        
        XCTAssertTrue(matcher.matches(instance: instance), "Should match when attribute is not present")
    }
    
    func test_imageSetMatcher_matches_containsOperator() {
        let selector = ImageSetSelector(attribute: .seriesDescription, operator: .contains, values: ["CHEST"])
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let matcher = ImageSetMatcher(imageSet: imageSet)
        
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2",
            attributes: [.seriesDescription: "CHEST CT ANGIO"]
        )
        
        XCTAssertTrue(matcher.matches(instance: instance), "Should match when value contains substring")
    }
    
    // MARK: - InstanceInfo Tests
    
    func test_instanceInfo_initialization() {
        let instance = InstanceInfo(
            sopInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4",
            attributes: [.instanceNumber: "1", .sliceLocation: "100.0"]
        )
        
        XCTAssertEqual(instance.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(instance.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(instance.attributes[.instanceNumber], "1")
        XCTAssertEqual(instance.attributes[.sliceLocation], "100.0")
    }
    
    func test_instanceInfo_fromDataSet() {
        var dataSet = DataSet()
        dataSet[.sopInstanceUID] = DataElement.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5")
        dataSet[.seriesInstanceUID] = DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: "1.2.3.4")
        dataSet[.instanceNumber] = DataElement.string(tag: .instanceNumber, vr: .IS, value: "1")
        
        let instance = InstanceInfo(from: dataSet)
        
        XCTAssertNotNil(instance)
        XCTAssertEqual(instance?.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(instance?.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(instance?.attributes[.instanceNumber], "1")
    }
    
    func test_instanceInfo_fromDataSet_missingRequiredFields() {
        var dataSet = DataSet()
        dataSet[.sopInstanceUID] = DataElement.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5")
        
        let instance = InstanceInfo(from: dataSet)
        
        XCTAssertNil(instance, "Should return nil if required fields are missing")
    }
}
