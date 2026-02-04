import Testing
import Foundation
import DICOMCore
@testable import DICOMKit

// MARK: - MeasurementReportBuilder Tests

@Suite("MeasurementReportBuilder Tests")
struct MeasurementReportBuilderTests {
    
    // MARK: - Basic Builder Tests
    
    @Test("Builder initialization with default values")
    func testBuilderInitialization() {
        let builder = MeasurementReportBuilder()
        
        #expect(builder.validateOnBuild == true)
        #expect(builder.completionFlag == .partial)
        #expect(builder.verificationFlag == .unverified)
        #expect(builder.imageLibraryEntries.isEmpty)
        #expect(builder.measurementGroups.isEmpty)
    }
    
    @Test("Builder initialization with validation disabled")
    func testBuilderWithValidationDisabled() {
        let builder = MeasurementReportBuilder(validateOnBuild: false)
        #expect(builder.validateOnBuild == false)
    }
    
    @Test("Build minimal document")
    func testBuildMinimalDocument() throws {
        let document = try MeasurementReportBuilder()
            .build()
        
        #expect(!document.sopInstanceUID.isEmpty)
        #expect(document.sopClassUID == SRDocumentType.comprehensiveSR.sopClassUID)
        #expect(document.modality == "SR")
        // Default title should be Imaging Measurement Report
        #expect(document.documentTitle?.codeValue == "126000")
    }
    
    // MARK: - Document Identification Tests
    
    @Test("Set SOP Instance UID")
    func testSetSOPInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.9"
        let document = try MeasurementReportBuilder()
            .withSOPInstanceUID(uid)
            .build()
        
        #expect(document.sopInstanceUID == uid)
    }
    
    @Test("Set Study Instance UID")
    func testSetStudyInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.10"
        let document = try MeasurementReportBuilder()
            .withStudyInstanceUID(uid)
            .build()
        
        #expect(document.studyInstanceUID == uid)
    }
    
    @Test("Set Series Instance UID")
    func testSetSeriesInstanceUID() throws {
        let uid = "1.2.3.4.5.6.7.8.11"
        let document = try MeasurementReportBuilder()
            .withSeriesInstanceUID(uid)
            .build()
        
        #expect(document.seriesInstanceUID == uid)
    }
    
    @Test("Set Instance Number")
    func testSetInstanceNumber() {
        let builder = MeasurementReportBuilder()
            .withInstanceNumber("5")
        
        #expect(builder.instanceNumber == "5")
    }
    
    // MARK: - Patient Information Tests
    
    @Test("Set Patient ID")
    func testSetPatientID() throws {
        let document = try MeasurementReportBuilder()
            .withPatientID("PAT123")
            .build()
        
        #expect(document.patientID == "PAT123")
    }
    
    @Test("Set Patient Name")
    func testSetPatientName() throws {
        let document = try MeasurementReportBuilder()
            .withPatientName("Doe^John")
            .build()
        
        #expect(document.patientName == "Doe^John")
    }
    
    @Test("Set Patient Birth Date")
    func testSetPatientBirthDate() {
        let builder = MeasurementReportBuilder()
            .withPatientBirthDate("19800101")
        
        #expect(builder.patientBirthDate == "19800101")
    }
    
    @Test("Set Patient Sex")
    func testSetPatientSex() {
        let builder = MeasurementReportBuilder()
            .withPatientSex("M")
        
        #expect(builder.patientSex == "M")
    }
    
    // MARK: - Study Information Tests
    
    @Test("Set Study Date")
    func testSetStudyDate() throws {
        let document = try MeasurementReportBuilder()
            .withStudyDate("20240115")
            .build()
        
        #expect(document.studyDate == "20240115")
    }
    
    @Test("Set Study Time")
    func testSetStudyTime() throws {
        let document = try MeasurementReportBuilder()
            .withStudyTime("143025")
            .build()
        
        #expect(document.studyTime == "143025")
    }
    
    @Test("Set Study Description")
    func testSetStudyDescription() {
        let builder = MeasurementReportBuilder()
            .withStudyDescription("CT Chest")
        
        #expect(builder.studyDescription == "CT Chest")
    }
    
    @Test("Set Accession Number")
    func testSetAccessionNumber() throws {
        let document = try MeasurementReportBuilder()
            .withAccessionNumber("ACC123")
            .build()
        
        #expect(document.accessionNumber == "ACC123")
    }
    
    // MARK: - Document Title Tests
    
    @Test("Set document title with coded concept")
    func testSetDocumentTitleCoded() throws {
        let title = MeasurementReportDocumentTitle.lesionMeasurementReport
        let document = try MeasurementReportBuilder()
            .withDocumentTitle(title)
            .build()
        
        #expect(document.documentTitle?.codeValue == "126002")
        #expect(document.documentTitle?.codeMeaning == "Lesion Measurement Report")
    }
    
    @Test("Set imaging measurement report title convenience")
    func testSetImagingMeasurementReportTitle() throws {
        let document = try MeasurementReportBuilder()
            .withImagingMeasurementReportTitle()
            .build()
        
        #expect(document.documentTitle?.codeValue == "126000")
        #expect(document.documentTitle?.codingSchemeDesignator == "DCM")
    }
    
    // MARK: - Document Status Tests
    
    @Test("Set completion flag to complete")
    func testSetCompletionFlag() throws {
        let document = try MeasurementReportBuilder()
            .withCompletionFlag(.complete)
            .build()
        
        #expect(document.completionFlag == .complete)
    }
    
    @Test("Set verification flag to verified")
    func testSetVerificationFlag() throws {
        let document = try MeasurementReportBuilder()
            .withVerificationFlag(.verified)
            .build()
        
        #expect(document.verificationFlag == .verified)
    }
    
    @Test("Set preliminary flag")
    func testSetPreliminaryFlag() {
        let builder = MeasurementReportBuilder()
            .withPreliminaryFlag(.preliminary)
        
        #expect(builder.preliminaryFlag == .preliminary)
    }
    
    // MARK: - Image Library Tests
    
    @Test("Add image library entry")
    func testAddImageLibraryEntry() throws {
        let document = try MeasurementReportBuilder()
            .addImageLibraryEntry(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9"
            )
            .build()
        
        // Verify the document has an image library container
        let imageLibraryContainer = document.rootContent.contentItems.first { item in
            item.asContainer?.conceptName?.codeValue == "111028"
        }
        #expect(imageLibraryContainer != nil)
    }
    
    @Test("Add image library entry with modality")
    func testAddImageLibraryEntryWithModality() {
        let modality = CodedConcept(
            codeValue: "CT",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Computed Tomography"
        )
        
        let builder = MeasurementReportBuilder()
            .addImageLibraryEntry(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9",
                modality: modality
            )
        
        #expect(builder.imageLibraryEntries.count == 1)
        #expect(builder.imageLibraryEntries[0].modality?.codeValue == "CT")
    }
    
    @Test("Add multiple image library entries")
    func testAddMultipleImageLibraryEntries() throws {
        let entries = [
            ImageLibraryEntry(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9"
            ),
            ImageLibraryEntry(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.10"
            )
        ]
        
        let builder = MeasurementReportBuilder()
            .addImageLibraryEntries(entries)
        
        #expect(builder.imageLibraryEntries.count == 2)
    }
    
    // MARK: - Measurement Group Tests
    
    @Test("Add measurement group with tracking")
    func testAddMeasurementGroupWithTracking() throws {
        let document = try MeasurementReportBuilder()
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 1",
                trackingUID: "1.2.3.4.5.6.7.8.100"
            ) {
                MeasurementGroupContent.measurement(
                    conceptName: CodedConcept(
                        codeValue: "410668003",
                        codingSchemeDesignator: "SCT",
                        codeMeaning: "Length"
                    ),
                    value: 25.5,
                    units: UCUMUnit.millimeter.concept
                )
            }
            .build()
        
        // Verify imaging measurements container exists
        let imagingMeasurements = document.rootContent.contentItems.first { item in
            item.asContainer?.conceptName?.codeValue == "126010"
        }
        #expect(imagingMeasurements != nil)
    }
    
    @Test("Add measurement group with auto-generated UID")
    func testAddMeasurementGroupAutoUID() {
        let builder = MeasurementReportBuilder()
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 2"
            ) {
                MeasurementGroupContentHelper.lengthMM(value: 15.0)
            }
        
        #expect(builder.measurementGroups.count == 1)
        #expect(builder.measurementGroups[0].trackingIdentifier == "Lesion 2")
        #expect(!builder.measurementGroups[0].trackingUID.isEmpty)
    }
    
    @Test("Add measurement group with finding")
    func testAddMeasurementGroupWithFinding() {
        let finding = CodedConcept(
            codeValue: "4147007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Mass"
        )
        
        let group = MeasurementGroupData(
            trackingIdentifier: "Mass 1",
            trackingUID: "1.2.3.4.5.6.7.8.200",
            finding: finding
        )
        
        let builder = MeasurementReportBuilder()
            .addMeasurementGroup(group)
        
        #expect(builder.measurementGroups.count == 1)
        #expect(builder.measurementGroups[0].finding?.codeValue == "4147007")
    }
    
    // MARK: - Measurement Group Content Tests
    
    @Test("Measurement group content - length measurement")
    func testMeasurementGroupContentLength() {
        let content = MeasurementGroupContentHelper.lengthMM(value: 10.5)
        let item = content.toContentItem()
        
        #expect(item.valueType == .num)
    }
    
    @Test("Measurement group content - long axis measurement")
    func testMeasurementGroupContentLongAxis() {
        let content = MeasurementGroupContentHelper.longAxisMM(value: 25.0)
        _ = content.toContentItem()
        
        if case .measurement(let conceptName, let value, let units) = content {
            #expect(conceptName?.codeValue == "103339001")
            #expect(value == 25.0)
            #expect(units?.codeValue == "mm")
        } else {
            Issue.record("Expected measurement case")
        }
    }
    
    @Test("Measurement group content - short axis measurement")
    func testMeasurementGroupContentShortAxis() {
        let content = MeasurementGroupContentHelper.shortAxisMM(value: 15.0)
        
        if case .measurement(let conceptName, let value, _) = content {
            #expect(conceptName?.codeValue == "103340004")
            #expect(value == 15.0)
        } else {
            Issue.record("Expected measurement case")
        }
    }
    
    @Test("Measurement group content - area measurement")
    func testMeasurementGroupContentArea() {
        let content = MeasurementGroupContentHelper.areaMM2(value: 100.0)
        
        if case .measurement(let conceptName, let value, let units) = content {
            #expect(conceptName?.codeValue == "42798000")
            #expect(value == 100.0)
            #expect(units?.codeValue == "mm2")
        } else {
            Issue.record("Expected measurement case")
        }
    }
    
    @Test("Measurement group content - volume measurement")
    func testMeasurementGroupContentVolume() {
        let content = MeasurementGroupContentHelper.volumeMM3(value: 1000.0)
        
        if case .measurement(let conceptName, let value, _) = content {
            #expect(conceptName?.codeValue == "118565006")
            #expect(value == 1000.0)
        } else {
            Issue.record("Expected measurement case")
        }
    }
    
    @Test("Measurement group content - image reference")
    func testMeasurementGroupContentImageReference() {
        let content = MeasurementGroupContentHelper.imageReference(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
        let item = content.toContentItem()
        
        #expect(item.valueType == .image)
    }
    
    @Test("Measurement group content - spatial coordinates")
    func testMeasurementGroupContentCoordinates() {
        let content = MeasurementGroupContentHelper.coordinates(
            graphicType: .circle,
            graphicData: [100.0, 100.0, 120.0, 100.0]
        )
        let item = content.toContentItem()
        
        #expect(item.valueType == .scoord)
    }
    
    // MARK: - Qualitative Evaluation Tests
    
    @Test("Add qualitative evaluation")
    func testAddQualitativeEvaluation() {
        let evaluation = CodedConcept(
            codeValue: "260415000",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Not detected"
        )
        
        let builder = MeasurementReportBuilder()
            .addQualitativeEvaluation(
                conceptName: CodedConcept(
                    codeValue: "121071",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Finding"
                ),
                value: evaluation
            )
        
        #expect(builder.qualitativeEvaluations.count == 1)
    }
    
    // MARK: - Procedure Reported Tests
    
    @Test("Add procedure reported")
    func testAddProcedureReported() {
        let procedure = CodedConcept(
            codeValue: "77477000",
            codingSchemeDesignator: "SCT",
            codeMeaning: "CT of abdomen"
        )
        
        let builder = MeasurementReportBuilder()
            .addProcedureReported(procedure)
        
        #expect(builder.proceduresReported.count == 1)
        #expect(builder.proceduresReported[0].codeValue == "77477000")
    }
    
    // MARK: - Language Tests
    
    @Test("Set language of content")
    func testSetLanguage() {
        let language = CodedConcept(
            codeValue: "en",
            codingSchemeDesignator: "RFC5646",
            codeMeaning: "English"
        )
        
        let builder = MeasurementReportBuilder()
            .withLanguage(language)
        
        #expect(builder.languageOfContent?.codeValue == "en")
    }
    
    @Test("Set language with country")
    func testSetLanguageWithCountry() {
        let language = CodedConcept(
            codeValue: "en",
            codingSchemeDesignator: "RFC5646",
            codeMeaning: "English"
        )
        let country = CodedConcept(
            codeValue: "US",
            codingSchemeDesignator: "ISO3166_1",
            codeMeaning: "United States"
        )
        
        let builder = MeasurementReportBuilder()
            .withLanguage(language, country: country)
        
        #expect(builder.languageOfContent?.codeValue == "en")
        #expect(builder.countryOfLanguage?.codeValue == "US")
    }
    
    // MARK: - Validation Tests
    
    @Test("Validation passes with valid tracking")
    func testValidationPassesWithValidTracking() throws {
        // Should not throw
        _ = try MeasurementReportBuilder()
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 1",
                trackingUID: "1.2.3.4.5.6.7.8.100"
            ) {
                MeasurementGroupContentHelper.lengthMM(value: 10.0)
            }
            .build()
    }
    
    @Test("Validation fails with empty tracking identifier")
    func testValidationFailsEmptyTrackingIdentifier() {
        let group = MeasurementGroupData(
            trackingIdentifier: "",
            trackingUID: "1.2.3.4.5.6.7.8.100"
        )
        
        let builder = MeasurementReportBuilder()
            .addMeasurementGroup(group)
        
        #expect(throws: MeasurementReportBuilder.BuildError.missingTrackingIdentifier) {
            try builder.build()
        }
    }
    
    @Test("Validation fails with empty tracking UID")
    func testValidationFailsEmptyTrackingUID() {
        let group = MeasurementGroupData(
            trackingIdentifier: "Lesion 1",
            trackingUID: ""
        )
        
        let builder = MeasurementReportBuilder()
            .addMeasurementGroup(group)
        
        #expect(throws: MeasurementReportBuilder.BuildError.missingTrackingUID) {
            try builder.build()
        }
    }
    
    @Test("Validation disabled allows empty tracking")
    func testValidationDisabledAllowsEmptyTracking() throws {
        let group = MeasurementGroupData(
            trackingIdentifier: "",
            trackingUID: ""
        )
        
        // Should not throw when validation is disabled
        _ = try MeasurementReportBuilder(validateOnBuild: false)
            .addMeasurementGroup(group)
            .build()
    }
    
    // MARK: - Complete Report Tests
    
    @Test("Build complete measurement report")
    func testBuildCompleteMeasurementReport() throws {
        let document = try MeasurementReportBuilder()
            .withPatientID("12345")
            .withPatientName("Doe^John")
            .withStudyDate("20240115")
            .withAccessionNumber("ACC001")
            .withImagingMeasurementReportTitle()
            .withCompletionFlag(.complete)
            .withVerificationFlag(.verified)
            .addImageLibraryEntry(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9",
                modality: CodedConcept(
                    codeValue: "CT",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Computed Tomography"
                )
            )
            .addMeasurementGroup(
                trackingIdentifier: "Liver Lesion",
                trackingUID: "1.2.3.4.5.6.7.8.100"
            ) {
                MeasurementGroupContentHelper.longAxisMM(value: 25.5)
                MeasurementGroupContentHelper.shortAxisMM(value: 18.2)
                MeasurementGroupContentHelper.areaMM2(value: 363.15)
                MeasurementGroupContentHelper.imageReference(
                    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                    sopInstanceUID: "1.2.3.4.5.6.7.8.9",
                    frameNumbers: [1]
                )
            }
            .build()
        
        #expect(document.patientID == "12345")
        #expect(document.patientName == "Doe^John")
        #expect(document.studyDate == "20240115")
        #expect(document.accessionNumber == "ACC001")
        #expect(document.completionFlag == .complete)
        #expect(document.verificationFlag == .verified)
        #expect(document.documentTitle?.codeValue == "126000")
        
        // Check that image library exists
        let hasImageLibrary = document.rootContent.contentItems.contains { item in
            item.asContainer?.conceptName?.codeValue == "111028"
        }
        #expect(hasImageLibrary)
        
        // Check that imaging measurements exists
        let hasImagingMeasurements = document.rootContent.contentItems.contains { item in
            item.asContainer?.conceptName?.codeValue == "126010"
        }
        #expect(hasImagingMeasurements)
    }
    
    @Test("Build report with multiple measurement groups")
    func testBuildReportWithMultipleMeasurementGroups() throws {
        let document = try MeasurementReportBuilder()
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 1",
                trackingUID: "1.2.3.4.5.6.7.8.100"
            ) {
                MeasurementGroupContentHelper.longAxisMM(value: 20.0)
            }
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 2",
                trackingUID: "1.2.3.4.5.6.7.8.101"
            ) {
                MeasurementGroupContentHelper.longAxisMM(value: 15.0)
            }
            .addMeasurementGroup(
                trackingIdentifier: "Lesion 3",
                trackingUID: "1.2.3.4.5.6.7.8.102"
            ) {
                MeasurementGroupContentHelper.longAxisMM(value: 10.0)
            }
            .build()
        
        // Count measurement groups in the imaging measurements container
        let imagingMeasurements = document.rootContent.contentItems.first { item in
            item.asContainer?.conceptName?.codeValue == "126010"
        }
        let measurementGroupCount = imagingMeasurements?.asContainer?.contentItems.filter { item in
            item.asContainer?.conceptName?.codeValue == "125007"
        }.count ?? 0
        
        #expect(measurementGroupCount == 3)
    }
}

// MARK: - MeasurementReportDocumentTitle Tests

@Suite("MeasurementReportDocumentTitle Tests")
struct MeasurementReportDocumentTitleTests {
    
    @Test("Imaging Measurement Report title")
    func testImagingMeasurementReportTitle() {
        let title = MeasurementReportDocumentTitle.imagingMeasurementReport
        #expect(title.codeValue == "126000")
        #expect(title.codingSchemeDesignator == "DCM")
    }
    
    @Test("Lesion Measurement Report title")
    func testLesionMeasurementReportTitle() {
        let title = MeasurementReportDocumentTitle.lesionMeasurementReport
        #expect(title.codeValue == "126002")
    }
    
    @Test("CT Perfusion Report title")
    func testCTPerfusionReportTitle() {
        let title = MeasurementReportDocumentTitle.ctPerfusionReport
        #expect(title.codeValue == "126003")
    }
    
    @Test("PET Measurement Report title")
    func testPETMeasurementReportTitle() {
        let title = MeasurementReportDocumentTitle.petMeasurementReport
        #expect(title.codeValue == "126010")
    }
}

// MARK: - ImageLibraryEntry Tests

@Suite("ImageLibraryEntry Tests")
struct ImageLibraryEntryTests {
    
    @Test("Create basic entry")
    func testCreateBasicEntry() {
        let entry = ImageLibraryEntry(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9"
        )
        
        #expect(entry.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(entry.sopInstanceUID == "1.2.3.4.5.6.7.8.9")
        #expect(entry.frameNumbers == nil)
        #expect(entry.modality == nil)
    }
    
    @Test("Create entry with all attributes")
    func testCreateEntryWithAllAttributes() {
        let modality = CodedConcept(
            codeValue: "CT",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Computed Tomography"
        )
        let targetRegion = CodedConcept(
            codeValue: "818981001",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Abdomen"
        )
        let laterality = CodedConcept(
            codeValue: "24028007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Right"
        )
        
        let entry = ImageLibraryEntry(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            frameNumbers: [1, 2, 3],
            modality: modality,
            targetRegion: targetRegion,
            laterality: laterality
        )
        
        #expect(entry.frameNumbers == [1, 2, 3])
        #expect(entry.modality?.codeValue == "CT")
        #expect(entry.targetRegion?.codeValue == "818981001")
        #expect(entry.laterality?.codeValue == "24028007")
    }
}

// MARK: - MeasurementGroupData Tests

@Suite("MeasurementGroupData Tests")
struct MeasurementGroupDataTests {
    
    @Test("Create basic measurement group")
    func testCreateBasicGroup() {
        let group = MeasurementGroupData(
            trackingIdentifier: "Lesion 1",
            trackingUID: "1.2.3.4.5.6.7.8.100"
        )
        
        #expect(group.trackingIdentifier == "Lesion 1")
        #expect(group.trackingUID == "1.2.3.4.5.6.7.8.100")
        #expect(group.contents.isEmpty)
    }
    
    @Test("Create measurement group with all attributes")
    func testCreateGroupWithAllAttributes() {
        let finding = CodedConcept(
            codeValue: "4147007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Mass"
        )
        let findingSite = CodedConcept(
            codeValue: "10200004",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Liver"
        )
        let laterality = CodedConcept(
            codeValue: "24028007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Right"
        )
        
        let group = MeasurementGroupData(
            trackingIdentifier: "Liver Lesion",
            trackingUID: "1.2.3.4.5.6.7.8.100",
            activitySession: "Session1",
            timePoint: "Baseline",
            finding: finding,
            findingSite: findingSite,
            laterality: laterality,
            contents: [
                .measurement(
                    conceptName: nil,
                    value: 25.0,
                    units: UCUMUnit.millimeter.concept
                )
            ]
        )
        
        #expect(group.activitySession == "Session1")
        #expect(group.timePoint == "Baseline")
        #expect(group.finding?.codeValue == "4147007")
        #expect(group.findingSite?.codeValue == "10200004")
        #expect(group.laterality?.codeValue == "24028007")
        #expect(group.contents.count == 1)
    }
}

// MARK: - TID Template Tests

@Suite("TID 1500/1501/1600 Template Definition Tests")
struct TIDTemplateDefinitionTests {
    
    @Test("TID 1500 identifier")
    func testTID1500Identifier() {
        #expect(TID1500MeasurementReport.identifier.templateID == "1500")
        #expect(TID1500MeasurementReport.displayName == "Measurement Report")
    }
    
    @Test("TID 1501 identifier")
    func testTID1501Identifier() {
        #expect(TID1501MeasurementGroup.identifier.templateID == "1501")
        #expect(TID1501MeasurementGroup.displayName == "Measurement Group")
    }
    
    @Test("TID 1600 identifier")
    func testTID1600Identifier() {
        #expect(TID1600ImageLibrary.identifier.templateID == "1600")
        #expect(TID1600ImageLibrary.displayName == "Image Library")
    }
    
    @Test("TID 1500 has rows defined")
    func testTID1500HasRows() {
        #expect(!TID1500MeasurementReport.rows.isEmpty)
    }
    
    @Test("TID 1501 has rows defined")
    func testTID1501HasRows() {
        #expect(!TID1501MeasurementGroup.rows.isEmpty)
    }
    
    @Test("TID 1600 has rows defined")
    func testTID1600HasRows() {
        #expect(!TID1600ImageLibrary.rows.isEmpty)
    }
    
    @Test("Templates are registered in registry")
    func testTemplatesRegistered() {
        let registry = TemplateRegistry.shared
        
        #expect(registry.template(tid: 1500) != nil)
        #expect(registry.template(tid: 1501) != nil)
        #expect(registry.template(tid: 1600) != nil)
    }
    
    @Test("TID 1500 is extensible")
    func testTID1500IsExtensible() {
        #expect(TID1500MeasurementReport.isExtensible == true)
    }
    
    @Test("TID 1500 root value type is container")
    func testTID1500RootValueType() {
        #expect(TID1500MeasurementReport.rootValueType == .container)
    }
}
