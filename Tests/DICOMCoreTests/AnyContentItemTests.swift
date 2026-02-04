import Testing
@testable import DICOMCore

// MARK: - AnyContentItem Tests

@Suite("AnyContentItem Tests")
struct AnyContentItemTests {
    
    // MARK: - Initialization Tests
    
    @Test("Create from TextContentItem")
    func testCreateFromText() {
        let textItem = TextContentItem(textValue: "Test finding")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.valueType == .text)
        #expect(anyItem.asText != nil)
        #expect(anyItem.asText?.textValue == "Test finding")
    }
    
    @Test("Create from CodeContentItem")
    func testCreateFromCode() {
        let code = CodedConcept.finding
        let codeItem = CodeContentItem(conceptCode: code)
        let anyItem = AnyContentItem(codeItem)
        
        #expect(anyItem.valueType == .code)
        #expect(anyItem.asCode != nil)
        #expect(anyItem.asCode?.conceptCode == code)
    }
    
    @Test("Create from NumericContentItem")
    func testCreateFromNumeric() {
        let numItem = NumericContentItem(value: 42.5, units: .unitMillimeter)
        let anyItem = AnyContentItem(numItem)
        
        #expect(anyItem.valueType == .num)
        #expect(anyItem.asNumeric != nil)
        #expect(anyItem.asNumeric?.value == 42.5)
    }
    
    @Test("Create from DateContentItem")
    func testCreateFromDate() {
        let dateItem = DateContentItem(dateValue: "20240115")
        let anyItem = AnyContentItem(dateItem)
        
        #expect(anyItem.valueType == .date)
        #expect(anyItem.asDate != nil)
        #expect(anyItem.asDate?.dateValue == "20240115")
    }
    
    @Test("Create from TimeContentItem")
    func testCreateFromTime() {
        let timeItem = TimeContentItem(timeValue: "143000")
        let anyItem = AnyContentItem(timeItem)
        
        #expect(anyItem.valueType == .time)
        #expect(anyItem.asTime != nil)
    }
    
    @Test("Create from DateTimeContentItem")
    func testCreateFromDateTime() {
        let dtItem = DateTimeContentItem(dateTimeValue: "20240115143000")
        let anyItem = AnyContentItem(dtItem)
        
        #expect(anyItem.valueType == .datetime)
        #expect(anyItem.asDateTime != nil)
    }
    
    @Test("Create from PersonNameContentItem")
    func testCreateFromPersonName() {
        let pnItem = PersonNameContentItem(personName: "Smith^John")
        let anyItem = AnyContentItem(pnItem)
        
        #expect(anyItem.valueType == .pname)
        #expect(anyItem.asPersonName != nil)
    }
    
    @Test("Create from UIDRefContentItem")
    func testCreateFromUIDRef() {
        let uidItem = UIDRefContentItem(uidValue: "1.2.3.4.5")
        let anyItem = AnyContentItem(uidItem)
        
        #expect(anyItem.valueType == .uidref)
        #expect(anyItem.asUIDRef != nil)
    }
    
    @Test("Create from CompositeContentItem")
    func testCreateFromComposite() {
        let compItem = CompositeContentItem(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let anyItem = AnyContentItem(compItem)
        
        #expect(anyItem.valueType == .composite)
        #expect(anyItem.asComposite != nil)
    }
    
    @Test("Create from ImageContentItem")
    func testCreateFromImage() {
        let imgItem = ImageContentItem(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let anyItem = AnyContentItem(imgItem)
        
        #expect(anyItem.valueType == .image)
        #expect(anyItem.asImage != nil)
    }
    
    @Test("Create from WaveformContentItem")
    func testCreateFromWaveform() {
        let waveRef = WaveformReference(
            sopReference: ReferencedSOP(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        )
        let waveItem = WaveformContentItem(waveformReference: waveRef)
        let anyItem = AnyContentItem(waveItem)
        
        #expect(anyItem.valueType == .waveform)
        #expect(anyItem.asWaveform != nil)
    }
    
    @Test("Create from SpatialCoordinatesContentItem")
    func testCreateFromScoord() {
        let scoordItem = SpatialCoordinatesContentItem(
            graphicType: .point,
            graphicData: [100.0, 200.0]
        )
        let anyItem = AnyContentItem(scoordItem)
        
        #expect(anyItem.valueType == .scoord)
        #expect(anyItem.asSpatialCoordinates != nil)
    }
    
    @Test("Create from SpatialCoordinates3DContentItem")
    func testCreateFromScoord3D() {
        let scoord3DItem = SpatialCoordinates3DContentItem(
            graphicType: .point,
            graphicData: [10.0, 20.0, 30.0]
        )
        let anyItem = AnyContentItem(scoord3DItem)
        
        #expect(anyItem.valueType == .scoord3D)
        #expect(anyItem.asSpatialCoordinates3D != nil)
    }
    
    @Test("Create from TemporalCoordinatesContentItem")
    func testCreateFromTcoord() {
        let tcoordItem = TemporalCoordinatesContentItem(
            temporalRangeType: .point,
            samplePositions: [100]
        )
        let anyItem = AnyContentItem(tcoordItem)
        
        #expect(anyItem.valueType == .tcoord)
        #expect(anyItem.asTemporalCoordinates != nil)
    }
    
    @Test("Create from ContainerContentItem")
    func testCreateFromContainer() {
        let containerItem = ContainerContentItem(continuityOfContent: .separate)
        let anyItem = AnyContentItem(containerItem)
        
        #expect(anyItem.valueType == .container)
        #expect(anyItem.asContainer != nil)
        #expect(anyItem.isContainer == true)
    }
    
    // MARK: - Common Properties Tests
    
    @Test("Access concept name through AnyContentItem")
    func testConceptNameAccess() {
        let concept = CodedConcept.finding
        let textItem = TextContentItem(conceptName: concept, textValue: "Test")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.conceptName == concept)
    }
    
    @Test("Access relationship type through AnyContentItem")
    func testRelationshipTypeAccess() {
        let textItem = TextContentItem(
            textValue: "Test",
            relationshipType: .hasProperties
        )
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.relationshipType == .hasProperties)
    }
    
    @Test("Access observation date time through AnyContentItem")
    func testObservationDateTimeAccess() {
        let textItem = TextContentItem(
            textValue: "Test",
            observationDateTime: "20240115120000"
        )
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.observationDateTime == "20240115120000")
    }
    
    // MARK: - Type-Specific Access Tests
    
    @Test("Wrong type access returns nil")
    func testWrongTypeAccessReturnsNil() {
        let textItem = TextContentItem(textValue: "Test")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.asText != nil)
        #expect(anyItem.asCode == nil)
        #expect(anyItem.asNumeric == nil)
        #expect(anyItem.asContainer == nil)
    }
    
    // MARK: - Utility Properties Tests
    
    @Test("isReference property")
    func testIsReferenceProperty() {
        let imgItem = ImageContentItem(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let textItem = TextContentItem(textValue: "Test")
        
        #expect(AnyContentItem(imgItem).isReference == true)
        #expect(AnyContentItem(textItem).isReference == false)
    }
    
    @Test("isCoordinate property")
    func testIsCoordinateProperty() {
        let scoordItem = SpatialCoordinatesContentItem(
            graphicType: .point,
            graphicData: [100.0, 200.0]
        )
        let textItem = TextContentItem(textValue: "Test")
        
        #expect(AnyContentItem(scoordItem).isCoordinate == true)
        #expect(AnyContentItem(textItem).isCoordinate == false)
    }
    
    @Test("children property for container")
    func testChildrenProperty() {
        let childItem = AnyContentItem(TextContentItem(textValue: "Child"))
        let containerItem = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: [childItem]
        )
        let anyItem = AnyContentItem(containerItem)
        
        #expect(anyItem.children?.count == 1)
        #expect(anyItem.children?.first?.asText?.textValue == "Child")
    }
    
    @Test("children property for non-container")
    func testChildrenPropertyForNonContainer() {
        let textItem = TextContentItem(textValue: "Test")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.children == nil)
    }
    
    // MARK: - Equatable Tests
    
    @Test("Equatable conformance")
    func testEquatable() {
        let item1 = AnyContentItem(TextContentItem(textValue: "Test"))
        let item2 = AnyContentItem(TextContentItem(textValue: "Test"))
        let item3 = AnyContentItem(TextContentItem(textValue: "Different"))
        
        #expect(item1 == item2)
        #expect(item1 != item3)
    }
    
    @Test("Different types are not equal")
    func testDifferentTypesNotEqual() {
        let textItem = AnyContentItem(TextContentItem(textValue: "Test"))
        let codeItem = AnyContentItem(CodeContentItem(conceptCode: .finding))
        
        #expect(textItem != codeItem)
    }
    
    // MARK: - Hashable Tests
    
    @Test("Hashable conformance")
    func testHashable() {
        let item1 = AnyContentItem(TextContentItem(textValue: "Test"))
        let item2 = AnyContentItem(TextContentItem(textValue: "Test"))
        
        var set = Set<AnyContentItem>()
        set.insert(item1)
        set.insert(item2)
        
        #expect(set.count == 1)
    }
    
    // MARK: - Description Tests
    
    @Test("Description format")
    func testDescription() {
        let concept = CodedConcept.finding
        let textItem = TextContentItem(conceptName: concept, textValue: "Test")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.description == "TEXT: Finding")
    }
    
    @Test("Description format without concept name")
    func testDescriptionWithoutConceptName() {
        let textItem = TextContentItem(textValue: "Test")
        let anyItem = AnyContentItem(textItem)
        
        #expect(anyItem.description == "TEXT: unnamed")
    }
    
    // MARK: - Convenience Initializers Tests
    
    @Test("Static text factory method")
    func testStaticTextFactory() {
        let item = AnyContentItem.text(
            conceptName: .finding,
            value: "Test finding",
            relationshipType: .hasProperties
        )
        
        #expect(item.valueType == .text)
        #expect(item.asText?.textValue == "Test finding")
        #expect(item.conceptName == .finding)
        #expect(item.relationshipType == .hasProperties)
    }
    
    @Test("Static code factory method")
    func testStaticCodeFactory() {
        let item = AnyContentItem.code(
            conceptName: .finding,
            value: .person,
            relationshipType: .contains
        )
        
        #expect(item.valueType == .code)
        #expect(item.asCode?.conceptCode == .person)
    }
    
    @Test("Static numeric factory method")
    func testStaticNumericFactory() {
        let item = AnyContentItem.numeric(
            conceptName: .measurement,
            value: 42.5,
            units: .unitMillimeter
        )
        
        #expect(item.valueType == .num)
        #expect(item.asNumeric?.value == 42.5)
    }
    
    @Test("Static container factory method")
    func testStaticContainerFactory() {
        let childItem = AnyContentItem.text(value: "Child")
        let item = AnyContentItem.container(
            conceptName: .finding,
            continuityOfContent: .continuous,
            items: [childItem]
        )
        
        #expect(item.valueType == .container)
        #expect(item.asContainer?.continuityOfContent == .continuous)
        #expect(item.asContainer?.childCount == 1)
    }
}
