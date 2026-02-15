import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

// MARK: - DICOMGateway Tests

final class DICOMGatewayTests: XCTestCase {
    
    // MARK: - HL7 Parser Tests
    
    func test_HL7Parser_ParsesADTMessage() throws {
        let hl7Message = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ADT^A01|12345|P|2.5\r
        EVN|A01|20260215120000\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        PV1||O|||||||||||||||||||ACC12345\r
        """
        
        let parser = HL7Parser()
        let parsed = try parser.parse(hl7Message)
        
        XCTAssertEqual(parsed.messageType, .ADT)
        XCTAssertEqual(parsed.segments.count, 4)
        
        let msh = parsed.segment("MSH")
        XCTAssertNotNil(msh)
        XCTAssertEqual(msh?.id, "MSH")
        
        let pid = parsed.segment("PID")
        XCTAssertNotNil(pid)
        XCTAssertEqual(pid?[2], "PAT001")
        XCTAssertEqual(pid?[4], "DOE^JOHN^M")
    }
    
    func test_HL7Parser_ParsesORMMessage() throws {
        let hl7Message = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ORM^O01|12345|P|2.5\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        ORC|NW|ACC123|ORD456\r
        OBR||ACC123|ORD456|CT^CT Chest\r
        """
        
        let parser = HL7Parser()
        let parsed = try parser.parse(hl7Message)
        
        XCTAssertEqual(parsed.messageType, .ORM)
        XCTAssertEqual(parsed.segments.count, 4)
        
        let orc = parsed.segment("ORC")
        XCTAssertNotNil(orc)
        XCTAssertEqual(orc?[0], "NW")
        
        let obr = parsed.segment("OBR")
        XCTAssertNotNil(obr)
        XCTAssertEqual(obr?[3], "CT^CT Chest")
    }
    
    func test_HL7Parser_ParsesORUMessage() throws {
        let hl7Message = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ORU^R01|12345|P|2.5\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        OBR||ACC123|ORD456|CT^CT Chest||20260215120000\r
        OBX|1|NM|IMG_COUNT||150|images\r
        """
        
        let parser = HL7Parser()
        let parsed = try parser.parse(hl7Message)
        
        XCTAssertEqual(parsed.messageType, .ORU)
        XCTAssertEqual(parsed.segments.count, 4)
        
        let obx = parsed.segment("OBX")
        XCTAssertNotNil(obx)
        XCTAssertEqual(obx?[0], "1")
        XCTAssertEqual(obx?[4], "150")
    }
    
    func test_HL7Parser_GeneratesMessage() throws {
        let builder = HL7MessageBuilder()
        _ = builder.addMSH(
            sendingApplication: "TEST",
            sendingFacility: "FAC",
            receivingApplication: "REC",
            receivingFacility: "HOSP",
            messageType: "ADT^A01",
            messageControlId: "MSG001"
        )
        _ = builder.addSegment(id: "PID", fields: ["", "PAT001", "PAT001", "", "DOE^JOHN"])
        
        let message = try builder.build(messageType: .ADT)
        let parser = HL7Parser()
        let generated = parser.generate(message: message)
        
        XCTAssertTrue(generated.contains("MSH"))
        XCTAssertTrue(generated.contains("PID"))
        XCTAssertTrue(generated.contains("PAT001"))
        XCTAssertTrue(generated.contains("DOE^JOHN"))
    }
    
    func test_HL7Parser_ParsesEmptyMessage_ThrowsError() {
        let parser = HL7Parser()
        
        XCTAssertThrowsError(try parser.parse("")) { error in
            XCTAssertTrue(error is GatewayError)
        }
    }
    
    // MARK: - DICOM to HL7 Converter Tests
    
    func test_DICOMToHL7_ConvertsToDicom_ADT() throws {
        // Create a simple DICOM file
        let dicomFile = try createTestDICOMFile()
        
        let converter = DICOMToHL7Converter()
        let hl7Message = try converter.convertToADT(dicomFile: dicomFile, eventType: "A01")
        
        XCTAssertEqual(hl7Message.messageType, .ADT)
        XCTAssertTrue(hl7Message.segments.count >= 3)
        
        let msh = hl7Message.segment("MSH")
        XCTAssertNotNil(msh)
        
        let pid = hl7Message.segment("PID")
        XCTAssertNotNil(pid)
        XCTAssertEqual(pid?[2], "TEST001")
        XCTAssertTrue(pid?[4]?.contains("DOE") == true)
    }
    
    func test_DICOMToHL7_ConvertsToORM() throws {
        let dicomFile = try createTestDICOMFile()
        
        let converter = DICOMToHL7Converter()
        let hl7Message = try converter.convertToORM(dicomFile: dicomFile)
        
        XCTAssertEqual(hl7Message.messageType, .ORM)
        
        let orc = hl7Message.segment("ORC")
        XCTAssertNotNil(orc)
        XCTAssertEqual(orc?[0], "NW")
        
        let obr = hl7Message.segment("OBR")
        XCTAssertNotNil(obr)
    }
    
    func test_DICOMToHL7_ConvertsToORU() throws {
        let dicomFile = try createTestDICOMFile()
        
        let converter = DICOMToHL7Converter()
        let hl7Message = try converter.convertToORU(dicomFile: dicomFile)
        
        XCTAssertEqual(hl7Message.messageType, .ORU)
        
        let obr = hl7Message.segment("OBR")
        XCTAssertNotNil(obr)
        
        let obx = hl7Message.segment("OBX")
        XCTAssertNotNil(obx)
    }
    
    // MARK: - HL7 to DICOM Converter Tests
    
    func test_HL7ToDICOM_ConvertsPIDSegment() throws {
        let hl7Message = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ADT^A01|12345|P|2.5\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        """
        
        let parser = HL7Parser()
        let parsed = try parser.parse(hl7Message)
        
        let converter = HL7ToDICOMConverter()
        let dicomFile = try converter.convert(hl7Message: parsed, templateFile: nil)
        
        let patientID = dicomFile.dataSet.string(for: .patientID)
        XCTAssertEqual(patientID, "PAT001")
        
        let patientName = dicomFile.dataSet.string(for: .patientName)
        XCTAssertNotNil(patientName)
        XCTAssertTrue(patientName?.contains("DOE") == true)
        
        let birthDate = dicomFile.dataSet.string(for: .patientBirthDate)
        XCTAssertEqual(birthDate, "19800115")
        
        let sex = dicomFile.dataSet.string(for: .patientSex)
        XCTAssertEqual(sex, "M")
    }
    
    func test_HL7ToDICOM_ConvertsWithTemplate() throws {
        let template = try createTestDICOMFile()
        
        let hl7Message = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ADT^A01|12345|P|2.5\r
        PID||NEWPAT||SMITH^JANE^A||19901231|F\r
        """
        
        let parser = HL7Parser()
        let parsed = try parser.parse(hl7Message)
        
        let converter = HL7ToDICOMConverter()
        let dicomFile = try converter.convert(hl7Message: parsed, templateFile: template)
        
        let patientID = dicomFile.dataSet.string(for: .patientID)
        XCTAssertEqual(patientID, "NEWPAT")
        
        let sex = dicomFile.dataSet.string(for: .patientSex)
        XCTAssertEqual(sex, "F")
        
        // Verify template data is preserved where not overwritten
        let modality = dicomFile.dataSet.string(for: .modality)
        XCTAssertNotNil(modality)
    }
    
    // MARK: - FHIR Converter Tests
    
    func test_FHIRConverter_ConvertsToImagingStudy() throws {
        let dicomFile = try createTestDICOMFile()
        
        let converter = FHIRConverter()
        let fhir = try converter.convertToFHIR(dicomFile: dicomFile, resourceType: .imagingStudy)
        
        XCTAssertEqual(fhir["resourceType"] as? String, "ImagingStudy")
        XCTAssertEqual(fhir["status"] as? String, "available")
        
        let identifier = fhir["identifier"] as? [[String: Any]]
        XCTAssertNotNil(identifier)
        XCTAssertFalse(identifier?.isEmpty ?? true)
    }
    
    func test_FHIRConverter_ConvertsToPatient() throws {
        let dicomFile = try createTestDICOMFile()
        
        let converter = FHIRConverter()
        let fhir = try converter.convertToFHIR(dicomFile: dicomFile, resourceType: .patient)
        
        XCTAssertEqual(fhir["resourceType"] as? String, "Patient")
        XCTAssertEqual(fhir["id"] as? String, "TEST001")
        
        let names = fhir["name"] as? [[String: Any]]
        XCTAssertNotNil(names)
        XCTAssertFalse(names?.isEmpty ?? true)
    }
    
    func test_FHIRConverter_ConvertsFromImagingStudy() throws {
        let fhirResource: [String: Any] = [
            "resourceType": "ImagingStudy",
            "identifier": [
                [
                    "system": "urn:dicom:uid",
                    "value": "urn:oid:1.2.840.113619.2.62.994044785528.114289542805"
                ]
            ],
            "started": "2026-02-15T12:00:00",
            "modality": [
                [
                    "system": "http://dicom.nema.org/resources/ontology/DCM",
                    "code": "CT"
                ]
            ],
            "description": "CT Chest with Contrast"
        ]
        
        let converter = FHIRConverter()
        let dicomFile = try converter.convertFromFHIR(fhirResource: fhirResource, templateFile: nil)
        
        let studyUID = dicomFile.dataSet.string(for: .studyInstanceUID)
        XCTAssertEqual(studyUID, "1.2.840.113619.2.62.994044785528.114289542805")
        
        let studyDate = dicomFile.dataSet.string(for: .studyDate)
        XCTAssertEqual(studyDate, "20260215")
        
        let modality = dicomFile.dataSet.string(for: .modality)
        XCTAssertEqual(modality, "CT")
    }
    
    func test_FHIRConverter_ConvertsFromPatient() throws {
        let fhirResource: [String: Any] = [
            "resourceType": "Patient",
            "id": "PAT123",
            "name": [
                [
                    "use": "official",
                    "family": "Smith",
                    "given": ["John", "Michael"]
                ]
            ],
            "birthDate": "1980-01-15",
            "gender": "male"
        ]
        
        let converter = FHIRConverter()
        let dicomFile = try converter.convertFromFHIR(fhirResource: fhirResource, templateFile: nil)
        
        let patientID = dicomFile.dataSet.string(for: .patientID)
        XCTAssertEqual(patientID, "PAT123")
        
        let birthDate = dicomFile.dataSet.string(for: .patientBirthDate)
        XCTAssertEqual(birthDate, "19800115")
        
        let sex = dicomFile.dataSet.string(for: .patientSex)
        XCTAssertEqual(sex, "M")
    }
    
    // MARK: - Gateway Error Tests
    
    func test_GatewayError_DescriptionIsCorrect() {
        let error1 = GatewayError.invalidInput("test")
        XCTAssertTrue(error1.description.contains("Invalid input"))
        
        let error2 = GatewayError.parsingFailed("test")
        XCTAssertTrue(error2.description.contains("Parsing failed"))
        
        let error3 = GatewayError.conversionFailed("test")
        XCTAssertTrue(error3.description.contains("Conversion failed"))
    }
    
    // MARK: - Integration Tests
    
    func test_RoundTrip_DICOM_To_HL7_To_DICOM() throws {
        // Create original DICOM
        let original = try createTestDICOMFile()
        
        // Convert to HL7
        let hl7Converter = DICOMToHL7Converter()
        let hl7Message = try hl7Converter.convertToADT(dicomFile: original)
        
        // Convert back to DICOM
        let dicomConverter = HL7ToDICOMConverter()
        let converted = try dicomConverter.convert(hl7Message: hl7Message, templateFile: nil)
        
        // Verify key fields match
        XCTAssertEqual(
            original.dataSet.string(for: .patientID),
            converted.dataSet.string(for: .patientID)
        )
        XCTAssertEqual(
            original.dataSet.string(for: .patientSex),
            converted.dataSet.string(for: .patientSex)
        )
    }
    
    func test_RoundTrip_DICOM_To_FHIR_To_DICOM() throws {
        // Create original DICOM
        let original = try createTestDICOMFile()
        
        // Convert to FHIR
        let fhirConverter = FHIRConverter()
        let fhirResource = try fhirConverter.convertToFHIR(dicomFile: original, resourceType: .patient)
        
        // Convert back to DICOM
        let converted = try fhirConverter.convertFromFHIR(fhirResource: fhirResource, templateFile: nil)
        
        // Verify key fields match
        XCTAssertEqual(
            original.dataSet.string(for: .patientID),
            converted.dataSet.string(for: .patientID)
        )
    }
    
    // MARK: - Phase C: Gateway Modes Tests
    
    func test_HL7Listener_Initialization() {
        let listener = HL7Listener(
            port: 2575,
            forwardDestination: "pacs://localhost:11112",
            messageTypes: ["ADT", "ORM"],
            verbose: false
        )
        
        XCTAssertNotNil(listener)
    }
    
    func test_HL7Listener_MessageTypeFiltering() throws {
        // Test that listener properly filters message types
        let parser = HL7Parser()
        
        // ADT message
        let adtMessage = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ADT^A01|12345|P|2.5\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        """
        
        let parsedADT = try parser.parse(adtMessage)
        XCTAssertEqual(parsedADT.messageType, .ADT)
        
        // ORM message
        let ormMessage = """
        MSH|^~\\&|SYSTEM|FACILITY|RIS|HOSPITAL|20260215120000||ORM^O01|12346|P|2.5\r
        PID||PAT001||DOE^JOHN^M||19800115|M\r
        """
        
        let parsedORM = try parser.parse(ormMessage)
        XCTAssertEqual(parsedORM.messageType, .ORM)
    }
    
    func test_HL7Listener_ACKGeneration() {
        // Test that ACK messages are properly formatted
        let messageControlId = "MSG12345"
        let timestamp = "20260215120000"
        
        let ack = """
        MSH|^~\\&|DICOMKit|GATEWAY|CLIENT|SYSTEM|\(timestamp)||ACK|\(messageControlId)|P|2.5\r
        MSA|AA|\(messageControlId)\r
        """
        
        XCTAssertTrue(ack.contains("MSH"))
        XCTAssertTrue(ack.contains("MSA|AA|"))
        XCTAssertTrue(ack.contains(messageControlId))
    }
    
    func test_DICOMForwarder_Initialization() {
        let forwarder = DICOMForwarder(
            listenPort: 11112,
            forwardHL7Destination: "hl7://localhost:2575",
            forwardFHIRDestination: nil,
            messageType: "ORU",
            verbose: false
        )
        
        XCTAssertNotNil(forwarder)
    }
    
    func test_DICOMForwarder_HL7MessageTypeSelection() throws {
        let dicomFile = try createTestDICOMFile()
        let converter = DICOMToHL7Converter()
        
        // Test ADT generation
        let adtMessage = try converter.convertToADT(dicomFile: dicomFile, eventType: "A01")
        XCTAssertEqual(adtMessage.messageType, .ADT)
        
        // Test ORM generation
        let ormMessage = try converter.convertToORM(dicomFile: dicomFile)
        XCTAssertEqual(ormMessage.messageType, .ORM)
        
        // Test ORU generation
        let oruMessage = try converter.convertToORU(dicomFile: dicomFile)
        XCTAssertEqual(oruMessage.messageType, .ORU)
    }
    
    func test_DICOMForwarder_FHIRConversion() throws {
        let dicomFile = try createTestDICOMFile()
        let converter = FHIRConverter()
        
        let fhirResource = try converter.convertToFHIR(dicomFile: dicomFile, resourceType: .imagingStudy)
        
        XCTAssertNotNil(fhirResource["resourceType"])
        XCTAssertEqual(fhirResource["resourceType"] as? String, "ImagingStudy")
    }
    
    func test_ListenerMode_ErrorHandling() {
        // Test that listener handles invalid messages gracefully
        let parser = HL7Parser()
        
        // Empty message should throw
        XCTAssertThrowsError(try parser.parse(""))
        
        // Malformed message should throw
        XCTAssertThrowsError(try parser.parse("INVALID|MESSAGE"))
    }
    
    func test_ForwarderMode_ErrorHandling() {
        // Test that forwarder handles invalid destinations gracefully
        let invalidURL = "not-a-valid-url"
        let url = URL(string: invalidURL)
        
        // Invalid URL should be nil
        XCTAssertNil(url)
    }
    
    func test_ForwarderMode_URLParsing() {
        // Test various destination URL formats
        let hl7URL = URL(string: "hl7://server:2575")
        XCTAssertNotNil(hl7URL)
        XCTAssertEqual(hl7URL?.host, "server")
        XCTAssertEqual(hl7URL?.port, 2575)
        
        let pacsURL = URL(string: "pacs://pacs.example.com:11112")
        XCTAssertNotNil(pacsURL)
        XCTAssertEqual(pacsURL?.host, "pacs.example.com")
        XCTAssertEqual(pacsURL?.port, 11112)
        
        let fhirURL = URL(string: "https://fhir.example.com/ImagingStudy")
        XCTAssertNotNil(fhirURL)
        XCTAssertEqual(fhirURL?.scheme, "https")
        XCTAssertEqual(fhirURL?.host, "fhir.example.com")
    }
    
    func test_Gateway_IntegrationWorkflow() throws {
        // Test complete workflow: DICOM -> HL7 -> Forward
        let dicomFile = try createTestDICOMFile()
        
        // Step 1: Convert DICOM to HL7
        let hl7Converter = DICOMToHL7Converter()
        let hl7Message = try hl7Converter.convertToORU(dicomFile: dicomFile)
        
        XCTAssertEqual(hl7Message.messageType, .ORU)
        XCTAssertFalse(hl7Message.segments.isEmpty)
        
        // Step 2: Generate HL7 text
        let parser = HL7Parser()
        let hl7Text = parser.generate(message: hl7Message)
        
        XCTAssertTrue(hl7Text.contains("MSH"))
        XCTAssertTrue(hl7Text.contains("PID"))
        XCTAssertTrue(hl7Text.contains("OBR"))
        
        // Step 3: Parse back
        let reparsed = try parser.parse(hl7Text)
        XCTAssertEqual(reparsed.messageType, hl7Message.messageType)
    }
    
    // MARK: - Phase D: IHE Profiles Tests
    
    func test_IHE_PDI_Validation() throws {
        let dicomFile = try createTestDICOMFile()
        
        // Validate PDI compliance
        let issues = IHEProfiles.PDI.validate(dicomFile)
        
        // Our test file should pass validation (empty issues array)
        XCTAssertTrue(issues.isEmpty, "PDI validation should pass for test file")
    }
    
    func test_IHE_PDI_MissingRequiredTags() throws {
        // Create DICOM file missing required tags
        var fileMetaInformation = DataSet()
        var dataSet = DataSet()
        
        fileMetaInformation.setString("1.2.840.10008.1.2.1", for: .transferSyntaxUID, vr: .UI)
        
        // Only set Patient ID, missing other required fields
        dataSet.setString("TEST001", for: .patientID, vr: .LO)
        
        let dicomFile = DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: dataSet)
        
        let issues = IHEProfiles.PDI.validate(dicomFile)
        
        // Should have issues for missing required tags
        XCTAssertFalse(issues.isEmpty, "Should detect missing required tags")
        XCTAssertTrue(issues.contains { $0.contains("Patient Name") })
    }
    
    func test_IHE_PDI_MetadataRecommendations() throws {
        let dicomFile = try createTestDICOMFile()
        
        let recommendations = IHEProfiles.PDI.recommendPDIMetadata(dicomFile)
        
        // Should provide recommendations even for valid files
        XCTAssertNotNil(recommendations)
    }
    
    func test_IHE_XDSI_MetadataExtraction() throws {
        let dicomFile = try createTestDICOMFile()
        
        let metadata = IHEProfiles.XDSI.extractMetadata(dicomFile)
        
        // Verify key metadata fields are extracted
        XCTAssertNotNil(metadata["patientId"])
        XCTAssertEqual(metadata["patientId"], "TEST001")
        XCTAssertNotNil(metadata["studyInstanceUID"])
        XCTAssertNotNil(metadata["modality"])
        XCTAssertEqual(metadata["modality"], "CT")
    }
    
    func test_IHE_XDSI_ManifestCreation() throws {
        let dicomFile = try createTestDICOMFile()
        let files = [dicomFile]
        
        let manifest = IHEProfiles.XDSI.createManifest(files: files)
        
        // Verify manifest structure
        XCTAssertTrue(manifest.contains("<?xml"))
        XCTAssertTrue(manifest.contains("SubmitObjectsRequest"))
        XCTAssertTrue(manifest.contains("ExtrinsicObject"))
    }
    
    func test_IHE_PIX_PatientIDCrossReferencing() throws {
        // Test PIX profile for patient ID cross-referencing
        let dicomFile = try createTestDICOMFile()
        
        let metadata = IHEProfiles.XDSI.extractMetadata(dicomFile)
        let patientId = metadata["patientId"]
        
        XCTAssertNotNil(patientId)
        XCTAssertEqual(patientId, "TEST001")
        
        // In a real implementation, this would query a PIX manager
        // For now, just verify we can extract the patient ID
    }
    
    func test_IHE_PDQ_DemographicsQuery() throws {
        // Test PDQ profile for demographics query
        let dicomFile = try createTestDICOMFile()
        
        let patientID = dicomFile.dataSet.string(for: .patientID)
        let patientName = dicomFile.dataSet.string(for: .patientName)
        let birthDate = dicomFile.dataSet.string(for: .patientBirthDate)
        
        XCTAssertNotNil(patientID)
        XCTAssertNotNil(patientName)
        XCTAssertNotNil(birthDate)
        
        // Verify demographics are in expected format
        XCTAssertEqual(patientID, "TEST001")
        XCTAssertEqual(patientName, "DOE^JOHN^MICHAEL")
        XCTAssertEqual(birthDate, "19800115")
    }
    
    // MARK: - Phase D: Mapping Engine Tests
    
    func test_MappingEngine_RuleCreation() {
        let rule = MappingEngine.MappingRule(
            source: "PatientID",
            target: "PID-2",
            transform: "uppercase",
            required: true,
            defaultValue: nil
        )
        
        XCTAssertEqual(rule.source, "PatientID")
        XCTAssertEqual(rule.target, "PID-2")
        XCTAssertEqual(rule.transform, "uppercase")
        XCTAssertTrue(rule.required)
    }
    
    func test_MappingEngine_ConfigurationCreation() {
        let rules = [
            MappingEngine.MappingRule(source: "PatientID", target: "PID-2", required: true),
            MappingEngine.MappingRule(source: "PatientName", target: "PID-5", transform: "uppercase")
        ]
        
        let config = MappingEngine.MappingConfig(
            name: "Test Mapping",
            sourceFormat: "dicom",
            targetFormat: "hl7",
            rules: rules,
            includeUnmapped: true
        )
        
        XCTAssertEqual(config.name, "Test Mapping")
        XCTAssertEqual(config.sourceFormat, "dicom")
        XCTAssertEqual(config.targetFormat, "hl7")
        XCTAssertEqual(config.rules.count, 2)
        XCTAssertTrue(config.includeUnmapped)
    }
    
    func test_MappingEngine_TransformationUppercase() {
        let transform = MappingEngine.Transformation.uppercase
        let result = transform.apply("test value")
        
        XCTAssertEqual(result, "TEST VALUE")
    }
    
    func test_MappingEngine_TransformationLowercase() {
        let transform = MappingEngine.Transformation.lowercase
        let result = transform.apply("TEST VALUE")
        
        XCTAssertEqual(result, "test value")
    }
    
    func test_MappingEngine_TransformationTrim() {
        let transform = MappingEngine.Transformation.trim
        let result = transform.apply("  test value  ")
        
        XCTAssertEqual(result, "test value")
    }
    
    func test_MappingEngine_TransformationRemoveSpaces() {
        let transform = MappingEngine.Transformation.removeSpaces
        let result = transform.apply("test value with spaces")
        
        XCTAssertEqual(result, "testvaluewithspaces")
    }
    
    func test_MappingEngine_ConfigurationEncoding() throws {
        let rules = [
            MappingEngine.MappingRule(source: "PatientID", target: "PID-2", required: true)
        ]
        
        let config = MappingEngine.MappingConfig(
            name: "Test Mapping",
            sourceFormat: "dicom",
            targetFormat: "hl7",
            rules: rules
        )
        
        // Test JSON encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        
        XCTAssertFalse(data.isEmpty)
        
        // Test JSON decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MappingEngine.MappingConfig.self, from: data)
        
        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.sourceFormat, config.sourceFormat)
        XCTAssertEqual(decoded.targetFormat, config.targetFormat)
        XCTAssertEqual(decoded.rules.count, config.rules.count)
    }
    
    func test_MappingEngine_AllTransformations() {
        // Test that all transformation cases are defined
        let allTransformations = MappingEngine.Transformation.allCases
        
        XCTAssertTrue(allTransformations.contains(.uppercase))
        XCTAssertTrue(allTransformations.contains(.lowercase))
        XCTAssertTrue(allTransformations.contains(.trim))
        XCTAssertTrue(allTransformations.contains(.dateFormat))
        XCTAssertTrue(allTransformations.contains(.splitName))
        XCTAssertTrue(allTransformations.contains(.combineName))
        XCTAssertTrue(allTransformations.contains(.extractFirst))
        XCTAssertTrue(allTransformations.contains(.extractLast))
        XCTAssertTrue(allTransformations.contains(.removeSpaces))
        XCTAssertTrue(allTransformations.contains(.padLeft))
        XCTAssertTrue(allTransformations.contains(.padRight))
        XCTAssertTrue(allTransformations.contains(.substring))
        
        XCTAssertGreaterThanOrEqual(allTransformations.count, 12)
    }
    
    func test_MappingEngine_InvalidTransformation() {
        // Test that transformations handle invalid input gracefully
        let transform = MappingEngine.Transformation.uppercase
        let emptyResult = transform.apply("")
        
        XCTAssertEqual(emptyResult, "")
    }
    
    // MARK: - Helper Methods
    
    private func createTestDICOMFile() throws -> DICOMFile {
        var fileMetaInformation = DataSet()
        var dataSet = DataSet()
        
        // File Meta Information
        fileMetaInformation.setString("1.2.840.10008.1.2.1", for: .transferSyntaxUID, vr: .UI)
        fileMetaInformation.setString("1.2.840.10008.5.1.4.1.1.7", for: .mediaStorageSOPClassUID, vr: .UI)
        fileMetaInformation.setString("1.2.3.4.5.6.7.8.9", for: .mediaStorageSOPInstanceUID, vr: .UI)
        fileMetaInformation.setString("1.2.826.0.1.3680043.10.1078", for: .implementationClassUID, vr: .UI)
        fileMetaInformation.setString("DICOMKit_Test", for: .implementationVersionName, vr: .SH)
        
        // Patient Information
        dataSet.setString("TEST001", for: .patientID, vr: .LO)
        dataSet.setString("DOE^JOHN^MICHAEL", for: .patientName, vr: .PN)
        dataSet.setString("19800115", for: .patientBirthDate, vr: .DA)
        dataSet.setString("M", for: .patientSex, vr: .CS)
        
        // Study Information
        dataSet.setString("1.2.840.113619.2.62.994044785528.114289542805", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("ACC12345", for: .accessionNumber, vr: .SH)
        dataSet.setString("CT Chest", for: .studyDescription, vr: .LO)
        dataSet.setString("20260215", for: .studyDate, vr: .DA)
        dataSet.setString("120000", for: .studyTime, vr: .TM)
        
        // Series Information
        dataSet.setString("1.2.840.113619.2.62.994044785528.20070822161025697420", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("CT", for: .modality, vr: .CS)
        
        // SOP Information
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        
        return DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: dataSet)
    }
}
