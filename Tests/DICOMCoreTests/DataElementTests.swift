import Testing
import Foundation
@testable import DICOMCore

@Suite("DataElement Tests")
struct DataElementTests {
    
    @Test("DataElement creation")
    func testDataElementCreation() {
        let tag = Tag.patientName
        let vr = VR.PN
        let data = "DOE^JOHN".data(using: .utf8)!
        let element = DataElement(tag: tag, vr: vr, length: UInt32(data.count), valueData: data)
        
        #expect(element.tag == tag)
        #expect(element.vr == vr)
        #expect(element.length == UInt32(data.count))
        #expect(element.valueData == data)
    }
    
    @Test("Undefined length detection")
    func testUndefinedLength() {
        let element = DataElement(
            tag: Tag.sopInstanceUID,
            vr: .UI,
            length: 0xFFFFFFFF,
            valueData: Data()
        )
        
        #expect(element.hasUndefinedLength == true)
        
        let element2 = DataElement(
            tag: Tag.sopInstanceUID,
            vr: .UI,
            length: 10,
            valueData: Data()
        )
        
        #expect(element2.hasUndefinedLength == false)
    }
    
    @Test("String value extraction")
    func testStringValue() {
        let data = "DOE^JOHN  ".data(using: .utf8)!
        let element = DataElement(tag: Tag.patientName, vr: .PN, length: UInt32(data.count), valueData: data)
        
        // Should trim whitespace
        #expect(element.stringValue == "DOE^JOHN")
    }
    
    @Test("Multiple string values")
    func testMultipleStringValues() {
        let data = "VALUE1\\VALUE2\\VALUE3".data(using: .utf8)!
        let element = DataElement(tag: Tag.sopInstanceUID, vr: .UI, length: UInt32(data.count), valueData: data)
        
        let values = element.stringValues
        #expect(values?.count == 3)
        #expect(values?[0] == "VALUE1")
        #expect(values?[1] == "VALUE2")
        #expect(values?[2] == "VALUE3")
    }
    
    @Test("UInt16 value extraction")
    func testUInt16Value() {
        var data = Data()
        data.append(0x34)
        data.append(0x12)
        
        let element = DataElement(tag: Tag.seriesNumber, vr: .US, length: 2, valueData: data)
        #expect(element.uint16Value == 0x1234)
    }
    
    @Test("UInt32 value extraction")
    func testUInt32Value() {
        var data = Data()
        data.append(0x78)
        data.append(0x56)
        data.append(0x34)
        data.append(0x12)
        
        let element = DataElement(tag: .fileMetaInformationGroupLength, vr: .UL, length: 4, valueData: data)
        #expect(element.uint32Value == 0x12345678)
    }
}
