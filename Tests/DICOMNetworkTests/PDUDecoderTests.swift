import Testing
import Foundation
@testable import DICOMNetwork

@Suite("PDU Decoder Tests")
struct PDUDecoderTests {
    
    @Test("Decoder reads PDU header correctly")
    func testReadPDUHeader() throws {
        // Create a minimal PDU header (A-RELEASE-RQ)
        var data = Data()
        data.append(0x05)  // PDU Type
        data.append(0x00)  // Reserved
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])  // Length = 4 (big endian)
        
        let (pduType, pduLength) = try PDUDecoder.readHeader(from: data)
        
        #expect(pduType == .releaseRequest)
        #expect(pduLength == 4)
    }
    
    @Test("Decoder throws for short header")
    func testDecoderThrowsForShortHeader() {
        let shortData = Data([0x01, 0x00, 0x00])  // Only 3 bytes
        
        #expect(throws: DICOMNetworkError.self) {
            _ = try PDUDecoder.readHeader(from: shortData)
        }
    }
    
    @Test("Decoder throws for unknown PDU type")
    func testDecoderThrowsForUnknownPDUType() {
        var data = Data()
        data.append(0xFF)  // Invalid PDU Type
        data.append(0x00)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])
        
        #expect(throws: DICOMNetworkError.self) {
            _ = try PDUDecoder.readHeader(from: data)
        }
    }
    
    @Test("Decoder throws when data is shorter than declared length")
    func testDecoderThrowsForIncompleteData() throws {
        // Create an A-RELEASE-RQ header that says length is 4
        // but only provide 2 bytes of content
        var data = Data()
        data.append(0x05)  // PDU Type
        data.append(0x00)  // Reserved
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])  // Length = 4
        data.append(contentsOf: [0x00, 0x00])  // Only 2 bytes of content
        
        #expect(throws: DICOMNetworkError.self) {
            _ = try PDUDecoder.decode(from: data)
        }
    }
    
    @Test("Decoder handles A-RELEASE-RQ")
    func testDecodeReleaseRequest() throws {
        let original = ReleaseRequestPDU()
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        #expect(decoded is ReleaseRequestPDU)
        #expect(decoded.pduType == .releaseRequest)
    }
    
    @Test("Decoder handles A-RELEASE-RP")
    func testDecodeReleaseResponse() throws {
        let original = ReleaseResponsePDU()
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        #expect(decoded is ReleaseResponsePDU)
        #expect(decoded.pduType == .releaseResponse)
    }
    
    @Test("Decoder handles A-ABORT")
    func testDecodeAbort() throws {
        let original = AbortPDU(source: .serviceProvider, reason: .unexpectedPDU)
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let abortPDU = decoded as? AbortPDU else {
            #expect(Bool(false), "Decoded PDU is not AbortPDU")
            return
        }
        
        #expect(abortPDU.source == .serviceProvider)
        #expect(abortPDU.reason == AbortReason.unexpectedPDU.rawValue)
    }
    
    @Test("Decoder handles A-ASSOCIATE-RJ")
    func testDecodeAssociateReject() throws {
        let original = AssociateRejectPDU(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 7
        )
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let rejectPDU = decoded as? AssociateRejectPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateRejectPDU")
            return
        }
        
        #expect(rejectPDU.result == .rejectedPermanent)
        #expect(rejectPDU.source == .serviceUser)
        #expect(rejectPDU.reason == 7)
    }
    
    @Test("Decoder handles P-DATA-TF")
    func testDecodeDataTransfer() throws {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02, 0x03, 0x04])
        )
        let original = DataTransferPDU(pdv: pdv)
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let dataPDU = decoded as? DataTransferPDU else {
            #expect(Bool(false), "Decoded PDU is not DataTransferPDU")
            return
        }
        
        #expect(dataPDU.presentationDataValues.count == 1)
        let decodedPDV = dataPDU.presentationDataValues[0]
        #expect(decodedPDV.presentationContextID == 1)
        #expect(decodedPDV.isCommand == true)
        #expect(decodedPDV.isLastFragment == true)
        #expect(decodedPDV.data == Data([0x01, 0x02, 0x03, 0x04]))
    }
    
    @Test("Decoder handles multiple PDVs in P-DATA-TF")
    func testDecodeMultiplePDVs() throws {
        let pdv1 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0xAA])
        )
        let pdv2 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: false,
            data: Data([0xBB, 0xCC])
        )
        let pdv3 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: true,
            data: Data([0xDD])
        )
        
        let original = DataTransferPDU(presentationDataValues: [pdv1, pdv2, pdv3])
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let dataPDU = decoded as? DataTransferPDU else {
            #expect(Bool(false), "Decoded PDU is not DataTransferPDU")
            return
        }
        
        #expect(dataPDU.presentationDataValues.count == 3)
        #expect(dataPDU.presentationDataValues[0].isCommand == true)
        #expect(dataPDU.presentationDataValues[1].isCommand == false)
        #expect(dataPDU.presentationDataValues[1].isLastFragment == false)
        #expect(dataPDU.presentationDataValues[2].isLastFragment == true)
    }
}
