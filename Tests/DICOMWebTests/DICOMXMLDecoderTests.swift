import XCTest
@testable import DICOMWeb
@testable import DICOMCore

final class DICOMXMLDecoderTests: XCTestCase {
    
    // MARK: - Basic Decoding Tests
    
    func testDecodeSimpleElement() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100020" vr="LO" keyword="PatientID">
            <Value number="1">123456</Value>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].tag.group, 0x0010)
        XCTAssertEqual(elements[0].tag.element, 0x0020)
        XCTAssertEqual(elements[0].vr, .LO)
        
        let value = elements[0].stringValues?.first
        XCTAssertEqual(value, "123456")
    }
    
    func testDecodeMultipleValues() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00080008" vr="CS" keyword="ImageType">
            <Value number="1">ORIGINAL</Value>
            <Value number="2">PRIMARY</Value>
            <Value number="3">AXIAL</Value>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        
        let values = elements[0].stringValues ?? []
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0], "ORIGINAL")
        XCTAssertEqual(values[1], "PRIMARY")
        XCTAssertEqual(values[2], "AXIAL")
    }
    
    // MARK: - Person Name Tests
    
    func testDecodePersonNameSimple() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100010" vr="PN" keyword="PatientName">
            <PersonName number="1">
              <Alphabetic>
                <FamilyName>Doe</FamilyName>
                <GivenName>John</GivenName>
              </Alphabetic>
            </PersonName>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].vr, .PN)
        
        let value = elements[0].stringValues?.first
        XCTAssertEqual(value, "Doe^John")
    }
    
    func testDecodePersonNameWithMiddleName() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100010" vr="PN">
            <PersonName number="1">
              <Alphabetic>
                <FamilyName>Doe</FamilyName>
                <GivenName>John</GivenName>
                <MiddleName>Q</MiddleName>
              </Alphabetic>
            </PersonName>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        let value = elements[0].stringValues?.first
        XCTAssertEqual(value, "Doe^John^Q")
    }
    
    func testDecodePersonNameWithPrefixSuffix() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100010" vr="PN">
            <PersonName number="1">
              <Alphabetic>
                <FamilyName>Doe</FamilyName>
                <GivenName>John</GivenName>
                <MiddleName>Q</MiddleName>
                <NamePrefix>Dr</NamePrefix>
                <NameSuffix>Jr</NameSuffix>
              </Alphabetic>
            </PersonName>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        let value = elements[0].stringValues?.first
        XCTAssertEqual(value, "Doe^John^Q^Dr^Jr")
    }
    
    // MARK: - Binary Data Tests
    
    func testDecodeInlineBinaryData() throws {
        let binaryData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let base64String = binaryData.base64EncodedString()
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="7FE00010" vr="OB" keyword="PixelData">
            <InlineBinary>\(base64String)</InlineBinary>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].vr, .OB)
        XCTAssertEqual(elements[0].valueData, binaryData)
    }
    
    func testDecodeBulkDataURI() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="7FE00010" vr="OB" keyword="PixelData">
            <BulkData uri="http://example.com/bulk/7FE00010"/>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].vr, .OB)
        // Bulk data URI creates placeholder element
        XCTAssertTrue(elements[0].valueData.isEmpty)
    }
    
    // MARK: - Sequence Tests
    
    func testDecodeSequence() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00081110" vr="SQ" keyword="ReferencedStudySequence">
            <Item number="1">
              <DicomAttribute tag="00081150" vr="UI" keyword="ReferencedSOPClassUID">
                <Value number="1">1.2.840.10008.3.1.2.3.1</Value>
              </DicomAttribute>
            </Item>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].vr, .SQ)
        
        let items = elements[0].sequenceItems
        XCTAssertEqual(items?.count, 1)
        
        let itemElements = items?[0].allElements
        XCTAssertEqual(itemElements?.count, 1)
        XCTAssertEqual(itemElements?[0].tag.group, 0x0008)
        XCTAssertEqual(itemElements?[0].tag.element, 0x1150)
    }
    
    func testDecodeNestedSequence() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00400260" vr="SQ">
            <Item number="1">
              <DicomAttribute tag="00400440" vr="SQ">
                <Item number="1">
                  <DicomAttribute tag="00080100" vr="SH">
                    <Value number="1">CODE123</Value>
                  </DicomAttribute>
                </Item>
              </DicomAttribute>
            </Item>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        
        let outerItems = elements[0].sequenceItems
        XCTAssertEqual(outerItems?.count, 1)
        
        let nestedElement = outerItems?[0].allElements.first
        XCTAssertEqual(nestedElement?.vr, .SQ)
        
        let innerItems = nestedElement?.sequenceItems
        XCTAssertEqual(innerItems?.count, 1)
    }
    
    // MARK: - Missing VR Tests
    
    func testDecodeMissingVRWithAllowMissing() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100020">
            <Value number="1">123456</Value>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let config = DICOMXMLDecoder.Configuration(allowMissingVR: true)
        let decoder = DICOMXMLDecoder(configuration: config)
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 1)
        // PatientID should infer LO from dictionary
        XCTAssertEqual(elements[0].vr, .LO)
    }
    
    func testDecodeMissingVRWithoutAllowMissing() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100020">
            <Value number="1">123456</Value>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let config = DICOMXMLDecoder.Configuration(allowMissingVR: false)
        let decoder = DICOMXMLDecoder(configuration: config)
        let elements = try decoder.decode(xml)
        
        // Should skip element without VR
        XCTAssertEqual(elements.count, 0)
    }
    
    // MARK: - Multiple Elements Test
    
    func testDecodeMultipleElements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
          <DicomAttribute tag="00100010" vr="PN">
            <PersonName number="1">
              <Alphabetic>
                <FamilyName>Doe</FamilyName>
                <GivenName>John</GivenName>
              </Alphabetic>
            </PersonName>
          </DicomAttribute>
          <DicomAttribute tag="00100020" vr="LO">
            <Value number="1">123456</Value>
          </DicomAttribute>
          <DicomAttribute tag="00080020" vr="DA">
            <Value number="1">20230115</Value>
          </DicomAttribute>
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[0].tag.group, 0x0010)
        XCTAssertEqual(elements[1].tag.group, 0x0010)
        XCTAssertEqual(elements[2].tag.group, 0x0008)
    }
    
    // MARK: - Roundtrip Test
    
    func testRoundtripConversion() throws {
        // Create elements
        let originalElements = [
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
        
        // Encode to XML
        let encoder = DICOMXMLEncoder()
        let xml = try encoder.encodeToString(originalElements)
        
        // Decode back to elements
        let decoder = DICOMXMLDecoder()
        let decodedElements = try decoder.decode(xml)
        
        // Compare
        XCTAssertEqual(decodedElements.count, originalElements.count)
        
        for (original, decoded) in zip(originalElements, decodedElements) {
            XCTAssertEqual(decoded.tag, original.tag)
            XCTAssertEqual(decoded.vr, original.vr)
            
            // Compare values
            if original.vr == .PN {
                // Person names might have different internal representation
                XCTAssertEqual(decoded.stringValues?.first, original.stringValues?.first)
            } else {
                XCTAssertEqual(decoded.valueData, original.valueData)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDecodeInvalidXML() throws {
        let xml = "This is not XML"
        
        let decoder = DICOMXMLDecoder()
        
        XCTAssertThrowsError(try decoder.decode(xml)) { error in
            guard case DICOMwebError.invalidXML = error else {
                XCTFail("Expected invalidXML error")
                return
            }
        }
    }
    
    func testDecodeEmptyXML() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
        </NativeDicomModel>
        """
        
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xml)
        
        XCTAssertEqual(elements.count, 0)
    }
}
