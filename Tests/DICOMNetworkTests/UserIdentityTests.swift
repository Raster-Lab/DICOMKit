import Testing
import Foundation
@testable import DICOMNetwork

// Helper function to read big-endian UInt16 from data
fileprivate func readUInt16BigEndian(from data: Data, at offset: Int) -> UInt16 {
    return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
}

// Helper function to read big-endian UInt32 from data
fileprivate func readUInt32BigEndian(from data: Data, at offset: Int) -> UInt32 {
    return (UInt32(data[offset]) << 24) |
           (UInt32(data[offset + 1]) << 16) |
           (UInt32(data[offset + 2]) << 8) |
           UInt32(data[offset + 3])
}

@Suite("User Identity Type Tests")
struct UserIdentityTypeTests {
    
    @Test("UserIdentityType raw values")
    func testUserIdentityTypeRawValues() {
        #expect(UserIdentityType.username.rawValue == 1)
        #expect(UserIdentityType.usernameAndPasscode.rawValue == 2)
        #expect(UserIdentityType.kerberos.rawValue == 3)
        #expect(UserIdentityType.saml.rawValue == 4)
        #expect(UserIdentityType.jwt.rawValue == 5)
    }
    
    @Test("UserIdentityType description")
    func testUserIdentityTypeDescription() {
        #expect(UserIdentityType.username.description == "username")
        #expect(UserIdentityType.usernameAndPasscode.description == "usernameAndPasscode")
        #expect(UserIdentityType.kerberos.description == "kerberos")
        #expect(UserIdentityType.saml.description == "saml")
        #expect(UserIdentityType.jwt.description == "jwt")
    }
}

@Suite("User Identity Tests")
struct UserIdentityTests {
    
    @Test("Username only identity creation")
    func testUsernameOnlyIdentity() {
        let identity = UserIdentity.username("testuser")
        
        #expect(identity.identityType == .username)
        #expect(identity.username == "testuser")
        #expect(identity.positiveResponseRequested == false)
        #expect(identity.primaryField == Data("testuser".utf8))
        #expect(identity.secondaryField == nil)
    }
    
    @Test("Username only identity with positive response")
    func testUsernameOnlyIdentityWithResponse() {
        let identity = UserIdentity.username("testuser", positiveResponseRequested: true)
        
        #expect(identity.identityType == .username)
        #expect(identity.positiveResponseRequested == true)
    }
    
    @Test("Username and passcode identity creation")
    func testUsernameAndPasscodeIdentity() {
        let identity = UserIdentity.usernameAndPasscode(
            username: "admin",
            passcode: "secret123"
        )
        
        #expect(identity.identityType == .usernameAndPasscode)
        #expect(identity.username == "admin")
        #expect(identity.positiveResponseRequested == false)
        #expect(identity.primaryField == Data("admin".utf8))
        #expect(identity.secondaryField == Data("secret123".utf8))
    }
    
    @Test("Kerberos identity creation")
    func testKerberosIdentity() {
        let ticket = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let identity = UserIdentity.kerberos(serviceTicket: ticket)
        
        #expect(identity.identityType == .kerberos)
        #expect(identity.positiveResponseRequested == true) // Default for Kerberos
        #expect(identity.primaryField == ticket)
        #expect(identity.secondaryField == nil)
        #expect(identity.username == nil) // Not applicable for Kerberos
    }
    
    @Test("SAML identity creation")
    func testSAMLIdentity() {
        let assertion = Data("<saml>...</saml>".utf8)
        let identity = UserIdentity.saml(assertion: assertion)
        
        #expect(identity.identityType == .saml)
        #expect(identity.positiveResponseRequested == true) // Default for SAML
        #expect(identity.primaryField == assertion)
    }
    
    @Test("JWT identity creation")
    func testJWTIdentity() {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0"
        let identity = UserIdentity.jwt(token: token)
        
        #expect(identity.identityType == .jwt)
        #expect(identity.positiveResponseRequested == true) // Default for JWT
        #expect(identity.primaryField == Data(token.utf8))
    }
    
    @Test("User identity description")
    func testUserIdentityDescription() {
        let identity = UserIdentity.username("testuser", positiveResponseRequested: true)
        let description = identity.description
        
        #expect(description.contains("username"))
        #expect(description.contains("testuser"))
        #expect(description.contains("positiveResponseRequested"))
    }
    
    @Test("User identity Hashable conformance")
    func testUserIdentityHashable() {
        let identity1 = UserIdentity.username("user1")
        let identity2 = UserIdentity.username("user1")
        let identity3 = UserIdentity.username("user2")
        
        #expect(identity1 == identity2)
        #expect(identity1 != identity3)
        #expect(identity1.hashValue == identity2.hashValue)
    }
}

@Suite("User Identity Encoding Tests")
struct UserIdentityEncodingTests {
    
    @Test("Username only encoding")
    func testUsernameOnlyEncoding() {
        let identity = UserIdentity.username("testuser")
        let encoded = identity.encode()
        
        // Sub-item type should be 0x58
        #expect(encoded[0] == 0x58)
        
        // Reserved byte should be 0x00
        #expect(encoded[1] == 0x00)
        
        // User identity type should be 1 (username)
        #expect(encoded[4] == 1)
        
        // Positive response requested should be 0
        #expect(encoded[5] == 0)
        
        // Primary field length should match username length
        let primaryLength = readUInt16BigEndian(from: encoded, at: 6)
        #expect(primaryLength == UInt16("testuser".count))
    }
    
    @Test("Username and passcode encoding")
    func testUsernameAndPasscodeEncoding() {
        let identity = UserIdentity.usernameAndPasscode(
            username: "admin",
            passcode: "password",
            positiveResponseRequested: true
        )
        let encoded = identity.encode()
        
        // Sub-item type should be 0x58
        #expect(encoded[0] == 0x58)
        
        // User identity type should be 2 (username + passcode)
        #expect(encoded[4] == 2)
        
        // Positive response requested should be 1
        #expect(encoded[5] == 1)
        
        // Primary field length
        let primaryLength = readUInt16BigEndian(from: encoded, at: 6)
        #expect(primaryLength == UInt16("admin".count))
        
        // Secondary field should follow primary
        let secondaryOffset = 8 + Int(primaryLength)
        let secondaryLength = readUInt16BigEndian(from: encoded, at: secondaryOffset)
        #expect(secondaryLength == UInt16("password".count))
    }
}

@Suite("User Identity Server Response Tests")
struct UserIdentityServerResponseTests {
    
    @Test("Server response creation")
    func testServerResponseCreation() {
        let responseData = Data([0x01, 0x02, 0x03, 0x04])
        let response = UserIdentityServerResponse(serverResponse: responseData)
        
        #expect(response.serverResponse == responseData)
    }
    
    @Test("Server response encoding")
    func testServerResponseEncoding() {
        let responseData = Data([0x01, 0x02, 0x03, 0x04])
        let response = UserIdentityServerResponse(serverResponse: responseData)
        let encoded = response.encode()
        
        // Sub-item type should be 0x59
        #expect(encoded[0] == 0x59)
        
        // Reserved byte should be 0x00
        #expect(encoded[1] == 0x00)
        
        // Item length (2 + response length)
        let itemLength = readUInt16BigEndian(from: encoded, at: 2)
        #expect(itemLength == 6) // 2 (response length field) + 4 (response data)
        
        // Response length
        let responseLength = readUInt16BigEndian(from: encoded, at: 4)
        #expect(responseLength == 4)
    }
    
    @Test("Server response Hashable conformance")
    func testServerResponseHashable() {
        let response1 = UserIdentityServerResponse(serverResponse: Data([0x01, 0x02]))
        let response2 = UserIdentityServerResponse(serverResponse: Data([0x01, 0x02]))
        let response3 = UserIdentityServerResponse(serverResponse: Data([0x03, 0x04]))
        
        #expect(response1 == response2)
        #expect(response1 != response3)
    }
}

@Suite("User Identity in AssociateRequestPDU Tests")
struct UserIdentityAssociateRequestTests {
    
    @Test("AssociateRequestPDU with user identity")
    func testAssociateRequestWithUserIdentity() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let userIdentity = UserIdentity.username("testuser", positiveResponseRequested: true)
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("PACS_SERVER"),
            callingAETitle: try AETitle("MY_CLIENT"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5.6.7.8.9",
            userIdentity: userIdentity
        )
        
        #expect(request.userIdentity != nil)
        #expect(request.userIdentity?.identityType == .username)
        #expect(request.userIdentity?.username == "testuser")
    }
    
    @Test("AssociateRequestPDU without user identity")
    func testAssociateRequestWithoutUserIdentity() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("PACS_SERVER"),
            callingAETitle: try AETitle("MY_CLIENT"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5.6.7.8.9"
        )
        
        #expect(request.userIdentity == nil)
    }
    
    @Test("AssociateRequestPDU description includes user identity")
    func testAssociateRequestDescriptionWithUserIdentity() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let userIdentity = UserIdentity.username("admin")
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("SCP"),
            callingAETitle: try AETitle("SCU"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5",
            userIdentity: userIdentity
        )
        
        let description = request.description
        #expect(description.contains("User Identity"))
    }
    
    @Test("AssociateRequestPDU round-trip with user identity")
    func testAssociateRequestRoundTripWithUserIdentity() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let userIdentity = UserIdentity.usernameAndPasscode(
            username: "testuser",
            passcode: "testpass",
            positiveResponseRequested: true
        )
        
        let original = AssociateRequestPDU(
            calledAETitle: try AETitle("PACS_SERVER"),
            callingAETitle: try AETitle("MY_CLIENT"),
            presentationContexts: [context],
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6.7.8.9",
            implementationVersionName: "TEST_V1",
            userIdentity: userIdentity
        )
        
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedRequest = decoded as? AssociateRequestPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateRequestPDU")
            return
        }
        
        #expect(decodedRequest.userIdentity != nil)
        #expect(decodedRequest.userIdentity?.identityType == .usernameAndPasscode)
        #expect(decodedRequest.userIdentity?.username == "testuser")
        #expect(decodedRequest.userIdentity?.positiveResponseRequested == true)
    }
}

@Suite("User Identity in AssociateAcceptPDU Tests")
struct UserIdentityAssociateAcceptTests {
    
    @Test("AssociateAcceptPDU with server response")
    func testAssociateAcceptWithServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let serverResponse = UserIdentityServerResponse(serverResponse: Data([0x01, 0x02, 0x03]))
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("MY_CLIENT"),
            callingAETitle: try AETitle("PACS_SERVER"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5.6.7",
            userIdentityServerResponse: serverResponse
        )
        
        #expect(accept.userIdentityServerResponse != nil)
        #expect(accept.userIdentityServerResponse?.serverResponse == Data([0x01, 0x02, 0x03]))
    }
    
    @Test("AssociateAcceptPDU without server response")
    func testAssociateAcceptWithoutServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("MY_CLIENT"),
            callingAETitle: try AETitle("PACS_SERVER"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5.6.7"
        )
        
        #expect(accept.userIdentityServerResponse == nil)
    }
    
    @Test("AssociateAcceptPDU description with server response")
    func testAssociateAcceptDescriptionWithServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let serverResponse = UserIdentityServerResponse(serverResponse: Data([0x01]))
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5",
            userIdentityServerResponse: serverResponse
        )
        
        let description = accept.description
        #expect(description.contains("User Identity Response"))
    }
    
    @Test("AssociateAcceptPDU round-trip with server response")
    func testAssociateAcceptRoundTripWithServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let serverResponse = UserIdentityServerResponse(
            serverResponse: Data("server_ticket_data".utf8)
        )
        
        let original = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [accepted],
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6",
            implementationVersionName: "TEST",
            userIdentityServerResponse: serverResponse
        )
        
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedAccept = decoded as? AssociateAcceptPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateAcceptPDU")
            return
        }
        
        #expect(decodedAccept.userIdentityServerResponse != nil)
        #expect(decodedAccept.userIdentityServerResponse?.serverResponse == Data("server_ticket_data".utf8))
    }
}

@Suite("User Identity in Configuration Tests")
struct UserIdentityConfigurationTests {
    
    @Test("AssociationConfiguration with user identity")
    func testAssociationConfigurationWithUserIdentity() throws {
        let userIdentity = UserIdentity.username("admin")
        
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            port: 11112,
            implementationClassUID: "1.2.3.4.5",
            userIdentity: userIdentity
        )
        
        #expect(config.userIdentity != nil)
        #expect(config.userIdentity?.username == "admin")
    }
    
    @Test("VerificationConfiguration with user identity")
    func testVerificationConfigurationWithUserIdentity() throws {
        let userIdentity = UserIdentity.username("testuser")
        
        let config = VerificationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            userIdentity: userIdentity
        )
        
        #expect(config.userIdentity != nil)
        #expect(config.userIdentity?.username == "testuser")
    }
    
    @Test("QueryConfiguration with user identity")
    func testQueryConfigurationWithUserIdentity() throws {
        let userIdentity = UserIdentity.usernameAndPasscode(
            username: "query_user",
            passcode: "password"
        )
        
        let config = QueryConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            userIdentity: userIdentity
        )
        
        #expect(config.userIdentity != nil)
        #expect(config.userIdentity?.identityType == .usernameAndPasscode)
    }
    
    #if canImport(Network)
    @Test("DICOMClientConfiguration with user identity") 
    func testDICOMClientConfigurationWithUserIdentity() throws {
        let userIdentity = UserIdentity.jwt(token: "eyJhbGciOiJIUzI1NiIs...")
        
        let config = try DICOMClientConfiguration(
            host: "pacs.example.com",
            port: 11112,
            callingAE: "SCU",
            calledAE: "SCP",
            userIdentity: userIdentity
        )
        
        #expect(config.userIdentity != nil)
        #expect(config.userIdentity?.identityType == .jwt)
    }
    
    @Test("DICOMClientConfiguration without user identity")
    func testDICOMClientConfigurationWithoutUserIdentity() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.example.com",
            port: 11112,
            callingAE: "SCU",
            calledAE: "SCP"
        )
        
        #expect(config.userIdentity == nil)
    }
    #endif
}

@Suite("User Identity in NegotiatedAssociation Tests")
struct UserIdentityNegotiatedAssociationTests {
    
    @Test("NegotiatedAssociation includes server response")
    func testNegotiatedAssociationWithServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let serverResponse = UserIdentityServerResponse(serverResponse: Data([0x01, 0x02]))
        
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5",
            userIdentityServerResponse: serverResponse
        )
        
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        
        #expect(negotiated.userIdentityServerResponse != nil)
        #expect(negotiated.userIdentityServerResponse?.serverResponse == Data([0x01, 0x02]))
    }
    
    @Test("NegotiatedAssociation without server response")
    func testNegotiatedAssociationWithoutServerResponse() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5"
        )
        
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        
        #expect(negotiated.userIdentityServerResponse == nil)
    }
}
