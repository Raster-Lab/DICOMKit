import Foundation
import DICOMKit
import DICOMCore

/// IHE (Integrating the Healthcare Enterprise) profile support
/// Implements common IHE integration profiles for medical imaging
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct IHEProfiles {
    
    // MARK: - IHE Profile Types
    
    enum Profile: String, CaseIterable {
        case pdi = "PDI"           // Portable Data for Imaging
        case xdsI = "XDS-I"         // Cross-Enterprise Document Sharing for Imaging
        case pix = "PIX"            // Patient Identifier Cross-Referencing
        case pdq = "PDQ"            // Patient Demographics Query
        case swd = "SWD"            // Scheduled Workflow with Distribution
        case iid = "IID"            // Imaging Integration DICOM
        
        var name: String {
            switch self {
            case .pdi:
                return "Portable Data for Imaging"
            case .xdsI:
                return "Cross-Enterprise Document Sharing for Imaging"
            case .pix:
                return "Patient Identifier Cross-Referencing"
            case .pdq:
                return "Patient Demographics Query"
            case .swd:
                return "Scheduled Workflow with Distribution"
            case .iid:
                return "Imaging Integration DICOM"
            }
        }
        
        var description: String {
            switch self {
            case .pdi:
                return "Enables portable imaging media with DICOMDIR"
            case .xdsI:
                return "Enables sharing of imaging documents across enterprises"
            case .pix:
                return "Cross-references patient identifiers across domains"
            case .pdq:
                return "Queries patient demographics from multiple sources"
            case .swd:
                return "Scheduled workflow with results distribution"
            case .iid:
                return "Imaging acquisition workflow integration"
            }
        }
    }
    
    // MARK: - PDI Profile
    
    /// Portable Data for Imaging profile
    /// Implements basic DICOMDIR and media export requirements
    struct PDI {
        
        /// Validate DICOM file for PDI compliance
        static func validate(_ dicomFile: DICOMFile) throws -> [String] {
            var issues: [String] = []
            
            // Required Type 1 attributes for PDI
            let requiredTags: [Tag] = [
                .patientID,
                .patientName,
                .studyInstanceUID,
                .seriesInstanceUID,
                .sopInstanceUID,
                .sopClassUID,
                .modality
            ]
            
            for tag in requiredTags {
                if dicomFile.dataSet[tag] == nil {
                    issues.append("Missing required tag: \(tag)")
                }
            }
            
            // Check for patient birth date (Type 2 - should be present even if empty)
            if dicomFile.dataSet[.patientBirthDate] == nil {
                issues.append("Missing recommended tag: Patient Birth Date")
            }
            
            // Check for study date and time
            if dicomFile.dataSet[.studyDate] == nil {
                issues.append("Missing recommended tag: Study Date")
            }
            
            return issues
        }
        
        /// Add PDI-required metadata to DICOM file
        /// Note: Returns recommendations for missing fields since DICOMFile is immutable
        static func recommendPDIMetadata(_ dicomFile: DICOMFile) -> [String] {
            var recommendations: [String] = []
            
            // Check if Instance Creator UID is present
            if dicomFile.dataSet[.instanceCreatorUID] == nil {
                recommendations.append("Add Instance Creator UID: 1.2.840.113619.DICOMKit")
            }
            
            // Check for timezone if not present (for proper date/time interpretation)
            if dicomFile.dataSet[.timezoneOffsetFromUTC] == nil {
                let timezone = TimeZone.current
                let offset = timezone.secondsFromGMT() / 3600
                let sign = offset >= 0 ? "+" : "-"
                let hours = abs(offset)
                let tzString = String(format: "%@%04d", sign, hours * 100)
                recommendations.append("Add Timezone Offset From UTC: \(tzString)")
            }
            
            return recommendations
        }
    }
    
    // MARK: - XDS-I Profile
    
    /// Cross-Enterprise Document Sharing for Imaging
    /// Implements metadata extraction for XDS registry
    struct XDSI {
        
        /// Extract XDS metadata from DICOM file
        static func extractMetadata(_ dicomFile: DICOMFile) -> [String: String] {
            var metadata: [String: String] = [:]
            
            // Patient identification
            if let patientID = dicomFile.dataSet.string(for: .patientID) {
                metadata["patientId"] = patientID
            }
            if let patientName = dicomFile.dataSet.string(for: .patientName) {
                metadata["patientName"] = patientName
            }
            
            // Study identification
            if let studyUID = dicomFile.dataSet.string(for: .studyInstanceUID) {
                metadata["studyInstanceUID"] = studyUID
            }
            if let studyDate = dicomFile.dataSet.string(for: .studyDate) {
                metadata["studyDate"] = studyDate
            }
            if let studyTime = dicomFile.dataSet.string(for: .studyTime) {
                metadata["studyTime"] = studyTime
            }
            if let studyDescription = dicomFile.dataSet.string(for: .studyDescription) {
                metadata["studyDescription"] = studyDescription
            }
            
            // Series identification
            if let seriesUID = dicomFile.dataSet.string(for: .seriesInstanceUID) {
                metadata["seriesInstanceUID"] = seriesUID
            }
            if let modality = dicomFile.dataSet.string(for: .modality) {
                metadata["modality"] = modality
            }
            
            // Document metadata
            if let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID) {
                metadata["documentId"] = sopInstanceUID
            }
            if let sopClassUID = dicomFile.dataSet.string(for: .sopClassUID) {
                metadata["documentType"] = sopClassUID
            }
            
            // Referring physician (author)
            if let referringPhysician = dicomFile.dataSet.string(for: .referringPhysicianName) {
                metadata["author"] = referringPhysician
            }
            
            return metadata
        }
        
        /// Create XDS manifest (simplified)
        static func createManifest(files: [DICOMFile]) -> String {
            var manifest = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            manifest += "<SubmitObjectsRequest xmlns=\"urn:oasis:names:tc:ebxml-regrep:xsd:rim:3.0\">\n"
            manifest += "  <RegistryObjectList>\n"
            
            for (index, file) in files.enumerated() {
                let metadata = extractMetadata(file)
                manifest += "    <ExtrinsicObject id=\"Document\(index)\">\n"
                
                for (key, value) in metadata {
                    manifest += "      <Slot name=\"\(key)\">\n"
                    manifest += "        <ValueList>\n"
                    manifest += "          <Value>\(value)</Value>\n"
                    manifest += "        </ValueList>\n"
                    manifest += "      </Slot>\n"
                }
                
                manifest += "    </ExtrinsicObject>\n"
            }
            
            manifest += "  </RegistryObjectList>\n"
            manifest += "</SubmitObjectsRequest>\n"
            
            return manifest
        }
    }
    
    // MARK: - PIX Profile
    
    /// Patient Identifier Cross-Referencing
    /// Maps patient IDs across different domains
    struct PIX {
        
        /// Cross-reference domains
        struct Domain {
            let id: String
            let name: String
            let assigningAuthority: String
        }
        
        /// Patient identifier with domain
        struct PatientIdentifier {
            let id: String
            let domain: Domain
        }
        
        /// Extract patient identifier from DICOM
        static func extractPatientIdentifier(_ dicomFile: DICOMFile, domain: Domain) -> PatientIdentifier? {
            guard let patientID = dicomFile.dataSet.string(for: .patientID) else {
                return nil
            }
            
            return PatientIdentifier(id: patientID, domain: domain)
        }
        
        /// Create HL7 PIX query message
        static func createPIXQuery(patientID: String, sourceDomain: Domain, targetDomains: [Domain]) -> String {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let messageControlID = UUID().uuidString
            
            var message = "MSH|^~\\&|DICOMKit|GATEWAY|PIX_MGR|HOSPITAL|\(timestamp)||QBP^Q23|\(messageControlID)|P|2.5\r"
            message += "QPD|IHE PIX Query|Q\(messageControlID)|"
            message += "\(patientID)^^^&\(sourceDomain.assigningAuthority)&ISO\r"
            message += "RCP|I\r"
            
            return message
        }
    }
    
    // MARK: - PDQ Profile
    
    /// Patient Demographics Query
    /// Query patient demographics using HL7 messages
    struct PDQ {
        
        /// Demographics query parameters
        struct QueryParameters {
            var patientName: String?
            var patientID: String?
            var birthDate: String?
            var gender: String?
        }
        
        /// Create HL7 PDQ query message
        static func createPDQQuery(params: QueryParameters) -> String {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let messageControlID = UUID().uuidString
            
            var message = "MSH|^~\\&|DICOMKit|GATEWAY|PDQ_MGR|HOSPITAL|\(timestamp)||QBP^Q22|\(messageControlID)|P|2.5\r"
            message += "QPD|IHE PDQ Query|Q\(messageControlID)"
            
            // Add query parameters
            if let name = params.patientName {
                message += "|@PID.5.1^\(name)"
            }
            if let id = params.patientID {
                message += "|@PID.3.1^\(id)"
            }
            if let birthDate = params.birthDate {
                message += "|@PID.7^\(birthDate)"
            }
            if let gender = params.gender {
                message += "|@PID.8^\(gender)"
            }
            
            message += "\r"
            message += "RCP|I|10^RD\r"  // 10 records per page
            
            return message
        }
        
        /// Extract demographics from DICOM for PDQ query
        static func extractQueryParameters(_ dicomFile: DICOMFile) -> QueryParameters {
            return QueryParameters(
                patientName: dicomFile.dataSet.string(for: .patientName),
                patientID: dicomFile.dataSet.string(for: .patientID),
                birthDate: dicomFile.dataSet.string(for: .patientBirthDate),
                gender: dicomFile.dataSet.string(for: .patientSex)
            )
        }
    }
    
    // MARK: - Profile Validator
    
    /// Validate DICOM file against specific IHE profile
    static func validateProfile(_ dicomFile: DICOMFile, profile: Profile) throws -> ValidationResult {
        var result = ValidationResult(profile: profile, compliant: true, issues: [])
        
        switch profile {
        case .pdi:
            let issues = try PDI.validate(dicomFile)
            result.issues = issues
            result.compliant = issues.isEmpty
            
        case .xdsI:
            let metadata = XDSI.extractMetadata(dicomFile)
            if metadata.isEmpty {
                result.compliant = false
                result.issues.append("No XDS metadata could be extracted")
            }
            
        case .pix, .pdq:
            // PIX and PDQ validation primarily applies to HL7 messages
            if dicomFile.dataSet[.patientID] == nil {
                result.compliant = false
                result.issues.append("Patient ID required for PIX/PDQ integration")
            }
            
        case .swd, .iid:
            // These profiles have specific workflow requirements
            result.issues.append("Profile validation not fully implemented")
        }
        
        return result
    }
    
    /// Validation result
    struct ValidationResult {
        let profile: Profile
        var compliant: Bool
        var issues: [String]
        
        var summary: String {
            if compliant {
                return "✓ Compliant with \(profile.rawValue) profile"
            } else {
                return "✗ Not compliant with \(profile.rawValue) profile (\(issues.count) issues)"
            }
        }
    }
}

// MARK: - IHE Extensions

extension IHEProfiles {
    
    /// Get all supported profiles
    static var supportedProfiles: [Profile] {
        return Profile.allCases
    }
    
    /// Get profile by name
    static func profile(named: String) -> Profile? {
        return Profile.allCases.first { $0.rawValue.lowercased() == named.lowercased() }
    }
}
