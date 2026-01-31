import Testing
@testable import DICOMNetwork

@Suite("PDU Type Tests")
struct PDUTypeTests {
    
    @Test("All PDU types are defined")
    func testAllPDUTypesDefined() {
        #expect(PDUType.allCases.count == 7)
    }
    
    @Test("PDU type raw values are correct")
    func testPDUTypeRawValues() {
        #expect(PDUType.associateRequest.rawValue == 0x01)
        #expect(PDUType.associateAccept.rawValue == 0x02)
        #expect(PDUType.associateReject.rawValue == 0x03)
        #expect(PDUType.dataTransfer.rawValue == 0x04)
        #expect(PDUType.releaseRequest.rawValue == 0x05)
        #expect(PDUType.releaseResponse.rawValue == 0x06)
        #expect(PDUType.abort.rawValue == 0x07)
    }
    
    @Test("PDU type descriptions are correct")
    func testPDUTypeDescriptions() {
        #expect(PDUType.associateRequest.description == "A-ASSOCIATE-RQ")
        #expect(PDUType.associateAccept.description == "A-ASSOCIATE-AC")
        #expect(PDUType.associateReject.description == "A-ASSOCIATE-RJ")
        #expect(PDUType.dataTransfer.description == "P-DATA-TF")
        #expect(PDUType.releaseRequest.description == "A-RELEASE-RQ")
        #expect(PDUType.releaseResponse.description == "A-RELEASE-RP")
        #expect(PDUType.abort.description == "A-ABORT")
    }
    
    @Test("PDU types are Sendable and Hashable")
    func testSendableHashable() {
        var set: Set<PDUType> = []
        set.insert(.associateRequest)
        set.insert(.associateAccept)
        set.insert(.dataTransfer)
        
        #expect(set.count == 3)
        #expect(set.contains(.associateRequest))
    }
}
