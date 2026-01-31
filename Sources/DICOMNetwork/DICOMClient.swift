import Foundation
import DICOMCore

// MARK: - DICOMClient Configuration

/// Configuration for a DICOM Client
///
/// Contains all the parameters needed to connect to a remote DICOM service.
///
/// ## Usage
///
/// ```swift
/// let config = DICOMClientConfiguration(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS"
/// )
///
/// let client = DICOMClient(configuration: config)
/// ```
public struct DICOMClientConfiguration: Sendable, Hashable {
    /// The remote host address (IP or hostname)
    public let host: String
    
    /// The remote port number
    public let port: UInt16
    
    /// The local Application Entity title (calling AE)
    public let callingAETitle: AETitle
    
    /// The remote Application Entity title (called AE)
    public let calledAETitle: AETitle
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum PDU size to propose
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// Whether to use TLS encryption
    public let tlsEnabled: Bool
    
    /// Retry policy for network operations
    public let retryPolicy: RetryPolicy
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a DICOM client configuration
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title string
    ///   - calledAE: The remote AE title string
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - tlsEnabled: Use TLS encryption (default: false)
    ///   - retryPolicy: Retry policy for operations (default: no retries)
    /// - Throws: `DICOMNetworkError.invalidAETitle` if AE titles are invalid
    public init(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        tlsEnabled: Bool = false,
        retryPolicy: RetryPolicy = .none
    ) throws {
        self.host = host
        self.port = port
        self.callingAETitle = try AETitle(callingAE)
        self.calledAETitle = try AETitle(calledAE)
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.tlsEnabled = tlsEnabled
        self.retryPolicy = retryPolicy
    }
    
    /// Creates a DICOM client configuration with pre-validated AE titles
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - tlsEnabled: Use TLS encryption (default: false)
    ///   - retryPolicy: Retry policy for operations (default: no retries)
    public init(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 30,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        tlsEnabled: Bool = false,
        retryPolicy: RetryPolicy = .none
    ) {
        self.host = host
        self.port = port
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.tlsEnabled = tlsEnabled
        self.retryPolicy = retryPolicy
    }
}

// MARK: - Retry Policy

/// Policy for retrying failed network operations
///
/// Defines how many times and with what delay network operations should be retried.
///
/// ## Usage
///
/// ```swift
/// // No retries
/// let noRetry = RetryPolicy.none
///
/// // Fixed delay retries
/// let fixedRetry = RetryPolicy.fixed(maxRetries: 3, delay: 1.0)
///
/// // Exponential backoff
/// let exponentialRetry = RetryPolicy.exponentialBackoff(
///     maxRetries: 5,
///     initialDelay: 0.5,
///     maxDelay: 30.0,
///     multiplier: 2.0
/// )
/// ```
public struct RetryPolicy: Sendable, Hashable {
    /// Maximum number of retry attempts
    public let maxRetries: Int
    
    /// Initial delay before first retry (in seconds)
    public let initialDelay: TimeInterval
    
    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval
    
    /// Multiplier for exponential backoff
    public let multiplier: Double
    
    /// Whether this policy allows any retries
    public var allowsRetries: Bool {
        maxRetries > 0
    }
    
    /// Creates a custom retry policy
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - initialDelay: Initial delay before first retry
    ///   - maxDelay: Maximum delay between retries
    ///   - multiplier: Multiplier for exponential backoff (1.0 for fixed delay)
    public init(
        maxRetries: Int,
        initialDelay: TimeInterval,
        maxDelay: TimeInterval,
        multiplier: Double = 1.0
    ) {
        self.maxRetries = max(0, maxRetries)
        let normalizedInitialDelay = max(0, initialDelay)
        self.initialDelay = normalizedInitialDelay
        self.maxDelay = max(normalizedInitialDelay, max(0, maxDelay))
        self.multiplier = max(1.0, multiplier)
    }
    
    /// No retry policy - operations fail immediately on first error
    public static let none = RetryPolicy(
        maxRetries: 0,
        initialDelay: 0,
        maxDelay: 0
    )
    
    /// Creates a fixed-delay retry policy
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - delay: Fixed delay between retries in seconds
    /// - Returns: A retry policy with fixed delays
    public static func fixed(maxRetries: Int, delay: TimeInterval) -> RetryPolicy {
        RetryPolicy(
            maxRetries: maxRetries,
            initialDelay: delay,
            maxDelay: delay,
            multiplier: 1.0
        )
    }
    
    /// Creates an exponential backoff retry policy
    ///
    /// Each retry attempt waits longer than the previous, up to maxDelay.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - initialDelay: Initial delay before first retry (default: 0.5 seconds)
    ///   - maxDelay: Maximum delay between retries (default: 30 seconds)
    ///   - multiplier: Multiplier for each retry (default: 2.0)
    /// - Returns: A retry policy with exponential backoff
    public static func exponentialBackoff(
        maxRetries: Int,
        initialDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0
    ) -> RetryPolicy {
        RetryPolicy(
            maxRetries: maxRetries,
            initialDelay: initialDelay,
            maxDelay: maxDelay,
            multiplier: multiplier
        )
    }
    
    /// Calculates the delay for a specific retry attempt
    ///
    /// - Parameter attempt: The retry attempt number (0-based)
    /// - Returns: The delay in seconds before this retry attempt
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - DICOMClient

#if canImport(Network)

/// Unified high-level DICOM client for network operations
///
/// Provides a convenient interface for DICOM networking including verification (C-ECHO),
/// query (C-FIND), and retrieve (C-MOVE, C-GET) operations.
///
/// Reference: PS3.7 - Message Exchange
/// Reference: PS3.8 - Network Communication Support
///
/// ## Usage
///
/// ```swift
/// // Create a client
/// let config = try DICOMClientConfiguration(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS"
/// )
/// let client = DICOMClient(configuration: config)
///
/// // Test connectivity
/// let success = try await client.verify()
///
/// // Query for studies
/// let studies = try await client.findStudies(
///     matching: QueryKeys(level: .study)
///         .patientName("DOE^JOHN*")
///         .studyDate("20240101-20241231")
/// )
///
/// // Download a study using C-GET
/// for await event in try await client.getStudy(studyInstanceUID: studies[0].studyInstanceUID!) {
///     switch event {
///     case .instance(_, _, let data):
///         print("Received \(data.count) bytes")
///     case .completed(let result):
///         print("Download complete: \(result.progress.completed) instances")
///     default:
///         break
///     }
/// }
/// ```
public final class DICOMClient: Sendable {
    
    /// The client configuration
    public let configuration: DICOMClientConfiguration
    
    /// Creates a new DICOM client
    ///
    /// - Parameter configuration: The client configuration
    public init(configuration: DICOMClientConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - Convenience Initializer
    
    /// Creates a new DICOM client with the specified parameters
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - timeout: Connection timeout (default: 30 seconds)
    ///   - retryPolicy: Retry policy (default: no retries)
    /// - Throws: `DICOMNetworkError.invalidAETitle` if AE titles are invalid
    public convenience init(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .none
    ) throws {
        let config = try DICOMClientConfiguration(
            host: host,
            port: port,
            callingAE: callingAE,
            calledAE: calledAE,
            timeout: timeout,
            retryPolicy: retryPolicy
        )
        self.init(configuration: config)
    }
    
    // MARK: - Verification (C-ECHO)
    
    /// Tests connectivity with the remote DICOM service using C-ECHO
    ///
    /// - Returns: `true` if verification succeeded, `false` otherwise
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func verify() async throws -> Bool {
        try await withRetry {
            try await DICOMVerificationService.verify(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                timeout: self.configuration.timeout
            )
        }
    }
    
    /// Performs a C-ECHO operation and returns detailed results
    ///
    /// - Returns: A `VerificationResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func echo() async throws -> VerificationResult {
        try await withRetry {
            try await DICOMVerificationService.echo(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                timeout: self.configuration.timeout
            )
        }
    }
    
    // MARK: - Query (C-FIND)
    
    /// Finds studies matching the specified query keys
    ///
    /// - Parameter matching: Query keys specifying match criteria (optional)
    /// - Returns: Array of study results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func findStudies(matching: QueryKeys? = nil) async throws -> [StudyResult] {
        try await withRetry {
            try await DICOMQueryService.findStudies(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                matching: matching,
                timeout: self.configuration.timeout
            )
        }
    }
    
    /// Finds series within a study matching the specified query keys
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - matching: Additional query keys (optional)
    /// - Returns: Array of series results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func findSeries(
        forStudy studyInstanceUID: String,
        matching: QueryKeys? = nil
    ) async throws -> [SeriesResult] {
        try await withRetry {
            try await DICOMQueryService.findSeries(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                forStudy: studyInstanceUID,
                matching: matching,
                timeout: self.configuration.timeout
            )
        }
    }
    
    /// Finds instances within a series matching the specified query keys
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - matching: Additional query keys (optional)
    /// - Returns: Array of instance results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func findInstances(
        forStudy studyInstanceUID: String,
        forSeries seriesInstanceUID: String,
        matching: QueryKeys? = nil
    ) async throws -> [InstanceResult] {
        try await withRetry {
            try await DICOMQueryService.findInstances(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                forStudy: studyInstanceUID,
                forSeries: seriesInstanceUID,
                matching: matching,
                timeout: self.configuration.timeout
            )
        }
    }
    
    // MARK: - Retrieve (C-MOVE)
    
    /// Moves a study to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - moveDestination: The destination AE title
    ///   - onProgress: Optional progress callback
    /// - Returns: The retrieve result
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func moveStudy(
        studyInstanceUID: String,
        moveDestination: String,
        onProgress: ((RetrieveProgress) -> Void)? = nil
    ) async throws -> RetrieveResult {
        try await withRetry {
            try await DICOMRetrieveService.moveStudy(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                studyInstanceUID: studyInstanceUID,
                moveDestination: moveDestination,
                timeout: self.configuration.timeout,
                onProgress: onProgress
            )
        }
    }
    
    /// Moves a series to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - moveDestination: The destination AE title
    ///   - onProgress: Optional progress callback
    /// - Returns: The retrieve result
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func moveSeries(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        moveDestination: String,
        onProgress: ((RetrieveProgress) -> Void)? = nil
    ) async throws -> RetrieveResult {
        try await withRetry {
            try await DICOMRetrieveService.moveSeries(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                studyInstanceUID: studyInstanceUID,
                seriesInstanceUID: seriesInstanceUID,
                moveDestination: moveDestination,
                timeout: self.configuration.timeout,
                onProgress: onProgress
            )
        }
    }
    
    /// Moves an instance to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - moveDestination: The destination AE title
    ///   - onProgress: Optional progress callback
    /// - Returns: The retrieve result
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func moveInstance(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        moveDestination: String,
        onProgress: ((RetrieveProgress) -> Void)? = nil
    ) async throws -> RetrieveResult {
        try await withRetry {
            try await DICOMRetrieveService.moveInstance(
                host: self.configuration.host,
                port: self.configuration.port,
                callingAE: self.configuration.callingAETitle.value,
                calledAE: self.configuration.calledAETitle.value,
                studyInstanceUID: studyInstanceUID,
                seriesInstanceUID: seriesInstanceUID,
                sopInstanceUID: sopInstanceUID,
                moveDestination: moveDestination,
                timeout: self.configuration.timeout,
                onProgress: onProgress
            )
        }
    }
    
    // MARK: - Download (C-GET)
    
    /// Downloads a study using C-GET
    ///
    /// C-GET retrieves images directly on the same association without
    /// needing a separate Storage SCP.
    ///
    /// - Parameter studyInstanceUID: The Study Instance UID
    /// - Returns: An async stream of retrieve events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func getStudy(
        studyInstanceUID: String
    ) async throws -> AsyncThrowingStream<RetrieveEvent, Error> {
        // Note: C-GET operations are not retried since they return a stream
        // Individual failures are reported through the stream
        try await DICOMRetrieveService.getStudy(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle.value,
            calledAE: configuration.calledAETitle.value,
            studyInstanceUID: studyInstanceUID,
            timeout: configuration.timeout
        )
    }
    
    /// Downloads a series using C-GET
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    /// - Returns: An async stream of retrieve events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func getSeries(
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) async throws -> AsyncThrowingStream<RetrieveEvent, Error> {
        try await DICOMRetrieveService.getSeries(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle.value,
            calledAE: configuration.calledAETitle.value,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            timeout: configuration.timeout
        )
    }
    
    /// Downloads an instance using C-GET
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    /// - Returns: An async stream of retrieve events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public func getInstance(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) async throws -> AsyncThrowingStream<RetrieveEvent, Error> {
        try await DICOMRetrieveService.getInstance(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle.value,
            calledAE: configuration.calledAETitle.value,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopInstanceUID,
            timeout: configuration.timeout
        )
    }
    
    // MARK: - Retry Logic
    
    /// Executes an operation with retry logic
    ///
    /// - Parameter operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    private func withRetry<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        let policy = configuration.retryPolicy
        
        var lastError: Error?
        
        for attempt in 0...policy.maxRetries {
            do {
                // Wait before retry (no wait on first attempt)
                if attempt > 0 {
                    let delay = policy.delay(forAttempt: attempt)
                    if delay > 0 {
                        try await Task.sleep(for: .seconds(delay))
                    }
                }
                
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                if !shouldRetry(error: error) {
                    throw error
                }
                
                // If this was the last attempt, throw the error
                if attempt == policy.maxRetries {
                    throw error
                }
            }
        }
        
        // Should never reach here, but just in case
        throw lastError ?? DICOMNetworkError.connectionFailed("Unknown error")
    }
    
    /// Determines if an error should trigger a retry
    ///
    /// - Parameter error: The error to check
    /// - Returns: `true` if the operation should be retried
    private func shouldRetry(error: Error) -> Bool {
        guard let networkError = error as? DICOMNetworkError else {
            // Retry unknown errors
            return true
        }
        
        switch networkError {
        case .connectionFailed, .timeout, .connectionClosed:
            // Transient errors - retry
            return true
        case .associationRejected(let result, _, _):
            // Retry only transient rejections
            return result == .rejectedTransient
        case .artimTimerExpired:
            // Timeout waiting for response - retry
            return true
        case .invalidAETitle, .invalidState, .noPresentationContextAccepted,
             .sopClassNotSupported, .unexpectedPDUType, .invalidPDU,
             .encodingFailed, .decodingFailed, .pduTooLarge:
            // Protocol/configuration errors - don't retry
            return false
        case .associationAborted, .queryFailed, .retrieveFailed:
            // Application-level failures - don't retry
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension DICOMClient: CustomStringConvertible {
    public var description: String {
        """
        DICOMClient:
          Host: \(configuration.host):\(configuration.port)
          Calling AE: \(configuration.callingAETitle)
          Called AE: \(configuration.calledAETitle)
          TLS: \(configuration.tlsEnabled)
          Retry: \(configuration.retryPolicy.maxRetries) attempts
        """
    }
}

#endif
