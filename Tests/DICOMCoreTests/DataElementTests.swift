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
    
    // MARK: - Date/Time Value Extraction
    
    @Test("DICOM Date (DA) value extraction")
    func testDateValue() {
        let data = "20250130".data(using: .utf8)!
        let element = DataElement(tag: Tag.studyDate, vr: .DA, length: UInt32(data.count), valueData: data)
        
        let date = element.dateValue
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("DICOM Time (TM) value extraction")
    func testTimeValue() {
        let data = "143025.123456".data(using: .utf8)!
        let element = DataElement(tag: Tag.studyTime, vr: .TM, length: UInt32(data.count), valueData: data)
        
        let time = element.timeValue
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
        #expect(time?.microsecond == 123456)
    }
    
    @Test("DICOM DateTime (DT) value extraction")
    func testDateTimeValue() {
        let data = "20250130143025+0530".data(using: .utf8)!
        let element = DataElement(tag: Tag(group: 0x0008, element: 0x002A), vr: .DT, length: UInt32(data.count), valueData: data)
        
        let dateTime = element.dateTimeValue
        #expect(dateTime != nil)
        #expect(dateTime?.year == 2025)
        #expect(dateTime?.month == 1)
        #expect(dateTime?.day == 30)
        #expect(dateTime?.hour == 14)
        #expect(dateTime?.minute == 30)
        #expect(dateTime?.second == 25)
        #expect(dateTime?.timezoneOffsetMinutes == 330)
    }
    
    @Test("Foundation Date from DA value")
    func testFoundationDateFromDA() {
        let data = "20250130".data(using: .utf8)!
        let element = DataElement(tag: Tag.studyDate, vr: .DA, length: UInt32(data.count), valueData: data)
        
        let date = element.foundationDateValue
        #expect(date != nil)
    }
    
    @Test("Foundation Date from DT value")
    func testFoundationDateFromDT() {
        let data = "20250130143025".data(using: .utf8)!
        let element = DataElement(tag: Tag(group: 0x0008, element: 0x002A), vr: .DT, length: UInt32(data.count), valueData: data)
        
        let date = element.foundationDateValue
        #expect(date != nil)
    }
    
    @Test("Date value returns nil for wrong VR")
    func testDateValueWrongVR() {
        let data = "20250130".data(using: .utf8)!
        // Using LO (Long String) instead of DA
        let element = DataElement(tag: Tag.patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        
        #expect(element.dateValue == nil)
    }
    
    @Test("Time value returns nil for wrong VR")
    func testTimeValueWrongVR() {
        let data = "143025".data(using: .utf8)!
        // Using LO (Long String) instead of TM
        let element = DataElement(tag: Tag.patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        
        #expect(element.timeValue == nil)
    }
    
    // MARK: - Age String Value Extraction
    
    @Test("DICOM Age String (AS) value extraction")
    func testAgeValue() {
        let data = "018Y".data(using: .utf8)!
        let element = DataElement(tag: Tag.patientAge, vr: .AS, length: UInt32(data.count), valueData: data)
        
        let age = element.ageValue
        #expect(age != nil)
        #expect(age?.value == 18)
        #expect(age?.unit == .years)
    }
    
    @Test("Age value returns nil for wrong VR")
    func testAgeValueWrongVR() {
        let data = "018Y".data(using: .utf8)!
        // Using LO (Long String) instead of AS
        let element = DataElement(tag: Tag.patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        
        #expect(element.ageValue == nil)
    }
    
    // MARK: - Decimal String Value Extraction
    
    @Test("DICOM Decimal String (DS) value extraction")
    func testDecimalStringValue() {
        let data = "3.14159".data(using: .utf8)!
        let element = DataElement(tag: Tag.sliceThickness, vr: .DS, length: UInt32(data.count), valueData: data)
        
        let ds = element.decimalStringValue
        #expect(ds != nil)
        #expect(ds?.value == 3.14159)
    }
    
    @Test("DICOM Decimal String multiple values extraction")
    func testDecimalStringValuesMultiple() {
        let data = "0.3125\\0.3125".data(using: .utf8)!
        let element = DataElement(tag: Tag.pixelSpacing, vr: .DS, length: UInt32(data.count), valueData: data)
        
        let values = element.decimalStringValues
        #expect(values != nil)
        #expect(values?.count == 2)
        #expect(values?[0].value == 0.3125)
        #expect(values?[1].value == 0.3125)
    }
    
    @Test("Decimal String value returns nil for wrong VR")
    func testDecimalStringValueWrongVR() {
        let data = "3.14159".data(using: .utf8)!
        // Using LO (Long String) instead of DS
        let element = DataElement(tag: Tag.patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        
        #expect(element.decimalStringValue == nil)
        #expect(element.decimalStringValues == nil)
    }
    
    // MARK: - Integer String Value Extraction
    
    @Test("DICOM Integer String (IS) value extraction")
    func testIntegerStringValue() {
        let data = "12345".data(using: .utf8)!
        let element = DataElement(tag: Tag.instanceNumber, vr: .IS, length: UInt32(data.count), valueData: data)
        
        let is_value = element.integerStringValue
        #expect(is_value != nil)
        #expect(is_value?.value == 12345)
    }
    
    @Test("DICOM Integer String multiple values extraction")
    func testIntegerStringValuesMultiple() {
        let data = "1\\2\\3".data(using: .utf8)!
        let element = DataElement(tag: Tag(group: 0x0020, element: 0x0013), vr: .IS, length: UInt32(data.count), valueData: data)
        
        let values = element.integerStringValues
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == 1)
        #expect(values?[1].value == 2)
        #expect(values?[2].value == 3)
    }
    
    @Test("Integer String value returns nil for wrong VR")
    func testIntegerStringValueWrongVR() {
        let data = "12345".data(using: .utf8)!
        // Using LO (Long String) instead of IS
        let element = DataElement(tag: Tag.patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        
        #expect(element.integerStringValue == nil)
        #expect(element.integerStringValues == nil)
    }
}
