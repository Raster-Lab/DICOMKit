/// Tests for ChestCADSRBuilder
///
/// Validates the creation and validation of Chest CAD SR documents.

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class ChestCADSRBuilderTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func createBasicBuilder() -> ChestCADSRBuilder {
        ChestCADSRBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^John")
            .withStudyInstanceUID("1.2.3.4.5")
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems"
            )
    }
    
    private func createSampleImageReference() -> ImageReference {
        ImageReference(
            sopReference: ReferencedSOP(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
                sopInstanceUID: "1.2.3.4.5.6.7.8.9"
            ),
            frameNumbers: nil,
            segmentNumbers: nil,
            purposeOfReference: nil
        )
    }
    
    // MARK: - Initialization Tests
    
    func testBuilderInitialization() {
        let builder = ChestCADSRBuilder()
        XCTAssertTrue(builder.validateOnBuild)
        XCTAssertNil(builder.sopInstanceUID)
        XCTAssertNil(builder.patientID)
        XCTAssertEqual(builder.findings.count, 0)
        XCTAssertEqual(builder.completionFlag, .complete)
        XCTAssertEqual(builder.verificationFlag, .unverified)
    }
    
    func testBuilderInitializationWithoutValidation() {
        let builder = ChestCADSRBuilder(validateOnBuild: false)
        XCTAssertFalse(builder.validateOnBuild)
    }
    
    // MARK: - Patient Information Tests
    
    func testWithPatientID() {
        let builder = ChestCADSRBuilder()
            .withPatientID("12345")
        XCTAssertEqual(builder.patientID, "12345")
    }
    
    func testWithPatientName() {
        let builder = ChestCADSRBuilder()
            .withPatientName("Doe^John")
        XCTAssertEqual(builder.patientName, "Doe^John")
    }
    
    func testWithPatientBirthDate() {
        let builder = ChestCADSRBuilder()
            .withPatientBirthDate("19700101")
        XCTAssertEqual(builder.patientBirthDate, "19700101")
    }
    
    func testWithPatientSex() {
        let builder = ChestCADSRBuilder()
            .withPatientSex("M")
        XCTAssertEqual(builder.patientSex, "M")
    }
    
    // MARK: - Study Information Tests
    
    func testWithStudyInstanceUID() {
        let builder = ChestCADSRBuilder()
            .withStudyInstanceUID("1.2.3.4.5")
        XCTAssertEqual(builder.studyInstanceUID, "1.2.3.4.5")
    }
    
    func testWithStudyDate() {
        let builder = ChestCADSRBuilder()
            .withStudyDate("20240101")
        XCTAssertEqual(builder.studyDate, "20240101")
    }
    
    func testWithStudyTime() {
        let builder = ChestCADSRBuilder()
            .withStudyTime("120000")
        XCTAssertEqual(builder.studyTime, "120000")
    }
    
    func testWithStudyDescription() {
        let builder = ChestCADSRBuilder()
            .withStudyDescription("Chest CT")
        XCTAssertEqual(builder.studyDescription, "Chest CT")
    }
    
    func testWithAccessionNumber() {
        let builder = ChestCADSRBuilder()
            .withAccessionNumber("ACC123456")
        XCTAssertEqual(builder.accessionNumber, "ACC123456")
    }
    
    func testWithReferringPhysicianName() {
        let builder = ChestCADSRBuilder()
            .withReferringPhysicianName("Smith^Jane")
        XCTAssertEqual(builder.referringPhysicianName, "Smith^Jane")
    }
    
    // MARK: - Series Information Tests
    
    func testWithSeriesInstanceUID() {
        let builder = ChestCADSRBuilder()
            .withSeriesInstanceUID("1.2.3.4.5.6")
        XCTAssertEqual(builder.seriesInstanceUID, "1.2.3.4.5.6")
    }
    
    func testWithSeriesNumber() {
        let builder = ChestCADSRBuilder()
            .withSeriesNumber("2")
        XCTAssertEqual(builder.seriesNumber, "2")
    }
    
    func testWithSeriesDescription() {
        let builder = ChestCADSRBuilder()
            .withSeriesDescription("CAD Analysis")
        XCTAssertEqual(builder.seriesDescription, "CAD Analysis")
    }
    
    // MARK: - Document Information Tests
    
    func testWithSOPInstanceUID() {
        let builder = ChestCADSRBuilder()
            .withSOPInstanceUID("1.2.3.4.5.6.7")
        XCTAssertEqual(builder.sopInstanceUID, "1.2.3.4.5.6.7")
    }
    
    func testWithInstanceNumber() {
        let builder = ChestCADSRBuilder()
            .withInstanceNumber("1")
        XCTAssertEqual(builder.instanceNumber, "1")
    }
    
    func testWithContentDate() {
        let builder = ChestCADSRBuilder()
            .withContentDate("20240101")
        XCTAssertEqual(builder.contentDate, "20240101")
    }
    
    func testWithContentTime() {
        let builder = ChestCADSRBuilder()
            .withContentTime("120000")
        XCTAssertEqual(builder.contentTime, "120000")
    }
    
    func testWithCompletionFlag() {
        let builder = ChestCADSRBuilder()
            .withCompletionFlag(.partial)
        XCTAssertEqual(builder.completionFlag, .partial)
    }
    
    func testWithVerificationFlag() {
        let builder = ChestCADSRBuilder()
            .withVerificationFlag(.verified)
        XCTAssertEqual(builder.verificationFlag, .verified)
    }
    
    // MARK: - CAD Processing Information Tests
    
    func testWithCADProcessingSummary() {
        let builder = ChestCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems",
                processingDateTime: "20240101120000"
            )
        
        XCTAssertEqual(builder.algorithmName, "ChestCAD")
        XCTAssertEqual(builder.algorithmVersion, "3.2.0")
        XCTAssertEqual(builder.manufacturer, "Example Medical Systems")
        XCTAssertEqual(builder.processingDateTime, "20240101120000")
    }
    
    func testWithCADProcessingSummaryWithoutDateTime() {
        let builder = ChestCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems"
            )
        
        XCTAssertEqual(builder.algorithmName, "ChestCAD")
        XCTAssertNil(builder.processingDateTime)
    }
    
    // MARK: - Finding Management Tests
    
    func testAddFindingWithFindingStruct() {
        let imageRef = createSampleImageReference()
        let finding = ChestCADFinding(
            type: .nodule,
            probability: 0.92,
            location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
        )
        
        let builder = ChestCADSRBuilder()
            .addFinding(finding)
        
        XCTAssertEqual(builder.findings.count, 1)
        XCTAssertEqual(builder.findings[0], finding)
    }
    
    func testAddFindingWithParameters() {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        XCTAssertEqual(builder.findings.count, 1)
        XCTAssertEqual(builder.findings[0].probability, 0.92)
    }
    
    func testAddMultipleFindings() {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
            .addFinding(
                type: .mass,
                probability: 0.75,
                location: .point2D(x: 128.3, y: 192.1, imageReference: imageRef)
            )
        
        XCTAssertEqual(builder.findings.count, 2)
    }
    
    func testClearFindings() {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
            .clearFindings()
        
        XCTAssertEqual(builder.findings.count, 0)
    }
    
    // MARK: - Finding Type Tests
    
    func testNoduleFindingType() {
        let concept = ChestFindingType.nodule.concept
        XCTAssertEqual(concept.codeValue, "39607008")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Lung nodule")
    }
    
    func testMassFindingType() {
        let concept = ChestFindingType.mass.concept
        XCTAssertEqual(concept.codeValue, "126952004")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Lung mass")
    }
    
    func testLesionFindingType() {
        let concept = ChestFindingType.lesion.concept
        XCTAssertEqual(concept.codeValue, "126601007")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Lesion of lung")
    }
    
    func testConsolidationFindingType() {
        let concept = ChestFindingType.consolidation.concept
        XCTAssertEqual(concept.codeValue, "3128005")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Pulmonary consolidation")
    }
    
    func testTreeInBudFindingType() {
        let concept = ChestFindingType.treeInBud.concept
        XCTAssertEqual(concept.codeValue, "44914007")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Tree-in-bud pattern")
    }
    
    func testCustomFindingType() {
        let customConcept = CodedConcept(
            codeValue: "12345",
            codingSchemeDesignator: "SRT",
            codeMeaning: "Custom Finding"
        )
        let findingType = ChestFindingType.custom(customConcept)
        XCTAssertEqual(findingType.concept, customConcept)
    }
    
    // MARK: - Finding Location Tests
    
    func testPoint2DLocation() {
        let imageRef = createSampleImageReference()
        let location = ChestFindingLocation.point2D(x: 256.5, y: 384.7, imageReference: imageRef)
        
        if case .point2D(let x, let y, let ref) = location {
            XCTAssertEqual(x, 256.5)
            XCTAssertEqual(y, 384.7)
            XCTAssertEqual(ref.sopReference.sopInstanceUID, imageRef.sopReference.sopInstanceUID)
        } else {
            XCTFail("Expected point2D location")
        }
    }
    
    func testROI2DLocation() {
        let imageRef = createSampleImageReference()
        let points = [100.0, 100.0, 200.0, 100.0, 200.0, 200.0, 100.0, 200.0]
        let location = ChestFindingLocation.roi2D(points: points, imageReference: imageRef)
        
        if case .roi2D(let pts, let ref) = location {
            XCTAssertEqual(pts, points)
            XCTAssertEqual(ref.sopReference.sopInstanceUID, imageRef.sopReference.sopInstanceUID)
        } else {
            XCTFail("Expected roi2D location")
        }
    }
    
    func testCircle2DLocation() {
        let imageRef = createSampleImageReference()
        let location = ChestFindingLocation.circle2D(
            centerX: 256.0,
            centerY: 384.0,
            radius: 50.0,
            imageReference: imageRef
        )
        
        if case .circle2D(let cx, let cy, let r, let ref) = location {
            XCTAssertEqual(cx, 256.0)
            XCTAssertEqual(cy, 384.0)
            XCTAssertEqual(r, 50.0)
            XCTAssertEqual(ref.sopReference.sopInstanceUID, imageRef.sopReference.sopInstanceUID)
        } else {
            XCTFail("Expected circle2D location")
        }
    }
    
    // MARK: - Build Tests
    
    func testBuildBasicDocument() throws {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        XCTAssertEqual(document.sopClassUID, "1.2.840.10008.5.1.4.1.1.88.65")
        XCTAssertEqual(document.documentType, .chestCADSR)
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.patientName, "Doe^John")
        XCTAssertEqual(document.studyInstanceUID, "1.2.3.4.5")
        XCTAssertNotNil(document.sopInstanceUID)
        XCTAssertNotNil(document.seriesInstanceUID)
    }
    
    func testBuildGeneratesUIDsWhenNotSet() throws {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .withPatientID("12345")
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems"
            )
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        XCTAssertFalse(document.sopInstanceUID.isEmpty)
        XCTAssertFalse(document.seriesInstanceUID?.isEmpty ?? true)
    }
    
    func testBuildWithAllPropertiesSet() throws {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .withSOPInstanceUID("1.2.3.4.5.6.7")
            .withStudyInstanceUID("1.2.3.4.5")
            .withSeriesInstanceUID("1.2.3.4.5.6")
            .withInstanceNumber("1")
            .withPatientID("12345")
            .withPatientName("Doe^John")
            .withPatientBirthDate("19700101")
            .withPatientSex("M")
            .withStudyDate("20240101")
            .withStudyTime("120000")
            .withStudyDescription("Chest CT")
            .withAccessionNumber("ACC123456")
            .withReferringPhysicianName("Smith^Jane")
            .withSeriesNumber("2")
            .withSeriesDescription("CAD Analysis")
            .withContentDate("20240101")
            .withContentTime("120000")
            .withCompletionFlag(.complete)
            .withVerificationFlag(.verified)
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems",
                processingDateTime: "20240101120000"
            )
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        XCTAssertEqual(document.sopInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertEqual(document.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(document.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(document.instanceNumber, "1")
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.patientName, "Doe^John")
        XCTAssertEqual(document.studyDate, "20240101")
        XCTAssertEqual(document.studyTime, "120000")
        XCTAssertEqual(document.accessionNumber, "ACC123456")
        XCTAssertEqual(document.seriesNumber, "2")
        XCTAssertEqual(document.contentDate, "20240101")
        XCTAssertEqual(document.contentTime, "120000")
        XCTAssertEqual(document.completionFlag, .complete)
        XCTAssertEqual(document.verificationFlag, .verified)
    }
    
    func testBuildWithMultipleFindings() throws {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
            .addFinding(
                type: .mass,
                probability: 0.75,
                location: .roi2D(
                    points: [100.0, 100.0, 200.0, 100.0, 200.0, 200.0, 100.0, 200.0],
                    imageReference: imageRef
                )
            )
            .addFinding(
                type: .consolidation,
                probability: 0.88,
                location: .circle2D(centerX: 128.0, centerY: 192.0, radius: 25.0, imageReference: imageRef)
            )
        
        let document = try builder.build()
        
        // Verify document was created with multiple findings
        XCTAssertNotNil(document)
        XCTAssertEqual(document.patientID, "12345")
    }
    
    func testBuildWithCharacteristics() throws {
        let imageRef = createSampleImageReference()
        let characteristics = [
            CodedConcept(codeValue: "C001", codingSchemeDesignator: "SRT", codeMeaning: "Spiculated"),
            CodedConcept(codeValue: "C002", codingSchemeDesignator: "SRT", codeMeaning: "Solid")
        ]
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef),
                characteristics: characteristics
            )
        
        let document = try builder.build()
        
        XCTAssertNotNil(document)
        XCTAssertEqual(document.patientID, "12345")
    }
    
    // MARK: - Validation Tests
    
    func testValidationFailsWithoutAlgorithmName() {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .withPatientID("12345")
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            if case ChestCADSRBuilder.BuildError.validationError(let message) = error {
                XCTAssertTrue(message.contains("algorithm name"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testValidationFailsWithoutFindings() {
        let builder = ChestCADSRBuilder()
            .withPatientID("12345")
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.2.0",
                manufacturer: "Example Medical Systems"
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            if case ChestCADSRBuilder.BuildError.validationError(let message) = error {
                XCTAssertTrue(message.contains("at least one finding"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testValidationFailsWithInvalidProbabilityTooLow() {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: -0.1,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            if case ChestCADSRBuilder.BuildError.validationError(let message) = error {
                XCTAssertTrue(message.contains("probability"))
                XCTAssertTrue(message.contains("0.0"))
                XCTAssertTrue(message.contains("1.0"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testValidationFailsWithInvalidProbabilityTooHigh() {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 1.5,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        
        XCTAssertThrowsError(try builder.build()) { error in
            if case ChestCADSRBuilder.BuildError.validationError(let message) = error {
                XCTAssertTrue(message.contains("probability"))
                XCTAssertTrue(message.contains("0.0"))
                XCTAssertTrue(message.contains("1.0"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testBuildWithoutValidation() throws {
        let builder = ChestCADSRBuilder(validateOnBuild: false)
            .withPatientID("12345")
        
        // Should not throw even without algorithm name or findings
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    // MARK: - Edge Case Tests
    
    func testBuildWithMinimalInformation() throws {
        let imageRef = createSampleImageReference()
        
        let builder = ChestCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "1.0",
                manufacturer: "Test"
            )
            .addFinding(
                type: .nodule,
                probability: 0.5,
                location: .point2D(x: 0, y: 0, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildWithProbabilityAtBoundaries() throws {
        let imageRef = createSampleImageReference()
        
        // Test with probability = 0.0
        let builder1 = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.0,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        let document1 = try builder1.build()
        XCTAssertNotNil(document1)
        
        // Test with probability = 1.0
        let builder2 = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 1.0,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
        let document2 = try builder2.build()
        XCTAssertNotNil(document2)
    }
    
    func testBuildWithAllFindingTypes() throws {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(type: .nodule, probability: 0.9, location: .point2D(x: 100, y: 100, imageReference: imageRef))
            .addFinding(type: .mass, probability: 0.8, location: .point2D(x: 200, y: 200, imageReference: imageRef))
            .addFinding(type: .lesion, probability: 0.7, location: .point2D(x: 300, y: 300, imageReference: imageRef))
            .addFinding(type: .consolidation, probability: 0.6, location: .point2D(x: 400, y: 400, imageReference: imageRef))
            .addFinding(type: .treeInBud, probability: 0.5, location: .point2D(x: 500, y: 500, imageReference: imageRef))
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
    
    func testBuildWithAllLocationType() throws {
        let imageRef = createSampleImageReference()
        
        let builder = createBasicBuilder()
            .addFinding(
                type: .nodule,
                probability: 0.9,
                location: .point2D(x: 256.5, y: 384.7, imageReference: imageRef)
            )
            .addFinding(
                type: .mass,
                probability: 0.8,
                location: .roi2D(
                    points: [100.0, 100.0, 200.0, 100.0, 200.0, 200.0, 100.0, 200.0],
                    imageReference: imageRef
                )
            )
            .addFinding(
                type: .consolidation,
                probability: 0.7,
                location: .circle2D(centerX: 128.0, centerY: 192.0, radius: 25.0, imageReference: imageRef)
            )
        
        let document = try builder.build()
        XCTAssertNotNil(document)
    }
}
