/// Tests for MammographyCADSRBuilder
///
/// Validates the creation and validation of Mammography CAD SR documents.

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class MammographyCADSRBuilderTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func createBasicBuilder() -> MammographyCADSRBuilder {
        MammographyCADSRBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^Jane")
            .withStudyInstanceUID("1.2.3.4.5")
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "2.1.0",
                manufacturer: "Example Medical Systems"
            )
    }
    
    private func createSampleImageReference() -> ImageReference {
        ImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.1.2", // Digital Mammography X-Ray Image Storage
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
    }
    
    // MARK: - Initialization Tests
    
    func testBuilderInitialization() {
        let builder = MammographyCADSRBuilder()
        XCTAssertTrue(builder.validateOnBuild)
        XCTAssertNil(builder.sopInstanceUID)
        XCTAssertNil(builder.patientID)
        XCTAssertEqual(builder.findings.count, 0)
        XCTAssertEqual(builder.completionFlag, .complete)
        XCTAssertEqual(builder.verificationFlag, .unverified)
    }
    
    func testBuilderInitializationWithoutValidation() {
        let builder = MammographyCADSRBuilder(validateOnBuild: false)
        XCTAssertFalse(builder.validateOnBuild)
    }
    
    // MARK: - Patient Information Tests
    
    func testWithPatientID() {
        let builder = MammographyCADSRBuilder()
            .withPatientID("12345")
        XCTAssertEqual(builder.patientID, "12345")
    }
    
    func testWithPatientName() {
        let builder = MammographyCADSRBuilder()
            .withPatientName("Doe^Jane")
        XCTAssertEqual(builder.patientName, "Doe^Jane")
    }
    
    func testWithPatientBirthDate() {
        let builder = MammographyCADSRBuilder()
            .withPatientBirthDate("19700101")
        XCTAssertEqual(builder.patientBirthDate, "19700101")
    }
    
    func testWithPatientSex() {
        let builder = MammographyCADSRBuilder()
            .withPatientSex("F")
        XCTAssertEqual(builder.patientSex, "F")
    }
    
    // MARK: - Study Information Tests
    
    func testWithStudyInstanceUID() {
        let builder = MammographyCADSRBuilder()
            .withStudyInstanceUID("1.2.3.4.5")
        XCTAssertEqual(builder.studyInstanceUID, "1.2.3.4.5")
    }
    
    func testWithStudyDate() {
        let builder = MammographyCADSRBuilder()
            .withStudyDate("20240101")
        XCTAssertEqual(builder.studyDate, "20240101")
    }
    
    func testWithStudyTime() {
        let builder = MammographyCADSRBuilder()
            .withStudyTime("120000")
        XCTAssertEqual(builder.studyTime, "120000")
    }
    
    func testWithStudyDescription() {
        let builder = MammographyCADSRBuilder()
            .withStudyDescription("Screening Mammography")
        XCTAssertEqual(builder.studyDescription, "Screening Mammography")
    }
    
    func testWithAccessionNumber() {
        let builder = MammographyCADSRBuilder()
            .withAccessionNumber("ACC123")
        XCTAssertEqual(builder.accessionNumber, "ACC123")
    }
    
    func testWithReferringPhysicianName() {
        let builder = MammographyCADSRBuilder()
            .withReferringPhysicianName("Smith^John")
        XCTAssertEqual(builder.referringPhysicianName, "Smith^John")
    }
    
    // MARK: - Series Information Tests
    
    func testWithSeriesInstanceUID() {
        let builder = MammographyCADSRBuilder()
            .withSeriesInstanceUID("1.2.3.4.5.6")
        XCTAssertEqual(builder.seriesInstanceUID, "1.2.3.4.5.6")
    }
    
    func testWithSeriesNumber() {
        let builder = MammographyCADSRBuilder()
            .withSeriesNumber("2")
        XCTAssertEqual(builder.seriesNumber, "2")
    }
    
    func testWithSeriesDescription() {
        let builder = MammographyCADSRBuilder()
            .withSeriesDescription("CAD Analysis")
        XCTAssertEqual(builder.seriesDescription, "CAD Analysis")
    }
    
    // MARK: - Document Information Tests
    
    func testWithSOPInstanceUID() {
        let builder = MammographyCADSRBuilder()
            .withSOPInstanceUID("1.2.3.4.5.6.7")
        XCTAssertEqual(builder.sopInstanceUID, "1.2.3.4.5.6.7")
    }
    
    func testWithInstanceNumber() {
        let builder = MammographyCADSRBuilder()
            .withInstanceNumber("1")
        XCTAssertEqual(builder.instanceNumber, "1")
    }
    
    func testWithContentDate() {
        let builder = MammographyCADSRBuilder()
            .withContentDate("20240101")
        XCTAssertEqual(builder.contentDate, "20240101")
    }
    
    func testWithContentTime() {
        let builder = MammographyCADSRBuilder()
            .withContentTime("120000")
        XCTAssertEqual(builder.contentTime, "120000")
    }
    
    func testWithCompletionFlag() {
        let builder = MammographyCADSRBuilder()
            .withCompletionFlag(.partial)
        XCTAssertEqual(builder.completionFlag, .partial)
    }
    
    func testWithVerificationFlag() {
        let builder = MammographyCADSRBuilder()
            .withVerificationFlag(.verified)
        XCTAssertEqual(builder.verificationFlag, .verified)
    }
    
    // MARK: - CAD Processing Summary Tests
    
    func testWithCADProcessingSummary() {
        let builder = MammographyCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "2.1.0",
                manufacturer: "Example Medical Systems",
                processingDateTime: "20240101120000"
            )
        
        XCTAssertEqual(builder.algorithmName, "MammoCAD")
        XCTAssertEqual(builder.algorithmVersion, "2.1.0")
        XCTAssertEqual(builder.manufacturer, "Example Medical Systems")
        XCTAssertEqual(builder.processingDateTime, "20240101120000")
    }
    
    func testWithCADProcessingSummaryWithoutDateTime() {
        let builder = MammographyCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "2.1.0",
                manufacturer: "Example Medical Systems"
            )
        
        XCTAssertEqual(builder.algorithmName, "MammoCAD")
        XCTAssertNil(builder.processingDateTime)
    }
    
    // MARK: - Finding Management Tests
    
    func testAddFindingWithStruct() {
        let imageRef = createSampleImageReference()
        let finding = CADFinding(
            type: .mass,
            probability: 0.85,
            location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
        )
        
        let builder = createBasicBuilder()
            .addFinding(finding)
        
        XCTAssertEqual(builder.findings.count, 1)
        XCTAssertEqual(builder.findings[0], finding)
    }
    
    func testAddFindingWithParameters() {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        XCTAssertEqual(builder.findings.count, 1)
        XCTAssertEqual(builder.findings[0].type, .mass)
        XCTAssertEqual(builder.findings[0].probability, 0.85, accuracy: 0.001)
    }
    
    func testAddMultipleFindings() {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
            .addFinding(
                type: .calcification,
                probability: 0.72,
                location: .point2D(x: 64.2, y: 128.7, imageReference: imageRef)
            )
        
        XCTAssertEqual(builder.findings.count, 2)
        XCTAssertEqual(builder.findings[0].type, .mass)
        XCTAssertEqual(builder.findings[1].type, .calcification)
    }
    
    func testClearFindings() {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
            .clearFindings()
        
        XCTAssertEqual(builder.findings.count, 0)
    }
    
    // MARK: - Finding Type Tests
    
    func testFindingTypeMass() {
        let concept = FindingType.mass.concept
        XCTAssertEqual(concept.codeValue, "F-01796")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Mass")
    }
    
    func testFindingTypeCalcification() {
        let concept = FindingType.calcification.concept
        XCTAssertEqual(concept.codeValue, "F-61769")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Calcification")
    }
    
    func testFindingTypeArchitecturalDistortion() {
        let concept = FindingType.architecturalDistortion.concept
        XCTAssertEqual(concept.codeValue, "F-01775")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Architectural Distortion")
    }
    
    func testFindingTypeAsymmetry() {
        let concept = FindingType.asymmetry.concept
        XCTAssertEqual(concept.codeValue, "F-01710")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Asymmetry")
    }
    
    func testFindingTypeCustom() {
        let customConcept = CodedConcept(
            codeValue: "CUSTOM-001",
            codingSchemeDesignator: "99TEST",
            codeMeaning: "Custom Finding"
        )
        let concept = FindingType.custom(customConcept).concept
        XCTAssertEqual(concept.codeValue, "CUSTOM-001")
        XCTAssertEqual(concept.codingSchemeDesignator, "99TEST")
        XCTAssertEqual(concept.codeMeaning, "Custom Finding")
    }
    
    // MARK: - Finding Location Tests
    
    func testFindingLocationPoint2D() {
        let imageRef = createSampleImageReference()
        let location = FindingLocation.point2D(x: 128.5, y: 256.3, imageReference: imageRef)
        
        switch location {
        case .point2D(let x, let y, let ref):
            XCTAssertEqual(x, 128.5, accuracy: 0.001)
            XCTAssertEqual(y, 256.3, accuracy: 0.001)
            XCTAssertEqual(ref, imageRef)
        default:
            XCTFail("Expected point2D location")
        }
    }
    
    func testFindingLocationROI2D() {
        let imageRef = createSampleImageReference()
        let points = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
        let location = FindingLocation.roi2D(points: points, imageReference: imageRef)
        
        switch location {
        case .roi2D(let pts, let ref):
            XCTAssertEqual(pts, points)
            XCTAssertEqual(ref, imageRef)
        default:
            XCTFail("Expected roi2D location")
        }
    }
    
    func testFindingLocationCircle2D() {
        let imageRef = createSampleImageReference()
        let location = FindingLocation.circle2D(
            centerX: 128.0,
            centerY: 256.0,
            radius: 30.0,
            imageReference: imageRef
        )
        
        switch location {
        case .circle2D(let cx, let cy, let r, let ref):
            XCTAssertEqual(cx, 128.0, accuracy: 0.001)
            XCTAssertEqual(cy, 256.0, accuracy: 0.001)
            XCTAssertEqual(r, 30.0, accuracy: 0.001)
            XCTAssertEqual(ref, imageRef)
        default:
            XCTFail("Expected circle2D location")
        }
    }
    
    // MARK: - Build Tests
    
    func testBuildBasicDocument() throws {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        XCTAssertEqual(document.sopClassUID, SRDocumentType.mammographyCADSR.sopClassUID)
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.patientName, "Doe^Jane")
        XCTAssertEqual(document.modality, "SR")
        XCTAssertEqual(document.documentTitle?.codeValue, "111036")
        XCTAssertEqual(document.documentTitle?.codeMeaning, "Mammography CAD Report")
    }
    
    func testBuildDocumentWithMultipleFindings() throws {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
            .addFinding(
                type: .calcification,
                probability: 0.72,
                location: .point2D(x: 64.2, y: 128.7, imageReference: imageRef)
            )
            .addFinding(
                type: .architecturalDistortion,
                probability: 0.65,
                location: .circle2D(centerX: 200.0, centerY: 300.0, radius: 25.0, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        // The root container should have processing summary + 3 findings
        XCTAssertGreaterThanOrEqual(document.rootContent.contentItems.count, 3)
    }
    
    func testBuildDocumentWithROILocation() throws {
        let imageRef = createSampleImageReference()
        let roiPoints = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 10.0, 20.0] // Closed polygon
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.90,
                location: .roi2D(points: roiPoints, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildDocumentWithCharacteristics() throws {
        let imageRef = createSampleImageReference()
        let characteristics = [
            CodedConcept(
                codeValue: "M-78060",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Spiculated margin"
            ),
            CodedConcept(
                codeValue: "M-02520",
                codingSchemeDesignator: "SRT",
                codeMeaning: "High density"
            )
        ]
        
        let finding = CADFinding(
            type: .mass,
            probability: 0.92,
            location: .point2D(x: 150.0, y: 200.0, imageReference: imageRef),
            characteristics: characteristics
        )
        
        let builder = createBasicBuilder()
            .addFinding(finding)
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildDocumentGeneratesUIDs() throws {
        let imageRef = createSampleImageReference()
        let builder = MammographyCADSRBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^Jane")
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "2.1.0",
                manufacturer: "Example Medical Systems"
            )
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        // UIDs should be auto-generated
        XCTAssertFalse(document.sopInstanceUID.isEmpty)
        XCTAssertNotNil(document.studyInstanceUID)
        XCTAssertNotNil(document.seriesInstanceUID)
    }
    
    func testBuildDocumentPreservesExplicitUIDs() throws {
        let imageRef = createSampleImageReference()
        let sopUID = "1.2.3.4.5.6.7.8.9.10"
        let studyUID = "1.2.3.4.5"
        let seriesUID = "1.2.3.4.5.6"
        
        let builder = createBasicBuilder()
            .withSOPInstanceUID(sopUID)
            .withStudyInstanceUID(studyUID)
            .withSeriesInstanceUID(seriesUID)
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        XCTAssertEqual(document.sopInstanceUID, sopUID)
        XCTAssertEqual(document.studyInstanceUID, studyUID)
        XCTAssertEqual(document.seriesInstanceUID, seriesUID)
    }
    
    // MARK: - Validation Tests
    
    func testValidationFailsWithNoAlgorithmName() {
        let imageRef = createSampleImageReference()
        let builder = MammographyCADSRBuilder()
            .withPatientID("12345")
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            guard case MammographyCADSRBuilder.BuildError.validationError(let message) = error else {
                XCTFail("Expected validationError")
                return
            }
            XCTAssertTrue(message.contains("algorithm name"))
        }
    }
    
    func testValidationFailsWithNoFindings() {
        let builder = createBasicBuilder()
        
        XCTAssertThrowsError(try builder.build()) { error in
            guard case MammographyCADSRBuilder.BuildError.validationError(let message) = error else {
                XCTFail("Expected validationError")
                return
            }
            XCTAssertTrue(message.contains("at least one finding"))
        }
    }
    
    func testValidationFailsWithInvalidProbability() {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 1.5, // Invalid: > 1.0
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            guard case MammographyCADSRBuilder.BuildError.validationError(let message) = error else {
                XCTFail("Expected validationError")
                return
            }
            XCTAssertTrue(message.contains("probability"))
        }
    }
    
    func testValidationFailsWithNegativeProbability() {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: -0.1, // Invalid: < 0.0
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            guard case MammographyCADSRBuilder.BuildError.validationError(let message) = error else {
                XCTFail("Expected validationError")
                return
            }
            XCTAssertTrue(message.contains("probability"))
        }
    }
    
    func testValidationCanBeDisabled() throws {
        let builder = MammographyCADSRBuilder(validateOnBuild: false)
            .withPatientID("12345")
        
        // This should not throw even though it's invalid
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    // MARK: - Edge Case Tests
    
    func testBuildWithMinimalInformation() throws {
        let imageRef = createSampleImageReference()
        let builder = MammographyCADSRBuilder(validateOnBuild: false)
            .addFinding(
                type: .mass,
                probability: 0.5,
                location: .point2D(x: 100.0, y: 100.0, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildWithZeroProbability() throws {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 0.0, // Edge case: valid but unusual
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildWithMaxProbability() throws {
        let imageRef = createSampleImageReference()
        let builder = createBasicBuilder()
            .addFinding(
                type: .mass,
                probability: 1.0, // Edge case: maximum valid value
                location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() throws {
        let imageRef = createSampleImageReference()
        
        let document = try MammographyCADSRBuilder()
            .withPatientID("MM-2024-001")
            .withPatientName("Smith^Jane^Marie")
            .withPatientBirthDate("19750615")
            .withPatientSex("F")
            .withStudyInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.78")
            .withStudyDate("20240115")
            .withStudyTime("143000")
            .withStudyDescription("Digital Screening Mammography")
            .withAccessionNumber("MM2024001")
            .withSeriesInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.100")
            .withSeriesNumber("501")
            .withSeriesDescription("CAD Analysis Results")
            .withInstanceNumber("1")
            .withContentDate("20240115")
            .withContentTime("144500")
            .withCADProcessingSummary(
                algorithmName: "MammoCare CAD",
                algorithmVersion: "3.2.1",
                manufacturer: "Digital Mammography Systems Inc",
                processingDateTime: "20240115144500"
            )
            .addFinding(
                type: .mass,
                probability: 0.87,
                location: .circle2D(
                    centerX: 245.5,
                    centerY: 389.2,
                    radius: 18.5,
                    imageReference: imageRef
                ),
                characteristics: [
                    CodedConcept(
                        codeValue: "M-78060",
                        codingSchemeDesignator: "SRT",
                        codeMeaning: "Spiculated margin"
                    )
                ]
            )
            .addFinding(
                type: .calcification,
                probability: 0.64,
                location: .point2D(x: 156.3, y: 425.8, imageReference: imageRef)
            )
            .withCompletionFlag(.complete)
            .withVerificationFlag(.unverified)
            .build()
        
        // Verify document structure
        XCTAssertEqual(document.patientID, "MM-2024-001")
        XCTAssertEqual(document.sopClassUID, "1.2.840.10008.5.1.4.1.1.88.50")
        XCTAssertEqual(document.documentTitle?.codeMeaning, "Mammography CAD Report")
        XCTAssertEqual(document.completionFlag, .complete)
        XCTAssertEqual(document.verificationFlag, .unverified)
    }
}
