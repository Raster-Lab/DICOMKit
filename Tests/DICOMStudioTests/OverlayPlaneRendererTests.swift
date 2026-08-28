// OverlayPlaneRendererTests.swift
// DICOMStudioTests
//
// Overlay planes (60xx): what is read out of a data set, and what lands on the
// picture. The case that forced this is a Siemens "Patient Protocol" Secondary
// Capture — all-zero Pixel Data with the whole page in a 1-bit overlay — which
// rendered as a black square until the plane was drawn.

import Testing
@testable import DICOMStudio
import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite("Overlay Plane Renderer Tests")
struct OverlayPlaneRendererTests {

    // MARK: - Building a data set

    private func element(_ group: UInt16, _ element: UInt16, _ vr: VR, _ data: Data) -> DataElement {
        DataElement(tag: Tag(group: group, element: element), vr: vr,
                    length: UInt32(data.count), valueData: data)
    }

    private func uint16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private func int16Pair(_ first: Int16, _ second: Int16) -> Data {
        withUnsafeBytes(of: first.littleEndian) { Data($0) }
            + withUnsafeBytes(of: second.littleEndian) { Data($0) }
    }

    /// A data set holding one overlay plane over `rows` × `columns`, with the
    /// given bits set.
    private func dataSet(
        group: UInt16 = 0x6000,
        rows: Int = 8,
        columns: Int = 8,
        origin: (Int16, Int16) = (1, 1),
        bitsAllocated: UInt16 = 1,
        frames: Int? = nil,
        imageFrameOrigin: UInt16? = nil,
        setBits: [(row: Int, column: Int, frame: Int)] = [],
        truncated: Bool = false
    ) -> DataSet {
        let frameCount = frames ?? 1
        let totalBits = rows * columns * frameCount
        var packed = [UInt8](repeating: 0, count: (totalBits + 7) / 8)
        for bit in setBits {
            let index = (bit.frame * rows * columns) + (bit.row * columns) + bit.column
            packed[index / 8] |= UInt8(1 << (index % 8))
        }
        if truncated { packed = Array(packed.prefix(max(0, packed.count - 4))) }

        var elements: [DataElement] = [
            element(group, 0x0010, .US, uint16(UInt16(rows))),
            element(group, 0x0011, .US, uint16(UInt16(columns))),
            element(group, 0x0040, .CS, Data("G ".utf8)),
            element(group, 0x0050, .SS, int16Pair(origin.0, origin.1)),
            element(group, 0x0100, .US, uint16(bitsAllocated)),
            element(group, 0x0102, .US, uint16(0)),
            element(group, 0x3000, .OW, Data(packed))
        ]
        if let frames {
            elements.append(element(group, 0x0015, .IS, Data("\(frames) ".utf8)))
        }
        if let imageFrameOrigin {
            elements.append(element(group, 0x0051, .US, uint16(imageFrameOrigin)))
        }
        return DataSet(elements: elements)
    }

    // MARK: - Reading the plane

    @Test("A plane is read with its size, origin, type and bitmap")
    func testPlaneParsing() throws {
        let planes = OverlayPlaneRenderer.planes(in: dataSet(setBits: [(0, 0, 0)]))
        let plane = try #require(planes.first)
        #expect(planes.count == 1)
        #expect(plane.group == 0x6000)
        #expect(plane.rows == 8)
        #expect(plane.columns == 8)
        #expect(plane.originRow == 1)
        #expect(plane.originColumn == 1)
        #expect(plane.type == "G")
        #expect(plane.frameCount == 1)
    }

    @Test("Bits are packed least-significant-bit first, row by row")
    func testBitOrder() throws {
        // Bit 1 is the second pixel of the first row; bit 8 is the first pixel
        // of the second row. Reading a byte the other way round shifts the whole
        // picture and is the classic overlay bug.
        let set = [(row: 0, column: 1, frame: 0), (row: 1, column: 0, frame: 0)]
        let plane = try #require(OverlayPlaneRenderer.planes(in: dataSet(setBits: set)).first)
        #expect(plane.isSet(row: 0, column: 1))
        #expect(plane.isSet(row: 1, column: 0))
        #expect(!plane.isSet(row: 0, column: 0))
        #expect(!plane.isSet(row: 0, column: 2))
        // Out of bounds is empty, not a crash or a wrapped read.
        #expect(!plane.isSet(row: -1, column: 0))
        #expect(!plane.isSet(row: 8, column: 0))
        #expect(!plane.isSet(row: 0, column: 8))
    }

    @Test("An embedded overlay is skipped rather than drawn from the wrong bits")
    func testEmbeddedOverlaySkipped() {
        // Bits Allocated 16 means the plane lives in the high bits of Pixel
        // Data — a retired construct this renderer cannot reach.
        #expect(OverlayPlaneRenderer.planes(in: dataSet(bitsAllocated: 16)).isEmpty)
    }

    @Test("A bitmap too short for one frame is skipped")
    func testTruncatedOverlaySkipped() {
        #expect(OverlayPlaneRenderer.planes(in: dataSet(truncated: true)).isEmpty)
    }

    @Test("A data set with no overlay group yields nothing")
    func testNoOverlay() {
        #expect(OverlayPlaneRenderer.planes(in: DataSet()).isEmpty)
        #expect(!OverlayPlaneRenderer.hasOverlay(DataSet()))
    }

    @Test("Every even group from 6000 to 601E is looked at")
    func testHighGroup() throws {
        let plane = try #require(
            OverlayPlaneRenderer.planes(in: dataSet(group: 0x601E, setBits: [(0, 0, 0)])).first)
        #expect(plane.group == 0x601E)
    }

    // MARK: - Which frames a plane covers

    @Test("A single-frame overlay applies to every frame of the image")
    func testSingleFrameOverlayAppliesEverywhere() throws {
        let plane = try #require(OverlayPlaneRenderer.planes(in: dataSet(setBits: [(0, 0, 0)])).first)
        #expect(plane.applies(toImageFrame: 0))
        #expect(plane.applies(toImageFrame: 47))
    }

    @Test("A multi-frame overlay covers only its own run of image frames")
    func testMultiFrameOverlayRange() throws {
        // Three overlay frames starting at image frame 3 (1-based) — frames 2, 3
        // and 4 zero-based.
        let plane = try #require(OverlayPlaneRenderer.planes(in: dataSet(
            frames: 3, imageFrameOrigin: 3, setBits: [(0, 0, 2)])).first)
        #expect(!plane.applies(toImageFrame: 1))
        #expect(plane.applies(toImageFrame: 2))
        #expect(plane.applies(toImageFrame: 4))
        #expect(!plane.applies(toImageFrame: 5))
    }

    // MARK: - Burning into print samples

    @Test("An 8-bit film frame gains white where the overlay bits are set")
    func testBurnIntoEightBitSamples() {
        let samples = Data(repeating: 0, count: 64)
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: [(0, 0, 0), (7, 7, 0)]),
            into: samples, width: 8, height: 8,
            bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2")

        #expect(burned[0] == 255)
        #expect(burned[63] == 255)
        #expect(burned[1] == 0)
        #expect(burned.count == samples.count)
    }

    @Test("A 16-bit frame is filled to the stored maximum, little-endian")
    func testBurnIntoSixteenBitSamples() {
        let samples = Data(repeating: 0, count: 64 * 2)
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: [(0, 1, 0)]),
            into: samples, width: 8, height: 8,
            bitsAllocated: 16, bitsStored: 12, samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2")

        // 12 bits stored: 4095 = 0x0FFF, low byte first.
        #expect(burned[2] == 0xFF)
        #expect(burned[3] == 0x0F)
        #expect(burned[0] == 0)
    }

    @Test("On MONOCHROME1 the overlay is drawn in zero, which is that space's white")
    func testBurnIntoMonochrome1() {
        let samples = Data(repeating: 200, count: 64)
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: [(0, 0, 0)]),
            into: samples, width: 8, height: 8,
            bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME1")

        #expect(burned[0] == 0)
        #expect(burned[1] == 200)
    }

    @Test("A buffer smaller than the frame it claims to be is left alone")
    func testBurnRejectsShortBuffer() {
        let samples = Data(repeating: 0, count: 10)
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: [(0, 0, 0)]),
            into: samples, width: 8, height: 8,
            bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2")
        #expect(burned == samples)
    }

    @Test("A frame with no overlay keeps its samples byte for byte")
    func testBurnWithoutOverlayIsIdentity() {
        let samples = Data((0..<64).map { UInt8($0) })
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: DataSet(), into: samples, width: 8, height: 8,
            bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2")
        #expect(burned == samples)
    }

    // MARK: - Drawing

    #if canImport(CoreGraphics)

    /// An all-black 8-bit image, like the Patient Protocol capture's own pixels.
    private func blackImage(width: Int, height: Int) -> CGImage? {
        let bytes = [UInt8](repeating: 0, count: width * height)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The RGBA bytes of a rendered image.
    private func samples(_ image: CGImage) throws -> [UInt8] {
        let width = image.width, height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    @Test("The overlay lights exactly the pixels its bits name, and no others")
    func testBurnLightsTheRightPixels() throws {
        let base = try #require(blackImage(width: 8, height: 8))
        let set = [(row: 0, column: 0, frame: 0), (row: 3, column: 5, frame: 0)]
        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: set), onto: base, frameIndex: 0)

        let pixels = try samples(burned)
        func red(row: Int, column: Int) -> UInt8 { pixels[(row * 8 + column) * 4] }

        // Row 0 of the overlay is row 0 of the image: the plane must not land
        // upside down, which is what happens when CoreGraphics' bottom-left
        // origin is forgotten.
        #expect(red(row: 0, column: 0) == 255)
        #expect(red(row: 3, column: 5) == 255)
        #expect(red(row: 7, column: 0) == 0)
        #expect(red(row: 0, column: 7) == 0)
        #expect(red(row: 4, column: 4) == 0)
    }

    @Test("An all-black frame with an overlay stops being all black")
    func testBlackFrameGainsContent() throws {
        let base = try #require(blackImage(width: 8, height: 8))
        #expect(try samples(base).allSatisfy { $0 == 0 || $0 == 255 })

        let burned = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(setBits: [(2, 2, 0)]), onto: base, frameIndex: 0)
        let lit = try samples(burned).enumerated()
            .filter { $0.offset % 4 != 3 && $0.element > 0 }
        #expect(!lit.isEmpty, "the overlay is the only content this frame has")
    }

    @Test("A frame with no overlay comes back untouched")
    func testNoOverlayReturnsSameImage() throws {
        let base = try #require(blackImage(width: 4, height: 4))
        let result = OverlayPlaneRenderer.burningOverlays(
            of: DataSet(), onto: base, frameIndex: 0)
        #expect(result === base)
    }

    @Test("An overlay outside its frame range is not drawn")
    func testOverlayOutsideFrameRangeNotDrawn() throws {
        let base = try #require(blackImage(width: 8, height: 8))
        let set = [(row: 0, column: 0, frame: 0)]
        let result = OverlayPlaneRenderer.burningOverlays(
            of: dataSet(frames: 2, imageFrameOrigin: 5, setBits: set),
            onto: base, frameIndex: 0)
        #expect(result === base)
    }

    #endif
}
