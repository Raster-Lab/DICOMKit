//
// HangingProtocolMatcher.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Matcher for finding appropriate hanging protocols for studies
///
/// Evaluates study characteristics against hanging protocol environments
/// and selection criteria to determine which protocols are applicable.
public actor HangingProtocolMatcher {
    /// Available hanging protocols
    private var protocols: [HangingProtocol]
    
    public init(protocols: [HangingProtocol] = []) {
        self.protocols = protocols
    }
    
    // MARK: - Protocol Management
    
    /// Add a protocol to the available protocols
    public func add(protocol: HangingProtocol) {
        protocols.append(`protocol`)
    }
    
    /// Remove a protocol by name
    public func remove(protocolNamed name: String) {
        protocols.removeAll { $0.name == name }
    }
    
    /// Get all available protocols
    public func allProtocols() -> [HangingProtocol] {
        return protocols
    }
    
    // MARK: - Protocol Matching
    
    /// Find the best matching protocol for a study
    ///
    /// - Parameters:
    ///   - studyInfo: Study information for matching
    ///   - userGroup: Optional user group for user-specific protocols
    /// - Returns: Best matching protocol, or nil if no match found
    public func matchProtocol(
        for studyInfo: StudyInfo,
        userGroup: String? = nil
    ) -> HangingProtocol? {
        // Find all protocols that match the study
        let matches = matchingProtocols(for: studyInfo, userGroup: userGroup)
        
        // Return the highest priority match
        return matches.first
    }
    
    /// Find all matching protocols for a study, sorted by priority
    ///
    /// - Parameters:
    ///   - studyInfo: Study information for matching
    ///   - userGroup: Optional user group for user-specific protocols
    /// - Returns: Array of matching protocols, sorted by priority (user > group > site)
    public func matchingProtocols(
        for studyInfo: StudyInfo,
        userGroup: String? = nil
    ) -> [HangingProtocol] {
        var matches: [HangingProtocol] = []
        
        for `protocol` in protocols {
            // Check user group match
            if let userGroup = userGroup, !`protocol`.userGroups.isEmpty {
                guard `protocol`.userGroups.contains(userGroup) else {
                    continue
                }
            }
            
            // Check environment match
            if !`protocol`.environments.isEmpty {
                let environmentMatches = `protocol`.environments.contains { env in
                    matchesEnvironment(env, studyInfo: studyInfo)
                }
                
                guard environmentMatches else {
                    continue
                }
            }
            
            matches.append(`protocol`)
        }
        
        // Sort by priority: USER > GROUP > SITE
        matches.sort { lhs, rhs in
            priorityValue(for: lhs.level) > priorityValue(for: rhs.level)
        }
        
        return matches
    }
    
    // MARK: - Private Helpers
    
    private func matchesEnvironment(
        _ environment: HangingProtocolEnvironment,
        studyInfo: StudyInfo
    ) -> Bool {
        // Check modality match
        if let envModality = environment.modality {
            guard studyInfo.modalities.contains(envModality) else {
                return false
            }
        }
        
        // Check laterality match
        if let envLaterality = environment.laterality {
            guard studyInfo.laterality == envLaterality else {
                return false
            }
        }
        
        return true
    }
    
    private func priorityValue(for level: HangingProtocolLevel) -> Int {
        switch level {
        case .user: return 3
        case .group: return 2
        case .site: return 1
        }
    }
}

// MARK: - Study Info

/// Information about a study for protocol matching
public struct StudyInfo: Sendable {
    /// Study Instance UID
    public let studyInstanceUID: String
    
    /// Modalities present in the study
    public let modalities: Set<String>
    
    /// Anatomic laterality
    public let laterality: String?
    
    /// Study description
    public let studyDescription: String?
    
    /// Body part examined
    public let bodyPartExamined: String?
    
    /// Additional DICOM attributes for matching
    public let attributes: [Tag: String]
    
    public init(
        studyInstanceUID: String,
        modalities: Set<String> = [],
        laterality: String? = nil,
        studyDescription: String? = nil,
        bodyPartExamined: String? = nil,
        attributes: [Tag: String] = [:]
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.modalities = modalities
        self.laterality = laterality
        self.studyDescription = studyDescription
        self.bodyPartExamined = bodyPartExamined
        self.attributes = attributes
    }
    
    /// Create StudyInfo from a DICOM DataSet
    public init?(from dataSet: DataSet) {
        guard let studyUID = dataSet.string(for: .studyInstanceUID) else {
            return nil
        }
        
        self.studyInstanceUID = studyUID
        
        // Extract modality (may be from series)
        if let modality = dataSet.string(for: .modality) {
            self.modalities = [modality]
        } else {
            self.modalities = []
        }
        
        self.laterality = dataSet.string(for: .laterality)
        self.studyDescription = dataSet.string(for: .studyDescription)
        self.bodyPartExamined = dataSet.string(for: .bodyPartExamined)
        self.attributes = [:]
    }
}

// MARK: - Image Set Matcher

/// Matcher for selecting images based on image set selectors
public struct ImageSetMatcher {
    private let imageSet: ImageSetDefinition
    
    public init(imageSet: ImageSetDefinition) {
        self.imageSet = imageSet
    }
    
    /// Check if an instance matches the image set selectors
    ///
    /// - Parameter instance: Instance information to match
    /// - Returns: true if the instance matches all selectors
    public func matches(instance: InstanceInfo) -> Bool {
        for selector in imageSet.selectors {
            let matchResult = evaluateSelector(selector, instance: instance)
            
            switch selector.usageFlag {
            case .match:
                guard matchResult else { return false }
            case .noMatch:
                guard !matchResult else { return false }
            }
        }
        
        return true
    }
    
    private func evaluateSelector(
        _ selector: ImageSetSelector,
        instance: InstanceInfo
    ) -> Bool {
        guard let value = instance.attributes[selector.attribute] else {
            // Attribute not present
            if let op = selector.operator {
                return op == .notPresent
            }
            return false
        }
        
        // If operator specifies presence check
        if let op = selector.operator {
            switch op {
            case .present:
                return true
            case .notPresent:
                return false
            default:
                break
            }
        }
        
        // Check against selector values
        for selectorValue in selector.values {
            if matchesValue(value, selectorValue: selectorValue, operator: selector.operator) {
                return true
            }
        }
        
        return selector.values.isEmpty
    }
    
    private func matchesValue(
        _ value: String,
        selectorValue: String,
        operator: FilterOperator?
    ) -> Bool {
        guard let op = `operator` else {
            return value == selectorValue
        }
        
        switch op {
        case .equal:
            return value == selectorValue
        case .notEqual:
            return value != selectorValue
        case .lessThan:
            return value < selectorValue
        case .lessThanOrEqual:
            return value <= selectorValue
        case .greaterThan:
            return value > selectorValue
        case .greaterThanOrEqual:
            return value >= selectorValue
        case .contains:
            return value.contains(selectorValue)
        case .present, .notPresent:
            return true
        }
    }
}

// MARK: - Instance Info

/// Information about an instance for image set matching
public struct InstanceInfo: Sendable {
    /// SOP Instance UID
    public let sopInstanceUID: String
    
    /// Series Instance UID
    public let seriesInstanceUID: String
    
    /// DICOM attributes
    public let attributes: [Tag: String]
    
    public init(
        sopInstanceUID: String,
        seriesInstanceUID: String,
        attributes: [Tag: String] = [:]
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.attributes = attributes
    }
    
    /// Create InstanceInfo from a DICOM DataSet
    public init?(from dataSet: DataSet) {
        guard let sopUID = dataSet.string(for: .sopInstanceUID),
              let seriesUID = dataSet.string(for: .seriesInstanceUID) else {
            return nil
        }
        
        self.sopInstanceUID = sopUID
        self.seriesInstanceUID = seriesUID
        
        // Extract commonly used attributes
        var attrs: [Tag: String] = [:]
        if let instanceNumber = dataSet.string(for: .instanceNumber) {
            attrs[.instanceNumber] = instanceNumber
        }
        if let sliceLocation = dataSet.string(for: .sliceLocation) {
            attrs[.sliceLocation] = sliceLocation
        }
        
        self.attributes = attrs
    }
}
