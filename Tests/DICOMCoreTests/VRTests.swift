import Testing
@testable import DICOMCore

@Suite("VR Tests")
struct VRTests {
    
    @Test("All 31 VRs are defined")
    func testAllVRsDefined() {
        #expect(VR.allCases.count == 31)
    }
    
    @Test("VR raw values are correct")
    func testVRRawValues() {
        #expect(VR.AE.rawValue == "AE")
        #expect(VR.CS.rawValue == "CS")
        #expect(VR.UI.rawValue == "UI")
        #expect(VR.SQ.rawValue == "SQ")
        #expect(VR.OB.rawValue == "OB")
    }
    
    @Test("32-bit length VRs")
    func test32BitLengthVRs() {
        // VRs that use 32-bit length field (PS3.5 Section 7.1.2)
        #expect(VR.OB.uses32BitLength == true)
        #expect(VR.OD.uses32BitLength == true)
        #expect(VR.OF.uses32BitLength == true)
        #expect(VR.OL.uses32BitLength == true)
        #expect(VR.OW.uses32BitLength == true)
        #expect(VR.SQ.uses32BitLength == true)
        #expect(VR.UC.uses32BitLength == true)
        #expect(VR.UN.uses32BitLength == true)
        #expect(VR.UR.uses32BitLength == true)
        #expect(VR.UT.uses32BitLength == true)
    }
    
    @Test("16-bit length VRs")
    func test16BitLengthVRs() {
        // VRs that use 16-bit length field
        #expect(VR.AE.uses32BitLength == false)
        #expect(VR.CS.uses32BitLength == false)
        #expect(VR.UI.uses32BitLength == false)
        #expect(VR.LO.uses32BitLength == false)
        #expect(VR.PN.uses32BitLength == false)
        #expect(VR.US.uses32BitLength == false)
        #expect(VR.UL.uses32BitLength == false)
    }
    
    @Test("Character repertoire for string VRs")
    func testCharacterRepertoire() {
        // Default repertoire VRs
        #expect(VR.AE.characterRepertoire == .defaultRepertoire)
        #expect(VR.CS.characterRepertoire == .defaultRepertoire)
        #expect(VR.UI.characterRepertoire == .defaultRepertoire)
        
        // Extended or replacement repertoire VRs
        #expect(VR.LO.characterRepertoire == .extendedOrReplacement)
        #expect(VR.PN.characterRepertoire == .extendedOrReplacement)
        #expect(VR.ST.characterRepertoire == .extendedOrReplacement)
        
        // Binary VRs have no character repertoire
        #expect(VR.OB.characterRepertoire == nil)
        #expect(VR.US.characterRepertoire == nil)
        #expect(VR.SQ.characterRepertoire == nil)
    }
}
