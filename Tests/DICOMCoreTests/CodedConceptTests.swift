import Testing
@testable import DICOMCore

// MARK: - CodedConcept Tests

@Suite("CodedConcept Tests")
struct CodedConceptTests {
    
    @Test("Basic creation with triplet")
    func testBasicCreation() {
        let concept = CodedConcept(
            codeValue: "121071",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Finding"
        )
        
        #expect(concept.codeValue == "121071")
        #expect(concept.codingSchemeDesignator == "DCM")
        #expect(concept.codeMeaning == "Finding")
        #expect(concept.codingSchemeVersion == nil)
        #expect(concept.longCodeValue == nil)
        #expect(concept.urnCodeValue == nil)
    }
    
    @Test("Creation with coding scheme enum")
    func testCreationWithSchemeEnum() {
        let concept = CodedConcept(
            codeValue: "mm",
            scheme: .UCUM,
            codeMeaning: "millimeter"
        )
        
        #expect(concept.codeValue == "mm")
        #expect(concept.codingSchemeDesignator == "UCUM")
        #expect(concept.codeMeaning == "millimeter")
    }
    
    @Test("Creation with all optional fields")
    func testCreationWithOptionalFields() {
        let concept = CodedConcept(
            codeValue: "12345",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Test Concept",
            codingSchemeVersion: "2023.01",
            longCodeValue: "very-long-code-value-exceeding-16",
            urnCodeValue: "urn:example:code"
        )
        
        #expect(concept.codingSchemeVersion == "2023.01")
        #expect(concept.longCodeValue == "very-long-code-value-exceeding-16")
        #expect(concept.urnCodeValue == "urn:example:code")
    }
    
    @Test("isDICOMControlled property")
    func testIsDICOMControlled() {
        let dcmConcept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let sctConcept = CodedConcept(codeValue: "123456", scheme: .SCT, codeMeaning: "Test")
        
        #expect(dcmConcept.isDICOMControlled == true)
        #expect(sctConcept.isDICOMControlled == false)
    }
    
    @Test("isSNOMED property")
    func testIsSNOMED() {
        let sctConcept = CodedConcept(codeValue: "123", scheme: .SCT, codeMeaning: "Test")
        let srtConcept = CodedConcept(codeValue: "456", scheme: .SRT, codeMeaning: "Test")
        let dcmConcept = CodedConcept(codeValue: "789", scheme: .DCM, codeMeaning: "Test")
        
        #expect(sctConcept.isSNOMED == true)
        #expect(srtConcept.isSNOMED == true)
        #expect(dcmConcept.isSNOMED == false)
    }
    
    @Test("isPrivate property")
    func testIsPrivate() {
        let privateConcept = CodedConcept(
            codeValue: "001",
            codingSchemeDesignator: "99ACME",
            codeMeaning: "Private Code"
        )
        let standardConcept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        #expect(privateConcept.isPrivate == true)
        #expect(standardConcept.isPrivate == false)
    }
    
    @Test("effectiveCodeValue property")
    func testEffectiveCodeValue() {
        let normalConcept = CodedConcept(codeValue: "12345", scheme: .DCM, codeMeaning: "Test")
        let longConcept = CodedConcept(
            codeValue: "short",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Test",
            longCodeValue: "this-is-a-very-long-code-value"
        )
        let urnConcept = CodedConcept(
            codeValue: "",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Test",
            urnCodeValue: "urn:example:code"
        )
        
        #expect(normalConcept.effectiveCodeValue == "12345")
        #expect(longConcept.effectiveCodeValue == "this-is-a-very-long-code-value")
        #expect(urnConcept.effectiveCodeValue == "urn:example:code")
    }
    
    @Test("Description format")
    func testDescription() {
        let concept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        #expect(concept.description == "(121071, DCM, \"Finding\")")
    }
    
    @Test("Validation - valid concept")
    func testValidationValid() {
        let concept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        #expect(concept.isValid == true)
        #expect(concept.validate().isEmpty)
    }
    
    @Test("Validation - empty code value")
    func testValidationEmptyCodeValue() {
        let concept = CodedConcept(codeValue: "", scheme: .DCM, codeMeaning: "Finding")
        let errors = concept.validate()
        
        #expect(errors.contains(.emptyCodeValue))
        #expect(concept.isValid == false)
    }
    
    @Test("Validation - empty coding scheme designator")
    func testValidationEmptyCodingScheme() {
        let concept = CodedConcept(codeValue: "121071", codingSchemeDesignator: "", codeMeaning: "Finding")
        let errors = concept.validate()
        
        #expect(errors.contains(.emptyCodingSchemeDesignator))
    }
    
    @Test("Validation - empty code meaning")
    func testValidationEmptyCodeMeaning() {
        let concept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "")
        let errors = concept.validate()
        
        #expect(errors.contains(.emptyCodeMeaning))
    }
    
    @Test("Validation - code value too long without long code value")
    func testValidationCodeValueTooLong() {
        let concept = CodedConcept(
            codeValue: "this-is-a-very-long-code-value",
            scheme: .DCM,
            codeMeaning: "Test"
        )
        let errors = concept.validate()
        
        #expect(errors.contains { error in
            if case .codeValueTooLong = error { return true }
            return false
        })
    }
    
    @Test("Validation - long code value is acceptable")
    func testValidationLongCodeValueOK() {
        let concept = CodedConcept(
            codeValue: "short",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Test",
            longCodeValue: "this-is-a-very-long-code-value"
        )
        
        #expect(concept.isValid == true)
    }
    
    @Test("Equatable conformance")
    func testEquatable() {
        let concept1 = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let concept2 = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let concept3 = CodedConcept(codeValue: "121072", scheme: .DCM, codeMeaning: "Other")
        
        #expect(concept1 == concept2)
        #expect(concept1 != concept3)
    }
    
    @Test("Hashable conformance")
    func testHashable() {
        let concept1 = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let concept2 = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        var set = Set<CodedConcept>()
        set.insert(concept1)
        set.insert(concept2)
        
        #expect(set.count == 1)
    }
    
    @Test("Common concepts - Finding")
    func testCommonConceptFinding() {
        let finding = CodedConcept.finding
        
        #expect(finding.codeValue == "121071")
        #expect(finding.codingSchemeDesignator == "DCM")
        #expect(finding.codeMeaning == "Finding")
    }
    
    @Test("Common concepts - UCUM units")
    func testCommonConceptUnits() {
        #expect(CodedConcept.unitMillimeter.codeValue == "mm")
        #expect(CodedConcept.unitCentimeter.codeValue == "cm")
        #expect(CodedConcept.unitSquareMillimeter.codeValue == "mm2")
        #expect(CodedConcept.unitCubicMillimeter.codeValue == "mm3")
        #expect(CodedConcept.unitHounsfieldUnit.codeValue == "[hnsf'U]")
    }
}

// MARK: - CodingSchemeDesignator Tests

@Suite("CodingSchemeDesignator Tests")
struct CodingSchemeDesignatorTests {
    
    @Test("All coding schemes have display names")
    func testDisplayNames() {
        for scheme in CodingSchemeDesignator.allCases {
            #expect(scheme.displayName.isEmpty == false)
        }
    }
    
    @Test("Raw values are correct")
    func testRawValues() {
        #expect(CodingSchemeDesignator.DCM.rawValue == "DCM")
        #expect(CodingSchemeDesignator.SCT.rawValue == "SCT")
        #expect(CodingSchemeDesignator.LOINC.rawValue == "LN")
        #expect(CodingSchemeDesignator.UCUM.rawValue == "UCUM")
    }
}
