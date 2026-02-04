import Testing
import Foundation
import DICOMCore
@testable import DICOMKit

// MARK: - Comprehensive3DSRBuilder Tests

@Suite("Comprehensive3DSRBuilder Tests")
struct Comprehensive3DSRBuilderTests {
    
    // MARK: - Basic Builder Tests
    
    @Test("Builder initialization with default values")
    func testBuilderInitialization() {
        let builder = Comprehensive3DSRBuilder()
        
        #expect(builder.validateOnBuild == true)
        #expect(builder.completionFlag == .partial)
        #expect(builder.verificationFlag == .unverified)
        #expect(builder.contentItems.isEmpty)
        #expect(builder.frameOfReferenceUID == nil)
    }
    
    @Test("Builder initialization with validation disabled")
    func testBuilderWithValidationDisabled() {
        let builder = Comprehensive3DSRBuilder(validateOnBuild: false)
        #expect(builder.validateOnBuild == false)
    }
    
    @Test("Build minimal document")
    func testBuildMinimalDocument() throws {
        let document = try Comprehensive3DSRBuilder()
            .build()
        
        #expect(!document.sopInstanceUID.isEmpty)
        #expect(document.sopClassUID == SRDocumentType.comprehensive3DSR.sopClassUID)
        #expect(document.documentType == .comprehensive3DSR)
        #expect(document.modality == "SR")
    }
    
    // MARK: - Document Identification Tests
    
    @Test("Set SOP Instance UID")
    func testSetSOPInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.9"
        let document = try Comprehensive3DSRBuilder()
            .withSOPInstanceUID(uid)
            .build()
        
        #expect(document.sopInstanceUID == uid)
    }
    
    @Test("Set Study Instance UID")
    func testSetStudyInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.10"
        let document = try Comprehensive3DSRBuilder()
            .withStudyInstanceUID(uid)
            .build()
        
        #expect(document.studyInstanceUID == uid)
    }
    
    @Test("Set Series Instance UID")
    func testSetSeriesInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.11"
        let document = try Comprehensive3DSRBuilder()
            .withSeriesInstanceUID(uid)
            .build()
        
        #expect(document.seriesInstanceUID == uid)
    }
    
    @Test("Set Instance Number")
    func testSetInstanceNumber() throws {
        let builder = Comprehensive3DSRBuilder()
            .withInstanceNumber("5")
        
        #expect(builder.instanceNumber == "5")
    }
    
    // MARK: - Patient Information Tests
    
    @Test("Set Patient ID")
    func testSetPatientID() throws {
        let document = try Comprehensive3DSRBuilder()
            .withPatientID("PAT123")
            .build()
        
        #expect(document.patientID == "PAT123")
    }
    
    @Test("Set Patient Name")
    func testSetPatientName() throws {
        let document = try Comprehensive3DSRBuilder()
            .withPatientName("Doe^John")
            .build()
        
        #expect(document.patientName == "Doe^John")
    }
    
    @Test("Set Patient Birth Date")
    func testSetPatientBirthDate() throws {
        let builder = Comprehensive3DSRBuilder()
            .withPatientBirthDate("19800101")
        
        #expect(builder.patientBirthDate == "19800101")
    }
    
    @Test("Set Patient Sex")
    func testSetPatientSex() throws {
        let builder = Comprehensive3DSRBuilder()
            .withPatientSex("M")
        
        #expect(builder.patientSex == "M")
    }
    
    // MARK: - Study Information Tests
    
    @Test("Set Study Date")
    func testSetStudyDate() throws {
        let builder = Comprehensive3DSRBuilder()
            .withStudyDate("20240115")
        
        #expect(builder.studyDate == "20240115")
    }
    
    @Test("Set Study Time")
    func testSetStudyTime() throws {
        let builder = Comprehensive3DSRBuilder()
            .withStudyTime("143025")
        
        #expect(builder.studyTime == "143025")
    }
    
    @Test("Set Study Description")
    func testSetStudyDescription() throws {
        let builder = Comprehensive3DSRBuilder()
            .withStudyDescription("CT Chest")
        
        #expect(builder.studyDescription == "CT Chest")
    }
    
    @Test("Set Accession Number")
    func testSetAccessionNumber() throws {
        let builder = Comprehensive3DSRBuilder()
            .withAccessionNumber("ACC123456")
        
        #expect(builder.accessionNumber == "ACC123456")
    }
    
    @Test("Set Referring Physician Name")
    func testSetReferringPhysicianName() throws {
        let builder = Comprehensive3DSRBuilder()
            .withReferringPhysicianName("Smith^Dr")
        
        #expect(builder.referringPhysicianName == "Smith^Dr")
    }
    
    // MARK: - Series Information Tests
    
    @Test("Set Series Number")
    func testSetSeriesNumber() throws {
        let builder = Comprehensive3DSRBuilder()
            .withSeriesNumber("1")
        
        #expect(builder.seriesNumber == "1")
    }
    
    @Test("Set Series Description")
    func testSetSeriesDescription() throws {
        let builder = Comprehensive3DSRBuilder()
            .withSeriesDescription("3D Measurement Report")
        
        #expect(builder.seriesDescription == "3D Measurement Report")
    }
    
    // MARK: - Document Information Tests
    
    @Test("Set Content Date")
    func testSetContentDate() throws {
        let builder = Comprehensive3DSRBuilder()
            .withContentDate("20240115")
        
        #expect(builder.contentDate == "20240115")
    }
    
    @Test("Set Content Time")
    func testSetContentTime() throws {
        let builder = Comprehensive3DSRBuilder()
            .withContentTime("143025")
        
        #expect(builder.contentTime == "143025")
    }
    
    @Test("Set Document Title (coded)")
    func testSetDocumentTitleCoded() throws {
        let title = CodedConcept(
            codeValue: "11528-7",
            codingSchemeDesignator: "LN",
            codeMeaning: "Radiology Report"
        )
        
        let document = try Comprehensive3DSRBuilder()
            .withDocumentTitle(title)
            .build()
        
        #expect(document.documentTitle == title)
    }
    
    @Test("Set Document Title (string)")
    func testSetDocumentTitleString() throws {
        let document = try Comprehensive3DSRBuilder()
            .withDocumentTitle("3D Analysis Report")
            .build()
        
        #expect(document.documentTitle?.codeMeaning == "3D Analysis Report")
    }
    
    @Test("Set Completion Flag")
    func testSetCompletionFlag() throws {
        let builder = Comprehensive3DSRBuilder()
            .withCompletionFlag(.complete)
        
        #expect(builder.completionFlag == .complete)
    }
    
    @Test("Set Verification Flag")
    func testSetVerificationFlag() throws {
        let builder = Comprehensive3DSRBuilder()
            .withVerificationFlag(.verified)
        
        #expect(builder.verificationFlag == .verified)
    }
    
    @Test("Set Preliminary Flag")
    func testSetPreliminaryFlag() throws {
        let builder = Comprehensive3DSRBuilder()
            .withPreliminaryFlag(.preliminary)
        
        #expect(builder.preliminaryFlag == .preliminary)
    }
    
    // MARK: - Frame of Reference Tests
    
    @Test("Set Frame of Reference UID")
    func testSetFrameOfReferenceUID() throws {
        let uid = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let builder = Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(uid)
        
        #expect(builder.frameOfReferenceUID == uid)
    }
    
    @Test("Frame of Reference UID is used for 3D coordinates")
    func testFrameOfReferenceUIDUsedForCoordinates() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPoint3D(x: 10.0, y: 20.0, z: 30.0)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.asSpatialCoordinates3D?.frameOfReferenceUID == frameOfRef)
    }
    
    @Test("Override default Frame of Reference UID per coordinate")
    func testOverrideFrameOfReferenceUID() throws {
        let defaultFrameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let overrideFrameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.2"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(defaultFrameOfRef)
            .addPoint3D(x: 10.0, y: 20.0, z: 30.0)
            .addPoint3D(x: 15.0, y: 25.0, z: 35.0, frameOfReferenceUID: overrideFrameOfRef)
            .build()
        
        #expect(document.rootContent.contentItems[0].asSpatialCoordinates3D?.frameOfReferenceUID == defaultFrameOfRef)
        #expect(document.rootContent.contentItems[1].asSpatialCoordinates3D?.frameOfReferenceUID == overrideFrameOfRef)
    }
    
    // MARK: - 3D Spatial Coordinates Tests
    
    @Test("Add 3D point")
    func testAdd3DPoint() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPoint3D(x: 100.5, y: 200.5, z: 50.5)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .scoord3D)
        
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .point)
        #expect(scoord?.graphicData == [100.5, 200.5, 50.5])
        #expect(scoord?.pointCount == 1)
    }
    
    @Test("Add 3D polyline")
    func testAdd3DPolyline() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let points: [(x: Float, y: Float, z: Float)] = [
            (10.0, 20.0, 30.0),
            (15.0, 25.0, 35.0),
            (20.0, 30.0, 40.0)
        ]
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPolyline3D(points: points)
            .build()
        
        let item = document.rootContent.contentItems[0]
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .polyline)
        #expect(scoord?.pointCount == 3)
        #expect(scoord?.graphicData == [10.0, 20.0, 30.0, 15.0, 25.0, 35.0, 20.0, 30.0, 40.0])
    }
    
    @Test("Add 3D polygon")
    func testAdd3DPolygon() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let points: [(x: Float, y: Float, z: Float)] = [
            (10.0, 20.0, 30.0),
            (15.0, 25.0, 35.0),
            (20.0, 30.0, 40.0),
            (10.0, 20.0, 30.0) // Close the polygon
        ]
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPolygon3D(points: points)
            .build()
        
        let item = document.rootContent.contentItems[0]
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .polygon)
        #expect(scoord?.pointCount == 4)
    }
    
    @Test("Add 3D ellipse")
    func testAdd3DEllipse() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addEllipse3D(
                majorAxisEndpoint1: (x: 100.0, y: 100.0, z: 50.0),
                majorAxisEndpoint2: (x: 120.0, y: 100.0, z: 50.0),
                minorAxisEndpoint1: (x: 110.0, y: 90.0, z: 50.0),
                minorAxisEndpoint2: (x: 110.0, y: 110.0, z: 50.0)
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .ellipse)
        #expect(scoord?.pointCount == 4)
        #expect(scoord?.graphicData.count == 12)
    }
    
    @Test("Add 3D ellipsoid")
    func testAdd3DEllipsoid() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addEllipsoid(
                firstAxis: (
                    point1: (x: 100.0, y: 100.0, z: 50.0),
                    point2: (x: 120.0, y: 100.0, z: 50.0)
                ),
                secondAxis: (
                    point1: (x: 110.0, y: 90.0, z: 50.0),
                    point2: (x: 110.0, y: 110.0, z: 50.0)
                ),
                thirdAxis: (
                    point1: (x: 110.0, y: 100.0, z: 40.0),
                    point2: (x: 110.0, y: 100.0, z: 60.0)
                )
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .ellipsoid)
        #expect(scoord?.pointCount == 6)
        #expect(scoord?.graphicData.count == 18)
    }
    
    @Test("Add 3D multipoint")
    func testAdd3DMultipoint() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let points: [(x: Float, y: Float, z: Float)] = [
            (10.0, 20.0, 30.0),
            (15.0, 25.0, 35.0),
            (20.0, 30.0, 40.0)
        ]
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addMultipoint3D(points: points)
            .build()
        
        let item = document.rootContent.contentItems[0]
        let scoord = item.asSpatialCoordinates3D
        #expect(scoord?.graphicType == .multipoint)
        #expect(scoord?.pointCount == 3)
    }
    
    @Test("Add 3D coordinates with concept name")
    func testAdd3DCoordinatesWithConceptName() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        let conceptName = CodedConcept(
            codeValue: "111030",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Image Region"
        )
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPoint3D(conceptName: conceptName, x: 10.0, y: 20.0, z: 30.0)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.conceptName == conceptName)
    }
    
    // MARK: - 2D Spatial Coordinates Tests (inherited from Comprehensive SR)
    
    @Test("Add 2D spatial coordinates")
    func testAdd2DSpatialCoordinates() throws {
        let document = try Comprehensive3DSRBuilder()
            .addSpatialCoordinates(graphicType: .circle, graphicData: [100.0, 100.0, 120.0, 100.0])
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .scoord)
        #expect(item.asSpatialCoordinates?.graphicType == .circle)
    }
    
    // MARK: - Content Tests
    
    @Test("Add text content")
    func testAddText() throws {
        let document = try Comprehensive3DSRBuilder()
            .addText(text: "Test finding")
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .text)
        #expect(item.asText?.textValue == "Test finding")
    }
    
    @Test("Add labeled text")
    func testAddLabeledText() throws {
        let document = try Comprehensive3DSRBuilder()
            .addLabeledText(label: "Finding", text: "Normal")
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .text)
        #expect(item.conceptName?.codeMeaning == "Finding")
        #expect(item.asText?.textValue == "Normal")
    }
    
    @Test("Add numeric content")
    func testAddNumeric() throws {
        let document = try Comprehensive3DSRBuilder()
            .addNumeric(value: 25.5, units: UCUMUnit.millimeter.concept)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .num)
        #expect(item.asNumeric?.value == 25.5)
        #expect(item.asNumeric?.measurementUnits == UCUMUnit.millimeter.concept)
    }
    
    @Test("Add labeled measurement")
    func testAddMeasurement() throws {
        let document = try Comprehensive3DSRBuilder()
            .addMeasurement(label: "Diameter", value: 25.5, units: UCUMUnit.millimeter.concept)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.conceptName?.codeMeaning == "Diameter")
        #expect(item.asNumeric?.value == 25.5)
    }
    
    @Test("Add measurement in millimeters")
    func testAddMeasurementMM() throws {
        let document = try Comprehensive3DSRBuilder()
            .addMeasurementMM(label: "Length", value: 12.5)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.asNumeric?.value == 12.5)
        #expect(item.asNumeric?.measurementUnits == UCUMUnit.millimeter.concept)
    }
    
    @Test("Add measurement in centimeters")
    func testAddMeasurementCM() throws {
        let document = try Comprehensive3DSRBuilder()
            .addMeasurementCM(label: "Height", value: 5.5)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.asNumeric?.value == 5.5)
        #expect(item.asNumeric?.measurementUnits == UCUMUnit.centimeter.concept)
    }
    
    @Test("Add code content")
    func testAddCode() throws {
        let conceptName = CodedConcept(
            codeValue: "121071",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Finding"
        )
        let code = CodedConcept(
            codeValue: "F-01776",
            codingSchemeDesignator: "SRT",
            codeMeaning: "Normal"
        )
        
        let document = try Comprehensive3DSRBuilder()
            .addCode(conceptName: conceptName, code: code)
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .code)
        #expect(item.asCode?.conceptCode == code)
    }
    
    // MARK: - Section Building Tests
    
    @Test("Add section with coded concept")
    func testAddSectionWithCodedConcept() throws {
        let document = try Comprehensive3DSRBuilder()
            .addSection(CodedConcept.findings) {
                Comprehensive3DSectionContent.text("Normal findings")
            }
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.valueType == .container)
        #expect(section.conceptName == CodedConcept.findings)
        #expect(section.asContainer?.contentItems.count == 1)
    }
    
    @Test("Add section with string heading")
    func testAddSectionWithString() throws {
        let document = try Comprehensive3DSRBuilder()
            .addSection("Custom Section") {
                Comprehensive3DSectionContent.text("Content")
            }
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.valueType == .container)
        #expect(section.conceptName?.codeMeaning == "Custom Section")
    }
    
    @Test("Add section with multiple items")
    func testAddSectionWithMultipleItems() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addSection("Measurements") {
                Comprehensive3DSectionContent.text("Lesion measurements")
                Comprehensive3DSectionContent.measurement(label: "Volume", value: 125.5, units: UCUMUnit.cubicMillimeter.concept)
                Comprehensive3DSectionContent.spatialCoordinates3D(
                    graphicType: .point,
                    graphicData: [10.0, 20.0, 30.0],
                    frameOfReferenceUID: frameOfRef
                )
            }
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.asContainer?.contentItems.count == 3)
    }
    
    // MARK: - Common Section Shortcuts
    
    @Test("Add findings section")
    func testAddFindings() throws {
        let document = try Comprehensive3DSRBuilder()
            .addFindings("Normal findings")
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.findings)
    }
    
    @Test("Add impression section")
    func testAddImpression() throws {
        let document = try Comprehensive3DSRBuilder()
            .addImpression("No significant abnormalities")
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.impression)
    }
    
    @Test("Add clinical history section")
    func testAddClinicalHistory() throws {
        let document = try Comprehensive3DSRBuilder()
            .addClinicalHistory("Patient presents with chest pain")
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.clinicalHistory)
    }
    
    @Test("Add conclusion section")
    func testAddConclusion() throws {
        let document = try Comprehensive3DSRBuilder()
            .addConclusion("Normal study")
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.conclusion)
    }
    
    @Test("Add recommendation section")
    func testAddRecommendation() throws {
        let document = try Comprehensive3DSRBuilder()
            .addRecommendation("Follow-up in 6 months")
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.recommendation)
    }
    
    @Test("Add measurements section")
    func testAddMeasurements() throws {
        let document = try Comprehensive3DSRBuilder()
            .addMeasurements {
                Comprehensive3DSectionContent.numeric(value: 10.0, units: UCUMUnit.millimeter.concept)
                Comprehensive3DSectionContent.numeric(value: 20.0, units: UCUMUnit.millimeter.concept)
            }
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.conceptName == CodedConcept.measurements)
        #expect(section.asContainer?.contentItems.count == 2)
    }
    
    // MARK: - 3D ROI Definition Tests
    
    @Test("Add 3D ROI with ellipsoid")
    func testAdd3DROI() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .add3DROI(
                label: "Lesion 1",
                ellipsoidAxes: (
                    first: (
                        point1: (x: 100.0, y: 100.0, z: 50.0),
                        point2: (x: 120.0, y: 100.0, z: 50.0)
                    ),
                    second: (
                        point1: (x: 110.0, y: 90.0, z: 50.0),
                        point2: (x: 110.0, y: 110.0, z: 50.0)
                    ),
                    third: (
                        point1: (x: 110.0, y: 100.0, z: 40.0),
                        point2: (x: 110.0, y: 100.0, z: 60.0)
                    )
                )
            )
            .build()
        
        let section = document.rootContent.contentItems[0]
        #expect(section.valueType == .container)
        #expect(section.conceptName?.codeMeaning == "Lesion 1")
        
        let coords = section.asContainer?.contentItems.first
        #expect(coords?.valueType == .scoord3D)
        #expect(coords?.asSpatialCoordinates3D?.graphicType == .ellipsoid)
    }
    
    @Test("Add 3D ROI with volume measurement")
    func testAdd3DROIWithVolume() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .add3DROI(
                label: "Tumor",
                ellipsoidAxes: (
                    first: (
                        point1: (x: 100.0, y: 100.0, z: 50.0),
                        point2: (x: 120.0, y: 100.0, z: 50.0)
                    ),
                    second: (
                        point1: (x: 110.0, y: 90.0, z: 50.0),
                        point2: (x: 110.0, y: 110.0, z: 50.0)
                    ),
                    third: (
                        point1: (x: 110.0, y: 100.0, z: 40.0),
                        point2: (x: 110.0, y: 100.0, z: 60.0)
                    )
                ),
                volume: 523.6
            )
            .build()
        
        let section = document.rootContent.contentItems[0]
        let items = section.asContainer?.contentItems
        #expect(items?.count == 2)
        
        let volumeItem = items?[1]
        #expect(volumeItem?.valueType == .num)
        #expect(volumeItem?.asNumeric?.value == 523.6)
        #expect(volumeItem?.asNumeric?.measurementUnits == UCUMUnit.cubicMillimeter.concept)
    }
    
    // MARK: - Reference Content Tests
    
    @Test("Add image reference")
    func testAddImageReference() throws {
        let document = try Comprehensive3DSRBuilder()
            .addImageReference(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9"
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .image)
        #expect(item.asImage?.imageReference.sopReference.sopInstanceUID == "1.2.3.4.5.6.7.8.9")
    }
    
    @Test("Add composite reference")
    func testAddCompositeReference() throws {
        let document = try Comprehensive3DSRBuilder()
            .addCompositeReference(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
                sopInstanceUID: "1.2.3.4.5"
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .composite)
    }
    
    @Test("Add waveform reference")
    func testAddWaveformReference() throws {
        let document = try Comprehensive3DSRBuilder()
            .addWaveformReference(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.9.1.1",
                sopInstanceUID: "1.2.3.4.5.6.7.8.10"
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .waveform)
    }
    
    // MARK: - Date/Time Content Tests
    
    @Test("Add date content")
    func testAddDate() throws {
        let document = try Comprehensive3DSRBuilder()
            .addDate(date: "20240115")
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .date)
        #expect(item.asDate?.dateValue == "20240115")
    }
    
    @Test("Add time content")
    func testAddTime() throws {
        let document = try Comprehensive3DSRBuilder()
            .addTime(time: "143025")
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .time)
        #expect(item.asTime?.timeValue == "143025")
    }
    
    @Test("Add datetime content")
    func testAddDateTime() throws {
        let document = try Comprehensive3DSRBuilder()
            .addDateTime(datetime: "20240115143025")
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .datetime)
        #expect(item.asDateTime?.dateTimeValue == "20240115143025")
    }
    
    // MARK: - Temporal Coordinates Tests
    
    @Test("Add temporal coordinates")
    func testAddTemporalCoordinates() throws {
        let document = try Comprehensive3DSRBuilder()
            .addTemporalCoordinates(
                temporalRangeType: .point,
                samplePositions: [100, 200, 300]
            )
            .build()
        
        let item = document.rootContent.contentItems[0]
        #expect(item.valueType == .tcoord)
        #expect(item.asTemporalCoordinates?.temporalRangeType == .point)
    }
    
    // MARK: - Validation Tests
    
    @Test("Validation requires Frame of Reference for 3D coordinates")
    func testValidationRequiresFrameOfReference() {
        #expect(throws: Comprehensive3DSRBuilder.BuildError.missingFrameOfReferenceUID) {
            try Comprehensive3DSRBuilder()
                .addPoint3D(x: 10.0, y: 20.0, z: 30.0)  // No Frame of Reference set
                .build()
        }
    }
    
    @Test("Validation passes with Frame of Reference")
    func testValidationPassesWithFrameOfReference() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withFrameOfReferenceUID(frameOfRef)
            .addPoint3D(x: 10.0, y: 20.0, z: 30.0)
            .build()
        
        #expect(document.sopClassUID == SRDocumentType.comprehensive3DSR.sopClassUID)
    }
    
    @Test("Validation can be disabled")
    func testValidationCanBeDisabled() throws {
        // With validation disabled, should not throw even without Frame of Reference
        let document = try Comprehensive3DSRBuilder(validateOnBuild: false)
            .addPoint3D(x: 10.0, y: 20.0, z: 30.0)  // No Frame of Reference set
            .build()
        
        #expect(document.sopClassUID == SRDocumentType.comprehensive3DSR.sopClassUID)
    }
    
    // MARK: - Integration Tests
    
    @Test("Build complete 3D measurement report")
    func testCompleteReport() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withPatientID("PAT12345")
            .withPatientName("Doe^John")
            .withPatientBirthDate("19800101")
            .withPatientSex("M")
            .withStudyInstanceUID("1.2.840.113619.2.1.1.1.1")
            .withStudyDate("20240115")
            .withStudyTime("143025")
            .withSeriesInstanceUID("1.2.840.113619.2.1.1.1.2")
            .withSeriesNumber("1")
            .withDocumentTitle("3D Lesion Analysis")
            .withFrameOfReferenceUID(frameOfRef)
            .withCompletionFlag(.complete)
            .withVerificationFlag(.verified)
            .addClinicalHistory("Patient with suspected liver lesion")
            .addSection("Findings") {
                Comprehensive3DSectionContent.text("Focal lesion identified in liver segment VII")
                Comprehensive3DSectionContent.measurement(label: "Maximum Diameter", value: 25.5, units: UCUMUnit.millimeter.concept)
                Comprehensive3DSectionContent.measurement(label: "Volume", value: 8654.3, units: UCUMUnit.cubicMillimeter.concept)
                Comprehensive3DSectionContent.spatialCoordinates3D(
                    conceptName: CodedConcept(
                        codeValue: "111030",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Image Region"
                    ),
                    graphicType: .ellipsoid,
                    graphicData: [
                        100.0, 100.0, 50.0,
                        120.0, 100.0, 50.0,
                        110.0, 110.0, 50.0,
                        110.0, 90.0, 50.0,
                        110.0, 100.0, 60.0,
                        110.0, 100.0, 40.0
                    ],
                    frameOfReferenceUID: frameOfRef
                )
            }
            .addImpression("Focal liver lesion compatible with hemangioma")
            .addRecommendation("Follow-up MRI in 6 months")
            .build()
        
        // Verify document structure
        #expect(document.sopClassUID == SRDocumentType.comprehensive3DSR.sopClassUID)
        #expect(document.patientID == "PAT12345")
        #expect(document.patientName == "Doe^John")
        #expect(document.completionFlag == .complete)
        #expect(document.verificationFlag == .verified)
        
        // Verify sections
        #expect(document.rootContent.contentItems.count == 4)
        
        // Verify findings section
        let findingsSection = document.rootContent.contentItems[1]
        #expect(findingsSection.valueType == .container)
        #expect(findingsSection.conceptName == CodedConcept.findings)
        #expect(findingsSection.asContainer?.contentItems.count == 4)
        
        // Verify 3D coordinates
        let coordsItem = findingsSection.asContainer?.contentItems[3]
        #expect(coordsItem?.valueType == .scoord3D)
        #expect(coordsItem?.asSpatialCoordinates3D?.graphicType == .ellipsoid)
        #expect(coordsItem?.asSpatialCoordinates3D?.pointCount == 6)
        #expect(coordsItem?.asSpatialCoordinates3D?.frameOfReferenceUID == frameOfRef)
    }
    
    @Test("Build report with multiple 3D ROIs")
    func testMultiple3DROIs() throws {
        let frameOfRef = "1.2.840.10008.5.1.4.1.1.88.34.1"
        
        let document = try Comprehensive3DSRBuilder()
            .withDocumentTitle("Multi-Lesion Analysis")
            .withFrameOfReferenceUID(frameOfRef)
            .add3DROI(
                label: "Lesion 1",
                ellipsoidAxes: (
                    first: ((x: 100.0, y: 100.0, z: 50.0), (x: 120.0, y: 100.0, z: 50.0)),
                    second: ((x: 110.0, y: 90.0, z: 50.0), (x: 110.0, y: 110.0, z: 50.0)),
                    third: ((x: 110.0, y: 100.0, z: 40.0), (x: 110.0, y: 100.0, z: 60.0))
                ),
                volume: 523.6
            )
            .add3DROI(
                label: "Lesion 2",
                ellipsoidAxes: (
                    first: ((x: 200.0, y: 200.0, z: 80.0), (x: 215.0, y: 200.0, z: 80.0)),
                    second: ((x: 207.5, y: 192.0, z: 80.0), (x: 207.5, y: 208.0, z: 80.0)),
                    third: ((x: 207.5, y: 200.0, z: 72.0), (x: 207.5, y: 200.0, z: 88.0))
                ),
                volume: 314.2
            )
            .build()
        
        #expect(document.rootContent.contentItems.count == 2)
        
        // Verify first ROI
        let roi1 = document.rootContent.contentItems[0]
        #expect(roi1.conceptName?.codeMeaning == "Lesion 1")
        #expect(roi1.asContainer?.contentItems.count == 2)
        
        // Verify second ROI
        let roi2 = document.rootContent.contentItems[1]
        #expect(roi2.conceptName?.codeMeaning == "Lesion 2")
        #expect(roi2.asContainer?.contentItems.count == 2)
    }
}
