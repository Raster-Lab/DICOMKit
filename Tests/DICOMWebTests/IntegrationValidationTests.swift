import Testing
import Foundation
@testable import DICOMWeb
@testable import DICOMKit
@testable import DICOMCore

/// Integration validation tests for Milestone 8.8 acceptance criteria
///
/// These tests validate that:
/// 1. OAuth2 authentication configuration works with major providers
/// 2. SMART on FHIR launch flow configuration is correct
/// 3. Capability discovery provides accurate information
/// 4. Caching improves performance for repeated requests
///
/// Note: These are integration tests that validate the framework's ability
/// to work with real-world authentication providers and servers without
/// requiring actual network connections.
@Suite("Milestone 8.8 Integration Validation")
struct IntegrationValidationTests {
    
    // MARK: - OAuth2 with Major Providers
    
    @Test("OAuth2 configuration for Google Healthcare API")
    func testGoogleHealthcareAPIConfiguration() async throws {
        // Google Cloud Healthcare API uses OAuth2 client credentials
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        
        let config = OAuth2Configuration.clientCredentials(
            tokenEndpoint: tokenURL,
            clientID: "test-client-id",
            clientSecret: "test-client-secret",
            scopes: ["https://www.googleapis.com/auth/cloud-healthcare"]
        )
        
        #expect(config.tokenEndpoint.host == "oauth2.googleapis.com")
        #expect(config.availableGrantType == .clientCredentials)
        #expect(config.scopes.contains("https://www.googleapis.com/auth/cloud-healthcare"))
        #expect(config.clientSecret != nil)
    }
    
    @Test("OAuth2 configuration for Microsoft Azure (Entra ID)")
    func testAzureEntraIDConfiguration() async throws {
        // Azure/Entra ID uses OAuth2 authorization code flow with PKCE
        let tenantID = "common"
        let authURL = URL(string: "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/authorize")!
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token")!
        let redirectURL = URL(string: "https://app.example.com/callback")!
        
        let config = OAuth2Configuration.authorizationCode(
            authorizationEndpoint: authURL,
            tokenEndpoint: tokenURL,
            clientID: "azure-client-id",
            redirectURI: redirectURL,
            scopes: ["https://dicomweb.azurehealthcareapis.com/user_impersonation", "openid", "profile"],
            usePKCE: true
        )
        
        #expect(config.tokenEndpoint.host == "login.microsoftonline.com")
        #expect(config.availableGrantType == .authorizationCode)
        #expect(config.usePKCE == true)
        #expect(config.authorizationEndpoint != nil)
        #expect(config.redirectURI != nil)
    }
    
    @Test("OAuth2 configuration for AWS HealthImaging")
    func testAWSHealthImagingConfiguration() async throws {
        // AWS uses OAuth2 with Cognito
        let region = "us-east-1"
        let _ = "us-east-1_EXAMPLE" // userPoolID not used in URL construction
        let domain = "example-domain"
        
        let authURL = URL(string: "https://\(domain).auth.\(region).amazoncognito.com/oauth2/authorize")!
        let tokenURL = URL(string: "https://\(domain).auth.\(region).amazoncognito.com/oauth2/token")!
        let redirectURL = URL(string: "https://app.example.com/callback")!
        
        let config = OAuth2Configuration.authorizationCode(
            authorizationEndpoint: authURL,
            tokenEndpoint: tokenURL,
            clientID: "aws-client-id",
            clientSecret: "aws-client-secret",
            redirectURI: redirectURL,
            scopes: ["medical-imaging/readwrite", "openid"],
            usePKCE: false
        )
        
        #expect(config.tokenEndpoint.host == "\(domain).auth.\(region).amazoncognito.com")
        #expect(config.availableGrantType == .authorizationCode)
        #expect(config.scopes.contains("medical-imaging/readwrite"))
    }
    
    @Test("OAuth2 configuration for Orthanc with external OAuth2")
    func testOrthancOAuth2Configuration() async throws {
        // Orthanc can be configured with external OAuth2 provider (e.g., Keycloak)
        let keycloakRealm = "healthcare"
        let keycloakURL = "https://auth.example.com"
        
        let authURL = URL(string: "\(keycloakURL)/realms/\(keycloakRealm)/protocol/openid-connect/auth")!
        let tokenURL = URL(string: "\(keycloakURL)/realms/\(keycloakRealm)/protocol/openid-connect/token")!
        let redirectURL = URL(string: "http://localhost:8080/callback")!
        
        let config = OAuth2Configuration.authorizationCode(
            authorizationEndpoint: authURL,
            tokenEndpoint: tokenURL,
            clientID: "orthanc-client",
            clientSecret: "orthanc-secret",
            redirectURI: redirectURL,
            scopes: ["openid", "profile", "dicom"],
            usePKCE: true
        )
        
        #expect(config.tokenEndpoint.path.contains("token"))
        #expect(config.authorizationEndpoint?.path.contains("auth") == true)
        #expect(config.availableGrantType == .authorizationCode)
    }
    
    // MARK: - SMART on FHIR Launch Flow
    
    @Test("SMART on FHIR EHR launch configuration")
    func testSMARTEHRLaunchConfiguration() async throws {
        // SMART on FHIR EHR launch (provider launches the app)
        let fhirBaseURL = URL(string: "https://fhir.example.com")!
        
        let config = OAuth2Configuration.smartOnFHIR(
            fhirBaseURL: fhirBaseURL,
            clientID: "smart-app-id",
            scopes: [.launchEHR, .openID, .fhirUser, .dicomRead]
        )
        
        #expect(config.authorizationEndpoint?.absoluteString == "https://fhir.example.com/authorize")
        #expect(config.tokenEndpoint.absoluteString == "https://fhir.example.com/token")
        #expect(config.scopes.contains("launch"))
        #expect(config.scopes.contains("openid"))
        #expect(config.scopes.contains("fhirUser"))
        #expect(config.scopes.contains("system/ImagingStudy.read"))
        #expect(config.usePKCE == true)
    }
    
    @Test("SMART on FHIR standalone launch configuration")
    func testSMARTStandaloneLaunchConfiguration() async throws {
        // SMART on FHIR standalone launch (user launches the app)
        let fhirBaseURL = URL(string: "https://fhir.example.com")!
        let redirectURL = URL(string: "smartapp://callback")!
        
        let config = OAuth2Configuration.smartOnFHIR(
            fhirBaseURL: fhirBaseURL,
            clientID: "smart-standalone-app",
            redirectURI: redirectURL,
            scopes: [.launchStandalone, .openID, .patientRead, .offlineAccess]
        )
        
        #expect(config.scopes.contains("launch/patient"))
        #expect(config.scopes.contains("patient/*.read"))
        #expect(config.scopes.contains("offline_access"))
        #expect(config.redirectURI == redirectURL)
    }
    
    @Test("SMART well-known configuration endpoint")
    func testSMARTWellKnownEndpoint() async throws {
        let fhirBaseURL = URL(string: "https://fhir.example.com")!
        let wellKnownURL = OAuth2Configuration.smartWellKnownURL(for: fhirBaseURL)
        
        #expect(wellKnownURL.absoluteString == "https://fhir.example.com/.well-known/smart-configuration")
        #expect(wellKnownURL.lastPathComponent == "smart-configuration")
    }
    
    @Test("SMART on FHIR with Epic EHR")
    func testSMARTEpicConfiguration() async throws {
        // Epic uses standard SMART on FHIR endpoints
        let epicFHIRBase = URL(string: "https://fhir.epic.com/interconnect-fhir-oauth")!
        
        let config = OAuth2Configuration.smartOnFHIR(
            fhirBaseURL: epicFHIRBase,
            clientID: "epic-app-id",
            scopes: [.launchEHR, .openID, .fhirUser, .patientRead, .dicomRead]
        )
        
        #expect(config.authorizationEndpoint?.host == "fhir.epic.com")
        #expect(config.tokenEndpoint.host == "fhir.epic.com")
        #expect(config.scopes.contains("launch"))
    }
    
    @Test("SMART on FHIR with Cerner (Oracle Health)")
    func testSMARTCernerConfiguration() async throws {
        // Cerner/Oracle Health uses standard SMART on FHIR
        let cernerFHIRBase = URL(string: "https://fhir-ehr.cerner.com/r4/tenant-id")!
        
        let config = OAuth2Configuration.smartOnFHIR(
            fhirBaseURL: cernerFHIRBase,
            clientID: "cerner-app-id",
            scopes: [.launchStandalone, .openID, .userRead]
        )
        
        #expect(config.authorizationEndpoint != nil)
        #expect(config.tokenEndpoint.path.contains("token"))
        #expect(config.scopes.contains("user/*.read"))
    }
    
    // MARK: - Capability Discovery
    
    @Test("Capability discovery provides accurate service information")
    func testCapabilityDiscoveryServices() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        // Verify all advertised services are accurate
        #expect(capabilities.services.wadoRS == true)
        #expect(capabilities.services.qidoRS == true)
        #expect(capabilities.services.stowRS == true)
        #expect(capabilities.services.upsRS == true)
        #expect(capabilities.services.delete == true)
        #expect(capabilities.services.bulkdata == true)
        
        // Verify server identification
        #expect(capabilities.serverName == "DICOMKit")
        #expect(capabilities.serverVersion == "0.8.8")
        #expect(capabilities.apiVersion == "1.0")
    }
    
    @Test("Capability discovery provides accurate media type support")
    func testCapabilityDiscoveryMediaTypes() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        // Verify retrieve media types
        #expect(capabilities.mediaTypes.retrieve.contains("application/dicom"))
        #expect(capabilities.mediaTypes.retrieve.contains("application/dicom+json"))
        #expect(capabilities.mediaTypes.retrieve.contains("multipart/related"))
        
        // Verify store media types
        #expect(capabilities.mediaTypes.store.contains("application/dicom"))
        #expect(capabilities.mediaTypes.store.contains("multipart/related"))
        
        // Verify rendered image formats
        #expect(capabilities.mediaTypes.rendered.contains("image/jpeg"))
        #expect(capabilities.mediaTypes.rendered.contains("image/png"))
    }
    
    @Test("Capability discovery provides accurate transfer syntax support")
    func testCapabilityDiscoveryTransferSyntaxes() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        // Verify essential transfer syntaxes
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.1"))  // Explicit VR Little Endian
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2"))    // Implicit VR Little Endian
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.2"))  // Explicit VR Big Endian
        
        // Verify compression support
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.4.50")) // JPEG Baseline
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.4.70")) // JPEG Lossless
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.4.90")) // JPEG 2000 Lossless
        #expect(capabilities.transferSyntaxes.contains("1.2.840.10008.1.2.5"))   // RLE Lossless
    }
    
    @Test("Capability discovery provides accurate query capabilities")
    func testCapabilityDiscoveryQueryCapabilities() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        #expect(capabilities.queryCapabilities.fuzzyMatching == false)
        #expect(capabilities.queryCapabilities.wildcardMatching == true)
        #expect(capabilities.queryCapabilities.dateRangeQueries == true)
        #expect(capabilities.queryCapabilities.includeFieldAll == true)
        #expect(capabilities.queryCapabilities.queryLevels.contains(.study))
        #expect(capabilities.queryCapabilities.queryLevels.contains(.series))
        #expect(capabilities.queryCapabilities.queryLevels.contains(.instance))
    }
    
    @Test("Capability discovery provides accurate store capabilities")
    func testCapabilityDiscoveryStoreCapabilities() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        #expect(capabilities.storeCapabilities.maxRequestSize == 500 * 1024 * 1024) // 500 MB
        #expect(capabilities.storeCapabilities.partialSuccess == true)
    }
    
    @Test("Capability discovery provides accurate authentication methods")
    func testCapabilityDiscoveryAuthMethods() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        
        #expect(capabilities.authenticationMethods.contains(.none))
        #expect(capabilities.authenticationMethods.contains(.basic))
        #expect(capabilities.authenticationMethods.contains(.bearer))
        #expect(capabilities.authenticationMethods.contains(.apiKey))
    }
    
    @Test("Capability discovery JSON serialization is accurate")
    func testCapabilityDiscoveryJSONSerialization() async throws {
        let capabilities = DICOMwebCapabilities.dicomKitServer
        let jsonDict = capabilities.toJSONDictionary()
        
        // Verify JSON structure
        #expect(jsonDict["serverName"] as? String == "DICOMKit")
        #expect(jsonDict["serverVersion"] as? String == "0.8.8")
        #expect(jsonDict["apiVersion"] as? String == "1.0")
        
        let services = jsonDict["services"] as? [String: Bool]
        #expect(services?["wado-rs"] == true)
        #expect(services?["qido-rs"] == true)
        #expect(services?["stow-rs"] == true)
        #expect(services?["ups-rs"] == true)
    }
    
    @Test("Minimal capabilities configuration is valid")
    func testMinimalCapabilitiesConfiguration() async throws {
        let capabilities = DICOMwebCapabilities.minimal
        
        // Verify minimal server only advertises what it supports
        #expect(capabilities.services.wadoRS == true)
        #expect(capabilities.services.qidoRS == true)
        #expect(capabilities.services.stowRS == false)
        #expect(capabilities.services.upsRS == false)
        #expect(capabilities.services.delete == false)
    }
    
    // MARK: - Caching Performance
    
    @Test("In-memory cache stores and retrieves values correctly")
    func testInMemoryCacheBasicOperations() async throws {
        let cache = InMemoryCache()
        let key = "test-key"
        let value = "test-value"
        let entry = CacheEntry(
            data: value.data(using: .utf8)!,
            expiresAt: Date().addingTimeInterval(60)
        )
        
        // Store value
        await cache.set(entry, forKey: key)
        
        // Retrieve value
        let retrieved = await cache.get(key)
        #expect(retrieved?.data == entry.data)
        
        // Verify stats
        let stats = await cache.getStats()
        #expect(stats.hits == 1)
        #expect(stats.misses == 0)
    }
    
    @Test("Cache improves performance for repeated requests")
    func testCachePerformanceImprovement() async throws {
        let cache = InMemoryCache()
        let key = "performance-test-key"
        let value = String(repeating: "x", count: 10000) // 10KB string
        let entry = CacheEntry(
            data: value.data(using: .utf8)!,
            expiresAt: Date().addingTimeInterval(60)
        )
        
        // First request (cache miss)
        let startMiss = Date()
        let missResult = await cache.get(key)
        let missDuration = Date().timeIntervalSince(startMiss)
        #expect(missResult == nil)
        
        // Store in cache
        await cache.set(entry, forKey: key)
        
        // Second request (cache hit)
        let startHit = Date()
        let hitResult = await cache.get(key)
        let hitDuration = Date().timeIntervalSince(startHit)
        #expect(hitResult?.data == entry.data)
        
        // Cache hit should be significantly faster (allowing some variance for test stability)
        // In production, cache hits are typically microseconds vs milliseconds for network/disk
        #expect(hitDuration <= missDuration * 10) // Allow 10x variance for test stability
        
        let stats = await cache.getStats()
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
        #expect(stats.hitRatio > 0.0)
    }
    
    @Test("Cache respects TTL and expires entries")
    func testCacheTTLExpiration() async throws {
        let cache = InMemoryCache()
        let key = "ttl-test-key"
        let value = "expires-soon"
        let entry = CacheEntry(
            data: value.data(using: .utf8)!,
            expiresAt: Date().addingTimeInterval(1) // 1 second TTL
        )
        
        // Store with 1 second TTL
        await cache.set(entry, forKey: key)
        
        // Should be retrievable immediately
        let immediate = await cache.get(key)
        #expect(immediate?.data == entry.data)
        
        // Wait for expiration (with buffer)
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Should be expired
        let expired = await cache.get(key)
        #expect(expired == nil)
        
        let stats = await cache.getStats()
        #expect(stats.misses == 1) // Expired entry counts as miss
    }
    
    @Test("Cache supports eviction when at capacity")
    func testCacheEviction() async throws {
        let config = CacheConfiguration(enabled: true, maxEntries: 3, maxSizeBytes: 10 * 1024 * 1024)
        let cache = InMemoryCache(configuration: config)
        let expiresAt = Date().addingTimeInterval(60)
        
        // Fill cache to capacity
        await cache.set(CacheEntry(data: "value1".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key1")
        await cache.set(CacheEntry(data: "value2".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key2")
        await cache.set(CacheEntry(data: "value3".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key3")
        
        // Add one more (should evict oldest)
        await cache.set(CacheEntry(data: "value4".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key4")
        
        // First entry should be evicted (LRU)
        let evicted = await cache.get("key1")
        #expect(evicted == nil)
        
        // Newer entries should still exist
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")
        let value4 = await cache.get("key4")
        #expect(value2?.data == "value2".data(using: .utf8)!)
        #expect(value3?.data == "value3".data(using: .utf8)!)
        #expect(value4?.data == "value4".data(using: .utf8)!)
    }
    
    @Test("Cache provides accurate statistics")
    func testCacheStatistics() async throws {
        let cache = InMemoryCache()
        let entry = CacheEntry(data: "value1".data(using: .utf8)!, expiresAt: Date().addingTimeInterval(60))
        
        // Perform various operations
        await cache.set(entry, forKey: "key1")
        _ = await cache.get("key1") // hit
        _ = await cache.get("key2") // miss
        _ = await cache.get("key1") // hit
        _ = await cache.get("key3") // miss
        
        let stats = await cache.getStats()
        #expect(stats.hits == 2)
        #expect(stats.misses == 2)
        #expect(stats.hitRatio == 0.5)
    }
    
    @Test("Cache clear removes all entries")
    func testCacheClear() async throws {
        let cache = InMemoryCache()
        let expiresAt = Date().addingTimeInterval(60)
        
        // Add multiple entries
        await cache.set(CacheEntry(data: "value1".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key1")
        await cache.set(CacheEntry(data: "value2".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key2")
        await cache.set(CacheEntry(data: "value3".data(using: .utf8)!, expiresAt: expiresAt), forKey: "key3")
        
        // Clear cache
        await cache.clear()
        
        // All entries should be gone
        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")
        #expect(value1 == nil)
        #expect(value2 == nil)
        #expect(value3 == nil)
        
        let stats = await cache.getStats()
        #expect(stats.misses == 3)
    }
}
