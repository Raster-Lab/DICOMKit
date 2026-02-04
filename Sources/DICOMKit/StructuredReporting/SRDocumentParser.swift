/// DICOM Structured Reporting Document Parser
///
/// Parses DICOM SR data sets into the content item tree model.
///
/// Reference: PS3.3 Section C.17 - SR Document Information Object Definitions

import Foundation
import DICOMCore

/// Parser for DICOM Structured Reporting documents
///
/// Converts a DICOM DataSet into an SRDocument with a hierarchical content tree.
///
/// Example:
/// ```swift
/// let parser = SRDocumentParser()
/// let document = try parser.parse(dataSet: dataSet)
/// ```
public struct SRDocumentParser: Sendable {
    
    /// Validation level for parsing
    public enum ValidationLevel: Sendable, Equatable {
        /// Strict validation - all required attributes must be present
        case strict
        
        /// Lenient validation - missing attributes are tolerated
        case lenient
    }
    
    /// Parser configuration
    public struct Configuration: Sendable {
        /// Validation level to use during parsing
        public let validationLevel: ValidationLevel
        
        /// Maximum depth for nested content items (to prevent stack overflow)
        public let maxDepth: Int
        
        /// Creates a parser configuration
        /// - Parameters:
        ///   - validationLevel: The validation level
        ///   - maxDepth: Maximum nesting depth (default: 100)
        public init(
            validationLevel: ValidationLevel = .lenient,
            maxDepth: Int = 100
        ) {
            self.validationLevel = validationLevel
            self.maxDepth = maxDepth
        }
        
        /// Default configuration with lenient validation
        public static let `default` = Configuration()
        
        /// Strict configuration for conformance testing
        public static let strict = Configuration(validationLevel: .strict)
    }
    
    /// Parser errors
    public enum ParseError: Error, Sendable, Equatable {
        /// Missing required attribute
        case missingRequiredAttribute(tag: String, description: String)
        
        /// Invalid or missing SOP Class UID
        case invalidSOPClassUID
        
        /// Invalid or missing SOP Instance UID
        case invalidSOPInstanceUID
        
        /// Unknown value type
        case unknownValueType(String)
        
        /// Invalid content sequence
        case invalidContentSequence(String)
        
        /// Maximum nesting depth exceeded
        case maxDepthExceeded(depth: Int)
        
        /// Invalid coded concept
        case invalidCodedConcept(String)
        
        /// Invalid graphic data for spatial coordinates
        case invalidGraphicData(String)
        
        /// Invalid referenced SOP sequence
        case invalidReferencedSOPSequence(String)
    }
    
    /// The parser configuration
    public let configuration: Configuration
    
    /// Creates a new SR document parser
    /// - Parameter configuration: Parser configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Parsing API
    
    /// Parses a DICOM DataSet into an SRDocument
    /// - Parameter dataSet: The DICOM data set to parse
    /// - Returns: A parsed SR document
    /// - Throws: ParseError if parsing fails
    public func parse(dataSet: DataSet) throws -> SRDocument {
        // Extract required identifiers
        let sopClassUID = try extractRequiredString(from: dataSet, tag: .sopClassUID, description: "SOP Class UID")
        let sopInstanceUID = try extractRequiredString(from: dataSet, tag: .sopInstanceUID, description: "SOP Instance UID")
        
        // Extract optional patient information
        let patientID = dataSet.string(for: .patientID)
        let patientName = dataSet.string(for: .patientName)
        
        // Extract optional study information
        let studyInstanceUID = dataSet.string(for: .studyInstanceUID)
        let studyDate = dataSet.string(for: .studyDate)
        let studyTime = dataSet.string(for: .studyTime)
        let accessionNumber = dataSet.string(for: .accessionNumber)
        
        // Extract optional series information
        let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID)
        let seriesNumber = dataSet.string(for: .seriesNumber)
        let modality = dataSet.string(for: .modality)
        
        // Extract document header information
        let contentDate = dataSet.string(for: .contentDate)
        let contentTime = dataSet.string(for: .contentTime)
        let instanceNumber = dataSet.string(for: .instanceNumber)
        
        // Extract flags
        let completionFlag = dataSet.string(for: .completionFlag).flatMap { CompletionFlag(rawValue: $0) }
        let verificationFlag = dataSet.string(for: .verificationFlag).flatMap { VerificationFlag(rawValue: $0) }
        let preliminaryFlag = dataSet.string(for: .preliminaryFlag).flatMap { PreliminaryFlag(rawValue: $0) }
        
        // Parse document title from Concept Name Code Sequence
        let documentTitle = try? parseCodedConcept(from: dataSet, tag: .conceptNameCodeSequence)
        
        // Parse the content tree
        let rootContent = try parseRootContent(from: dataSet)
        
        return SRDocument(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            patientID: patientID,
            patientName: patientName,
            studyInstanceUID: studyInstanceUID,
            studyDate: studyDate,
            studyTime: studyTime,
            accessionNumber: accessionNumber,
            seriesInstanceUID: seriesInstanceUID,
            seriesNumber: seriesNumber,
            modality: modality,
            contentDate: contentDate,
            contentTime: contentTime,
            instanceNumber: instanceNumber,
            completionFlag: completionFlag,
            verificationFlag: verificationFlag,
            preliminaryFlag: preliminaryFlag,
            documentTitle: documentTitle,
            rootContent: rootContent
        )
    }
    
    // MARK: - Content Parsing
    
    /// Parses the root content from the data set
    private func parseRootContent(from dataSet: DataSet) throws -> ContainerContentItem {
        // The root of an SR document is always a CONTAINER
        // Parse the Concept Name Code Sequence for the root
        let conceptName = try? parseCodedConcept(from: dataSet, tag: .conceptNameCodeSequence)
        
        // Parse Continuity of Content
        let continuityString = dataSet.string(for: .continuityOfContent)
        let continuity = continuityString.flatMap { ContinuityOfContent(rawValue: $0) } ?? .separate
        
        // Parse template identifier if present
        let templateIdentifier = parseTemplateIdentifier(from: dataSet)
        
        // Parse Content Sequence
        var contentItems: [AnyContentItem] = []
        if let contentSequence = dataSet.sequence(for: .contentSequence) {
            contentItems = try parseContentSequence(contentSequence, depth: 0)
        }
        
        return ContainerContentItem(
            conceptName: conceptName,
            continuityOfContent: continuity,
            contentItems: contentItems,
            templateIdentifier: templateIdentifier?.identifier,
            mappingResource: templateIdentifier?.mappingResource,
            relationshipType: nil,
            observationDateTime: dataSet.string(for: .observationDateTime),
            observationUID: nil
        )
    }
    
    /// Parses Content Sequence items recursively
    private func parseContentSequence(_ sequence: [SequenceItem], depth: Int) throws -> [AnyContentItem] {
        // Check maximum depth
        guard depth < configuration.maxDepth else {
            throw ParseError.maxDepthExceeded(depth: depth)
        }
        
        var contentItems: [AnyContentItem] = []
        
        for item in sequence {
            if let contentItem = try parseContentItem(from: item, depth: depth) {
                contentItems.append(contentItem)
            }
        }
        
        return contentItems
    }
    
    /// Parses a single content item from a sequence item
    private func parseContentItem(from item: SequenceItem, depth: Int) throws -> AnyContentItem? {
        // Get the Value Type (0040,A040)
        guard let valueTypeString = item.string(for: .valueType) else {
            if configuration.validationLevel == .strict {
                throw ParseError.missingRequiredAttribute(tag: "(0040,A040)", description: "Value Type")
            }
            return nil
        }
        
        guard let valueType = ContentItemValueType(rawValue: valueTypeString) else {
            if configuration.validationLevel == .strict {
                throw ParseError.unknownValueType(valueTypeString)
            }
            return nil
        }
        
        // Parse common attributes
        let conceptName = try? parseCodedConceptFromItem(item, tag: .conceptNameCodeSequence)
        let relationshipType = item.string(for: .relationshipType).flatMap { RelationshipType(rawValue: $0) }
        let observationDateTime = item.string(for: .observationDateTime)
        let observationUID = item.string(for: .observationUID)
        
        // Parse based on value type
        switch valueType {
        case .text:
            return try parseTextContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .code:
            return try parseCodeContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .num:
            return try parseNumericContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .date:
            return try parseDateContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .time:
            return try parseTimeContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .datetime:
            return try parseDateTimeContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .pname:
            return try parsePersonNameContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .uidref:
            return try parseUIDRefContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .composite:
            return try parseCompositeContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .image:
            return try parseImageContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .waveform:
            return try parseWaveformContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .scoord:
            return try parseSCoordContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .scoord3D:
            return try parseSCoord3DContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .tcoord:
            return try parseTCoordContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID)
            
        case .container:
            return try parseContainerContentItem(from: item, conceptName: conceptName, relationshipType: relationshipType, observationDateTime: observationDateTime, observationUID: observationUID, depth: depth)
        }
    }
    
    // MARK: - Value Type Specific Parsers
    
    private func parseTextContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let textValue = item.string(for: .textValue) ?? ""
        
        return AnyContentItem(TextContentItem(
            conceptName: conceptName,
            textValue: textValue,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseCodeContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        guard let conceptCode = try? parseCodedConceptFromItem(item, tag: .conceptCodeSequence) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidCodedConcept("Missing Concept Code Sequence for CODE content item")
            }
            // Return with a placeholder code for lenient mode
            return AnyContentItem(CodeContentItem(
                conceptName: conceptName,
                conceptCode: CodedConcept(codeValue: "UNKNOWN", codingSchemeDesignator: "99LOCAL", codeMeaning: "Unknown"),
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        return AnyContentItem(CodeContentItem(
            conceptName: conceptName,
            conceptCode: conceptCode,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseNumericContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        // Parse Measured Value Sequence (0040,A300) or direct Numeric Value (0040,A30A)
        var numericValues: [Double] = []
        var measurementUnits: CodedConcept?
        var floatingPointValues: [Double]?
        
        // Try Measured Value Sequence first
        if let measuredValueSeq = item[.measuredValueSequence]?.sequenceItems?.first {
            // Get Numeric Value from sequence
            if let numericValueStr = measuredValueSeq.string(for: .numericValue) {
                numericValues = numericValueStr.split(separator: "\\").compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
            }
            
            // Get Floating Point Value if present
            if let floatData = measuredValueSeq[.floatingPointValue]?.float64Values {
                floatingPointValues = floatData
            }
            
            // Get Measurement Units Code Sequence
            measurementUnits = try? parseCodedConceptFromItem(measuredValueSeq, tag: .measurementUnitsCodeSequence)
        } else {
            // Try direct Numeric Value (0040,A30A)
            if let numericValueStr = item.string(for: .numericValue) {
                numericValues = numericValueStr.split(separator: "\\").compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
            }
            
            // Try direct measurement units
            measurementUnits = try? parseCodedConceptFromItem(item, tag: .measurementUnitsCodeSequence)
        }
        
        // If no values found, use 0.0 as placeholder in lenient mode
        if numericValues.isEmpty && configuration.validationLevel != .strict {
            numericValues = [0.0]
        }
        
        return AnyContentItem(NumericContentItem(
            conceptName: conceptName,
            values: numericValues,
            units: measurementUnits,
            floatingPointValues: floatingPointValues,
            qualifier: nil,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseDateContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let dateValue = item.string(for: .date) ?? ""
        
        return AnyContentItem(DateContentItem(
            conceptName: conceptName,
            dateValue: dateValue,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseTimeContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let timeValue = item.string(for: .time) ?? ""
        
        return AnyContentItem(TimeContentItem(
            conceptName: conceptName,
            timeValue: timeValue,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseDateTimeContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let dateTimeValue = item.string(for: .dateTime) ?? ""
        
        return AnyContentItem(DateTimeContentItem(
            conceptName: conceptName,
            dateTimeValue: dateTimeValue,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parsePersonNameContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let personName = item.string(for: .personName) ?? ""
        
        return AnyContentItem(PersonNameContentItem(
            conceptName: conceptName,
            personName: personName,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseUIDRefContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        let uidValue = item.string(for: .uid) ?? ""
        
        return AnyContentItem(UIDRefContentItem(
            conceptName: conceptName,
            uidValue: uidValue,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseCompositeContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        guard let sopRef = try parseReferencedSOPSequence(from: item) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidReferencedSOPSequence("Missing Referenced SOP Sequence for COMPOSITE content item")
            }
            // Return placeholder in lenient mode
            return AnyContentItem(CompositeContentItem(
                conceptName: conceptName,
                referencedSOPSequence: ReferencedSOP(sopClassUID: "", sopInstanceUID: ""),
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        return AnyContentItem(CompositeContentItem(
            conceptName: conceptName,
            referencedSOPSequence: sopRef,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseImageContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        guard let sopRef = try parseReferencedSOPSequence(from: item) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidReferencedSOPSequence("Missing Referenced SOP Sequence for IMAGE content item")
            }
            // Return placeholder in lenient mode
            return AnyContentItem(ImageContentItem(
                conceptName: conceptName,
                imageReference: ImageReference(sopReference: ReferencedSOP(sopClassUID: "", sopInstanceUID: "")),
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        // Parse frame numbers if present
        var frameNumbers: [Int]?
        if let refSOPSeq = item[.referencedSOPSequence]?.sequenceItems?.first {
            if let frameNumStr = refSOPSeq.string(for: .referencedFrameNumber) {
                frameNumbers = frameNumStr.split(separator: "\\").compactMap { Int(String($0).trimmingCharacters(in: .whitespaces)) }
            }
        }
        
        // Parse segment numbers if present
        var segmentNumbers: [Int]?
        if let refSOPSeq = item[.referencedSOPSequence]?.sequenceItems?.first {
            if let segmentNumData = refSOPSeq[.referencedSegmentNumber]?.uint16Values {
                segmentNumbers = segmentNumData.map { Int($0) }
            }
        }
        
        // Parse purpose of reference if present
        var purposeOfReference: CodedConcept?
        if let refSOPSeq = item[.referencedSOPSequence]?.sequenceItems?.first {
            purposeOfReference = try? parseCodedConceptFromItem(refSOPSeq, tag: .purposeOfReferenceCodeSequence)
        }
        
        let imageRef = ImageReference(
            sopReference: sopRef,
            frameNumbers: frameNumbers,
            segmentNumbers: segmentNumbers,
            purposeOfReference: purposeOfReference
        )
        
        return AnyContentItem(ImageContentItem(
            conceptName: conceptName,
            imageReference: imageRef,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseWaveformContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        guard let sopRef = try parseReferencedSOPSequence(from: item) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidReferencedSOPSequence("Missing Referenced SOP Sequence for WAVEFORM content item")
            }
            // Return placeholder in lenient mode
            return AnyContentItem(WaveformContentItem(
                conceptName: conceptName,
                waveformReference: WaveformReference(sopReference: ReferencedSOP(sopClassUID: "", sopInstanceUID: "")),
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        // Parse channel numbers if present (from Referenced Waveform Channels)
        // Tag (0040,A0B0) - Referenced Waveform Channels is US VM: 2-2n
        var channelNumbers: [Int]?
        if let refSOPSeq = item[.referencedSOPSequence]?.sequenceItems?.first {
            let referencedWaveformChannels = Tag(group: 0x0040, element: 0xA0B0)
            if let channelData = refSOPSeq[referencedWaveformChannels]?.uint16Values {
                // Each pair is (multiplex group, channel number), extract channel numbers
                channelNumbers = stride(from: 1, to: channelData.count, by: 2).map { Int(channelData[$0]) }
            }
        }
        
        let waveformRef = WaveformReference(sopReference: sopRef, channelNumbers: channelNumbers)
        
        return AnyContentItem(WaveformContentItem(
            conceptName: conceptName,
            waveformReference: waveformRef,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseSCoordContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        // Parse Graphic Type (0070,0023)
        let graphicTypeTag = Tag(group: 0x0070, element: 0x0023)
        guard let graphicTypeStr = item.string(for: graphicTypeTag),
              let graphicType = GraphicType(rawValue: graphicTypeStr) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidGraphicData("Missing or invalid Graphic Type for SCOORD content item")
            }
            return AnyContentItem(SpatialCoordinatesContentItem(
                conceptName: conceptName,
                graphicType: .point,
                graphicData: [],
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        // Parse Graphic Data (0070,0022)
        let graphicDataTag = Tag(group: 0x0070, element: 0x0022)
        let graphicData = item[graphicDataTag]?.float32Values ?? []
        
        return AnyContentItem(SpatialCoordinatesContentItem(
            conceptName: conceptName,
            graphicType: graphicType,
            graphicData: graphicData,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseSCoord3DContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        // Parse Graphic Type (0070,0023)
        let graphicTypeTag = Tag(group: 0x0070, element: 0x0023)
        guard let graphicTypeStr = item.string(for: graphicTypeTag),
              let graphicType = GraphicType3D(rawValue: graphicTypeStr) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidGraphicData("Missing or invalid Graphic Type for SCOORD3D content item")
            }
            return AnyContentItem(SpatialCoordinates3DContentItem(
                conceptName: conceptName,
                graphicType: .point,
                graphicData: [],
                frameOfReferenceUID: nil,
                relationshipType: relationshipType,
                observationDateTime: observationDateTime,
                observationUID: observationUID
            ))
        }
        
        // Parse Graphic Data (0070,0022)
        let graphicDataTag = Tag(group: 0x0070, element: 0x0022)
        let graphicData = item[graphicDataTag]?.float32Values ?? []
        
        // Parse Referenced Frame of Reference UID (0020,0052)
        let frameOfRefTag = Tag(group: 0x0020, element: 0x0052)
        let frameOfReferenceUID = item.string(for: frameOfRefTag)
        
        return AnyContentItem(SpatialCoordinates3DContentItem(
            conceptName: conceptName,
            graphicType: graphicType,
            graphicData: graphicData,
            frameOfReferenceUID: frameOfReferenceUID,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    private func parseTCoordContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?
    ) throws -> AnyContentItem {
        // Parse Temporal Range Type (0040,A130)
        let temporalRangeTypeTag = Tag(group: 0x0040, element: 0xA130)
        guard let temporalRangeTypeStr = item.string(for: temporalRangeTypeTag),
              let temporalRangeType = TemporalRangeType(rawValue: temporalRangeTypeStr) else {
            if configuration.validationLevel == .strict {
                throw ParseError.invalidGraphicData("Missing or invalid Temporal Range Type for TCOORD content item")
            }
            return AnyContentItem(TemporalCoordinatesContentItem(
                conceptName: conceptName,
                temporalRangeType: .point,
                samplePositions: [],
                relationshipType: relationshipType
            ))
        }
        
        // Try to parse Referenced Sample Positions (0040,A132)
        let samplePositionsTag = Tag(group: 0x0040, element: 0xA132)
        if let samplePositions = item[samplePositionsTag]?.uint32Values {
            return AnyContentItem(TemporalCoordinatesContentItem(
                conceptName: conceptName,
                temporalRangeType: temporalRangeType,
                samplePositions: samplePositions,
                relationshipType: relationshipType
            ))
        }
        
        // Try to parse Referenced Time Offsets (0040,A138)
        let timeOffsetsTag = Tag(group: 0x0040, element: 0xA138)
        if let timeOffsetStr = item.string(for: timeOffsetsTag) {
            let timeOffsets = timeOffsetStr.split(separator: "\\").compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
            return AnyContentItem(TemporalCoordinatesContentItem(
                conceptName: conceptName,
                temporalRangeType: temporalRangeType,
                timeOffsets: timeOffsets,
                relationshipType: relationshipType
            ))
        }
        
        // Try to parse Referenced DateTime (0040,A13A)
        let dateTimeTag = Tag(group: 0x0040, element: 0xA13A)
        if let dateTimeStr = item.string(for: dateTimeTag) {
            let dateTimes = dateTimeStr.split(separator: "\\").map { String($0) }
            return AnyContentItem(TemporalCoordinatesContentItem(
                conceptName: conceptName,
                temporalRangeType: temporalRangeType,
                dateTimes: dateTimes,
                relationshipType: relationshipType
            ))
        }
        
        // Return empty if no temporal data found
        return AnyContentItem(TemporalCoordinatesContentItem(
            conceptName: conceptName,
            temporalRangeType: temporalRangeType,
            samplePositions: [],
            relationshipType: relationshipType
        ))
    }
    
    private func parseContainerContentItem(
        from item: SequenceItem,
        conceptName: CodedConcept?,
        relationshipType: RelationshipType?,
        observationDateTime: String?,
        observationUID: String?,
        depth: Int
    ) throws -> AnyContentItem {
        // Parse Continuity of Content
        let continuityString = item.string(for: .continuityOfContent)
        let continuity = continuityString.flatMap { ContinuityOfContent(rawValue: $0) } ?? .separate
        
        // Parse template identifier if present
        let templateIdentifier = parseTemplateIdentifierFromItem(item)
        
        // Parse nested Content Sequence
        var contentItems: [AnyContentItem] = []
        if let contentSequence = item[.contentSequence]?.sequenceItems {
            contentItems = try parseContentSequence(contentSequence, depth: depth + 1)
        }
        
        return AnyContentItem(ContainerContentItem(
            conceptName: conceptName,
            continuityOfContent: continuity,
            contentItems: contentItems,
            templateIdentifier: templateIdentifier?.identifier,
            mappingResource: templateIdentifier?.mappingResource,
            relationshipType: relationshipType,
            observationDateTime: observationDateTime,
            observationUID: observationUID
        ))
    }
    
    // MARK: - Helper Methods
    
    private func extractRequiredString(from dataSet: DataSet, tag: Tag, description: String) throws -> String {
        guard let value = dataSet.string(for: tag), !value.isEmpty else {
            if configuration.validationLevel == .strict {
                throw ParseError.missingRequiredAttribute(tag: tag.description, description: description)
            }
            return ""
        }
        return value
    }
    
    /// Parses a coded concept from a sequence at the given tag
    private func parseCodedConcept(from dataSet: DataSet, tag: Tag) throws -> CodedConcept? {
        guard let sequence = dataSet.sequence(for: tag),
              let firstItem = sequence.first else {
            return nil
        }
        return parseCodedConceptFromSequenceItem(firstItem)
    }
    
    /// Parses a coded concept from a sequence item at the given tag
    private func parseCodedConceptFromItem(_ item: SequenceItem, tag: Tag) throws -> CodedConcept? {
        guard let sequence = item[tag]?.sequenceItems,
              let firstItem = sequence.first else {
            return nil
        }
        return parseCodedConceptFromSequenceItem(firstItem)
    }
    
    /// Parses a coded concept from a sequence item containing code attributes
    private func parseCodedConceptFromSequenceItem(_ item: SequenceItem) -> CodedConcept? {
        // Get Code Value (0008,0100)
        guard let codeValue = item.string(for: .codeValue) else {
            // Try Long Code Value (0008,0119) if Code Value is missing
            guard let longCodeValue = item.string(for: .longCodeValue) else {
                // Try URN Code Value (0008,0120) if Long Code Value is also missing
                guard let urnCodeValue = item.string(for: .urnCodeValue) else {
                    return nil
                }
                // URN Code Value case
                guard let codingSchemeDesignator = item.string(for: .codingSchemeDesignator),
                      let codeMeaning = item.string(for: .codeMeaning) else {
                    return nil
                }
                return CodedConcept(
                    codeValue: "",
                    codingSchemeDesignator: codingSchemeDesignator,
                    codeMeaning: codeMeaning,
                    codingSchemeVersion: item.string(for: .codingSchemeVersion),
                    longCodeValue: nil,
                    urnCodeValue: urnCodeValue
                )
            }
            // Long Code Value case
            guard let codingSchemeDesignator = item.string(for: .codingSchemeDesignator),
                  let codeMeaning = item.string(for: .codeMeaning) else {
                return nil
            }
            return CodedConcept(
                codeValue: "",
                codingSchemeDesignator: codingSchemeDesignator,
                codeMeaning: codeMeaning,
                codingSchemeVersion: item.string(for: .codingSchemeVersion),
                longCodeValue: longCodeValue,
                urnCodeValue: nil
            )
        }
        
        // Standard case with Code Value
        guard let codingSchemeDesignator = item.string(for: .codingSchemeDesignator),
              let codeMeaning = item.string(for: .codeMeaning) else {
            return nil
        }
        
        return CodedConcept(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning,
            codingSchemeVersion: item.string(for: .codingSchemeVersion),
            longCodeValue: item.string(for: .longCodeValue),
            urnCodeValue: item.string(for: .urnCodeValue)
        )
    }
    
    /// Parses Referenced SOP Sequence from a content item
    private func parseReferencedSOPSequence(from item: SequenceItem) throws -> ReferencedSOP? {
        guard let refSOPSeq = item[.referencedSOPSequence]?.sequenceItems?.first else {
            return nil
        }
        
        guard let sopClassUID = refSOPSeq.string(for: .referencedSOPClassUID),
              let sopInstanceUID = refSOPSeq.string(for: .referencedSOPInstanceUID) else {
            return nil
        }
        
        return ReferencedSOP(sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID)
    }
    
    /// Template identifier info
    private struct TemplateInfo {
        let identifier: String
        let mappingResource: String?
    }
    
    /// Parses template identifier from a data set
    private func parseTemplateIdentifier(from dataSet: DataSet) -> TemplateInfo? {
        guard let templateSeq = dataSet.sequence(for: .contentTemplateSequence),
              let firstItem = templateSeq.first else {
            return nil
        }
        
        guard let templateID = firstItem.string(for: .templateIdentifier) else {
            return nil
        }
        
        let mappingResource = firstItem.string(for: .mappingResource)
        
        return TemplateInfo(identifier: templateID, mappingResource: mappingResource)
    }
    
    /// Parses template identifier from a sequence item
    private func parseTemplateIdentifierFromItem(_ item: SequenceItem) -> TemplateInfo? {
        guard let templateSeq = item[.contentTemplateSequence]?.sequenceItems,
              let firstItem = templateSeq.first else {
            return nil
        }
        
        guard let templateID = firstItem.string(for: .templateIdentifier) else {
            return nil
        }
        
        let mappingResource = firstItem.string(for: .mappingResource)
        
        return TemplateInfo(identifier: templateID, mappingResource: mappingResource)
    }
}

// MARK: - Additional Tag Extensions for SR Parsing
// Note: contentDate and contentTime are already defined in Tag+ImageInformation.swift

extension Tag {
    /// Measured Value Sequence (0040,A300)
    /// VR: SQ, VM: 1
    static let measuredValueSequence = Tag(group: 0x0040, element: 0xA300)
    
    /// Floating Point Value (0040,A161)
    /// VR: FD, VM: 1-n
    static let floatingPointValue = Tag(group: 0x0040, element: 0xA161)
    
    /// Observation UID (0040,A171)
    /// VR: UI, VM: 1
    static let observationUID = Tag(group: 0x0040, element: 0xA171)
}
