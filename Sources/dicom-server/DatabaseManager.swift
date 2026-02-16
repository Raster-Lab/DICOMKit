import Foundation
import DICOMCore

/// Database manager for DICOM metadata indexing
actor DatabaseManager {
    private let connectionString: String
    private var patientIndex: [String: [DICOMMetadata]] = [:] // patientID -> metadata
    private var studyIndex: [String: [DICOMMetadata]] = [:] // studyInstanceUID -> metadata
    private var seriesIndex: [String: [DICOMMetadata]] = [:] // seriesInstanceUID -> metadata
    private var instanceIndex: [String: DICOMMetadata] = [:] // sopInstanceUID -> metadata
    
    init(connectionString: String) throws {
        self.connectionString = connectionString
        
        // Validate connection string format
        if !connectionString.hasPrefix("sqlite://") && !connectionString.hasPrefix("postgres://") && !connectionString.isEmpty {
            throw ServerError.databaseError("Unsupported database type in connection string: \(connectionString)")
        }
    }
    
    /// Initialize the database connection
    func initialize() async throws {
        // Parse connection string and initialize
        if connectionString.hasPrefix("sqlite://") {
            try await initializeSQLite()
        } else if connectionString.hasPrefix("postgres://") {
            try await initializePostgreSQL()
        }
        // If empty, use in-memory storage (already initialized)
    }
    
    private func initializeSQLite() async throws {
        // TODO: Initialize SQLite database with schema
        // For Phase A, using in-memory storage
        guard connectionString.hasPrefix("sqlite://") else {
            throw ServerError.databaseError("Invalid SQLite connection string")
        }
    }
    
    private func initializePostgreSQL() async throws {
        // TODO: Initialize PostgreSQL database
        // For Phase A, not implemented
        guard connectionString.hasPrefix("postgres://") else {
            throw ServerError.databaseError("Invalid PostgreSQL connection string")
        }
        throw ServerError.databaseError("PostgreSQL support not yet implemented")
    }
    
    /// Index a DICOM file
    func index(filePath: String, metadata: DICOMMetadata) async throws {
        // Add to instance index
        instanceIndex[metadata.sopInstanceUID] = metadata
        
        // Add to series index
        if let seriesUID = metadata.seriesInstanceUID {
            if seriesIndex[seriesUID] == nil {
                seriesIndex[seriesUID] = []
            }
            seriesIndex[seriesUID]?.append(metadata)
        }
        
        // Add to study index
        if let studyUID = metadata.studyInstanceUID {
            if studyIndex[studyUID] == nil {
                studyIndex[studyUID] = []
            }
            studyIndex[studyUID]?.append(metadata)
        }
        
        // Add to patient index
        if let patientID = metadata.patientID {
            if patientIndex[patientID] == nil {
                patientIndex[patientID] = []
            }
            patientIndex[patientID]?.append(metadata)
        }
    }
    
    /// Query DICOM metadata for C-FIND
    func queryForFind(queryDataset: DataSet, level: String) async throws -> [DataSet] {
        var results: [DataSet] = []
        
        switch level.uppercased() {
        case "PATIENT":
            results = try await queryPatientLevel(queryDataset)
        case "STUDY":
            results = try await queryStudyLevel(queryDataset)
        case "SERIES":
            results = try await querySeriesLevel(queryDataset)
        case "IMAGE", "INSTANCE":
            results = try await queryInstanceLevel(queryDataset)
        default:
            // Unknown level, return empty
            break
        }
        
        return results
    }
    
    /// Query DICOM metadata for C-MOVE/C-GET retrieval
    /// Returns the actual file metadata for instances to be retrieved
    func queryForRetrieve(queryDataset: DataSet, level: String) async throws -> [DICOMMetadata] {
        var instances: [DICOMMetadata] = []
        
        switch level.uppercased() {
        case "PATIENT":
            // Retrieve all instances for matching patients
            let patientID = queryDataset.string(for: .patientID)
            for (pid, metadataList) in patientIndex {
                if let queryPID = patientID, !queryPID.isEmpty {
                    if !matchesWildcard(pid, pattern: queryPID) {
                        continue
                    }
                }
                instances.append(contentsOf: metadataList)
            }
            
        case "STUDY":
            // Retrieve all instances for matching studies
            let studyInstanceUID = queryDataset.string(for: .studyInstanceUID)
            let patientID = queryDataset.string(for: .patientID)
            
            for (suid, metadataList) in studyIndex {
                if let queryUID = studyInstanceUID, !queryUID.isEmpty {
                    if !matchesWildcard(suid, pattern: queryUID) {
                        continue
                    }
                }
                
                // Also check patient ID if specified
                if let queryPID = patientID, !queryPID.isEmpty {
                    if let firstMeta = metadataList.first, let pid = firstMeta.patientID {
                        if !matchesWildcard(pid, pattern: queryPID) {
                            continue
                        }
                    }
                }
                
                instances.append(contentsOf: metadataList)
            }
            
        case "SERIES":
            // Retrieve all instances for matching series
            let seriesInstanceUID = queryDataset.string(for: .seriesInstanceUID)
            let studyInstanceUID = queryDataset.string(for: .studyInstanceUID)
            
            for (seriesUID, metadataList) in seriesIndex {
                if let querySeriesUID = seriesInstanceUID, !querySeriesUID.isEmpty {
                    if !matchesWildcard(seriesUID, pattern: querySeriesUID) {
                        continue
                    }
                }
                
                // Also check study UID if specified
                if let queryStudyUID = studyInstanceUID, !queryStudyUID.isEmpty {
                    if let firstMeta = metadataList.first, let suid = firstMeta.studyInstanceUID {
                        if !matchesWildcard(suid, pattern: queryStudyUID) {
                            continue
                        }
                    }
                }
                
                instances.append(contentsOf: metadataList)
            }
            
        case "IMAGE", "INSTANCE":
            // Retrieve specific matching instances
            let sopInstanceUID = queryDataset.string(for: .sopInstanceUID)
            let seriesInstanceUID = queryDataset.string(for: .seriesInstanceUID)
            
            for (instUID, metadata) in instanceIndex {
                if let queryUID = sopInstanceUID, !queryUID.isEmpty {
                    if !matchesWildcard(instUID, pattern: queryUID) {
                        continue
                    }
                }
                
                // Also check series UID if specified
                if let querySeriesUID = seriesInstanceUID, !querySeriesUID.isEmpty {
                    if let suid = metadata.seriesInstanceUID, !matchesWildcard(suid, pattern: querySeriesUID) {
                        continue
                    }
                }
                
                instances.append(metadata)
            }
            
        default:
            // Unknown level, return empty
            break
        }
        
        return instances
    }
    
    private func queryPatientLevel(_ queryDataset: DataSet) async throws -> [DataSet] {
        let patientID = queryDataset.string(for: .patientID)
        let patientName = queryDataset.string(for: .patientName)
        
        var results: [DataSet] = []
        var processedPatients: Set<String> = []
        
        // Get all patient IDs
        for (pid, metadataList) in patientIndex {
            guard !processedPatients.contains(pid) else { continue }
            
            // Match patient ID if specified
            if let queryPID = patientID, !queryPID.isEmpty {
                if !matchesWildcard(pid, pattern: queryPID) {
                    continue
                }
            }
            
            // Match patient name if specified
            if let queryName = patientName, !queryName.isEmpty {
                if let firstMeta = metadataList.first, let name = firstMeta.patientName {
                    if !matchesWildcard(name, pattern: queryName) {
                        continue
                    }
                }
            }
            
            // Build result dataset
            if let firstMeta = metadataList.first {
                var resultDS = DataSet()
                if let patID = firstMeta.patientID {
                    resultDS.set(string: patID, for: .patientID)
                }
                if let patName = firstMeta.patientName {
                    resultDS.set(string: patName, for: .patientName)
                }
                results.append(resultDS)
                processedPatients.insert(pid)
            }
        }
        
        return results
    }
    
    private func queryStudyLevel(_ queryDataset: DataSet) async throws -> [DataSet] {
        let patientID = queryDataset.string(for: .patientID)
        let studyInstanceUID = queryDataset.string(for: .studyInstanceUID)
        let studyDate = queryDataset.string(for: .studyDate)
        
        var results: [DataSet] = []
        var processedStudies: Set<String> = []
        
        // Iterate through all studies
        for (studyUID, metadataList) in studyIndex {
            guard !processedStudies.contains(studyUID) else { continue }
            
            // Match study instance UID if specified
            if let queryUID = studyInstanceUID, !queryUID.isEmpty {
                if !matchesWildcard(studyUID, pattern: queryUID) {
                    continue
                }
            }
            
            guard let firstMeta = metadataList.first else { continue }
            
            // Match patient ID if specified
            if let queryPID = patientID, !queryPID.isEmpty {
                if let pid = firstMeta.patientID, !matchesWildcard(pid, pattern: queryPID) {
                    continue
                }
            }
            
            // Match study date if specified
            if let queryDate = studyDate, !queryDate.isEmpty {
                if let date = firstMeta.studyDate, !matchesWildcard(date, pattern: queryDate) {
                    continue
                }
            }
            
            // Build result dataset
            var resultDS = DataSet()
            if let pid = firstMeta.patientID {
                resultDS.set(string: pid, for: .patientID)
            }
            if let pname = firstMeta.patientName {
                resultDS.set(string: pname, for: .patientName)
            }
            if let suid = firstMeta.studyInstanceUID {
                resultDS.set(string: suid, for: .studyInstanceUID)
            }
            if let sdate = firstMeta.studyDate {
                resultDS.set(string: sdate, for: .studyDate)
            }
            if let sdesc = firstMeta.studyDescription {
                resultDS.set(string: sdesc, for: .studyDescription)
            }
            results.append(resultDS)
            processedStudies.insert(studyUID)
        }
        
        return results
    }
    
    private func querySeriesLevel(_ queryDataset: DataSet) async throws -> [DataSet] {
        let studyInstanceUID = queryDataset.string(for: .studyInstanceUID)
        let seriesInstanceUID = queryDataset.string(for: .seriesInstanceUID)
        let modality = queryDataset.string(for: .modality)
        
        var results: [DataSet] = []
        var processedSeries: Set<String> = []
        
        for (seriesUID, metadataList) in seriesIndex {
            guard !processedSeries.contains(seriesUID) else { continue }
            
            // Match series instance UID if specified
            if let queryUID = seriesInstanceUID, !queryUID.isEmpty {
                if !matchesWildcard(seriesUID, pattern: queryUID) {
                    continue
                }
            }
            
            guard let firstMeta = metadataList.first else { continue }
            
            // Match study instance UID if specified
            if let queryStudyUID = studyInstanceUID, !queryStudyUID.isEmpty {
                if let suid = firstMeta.studyInstanceUID, !matchesWildcard(suid, pattern: queryStudyUID) {
                    continue
                }
            }
            
            // Match modality if specified
            if let queryModality = modality, !queryModality.isEmpty {
                if let mod = firstMeta.modality, !matchesWildcard(mod, pattern: queryModality) {
                    continue
                }
            }
            
            // Build result dataset
            var resultDS = DataSet()
            if let suid = firstMeta.studyInstanceUID {
                resultDS.set(string: suid, for: .studyInstanceUID)
            }
            if let seuid = firstMeta.seriesInstanceUID {
                resultDS.set(string: seuid, for: .seriesInstanceUID)
            }
            if let snum = firstMeta.seriesNumber {
                resultDS.set(string: snum, for: .seriesNumber)
            }
            if let mod = firstMeta.modality {
                resultDS.set(string: mod, for: .modality)
            }
            results.append(resultDS)
            processedSeries.insert(seriesUID)
        }
        
        return results
    }
    
    private func queryInstanceLevel(_ queryDataset: DataSet) async throws -> [DataSet] {
        let seriesInstanceUID = queryDataset.string(for: .seriesInstanceUID)
        let sopInstanceUID = queryDataset.string(for: .sopInstanceUID)
        
        var results: [DataSet] = []
        
        for (instUID, metadata) in instanceIndex {
            // Match SOP instance UID if specified
            if let queryUID = sopInstanceUID, !queryUID.isEmpty {
                if !matchesWildcard(instUID, pattern: queryUID) {
                    continue
                }
            }
            
            // Match series instance UID if specified
            if let querySeriesUID = seriesInstanceUID, !querySeriesUID.isEmpty {
                if let suid = metadata.seriesInstanceUID, !matchesWildcard(suid, pattern: querySeriesUID) {
                    continue
                }
            }
            
            // Build result dataset
            var resultDS = DataSet()
            if let suid = metadata.seriesInstanceUID {
                resultDS.set(string: suid, for: .seriesInstanceUID)
            }
            resultDS.set(string: metadata.sopInstanceUID, for: .sopInstanceUID)
            if let scuid = metadata.sopClassUID {
                resultDS.set(string: scuid, for: .sopClassUID)
            }
            if let inum = metadata.instanceNumber {
                resultDS.set(string: inum, for: .instanceNumber)
            }
            results.append(resultDS)
        }
        
        return results
    }
    
    /// Simple wildcard matching (* and ?)
    private func matchesWildcard(_ string: String, pattern: String) -> Bool {
        // If pattern has no wildcards, do exact match
        if !pattern.contains("*") && !pattern.contains("?") {
            return string == pattern
        }
        
        // Convert DICOM wildcard (* and ?) to regex
        var regexPattern = "^"
        for char in pattern {
            switch char {
            case "*":
                regexPattern += ".*"
            case "?":
                regexPattern += "."
            default:
                regexPattern += NSRegularExpression.escapedPattern(for: String(char))
            }
        }
        regexPattern += "$"
        
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) else {
            return false
        }
        
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
    
    /// Delete DICOM metadata
    func delete(sopInstanceUID: String) async throws {
        if let metadata = instanceIndex[sopInstanceUID] {
            // Remove from all indices
            instanceIndex.removeValue(forKey: sopInstanceUID)
            
            if let seriesUID = metadata.seriesInstanceUID {
                seriesIndex[seriesUID]?.removeAll { $0.sopInstanceUID == sopInstanceUID }
            }
            
            if let studyUID = metadata.studyInstanceUID {
                studyIndex[studyUID]?.removeAll { $0.sopInstanceUID == sopInstanceUID }
            }
            
            if let patientID = metadata.patientID {
                patientIndex[patientID]?.removeAll { $0.sopInstanceUID == sopInstanceUID }
            }
        }
    }
}

/// DICOM metadata for database indexing
struct DICOMMetadata: Sendable, Codable {
    let patientID: String?
    let patientName: String?
    let studyInstanceUID: String?
    let studyDate: String?
    let studyDescription: String?
    let seriesInstanceUID: String?
    let seriesNumber: String?
    let modality: String?
    let sopInstanceUID: String
    let sopClassUID: String?
    let instanceNumber: String?
    let filePath: String
}
