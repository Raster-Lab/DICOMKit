// NEMA-verified: 2026a, checked 2026-09-29 — reads every CS term of PS3.3 2026a Tables C.23.1-1 / C.23.3-1 (Level, Selector Category, Filter-by Category/Presence/Operator, Sort-by Category, Layout Type, Scroll Types, Reformatting Type, Initial View Direction, 3D Rendering Type VM 1-n, Partial Data Display Handling top-level, YES/NO flags); Relative Time US VM 2 and Abstract Prior Value SS VM 2 per PS3.6 Table 6-1; the old DICOMKit spellings are mapped where a mapping exists
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
        let numberOfPriors = dataSet.uint16(for: .numberOfPriorsReferenced).map { Int($0) }
        
        // Parse environments
        let environments = try parseEnvironments(from: dataSet)
        
        // Parse user groups
        let userGroups = parseUserGroups(from: dataSet)
        
        // Parse image sets
        let imageSets = try parseImageSets(from: dataSet)
        
        // Parse display specification
        let numberOfScreens = dataSet.uint16(for: .numberOfScreens).map { Int($0) } ?? 1
        let screenDefinitions = try parseScreenDefinitions(from: dataSet)
        let displaySets = try parseDisplaySets(from: dataSet)

        // Partial Data Display Handling (0072,0208) - top-level Type 2 (PS3.3
        // Table C.23.3-1); earlier DICOMKit versions wrote it inside each
        // Display Sets Sequence item, which is still read as a fallback.
        var partialData = dataSet.string(for: .partialDataDisplayHandling)
            .flatMap { PartialDataDisplayHandling(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        if partialData == nil, let displaySetsSequence = dataSet.sequence(for: .displaySetsSequence) {
            partialData = displaySetsSequence.lazy
                .compactMap { $0.string(for: .partialDataDisplayHandling) }
                .compactMap { PartialDataDisplayHandling(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                .first
        }

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
            displaySets: displaySets,
            partialDataDisplayHandling: partialData
        )
    }
    
    // MARK: - Environment Parsing
    
    private func parseEnvironments(from dataSet: DataSet) throws -> [HangingProtocolEnvironment] {
        guard let envSequence = dataSet.sequence(for: .hangingProtocolDefinitionSequence) else {
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
            let number = imageSetItem[.imageSetNumber]?.uint16Value.map(Int.init) ?? (index + 1)
            let label = imageSetItem.string(for: .imageSetLabel)
            let selectors = try parseSelectors(from: imageSetItem)
            let sortOperations = parseSortOperations(from: imageSetItem)
            let category = imageSetItem.string(for: .imageSetSelectorCategory)
                .flatMap { ImageSetSelectorCategory.reading($0) }
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
    
    private func parseSelectors(from imageSetItem: SequenceItem) throws -> [ImageSetSelector] {
        guard let selectorSequence = imageSetItem[.imageSetSelectorSequence]?.sequenceItems else {
            return []
        }
        
        var selectors: [ImageSetSelector] = []
        
        for selectorItem in selectorSequence {
            // Parse the attribute tag from Selector Attribute (AT VR)
            guard let attributeElement = selectorItem[.selectorAttribute],
                  let attributeTag = try? Self.parseAttributeTag(from: attributeElement) else {
                continue
            }
            
            let valueNumber = selectorItem[.selectorValueNumber]?.uint16Value.map(Int.init)
            // Filter-by Operator (0072,0406): Table C.23.3-1 terms; EQUAL /
            // NOT_EQUAL / CONTAINS written by earlier DICOMKit versions map to
            // MEMBER_OF / NOT_MEMBER_OF, and PRESENT / NOT_PRESENT to
            // Filter-by Attribute Presence (0072,0404).
            let operatorString = selectorItem.string(for: .filterByOperator)
            let filterOperator = operatorString.flatMap { FilterOperator.reading($0) }
            let attributePresence = selectorItem.string(for: .filterByAttributePresence)
                .flatMap { FilterByAttributePresence(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                ?? operatorString.flatMap { FilterByAttributePresence(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
            let filterByCategory = selectorItem.string(for: .filterByCategory)
                .flatMap { FilterByCategory(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
            let sequencePointer = selectorItem[.selectorSequencePointer].flatMap { try? Self.parseAttributeTag(from: $0) }
            
            // Selector Attribute VR (0072,0050) names the Selector xx Value
            // element that carries the values (PS3.3 Table C.23.4-1). Without
            // it, take whichever Selector xx Value element is present; failing
            // that, the attribute's own tag, which is where DICOMKit wrote the
            // values before it followed the macro.
            var attributeVR = selectorItem.string(for: .selectorAttributeVR)
                .flatMap { VR(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
            var valueElement = attributeVR.flatMap { selectorItem[SelectorAttributeValueCoding.valueTag(for: $0)] }
            if valueElement == nil {
                valueElement = selectorItem.allElements
                    .filter { SelectorAttributeValueCoding.vr(forValueTag: $0.tag) != nil }
                    .min { $0.tag < $1.tag }
                if attributeVR == nil, let found = valueElement {
                    attributeVR = SelectorAttributeValueCoding.vr(forValueTag: found.tag)
                }
            }
            if valueElement == nil {
                valueElement = selectorItem[attributeTag]
            }
            
            var values: [String] = []
            var codeValues: [CodedConcept] = []
            if let valueElement {
                (values, codeValues) = SelectorAttributeValueCoding.decode(valueElement)
            }
            
            let usageFlagString = selectorItem.string(for: .imageSetSelectorUsageFlag)
            let usageFlag = usageFlagString.flatMap { SelectorUsageFlag(rawValue: $0) } ?? .match
            
            selectors.append(ImageSetSelector(
                attribute: attributeTag,
                attributeVR: attributeVR,
                sequencePointer: sequencePointer,
                valueNumber: valueNumber,
                operator: filterOperator,
                filterByCategory: filterByCategory,
                attributePresence: attributePresence,
                values: values,
                codeValues: codeValues,
                usageFlag: usageFlag
            ))
        }

        return selectors
    }
    
    private func parseSortOperations(from imageSetItem: SequenceItem) -> [SortOperation] {
        guard let sortSequence = imageSetItem[.sortingOperationsSequence]?.sequenceItems else {
            return []
        }
        
        var operations: [SortOperation] = []
        
        for sortItem in sortSequence {
            let directionString = sortItem.string(for: .sortingDirection)
            let direction = directionString.flatMap { SortDirection(rawValue: $0.trimmingCharacters(in: .whitespaces)) } ?? .ascending

            // Selector Attribute (0072,0026) + Selector Value Number (0072,0028)
            var attribute: Tag?
            if let attrElement = sortItem[.selectorAttribute] {
                attribute = try? Self.parseAttributeTag(from: attrElement)
            }
            let valueNumber = sortItem[.selectorValueNumber]?.integerValueTolerant

            // Sort-by Category (0072,0602): ALONG_AXIS / BY_ACQ_TIME (PS3.3
            // Table C.23.3-1). The spellings earlier DICOMKit versions wrote
            // map to a category or to the attribute they named.
            let categoryString = sortItem.string(for: .sortByCategory)?.trimmingCharacters(in: .whitespaces)
            var category: SortByCategory?
            switch categoryString {
            case nil, "ATTRIBUTE"?:
                category = nil
            case "ACQUISITION_TIME"?:
                category = .byAcquisitionTime
            case "IMAGE_POSITION"?:
                category = .alongAxis
            case "INSTANCE_NUMBER"?:
                attribute = attribute ?? .instanceNumber
            case "SLICE_LOCATION"?:
                attribute = attribute ?? .sliceLocation
            case let term?:
                category = SortByCategory(rawValue: term)
            }

            if let category {
                operations.append(SortOperation(sortByCategory: category, direction: direction))
            } else if let attribute {
                operations.append(SortOperation(
                    attribute: attribute,
                    valueNumber: max(1, valueNumber ?? 1),
                    direction: direction
                ))
            }
        }

        return operations
    }
    
    private func parseTimeSelection(from imageSetItem: SequenceItem) -> TimeBasedSelection? {
        // Relative Time (0072,0038) US VM 2; a single value written by an
        // earlier DICOMKit version reads as the pair n\n.
        var relativeTimeRange = imageSetItem[.relativeTime]?.integerValuesTolerant ?? []
        if relativeTimeRange.count == 1 { relativeTimeRange.append(relativeTimeRange[0]) }
        let relativeTimeUnitsString = imageSetItem.string(for: .relativeTimeUnits)
        let relativeTimeUnits = relativeTimeUnitsString.flatMap { RelativeTimeUnits(rawValue: $0.trimmingCharacters(in: .whitespaces)) }

        // Abstract Prior Value (0072,003C) SS VM 2 (PS3.6 Table 6-1). Earlier
        // DICOMKit versions wrote text (SH) such as MOST_RECENT / OLDEST, which
        // maps to 1\1 / -1\-1 (PS3.3 Table C.23.1-1).
        var abstractPriorRange: [Int] = []
        if let element = imageSetItem[.abstractPriorValue] {
            if let ints = element.integerValuesTolerant {
                abstractPriorRange = ints
            } else {
                abstractPriorRange = TimeBasedSelection.abstractPriorRange(from: element.stringValue)
            }
            if abstractPriorRange.count == 1 { abstractPriorRange.append(abstractPriorRange[0]) }
        }

        if !relativeTimeRange.isEmpty || relativeTimeUnits != nil || !abstractPriorRange.isEmpty {
            return TimeBasedSelection(
                relativeTimeRange: relativeTimeRange,
                relativeTimeUnits: relativeTimeUnits,
                abstractPriorRange: abstractPriorRange
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
            guard let verticalPixels = screenItem[.numberOfVerticalPixels]?.uint16Value.map(Int.init),
                  let horizontalPixels = screenItem[.numberOfHorizontalPixels]?.uint16Value.map(Int.init) else {
                continue
            }
            
            let spatialPosition = screenItem[.displayEnvironmentSpatialPosition]?.float64Values
            let minGrayscaleBitDepth = screenItem[.screenMinimumGrayscaleBitDepth]?.uint16Value.map(Int.init)
            let minColorBitDepth = screenItem[.screenMinimumColorBitDepth]?.uint16Value.map(Int.init)
            let maxRepaintTime = screenItem[.applicationMaximumRepaintTime]?.uint16Value.map(Int.init)
            
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
            let number = displaySetItem[.displaySetNumber]?.uint16Value.map(Int.init) ?? (index + 1)
            let label = displaySetItem.string(for: .displaySetLabel)
            let presentationGroup = displaySetItem[.displaySetPresentationGroup]?.uint16Value.map(Int.init)
            let groupDescription = displaySetItem.string(for: .displaySetPresentationGroupDescription)
            // Partial Data Display Handling (0072,0208) is read at the top
            // level into HangingProtocol.partialDataDisplayHandling.
            let scrollingGroup = displaySetItem[.displaySetScrollingGroup]?.uint16Value.map(Int.init)
            let imageBoxes = try parseImageBoxes(from: displaySetItem)
            let displayOptions = parseDisplayOptions(from: displaySetItem)

            displaySets.append(DisplaySet(
                number: number,
                label: label,
                presentationGroup: presentationGroup,
                presentationGroupDescription: groupDescription,
                scrollingGroup: scrollingGroup,
                imageBoxes: imageBoxes,
                displayOptions: displayOptions
            ))
        }
        
        return displaySets
    }
    
    private func parseImageBoxes(from displaySetItem: SequenceItem) throws -> [ImageBox] {
        guard let imageBoxSequence = displaySetItem[.imageBoxesSequence]?.sequenceItems else {
            return []
        }
        
        var imageBoxes: [ImageBox] = []
        
        for (index, boxItem) in imageBoxSequence.enumerated() {
            let number = boxItem[.imageBoxNumber]?.uint16Value.map(Int.init) ?? (index + 1)
            let layoutTypeString = boxItem.string(for: .imageBoxLayoutType)
            let layoutType = layoutTypeString.flatMap { ImageBoxLayoutType.reading($0) } ?? .stack
            
            // Parse referenced image set numbers
            let imageSetNumbers: [Int] = []
            // This would typically come from a reference sequence
            
            let tileHorizontal = boxItem[.imageBoxTileHorizontalDimension]?.uint16Value.map(Int.init)
            let tileVertical = boxItem[.imageBoxTileVerticalDimension]?.uint16Value.map(Int.init)
            
            let scrollDirectionString = boxItem.string(for: .imageBoxScrollDirection)
            let scrollDirection = scrollDirectionString.flatMap { ScrollDirection(rawValue: $0) }
            
            let smallScrollTypeString = boxItem.string(for: .imageBoxSmallScrollType)
            let smallScrollType = smallScrollTypeString.flatMap { ScrollType.reading($0) }
            let smallScrollAmount = boxItem[.imageBoxSmallScrollAmount]?.uint16Value.map(Int.init)
            
            let largeScrollTypeString = boxItem.string(for: .imageBoxLargeScrollType)
            let largeScrollType = largeScrollTypeString.flatMap { ScrollType.reading($0) }
            let largeScrollAmount = boxItem[.imageBoxLargeScrollAmount]?.uint16Value.map(Int.init)
            
            let overlapPriority = boxItem[.imageBoxOverlapPriority]?.uint16Value.map(Int.init)
            let cineRelative = boxItem[.cineRelativeToRealTime]?.float64Value
            
            let reformattingOp = parseReformattingOperation(from: boxItem)
            
            // 3D Rendering Type (0072,0520) VM 1-n: Value 1 a Defined Term,
            // the rest implementation specific sub-types (PS3.3 Table C.23.3-1)
            let renderingValues = (boxItem[.threeDRenderingType]?.stringValues ?? [])
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let renderingType = renderingValues.first.flatMap { ThreeDRenderingType(rawValue: $0) }
            let renderingSubtypes = renderingValues.count > 1 ? Array(renderingValues.dropFirst()) : []

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
                threeDRenderingType: renderingType,
                threeDRenderingSubtypes: renderingSubtypes
            ))
        }

        return imageBoxes
    }

    private func parseReformattingOperation(from boxItem: SequenceItem) -> ReformattingOperation? {
        // Reformatting Operation Type (0072,0510): MPR / 3D_RENDERING / SLAB;
        // CPR, MIP, MinIP, AvgIP written by earlier DICOMKit versions map to
        // MPR / 3D_RENDERING (see ReformattingType.reading).
        guard let typeString = boxItem.string(for: .reformattingOperationType),
              let type = ReformattingType.reading(typeString) else {
            return nil
        }

        let thickness = boxItem[.reformattingThickness]?.float64Value
        let interval = boxItem[.reformattingInterval]?.float64Value
        // Reformatting Operation Initial View Direction (0072,0516): SAGITTAL /
        // TRANSVERSE / CORONAL / OBLIQUE ("AXIAL" reads as TRANSVERSE)
        let initialViewPlane = boxItem.string(for: .reformattingOperationInitialViewDirection)
            .flatMap { ImagePlane.reading($0) }

        return ReformattingOperation(
            type: type,
            thickness: thickness,
            interval: interval,
            initialViewPlane: initialViewPlane
        )
    }
    
    private func parseDisplayOptions(from displaySetItem: SequenceItem) -> DisplayOptions {
        let patientOrientation = displaySetItem.string(for: .displaySetPatientOrientation)
        let voiType = displaySetItem.string(for: .voiType)
        let pseudoColorType = displaySetItem.string(for: .pseudoColorType)
        // PS3.3 Table C.23.3-1 enumerates YES / NO; "Y" / "N" written by earlier DICOMKit
        // versions are still read.
        func flag(_ tag: Tag) -> String? {
            displaySetItem.string(for: tag)?.trimmingCharacters(in: .whitespaces)
        }
        let showGrayscaleInverted = ["YES", "Y"].contains(flag(.showGrayscaleInverted) ?? "")
        let showImageTrueSize = ["YES", "Y"].contains(flag(.showImageTrueSizeFlag) ?? "")
        let showGraphicAnnotations = !["NO", "N"].contains(flag(.showGraphicAnnotationFlag) ?? "")
        let showPatientDemographics = !["NO", "N"].contains(flag(.showPatientDemographicsFlag) ?? "")
        let showAcquisitionTechniques = !["NO", "N"].contains(flag(.showAcquisitionTechniquesFlag) ?? "")
        
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
        guard let element = self[tag] else { return nil }
        return try? HangingProtocolParser.parseAttributeTag(from: element)
    }
}

private extension HangingProtocolParser {
    static func parseAttributeTag(from element: DataElement) throws -> Tag {
        let data = element.valueData
        
        // Parse tag from AttributeTag VR (group, element as UInt16 pairs)
        guard data.count >= 4 else {
            throw HangingProtocolError.parsingFailed("Invalid attribute tag data")
        }
        
        let group = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        let elementValue = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
        
        return Tag(group: group, element: elementValue)
    }
}
