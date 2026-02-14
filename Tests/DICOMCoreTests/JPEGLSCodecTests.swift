import Testing
import Foundation
@testable import DICOMCore

@Suite("JPEGLSCodec Tests")
struct JPEGLSCodecTests {
    
    @Test("JPEG-LS codec supports correct transfer syntaxes")
    func testSupportedTransferSyntaxes() {
        let supported = JPEGLSCodec.supportedTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.4.80"))
        #expect(supported.contains("1.2.840.10008.1.2.4.81"))
        #expect(supported.count == 2)
    }
    
    @Test("JPEG-LS codec supports encoding transfer syntaxes")
    func testSupportedEncodingTransferSyntaxes() {
        let supported = JPEGLSCodec.supportedEncodingTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.4.80"))
        #expect(supported.contains("1.2.840.10008.1.2.4.81"))
        #expect(supported.count == 2)
    }
    
    @Test("JPEG-LS codec can encode 8-bit grayscale")
    func testCanEncode8BitGrayscale() {
        let codec = JPEGLSCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64, columns: 64,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(codec.canEncode(with: .default, descriptor: descriptor) == true)
        #expect(codec.canEncode(with: .lossless, descriptor: descriptor) == true)
    }
    
    @Test("JPEG-LS codec can encode 16-bit grayscale")
    func testCanEncode16BitGrayscale() {
        let codec = JPEGLSCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64, columns: 64,
            bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(codec.canEncode(with: .default, descriptor: descriptor) == true)
    }
    
    @Test("JPEG-LS codec can encode RGB")
    func testCanEncodeRGB() {
        let codec = JPEGLSCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64, columns: 64,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3,
            photometricInterpretation: .rgb
        )
        
        #expect(codec.canEncode(with: .default, descriptor: descriptor) == true)
    }
    
    @Test("JPEG-LS codec cannot encode unsupported bit depths")
    func testCannotEncodeUnsupportedBitDepths() {
        let codec = JPEGLSCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64, columns: 64,
            bitsAllocated: 32, bitsStored: 32, highBit: 31,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(codec.canEncode(with: .default, descriptor: descriptor) == false)
    }
    
    @Test("JPEG-LS decode empty data throws error")
    func testDecodeEmptyData() {
        let codec = JPEGLSCodec()
        let descriptor = PixelDataDescriptor(
            rows: 4, columns: 4,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        #expect(throws: DICOMError.self) {
            try codec.decodeFrame(Data(), descriptor: descriptor, frameIndex: 0)
        }
    }
    
    @Test("JPEG-LS lossless encode-decode roundtrip for 8-bit grayscale")
    func testLosslessRoundtrip8BitGrayscale() throws {
        let codec = JPEGLSCodec()
        let width = 8
        let height = 8
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create test image with a gradient pattern
        var pixelData = Data(count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixelData[y * width + x] = UInt8((x + y * width) % 256)
            }
        }
        
        // Encode
        let config = CompressionConfiguration.lossless
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        
        // Verify encoded data starts with SOI marker
        #expect(encoded.count >= 2)
        #expect(encoded[0] == 0xFF)
        #expect(encoded[1] == 0xD8)
        
        // Verify encoded data is compressed (should be smaller or at least have JPEG-LS structure)
        #expect(encoded.count > 0)
        
        // Decode
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        
        // Verify lossless roundtrip
        #expect(decoded.count == pixelData.count)
        for i in 0..<pixelData.count {
            #expect(decoded[i] == pixelData[i], "Mismatch at index \(i): expected \(pixelData[i]), got \(decoded[i])")
        }
    }
    
    @Test("JPEG-LS lossless encode-decode roundtrip for constant image")
    func testLosslessRoundtripConstantImage() throws {
        let codec = JPEGLSCodec()
        let width = 16
        let height = 16
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create constant image (all same value) - tests run mode
        let pixelData = Data(repeating: 128, count: width * height)
        
        let config = CompressionConfiguration.lossless
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        
        #expect(decoded.count == pixelData.count)
        for i in 0..<pixelData.count {
            #expect(decoded[i] == pixelData[i])
        }
    }
    
    @Test("JPEG-LS lossless encode-decode roundtrip for 16-bit grayscale")
    func testLosslessRoundtrip16BitGrayscale() throws {
        let codec = JPEGLSCodec()
        let width = 8
        let height = 8
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create 16-bit test image with values up to 4095 (12-bit)
        var pixelData = Data(count: width * height * 2)
        for y in 0..<height {
            for x in 0..<width {
                let value = UInt16((x + y * width) * 64 % 4096)
                let index = (y * width + x) * 2
                pixelData[index] = UInt8(value & 0xFF)
                pixelData[index + 1] = UInt8((value >> 8) & 0xFF)
            }
        }
        
        let config = CompressionConfiguration.lossless
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        
        #expect(decoded.count == pixelData.count)
        for i in 0..<pixelData.count {
            #expect(decoded[i] == pixelData[i], "Mismatch at byte \(i)")
        }
    }
    
    @Test("JPEG-LS near-lossless encode-decode roundtrip")
    func testNearLosslessRoundtrip() throws {
        let codec = JPEGLSCodec()
        let width = 8
        let height = 8
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create test image
        var pixelData = Data(count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixelData[y * width + x] = UInt8((x * 32 + y * 16) % 256)
            }
        }
        
        // Near-lossless with medium quality
        let config = CompressionConfiguration(quality: .medium, preferLossless: false)
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        
        #expect(decoded.count == pixelData.count)
        
        // Verify near-lossless: decoded values should be close to original
        for i in 0..<pixelData.count {
            let diff = abs(Int(decoded[i]) - Int(pixelData[i]))
            // NEAR parameter should limit the max error
            #expect(diff <= 25, "Near-lossless error too large at index \(i): \(diff)")
        }
    }
    
    @Test("JPEG-LS encoded data has valid JPEG-LS structure")
    func testEncodedDataStructure() throws {
        let codec = JPEGLSCodec()
        let width = 4
        let height = 4
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let pixelData = Data(repeating: 100, count: width * height)
        let config = CompressionConfiguration.lossless
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        
        // Verify SOI marker
        #expect(encoded[0] == 0xFF)
        #expect(encoded[1] == 0xD8)
        
        // Verify SOF55 (JPEG-LS frame) marker
        #expect(encoded[2] == 0xFF)
        #expect(encoded[3] == 0xF7)
        
        // Verify EOI marker at end
        #expect(encoded[encoded.count - 2] == 0xFF)
        #expect(encoded[encoded.count - 1] == 0xD9)
    }
    
    @Test("JPEG-LS compression achieves size reduction for compressible data")
    func testCompressionRatio() throws {
        let codec = JPEGLSCodec()
        let width = 64
        let height = 64
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create highly compressible constant image
        let pixelData = Data(repeating: 128, count: width * height)
        let config = CompressionConfiguration.lossless
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        
        // Constant image should compress very well
        #expect(encoded.count < pixelData.count, "JPEG-LS should compress constant image: encoded=\(encoded.count), original=\(pixelData.count)")
    }
    
    @Test("JPEG-LS multi-frame encode via default implementation")
    func testMultiFrameEncode() throws {
        let codec = JPEGLSCodec()
        let width = 4
        let height = 4
        let numFrames = 2
        
        let descriptor = PixelDataDescriptor(
            rows: height, columns: width,
            numberOfFrames: numFrames,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create 2-frame test data
        var pixelData = Data(count: width * height * numFrames)
        for i in 0..<pixelData.count {
            pixelData[i] = UInt8(i % 256)
        }
        
        let config = CompressionConfiguration.lossless
        let frames = try codec.encode(pixelData, descriptor: descriptor, configuration: config)
        
        #expect(frames.count == numFrames)
        #expect(frames[0].count > 0)
        #expect(frames[1].count > 0)
    }
}

@Suite("JPEG-LS TransferSyntax Tests")
struct JPEGLSTransferSyntaxTests {
    
    @Test("JPEG-LS Lossless transfer syntax properties")
    func testJPEGLSLossless() {
        let ts = TransferSyntax.jpegLSLossless
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.80")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == true)
        #expect(ts.isJPEGLS == true)
        #expect(ts.isLossless == true)
        #expect(ts.isJPEG == false)
        #expect(ts.isJPEG2000 == false)
        #expect(ts.isRLE == false)
    }
    
    @Test("JPEG-LS Near-Lossless transfer syntax properties")
    func testJPEGLSNearLossless() {
        let ts = TransferSyntax.jpegLSNearLossless
        
        #expect(ts.uid == "1.2.840.10008.1.2.4.81")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == true)
        #expect(ts.isJPEGLS == true)
        #expect(ts.isLossless == false)
        #expect(ts.isJPEG == false)
        #expect(ts.isJPEG2000 == false)
    }
    
    @Test("TransferSyntax.from returns JPEG-LS types")
    func testFromUIDJPEGLS() {
        let lossless = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.80")
        #expect(lossless?.isJPEGLS == true)
        #expect(lossless?.isLossless == true)
        
        let nearLossless = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.81")
        #expect(nearLossless?.isJPEGLS == true)
        #expect(nearLossless?.isLossless == false)
    }
}

@Suite("JPEG-LS CodecRegistry Tests")
struct JPEGLSCodecRegistryTests {
    
    @Test("CodecRegistry has JPEG-LS codec")
    func testHasJPEGLSCodec() {
        let registry = CodecRegistry.shared
        
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.80") == true)
        #expect(registry.hasCodec(for: "1.2.840.10008.1.2.4.81") == true)
        #expect(registry.codec(for: "1.2.840.10008.1.2.4.80") != nil)
        #expect(registry.codec(for: "1.2.840.10008.1.2.4.81") != nil)
    }
    
    @Test("CodecRegistry has JPEG-LS encoder")
    func testHasJPEGLSEncoder() {
        let registry = CodecRegistry.shared
        
        #expect(registry.hasEncoder(for: "1.2.840.10008.1.2.4.80") == true)
        #expect(registry.hasEncoder(for: "1.2.840.10008.1.2.4.81") == true)
        #expect(registry.encoder(for: "1.2.840.10008.1.2.4.80") != nil)
        #expect(registry.encoder(for: "1.2.840.10008.1.2.4.81") != nil)
    }
    
    @Test("supportedTransferSyntaxes includes JPEG-LS")
    func testSupportedTransferSyntaxesIncludeJPEGLS() {
        let registry = CodecRegistry.shared
        let supported = registry.supportedTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.4.80"))
        #expect(supported.contains("1.2.840.10008.1.2.4.81"))
    }
    
    @Test("supportedEncodingTransferSyntaxes includes JPEG-LS")
    func testSupportedEncodingTransferSyntaxesIncludeJPEGLS() {
        let registry = CodecRegistry.shared
        let supported = registry.supportedEncodingTransferSyntaxes
        
        #expect(supported.contains("1.2.840.10008.1.2.4.80"))
        #expect(supported.contains("1.2.840.10008.1.2.4.81"))
    }
}

@Suite("JPEG-LS Preset Parameters Tests")
struct JPEGLSPresetParametersTests {
    
    @Test("Default parameters for 8-bit lossless")
    func testDefaultParams8Bit() {
        let params = JPEGLSPresetParameters.defaultParameters(maxVal: 255, near: 0)
        
        #expect(params.maxVal == 255)
        #expect(params.t1 >= 1)
        #expect(params.t2 >= params.t1)
        #expect(params.t3 >= params.t2)
        #expect(params.reset == 64)
    }
    
    @Test("Default parameters for 12-bit lossless")
    func testDefaultParams12Bit() {
        let params = JPEGLSPresetParameters.defaultParameters(maxVal: 4095, near: 0)
        
        #expect(params.maxVal == 4095)
        #expect(params.t1 >= 1)
        #expect(params.t2 >= params.t1)
        #expect(params.t3 >= params.t2)
        #expect(params.reset == 64)
    }
    
    @Test("Default parameters for near-lossless")
    func testDefaultParamsNearLossless() {
        let params = JPEGLSPresetParameters.defaultParameters(maxVal: 255, near: 3)
        
        #expect(params.maxVal == 255)
        #expect(params.t1 >= 4) // near + 1
        #expect(params.t2 >= params.t1)
        #expect(params.t3 >= params.t2)
    }
}
