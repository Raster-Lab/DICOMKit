import Foundation
#if canImport(Network)
import Network
#if canImport(Security)
import Security
#endif

// MARK: - TLSConfiguration

/// Configuration for TLS (Transport Layer Security) in DICOM connections
///
/// Provides comprehensive TLS settings including protocol version, certificate
/// validation, and custom certificate configuration.
///
/// Reference: PS3.15 - Security and System Management Profiles
/// Reference: PS3.8 Annex A - DICOM Secure Transport Connection Profile
///
/// ## Usage
///
/// ```swift
/// // Use system trust store (default)
/// let defaultTLS = TLSConfiguration.default
///
/// // Development mode with self-signed certificates
/// let devTLS = TLSConfiguration.insecure
///
/// // Custom configuration
/// let customTLS = TLSConfiguration(
///     minimumVersion: .tlsProtocol12,
///     maximumVersion: .tlsProtocol13,
///     certificateValidation: .system
/// )
///
/// // Use in client configuration
/// let config = try DICOMClientConfiguration(
///     host: "secure-pacs.hospital.com",
///     port: 2762,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     tlsConfiguration: customTLS
/// )
/// ```
public struct TLSConfiguration: Sendable, Hashable {
    
    // MARK: - TLS Protocol Version
    
    /// Minimum TLS protocol version to accept
    public let minimumVersion: TLSProtocolVersion
    
    /// Maximum TLS protocol version to accept (nil means no maximum)
    public let maximumVersion: TLSProtocolVersion?
    
    /// Certificate validation mode
    public let certificateValidation: CertificateValidation
    
    /// Application protocols to advertise (ALPN)
    public let applicationProtocols: [String]
    
    /// Optional client identity for mutual TLS authentication
    public let clientIdentity: ClientIdentity?
    
    // MARK: - Initialization
    
    /// Creates a TLS configuration with specified settings
    ///
    /// - Parameters:
    ///   - minimumVersion: Minimum TLS protocol version (default: TLS 1.2)
    ///   - maximumVersion: Maximum TLS protocol version (default: nil, meaning latest)
    ///   - certificateValidation: Certificate validation mode (default: system trust store)
    ///   - applicationProtocols: ALPN protocols to advertise (default: none)
    ///   - clientIdentity: Client certificate for mutual TLS (default: none)
    public init(
        minimumVersion: TLSProtocolVersion = .tlsProtocol12,
        maximumVersion: TLSProtocolVersion? = nil,
        certificateValidation: CertificateValidation = .system,
        applicationProtocols: [String] = [],
        clientIdentity: ClientIdentity? = nil
    ) {
        self.minimumVersion = minimumVersion
        self.maximumVersion = maximumVersion
        self.certificateValidation = certificateValidation
        self.applicationProtocols = applicationProtocols
        self.clientIdentity = clientIdentity
    }
    
    // MARK: - Preset Configurations
    
    /// Default secure TLS configuration
    ///
    /// Uses TLS 1.2 as minimum with system trust store validation.
    /// Suitable for production use with properly signed certificates.
    public static let `default` = TLSConfiguration(
        minimumVersion: .tlsProtocol12,
        maximumVersion: nil,
        certificateValidation: .system
    )
    
    /// Strict TLS configuration requiring TLS 1.3
    ///
    /// Uses TLS 1.3 only with system trust store validation.
    /// Provides the highest level of security but may not work with older servers.
    public static let strict = TLSConfiguration(
        minimumVersion: .tlsProtocol13,
        maximumVersion: .tlsProtocol13,
        certificateValidation: .system
    )
    
    /// Insecure TLS configuration for development
    ///
    /// Disables certificate validation - **USE ONLY FOR DEVELOPMENT/TESTING**
    ///
    /// - Warning: This configuration is insecure and should never be used in production.
    ///   It allows connections to servers with self-signed, expired, or invalid certificates.
    public static let insecure = TLSConfiguration(
        minimumVersion: .tlsProtocol12,
        maximumVersion: nil,
        certificateValidation: .disabled
    )
    
    // MARK: - Network.framework Integration
    
    /// Creates NWProtocolTLS.Options for use with Network.framework
    ///
    /// - Returns: Configured TLS options for NWConnection
    /// - Throws: `TLSConfigurationError` if the configuration is invalid
    public func makeNWProtocolTLSOptions() throws -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let secOptions = options.securityProtocolOptions
        
        // Set minimum TLS version using the modern API
        sec_protocol_options_set_min_tls_protocol_version(
            secOptions,
            minimumVersion.secProtocolVersion
        )
        
        // Set maximum TLS version if specified
        if let maxVersion = maximumVersion {
            sec_protocol_options_set_max_tls_protocol_version(
                secOptions,
                maxVersion.secProtocolVersion
            )
        }
        
        // Configure certificate validation
        switch certificateValidation {
        case .system:
            // Use default system trust store - no additional configuration needed
            break
            
        case .disabled:
            // Disable certificate verification for development/testing
            sec_protocol_options_set_verify_block(
                secOptions,
                { _, _, completion in
                    // Accept all certificates
                    completion(true)
                },
                .main
            )
            
        case .pinned(let pinnedCertificates):
            // Certificate pinning
            try configurePinnedCertificates(pinnedCertificates, options: secOptions)
            
        case .custom(let trustRoots):
            // Custom trust roots
            try configureCustomTrustRoots(trustRoots, options: secOptions)
        }
        
        // Configure ALPN protocols if specified
        for proto in applicationProtocols {
            sec_protocol_options_add_tls_application_protocol(
                secOptions,
                proto
            )
        }
        
        // Configure client identity for mutual TLS
        if let identity = clientIdentity {
            try configureClientIdentity(identity, options: secOptions)
        }
        
        return options
    }
    
    // MARK: - Private Certificate Configuration
    
    private func configurePinnedCertificates(
        _ certificates: [SecCertificate],
        options: sec_protocol_options_t
    ) throws {
        guard !certificates.isEmpty else {
            throw TLSConfigurationError.noPinnedCertificates
        }
        
        sec_protocol_options_set_verify_block(
            options,
            { _, secTrust, completion in
                let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()
                
                // Get the server certificate using the modern API
                guard SecTrustGetCertificateCount(trust) > 0 else {
                    completion(false)
                    return
                }
                
                // Use SecTrustCopyCertificateChain (available on macOS 12+/iOS 15+)
                // Fall back to deprecated API for older systems
                let serverCert: SecCertificate?
                if #available(macOS 12.0, iOS 15.0, *) {
                    if let certChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                       let firstCert = certChain.first {
                        serverCert = firstCert
                    } else {
                        serverCert = nil
                    }
                } else {
                    serverCert = SecTrustGetCertificateAtIndex(trust, 0)
                }
                
                guard let serverCert = serverCert else {
                    completion(false)
                    return
                }
                
                // Check if server certificate matches any pinned certificate
                let serverCertData = SecCertificateCopyData(serverCert) as Data
                let matches = certificates.contains { pinnedCert in
                    let pinnedCertData = SecCertificateCopyData(pinnedCert) as Data
                    return serverCertData == pinnedCertData
                }
                
                completion(matches)
            },
            .main
        )
    }
    
    private func configureCustomTrustRoots(
        _ trustRoots: [SecCertificate],
        options: sec_protocol_options_t
    ) throws {
        guard !trustRoots.isEmpty else {
            throw TLSConfigurationError.noTrustRoots
        }
        
        sec_protocol_options_set_verify_block(
            options,
            { _, secTrust, completion in
                let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()
                
                // Set custom anchor certificates
                let status = SecTrustSetAnchorCertificates(trust, trustRoots as CFArray)
                guard status == errSecSuccess else {
                    completion(false)
                    return
                }
                
                // Only trust the custom anchors, not the system anchors
                SecTrustSetAnchorCertificatesOnly(trust, true)
                
                // Evaluate trust
                var error: CFError?
                let trusted = SecTrustEvaluateWithError(trust, &error)
                completion(trusted)
            },
            .main
        )
    }
    
    private func configureClientIdentity(
        _ identity: ClientIdentity,
        options: sec_protocol_options_t
    ) throws {
        let secIdentity = try identity.makeSecIdentity()
        if let secIdentityRef = sec_identity_create(secIdentity) {
            sec_protocol_options_set_local_identity(options, secIdentityRef)
        }
    }
}

// MARK: - TLS Protocol Version

/// Supported TLS protocol versions
///
/// DICOM networks typically require TLS 1.2 or higher for security compliance.
///
/// > Warning: TLS 1.0 and TLS 1.1 are deprecated and no longer supported on
/// > macOS 13+/iOS 16+ systems. On these newer systems, selecting TLS 1.0 or
/// > TLS 1.1 will automatically fall back to TLS 1.2 to maintain security
/// > compliance. If you require TLS 1.0/1.1 for legacy server compatibility,
/// > ensure your deployment targets support these protocol versions.
public enum TLSProtocolVersion: String, Sendable, Hashable, CaseIterable {
    /// TLS 1.0 (deprecated, not recommended)
    ///
    /// > Warning: TLS 1.0 is not available on macOS 13+/iOS 16+ and will
    /// > automatically fall back to TLS 1.2 on these systems.
    case tlsProtocol10 = "TLS 1.0"
    
    /// TLS 1.1 (deprecated, not recommended)
    ///
    /// > Warning: TLS 1.1 is not available on macOS 13+/iOS 16+ and will
    /// > automatically fall back to TLS 1.2 on these systems.
    case tlsProtocol11 = "TLS 1.1"
    
    /// TLS 1.2 (recommended minimum)
    case tlsProtocol12 = "TLS 1.2"
    
    /// TLS 1.3 (most secure)
    case tlsProtocol13 = "TLS 1.3"
    
    /// The corresponding Security framework protocol version
    ///
    /// > Note: On macOS 13+/iOS 16+, TLS 1.0 and TLS 1.1 are no longer
    /// > available and will return TLS 1.2 instead.
    @available(macOS 10.15, iOS 13.0, *)
    var secProtocolVersion: tls_protocol_version_t {
        switch self {
        case .tlsProtocol10:
            // TLSv10 is deprecated and not available on newer systems
            // Fall back to TLS 1.2 for security compliance
            if #available(macOS 13.0, iOS 16.0, *) {
                return .TLSv12
            } else {
                return .TLSv10
            }
        case .tlsProtocol11:
            // TLSv11 is deprecated and not available on newer systems
            // Fall back to TLS 1.2 for security compliance
            if #available(macOS 13.0, iOS 16.0, *) {
                return .TLSv12
            } else {
                return .TLSv11
            }
        case .tlsProtocol12:
            return .TLSv12
        case .tlsProtocol13:
            return .TLSv13
        }
    }
    
    /// Whether this protocol version is available on the current system
    ///
    /// TLS 1.0 and TLS 1.1 are not available on macOS 13+/iOS 16+.
    @available(macOS 10.15, iOS 13.0, *)
    public var isAvailableOnCurrentSystem: Bool {
        switch self {
        case .tlsProtocol10, .tlsProtocol11:
            if #available(macOS 13.0, iOS 16.0, *) {
                return false
            }
            return true
        case .tlsProtocol12, .tlsProtocol13:
            return true
        }
    }
}

// MARK: - Certificate Validation

/// Certificate validation mode for TLS connections
///
/// Determines how server certificates are validated during TLS handshake.
public enum CertificateValidation: Sendable, Hashable {
    /// Use system trust store for validation (default, recommended)
    ///
    /// Certificates are validated against the system's trusted CA certificates.
    /// This is the standard, secure mode for production use.
    case system
    
    /// Disable certificate validation (insecure, development only)
    ///
    /// - Warning: This mode accepts any certificate including self-signed,
    ///   expired, and revoked certificates. Use only for development/testing.
    case disabled
    
    /// Pin specific certificates
    ///
    /// Only accept connections where the server presents one of the pinned certificates.
    /// Provides the strongest security but requires certificate management.
    ///
    /// - Parameter certificates: The certificates to pin
    case pinned([SecCertificate])
    
    /// Use custom trust roots instead of system trust store
    ///
    /// Useful for internal PKI where a private CA is used.
    ///
    /// - Parameter trustRoots: Custom CA certificates to trust
    case custom([SecCertificate])
    
    // MARK: - Hashable conformance
    
    public static func == (lhs: CertificateValidation, rhs: CertificateValidation) -> Bool {
        switch (lhs, rhs) {
        case (.system, .system):
            return true
        case (.disabled, .disabled):
            return true
        case (.pinned(let lhsCerts), .pinned(let rhsCerts)):
            return certificatesEqual(lhsCerts, rhsCerts)
        case (.custom(let lhsCerts), .custom(let rhsCerts)):
            return certificatesEqual(lhsCerts, rhsCerts)
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .system:
            hasher.combine(0)
        case .disabled:
            hasher.combine(1)
        case .pinned(let certs):
            hasher.combine(2)
            for cert in certs {
                hasher.combine(SecCertificateCopyData(cert) as Data)
            }
        case .custom(let certs):
            hasher.combine(3)
            for cert in certs {
                hasher.combine(SecCertificateCopyData(cert) as Data)
            }
        }
    }
    
    private static func certificatesEqual(_ lhs: [SecCertificate], _ rhs: [SecCertificate]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (lhsCert, rhsCert) in zip(lhs, rhs) {
            let lhsData = SecCertificateCopyData(lhsCert) as Data
            let rhsData = SecCertificateCopyData(rhsCert) as Data
            if lhsData != rhsData {
                return false
            }
        }
        return true
    }
}

// MARK: - Client Identity

/// Client identity for mutual TLS (mTLS) authentication
///
/// Used when the server requires client certificate authentication.
public struct ClientIdentity: @unchecked Sendable, Hashable {
    
    /// The source of the client identity
    public enum Source: Hashable {
        /// Load identity from PKCS#12 data
        case pkcs12(data: Data, password: String)
        
        /// Load identity from keychain by label
        case keychain(label: String)
        
        /// Use an existing SecIdentity
        case secIdentity(SecIdentity)
        
        // MARK: - Hashable conformance
        
        public static func == (lhs: Source, rhs: Source) -> Bool {
            switch (lhs, rhs) {
            case (.pkcs12(let lhsData, let lhsPassword), .pkcs12(let rhsData, let rhsPassword)):
                return lhsData == rhsData && lhsPassword == rhsPassword
            case (.keychain(let lhsLabel), .keychain(let rhsLabel)):
                return lhsLabel == rhsLabel
            case (.secIdentity(let lhsIdentity), .secIdentity(let rhsIdentity)):
                // Compare identities by their certificate data
                var lhsCert: SecCertificate?
                var rhsCert: SecCertificate?
                SecIdentityCopyCertificate(lhsIdentity, &lhsCert)
                SecIdentityCopyCertificate(rhsIdentity, &rhsCert)
                guard let lc = lhsCert, let rc = rhsCert else { return false }
                return SecCertificateCopyData(lc) as Data == SecCertificateCopyData(rc) as Data
            default:
                return false
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .pkcs12(let data, let password):
                hasher.combine(0)
                hasher.combine(data)
                hasher.combine(password)
            case .keychain(let label):
                hasher.combine(1)
                hasher.combine(label)
            case .secIdentity(let identity):
                hasher.combine(2)
                var cert: SecCertificate?
                SecIdentityCopyCertificate(identity, &cert)
                if let c = cert {
                    hasher.combine(SecCertificateCopyData(c) as Data)
                }
            }
        }
    }
    
    /// The source of the identity
    public let source: Source
    
    /// Creates a client identity from PKCS#12 data
    ///
    /// - Parameters:
    ///   - pkcs12Data: The PKCS#12 (.p12 or .pfx) file data
    ///   - password: The password for the PKCS#12 file
    public init(pkcs12Data: Data, password: String) {
        self.source = .pkcs12(data: pkcs12Data, password: password)
    }
    
    /// Creates a client identity from the keychain
    ///
    /// - Parameter keychainLabel: The label of the identity in the keychain
    public init(keychainLabel: String) {
        self.source = .keychain(label: keychainLabel)
    }
    
    /// Creates a client identity from an existing SecIdentity
    ///
    /// - Parameter identity: The SecIdentity to use
    public init(identity: SecIdentity) {
        self.source = .secIdentity(identity)
    }
    
    /// Creates the SecIdentity from the configured source
    ///
    /// - Returns: The SecIdentity for use with TLS
    /// - Throws: `TLSConfigurationError` if the identity cannot be loaded
    public func makeSecIdentity() throws -> SecIdentity {
        switch source {
        case .pkcs12(let data, let password):
            return try loadPKCS12Identity(data: data, password: password)
            
        case .keychain(let label):
            return try loadKeychainIdentity(label: label)
            
        case .secIdentity(let identity):
            return identity
        }
    }
    
    private func loadPKCS12Identity(data: Data, password: String) throws -> SecIdentity {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        
        guard status == errSecSuccess else {
            throw TLSConfigurationError.pkcs12ImportFailed(status: status)
        }
        
        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw TLSConfigurationError.pkcs12NoIdentity
        }
        
        // The identity is guaranteed to be a SecIdentity from SecPKCS12Import
        // swiftlint:disable:next force_cast
        let identity = identityRef as! SecIdentity
        return identity
    }
    
    private func loadKeychainIdentity(label: String) throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw TLSConfigurationError.keychainIdentityNotFound(label: label, status: status)
        }
        
        guard item != nil else {
            throw TLSConfigurationError.keychainIdentityNotFound(label: label, status: errSecItemNotFound)
        }
        
        // The identity is guaranteed to be a SecIdentity when querying with kSecClassIdentity
        // swiftlint:disable:next force_cast
        let identity = item as! SecIdentity
        return identity
    }
}

// MARK: - TLS Configuration Errors

/// Errors that can occur when configuring TLS
public enum TLSConfigurationError: Error, Sendable, CustomStringConvertible {
    /// No pinned certificates were provided
    case noPinnedCertificates
    
    /// No trust roots were provided
    case noTrustRoots
    
    /// Failed to import PKCS#12 data
    case pkcs12ImportFailed(status: OSStatus)
    
    /// PKCS#12 data did not contain an identity
    case pkcs12NoIdentity
    
    /// Identity not found in keychain
    case keychainIdentityNotFound(label: String, status: OSStatus)
    
    /// Certificate data is invalid
    case invalidCertificateData
    
    public var description: String {
        switch self {
        case .noPinnedCertificates:
            return "No pinned certificates provided for certificate pinning"
        case .noTrustRoots:
            return "No trust roots provided for custom certificate validation"
        case .pkcs12ImportFailed(let status):
            return "Failed to import PKCS#12 data: OSStatus \(status)"
        case .pkcs12NoIdentity:
            return "PKCS#12 data did not contain an identity"
        case .keychainIdentityNotFound(let label, let status):
            return "Identity '\(label)' not found in keychain: OSStatus \(status)"
        case .invalidCertificateData:
            return "Certificate data is invalid or could not be parsed"
        }
    }
}

// MARK: - Certificate Loading Helpers

extension TLSConfiguration {
    
    /// Creates a certificate from DER-encoded data
    ///
    /// - Parameter derData: The DER-encoded certificate data
    /// - Returns: The SecCertificate
    /// - Throws: `TLSConfigurationError.invalidCertificateData` if data is invalid
    public static func certificate(fromDER derData: Data) throws -> SecCertificate {
        guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            throw TLSConfigurationError.invalidCertificateData
        }
        return certificate
    }
    
    /// Creates a certificate from PEM-encoded data
    ///
    /// - Parameter pemData: The PEM-encoded certificate data
    /// - Returns: The SecCertificate
    /// - Throws: `TLSConfigurationError.invalidCertificateData` if data is invalid
    public static func certificate(fromPEM pemData: Data) throws -> SecCertificate {
        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw TLSConfigurationError.invalidCertificateData
        }
        
        // Extract base64 content from PEM
        let lines = pemString.components(separatedBy: .newlines)
        var base64Content = ""
        var inCertificate = false
        
        for line in lines {
            if line.contains("-----BEGIN CERTIFICATE-----") {
                inCertificate = true
            } else if line.contains("-----END CERTIFICATE-----") {
                break
            } else if inCertificate {
                base64Content += line.trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard let derData = Data(base64Encoded: base64Content) else {
            throw TLSConfigurationError.invalidCertificateData
        }
        
        return try certificate(fromDER: derData)
    }
    
    /// Creates certificates from a PEM file containing multiple certificates
    ///
    /// - Parameter pemData: The PEM-encoded data containing one or more certificates
    /// - Returns: Array of SecCertificates
    /// - Throws: `TLSConfigurationError.invalidCertificateData` if data is invalid
    public static func certificates(fromPEM pemData: Data) throws -> [SecCertificate] {
        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw TLSConfigurationError.invalidCertificateData
        }
        
        var certificates: [SecCertificate] = []
        var currentCertBase64 = ""
        var inCertificate = false
        
        for line in pemString.components(separatedBy: .newlines) {
            if line.contains("-----BEGIN CERTIFICATE-----") {
                inCertificate = true
                currentCertBase64 = ""
            } else if line.contains("-----END CERTIFICATE-----") {
                inCertificate = false
                if let derData = Data(base64Encoded: currentCertBase64),
                   let cert = SecCertificateCreateWithData(nil, derData as CFData) {
                    certificates.append(cert)
                }
            } else if inCertificate {
                currentCertBase64 += line.trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard !certificates.isEmpty else {
            throw TLSConfigurationError.invalidCertificateData
        }
        
        return certificates
    }
}

// MARK: - CustomStringConvertible

extension TLSConfiguration: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("TLS \(minimumVersion.rawValue)")
        if let maxVersion = maximumVersion {
            parts.append("- \(maxVersion.rawValue)")
        } else {
            parts.append("+")
        }
        
        switch certificateValidation {
        case .system:
            parts.append("(system trust)")
        case .disabled:
            parts.append("(INSECURE)")
        case .pinned(let certs):
            parts.append("(pinned: \(certs.count) certs)")
        case .custom(let roots):
            parts.append("(custom: \(roots.count) roots)")
        }
        
        if clientIdentity != nil {
            parts.append("+ client cert")
        }
        
        return parts.joined(separator: " ")
    }
}

#endif
