import XCTest
@testable import DICOMWeb

/// Tests for OAuth2 authentication types
final class OAuth2Tests: XCTestCase {
    
    // MARK: - OAuth2Configuration Tests
    
    func testClientCredentialsConfiguration() {
        let tokenURL = URL(string: "https://auth.example.com/token")!
        let config = OAuth2Configuration.clientCredentials(
            tokenEndpoint: tokenURL,
            clientID: "my-client",
            clientSecret: "secret123",
            scopes: ["dicom.read", "dicom.write"]
        )
        
        XCTAssertEqual(config.tokenEndpoint, tokenURL)
        XCTAssertEqual(config.clientID, "my-client")
        XCTAssertEqual(config.clientSecret, "secret123")
        XCTAssertEqual(config.scopes, ["dicom.read", "dicom.write"])
        XCTAssertNil(config.authorizationEndpoint)
        XCTAssertNil(config.redirectURI)
        XCTAssertFalse(config.usePKCE)
    }
    
    func testAuthorizationCodeConfiguration() {
        let authURL = URL(string: "https://auth.example.com/authorize")!
        let tokenURL = URL(string: "https://auth.example.com/token")!
        let redirectURL = URL(string: "myapp://callback")!
        
        let config = OAuth2Configuration.authorizationCode(
            authorizationEndpoint: authURL,
            tokenEndpoint: tokenURL,
            clientID: "my-public-client",
            redirectURI: redirectURL,
            scopes: ["openid", "profile"],
            usePKCE: true
        )
        
        XCTAssertEqual(config.authorizationEndpoint, authURL)
        XCTAssertEqual(config.tokenEndpoint, tokenURL)
        XCTAssertEqual(config.clientID, "my-public-client")
        XCTAssertNil(config.clientSecret)
        XCTAssertEqual(config.redirectURI, redirectURL)
        XCTAssertEqual(config.scopes, ["openid", "profile"])
        XCTAssertTrue(config.usePKCE)
    }
    
    func testAvailableGrantType() {
        // Client credentials
        let clientConfig = OAuth2Configuration.clientCredentials(
            tokenEndpoint: URL(string: "https://auth.example.com/token")!,
            clientID: "client",
            clientSecret: "secret"
        )
        XCTAssertEqual(clientConfig.availableGrantType, .clientCredentials)
        
        // Authorization code
        let authConfig = OAuth2Configuration.authorizationCode(
            authorizationEndpoint: URL(string: "https://auth.example.com/authorize")!,
            tokenEndpoint: URL(string: "https://auth.example.com/token")!,
            clientID: "client",
            redirectURI: URL(string: "myapp://callback")!
        )
        XCTAssertEqual(authConfig.availableGrantType, .authorizationCode)
    }
    
    func testSMARTOnFHIRConfiguration() {
        let fhirBaseURL = URL(string: "https://fhir.example.com")!
        
        let config = OAuth2Configuration.smartOnFHIR(
            fhirBaseURL: fhirBaseURL,
            clientID: "smart-client",
            scopes: [.openID, .fhirUser, .dicomRead]
        )
        
        XCTAssertEqual(config.authorizationEndpoint?.absoluteString, "https://fhir.example.com/authorize")
        XCTAssertEqual(config.tokenEndpoint.absoluteString, "https://fhir.example.com/token")
        XCTAssertEqual(config.clientID, "smart-client")
        XCTAssertTrue(config.scopes.contains("openid"))
        XCTAssertTrue(config.scopes.contains("fhirUser"))
        XCTAssertTrue(config.scopes.contains("system/ImagingStudy.read"))
    }
    
    func testSMARTWellKnownURL() {
        let fhirBaseURL = URL(string: "https://fhir.example.com")!
        let wellKnown = OAuth2Configuration.smartWellKnownURL(for: fhirBaseURL)
        
        XCTAssertEqual(wellKnown.absoluteString, "https://fhir.example.com/.well-known/smart-configuration")
    }
    
    // MARK: - OAuth2Token Tests
    
    func testTokenDecoding() throws {
        let json = """
        {
            "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test",
            "token_type": "Bearer",
            "expires_in": 3600,
            "refresh_token": "refresh_abc123",
            "scope": "openid profile dicom.read"
        }
        """.data(using: .utf8)!
        
        let token = try JSONDecoder().decode(OAuth2Token.self, from: json)
        
        XCTAssertEqual(token.accessToken, "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.refreshToken, "refresh_abc123")
        XCTAssertEqual(token.scope, "openid profile dicom.read")
        XCTAssertEqual(token.scopes, ["openid", "profile", "dicom.read"])
    }
    
    func testTokenExpiration() {
        // Token that expires in 1 hour
        let validToken = OAuth2Token(
            accessToken: "test",
            expiresIn: 3600,
            issuedAt: Date()
        )
        XCTAssertFalse(validToken.isExpired)
        XCTAssertFalse(validToken.willExpireSoon(buffer: 60))
        
        // Token that expired 1 hour ago
        let expiredToken = OAuth2Token(
            accessToken: "test",
            expiresIn: 3600,
            issuedAt: Date().addingTimeInterval(-7200)
        )
        XCTAssertTrue(expiredToken.isExpired)
        XCTAssertTrue(expiredToken.needsRefresh())
        
        // Token expiring soon
        let expiringSoonToken = OAuth2Token(
            accessToken: "test",
            expiresIn: 30,
            issuedAt: Date()
        )
        XCTAssertFalse(expiringSoonToken.isExpired)
        XCTAssertTrue(expiringSoonToken.willExpireSoon(buffer: 60))
    }
    
    func testTokenAuthorizationHeader() {
        let token = OAuth2Token(accessToken: "test_token_123", tokenType: "Bearer")
        XCTAssertEqual(token.authorizationHeader, "Bearer test_token_123")
    }
    
    // MARK: - OAuth2Error Tests
    
    func testErrorDecoding() throws {
        let json = """
        {
            "error": "invalid_grant",
            "error_description": "The refresh token is expired"
        }
        """.data(using: .utf8)!
        
        let error = try JSONDecoder().decode(OAuth2Error.self, from: json)
        
        XCTAssertEqual(error.error, .invalidGrant)
        XCTAssertEqual(error.message, "The refresh token is expired")
    }
    
    func testErrorCodes() {
        let testCases: [(OAuth2Error.ErrorCode, String)] = [
            (.invalidRequest, "invalid_request"),
            (.invalidClient, "invalid_client"),
            (.invalidGrant, "invalid_grant"),
            (.unauthorizedClient, "unauthorized_client"),
            (.unsupportedGrantType, "unsupported_grant_type"),
            (.invalidScope, "invalid_scope"),
            (.accessDenied, "access_denied"),
            (.serverError, "server_error"),
            (.temporarilyUnavailable, "temporarily_unavailable")
        ]
        
        for (code, rawValue) in testCases {
            XCTAssertEqual(code.rawValue, rawValue)
        }
    }
    
    func testErrorLocalizedDescription() {
        let error = OAuth2Error(error: .invalidClient)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("authentication failed"))
    }
    
    // MARK: - PKCE Tests
    
    func testPKCECreation() {
        let pkce = PKCE(
            codeVerifier: "test_verifier_12345",
            codeChallenge: "test_challenge_67890",
            codeChallengeMethod: "S256"
        )
        
        XCTAssertEqual(pkce.codeVerifier, "test_verifier_12345")
        XCTAssertEqual(pkce.codeChallenge, "test_challenge_67890")
        XCTAssertEqual(pkce.codeChallengeMethod, "S256")
    }
    
    // MARK: - Static Token Provider Tests
    
    func testStaticTokenProvider() async throws {
        let provider = StaticTokenProvider(accessToken: "static_token_123")
        
        let token = try await provider.getAccessToken()
        XCTAssertEqual(token, "static_token_123")
        
        let current = await provider.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.accessToken, "static_token_123")
    }
    
    func testStaticTokenProviderClear() async throws {
        let provider = StaticTokenProvider(accessToken: "test")
        
        await provider.clearTokens()
        
        let current = await provider.currentToken
        XCTAssertNil(current)
        
        do {
            _ = try await provider.getAccessToken()
            XCTFail("Expected error")
        } catch let error as OAuth2Error {
            XCTAssertEqual(error.error, .invalidGrant)
        }
    }
    
    func testStaticTokenProviderSetToken() async throws {
        let provider = StaticTokenProvider(accessToken: "original")
        
        let newToken = OAuth2Token(accessToken: "updated_token", expiresIn: 3600)
        await provider.setToken(newToken)
        
        let token = try await provider.getAccessToken()
        XCTAssertEqual(token, "updated_token")
    }
    
    func testStaticTokenProviderRefreshFails() async {
        let provider = StaticTokenProvider(accessToken: "test")
        
        do {
            _ = try await provider.refreshAccessToken()
            XCTFail("Expected error")
        } catch let error as OAuth2Error {
            XCTAssertEqual(error.error, .invalidGrant)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
