import Foundation
import DICOMCore
import DICOMKit

/// Storage manager for DICOM files
actor StorageManager {
    private let dataDirectory: String
    private let fileManager = FileManager.default
    
    init(dataDirectory: String) throws {
        self.dataDirectory = dataDirectory
        
        // Create data directory if it doesn't exist
        try fileManager.createDirectory(
            atPath: dataDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// Store a DICOM file
    func store(file: DICOMFile) async throws -> String {
        // Generate file path based on Study/Series/Instance UIDs
        let studyUID = file.dataSet.string(for: .studyInstanceUID) ?? "UNKNOWN_STUDY"
        let seriesUID = file.dataSet.string(for: .seriesInstanceUID) ?? "UNKNOWN_SERIES"
        let instanceUID = file.dataSet.string(for: .sopInstanceUID) ?? UUID().uuidString
        
        // Create directory structure
        let studyPath = "\(dataDirectory)/\(studyUID)"
        let seriesPath = "\(studyPath)/\(seriesUID)"
        
        try fileManager.createDirectory(atPath: studyPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: seriesPath, withIntermediateDirectories: true)
        
        // Write file
        let filePath = "\(seriesPath)/\(instanceUID).dcm"
        let data = try file.write()
        try data.write(to: URL(fileURLWithPath: filePath))
        
        return filePath
    }
    
    /// Store a DICOM dataset
    func storeFile(dataset: DataSet, sopInstanceUID: String) async throws -> String {
        // Generate file path based on Study/Series/Instance UIDs
        let studyUID = dataset.string(for: .studyInstanceUID) ?? "UNKNOWN_STUDY"
        let seriesUID = dataset.string(for: .seriesInstanceUID) ?? "UNKNOWN_SERIES"
        
        // Create directory structure
        let studyPath = "\(dataDirectory)/\(studyUID)"
        let seriesPath = "\(studyPath)/\(seriesUID)"
        
        try fileManager.createDirectory(atPath: studyPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: seriesPath, withIntermediateDirectories: true)
        
        // Write file
        let filePath = "\(seriesPath)/\(sopInstanceUID).dcm"
        let data = dataset.write()
        try data.write(to: URL(fileURLWithPath: filePath))
        
        return filePath
    }
    
    /// Retrieve a DICOM file by SOP Instance UID
    func retrieve(sopInstanceUID: String) async throws -> DICOMFile? {
        // Search for the file
        let filePath = try await findFile(sopInstanceUID: sopInstanceUID)
        guard let path = filePath else {
            return nil
        }
        
        return try DICOMFile.read(from: URL(fileURLWithPath: path))
    }
    
    /// Find a file by SOP Instance UID
    private func findFile(sopInstanceUID: String) async throws -> String? {
        // Scan directories
        guard let enumerator = fileManager.enumerator(atPath: dataDirectory) else {
            return nil
        }
        
        for case let file as String in enumerator {
            if file.hasSuffix(".dcm") {
                let fullPath = "\(dataDirectory)/\(file)"
                
                // Read file and check SOP Instance UID
                do {
                    let dicomFile = try DICOMFile.read(from: URL(fileURLWithPath: fullPath))
                    if dicomFile.dataSet.string(for: .sopInstanceUID) == sopInstanceUID {
                        return fullPath
                    }
                } catch {
                    // Skip files that can't be read
                    continue
                }
            }
        }
        
        return nil
    }
    
    /// Get storage statistics
    func statistics() async throws -> StorageStatistics {
        var totalFiles = 0
        var totalSize: UInt64 = 0
        
        guard let enumerator = fileManager.enumerator(atPath: dataDirectory) else {
            return StorageStatistics(totalFiles: 0, totalSize: 0)
        }
        
        for case let file as String in enumerator {
            if file.hasSuffix(".dcm") {
                totalFiles += 1
                let fullPath = "\(dataDirectory)/\(file)"
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64 {
                    totalSize += size
                }
            }
        }
        
        return StorageStatistics(totalFiles: totalFiles, totalSize: totalSize)
    }
}

/// Storage statistics
struct StorageStatistics: Sendable {
    let totalFiles: Int
    let totalSize: UInt64
    
    var totalSizeMB: Double {
        Double(totalSize) / (1024 * 1024)
    }
}
