import Foundation
import DICOMCore
import DICOMNetwork
// NEMA-verified: 2026a, checked 2026-10-01 — C-STORE response handling diffed against PS3.4 2026a Table B.2-1 (7 rows: Success 0000 stored; Warning B000/B006/B007 stored and reported; Failure A7xx/A9xx/Cxxx not stored, counted as failed) and PS3.7 9.1.1.1.9 (0122 Refused: SOP Class not supported); status text comes from DICOMNetwork.DIMSEStatus

/// How a C-STORE response status is reported, per PS3.4 Table B.2-1: Success
/// (0000) and the Warning class (B000 Coercion of Data Elements, B006 Elements
/// Discarded, B007 Data Set does not match SOP Class) mean the SCP stored the
/// SOP Instance (PS3.7 9.1.1.1.9: "was able to store ... but detected a probable
/// error"); the Failure class (A7xx Refused: Out of resources, A9xx Error: Data
/// Set does not match SOP Class, Cxxx Error: Cannot understand, 0122 Refused:
/// SOP Class not supported) means it was not stored.
enum StoreOutcome: Equatable {
    case stored
    case storedWithWarning
    case failed

    init(status: DIMSEStatus) {
        if status.isSuccess {
            self = .stored
        } else if status.isWarning {
            self = .storedWithWarning
        } else {
            self = .failed
        }
    }
}

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
        var warningCount = 0
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
                if StoreOutcome(status: result.status) == .storedWithWarning {
                    // PS3.4 Table B.2-1 Warning class: stored, but the SCP reports a
                    // deviation (coercion, discarded elements, SOP Class mismatch).
                    warningCount += 1
                    print("    ⚠️ Stored with warning: \(result.status)")
                }

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
        if warningCount > 0 {
            print("  Stored with warning: \(warningCount) (PS3.4 Table B.2-1 Warning class)")
        }

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
    
    /// Sends a single DICOM file to the PACS server. A response in the Failure
    /// class of PS3.4 Table B.2-1 is thrown as ``SendError/storeFailed(_:)`` so the
    /// retry loop and the per-file tally treat it as a failed transfer (the engine
    /// returns such a response as a `StoreResult` rather than throwing).
    private func sendFile(fileData: Data) async throws -> StoreResult {
        let result = try await storeOnce(fileData: fileData)
        if StoreOutcome(status: result.status) == .failed {
            throw SendError.storeFailed(result.status)
        }
        return result
    }

    private func storeOnce(fileData: Data) async throws -> StoreResult {
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
    /// The SCP answered with a status in the Failure class of PS3.4 Table B.2-1.
    case storeFailed(DIMSEStatus)
    
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown error occurred"
        case .partialFailure(let succeeded, let failed):
            return "Send completed with \(succeeded) succeeded and \(failed) failed"
        case .storeFailed(let status):
            return "C-STORE response status \(status) — not stored (PS3.4 Table B.2-1)"
        }
    }
}

#endif
