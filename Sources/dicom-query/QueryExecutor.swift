import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(Network)

/// Executes C-FIND queries against a DICOM PACS server
struct QueryExecutor {
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let timeout: TimeInterval
    
    /// Executes a C-FIND query and returns results
    func executeQuery(level: QueryLevel, queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = try buildConfiguration()
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func buildConfiguration() throws -> QueryConfiguration {
        return QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
    }
}

#endif
