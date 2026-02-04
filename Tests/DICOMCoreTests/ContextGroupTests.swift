import Testing
@testable import DICOMCore

// MARK: - ContextGroup Tests

@Suite("ContextGroup Tests")
struct ContextGroupTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let members = [
            CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right"),
            CodedConcept(codeValue: "7771000", scheme: .SCT, codeMeaning: "Left")
        ]
        
        let group = ContextGroup(
            cid: 244,
            name: "Laterality",
            isExtensible: false,
            version: "2024",
            members: members
        )
        
        #expect(group.cid == 244)
        #expect(group.name == "Laterality")
        #expect(group.isExtensible == false)
        #expect(group.version == "2024")
        #expect(group.members.count == 2)
    }
    
    @Test("Default extensibility is true")
    func testDefaultExtensibility() {
        let group = ContextGroup(cid: 999, name: "Test", members: [])
        #expect(group.isExtensible == true)
    }
    
    @Test("Description format")
    func testDescription() {
        let group = ContextGroup.laterality
        #expect(group.description.contains("CID 244"))
        #expect(group.description.contains("Laterality"))
        #expect(group.description.contains("non-extensible"))
    }
    
    @Test("Contains member concept")
    func testContainsMember() {
        let right = CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")
        let unknown = CodedConcept(codeValue: "000000", scheme: .SCT, codeMeaning: "Unknown")
        
        #expect(ContextGroup.laterality.contains(right))
        #expect(!ContextGroup.laterality.contains(unknown))
    }
    
    // MARK: - Validation
    
    @Test("Validation - valid member")
    func testValidationValidMember() {
        let right = CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")
        let result = ContextGroup.laterality.validate(right)
        
        #expect(result == .valid)
        #expect(result.isAcceptable)
    }
    
    @Test("Validation - extension code in extensible group")
    func testValidationExtensionCodeExtensible() {
        let customCode = CodedConcept(codeValue: "99999", scheme: .SCT, codeMeaning: "Custom")
        let extensibleGroup = ContextGroup.findingSite // extensible
        
        let result = extensibleGroup.validate(customCode)
        
        #expect(result == .extensionCode)
        #expect(result.isAcceptable)
    }
    
    @Test("Validation - invalid code in non-extensible group")
    func testValidationInvalidCodeNonExtensible() {
        let customCode = CodedConcept(codeValue: "99999", scheme: .SCT, codeMeaning: "Custom")
        let result = ContextGroup.laterality.validate(customCode) // non-extensible
        
        if case .invalid(let reason) = result {
            #expect(reason.contains("CID 244"))
            #expect(!result.isAcceptable)
        } else {
            #expect(Bool(false), "Expected invalid result")
        }
    }
    
    // MARK: - Well-Known Context Groups
    
    @Test("CID 218 - Quantitative Temporal Relation")
    func testCID218() {
        let group = ContextGroup.quantitativeTemporalRelation
        
        #expect(group.cid == 218)
        #expect(group.isExtensible == false)
        #expect(group.members.count >= 5)
        
        // Check for baseline code
        let baseline = CodedConcept(codeValue: "121110", scheme: .DCM, codeMeaning: "Baseline")
        #expect(group.contains(baseline))
    }
    
    @Test("CID 244 - Laterality")
    func testCID244() {
        let group = ContextGroup.laterality
        
        #expect(group.cid == 244)
        #expect(group.name == "Laterality")
        #expect(group.isExtensible == false)
        #expect(group.members.count == 4)
        
        // Check standard laterality codes
        let right = CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")
        let left = CodedConcept(codeValue: "7771000", scheme: .SCT, codeMeaning: "Left")
        let bilateral = CodedConcept(codeValue: "51440002", scheme: .SCT, codeMeaning: "Bilateral")
        
        #expect(group.contains(right))
        #expect(group.contains(left))
        #expect(group.contains(bilateral))
    }
    
    @Test("CID 4021 - Finding Site")
    func testCID4021() {
        let group = ContextGroup.findingSite
        
        #expect(group.cid == 4021)
        #expect(group.isExtensible == true)
        #expect(group.members.count >= 15)
        
        // Check for common anatomical sites
        let liver = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        let brain = CodedConcept(codeValue: "12738006", scheme: .SCT, codeMeaning: "Brain")
        
        #expect(group.contains(liver))
        #expect(group.contains(brain))
    }
    
    @Test("CID 6147 - Response Evaluation")
    func testCID6147() {
        let group = ContextGroup.responseEvaluation
        
        #expect(group.cid == 6147)
        #expect(group.name == "Response Evaluation")
        #expect(group.members.count >= 5)
    }
    
    @Test("CID 7021 - Measurement Report Document Titles")
    func testCID7021() {
        let group = ContextGroup.measurementReportDocumentTitles
        
        #expect(group.cid == 7021)
        #expect(group.members.count >= 2)
    }
    
    @Test("CID 7464 - ROI Measurement Units")
    func testCID7464() {
        let group = ContextGroup.roiMeasurementUnits
        
        #expect(group.cid == 7464)
        #expect(group.isExtensible == true)
        
        // Check for common units
        let mm = CodedConcept(codeValue: "mm", scheme: .UCUM, codeMeaning: "millimeter")
        let cm2 = CodedConcept(codeValue: "cm2", scheme: .UCUM, codeMeaning: "square centimeter")
        let hu = CodedConcept(codeValue: "[hnsf'U]", scheme: .UCUM, codeMeaning: "Hounsfield unit")
        
        #expect(group.contains(mm))
        #expect(group.contains(cm2))
        #expect(group.contains(hu))
    }
    
    @Test("CID 12301 - Imaging Observations")
    func testCID12301() {
        let group = ContextGroup.imagingObservations
        
        #expect(group.cid == 12301)
        #expect(group.isExtensible == true)
        
        // Check for common observations
        let mass = CodedConcept(codeValue: "4147007", scheme: .SCT, codeMeaning: "Mass")
        let nodule = CodedConcept(codeValue: "27925004", scheme: .SCT, codeMeaning: "Nodule")
        
        #expect(group.contains(mass))
        #expect(group.contains(nodule))
    }
    
    @Test("CID 6051 - Breast Imaging Finding")
    func testCID6051() {
        let group = ContextGroup.breastImagingFinding
        
        #expect(group.cid == 6051)
        #expect(group.isExtensible == true)
        
        // Check for breast-specific findings
        let mass = CodedConcept(codeValue: "4147007", scheme: .SCT, codeMeaning: "Mass")
        let calcification = CodedConcept(codeValue: "36222007", scheme: .SCT, codeMeaning: "Calcification")
        
        #expect(group.contains(mass))
        #expect(group.contains(calcification))
    }
    
    @Test("CID 6024 - Derivation")
    func testCID6024() {
        let group = ContextGroup.derivation
        
        #expect(group.cid == 6024)
        #expect(group.members.count >= 3)
    }
}

// MARK: - ContextGroupRegistry Tests

@Suite("ContextGroupRegistry Tests")
struct ContextGroupRegistryTests {
    
    @Test("Shared instance has well-known groups")
    func testSharedHasWellKnownGroups() {
        let registry = ContextGroupRegistry.shared
        
        #expect(registry.group(forCID: 218) != nil)  // Temporal Relation
        #expect(registry.group(forCID: 244) != nil)  // Laterality
        #expect(registry.group(forCID: 4021) != nil) // Finding Site
        #expect(registry.group(forCID: 6147) != nil) // Response Evaluation
        #expect(registry.group(forCID: 7464) != nil) // ROI Measurement Units
    }
    
    @Test("Lookup by CID")
    func testLookupByCID() {
        let registry = ContextGroupRegistry.shared
        
        let laterality = registry.group(forCID: 244)
        #expect(laterality?.name == "Laterality")
        
        let unknown = registry.group(forCID: 99999)
        #expect(unknown == nil)
    }
    
    @Test("Register custom group")
    func testRegisterCustomGroup() {
        let registry = ContextGroupRegistry()
        let custom = ContextGroup(
            cid: 99999,
            name: "Custom Group",
            members: [CodedConcept(codeValue: "TEST", scheme: .DCM, codeMeaning: "Test")]
        )
        
        registry.register(custom)
        
        let found = registry.group(forCID: 99999)
        #expect(found?.name == "Custom Group")
    }
    
    @Test("All groups list")
    func testAllGroups() {
        let registry = ContextGroupRegistry.shared
        let all = registry.allGroups
        
        #expect(all.count >= 8) // At least our well-known groups
        #expect(all.contains(where: { $0.cid == 244 }))
    }
    
    @Test("Validate against CID")
    func testValidateAgainstCID() {
        let registry = ContextGroupRegistry.shared
        let right = CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")
        
        let result = registry.validate(right, againstCID: 244)
        #expect(result == .valid)
        
        let unknownResult = registry.validate(right, againstCID: 99999)
        #expect(unknownResult == nil)
    }
}
