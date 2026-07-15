import Foundation
import Testing
@testable import DICOMCore

@Suite("J2K and HTJ2K Transcoding Safety Tests")
struct J2KTranscodingSafetyTests {
    private func makeDataset(
        width: Int = 64,
        height: Int = 64,
        bitsAllocated: Int = 8,
        isSigned: Bool = false
    ) -> Data {
        let writer = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        var elements: [DataElement] = []

        var samplesPerPixel: UInt16 = 1
        elements.append(DataElement(
            tag: .samplesPerPixel,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &samplesPerPixel, count: 2)
        ))

        let photometricInterpretation = Data("MONOCHROME2 ".utf8)
        elements.append(DataElement(
            tag: .photometricInterpretation,
            vr: .CS,
            length: UInt32(photometricInterpretation.count),
            valueData: photometricInterpretation
        ))

        var rows = UInt16(height)
        elements.append(DataElement(tag: .rows, vr: .US, length: 2, valueData: Data(bytes: &rows, count: 2)))

        var columns = UInt16(width)
        elements.append(DataElement(tag: .columns, vr: .US, length: 2, valueData: Data(bytes: &columns, count: 2)))

        var allocated = UInt16(bitsAllocated)
        elements.append(DataElement(
            tag: .bitsAllocated,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &allocated, count: 2)
        ))

        var stored = UInt16(bitsAllocated)
        elements.append(DataElement(
            tag: .bitsStored,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &stored, count: 2)
        ))

        var highBit = UInt16(bitsAllocated - 1)
        elements.append(DataElement(
            tag: .highBit,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &highBit, count: 2)
        ))

        var representation: UInt16 = isSigned ? 1 : 0
        elements.append(DataElement(
            tag: .pixelRepresentation,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &representation, count: 2)
        ))

        var pixels = Data(capacity: width * height * (bitsAllocated / 8))
        for index in 0..<(width * height) {
            if bitsAllocated == 8 {
                pixels.append(UInt8(truncatingIfNeeded: index * 251 + 17))
            } else {
                let pattern = isSigned ? index * 257 + 0x8000 : index * 257
                var value = UInt16(truncatingIfNeeded: pattern).littleEndian
                withUnsafeBytes(of: &value) { pixels.append(contentsOf: $0) }
            }
        }
        elements.append(DataElement(
            tag: .pixelData,
            vr: bitsAllocated > 8 ? .OW : .OB,
            length: UInt32(pixels.count),
            valueData: pixels
        ))

        var data = Data()
        for element in elements.sorted(by: { $0.tag < $1.tag }) {
            data.append(writer.serializeElement(element))
        }
        return data
    }

    private func uncompressedPixelData(from data: Data) -> Data? {
        var offset = 0
        while offset + 12 <= data.count {
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            guard group != 0x7FE0 || element != 0x0010 else {
                let length = UInt32(data[offset + 8])
                    | (UInt32(data[offset + 9]) << 8)
                    | (UInt32(data[offset + 10]) << 16)
                    | (UInt32(data[offset + 11]) << 24)
                guard length != 0xFFFFFFFF else { return nil }
                let valueStart = offset + 12
                let valueEnd = valueStart + Int(length)
                guard valueEnd <= data.count else { return nil }
                return Data(data[valueStart..<valueEnd])
            }
            offset += 1
        }
        return nil
    }

    private func expectLosslessConversion(
        from sourceSyntax: TransferSyntax,
        to targetSyntax: TransferSyntax,
        bitsAllocated: Int = 8,
        isSigned: Bool = false
    ) throws {
        let sourceData = makeDataset(bitsAllocated: bitsAllocated, isSigned: isSigned)
        let converter = TransferSyntaxConverter(
            configuration: TranscodingConfiguration(
                preferredSyntaxes: [sourceSyntax, targetSyntax, .explicitVRLittleEndian],
                allowLossyCompression: false,
                preservePixelDataFidelity: true
            ),
            compressionConfiguration: .lossless
        )

        let sourceCompressed = try converter.transcode(
            dataSetData: sourceData,
            from: .explicitVRLittleEndian,
            to: sourceSyntax
        )
        let targetCompressed = try converter.transcode(
            dataSetData: sourceCompressed.data,
            from: sourceSyntax,
            to: targetSyntax
        )
        let decoded = try converter.transcode(
            dataSetData: targetCompressed.data,
            from: targetSyntax,
            to: .explicitVRLittleEndian
        )

        let expectedPixels = try #require(uncompressedPixelData(from: sourceData))
        let actualPixels = try #require(uncompressedPixelData(from: decoded.data))
        #expect(targetCompressed.isLossless)
        #expect(actualPixels == expectedPixels)
    }

    @Test("J2K to HTJ2K Lossless preserves 8-bit pixels")
    func testJ2KToHTJ2KLossless() throws {
        try expectLosslessConversion(from: .jpeg2000Lossless, to: .htj2kLossless)
    }

    @Test("HTJ2K Lossless to J2K preserves 8-bit pixels")
    func testHTJ2KToJ2KLossless() throws {
        try expectLosslessConversion(from: .htj2kLossless, to: .jpeg2000Lossless)
    }

    @Test("J2K to HTJ2K RPCL Lossless preserves 8-bit pixels")
    func testJ2KToHTJ2KRPCLLossless() throws {
        try expectLosslessConversion(from: .jpeg2000Lossless, to: .htj2kRPCLLossless)
    }

    @Test("HTJ2K RPCL Lossless to J2K preserves 8-bit pixels")
    func testHTJ2KRPCLToJ2KLossless() throws {
        try expectLosslessConversion(from: .htj2kRPCLLossless, to: .jpeg2000Lossless)
    }

    @Test("J2K to HTJ2K Lossless preserves signed 16-bit pixels")
    func testJ2KToHTJ2KSigned16Bit() throws {
        try expectLosslessConversion(
            from: .jpeg2000Lossless,
            to: .htj2kLossless,
            bitsAllocated: 16,
            isSigned: true
        )
    }

    @Test("HTJ2K Lossless to J2K preserves signed 16-bit pixels")
    func testHTJ2KToJ2KSigned16Bit() throws {
        try expectLosslessConversion(
            from: .htj2kLossless,
            to: .jpeg2000Lossless,
            bitsAllocated: 16,
            isSigned: true
        )
    }
}
