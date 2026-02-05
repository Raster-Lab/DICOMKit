//
// HangingProtocolSerializer.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Serializer for Hanging Protocol DICOM objects
///
/// Serializes HangingProtocol struct into DICOM DataSet format.
///
/// Reference: PS3.3 Section A.38 - Hanging Protocol IOD
/// Reference: PS3.3 Section C.23 - Hanging Protocol Modules
public struct HangingProtocolSerializer {
    
    public init() {}
    
    /// Serialize a HangingProtocol to a DICOM DataSet
    ///
    /// - Parameter protocol: HangingProtocol to serialize
    /// - Returns: DICOM DataSet containing hanging protocol
    /// - Throws: Error if required attributes are missing
    public func serialize(protocol hangingProtocol: HangingProtocol) throws -> DataSet {
        var dataSet = DataSet()
        
        // MARK: - Hanging Protocol Definition Module (C.23.1)
        
        // Hanging Protocol Name (0072,0002) - Required, Type 1
        dataSet[.hangingProtocolName] = DataElement.string(
            tag: .hangingProtocolName,
            vr: .LO,
            value: hangingProtocol.name
        )
        
        // Hanging Protocol Description (0072,0004) - Optional, Type 3
        if let description = hangingProtocol.description {
            dataSet[.hangingProtocolDescription] = DataElement.string(
                tag: .hangingProtocolDescription,
                vr: .ST,
                value: description
            )
        }
        
        // Hanging Protocol Level (0072,0006) - Required, Type 1
        dataSet[.hangingProtocolLevel] = DataElement.string(
            tag: .hangingProtocolLevel,
            vr: .CS,
            value: hangingProtocol.level.rawValue
        )
        
        // Hanging Protocol Creator (0072,0008) - Optional, Type 3
        if let creator = hangingProtocol.creator {
            dataSet[.hangingProtocolCreator] = DataElement.string(
                tag: .hangingProtocolCreator,
                vr: .LO,
                value: creator
            )
        }
        
        // Hanging Protocol Creation DateTime (0072,000A) - Optional, Type 3
        if let creationDateTime = hangingProtocol.creationDateTime {
            dataSet[.hangingProtocolCreationDateTime] = DataElement.string(
                tag: .hangingProtocolCreationDateTime,
                vr: .DT,
                value: creationDateTime.description
            )
        }
        
        // Number of Priors Referenced (0072,000E) - Optional, Type 3
        if let numberOfPriors = hangingProtocol.numberOfPriorsReferenced {
            dataSet[.numberOfPriorsReferenced] = DataElement.uint16(
                tag: .numberOfPriorsReferenced,
                value: UInt16(numberOfPriors)
            )
        }
        
        // MARK: - Hanging Protocol Environment Module (C.23.2)
        
        // Hanging Protocol Environment Sequence (0072,0010) - Optional, Type 3
        if !hangingProtocol.environments.isEmpty {
            let environmentItems = serializeEnvironments(hangingProtocol.environments)
            dataSet.setSequence(environmentItems, for: .hangingProtocolEnvironmentSequence)
        }
        
        // MARK: - Hanging Protocol User Identification Module (C.23.3)
        
        // Hanging Protocol User Group Name (0072,0016) - Optional, Type 3
        if !hangingProtocol.userGroups.isEmpty {
            // Serialize first user group (DICOM allows only one in practice)
            if let firstGroup = hangingProtocol.userGroups.first {
                dataSet[.hangingProtocolUserGroupName] = DataElement.string(
                    tag: .hangingProtocolUserGroupName,
                    vr: .LO,
                    value: firstGroup
                )
            }
        }
        
        // MARK: - Image Set Selector Module (C.23.4)
        
        // Image Sets Sequence (0072,0020) - Conditional, Type 1C
        if !hangingProtocol.imageSets.isEmpty {
            let imageSetItems = try serializeImageSets(hangingProtocol.imageSets)
            dataSet.setSequence(imageSetItems, for: .imageSetsSequence)
        }
        
        // MARK: - Display Set Presentation Module (C.23.5)
        
        // Number of Screens (0072,0100) - Required, Type 1
        dataSet[.numberOfScreens] = DataElement.uint16(
            tag: .numberOfScreens,
            value: UInt16(hangingProtocol.numberOfScreens)
        )
        
        // Nominal Screen Definition Sequence (0072,0102) - Optional, Type 3
        if !hangingProtocol.screenDefinitions.isEmpty {
            let screenItems = serializeScreenDefinitions(hangingProtocol.screenDefinitions)
            dataSet.setSequence(screenItems, for: .nominalScreenDefinitionSequence)
        }
        
        // MARK: - Display Set Specification Module (C.23.6)
        
        // Display Sets Sequence (0072,0200) - Required, Type 1
        if !hangingProtocol.displaySets.isEmpty {
            let displaySetItems = try serializeDisplaySets(hangingProtocol.displaySets)
            dataSet.setSequence(displaySetItems, for: .displaySetsSequence)
        }
        
        return dataSet
    }
    
    // MARK: - Environment Serialization
    
    private func serializeEnvironments(_ environments: [HangingProtocolEnvironment]) -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for environment in environments {
            var elements: [DataElement] = []
            
            // Modality (0008,0060) - Optional, Type 3
            if let modality = environment.modality {
                elements.append(DataElement.string(
                    tag: .modality,
                    vr: .CS,
                    value: modality
                ))
            }
            
            // Laterality (0020,0060) - Optional, Type 3
            if let laterality = environment.laterality {
                elements.append(DataElement.string(
                    tag: .laterality,
                    vr: .CS,
                    value: laterality
                ))
            }
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    // MARK: - Image Set Serialization
    
    private func serializeImageSets(_ imageSets: [ImageSetDefinition]) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for imageSet in imageSets {
            var elements: [DataElement] = []
            
            // Image Set Number (0072,0032) - Required, Type 1
            elements.append(DataElement.uint16(
                tag: .imageSetNumber,
                value: UInt16(imageSet.number)
            ))
            
            // Image Set Label (0072,0040) - Optional, Type 3
            if let label = imageSet.label {
                elements.append(DataElement.string(
                    tag: .imageSetLabel,
                    vr: .LO,
                    value: label
                ))
            }
            
            // Image Set Selector Category (0072,0034) - Optional, Type 3
            if let category = imageSet.category {
                elements.append(DataElement.string(
                    tag: .imageSetSelectorCategory,
                    vr: .CS,
                    value: category.rawValue
                ))
            }
            
            // Selector Sequence (0072,0050) - Conditional, Type 1C
            if !imageSet.selectors.isEmpty {
                let selectorItems = try serializeSelectors(imageSet.selectors)
                let selectorSequence = createSequenceElement(
                    tag: .selectorSequence,
                    items: selectorItems
                )
                elements.append(selectorSequence)
            }
            
            // Sorting Operations Sequence (0072,0600) - Optional, Type 3
            if !imageSet.sortOperations.isEmpty {
                let sortItems = serializeSortOperations(imageSet.sortOperations)
                let sortSequence = createSequenceElement(
                    tag: .sortingOperationsSequence,
                    items: sortItems
                )
                elements.append(sortSequence)
            }
            
            // Time-based selection attributes
            if let timeSelection = imageSet.timeSelection {
                serializeTimeSelection(timeSelection, into: &elements)
            }
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    private func serializeSelectors(_ selectors: [ImageSetSelector]) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for selector in selectors {
            var elements: [DataElement] = []
            
            // Selector Attribute (0072,0024) - Required, Type 1
            elements.append(serializeTagAsAttributeTag(
                tag: .selectorAttribute,
                value: selector.attribute
            ))
            
            // Selector Value Number (0072,0026) - Optional, Type 3
            if let valueNumber = selector.valueNumber {
                elements.append(DataElement.uint16(
                    tag: .selectorValueNumber,
                    value: UInt16(valueNumber)
                ))
            }
            
            // Filter-by Operator (0072,0406) - Optional, Type 3
            if let filterOperator = selector.operator {
                elements.append(DataElement.string(
                    tag: .filterByOperator,
                    vr: .CS,
                    value: filterOperator.rawValue
                ))
            }
            
            // Selector values are stored using the attribute tag itself
            if !selector.values.isEmpty {
                // Join values with backslash separator per DICOM multi-value standard
                let valueString = selector.values.joined(separator: "\\")
                elements.append(DataElement.string(
                    tag: selector.attribute,
                    vr: .LO,
                    value: valueString
                ))
            }
            
            // Image Set Selector Usage Flag (0072,0022) - Required, Type 1
            elements.append(DataElement.string(
                tag: .imageSetSelectorUsageFlag,
                vr: .CS,
                value: selector.usageFlag.rawValue
            ))
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    private func serializeSortOperations(_ operations: [SortOperation]) -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for operation in operations {
            var elements: [DataElement] = []
            
            // Sort-by Category (0072,0602) - Required, Type 1
            elements.append(DataElement.string(
                tag: .sortByCategory,
                vr: .CS,
                value: operation.sortByCategory.rawValue
            ))
            
            // Sorting Direction (0072,0604) - Required, Type 1
            elements.append(DataElement.string(
                tag: .sortingDirection,
                vr: .CS,
                value: operation.direction.rawValue
            ))
            
            // Selector Attribute (0072,0024) - Conditional, Type 1C
            // Required when Sort-by Category is ATTRIBUTE
            if let attribute = operation.attribute {
                elements.append(serializeTagAsAttributeTag(
                    tag: .selectorAttribute,
                    value: attribute
                ))
            }
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    private func serializeTimeSelection(_ timeSelection: TimeBasedSelection, into elements: inout [DataElement]) {
        // Relative Time (0072,0038) - Optional, Type 3
        if let relativeTime = timeSelection.relativeTime {
            elements.append(DataElement.int32(
                tag: .relativeTime,
                value: Int32(relativeTime)
            ))
        }
        
        // Relative Time Units (0072,003A) - Conditional, Type 1C
        if let relativeTimeUnits = timeSelection.relativeTimeUnits {
            elements.append(DataElement.string(
                tag: .relativeTimeUnits,
                vr: .CS,
                value: relativeTimeUnits.rawValue
            ))
        }
        
        // Abstract Prior Value (0072,003C) - Optional, Type 3
        if let abstractPriorValue = timeSelection.abstractPriorValue {
            elements.append(DataElement.string(
                tag: .abstractPriorValue,
                vr: .SH,
                value: abstractPriorValue
            ))
        }
    }
    
    // MARK: - Screen Definition Serialization
    
    private func serializeScreenDefinitions(_ definitions: [ScreenDefinition]) -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for definition in definitions {
            var elements: [DataElement] = []
            
            // Number of Vertical Pixels (0072,0104) - Required, Type 1
            elements.append(DataElement.uint16(
                tag: .numberOfVerticalPixels,
                value: UInt16(definition.verticalPixels)
            ))
            
            // Number of Horizontal Pixels (0072,0106) - Required, Type 1
            elements.append(DataElement.uint16(
                tag: .numberOfHorizontalPixels,
                value: UInt16(definition.horizontalPixels)
            ))
            
            // Display Environment Spatial Position (0072,0108) - Optional, Type 3
            if let spatialPosition = definition.spatialPosition {
                let values = spatialPosition.map { Float64($0) }
                elements.append(DataElement.string(
                    tag: .displayEnvironmentSpatialPosition,
                    vr: .FD,
                    value: values.map { String($0) }.joined(separator: "\\")
                ))
            }
            
            // Screen Minimum Grayscale Bit Depth (0072,010A) - Optional, Type 3
            if let minGrayscaleBitDepth = definition.minimumGrayscaleBitDepth {
                elements.append(DataElement.uint16(
                    tag: .screenMinimumGrayscaleBitDepth,
                    value: UInt16(minGrayscaleBitDepth)
                ))
            }
            
            // Screen Minimum Color Bit Depth (0072,010C) - Optional, Type 3
            if let minColorBitDepth = definition.minimumColorBitDepth {
                elements.append(DataElement.uint16(
                    tag: .screenMinimumColorBitDepth,
                    value: UInt16(minColorBitDepth)
                ))
            }
            
            // Application Maximum Repaint Time (0072,010E) - Optional, Type 3
            if let maxRepaintTime = definition.maximumRepaintTime {
                elements.append(DataElement.uint16(
                    tag: .applicationMaximumRepaintTime,
                    value: UInt16(maxRepaintTime)
                ))
            }
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    // MARK: - Display Set Serialization
    
    private func serializeDisplaySets(_ displaySets: [DisplaySet]) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for displaySet in displaySets {
            var elements: [DataElement] = []
            
            // Display Set Number (0072,0202) - Required, Type 1
            elements.append(DataElement.uint16(
                tag: .displaySetNumber,
                value: UInt16(displaySet.number)
            ))
            
            // Display Set Label (0072,0203) - Optional, Type 3
            if let label = displaySet.label {
                elements.append(DataElement.string(
                    tag: .displaySetLabel,
                    vr: .LO,
                    value: label
                ))
            }
            
            // Display Set Presentation Group (0072,0204) - Optional, Type 3
            if let presentationGroup = displaySet.presentationGroup {
                elements.append(DataElement.uint16(
                    tag: .displaySetPresentationGroup,
                    value: UInt16(presentationGroup)
                ))
            }
            
            // Display Set Presentation Group Description (0072,0206) - Optional, Type 3
            if let groupDescription = displaySet.presentationGroupDescription {
                elements.append(DataElement.string(
                    tag: .displaySetPresentationGroupDescription,
                    vr: .LO,
                    value: groupDescription
                ))
            }
            
            // Partial Data Display Handling (0072,0208) - Optional, Type 3
            if let partialDataHandling = displaySet.partialDataHandling {
                elements.append(DataElement.string(
                    tag: .partialDataDisplayHandling,
                    vr: .CS,
                    value: partialDataHandling
                ))
            }
            
            // Display Set Scrolling Group (0072,0212) - Optional, Type 3
            if let scrollingGroup = displaySet.scrollingGroup {
                elements.append(DataElement.uint16(
                    tag: .displaySetScrollingGroup,
                    value: UInt16(scrollingGroup)
                ))
            }
            
            // Image Boxes Sequence (0072,0300) - Required, Type 1
            if !displaySet.imageBoxes.isEmpty {
                let imageBoxItems = try serializeImageBoxes(displaySet.imageBoxes)
                let imageBoxSequence = createSequenceElement(
                    tag: .imageBoxesSequence,
                    items: imageBoxItems
                )
                elements.append(imageBoxSequence)
            }
            
            // Display options
            serializeDisplayOptions(displaySet.displayOptions, into: &elements)
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    private func serializeImageBoxes(_ imageBoxes: [ImageBox]) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        for imageBox in imageBoxes {
            var elements: [DataElement] = []
            
            // Image Box Number (0072,0302) - Required, Type 1
            elements.append(DataElement.uint16(
                tag: .imageBoxNumber,
                value: UInt16(imageBox.number)
            ))
            
            // Image Box Layout Type (0072,0304) - Required, Type 1
            elements.append(DataElement.string(
                tag: .imageBoxLayoutType,
                vr: .CS,
                value: imageBox.layoutType.rawValue
            ))
            
            // Image Box Tile Horizontal Dimension (0072,0306) - Conditional, Type 1C
            if let tileHorizontal = imageBox.tileHorizontalDimension {
                elements.append(DataElement.uint16(
                    tag: .imageBoxTileHorizontalDimension,
                    value: UInt16(tileHorizontal)
                ))
            }
            
            // Image Box Tile Vertical Dimension (0072,0308) - Conditional, Type 1C
            if let tileVertical = imageBox.tileVerticalDimension {
                elements.append(DataElement.uint16(
                    tag: .imageBoxTileVerticalDimension,
                    value: UInt16(tileVertical)
                ))
            }
            
            // Image Box Scroll Direction (0072,0310) - Optional, Type 3
            if let scrollDirection = imageBox.scrollDirection {
                elements.append(DataElement.string(
                    tag: .imageBoxScrollDirection,
                    vr: .CS,
                    value: scrollDirection.rawValue
                ))
            }
            
            // Image Box Small Scroll Type (0072,0312) - Optional, Type 3
            if let smallScrollType = imageBox.smallScrollType {
                elements.append(DataElement.string(
                    tag: .imageBoxSmallScrollType,
                    vr: .CS,
                    value: smallScrollType.rawValue
                ))
            }
            
            // Image Box Small Scroll Amount (0072,0314) - Optional, Type 3
            if let smallScrollAmount = imageBox.smallScrollAmount {
                elements.append(DataElement.uint16(
                    tag: .imageBoxSmallScrollAmount,
                    value: UInt16(smallScrollAmount)
                ))
            }
            
            // Image Box Large Scroll Type (0072,0316) - Optional, Type 3
            if let largeScrollType = imageBox.largeScrollType {
                elements.append(DataElement.string(
                    tag: .imageBoxLargeScrollType,
                    vr: .CS,
                    value: largeScrollType.rawValue
                ))
            }
            
            // Image Box Large Scroll Amount (0072,0318) - Optional, Type 3
            if let largeScrollAmount = imageBox.largeScrollAmount {
                elements.append(DataElement.uint16(
                    tag: .imageBoxLargeScrollAmount,
                    value: UInt16(largeScrollAmount)
                ))
            }
            
            // Image Box Overlap Priority (0072,0320) - Optional, Type 3
            if let overlapPriority = imageBox.overlapPriority {
                elements.append(DataElement.uint16(
                    tag: .imageBoxOverlapPriority,
                    value: UInt16(overlapPriority)
                ))
            }
            
            // Cine Relative to Real-Time (0072,0330) - Optional, Type 3
            if let cineRelative = imageBox.cineRelativeToRealTime {
                elements.append(DataElement.float64(
                    tag: .cineRelativeToRealTime,
                    value: cineRelative
                ))
            }
            
            // Reformatting Operation
            if let reformattingOp = imageBox.reformattingOperation {
                serializeReformattingOperation(reformattingOp, into: &elements)
            }
            
            // 3D Rendering Type (0072,0520) - Optional, Type 3
            if let renderingType = imageBox.threeDRenderingType {
                elements.append(DataElement.string(
                    tag: .threeDRenderingType,
                    vr: .CS,
                    value: renderingType.rawValue
                ))
            }
            
            items.append(SequenceItem(elements: elements))
        }
        
        return items
    }
    
    private func serializeReformattingOperation(_ operation: ReformattingOperation, into elements: inout [DataElement]) {
        // Reformatting Operation Type (0072,0510) - Required, Type 1
        elements.append(DataElement.string(
            tag: .reformattingOperationType,
            vr: .CS,
            value: operation.type.rawValue
        ))
        
        // Reformatting Thickness (0072,0512) - Optional, Type 3
        if let thickness = operation.thickness {
            elements.append(DataElement.float64(
                tag: .reformattingThickness,
                value: thickness
            ))
        }
        
        // Reformatting Interval (0072,0514) - Optional, Type 3
        if let interval = operation.interval {
            elements.append(DataElement.float64(
                tag: .reformattingInterval,
                value: interval
            ))
        }
        
        // Reformatting Operation Initial View Direction (0072,0516) - Optional, Type 3
        if let initialViewDirection = operation.initialViewDirection {
            elements.append(DataElement.string(
                tag: .reformattingOperationInitialViewDirection,
                vr: .CS,
                value: initialViewDirection
            ))
        }
    }
    
    private func serializeDisplayOptions(_ options: DisplayOptions, into elements: inout [DataElement]) {
        // Display Set Patient Orientation (0072,0700) - Optional, Type 3
        if let patientOrientation = options.patientOrientation {
            elements.append(DataElement.string(
                tag: .displaySetPatientOrientation,
                vr: .CS,
                value: patientOrientation
            ))
        }
        
        // VOI Type (0072,0702) - Optional, Type 3
        if let voiType = options.voiType {
            elements.append(DataElement.string(
                tag: .voiType,
                vr: .CS,
                value: voiType
            ))
        }
        
        // Pseudo-Color Type (0072,0704) - Optional, Type 3
        if let pseudoColorType = options.pseudoColorType {
            elements.append(DataElement.string(
                tag: .pseudoColorType,
                vr: .CS,
                value: pseudoColorType
            ))
        }
        
        // Show Grayscale Inverted (0072,0706) - Optional, Type 3
        if options.showGrayscaleInverted {
            elements.append(DataElement.string(
                tag: .showGrayscaleInverted,
                vr: .CS,
                value: "Y"
            ))
        }
        
        // Show Image True Size Flag (0072,0710) - Optional, Type 3
        if options.showImageTrueSize {
            elements.append(DataElement.string(
                tag: .showImageTrueSizeFlag,
                vr: .CS,
                value: "Y"
            ))
        }
        
        // Show Graphic Annotation Flag (0072,0712) - Optional, Type 3
        elements.append(DataElement.string(
            tag: .showGraphicAnnotationFlag,
            vr: .CS,
            value: options.showGraphicAnnotations ? "Y" : "N"
        ))
        
        // Show Patient Demographics Flag (0072,0714) - Optional, Type 3
        elements.append(DataElement.string(
            tag: .showPatientDemographicsFlag,
            vr: .CS,
            value: options.showPatientDemographics ? "Y" : "N"
        ))
        
        // Show Acquisition Techniques Flag (0072,0716) - Optional, Type 3
        elements.append(DataElement.string(
            tag: .showAcquisitionTechniquesFlag,
            vr: .CS,
            value: options.showAcquisitionTechniques ? "Y" : "N"
        ))
        
        // Display Set Horizontal Justification (0072,0717) - Optional, Type 3
        if let horizJust = options.horizontalJustification {
            elements.append(DataElement.string(
                tag: .displaySetHorizontalJustification,
                vr: .CS,
                value: horizJust.rawValue
            ))
        }
        
        // Display Set Vertical Justification (0072,0718) - Optional, Type 3
        if let vertJust = options.verticalJustification {
            elements.append(DataElement.string(
                tag: .displaySetVerticalJustification,
                vr: .CS,
                value: vertJust.rawValue
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sequence element from sequence items
    private func createSequenceElement(tag: Tag, items: [SequenceItem]) -> DataElement {
        let writer = DICOMWriter()
        var sequenceData = Data()
        
        for item in items {
            sequenceData.append(writer.serializeSequenceItem(item))
        }
        
        return DataElement(
            tag: tag,
            vr: .SQ,
            length: UInt32(sequenceData.count),
            valueData: sequenceData,
            sequenceItems: items
        )
    }
    
    /// Serializes a Tag to an AttributeTag (AT) VR data element
    ///
    /// The AT VR contains a DICOM tag as a pair of 16-bit unsigned integers
    /// (group, element) in little-endian byte order.
    ///
    /// Reference: PS3.5 Section 6.2 - AT Value Representation
    private func serializeTagAsAttributeTag(tag: Tag, value: Tag) -> DataElement {
        var data = Data()
        
        // Serialize as little-endian UInt16 pairs (group, element)
        withUnsafeBytes(of: value.group.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: value.element.littleEndian) { data.append(contentsOf: $0) }
        
        return DataElement(
            tag: tag,
            vr: .AT,
            length: 4,
            valueData: data
        )
    }
}
