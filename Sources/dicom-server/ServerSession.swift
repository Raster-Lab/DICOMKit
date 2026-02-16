import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(Network)
import Network

/// Server session handling a single client connection
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
actor ServerSession {
    let id: UUID
    private let connection: NWConnection
    private let configuration: ServerConfiguration
    private let storage: StorageManager
    private let database: DatabaseManager?
    private var isActive = false
    private var messageAssembler: MessageAssembler
    private var acceptedPresentationContexts: [UInt8: AcceptedContext] = [:]
    private var messageIDCounter: UInt16 = 0
    
    init(
        id: UUID,
        connection: NWConnection,
        configuration: ServerConfiguration,
        storage: StorageManager,
        database: DatabaseManager?
    ) {
        self.id = id
        self.connection = connection
        self.configuration = configuration
        self.storage = storage
        self.database = database
        self.messageAssembler = MessageAssembler()
    }
    
    /// Accepted presentation context
    struct AcceptedContext {
        let abstractSyntax: String
        let transferSyntax: String
    }
    
    /// Start the session
    func start() async {
        isActive = true
        
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionState(state)
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
        
        // Handle incoming messages
        await receiveLoop()
    }
    
    /// Cancel the session
    func cancel() async {
        isActive = false
        connection.cancel()
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            if configuration.verbose {
                print("[ServerSession \(id)] Connection ready")
            }
        case .failed(let error):
            if configuration.verbose {
                print("[ServerSession \(id)] Connection failed: \(error)")
            }
            Task { await self.cancel() }
        case .cancelled:
            if configuration.verbose {
                print("[ServerSession \(id)] Connection cancelled")
            }
            Task { await self.cancel() }
        default:
            break
        }
    }
    
    private func receiveLoop() async {
        while isActive {
            do {
                // Receive PDU header (first 6 bytes)
                guard let headerData = try await receive(minimumLength: 6, maximumLength: 6) else {
                    break
                }
                
                // Parse PDU type and length
                let pduType = headerData[0]
                let pduLength = UInt32(headerData[2]) << 24 |
                                UInt32(headerData[3]) << 16 |
                                UInt32(headerData[4]) << 8 |
                                UInt32(headerData[5])
                
                // Receive PDU body
                guard let bodyData = try await receive(minimumLength: Int(pduLength), maximumLength: Int(pduLength)) else {
                    break
                }
                
                // Handle PDU
                try await handlePDU(type: pduType, data: bodyData)
                
            } catch {
                if configuration.verbose {
                    print("[ServerSession \(id)] Error in receive loop: \(error)")
                }
                break
            }
        }
        
        await cancel()
    }
    
    private func receive(minimumLength: Int, maximumLength: Int) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: minimumLength, maximumLength: maximumLength) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
    
    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    private func handlePDU(type: UInt8, data: Data) async throws {
        switch type {
        case 0x01: // A-ASSOCIATE-RQ
            try await handleAssociationRequest(data)
        case 0x02: // A-ASSOCIATE-AC
            // Not expected from client
            if configuration.verbose {
                print("[ServerSession \(id)] Unexpected A-ASSOCIATE-AC from client")
            }
        case 0x03: // A-ASSOCIATE-RJ
            // Not expected from client
            if configuration.verbose {
                print("[ServerSession \(id)] Unexpected A-ASSOCIATE-RJ from client")
            }
        case 0x04: // P-DATA-TF
            try await handlePData(data)
        case 0x05: // A-RELEASE-RQ
            try await handleReleaseRequest()
        case 0x06: // A-RELEASE-RP
            // Not expected from client
            if configuration.verbose {
                print("[ServerSession \(id)] Unexpected A-RELEASE-RP from client")
            }
        case 0x07: // A-ABORT
            await cancel()
        default:
            if configuration.verbose {
                print("[ServerSession \(id)] Unknown PDU type: 0x\(String(format: "%02X", type))")
            }
        }
    }
    
    private func handleAssociationRequest(_ data: Data) async throws {
        if configuration.verbose {
            print("[ServerSession \(id)] Received A-ASSOCIATE-RQ")
        }
        
        // Decode the full PDU
        var fullPDU = Data()
        fullPDU.append(0x01) // PDU type
        fullPDU.append(0x00) // Reserved
        fullPDU.append(contentsOf: withUnsafeBytes(of: UInt32(data.count).bigEndian) { Array($0) })
        fullPDU.append(data)
        
        do {
            let pdu = try PDUDecoder.decode(from: fullPDU) as! AssociateRequestPDU
            
            // Validate calling AE Title if configured
            if let allowed = configuration.allowedCallingAETitles, !allowed.isEmpty {
                let callingAE = pdu.callingAETitle.trimmingCharacters(in: .whitespaces)
                if !allowed.contains(callingAE) {
                    if configuration.verbose {
                        print("[ServerSession \(id)] Rejected: Calling AE '\(callingAE)' not in whitelist")
                    }
                    try await sendAssociationReject(result: 1, source: 1, reason: 3)
                    await cancel()
                    return
                }
            }
            
            // Check blocked AE Titles
            if let blocked = configuration.blockedCallingAETitles, !blocked.isEmpty {
                let callingAE = pdu.callingAETitle.trimmingCharacters(in: .whitespaces)
                if blocked.contains(callingAE) {
                    if configuration.verbose {
                        print("[ServerSession \(id)] Rejected: Calling AE '\(callingAE)' is blocked")
                    }
                    try await sendAssociationReject(result: 1, source: 1, reason: 3)
                    await cancel()
                    return
                }
            }
            
            // Build association accept with negotiated presentation contexts
            try await sendAssociationAccept(requestPDU: pdu)
            
            if configuration.verbose {
                print("[ServerSession \(id)] Sent A-ASSOCIATE-AC")
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error decoding A-ASSOCIATE-RQ: \(error)")
            }
            try await sendAssociationReject(result: 2, source: 2, reason: 1)
            await cancel()
        }
    }
    
    private func sendAssociationReject(result: UInt8, source: UInt8, reason: UInt8) async throws {
        var data = Data()
        data.append(0x03) // PDU type: A-ASSOCIATE-RJ
        data.append(0x00) // Reserved
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04]) // Length: 4
        data.append(0x00) // Reserved
        data.append(result)
        data.append(source)
        data.append(reason)
        try await send(data)
    }
    
    private func sendAssociationAccept(requestPDU: AssociateRequestPDU) async throws {
        var contexts: [PresentationContextAccept] = []
        
        // Negotiate each presentation context
        for pc in requestPDU.presentationContexts {
            let abstractSyntax = pc.abstractSyntax
            
            // Check if we support this SOP Class
            let isSupported = isSupportedSOPClass(abstractSyntax)
            
            if isSupported {
                // Find a supported transfer syntax
                if let transferSyntax = findSupportedTransferSyntax(from: pc.transferSyntaxes) {
                    // Accept this context
                    contexts.append(PresentationContextAccept(
                        id: pc.id,
                        result: 0, // Acceptance
                        transferSyntax: transferSyntax
                    ))
                    acceptedPresentationContexts[pc.id] = AcceptedContext(
                        abstractSyntax: abstractSyntax,
                        transferSyntax: transferSyntax
                    )
                    
                    if configuration.verbose {
                        print("[ServerSession \(id)] Accepted context \(pc.id): \(abstractSyntax)")
                    }
                } else {
                    // Transfer syntax not supported
                    contexts.append(PresentationContextAccept(
                        id: pc.id,
                        result: 4, // Transfer syntax not supported
                        transferSyntax: ""
                    ))
                }
            } else {
                // Abstract syntax not supported
                contexts.append(PresentationContextAccept(
                    id: pc.id,
                    result: 3, // Abstract syntax not supported
                    transferSyntax: ""
                ))
            }
        }
        
        // Build A-ASSOCIATE-AC PDU
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: configuration.aeTitle,
            callingAETitle: requestPDU.callingAETitle,
            applicationContextName: "1.2.840.10008.3.1.1.1",
            presentationContextAccepts: contexts,
            implementationClassUID: "1.2.826.0.1.3680043.9.7433.1.2",
            implementationVersionName: "DICOMKIT_SCP"
        )
        
        let data = try acceptPDU.encode()
        try await send(data)
    }
    
    private func isSupportedSOPClass(_ uid: String) -> Bool {
        // Support common storage SOP Classes and verification
        let supportedClasses: Set<String> = [
            "1.2.840.10008.1.1", // Verification
            "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
            "1.2.840.10008.5.1.4.1.1.4", // MR Image Storage
            "1.2.840.10008.5.1.4.1.1.1", // CR Image Storage
            "1.2.840.10008.5.1.4.1.1.7", // Secondary Capture Image Storage
            "1.2.840.10008.5.1.4.1.1.128", // PET Image Storage
            "1.2.840.10008.5.1.4.1.2.1.1", // Patient Root Q/R - FIND
            "1.2.840.10008.5.1.4.1.2.2.1", // Study Root Q/R - FIND
            "1.2.840.10008.5.1.4.1.2.1.2", // Patient Root Q/R - MOVE
            "1.2.840.10008.5.1.4.1.2.2.2", // Study Root Q/R - MOVE
            "1.2.840.10008.5.1.4.1.2.1.3", // Patient Root Q/R - GET
            "1.2.840.10008.5.1.4.1.2.2.3", // Study Root Q/R - GET
        ]
        return supportedClasses.contains(uid)
    }
    
    private func findSupportedTransferSyntax(from syntaxes: [String]) -> String? {
        // Prefer explicit VR little endian, then implicit VR
        let preferredOrder: [String] = [
            "1.2.840.10008.1.2.1", // Explicit VR Little Endian
            "1.2.840.10008.1.2",   // Implicit VR Little Endian
            "1.2.840.10008.1.2.2", // Explicit VR Big Endian
        ]
        
        for syntax in preferredOrder {
            if syntaxes.contains(syntax) {
                return syntax
            }
        }
        
        return nil
    }
    
    private func handlePData(_ data: Data) async throws {
        if configuration.verbose {
            print("[ServerSession \(id)] Received P-DATA-TF (\(data.count) bytes)")
        }
        
        // Decode P-DATA-TF PDU
        var fullPDU = Data()
        fullPDU.append(0x04) // PDU type
        fullPDU.append(0x00) // Reserved
        fullPDU.append(contentsOf: withUnsafeBytes(of: UInt32(data.count).bigEndian) { Array($0) })
        fullPDU.append(data)
        
        do {
            let pdu = try PDUDecoder.decode(from: fullPDU) as! DataTransferPDU
            
            // Add PDVs to message assembler
            if let message = try messageAssembler.addPDVs(from: pdu) {
                // Complete message assembled
                try await handleDIMSEMessage(message)
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error decoding P-DATA-TF: \(error)")
            }
            throw error
        }
    }
    
    private func handleDIMSEMessage(_ message: AssembledMessage) async throws {
        guard let command = message.command else {
            if configuration.verbose {
                print("[ServerSession \(id)] Unknown DIMSE command")
            }
            return
        }
        
        if configuration.verbose {
            print("[ServerSession \(id)] Handling DIMSE command: \(command)")
        }
        
        switch command {
        case .cEchoRequest:
            try await handleCEcho(message)
        case .cStoreRequest:
            try await handleCStore(message)
        case .cFindRequest:
            try await handleCFind(message)
        case .cMoveRequest:
            try await handleCMove(message)
        case .cGetRequest:
            try await handleCGet(message)
        default:
            if configuration.verbose {
                print("[ServerSession \(id)] Unsupported DIMSE command: \(command)")
            }
        }
    }
    
    // MARK: - C-ECHO Handler
    
    private func handleCEcho(_ message: AssembledMessage) async throws {
        guard let request = message.asCEchoRequest() else {
            if configuration.verbose {
                print("[ServerSession \(id)] Invalid C-ECHO request")
            }
            return
        }
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-ECHO request received")
        }
        
        // Create C-ECHO response
        let response = CEchoResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .success,
            presentationContextID: request.presentationContextID
        )
        
        // Send response
        try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-ECHO response sent")
        }
    }
    
    // MARK: - C-STORE Handler
    
    private func handleCStore(_ message: AssembledMessage) async throws {
        guard let request = message.asCStoreRequest() else {
            if configuration.verbose {
                print("[ServerSession \(id)] Invalid C-STORE request")
            }
            return
        }
        
        guard let dataSetBytes = message.dataSet else {
            if configuration.verbose {
                print("[ServerSession \(id)] C-STORE request missing data set")
            }
            // Send failure response
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                affectedSOPInstanceUID: request.affectedSOPInstanceUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
            return
        }
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-STORE request: SOP Instance UID = \(request.affectedSOPInstanceUID)")
        }
        
        do {
            // Parse the data set to extract metadata
            let dataset = try DataSet.read(from: dataSetBytes)
            
            // Store the file
            let filePath = try await storage.storeFile(dataset: dataset, sopInstanceUID: request.affectedSOPInstanceUID)
            
            if configuration.verbose {
                print("[ServerSession \(id)] Stored file: \(filePath)")
            }
            
            // Index in database if available
            if let db = database {
                let metadata = extractMetadata(from: dataset, filePath: filePath)
                try await db.index(filePath: filePath, metadata: metadata)
                
                if configuration.verbose {
                    print("[ServerSession \(id)] Indexed in database")
                }
            }
            
            // Send success response
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                affectedSOPInstanceUID: request.affectedSOPInstanceUID,
                status: .success,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
            
            if configuration.verbose {
                print("[ServerSession \(id)] C-STORE response sent (success)")
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error storing file: \(error)")
            }
            
            // Send failure response
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                affectedSOPInstanceUID: request.affectedSOPInstanceUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
        }
    }
    
    // MARK: - C-FIND Handler
    
    private func handleCFind(_ message: AssembledMessage) async throws {
        guard let request = message.asCFindRequest() else {
            if configuration.verbose {
                print("[ServerSession \(id)] Invalid C-FIND request")
            }
            return
        }
        
        guard let dataSetBytes = message.dataSet else {
            if configuration.verbose {
                print("[ServerSession \(id)] C-FIND request missing data set")
            }
            return
        }
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-FIND request received")
        }
        
        do {
            // Parse query dataset
            let queryDataset = try DataSet.read(from: dataSetBytes)
            
            // Determine query level
            let queryLevel = queryDataset.string(for: .queryRetrieveLevel) ?? "STUDY"
            
            if configuration.verbose {
                print("[ServerSession \(id)] Query level: \(queryLevel)")
            }
            
            // Query database
            if let db = database {
                let results = try await db.queryForFind(queryDataset: queryDataset, level: queryLevel)
                
                if configuration.verbose {
                    print("[ServerSession \(id)] Found \(results.count) matches")
                }
                
                // Send pending responses with results
                for result in results {
                    let response = CFindResponse(
                        messageIDBeingRespondedTo: request.messageID,
                        affectedSOPClassUID: request.affectedSOPClassUID,
                        status: .pending,
                        presentationContextID: request.presentationContextID
                    )
                    
                    // Encode result dataset
                    let resultBytes = result.write()
                    try await sendDIMSEResponse(response.commandSet, dataSet: resultBytes, contextID: request.presentationContextID)
                }
                
                // Send final success response
                let finalResponse = CFindResponse(
                    messageIDBeingRespondedTo: request.messageID,
                    affectedSOPClassUID: request.affectedSOPClassUID,
                    status: .success,
                    presentationContextID: request.presentationContextID
                )
                try await sendDIMSEResponse(finalResponse.commandSet, dataSet: nil, contextID: request.presentationContextID)
                
                if configuration.verbose {
                    print("[ServerSession \(id)] C-FIND complete")
                }
            } else {
                // No database, send empty result
                let response = CFindResponse(
                    messageIDBeingRespondedTo: request.messageID,
                    affectedSOPClassUID: request.affectedSOPClassUID,
                    status: .success,
                    presentationContextID: request.presentationContextID
                )
                try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error handling C-FIND: \(error)")
            }
            
            // Send failure response
            let response = CFindResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
        }
    }
    
    // MARK: - C-MOVE Handler
    
    private func handleCMove(_ message: AssembledMessage) async throws {
        guard let request = message.asCMoveRequest() else {
            if configuration.verbose {
                print("[ServerSession \(id)] Invalid C-MOVE request")
            }
            return
        }
        
        guard let dataSetBytes = message.dataSet else {
            if configuration.verbose {
                print("[ServerSession \(id)] C-MOVE request missing data set")
            }
            // Send failure response
            let response = CMoveResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
            return
        }
        
        let moveDestination = request.moveDestination
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-MOVE request received, destination: \(moveDestination)")
        }
        
        do {
            // Parse query dataset
            let queryDataset = try DataSet.read(from: dataSetBytes)
            
            // Determine query level
            let queryLevel = queryDataset.string(for: .queryRetrieveLevel) ?? "STUDY"
            
            if configuration.verbose {
                print("[ServerSession \(id)] C-MOVE query level: \(queryLevel)")
            }
            
            // Find matching instances
            var instancesToMove: [DICOMMetadata] = []
            
            if let db = database {
                instancesToMove = try await db.queryForRetrieve(queryDataset: queryDataset, level: queryLevel)
                
                if configuration.verbose {
                    print("[ServerSession \(id)] Found \(instancesToMove.count) instances to move")
                }
            }
            
            if instancesToMove.isEmpty {
                // No matches, send success with 0 operations
                let response = CMoveResponse(
                    messageIDBeingRespondedTo: request.messageID,
                    affectedSOPClassUID: request.affectedSOPClassUID,
                    status: .success,
                    remaining: 0,
                    completed: 0,
                    failed: 0,
                    warning: 0,
                    presentationContextID: request.presentationContextID
                )
                try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
                return
            }
            
            // Execute C-MOVE by sending files to destination
            var completed: UInt16 = 0
            var failed: UInt16 = 0
            let totalCount = UInt16(instancesToMove.count)
            
            for (index, metadata) in instancesToMove.enumerated() {
                let remaining = UInt16(instancesToMove.count - index - 1)
                
                // Attempt to send file to destination
                let success = await sendToDestination(metadata: metadata, destination: moveDestination)
                
                if success {
                    completed += 1
                } else {
                    failed += 1
                }
                
                // Send pending response after each sub-operation
                if remaining > 0 {
                    let pendingResponse = CMoveResponse(
                        messageIDBeingRespondedTo: request.messageID,
                        affectedSOPClassUID: request.affectedSOPClassUID,
                        status: .pending,
                        remaining: remaining,
                        completed: completed,
                        failed: failed,
                        warning: 0,
                        presentationContextID: request.presentationContextID
                    )
                    try await sendDIMSEResponse(pendingResponse.commandSet, dataSet: nil, contextID: request.presentationContextID)
                }
            }
            
            // Send final response
            let finalStatus: DIMSEStatus = failed == 0 ? .success : (completed > 0 ? .warningSubOperationsCompleteOneOrMoreFailures : .refusedUnableToPerformSubOperations)
            let finalResponse = CMoveResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: finalStatus,
                remaining: 0,
                completed: completed,
                failed: failed,
                warning: 0,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(finalResponse.commandSet, dataSet: nil, contextID: request.presentationContextID)
            
            if configuration.verbose {
                print("[ServerSession \(id)] C-MOVE complete: \(completed) successful, \(failed) failed")
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error handling C-MOVE: \(error)")
            }
            
            // Send failure response
            let response = CMoveResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
        }
    }
    
    /// Send a DICOM file to a C-MOVE destination (C-STORE SCU)
    private func sendToDestination(metadata: DICOMMetadata, destination: String) async -> Bool {
        // For Phase B, we'll simulate the send operation
        // In Phase C, this would actually connect to the destination and perform C-STORE
        
        if configuration.verbose {
            print("[ServerSession \(id)] Simulating send of \(metadata.sopInstanceUID) to \(destination)")
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: metadata.filePath) else {
            if configuration.verbose {
                print("[ServerSession \(id)] File not found: \(metadata.filePath)")
            }
            return false
        }
        
        // TODO: In a full implementation, this would:
        // 1. Look up destination AE configuration
        // 2. Establish association with destination
        // 3. Perform C-STORE of the file
        // 4. Handle response
        
        // For now, return success if file exists
        return true
    }
    
    // MARK: - C-GET Handler
    
    private func handleCGet(_ message: AssembledMessage) async throws {
        guard let request = message.asCGetRequest() else {
            if configuration.verbose {
                print("[ServerSession \(id)] Invalid C-GET request")
            }
            return
        }
        
        guard let dataSetBytes = message.dataSet else {
            if configuration.verbose {
                print("[ServerSession \(id)] C-GET request missing data set")
            }
            // Send failure response
            let response = CGetResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
            return
        }
        
        if configuration.verbose {
            print("[ServerSession \(id)] C-GET request received")
        }
        
        do {
            // Parse query dataset
            let queryDataset = try DataSet.read(from: dataSetBytes)
            
            // Determine query level
            let queryLevel = queryDataset.string(for: .queryRetrieveLevel) ?? "STUDY"
            
            if configuration.verbose {
                print("[ServerSession \(id)] C-GET query level: \(queryLevel)")
            }
            
            // Find matching instances
            var instancesToGet: [DICOMMetadata] = []
            
            if let db = database {
                instancesToGet = try await db.queryForRetrieve(queryDataset: queryDataset, level: queryLevel)
                
                if configuration.verbose {
                    print("[ServerSession \(id)] Found \(instancesToGet.count) instances to retrieve")
                }
            }
            
            if instancesToGet.isEmpty {
                // No matches, send success with 0 operations
                let response = CGetResponse(
                    messageIDBeingRespondedTo: request.messageID,
                    affectedSOPClassUID: request.affectedSOPClassUID,
                    status: .success,
                    remaining: 0,
                    completed: 0,
                    failed: 0,
                    warning: 0,
                    presentationContextID: request.presentationContextID
                )
                try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
                return
            }
            
            // Execute C-GET by streaming files on same association
            var completed: UInt16 = 0
            var failed: UInt16 = 0
            let totalCount = UInt16(instancesToGet.count)
            
            for (index, metadata) in instancesToGet.enumerated() {
                let remaining = UInt16(instancesToGet.count - index - 1)
                
                // Send C-GET pending response
                if index == 0 || remaining > 0 {
                    let pendingResponse = CGetResponse(
                        messageIDBeingRespondedTo: request.messageID,
                        affectedSOPClassUID: request.affectedSOPClassUID,
                        status: .pending,
                        remaining: UInt16(instancesToGet.count - index),
                        completed: completed,
                        failed: failed,
                        warning: 0,
                        presentationContextID: request.presentationContextID
                    )
                    try await sendDIMSEResponse(pendingResponse.commandSet, dataSet: nil, contextID: request.presentationContextID)
                }
                
                // Attempt to send file via C-STORE on same association
                let success = await sendViaCStore(metadata: metadata)
                
                if success {
                    completed += 1
                } else {
                    failed += 1
                }
            }
            
            // Send final response
            let finalStatus: DIMSEStatus = failed == 0 ? .success : (completed > 0 ? .warningSubOperationsCompleteOneOrMoreFailures : .refusedUnableToPerformSubOperations)
            let finalResponse = CGetResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: finalStatus,
                remaining: 0,
                completed: completed,
                failed: failed,
                warning: 0,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(finalResponse.commandSet, dataSet: nil, contextID: request.presentationContextID)
            
            if configuration.verbose {
                print("[ServerSession \(id)] C-GET complete: \(completed) successful, \(failed) failed")
            }
        } catch {
            if configuration.verbose {
                print("[ServerSession \(id)] Error handling C-GET: \(error)")
            }
            
            // Send failure response
            let response = CGetResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .processingFailure,
                presentationContextID: request.presentationContextID
            )
            try await sendDIMSEResponse(response.commandSet, dataSet: nil, contextID: request.presentationContextID)
        }
    }
    
    /// Send a DICOM file via C-STORE on the same association (for C-GET)
    private func sendViaCStore(metadata: DICOMMetadata) async -> Bool {
        // For Phase B, we'll simulate the C-STORE operation
        // In Phase C, this would actually perform C-STORE on the same association
        
        if configuration.verbose {
            print("[ServerSession \(id)] Simulating C-STORE of \(metadata.sopInstanceUID)")
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: metadata.filePath) else {
            if configuration.verbose {
                print("[ServerSession \(id)] File not found: \(metadata.filePath)")
            }
            return false
        }
        
        // TODO: In a full implementation, this would:
        // 1. Read the DICOM file
        // 2. Create a C-STORE request with appropriate presentation context
        // 3. Send C-STORE request and dataset on this association
        // 4. Wait for C-STORE response
        // 5. Handle the response
        
        // For now, return success if file exists
        return true
    }
    
    // MARK: - Helper Methods
    
    private func sendDIMSEResponse(_ commandSet: CommandSet, dataSet: Data?, contextID: UInt8) async throws {
        let fragmenter = MessageFragmenter(maxPDUSize: configuration.maxPDUSize)
        let pdus = fragmenter.fragmentMessage(commandSet: commandSet, dataSet: dataSet, presentationContextID: contextID)
        
        for pdu in pdus {
            let data = try pdu.encode()
            try await send(data)
        }
    }
    
    private func extractMetadata(from dataset: DataSet, filePath: String) -> DICOMMetadata {
        return DICOMMetadata(
            patientID: dataset.string(for: .patientID),
            patientName: dataset.string(for: .patientName),
            studyInstanceUID: dataset.string(for: .studyInstanceUID),
            studyDate: dataset.string(for: .studyDate),
            studyDescription: dataset.string(for: .studyDescription),
            seriesInstanceUID: dataset.string(for: .seriesInstanceUID),
            seriesNumber: dataset.string(for: .seriesNumber),
            modality: dataset.string(for: .modality),
            sopInstanceUID: dataset.string(for: .sopInstanceUID) ?? "",
            sopClassUID: dataset.string(for: .sopClassUID),
            instanceNumber: dataset.string(for: .instanceNumber),
            filePath: filePath
        )
    }
    
    private func handleReleaseRequest() async throws {
        if configuration.verbose {
            print("[ServerSession \(id)] Received A-RELEASE-RQ")
        }
        
        // Send release response
        let releasePDU = createReleaseResponse()
        try await send(releasePDU)
        
        if configuration.verbose {
            print("[ServerSession \(id)] Sent A-RELEASE-RP")
        }
        
        // Close connection
        await cancel()
    }
    
    private func createReleaseResponse() -> Data {
        var data = Data()
        data.append(0x06) // PDU type: A-RELEASE-RP
        data.append(0x00) // Reserved
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04]) // Length: 4
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Reserved
        return data
    }
}

#endif
