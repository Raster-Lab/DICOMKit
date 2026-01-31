import Foundation

// MARK: - SOP Class UIDs

/// Verification SOP Class UID
///
/// Used for C-ECHO to test DICOM connectivity.
///
/// Reference: PS3.4 Annex A - Verification Service Class
public let verificationSOPClassUID = "1.2.840.10008.1.1"

// MARK: - Common Transfer Syntax UIDs

/// Implicit VR Little Endian Transfer Syntax UID
///
/// Default transfer syntax that must be supported by all DICOM implementations.
public let implicitVRLittleEndianTransferSyntaxUID = "1.2.840.10008.1.2"

/// Explicit VR Little Endian Transfer Syntax UID
///
/// Commonly supported transfer syntax.
public let explicitVRLittleEndianTransferSyntaxUID = "1.2.840.10008.1.2.1"

// MARK: - Verification Result

/// Result of a DICOM verification operation (C-ECHO)
public struct VerificationResult: Sendable, Hashable {
    /// Whether the verification was successful
    public let success: Bool
    
    /// The DIMSE status from the response
    public let status: DIMSEStatus
    
    /// Round-trip time in seconds
    public let roundTripTime: TimeInterval
    
    /// The remote Application Entity title
    public let remoteAETitle: String
    
    /// Creates a verification result
    public init(
        success: Bool,
        status: DIMSEStatus,
        roundTripTime: TimeInterval,
        remoteAETitle: String
    ) {
        self.success = success
        self.status = status
        self.roundTripTime = roundTripTime
        self.remoteAETitle = remoteAETitle
    }
}

extension VerificationResult: CustomStringConvertible {
    public var description: String {
        let statusStr = success ? "SUCCESS" : "FAILED"
        return "VerificationResult(\(statusStr), status=\(status), rtt=\(String(format: "%.3f", roundTripTime))s, ae=\(remoteAETitle))"
    }
}

// MARK: - Verification Configuration

/// Configuration for the DICOM Verification Service
public struct VerificationConfiguration: Sendable, Hashable {
    /// The local Application Entity title (calling AE)
    public let callingAETitle: AETitle
    
    /// The remote Application Entity title (called AE)
    public let calledAETitle: AETitle
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum PDU size to propose
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID for this DICOM implementation
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a verification configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 30,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
    }
}

#if canImport(Network)

// MARK: - DICOM Verification Service

/// DICOM Verification Service (C-ECHO SCU)
///
/// Implements the DICOM Verification Service Class as a Service Class User (SCU).
/// This is the simplest DICOM network operation and is used to test connectivity
/// with a remote DICOM Service Class Provider (SCP).
///
/// Reference: PS3.4 Annex A - Verification Service Class
/// Reference: PS3.7 Section 9.1.5 - C-ECHO Service
///
/// ## Usage
///
/// ```swift
/// // Simple verification
/// let success = try await DICOMVerificationService.verify(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS"
/// )
///
/// // Verification with detailed result
/// let result = try await DICOMVerificationService.echo(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     timeout: 10
/// )
/// print("Round-trip time: \(result.roundTripTime)s")
/// ```
public enum DICOMVerificationService {
    
    /// Verifies connectivity with a remote DICOM SCP using C-ECHO
    ///
    /// This is a convenience method that returns a simple boolean result.
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local Application Entity title
    ///   - calledAE: The remote Application Entity title
    ///   - timeout: Connection timeout in seconds (default: 30)
    /// - Returns: `true` if verification succeeded, `false` otherwise
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func verify(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30
    ) async throws -> Bool {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let result = try await echo(
            host: host,
            port: port,
            configuration: VerificationConfiguration(
                callingAETitle: callingAETitle,
                calledAETitle: calledAETitle,
                timeout: timeout
            )
        )
        
        return result.success
    }
    
    /// Performs a C-ECHO operation and returns detailed results
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local Application Entity title
    ///   - calledAE: The remote Application Entity title
    ///   - timeout: Connection timeout in seconds (default: 30)
    /// - Returns: A `VerificationResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func echo(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30
    ) async throws -> VerificationResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        return try await echo(
            host: host,
            port: port,
            configuration: VerificationConfiguration(
                callingAETitle: callingAETitle,
                calledAETitle: calledAETitle,
                timeout: timeout
            )
        )
    }
    
    /// Performs a C-ECHO operation with full configuration
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - configuration: The verification configuration
    /// - Returns: A `VerificationResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func echo(
        host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: VerificationConfiguration
    ) async throws -> VerificationResult {
        let startTime = Date()
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: configuration.callingAETitle,
            calledAETitle: configuration.calledAETitle,
            host: host,
            port: port,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            timeout: configuration.timeout
        )
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        // Create presentation context for Verification SOP Class
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: verificationSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify that the Verification SOP Class was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(verificationSOPClassUID)
            }
            
            // Send C-ECHO request
            let response = try await performCEcho(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize
            )
            
            // Release association gracefully
            try await association.release()
            
            let endTime = Date()
            let roundTripTime = endTime.timeIntervalSince(startTime)
            
            return VerificationResult(
                success: response.status.isSuccess,
                status: response.status,
                roundTripTime: roundTripTime,
                remoteAETitle: configuration.calledAETitle.value
            )
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Performs the C-ECHO request/response exchange
    ///
    /// - Parameters:
    ///   - association: The established association
    ///   - presentationContextID: The accepted presentation context ID
    ///   - maxPDUSize: The negotiated maximum PDU size
    /// - Returns: The C-ECHO response
    /// - Throws: `DICOMNetworkError` for protocol errors
    private static func performCEcho(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32
    ) async throws -> CEchoResponse {
        // Create C-ECHO request
        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: presentationContextID
        )
        
        // Fragment and send the command
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: nil,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive response
        let assembler = MessageAssembler()
        
        while true {
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                guard let echoResponse = message.asCEchoResponse() else {
                    throw DICOMNetworkError.decodingFailed(
                        "Expected C-ECHO-RSP, got \(message.command?.description ?? "unknown")"
                    )
                }
                return echoResponse
            }
        }
    }
}

#endif
