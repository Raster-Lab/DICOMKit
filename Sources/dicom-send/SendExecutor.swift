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
    let preferredTransferSyntaxUID: String?
    
    /// Verifies connection using a real C-ECHO before sending (matches the in-app
    /// dicom-send, which calls the same DICOMVerificationService.echo).
    func verifyConnection() async throws {
        let result = try await DICOMVerificationService.echo(
            host: host, port: port, callingAE: callingAE, calledAE: calledAE, timeout: timeout)
        guard result.success else {
            throw DICOMNetworkError.connectionFailed(
                "C-ECHO verification returned a non-success status: \(result.status)")
        }
    }
    
    /// Sends multiple DICOM files to the PACS server. All progress/summary text is
    /// rendered through the SHARED NetworkConsole formatter (DICOMNetwork) and printed
    /// to STDOUT, so the output is byte-identical to DICOMStudio's in-process send.
    func sendFiles(_ filePaths: [String]) async throws {
        var successCount = 0
        var failureCount = 0
        var totalBytesTransferred = 0
        let startTime = Date()

        for (index, filePath) in filePaths.enumerated() {
            let fileNumber = index + 1
            let filename = (filePath as NSString).lastPathComponent

            do {
                // Read file data
                let fileURL = URL(fileURLWithPath: filePath)
                let fileData = try Data(contentsOf: fileURL)

                print(NetworkConsole.sendFilePrefix(
                    index: fileNumber, total: filePaths.count,
                    filename: filename, size: fileData.count), terminator: "")
                fflush(stdout)

                // Send with retry logic
                let result = try await sendFileWithRetry(fileData: fileData, filePath: filePath)

                totalBytesTransferred += fileData.count
                successCount += 1

                print(NetworkConsole.sendFileResultSuffix(
                    success: true, rtt: result.roundTripTime, error: nil), terminator: "")

            } catch {
                failureCount += 1
                print(NetworkConsole.sendFileResultSuffix(
                    success: false, rtt: 0, error: error.localizedDescription), terminator: "")
                // Continue with next file
            }
        }

        // Print final summary
        print(NetworkConsole.sendSummary(
            total: filePaths.count, succeeded: successCount, failed: failureCount,
            bytes: totalBytesTransferred, duration: Date().timeIntervalSince(startTime)),
            terminator: "")

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
                    // No per-attempt chatter: retries are failure-driven and
                    // non-deterministic, so any retry line would diverge between the
                    // CLI and in-app runs. Only the final outcome line is emitted.
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
        if let preferredTransferSyntaxUID, !preferredTransferSyntaxUID.isEmpty {
            return try await DICOMStorageService.store(
                fileData: fileData,
                preferredTransferSyntaxUID: preferredTransferSyntaxUID,
                to: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                priority: priority,
                timeout: timeout
            )
        }

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

#endif
