import Testing
import Foundation
@testable import SwiftDICOMKit

@Suite("DataSet Tests")
struct DataSetTests {
    
    @Test("Empty DataSet creation")
    func testEmptyDataSet() {
        let dataSet = DataSet()
        #expect(dataSet.count == 0)
        #expect(dataSet.tags.isEmpty)
    }
    
    @Test("DataSet creation from elements")
    func testDataSetFromElements() {
        let element1 = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let element2 = DataElement(
            tag: .patientID,
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element1, element2])
        #expect(dataSet.count == 2)
        #expect(dataSet[.patientName] != nil)
        #expect(dataSet[.patientID] != nil)
    }
    
    @Test("DataSet subscript access")
    func testDataSetSubscript() {
        var dataSet = DataSet()
        
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        dataSet[.patientName] = element
        #expect(dataSet[.patientName] != nil)
        #expect(dataSet[.patientName]?.tag == .patientName)
    }
    
    @Test("DataSet string extraction")
    func testDataSetStringExtraction() {
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let name = dataSet.string(for: .patientName)
        #expect(name == "DOE^JOHN")
    }
    
    @Test("DataSet iteration")
    func testDataSetIteration() {
        let element1 = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let element2 = DataElement(
            tag: .patientID,
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element1, element2])
        
        var count = 0
        for _ in dataSet {
            count += 1
        }
        
        #expect(count == 2)
    }
    
    @Test("DataSet numeric value extraction")
    func testDataSetNumericExtraction() {
        // Create elements with various numeric types
        var uint16Data = Data()
        uint16Data.append(contentsOf: [0x64, 0x00]) // 100
        let seriesElement = DataElement(
            tag: .seriesNumber,
            vr: .US,
            length: 2,
            valueData: uint16Data
        )
        
        var float64Data = Data()
        let sliceThickness: Float64 = 5.0
        withUnsafeBytes(of: sliceThickness.bitPattern) { float64Data.append(contentsOf: $0) }
        let sliceElement = DataElement(
            tag: .sliceThickness,
            vr: .FD,
            length: 8,
            valueData: float64Data
        )
        
        let dataSet = DataSet(elements: [seriesElement, sliceElement])
        
        // Test single value extraction
        #expect(dataSet.uint16(for: .seriesNumber) == 100)
        #expect(dataSet.float64(for: .sliceThickness) == 5.0)
    }
    
    @Test("DataSet array value extraction")
    func testDataSetArrayExtraction() {
        // Create element with multiple UInt16 values
        var data = Data()
        data.append(contentsOf: [0x64, 0x00]) // 100
        data.append(contentsOf: [0xC8, 0x00]) // 200
        data.append(contentsOf: [0x2C, 0x01]) // 300
        
        let element = DataElement(
            tag: Tag(group: 0x0028, element: 0x0010),
            vr: .US,
            length: 6,
            valueData: data
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.uint16s(for: Tag(group: 0x0028, element: 0x0010))
        
        #expect(values?.count == 3)
        #expect(values?[0] == 100)
        #expect(values?[1] == 200)
        #expect(values?[2] == 300)
    }
    
    // MARK: - Date/Time Value Access Tests
    
    @Test("DataSet DICOM Date extraction")
    func testDataSetDateExtraction() {
        let element = DataElement(
            tag: .studyDate,
            vr: .DA,
            length: 8,
            valueData: "20250130".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let date = dataSet.date(for: .studyDate)
        
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("DataSet DICOM Time extraction")
    func testDataSetTimeExtraction() {
        let element = DataElement(
            tag: .studyTime,
            vr: .TM,
            length: 6,
            valueData: "143025".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let time = dataSet.time(for: .studyTime)
        
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
    }
    
    @Test("DataSet DICOM DateTime extraction")
    func testDataSetDateTimeExtraction() {
        // Create a DT element - using Acquisition DateTime tag
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x002A),
            vr: .DT,
            length: 19,
            valueData: "20250130143025+0530".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let dateTime = dataSet.dateTime(for: Tag(group: 0x0008, element: 0x002A))
        
        #expect(dateTime != nil)
        #expect(dateTime?.year == 2025)
        #expect(dateTime?.month == 1)
        #expect(dateTime?.day == 30)
        #expect(dateTime?.hour == 14)
        #expect(dateTime?.minute == 30)
        #expect(dateTime?.timezoneOffsetMinutes == 330)
    }
    
    @Test("DataSet Foundation Date extraction")
    func testDataSetFoundationDateExtraction() {
        let element = DataElement(
            tag: .studyDate,
            vr: .DA,
            length: 8,
            valueData: "20250130".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let date = dataSet.foundationDate(for: .studyDate)
        
        #expect(date != nil)
    }
    
    @Test("DataSet date returns nil for missing tag")
    func testDataSetDateMissingTag() {
        let dataSet = DataSet()
        
        #expect(dataSet.date(for: .studyDate) == nil)
        #expect(dataSet.time(for: .studyTime) == nil)
        #expect(dataSet.dateTime(for: Tag(group: 0x0008, element: 0x002A)) == nil)
        #expect(dataSet.foundationDate(for: .studyDate) == nil)
    }
    
    // MARK: - Age String Value Access Tests
    
    @Test("DataSet DICOM Age String extraction")
    func testDataSetAgeExtraction() {
        let element = DataElement(
            tag: .patientAge,
            vr: .AS,
            length: 4,
            valueData: "018Y".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let age = dataSet.age(for: .patientAge)
        
        #expect(age != nil)
        #expect(age?.value == 18)
        #expect(age?.unit == .years)
        #expect(age?.humanReadable == "18 years")
    }
    
    @Test("DataSet age returns nil for missing tag")
    func testDataSetAgeMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.age(for: .patientAge) == nil)
    }
    
    // MARK: - Decimal String Value Access Tests
    
    @Test("DataSet DICOM Decimal String extraction")
    func testDataSetDecimalStringExtraction() {
        let element = DataElement(
            tag: .sliceThickness,
            vr: .DS,
            length: 3,
            valueData: "2.5".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let ds = dataSet.decimalString(for: .sliceThickness)
        
        #expect(ds != nil)
        #expect(ds?.value == 2.5)
    }
    
    @Test("DataSet DICOM Decimal String multiple values extraction")
    func testDataSetDecimalStringsExtraction() {
        let element = DataElement(
            tag: .pixelSpacing,
            vr: .DS,
            length: 13,
            valueData: "0.3125\\0.3125".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.decimalStrings(for: .pixelSpacing)
        
        #expect(values != nil)
        #expect(values?.count == 2)
        #expect(values?[0].value == 0.3125)
        #expect(values?[1].value == 0.3125)
    }
    
    @Test("DataSet decimal string returns nil for missing tag")
    func testDataSetDecimalStringMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.decimalString(for: .sliceThickness) == nil)
        #expect(dataSet.decimalStrings(for: .pixelSpacing) == nil)
    }
    
    // MARK: - Integer String Value Access Tests
    
    @Test("DataSet DICOM Integer String extraction")
    func testDataSetIntegerStringExtraction() {
        let element = DataElement(
            tag: .instanceNumber,
            vr: .IS,
            length: 1,
            valueData: "1".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let is_value = dataSet.integerString(for: .instanceNumber)
        
        #expect(is_value != nil)
        #expect(is_value?.value == 1)
    }
    
    @Test("DataSet DICOM Integer String multiple values extraction")
    func testDataSetIntegerStringsExtraction() {
        let element = DataElement(
            tag: Tag(group: 0x0020, element: 0x0013),
            vr: .IS,
            length: 5,
            valueData: "1\\2\\3".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.integerStrings(for: Tag(group: 0x0020, element: 0x0013))
        
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == 1)
        #expect(values?[1].value == 2)
        #expect(values?[2].value == 3)
    }
    
    @Test("DataSet integer string returns nil for missing tag")
    func testDataSetIntegerStringMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.integerString(for: .instanceNumber) == nil)
        #expect(dataSet.integerStrings(for: Tag(group: 0x0020, element: 0x0013)) == nil)
    }
    
    @Test("DataSet sequence access methods")
    func testDataSetSequenceAccess() {
        // Create a sequence element with items
        let innerElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x0100),
            vr: .SH,
            length: 5,
            valueData: "12345".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [innerElement])
        
        let sequenceElement = DataElement(
            tag: .procedureCodeSequence,
            vr: .SQ,
            length: 0xFFFFFFFF,
            valueData: Data(),
            sequenceItems: [item]
        )
        
        let dataSet = DataSet(elements: [sequenceElement])
        
        #expect(dataSet.isSequence(tag: .procedureCodeSequence) == true)
        #expect(dataSet.sequenceItemCount(for: .procedureCodeSequence) == 1)
        #expect(dataSet.sequence(for: .procedureCodeSequence)?.count == 1)
        #expect(dataSet.firstSequenceItem(for: .procedureCodeSequence) != nil)
    }
}
