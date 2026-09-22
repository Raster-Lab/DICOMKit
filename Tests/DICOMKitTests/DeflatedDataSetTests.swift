import Foundation
import Testing
@testable import DICOMKit
import DICOMCore

/// Contract tests for strict PS3.5 A.5 inflation. The previous implementation
/// decoded into a fixed buffer of four times the input size and returned whatever
/// fit, so any Data Set that expanded more than four-fold was silently truncated.
@Suite("Deflated data set strict inflation")
struct DeflatedDataSetTests {
    private func deflate(_ payload: Data) throws -> Data {
        try #require(payload.deflateCompressed())
    }

    @Test("A stream that expands far beyond four-fold inflates completely")
    func highRatioRoundTrip() throws {
        let payload = Data(repeating: 0x2A, count: 1_000_000)
        let compressed = try deflate(payload)
        #expect(compressed.count < payload.count / 100)
        #expect(try DeflatedDataSet.inflate(compressed, maximumOutputByteCount: 2_000_000) == payload)
        let varied = Data((0..<300_000).map { UInt8(($0 * 31 + 7) & 0xFF) })
        #expect(try DeflatedDataSet.inflate(try deflate(varied), maximumOutputByteCount: 300_000) == varied)
    }

    @Test("Truncated, corrupt, empty and zlib-wrapped streams throw their own failure")
    func malformedStreams() throws {
        let payload = Data((0..<50_000).map { UInt8(($0 * 13) & 0xFF) })
        let compressed = try deflate(payload)
        #expect(throws: DeflatedDataSet.Failure.truncated) {
            try DeflatedDataSet.inflate(compressed.prefix(compressed.count / 2), maximumOutputByteCount: 1 << 20)
        }
        #expect(throws: DeflatedDataSet.Failure.truncated) {
            try DeflatedDataSet.inflate(Data(), maximumOutputByteCount: 1 << 20)
        }
        #expect(throws: DeflatedDataSet.Failure.self) {
            try DeflatedDataSet.inflate(Data([0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00]), maximumOutputByteCount: 1 << 20)
        }
        // RFC 1950 wrapper (78 9C header) is not a PS3.5 A.5 stream.
        var zlib = Data([0x78, 0x9C]); zlib.append(compressed); zlib.append(Data([0, 0, 0, 0]))
        #expect(throws: DeflatedDataSet.Failure.self) {
            try DeflatedDataSet.inflate(zlib, maximumOutputByteCount: 1 << 20)
        }
    }

    @Test("Bytes after the end-of-stream marker are refused")
    func trailingBytes() throws {
        let compressed = try deflate(Data(repeating: 7, count: 4096))
        var padded = compressed; padded.append(contentsOf: [0x00, 0x01, 0x02])
        #expect(throws: DeflatedDataSet.Failure.trailingBytes(3)) {
            try DeflatedDataSet.inflate(padded, maximumOutputByteCount: 1 << 20)
        }
    }

    @Test("Multi-chunk incompressible streams round-trip, and their end is located exactly")
    func multiChunkStreams() throws {
        // A linear congruential sequence does not compress: the compressed stream spans
        // many input chunks, exercising the chunked feed and FINALIZE handling.
        var state: UInt32 = 0x1234_5678
        let noise = Data((0..<200_000).map { _ -> UInt8 in
            state = state &* 1_664_525 &+ 1_013_904_223
            return UInt8(truncatingIfNeeded: state >> 24)
        })
        let compressed = try deflate(noise)
        #expect(compressed.count > 100_000)
        #expect(try DeflatedDataSet.inflate(compressed, maximumOutputByteCount: 200_000) == noise)
        for trailing in [1, 7, 4_095, 4_096, 100_000] {
            var padded = compressed; padded.append(Data(repeating: 0x55, count: trailing))
            #expect(throws: DeflatedDataSet.Failure.trailingBytes(trailing), "\(trailing)") {
                try DeflatedDataSet.inflate(padded, maximumOutputByteCount: 1 << 20)
            }
        }
        for keep in [1, 4_096, compressed.count - 1] {
            #expect(throws: DeflatedDataSet.Failure.truncated, "\(keep)") {
                try DeflatedDataSet.inflate(compressed.prefix(keep), maximumOutputByteCount: 1 << 20)
            }
        }
        // Two valid streams back to back: the second is trailing bytes, not a continuation.
        var doubled = compressed; doubled.append(compressed)
        #expect(throws: DeflatedDataSet.Failure.trailingBytes(compressed.count)) {
            try DeflatedDataSet.inflate(doubled, maximumOutputByteCount: 1 << 20)
        }
    }

    @Test("The output limit is enforced before the limit is exceeded")
    func outputLimit() throws {
        let compressed = try deflate(Data(repeating: 0, count: 5_000_000))
        #expect(throws: DeflatedDataSet.Failure.outputLimitExceeded(limit: 1_000_000)) {
            try DeflatedDataSet.inflate(compressed, maximumOutputByteCount: 1_000_000)
        }
        #expect(throws: DeflatedDataSet.Failure.outputLimitExceeded(limit: 0)) {
            try DeflatedDataSet.inflate(compressed, maximumOutputByteCount: 0)
        }
        #expect(try DeflatedDataSet.inflate(compressed, maximumOutputByteCount: 5_000_000).count == 5_000_000)
    }

    @Test("Reading a deflated file whose data set expands more than four-fold recovers every pixel")
    func deflatedFileReadIsComplete() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setUInt16(512, for: .rows)
        dataSet.setUInt16(512, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        let pixels = Data(repeating: 9, count: 512 * 512)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
        let plain = try DICOMFile.create(dataSet: dataSet).write()
        let deflated = try CompressionManager().compressData(plain, codec: "deflate", quality: nil)
        #expect(deflated.count * 4 < 512 * 512, "fixture must expand more than four-fold")

        let file = try DICOMFile.read(from: deflated)
        #expect(file.dataSet[.pixelData]?.valueData == pixels)

        #expect(throws: DICOMError.self) {
            try DICOMFile.read(from: deflated, options: ParsingOptions(maximumInflatedByteCount: 1024))
        }
        var truncated = deflated
        truncated.removeLast(8)
        #expect(throws: DICOMError.self) { try DICOMFile.read(from: truncated) }
    }
}
