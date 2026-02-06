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
        switch level {
        case .patient:
            return try await queryPatients(queryKeys: queryKeys)
        case .study:
            return try await queryStudies(queryKeys: queryKeys)
        case .series:
            return try await querySeries(queryKeys: queryKeys)
        case .image:
            return try await queryInstances(queryKeys: queryKeys)
        }
    }
    
    // MARK: - Private Query Methods
    
    private func queryPatients(queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    private func queryStudies(queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    private func querySeries(queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    private func queryInstances(queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
}

#endif
