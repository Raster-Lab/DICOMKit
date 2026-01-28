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
}
