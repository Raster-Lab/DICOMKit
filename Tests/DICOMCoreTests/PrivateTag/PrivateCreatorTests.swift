import XCTest
@testable import DICOMCore

final class PrivateCreatorTests: XCTestCase {
    // MARK: - Basic Functionality
    
    func test_init_createsPrivateCreator() {
        let creator = PrivateCreator(creatorID: "TEST_VENDOR", group: 0x0009, element: 0x0010)
        
        XCTAssertEqual(creator.creatorID, "TEST_VENDOR")
        XCTAssertEqual(creator.group, 0x0009)
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_blockNumber_computesCorrectly() {
        let creator1 = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        XCTAssertEqual(creator1.blockNumber, 0x10)
        
        let creator2 = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0011)
        XCTAssertEqual(creator2.blockNumber, 0x11)
        
        let creator3 = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x00FF)
        XCTAssertEqual(creator3.blockNumber, 0xFF)
    }
    
    func test_tag_returnsCreatorTag() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let tag = creator.tag
        
        XCTAssertEqual(tag.group, 0x0009)
        XCTAssertEqual(tag.element, 0x0010)
    }
    
    // MARK: - Private Tag Generation
    
    func test_privateTag_generatesCorrectTag() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        
        let tag1 = creator.privateTag(offset: 0x00)
        XCTAssertEqual(tag1?.group, 0x0009)
        XCTAssertEqual(tag1?.element, 0x1000) // block 0x10, offset 0x00
        
        let tag2 = creator.privateTag(offset: 0x20)
        XCTAssertEqual(tag2?.group, 0x0009)
        XCTAssertEqual(tag2?.element, 0x1020) // block 0x10, offset 0x20
        
        let tag3 = creator.privateTag(offset: 0xFF)
        XCTAssertEqual(tag3?.group, 0x0009)
        XCTAssertEqual(tag3?.element, 0x10FF) // block 0x10, offset 0xFF
    }
    
    func test_privateTag_withDifferentBlock() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0011)
        
        let tag = creator.privateTag(offset: 0x10)
        XCTAssertEqual(tag?.group, 0x0009)
        XCTAssertEqual(tag?.element, 0x1110) // block 0x11, offset 0x10
    }
    
    func test_privateTag_validOffsets() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        
        // All offsets 0x00-0xFF should be valid now
        XCTAssertNotNil(creator.privateTag(offset: 0x00))
        XCTAssertNotNil(creator.privateTag(offset: 0x10))
        XCTAssertNotNil(creator.privateTag(offset: 0xFF))
    }
    
    // MARK: - Ownership
    
    func test_owns_correctlyIdentifiesOwnedTags() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        // Block 0x10, so private tags are (0x0009, 0x1000-0x10FF)
        
        XCTAssertTrue(creator.owns(Tag(group: 0x0009, element: 0x1000)))
        XCTAssertTrue(creator.owns(Tag(group: 0x0009, element: 0x1020)))
        XCTAssertTrue(creator.owns(Tag(group: 0x0009, element: 0x10FF)))
    }
    
    func test_owns_rejectsNonOwnedTags() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        
        // Different group
        XCTAssertFalse(creator.owns(Tag(group: 0x000B, element: 0x1010)))
        
        // Different block (block 0x11)
        XCTAssertFalse(creator.owns(Tag(group: 0x0009, element: 0x1110)))
        
        // Creator element itself (0x0010) is in block 0x00, not block 0x10
        XCTAssertFalse(creator.owns(Tag(group: 0x0009, element: 0x0010)))
    }
    
    func test_owns_withDifferentBlock() {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0012)
        // Block 0x12, so private tags are (0x0009, 0x1200-0x12FF)
        
        XCTAssertTrue(creator.owns(Tag(group: 0x0009, element: 0x1210)))
        XCTAssertTrue(creator.owns(Tag(group: 0x0009, element: 0x1220)))
        XCTAssertFalse(creator.owns(Tag(group: 0x0009, element: 0x1110))) // block 0x11
    }
    
    // MARK: - Well-Known Creators
    
    func test_wellKnown_siemensCSA() {
        let creator = PrivateCreator.WellKnown.siemensCSA()
        
        XCTAssertEqual(creator.creatorID, "SIEMENS CSA HEADER")
        XCTAssertEqual(creator.group, 0x0029)
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_wellKnown_siemensCSA_customGroup() {
        let creator = PrivateCreator.WellKnown.siemensCSA(group: 0x0019)
        
        XCTAssertEqual(creator.creatorID, "SIEMENS CSA HEADER")
        XCTAssertEqual(creator.group, 0x0019)
    }
    
    func test_wellKnown_siemensMRHeader() {
        let creator = PrivateCreator.WellKnown.siemensMRHeader()
        
        XCTAssertEqual(creator.creatorID, "SIEMENS MR HEADER")
        XCTAssertEqual(creator.group, 0x0019)
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_wellKnown_geMedical() {
        let creator = PrivateCreator.WellKnown.geMedical()
        
        XCTAssertEqual(creator.creatorID, "GEMS_IDEN_01")
        XCTAssertEqual(creator.group, 0x0009)
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_wellKnown_geProtocol() {
        let creator = PrivateCreator.WellKnown.geProtocol()
        
        XCTAssertEqual(creator.creatorID, "GEMS_ACQU_01")
        XCTAssertEqual(creator.group, 0x0019)
    }
    
    func test_wellKnown_philipsImaging() {
        let creator = PrivateCreator.WellKnown.philipsImaging()
        
        XCTAssertEqual(creator.creatorID, "Philips Imaging DD 001")
        XCTAssertEqual(creator.group, 0x2001)
    }
    
    func test_wellKnown_canon() {
        let creator = PrivateCreator.WellKnown.canon()
        
        XCTAssertEqual(creator.creatorID, "TOSHIBA_MEC_MR3")
        XCTAssertEqual(creator.group, 0x7005)
    }
    
    // MARK: - Description
    
    func test_description_formatsCorrectly() {
        let creator = PrivateCreator(creatorID: "TEST_VENDOR", group: 0x0009, element: 0x0010)
        
        XCTAssertEqual(creator.description, "TEST_VENDOR at (0009,0010)")
    }
    
    // MARK: - Hashable & Equatable
    
    func test_hashable_sameValuesProduceSameHash() {
        let creator1 = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let creator2 = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        
        XCTAssertEqual(creator1, creator2)
        XCTAssertEqual(creator1.hashValue, creator2.hashValue)
    }
    
    func test_equatable_differentValuesNotEqual() {
        let creator1 = PrivateCreator(creatorID: "TEST1", group: 0x0009, element: 0x0010)
        let creator2 = PrivateCreator(creatorID: "TEST2", group: 0x0009, element: 0x0010)
        let creator3 = PrivateCreator(creatorID: "TEST1", group: 0x000B, element: 0x0010)
        
        XCTAssertNotEqual(creator1, creator2)
        XCTAssertNotEqual(creator1, creator3)
    }
}
