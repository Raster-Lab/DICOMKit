import Testing
import Foundation
@testable import DICOMNetwork

@Suite("Data Transfer PDU Tests")
struct DataTransferPDUTests {
    
    // Helper function to read big-endian UInt32 from data
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    @Test("Data Transfer PDU creation with single PDV")
    func testDataTransferCreationSinglePDV() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02, 0x03, 0x04])
        )
        
        let pdu = DataTransferPDU(pdv: pdv)
        
        #expect(pdu.pduType == .dataTransfer)
        #expect(pdu.presentationDataValues.count == 1)
        #expect(pdu.totalDataLength == 4)
    }
    
    @Test("Data Transfer PDU creation with multiple PDVs")
    func testDataTransferCreationMultiplePDVs() {
        let pdv1 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02])
        )
        let pdv2 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: false,
            data: Data([0x03, 0x04, 0x05])
        )
        
        let pdu = DataTransferPDU(presentationDataValues: [pdv1, pdv2])
        
        #expect(pdu.presentationDataValues.count == 2)
        #expect(pdu.totalDataLength == 5)
    }
    
    @Test("Data Transfer PDU encoding")
    func testDataTransferEncoding() throws {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0xAA, 0xBB, 0xCC])
        )
        
        let pdu = DataTransferPDU(pdv: pdv)
        let data = try pdu.encode()
        
        // PDU Type should be 0x04
        #expect(data[0] == 0x04)
        
        // Reserved byte
        #expect(data[1] == 0x00)
        
        // Check PDU length
        let pduLength = readUInt32(from: data, at: 2)
        #expect(pduLength > 0)
    }
    
    @Test("Data Transfer PDU round-trip encoding/decoding")
    func testDataTransferRoundTrip() throws {
        let pdv = PresentationDataValue(
            presentationContextID: 5,
            isCommand: false,
            isLastFragment: true,
            data: Data([0x01, 0x02, 0x03, 0x04, 0x05])
        )
        
        let original = DataTransferPDU(pdv: pdv)
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedPDU = decoded as? DataTransferPDU else {
            #expect(Bool(false), "Decoded PDU is not DataTransferPDU")
            return
        }
        
        #expect(decodedPDU.presentationDataValues.count == 1)
        
        let decodedPDV = decodedPDU.presentationDataValues[0]
        #expect(decodedPDV.presentationContextID == pdv.presentationContextID)
        #expect(decodedPDV.isCommand == pdv.isCommand)
        #expect(decodedPDV.isLastFragment == pdv.isLastFragment)
        #expect(decodedPDV.data == pdv.data)
    }
    
    @Test("Data Transfer PDU description")
    func testDataTransferDescription() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02, 0x03])
        )
        
        let pdu = DataTransferPDU(pdv: pdv)
        
        #expect(pdu.description.contains("P-DATA-TF"))
        #expect(pdu.description.contains("1 PDV"))
        #expect(pdu.description.contains("3 bytes"))
    }
}

@Suite("Presentation Data Value Tests")
struct PresentationDataValueTests {
    
    // Helper function to read big-endian UInt32 from data
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    @Test("PDV creation")
    func testPDVCreation() {
        let pdv = PresentationDataValue(
            presentationContextID: 3,
            isCommand: true,
            isLastFragment: false,
            data: Data([0x00, 0x01, 0x02])
        )
        
        #expect(pdv.presentationContextID == 3)
        #expect(pdv.isCommand == true)
        #expect(pdv.isLastFragment == false)
        #expect(pdv.data.count == 3)
    }
    
    @Test("PDV message control header - Command, Last")
    func testPDVControlHeaderCommandLast() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data()
        )
        
        // isCommand = bit 0 set, isLastFragment = bit 1 set
        #expect(pdv.messageControlHeader == 0x03)
    }
    
    @Test("PDV message control header - Data Set, Not Last")
    func testPDVControlHeaderDataNotLast() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: false,
            data: Data()
        )
        
        #expect(pdv.messageControlHeader == 0x00)
    }
    
    @Test("PDV message control header - Data Set, Last")
    func testPDVControlHeaderDataLast() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: true,
            data: Data()
        )
        
        #expect(pdv.messageControlHeader == 0x02)
    }
    
    @Test("PDV message control header - Command, Not Last")
    func testPDVControlHeaderCommandNotLast() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: false,
            data: Data()
        )
        
        #expect(pdv.messageControlHeader == 0x01)
    }
    
    @Test("PDV description")
    func testPDVDescription() {
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02, 0x03])
        )
        
        #expect(pdv.description.contains("context=1"))
        #expect(pdv.description.contains("Command"))
        #expect(pdv.description.contains("Last"))
        #expect(pdv.description.contains("3 bytes"))
    }
    
    @Test("PDV encoding")
    func testPDVEncoding() {
        let pdv = PresentationDataValue(
            presentationContextID: 5,
            isCommand: true,
            isLastFragment: true,
            data: Data([0xAA, 0xBB])
        )
        
        let encoded = pdv.encode()
        
        // Item length (4 bytes): 2 (context ID + control header) + 2 (data) = 4
        let itemLength = readUInt32(from: encoded, at: 0)
        #expect(itemLength == 4)
        
        // Context ID
        #expect(encoded[4] == 5)
        
        // Control header (command + last = 0x03)
        #expect(encoded[5] == 0x03)
        
        // Data
        #expect(encoded[6] == 0xAA)
        #expect(encoded[7] == 0xBB)
    }
}
