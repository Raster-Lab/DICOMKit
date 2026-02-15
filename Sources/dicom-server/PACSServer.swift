import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(Network)
import Network

/// PACS Server implementation
///
/// Provides C-ECHO, C-FIND, C-STORE, C-MOVE, and C-GET services
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public actor PACSServer {
    private let configuration: ServerConfiguration
    private let storage: StorageManager
    private let database: DatabaseManager?
    private var listener: NWListener?
    private var isRunning = false
    private var activeSessions: [UUID: ServerSession] = [:]
    
    public init(configuration: ServerConfiguration) throws {
        self.configuration = configuration
        
        // Initialize storage manager
        self.storage = try StorageManager(dataDirectory: configuration.dataDirectory)
        
        // Initialize database manager if configured
        if !configuration.databaseURL.isEmpty {
            self.database = try DatabaseManager(connectionString: configuration.databaseURL)
        } else {
            self.database = nil
        }
    }
    
    /// Start the PACS server
    public func start() async throws {
        guard !isRunning else {
            throw ServerError.invalidConfiguration("Server is already running")
        }
        
        // Create listener
        let parameters = NWParameters.tcp
        let port = NWEndpoint.Port(rawValue: configuration.port)!
        
        let listener = try NWListener(using: parameters, on: port)
        self.listener = listener
        
        // Set up listener state handler
        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleListenerState(state)
            }
        }
        
        // Set up new connection handler
        listener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleNewConnection(connection)
            }
        }
        
        // Start listening
        listener.start(queue: .global(qos: .userInitiated))
        isRunning = true
        
        if configuration.verbose {
            print("[PACSServer] Server started on port \(configuration.port)")
        }
        
        // Wait for the server to stop
        while isRunning {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
        }
    }
    
    /// Stop the PACS server
    public func stop() async {
        guard isRunning else { return }
        
        if configuration.verbose {
            print("[PACSServer] Stopping server...")
        }
        
        // Cancel all active sessions
        for (_, session) in activeSessions {
            await session.cancel()
        }
        activeSessions.removeAll()
        
        // Stop listener
        listener?.cancel()
        listener = nil
        isRunning = false
        
        if configuration.verbose {
            print("[PACSServer] Server stopped")
        }
    }
    
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            if configuration.verbose {
                print("[PACSServer] Listener ready")
            }
        case .failed(let error):
            if configuration.verbose {
                print("[PACSServer] Listener failed: \(error)")
            }
            Task { await self.stop() }
        case .cancelled:
            if configuration.verbose {
                print("[PACSServer] Listener cancelled")
            }
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) async {
        let sessionId = UUID()
        
        if configuration.verbose {
            print("[PACSServer] New connection: \(sessionId)")
        }
        
        // Check if we've reached max connections
        if activeSessions.count >= configuration.maxConcurrentConnections {
            if configuration.verbose {
                print("[PACSServer] Max connections reached, rejecting connection")
            }
            connection.cancel()
            return
        }
        
        // Create and start session
        let session = ServerSession(
            id: sessionId,
            connection: connection,
            configuration: configuration,
            storage: storage,
            database: database
        )
        
        activeSessions[sessionId] = session
        
        await session.start()
        
        // Remove session when done
        activeSessions.removeValue(forKey: sessionId)
        
        if configuration.verbose {
            print("[PACSServer] Session ended: \(sessionId)")
        }
    }
}

#else
// Fallback for platforms without Network framework
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public actor PACSServer {
    public init(configuration: ServerConfiguration) throws {
        throw ServerError.invalidConfiguration("Network operations not supported on this platform")
    }
    
    public func start() async throws {
        throw ServerError.invalidConfiguration("Network operations not supported on this platform")
    }
    
    public func stop() async {
    }
}
#endif
