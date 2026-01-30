import Testing
import Foundation
@testable import SwiftDICOMKit
@testable import DICOMCore

@Suite("Sequence Parsing Tests")
struct SequenceParsingTests {
    
    // MARK: - SequenceItem Tests
    
    @Test("Empty SequenceItem creation")
    func testEmptySequenceItemCreation() {
        let item = SequenceItem()
        #expect(item.count == 0)
        #expect(item.tags.isEmpty)
        #expect(item.allElements.isEmpty)
    }
    
    @Test("SequenceItem creation from elements array")
    func testSequenceItemFromElementsArray() {
        let element1 = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "Doe^John".data(using: .utf8)!
        )
        let element2 = DataElement(
            tag: .patientID,
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [element1, element2])
        #expect(item.count == 2)
        #expect(item.string(for: .patientName) == "Doe^John")
        #expect(item.string(for: .patientID) == "123456")
    }
    
    @Test("SequenceItem subscript access")
    func testSequenceItemSubscriptAccess() {
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "Doe^John".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [element])
        #expect(item[.patientName] != nil)
        #expect(item[.patientID] == nil)
    }
    
    // MARK: - Sequence Delimiter Tag Tests
    
    @Test("Sequence delimiter tags are correct")
    func testSequenceDelimiterTags() {
        #expect(Tag.item.group == 0xFFFE)
        #expect(Tag.item.element == 0xE000)
        
        #expect(Tag.itemDelimitationItem.group == 0xFFFE)
        #expect(Tag.itemDelimitationItem.element == 0xE00D)
        
        #expect(Tag.sequenceDelimitationItem.group == 0xFFFE)
        #expect(Tag.sequenceDelimitationItem.element == 0xE0DD)
    }
    
    // MARK: - DataElement Sequence Properties Tests
    
    @Test("DataElement isSequence property")
    func testDataElementIsSequenceProperty() {
        let regularElement = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "Doe^John".data(using: .utf8)!
        )
        #expect(regularElement.isSequence == false)
        
        let sequenceElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x1115), // Referenced Series Sequence
            vr: .SQ,
            length: 0,
            valueData: Data(),
            sequenceItems: []
        )
        #expect(sequenceElement.isSequence == true)
    }
    
    @Test("DataElement sequenceItemCount property")
    func testDataElementSequenceItemCount() {
        let item1 = SequenceItem()
        let item2 = SequenceItem()
        
        let sequenceElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x1115),
            vr: .SQ,
            length: 0,
            valueData: Data(),
            sequenceItems: [item1, item2]
        )
        
        #expect(sequenceElement.sequenceItemCount == 2)
        
        let nonSequenceElement = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "Test".data(using: .utf8)!
        )
        
        #expect(nonSequenceElement.sequenceItemCount == 0)
    }
    
    // MARK: - DataSet Sequence Access Tests
    
    @Test("DataSet sequence access methods")
    func testDataSetSequenceAccessMethods() {
        let item = SequenceItem(elements: [
            DataElement(
                tag: .studyInstanceUID,
                vr: .UI,
                length: 10,
                valueData: "1.2.3.4.5 ".data(using: .utf8)!
            )
        ])
        
        let sequenceElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x1115),
            vr: .SQ,
            length: 0,
            valueData: Data(),
            sequenceItems: [item]
        )
        
        let dataSet = DataSet(elements: [sequenceElement])
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        
        #expect(dataSet.isSequence(tag: seqTag) == true)
        #expect(dataSet.sequenceItemCount(for: seqTag) == 1)
        #expect(dataSet.sequence(for: seqTag)?.count == 1)
        #expect(dataSet.firstSequenceItem(for: seqTag)?.string(for: .studyInstanceUID) == "1.2.3.4.5")
    }
    
    // MARK: - Explicit VR Sequence Parsing Tests
    
    @Test("Parse empty explicit length sequence")
    func testParseEmptyExplicitLengthSequence() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Referenced Series Sequence (0008,1115) - SQ VR - Empty (length = 0)
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length: 0
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.isSequence(tag: seqTag) == true)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 0)
    }
    
    @Test("Parse explicit length sequence with one item")
    func testParseExplicitLengthSequenceWithOneItem() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Build the sequence item content first
        var itemContent = Data()
        // Patient Name (0010,0010) inside the item
        itemContent.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
        itemContent.append(contentsOf: [0x50, 0x4E]) // "PN"
        itemContent.append(contentsOf: [0x08, 0x00]) // Length: 8
        itemContent.append("Doe^John".data(using: .utf8)!)
        
        // Build the item wrapper
        var itemData = Data()
        itemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag (FFFE,E000)
        itemData.append(contentsOf: withUnsafeBytes(of: UInt32(itemContent.count).littleEndian) { Data($0) }) // Item length
        itemData.append(itemContent)
        
        // Now build the sequence
        // Referenced Series Sequence (0008,1115)
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: UInt32(itemData.count).littleEndian) { Data($0) }) // Sequence length
        data.append(itemData)
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.isSequence(tag: seqTag) == true)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 1)
        
        let firstItem = file.dataSet.firstSequenceItem(for: seqTag)
        #expect(firstItem?.string(for: .patientName) == "Doe^John")
    }
    
    @Test("Parse explicit length sequence with multiple items")
    func testParseExplicitLengthSequenceWithMultipleItems() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Build item 1
        var item1Content = Data()
        item1Content.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        item1Content.append(contentsOf: [0x50, 0x4E]) // "PN"
        item1Content.append(contentsOf: [0x08, 0x00]) // Length: 8
        item1Content.append("Patient1".data(using: .utf8)!)
        
        var item1Data = Data()
        item1Data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        item1Data.append(contentsOf: withUnsafeBytes(of: UInt32(item1Content.count).littleEndian) { Data($0) })
        item1Data.append(item1Content)
        
        // Build item 2
        var item2Content = Data()
        item2Content.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        item2Content.append(contentsOf: [0x50, 0x4E]) // "PN"
        item2Content.append(contentsOf: [0x08, 0x00]) // Length: 8
        item2Content.append("Patient2".data(using: .utf8)!)
        
        var item2Data = Data()
        item2Data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        item2Data.append(contentsOf: withUnsafeBytes(of: UInt32(item2Content.count).littleEndian) { Data($0) })
        item2Data.append(item2Content)
        
        // Combine items
        var allItems = Data()
        allItems.append(item1Data)
        allItems.append(item2Data)
        
        // Build sequence
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Sequence tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: UInt32(allItems.count).littleEndian) { Data($0) })
        data.append(allItems)
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 2)
        
        let items = file.dataSet.sequence(for: seqTag)
        #expect(items?[0].string(for: .patientName) == "Patient1")
        #expect(items?[1].string(for: .patientName) == "Patient2")
    }
    
    // MARK: - Undefined Length Sequence Parsing Tests
    
    @Test("Parse undefined length sequence with one item")
    func testParseUndefinedLengthSequenceWithOneItem() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Build item content
        var itemContent = Data()
        itemContent.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        itemContent.append(contentsOf: [0x50, 0x4E]) // "PN"
        itemContent.append(contentsOf: [0x08, 0x00]) // Length: 8
        itemContent.append("TestName".data(using: .utf8)!)
        
        // Sequence with undefined length
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Sequence tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Undefined length
        
        // Item with explicit length
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        data.append(contentsOf: withUnsafeBytes(of: UInt32(itemContent.count).littleEndian) { Data($0) })
        data.append(itemContent)
        
        // Sequence Delimitation Item
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0]) // Sequence Delimitation tag
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length: 0
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.isSequence(tag: seqTag) == true)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 1)
        #expect(file.dataSet.firstSequenceItem(for: seqTag)?.string(for: .patientName) == "TestName")
    }
    
    @Test("Parse undefined length sequence with undefined length item")
    func testParseUndefinedLengthSequenceWithUndefinedLengthItem() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Sequence with undefined length
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Sequence tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Undefined length
        
        // Item with undefined length
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Undefined length
        
        // Item content
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        data.append(contentsOf: [0x50, 0x4E]) // "PN"
        data.append(contentsOf: [0x08, 0x00]) // Length: 8
        data.append("NameTest".data(using: .utf8)!)
        
        // Item Delimitation Item
        data.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0]) // Item Delimitation tag
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length: 0
        
        // Sequence Delimitation Item
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0]) // Sequence Delimitation tag
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length: 0
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.isSequence(tag: seqTag) == true)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 1)
        #expect(file.dataSet.firstSequenceItem(for: seqTag)?.string(for: .patientName) == "NameTest")
    }
    
    // MARK: - Nested Sequence Tests
    
    @Test("Parse nested sequence")
    func testParseNestedSequence() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Build inner sequence content
        var innerItemContent = Data()
        innerItemContent.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        innerItemContent.append(contentsOf: [0x50, 0x4E]) // "PN"
        innerItemContent.append(contentsOf: [0x08, 0x00]) // Length: 8
        innerItemContent.append("Nested!!".data(using: .utf8)!)
        
        var innerItemData = Data()
        innerItemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        innerItemData.append(contentsOf: withUnsafeBytes(of: UInt32(innerItemContent.count).littleEndian) { Data($0) })
        innerItemData.append(innerItemContent)
        
        // Inner sequence (Custom tag 0009,0010 - private)
        var innerSeqData = Data()
        innerSeqData.append(contentsOf: [0x09, 0x00, 0x10, 0x00]) // Private tag
        innerSeqData.append(contentsOf: [0x53, 0x51]) // "SQ"
        innerSeqData.append(contentsOf: [0x00, 0x00]) // Reserved
        innerSeqData.append(contentsOf: withUnsafeBytes(of: UInt32(innerItemData.count).littleEndian) { Data($0) })
        innerSeqData.append(innerItemData)
        
        // Outer item containing the inner sequence
        var outerItemData = Data()
        outerItemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        outerItemData.append(contentsOf: withUnsafeBytes(of: UInt32(innerSeqData.count).littleEndian) { Data($0) })
        outerItemData.append(innerSeqData)
        
        // Outer sequence
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Sequence tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: UInt32(outerItemData.count).littleEndian) { Data($0) })
        data.append(outerItemData)
        
        let file = try DICOMFile.read(from: data)
        
        let outerSeqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.sequenceItemCount(for: outerSeqTag) == 1)
        
        // Access the outer item
        let outerItem = file.dataSet.firstSequenceItem(for: outerSeqTag)
        #expect(outerItem != nil)
        
        // Access the inner sequence from the outer item
        let innerSeqTag = Tag(group: 0x0009, element: 0x0010)
        let innerSeqElement = outerItem?[innerSeqTag]
        #expect(innerSeqElement?.isSequence == true)
        #expect(innerSeqElement?.sequenceItemCount == 1)
        
        // Access the content of the inner sequence item
        let innerItem = innerSeqElement?.sequenceItems?.first
        #expect(innerItem?.string(for: .patientName) == "Nested!!")
    }
    
    // MARK: - Implicit VR Sequence Parsing Tests
    
    @Test("Parse implicit VR sequence")
    func testParseImplicitVRSequence() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Transfer Syntax UID for Implicit VR Little Endian
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // "UI"
        data.append(contentsOf: [0x12, 0x00]) // Length: 18
        data.append("1.2.840.10008.1.2 ".data(using: .ascii)!)
        
        // Build item content (Implicit VR - no VR field)
        var itemContent = Data()
        itemContent.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Patient Name tag
        itemContent.append(contentsOf: withUnsafeBytes(of: UInt32(8).littleEndian) { Data($0) }) // Length: 8
        itemContent.append("ImplVR!!".data(using: .utf8)!)
        
        // Item wrapper
        var itemData = Data()
        itemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        itemData.append(contentsOf: withUnsafeBytes(of: UInt32(itemContent.count).littleEndian) { Data($0) })
        itemData.append(itemContent)
        
        // Sequence (Implicit VR - tag looked up from dictionary)
        // Use Procedure Code Sequence (0008,1032) which is in the dictionary
        data.append(contentsOf: [0x08, 0x00, 0x32, 0x10]) // Tag
        data.append(contentsOf: withUnsafeBytes(of: UInt32(itemData.count).littleEndian) { Data($0) })
        data.append(itemData)
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1032)
        #expect(file.dataSet.isSequence(tag: seqTag) == true)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 1)
        #expect(file.dataSet.firstSequenceItem(for: seqTag)?.string(for: .patientName) == "ImplVR!!")
    }
    
    // MARK: - Edge Cases
    
    @Test("Parse sequence with empty item")
    func testParseSequenceWithEmptyItem() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Empty item
        var itemData = Data()
        itemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0]) // Item tag
        itemData.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length: 0
        
        // Sequence
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11]) // Tag
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: UInt32(itemData.count).littleEndian) { Data($0) })
        data.append(itemData)
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        #expect(file.dataSet.sequenceItemCount(for: seqTag) == 1)
        
        let item = file.dataSet.firstSequenceItem(for: seqTag)
        #expect(item?.count == 0)
    }
    
    @Test("Sequence item with multiple elements")
    func testSequenceItemWithMultipleElements() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Build item content with multiple elements
        var itemContent = Data()
        
        // Patient Name
        itemContent.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
        itemContent.append(contentsOf: [0x50, 0x4E]) // "PN"
        itemContent.append(contentsOf: [0x08, 0x00])
        itemContent.append("Smith^Jo".data(using: .utf8)!)
        
        // Patient ID
        itemContent.append(contentsOf: [0x10, 0x00, 0x20, 0x00])
        itemContent.append(contentsOf: [0x4C, 0x4F]) // "LO"
        itemContent.append(contentsOf: [0x06, 0x00])
        itemContent.append("ABC123".data(using: .utf8)!)
        
        // Study Date
        itemContent.append(contentsOf: [0x08, 0x00, 0x20, 0x00])
        itemContent.append(contentsOf: [0x44, 0x41]) // "DA"
        itemContent.append(contentsOf: [0x08, 0x00])
        itemContent.append("20260130".data(using: .utf8)!)
        
        // Item wrapper
        var itemData = Data()
        itemData.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])
        itemData.append(contentsOf: withUnsafeBytes(of: UInt32(itemContent.count).littleEndian) { Data($0) })
        itemData.append(itemContent)
        
        // Sequence
        data.append(contentsOf: [0x08, 0x00, 0x15, 0x11])
        data.append(contentsOf: [0x53, 0x51])
        data.append(contentsOf: [0x00, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: UInt32(itemData.count).littleEndian) { Data($0) })
        data.append(itemData)
        
        let file = try DICOMFile.read(from: data)
        
        let seqTag = Tag(group: 0x0008, element: 0x1115)
        let item = file.dataSet.firstSequenceItem(for: seqTag)
        
        #expect(item?.count == 3)
        #expect(item?.string(for: .patientName) == "Smith^Jo")
        #expect(item?.string(for: .patientID) == "ABC123")
        #expect(item?.string(for: .studyDate) == "20260130")
    }
}
