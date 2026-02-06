import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(Network)

/// Executes C-MOVE and C-GET operations to retrieve DICOM files from a PACS server
struct RetrieveExecutor {
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let moveDestination: String?
    let timeout: TimeInterval
    let outputPath: String
    let hierarchical: Bool
    let verbose: Bool
    
    /// Retrieves a study from PACS
    func retrieveStudy(studyUID: String, method: RetrievalMethod) async throws {
        if verbose {
            fprintln("Retrieving study: \(studyUID)")
        }
        
        switch method {
        case .cMove:
            guard let dest = moveDestination else {
                throw RetrieveError.missingMoveDestination
            }
            try await performCMove(studyUID: studyUID, seriesUID: nil, sopUID: nil, destination: dest)
        case .cGet:
            try await performCGet(studyUID: studyUID, seriesUID: nil, sopUID: nil)
        }
    }
    
    /// Retrieves a series from PACS
    func retrieveSeries(studyUID: String, seriesUID: String, method: RetrievalMethod) async throws {
        if verbose {
            fprintln("Retrieving series: \(seriesUID) from study: \(studyUID)")
        }
        
        switch method {
        case .cMove:
            guard let dest = moveDestination else {
                throw RetrieveError.missingMoveDestination
            }
            try await performCMove(studyUID: studyUID, seriesUID: seriesUID, sopUID: nil, destination: dest)
        case .cGet:
            try await performCGet(studyUID: studyUID, seriesUID: seriesUID, sopUID: nil)
        }
    }
    
    /// Retrieves an instance from PACS
    func retrieveInstance(studyUID: String, seriesUID: String, sopUID: String, method: RetrievalMethod) async throws {
        if verbose {
            fprintln("Retrieving instance: \(sopUID)")
        }
        
        switch method {
        case .cMove:
            guard let dest = moveDestination else {
                throw RetrieveError.missingMoveDestination
            }
            try await performCMove(studyUID: studyUID, seriesUID: seriesUID, sopUID: sopUID, destination: dest)
        case .cGet:
            try await performCGet(studyUID: studyUID, seriesUID: seriesUID, sopUID: sopUID)
        }
    }
    
    /// Retrieves multiple studies in bulk
    func retrieveBulk(studyUIDs: [String], method: RetrievalMethod, parallelism: Int) async throws {
        if verbose {
            fprintln("Bulk retrieving \(studyUIDs.count) studies with parallelism: \(parallelism)")
        }
        
        var successCount = 0
        var failureCount = 0
        
        // Process in batches based on parallelism
        for batch in studyUIDs.chunked(into: parallelism) {
            await withTaskGroup(of: Result<Void, Error>.self) { group in
                for studyUID in batch {
                    group.addTask {
                        do {
                            try await self.retrieveStudy(studyUID: studyUID, method: method)
                            return .success(())
                        } catch {
                            return .failure(error)
                        }
                    }
                }
                
                for await result in group {
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        if verbose {
                            fprintln("Failed to retrieve study: \(error)")
                        }
                    }
                }
            }
        }
        
        fprintln("\nBulk retrieval complete:")
        fprintln("  Success: \(successCount)")
        fprintln("  Failed: \(failureCount)")
        
        if failureCount > 0 {
            throw RetrieveError.partialFailure(succeeded: successCount, failed: failureCount)
        }
    }
    
    // MARK: - C-MOVE Implementation
    
    private func performCMove(studyUID: String, seriesUID: String?, sopUID: String?, destination: String) async throws {
        let onProgress: (RetrieveProgress) -> Void = { progress in
            if self.verbose {
                fprintln("  Progress: \(progress.completed)/\(progress.total) completed, \(progress.failed) failed, \(progress.remaining) remaining")
            }
        }
        
        let result: RetrieveResult
        
        if let sopUID = sopUID, let seriesUID = seriesUID {
            // Instance level
            result = try await RetrieveService.moveInstance(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                sopInstanceUID: sopUID,
                moveDestination: destination,
                onProgress: onProgress,
                timeout: timeout
            )
        } else if let seriesUID = seriesUID {
            // Series level
            result = try await RetrieveService.moveSeries(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                moveDestination: destination,
                onProgress: onProgress,
                timeout: timeout
            )
        } else {
            // Study level
            result = try await RetrieveService.moveStudy(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                moveDestination: destination,
                onProgress: onProgress,
                timeout: timeout
            )
        }
        
        if verbose || !result.isSuccess {
            fprintln("\nC-MOVE Result:")
            fprintln("  Status: \(result.status)")
            fprintln("  Completed: \(result.progress.completed)")
            fprintln("  Failed: \(result.progress.failed)")
            fprintln("  Warnings: \(result.progress.warning)")
        }
        
        if !result.isSuccess {
            throw RetrieveError.retrievalFailed(status: result.status)
        }
    }
    
    // MARK: - C-GET Implementation
    
    private func performCGet(studyUID: String, seriesUID: String?, sopUID: String?) async throws {
        let stream: AsyncStream<GetEvent>
        
        if let sopUID = sopUID, let seriesUID = seriesUID {
            // Instance level
            stream = try await RetrieveService.getInstance(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                sopInstanceUID: sopUID,
                timeout: timeout
            )
        } else if let seriesUID = seriesUID {
            // Series level
            stream = try await RetrieveService.getSeries(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                timeout: timeout
            )
        } else {
            // Study level
            stream = try await RetrieveService.getStudy(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                timeout: timeout
            )
        }
        
        var filesReceived = 0
        var totalBytes = 0
        
        for await event in stream {
            switch event {
            case .progress(let progress):
                if verbose {
                    fprintln("  Progress: \(progress.completed)/\(progress.total) completed, \(progress.failed) failed, \(progress.remaining) remaining")
                }
                
            case .instance(let sopInstanceUID, let sopClassUID, let data):
                // Save received instance to disk
                try saveInstance(
                    sopInstanceUID: sopInstanceUID,
                    sopClassUID: sopClassUID,
                    data: data,
                    studyUID: studyUID,
                    seriesUID: seriesUID
                )
                
                filesReceived += 1
                totalBytes += data.count
                
                if verbose {
                    fprintln("  Received instance: \(sopInstanceUID) (\(formatBytes(data.count)))")
                }
                
            case .completed(let result):
                if verbose {
                    fprintln("\nC-GET Completed:")
                    fprintln("  Files received: \(filesReceived)")
                    fprintln("  Total size: \(formatBytes(totalBytes))")
                    fprintln("  Status: \(result.status)")
                    fprintln("  Completed: \(result.progress.completed)")
                    fprintln("  Failed: \(result.progress.failed)")
                }
                
                if !result.isSuccess {
                    throw RetrieveError.retrievalFailed(status: result.status)
                }
                
            case .error(let error):
                throw error
            }
        }
    }
    
    // MARK: - File Management
    
    private func saveInstance(
        sopInstanceUID: String,
        sopClassUID: String,
        data: Data,
        studyUID: String,
        seriesUID: String?
    ) throws {
        let filename = "\(sopInstanceUID).dcm"
        let filepath: String
        
        if hierarchical, let series = seriesUID {
            // Organize as study/series/instance
            let studyDir = (outputPath as NSString).appendingPathComponent(studyUID)
            let seriesDir = (studyDir as NSString).appendingPathComponent(series)
            
            // Create directories if needed
            try FileManager.default.createDirectory(
                atPath: seriesDir,
                withIntermediateDirectories: true
            )
            
            filepath = (seriesDir as NSString).appendingPathComponent(filename)
        } else {
            // Flat organization
            filepath = (outputPath as NSString).appendingPathComponent(filename)
        }
        
        // Write file
        try data.write(to: URL(fileURLWithPath: filepath))
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024.0 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Errors

enum RetrieveError: Error, CustomStringConvertible {
    case missingMoveDestination
    case retrievalFailed(status: DIMSEStatus)
    case partialFailure(succeeded: Int, failed: Int)
    
    var description: String {
        switch self {
        case .missingMoveDestination:
            return "C-MOVE requires a move destination AE title"
        case .retrievalFailed(let status):
            return "Retrieval failed with status: \(status)"
        case .partialFailure(let succeeded, let failed):
            return "Bulk retrieval partially failed: \(succeeded) succeeded, \(failed) failed"
        }
    }
}

// MARK: - Utilities

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

#endif
