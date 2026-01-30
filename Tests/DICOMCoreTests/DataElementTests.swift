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
    
    @Test("UInt16 array value extraction")
    func testUInt16Values() {
        var data = Data()
        // Three UInt16 values: 100, 200, 300
        data.append(contentsOf: [0x64, 0x00]) // 100
        data.append(contentsOf: [0xC8, 0x00]) // 200
        data.append(contentsOf: [0x2C, 0x01]) // 300
        
        let element = DataElement(tag: Tag(group: 0x0028, element: 0x0010), vr: .US, length: 6, valueData: data)
        let values = element.uint16Values
        
        #expect(values?.count == 3)
        #expect(values?[0] == 100)
        #expect(values?[1] == 200)
        #expect(values?[2] == 300)
    }
    
    @Test("UInt32 array value extraction")
    func testUInt32Values() {
        var data = Data()
        // Two UInt32 values: 1000, 2000
        data.append(contentsOf: [0xE8, 0x03, 0x00, 0x00]) // 1000
        data.append(contentsOf: [0xD0, 0x07, 0x00, 0x00]) // 2000
        
        let element = DataElement(tag: Tag(group: 0x0008, element: 0x0000), vr: .UL, length: 8, valueData: data)
        let values = element.uint32Values
        
        #expect(values?.count == 2)
        #expect(values?[0] == 1000)
        #expect(values?[1] == 2000)
    }
    
    @Test("Float32 array value extraction")
    func testFloat32Values() {
        var data = Data()
        // Two Float32 values: 1.5, 2.5
        let float1: Float32 = 1.5
        let float2: Float32 = 2.5
        
        withUnsafeBytes(of: float1.bitPattern) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: float2.bitPattern) { data.append(contentsOf: $0) }
        
        let element = DataElement(tag: Tag(group: 0x0020, element: 0x0032), vr: .FL, length: 8, valueData: data)
        let values = element.float32Values
        
        #expect(values?.count == 2)
        #expect(values?[0] == 1.5)
        #expect(values?[1] == 2.5)
    }
    
    @Test("Float64 array value extraction")
    func testFloat64Values() {
        var data = Data()
        // Two Float64 values: 3.14159, 2.71828
        let double1: Float64 = 3.14159
        let double2: Float64 = 2.71828
        
        withUnsafeBytes(of: double1.bitPattern) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: double2.bitPattern) { data.append(contentsOf: $0) }
        
        let element = DataElement(tag: Tag(group: 0x0018, element: 0x0050), vr: .FD, length: 16, valueData: data)
        let values = element.float64Values
        
        #expect(values?.count == 2)
        #expect(values?[0] == 3.14159)
        #expect(values?[1] == 2.71828)
    }
}
