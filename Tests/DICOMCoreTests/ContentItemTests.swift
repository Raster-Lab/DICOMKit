import Testing
@testable import DICOMCore

// MARK: - TextContentItem Tests

@Suite("TextContentItem Tests")
struct TextContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = TextContentItem(textValue: "Test finding description")
        
        #expect(item.valueType == .text)
        #expect(item.textValue == "Test finding description")
        #expect(item.conceptName == nil)
        #expect(item.relationshipType == nil)
    }
    
    @Test("Creation with concept name")
    func testCreationWithConceptName() {
        let concept = CodedConcept.finding
        let item = TextContentItem(
            conceptName: concept,
            textValue: "Nodule in right lung",
            relationshipType: .hasProperties
        )
        
        #expect(item.conceptName == concept)
        #expect(item.textValue == "Nodule in right lung")
        #expect(item.relationshipType == .hasProperties)
    }
    
    @Test("Equatable conformance")
    func testEquatable() {
        let item1 = TextContentItem(textValue: "Test")
        let item2 = TextContentItem(textValue: "Test")
        let item3 = TextContentItem(textValue: "Different")
        
        #expect(item1 == item2)
        #expect(item1 != item3)
    }
}

// MARK: - CodeContentItem Tests

@Suite("CodeContentItem Tests")
struct CodeContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let code = CodedConcept(codeValue: "F-01234", scheme: .SRT, codeMeaning: "Lung mass")
        let item = CodeContentItem(conceptCode: code)
        
        #expect(item.valueType == .code)
        #expect(item.conceptCode == code)
    }
    
    @Test("Creation with all fields")
    func testCreationWithAllFields() {
        let conceptName = CodedConcept.finding
        let conceptCode = CodedConcept(codeValue: "F-01234", scheme: .SRT, codeMeaning: "Lung mass")
        let item = CodeContentItem(
            conceptName: conceptName,
            conceptCode: conceptCode,
            relationshipType: .contains,
            observationDateTime: "20240115120000"
        )
        
        #expect(item.conceptName == conceptName)
        #expect(item.conceptCode == conceptCode)
        #expect(item.relationshipType == .contains)
        #expect(item.observationDateTime == "20240115120000")
    }
}

// MARK: - NumericContentItem Tests

@Suite("NumericContentItem Tests")
struct NumericContentItemTests {
    
    @Test("Single value creation")
    func testSingleValueCreation() {
        let item = NumericContentItem(value: 42.5, units: .unitMillimeter)
        
        #expect(item.valueType == .num)
        #expect(item.value == 42.5)
        #expect(item.numericValues == [42.5])
        #expect(item.measurementUnits == .unitMillimeter)
    }
    
    @Test("Multiple values creation")
    func testMultipleValuesCreation() {
        let item = NumericContentItem(
            values: [10.0, 20.0, 30.0],
            units: .unitCentimeter
        )
        
        #expect(item.numericValues == [10.0, 20.0, 30.0])
        #expect(item.value == 10.0) // First value
    }
    
    @Test("Creation with qualifier")
    func testCreationWithQualifier() {
        let item = NumericContentItem(
            values: [],
            qualifier: .notANumber
        )
        
        #expect(item.numericValueQualifier == .notANumber)
    }
    
    @Test("Measurement with concept name")
    func testMeasurementWithConceptName() {
        let conceptName = CodedConcept.measurement
        let item = NumericContentItem(
            conceptName: conceptName,
            value: 15.5,
            units: .unitMillimeter,
            relationshipType: .hasProperties
        )
        
        #expect(item.conceptName == conceptName)
        #expect(item.relationshipType == .hasProperties)
    }
}

// MARK: - DateContentItem Tests

@Suite("DateContentItem Tests")
struct DateContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = DateContentItem(dateValue: "20240115")
        
        #expect(item.valueType == .date)
        #expect(item.dateValue == "20240115")
    }
    
    @Test("Creation with concept name")
    func testCreationWithConceptName() {
        let concept = CodedConcept(codeValue: "111060", scheme: .DCM, codeMeaning: "Study Date")
        let item = DateContentItem(
            conceptName: concept,
            dateValue: "20240115"
        )
        
        #expect(item.conceptName == concept)
    }
}

// MARK: - TimeContentItem Tests

@Suite("TimeContentItem Tests")
struct TimeContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = TimeContentItem(timeValue: "143000.000000")
        
        #expect(item.valueType == .time)
        #expect(item.timeValue == "143000.000000")
    }
}

// MARK: - DateTimeContentItem Tests

@Suite("DateTimeContentItem Tests")
struct DateTimeContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = DateTimeContentItem(dateTimeValue: "20240115143000.000000")
        
        #expect(item.valueType == .datetime)
        #expect(item.dateTimeValue == "20240115143000.000000")
    }
}

// MARK: - PersonNameContentItem Tests

@Suite("PersonNameContentItem Tests")
struct PersonNameContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = PersonNameContentItem(personName: "Smith^John")
        
        #expect(item.valueType == .pname)
        #expect(item.personName == "Smith^John")
    }
    
    @Test("Creation with concept name")
    func testCreationWithConceptName() {
        let concept = CodedConcept.personObserverName
        let item = PersonNameContentItem(
            conceptName: concept,
            personName: "Doe^Jane^MD",
            relationshipType: .hasObsContext
        )
        
        #expect(item.conceptName == concept)
        #expect(item.relationshipType == .hasObsContext)
    }
}

// MARK: - UIDRefContentItem Tests

@Suite("UIDRefContentItem Tests")
struct UIDRefContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = UIDRefContentItem(uidValue: "1.2.840.10008.5.1.4.1.1.2")
        
        #expect(item.valueType == .uidref)
        #expect(item.uidValue == "1.2.840.10008.5.1.4.1.1.2")
    }
}

// MARK: - CompositeContentItem Tests

@Suite("CompositeContentItem Tests")
struct CompositeContentItemTests {
    
    @Test("Basic creation with SOP reference")
    func testBasicCreation() {
        let sopRef = ReferencedSOP(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
        let item = CompositeContentItem(referencedSOPSequence: sopRef)
        
        #expect(item.valueType == .composite)
        #expect(item.referencedSOPSequence == sopRef)
    }
    
    @Test("Convenience creation with UIDs")
    func testConvenienceCreation() {
        let item = CompositeContentItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        #expect(item.referencedSOPSequence.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(item.referencedSOPSequence.sopInstanceUID == "1.2.3.4.5")
    }
}

// MARK: - ImageContentItem Tests

@Suite("ImageContentItem Tests")
struct ImageContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let item = ImageContentItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        #expect(item.valueType == .image)
        #expect(item.imageReference.sopReference.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
    }
    
    @Test("Creation with frame numbers")
    func testCreationWithFrameNumbers() {
        let item = ImageContentItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            frameNumbers: [1, 5, 10]
        )
        
        #expect(item.imageReference.frameNumbers == [1, 5, 10])
    }
}

// MARK: - WaveformContentItem Tests

@Suite("WaveformContentItem Tests")
struct WaveformContentItemTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let waveformRef = WaveformReference(
            sopReference: ReferencedSOP(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6"),
            channelNumbers: [1, 2]
        )
        let item = WaveformContentItem(waveformReference: waveformRef)
        
        #expect(item.valueType == .waveform)
        #expect(item.waveformReference.channelNumbers == [1, 2])
    }
}

// MARK: - SpatialCoordinatesContentItem Tests

@Suite("SpatialCoordinatesContentItem Tests")
struct SpatialCoordinatesContentItemTests {
    
    @Test("Point creation")
    func testPointCreation() {
        let item = SpatialCoordinatesContentItem(
            graphicType: .point,
            graphicData: [100.0, 200.0]
        )
        
        #expect(item.valueType == .scoord)
        #expect(item.graphicType == .point)
        #expect(item.pointCount == 1)
    }
    
    @Test("Polyline creation")
    func testPolylineCreation() {
        let item = SpatialCoordinatesContentItem(
            graphicType: .polyline,
            graphicData: [0.0, 0.0, 100.0, 0.0, 100.0, 100.0, 0.0, 100.0]
        )
        
        #expect(item.graphicType == .polyline)
        #expect(item.pointCount == 4)
    }
    
    @Test("Points extraction")
    func testPointsExtraction() {
        let item = SpatialCoordinatesContentItem(
            graphicType: .polyline,
            graphicData: [10.0, 20.0, 30.0, 40.0]
        )
        
        let points = item.points
        #expect(points.count == 2)
        #expect(points[0].column == 10.0)
        #expect(points[0].row == 20.0)
        #expect(points[1].column == 30.0)
        #expect(points[1].row == 40.0)
    }
    
    @Test("Circle creation")
    func testCircleCreation() {
        let item = SpatialCoordinatesContentItem(
            graphicType: .circle,
            graphicData: [100.0, 100.0, 150.0, 100.0]
        )
        
        #expect(item.graphicType == .circle)
        #expect(item.pointCount == 2)
    }
}

// MARK: - SpatialCoordinates3DContentItem Tests

@Suite("SpatialCoordinates3DContentItem Tests")
struct SpatialCoordinates3DContentItemTests {
    
    @Test("Point creation")
    func testPointCreation() {
        let item = SpatialCoordinates3DContentItem(
            graphicType: .point,
            graphicData: [10.0, 20.0, 30.0]
        )
        
        #expect(item.valueType == .scoord3D)
        #expect(item.graphicType == .point)
        #expect(item.pointCount == 1)
    }
    
    @Test("Points extraction")
    func testPointsExtraction() {
        let item = SpatialCoordinates3DContentItem(
            graphicType: .polyline,
            graphicData: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        )
        
        let points = item.points
        #expect(points.count == 2)
        #expect(points[0].x == 1.0)
        #expect(points[0].y == 2.0)
        #expect(points[0].z == 3.0)
        #expect(points[1].x == 4.0)
        #expect(points[1].y == 5.0)
        #expect(points[1].z == 6.0)
    }
    
    @Test("Creation with frame of reference")
    func testCreationWithFrameOfReference() {
        let item = SpatialCoordinates3DContentItem(
            graphicType: .point,
            graphicData: [0.0, 0.0, 0.0],
            frameOfReferenceUID: "1.2.3.4.5.6.7"
        )
        
        #expect(item.frameOfReferenceUID == "1.2.3.4.5.6.7")
    }
}

// MARK: - TemporalCoordinatesContentItem Tests

@Suite("TemporalCoordinatesContentItem Tests")
struct TemporalCoordinatesContentItemTests {
    
    @Test("Sample positions creation")
    func testSamplePositionsCreation() {
        let item = TemporalCoordinatesContentItem(
            temporalRangeType: .point,
            samplePositions: [100, 200, 300]
        )
        
        #expect(item.valueType == .tcoord)
        #expect(item.temporalRangeType == .point)
        #expect(item.referencedSamplePositions == [100, 200, 300])
        #expect(item.referencedTimeOffsets == nil)
        #expect(item.referencedDateTime == nil)
    }
    
    @Test("Time offsets creation")
    func testTimeOffsetsCreation() {
        let item = TemporalCoordinatesContentItem(
            temporalRangeType: .segment,
            timeOffsets: [0.0, 1.5, 3.0]
        )
        
        #expect(item.temporalRangeType == .segment)
        #expect(item.referencedTimeOffsets == [0.0, 1.5, 3.0])
        #expect(item.referencedSamplePositions == nil)
    }
    
    @Test("DateTime creation")
    func testDateTimeCreation() {
        let item = TemporalCoordinatesContentItem(
            temporalRangeType: .multipoint,
            dateTimes: ["20240115100000", "20240115110000"]
        )
        
        #expect(item.temporalRangeType == .multipoint)
        #expect(item.referencedDateTime == ["20240115100000", "20240115110000"])
    }
}

// MARK: - ContainerContentItem Tests

@Suite("ContainerContentItem Tests")
struct ContainerContentItemTests {
    
    @Test("Empty container creation")
    func testEmptyContainerCreation() {
        let item = ContainerContentItem(continuityOfContent: .separate)
        
        #expect(item.valueType == .container)
        #expect(item.continuityOfContent == .separate)
        #expect(item.isEmpty == true)
        #expect(item.childCount == 0)
    }
    
    @Test("Container with children")
    func testContainerWithChildren() {
        let textItem = AnyContentItem(TextContentItem(textValue: "Test"))
        let codeItem = AnyContentItem(CodeContentItem(
            conceptCode: CodedConcept.finding
        ))
        
        let container = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: [textItem, codeItem]
        )
        
        #expect(container.isEmpty == false)
        #expect(container.childCount == 2)
    }
    
    @Test("Container adding items")
    func testContainerAddingItems() {
        let container = ContainerContentItem(continuityOfContent: .separate)
        let textItem = AnyContentItem(TextContentItem(textValue: "Test"))
        
        let newContainer = container.adding([textItem])
        
        #expect(container.childCount == 0) // Original unchanged
        #expect(newContainer.childCount == 1)
    }
    
    @Test("Continuous container")
    func testContinuousContainer() {
        let item = ContainerContentItem(continuityOfContent: .continuous)
        
        #expect(item.continuityOfContent == .continuous)
    }
    
    @Test("Container with template")
    func testContainerWithTemplate() {
        let container = ContainerContentItem(
            conceptName: CodedConcept.finding,
            continuityOfContent: .separate,
            templateIdentifier: "TID_1500",
            mappingResource: "DCMR"
        )
        
        #expect(container.templateIdentifier == "TID_1500")
        #expect(container.mappingResource == "DCMR")
    }
}
