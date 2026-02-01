import Testing
import Foundation
@testable import DICOMCore

@Suite("PixelDataError Tests")
struct PixelDataErrorTests {
    
    // MARK: - Error Creation Tests
    
    @Test("missingDescriptor error has correct description")
    func testMissingDescriptorDescription() {
        let error = PixelDataError.missingDescriptor
        
        #expect(error.description.contains("Missing required pixel data attributes"))
        #expect(error.explanation.contains("missing required attributes"))
    }
    
    @Test("missingPixelData error has correct description")
    func testMissingPixelDataDescription() {
        let error = PixelDataError.missingPixelData
        
        #expect(error.description.contains("No pixel data element"))
        #expect(error.explanation.contains("does not contain any pixel data"))
    }
    
    @Test("missingTransferSyntax error has correct description")
    func testMissingTransferSyntaxDescription() {
        let error = PixelDataError.missingTransferSyntax
        
        #expect(error.description.contains("Transfer syntax UID is missing"))
        #expect(error.explanation.contains("Transfer Syntax UID is not"))
    }
    
    @Test("unsupportedTransferSyntax error includes UID")
    func testUnsupportedTransferSyntaxDescription() {
        let uid = "1.2.840.10008.1.2.4.80"
        let error = PixelDataError.unsupportedTransferSyntax(uid)
        
        #expect(error.description.contains(uid))
        #expect(error.explanation.contains("not currently supported"))
        #expect(error.transferSyntaxName == "JPEG-LS Lossless")
    }
    
    @Test("frameExtractionFailed error includes frame index")
    func testFrameExtractionFailedDescription() {
        let error = PixelDataError.frameExtractionFailed(frameIndex: 5)
        
        #expect(error.description.contains("frame 5"))
        #expect(error.explanation.contains("frame 5"))
    }
    
    @Test("decodingFailed error includes frame index and reason")
    func testDecodingFailedDescription() {
        let error = PixelDataError.decodingFailed(frameIndex: 3, reason: "Invalid JPEG header")
        
        #expect(error.description.contains("frame 3"))
        #expect(error.description.contains("Invalid JPEG header"))
        #expect(error.explanation.contains("failed to decompress"))
    }
    
    // MARK: - Transfer Syntax Name Tests
    
    @Test("transferSyntaxName returns correct name for JPEG-LS Lossless")
    func testTransferSyntaxNameJPEGLSLossless() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.80")
        #expect(error.transferSyntaxName == "JPEG-LS Lossless")
    }
    
    @Test("transferSyntaxName returns correct name for JPEG-LS Near-Lossless")
    func testTransferSyntaxNameJPEGLSNearLossless() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.81")
        #expect(error.transferSyntaxName == "JPEG-LS Near-Lossless")
    }
    
    @Test("transferSyntaxName returns correct name for JPEG 2000 Part 2 Lossless")
    func testTransferSyntaxNameJPEG2000Part2Lossless() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.92")
        #expect(error.transferSyntaxName == "JPEG 2000 Part 2 Lossless")
    }
    
    @Test("transferSyntaxName returns correct name for JPEG 2000 Part 2 Lossy")
    func testTransferSyntaxNameJPEG2000Part2Lossy() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.93")
        #expect(error.transferSyntaxName == "JPEG 2000 Part 2 Lossy")
    }
    
    @Test("transferSyntaxName returns correct name for High-Throughput JPEG 2000 Lossless")
    func testTransferSyntaxNameHTJPEG2000Lossless() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.201")
        #expect(error.transferSyntaxName == "High-Throughput JPEG 2000 Lossless")
    }
    
    @Test("transferSyntaxName returns correct name for High-Throughput JPEG 2000 with RPCL")
    func testTransferSyntaxNameHTJPEG2000RPCL() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.202")
        #expect(error.transferSyntaxName == "High-Throughput JPEG 2000 with RPCL Lossless")
    }
    
    @Test("transferSyntaxName returns correct name for High-Throughput JPEG 2000 Lossy")
    func testTransferSyntaxNameHTJPEG2000Lossy() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.840.10008.1.2.4.203")
        #expect(error.transferSyntaxName == "High-Throughput JPEG 2000 Lossy")
    }
    
    @Test("transferSyntaxName returns nil for unknown UID")
    func testTransferSyntaxNameUnknown() {
        let error = PixelDataError.unsupportedTransferSyntax("1.2.3.4.5.6.7")
        #expect(error.transferSyntaxName == nil)
    }
    
    @Test("transferSyntaxName returns nil for non-unsupportedTransferSyntax errors")
    func testTransferSyntaxNameNonApplicable() {
        let error = PixelDataError.missingDescriptor
        #expect(error.transferSyntaxName == nil)
    }
    
    // MARK: - Error Conformance Tests
    
    @Test("PixelDataError conforms to Error protocol")
    func testErrorConformance() {
        let error: Error = PixelDataError.missingDescriptor
        #expect(error is PixelDataError)
    }
    
    @Test("PixelDataError conforms to Sendable")
    func testSendableConformance() {
        let error: any Sendable = PixelDataError.missingDescriptor
        #expect(error is PixelDataError)
    }
}
