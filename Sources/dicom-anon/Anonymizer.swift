import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Anonymization profile types
public enum AnonymizationProfile {
    case basic
    case clinicalTrial
    case research
    case custom([Tag])
    
    var tagsToRemove: Set<Tag> {
        switch self {
        case .basic:
            return basicProfileTags
        case .clinicalTrial:
            return clinicalTrialProfileTags
        case .research:
            return researchProfileTags
        case .custom(let tags):
            return Set(tags)
        }
    }
    
    private var basicProfileTags: Set<Tag> {
        Set([
            .patientName,
            .patientID,
            .patientBirthDate,
            .patientBirthTime,
            .otherPatientIDs,
            .otherPatientNames,
            .patientComments,
            .referringPhysicianName,
            .performingPhysicianName,
            .operatorName,
            .institutionName,
            .institutionAddress,
            .stationName,
            .deviceSerialNumber
        ])
    }
    
    private var clinicalTrialProfileTags: Set<Tag> {
        basicProfileTags.union([
            .studyDate,
            .seriesDate,
            .acquisitionDate,
            .contentDate,
            .studyTime,
            .seriesTime,
            .acquisitionTime,
            .contentTime
        ])
    }
    
    private var researchProfileTags: Set<Tag> {
        Set([
            .patientName,
            .patientID,
            .patientBirthDate
        ])
    }
}

/// Anonymization action for a tag
public enum AnonymizationAction {
    case remove
    case replaceWithEmpty
    case replaceWithDummy(String)
    case hash
    case shiftDate(days: Int)
    case regenerateUID
}

/// Result of anonymization
public struct AnonymizationResult {
    let filePath: String
    let success: Bool
    let changedTags: [Tag]
    let warnings: [String]
}

/// Audit log entry
public struct AuditLogEntry {
    let timestamp: Date
    let filePath: String
    let action: String
    let tag: Tag
    let originalValue: String?
    let newValue: String?
}

/// Main anonymizer class
public class Anonymizer {
    let profile: AnonymizationProfile
    let shiftDates: Int?
    let regenerateUIDs: Bool
    let preserveTags: Set<Tag>
    let customActions: [Tag: AnonymizationAction]
    
    private var dateOffset: Int?
    private var uidMapping: [String: String] = [:]
    private var auditLog: [AuditLogEntry] = []
    
    public init(
        profile: AnonymizationProfile,
        shiftDates: Int? = nil,
        regenerateUIDs: Bool = true,
        preserveTags: Set<Tag> = [],
        customActions: [Tag: AnonymizationAction] = [:]
    ) {
        self.profile = profile
        self.shiftDates = shiftDates
        self.regenerateUIDs = regenerateUIDs
        self.preserveTags = preserveTags
        self.customActions = customActions
        
        if let shift = shiftDates {
            self.dateOffset = shift
        }
    }
    
    public func anonymize(file: DICOMFile, filePath: String) throws -> (DICOMFile, AnonymizationResult) {
        var newDataSet = file.dataSet
        var changedTags: [Tag] = []
        var warnings: [String] = []
        
        let tagsToProcess = profile.tagsToRemove.subtracting(preserveTags)
        
        for tag in tagsToProcess {
            guard let element = newDataSet[tag] else { continue }
            
            let action = customActions[tag] ?? defaultAction(for: tag)
            
            switch action {
            case .remove:
                let originalValue = extractValue(from: element)
                newDataSet.remove(tag: tag)
                changedTags.append(tag)
                logChange(filePath: filePath, action: "remove", tag: tag, originalValue: originalValue, newValue: nil)
                
            case .replaceWithEmpty:
                let originalValue = extractValue(from: element)
                replaceWithEmpty(tag: tag, vr: element.vr, in: &newDataSet)
                changedTags.append(tag)
                logChange(filePath: filePath, action: "replace_empty", tag: tag, originalValue: originalValue, newValue: "")
                
            case .replaceWithDummy(let dummy):
                let originalValue = extractValue(from: element)
                replaceWithDummy(tag: tag, vr: element.vr, value: dummy, in: &newDataSet)
                changedTags.append(tag)
                logChange(filePath: filePath, action: "replace_dummy", tag: tag, originalValue: originalValue, newValue: dummy)
                
            case .hash:
                if let originalValue = extractValue(from: element) {
                    let hashed = hashValue(originalValue)
                    replaceWithDummy(tag: tag, vr: element.vr, value: hashed, in: &newDataSet)
                    changedTags.append(tag)
                    logChange(filePath: filePath, action: "hash", tag: tag, originalValue: originalValue, newValue: hashed)
                }
                
            case .shiftDate(let days):
                if let originalDate = newDataSet.string(for: tag) {
                    if let shifted = shiftDate(originalDate, byDays: days) {
                        newDataSet.setString(shifted, for: tag, vr: element.vr)
                        changedTags.append(tag)
                        logChange(filePath: filePath, action: "shift_date", tag: tag, originalValue: originalDate, newValue: shifted)
                    }
                }
                
            case .regenerateUID:
                if let originalUID = newDataSet.string(for: tag) {
                    let newUID = getMappedUID(originalUID)
                    newDataSet.setString(newUID, for: tag, vr: element.vr)
                    changedTags.append(tag)
                    logChange(filePath: filePath, action: "regenerate_uid", tag: tag, originalValue: originalUID, newValue: newUID)
                }
            }
        }
        
        // Handle date shifting if specified
        if let offset = dateOffset {
            shiftAllDates(in: &newDataSet, byDays: offset, changedTags: &changedTags, filePath: filePath)
        }
        
        // Regenerate UIDs if specified
        if regenerateUIDs {
            regenerateAllUIDs(in: &newDataSet, changedTags: &changedTags, filePath: filePath)
        }
        
        // Scan for potential PHI leaks in private tags
        let phiWarnings = scanForPHILeaks(in: newDataSet)
        warnings.append(contentsOf: phiWarnings)
        
        let newFile = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: newDataSet)
        let result = AnonymizationResult(
            filePath: filePath,
            success: true,
            changedTags: changedTags,
            warnings: warnings
        )
        
        return (newFile, result)
    }
    
    private func defaultAction(for tag: Tag) -> AnonymizationAction {
        if tag == .patientName {
            return .replaceWithDummy("ANONYMOUS")
        } else if tag == .patientID {
            return .hash
        } else if isDateTag(tag) {
            return shiftDates != nil ? .shiftDate(days: shiftDates!) : .remove
        } else if isUIDTag(tag) {
            return regenerateUIDs ? .regenerateUID : .remove
        } else {
            return .remove
        }
    }
    
    private func isDateTag(_ tag: Tag) -> Bool {
        [.studyDate, .seriesDate, .acquisitionDate, .contentDate, .patientBirthDate].contains(tag)
    }
    
    private func isUIDTag(_ tag: Tag) -> Bool {
        [.studyInstanceUID, .seriesInstanceUID, .sopInstanceUID].contains(tag)
    }
    
    private func extractValue(from element: DataElement) -> String? {
        if let str = element.stringValue {
            return str
        }
        // Convert to a simple string representation
        return "\(element.tag)"
    }
    
    private func replaceWithEmpty(tag: Tag, vr: VR, in dataSet: inout DataSet) {
        dataSet.setString("", for: tag, vr: vr)
    }
    
    private func replaceWithDummy(tag: Tag, vr: VR, value: String, in dataSet: inout DataSet) {
        dataSet.setString(value, for: tag, vr: vr)
    }
    
    private func hashValue(_ value: String) -> String {
        #if canImport(CryptoKit)
        let data = Data(value.utf8)
        let hash = SHA256.hash(data: data)
        // Use 16 hex characters (64 bits) for pseudonymization
        // This provides 2^64 possible values, sufficient for medical datasets
        // while keeping values human-readable in DICOM tags
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
        #else
        // Fallback to simple hash for platforms without CryptoKit
        var hash = value.hashValue
        if hash < 0 {
            hash = -hash
        }
        return String(format: "%016X", hash)
        #endif
    }
    
    private func shiftDate(_ dateString: String, byDays days: Int) -> String? {
        let formatter = DateFormatter()
        
        // Try DICOM date format (YYYYMMDD)
        formatter.dateFormat = "yyyyMMdd"
        if let date = formatter.date(from: dateString) {
            if let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) {
                return formatter.string(from: shifted)
            }
        }
        
        return nil
    }
    
    private func shiftAllDates(in dataSet: inout DataSet, byDays days: Int, changedTags: inout [Tag], filePath: String) {
        let dateTags: [Tag] = [.studyDate, .seriesDate, .acquisitionDate, .contentDate]
        
        for tag in dateTags {
            if let originalDate = dataSet.string(for: tag), !changedTags.contains(tag) {
                if let shifted = shiftDate(originalDate, byDays: days) {
                    if let element = dataSet[tag] {
                        dataSet.setString(shifted, for: tag, vr: element.vr)
                        changedTags.append(tag)
                        logChange(filePath: filePath, action: "shift_date", tag: tag, originalValue: originalDate, newValue: shifted)
                    }
                }
            }
        }
    }
    
    private func regenerateAllUIDs(in dataSet: inout DataSet, changedTags: inout [Tag], filePath: String) {
        let uidTags: [Tag] = [.studyInstanceUID, .seriesInstanceUID, .sopInstanceUID]
        
        for tag in uidTags {
            if let originalUID = dataSet.string(for: tag), !changedTags.contains(tag) {
                let newUID = getMappedUID(originalUID)
                if let element = dataSet[tag] {
                    dataSet.setString(newUID, for: tag, vr: element.vr)
                    changedTags.append(tag)
                    logChange(filePath: filePath, action: "regenerate_uid", tag: tag, originalValue: originalUID, newValue: newUID)
                }
            }
        }
    }
    
    private func getMappedUID(_ originalUID: String) -> String {
        if let mapped = uidMapping[originalUID] {
            return mapped
        }
        
        let newUID = UIDGenerator.generateUID().value
        uidMapping[originalUID] = newUID
        return newUID
    }
    
    private func scanForPHILeaks(in dataSet: DataSet) -> [String] {
        var warnings: [String] = []
        
        for tag in dataSet.tags {
            // Check private tags
            if tag.isPrivate {
                if let element = dataSet[tag], let value = extractValue(from: element) {
                    if containsSuspiciousPHI(value) {
                        warnings.append("Potential PHI detected in private tag \(tag): \(value.prefix(20))...")
                    }
                }
            }
        }
        
        return warnings
    }
    
    private func containsSuspiciousPHI(_ value: String) -> Bool {
        let patterns = [
            "\\b[A-Z][a-z]+\\s[A-Z][a-z]+\\b", // Name pattern
            "\\b\\d{3}-\\d{2}-\\d{4}\\b", // SSN pattern
            "\\b\\d{10}\\b", // Phone number pattern
            "\\b\\d{1,2}/\\d{1,2}/\\d{4}\\b" // Date pattern
        ]
        
        for pattern in patterns {
            if let _ = value.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        
        return false
    }
    
    private func logChange(filePath: String, action: String, tag: Tag, originalValue: String?, newValue: String?) {
        let entry = AuditLogEntry(
            timestamp: Date(),
            filePath: filePath,
            action: action,
            tag: tag,
            originalValue: originalValue,
            newValue: newValue
        )
        auditLog.append(entry)
    }
    
    public func getAuditLog() -> [AuditLogEntry] {
        return auditLog
    }
    
    public func writeAuditLog(to url: URL) throws {
        let dateFormatter = ISO8601DateFormatter()
        var logText = "DICOM Anonymization Audit Log\n"
        logText += "Generated: \(dateFormatter.string(from: Date()))\n\n"
        
        for entry in auditLog {
            logText += "[\(dateFormatter.string(from: entry.timestamp))] "
            logText += "\(entry.filePath) - \(entry.action) - \(entry.tag)\n"
            if let orig = entry.originalValue {
                logText += "  Original: \(orig)\n"
            }
            if let new = entry.newValue {
                logText += "  New: \(new)\n"
            }
            logText += "\n"
        }
        
        try logText.write(to: url, atomically: true, encoding: .utf8)
    }
}

enum AnonymizationError: Error {
    case invalidProfile
    case fileNotFound
    case writeError(String)
}

extension AnonymizationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidProfile:
            return "Invalid anonymization profile"
        case .fileNotFound:
            return "File not found"
        case .writeError(let msg):
            return "Write error: \(msg)"
        }
    }
}
