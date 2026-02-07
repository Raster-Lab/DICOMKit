import XCTest
@testable import DICOMWeb
@testable import DICOMCore

final class DICOMXMLEncoderTests: XCTestCase {
    
    // MARK: - Basic Encoding Tests
    
    func testEncodeSimpleElement() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 8,
            valueData: Data("DOE^JOHN".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<NativeDicomModel"))
        XCTAssertTrue(xml.contains("xmlns=\"http://dicom.nema.org/PS3.19/models/NativeDICOM\""))
        XCTAssertTrue(xml.contains("tag=\"00100010\""))
        XCTAssertTrue(xml.contains("vr=\"PN\""))
        XCTAssertTrue(xml.contains("<PersonName"))
        XCTAssertTrue(xml.contains("<FamilyName>DOE</FamilyName>"))
        XCTAssertTrue(xml.contains("<GivenName>JOHN</GivenName>"))
    }
    
    func testEncodeStringValue() throws {
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x0020),
            vr: .DA,
            length: 8,
            valueData: Data("20230115".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("tag=\"00080020\""))
        XCTAssertTrue(xml.contains("vr=\"DA\""))
        XCTAssertTrue(xml.contains("<Value number=\"1\">20230115</Value>"))
    }
    
    func testEncodeMultipleValues() throws {
        let values = "Value1\\Value2\\Value3"
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x0008),
            vr: .CS,
            length: UInt32(values.utf8.count),
            valueData: Data(values.utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<Value number=\"1\">Value1</Value>"))
        XCTAssertTrue(xml.contains("<Value number=\"2\">Value2</Value>"))
        XCTAssertTrue(xml.contains("<Value number=\"3\">Value3</Value>"))
    }
    
    // MARK: - Pretty Printing Tests
    
    func testPrettyPrinting() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            length: 6,
            valueData: Data("123456".utf8)
        )
        
        let config = DICOMXMLEncoder.Configuration(prettyPrinted: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        // Pretty printed should have indentation
        XCTAssertTrue(xml.contains("  <DicomAttribute"))
        XCTAssertTrue(xml.contains("    <Value"))
    }
    
    func testNoPrettyPrinting() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            length: 6,
            valueData: Data("123456".utf8)
        )
        
        let config = DICOMXMLEncoder.Configuration(prettyPrinted: false)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        // Non-pretty printed should not have indentation
        XCTAssertFalse(xml.contains("  <DicomAttribute"))
    }
    
    // MARK: - Keyword Tests
    
    func testIncludeKeywords() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 8,
            valueData: Data("DOE^JOHN".utf8)
        )
        
        let config = DICOMXMLEncoder.Configuration(includeKeywords: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("keyword=\"PatientName\""))
    }
    
    func testExcludeKeywords() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 8,
            valueData: Data("DOE^JOHN".utf8)
        )
        
        let config = DICOMXMLEncoder.Configuration(includeKeywords: false)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertFalse(xml.contains("keyword="))
    }
    
    // MARK: - Binary Data Tests
    
    func testInlineBinaryData() throws {
        let binaryData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let element = DataElement(
            tag: Tag(group: 0x7FE0, element: 0x0010),
            vr: .OB,
            length: UInt32(binaryData.count),
            valueData: binaryData
        )
        
        let config = DICOMXMLEncoder.Configuration(inlineBinaryThreshold: 1024)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<InlineBinary>"))
        XCTAssertTrue(xml.contains("</InlineBinary>"))
        XCTAssertTrue(xml.contains(binaryData.base64EncodedString()))
    }
    
    func testBulkDataURI() throws {
        let binaryData = Data(repeating: 0xFF, count: 2000) // Larger than threshold
        let element = DataElement(
            tag: Tag(group: 0x7FE0, element: 0x0010),
            vr: .OB,
            length: UInt32(binaryData.count),
            valueData: binaryData
        )
        
        let baseURL = URL(string: "http://example.com/bulk")!
        let config = DICOMXMLEncoder.Configuration(
            inlineBinaryThreshold: 1024,
            bulkDataBaseURL: baseURL
        )
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<BulkData uri="))
        XCTAssertTrue(xml.contains("http://example.com/bulk"))
        XCTAssertFalse(xml.contains("<InlineBinary>"))
    }
    
    // MARK: - Sequence Tests
    
    func testEncodeSequence() throws {
        let item1Element = DataElement(
            tag: Tag(group: 0x0008, element: 0x1150),
            vr: .UI,
            length: 26,
            valueData: Data("1.2.840.10008.3.1.2.3.1".utf8)
        )
        
        let item1 = SequenceItem(elements: [item1Element])
        
        let sequenceElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x1110),
            vr: .SQ,
            length: 0xFFFFFFFF,
            valueData: Data(),
            sequenceItems: [item1]
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([sequenceElement])
        
        XCTAssertTrue(xml.contains("tag=\"00081110\""))
        XCTAssertTrue(xml.contains("vr=\"SQ\""))
        XCTAssertTrue(xml.contains("<Item number=\"1\">"))
        XCTAssertTrue(xml.contains("tag=\"00081150\""))
        XCTAssertTrue(xml.contains("</Item>"))
    }
    
    // MARK: - Person Name Tests
    
    func testEncodePersonNameSimple() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 8,
            valueData: Data("DOE^JOHN".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<PersonName number=\"1\">"))
        XCTAssertTrue(xml.contains("<Alphabetic>"))
        XCTAssertTrue(xml.contains("<FamilyName>DOE</FamilyName>"))
        XCTAssertTrue(xml.contains("<GivenName>JOHN</GivenName>"))
        XCTAssertTrue(xml.contains("</Alphabetic>"))
        XCTAssertTrue(xml.contains("</PersonName>"))
    }
    
    func testEncodePersonNameWithMiddleName() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 12,
            valueData: Data("DOE^JOHN^Q".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<FamilyName>DOE</FamilyName>"))
        XCTAssertTrue(xml.contains("<GivenName>JOHN</GivenName>"))
        XCTAssertTrue(xml.contains("<MiddleName>Q</MiddleName>"))
    }
    
    func testEncodePersonNameWithPrefixSuffix() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 20,
            valueData: Data("DOE^JOHN^Q^DR^JR".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("<FamilyName>DOE</FamilyName>"))
        XCTAssertTrue(xml.contains("<GivenName>JOHN</GivenName>"))
        XCTAssertTrue(xml.contains("<MiddleName>Q</MiddleName>"))
        XCTAssertTrue(xml.contains("<NamePrefix>DR</NamePrefix>"))
        XCTAssertTrue(xml.contains("<NameSuffix>JR</NameSuffix>"))
    }
    
    // MARK: - XML Escaping Tests
    
    func testXMLEscaping() throws {
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x103E),
            vr: .LO,
            length: 20,
            valueData: Data("<Test & \"Value\" with >".utf8)
        )
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("&lt;Test &amp; &quot;Value&quot; with &gt;"))
        XCTAssertFalse(xml.contains("<Test & \"Value\" with >"))
    }
    
    // MARK: - Empty Value Tests
    
    func testIncludeEmptyValues() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            length: 0,
            valueData: Data()
        )
        
        let config = DICOMXMLEncoder.Configuration(includeEmptyValues: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertTrue(xml.contains("tag=\"00100020\""))
    }
    
    func testExcludeEmptyValues() throws {
        let element = DataElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            length: 0,
            valueData: Data()
        )
        
        let config = DICOMXMLEncoder.Configuration(includeEmptyValues: false)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xml = try encoder.encodeToString([element])
        
        XCTAssertFalse(xml.contains("tag=\"00100020\""))
    }
    
    // MARK: - Multiple Elements Test
    
    func testEncodeMultipleElements() throws {
        let elements = [
            DataElement(
                tag: Tag(group: 0x0010, element: 0x0010),
                vr: .PN,
                length: 8,
                valueData: Data("DOE^JOHN".utf8)
            ),
            DataElement(
                tag: Tag(group: 0x0010, element: 0x0020),
                vr: .LO,
                length: 6,
                valueData: Data("123456".utf8)
            ),
            DataElement(
                tag: Tag(group: 0x0008, element: 0x0020),
                vr: .DA,
                length: 8,
                valueData: Data("20230115".utf8)
            )
        ]
        
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString(elements)
        
        XCTAssertTrue(xml.contains("tag=\"00100010\""))
        XCTAssertTrue(xml.contains("tag=\"00100020\""))
        XCTAssertTrue(xml.contains("tag=\"00080020\""))
    }
}
