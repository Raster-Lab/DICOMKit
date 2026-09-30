import XCTest
@testable import DICOMRenderKit
import DICOMCore
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Pins what both backends render against the DICOM 2026a text, rather than
/// against each other (`MetalCPUEquivalenceTests` does that).
///
/// See DICOMRENDERKIT_STANDARD_IMPLEMENTATION.md for the clauses and for the
/// findings that live in DICOMCore / DICOMKit (D63–D67).
final class RenderStandardConformanceTests: XCTestCase {

    #if canImport(Metal) && canImport(CoreGraphics)

    private func requireMetal() throws -> MetalFrameRenderer {
        guard let renderer = MetalFrameRenderer(minimumPixelCount: 0) else {
            throw XCTSkip("No Metal device on this machine")
        }
        return renderer
    }

    private func bytes(of image: CGImage) throws -> [UInt8] {
        [UInt8](try XCTUnwrap(image.dataProvider?.data as Data?))
    }

    /// Every backend that renders the request, labelled.
    private func backends() throws -> [(String, FrameRenderBackend)] {
        var out: [(String, FrameRenderBackend)] = [("cpu", CPUFrameRenderer())]
        if let metal = MetalFrameRenderer(minimumPixelCount: 0) { out.append(("metal", metal)) }
        return out
    }

    private func signed16(_ values: [Int16]) -> Data {
        var data = Data()
        for v in values {
            let u = UInt16(bitPattern: v)
            data.append(UInt8(u & 0xFF))
            data.append(UInt8(u >> 8))
        }
        return data
    }

    // MARK: - PS3.5 8.1.1: a Pixel Cell is Bits Allocated wide

    /// The kernels assemble one or two bytes per sample. A 32-bit cell read as its
    /// low two bytes is another value (65,541 would render as 5), so the GPU must
    /// decline it and leave the frame to the CPU.
    func testMetalDeclinesPixelCellsWiderThanTwoBytes() throws {
        let metal = try requireMetal()
        var cells = Data()
        for value: UInt32 in [5, 65_541, 70_000, 1_000_000] {
            withUnsafeBytes(of: value.littleEndian) { cells.append(contentsOf: $0) }
        }
        let monochrome = PixelData(data: cells, descriptor: PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 32, bitsStored: 32, highBit: 31,
            isSigned: false, photometricInterpretation: .monochrome2))
        let request = FrameRenderRequest(
            pixelData: monochrome, window: WindowSettings(center: 500_000, width: 1_000_000))
        XCTAssertNil(metal.renderFrame(request))
        XCTAssertNil(metal.renderDisplayTexture(request))

        let rgb = PixelData(data: Data(count: 2 * 2 * 3 * 4), descriptor: PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 32, bitsStored: 32, highBit: 31,
            isSigned: false, samplesPerPixel: 3, photometricInterpretation: .rgb))
        XCTAssertNil(metal.renderFrame(FrameRenderRequest(pixelData: rgb)))
    }

    // MARK: - PS3.3 C.11.2.1.2.1: the LINEAR window

    /// The worked example of C.11.2.1.2.1 for c = 0, w = 100 on an output range
    /// 0–255: x ≤ −50 → 0, x > 49 → 255, otherwise ((x + 0.5) / 99 + 0.5) × 255.
    /// Signed 16-bit input (Pixel Representation 1, sign bit = High Bit).
    func testLinearWindowMatchesTheWorkedExampleOnEveryBackend() throws {
        let inputs: [Int16] = [-1000, -51, -50, -49, 0, 48, 49, 50, 1000]
        let pixelData = PixelData(data: signed16(inputs), descriptor: PixelDataDescriptor(
            rows: 1, columns: inputs.count, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: true, photometricInterpretation: .monochrome2))
        let request = FrameRenderRequest(
            pixelData: pixelData, window: WindowSettings(center: 0, width: 100))
        let expected: [UInt8] = inputs.map { x in
            let x = Double(x)
            if x <= -50 { return 0 }
            if x > 49 { return 255 }
            return UInt8(((x + 0.5) / 99 + 0.5) * 255)
        }
        for (name, backend) in try backends() {
            let image = try XCTUnwrap(backend.renderFrame(request), name)
            XCTAssertEqual(try bytes(of: image), expected, name)
        }
    }

    // MARK: - PS3.3 C.7.6.3.1.2: MONOCHROME1 after the VOI transformation

    /// "The minimum sample value is intended to be displayed as white after any
    /// VOI gray scale transformations have been performed": the window selects
    /// first, then the output is inverted. Below the window is white, above it
    /// black, and the ramp runs downwards.
    func testMonochrome1InvertsAfterTheWindowOnEveryBackend() throws {
        let inputs: [Int16] = [-1000, -50, 0, 49, 50, 1000]
        let pixelData = PixelData(data: signed16(inputs), descriptor: PixelDataDescriptor(
            rows: 1, columns: inputs.count, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: true, photometricInterpretation: .monochrome1))
        let request = FrameRenderRequest(
            pixelData: pixelData, window: WindowSettings(center: 0, width: 100))
        for (name, backend) in try backends() {
            let out = try bytes(of: try XCTUnwrap(backend.renderFrame(request), name))
            XCTAssertEqual(out.first, 255, "\(name): below the window is white")
            XCTAssertEqual(out.last, 0, "\(name): above the window is black")
            XCTAssertEqual(out[1], 255, "\(name): the lower edge x = c − w/2 is ymin, shown white")
            XCTAssertEqual(out[5], 0, "\(name)")
            XCTAssertGreaterThan(out[2], out[3], "\(name): the ramp runs downwards")
        }
    }

    // MARK: - PS3.3 C.7.6.3.1.3: Planar Configuration

    /// Enumerated Value 1: "R1, R2, R3, …, G1, G2, G3, …, B1, B2, B3". Two pixels,
    /// pure red then pure blue, must come out as red then blue on every backend.
    func testPlanarConfigurationOneIsReadColourByPlane() throws {
        let planes: [UInt8] = [255, 0,   0, 0,   0, 255]    // R1 R2, G1 G2, B1 B2
        let pixelData = PixelData(data: Data(planes), descriptor: PixelDataDescriptor(
            rows: 1, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7, isSigned: false,
            samplesPerPixel: 3, photometricInterpretation: .rgb, planarConfiguration: 1))
        for (name, backend) in try backends() {
            let out = try bytes(of: try XCTUnwrap(
                backend.renderFrame(FrameRenderRequest(pixelData: pixelData)), name))
            XCTAssertEqual(Array(out[0..<3]), [255, 0, 0], "\(name): first pixel red")
            XCTAssertEqual(Array(out[4..<7]), [0, 0, 255], "\(name): second pixel blue")
        }
    }

    #endif
}
