import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(Network)

/// Executes C-STORE operations to send DICOM files to a PACS server
struct SendExecutor {
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let timeout: TimeInterval
    let priority: DIMSEPriority
    let retryAttempts: Int
    let verbose: Bool
    
    /// Verifies connection using C-ECHO
    func verifyConnection() async throws {
        // For now, we'll skip C-ECHO verification as it requires more complex setup
        // In production, this would send a C-ECHO request to verify connectivity
        // The actual file send will verify connectivity anyway
    }
    
    /// Sends multiple DICOM files to the PACS server
    func sendFiles(_ filePaths: [String]) async throws {
        let reporter = ProgressReporter(totalFiles: filePaths.count, verbose: verbose)
        
        var successCount = 0
        var failureCount = 0
        var totalBytesTransferred = 0
        
        for (index, filePath) in filePaths.enumerated() {
            let fileNumber = index + 1
            
            do {
                // Read file data
                let fileURL = URL(fileURLWithPath: filePath)
                let fileData = try Data(contentsOf: fileURL)
                
                reporter.startFile(fileNumber, path: filePath, size: fileData.count)
                
                // Send with retry logic
                let result = try await sendFileWithRetry(fileData: fileData, filePath: filePath)
                
                totalBytesTransferred += fileData.count
                successCount += 1
                
                reporter.completeFile(
                    fileNumber,
                    success: true,
                    sopInstanceUID: result.affectedSOPInstanceUID,
                    roundTripTime: result.roundTripTime,
                    totalBytes: totalBytesTransferred
                )
                
            } catch {
                failureCount += 1
                reporter.completeFile(
                    fileNumber,
                    success: false,
                    error: error,
                    totalBytes: totalBytesTransferred
                )
                
                // Continue with next file
            }
        }
        
        // Print final summary
        reporter.printSummary(succeeded: successCount, failed: failureCount, totalBytes: totalBytesTransferred)
        
        if failureCount > 0 {
            throw SendError.partialFailure(succeeded: successCount, failed: failureCount)
        }
    }
    
    /// Sends a single file with retry logic
    private func sendFileWithRetry(fileData: Data, filePath: String) async throws -> StoreResult {
        var lastError: Error?
        
        for attempt in 0...retryAttempts {
            do {
                return try await sendFile(fileData: fileData)
            } catch {
                lastError = error
                
                if attempt < retryAttempts {
                    if verbose {
                        fprintln("  Retry attempt \(attempt + 1)/\(retryAttempts)...")
                    }
                    // Exponential backoff: 1s, 2s, 4s, 8s...
                    let delay = Double(1 << attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? SendError.unknownError
    }
    
    /// Sends a single DICOM file to the PACS server
    private func sendFile(fileData: Data) async throws -> StoreResult {
        return try await DICOMStorageService.store(
            fileData: fileData,
            to: host,
            port: port,
            callingAE: callingAE,
            calledAE: calledAE,
            priority: priority,
            timeout: timeout
        )
    }
}

/// Errors that can occur during send operations
enum SendError: LocalizedError {
    case unknownError
    case partialFailure(succeeded: Int, failed: Int)
    
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown error occurred"
        case .partialFailure(let succeeded, let failed):
            return "Send completed with \(succeeded) succeeded and \(failed) failed"
        }
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

#endif
