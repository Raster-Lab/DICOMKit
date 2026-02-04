import Testing
@testable import DICOMCore

// MARK: - DICOMCode Tests

@Suite("DICOMCode Tests")
struct DICOMCodeTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let code = DICOMCode(codeValue: "121071", codeMeaning: "Finding")
        
        #expect(code.codeValue == "121071")
        #expect(code.codeMeaning == "Finding")
        #expect(code.concept.codingSchemeDesignator == "DCM")
    }
    
    @Test("Creation from CodedConcept - valid DCM")
    func testCreationFromCodedConcept() {
        let concept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let code = DICOMCode(concept: concept)
        
        #expect(code != nil)
        #expect(code?.codeValue == "121071")
    }
    
    @Test("Creation from CodedConcept - non-DCM returns nil")
    func testCreationFromNonDCM() {
        let concept = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        let code = DICOMCode(concept: concept)
        
        #expect(code == nil)
    }
    
    @Test("Description format")
    func testDescription() {
        let code = DICOMCode.finding
        #expect(code.description.contains("121071"))
        #expect(code.description.contains("DCM"))
    }
    
    // MARK: - SR Document Concepts
    
    @Test("Document structure codes")
    func testDocumentStructureCodes() {
        #expect(DICOMCode.report.codeValue == "121060")
        #expect(DICOMCode.finding.codeValue == "121071")
        #expect(DICOMCode.measurement.codeValue == "125007")
        #expect(DICOMCode.procedureReported.codeValue == "121058")
        #expect(DICOMCode.imagingMeasurements.codeValue == "126010")
        #expect(DICOMCode.summary.codeValue == "121070")
        #expect(DICOMCode.conclusion.codeValue == "121076")
        #expect(DICOMCode.impression.codeValue == "121077")
        #expect(DICOMCode.recommendation.codeValue == "121074")
    }
    
    @Test("Observer context codes")
    func testObserverContextCodes() {
        #expect(DICOMCode.observerType.codeValue == "121005")
        #expect(DICOMCode.personObserverName.codeValue == "121008")
        #expect(DICOMCode.deviceObserverUID.codeValue == "121012")
        #expect(DICOMCode.deviceObserverName.codeValue == "121013")
        #expect(DICOMCode.deviceObserverManufacturer.codeValue == "121014")
        #expect(DICOMCode.person.codeValue == "121006")
        #expect(DICOMCode.device.codeValue == "121007")
    }
    
    @Test("Subject context codes")
    func testSubjectContextCodes() {
        #expect(DICOMCode.subjectName.codeValue == "121029")
        #expect(DICOMCode.subjectID.codeValue == "121030")
        #expect(DICOMCode.subjectBirthDate.codeValue == "121031")
        #expect(DICOMCode.subjectSex.codeValue == "121032")
    }
    
    @Test("Language context codes")
    func testLanguageContextCodes() {
        #expect(DICOMCode.languageOfContentItemAndDescendants.codeValue == "121049")
        #expect(DICOMCode.countryOfLanguage.codeValue == "121046")
    }
    
    // MARK: - Measurement Concepts
    
    @Test("Measurement type codes")
    func testMeasurementTypeCodes() {
        #expect(DICOMCode.diameter.codeValue == "131190")
        #expect(DICOMCode.longAxis.codeValue == "103340")
        #expect(DICOMCode.shortAxis.codeValue == "103339")
        #expect(DICOMCode.area.codeValue == "131184")
        #expect(DICOMCode.volume.codeValue == "118565")
        #expect(DICOMCode.circumference.codeValue == "131183")
        #expect(DICOMCode.length.codeValue == "118558")
        #expect(DICOMCode.width.codeValue == "118559")
    }
    
    @Test("Statistical measurement codes")
    func testStatisticalMeasurementCodes() {
        #expect(DICOMCode.meanValue.codeValue == "121401")
        #expect(DICOMCode.maximumValue.codeValue == "121403")
        #expect(DICOMCode.minimumValue.codeValue == "121402")
        #expect(DICOMCode.standardDeviation.codeValue == "121404")
        #expect(DICOMCode.median.codeValue == "121405")
        #expect(DICOMCode.mode.codeValue == "121406")
        #expect(DICOMCode.count.codeValue == "121407")
    }
    
    @Test("Measurement property codes")
    func testMeasurementPropertyCodes() {
        #expect(DICOMCode.sourceOfMeasurement.codeValue == "121112")
        #expect(DICOMCode.derivation.codeValue == "121401")
        #expect(DICOMCode.trackingIdentifier.codeValue == "112039")
        #expect(DICOMCode.trackingUniqueIdentifier.codeValue == "112040")
    }
    
    // MARK: - Reference Concepts
    
    @Test("Reference codes")
    func testReferenceCodes() {
        #expect(DICOMCode.imageReference.codeValue == "121191")
        #expect(DICOMCode.compositeReference.codeValue == "121190")
        #expect(DICOMCode.waveformReference.codeValue == "121192")
        #expect(DICOMCode.sourceImageForSegmentation.codeValue == "121324")
    }
    
    // MARK: - Qualitative Evaluation
    
    @Test("Assessment codes")
    func testAssessmentCodes() {
        #expect(DICOMCode.assessment.codeValue == "121073")
        #expect(DICOMCode.abnormality.codeValue == "121072")
        #expect(DICOMCode.noChange.codeValue == "121056")
        #expect(DICOMCode.progression.codeValue == "121057")
        #expect(DICOMCode.improvement.codeValue == "121055")
    }
    
    // MARK: - Relationship Type Codes
    
    @Test("Relationship type codes")
    func testRelationshipTypeCodes() {
        #expect(DICOMCode.contains.codeValue == "121311")
        #expect(DICOMCode.hasProperties.codeValue == "121309")
        #expect(DICOMCode.hasObservationContext.codeValue == "121310")
        #expect(DICOMCode.hasAcquisitionContext.codeValue == "121312")
        #expect(DICOMCode.inferredFrom.codeValue == "121307")
        #expect(DICOMCode.selectedFrom.codeValue == "121308")
        #expect(DICOMCode.hasConceptModifier.codeValue == "121313")
    }
    
    // MARK: - SR Document Title Codes
    
    @Test("SR document title codes")
    func testSRDocumentTitleCodes() {
        #expect(DICOMCode.basicDiagnosticImagingReport.codeValue == "126000")
        #expect(DICOMCode.comprehensiveSR.codeValue == "121181")
        #expect(DICOMCode.mammographyCADReport.codeValue == "111001")
        #expect(DICOMCode.chestCADReport.codeValue == "111002")
        #expect(DICOMCode.colonCADReport.codeValue == "111003")
        #expect(DICOMCode.procedureLog.codeValue == "121184")
        #expect(DICOMCode.xRayRadiationDoseReport.codeValue == "113701")
    }
    
    // MARK: - CodedConcept Convenience
    
    @Test("CodedConcept to DICOMCode conversion")
    func testCodedConceptToDICOMCode() {
        let concept = CodedConcept(dicomCode: DICOMCode.finding)
        
        #expect(concept.codeValue == "121071")
        #expect(concept.codingSchemeDesignator == "DCM")
        #expect(concept.isDICOMControlled)
    }
    
    @Test("CodedConcept asDICOMCode property")
    func testCodedConceptAsDICOMCode() {
        let dcmConcept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        let sctConcept = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        
        #expect(dcmConcept.asDICOMCode != nil)
        #expect(sctConcept.asDICOMCode == nil)
    }
    
    // MARK: - Equatable / Hashable
    
    @Test("Equatable conformance")
    func testEquatable() {
        let code1 = DICOMCode(codeValue: "121071", codeMeaning: "Finding")
        let code2 = DICOMCode.finding
        let code3 = DICOMCode.measurement
        
        #expect(code1 == code2)
        #expect(code1 != code3)
    }
    
    @Test("Hashable conformance")
    func testHashable() {
        let code1 = DICOMCode.finding
        let code2 = DICOMCode(codeValue: "121071", codeMeaning: "Finding")
        
        var set = Set<DICOMCode>()
        set.insert(code1)
        set.insert(code2)
        
        #expect(set.count == 1)
    }
}
