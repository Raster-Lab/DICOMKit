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
}
