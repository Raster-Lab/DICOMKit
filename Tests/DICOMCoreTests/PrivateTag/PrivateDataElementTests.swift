import XCTest
@testable import DICOMCore

final class PrivateDataElementTests: XCTestCase {
    // MARK: - Basic Functionality
    
    func test_init_createsPrivateDataElement() {
        let tag = Tag(group: 0x0009, element: 0x0020)
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let element = DataElement(tag: tag, vr: .LO, length: 0, valueData: Data())
        
        let privateElement = PrivateDataElement(tag: tag, creator: creator, element: element)
        
        XCTAssertEqual(privateElement.tag, tag)
        XCTAssertEqual(privateElement.creator.creatorID, "TEST")
    }
    
    func test_blockOffset_computesCorrectly() {
        let tag = Tag(group: 0x0009, element: 0x1020) // block 0x10, offset 0x20
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let element = DataElement(tag: tag, vr: .LO, length: 0, valueData: Data())
        
        let privateElement = PrivateDataElement(tag: tag, creator: creator, element: element)
        
        XCTAssertEqual(privateElement.blockOffset, 0x20)
    }
    
    func test_blockOffset_returnsNilForNonOwnedTag() {
        let tag = Tag(group: 0x0009, element: 0x1120) // Block 0x11
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010) // Block 0x10
        let element = DataElement(tag: tag, vr: .LO, length: 0, valueData: Data())
        
        let privateElement = PrivateDataElement(tag: tag, creator: creator, element: element)
        
        XCTAssertNil(privateElement.blockOffset)
    }
    
    // MARK: - Description
    
    func test_description_withKnownTag() {
        let tag = Tag(group: 0x0029, element: 0x1010)
        let creator = PrivateCreator.WellKnown.siemensCSA()
        let element = DataElement(tag: tag, vr: .OB, length: 0, valueData: Data())
        
        let privateElement = PrivateDataElement(tag: tag, creator: creator, element: element)
        
        let desc = privateElement.description
        XCTAssertTrue(desc.contains("(0029,1010)"))
        XCTAssertTrue(desc.contains("CSA Image Header Info"))
        XCTAssertTrue(desc.contains("SIEMENS CSA HEADER"))
    }
    
    func test_description_withUnknownTag() {
        let tag = Tag(group: 0x0009, element: 0x0020)
        let creator = PrivateCreator(creatorID: "UNKNOWN_VENDOR", group: 0x0009, element: 0x0010)
        let element = DataElement(tag: tag, vr: .LO, length: 0, valueData: Data())
        
        let privateElement = PrivateDataElement(tag: tag, creator: creator, element: element)
        
        let desc = privateElement.description
        XCTAssertTrue(desc.contains("(0009,0020)"))
        XCTAssertTrue(desc.contains("UNKNOWN_VENDOR"))
    }
}

final class PrivateTagErrorTests: XCTestCase {
    // MARK: - Error Descriptions
    
    func test_invalidGroup_description() {
        let error = PrivateTagError.invalidGroup(0x0008)
        
        let desc = error.description
        XCTAssertTrue(desc.contains("0x0008"))
        XCTAssertTrue(desc.contains("not odd"))
    }
    
    func test_noBlocksAvailable_description() {
        let error = PrivateTagError.noBlocksAvailable(group: 0x0009)
        
        let desc = error.description
        XCTAssertTrue(desc.contains("0x0009"))
        XCTAssertTrue(desc.contains("No private creator blocks"))
    }
    
    func test_invalidOffset_description() {
        let error = PrivateTagError.invalidOffset(0x05)
        
        let desc = error.description
        XCTAssertTrue(desc.contains("0x05"))
        XCTAssertTrue(desc.contains("Invalid private tag offset"))
    }
}
