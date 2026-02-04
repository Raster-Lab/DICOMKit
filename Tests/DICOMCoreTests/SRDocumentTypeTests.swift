import Testing
@testable import DICOMCore

// MARK: - SRDocumentType Tests

@Suite("SRDocumentType Tests")
struct SRDocumentTypeTests {
    
    // MARK: - SOP Class UID Tests
    
    @Test("Basic Text SR SOP Class UID")
    func testBasicTextSRUID() {
        #expect(SRDocumentType.basicTextSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.11")
    }
    
    @Test("Enhanced SR SOP Class UID")
    func testEnhancedSRUID() {
        #expect(SRDocumentType.enhancedSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.22")
    }
    
    @Test("Comprehensive SR SOP Class UID")
    func testComprehensiveSRUID() {
        #expect(SRDocumentType.comprehensiveSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.33")
    }
    
    @Test("Comprehensive 3D SR SOP Class UID")
    func testComprehensive3DSRUID() {
        #expect(SRDocumentType.comprehensive3DSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.34")
    }
    
    @Test("Extensible SR SOP Class UID")
    func testExtensibleSRUID() {
        #expect(SRDocumentType.extensibleSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.35")
    }
    
    @Test("Key Object Selection Document SOP Class UID")
    func testKeyObjectSelectionUID() {
        #expect(SRDocumentType.keyObjectSelectionDocument.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.59")
    }
    
    @Test("All CAD SR SOP Class UIDs")
    func testCADSRUIDs() {
        #expect(SRDocumentType.mammographyCADSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.50")
        #expect(SRDocumentType.chestCADSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.65")
        #expect(SRDocumentType.colonCADSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.69")
    }
    
    @Test("Radiation Dose SR SOP Class UIDs")
    func testRadiationDoseSRUIDs() {
        #expect(SRDocumentType.xRayRadiationDoseSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.67")
        #expect(SRDocumentType.enhancedXRayRadiationDoseSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.76")
        #expect(SRDocumentType.radiopharmaceuticalRadiationDoseSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.68")
        #expect(SRDocumentType.patientRadiationDoseSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.73")
    }
    
    @Test("Other SR SOP Class UIDs")
    func testOtherSRUIDs() {
        #expect(SRDocumentType.acquisitionContextSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.71")
        #expect(SRDocumentType.simplifiedAdultEchoSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.72")
        #expect(SRDocumentType.implantationPlanSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.70")
        #expect(SRDocumentType.plannedImagingAgentAdministrationSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.74")
        #expect(SRDocumentType.performedImagingAgentAdministrationSR.sopClassUID == "1.2.840.10008.5.1.4.1.1.88.75")
    }
    
    // MARK: - Display Name Tests
    
    @Test("Display names are non-empty")
    func testDisplayNamesNonEmpty() {
        let allTypes: [SRDocumentType] = [
            .basicTextSR, .enhancedSR, .comprehensiveSR, .comprehensive3DSR,
            .extensibleSR, .keyObjectSelectionDocument, .mammographyCADSR,
            .chestCADSR, .colonCADSR, .xRayRadiationDoseSR, .enhancedXRayRadiationDoseSR,
            .radiopharmaceuticalRadiationDoseSR, .patientRadiationDoseSR,
            .acquisitionContextSR, .simplifiedAdultEchoSR, .implantationPlanSR,
            .plannedImagingAgentAdministrationSR, .performedImagingAgentAdministrationSR
        ]
        
        for docType in allTypes {
            #expect(docType.displayName.isEmpty == false)
        }
    }
    
    @Test("Display name examples")
    func testDisplayNameExamples() {
        #expect(SRDocumentType.basicTextSR.displayName == "Basic Text SR")
        #expect(SRDocumentType.comprehensiveSR.displayName == "Comprehensive SR")
        #expect(SRDocumentType.keyObjectSelectionDocument.displayName == "Key Object Selection Document")
    }
    
    // MARK: - Content Item Type Constraints Tests
    
    @Test("Basic Text SR allowed value types")
    func testBasicTextSRAllowedTypes() {
        let allowed = SRDocumentType.basicTextSR.allowedValueTypes
        
        #expect(allowed.contains(.text))
        #expect(allowed.contains(.code))
        #expect(allowed.contains(.container))
        #expect(allowed.contains(.image))
        
        // Basic Text SR does NOT support NUM
        #expect(allowed.contains(.num) == false)
        // Basic Text SR does NOT support SCOORD
        #expect(allowed.contains(.scoord) == false)
    }
    
    @Test("Enhanced SR adds NUM support")
    func testEnhancedSRAddsNum() {
        let basicAllowed = SRDocumentType.basicTextSR.allowedValueTypes
        let enhancedAllowed = SRDocumentType.enhancedSR.allowedValueTypes
        
        #expect(basicAllowed.contains(.num) == false)
        #expect(enhancedAllowed.contains(.num) == true)
    }
    
    @Test("Comprehensive SR adds SCOORD and TCOORD")
    func testComprehensiveSRAddsScoord() {
        let allowed = SRDocumentType.comprehensiveSR.allowedValueTypes
        
        #expect(allowed.contains(.scoord))
        #expect(allowed.contains(.tcoord))
        
        // But not SCOORD3D
        #expect(allowed.contains(.scoord3D) == false)
    }
    
    @Test("Comprehensive 3D SR adds SCOORD3D")
    func testComprehensive3DSRAddsScoord3D() {
        let allowed = SRDocumentType.comprehensive3DSR.allowedValueTypes
        
        #expect(allowed.contains(.scoord3D))
        
        // Has all value types
        #expect(allowed == Set(ContentItemValueType.allCases))
    }
    
    @Test("Key Object Selection limited types")
    func testKeyObjectSelectionLimitedTypes() {
        let allowed = SRDocumentType.keyObjectSelectionDocument.allowedValueTypes
        
        #expect(allowed.contains(.text))
        #expect(allowed.contains(.code))
        #expect(allowed.contains(.image))
        #expect(allowed.contains(.composite))
        #expect(allowed.contains(.container))
        
        // Limited set - no NUM or coordinates
        #expect(allowed.contains(.num) == false)
        #expect(allowed.contains(.scoord) == false)
    }
    
    @Test("allows method")
    func testAllowsMethod() {
        #expect(SRDocumentType.basicTextSR.allows(.text) == true)
        #expect(SRDocumentType.basicTextSR.allows(.num) == false)
        #expect(SRDocumentType.enhancedSR.allows(.num) == true)
        #expect(SRDocumentType.comprehensive3DSR.allows(.scoord3D) == true)
    }
    
    // MARK: - Factory Method Tests
    
    @Test("from sopClassUID - valid UIDs")
    func testFromSOPClassUIDValid() {
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.11") == .basicTextSR)
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.22") == .enhancedSR)
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33") == .comprehensiveSR)
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.34") == .comprehensive3DSR)
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.35") == .extensibleSR)
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.59") == .keyObjectSelectionDocument)
    }
    
    @Test("from sopClassUID - invalid UID")
    func testFromSOPClassUIDInvalid() {
        #expect(SRDocumentType.from(sopClassUID: "1.2.840.10008.5.1.4.1.1.2") == nil) // CT Storage
        #expect(SRDocumentType.from(sopClassUID: "invalid") == nil)
        #expect(SRDocumentType.from(sopClassUID: "") == nil)
    }
    
    @Test("isSRDocument static method")
    func testIsSRDocument() {
        #expect(SRDocumentType.isSRDocument(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.11") == true)
        #expect(SRDocumentType.isSRDocument(sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33") == true)
        #expect(SRDocumentType.isSRDocument(sopClassUID: "1.2.840.10008.5.1.4.1.1.2") == false)
    }
    
    // MARK: - All SOP Class UIDs Tests
    
    @Test("allSOPClassUIDs contains all document types")
    func testAllSOPClassUIDsCount() {
        // 18 document types defined
        #expect(SRDocumentType.allSOPClassUIDs.count == 18)
    }
    
    @Test("allSOPClassUIDs contains specific UIDs")
    func testAllSOPClassUIDsContains() {
        let allUIDs = SRDocumentType.allSOPClassUIDs
        
        #expect(allUIDs.contains("1.2.840.10008.5.1.4.1.1.88.11"))
        #expect(allUIDs.contains("1.2.840.10008.5.1.4.1.1.88.33"))
        #expect(allUIDs.contains("1.2.840.10008.5.1.4.1.1.88.59"))
    }
    
    // MARK: - Description Tests
    
    @Test("description returns display name")
    func testDescription() {
        #expect(SRDocumentType.basicTextSR.description == "Basic Text SR")
        #expect(SRDocumentType.comprehensiveSR.description == "Comprehensive SR")
    }
    
    // MARK: - Equatable and Hashable Tests
    
    @Test("Equatable conformance")
    func testEquatable() {
        #expect(SRDocumentType.basicTextSR == SRDocumentType.basicTextSR)
        #expect(SRDocumentType.basicTextSR != SRDocumentType.enhancedSR)
    }
    
    @Test("Hashable conformance")
    func testHashable() {
        var set = Set<SRDocumentType>()
        set.insert(.basicTextSR)
        set.insert(.basicTextSR)
        set.insert(.enhancedSR)
        
        #expect(set.count == 2)
    }
}
