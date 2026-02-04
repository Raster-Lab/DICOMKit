import Testing
@testable import DICOMCore

// MARK: - CodeMapper Tests

@Suite("CodeMapper Tests")
struct CodeMapperTests {
    
    @Test("Map code to same scheme returns original")
    func testMapToSameScheme() {
        let mapper = CodeMapper.shared
        let liver = SNOMEDCode.liver.concept
        
        let result = mapper.mapCode(liver, to: .SCT)
        
        #expect(result == liver)
    }
    
    @Test("Map SNOMED to RadLex - anatomical")
    func testMapSNOMEDToRadLexAnatomical() {
        let mapper = CodeMapper.shared
        let snomedLiver = SNOMEDCode.liver.concept
        
        let radlexLiver = mapper.mapCode(snomedLiver, to: .RADLEX)
        
        #expect(radlexLiver != nil)
        #expect(radlexLiver?.codingSchemeDesignator == "RADLEX")
    }
    
    @Test("Map RadLex to SNOMED - anatomical")
    func testMapRadLexToSNOMEDAnatomical() {
        let mapper = CodeMapper.shared
        let radlexLiver = RadLexCode.liver.concept
        
        let snomedLiver = mapper.mapCode(radlexLiver, to: .SCT)
        
        #expect(snomedLiver != nil)
        #expect(snomedLiver?.codingSchemeDesignator == "SCT")
    }
    
    @Test("Map SNOMED to RadLex - findings")
    func testMapSNOMEDToRadLexFindings() {
        let mapper = CodeMapper.shared
        let snomedMass = SNOMEDCode.mass.concept
        
        let radlexMass = mapper.mapCode(snomedMass, to: .RADLEX)
        
        #expect(radlexMass != nil)
        #expect(radlexMass?.codingSchemeDesignator == "RADLEX")
    }
    
    @Test("Map returns nil for unknown mapping")
    func testMapReturnsNilForUnknownMapping() {
        let mapper = CodeMapper.shared
        let unknown = CodedConcept(codeValue: "UNKNOWN123", scheme: .DCM, codeMeaning: "Unknown")
        
        let result = mapper.mapCode(unknown, to: .SCT)
        
        #expect(result == nil)
    }
    
    @Test("Register custom mapping")
    func testRegisterCustomMapping() {
        let mapper = CodeMapper()
        let custom1 = CodedConcept(codeValue: "CUSTOM1", scheme: .DCM, codeMeaning: "Custom 1")
        let custom2 = CodedConcept(codeValue: "CUSTOM2", scheme: .SCT, codeMeaning: "Custom 2")
        
        mapper.registerMapping(between: custom1, and: custom2)
        
        let mapped1to2 = mapper.mapCode(custom1, to: .SCT)
        let mapped2to1 = mapper.mapCode(custom2, to: .DCM)
        
        #expect(mapped1to2 == custom2)
        #expect(mapped2to1 == custom1)
    }
    
    @Test("Register multiple mappings")
    func testRegisterMultipleMappings() {
        let mapper = CodeMapper()
        let source = CodedConcept(codeValue: "SOURCE", scheme: .DCM, codeMeaning: "Source")
        let target1 = CodedConcept(codeValue: "TARGET1", scheme: .SCT, codeMeaning: "Target 1")
        let target2 = CodedConcept(codeValue: "TARGET2", scheme: .RADLEX, codeMeaning: "Target 2")
        
        mapper.registerMappings(from: source, to: [target1, target2])
        
        #expect(mapper.mapCode(source, to: .SCT) == target1)
        #expect(mapper.mapCode(source, to: .RADLEX) == target2)
        // Cross-mapping between targets should also work
        #expect(mapper.mapCode(target1, to: .RADLEX) == target2)
    }
    
    @Test("All mappings for concept")
    func testAllMappingsForConcept() {
        let mapper = CodeMapper.shared
        let liver = SNOMEDCode.liver.concept
        
        let mappings = mapper.allMappings(for: liver)
        
        #expect(mappings.count >= 1)
        #expect(mappings["RADLEX"] != nil)
    }
    
    @Test("Has mapping check")
    func testHasMappingCheck() {
        let mapper = CodeMapper.shared
        let liver = SNOMEDCode.liver.concept
        let unknown = CodedConcept(codeValue: "UNKNOWN", scheme: .DCM, codeMeaning: "Unknown")
        
        #expect(mapper.hasMapping(for: liver, to: .RADLEX))
        #expect(!mapper.hasMapping(for: unknown, to: .SCT))
    }
    
    @Test("Display name with preferred scheme")
    func testDisplayNameWithPreferredScheme() {
        let mapper = CodeMapper.shared
        let radlexLiver = RadLexCode.liver.concept
        
        let snomedDisplayName = mapper.displayName(for: radlexLiver, preferredScheme: .SCT)
        
        // Should get SNOMED display name or fall back to original
        #expect(!snomedDisplayName.isEmpty)
    }
    
    @Test("Display name fallback to original")
    func testDisplayNameFallback() {
        let mapper = CodeMapper.shared
        let unknown = CodedConcept(codeValue: "UNKNOWN", scheme: .DCM, codeMeaning: "Unknown Concept")
        
        let displayName = mapper.displayName(for: unknown, preferredScheme: .SCT)
        
        #expect(displayName == "Unknown Concept")
    }
    
    // MARK: - Well-Known Mappings
    
    @Test("Anatomical mappings - organs")
    func testAnatomicalMappingsOrgans() {
        let mapper = CodeMapper.shared
        
        // Test bidirectional mapping for liver
        #expect(mapper.hasMapping(for: SNOMEDCode.liver.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: RadLexCode.liver.concept, to: .SCT))
        
        // Test other organs
        #expect(mapper.hasMapping(for: SNOMEDCode.brain.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.heart.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.kidney.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.spleen.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.pancreas.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.lung.concept, to: .RADLEX))
    }
    
    @Test("Anatomical mappings - body regions")
    func testAnatomicalMappingsBodyRegions() {
        let mapper = CodeMapper.shared
        
        #expect(mapper.hasMapping(for: SNOMEDCode.head.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.neck.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.chest.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.abdomen.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.pelvis.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.spine.concept, to: .RADLEX))
    }
    
    @Test("Finding mappings")
    func testFindingMappings() {
        let mapper = CodeMapper.shared
        
        #expect(mapper.hasMapping(for: SNOMEDCode.mass.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.nodule.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.cyst.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.calcification.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.hemorrhage.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.fracture.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.metastasis.concept, to: .RADLEX))
    }
    
    @Test("Modality mappings")
    func testModalityMappings() {
        let mapper = CodeMapper.shared
        
        #expect(mapper.hasMapping(for: SNOMEDCode.computedTomography.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.magneticResonanceImaging.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.radiography.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.ultrasonography.concept, to: .RADLEX))
        #expect(mapper.hasMapping(for: SNOMEDCode.mammography.concept, to: .RADLEX))
    }
}

// MARK: - CodeEquivalent Tests

@Suite("CodeEquivalent Tests")
struct CodeEquivalentTests {
    
    @Test("Same concept is equivalent")
    func testSameConceptIsEquivalent() {
        let liver1 = SNOMEDCode.liver
        let liver2 = SNOMEDCode.liver
        
        #expect(liver1.isEquivalent(to: liver2))
    }
    
    @Test("Mapped concepts are equivalent")
    func testMappedConceptsAreEquivalent() {
        let snomedLiver = SNOMEDCode.liver
        let radlexLiver = RadLexCode.liver
        
        #expect(snomedLiver.isEquivalent(to: radlexLiver))
        #expect(radlexLiver.isEquivalent(to: snomedLiver))
    }
    
    @Test("Different concepts are not equivalent")
    func testDifferentConceptsNotEquivalent() {
        let liver = SNOMEDCode.liver
        let brain = SNOMEDCode.brain
        
        #expect(!liver.isEquivalent(to: brain))
    }
    
    @Test("CodedConcept equivalence check")
    func testCodedConceptEquivalence() {
        let concept1 = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        let concept2 = CodedConcept(codeValue: "RID58", scheme: .RADLEX, codeMeaning: "Liver")
        
        #expect(concept1.isEquivalent(to: concept2))
    }
}

// MARK: - CodedConcept Mapping Extensions Tests

@Suite("CodedConcept Mapping Extensions Tests")
struct CodedConceptMappingExtensionsTests {
    
    @Test("Map method")
    func testMapMethod() {
        let snomedLiver = SNOMEDCode.liver.concept
        let radlexLiver = snomedLiver.map(to: .RADLEX)
        
        #expect(radlexLiver != nil)
        #expect(radlexLiver?.codingSchemeDesignator == "RADLEX")
    }
    
    @Test("Equivalent codes property")
    func testEquivalentCodesProperty() {
        let liver = SNOMEDCode.liver.concept
        let equivalents = liver.equivalentCodes
        
        #expect(equivalents.count >= 1)
        #expect(equivalents["RADLEX"] != nil)
    }
}
