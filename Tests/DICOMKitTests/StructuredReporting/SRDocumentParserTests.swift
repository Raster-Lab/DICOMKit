import Testing
import Foundation
import DICOMCore
@testable import DICOMKit

// MARK: - SRDocument Tests

@Suite("SRDocument Tests")
struct SRDocumentTests {
    
    @Test("Document creation with minimal attributes")
    func testMinimalDocumentCreation() {
        let rootContent = ContainerContentItem(
            conceptName: CodedConcept.finding,
            continuityOfContent: .separate,
            contentItems: []
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            rootContent: rootContent
        )
        
        #expect(document.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.33")
        #expect(document.sopInstanceUID == "1.2.3.4.5.6.7.8.9")
        #expect(document.documentType == .comprehensiveSR)
        #expect(document.contentItemCount == 0)
    }
    
    @Test("Document type detection from SOP Class UID")
    func testDocumentTypeDetection() {
        let testCases: [(String, SRDocumentType)] = [
            ("1.2.840.10008.5.1.4.1.1.88.11", .basicTextSR),
            ("1.2.840.10008.5.1.4.1.1.88.22", .enhancedSR),
            ("1.2.840.10008.5.1.4.1.1.88.33", .comprehensiveSR),
            ("1.2.840.10008.5.1.4.1.1.88.34", .comprehensive3DSR),
            ("1.2.840.10008.5.1.4.1.1.88.59", .keyObjectSelectionDocument),
        ]
        
        for (sopClassUID, expectedType) in testCases {
            let rootContent = ContainerContentItem(continuityOfContent: .separate, contentItems: [])
            let document = SRDocument(
                sopClassUID: sopClassUID,
                sopInstanceUID: "1.2.3",
                rootContent: rootContent
            )
            
            #expect(document.documentType == expectedType)
        }
    }
    
    @Test("Document with nested content items")
    func testNestedContentItems() {
        // Create a hierarchy of content items
        let innerItems: [AnyContentItem] = [
            AnyContentItem(TextContentItem(textValue: "Inner text 1")),
            AnyContentItem(TextContentItem(textValue: "Inner text 2")),
        ]
        
        let nestedContainer = ContainerContentItem(
            conceptName: CodedConcept.finding,
            continuityOfContent: .separate,
            contentItems: innerItems,
            relationshipType: .contains
        )
        
        let rootItems: [AnyContentItem] = [
            AnyContentItem(TextContentItem(textValue: "Root text")),
            AnyContentItem(nestedContainer),
        ]
        
        let rootContent = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: rootItems
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            rootContent: rootContent
        )
        
        // Root has 2 items, nested container has 2 items = 4 total
        #expect(document.contentItemCount == 4)
        
        // All content items should include the nested ones
        let allItems = document.allContentItems
        #expect(allItems.count == 4)
    }
    
    @Test("Find content items by value type")
    func testFindContentItemsByType() {
        let rootItems: [AnyContentItem] = [
            AnyContentItem(TextContentItem(textValue: "Text 1")),
            AnyContentItem(TextContentItem(textValue: "Text 2")),
            AnyContentItem(CodeContentItem(conceptCode: CodedConcept.finding)),
            AnyContentItem(NumericContentItem(value: 42.0, units: CodedConcept.unitMillimeter)),
        ]
        
        let rootContent = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: rootItems
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3",
            rootContent: rootContent
        )
        
        let textItems = document.findTextItems()
        let codeItems = document.findCodeItems()
        let numericItems = document.findNumericItems()
        
        #expect(textItems.count == 2)
        #expect(codeItems.count == 1)
        #expect(numericItems.count == 1)
    }
    
    @Test("Find content items by concept name")
    func testFindContentItemsByConceptName() {
        let findingConcept = CodedConcept.finding
        let measurementConcept = CodedConcept.measurement
        
        let rootItems: [AnyContentItem] = [
            AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Text 1")),
            AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Text 2")),
            AnyContentItem(NumericContentItem(conceptName: measurementConcept, value: 42.0)),
        ]
        
        let rootContent = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: rootItems
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3",
            rootContent: rootContent
        )
        
        let findingItems = document.findContentItems(withConceptName: findingConcept)
        let measurementItems = document.findContentItems(withConceptName: measurementConcept)
        
        #expect(findingItems.count == 2)
        #expect(measurementItems.count == 1)
    }
    
    @Test("Document description")
    func testDocumentDescription() {
        let rootContent = ContainerContentItem(
            continuityOfContent: .separate,
            contentItems: [AnyContentItem(TextContentItem(textValue: "Test"))]
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3",
            documentTitle: CodedConcept.finding,
            rootContent: rootContent
        )
        
        let description = document.description
        #expect(description.contains("Comprehensive SR"))
        #expect(description.contains("Finding"))
        #expect(description.contains("1 items"))
    }
}

// MARK: - SRDocumentParser Tests

@Suite("SRDocumentParser Tests")
struct SRDocumentParserTests {
    
    @Test("Parser initialization")
    func testParserInitialization() {
        let parser = SRDocumentParser()
        #expect(parser.configuration.validationLevel == .lenient)
        #expect(parser.configuration.maxDepth == 100)
        
        let strictParser = SRDocumentParser(configuration: .strict)
        #expect(strictParser.configuration.validationLevel == .strict)
    }
    
    @Test("Parse basic SR document")
    func testParseBasicDocument() throws {
        // Create a minimal data set with required SR attributes
        var dataSet = DataSet()
        
        // Add required identifiers
        dataSet[.sopClassUID] = DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: UInt32("1.2.840.10008.5.1.4.1.1.88.33".utf8.count),
            valueData: "1.2.840.10008.5.1.4.1.1.88.33".data(using: .utf8)!
        )
        
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: UInt32("1.2.3.4.5".utf8.count),
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        
        // Add Value Type for root container
        dataSet[.valueType] = DataElement(
            tag: .valueType,
            vr: .CS,
            length: UInt32("CONTAINER".utf8.count),
            valueData: "CONTAINER".data(using: .utf8)!
        )
        
        // Add Continuity of Content
        dataSet[.continuityOfContent] = DataElement(
            tag: .continuityOfContent,
            vr: .CS,
            length: UInt32("SEPARATE".utf8.count),
            valueData: "SEPARATE".data(using: .utf8)!
        )
        
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dataSet)
        
        #expect(document.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.33")
        #expect(document.sopInstanceUID == "1.2.3.4.5")
        #expect(document.documentType == .comprehensiveSR)
        #expect(document.rootContent.continuityOfContent == .separate)
    }
    
    @Test("Parse document with patient information")
    func testParseDocumentWithPatientInfo() throws {
        var dataSet = DataSet()
        
        // Required identifiers
        dataSet[.sopClassUID] = DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: UInt32("1.2.840.10008.5.1.4.1.1.88.33".utf8.count),
            valueData: "1.2.840.10008.5.1.4.1.1.88.33".data(using: .utf8)!
        )
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: UInt32("1.2.3.4.5".utf8.count),
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        
        // Patient information
        dataSet[.patientID] = DataElement(
            tag: .patientID,
            vr: .LO,
            length: UInt32("12345".utf8.count),
            valueData: "12345".data(using: .utf8)!
        )
        dataSet[.patientName] = DataElement(
            tag: .patientName,
            vr: .PN,
            length: UInt32("Doe^John".utf8.count),
            valueData: "Doe^John".data(using: .utf8)!
        )
        
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dataSet)
        
        #expect(document.patientID == "12345")
        #expect(document.patientName == "Doe^John")
    }
    
    @Test("Parse document with completion and verification flags")
    func testParseDocumentWithFlags() throws {
        var dataSet = DataSet()
        
        // Required identifiers
        dataSet[.sopClassUID] = DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: UInt32("1.2.840.10008.5.1.4.1.1.88.33".utf8.count),
            valueData: "1.2.840.10008.5.1.4.1.1.88.33".data(using: .utf8)!
        )
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: UInt32("1.2.3.4.5".utf8.count),
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        
        // Flags
        dataSet[.completionFlag] = DataElement(
            tag: .completionFlag,
            vr: .CS,
            length: UInt32("COMPLETE".utf8.count),
            valueData: "COMPLETE".data(using: .utf8)!
        )
        dataSet[.verificationFlag] = DataElement(
            tag: .verificationFlag,
            vr: .CS,
            length: UInt32("VERIFIED".utf8.count),
            valueData: "VERIFIED".data(using: .utf8)!
        )
        dataSet[.preliminaryFlag] = DataElement(
            tag: .preliminaryFlag,
            vr: .CS,
            length: UInt32("FINAL".utf8.count),
            valueData: "FINAL".data(using: .utf8)!
        )
        
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dataSet)
        
        #expect(document.completionFlag == .complete)
        #expect(document.verificationFlag == .verified)
        #expect(document.preliminaryFlag == .final)
    }
    
    @Test("Lenient parsing with missing required attributes")
    func testLenientParsingMissingAttributes() throws {
        var dataSet = DataSet()
        
        // Only add SOP Class UID, missing SOP Instance UID
        dataSet[.sopClassUID] = DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: UInt32("1.2.840.10008.5.1.4.1.1.88.33".utf8.count),
            valueData: "1.2.840.10008.5.1.4.1.1.88.33".data(using: .utf8)!
        )
        
        // Lenient parser should not throw
        let lenientParser = SRDocumentParser(configuration: .default)
        let document = try lenientParser.parse(dataSet: dataSet)
        
        #expect(document.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.33")
        #expect(document.sopInstanceUID == "") // Empty in lenient mode
    }
}

// MARK: - CompletionFlag Tests

@Suite("CompletionFlag Tests")
struct CompletionFlagTests {
    
    @Test("Raw value parsing")
    func testRawValueParsing() {
        #expect(CompletionFlag(rawValue: "COMPLETE") == .complete)
        #expect(CompletionFlag(rawValue: "PARTIAL") == .partial)
        #expect(CompletionFlag(rawValue: "INVALID") == nil)
    }
}

// MARK: - VerificationFlag Tests

@Suite("VerificationFlag Tests")
struct VerificationFlagTests {
    
    @Test("Raw value parsing")
    func testRawValueParsing() {
        #expect(VerificationFlag(rawValue: "VERIFIED") == .verified)
        #expect(VerificationFlag(rawValue: "UNVERIFIED") == .unverified)
        #expect(VerificationFlag(rawValue: "INVALID") == nil)
    }
}

// MARK: - PreliminaryFlag Tests

@Suite("PreliminaryFlag Tests")
struct PreliminaryFlagTests {
    
    @Test("Raw value parsing")
    func testRawValueParsing() {
        #expect(PreliminaryFlag(rawValue: "PRELIMINARY") == .preliminary)
        #expect(PreliminaryFlag(rawValue: "FINAL") == .final)
        #expect(PreliminaryFlag(rawValue: "INVALID") == nil)
    }
}

// MARK: - SRDocumentParser Content Item Parsing Tests

@Suite("SRDocumentParser Content Item Tests")
struct SRDocumentParserContentItemTests {
    
    /// Helper to create a minimal data set for testing
    private func createMinimalDataSet() -> DataSet {
        var dataSet = DataSet()
        dataSet[.sopClassUID] = DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: UInt32("1.2.840.10008.5.1.4.1.1.88.33".utf8.count),
            valueData: "1.2.840.10008.5.1.4.1.1.88.33".data(using: .utf8)!
        )
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: UInt32("1.2.3.4.5".utf8.count),
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        return dataSet
    }
    
    /// Helper to create a sequence item with value type
    private func createContentSequenceItem(valueType: String, additionalElements: [(DICOMCore.Tag, DICOMCore.VR, String)] = []) -> SequenceItem {
        var elements: [DataElement] = [
            DataElement(
                tag: .valueType,
                vr: .CS,
                length: UInt32(valueType.utf8.count),
                valueData: valueType.data(using: .utf8)!
            )
        ]
        
        for (tag, vr, value) in additionalElements {
            elements.append(DataElement(
                tag: tag,
                vr: vr,
                length: UInt32(value.utf8.count),
                valueData: value.data(using: .utf8)!
            ))
        }
        
        return SequenceItem(elements: elements)
    }
    
    @Test("Parse empty document with no content sequence")
    func testParseEmptyDocument() throws {
        let dataSet = createMinimalDataSet()
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dataSet)
        
        #expect(document.rootContent.contentItems.isEmpty)
        #expect(document.contentItemCount == 0)
    }
    
    @Test("Parser configuration options")
    func testParserConfigurationOptions() {
        let defaultConfig = SRDocumentParser.Configuration()
        #expect(defaultConfig.validationLevel == .lenient)
        #expect(defaultConfig.maxDepth == 100)
        
        let customConfig = SRDocumentParser.Configuration(
            validationLevel: .strict,
            maxDepth: 50
        )
        #expect(customConfig.validationLevel == .strict)
        #expect(customConfig.maxDepth == 50)
    }
}

// MARK: - Integration Tests

@Suite("SR Document Integration Tests")
struct SRDocumentIntegrationTests {
    
    @Test("Full round-trip document processing")
    func testFullDocumentProcessing() throws {
        // Create a structured document with various content types
        let measurementConcept = CodedConcept(
            codeValue: "118565006",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Volume"
        )
        
        let unitsConcept = CodedConcept(
            codeValue: "mm3",
            codingSchemeDesignator: "UCUM",
            codeMeaning: "cubic millimeter"
        )
        
        let rootItems: [AnyContentItem] = [
            .text(
                conceptName: CodedConcept.finding,
                value: "Lesion identified in left lobe",
                relationshipType: .contains
            ),
            .numeric(
                conceptName: measurementConcept,
                value: 125.5,
                units: unitsConcept,
                relationshipType: .contains
            ),
            .code(
                conceptName: CodedConcept.finding,
                value: CodedConcept(codeValue: "111001", codingSchemeDesignator: "DCM", codeMeaning: "Present"),
                relationshipType: .contains
            ),
        ]
        
        let rootContent = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "126001", codingSchemeDesignator: "DCM", codeMeaning: "Imaging Report"),
            continuityOfContent: .separate,
            contentItems: rootItems
        )
        
        let document = SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            patientID: "PATIENT001",
            patientName: "Smith^Jane",
            studyInstanceUID: "1.2.3.4.5.6.7.8.9.10",
            studyDate: "20240115",
            contentDate: "20240115",
            contentTime: "143022",
            completionFlag: .complete,
            verificationFlag: .verified,
            documentTitle: CodedConcept(codeValue: "126001", codingSchemeDesignator: "DCM", codeMeaning: "Imaging Report"),
            rootContent: rootContent
        )
        
        // Verify all properties
        #expect(document.documentType == .comprehensiveSR)
        #expect(document.contentItemCount == 3)
        #expect(document.findTextItems().count == 1)
        #expect(document.findNumericItems().count == 1)
        #expect(document.findCodeItems().count == 1)
        #expect(document.patientID == "PATIENT001")
        #expect(document.completionFlag == .complete)
    }
}
