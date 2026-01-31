import Testing
import Foundation
@testable import DICOMNetwork

@Suite("Release PDU Tests")
struct ReleasePDUTests {
    
    // Helper function to read big-endian UInt32 from data
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    @Test("Release Request PDU creation")
    func testReleaseRequestCreation() {
        let request = ReleaseRequestPDU()
        #expect(request.pduType == .releaseRequest)
    }
    
    @Test("Release Request PDU encoding")
    func testReleaseRequestEncoding() throws {
        let request = ReleaseRequestPDU()
        let data = try request.encode()
        
        // PDU Type should be 0x05
        #expect(data[0] == 0x05)
        
        // Reserved byte
        #expect(data[1] == 0x00)
        
        // PDU Length should be 4
        let pduLength = readUInt32(from: data, at: 2)
        #expect(pduLength == 4)
        
        // Total size should be 10 bytes
        #expect(data.count == 10)
        
        // Reserved bytes (4 bytes after header)
        #expect(data[6] == 0x00)
        #expect(data[7] == 0x00)
        #expect(data[8] == 0x00)
        #expect(data[9] == 0x00)
    }
    
    @Test("Release Request round-trip encoding/decoding")
    func testReleaseRequestRoundTrip() throws {
        let original = ReleaseRequestPDU()
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        #expect(decoded is ReleaseRequestPDU)
    }
    
    @Test("Release Response PDU creation")
    func testReleaseResponseCreation() {
        let response = ReleaseResponsePDU()
        #expect(response.pduType == .releaseResponse)
    }
    
    @Test("Release Response PDU encoding")
    func testReleaseResponseEncoding() throws {
        let response = ReleaseResponsePDU()
        let data = try response.encode()
        
        // PDU Type should be 0x06
        #expect(data[0] == 0x06)
        
        // Total size should be 10 bytes
        #expect(data.count == 10)
    }
    
    @Test("Release Response round-trip encoding/decoding")
    func testReleaseResponseRoundTrip() throws {
        let original = ReleaseResponsePDU()
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        #expect(decoded is ReleaseResponsePDU)
    }
    
    @Test("Release PDU descriptions")
    func testReleasePDUDescriptions() {
        let request = ReleaseRequestPDU()
        let response = ReleaseResponsePDU()
        
        #expect(request.description == "A-RELEASE-RQ")
        #expect(response.description == "A-RELEASE-RP")
    }
}

@Suite("Abort PDU Tests")
struct AbortPDUTests {
    
    // Helper function to read big-endian UInt32 from data
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    @Test("Abort PDU creation with source")
    func testAbortCreation() {
        let abort = AbortPDU(source: .serviceUser)
        
        #expect(abort.pduType == .abort)
        #expect(abort.source == .serviceUser)
        #expect(abort.reason == 0)
    }
    
    @Test("Abort PDU creation with reason")
    func testAbortCreationWithReason() {
        let abort = AbortPDU(source: .serviceProvider, reason: .unrecognizedPDU)
        
        #expect(abort.source == .serviceProvider)
        #expect(abort.reason == 1)
    }
    
    @Test("Abort PDU encoding")
    func testAbortEncoding() throws {
        let abort = AbortPDU(source: .serviceProvider, reason: .unexpectedPDU)
        let data = try abort.encode()
        
        // PDU Type should be 0x07
        #expect(data[0] == 0x07)
        
        // PDU Length should be 4
        let pduLength = readUInt32(from: data, at: 2)
        #expect(pduLength == 4)
        
        // Total size should be 10 bytes
        #expect(data.count == 10)
        
        // Source and reason
        #expect(data[8] == 2)  // Service Provider
        #expect(data[9] == 2)  // Unexpected PDU
    }
    
    @Test("Abort PDU reason descriptions")
    func testAbortReasonDescriptions() {
        // Service user abort - reason not meaningful
        var abort = AbortPDU(source: .serviceUser, reason: 0)
        #expect(abort.reasonDescription == "Not specified")
        
        // Service provider abort with reason
        abort = AbortPDU(source: .serviceProvider, reason: .unrecognizedPDU)
        #expect(abort.reasonDescription.contains("Unrecognized PDU"))
        
        abort = AbortPDU(source: .serviceProvider, reason: .unexpectedPDU)
        #expect(abort.reasonDescription.contains("Unexpected PDU"))
        
        abort = AbortPDU(source: .serviceProvider, reason: .invalidPDUParameterValue)
        #expect(abort.reasonDescription.contains("Invalid PDU parameter"))
    }
    
    @Test("Abort PDU round-trip encoding/decoding")
    func testAbortRoundTrip() throws {
        let original = AbortPDU(source: .serviceProvider, reason: .unrecognizedPDUParameter)
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedAbort = decoded as? AbortPDU else {
            #expect(Bool(false), "Decoded PDU is not AbortPDU")
            return
        }
        
        #expect(decodedAbort.source == original.source)
        #expect(decodedAbort.reason == original.reason)
    }
    
    @Test("Abort Source raw values")
    func testAbortSourceRawValues() {
        #expect(AbortSource.serviceUser.rawValue == 0)
        #expect(AbortSource.serviceProvider.rawValue == 2)
    }
    
    @Test("Abort Reason raw values")
    func testAbortReasonRawValues() {
        #expect(AbortReason.notSpecified.rawValue == 0)
        #expect(AbortReason.unrecognizedPDU.rawValue == 1)
        #expect(AbortReason.unexpectedPDU.rawValue == 2)
        #expect(AbortReason.reserved.rawValue == 3)
        #expect(AbortReason.unrecognizedPDUParameter.rawValue == 4)
        #expect(AbortReason.unexpectedPDUParameter.rawValue == 5)
        #expect(AbortReason.invalidPDUParameterValue.rawValue == 6)
    }
}
