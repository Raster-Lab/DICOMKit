import XCTest
@testable import DICOMWeb
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Tests for authentication middleware and JWT handling
final class AuthenticationMiddlewareTests: XCTestCase {
    
    // MARK: - JWT Claims Tests
    
    func testJWTClaimsInit() {
        let claims = JWTClaims(
            issuer: "https://auth.example.com",
            subject: "user123",
            audience: ["client1", "client2"],
            expirationTime: Date().addingTimeInterval(3600),
            scopes: ["dicom.read", "dicom.write"],
            roles: ["dicom.reader", "dicom.writer"],
            clientID: "my-client"
        )
        
        XCTAssertEqual(claims.issuer, "https://auth.example.com")
        XCTAssertEqual(claims.subject, "user123")
        XCTAssertEqual(claims.audience.count, 2)
        XCTAssertEqual(claims.scopes, ["dicom.read", "dicom.write"])
        XCTAssertEqual(claims.roles, ["dicom.reader", "dicom.writer"])
        XCTAssertEqual(claims.clientID, "my-client")
    }
    
    func testJWTClaimsExpiration() {
        // Non-expired token
        let validClaims = JWTClaims(
            expirationTime: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(validClaims.isExpired)
        XCTAssertTrue(validClaims.isValidForUse)
        
        // Expired token
        let expiredClaims = JWTClaims(
            expirationTime: Date().addingTimeInterval(-3600)
        )
        XCTAssertTrue(expiredClaims.isExpired)
        XCTAssertFalse(expiredClaims.isValidForUse)
        
        // Token with no expiration
        let noExpClaims = JWTClaims()
        XCTAssertFalse(noExpClaims.isExpired)
        XCTAssertTrue(noExpClaims.isValidForUse)
    }
    
    func testJWTClaimsNotBefore() {
        // Token that's valid now
        let validClaims = JWTClaims(
            expirationTime: Date().addingTimeInterval(3600),
            notBefore: Date().addingTimeInterval(-3600)
        )
        XCTAssertTrue(validClaims.isValidForUse)
        
        // Token not yet valid
        let notYetValidClaims = JWTClaims(
            expirationTime: Date().addingTimeInterval(7200),
            notBefore: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(notYetValidClaims.isValidForUse)
    }
    
    func testJWTClaimsScopeChecks() {
        let claims = JWTClaims(
            scopes: ["dicom.read", "dicom.write", "openid"]
        )
        
        XCTAssertTrue(claims.hasScope("dicom.read"))
        XCTAssertTrue(claims.hasScope("dicom.write"))
        XCTAssertFalse(claims.hasScope("dicom.delete"))
        
        XCTAssertTrue(claims.hasAnyScope(["dicom.read", "dicom.admin"]))
        XCTAssertFalse(claims.hasAnyScope(["dicom.admin", "dicom.delete"]))
    }
    
    func testJWTClaimsRoleChecks() {
        let claims = JWTClaims(
            roles: ["dicom.reader", "dicom.writer"]
        )
        
        XCTAssertTrue(claims.hasRole("dicom.reader"))
        XCTAssertFalse(claims.hasRole("dicom.admin"))
    }
    
    func testJWTClaimsAudienceChecks() {
        let claims = JWTClaims(
            audience: ["client1", "client2"]
        )
        
        XCTAssertTrue(claims.hasAudience("client1"))
        XCTAssertTrue(claims.hasAudience("client2"))
        XCTAssertFalse(claims.hasAudience("client3"))
    }
    
    // MARK: - JWT Verification Error Tests
    
    func testJWTVerificationErrorDescriptions() {
        let errors: [JWTVerificationError] = [
            .invalidFormat,
            .malformedHeader,
            .malformedPayload,
            .invalidSignature,
            .expired,
            .notYetValid,
            .invalidIssuer(expected: "expected", actual: "actual"),
            .invalidAudience(expected: "client"),
            .unsupportedAlgorithm("RS384"),
            .noSigningKey,
            .missingClaim("sub")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Unsafe JWT Parser Tests
    
    func testUnsafeJWTParserValidToken() throws {
        // Create a simple JWT with base64url encoded parts
        let header = base64URLEncode(#"{"alg":"none","typ":"JWT"}"#)
        let payload = base64URLEncode("""
        {
            "iss": "https://auth.example.com",
            "sub": "user123",
            "aud": ["client1"],
            "exp": \(Int(Date().addingTimeInterval(3600).timeIntervalSince1970)),
            "scope": "dicom.read dicom.write",
            "roles": ["dicom.reader"]
        }
        """)
        let signature = base64URLEncode("test-signature")
        
        let token = "\(header).\(payload).\(signature)"
        
        let parser = UnsafeJWTParser(options: .none)
        let claims = try parser.parseToken(token)
        
        XCTAssertEqual(claims.issuer, "https://auth.example.com")
        XCTAssertEqual(claims.subject, "user123")
        XCTAssertEqual(claims.audience, ["client1"])
        XCTAssertEqual(claims.scopes, ["dicom.read", "dicom.write"])
        XCTAssertEqual(claims.roles, ["dicom.reader"])
    }
    
    func testUnsafeJWTParserInvalidFormat() {
        let parser = UnsafeJWTParser()
        
        // No dots
        XCTAssertThrowsError(try parser.parseToken("invalid")) { error in
            XCTAssertEqual(error as? JWTVerificationError, .invalidFormat)
        }
        
        // Only one dot
        XCTAssertThrowsError(try parser.parseToken("header.payload")) { error in
            XCTAssertEqual(error as? JWTVerificationError, .invalidFormat)
        }
    }
    
    func testUnsafeJWTParserMalformedPayload() {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("not-json")
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let parser = UnsafeJWTParser()
        
        XCTAssertThrowsError(try parser.parseToken(token)) { error in
            XCTAssertEqual(error as? JWTVerificationError, .malformedPayload)
        }
    }
    
    func testUnsafeJWTParserExpiredToken() async throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "exp": \(Int(Date().addingTimeInterval(-3600).timeIntervalSince1970))
        }
        """)
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let parser = UnsafeJWTParser(options: .default)
        
        do {
            _ = try await parser.verify(token)
            XCTFail("Expected error")
        } catch JWTVerificationError.expired {
            // Expected
        }
    }
    
    func testUnsafeJWTParserInvalidIssuer() async throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "iss": "https://wrong.issuer.com",
            "exp": \(Int(Date().addingTimeInterval(3600).timeIntervalSince1970))
        }
        """)
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let options = UnsafeJWTParser.ValidationOptions(
            expectedIssuer: "https://auth.example.com"
        )
        let parser = UnsafeJWTParser(options: options)
        
        do {
            _ = try await parser.verify(token)
            XCTFail("Expected error")
        } catch JWTVerificationError.invalidIssuer(let expected, let actual) {
            XCTAssertEqual(expected, "https://auth.example.com")
            XCTAssertEqual(actual, "https://wrong.issuer.com")
        }
    }
    
    func testUnsafeJWTParserRequiredClaims() async throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "iss": "https://auth.example.com",
            "exp": \(Int(Date().addingTimeInterval(3600).timeIntervalSince1970))
        }
        """)
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let options = UnsafeJWTParser.ValidationOptions(
            requiredClaims: ["sub"]
        )
        let parser = UnsafeJWTParser(options: options)
        
        do {
            _ = try await parser.verify(token)
            XCTFail("Expected error")
        } catch JWTVerificationError.missingClaim(let claim) {
            XCTAssertEqual(claim, "sub")
        }
    }
    
    func testUnsafeJWTParserKeycloakRoles() throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "realm_access": {
                "roles": ["admin", "user"]
            }
        }
        """)
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let parser = UnsafeJWTParser(options: .none)
        let claims = try parser.parseToken(token)
        
        XCTAssertEqual(claims.roles, ["admin", "user"])
    }
    
    func testUnsafeJWTParserSMARTPatientContext() throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "patient": "patient-123"
        }
        """)
        let signature = base64URLEncode("sig")
        
        let token = "\(header).\(payload).\(signature)"
        let parser = UnsafeJWTParser(options: .none)
        let claims = try parser.parseToken(token)
        
        XCTAssertEqual(claims.patientID, "patient-123")
    }
    
    // MARK: - Authenticated User Tests
    
    func testAuthenticatedUserFromClaims() {
        let claims = JWTClaims(
            subject: "user123",
            scopes: ["dicom.read", "dicom.write"],
            roles: ["dicom.reader", "dicom.writer"],
            clientID: "my-client",
            patientID: "patient-456"
        )
        
        let user = AuthenticatedUser(claims: claims)
        
        XCTAssertEqual(user.userID, "user123")
        XCTAssertEqual(user.clientID, "my-client")
        XCTAssertEqual(user.patientContext, "patient-456")
        XCTAssertTrue(user.hasScope("dicom.read"))
        XCTAssertFalse(user.hasScope("dicom.admin"))
        XCTAssertTrue(user.roles.contains(.reader))
        XCTAssertTrue(user.roles.contains(.writer))
    }
    
    func testAuthenticatedUserRoleChecks() {
        let claims = JWTClaims(
            roles: ["dicom.reader", "dicom.admin"]
        )
        let user = AuthenticatedUser(claims: claims)
        
        XCTAssertTrue(user.hasRole(.reader))
        XCTAssertTrue(user.hasRole(.admin))
        XCTAssertFalse(user.hasRole(.deleter))
        
        XCTAssertTrue(user.hasAnyRole([.reader, .writer]))
        XCTAssertFalse(user.hasAnyRole([.deleter, .worklistManager]))
    }
    
    // MARK: - DICOMweb Role Tests
    
    func testDICOMwebRoleScopes() {
        XCTAssertTrue(DICOMwebRole.reader.scopes.contains("dicom.read"))
        XCTAssertTrue(DICOMwebRole.writer.scopes.contains("dicom.write"))
        XCTAssertTrue(DICOMwebRole.admin.scopes.contains("dicom.admin"))
    }
    
    func testDICOMwebRoleImplies() {
        // Admin implies all roles
        XCTAssertTrue(DICOMwebRole.admin.implies(.reader))
        XCTAssertTrue(DICOMwebRole.admin.implies(.writer))
        XCTAssertTrue(DICOMwebRole.admin.implies(.deleter))
        
        // Writer implies reader
        XCTAssertTrue(DICOMwebRole.writer.implies(.reader))
        XCTAssertFalse(DICOMwebRole.writer.implies(.deleter))
        
        // Reader only implies itself
        XCTAssertTrue(DICOMwebRole.reader.implies(.reader))
        XCTAssertFalse(DICOMwebRole.reader.implies(.writer))
    }
    
    // MARK: - DICOMweb Resource Tests
    
    func testResourceFromPath() {
        // Study path
        let studyResource = DICOMwebResource.from(path: "/dicom-web/studies/1.2.3")
        XCTAssertEqual(studyResource.type, .studies)
        XCTAssertEqual(studyResource.studyUID, "1.2.3")
        
        // Series path
        let seriesResource = DICOMwebResource.from(path: "/studies/1.2.3/series/4.5.6")
        XCTAssertEqual(seriesResource.type, .series)
        XCTAssertEqual(seriesResource.studyUID, "1.2.3")
        XCTAssertEqual(seriesResource.seriesUID, "4.5.6")
        
        // Instance path
        let instanceResource = DICOMwebResource.from(path: "/studies/1.2.3/series/4.5.6/instances/7.8.9")
        XCTAssertEqual(instanceResource.type, .instances)
        XCTAssertEqual(instanceResource.studyUID, "1.2.3")
        XCTAssertEqual(instanceResource.seriesUID, "4.5.6")
        XCTAssertEqual(instanceResource.instanceUID, "7.8.9")
        
        // Metadata path
        let metadataResource = DICOMwebResource.from(path: "/studies/1.2.3/metadata")
        XCTAssertEqual(metadataResource.type, .metadata)
        XCTAssertEqual(metadataResource.studyUID, "1.2.3")
        
        // Workitems path
        let workitemResource = DICOMwebResource.from(path: "/workitems/uid123")
        XCTAssertEqual(workitemResource.type, .workitems)
        XCTAssertEqual(workitemResource.workitemUID, "uid123")
        
        // Capabilities path
        let capsResource = DICOMwebResource.from(path: "/capabilities")
        XCTAssertEqual(capsResource.type, .capabilities)
    }
    
    // MARK: - Role-Based Access Policy Tests
    
    func testRoleBasedAccessPolicyAnonymous() {
        // Permissive policy allows anonymous read
        let permissive = RoleBasedAccessPolicy.permissive
        let resource = DICOMwebResource(type: .studies)
        
        XCTAssertTrue(permissive.isAllowed(user: nil, operation: .search, resource: resource))
        XCTAssertTrue(permissive.isAllowed(user: nil, operation: .retrieve, resource: resource))
        XCTAssertFalse(permissive.isAllowed(user: nil, operation: .store, resource: resource))
        
        // Strict policy denies anonymous access
        let strict = RoleBasedAccessPolicy.strict
        XCTAssertFalse(strict.isAllowed(user: nil, operation: .search, resource: resource))
        XCTAssertFalse(strict.isAllowed(user: nil, operation: .capabilities, resource: resource))
    }
    
    func testRoleBasedAccessPolicyCapabilities() {
        // Default allows anonymous capabilities
        let policy = RoleBasedAccessPolicy(allowAnonymousCapabilities: true)
        let resource = DICOMwebResource(type: .capabilities)
        
        XCTAssertTrue(policy.isAllowed(user: nil, operation: .capabilities, resource: resource))
    }
    
    func testRoleBasedAccessPolicyAdminAccess() {
        let policy = RoleBasedAccessPolicy(allowAnonymousRead: false)
        let resource = DICOMwebResource(type: .studies)
        
        let adminClaims = JWTClaims(roles: ["dicom.admin"])
        let adminUser = AuthenticatedUser(claims: adminClaims)
        
        // Admin can do anything
        XCTAssertTrue(policy.isAllowed(user: adminUser, operation: .search, resource: resource))
        XCTAssertTrue(policy.isAllowed(user: adminUser, operation: .store, resource: resource))
        XCTAssertTrue(policy.isAllowed(user: adminUser, operation: .delete, resource: resource))
    }
    
    func testRoleBasedAccessPolicyRoleRequirements() {
        let policy = RoleBasedAccessPolicy(allowAnonymousRead: false)
        let resource = DICOMwebResource(type: .studies)
        
        // Reader can only read
        let readerClaims = JWTClaims(scopes: ["dicom.read"], roles: ["dicom.reader"])
        let reader = AuthenticatedUser(claims: readerClaims)
        
        XCTAssertTrue(policy.isAllowed(user: reader, operation: .search, resource: resource))
        XCTAssertTrue(policy.isAllowed(user: reader, operation: .retrieve, resource: resource))
        XCTAssertFalse(policy.isAllowed(user: reader, operation: .store, resource: resource))
        XCTAssertFalse(policy.isAllowed(user: reader, operation: .delete, resource: resource))
        
        // Writer can read and write
        let writerClaims = JWTClaims(scopes: ["dicom.write", "dicom.read"], roles: ["dicom.writer"])
        let writer = AuthenticatedUser(claims: writerClaims)
        
        XCTAssertTrue(policy.isAllowed(user: writer, operation: .search, resource: resource))
        XCTAssertTrue(policy.isAllowed(user: writer, operation: .store, resource: resource))
        XCTAssertFalse(policy.isAllowed(user: writer, operation: .delete, resource: resource))
    }
    
    func testRoleBasedAccessPolicyPatientContext() {
        let policy = RoleBasedAccessPolicy(allowAnonymousRead: false)
        
        // User scoped to patient123
        let scopedClaims = JWTClaims(
            scopes: ["dicom.read"],
            roles: ["dicom.reader"],
            patientID: "patient123"
        )
        let scopedUser = AuthenticatedUser(claims: scopedClaims)
        
        // Can access matching patient's resources
        let matchingResource = DICOMwebResource(type: .studies, patientID: "patient123")
        XCTAssertTrue(policy.isAllowed(user: scopedUser, operation: .search, resource: matchingResource))
        
        // Cannot access different patient's resources
        let otherResource = DICOMwebResource(type: .studies, patientID: "patient456")
        XCTAssertFalse(policy.isAllowed(user: scopedUser, operation: .search, resource: otherResource))
        
        // Can access resources without patient ID (e.g., search all)
        let noPatientResource = DICOMwebResource(type: .studies)
        XCTAssertTrue(policy.isAllowed(user: scopedUser, operation: .search, resource: noPatientResource))
    }
    
    // MARK: - Authentication Middleware Tests
    
    func testAuthenticationMiddlewareNoToken() async throws {
        let middleware = AuthenticationMiddleware(configuration: .development)
        let request = DICOMwebRequest(method: .get, path: "/studies")
        
        // Development config allows unauthenticated
        let user = try await middleware.authenticate(request)
        XCTAssertNil(user)
    }
    
    func testAuthenticationMiddlewareMissingToken() async {
        let config = AuthenticationConfiguration(
            allowUnauthenticated: false
        )
        let middleware = AuthenticationMiddleware(configuration: config)
        let request = DICOMwebRequest(method: .get, path: "/studies")
        
        do {
            _ = try await middleware.authenticate(request)
            XCTFail("Expected error")
        } catch AuthenticationError.missingToken {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAuthenticationMiddlewareInvalidFormat() async {
        let config = AuthenticationConfiguration(
            allowUnauthenticated: false
        )
        let middleware = AuthenticationMiddleware(configuration: config)
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Authorization": "Basic dXNlcjpwYXNz"]
        )
        
        do {
            _ = try await middleware.authenticate(request)
            XCTFail("Expected error")
        } catch AuthenticationError.invalidTokenFormat {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAuthenticationMiddlewareValidToken() async throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "sub": "user123",
            "scope": "dicom.read"
        }
        """)
        let signature = base64URLEncode("sig")
        let token = "\(header).\(payload).\(signature)"
        
        let config = AuthenticationConfiguration(
            verifier: UnsafeJWTParser(options: .none),
            allowUnauthenticated: false
        )
        let middleware = AuthenticationMiddleware(configuration: config)
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        let user = try await middleware.authenticate(request)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userID, "user123")
        XCTAssertTrue(user?.hasScope("dicom.read") ?? false)
    }
    
    func testAuthenticationMiddlewareAuthorization() async throws {
        let header = base64URLEncode(#"{"alg":"none"}"#)
        let payload = base64URLEncode("""
        {
            "sub": "user123",
            "scope": "dicom.read",
            "roles": ["dicom.reader"]
        }
        """)
        let signature = base64URLEncode("sig")
        let token = "\(header).\(payload).\(signature)"
        
        let config = AuthenticationConfiguration(
            verifier: UnsafeJWTParser(options: .none),
            accessPolicy: RoleBasedAccessPolicy.strict,
            allowUnauthenticated: false
        )
        let middleware = AuthenticationMiddleware(configuration: config)
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Authorization": "Bearer \(token)"]
        )
        let resource = DICOMwebResource(type: .studies)
        
        // Reader can search
        let userForSearch = try await middleware.authenticateAndAuthorize(
            request: request,
            operation: .search,
            resource: resource
        )
        XCTAssertNotNil(userForSearch)
        
        // Reader cannot store
        do {
            _ = try await middleware.authenticateAndAuthorize(
                request: request,
                operation: .store,
                resource: resource
            )
            XCTFail("Expected authorization error")
        } catch AuthorizationError.accessDenied {
            // Expected
        }
    }
    
    // MARK: - Authentication Configuration Tests
    
    func testAuthenticationConfigurationPresets() {
        // Development config
        let dev = AuthenticationConfiguration.development
        XCTAssertNil(dev.verifier)
        XCTAssertTrue(dev.allowUnauthenticated)
        
        // Production config
        let prod = AuthenticationConfiguration.production(
            verifier: UnsafeJWTParser()
        )
        XCTAssertNotNil(prod.verifier)
        XCTAssertFalse(prod.allowUnauthenticated)
    }
    
    // MARK: - Response Helpers Tests
    
    func testUnauthorizedResponse() {
        let response = DICOMwebResponse.unauthorized()
        
        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
        XCTAssertNotNil(response.headers["WWW-Authenticate"])
    }
    
    func testForbiddenResponse() {
        let response = DICOMwebResponse.forbidden(message: "Access denied")
        
        XCTAssertEqual(response.statusCode, 403)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
        XCTAssertNotNil(response.body)
    }
    
    // MARK: - HMAC JWT Verifier Tests (Apple platforms only)
    
    #if canImport(CryptoKit) && (os(macOS) || os(iOS) || os(visionOS))
    func testHMACJWTVerifierValidToken() async throws {
        let secret = "my-super-secret-key-for-testing-hmac"
        let verifier = HMACJWTVerifier(
            secret: secret,
            algorithm: .hs256,
            options: .none
        )
        
        // Create a valid HS256 token
        let header = base64URLEncode(#"{"alg":"HS256","typ":"JWT"}"#)
        let payload = base64URLEncode("""
        {
            "sub": "user123",
            "scope": "dicom.read"
        }
        """)
        
        // Calculate HMAC signature
        let signatureInput = "\(header).\(payload)"
        let signature = calculateHS256Signature(input: signatureInput, secret: secret)
        
        let token = "\(header).\(payload).\(signature)"
        
        let claims = try await verifier.verify(token)
        XCTAssertEqual(claims.subject, "user123")
        XCTAssertEqual(claims.scopes, ["dicom.read"])
    }
    
    func testHMACJWTVerifierInvalidSignature() async {
        let verifier = HMACJWTVerifier(
            secret: "correct-secret",
            algorithm: .hs256,
            options: .none
        )
        
        // Token signed with different secret
        let header = base64URLEncode(#"{"alg":"HS256","typ":"JWT"}"#)
        let payload = base64URLEncode(#"{"sub":"user123"}"#)
        let wrongSignature = calculateHS256Signature(
            input: "\(header).\(payload)",
            secret: "wrong-secret"
        )
        
        let token = "\(header).\(payload).\(wrongSignature)"
        
        do {
            _ = try await verifier.verify(token)
            XCTFail("Expected error")
        } catch JWTVerificationError.invalidSignature {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHMACJWTVerifierWrongAlgorithm() async {
        let verifier = HMACJWTVerifier(
            secret: "secret",
            algorithm: .hs256,
            options: .none
        )
        
        // Token with HS384 header but verifier expects HS256
        let header = base64URLEncode(#"{"alg":"HS384","typ":"JWT"}"#)
        let payload = base64URLEncode(#"{"sub":"user123"}"#)
        let signature = base64URLEncode("somesig")
        
        let token = "\(header).\(payload).\(signature)"
        
        do {
            _ = try await verifier.verify(token)
            XCTFail("Expected error")
        } catch JWTVerificationError.unsupportedAlgorithm(let alg) {
            XCTAssertEqual(alg, "HS384")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // Helper to calculate HS256 signature
    private func calculateHS256Signature(input: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(input.utf8), using: key)
        return base64URLEncode(Data(signature))
    }
    #endif
    
    // MARK: - Error Tests
    
    func testAuthenticationErrorDescriptions() {
        let errors: [AuthenticationError] = [
            .missingToken,
            .invalidTokenFormat,
            .verificationFailed("test reason")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
    
    func testAuthorizationErrorDescriptions() {
        let errors: [AuthorizationError] = [
            .accessDenied(operation: "store"),
            .insufficientPermissions(required: "dicom.admin"),
            .resourceNotAccessible("studies/1.2.3")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
    
    // MARK: - Helpers
    
    private func base64URLEncode(_ string: String) -> String {
        base64URLEncode(Data(string.utf8))
    }
    
    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
