import XCTest
@testable import DICOMCore

final class PrivateTagDictionaryTests: XCTestCase {
    // MARK: - Basic Functionality
    
    func test_init_createsEmptyDictionary() {
        let dict = PrivateTagDictionary()
        
        XCTAssertNil(dict.definition(for: Tag(group: 0x0029, element: 0x1010), creatorID: "TEST"))
    }
    
    func test_init_withDefinitions() {
        let tag = Tag(group: 0x0029, element: 0x1010)
        let def = PrivateTagDefinition(tag: tag, name: "Test Tag", vr: .LO)
        let dict = PrivateTagDictionary(definitions: ["TEST": [tag: def]])
        
        XCTAssertNotNil(dict.definition(for: tag, creatorID: "TEST"))
    }
    
    func test_definition_returnsCorrectDefinition() {
        let tag = Tag(group: 0x0029, element: 0x1010)
        let def = PrivateTagDefinition(tag: tag, name: "Test Tag", vr: .LO, description: "Test description")
        let dict = PrivateTagDictionary(definitions: ["TEST": [tag: def]])
        
        let result = dict.definition(for: tag, creatorID: "TEST")
        
        XCTAssertEqual(result?.tag, tag)
        XCTAssertEqual(result?.name, "Test Tag")
        XCTAssertEqual(result?.vr, .LO)
        XCTAssertEqual(result?.description, "Test description")
    }
    
    func test_vr_returnsCorrectVR() {
        let tag = Tag(group: 0x0029, element: 0x1010)
        let def = PrivateTagDefinition(tag: tag, name: "Test", vr: .CS)
        let dict = PrivateTagDictionary(definitions: ["TEST": [tag: def]])
        
        XCTAssertEqual(dict.vr(for: tag, creatorID: "TEST"), .CS)
    }
    
    func test_name_returnsCorrectName() {
        let tag = Tag(group: 0x0029, element: 0x1010)
        let def = PrivateTagDefinition(tag: tag, name: "Test Name", vr: .LO)
        let dict = PrivateTagDictionary(definitions: ["TEST": [tag: def]])
        
        XCTAssertEqual(dict.name(for: tag, creatorID: "TEST"), "Test Name")
    }
    
    // MARK: - Siemens CSA Dictionary
    
    func test_siemensCSA_hasCSAImageHeaderInfo() {
        let dict = PrivateTagDictionary.siemensCSA
        let tag = Tag(group: 0x0029, element: 0x1010)
        
        let def = dict.definition(for: tag, creatorID: "SIEMENS CSA HEADER")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "CSA Image Header Info")
        XCTAssertEqual(def?.vr, .OB)
    }
    
    func test_siemensCSA_hasCSASeriesHeaderInfo() {
        let dict = PrivateTagDictionary.siemensCSA
        let tag = Tag(group: 0x0029, element: 0x1020)
        
        let def = dict.definition(for: tag, creatorID: "SIEMENS CSA HEADER")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "CSA Series Header Info")
    }
    
    // MARK: - Siemens MR Dictionary
    
    func test_siemensMR_hasBValue() {
        let dict = PrivateTagDictionary.siemensMR
        let tag = Tag(group: 0x0019, element: 0x100c)
        
        let def = dict.definition(for: tag, creatorID: "SIEMENS MR HEADER")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "B Value")
        XCTAssertEqual(def?.vr, .IS)
    }
    
    func test_siemensMR_hasDiffusionGradientDirection() {
        let dict = PrivateTagDictionary.siemensMR
        let tag = Tag(group: 0x0019, element: 0x100d)
        
        let def = dict.definition(for: tag, creatorID: "SIEMENS MR HEADER")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "Diffusion Gradient Direction")
    }
    
    // MARK: - GE Medical Dictionary
    
    func test_geMedical_hasProductID() {
        let dict = PrivateTagDictionary.geMedical
        let tag = Tag(group: 0x0009, element: 0x1004)
        
        let def = dict.definition(for: tag, creatorID: "GEMS_IDEN_01")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "Product ID")
    }
    
    // MARK: - Philips Dictionary
    
    func test_philipsImaging_hasChemicalShift() {
        let dict = PrivateTagDictionary.philipsImaging
        let tag = Tag(group: 0x2001, element: 0x1003)
        
        let def = dict.definition(for: tag, creatorID: "Philips Imaging DD 001")
        
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.name, "Chemical Shift")
        XCTAssertEqual(def?.vr, .FL)
    }
    
    // MARK: - Well-Known Combined Dictionary
    
    func test_wellKnown_includesSiemensTags() {
        let dict = PrivateTagDictionary.wellKnown
        
        XCTAssertNotNil(dict.definition(for: Tag(group: 0x0029, element: 0x1010), creatorID: "SIEMENS CSA HEADER"))
        XCTAssertNotNil(dict.definition(for: Tag(group: 0x0019, element: 0x100c), creatorID: "SIEMENS MR HEADER"))
    }
    
    func test_wellKnown_includesGETags() {
        let dict = PrivateTagDictionary.wellKnown
        
        XCTAssertNotNil(dict.definition(for: Tag(group: 0x0009, element: 0x1004), creatorID: "GEMS_IDEN_01"))
    }
    
    func test_wellKnown_includesPhilipsTags() {
        let dict = PrivateTagDictionary.wellKnown
        
        XCTAssertNotNil(dict.definition(for: Tag(group: 0x2001, element: 0x1003), creatorID: "Philips Imaging DD 001"))
    }
}
