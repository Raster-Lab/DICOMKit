//
// HangingProtocolParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for Hanging Protocol DICOM objects
///
/// Parses DICOM Hanging Protocol IOD into HangingProtocol struct.
///
/// Reference: PS3.3 Section A.38 - Hanging Protocol IOD
public struct HangingProtocolParser {
    
    public init() {}
    
    /// Parse a Hanging Protocol from a DICOM DataSet
    ///
    /// - Parameter dataSet: DICOM DataSet containing hanging protocol
    /// - Returns: Parsed HangingProtocol, or nil if parsing fails
    /// - Throws: Error if required attributes are missing
    public func parse(from dataSet: DataSet) throws -> HangingProtocol {
        // Required: Hanging Protocol Name
        guard let name = dataSet.string(for: .hangingProtocolName) else {
            throw HangingProtocolError.missingRequiredAttribute("Hanging Protocol Name")
        }
        
        // Parse basic identification attributes
        let description = dataSet.string(for: .hangingProtocolDescription)
        let levelString = dataSet.string(for: .hangingProtocolLevel)
        let level = levelString.flatMap { HangingProtocolLevel(rawValue: $0) } ?? .user
        let creator = dataSet.string(for: .hangingProtocolCreator)
        let creationDateTime = dataSet.dateTime(for: .hangingProtocolCreationDateTime)
        let numberOfPriors = dataSet.integer(for: .numberOfPriorsReferenced)
        
        // Parse environments
        let environments = try parseEnvironments(from: dataSet)
        
        // Parse user groups
        let userGroups = parseUserGroups(from: dataSet)
        
        // Parse image sets
        let imageSets = try parseImageSets(from: dataSet)
        
        // Parse display specification
        let numberOfScreens = dataSet.integer(for: .numberOfScreens) ?? 1
        let screenDefinitions = try parseScreenDefinitions(from: dataSet)
        let displaySets = try parseDisplaySets(from: dataSet)
        
        return HangingProtocol(
            name: name,
            description: description,
            level: level,
            creator: creator,
            creationDateTime: creationDateTime,
            numberOfPriorsReferenced: numberOfPriors,
            environments: environments,
            userGroups: userGroups,
            imageSets: imageSets,
            numberOfScreens: numberOfScreens,
            screenDefinitions: screenDefinitions,
            displaySets: displaySets
        )
    }
    
    // MARK: - Environment Parsing
    
    private func parseEnvironments(from dataSet: DataSet) throws -> [HangingProtocolEnvironment] {
        guard let envSequence = dataSet.sequence(for: .hangingProtocolEnvironmentSequence) else {
            return []
        }
        
        var environments: [HangingProtocolEnvironment] = []
        
        for envItem in envSequence {
            let modality = envItem.string(for: .modality)
            let laterality = envItem.string(for: .laterality)
            
            environments.append(HangingProtocolEnvironment(
                modality: modality,
                laterality: laterality
            ))
        }
        
        return environments
    }
    
    // MARK: - User Group Parsing
    
    private func parseUserGroups(from dataSet: DataSet) -> [String] {
        var groups: [String] = []
        
        if let groupName = dataSet.string(for: .hangingProtocolUserGroupName) {
            groups.append(groupName)
        }
        
        return groups
    }
    
    // MARK: - Image Set Parsing
    
    private func parseImageSets(from dataSet: DataSet) throws -> [ImageSetDefinition] {
        guard let imageSetsSequence = dataSet.sequence(for: .imageSetsSequence) else {
            return []
        }
        
        var imageSets: [ImageSetDefinition] = []
        
        for (index, imageSetItem) in imageSetsSequence.enumerated() {
            let number = imageSetItem.integer(for: .imageSetNumber) ?? (index + 1)
            let label = imageSetItem.string(for: .imageSetLabel)
            let selectors = try parseSelectors(from: imageSetItem)
            let sortOperations = parseSortOperations(from: imageSetItem)
            let category = imageSetItem.string(for: .imageSetSelectorCategory)
                .flatMap { ImageSetSelectorCategory(rawValue: $0) }
            let timeSelection = parseTimeSelection(from: imageSetItem)
            
            imageSets.append(ImageSetDefinition(
                number: number,
                label: label,
                selectors: selectors,
                sortOperations: sortOperations,
                category: category,
                timeSelection: timeSelection
            ))
        }
        
        return imageSets
    }
    
    private func parseSelectors(from imageSetItem: DataSet) throws -> [ImageSetSelector] {
        guard let selectorSequence = imageSetItem.sequence(for: .selectorSequence) else {
            return []
        }
        
        var selectors: [ImageSetSelector] = []
        
        for selectorItem in selectorSequence {
            guard let attributeTag = selectorItem.tag(for: .selectorAttribute) else {
                continue
            }
            
            let valueNumber = selectorItem.integer(for: .selectorValueNumber)
            let operatorString = selectorItem.string(for: .filterByOperator)
            let filterOperator = operatorString.flatMap { FilterOperator(rawValue: $0) }
            
            // Parse selector values
            var values: [String] = []
            if let valueData = selectorItem.element(for: attributeTag) {
                if let strValue = try? valueData.string() {
                    values = strValue.components(separatedBy: "\\")
                }
            }
            
            let usageFlagString = selectorItem.string(for: .imageSetSelectorUsageFlag)
            let usageFlag = usageFlagString.flatMap { SelectorUsageFlag(rawValue: $0) } ?? .match
            
            selectors.append(ImageSetSelector(
                attribute: attributeTag,
                valueNumber: valueNumber,
                operator: filterOperator,
                values: values,
                usageFlag: usageFlag
            ))
        }
        
        return selectors
    }
    
    private func parseSortOperations(from imageSetItem: DataSet) -> [SortOperation] {
        guard let sortSequence = imageSetItem.sequence(for: .sortingOperationsSequence) else {
            return []
        }
        
        var operations: [SortOperation] = []
        
        for sortItem in sortSequence {
            guard let categoryString = sortItem.string(for: .sortByCategory),
                  let category = SortByCategory(rawValue: categoryString) else {
                continue
            }
            
            let directionString = sortItem.string(for: .sortingDirection)
            let direction = directionString.flatMap { SortDirection(rawValue: $0) } ?? .ascending
            let attribute = sortItem.tag(for: .selectorAttribute)
            
            operations.append(SortOperation(
                sortByCategory: category,
                direction: direction,
                attribute: attribute
            ))
        }
        
        return operations
    }
    
    private func parseTimeSelection(from imageSetItem: DataSet) -> TimeBasedSelection? {
        let relativeTime = imageSetItem.integer(for: .relativeTime)
        let relativeTimeUnitsString = imageSetItem.string(for: .relativeTimeUnits)
        let relativeTimeUnits = relativeTimeUnitsString.flatMap { RelativeTimeUnits(rawValue: $0) }
        let abstractPriorValue = imageSetItem.string(for: .abstractPriorValue)
        
        if relativeTime != nil || relativeTimeUnits != nil || abstractPriorValue != nil {
            return TimeBasedSelection(
                relativeTime: relativeTime,
                relativeTimeUnits: relativeTimeUnits,
                abstractPriorValue: abstractPriorValue
            )
        }
        
        return nil
    }
    
    // MARK: - Screen Definition Parsing
    
    private func parseScreenDefinitions(from dataSet: DataSet) throws -> [ScreenDefinition] {
        guard let screenSequence = dataSet.sequence(for: .nominalScreenDefinitionSequence) else {
            return []
        }
        
        var definitions: [ScreenDefinition] = []
        
        for screenItem in screenSequence {
            guard let verticalPixels = screenItem.integer(for: .numberOfVerticalPixels),
                  let horizontalPixels = screenItem.integer(for: .numberOfHorizontalPixels) else {
                continue
            }
            
            let spatialPosition = screenItem.doubles(for: .displayEnvironmentSpatialPosition)
            let minGrayscaleBitDepth = screenItem.integer(for: .screenMinimumGrayscaleBitDepth)
            let minColorBitDepth = screenItem.integer(for: .screenMinimumColorBitDepth)
            let maxRepaintTime = screenItem.integer(for: .applicationMaximumRepaintTime)
            
            definitions.append(ScreenDefinition(
                verticalPixels: verticalPixels,
                horizontalPixels: horizontalPixels,
                spatialPosition: spatialPosition,
                minimumGrayscaleBitDepth: minGrayscaleBitDepth,
                minimumColorBitDepth: minColorBitDepth,
                maximumRepaintTime: maxRepaintTime
            ))
        }
        
        return definitions
    }
    
    // MARK: - Display Set Parsing
    
    private func parseDisplaySets(from dataSet: DataSet) throws -> [DisplaySet] {
        guard let displaySetsSequence = dataSet.sequence(for: .displaySetsSequence) else {
            return []
        }
        
        var displaySets: [DisplaySet] = []
        
        for (index, displaySetItem) in displaySetsSequence.enumerated() {
            let number = displaySetItem.integer(for: .displaySetNumber) ?? (index + 1)
            let label = displaySetItem.string(for: .displaySetLabel)
            let presentationGroup = displaySetItem.integer(for: .displaySetPresentationGroup)
            let groupDescription = displaySetItem.string(for: .displaySetPresentationGroupDescription)
            let partialDataHandling = displaySetItem.string(for: .partialDataDisplayHandling)
            let scrollingGroup = displaySetItem.integer(for: .displaySetScrollingGroup)
            let imageBoxes = try parseImageBoxes(from: displaySetItem)
            let displayOptions = parseDisplayOptions(from: displaySetItem)
            
            displaySets.append(DisplaySet(
                number: number,
                label: label,
                presentationGroup: presentationGroup,
                presentationGroupDescription: groupDescription,
                partialDataHandling: partialDataHandling,
                scrollingGroup: scrollingGroup,
                imageBoxes: imageBoxes,
                displayOptions: displayOptions
            ))
        }
        
        return displaySets
    }
    
    private func parseImageBoxes(from displaySetItem: DataSet) throws -> [ImageBox] {
        guard let imageBoxSequence = displaySetItem.sequence(for: .imageBoxesSequence) else {
            return []
        }
        
        var imageBoxes: [ImageBox] = []
        
        for (index, boxItem) in imageBoxSequence.enumerated() {
            let number = boxItem.integer(for: .imageBoxNumber) ?? (index + 1)
            let layoutTypeString = boxItem.string(for: .imageBoxLayoutType)
            let layoutType = layoutTypeString.flatMap { ImageBoxLayoutType(rawValue: $0) } ?? .stack
            
            // Parse referenced image set numbers
            var imageSetNumbers: [Int] = []
            // This would typically come from a reference sequence
            
            let tileHorizontal = boxItem.integer(for: .imageBoxTileHorizontalDimension)
            let tileVertical = boxItem.integer(for: .imageBoxTileVerticalDimension)
            
            let scrollDirectionString = boxItem.string(for: .imageBoxScrollDirection)
            let scrollDirection = scrollDirectionString.flatMap { ScrollDirection(rawValue: $0) }
            
            let smallScrollTypeString = boxItem.string(for: .imageBoxSmallScrollType)
            let smallScrollType = smallScrollTypeString.flatMap { ScrollType(rawValue: $0) }
            let smallScrollAmount = boxItem.integer(for: .imageBoxSmallScrollAmount)
            
            let largeScrollTypeString = boxItem.string(for: .imageBoxLargeScrollType)
            let largeScrollType = largeScrollTypeString.flatMap { ScrollType(rawValue: $0) }
            let largeScrollAmount = boxItem.integer(for: .imageBoxLargeScrollAmount)
            
            let overlapPriority = boxItem.integer(for: .imageBoxOverlapPriority)
            let cineRelative = boxItem.double(for: .cineRelativeToRealTime)
            
            let reformattingOp = parseReformattingOperation(from: boxItem)
            
            let renderingTypeString = boxItem.string(for: .threeDRenderingType)
            let renderingType = renderingTypeString.flatMap { ThreeDRenderingType(rawValue: $0) }
            
            imageBoxes.append(ImageBox(
                number: number,
                layoutType: layoutType,
                imageSetNumbers: imageSetNumbers,
                tileHorizontalDimension: tileHorizontal,
                tileVerticalDimension: tileVertical,
                scrollDirection: scrollDirection,
                smallScrollType: smallScrollType,
                smallScrollAmount: smallScrollAmount,
                largeScrollType: largeScrollType,
                largeScrollAmount: largeScrollAmount,
                overlapPriority: overlapPriority,
                cineRelativeToRealTime: cineRelative,
                reformattingOperation: reformattingOp,
                threeDRenderingType: renderingType
            ))
        }
        
        return imageBoxes
    }
    
    private func parseReformattingOperation(from boxItem: DataSet) -> ReformattingOperation? {
        guard let typeString = boxItem.string(for: .reformattingOperationType),
              let type = ReformattingType(rawValue: typeString) else {
            return nil
        }
        
        let thickness = boxItem.double(for: .reformattingThickness)
        let interval = boxItem.double(for: .reformattingInterval)
        let initialViewDirection = boxItem.string(for: .reformattingOperationInitialViewDirection)
        
        return ReformattingOperation(
            type: type,
            thickness: thickness,
            interval: interval,
            initialViewDirection: initialViewDirection
        )
    }
    
    private func parseDisplayOptions(from displaySetItem: DataSet) -> DisplayOptions {
        let patientOrientation = displaySetItem.string(for: .displaySetPatientOrientation)
        let voiType = displaySetItem.string(for: .voiType)
        let pseudoColorType = displaySetItem.string(for: .pseudoColorType)
        let showGrayscaleInverted = displaySetItem.string(for: .showGrayscaleInverted) == "Y"
        let showImageTrueSize = displaySetItem.string(for: .showImageTrueSizeFlag) == "Y"
        let showGraphicAnnotations = displaySetItem.string(for: .showGraphicAnnotationFlag) != "N"
        let showPatientDemographics = displaySetItem.string(for: .showPatientDemographicsFlag) != "N"
        let showAcquisitionTechniques = displaySetItem.string(for: .showAcquisitionTechniquesFlag) != "N"
        
        let horizJustString = displaySetItem.string(for: .displaySetHorizontalJustification)
        let horizJust = horizJustString.flatMap { Justification(rawValue: $0) }
        
        let vertJustString = displaySetItem.string(for: .displaySetVerticalJustification)
        let vertJust = vertJustString.flatMap { Justification(rawValue: $0) }
        
        return DisplayOptions(
            patientOrientation: patientOrientation,
            voiType: voiType,
            pseudoColorType: pseudoColorType,
            showGrayscaleInverted: showGrayscaleInverted,
            showImageTrueSize: showImageTrueSize,
            showGraphicAnnotations: showGraphicAnnotations,
            showPatientDemographics: showPatientDemographics,
            showAcquisitionTechniques: showAcquisitionTechniques,
            horizontalJustification: horizJust,
            verticalJustification: vertJust
        )
    }
}

// MARK: - Errors

public enum HangingProtocolError: Error, LocalizedError {
    case missingRequiredAttribute(String)
    case invalidAttributeValue(String)
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredAttribute(let attr):
            return "Missing required attribute: \(attr)"
        case .invalidAttributeValue(let attr):
            return "Invalid attribute value: \(attr)"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        }
    }
}

// MARK: - DataSet Extensions

private extension DataSet {
    func tag(for tag: Tag) -> Tag? {
        guard let element = element(for: tag),
              let data = try? element.data() else {
            return nil
        }
        
        // Parse tag from AttributeTag VR (group, element as UInt16 pairs)
        guard data.count >= 4 else { return nil }
        
        let group = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        let element = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
        
        return Tag(group: group, element: element)
    }
}
