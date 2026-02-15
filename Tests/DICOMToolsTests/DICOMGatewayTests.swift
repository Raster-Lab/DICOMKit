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
