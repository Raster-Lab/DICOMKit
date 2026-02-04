/// Tests for AIInferenceResult
///
/// Validates AI/ML inference result types and utilities.

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class AIInferenceResultTests: XCTestCase {
    
    // MARK: - AIDetection Tests
    
    func testAIDetectionInitialization() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.point2D(x: 100.0, y: 200.0, imageReference: imageRef)
        
        let detection = AIDetection(
            type: .lungNodule,
            confidence: 0.95,
            location: location,
            attributes: ["size": "small"]
        )
        
        XCTAssertEqual(detection.type, .lungNodule)
        XCTAssertEqual(detection.confidence, 0.95)
        if case .point2D(let x, let y, _) = detection.location {
            XCTAssertEqual(x, 100.0)
            XCTAssertEqual(y, 200.0)
        } else {
            XCTFail("Expected point2D location")
        }
        XCTAssertEqual(detection.attributes?["size"], "small")
    }
    
    func testAIDetectionWithoutAttributes() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.point2D(x: 100.0, y: 200.0, imageReference: imageRef)
        
        let detection = AIDetection(
            type: .mass,
            confidence: 0.85,
            location: location
        )
        
        XCTAssertNil(detection.attributes)
    }
    
    // MARK: - AIDetectionType Tests
    
    func testLungNoduleType() {
        let type = AIDetectionType.lungNodule
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "M-03010")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Nodule")
    }
    
    func testMassType() {
        let type = AIDetectionType.mass
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "F-01796")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Mass")
    }
    
    func testCalcificationType() {
        let type = AIDetectionType.calcification
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "F-61769")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Calcification")
    }
    
    func testLesionType() {
        let type = AIDetectionType.lesion
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "M-03000")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Lesion")
    }
    
    func testFractureType() {
        let type = AIDetectionType.fracture
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "M-12000")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Fracture")
    }
    
    func testHemorrhageType() {
        let type = AIDetectionType.hemorrhage
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "M-37000")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Hemorrhage")
    }
    
    func testPneumoniaType() {
        let type = AIDetectionType.pneumonia
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "M-40000")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Pneumonia")
    }
    
    func testPulmonaryEmbolismType() {
        let type = AIDetectionType.pulmonaryEmbolism
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "D3-81004")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Pulmonary embolism")
    }
    
    func testAnatomicalStructureType() {
        let type = AIDetectionType.anatomicalStructure(name: "Liver")
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "T-D0050")
        XCTAssertEqual(concept.codingSchemeDesignator, "SRT")
        XCTAssertEqual(concept.codeMeaning, "Liver")
    }
    
    func testCustomDetectionType() {
        let customConcept = CodedConcept(
            codeValue: "123456",
            codingSchemeDesignator: "CUSTOM",
            codeMeaning: "Custom Finding"
        )
        let type = AIDetectionType.custom(customConcept)
        let concept = type.concept
        
        XCTAssertEqual(concept.codeValue, "123456")
        XCTAssertEqual(concept.codingSchemeDesignator, "CUSTOM")
        XCTAssertEqual(concept.codeMeaning, "Custom Finding")
    }
    
    // MARK: - AIDetectionLocation Tests
    
    func testPoint2DLocation() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.point2D(x: 150.5, y: 250.3, imageReference: imageRef)
        
        if case .point2D(let x, let y, let ref) = location {
            XCTAssertEqual(x, 150.5)
            XCTAssertEqual(y, 250.3)
            XCTAssertEqual(ref.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
            XCTAssertEqual(ref.sopInstanceUID, "1.2.3.4.5")
        } else {
            XCTFail("Expected point2D location")
        }
    }
    
    func testBoundingBox2DLocation() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.boundingBox2D(
            x: 100.0, y: 100.0, width: 50.0, height: 75.0,
            imageReference: imageRef
        )
        
        if case .boundingBox2D(let x, let y, let width, let height, _) = location {
            XCTAssertEqual(x, 100.0)
            XCTAssertEqual(y, 100.0)
            XCTAssertEqual(width, 50.0)
            XCTAssertEqual(height, 75.0)
        } else {
            XCTFail("Expected boundingBox2D location")
        }
    }
    
    func testPolygon2DLocation() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let points = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
        let location = AIDetectionLocation.polygon2D(points: points, imageReference: imageRef)
        
        if case .polygon2D(let p, _) = location {
            XCTAssertEqual(p, points)
        } else {
            XCTFail("Expected polygon2D location")
        }
    }
    
    func testCircle2DLocation() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.circle2D(
            centerX: 200.0, centerY: 300.0, radius: 25.0,
            imageReference: imageRef
        )
        
        if case .circle2D(let cx, let cy, let r, _) = location {
            XCTAssertEqual(cx, 200.0)
            XCTAssertEqual(cy, 300.0)
            XCTAssertEqual(r, 25.0)
        } else {
            XCTFail("Expected circle2D location")
        }
    }
    
    func testPoint3DLocation() {
        let imageRef = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        let location = AIDetectionLocation.point3D(
            x: 100.0, y: 150.0, z: 200.0,
            frameOfReferenceUID: "1.2.3.4.5.6",
            imageReference: imageRef
        )
        
        if case .point3D(let x, let y, let z, let frameUID, _) = location {
            XCTAssertEqual(x, 100.0)
            XCTAssertEqual(y, 150.0)
            XCTAssertEqual(z, 200.0)
            XCTAssertEqual(frameUID, "1.2.3.4.5.6")
        } else {
            XCTFail("Expected point3D location")
        }
    }
    
    func testBoundingBox3DLocation() {
        let location = AIDetectionLocation.boundingBox3D(
            x: 10.0, y: 20.0, z: 30.0,
            width: 50.0, height: 60.0, depth: 70.0,
            frameOfReferenceUID: "1.2.3.4.5.6",
            imageReference: nil
        )
        
        if case .boundingBox3D(let x, let y, let z, let width, let height, let depth, let frameUID, _) = location {
            XCTAssertEqual(x, 10.0)
            XCTAssertEqual(y, 20.0)
            XCTAssertEqual(z, 30.0)
            XCTAssertEqual(width, 50.0)
            XCTAssertEqual(height, 60.0)
            XCTAssertEqual(depth, 70.0)
            XCTAssertEqual(frameUID, "1.2.3.4.5.6")
        } else {
            XCTFail("Expected boundingBox3D location")
        }
    }
    
    func testPolygon3DLocation() {
        let points = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
        let location = AIDetectionLocation.polygon3D(
            points: points,
            frameOfReferenceUID: "1.2.3.4.5.6",
            imageReference: nil
        )
        
        if case .polygon3D(let p, let frameUID, _) = location {
            XCTAssertEqual(p, points)
            XCTAssertEqual(frameUID, "1.2.3.4.5.6")
        } else {
            XCTFail("Expected polygon3D location")
        }
    }
    
    func testEllipsoid3DLocation() {
        let location = AIDetectionLocation.ellipsoid3D(
            centerX: 100.0, centerY: 150.0, centerZ: 200.0,
            radiusX: 10.0, radiusY: 15.0, radiusZ: 20.0,
            frameOfReferenceUID: "1.2.3.4.5.6",
            imageReference: nil
        )
        
        if case .ellipsoid3D(let cx, let cy, let cz, let rx, let ry, let rz, let frameUID, _) = location {
            XCTAssertEqual(cx, 100.0)
            XCTAssertEqual(cy, 150.0)
            XCTAssertEqual(cz, 200.0)
            XCTAssertEqual(rx, 10.0)
            XCTAssertEqual(ry, 15.0)
            XCTAssertEqual(rz, 20.0)
            XCTAssertEqual(frameUID, "1.2.3.4.5.6")
        } else {
            XCTFail("Expected ellipsoid3D location")
        }
    }
    
    // MARK: - ImageReference Tests
    
    func testImageReferenceInitialization() {
        let ref = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        XCTAssertEqual(ref.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(ref.sopInstanceUID, "1.2.3.4.5")
        XCTAssertNil(ref.frameNumber)
    }
    
    func testImageReferenceWithFrameNumber() {
        let ref = AIImageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            frameNumber: 5
        )
        
        XCTAssertEqual(ref.frameNumber, 5)
    }
    
    // MARK: - ConfidenceScore Tests
    
    func testConfidenceScoreToPercentageString() {
        XCTAssertEqual(ConfidenceScore.toPercentageString(0.0), "0.0")
        XCTAssertEqual(ConfidenceScore.toPercentageString(0.5), "50.0")
        XCTAssertEqual(ConfidenceScore.toPercentageString(0.855), "85.5")
        XCTAssertEqual(ConfidenceScore.toPercentageString(1.0), "100.0")
    }
    
    func testConfidenceScoreToCodedConcept() {
        let highConcept = ConfidenceScore.toCodedConcept(0.95)
        XCTAssertEqual(highConcept.codeValue, "R-00339")
        XCTAssertEqual(highConcept.codeMeaning, "High confidence")
        
        let mediumConcept = ConfidenceScore.toCodedConcept(0.80)
        XCTAssertEqual(mediumConcept.codeValue, "R-00340")
        XCTAssertEqual(mediumConcept.codeMeaning, "Medium confidence")
        
        let lowConcept = ConfidenceScore.toCodedConcept(0.65)
        XCTAssertEqual(lowConcept.codeValue, "R-00341")
        XCTAssertEqual(lowConcept.codeMeaning, "Low confidence")
    }
    
    func testConfidenceScoreCategorize() {
        XCTAssertEqual(ConfidenceScore.categorize(0.95), .high)
        XCTAssertEqual(ConfidenceScore.categorize(0.90), .high)
        XCTAssertEqual(ConfidenceScore.categorize(0.85), .medium)
        XCTAssertEqual(ConfidenceScore.categorize(0.70), .medium)
        XCTAssertEqual(ConfidenceScore.categorize(0.65), .low)
        XCTAssertEqual(ConfidenceScore.categorize(0.0), .low)
    }
    
    func testConfidenceScoreBoundaries() {
        // Test boundary conditions
        XCTAssertEqual(ConfidenceScore.categorize(1.0), .high)
        XCTAssertEqual(ConfidenceScore.categorize(0.9), .high)
        XCTAssertEqual(ConfidenceScore.categorize(0.89999), .medium)
        XCTAssertEqual(ConfidenceScore.categorize(0.7), .medium)
        XCTAssertEqual(ConfidenceScore.categorize(0.69999), .low)
    }
}
