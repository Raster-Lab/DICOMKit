import Foundation
import DICOMKit
import DICOMCore

// MARK: - FHIR Resource Type

enum FHIRResourceType: String, CaseIterable {
    case imagingStudy = "ImagingStudy"
    case patient = "Patient"
    case practitioner = "Practitioner"
    case diagnosticReport = "DiagnosticReport"
}

// MARK: - FHIR JSON Converter

class FHIRConverter {
    private let config: MappingConfiguration
    
    init(config: MappingConfiguration = MappingConfiguration()) {
        self.config = config
    }
    
    // MARK: - DICOM to FHIR
    
    func convertToFHIR(dicomFile: DICOMFile, resourceType: FHIRResourceType) throws -> [String: Any] {
        switch resourceType {
        case .imagingStudy:
            return try convertToImagingStudy(dicomFile: dicomFile)
        case .patient:
            return try convertToPatient(dicomFile: dicomFile)
        case .practitioner:
            return try convertToPractitioner(dicomFile: dicomFile)
        case .diagnosticReport:
            return try convertToDiagnosticReport(dicomFile: dicomFile)
        }
    }
    
    private func convertToImagingStudy(dicomFile: DICOMFile) throws -> [String: Any] {
        var resource: [String: Any] = [
            "resourceType": "ImagingStudy",
            "status": "available"
        ]
        
        // Study Instance UID
        if let studyUID = extractString(from: dicomFile, tag: .studyInstanceUID) {
            resource["identifier"] = [
                [
                    "system": "urn:dicom:uid",
                    "value": "urn:oid:\(studyUID)"
                ]
            ]
        }
        
        // Study Date/Time
        if let studyDate = extractString(from: dicomFile, tag: .studyDate),
           let studyTime = extractString(from: dicomFile, tag: .studyTime) {
            resource["started"] = formatFHIRDateTime(date: studyDate, time: studyTime)
        }
        
        // Modality
        if let modality = extractString(from: dicomFile, tag: .modality) {
            resource["modality"] = [
                [
                    "system": "http://dicom.nema.org/resources/ontology/DCM",
                    "code": modality
                ]
            ]
        }
        
        // Study Description
        if let description = extractString(from: dicomFile, tag: .studyDescription) {
            resource["description"] = description
        }
        
        // Number of Series
        if let numberOfSeries = extractString(from: dicomFile, tag: .numberOfStudyRelatedSeries) {
            resource["numberOfSeries"] = Int(numberOfSeries) ?? 0
        }
        
        // Number of Instances
        if let numberOfInstances = extractString(from: dicomFile, tag: .numberOfStudyRelatedInstances) {
            resource["numberOfInstances"] = Int(numberOfInstances) ?? 0
        }
        
        // Patient reference
        if let patientID = extractString(from: dicomFile, tag: .patientID) {
            resource["subject"] = [
                "reference": "Patient/\(patientID)"
            ]
        }
        
        return resource
    }
    
    private func convertToPatient(dicomFile: DICOMFile) throws -> [String: Any] {
        var resource: [String: Any] = [
            "resourceType": "Patient"
        ]
        
        // Patient ID
        if let patientID = extractString(from: dicomFile, tag: .patientID) {
            resource["id"] = patientID
            resource["identifier"] = [
                [
                    "system": "urn:oid:2.16.840.1.113883.19.5",
                    "value": patientID
                ]
            ]
        }
        
        // Patient Name
        if let patientName = extractString(from: dicomFile, tag: .patientName) {
            let nameComponents = parseDICOMName(patientName)
            resource["name"] = [
                [
                    "use": "official",
                    "family": nameComponents.family,
                    "given": nameComponents.given
                ]
            ]
        }
        
        // Birth Date
        if let birthDate = extractString(from: dicomFile, tag: .patientBirthDate) {
            resource["birthDate"] = formatFHIRDate(birthDate)
        }
        
        // Gender
        if let sex = extractString(from: dicomFile, tag: .patientSex) {
            resource["gender"] = mapDICOMSexToFHIR(sex)
        }
        
        return resource
    }
    
    private func convertToPractitioner(dicomFile: DICOMFile) throws -> [String: Any] {
        var resource: [String: Any] = [
            "resourceType": "Practitioner"
        ]
        
        // Referring Physician
        if let referringPhysician = extractString(from: dicomFile, tag: .referringPhysicianName) {
            let nameComponents = parseDICOMName(referringPhysician)
            resource["name"] = [
                [
                    "use": "official",
                    "family": nameComponents.family,
                    "given": nameComponents.given
                ]
            ]
        }
        
        return resource
    }
    
    private func convertToDiagnosticReport(dicomFile: DICOMFile) throws -> [String: Any] {
        var resource: [String: Any] = [
            "resourceType": "DiagnosticReport",
            "status": "final"
        ]
        
        // Study Description -> Code
        if let studyDescription = extractString(from: dicomFile, tag: .studyDescription) {
            resource["code"] = [
                "text": studyDescription
            ]
        }
        
        // Effective DateTime
        if let studyDate = extractString(from: dicomFile, tag: .studyDate),
           let studyTime = extractString(from: dicomFile, tag: .studyTime) {
            resource["effectiveDateTime"] = formatFHIRDateTime(date: studyDate, time: studyTime)
        }
        
        // Patient reference
        if let patientID = extractString(from: dicomFile, tag: .patientID) {
            resource["subject"] = [
                "reference": "Patient/\(patientID)"
            ]
        }
        
        return resource
    }
    
    // MARK: - FHIR to DICOM
    
    func convertFromFHIR(fhirResource: [String: Any], templateFile: DICOMFile? = nil) throws -> DICOMFile {
        guard let resourceType = fhirResource["resourceType"] as? String else {
            throw GatewayError.parsingFailed("Missing resourceType in FHIR resource")
        }
        
        var dicomFile: DICOMFile
        if let template = templateFile {
            dicomFile = template
        } else {
            dicomFile = try createBasicDICOMFile()
        }
        
        switch resourceType {
        case "ImagingStudy":
            try populateFromImagingStudy(dicomFile: &dicomFile, fhir: fhirResource)
        case "Patient":
            try populateFromPatient(dicomFile: &dicomFile, fhir: fhirResource)
        default:
            throw GatewayError.notImplemented("FHIR resource type '\(resourceType)' not yet supported")
        }
        
        return dicomFile
    }
    
    private func populateFromImagingStudy(dicomFile: inout DICOMFile, fhir: [String: Any]) throws {
        // Extract Study Instance UID from identifier
        if let identifiers = fhir["identifier"] as? [[String: Any]],
           let firstIdentifier = identifiers.first,
           let value = firstIdentifier["value"] as? String {
            // Remove "urn:oid:" prefix if present
            let uid = value.replacingOccurrences(of: "urn:oid:", with: "")
            try setElement(&dicomFile, tag: .studyInstanceUID, value: uid, vr: .UI)
        }
        
        // Study Date/Time
        if let started = fhir["started"] as? String {
            let (date, time) = parseFHIRDateTime(started)
            if !date.isEmpty {
                try setElement(&dicomFile, tag: .studyDate, value: date, vr: .DA)
            }
            if !time.isEmpty {
                try setElement(&dicomFile, tag: .studyTime, value: time, vr: .TM)
            }
        }
        
        // Study Description
        if let description = fhir["description"] as? String {
            try setElement(&dicomFile, tag: .studyDescription, value: description, vr: .LO)
        }
        
        // Modality
        if let modalities = fhir["modality"] as? [[String: Any]],
           let firstModality = modalities.first,
           let code = firstModality["code"] as? String {
            try setElement(&dicomFile, tag: .modality, value: code, vr: .CS)
        }
    }
    
    private func populateFromPatient(dicomFile: inout DICOMFile, fhir: [String: Any]) throws {
        // Patient ID
        if let patientID = fhir["id"] as? String {
            try setElement(&dicomFile, tag: .patientID, value: patientID, vr: .LO)
        }
        
        // Patient Name
        if let names = fhir["name"] as? [[String: Any]],
           let firstName = names.first {
            let family = firstName["family"] as? String ?? ""
            let given = firstName["given"] as? [String] ?? []
            let dicomName = formatDICOMName(family: family, given: given)
            try setElement(&dicomFile, tag: .patientName, value: dicomName, vr: .PN)
        }
        
        // Birth Date
        if let birthDate = fhir["birthDate"] as? String {
            let dicomDate = birthDate.replacingOccurrences(of: "-", with: "")
            try setElement(&dicomFile, tag: .patientBirthDate, value: dicomDate, vr: .DA)
        }
        
        // Gender
        if let gender = fhir["gender"] as? String {
            try setElement(&dicomFile, tag: .patientSex, value: mapFHIRGenderToDICOM(gender), vr: .CS)
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractString(from file: DICOMFile, tag: Tag) -> String? {
        return file.dataSet.string(for: tag)
    }
    
    private func setElement(_ file: inout DICOMFile, tag: Tag, value: String, vr: VR) throws {
        var newDataSet = file.dataSet
        newDataSet.setString(value, for: tag, vr: vr)
        file = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: newDataSet)
    }
    
    private func createBasicDICOMFile() throws -> DICOMFile {
        var dataset = DataSet()
        var fileMetaInformation = DataSet()
        
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.7" // Secondary Capture Image Storage
        let sopInstanceUID = generateUID()
        
        // File Meta Information
        fileMetaInformation.setString("1.2.840.10008.1.2.1", for: .transferSyntaxUID, vr: .UI)
        fileMetaInformation.setString(sopClassUID, for: .mediaStorageSOPClassUID, vr: .UI)
        fileMetaInformation.setString(sopInstanceUID, for: .mediaStorageSOPInstanceUID, vr: .UI)
        fileMetaInformation.setString("1.2.826.0.1.3680043.10.1078", for: .implementationClassUID, vr: .UI)
        fileMetaInformation.setString("DICOMKit_1.0", for: .implementationVersionName, vr: .SH)
        
        // Main dataset
        dataset.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        dataset.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        dataset.setString(generateUID(), for: .studyInstanceUID, vr: .UI)
        dataset.setString(generateUID(), for: .seriesInstanceUID, vr: .UI)
        dataset.setString("OT", for: .modality, vr: .CS)
        
        return DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: dataset)
    }
    
    private func parseDICOMName(_ name: String) -> (family: String, given: [String]) {
        let components = name.split(separator: "^")
        let family = components.first.map(String.init) ?? ""
        let given = components.count > 1 ? [String(components[1])] : []
        return (family, given)
    }
    
    private func formatDICOMName(family: String, given: [String]) -> String {
        if given.isEmpty {
            return family
        }
        return "\(family)^\(given.joined(separator: " "))"
    }
    
    private func formatFHIRDateTime(date: String, time: String) -> String {
        // DICOM: YYYYMMDD + HHMMSS
        // FHIR: YYYY-MM-DDTHH:MM:SS
        guard date.count == 8 else { return "" }
        
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.dropFirst(6).prefix(2)
        
        var result = "\(year)-\(month)-\(day)"
        
        if time.count >= 6 {
            let hour = time.prefix(2)
            let minute = time.dropFirst(2).prefix(2)
            let second = time.dropFirst(4).prefix(2)
            result += "T\(hour):\(minute):\(second)"
        }
        
        return result
    }
    
    private func formatFHIRDate(_ date: String) -> String {
        // DICOM: YYYYMMDD -> FHIR: YYYY-MM-DD
        guard date.count == 8 else { return date }
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.dropFirst(6).prefix(2)
        return "\(year)-\(month)-\(day)"
    }
    
    private func parseFHIRDateTime(_ dateTime: String) -> (date: String, time: String) {
        // FHIR: YYYY-MM-DDTHH:MM:SS -> DICOM: YYYYMMDD + HHMMSS
        let components = dateTime.split(separator: "T")
        
        var date = ""
        if !components.isEmpty {
            date = String(components[0]).replacingOccurrences(of: "-", with: "")
        }
        
        var time = ""
        if components.count > 1 {
            time = String(components[1]).replacingOccurrences(of: ":", with: "")
        }
        
        return (date, time)
    }
    
    private func mapDICOMSexToFHIR(_ sex: String) -> String {
        switch sex.uppercased() {
        case "M": return "male"
        case "F": return "female"
        case "O": return "other"
        default: return "unknown"
        }
    }
    
    private func mapFHIRGenderToDICOM(_ gender: String) -> String {
        switch gender.lowercased() {
        case "male": return "M"
        case "female": return "F"
        case "other": return "O"
        default: return ""
        }
    }
    
    private func generateUID() -> String {
        let prefix = "1.2.826.0.1.3680043.10"
        let timestamp = Date().timeIntervalSince1970
        let random = UInt32.random(in: 0...999999)
        return "\(prefix).\(Int(timestamp)).\(random)"
    }
}

// MARK: - Additional DICOM Tags (not in standard extensions)

extension Tag {
    static let numberOfStudyRelatedSeries = Tag(group: 0x0020, element: 0x1206)
    static let numberOfStudyRelatedInstances = Tag(group: 0x0020, element: 0x1208)
    static let numberOfSeriesRelatedInstances = Tag(group: 0x0020, element: 0x1209)
    static let seriesInstanceUID = Tag(group: 0x0020, element: 0x000E)
    static let sopClassUID = Tag(group: 0x0008, element: 0x0016)
    static let sopInstanceUID = Tag(group: 0x0008, element: 0x0018)
}
