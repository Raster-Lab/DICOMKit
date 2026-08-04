import XCTest
@testable import DICOMRenderKit
import DICOMCore
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Metal)
import Metal
#endif

/// The gate for milestones M3 and M4 of `GPU_RENDERING_PLAN.md`.
///
/// GPU and CPU output must be **byte-for-byte equal**. Not "within tolerance" — the
/// project's parity contract is that the CLIs and the app produce the same raster,
/// and a GPU path that differed by one grey level on some pixels would break it
/// silently, in a way no visual check would catch.
///
/// Equality is achievable because every value-mapping decision is made on the CPU
/// in `Double` and handed to the shader as a byte table; the shader does no
/// floating-point work at all. These tests are what proves that held.
final class MetalCPUEquivalenceTests: XCTestCase {

    #if canImport(Metal) && canImport(CoreGraphics)

    /// A renderer with the size threshold disabled.
    ///
    /// In production the GPU declines frames under a megapixel because a dispatch
    /// costs more than the CPU render does (see
    /// `MetalFrameRenderer.minimumGPUPixelCount`). That is a performance policy and
    /// has nothing to do with whether the kernels are *correct*, so these tests
    /// switch it off and exercise the shaders on small frames they can enumerate
    /// exhaustively. The threshold has its own test below.
    private func requireMetal() throws -> MetalFrameRenderer {
        guard let renderer = MetalFrameRenderer(minimumPixelCount: 0) else {
            throw XCTSkip("No Metal device on this machine")
        }
        return renderer
    }

    private let cpu = CPUFrameRenderer()

    private func bytes(of image: CGImage) throws -> [UInt8] {
        let data = try XCTUnwrap(image.dataProvider?.data as Data?)
        return [UInt8](data)
    }

    /// Renders the same request both ways and demands identical bytes.
    private func assertEquivalent(
        _ request: FrameRenderRequest,
        _ metal: MetalFrameRenderer,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let cpuImage = try XCTUnwrap(cpu.renderFrame(request), "CPU render failed: \(label)",
                                     file: file, line: line)
        guard let gpuImage = metal.renderFrame(request) else {
            XCTFail("GPU declined to render \(label) — expected it to handle this case",
                    file: file, line: line)
            return
        }

        XCTAssertEqual(gpuImage.width, cpuImage.width, "\(label): width", file: file, line: line)
        XCTAssertEqual(gpuImage.height, cpuImage.height, "\(label): height", file: file, line: line)
        XCTAssertEqual(gpuImage.bitsPerPixel, cpuImage.bitsPerPixel,
                       "\(label): bitsPerPixel", file: file, line: line)
        XCTAssertEqual(gpuImage.bytesPerRow, cpuImage.bytesPerRow,
                       "\(label): bytesPerRow", file: file, line: line)

        let cpuBytes = try bytes(of: cpuImage)
        let gpuBytes = try bytes(of: gpuImage)
        XCTAssertEqual(cpuBytes.count, gpuBytes.count, "\(label): byte count",
                       file: file, line: line)

        if cpuBytes != gpuBytes {
            let firstDifference = zip(cpuBytes, gpuBytes).enumerated()
                .first { $0.element.0 != $0.element.1 }
            let detail = firstDifference.map {
                "first difference at byte \($0.offset): CPU \($0.element.0) vs GPU \($0.element.1)"
            } ?? "lengths differ"
            XCTFail("\(label): GPU output is not byte-identical to CPU — \(detail)",
                    file: file, line: line)
        }
    }

    // MARK: - Fixtures

    private func monochromeDescriptor(
        rows: Int, columns: Int,
        bitsAllocated: Int, bitsStored: Int, highBit: Int, isSigned: Bool,
        photometric: PhotometricInterpretation = .monochrome2,
        frames: Int = 1
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows, columns: columns, numberOfFrames: frames,
            bitsAllocated: bitsAllocated, bitsStored: bitsStored, highBit: highBit,
            isSigned: isSigned, samplesPerPixel: 1, photometricInterpretation: photometric
        )
    }

    /// Deterministic pseudo-random bytes — a fixed sequence, so a failure is
    /// reproducible, but not a smooth ramp that could hide an indexing error.
    private func scatteredBytes(count: Int, seed: UInt64 = 0x5DEECE66D) -> Data {
        var state = seed
        var data = Data(count: count)
        data.withUnsafeMutableBytes { raw in
            for i in 0..<raw.count {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                raw[i] = UInt8((state >> 33) & 0xFF)
            }
        }
        return data
    }

    private var windows: [WindowSettings] {
        [
            WindowSettings(center: 40, width: 400),
            WindowSettings(center: 2048, width: 4096),
            WindowSettings(center: 0, width: 1),
            WindowSettings(center: -500, width: 1500),
            WindowSettings(center: 32768, width: 65536),
            WindowSettings(center: 40, width: 400, function: .linearExact),
            WindowSettings(center: 1500, width: 2500, function: .sigmoid)
        ]
    }

    // MARK: - M3: monochrome

    /// The full descriptor matrix, at a size whose dimensions are coprime with any
    /// plausible threadgroup size — 37×23 will expose an off-by-one in the grid
    /// rounding that a 512×512 image would hide.
    func testMonochromeEquivalenceAcrossDescriptorsAndWindows() throws {
        let metal = try requireMetal()

        var descriptors: [PixelDataDescriptor] = []
        for photometric: PhotometricInterpretation in [.monochrome2, .monochrome1] {
            for isSigned in [false, true] {
                descriptors.append(monochromeDescriptor(
                    rows: 23, columns: 37, bitsAllocated: 8, bitsStored: 8, highBit: 7,
                    isSigned: isSigned, photometric: photometric))
                descriptors.append(monochromeDescriptor(
                    rows: 23, columns: 37, bitsAllocated: 16, bitsStored: 16, highBit: 15,
                    isSigned: isSigned, photometric: photometric))
                descriptors.append(monochromeDescriptor(
                    rows: 23, columns: 37, bitsAllocated: 16, bitsStored: 12, highBit: 11,
                    isSigned: isSigned, photometric: photometric))
                // High Bit above Bits Stored − 1: a non-zero bit shift, folded into
                // the table rather than done in the shader.
                descriptors.append(monochromeDescriptor(
                    rows: 23, columns: 37, bitsAllocated: 16, bitsStored: 12, highBit: 15,
                    isSigned: isSigned, photometric: photometric))
            }
        }

        for descriptor in descriptors {
            let data = scatteredBytes(count: descriptor.bytesPerFrame)
            let pixelData = PixelData(data: data, descriptor: descriptor).pageAligned()
            for window in windows {
                let request = FrameRenderRequest(
                    pixelData: pixelData, frameIndex: 0, window: window)
                try assertEquivalent(
                    request, metal,
                    "mono \(descriptor.bitsStored)-bit signed=\(descriptor.isSigned) "
                    + "\(descriptor.photometricInterpretation.rawValue) "
                    + "w=\(window.center)/\(window.width)/\(window.function.rawValue)")
            }
        }
    }

    /// Every representable 16-bit sample, so no table entry goes unchecked.
    func testMonochromeEquivalenceOverEveryRepresentableSample() throws {
        let metal = try requireMetal()
        // 65,536 samples laid out as 256×256.
        let descriptor = monochromeDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false)
        var data = Data(count: descriptor.bytesPerFrame)
        data.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for i in 0..<65_536 { out[i] = UInt16(i) }
        }
        let pixelData = PixelData(data: data, descriptor: descriptor).pageAligned()

        for window in windows {
            try assertEquivalent(
                FrameRenderRequest(pixelData: pixelData, frameIndex: 0, window: window),
                metal, "mono full-range w=\(window.center)/\(window.width)")
        }
    }

    /// A realistic size, and one that is an exact multiple of common threadgroup
    /// dimensions — the complement of the 37×23 case.
    func testMonochromeEquivalenceAtClinicalSize() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 512, columns: 512, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        try assertEquivalent(
            FrameRenderRequest(pixelData: pixelData, frameIndex: 0,
                               window: WindowSettings(center: 2048, width: 4096)),
            metal, "mono CT 512×512")
    }

    /// Frame indexing: the shader addresses a frame by byte offset within one
    /// wrapped buffer, so a wrong offset would show up only past frame 0.
    func testMonochromeEquivalenceAcrossFrames() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, frames: 5)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.totalBytes),
                                  descriptor: descriptor).pageAligned()
        for frame in 0..<5 {
            try assertEquivalent(
                FrameRenderRequest(pixelData: pixelData, frameIndex: frame,
                                   window: WindowSettings(center: 30000, width: 60000)),
                metal, "mono frame \(frame)")
        }
    }

    /// Unaligned input must produce identical pixels too — it just takes the
    /// pooled-copy route instead of `bytesNoCopy`.
    func testMonochromeEquivalenceWithUnalignedInput() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 23, columns: 37, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor)
        XCTAssertNil(pixelData.alignedStorage)
        try assertEquivalent(
            FrameRenderRequest(pixelData: pixelData, frameIndex: 0,
                               window: WindowSettings(center: 32768, width: 65536)),
            metal, "mono unaligned input")
    }

    // MARK: - M4: colour

    func testRGBEquivalenceAcrossPlanarConfigurations() throws {
        let metal = try requireMetal()
        for planar in [0, 1] {
            for (bitsAllocated, bitsStored, highBit) in [(8, 8, 7), (16, 16, 15), (16, 12, 11)] {
                let descriptor = PixelDataDescriptor(
                    rows: 23, columns: 37,
                    bitsAllocated: bitsAllocated, bitsStored: bitsStored, highBit: highBit,
                    isSigned: false, samplesPerPixel: 3,
                    photometricInterpretation: .rgb, planarConfiguration: planar
                )
                let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                          descriptor: descriptor).pageAligned()
                try assertEquivalent(
                    FrameRenderRequest(pixelData: pixelData),
                    metal, "rgb planar=\(planar) \(bitsStored)-bit")
            }
        }
    }

    func testPaletteEquivalence() throws {
        let metal = try requireMetal()
        for (bitsAllocated, bitsStored, highBit, entries) in
            [(8, 8, 7, 256), (16, 16, 15, 4096)] {
            let descriptor = PixelDataDescriptor(
                rows: 23, columns: 37,
                bitsAllocated: bitsAllocated, bitsStored: bitsStored, highBit: highBit,
                isSigned: false, samplesPerPixel: 1,
                photometricInterpretation: .paletteColor
            )
            let lutDescriptor = PaletteColorLUT.Descriptor(
                numberOfEntries: entries, firstMappedValue: 0, bitsPerEntry: 16)
            // Three distinct ramps, so a channel swap cannot pass.
            let red = (0..<entries).map { UInt16(($0 &* 7) % 65_536) }
            let green = (0..<entries).map { UInt16(($0 &* 251) % 65_536) }
            let blue = (0..<entries).map { UInt16(65_535 - ($0 % 65_536)) }
            let palette = PaletteColorLUT(
                redDescriptor: lutDescriptor, greenDescriptor: lutDescriptor,
                blueDescriptor: lutDescriptor,
                redLUT: red, greenLUT: green, blueLUT: blue)

            let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                      descriptor: descriptor).pageAligned()
            try assertEquivalent(
                FrameRenderRequest(pixelData: pixelData, paletteLUT: palette),
                metal, "palette \(bitsStored)-bit")
        }
    }

    /// YBR must be *declined* by the GPU, not approximated by it.
    ///
    /// This is the documented scope limit from M4: green depends on all three of
    /// Y, Cb and Cr, so an exact table would need 2^24 entries and anything smaller
    /// means float arithmetic that diverges from the CPU's Double. The service must
    /// route these to the CPU, and the picture must still be right.
    func testYBRIsDeclinedByGPUAndStillRenders() throws {
        let metal = try requireMetal()
        let descriptor = PixelDataDescriptor(
            rows: 23, columns: 37, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3,
            photometricInterpretation: .ybrFull, planarConfiguration: 0
        )
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        let request = FrameRenderRequest(pixelData: pixelData)

        XCTAssertNil(metal.renderFrame(request),
                     "the GPU must decline YBR rather than approximate it")

        let service = FrameRenderService(preference: .metal)
        let viaService = try XCTUnwrap(service.renderFrame(request))
        let viaCPU = try XCTUnwrap(cpu.renderFrame(request))
        XCTAssertEqual(try bytes(of: viaService), try bytes(of: viaCPU),
                       "the fallback must produce exactly the CPU's image")
    }

    /// Auto-windowing (no explicit window) is also a CPU-only path, for the same
    /// reason: it is a policy decision, and there must be only one of it.
    func testMissingWindowFallsBackToCPU() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        let request = FrameRenderRequest(pixelData: pixelData, frameIndex: 0, window: nil)

        XCTAssertNil(metal.renderFrame(request))
        XCTAssertNotNil(FrameRenderService(preference: .metal).renderFrame(request))
    }

    // MARK: - Size threshold

    /// The production renderer must decline small frames, and the service must
    /// still return the right picture for them.
    ///
    /// This is the measured finding from M3: a dispatch costs ~0.24 ms regardless
    /// of size, so on an M4 a 512×512 CT is *faster* on the CPU (0.156 ms) than on
    /// the GPU (0.254 ms). Sending small renders to the GPU anyway would make the
    /// most common render in the app — tiles and thumbnails — slower.
    func testSmallFramesAreDeclinedByTheProductionRenderer() throws {
        guard let production = MetalFrameRenderer() else {
            throw XCTSkip("No Metal device on this machine")
        }
        let descriptor = monochromeDescriptor(
            rows: 512, columns: 512, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false)
        XCTAssertLessThan(descriptor.pixelsPerFrame, MetalFrameRenderer.minimumGPUPixelCount)

        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        let request = FrameRenderRequest(pixelData: pixelData, frameIndex: 0,
                                         window: WindowSettings(center: 2048, width: 4096))

        XCTAssertNil(production.renderFrame(request),
                     "a sub-megapixel frame must not be dispatched to the GPU")

        let viaService = try XCTUnwrap(FrameRenderService(preference: .metal).renderFrame(request))
        let viaCPU = try XCTUnwrap(cpu.renderFrame(request))
        XCTAssertEqual(try bytes(of: viaService), try bytes(of: viaCPU))
    }

    /// …and must accept a frame above the threshold, so the constant is not
    /// accidentally set somewhere nothing reaches.
    func testLargeFramesAreAcceptedByTheProductionRenderer() throws {
        guard let production = MetalFrameRenderer() else {
            throw XCTSkip("No Metal device on this machine")
        }
        let descriptor = monochromeDescriptor(
            rows: 1024, columns: 1024, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false)
        XCTAssertGreaterThanOrEqual(descriptor.pixelsPerFrame,
                                    MetalFrameRenderer.minimumGPUPixelCount)

        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        let request = FrameRenderRequest(pixelData: pixelData, frameIndex: 0,
                                         window: WindowSettings(center: 2048, width: 4096))

        let gpu = try XCTUnwrap(production.renderFrame(request))
        let cpuImage = try XCTUnwrap(cpu.renderFrame(request))
        XCTAssertEqual(try bytes(of: gpu), try bytes(of: cpuImage))
    }

    // MARK: - Zero copy (design pillar 2)

    /// The claim that carries the whole design: with aligned input, a render copies
    /// no pixel data at all.
    func testAlignedInputTakesTheNoCopyPath() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()
        XCTAssertNotNil(pixelData.alignedStorage)

        _ = metal.renderFrame(FrameRenderRequest(
            pixelData: pixelData, frameIndex: 0,
            window: WindowSettings(center: 32768, width: 65536)))

        let counters = metal.memoryCounters
        XCTAssertEqual(counters.pixelCopies, 0, "aligned input must not be copied")
        XCTAssertGreaterThan(counters.zeroCopyWraps, 0, "input must be wrapped in place")
    }

    /// The M3 exit criterion: a steady-state window drag allocates nothing and
    /// copies no pixels.
    ///
    /// The first render is allowed to allocate — that is the pool filling. Every
    /// render after it must reuse, which is what makes a drag free.
    func testSteadyStateDragAllocatesNothingAndCopiesNothing() throws {
        let metal = try requireMetal()
        let descriptor = monochromeDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false)
        let pixelData = PixelData(data: scatteredBytes(count: descriptor.bytesPerFrame),
                                  descriptor: descriptor).pageAligned()

        // Warm-up: fills the pool and wraps the input.
        autoreleasepool {
            _ = metal.renderFrame(FrameRenderRequest(
                pixelData: pixelData, frameIndex: 0,
                window: WindowSettings(center: 2048, width: 4096)))
        }
        let baseline = metal.memoryCounters

        // A drag: 40 deltas, a new window each time, each image released before the
        // next render so its output buffer returns to the pool.
        for step in 0..<40 {
            autoreleasepool {
                let window = WindowSettings(center: 2048 + Double(step) * 4, width: 4096)
                _ = metal.renderFrame(FrameRenderRequest(
                    pixelData: pixelData, frameIndex: 0, window: window))
            }
        }

        let after = metal.memoryCounters
        XCTAssertEqual(after.allocations, baseline.allocations,
                       "a steady-state drag must not allocate a single buffer")
        XCTAssertEqual(after.pixelCopies, 0,
                       "a steady-state drag must not copy pixel data")
        XCTAssertEqual(after.zeroCopyWraps, baseline.zeroCopyWraps,
                       "the input must be wrapped once, not re-wrapped per render")
    }

    #endif

    // MARK: - Aligned storage (M2b)

    func testAlignedBufferIsPageAlignedAndPageSized() throws {
        let buffer = try XCTUnwrap(AlignedPixelBuffer(byteCount: 1000))
        XCTAssertTrue(buffer.isPageAligned)
        XCTAssertEqual(buffer.byteCount, 1000)
        XCTAssertEqual(buffer.allocatedByteCount % AlignedPixelBuffer.pageSize, 0)
        XCTAssertGreaterThanOrEqual(buffer.allocatedByteCount, 1000)
    }

    func testAlignedBufferRejectsEmpty() {
        XCTAssertNil(AlignedPixelBuffer(byteCount: 0))
        XCTAssertNil(AlignedPixelBuffer(copying: Data()))
    }

    /// The bytes must survive, and `data` must be a view rather than a copy.
    func testAlignedCopyPreservesBytesWithoutCopyingOnRead() throws {
        let original = Data((0..<5000).map { UInt8($0 % 256) })
        let buffer = try XCTUnwrap(AlignedPixelBuffer(copying: original))
        XCTAssertEqual(buffer.data, original)

        let viewed = buffer.data.withUnsafeBytes { $0.baseAddress }
        XCTAssertEqual(viewed, UnsafeRawPointer(buffer.baseAddress),
                       "`data` must view the aligned allocation, not copy it")
    }

    /// The `Data` must keep the allocation alive on its own — otherwise a caller
    /// holding only the `Data` would be reading freed memory.
    func testDataOutlivesTheBufferReference() throws {
        var buffer: AlignedPixelBuffer? = AlignedPixelBuffer(copying: Data(repeating: 0xAB, count: 4096))
        let data = try XCTUnwrap(buffer?.data)
        buffer = nil
        XCTAssertEqual(data.count, 4096)
        XCTAssertTrue(data.allSatisfy { $0 == 0xAB })
    }

    func testPageAlignedIsIdempotentAndPreservesPixels() {
        let descriptor = PixelDataDescriptor(
            rows: 8, columns: 8, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, samplesPerPixel: 1, photometricInterpretation: .monochrome2)
        let original = PixelData(data: Data((0..<128).map { UInt8($0) }), descriptor: descriptor)

        let aligned = original.pageAligned()
        XCTAssertNotNil(aligned.alignedStorage)
        XCTAssertEqual(aligned.data, original.data)

        // Calling it twice must not copy again.
        let again = aligned.pageAligned()
        XCTAssertTrue(again.alignedStorage === aligned.alignedStorage)
    }
}
