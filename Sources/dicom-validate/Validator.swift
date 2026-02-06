import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Main validator class that orchestrates DICOM file validation
public struct DICOMValidator {
    let level: Int
    let iod: String?
    let force: Bool
    
    public init(level: Int, iod: String?, force: Bool) {
        self.level = level
        self.iod = iod
        self.force = force
    }
    
    public func validate(data: Data, filePath: String) throws -> ValidationResult {
        var errors: [ValidationIssue] = []
        var warnings: [ValidationIssue] = []
        
        // Level 1: File format validation
        let dicomFile: DICOMFile
        do {
            dicomFile = try DICOMFile.read(from: data, force: force)
        } catch {
            errors.append(ValidationIssue(
                level: .error,
                message: "Failed to parse DICOM file: \(error.localizedDescription)",
                tag: nil
            ))
            return ValidationResult(filePath: filePath, isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check preamble if not forced
        if !force && data.count >= 132 {
            let preambleEnd = data.startIndex.advanced(by: 128)
            let dicmPrefix = data[preambleEnd..<preambleEnd.advanced(by: 4)]
            if String(data: dicmPrefix, encoding: .ascii) != "DICM" {
                warnings.append(ValidationIssue(
                    level: .warning,
                    message: "Missing DICM prefix at byte 128",
                    tag: nil
                ))
            }
        }
        
        // Validate file meta information
        validateFileMetaInformation(dicomFile: dicomFile, errors: &errors, warnings: &warnings)
        
        if level >= 2 {
            // Level 2: Tag presence and VR/VM validation
            validateTagsAndVR(dataSet: dicomFile.dataSet, errors: &errors, warnings: &warnings)
        }
        
        if level >= 3 {
            // Level 3: IOD-specific validation
            if let iodName = iod ?? detectIOD(from: dicomFile.dataSet) {
                validateIOD(dataSet: dicomFile.dataSet, iodName: iodName, errors: &errors, warnings: &warnings)
            } else {
                warnings.append(ValidationIssue(
                    level: .warning,
                    message: "Cannot determine IOD type for validation",
                    tag: .sopClassUID
                ))
            }
        }
        
        if level >= 4 {
            // Level 4: Best practices validation
            validateBestPractices(dataSet: dicomFile.dataSet, errors: &errors, warnings: &warnings)
        }
        
        let isValid = errors.isEmpty
        return ValidationResult(filePath: filePath, isValid: isValid, errors: errors, warnings: warnings)
    }
    
    private func validateFileMetaInformation(dicomFile: DICOMFile, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let dataSet = dicomFile.dataSet
        
        // Required File Meta Information elements
        let requiredMetaTags: [(Tag, String)] = [
            (.mediaStorageSOPClassUID, "Media Storage SOP Class UID"),
            (.mediaStorageSOPInstanceUID, "Media Storage SOP Instance UID"),
            (.transferSyntaxUID, "Transfer Syntax UID")
        ]
        
        for (tag, name) in requiredMetaTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "Missing required File Meta Information element: \(name)",
                    tag: tag
                ))
            }
        }
        
        // Validate Transfer Syntax UID format
        if let tsUID = dataSet.string(for: .transferSyntaxUID) {
            if !isValidUID(tsUID) {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "Invalid Transfer Syntax UID format",
                    tag: .transferSyntaxUID
                ))
            }
        }
    }
    
    private func validateTagsAndVR(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        // Validate required Type 1 elements
        let requiredTags: [(Tag, String)] = [
            (.sopClassUID, "SOP Class UID"),
            (.sopInstanceUID, "SOP Instance UID")
        ]
        
        for (tag, name) in requiredTags {
            if let element = dataSet[tag] {
                if element.length == 0 {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Type 1 element \(name) is empty",
                        tag: tag
                    ))
                }
            } else {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "Missing required Type 1 element: \(name)",
                    tag: tag
                ))
            }
        }
        
        // Validate VR for known tags
        for tag in dataSet.tags {
            if let element = dataSet[tag],
               let entry = DataElementDictionary.lookup(tag: tag) {
                
                // Check if VR matches dictionary
                if !entry.vr.contains(element.vr) && element.vr != .UN {
                    warnings.append(ValidationIssue(
                        level: .warning,
                        message: "Unexpected VR \(element.vr) for tag \(tag) (expected: \(entry.vr.map { $0.rawValue }.joined(separator: " or ")))",
                        tag: tag
                    ))
                }
                
                // Validate value format based on VR
                validateValueFormat(element: element, entry: entry, errors: &errors, warnings: &warnings)
            }
        }
        
        // Validate UIDs
        validateUIDs(dataSet: dataSet, errors: &errors, warnings: &warnings)
        
        // Validate dates and times
        validateDatesAndTimes(dataSet: dataSet, errors: &errors, warnings: &warnings)
    }
    
    private func validateValueFormat(element: DataElement, entry: DataElementEntry, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        switch element.vr {
        case .UI:
            if let value = element.stringValue {
                if !isValidUID(value) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid UID format for \(entry.name)",
                        tag: element.tag
                    ))
                }
            }
        case .DA:
            if let value = element.stringValue {
                if !isValidDate(value) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid date format for \(entry.name) (expected YYYYMMDD)",
                        tag: element.tag
                    ))
                }
            }
        case .TM:
            if let value = element.stringValue {
                if !isValidTime(value) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid time format for \(entry.name) (expected HHMMSS.FFFFFF)",
                        tag: element.tag
                    ))
                }
            }
        case .PN:
            if let value = element.stringValue {
                if value.components(separatedBy: "=").count > 3 {
                    warnings.append(ValidationIssue(
                        level: .warning,
                        message: "Person Name has more than 3 components",
                        tag: element.tag
                    ))
                }
            }
        case .CS:
            if let value = element.stringValue {
                if value.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil {
                    warnings.append(ValidationIssue(
                        level: .warning,
                        message: "Code String should be uppercase",
                        tag: element.tag
                    ))
                }
            }
        default:
            break
        }
    }
    
    private func validateUIDs(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let uidTags: [(Tag, String)] = [
            (.sopClassUID, "SOP Class UID"),
            (.sopInstanceUID, "SOP Instance UID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID")
        ]
        
        for (tag, name) in uidTags {
            if let uid = dataSet.string(for: tag) {
                if !isValidUID(uid) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid \(name) format",
                        tag: tag
                    ))
                }
            }
        }
    }
    
    private func validateDatesAndTimes(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let dateTags: [(Tag, String)] = [
            (.studyDate, "Study Date"),
            (.seriesDate, "Series Date"),
            (.acquisitionDate, "Acquisition Date")
        ]
        
        for (tag, name) in dateTags {
            if let date = dataSet.string(for: tag), !date.isEmpty {
                if !isValidDate(date) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid \(name) format (expected YYYYMMDD)",
                        tag: tag
                    ))
                }
            }
        }
        
        let timeTags: [(Tag, String)] = [
            (.studyTime, "Study Time"),
            (.seriesTime, "Series Time"),
            (.acquisitionTime, "Acquisition Time")
        ]
        
        for (tag, name) in timeTags {
            if let time = dataSet.string(for: tag), !time.isEmpty {
                if !isValidTime(time) {
                    errors.append(ValidationIssue(
                        level: .error,
                        message: "Invalid \(name) format (expected HHMMSS.FFFFFF)",
                        tag: tag
                    ))
                }
            }
        }
    }
    
    private func validateIOD(dataSet: DataSet, iodName: String, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let validator: IODValidator
        
        switch iodName.lowercased() {
        case "ctimagestorage", "ct":
            validator = CTImageStorageValidator()
        case "mrimagestorage", "mr":
            validator = MRImageStorageValidator()
        case "crimagestorage", "cr":
            validator = CRImageStorageValidator()
        case "usimagestorage", "ultrasound":
            validator = USImageStorageValidator()
        case "secondarycaptureimagestorage", "sc":
            validator = SecondaryCaptureImageStorageValidator()
        case "grayscalesoftcopypresentationstate", "gsps":
            validator = GrayscaleSoftcopyPresentationStateValidator()
        case "basictextsr", "enhancedsr", "comprehensivesr", "structuredreport", "sr":
            validator = StructuredReportValidator()
        default:
            warnings.append(ValidationIssue(
                level: .warning,
                message: "IOD validation not implemented for: \(iodName)",
                tag: .sopClassUID
            ))
            return
        }
        
        validator.validate(dataSet: dataSet, errors: &errors, warnings: &warnings)
    }
    
    private func validateBestPractices(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        // Check for deprecated tags
        if dataSet[Tag(group: 0x0028, element: 0x0004)] != nil {
            warnings.append(ValidationIssue(
                level: .warning,
                message: "Tag (0028,0004) Photometric Interpretation is deprecated in some contexts",
                tag: Tag(group: 0x0028, element: 0x0004)
            ))
        }
        
        // Recommend Character Set specification
        if dataSet[.specificCharacterSet] == nil {
            warnings.append(ValidationIssue(
                level: .warning,
                message: "Specific Character Set not specified (ISO_IR 100 or UTF-8 recommended)",
                tag: .specificCharacterSet
            ))
        }
        
        // Check for private tags usage
        let privateTags = dataSet.tags.filter { $0.isPrivate }
        if privateTags.count > 10 {
            warnings.append(ValidationIssue(
                level: .warning,
                message: "File contains \(privateTags.count) private tags (may affect interoperability)",
                tag: nil
            ))
        }
    }
    
    private func detectIOD(from dataSet: DataSet) -> String? {
        guard let sopClassUID = dataSet.string(for: .sopClassUID) else {
            return nil
        }
        
        // Map common SOP Class UIDs to IOD names
        switch sopClassUID {
        case "1.2.840.10008.5.1.4.1.1.2":
            return "CTImageStorage"
        case "1.2.840.10008.5.1.4.1.1.4":
            return "MRImageStorage"
        case "1.2.840.10008.5.1.4.1.1.1":
            return "CRImageStorage"
        case "1.2.840.10008.5.1.4.1.1.6.1":
            return "USImageStorage"
        case "1.2.840.10008.5.1.4.1.1.7":
            return "SecondaryCapture ImageStorage"
        case "1.2.840.10008.5.1.4.1.1.11.1":
            return "GrayscaleSoftcopyPresentationState"
        case "1.2.840.10008.5.1.4.1.1.88.11", "1.2.840.10008.5.1.4.1.1.88.22", "1.2.840.10008.5.1.4.1.1.88.33":
            return "StructuredReport"
        default:
            return nil
        }
    }
    
    private func isValidUID(_ uid: String) -> Bool {
        // UID format: numeric components separated by dots
        // Each component is 1 or more digits
        // Max length 64 characters
        guard uid.count <= 64 else { return false }
        
        let components = uid.components(separatedBy: ".")
        guard !components.isEmpty else { return false }
        
        for component in components {
            guard !component.isEmpty else { return false }
            guard component.allSatisfy({ $0.isNumber }) else { return false }
            // Leading zeros not allowed except for "0"
            if component.count > 1 && component.first == "0" {
                return false
            }
        }
        
        return true
    }
    
    private func isValidDate(_ date: String) -> Bool {
        // DICOM Date format: YYYYMMDD
        guard date.count == 8 else { return false }
        guard date.allSatisfy({ $0.isNumber }) else { return false }
        
        guard let year = Int(date.prefix(4)),
              let month = Int(date.dropFirst(4).prefix(2)),
              let day = Int(date.suffix(2)) else {
            return false
        }
        
        guard year >= 1900 && year <= 9999 else { return false }
        guard month >= 1 && month <= 12 else { return false }
        guard day >= 1 && day <= 31 else { return false }
        
        return true
    }
    
    private func isValidTime(_ time: String) -> Bool {
        // DICOM Time format: HHMMSS.FFFFFF (fractional seconds optional)
        guard time.count >= 6 else { return false }
        
        let components = time.components(separatedBy: ".")
        guard components.count <= 2 else { return false }
        
        let hhmmss = components[0]
        guard hhmmss.count == 6 else { return false }
        guard hhmmss.allSatisfy({ $0.isNumber }) else { return false }
        
        guard let hh = Int(hhmmss.prefix(2)),
              let mm = Int(hhmmss.dropFirst(2).prefix(2)),
              let ss = Int(hhmmss.suffix(2)) else {
            return false
        }
        
        guard hh >= 0 && hh <= 23 else { return false }
        guard mm >= 0 && mm <= 59 else { return false }
        guard ss >= 0 && ss <= 59 else { return false }
        
        if components.count == 2 {
            let fraction = components[1]
            guard fraction.count <= 6 else { return false }
            guard fraction.allSatisfy({ $0.isNumber }) else { return false }
        }
        
        return true
    }
}

/// Validation issue
public struct ValidationIssue {
    public enum Level: String, Codable {
        case error
        case warning
    }
    
    public let level: Level
    public let message: String
    public let tag: Tag?
    
    public init(level: Level, message: String, tag: Tag?) {
        self.level = level
        self.message = message
        self.tag = tag
    }
    
    var tagString: String? {
        tag?.description
    }
}

/// Validation result for a single file
public struct ValidationResult {
    public let filePath: String
    public let isValid: Bool
    public let errors: [ValidationIssue]
    public let warnings: [ValidationIssue]
    
    public init(filePath: String, isValid: Bool, errors: [ValidationIssue], warnings: [ValidationIssue]) {
        self.filePath = filePath
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// IOD-specific validator protocol
protocol IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue])
}

/// CT Image Storage validator
struct CTImageStorageValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        // CT-specific required attributes
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality"),
            (.rows, "Rows"),
            (.columns, "Columns")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "CT Image Storage: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        // Validate modality
        if let modality = dataSet.string(for: .modality), modality != "CT" {
            errors.append(ValidationIssue(
                level: .error,
                message: "CT Image Storage: Modality must be 'CT'",
                tag: .modality
            ))
        }
    }
}

/// MR Image Storage validator
struct MRImageStorageValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality"),
            (.rows, "Rows"),
            (.columns, "Columns")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "MR Image Storage: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        if let modality = dataSet.string(for: .modality), modality != "MR" {
            errors.append(ValidationIssue(
                level: .error,
                message: "MR Image Storage: Modality must be 'MR'",
                tag: .modality
            ))
        }
    }
}

/// CR Image Storage validator
struct CRImageStorageValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "CR Image Storage: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        if let modality = dataSet.string(for: .modality), modality != "CR" {
            errors.append(ValidationIssue(
                level: .error,
                message: "CR Image Storage: Modality must be 'CR'",
                tag: .modality
            ))
        }
    }
}

/// Ultrasound Image Storage validator
struct USImageStorageValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "US Image Storage: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        if let modality = dataSet.string(for: .modality), modality != "US" {
            errors.append(ValidationIssue(
                level: .error,
                message: "US Image Storage: Modality must be 'US'",
                tag: .modality
            ))
        }
    }
}

/// Secondary Capture Image Storage validator
struct SecondaryCaptureImageStorageValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "Secondary Capture: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
    }
}

/// Grayscale Softcopy Presentation State validator
struct GrayscaleSoftcopyPresentationStateValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "GSPS: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        if let modality = dataSet.string(for: .modality), modality != "PR" {
            warnings.append(ValidationIssue(
                level: .warning,
                message: "GSPS: Modality should be 'PR'",
                tag: .modality
            ))
        }
    }
}

/// Structured Report validator
struct StructuredReportValidator: IODValidator {
    func validate(dataSet: DataSet, errors: inout [ValidationIssue], warnings: inout [ValidationIssue]) {
        let requiredTags: [(Tag, String)] = [
            (.patientName, "Patient Name"),
            (.patientID, "Patient ID"),
            (.studyInstanceUID, "Study Instance UID"),
            (.seriesInstanceUID, "Series Instance UID"),
            (.modality, "Modality")
        ]
        
        for (tag, name) in requiredTags {
            if dataSet[tag] == nil {
                errors.append(ValidationIssue(
                    level: .error,
                    message: "Structured Report: Missing required attribute \(name)",
                    tag: tag
                ))
            }
        }
        
        if let modality = dataSet.string(for: .modality), modality != "SR" {
            errors.append(ValidationIssue(
                level: .error,
                message: "Structured Report: Modality must be 'SR'",
                tag: .modality
            ))
        }
    }
}
