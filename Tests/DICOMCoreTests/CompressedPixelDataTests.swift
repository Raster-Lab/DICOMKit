import Testing
import Foundation
@testable import DICOMCore

@Suite("EncapsulatedPixelData Tests")
struct EncapsulatedPixelDataTests {
    
    @Test("Create encapsulated pixel data with offset table and fragments")
    func testCreateEncapsulatedPixelData() {
        let descriptor = PixelDataDescriptor(
            rows: 256,
            columns: 256,
            numberOfFrames: 2,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let offsetTable: [UInt32] = [0, 1000]
        let fragment1 = Data(repeating: 0xFF, count: 1000)
        let fragment2 = Data(repeating: 0xAA, count: 1000)
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: offsetTable,
            fragments: [fragment1, fragment2],
            descriptor: descriptor
        )
        
        #expect(encapsulated.hasOffsetTable == true)
        #expect(encapsulated.offsetTable.count == 2)
        #expect(encapsulated.fragmentCount == 2)
        #expect(encapsulated.descriptor.numberOfFrames == 2)
    }
    
    @Test("Frame data extraction without offset table - one fragment per frame")
    func testFrameDataWithoutOffsetTable() {
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 3,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let fragment1 = Data([0x01, 0x02, 0x03])
        let fragment2 = Data([0x04, 0x05, 0x06])
        let fragment3 = Data([0x07, 0x08, 0x09])
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: [],
            fragments: [fragment1, fragment2, fragment3],
            descriptor: descriptor
        )
        
        #expect(encapsulated.hasOffsetTable == false)
        
        // Each fragment corresponds to a frame
        let frame0 = encapsulated.frameData(at: 0)
        let frame1 = encapsulated.frameData(at: 1)
        let frame2 = encapsulated.frameData(at: 2)
        
        #expect(frame0 == fragment1)
        #expect(frame1 == fragment2)
        #expect(frame2 == fragment3)
    }
    
    @Test("Single-frame with multiple fragments concatenates all")
    func testSingleFrameMultipleFragments() {
        let descriptor = PixelDataDescriptor(
            rows: 128,
            columns: 128,
            numberOfFrames: 1,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: true,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let fragment1 = Data([0x01, 0x02])
        let fragment2 = Data([0x03, 0x04])
        let fragment3 = Data([0x05, 0x06])
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: [],
            fragments: [fragment1, fragment2, fragment3],
            descriptor: descriptor
        )
        
        let frame = encapsulated.frameData(at: 0)
        
        #expect(frame != nil)
        #expect(frame?.count == 6)
        #expect(frame == Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
    }
    
    @Test("allFragmentData concatenates all fragments")
    func testAllFragmentData() {
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let fragment1 = Data([0x01, 0x02, 0x03])
        let fragment2 = Data([0x04, 0x05])
        let fragment3 = Data([0x06])
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: [],
            fragments: [fragment1, fragment2, fragment3],
            descriptor: descriptor
        )
        
        let all = encapsulated.allFragmentData
        
        #expect(all.count == 6)
        #expect(all == Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
    }
    
    @Test("Frame data out of bounds returns nil")
    func testFrameDataOutOfBounds() {
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 2,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: [],
            fragments: [Data([0x01]), Data([0x02])],
            descriptor: descriptor
        )
        
        #expect(encapsulated.frameData(at: -1) == nil)
        #expect(encapsulated.frameData(at: 2) == nil)
        #expect(encapsulated.frameData(at: 100) == nil)
    }
    
    @Test("Empty fragments returns empty allFragmentData")
    func testEmptyFragments() {
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let encapsulated = EncapsulatedPixelData(
            offsetTable: [],
            fragments: [],
            descriptor: descriptor
        )
        
        #expect(encapsulated.fragmentCount == 0)
        #expect(encapsulated.allFragmentData.isEmpty)
    }
}

@Suite("RLECodec Tests")
struct RLECodecTests {
    
    @Test("RLE codec supports correct transfer syntax")
    func testSupportedTransferSyntaxes() {
        let supported = RLECodec.supportedTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.5"))
        #expect(supported.count == 1)
    }
    
    @Test("RLE decode simple literal run")
    func testRLEDecodeLiteralRun() throws {
        let codec = RLECodec()
        
        // Create RLE data for 4x4 8-bit grayscale image
        // Header: 1 segment (4 bytes), offset at 64 (4 bytes), padding
        var rleData = Data(count: 64)
        
        // Number of segments: 1
        rleData[0] = 0x01
        rleData[1] = 0x00
        rleData[2] = 0x00
        rleData[3] = 0x00
        
        // Segment offset: 64 (0x40)
        rleData[4] = 0x40
        rleData[5] = 0x00
        rleData[6] = 0x00
        rleData[7] = 0x00
        
        // Segment data: literal run of 16 bytes (control byte 15 = 0x0F)
        // Control byte: n = 15 means copy next 16 bytes
        rleData.append(0x0F) // Control byte
        for i in 0..<16 {
            rleData.append(UInt8(i))
        }
        
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let decoded = try codec.decodeFrame(rleData, descriptor: descriptor, frameIndex: 0)
        
        #expect(decoded.count == 16)
        for i in 0..<16 {
            #expect(decoded[i] == UInt8(i))
        }
    }
    
    @Test("RLE decode repeat run")
    func testRLEDecodeRepeatRun() throws {
        let codec = RLECodec()
        
        // Create RLE data for 4x4 8-bit grayscale image
        var rleData = Data(count: 64)
        
        // Number of segments: 1
        rleData[0] = 0x01
        rleData[1] = 0x00
        rleData[2] = 0x00
        rleData[3] = 0x00
        
        // Segment offset: 64 (0x40)
        rleData[4] = 0x40
        rleData[5] = 0x00
        rleData[6] = 0x00
        rleData[7] = 0x00
        
        // Segment data: repeat run of 16 bytes (control byte -15 = 0xF1)
        // Control byte: n = -15 means repeat next byte 16 times
        rleData.append(0xF1) // -15 as unsigned byte
        rleData.append(0xAB) // Value to repeat
        
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let decoded = try codec.decodeFrame(rleData, descriptor: descriptor, frameIndex: 0)
        
        #expect(decoded.count == 16)
        for i in 0..<16 {
            #expect(decoded[i] == 0xAB)
        }
    }
    
    @Test("RLE decode empty data throws error")
    func testRLEDecodeEmptyData() {
        let codec = RLECodec()
        
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(throws: DICOMError.self) {
            try codec.decodeFrame(Data(), descriptor: descriptor, frameIndex: 0)
        }
    }
    
    @Test("RLE decode data too short for header throws error")
    func testRLEDecodeDataTooShort() {
        let codec = RLECodec()
        
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(throws: DICOMError.self) {
            try codec.decodeFrame(Data(count: 32), descriptor: descriptor, frameIndex: 0)
        }
    }
}

@Suite("Compressed TransferSyntax Tests")
struct CompressedTransferSyntaxTests {
    
    @Test("JPEG Baseline properties")
    func testJPEGBaseline() {
        let ts = TransferSyntax.jpegBaseline
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.50")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == true)
        #expect(ts.isDeflated == false)
        #expect(ts.isJPEG == true)
        #expect(ts.isJPEG2000 == false)
        #expect(ts.isRLE == false)
        #expect(ts.isLossless == false)
    }
    
    @Test("JPEG Lossless properties")
    func testJPEGLossless() {
        let ts = TransferSyntax.jpegLossless
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.57")
        #expect(ts.isEncapsulated == true)
        #expect(ts.isJPEG == true)
        #expect(ts.isLossless == true)
    }
    
    @Test("JPEG 2000 Lossless properties")
    func testJPEG2000Lossless() {
        let ts = TransferSyntax.jpeg2000Lossless
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.90")
        #expect(ts.isEncapsulated == true)
        #expect(ts.isJPEG2000 == true)
        #expect(ts.isLossless == true)
    }
    
    @Test("JPEG 2000 Lossy properties")
    func testJPEG2000Lossy() {
        let ts = TransferSyntax.jpeg2000
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.91")
        #expect(ts.isEncapsulated == true)
        #expect(ts.isJPEG2000 == true)
        #expect(ts.isLossless == false)
    }
    
    @Test("RLE Lossless properties")
    func testRLELossless() {
        let ts = TransferSyntax.rleLossless
        
        #expect(ts.uid == "1.2.840.10008.1.2.5")
        #expect(ts.isEncapsulated == true)
        #expect(ts.isRLE == true)
        #expect(ts.isLossless == true)
    }
    
    @Test("TransferSyntax.from returns correct types for all compressed syntaxes")
    func testFromUIDAllCompressed() {
        let jpegBaseline = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.50")
        #expect(jpegBaseline?.isJPEG == true)
        
        let jpegExtended = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.51")
        #expect(jpegExtended?.isJPEG == true)
        
        let jpegLossless = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.57")
        #expect(jpegLossless?.isJPEG == true)
        
        let jpegLosslessSV1 = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.70")
        #expect(jpegLosslessSV1?.isJPEG == true)
        
        let j2kLossless = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.90")
        #expect(j2kLossless?.isJPEG2000 == true)
        
        let j2k = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.91")
        #expect(j2k?.isJPEG2000 == true)
        
        let rle = TransferSyntax.from(uid: "1.2.840.10008.1.2.5")
        #expect(rle?.isRLE == true)
    }
}

@Suite("CodecRegistry Tests")
struct CodecRegistryTests {
    
    @Test("CodecRegistry has RLE codec")
    func testHasRLECodec() {
        let registry = CodecRegistry.shared
        
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.5") == true)
        #expect(registry.codec(for: "1.2.840.10008.1.2.5") != nil)
    }
    
    #if canImport(ImageIO)
    @Test("CodecRegistry has JPEG codecs on Apple platforms")
    func testHasJPEGCodecs() {
        let registry = CodecRegistry.shared
        
        // JPEG Baseline
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.50") == true)
        
        // JPEG Extended
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.51") == true)
        
        // JPEG Lossless
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.57") == true)
        
        // JPEG Lossless SV1
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.70") == true)
    }
    
    @Test("CodecRegistry has JPEG 2000 codecs on Apple platforms")
    func testHasJPEG2000Codecs() {
        let registry = CodecRegistry.shared
        
        // JPEG 2000 Lossless
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.90") == true)
        
        // JPEG 2000
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.91") == true)
    }
    #endif
    
    @Test("CodecRegistry returns nil for unsupported syntaxes")
    func testNoCodecForUnsupported() {
        let registry = CodecRegistry.shared
        
        // Uncompressed - no codec needed
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2") == false)
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.1") == false)
        
        // Unknown UID
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.999") == false)
    }
    
    @Test("supportedTransferSyntaxes includes RLE")
    func testSupportedTransferSyntaxes() {
        let registry = CodecRegistry.shared
        let supported = registry.supportedTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.5"))
    }
}

@Suite("DataElement Encapsulated Tests")
struct DataElementEncapsulatedTests {
    
    @Test("DataElement with encapsulated data")
    func testDataElementEncapsulated() {
        let tag = Tag.pixelData
        let fragment1 = Data([0x01, 0x02, 0x03])
        let fragment2 = Data([0x04, 0x05, 0x06])
        let offsetTable: [UInt32] = [0, 100]
        
        let element = DataElement(
            tag: tag,
            vr: .OB,
            length: 0xFFFFFFFF,
            valueData: Data(),
            encapsulatedFragments: [fragment1, fragment2],
            encapsulatedOffsetTable: offsetTable
        )
        
        #expect(element.isEncapsulated == true)
        #expect(element.encapsulatedFragmentCount == 2)
        #expect(element.encapsulatedFragments?.count == 2)
        #expect(element.encapsulatedOffsetTable?.count == 2)
        #expect(element.hasUndefinedLength == true)
    }
    
    @Test("Regular DataElement is not encapsulated")
    func testDataElementNotEncapsulated() {
        let element = DataElement(
            tag: Tag.pixelData,
            vr: .OW,
            length: 100,
            valueData: Data(count: 100)
        )
        
        #expect(element.isEncapsulated == false)
        #expect(element.encapsulatedFragmentCount == 0)
        #expect(element.encapsulatedFragments == nil)
    }
}
