import Foundation

/// Database manager for DICOM metadata indexing
actor DatabaseManager {
    private let connectionString: String
    
    init(connectionString: String) throws {
        self.connectionString = connectionString
        
        // Validate connection string format
        if !connectionString.hasPrefix("sqlite://") && !connectionString.hasPrefix("postgres://") {
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
    }
    
    private func initializeSQLite() async throws {
        // TODO: Initialize SQLite database
        // For now, just validate the connection string
        guard connectionString.hasPrefix("sqlite://") else {
            throw ServerError.databaseError("Invalid SQLite connection string")
        }
    }
    
    private func initializePostgreSQL() async throws {
        // TODO: Initialize PostgreSQL database
        // For now, just validate the connection string
        guard connectionString.hasPrefix("postgres://") else {
            throw ServerError.databaseError("Invalid PostgreSQL connection string")
        }
    }
    
    /// Index a DICOM file
    func index(filePath: String, metadata: DICOMMetadata) async throws {
        // TODO: Implement database indexing
    }
    
    /// Query DICOM metadata
    func query(level: String, keys: [String: String]) async throws -> [DICOMMetadata] {
        // TODO: Implement database queries
        return []
    }
    
    /// Delete DICOM metadata
    func delete(sopInstanceUID: String) async throws {
        // TODO: Implement deletion
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
