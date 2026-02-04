import XCTest
@testable import DICOMWeb

/// Tests for DICOM Conformance Statement generation
final class ConformanceStatementTests: XCTestCase {
    
    // MARK: - ConformanceStatement Tests
    
    func testDefaultConformanceStatement() {
        let statement = ConformanceStatement(
            implementation: .dicomKit,
            networkServices: ConformanceStatement.NetworkServices(
                dicomWeb: ConformanceStatement.DICOMwebServices()
            )
        )
        
        XCTAssertEqual(statement.documentVersion, "1.0")
        XCTAssertEqual(statement.implementation.name, "DICOMKit")
        XCTAssertEqual(statement.implementation.version, "0.8.8")
    }
    
    func testImplementationInfo() {
        let implementation = ConformanceStatement.Implementation(
            name: "TestPACS",
            version: "1.0.0",
            vendor: "Test Vendor",
            description: "Test PACS implementation",
            dicomVersion: "2024c"
        )
        
        XCTAssertEqual(implementation.name, "TestPACS")
        XCTAssertEqual(implementation.version, "1.0.0")
        XCTAssertEqual(implementation.vendor, "Test Vendor")
        XCTAssertEqual(implementation.description, "Test PACS implementation")
        XCTAssertEqual(implementation.dicomVersion, "2024c")
    }
    
    func testDICOMKitImplementation() {
        let implementation = ConformanceStatement.Implementation.dicomKit
        
        XCTAssertEqual(implementation.name, "DICOMKit")
        XCTAssertEqual(implementation.version, "0.8.8")
        XCTAssertEqual(implementation.vendor, "DICOMKit Contributors")
        XCTAssertNotNil(implementation.description)
        XCTAssertNotNil(implementation.implementationClassUID)
        XCTAssertNotNil(implementation.implementationVersionName)
    }
    
    // MARK: - WADO-RS Conformance Tests
    
    func testWADORSConformance() {
        let wado = ConformanceStatement.WADORSConformance(
            supported: true,
            endpoints: ConformanceStatement.WADORSEndpoints(
                study: true,
                series: true,
                instance: true,
                frames: false,
                metadata: true,
                rendered: false,
                thumbnail: false,
                bulkdata: true
            ),
            acceptMediaTypes: ["application/dicom", "application/dicom+json"],
            transferSyntaxes: ["1.2.840.10008.1.2.1", "1.2.840.10008.1.2"],
            retrievalOptions: ConformanceStatement.RetrievalOptions()
        )
        
        XCTAssertTrue(wado.supported)
        XCTAssertTrue(wado.endpoints.study)
        XCTAssertTrue(wado.endpoints.series)
        XCTAssertTrue(wado.endpoints.instance)
        XCTAssertFalse(wado.endpoints.frames)
        XCTAssertTrue(wado.endpoints.metadata)
        XCTAssertFalse(wado.endpoints.rendered)
        XCTAssertTrue(wado.endpoints.bulkdata)
        XCTAssertEqual(wado.acceptMediaTypes.count, 2)
        XCTAssertEqual(wado.transferSyntaxes.count, 2)
    }
    
    func testWADORSEndpointsDefaults() {
        let endpoints = ConformanceStatement.WADORSEndpoints()
        
        XCTAssertTrue(endpoints.study)
        XCTAssertTrue(endpoints.series)
        XCTAssertTrue(endpoints.instance)
        XCTAssertFalse(endpoints.frames)
        XCTAssertTrue(endpoints.metadata)
        XCTAssertFalse(endpoints.rendered)
        XCTAssertFalse(endpoints.thumbnail)
        XCTAssertTrue(endpoints.bulkdata)
    }
    
    // MARK: - QIDO-RS Conformance Tests
    
    func testQIDORSConformance() {
        let qido = ConformanceStatement.QIDORSConformance(
            supported: true,
            queryLevels: ["STUDY", "SERIES", "INSTANCE"],
            matchingAttributes: [],
            returnAttributes: [],
            queryOptions: ConformanceStatement.QueryOptions(
                fuzzyMatching: false,
                wildcardMatching: true,
                dateRangeQueries: true
            )
        )
        
        XCTAssertTrue(qido.supported)
        XCTAssertEqual(qido.queryLevels.count, 3)
        XCTAssertTrue(qido.queryLevels.contains("STUDY"))
        XCTAssertFalse(qido.queryOptions.fuzzyMatching)
        XCTAssertTrue(qido.queryOptions.wildcardMatching)
        XCTAssertTrue(qido.queryOptions.dateRangeQueries)
    }
    
    func testQueryOptions() {
        let options = ConformanceStatement.QueryOptions(
            fuzzyMatching: true,
            wildcardMatching: true,
            dateRangeQueries: true,
            timeRangeQueries: true,
            dateTimeRangeQueries: true,
            maxResults: 1000,
            includeFieldAll: true,
            paginationSupported: true
        )
        
        XCTAssertTrue(options.fuzzyMatching)
        XCTAssertTrue(options.wildcardMatching)
        XCTAssertTrue(options.dateRangeQueries)
        XCTAssertEqual(options.maxResults, 1000)
        XCTAssertTrue(options.includeFieldAll)
        XCTAssertTrue(options.paginationSupported)
    }
    
    func testQueryAttribute() {
        let attribute = ConformanceStatement.QueryAttribute(
            tag: "00100010",
            name: "PatientName",
            vr: "PN",
            levels: ["STUDY"]
        )
        
        XCTAssertEqual(attribute.tag, "00100010")
        XCTAssertEqual(attribute.name, "PatientName")
        XCTAssertEqual(attribute.vr, "PN")
        XCTAssertEqual(attribute.levels, ["STUDY"])
    }
    
    // MARK: - STOW-RS Conformance Tests
    
    func testSTOWRSConformance() {
        let stow = ConformanceStatement.STOWRSConformance(
            supported: true,
            supportedSOPClasses: [
                ConformanceStatement.SOPClassInfo(
                    uid: "1.2.840.10008.5.1.4.1.1.2",
                    name: "CT Image Storage",
                    category: "Image"
                )
            ],
            acceptMediaTypes: ["application/dicom", "multipart/related"],
            storeOptions: ConformanceStatement.StoreOptions(
                maxRequestSize: 500 * 1024 * 1024,
                maxInstancesPerRequest: 100,
                partialSuccessSupported: true,
                duplicatePolicy: "replace"
            )
        )
        
        XCTAssertTrue(stow.supported)
        XCTAssertEqual(stow.supportedSOPClasses.count, 1)
        XCTAssertEqual(stow.supportedSOPClasses[0].uid, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(stow.storeOptions.maxRequestSize, 500 * 1024 * 1024)
        XCTAssertEqual(stow.storeOptions.duplicatePolicy, "replace")
    }
    
    func testSOPClassInfo() {
        let sopClass = ConformanceStatement.SOPClassInfo(
            uid: "1.2.840.10008.5.1.4.1.1.4",
            name: "MR Image Storage",
            category: "Image"
        )
        
        XCTAssertEqual(sopClass.uid, "1.2.840.10008.5.1.4.1.1.4")
        XCTAssertEqual(sopClass.name, "MR Image Storage")
        XCTAssertEqual(sopClass.category, "Image")
    }
    
    // MARK: - UPS-RS Conformance Tests
    
    func testUPSRSConformance() {
        let ups = ConformanceStatement.UPSRSConformance(
            supported: true,
            operations: ConformanceStatement.UPSOperations(
                search: true,
                retrieve: true,
                create: true,
                update: true,
                changeState: true,
                requestCancellation: true
            ),
            stateManagement: ConformanceStatement.StateManagement(
                supportedStates: ["SCHEDULED", "IN PROGRESS", "COMPLETED", "CANCELED"],
                transactionUIDTracking: true
            ),
            eventSubscription: ConformanceStatement.EventSubscription(
                supported: false,
                deliveryMethods: [],
                globalSubscription: false
            )
        )
        
        XCTAssertTrue(ups.supported)
        XCTAssertTrue(ups.operations.search)
        XCTAssertTrue(ups.operations.changeState)
        XCTAssertEqual(ups.stateManagement.supportedStates.count, 4)
        XCTAssertFalse(ups.eventSubscription.supported)
    }
    
    func testUPSOperations() {
        let operations = ConformanceStatement.UPSOperations()
        
        XCTAssertTrue(operations.search)
        XCTAssertTrue(operations.retrieve)
        XCTAssertTrue(operations.create)
        XCTAssertTrue(operations.update)
        XCTAssertTrue(operations.changeState)
        XCTAssertTrue(operations.requestCancellation)
        XCTAssertTrue(operations.subscribe)
        XCTAssertTrue(operations.unsubscribe)
        XCTAssertTrue(operations.suspendSubscription)
    }
    
    // MARK: - Delete Conformance Tests
    
    func testDeleteConformance() {
        let delete = ConformanceStatement.DeleteConformance(
            supported: true,
            levels: ["STUDY", "SERIES", "INSTANCE"],
            softDeleteSupported: false
        )
        
        XCTAssertTrue(delete.supported)
        XCTAssertEqual(delete.levels.count, 3)
        XCTAssertFalse(delete.softDeleteSupported)
    }
    
    // MARK: - Security Information Tests
    
    func testSecurityInformation() {
        let security = ConformanceStatement.SecurityInformation(
            authenticationMethods: ["none", "basic", "bearer"],
            tlsSupport: ConformanceStatement.TLSSupport(
                supported: true,
                required: true,
                minimumVersion: "TLS 1.2"
            ),
            auditLogging: true,
            accessControl: ConformanceStatement.AccessControlInfo(
                enabled: true,
                model: "RBAC",
                roles: ["reader", "writer", "admin"]
            )
        )
        
        XCTAssertEqual(security.authenticationMethods.count, 3)
        XCTAssertTrue(security.tlsSupport.supported)
        XCTAssertTrue(security.tlsSupport.required)
        XCTAssertEqual(security.tlsSupport.minimumVersion, "TLS 1.2")
        XCTAssertTrue(security.auditLogging)
        XCTAssertTrue(security.accessControl.enabled)
        XCTAssertEqual(security.accessControl.model, "RBAC")
    }
    
    func testTLSSupport() {
        let tls = ConformanceStatement.TLSSupport(
            supported: true,
            required: true,
            minimumVersion: "TLS 1.2",
            maximumVersion: "TLS 1.3",
            clientCertificatesSupported: true,
            clientCertificatesRequired: false
        )
        
        XCTAssertTrue(tls.supported)
        XCTAssertTrue(tls.required)
        XCTAssertEqual(tls.minimumVersion, "TLS 1.2")
        XCTAssertEqual(tls.maximumVersion, "TLS 1.3")
        XCTAssertTrue(tls.clientCertificatesSupported)
        XCTAssertFalse(tls.clientCertificatesRequired)
    }
    
    func testAccessControlInfo() {
        let accessControl = ConformanceStatement.AccessControlInfo(
            enabled: true,
            model: "OAuth2/RBAC",
            roles: ["reader", "writer", "deleter", "admin"]
        )
        
        XCTAssertTrue(accessControl.enabled)
        XCTAssertEqual(accessControl.model, "OAuth2/RBAC")
        XCTAssertEqual(accessControl.roles?.count, 4)
    }
    
    // MARK: - Character Set Support Tests
    
    func testCharacterSetSupport() {
        let charsets = ConformanceStatement.CharacterSetSupport(
            defaultCharacterSet: "UTF-8",
            supportedCharacterSets: ["UTF-8", "ISO_IR 100", "ISO_IR 101"],
            acceptCharsetNegotiation: false
        )
        
        XCTAssertEqual(charsets.defaultCharacterSet, "UTF-8")
        XCTAssertEqual(charsets.supportedCharacterSets.count, 3)
        XCTAssertFalse(charsets.acceptCharsetNegotiation)
    }
    
    // MARK: - Export Tests
    
    func testJSONExport() throws {
        let statement = createTestConformanceStatement()
        
        let jsonData = try statement.toJSON()
        XCTAssertGreaterThan(jsonData.count, 0)
        
        // Verify it can be parsed back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ConformanceStatement.self, from: jsonData)
        
        XCTAssertEqual(decoded.implementation.name, statement.implementation.name)
        XCTAssertEqual(decoded.implementation.version, statement.implementation.version)
    }
    
    func testJSONStringExport() throws {
        let statement = createTestConformanceStatement()
        
        let jsonString = try statement.toJSONString()
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("DICOMKit"))
        XCTAssertTrue(jsonString.contains("0.8.8"))
    }
    
    func testTextExport() {
        let statement = createTestConformanceStatement()
        
        let textDocument = statement.toText()
        
        XCTAssertFalse(textDocument.isEmpty)
        XCTAssertTrue(textDocument.contains("DICOM CONFORMANCE STATEMENT"))
        XCTAssertTrue(textDocument.contains("IMPLEMENTATION"))
        XCTAssertTrue(textDocument.contains("DICOMKit"))
        XCTAssertTrue(textDocument.contains("DICOMWEB SERVICES"))
        XCTAssertTrue(textDocument.contains("WADO-RS"))
        XCTAssertTrue(textDocument.contains("QIDO-RS"))
        XCTAssertTrue(textDocument.contains("STOW-RS"))
        XCTAssertTrue(textDocument.contains("SECURITY"))
    }
    
    // MARK: - Codable Tests
    
    func testConformanceStatementCodable() throws {
        let original = createTestConformanceStatement()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ConformanceStatement.self, from: data)
        
        XCTAssertEqual(decoded.documentVersion, original.documentVersion)
        XCTAssertEqual(decoded.implementation, original.implementation)
        XCTAssertEqual(decoded.networkServices.dicomWeb.wadoRS?.supported, 
                      original.networkServices.dicomWeb.wadoRS?.supported)
    }
    
    // MARK: - Error Tests
    
    func testConformanceStatementErrorDescriptions() {
        let encodingError = ConformanceStatementError.encodingFailed("Test error")
        XCTAssertTrue(encodingError.description.contains("encoding failed"))
        
        let decodingError = ConformanceStatementError.decodingFailed("Test error")
        XCTAssertTrue(decodingError.description.contains("decoding failed"))
        
        let configError = ConformanceStatementError.invalidConfiguration("Test error")
        XCTAssertTrue(configError.description.contains("Invalid conformance"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestConformanceStatement() -> ConformanceStatement {
        return ConformanceStatement(
            documentVersion: "1.0",
            generatedDate: Date(),
            implementation: .dicomKit,
            networkServices: ConformanceStatement.NetworkServices(
                dicomWeb: ConformanceStatement.DICOMwebServices(
                    wadoRS: ConformanceStatement.WADORSConformance(
                        supported: true,
                        endpoints: ConformanceStatement.WADORSEndpoints(),
                        acceptMediaTypes: ["application/dicom"],
                        transferSyntaxes: ["1.2.840.10008.1.2.1"],
                        retrievalOptions: ConformanceStatement.RetrievalOptions()
                    ),
                    qidoRS: ConformanceStatement.QIDORSConformance(
                        supported: true,
                        queryLevels: ["STUDY", "SERIES", "INSTANCE"],
                        matchingAttributes: [],
                        returnAttributes: [],
                        queryOptions: ConformanceStatement.QueryOptions()
                    ),
                    stowRS: ConformanceStatement.STOWRSConformance(
                        supported: true,
                        supportedSOPClasses: [],
                        acceptMediaTypes: ["application/dicom"],
                        storeOptions: ConformanceStatement.StoreOptions()
                    ),
                    upsRS: ConformanceStatement.UPSRSConformance(
                        supported: true,
                        operations: ConformanceStatement.UPSOperations(),
                        stateManagement: ConformanceStatement.StateManagement(),
                        eventSubscription: ConformanceStatement.EventSubscription()
                    ),
                    deleteSupport: ConformanceStatement.DeleteConformance()
                )
            ),
            security: ConformanceStatement.SecurityInformation(
                authenticationMethods: ["none", "bearer"],
                tlsSupport: ConformanceStatement.TLSSupport(supported: true, required: true),
                auditLogging: false,
                accessControl: ConformanceStatement.AccessControlInfo(enabled: true)
            ),
            characterSets: ConformanceStatement.CharacterSetSupport()
        )
    }
}

// MARK: - ConformanceStatementGenerator Tests

final class ConformanceStatementGeneratorTests: XCTestCase {
    
    func testGenerateFromCapabilities() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        XCTAssertEqual(statement.implementation.name, "DICOMKit")
        XCTAssertNotNil(statement.networkServices.dicomWeb.wadoRS)
        XCTAssertNotNil(statement.networkServices.dicomWeb.qidoRS)
        XCTAssertNotNil(statement.networkServices.dicomWeb.stowRS)
        XCTAssertNotNil(statement.networkServices.dicomWeb.upsRS)
    }
    
    func testGenerateFromCapabilitiesWithCustomImplementation() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        let customImpl = ConformanceStatement.Implementation(
            name: "CustomPACS",
            version: "2.0",
            vendor: "Custom Vendor"
        )
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities,
            implementation: customImpl
        )
        
        XCTAssertEqual(statement.implementation.name, "CustomPACS")
        XCTAssertEqual(statement.implementation.version, "2.0")
        XCTAssertEqual(statement.implementation.vendor, "Custom Vendor")
    }
    
    func testGenerateFromConfiguration() {
        let configuration = DICOMwebServerConfiguration.development
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: configuration,
            capabilities: capabilities
        )
        
        XCTAssertEqual(statement.implementation.name, "DICOMKit")
        XCTAssertNotNil(statement.networkServices.dicomWeb.wadoRS)
        XCTAssertTrue(statement.networkServices.dicomWeb.wadoRS?.supported ?? false)
        
        // Development config has no TLS
        XCTAssertFalse(statement.security.tlsSupport.supported)
    }
    
    func testGenerateWithMinimalCapabilities() {
        let capabilities = DICOMwebCapabilities.minimal
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        // Minimal has WADO and QIDO but not STOW
        XCTAssertNotNil(statement.networkServices.dicomWeb.wadoRS)
        XCTAssertNotNil(statement.networkServices.dicomWeb.qidoRS)
        XCTAssertNil(statement.networkServices.dicomWeb.stowRS)
        XCTAssertNil(statement.networkServices.dicomWeb.upsRS)
    }
    
    func testGenerateWithTLSConfiguration() throws {
        // Create a config with TLS (we can't validate the paths in tests)
        let configuration = DICOMwebServerConfiguration(
            port: 443,
            host: "0.0.0.0",
            tlsConfiguration: DICOMwebServerConfiguration.TLSConfiguration(
                certificatePath: "/path/to/cert.pem",
                privateKeyPath: "/path/to/key.pem",
                minimumTLSVersion: .v12,
                requireClientCertificate: false
            )
        )
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: configuration,
            capabilities: capabilities
        )
        
        XCTAssertTrue(statement.security.tlsSupport.supported)
        XCTAssertTrue(statement.security.tlsSupport.required)
        XCTAssertEqual(statement.security.tlsSupport.minimumVersion, "TLS 1.2")
        XCTAssertFalse(statement.security.tlsSupport.clientCertificatesRequired)
    }
    
    func testGenerateWithMutualTLS() {
        let configuration = DICOMwebServerConfiguration(
            port: 443,
            host: "0.0.0.0",
            tlsConfiguration: DICOMwebServerConfiguration.TLSConfiguration(
                certificatePath: "/path/to/cert.pem",
                privateKeyPath: "/path/to/key.pem",
                minimumTLSVersion: .v12,
                requireClientCertificate: true,
                clientCACertificatePath: "/path/to/ca.pem"
            )
        )
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: configuration,
            capabilities: capabilities
        )
        
        XCTAssertTrue(statement.security.tlsSupport.clientCertificatesSupported)
        XCTAssertTrue(statement.security.tlsSupport.clientCertificatesRequired)
    }
    
    func testGenerateQueryAttributes() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        guard let qido = statement.networkServices.dicomWeb.qidoRS else {
            XCTFail("QIDO-RS should be present")
            return
        }
        
        // Should have common matching attributes
        XCTAssertGreaterThan(qido.matchingAttributes.count, 0)
        
        // Check for PatientName attribute
        let hasPatientName = qido.matchingAttributes.contains { $0.name == "PatientName" }
        XCTAssertTrue(hasPatientName)
        
        // Check for StudyDate attribute
        let hasStudyDate = qido.matchingAttributes.contains { $0.name == "StudyDate" }
        XCTAssertTrue(hasStudyDate)
    }
    
    func testGenerateSOPClasses() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        guard let stow = statement.networkServices.dicomWeb.stowRS else {
            XCTFail("STOW-RS should be present")
            return
        }
        
        // Should have common SOP classes
        XCTAssertGreaterThan(stow.supportedSOPClasses.count, 0)
        
        // Check for CT Image Storage
        let hasCT = stow.supportedSOPClasses.contains { $0.uid == "1.2.840.10008.5.1.4.1.1.2" }
        XCTAssertTrue(hasCT)
    }
    
    func testGenerateWithSTOWConfiguration() {
        let configuration = DICOMwebServerConfiguration(
            stowConfiguration: DICOMwebServerConfiguration.STOWConfiguration(
                duplicatePolicy: .reject,
                validateRequiredAttributes: true
            )
        )
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: configuration,
            capabilities: capabilities
        )
        
        guard let stow = statement.networkServices.dicomWeb.stowRS else {
            XCTFail("STOW-RS should be present")
            return
        }
        
        XCTAssertEqual(stow.storeOptions.duplicatePolicy, "reject")
        XCTAssertTrue(stow.storeOptions.validationEnabled)
    }
    
    func testGenerateUPSRSWithStateTransitions() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        guard let ups = statement.networkServices.dicomWeb.upsRS else {
            XCTFail("UPS-RS should be present")
            return
        }
        
        XCTAssertTrue(ups.supported)
        XCTAssertEqual(ups.stateManagement.supportedStates.count, 4)
        XCTAssertTrue(ups.stateManagement.supportedStates.contains("SCHEDULED"))
        XCTAssertTrue(ups.stateManagement.supportedStates.contains("IN PROGRESS"))
        XCTAssertTrue(ups.stateManagement.supportedStates.contains("COMPLETED"))
        XCTAssertTrue(ups.stateManagement.supportedStates.contains("CANCELED"))
        XCTAssertNotNil(ups.stateManagement.validTransitions)
    }
    
    func testGenerateWithDeleteService() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        guard let delete = statement.networkServices.dicomWeb.deleteSupport else {
            XCTFail("Delete support should be present")
            return
        }
        
        XCTAssertTrue(delete.supported)
        XCTAssertTrue(delete.levels.contains("STUDY"))
        XCTAssertTrue(delete.levels.contains("SERIES"))
        XCTAssertTrue(delete.levels.contains("INSTANCE"))
        XCTAssertFalse(delete.softDeleteSupported)  // Per MILESTONES.md - not implemented
    }
    
    func testGenerateWithOAuth2Authentication() {
        let capabilities = DICOMwebCapabilities(
            authenticationMethods: [.oauth2, .bearer]
        )
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        XCTAssertTrue(statement.security.authenticationMethods.contains("oauth2"))
        XCTAssertTrue(statement.security.authenticationMethods.contains("bearer"))
        XCTAssertTrue(statement.security.accessControl.enabled)
        XCTAssertEqual(statement.security.accessControl.model, "OAuth2/RBAC")
        XCTAssertNotNil(statement.security.accessControl.roles)
    }
    
    func testConformanceStatementEquatable() {
        let statement1 = ConformanceStatementGenerator.generate(
            from: DICOMwebCapabilities.dicomKitServer
        )
        
        let statement2 = ConformanceStatementGenerator.generate(
            from: DICOMwebCapabilities.dicomKitServer
        )
        
        // Different generated dates will make them not equal
        // But we can compare individual components
        XCTAssertEqual(statement1.implementation, statement2.implementation)
        XCTAssertEqual(statement1.documentVersion, statement2.documentVersion)
    }
    
    func testConformanceStatementTextOutput() {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        let statement = ConformanceStatementGenerator.generate(
            from: capabilities
        )
        
        let text = statement.toText()
        
        // Verify section headers
        XCTAssertTrue(text.contains("DICOM CONFORMANCE STATEMENT"))
        XCTAssertTrue(text.contains("IMPLEMENTATION"))
        XCTAssertTrue(text.contains("DICOMWEB SERVICES"))
        XCTAssertTrue(text.contains("SECURITY"))
        XCTAssertTrue(text.contains("CHARACTER ENCODING"))
        XCTAssertTrue(text.contains("END OF CONFORMANCE STATEMENT"))
        
        // Verify implementation details
        XCTAssertTrue(text.contains("Name: DICOMKit"))
        XCTAssertTrue(text.contains("Version: 0.8.8"))
        
        // Verify services
        XCTAssertTrue(text.contains("WADO-RS (Retrieve):"))
        XCTAssertTrue(text.contains("QIDO-RS (Query):"))
        XCTAssertTrue(text.contains("STOW-RS (Store):"))
        XCTAssertTrue(text.contains("UPS-RS (Worklist):"))
    }
}
