import Foundation
import DICOMCore

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
    }
    
    /// Start the session
    func start() async {
        isActive = true
        
        connection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
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
        // TODO: Parse and validate association request
        // For now, accept all associations
        
        if configuration.verbose {
            print("[ServerSession \(id)] Received A-ASSOCIATE-RQ")
        }
        
        // Send association accept
        let acceptPDU = createAssociationAccept()
        try await send(acceptPDU)
        
        if configuration.verbose {
            print("[ServerSession \(id)] Sent A-ASSOCIATE-AC")
        }
    }
    
    private func handlePData(_ data: Data) async throws {
        // TODO: Parse and handle DIMSE messages
        // C-ECHO, C-FIND, C-STORE, C-MOVE, C-GET
        
        if configuration.verbose {
            print("[ServerSession \(id)] Received P-DATA-TF (\(data.count) bytes)")
        }
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
    
    private func createAssociationAccept() -> Data {
        // Minimal A-ASSOCIATE-AC PDU
        var data = Data()
        data.append(0x02) // PDU type: A-ASSOCIATE-AC
        data.append(0x00) // Reserved
        
        // PDU length (placeholder, will be updated)
        let lengthOffset = data.count
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        
        // Protocol version
        data.append(contentsOf: [0x00, 0x01])
        
        // Reserved
        data.append(contentsOf: [0x00, 0x00])
        
        // Called AE Title (16 bytes, padded with spaces)
        let calledAE = configuration.aeTitle.padding(toLength: 16, withPad: " ", startingAt: 0)
        data.append(contentsOf: calledAE.utf8)
        
        // Calling AE Title (16 bytes, padded with spaces)
        let callingAE = "ANY-SCU".padding(toLength: 16, withPad: " ", startingAt: 0)
        data.append(contentsOf: callingAE.utf8)
        
        // Reserved (32 bytes)
        data.append(contentsOf: [UInt8](repeating: 0x00, count: 32))
        
        // Update length field
        let pduLength = UInt32(data.count - 6)
        data[lengthOffset] = UInt8((pduLength >> 24) & 0xFF)
        data[lengthOffset + 1] = UInt8((pduLength >> 16) & 0xFF)
        data[lengthOffset + 2] = UInt8((pduLength >> 8) & 0xFF)
        data[lengthOffset + 3] = UInt8(pduLength & 0xFF)
        
        return data
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
