/// Tests for CADFindings Extraction API
///
/// Validates extraction of CAD findings from Mammography and Chest CAD SR documents.

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class CADFindingsExtractorTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func createBasicMammographyCAD() throws -> SRDocument {
        let imageRef = createImageReference()
        let document = try MammographyCADSRBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^Jane")
            .withStudyInstanceUID("1.2.3.4.5")
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
            .build()
        return document
    }
    
    private func createBasicChestCAD() throws -> SRDocument {
        let imageRef = createImageReference()
        let document = try ChestCADSRBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^John")
            .withStudyInstanceUID("1.2.3.4.5")
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.0.0",
                manufacturer: "Example Medical Systems"
            )
            .addFinding(
                type: .nodule,
                probability: 0.75,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        return document
    }
    
    private func serializeAndParse(_ document: SRDocument) throws -> SRDocument {
        let serializer = SRDocumentSerializer()
        let dataSet = try serializer.serialize(document: document)
        
        let parser = SRDocumentParser()
        return try parser.parse(dataSet: dataSet)
    }
    
    private func createImageReference() -> ImageReference {
        ImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
    }
    
    // MARK: - Basic Extraction Tests - Mammography
    
    func testExtractMammographyCADMinimal() throws {
        let original = try createBasicMammographyCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.cadType, .mammography)
        XCTAssertNotNil(findings.processingInfo.algorithmName)
        XCTAssertGreaterThanOrEqual(findings.findings.count, 1)
    }
    
    func testExtractMammographyCADType() throws {
        let original = try createBasicMammographyCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.cadType, .mammography)
        XCTAssertEqual(findings.document.sopClassUID, SRDocumentType.mammographyCADSR.sopClassUID)
    }
    
    func testExtractChestCADType() throws {
        let original = try createBasicChestCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.cadType, .chest)
        XCTAssertEqual(findings.document.sopClassUID, SRDocumentType.chestCADSR.sopClassUID)
    }
    
    // MARK: - CAD Processing Info Tests
    
    func testExtractProcessingInfoAlgorithmName() throws {
        let original = try createBasicMammographyCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.processingInfo.algorithmName, "MammoCAD")
    }
    
    func testExtractProcessingInfoAlgorithmVersion() throws {
        let original = try createBasicMammographyCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.processingInfo.algorithmVersion, "2.1.0")
    }
    
    func testExtractProcessingInfoManufacturer() throws {
        let original = try createBasicMammographyCAD()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.processingInfo.manufacturer, "Example Medical Systems")
    }
    
    func testExtractProcessingInfoComplete() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "Advanced MammoCAD",
                algorithmVersion: "5.2.1",
                manufacturer: "Digital Mammography Inc"
            )
            .addFinding(
                type: .mass,
                probability: 0.9,
                location: .point2D(x: 100.0, y: 200.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.processingInfo.algorithmName, "Advanced MammoCAD")
        XCTAssertEqual(findings.processingInfo.algorithmVersion, "5.2.1")
        XCTAssertEqual(findings.processingInfo.manufacturer, "Digital Mammography Inc")
    }
    
    func testExtractProcessingInfoMinimal() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "1.0",
                manufacturer: "Vendor"
            )
            .addFinding(
                type: .mass,
                probability: 0.5,
                location: .point2D(x: 100.0, y: 100.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.processingInfo.algorithmName, "MammoCAD")
        XCTAssertNotNil(findings.processingInfo.algorithmVersion)
        XCTAssertNotNil(findings.processingInfo.manufacturer)
    }
    
    // MARK: - Single Finding Extraction Tests
    
    func testExtractSingleFindingMass() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "MammoCAD",
                algorithmVersion: "2.0",
                manufacturer: "Vendor"
            )
            .addFinding(
                type: .mass,
                probability: 0.87,
                location: .point2D(x: 150.5, y: 250.3, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        let finding = findings.findings[0]
        
        XCTAssertNotNil(finding.findingType)
        XCTAssertEqual(finding.findingType?.codeMeaning, "Mass")
        XCTAssertEqual(finding.probability ?? 0.0, 0.87, accuracy: 0.01)
    }
    
    func testExtractSingleFindingCalcification() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .calcification,
                probability: 0.65,
                location: .point2D(x: 75.0, y: 125.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].findingType?.codeMeaning, "Calcification")
        XCTAssertEqual(findings.findings[0].probability ?? 0.0, 0.65, accuracy: 0.01)
    }
    
    func testExtractSingleFindingArchitecturalDistortion() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .architecturalDistortion,
                probability: 0.55,
                location: .point2D(x: 200.0, y: 300.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].findingType?.codeMeaning, "Architectural Distortion")
    }
    
    func testExtractSingleFindingAsymmetry() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .asymmetry,
                probability: 0.45,
                location: .point2D(x: 180.0, y: 220.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].findingType?.codeMeaning, "Asymmetry")
    }
    
    // MARK: - Multiple Findings Tests
    
    func testExtractMultipleFindings() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.87,
                location: .point2D(x: 150.0, y: 250.0, imageReference: imageRef)
            )
            .addFinding(
                type: .calcification,
                probability: 0.65,
                location: .point2D(x: 75.0, y: 125.0, imageReference: imageRef)
            )
            .addFinding(
                type: .architecturalDistortion,
                probability: 0.55,
                location: .point2D(x: 200.0, y: 300.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 3)
        XCTAssertEqual(findings.findings[0].findingType?.codeMeaning, "Mass")
        XCTAssertEqual(findings.findings[1].findingType?.codeMeaning, "Calcification")
        XCTAssertEqual(findings.findings[2].findingType?.codeMeaning, "Architectural Distortion")
    }
    
    func testExtractManyFindings() throws {
        let imageRef = createImageReference()
        var builder = MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
        
        for i in 1...10 {
            builder = builder.addFinding(
                type: .mass,
                probability: Double(i) * 0.1,
                location: .point2D(x: Double(i) * 10.0, y: Double(i) * 20.0, imageReference: imageRef)
            )
        }
        
        let original = try builder.build()
        let parsed = try serializeAndParse(original)
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 10)
    }
    
    // MARK: - Finding Location Tests
    
    func testExtractFindingLocationPoint2D() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.9,
                location: .point2D(x: 123.45, y: 234.56, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertNotNil(findings.findings[0].location)
        
        if case .point2D(let x, let y, let ref) = findings.findings[0].location {
            XCTAssertEqual(x, 123.45, accuracy: 0.01)
            XCTAssertEqual(y, 234.56, accuracy: 0.01)
            XCTAssertNotNil(ref)
        } else {
            XCTFail("Expected point2D location")
        }
    }
    
    func testExtractFindingLocationCircle() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.85,
                location: .circle2D(centerX: 150.0, centerY: 200.0, radius: 25.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertNotNil(findings.findings[0].location)
        
        if case .circle(let cx, let cy, let rx, let ry, _) = findings.findings[0].location {
            XCTAssertEqual(cx, 150.0, accuracy: 0.01)
            XCTAssertEqual(cy, 200.0, accuracy: 0.01)
            XCTAssertEqual(rx, 25.0, accuracy: 0.01)
            XCTAssertEqual(ry, 25.0, accuracy: 0.01)
        } else {
            XCTFail("Expected circle location")
        }
    }
    
    func testExtractFindingLocationROI() throws {
        let imageRef = createImageReference()
        let roiPoints = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 10.0, 20.0]
        
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.8,
                location: .roi2D(points: roiPoints, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertNotNil(findings.findings[0].location)
        
        if case .polyline(let points, _) = findings.findings[0].location {
            XCTAssertEqual(points.count, 4)
        } else {
            XCTFail("Expected polyline location")
        }
    }
    
    // MARK: - Finding Characteristics Tests
    
    func testExtractFindingWithCharacteristics() throws {
        let imageRef = createImageReference()
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
        
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(finding)
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertGreaterThanOrEqual(findings.findings[0].characteristics.count, 2)
    }
    
    func testExtractFindingWithoutCharacteristics() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.7,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].characteristics.count, 0)
    }
    
    // MARK: - Probability Tests
    
    func testExtractFindingWithZeroProbability() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.0,
                location: .point2D(x: 100.0, y: 100.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].probability ?? 0.0, 0.0)
    }
    
    func testExtractFindingWithMaxProbability() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 1.0,
                location: .point2D(x: 100.0, y: 100.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].probability ?? 0.0, 1.0)
    }
    
    func testExtractFindingWithMidRangeProbability() throws {
        let imageRef = createImageReference()
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.5432,
                location: .point2D(x: 100.0, y: 100.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].probability ?? 0.0, 0.5432, accuracy: 0.0001)
    }
    
    // MARK: - Error Cases Tests
    
    func testExtractFromInvalidDocumentType() throws {
        let document = try BasicTextSRBuilder()
            .build()
        let parsed = try serializeAndParse(document)
        
        XCTAssertThrowsError(try CADFindings.extract(from: parsed)) { error in
            guard case ExtractionError.invalidDocumentType = error else {
                XCTFail("Expected invalidDocumentType error")
                return
            }
        }
    }
    
    func testExtractFromMeasurementReport() throws {
        let document = try MeasurementReportBuilder()
            .addMeasurementGroup(trackingIdentifier: "Lesion 1") {
                MeasurementGroupContentHelper.longAxisMM(value: 10.0)
            }
            .build()
        let parsed = try serializeAndParse(document)
        
        XCTAssertThrowsError(try CADFindings.extract(from: parsed)) { error in
            guard case ExtractionError.invalidDocumentType = error else {
                XCTFail("Expected invalidDocumentType error")
                return
            }
        }
    }
    
    func testExtractFromKeyObjectSelection() throws {
        let keyObject = KeyObject(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
        
        let document = try KeyObjectSelectionBuilder()
            .withDocumentTitle(.ofInterest)
            .addKeyObject(
                sopClassUID: keyObject.sopClassUID,
                sopInstanceUID: keyObject.sopInstanceUID
            )
            .build()
        let parsed = try serializeAndParse(document)
        
        XCTAssertThrowsError(try CADFindings.extract(from: parsed)) { error in
            guard case ExtractionError.invalidDocumentType = error else {
                XCTFail("Expected invalidDocumentType error")
                return
            }
        }
    }
    
    // MARK: - Chest CAD Specific Tests
    
    func testExtractChestCADNodule() throws {
        let imageRef = createImageReference()
        let original = try ChestCADSRBuilder()
            .withCADProcessingSummary(
                algorithmName: "ChestCAD",
                algorithmVersion: "3.0.0",
                manufacturer: "Example Medical Systems"
            )
            .addFinding(
                type: .nodule,
                probability: 0.85,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.cadType, .chest)
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertNotNil(findings.findings[0].findingType)
    }
    
    func testExtractChestCADMultipleFindings() throws {
        let imageRef = createImageReference()
        let original = try ChestCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "ChestCAD", algorithmVersion: "3.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .nodule,
                probability: 0.85,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .addFinding(
                type: .nodule,
                probability: 0.72,
                location: .point2D(x: 200.0, y: 250.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 2)
    }
    
    // MARK: - Complete Workflow Tests
    
    func testCompleteWorkflowMammography() throws {
        let imageRef = createImageReference()
        let characteristics = [
            CodedConcept(codeValue: "M-78060", codingSchemeDesignator: "SRT", codeMeaning: "Spiculated margin")
        ]
        
        let original = try MammographyCADSRBuilder()
            .withPatientID("CAD-2024-001")
            .withPatientName("Smith^Jane")
            .withPatientBirthDate("19750615")
            .withPatientSex("F")
            .withStudyInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.100")
            .withStudyDate("20240115")
            .withCADProcessingSummary(
                algorithmName: "MammoCare CAD",
                algorithmVersion: "3.2.1",
                manufacturer: "Digital Mammography Systems Inc"
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
                characteristics: characteristics
            )
            .addFinding(
                type: .calcification,
                probability: 0.64,
                location: .point2D(x: 156.3, y: 425.8, imageReference: imageRef)
            )
            .build()
        
        let parsed = try serializeAndParse(original)
        let extracted = try CADFindings.extract(from: parsed)
        
        // Verify document information
        XCTAssertEqual(extracted.cadType, .mammography)
        XCTAssertEqual(extracted.document.patientID, "CAD-2024-001")
        
        // Verify processing info
        XCTAssertEqual(extracted.processingInfo.algorithmName, "MammoCare CAD")
        XCTAssertEqual(extracted.processingInfo.algorithmVersion, "3.2.1")
        XCTAssertEqual(extracted.processingInfo.manufacturer, "Digital Mammography Systems Inc")
        
        // Verify findings
        XCTAssertEqual(extracted.findings.count, 2)
        
        let massFindings = extracted.findings.filter { $0.findingType?.codeMeaning == "Mass" }
        XCTAssertEqual(massFindings.count, 1)
        XCTAssertEqual(massFindings[0].probability ?? 0.0, 0.87, accuracy: 0.01)
        
        let calcFindings = extracted.findings.filter { $0.findingType?.codeMeaning == "Calcification" }
        XCTAssertEqual(calcFindings.count, 1)
        XCTAssertEqual(calcFindings[0].probability ?? 0.0, 0.64, accuracy: 0.01)
    }
    
    func testCompleteWorkflowChest() throws {
        let imageRef = createImageReference()
        
        let original = try ChestCADSRBuilder()
            .withPatientID("CHEST-2024-001")
            .withPatientName("Doe^John")
            .withStudyInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.200")
            .withCADProcessingSummary(
                algorithmName: "LungCAD Pro",
                algorithmVersion: "4.1.0",
                manufacturer: "Pulmonary Imaging Systems"
            )
            .addFinding(
                type: .nodule,
                probability: 0.92,
                location: .point2D(x: 150.0, y: 200.0, imageReference: imageRef)
            )
            .addFinding(
                type: .nodule,
                probability: 0.68,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        
        let parsed = try serializeAndParse(original)
        let extracted = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(extracted.cadType, .chest)
        XCTAssertEqual(extracted.document.patientID, "CHEST-2024-001")
        XCTAssertEqual(extracted.processingInfo.algorithmName, "LungCAD Pro")
        XCTAssertEqual(extracted.findings.count, 2)
    }
    
    // MARK: - Edge Cases Tests
    
    func testExtractWithNoFindings() throws {
        let original = try MammographyCADSRBuilder(validateOnBuild: false)
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        // Should extract successfully but have no findings
        XCTAssertEqual(findings.findings.count, 0)
    }
    
    func testExtractWithCustomFindingType() throws {
        let imageRef = createImageReference()
        let customType = CodedConcept(
            codeValue: "CUSTOM-001",
            codingSchemeDesignator: "99TEST",
            codeMeaning: "Custom Finding Type"
        )
        
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .custom(customType),
                probability: 0.75,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertEqual(findings.findings[0].findingType?.codeValue, "CUSTOM-001")
    }
    
    func testExtractFindingWithImageReference() throws {
        let imageRef = ImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9.10"
        )
        
        let original = try MammographyCADSRBuilder()
            .withCADProcessingSummary(algorithmName: "MammoCAD", algorithmVersion: "2.0", manufacturer: "Test Vendor")
            .addFinding(
                type: .mass,
                probability: 0.8,
                location: .point2D(x: 100.0, y: 150.0, imageReference: imageRef)
            )
            .build()
        let parsed = try serializeAndParse(original)
        
        let findings = try CADFindings.extract(from: parsed)
        
        XCTAssertEqual(findings.findings.count, 1)
        XCTAssertNotNil(findings.findings[0].imageReference)
        XCTAssertEqual(findings.findings[0].imageReference?.sopReference.sopInstanceUID, "1.2.3.4.5.6.7.8.9.10")
    }
}
