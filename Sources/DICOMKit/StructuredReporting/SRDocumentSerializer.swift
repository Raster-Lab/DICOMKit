/// DICOM Structured Reporting Document Serializer
///
/// Converts SRDocument objects to DICOM DataSet format for storage.
///
/// Reference: PS3.3 Section C.17 - SR Document Information Object Definitions

import Foundation
import DICOMCore

/// Serializer for converting SRDocument to DICOM DataSet
///
/// Example:
/// ```swift
/// let serializer = SRDocumentSerializer()
/// let dataSet = try serializer.serialize(document: srDocument)
/// ```
public struct SRDocumentSerializer: Sendable {
    
    /// Serialization errors
    public enum SerializationError: Error, Sendable, Equatable {
        /// Missing required attribute
        case missingRequiredAttribute(String)
        
        /// Invalid content item
        case invalidContentItem(String)
        
        /// Encoding error
        case encodingError(String)
    }
    
    /// Creates a new SR document serializer
    public init() {}
    
    // MARK: - Public API
    
    /// Serializes an SRDocument to a DataSet
    /// - Parameter document: The SR document to serialize
    /// - Returns: A DICOM DataSet representation
    /// - Throws: `SerializationError` if serialization fails
    public func serialize(document: SRDocument) throws -> DataSet {
        var dataSet = DataSet()
        
        // Add SOP Common Module
        addSOPCommonModule(to: &dataSet, document: document)
        
        // Add Patient Module
        addPatientModule(to: &dataSet, document: document)
        
        // Add General Study Module
        addGeneralStudyModule(to: &dataSet, document: document)
        
        // Add General Series Module
        addGeneralSeriesModule(to: &dataSet, document: document)
        
        // Add SR Document General Module
        addSRDocumentGeneralModule(to: &dataSet, document: document)
        
        // Add SR Document Content Module
        try addSRDocumentContentModule(to: &dataSet, document: document)
        
        return dataSet
    }
    
    // MARK: - SOP Common Module
    
    private func addSOPCommonModule(to dataSet: inout DataSet, document: SRDocument) {
        // SOP Class UID (0008,0016)
        dataSet[.sopClassUID] = DataElement.string(
            tag: .sopClassUID,
            vr: .UI,
            value: document.sopClassUID
        )
        
        // SOP Instance UID (0008,0018)
        dataSet[.sopInstanceUID] = DataElement.string(
            tag: .sopInstanceUID,
            vr: .UI,
            value: document.sopInstanceUID
        )
    }
    
    // MARK: - Patient Module
    
    private func addPatientModule(to dataSet: inout DataSet, document: SRDocument) {
        // Patient Name (0010,0010)
        if let patientName = document.patientName {
            dataSet[.patientName] = DataElement.string(
                tag: .patientName,
                vr: .PN,
                value: patientName
            )
        }
        
        // Patient ID (0010,0020)
        if let patientID = document.patientID {
            dataSet[.patientID] = DataElement.string(
                tag: .patientID,
                vr: .LO,
                value: patientID
            )
        }
    }
    
    // MARK: - General Study Module
    
    private func addGeneralStudyModule(to dataSet: inout DataSet, document: SRDocument) {
        // Study Instance UID (0020,000D)
        if let studyInstanceUID = document.studyInstanceUID {
            dataSet[.studyInstanceUID] = DataElement.string(
                tag: .studyInstanceUID,
                vr: .UI,
                value: studyInstanceUID
            )
        }
        
        // Study Date (0008,0020)
        if let studyDate = document.studyDate {
            dataSet[.studyDate] = DataElement.string(
                tag: .studyDate,
                vr: .DA,
                value: studyDate
            )
        }
        
        // Study Time (0008,0030)
        if let studyTime = document.studyTime {
            dataSet[.studyTime] = DataElement.string(
                tag: .studyTime,
                vr: .TM,
                value: studyTime
            )
        }
        
        // Accession Number (0008,0050)
        if let accessionNumber = document.accessionNumber {
            dataSet[.accessionNumber] = DataElement.string(
                tag: .accessionNumber,
                vr: .SH,
                value: accessionNumber
            )
        }
    }
    
    // MARK: - General Series Module
    
    private func addGeneralSeriesModule(to dataSet: inout DataSet, document: SRDocument) {
        // Series Instance UID (0020,000E)
        if let seriesInstanceUID = document.seriesInstanceUID {
            dataSet[.seriesInstanceUID] = DataElement.string(
                tag: .seriesInstanceUID,
                vr: .UI,
                value: seriesInstanceUID
            )
        }
        
        // Modality (0008,0060)
        if let modality = document.modality {
            dataSet[.modality] = DataElement.string(
                tag: .modality,
                vr: .CS,
                value: modality
            )
        }
        
        // Series Number (0020,0011)
        if let seriesNumber = document.seriesNumber {
            dataSet[.seriesNumber] = DataElement.string(
                tag: .seriesNumber,
                vr: .IS,
                value: seriesNumber
            )
        }
    }
    
    // MARK: - SR Document General Module
    
    private func addSRDocumentGeneralModule(to dataSet: inout DataSet, document: SRDocument) {
        // Content Date (0008,0023)
        if let contentDate = document.contentDate {
            dataSet[.contentDate] = DataElement.string(
                tag: .contentDate,
                vr: .DA,
                value: contentDate
            )
        }
        
        // Content Time (0008,0033)
        if let contentTime = document.contentTime {
            dataSet[.contentTime] = DataElement.string(
                tag: .contentTime,
                vr: .TM,
                value: contentTime
            )
        }
        
        // Instance Number (0020,0013)
        if let instanceNumber = document.instanceNumber {
            dataSet[.instanceNumber] = DataElement.string(
                tag: .instanceNumber,
                vr: .IS,
                value: instanceNumber
            )
        }
        
        // Completion Flag (0040,A491)
        if let completionFlag = document.completionFlag {
            dataSet[.completionFlag] = DataElement.string(
                tag: .completionFlag,
                vr: .CS,
                value: completionFlag.rawValue
            )
        }
        
        // Verification Flag (0040,A493)
        if let verificationFlag = document.verificationFlag {
            dataSet[.verificationFlag] = DataElement.string(
                tag: .verificationFlag,
                vr: .CS,
                value: verificationFlag.rawValue
            )
        }
        
        // Preliminary Flag (0040,A496)
        if let preliminaryFlag = document.preliminaryFlag {
            dataSet[.preliminaryFlag] = DataElement.string(
                tag: .preliminaryFlag,
                vr: .CS,
                value: preliminaryFlag.rawValue
            )
        }
    }
    
    // MARK: - SR Document Content Module
    
    private func addSRDocumentContentModule(to dataSet: inout DataSet, document: SRDocument) throws {
        // Value Type - root is always CONTAINER
        dataSet[.valueType] = DataElement.string(
            tag: .valueType,
            vr: .CS,
            value: ContentItemValueType.container.rawValue
        )
        
        // Concept Name Code Sequence (Document Title)
        if let documentTitle = document.documentTitle {
            dataSet[.conceptNameCodeSequence] = try createCodeSequenceElement(
                tag: .conceptNameCodeSequence,
                code: documentTitle
            )
        }
        
        // Continuity of Content
        dataSet[.continuityOfContent] = DataElement.string(
            tag: .continuityOfContent,
            vr: .CS,
            value: document.rootContent.continuityOfContent.rawValue
        )
        
        // Content Template Sequence (if template is specified)
        if let templateID = document.rootContent.templateIdentifier {
            dataSet[.contentTemplateSequence] = createTemplateSequenceElement(
                templateIdentifier: templateID,
                mappingResource: document.rootContent.mappingResource ?? "DCMR"
            )
        }
        
        // Content Sequence (the content tree)
        if !document.rootContent.contentItems.isEmpty {
            dataSet[.contentSequence] = try createContentSequenceElement(
                items: document.rootContent.contentItems
            )
        }
    }
    
    // MARK: - Code Sequence Creation
    
    /// Creates a Code Sequence element from a CodedConcept
    private func createCodeSequenceElement(tag: Tag, code: CodedConcept) throws -> DataElement {
        let sequenceItem = createCodeSequenceItem(code: code)
        return createSequenceElement(tag: tag, items: [sequenceItem])
    }
    
    /// Creates a sequence item for a coded concept
    private func createCodeSequenceItem(code: CodedConcept) -> SequenceItem {
        var elements: [DataElement] = []
        
        // Code Value (0008,0100)
        elements.append(DataElement.string(
            tag: .codeValue,
            vr: .SH,
            value: code.codeValue
        ))
        
        // Coding Scheme Designator (0008,0102)
        elements.append(DataElement.string(
            tag: .codingSchemeDesignator,
            vr: .SH,
            value: code.codingSchemeDesignator
        ))
        
        // Code Meaning (0008,0104)
        elements.append(DataElement.string(
            tag: .codeMeaning,
            vr: .LO,
            value: code.codeMeaning
        ))
        
        // Coding Scheme Version (0008,0103) - optional
        if let version = code.codingSchemeVersion {
            elements.append(DataElement.string(
                tag: .codingSchemeVersion,
                vr: .SH,
                value: version
            ))
        }
        
        return SequenceItem(elements: elements)
    }
    
    // MARK: - Template Sequence Creation
    
    /// Creates a Content Template Sequence element
    private func createTemplateSequenceElement(templateIdentifier: String, mappingResource: String) -> DataElement {
        var elements: [DataElement] = []
        
        // Template Identifier (0040,DB00)
        elements.append(DataElement.string(
            tag: .templateIdentifier,
            vr: .CS,
            value: templateIdentifier
        ))
        
        // Mapping Resource (0008,0105)
        elements.append(DataElement.string(
            tag: .mappingResource,
            vr: .CS,
            value: mappingResource
        ))
        
        let sequenceItem = SequenceItem(elements: elements)
        return createSequenceElement(tag: .contentTemplateSequence, items: [sequenceItem])
    }
    
    // MARK: - Content Sequence Creation
    
    /// Creates a Content Sequence element from content items
    private func createContentSequenceElement(items: [AnyContentItem]) throws -> DataElement {
        var sequenceItems: [SequenceItem] = []
        
        for item in items {
            let sequenceItem = try createContentItemSequenceItem(item: item)
            sequenceItems.append(sequenceItem)
        }
        
        return createSequenceElement(tag: .contentSequence, items: sequenceItems)
    }
    
    /// Creates a sequence item for a content item
    private func createContentItemSequenceItem(item: AnyContentItem) throws -> SequenceItem {
        var elements: [DataElement] = []
        
        // Value Type (0040,A040)
        elements.append(DataElement.string(
            tag: .valueType,
            vr: .CS,
            value: item.valueType.rawValue
        ))
        
        // Relationship Type (0040,A010)
        if let relationshipType = item.relationshipType {
            elements.append(DataElement.string(
                tag: .relationshipType,
                vr: .CS,
                value: relationshipType.rawValue
            ))
        }
        
        // Concept Name Code Sequence (0040,A043)
        if let conceptName = item.conceptName {
            elements.append(try createCodeSequenceElement(
                tag: .conceptNameCodeSequence,
                code: conceptName
            ))
        }
        
        // Observation DateTime (0040,A032)
        if let observationDateTime = item.observationDateTime {
            elements.append(DataElement.string(
                tag: .observationDateTime,
                vr: .DT,
                value: observationDateTime
            ))
        }
        
        // Value type-specific elements
        try addValueTypeSpecificElements(to: &elements, item: item)
        
        return SequenceItem(elements: elements)
    }
    
    /// Adds value type-specific elements to a content item
    private func addValueTypeSpecificElements(to elements: inout [DataElement], item: AnyContentItem) throws {
        switch item.valueType {
        case .text:
            if let textItem = item.asText {
                elements.append(DataElement.string(
                    tag: .textValue,
                    vr: .UT,
                    value: textItem.textValue
                ))
            }
            
        case .code:
            if let codeItem = item.asCode {
                elements.append(try createCodeSequenceElement(
                    tag: .conceptCodeSequence,
                    code: codeItem.conceptCode
                ))
            }
            
        case .num:
            if let numericItem = item.asNumeric {
                try addNumericElements(to: &elements, item: numericItem)
            }
            
        case .date:
            if let dateItem = item.asDate {
                elements.append(DataElement.string(
                    tag: .date,
                    vr: .DA,
                    value: dateItem.dateValue
                ))
            }
            
        case .time:
            if let timeItem = item.asTime {
                elements.append(DataElement.string(
                    tag: .time,
                    vr: .TM,
                    value: timeItem.timeValue
                ))
            }
            
        case .datetime:
            if let dateTimeItem = item.asDateTime {
                elements.append(DataElement.string(
                    tag: .dateTime,
                    vr: .DT,
                    value: dateTimeItem.dateTimeValue
                ))
            }
            
        case .pname:
            if let personNameItem = item.asPersonName {
                elements.append(DataElement.string(
                    tag: .personName,
                    vr: .PN,
                    value: personNameItem.personName
                ))
            }
            
        case .uidref:
            if let uidRefItem = item.asUIDRef {
                elements.append(DataElement.string(
                    tag: .uid,
                    vr: .UI,
                    value: uidRefItem.uidValue
                ))
            }
            
        case .composite:
            if let compositeItem = item.asComposite {
                elements.append(createReferencedSOPSequenceElement(
                    sopClassUID: compositeItem.referencedSOPSequence.sopClassUID,
                    sopInstanceUID: compositeItem.referencedSOPSequence.sopInstanceUID
                ))
            }
            
        case .image:
            if let imageItem = item.asImage {
                elements.append(createImageReferencedSOPSequenceElement(imageItem: imageItem))
            }
            
        case .waveform:
            if let waveformItem = item.asWaveform {
                elements.append(createWaveformReferencedSOPSequenceElement(waveformItem: waveformItem))
            }
            
        case .scoord:
            if let scoordItem = item.asSpatialCoordinates {
                addSpatialCoordinatesElements(to: &elements, item: scoordItem)
            }
            
        case .scoord3D:
            if let scoord3DItem = item.asSpatialCoordinates3D {
                addSpatialCoordinates3DElements(to: &elements, item: scoord3DItem)
            }
            
        case .tcoord:
            if let tcoordItem = item.asTemporalCoordinates {
                addTemporalCoordinatesElements(to: &elements, item: tcoordItem)
            }
            
        case .container:
            if let containerItem = item.asContainer {
                try addContainerElements(to: &elements, item: containerItem)
            }
        }
    }
    
    // MARK: - Numeric Content Item Elements
    
    /// Adds numeric content item elements using Measured Value Sequence
    private func addNumericElements(to elements: inout [DataElement], item: NumericContentItem) throws {
        // Create Measured Value Sequence
        var measuredValueElements: [DataElement] = []
        
        // Numeric Value (0040,A30A) - as DS (Decimal String)
        let numericString = item.numericValues.map { formatDecimalString($0) }.joined(separator: "\\")
        measuredValueElements.append(DataElement.string(
            tag: .numericValue,
            vr: .DS,
            value: numericString
        ))
        
        // Measurement Units Code Sequence (0040,08EA)
        if let units = item.measurementUnits {
            measuredValueElements.append(try createCodeSequenceElement(
                tag: .measurementUnitsCodeSequence,
                code: units
            ))
        }
        
        // Floating Point Value (0040,A161) - optional high precision values
        if let floatValues = item.floatingPointValues {
            let writer = DICOMWriter()
            let float64Data = writer.serializeFloat64s(floatValues)
            measuredValueElements.append(DataElement(
                tag: .floatingPointValue,
                vr: .FD,
                length: UInt32(float64Data.count),
                valueData: float64Data
            ))
        }
        
        let measuredValueItem = SequenceItem(elements: measuredValueElements)
        elements.append(createSequenceElement(tag: .measuredValueSequence, items: [measuredValueItem]))
    }
    
    /// Formats a Double as a DICOM Decimal String
    private func formatDecimalString(_ value: Double) -> String {
        // DICOM DS allows up to 16 characters
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            // Use a reasonable precision
            let formatted = String(format: "%.10g", value)
            return formatted
        }
    }
    
    // MARK: - Referenced SOP Sequence Elements
    
    /// Creates a Referenced SOP Sequence element
    private func createReferencedSOPSequenceElement(sopClassUID: String, sopInstanceUID: String) -> DataElement {
        var elements: [DataElement] = []
        
        elements.append(DataElement.string(
            tag: .referencedSOPClassUID,
            vr: .UI,
            value: sopClassUID
        ))
        
        elements.append(DataElement.string(
            tag: .referencedSOPInstanceUID,
            vr: .UI,
            value: sopInstanceUID
        ))
        
        let sequenceItem = SequenceItem(elements: elements)
        return createSequenceElement(tag: .referencedSOPSequence, items: [sequenceItem])
    }
    
    /// Creates a Referenced SOP Sequence element for an image reference
    private func createImageReferencedSOPSequenceElement(imageItem: ImageContentItem) -> DataElement {
        var elements: [DataElement] = []
        
        elements.append(DataElement.string(
            tag: .referencedSOPClassUID,
            vr: .UI,
            value: imageItem.imageReference.sopReference.sopClassUID
        ))
        
        elements.append(DataElement.string(
            tag: .referencedSOPInstanceUID,
            vr: .UI,
            value: imageItem.imageReference.sopReference.sopInstanceUID
        ))
        
        // Referenced Frame Number (0008,1160)
        if let frameNumbers = imageItem.imageReference.frameNumbers, !frameNumbers.isEmpty {
            let frameString = frameNumbers.map { String($0) }.joined(separator: "\\")
            elements.append(DataElement.string(
                tag: .referencedFrameNumber,
                vr: .IS,
                value: frameString
            ))
        }
        
        // Referenced Segment Number (0062,000B)
        if let segmentNumbers = imageItem.imageReference.segmentNumbers, !segmentNumbers.isEmpty {
            let writer = DICOMWriter()
            let values = segmentNumbers.map { UInt16($0) }
            let segmentData = writer.serializeUInt16s(values)
            elements.append(DataElement(
                tag: .referencedSegmentNumber,
                vr: .US,
                length: UInt32(segmentData.count),
                valueData: segmentData
            ))
        }
        
        let sequenceItem = SequenceItem(elements: elements)
        return createSequenceElement(tag: .referencedSOPSequence, items: [sequenceItem])
    }
    
    /// Creates a Referenced SOP Sequence element for a waveform reference
    private func createWaveformReferencedSOPSequenceElement(waveformItem: WaveformContentItem) -> DataElement {
        var elements: [DataElement] = []
        
        elements.append(DataElement.string(
            tag: .referencedSOPClassUID,
            vr: .UI,
            value: waveformItem.waveformReference.sopReference.sopClassUID
        ))
        
        elements.append(DataElement.string(
            tag: .referencedSOPInstanceUID,
            vr: .UI,
            value: waveformItem.waveformReference.sopReference.sopInstanceUID
        ))
        
        // Referenced Waveform Channels (can be added if needed)
        
        let sequenceItem = SequenceItem(elements: elements)
        return createSequenceElement(tag: .referencedSOPSequence, items: [sequenceItem])
    }
    
    // MARK: - Spatial Coordinates Elements
    
    /// Adds spatial coordinates elements
    private func addSpatialCoordinatesElements(to elements: inout [DataElement], item: SpatialCoordinatesContentItem) {
        // Graphic Type (0070,0023)
        elements.append(DataElement.string(
            tag: .graphicType,
            vr: .CS,
            value: item.graphicType.rawValue
        ))
        
        // Graphic Data (0070,0022) - FL
        let writer = DICOMWriter()
        let graphicData = writer.serializeFloat32s(item.graphicData)
        elements.append(DataElement(
            tag: .graphicData,
            vr: .FL,
            length: UInt32(graphicData.count),
            valueData: graphicData
        ))
    }
    
    /// Adds 3D spatial coordinates elements
    private func addSpatialCoordinates3DElements(to elements: inout [DataElement], item: SpatialCoordinates3DContentItem) {
        // Graphic Type (0070,0023)
        elements.append(DataElement.string(
            tag: .graphicType,
            vr: .CS,
            value: item.graphicType.rawValue
        ))
        
        // Graphic Data 3D (0070,0022) - FL
        let writer = DICOMWriter()
        let graphicData = writer.serializeFloat32s(item.graphicData)
        elements.append(DataElement(
            tag: .graphicData,
            vr: .FL,
            length: UInt32(graphicData.count),
            valueData: graphicData
        ))
        
        // Referenced Frame of Reference UID (0020,0052)
        if let frameOfRefUID = item.frameOfReferenceUID {
            elements.append(DataElement.string(
                tag: .frameOfReferenceUID,
                vr: .UI,
                value: frameOfRefUID
            ))
        }
    }
    
    // MARK: - Temporal Coordinates Elements
    
    /// Adds temporal coordinates elements
    private func addTemporalCoordinatesElements(to elements: inout [DataElement], item: TemporalCoordinatesContentItem) {
        // Temporal Range Type (0040,A130)
        elements.append(DataElement.string(
            tag: .temporalRangeType,
            vr: .CS,
            value: item.temporalRangeType.rawValue
        ))
        
        // Referenced Sample Positions (0040,A132) - UL
        if let samplePositions = item.referencedSamplePositions, !samplePositions.isEmpty {
            let writer = DICOMWriter()
            let samplePositionsData = writer.serializeUInt32s(samplePositions)
            elements.append(DataElement(
                tag: .referencedSamplePositions,
                vr: .UL,
                length: UInt32(samplePositionsData.count),
                valueData: samplePositionsData
            ))
        }
        
        // Referenced Time Offsets (0040,A138) - DS
        if let timeOffsets = item.referencedTimeOffsets, !timeOffsets.isEmpty {
            let timeOffsetString = timeOffsets.map { formatDecimalString($0) }.joined(separator: "\\")
            elements.append(DataElement.string(
                tag: .referencedTimeOffsets,
                vr: .DS,
                value: timeOffsetString
            ))
        }
        
        // Referenced DateTime (0040,A13A) - DT
        if let dateTimes = item.referencedDateTime, !dateTimes.isEmpty {
            let dateTimeString = dateTimes.joined(separator: "\\")
            elements.append(DataElement.string(
                tag: .referencedDateTime,
                vr: .DT,
                value: dateTimeString
            ))
        }
    }
    
    // MARK: - Container Elements
    
    /// Adds container content item elements
    private func addContainerElements(to elements: inout [DataElement], item: ContainerContentItem) throws {
        // Continuity of Content (0040,A050)
        elements.append(DataElement.string(
            tag: .continuityOfContent,
            vr: .CS,
            value: item.continuityOfContent.rawValue
        ))
        
        // Content Template Sequence (if template is specified)
        if let templateID = item.templateIdentifier {
            elements.append(createTemplateSequenceElement(
                templateIdentifier: templateID,
                mappingResource: item.mappingResource ?? "DCMR"
            ))
        }
        
        // Content Sequence (nested content items)
        if !item.contentItems.isEmpty {
            elements.append(try createContentSequenceElement(items: item.contentItems))
        }
    }
    
    // MARK: - Sequence Element Creation
    
    /// Creates a sequence element from sequence items
    private func createSequenceElement(tag: Tag, items: [SequenceItem]) -> DataElement {
        // Calculate the total length of all items
        let writer = DICOMWriter()
        var totalLength: UInt32 = 0
        
        for item in items {
            let itemData = writer.serializeSequenceItem(item)
            totalLength += UInt32(itemData.count)
        }
        
        // Create the sequence data
        var sequenceData = Data()
        for item in items {
            sequenceData.append(writer.serializeSequenceItem(item))
        }
        
        return DataElement(
            tag: tag,
            vr: .SQ,
            length: totalLength,
            valueData: sequenceData,
            sequenceItems: items
        )
    }
}

// MARK: - SRDocument Extension for Serialization

extension SRDocument {
    /// Converts this SR document to a DICOM DataSet
    /// - Returns: A DICOM DataSet representation of this document
    /// - Throws: `SRDocumentSerializer.SerializationError` if serialization fails
    public func toDataSet() throws -> DataSet {
        let serializer = SRDocumentSerializer()
        return try serializer.serialize(document: self)
    }
}

// MARK: - Tag Extensions for SR Serialization
// Note: Some tags are already defined in SRDocumentParser.swift and Tag+StructuredReporting.swift

extension Tag {
    /// Temporal Range Type (0040,A130)
    /// VR: CS, VM: 1
    public static let temporalRangeType = Tag(group: 0x0040, element: 0xA130)
    
    /// Referenced Sample Positions (0040,A132)
    /// VR: UL, VM: 1-n
    public static let referencedSamplePositions = Tag(group: 0x0040, element: 0xA132)
    
    /// Referenced Time Offsets (0040,A138)
    /// VR: DS, VM: 1-n
    public static let referencedTimeOffsets = Tag(group: 0x0040, element: 0xA138)
    
    /// Referenced DateTime (0040,A13A) for TCOORD
    /// VR: DT, VM: 1-n
    public static let referencedDateTime = Tag(group: 0x0040, element: 0xA13A)
    
    /// Graphic Type (0070,0023)
    /// VR: CS, VM: 1
    public static let graphicType = Tag(group: 0x0070, element: 0x0023)
    
    /// Graphic Data (0070,0022)
    /// VR: FL, VM: 2-n
    public static let graphicData = Tag(group: 0x0070, element: 0x0022)
    
    /// Frame of Reference UID (0020,0052)
    /// VR: UI, VM: 1
    public static let frameOfReferenceUID = Tag(group: 0x0020, element: 0x0052)
}
