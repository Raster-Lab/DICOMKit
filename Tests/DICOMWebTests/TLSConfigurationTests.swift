import Testing
import Foundation
@testable import DICOMWeb

// MARK: - TLS Configuration Tests

@Suite("DICOMweb TLS Configuration Tests")
struct DICOMwebTLSConfigurationTests {
    
    // MARK: - Basic Configuration Tests
    
    @Test("Default TLS configuration values")
    func testDefaultTLSConfiguration() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem"
        )
        
        #expect(config.certificatePath == "/path/to/cert.pem")
        #expect(config.privateKeyPath == "/path/to/key.pem")
        #expect(config.privateKeyPassword == nil)
        #expect(config.minimumTLSVersion == .v12)
        #expect(config.maximumTLSVersion == nil)
        #expect(config.requireClientCertificate == false)
        #expect(config.clientCACertificatePath == nil)
        #expect(config.clientCertificateValidation == .strict)
        #expect(config.allowSelfSignedClientCertificates == false)
        #expect(config.cipherSuites.isEmpty)
    }
    
    @Test("Custom TLS configuration values")
    func testCustomTLSConfiguration() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/custom/cert.pem",
            privateKeyPath: "/custom/key.pem",
            privateKeyPassword: "secret",
            minimumTLSVersion: .v13,
            maximumTLSVersion: .v13,
            requireClientCertificate: true,
            clientCACertificatePath: "/custom/ca.pem",
            clientCertificateValidation: .standard,
            allowSelfSignedClientCertificates: true,
            cipherSuites: ["TLS_AES_256_GCM_SHA384"]
        )
        
        #expect(config.certificatePath == "/custom/cert.pem")
        #expect(config.privateKeyPath == "/custom/key.pem")
        #expect(config.privateKeyPassword == "secret")
        #expect(config.minimumTLSVersion == .v13)
        #expect(config.maximumTLSVersion == .v13)
        #expect(config.requireClientCertificate == true)
        #expect(config.clientCACertificatePath == "/custom/ca.pem")
        #expect(config.clientCertificateValidation == .standard)
        #expect(config.allowSelfSignedClientCertificates == true)
        #expect(config.cipherSuites == ["TLS_AES_256_GCM_SHA384"])
    }
    
    // MARK: - Preset Configuration Tests
    
    @Test("Strict preset configuration")
    func testStrictPreset() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.strict(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem"
        )
        
        #expect(config.minimumTLSVersion == .v13)
        #expect(config.maximumTLSVersion == .v13)
        #expect(config.clientCertificateValidation == .strict)
        #expect(config.requireClientCertificate == false)
    }
    
    @Test("Strict preset with password")
    func testStrictPresetWithPassword() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.strict(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem",
            privateKeyPassword: "password123"
        )
        
        #expect(config.privateKeyPassword == "password123")
        #expect(config.minimumTLSVersion == .v13)
    }
    
    @Test("Compatible preset configuration")
    func testCompatiblePreset() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.compatible(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem"
        )
        
        #expect(config.minimumTLSVersion == .v12)
        #expect(config.maximumTLSVersion == nil)
        #expect(config.clientCertificateValidation == .standard)
    }
    
    @Test("Development preset configuration")
    func testDevelopmentPreset() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.development(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem"
        )
        
        #expect(config.minimumTLSVersion == .v12)
        #expect(config.clientCertificateValidation == .permissive)
        #expect(config.allowSelfSignedClientCertificates == true)
        #expect(config.requireClientCertificate == false)
    }
    
    @Test("Mutual TLS preset configuration")
    func testMutualTLSPreset() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.mutualTLS(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem",
            clientCACertificatePath: "/path/to/ca.pem"
        )
        
        #expect(config.requireClientCertificate == true)
        #expect(config.clientCACertificatePath == "/path/to/ca.pem")
        #expect(config.clientCertificateValidation == .strict)
        #expect(config.minimumTLSVersion == .v12)
    }
    
    @Test("Mutual TLS preset with password")
    func testMutualTLSPresetWithPassword() {
        let config = DICOMwebServerConfiguration.TLSConfiguration.mutualTLS(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem",
            clientCACertificatePath: "/path/to/ca.pem",
            privateKeyPassword: "mtls-secret"
        )
        
        #expect(config.privateKeyPassword == "mtls-secret")
        #expect(config.requireClientCertificate == true)
    }
    
    // MARK: - TLS Version Tests
    
    @Test("TLS version raw values")
    func testTLSVersionRawValues() {
        #expect(DICOMwebServerConfiguration.TLSVersion.v12.rawValue == "TLS 1.2")
        #expect(DICOMwebServerConfiguration.TLSVersion.v13.rawValue == "TLS 1.3")
    }
    
    @Test("TLS version comparison")
    func testTLSVersionComparison() {
        let v12 = DICOMwebServerConfiguration.TLSVersion.v12
        let v13 = DICOMwebServerConfiguration.TLSVersion.v13
        
        #expect(v12 < v13)
        #expect(v13 > v12)
        #expect(v12 == v12)
        #expect(v13 == v13)
        #expect(!(v13 < v12))
    }
    
    @Test("TLS version all cases")
    func testTLSVersionAllCases() {
        let allCases = DICOMwebServerConfiguration.TLSVersion.allCases
        
        #expect(allCases.count == 2)
        #expect(allCases.contains(.v12))
        #expect(allCases.contains(.v13))
    }
    
    // MARK: - Certificate Validation Mode Tests
    
    @Test("Certificate validation mode raw values")
    func testCertificateValidationModeRawValues() {
        #expect(DICOMwebServerConfiguration.CertificateValidationMode.strict.rawValue == "strict")
        #expect(DICOMwebServerConfiguration.CertificateValidationMode.standard.rawValue == "standard")
        #expect(DICOMwebServerConfiguration.CertificateValidationMode.permissive.rawValue == "permissive")
    }
    
    @Test("Certificate validation mode descriptions")
    func testCertificateValidationModeDescriptions() {
        let strict = DICOMwebServerConfiguration.CertificateValidationMode.strict
        let standard = DICOMwebServerConfiguration.CertificateValidationMode.standard
        let permissive = DICOMwebServerConfiguration.CertificateValidationMode.permissive
        
        #expect(strict.description.contains("Strict"))
        #expect(strict.description.contains("revocation"))
        #expect(standard.description.contains("Standard"))
        #expect(permissive.description.contains("DEVELOPMENT"))
    }
    
    // MARK: - TLS Configuration Error Tests
    
    @Test("TLS configuration error descriptions")
    func testTLSConfigurationErrorDescriptions() {
        let certNotFound = DICOMwebServerConfiguration.TLSConfigurationError.certificateFileNotFound(path: "/missing/cert.pem")
        let keyNotFound = DICOMwebServerConfiguration.TLSConfigurationError.privateKeyFileNotFound(path: "/missing/key.pem")
        let caNotFound = DICOMwebServerConfiguration.TLSConfigurationError.caCertificateFileNotFound(path: "/missing/ca.pem")
        let versionRange = DICOMwebServerConfiguration.TLSConfigurationError.invalidVersionRange(minimum: .v13, maximum: .v12)
        let invalidCert = DICOMwebServerConfiguration.TLSConfigurationError.invalidCertificateData(reason: "malformed")
        let invalidKey = DICOMwebServerConfiguration.TLSConfigurationError.invalidPrivateKeyData(reason: "corrupted")
        let loadFailed = DICOMwebServerConfiguration.TLSConfigurationError.certificateLoadingFailed(reason: "permission denied")
        
        #expect(certNotFound.description.contains("/missing/cert.pem"))
        #expect(keyNotFound.description.contains("/missing/key.pem"))
        #expect(caNotFound.description.contains("/missing/ca.pem"))
        #expect(versionRange.description.contains("TLS 1.3"))
        #expect(versionRange.description.contains("TLS 1.2"))
        #expect(invalidCert.description.contains("malformed"))
        #expect(invalidKey.description.contains("corrupted"))
        #expect(loadFailed.description.contains("permission denied"))
    }
    
    // MARK: - Validation Tests
    
    @Test("Validation fails for missing certificate file")
    func testValidationMissingCertificate() throws {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/nonexistent/cert.pem",
            privateKeyPath: "/nonexistent/key.pem"
        )
        
        #expect(throws: DICOMwebServerConfiguration.TLSConfigurationError.self) {
            try config.validate()
        }
    }
    
    @Test("Validation fails for invalid version range")
    func testValidationInvalidVersionRange() throws {
        // Create a temp directory with temp files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        try "dummy cert".write(toFile: certPath, atomically: true, encoding: .utf8)
        try "dummy key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath,
            minimumTLSVersion: .v13,
            maximumTLSVersion: .v12 // Invalid: minimum > maximum
        )
        
        #expect(throws: DICOMwebServerConfiguration.TLSConfigurationError.self) {
            try config.validate()
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Validation succeeds with valid configuration")
    func testValidationSuccess() throws {
        // Create temp files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        try "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----".write(toFile: certPath, atomically: true, encoding: .utf8)
        try "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        // Should not throw
        try config.validate()
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Validation fails when mTLS CA cert missing")
    func testValidationMissingCACert() throws {
        // Create temp files for cert and key but not CA
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        try "cert".write(toFile: certPath, atomically: true, encoding: .utf8)
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath,
            requireClientCertificate: true,
            clientCACertificatePath: "/nonexistent/ca.pem"
        )
        
        #expect(throws: DICOMwebServerConfiguration.TLSConfigurationError.self) {
            try config.validate()
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Certificate Loading Tests
    
    @Test("Load certificate data from file")
    func testLoadCertificateData() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        let certContent = "-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----"
        try certContent.write(toFile: certPath, atomically: true, encoding: .utf8)
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        let data = try config.loadCertificateData()
        #expect(!data.isEmpty)
        #expect(String(data: data, encoding: .utf8)?.contains("BEGIN CERTIFICATE") == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Load private key data from file")
    func testLoadPrivateKeyData() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        try "cert".write(toFile: certPath, atomically: true, encoding: .utf8)
        let keyContent = "-----BEGIN PRIVATE KEY-----\nMIIC...\n-----END PRIVATE KEY-----"
        try keyContent.write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        let data = try config.loadPrivateKeyData()
        #expect(!data.isEmpty)
        #expect(String(data: data, encoding: .utf8)?.contains("BEGIN PRIVATE KEY") == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Load CA certificate data returns nil when not configured")
    func testLoadCACertificateDataNil() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        try "cert".write(toFile: certPath, atomically: true, encoding: .utf8)
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        let data = try config.loadCACertificateData()
        #expect(data == nil)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Load CA certificate data from file")
    func testLoadCACertificateData() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        let caPath = tempDir.appendingPathComponent("ca.pem").path
        
        try "cert".write(toFile: certPath, atomically: true, encoding: .utf8)
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        let caContent = "-----BEGIN CERTIFICATE-----\nCA...\n-----END CERTIFICATE-----"
        try caContent.write(toFile: caPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath,
            clientCACertificatePath: caPath
        )
        
        let data = try config.loadCACertificateData()
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8)?.contains("BEGIN CERTIFICATE") == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - PEM Extraction Tests
    
    @Test("Extract PEM content from valid PEM data")
    func testExtractPEMContent() throws {
        let pemContent = """
        -----BEGIN CERTIFICATE-----
        dGVzdA==
        -----END CERTIFICATE-----
        """
        let pemData = pemContent.data(using: .utf8)!
        
        let derData = try DICOMwebServerConfiguration.TLSConfiguration.extractPEMContent(pemData)
        #expect(!derData.isEmpty)
        // Base64 "dGVzdA==" decodes to "test"
        #expect(String(data: derData, encoding: .utf8) == "test")
    }
    
    @Test("Extract PEM content from DER data passes through")
    func testExtractPEMContentDER() throws {
        // DER data starts with 0x30 (ASN.1 SEQUENCE tag)
        let derData = Data([0x30, 0x01, 0x02, 0x03])
        
        let result = try DICOMwebServerConfiguration.TLSConfiguration.extractPEMContent(derData)
        #expect(result == derData)
    }
    
    @Test("Extract PEM content fails for invalid data")
    func testExtractPEMContentInvalid() {
        let invalidData = "not a certificate".data(using: .utf8)!
        
        #expect(throws: DICOMwebServerConfiguration.TLSConfigurationError.self) {
            _ = try DICOMwebServerConfiguration.TLSConfiguration.extractPEMContent(invalidData)
        }
    }
    
    // MARK: - PEM Format Detection Tests
    
    @Test("Detect PEM format")
    func testIsPEMFormat() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        let pemCert = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----"
        try pemCert.write(toFile: certPath, atomically: true, encoding: .utf8)
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        #expect(config.isPEMFormat == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("Detect non-PEM format")
    func testIsNotPEMFormat() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let certPath = tempDir.appendingPathComponent("cert.der").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        
        // DER data (binary, not PEM)
        try Data([0x30, 0x01, 0x02]).write(to: URL(fileURLWithPath: certPath))
        try "key".write(toFile: keyPath, atomically: true, encoding: .utf8)
        
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: certPath,
            privateKeyPath: keyPath
        )
        
        #expect(config.isPEMFormat == false)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Description Tests
    
    @Test("TLS configuration description TLS 1.2+")
    func testDescriptionTLS12Plus() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v12
        )
        
        let description = config.description
        #expect(description.contains("TLS 1.2+"))
        #expect(description.contains("strict"))
    }
    
    @Test("TLS configuration description TLS 1.3 only")
    func testDescriptionTLS13Only() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v13,
            maximumTLSVersion: .v13
        )
        
        let description = config.description
        #expect(description.contains("TLS 1.3"))
        #expect(!description.contains("+"))
    }
    
    @Test("TLS configuration description with mTLS")
    func testDescriptionWithMTLS() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            requireClientCertificate: true
        )
        
        let description = config.description
        #expect(description.contains("mTLS"))
    }
    
    @Test("TLS configuration description with validation mode")
    func testDescriptionWithValidationMode() {
        let config = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            clientCertificateValidation: .permissive
        )
        
        let description = config.description
        #expect(description.contains("permissive"))
    }
    
    // MARK: - Equatable Tests
    
    @Test("TLS configurations are equal")
    func testTLSConfigurationEquality() {
        let config1 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v12
        )
        
        let config2 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v12
        )
        
        #expect(config1 == config2)
    }
    
    @Test("TLS configurations are not equal with different paths")
    func testTLSConfigurationInequalityPaths() {
        let config1 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path1/cert.pem",
            privateKeyPath: "/path/key.pem"
        )
        
        let config2 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path2/cert.pem",
            privateKeyPath: "/path/key.pem"
        )
        
        #expect(config1 != config2)
    }
    
    @Test("TLS configurations are not equal with different versions")
    func testTLSConfigurationInequalityVersions() {
        let config1 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v12
        )
        
        let config2 = DICOMwebServerConfiguration.TLSConfiguration(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem",
            minimumTLSVersion: .v13
        )
        
        #expect(config1 != config2)
    }
    
    // MARK: - Integration with Server Configuration
    
    @Test("Server configuration with TLS")
    func testServerConfigurationWithTLS() {
        let tlsConfig = DICOMwebServerConfiguration.TLSConfiguration.strict(
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem"
        )
        
        let serverConfig = DICOMwebServerConfiguration(
            port: 443,
            host: "0.0.0.0",
            tlsConfiguration: tlsConfig
        )
        
        #expect(serverConfig.tlsConfiguration != nil)
        #expect(serverConfig.baseURL.scheme == "https")
        #expect(serverConfig.tlsConfiguration?.minimumTLSVersion == .v13)
    }
    
    @Test("Production preset configuration")
    func testProductionPreset() {
        let serverConfig = DICOMwebServerConfiguration.production(
            port: 8443,
            certificatePath: "/path/cert.pem",
            privateKeyPath: "/path/key.pem"
        )
        
        #expect(serverConfig.port == 8443)
        #expect(serverConfig.tlsConfiguration != nil)
        #expect(serverConfig.tlsConfiguration?.minimumTLSVersion == .v12)
        #expect(serverConfig.rateLimitConfiguration != nil)
    }
}
