import Foundation
import DICOMKit
import DICOMCore

// MARK: - HL7 to DICOM Converter

class HL7ToDICOMConverter {
    private let config: MappingConfiguration
    
    init(config: MappingConfiguration = MappingConfiguration()) {
        self.config = config
    }
    
    func convert(hl7Message: HL7Message, templateFile: DICOMFile? = nil) throws -> DICOMFile {
        // Start with template or create new file
        var dicomFile: DICOMFile
        if let template = templateFile {
            dicomFile = template
        } else {
            dicomFile = try createBasicDICOMFile()
        }
        
        // Extract patient information from PID segment
        if let pid = hl7Message.segment("PID") {
            try populatePatientInfo(dicomFile: &dicomFile, pid: pid)
        }
        
        // Extract study information from OBR segment if present
        if let obr = hl7Message.segment("OBR") {
            try populateStudyInfo(dicomFile: &dicomFile, obr: obr)
        }
        
        // Extract accession number from ORC segment if present
        if let orc = hl7Message.segment("ORC") {
            try populateOrderInfo(dicomFile: &dicomFile, orc: orc)
        }
        
        return dicomFile
    }
    
    // MARK: - Population Methods
    
    private func populatePatientInfo(dicomFile: inout DICOMFile, pid: HL7Segment) throws {
        // Patient ID (PID-3)
        if let patientID = pid[2] {
            try setElement(&dicomFile, tag: .patientID, value: patientID, vr: .LO)
        }
        
        // Patient Name (PID-5)
        if let hl7Name = pid[4] {
            let dicomName = convertHL7NameToDICOM(hl7Name)
            try setElement(&dicomFile, tag: .patientName, value: dicomName, vr: .PN)
        }
        
        // Date of Birth (PID-7)
        if let dob = pid[6] {
            let dicomDate = convertHL7DateToDICOM(dob)
            try setElement(&dicomFile, tag: .patientBirthDate, value: dicomDate, vr: .DA)
        }
        
        // Sex (PID-8)
        if let sex = pid[7] {
            let dicomSex = mapHL7SexToDICOM(sex)
            try setElement(&dicomFile, tag: .patientSex, value: dicomSex, vr: .CS)
        }
    }
    
    private func populateStudyInfo(dicomFile: inout DICOMFile, obr: HL7Segment) throws {
        // Study Description (OBR-4)
        if let serviceID = obr[3] {
            // Parse "MODALITY^Description"
            let components = serviceID.split(separator: "^")
            if components.count >= 2 {
                try setElement(&dicomFile, tag: .studyDescription, value: String(components[1]), vr: .LO)
                try setElement(&dicomFile, tag: .modality, value: String(components[0]), vr: .CS)
            }
        }
        
        // Study Date/Time (OBR-7)
        if let observationDateTime = obr[6] {
            let (date, time) = splitHL7DateTime(observationDateTime)
            if !date.isEmpty {
                try setElement(&dicomFile, tag: .studyDate, value: date, vr: .DA)
            }
            if !time.isEmpty {
                try setElement(&dicomFile, tag: .studyTime, value: time, vr: .TM)
            }
        }
        
        // Filler Order Number -> Study Instance UID (OBR-3)
        if let fillerOrderNumber = obr[2], !fillerOrderNumber.isEmpty {
            // If it looks like a UID, use it; otherwise generate one
            if isValidUID(fillerOrderNumber) {
                try setElement(&dicomFile, tag: .studyInstanceUID, value: fillerOrderNumber, vr: .UI)
            }
        }
    }
    
    private func populateOrderInfo(dicomFile: inout DICOMFile, orc: HL7Segment) throws {
        // Accession Number (ORC-2)
        if let accessionNumber = orc[1] {
            try setElement(&dicomFile, tag: .accessionNumber, value: accessionNumber, vr: .SH)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createBasicDICOMFile() throws -> DICOMFile {
        // Create a minimal Secondary Capture image as template
        var dataset = DataSet()
        var fileMetaInformation = DataSet()
        
        // File Meta Information
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.7" // Secondary Capture Image Storage
        let sopInstanceUID = generateUID()
        
        // SOP Class UID - Transfer Syntax UID (Explicit VR Little Endian)
        fileMetaInformation.setString("1.2.840.10008.1.2.1", for: .transferSyntaxUID, vr: .UI)
        fileMetaInformation.setString(sopClassUID, for: .mediaStorageSOPClassUID, vr: .UI)
        fileMetaInformation.setString(sopInstanceUID, for: .mediaStorageSOPInstanceUID, vr: .UI)
        fileMetaInformation.setString("1.2.826.0.1.3680043.10.1078", for: .implementationClassUID, vr: .UI)
        fileMetaInformation.setString("DICOMKit_1.0", for: .implementationVersionName, vr: .SH)
        
        // Main dataset
        // SOP Class UID
        dataset.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        
        // SOP Instance UID
        dataset.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        
        // Study Instance UID
        dataset.setString(generateUID(), for: .studyInstanceUID, vr: .UI)
        
        // Series Instance UID
        dataset.setString(generateUID(), for: .seriesInstanceUID, vr: .UI)
        
        // Modality
        dataset.setString("OT", for: .modality, vr: .CS)
        
        return DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: dataset)
    }
    
    private func setElement(_ file: inout DICOMFile, tag: Tag, value: String, vr: VR) throws {
        var newDataSet = file.dataSet
        newDataSet.setString(value, for: tag, vr: vr)
        file = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: newDataSet)
    }
    
    private func convertHL7NameToDICOM(_ hl7Name: String) -> String {
        // HL7 format: LastName^FirstName^MiddleName^Suffix^Prefix
        // DICOM format: LastName^FirstName^MiddleName^Prefix^Suffix
        let components = hl7Name.split(separator: "^", omittingEmptySubsequences: false)
        if components.count >= 5 {
            return "\(components[0])^\(components[1])^\(components[2])^\(components[4])^\(components[3])"
        }
        return hl7Name
    }
    
    private func convertHL7DateToDICOM(_ hl7Date: String) -> String {
        // HL7: YYYYMMDD or YYYYMMDDHHMMSS
        // DICOM date: YYYYMMDD
        if hl7Date.count >= 8 {
            return String(hl7Date.prefix(8))
        }
        return hl7Date
    }
    
    private func splitHL7DateTime(_ dateTime: String) -> (date: String, time: String) {
        // HL7: YYYYMMDDHHMMSS
        if dateTime.count >= 8 {
            let date = String(dateTime.prefix(8))
            if dateTime.count >= 14 {
                let timeIndex = dateTime.index(dateTime.startIndex, offsetBy: 8)
                let time = String(dateTime[timeIndex..<dateTime.index(timeIndex, offsetBy: 6)])
                return (date, time)
            }
            return (date, "")
        }
        return ("", "")
    }
    
    private func mapHL7SexToDICOM(_ hl7Sex: String) -> String {
        switch hl7Sex.uppercased() {
        case "M": return "M"
        case "F": return "F"
        case "O": return "O"
        case "U", "": return ""
        default: return "O"
        }
    }
    
    private func isValidUID(_ string: String) -> Bool {
        // UID should contain only digits and dots, start with digit
        guard !string.isEmpty, string.first?.isNumber == true else { return false }
        let validCharacters = CharacterSet(charactersIn: "0123456789.")
        return string.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }
    
    private func generateUID() -> String {
        // Generate a UID using a base prefix and timestamp
        let prefix = "1.2.826.0.1.3680043.10"
        let timestamp = Date().timeIntervalSince1970
        let random = UInt32.random(in: 0...999999)
        return "\(prefix).\(Int(timestamp)).\(random)"
    }
}
