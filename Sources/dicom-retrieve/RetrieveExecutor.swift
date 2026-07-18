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
    let preferredTransferSyntaxUID: String?
    
    /// Retrieves a study from PACS
    func retrieveStudy(studyUID: String, method: RetrievalMethod) async throws {
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
        // Intermediate progress is suppressed: the count/cadence of C-MOVE progress
        // messages depends on SCP pacing and differs between two associations, so it
        // can't be compared. Only the deterministic final result is rendered.
        let onProgress: @Sendable (RetrieveProgress) -> Void = { _ in }

        let result: RetrieveResult
        
        if let sopUID = sopUID, let seriesUID = seriesUID {
            // Instance level
            result = try await DICOMRetrieveService.moveInstance(
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
            result = try await DICOMRetrieveService.moveSeries(
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
            result = try await DICOMRetrieveService.moveStudy(
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
        
        // C-MOVE result via the SHARED formatter, printed to STDOUT (always).
        print(NetworkConsole.cMoveResult(
            status: "\(result.status)",
            completed: result.progress.completed,
            failed: result.progress.failed,
            warning: result.progress.warning,
            isSuccess: result.isSuccess), terminator: "")

        if !result.isSuccess {
            throw RetrieveError.retrievalFailed(status: result.status)
        }
    }
    
    // MARK: - C-GET Implementation
    
    private func performCGet(studyUID: String, seriesUID: String?, sopUID: String?) async throws {
        let stream: AsyncStream<DICOMRetrieveService.GetEvent>
        
        if let sopUID = sopUID, let seriesUID = seriesUID {
            // Instance level
            stream = try await DICOMRetrieveService.getInstance(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                sopInstanceUID: sopUID,
                preferredTransferSyntaxUID: preferredTransferSyntaxUID,
                timeout: timeout
            )
        } else if let seriesUID = seriesUID {
            // Series level
            stream = try await DICOMRetrieveService.getSeries(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                preferredTransferSyntaxUID: preferredTransferSyntaxUID,
                timeout: timeout
            )
        } else {
            // Study level
            stream = try await DICOMRetrieveService.getStudy(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                preferredTransferSyntaxUID: preferredTransferSyntaxUID,
                timeout: timeout
            )
        }
        
        var filesReceived = 0
        var finalResult: RetrieveResult?

        for await event in stream {
            switch event {
            case .progress:
                // Suppressed: progress cadence is SCP-dependent and differs run-to-run.
                break

            case .instance(let sopInstanceUID, let sopClassUID, let transferSyntaxUID, let data):
                // Save received instance to disk as a proper Part 10 file. Per-instance
                // lines are NOT printed: the SCP's send order is not guaranteed stable
                // across associations, so they would diff positionally. Only the
                // deterministic received count is reported in the summary.
                try saveInstance(
                    sopInstanceUID: sopInstanceUID,
                    sopClassUID: sopClassUID,
                    transferSyntaxUID: transferSyntaxUID,
                    data: data,
                    studyUID: studyUID,
                    seriesUID: seriesUID
                )
                filesReceived += 1

            case .completed(let result):
                finalResult = result

            case .error(let error):
                throw error
            }
        }

        // C-GET summary via the SHARED formatter (handles the 0-instances warning).
        print(NetworkConsole.cGetSummary(received: filesReceived), terminator: "")

        if let result = finalResult, !result.isSuccess {
            throw RetrieveError.retrievalFailed(status: result.status)
        }
    }

    // MARK: - File Management
    
    private func saveInstance(
        sopInstanceUID: String,
        sopClassUID: String,
        transferSyntaxUID: String,
        data: Data,
        studyUID: String,
        seriesUID: String?
    ) throws {
        let filename = "\(sopInstanceUID).dcm"
        let filepath: String

        // For a study-level C-GET the caller has no series UID, so recover it from the
        // received dataset itself; otherwise --hierarchical would collapse to a flat dump.
        // If it can't be recovered we fall back to flat layout (the prior behavior).
        let effectiveSeriesUID = seriesUID
            ?? Self.extractSeriesUID(fromDataSet: data, transferSyntaxUID: transferSyntaxUID)

        if hierarchical, let series = effectiveSeriesUID {
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
        
        // Wrap raw dataset in Part 10 container (preamble + DICM magic + File Meta)
        let part10 = buildPart10(dataset: data, sopClassUID: sopClassUID,
                                  sopInstanceUID: sopInstanceUID,
                                  transferSyntaxUID: transferSyntaxUID)
        try part10.write(to: URL(fileURLWithPath: filepath))
    }
    
    // MARK: - Series UID recovery

    /// Best-effort scan of a raw C-GET dataset for SeriesInstanceUID (0020,000E).
    ///
    /// Handles Explicit and Implicit VR Little Endian (which covers every transfer
    /// syntax a C-GET yields — encapsulated pixel data still uses Explicit VR LE for
    /// the surrounding data set). Returns `nil` on anything it can't confidently parse
    /// (undefined-length sequences, big endian, truncation) so callers fall back to a
    /// flat layout rather than misfiling. Never traps: every read is bounds-checked.
    static func extractSeriesUID(fromDataSet data: Data, transferSyntaxUID: String) -> String? {
        // Re-base to guarantee 0-based indexing (the dataset may arrive as a slice).
        let bytes = Data(data)
        let implicitVR = (transferSyntaxUID == "1.2.840.10008.1.2")
        // VRs that carry a 2-byte reserved field + 4-byte length in Explicit VR.
        let longFormVRs: Set<String> = ["OB", "OW", "OF", "OD", "OL", "SQ", "UT", "UN", "UC", "UR"]

        var offset = 0
        while offset + 8 <= bytes.count {
            guard let group = bytes.readUInt16LE(at: offset),
                  let element = bytes.readUInt16LE(at: offset + 2) else { return nil }

            // Elements are ordered by (group, element); once we pass 0020,000E it's absent.
            if group > 0x0020 || (group == 0x0020 && element > 0x000E) { return nil }

            let valueLength: Int
            let valueOffset: Int
            if implicitVR {
                guard let len = bytes.readUInt32LE(at: offset + 4) else { return nil }
                valueLength = Int(len)
                valueOffset = offset + 8
            } else {
                let vr = String(decoding: bytes[offset + 4 ..< offset + 6], as: UTF8.self)
                if longFormVRs.contains(vr) {
                    guard offset + 12 <= bytes.count,
                          let len = bytes.readUInt32LE(at: offset + 8) else { return nil }
                    valueLength = Int(len)
                    valueOffset = offset + 12
                } else {
                    guard let len = bytes.readUInt16LE(at: offset + 6) else { return nil }
                    valueLength = Int(len)
                    valueOffset = offset + 8
                }
            }

            // Undefined length (sequences/encapsulated) — can't skip reliably here.
            if valueLength == 0xFFFF_FFFF { return nil }
            guard valueOffset + valueLength <= bytes.count else { return nil }

            if group == 0x0020 && element == 0x000E {
                let raw = bytes[valueOffset ..< valueOffset + valueLength]
                let uid = String(decoding: raw, as: UTF8.self)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
                return uid.isEmpty ? nil : uid
            }

            offset = valueOffset + valueLength
        }
        return nil
    }

    // MARK: - Part 10 file wrapper

    /// Wraps raw C-GET/C-STORE dataset bytes in a DICOM Part 10 container.
    private func buildPart10(dataset: Data,
                              sopClassUID: String,
                              sopInstanceUID: String,
                              transferSyntaxUID: String) -> Data {
        func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func le32(_ v: UInt32) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                                               UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]) }
        func ulElem(_ g: UInt16, _ e: UInt16, _ val: UInt32) -> Data {
            le16(g) + le16(e) + Data([0x55, 0x4C]) + le16(4) + le32(val)
        }
        func obElem(_ g: UInt16, _ e: UInt16, _ val: Data) -> Data {
            le16(g) + le16(e) + Data([0x4F, 0x42, 0x00, 0x00]) + le32(UInt32(val.count)) + val
        }
        func uiElem(_ g: UInt16, _ e: UInt16, _ val: String) -> Data {
            var b = val.data(using: .ascii) ?? Data()
            if b.count % 2 != 0 { b.append(0x00) }
            return le16(g) + le16(e) + Data([0x55, 0x49]) + le16(UInt16(b.count)) + b
        }

        var meta = Data()
        meta += obElem(0x0002, 0x0001, Data([0x00, 0x01]))
        meta += uiElem(0x0002, 0x0002, sopClassUID)
        meta += uiElem(0x0002, 0x0003, sopInstanceUID)
        meta += uiElem(0x0002, 0x0010, transferSyntaxUID)
        meta += uiElem(0x0002, 0x0012, "1.2.826.0.1.3680043.9.7433.1.1")

        var file = Data(repeating: 0, count: 128)            // preamble
        file += Data([0x44, 0x49, 0x43, 0x4D])               // DICM
        file += ulElem(0x0002, 0x0000, UInt32(meta.count))   // group length
        file += meta
        file += dataset
        return file
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
