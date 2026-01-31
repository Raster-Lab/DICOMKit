import XCTest
@testable import DICOMNetwork

#if canImport(Network) && canImport(Security)

import Security

final class TLSConfigurationTests: XCTestCase {
    
    // MARK: - TLS Protocol Version Tests
    
    func testTLSProtocolVersionRawValues() {
        XCTAssertEqual(TLSProtocolVersion.tlsProtocol10.rawValue, "TLS 1.0")
        XCTAssertEqual(TLSProtocolVersion.tlsProtocol11.rawValue, "TLS 1.1")
        XCTAssertEqual(TLSProtocolVersion.tlsProtocol12.rawValue, "TLS 1.2")
        XCTAssertEqual(TLSProtocolVersion.tlsProtocol13.rawValue, "TLS 1.3")
    }
    
    func testTLSProtocolVersionAllCases() {
        let allCases = TLSProtocolVersion.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.tlsProtocol10))
        XCTAssertTrue(allCases.contains(.tlsProtocol11))
        XCTAssertTrue(allCases.contains(.tlsProtocol12))
        XCTAssertTrue(allCases.contains(.tlsProtocol13))
    }
    
    // MARK: - TLS Configuration Creation Tests
    
    func testDefaultConfiguration() {
        let config = TLSConfiguration.default
        
        XCTAssertEqual(config.minimumVersion, .tlsProtocol12)
        XCTAssertNil(config.maximumVersion)
        XCTAssertEqual(config.certificateValidation, .system)
        XCTAssertTrue(config.applicationProtocols.isEmpty)
        XCTAssertNil(config.clientIdentity)
    }
    
    func testStrictConfiguration() {
        let config = TLSConfiguration.strict
        
        XCTAssertEqual(config.minimumVersion, .tlsProtocol13)
        XCTAssertEqual(config.maximumVersion, .tlsProtocol13)
        XCTAssertEqual(config.certificateValidation, .system)
    }
    
    func testInsecureConfiguration() {
        let config = TLSConfiguration.insecure
        
        XCTAssertEqual(config.minimumVersion, .tlsProtocol12)
        XCTAssertNil(config.maximumVersion)
        XCTAssertEqual(config.certificateValidation, .disabled)
    }
    
    func testCustomConfiguration() {
        let config = TLSConfiguration(
            minimumVersion: .tlsProtocol12,
            maximumVersion: .tlsProtocol13,
            certificateValidation: .system,
            applicationProtocols: ["dicom"],
            clientIdentity: nil
        )
        
        XCTAssertEqual(config.minimumVersion, .tlsProtocol12)
        XCTAssertEqual(config.maximumVersion, .tlsProtocol13)
        XCTAssertEqual(config.certificateValidation, .system)
        XCTAssertEqual(config.applicationProtocols, ["dicom"])
        XCTAssertNil(config.clientIdentity)
    }
    
    // MARK: - Certificate Validation Mode Tests
    
    func testCertificateValidationEquality() {
        XCTAssertEqual(CertificateValidation.system, CertificateValidation.system)
        XCTAssertEqual(CertificateValidation.disabled, CertificateValidation.disabled)
        XCTAssertNotEqual(CertificateValidation.system, CertificateValidation.disabled)
    }
    
    func testCertificateValidationHashable() {
        let validations: Set<CertificateValidation> = [.system, .disabled]
        XCTAssertEqual(validations.count, 2)
        XCTAssertTrue(validations.contains(.system))
        XCTAssertTrue(validations.contains(.disabled))
    }
    
    // MARK: - TLS Configuration Hashable Tests
    
    func testTLSConfigurationEquality() {
        let config1 = TLSConfiguration.default
        let config2 = TLSConfiguration.default
        let config3 = TLSConfiguration.strict
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    func testTLSConfigurationHashable() {
        let config1 = TLSConfiguration.default
        let config2 = TLSConfiguration.default
        
        XCTAssertEqual(config1.hashValue, config2.hashValue)
    }
    
    // MARK: - Description Tests
    
    func testDefaultConfigurationDescription() {
        let config = TLSConfiguration.default
        let description = config.description
        
        XCTAssertTrue(description.contains("TLS 1.2"))
        XCTAssertTrue(description.contains("system trust"))
    }
    
    func testInsecureConfigurationDescription() {
        let config = TLSConfiguration.insecure
        let description = config.description
        
        XCTAssertTrue(description.contains("INSECURE"))
    }
    
    func testStrictConfigurationDescription() {
        let config = TLSConfiguration.strict
        let description = config.description
        
        XCTAssertTrue(description.contains("TLS 1.3"))
    }
    
    // MARK: - TLS Configuration Error Tests
    
    func testTLSConfigurationErrorDescriptions() {
        XCTAssertTrue(TLSConfigurationError.noPinnedCertificates.description.contains("pinned"))
        XCTAssertTrue(TLSConfigurationError.noTrustRoots.description.contains("trust roots"))
        XCTAssertTrue(TLSConfigurationError.pkcs12ImportFailed(status: -1).description.contains("PKCS#12"))
        XCTAssertTrue(TLSConfigurationError.pkcs12NoIdentity.description.contains("identity"))
        XCTAssertTrue(TLSConfigurationError.keychainIdentityNotFound(label: "test", status: -1).description.contains("test"))
        XCTAssertTrue(TLSConfigurationError.invalidCertificateData.description.contains("invalid"))
    }
    
    // MARK: - Certificate Loading Helper Tests
    
    func testCertificateFromInvalidDERThrows() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        XCTAssertThrowsError(try TLSConfiguration.certificate(fromDER: invalidData)) { error in
            XCTAssertTrue(error is TLSConfigurationError)
            if case TLSConfigurationError.invalidCertificateData = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testCertificateFromInvalidPEMThrows() {
        let invalidPEM = "Not a valid PEM certificate".data(using: .utf8)!
        
        XCTAssertThrowsError(try TLSConfiguration.certificate(fromPEM: invalidPEM)) { error in
            XCTAssertTrue(error is TLSConfigurationError)
        }
    }
    
    func testCertificatesFromEmptyPEMThrows() {
        let emptyPEM = "".data(using: .utf8)!
        
        XCTAssertThrowsError(try TLSConfiguration.certificates(fromPEM: emptyPEM)) { error in
            XCTAssertTrue(error is TLSConfigurationError)
        }
    }
    
    // MARK: - Client Identity Tests
    
    func testClientIdentityFromPKCS12() {
        let identity = ClientIdentity(pkcs12Data: Data(), password: "test")
        
        if case .pkcs12(let data, let password) = identity.source {
            XCTAssertTrue(data.isEmpty)
            XCTAssertEqual(password, "test")
        } else {
            XCTFail("Wrong source type")
        }
    }
    
    func testClientIdentityFromKeychain() {
        let identity = ClientIdentity(keychainLabel: "my-identity")
        
        if case .keychain(let label) = identity.source {
            XCTAssertEqual(label, "my-identity")
        } else {
            XCTFail("Wrong source type")
        }
    }
    
    func testClientIdentityEquality() {
        let identity1 = ClientIdentity(keychainLabel: "test")
        let identity2 = ClientIdentity(keychainLabel: "test")
        let identity3 = ClientIdentity(keychainLabel: "other")
        
        XCTAssertEqual(identity1, identity2)
        XCTAssertNotEqual(identity1, identity3)
    }
    
    func testClientIdentityMakeSecIdentityFromInvalidPKCS12Throws() {
        let identity = ClientIdentity(pkcs12Data: Data([0x00]), password: "wrong")
        
        XCTAssertThrowsError(try identity.makeSecIdentity()) { error in
            XCTAssertTrue(error is TLSConfigurationError)
        }
    }
    
    func testClientIdentityMakeSecIdentityFromMissingKeychainThrows() {
        let identity = ClientIdentity(keychainLabel: "non-existent-identity-12345")
        
        XCTAssertThrowsError(try identity.makeSecIdentity()) { error in
            XCTAssertTrue(error is TLSConfigurationError)
        }
    }
}

// MARK: - DICOMClientConfiguration TLS Tests

final class DICOMClientConfigurationTLSTests: XCTestCase {
    
    func testConfigurationWithTLSEnabled() throws {
        let config = try DICOMClientConfiguration(
            host: "secure-pacs.hospital.com",
            port: 2762,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsEnabled: true
        )
        
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertNotNil(config.tlsConfiguration)
        XCTAssertEqual(config.tlsConfiguration, .default)
    }
    
    func testConfigurationWithTLSDisabled() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsEnabled: false
        )
        
        XCTAssertFalse(config.tlsEnabled)
        XCTAssertNil(config.tlsConfiguration)
    }
    
    func testConfigurationWithCustomTLSConfiguration() throws {
        let tlsConfig = TLSConfiguration(
            minimumVersion: .tlsProtocol13,
            maximumVersion: .tlsProtocol13,
            certificateValidation: .system
        )
        
        let config = try DICOMClientConfiguration(
            host: "secure-pacs.hospital.com",
            port: 2762,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: tlsConfig
        )
        
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertEqual(config.tlsConfiguration, tlsConfig)
    }
    
    func testConfigurationWithInsecureTLS() throws {
        let config = try DICOMClientConfiguration(
            host: "dev-pacs.local",
            port: 2762,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: .insecure
        )
        
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertEqual(config.tlsConfiguration?.certificateValidation, .disabled)
    }
    
    func testConfigurationWithNilTLSConfiguration() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: nil
        )
        
        XCTAssertFalse(config.tlsEnabled)
        XCTAssertNil(config.tlsConfiguration)
    }
    
    func testConfigurationTLSHashable() throws {
        let tlsConfig = TLSConfiguration.default
        
        let config1 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: tlsConfig
        )
        
        let config2 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: tlsConfig
        )
        
        let config3 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            tlsConfiguration: .strict
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
        XCTAssertEqual(config1.hashValue, config2.hashValue)
    }
    
    func testConfigurationWithPrevalidatedAETitlesAndTLS() {
        let callingAE = try! AETitle("MY_SCU")
        let calledAE = try! AETitle("PACS")
        
        let config = DICOMClientConfiguration(
            host: "secure-pacs.hospital.com",
            port: 2762,
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            tlsConfiguration: .default
        )
        
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertEqual(config.tlsConfiguration, .default)
    }
}

// MARK: - DICOMConnection TLS Tests

final class DICOMConnectionTLSTests: XCTestCase {
    
    func testConnectionWithTLSConfiguration() throws {
        let tlsConfig = TLSConfiguration.default
        
        let connection = try DICOMConnection(
            host: "secure-pacs.hospital.com",
            port: 2762,
            tlsConfiguration: tlsConfig
        )
        
        XCTAssertEqual(connection.host, "secure-pacs.hospital.com")
        XCTAssertEqual(connection.port, 2762)
        XCTAssertEqual(connection.tlsConfiguration, tlsConfig)
    }
    
    func testConnectionWithNilTLSConfiguration() throws {
        let connection = try DICOMConnection(
            host: "pacs.hospital.com",
            port: 11112,
            tlsConfiguration: nil
        )
        
        XCTAssertEqual(connection.host, "pacs.hospital.com")
        XCTAssertEqual(connection.port, 11112)
        XCTAssertNil(connection.tlsConfiguration)
    }
    
    func testConnectionWithInsecureTLS() throws {
        let connection = try DICOMConnection(
            host: "dev-pacs.local",
            port: 2762,
            tlsConfiguration: .insecure
        )
        
        XCTAssertEqual(connection.tlsConfiguration?.certificateValidation, .disabled)
    }
    
    func testConnectionWithStrictTLS() throws {
        let connection = try DICOMConnection(
            host: "strict-pacs.hospital.com",
            port: 2762,
            tlsConfiguration: .strict
        )
        
        XCTAssertEqual(connection.tlsConfiguration?.minimumVersion, .tlsProtocol13)
        XCTAssertEqual(connection.tlsConfiguration?.maximumVersion, .tlsProtocol13)
    }
}

#endif
