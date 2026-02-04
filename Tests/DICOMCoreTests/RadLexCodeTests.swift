import Testing
@testable import DICOMCore

// MARK: - RadLexCode Tests

@Suite("RadLexCode Tests")
struct RadLexCodeTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let code = RadLexCode(radlexId: "RID58", preferredName: "Liver")
        
        #expect(code.radlexId == "RID58")
        #expect(code.preferredName == "Liver")
        #expect(code.concept.codingSchemeDesignator == "RADLEX")
    }
    
    @Test("Creation from CodedConcept - valid RadLex")
    func testCreationFromCodedConcept() {
        let concept = CodedConcept(codeValue: "RID58", scheme: .RADLEX, codeMeaning: "Liver")
        let code = RadLexCode(concept: concept)
        
        #expect(code != nil)
        #expect(code?.radlexId == "RID58")
    }
    
    @Test("Creation from CodedConcept - non-RadLex returns nil")
    func testCreationFromNonRadLex() {
        let concept = CodedConcept(codeValue: "12345", scheme: .DCM, codeMeaning: "Test")
        let code = RadLexCode(concept: concept)
        
        #expect(code == nil)
    }
    
    @Test("Description format")
    func testDescription() {
        let code = RadLexCode.liver
        #expect(code.description.contains("RID58"))
        #expect(code.description.contains("RADLEX"))
    }
    
    // MARK: - Imaging Modalities
    
    @Test("Imaging modality codes")
    func testImagingModalityCodes() {
        #expect(RadLexCode.computedTomography.radlexId == "RID10321")
        #expect(RadLexCode.magneticResonanceImaging.radlexId == "RID10312")
        #expect(RadLexCode.radiography.radlexId == "RID10345")
        #expect(RadLexCode.mammography.radlexId == "RID10357")
        #expect(RadLexCode.ultrasound.radlexId == "RID10326")
        #expect(RadLexCode.nuclearMedicine.radlexId == "RID10330")
        #expect(RadLexCode.petImaging.radlexId == "RID10337")
        #expect(RadLexCode.fluoroscopy.radlexId == "RID10361")
    }
    
    // MARK: - Anatomical Structures
    
    @Test("Body region codes")
    func testBodyRegionCodes() {
        #expect(RadLexCode.head.radlexId == "RID9080")
        #expect(RadLexCode.neck.radlexId == "RID7488")
        #expect(RadLexCode.chest.radlexId == "RID1243")
        #expect(RadLexCode.abdomen.radlexId == "RID56")
        #expect(RadLexCode.pelvis.radlexId == "RID2507")
        #expect(RadLexCode.spine.radlexId == "RID7741")
    }
    
    @Test("Organ codes")
    func testOrganCodes() {
        #expect(RadLexCode.brain.radlexId == "RID6434")
        #expect(RadLexCode.lung.radlexId == "RID1301")
        #expect(RadLexCode.heart.radlexId == "RID1385")
        #expect(RadLexCode.liver.radlexId == "RID58")
        #expect(RadLexCode.kidney.radlexId == "RID205")
        #expect(RadLexCode.spleen.radlexId == "RID86")
        #expect(RadLexCode.pancreas.radlexId == "RID170")
        #expect(RadLexCode.gallbladder.radlexId == "RID187")
        #expect(RadLexCode.prostate.radlexId == "RID343")
        #expect(RadLexCode.breast.radlexId == "RID29897")
    }
    
    // MARK: - Common Radiology Findings
    
    @Test("General finding codes")
    func testGeneralFindingCodes() {
        #expect(RadLexCode.mass.radlexId == "RID3874")
        #expect(RadLexCode.nodule.radlexId == "RID3875")
        #expect(RadLexCode.lesion.radlexId == "RID38780")
        #expect(RadLexCode.cyst.radlexId == "RID3882")
        #expect(RadLexCode.calcification.radlexId == "RID5196")
        #expect(RadLexCode.consolidation.radlexId == "RID28540")
        #expect(RadLexCode.groundGlassOpacity.radlexId == "RID28754")
        #expect(RadLexCode.atelectasis.radlexId == "RID28496")
        #expect(RadLexCode.pneumothorax.radlexId == "RID4872")
        #expect(RadLexCode.pleuralEffusion.radlexId == "RID4890")
    }
    
    @Test("Vascular finding codes")
    func testVascularFindingCodes() {
        #expect(RadLexCode.stenosis.radlexId == "RID4640")
        #expect(RadLexCode.aneurysm.radlexId == "RID4648")
        #expect(RadLexCode.thrombus.radlexId == "RID4649")
    }
    
    @Test("Other finding codes")
    func testOtherFindingCodes() {
        #expect(RadLexCode.hemorrhage.radlexId == "RID4697")
        #expect(RadLexCode.edema.radlexId == "RID4696")
        #expect(RadLexCode.fracture.radlexId == "RID5325")
        #expect(RadLexCode.metastasis.radlexId == "RID5231")
        #expect(RadLexCode.lymphadenopathy.radlexId == "RID3890")
    }
    
    // MARK: - Qualitative Descriptors
    
    @Test("Shape descriptor codes")
    func testShapeDescriptorCodes() {
        #expect(RadLexCode.wellDefined.radlexId == "RID5706")
        #expect(RadLexCode.illDefined.radlexId == "RID5707")
        #expect(RadLexCode.homogeneous.radlexId == "RID5715")
        #expect(RadLexCode.heterogeneous.radlexId == "RID5716")
        #expect(RadLexCode.spiculated.radlexId == "RID5721")
        #expect(RadLexCode.round.radlexId == "RID5798")
        #expect(RadLexCode.oval.radlexId == "RID5799")
        #expect(RadLexCode.irregular.radlexId == "RID5800")
        #expect(RadLexCode.lobulated.radlexId == "RID5801")
    }
    
    // MARK: - Temporal Descriptors
    
    @Test("Temporal descriptor codes")
    func testTemporalDescriptorCodes() {
        #expect(RadLexCode.acute.radlexId == "RID5733")
        #expect(RadLexCode.subacute.radlexId == "RID5734")
        #expect(RadLexCode.chronic.radlexId == "RID5735")
        #expect(RadLexCode.new.radlexId == "RID5751")
        #expect(RadLexCode.stable.radlexId == "RID5752")
        #expect(RadLexCode.improved.radlexId == "RID5753")
        #expect(RadLexCode.worsened.radlexId == "RID5754")
        #expect(RadLexCode.resolved.radlexId == "RID5755")
    }
    
    // MARK: - Size Descriptors
    
    @Test("Size descriptor codes")
    func testSizeDescriptorCodes() {
        #expect(RadLexCode.small.radlexId == "RID5760")
        #expect(RadLexCode.medium.radlexId == "RID5761")
        #expect(RadLexCode.large.radlexId == "RID5762")
        #expect(RadLexCode.massive.radlexId == "RID5763")
    }
    
    // MARK: - CodedConcept Convenience
    
    @Test("CodedConcept to RadLex conversion")
    func testCodedConceptToRadLex() {
        let concept = CodedConcept(radlex: RadLexCode.liver)
        
        #expect(concept.codeValue == "RID58")
        #expect(concept.codingSchemeDesignator == "RADLEX")
        #expect(concept.isRadLex)
    }
    
    @Test("CodedConcept asRadLex property")
    func testCodedConceptAsRadLex() {
        let radlexConcept = CodedConcept(codeValue: "RID58", scheme: .RADLEX, codeMeaning: "Liver")
        let dcmConcept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        #expect(radlexConcept.asRadLex != nil)
        #expect(dcmConcept.asRadLex == nil)
    }
    
    @Test("CodedConcept isRadLex property")
    func testCodedConceptIsRadLex() {
        let radlexConcept = CodedConcept(codeValue: "RID58", scheme: .RADLEX, codeMeaning: "Liver")
        let sctConcept = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        
        #expect(radlexConcept.isRadLex == true)
        #expect(sctConcept.isRadLex == false)
    }
    
    // MARK: - Equatable / Hashable
    
    @Test("Equatable conformance")
    func testEquatable() {
        let code1 = RadLexCode(radlexId: "RID58", preferredName: "Liver")
        let code2 = RadLexCode.liver
        let code3 = RadLexCode.brain
        
        #expect(code1 == code2)
        #expect(code1 != code3)
    }
    
    @Test("Hashable conformance")
    func testHashable() {
        let code1 = RadLexCode.liver
        let code2 = RadLexCode(radlexId: "RID58", preferredName: "Liver")
        
        var set = Set<RadLexCode>()
        set.insert(code1)
        set.insert(code2)
        
        #expect(set.count == 1)
    }
}
