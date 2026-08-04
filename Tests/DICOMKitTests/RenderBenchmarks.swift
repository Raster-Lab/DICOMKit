import XCTest
@testable import DICOMKit
import DICOMCore
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Metal)
import Metal
#endif

/// Milestone 0 of `GPU_RENDERING_PLAN.md`: the baseline every later milestone reports a
/// delta against.
///
/// Skipped unless `DICOMKIT_RUN_RENDER_BENCH=1` — these are timing runs, not assertions,
/// and a 3000×4000 render loop has no business in the normal test pass. Run them with:
///
/// ```
/// DICOMKIT_RUN_RENDER_BENCH=1 swift test --filter RenderBenchmarks -c release
/// ```
///
/// Always measure in **release**. A debug build's bounds-checking dominates the scalar
/// loop and would flatter every subsequent milestone.
final class RenderBenchmarks: XCTestCase {

    private var shouldRun: Bool {
        ProcessInfo.processInfo.environment["DICOMKIT_RUN_RENDER_BENCH"] == "1"
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(shouldRun, "Set DICOMKIT_RUN_RENDER_BENCH=1 to run render benchmarks")
    }

    // MARK: - Timing

    /// Best-of-`iterations` wall clock, in milliseconds.
    ///
    /// Best-of rather than mean: we are measuring the cost of the work, and the fastest
    /// run is the one least polluted by scheduling noise.
    private func bestMilliseconds(iterations: Int = 5, _ body: () -> Void) -> Double {
        var best = Double.infinity
        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            body()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            best = min(best, elapsed)
        }
        return best
    }

    private func report(_ label: String, _ milliseconds: Double, pixels: Int? = nil) {
        let padded = label.padding(toLength: max(label.count, 36), withPad: " ", startingAt: 0)
        var line = "  " + padded + String(format: "%8.3f ms", milliseconds)
        if let pixels, milliseconds > 0 {
            let megapixelsPerSecond = Double(pixels) / (milliseconds / 1000) / 1_000_000
            line += String(format: "   %8.1f Mpx/s", megapixelsPerSecond)
        }
        print(line)
    }

    // MARK: - Synthetic frames

    private struct Case {
        let name: String
        let rows: Int
        let columns: Int
    }

    /// Representative clinical sizes: a CT slice, a CR/DX plate, a mammogram.
    private let monochromeCases = [
        Case(name: "CT 512×512 16-bit", rows: 512, columns: 512),
        Case(name: "CR/DX 2048×2500 16-bit", rows: 2500, columns: 2048),
        Case(name: "MG 3000×4000 16-bit", rows: 4000, columns: 3000)
    ]

    private func monochromePixelData(rows: Int, columns: Int) -> PixelData {
        let descriptor = PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: 16, bitsStored: 12, highBit: 11, isSigned: false,
            samplesPerPixel: 1, photometricInterpretation: .monochrome2
        )
        var bytes = Data(count: rows * columns * 2)
        bytes.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for i in 0..<(rows * columns) {
                out[i] = UInt16((i &* 7) % 4096)
            }
        }
        return PixelData(data: bytes, descriptor: descriptor)
    }

    private func rgbPixelData(rows: Int, columns: Int) -> PixelData {
        let descriptor = PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: 8, bitsStored: 8, highBit: 7, isSigned: false,
            samplesPerPixel: 3, photometricInterpretation: .rgb, planarConfiguration: 0
        )
        var bytes = Data(count: rows * columns * 3)
        bytes.withUnsafeMutableBytes { raw in
            for i in 0..<raw.count { raw[i] = UInt8(i % 256) }
        }
        return PixelData(data: bytes, descriptor: descriptor)
    }

    private func palettePixelData(rows: Int, columns: Int) -> (PixelData, PaletteColorLUT) {
        let descriptor = PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: 8, bitsStored: 8, highBit: 7, isSigned: false,
            samplesPerPixel: 1, photometricInterpretation: .paletteColor
        )
        var bytes = Data(count: rows * columns)
        bytes.withUnsafeMutableBytes { raw in
            for i in 0..<raw.count { raw[i] = UInt8(i % 256) }
        }
        let descriptorLUT = PaletteColorLUT.Descriptor(
            numberOfEntries: 256, firstMappedValue: 0, bitsPerEntry: 8
        )
        let ramp = (0..<256).map { UInt16($0) }
        let lut = PaletteColorLUT(
            redDescriptor: descriptorLUT, greenDescriptor: descriptorLUT,
            blueDescriptor: descriptorLUT,
            redLUT: ramp, greenLUT: ramp, blueLUT: ramp
        )
        return (PixelData(data: bytes, descriptor: descriptor), lut)
    }

    // MARK: - Benchmarks

    #if canImport(CoreGraphics)
    /// A single full-frame monochrome render, per size — the cost of showing an image.
    func testMonochromeRenderBaseline() {
        print("\n[bench] monochrome renderMonochromeFrame (linear window)")
        let window = WindowSettings(center: 2048, width: 4096)
        for testCase in monochromeCases {
            let renderer = PixelDataRenderer(
                pixelData: monochromePixelData(rows: testCase.rows, columns: testCase.columns)
            )
            let milliseconds = bestMilliseconds {
                _ = renderer.renderMonochromeFrame(0, window: window)
            }
            report(testCase.name, milliseconds, pixels: testCase.rows * testCase.columns)
        }
    }

    /// The sigmoid VOI function calls `exp()`. Before the LUT that was once per pixel;
    /// after it, once per table entry regardless of image size. The gap between this and
    /// the linear numbers above is the measurement of that.
    func testMonochromeSigmoidRenderBaseline() {
        print("\n[bench] monochrome renderMonochromeFrame (SIGMOID window)")
        let window = WindowSettings(center: 2048, width: 4096, function: .sigmoid)
        for testCase in monochromeCases {
            let renderer = PixelDataRenderer(
                pixelData: monochromePixelData(rows: testCase.rows, columns: testCase.columns)
            )
            let milliseconds = bestMilliseconds {
                _ = renderer.renderMonochromeFrame(0, window: window)
            }
            report(testCase.name, milliseconds, pixels: testCase.rows * testCase.columns)
        }
    }

    /// The interactive hot path: `ImageViewerViewModel.adjustWindowLevel` re-renders the
    /// full frame synchronously on every mouse delta, so a drag is N renders at N
    /// distinct windows — which also means N table builds, no cache hits. 60 fps allows
    /// 16.7 ms per step; the per-step figure here is what has to fit inside that.
    func testWindowDragBaseline() {
        print("\n[bench] synthetic window drag — 60 deltas, per-step cost")
        let steps = 60
        for testCase in monochromeCases {
            let renderer = PixelDataRenderer(
                pixelData: monochromePixelData(rows: testCase.rows, columns: testCase.columns)
            )
            let milliseconds = bestMilliseconds(iterations: 3) {
                for step in 0..<steps {
                    let window = WindowSettings(center: 2048 + Double(step) * 8, width: 4096)
                    _ = renderer.renderMonochromeFrame(0, window: window)
                }
            }
            report(testCase.name + " (per step)", milliseconds / Double(steps),
                   pixels: testCase.rows * testCase.columns)
        }
    }

    /// Cine: same window, successive frames. This is the case the table cache serves —
    /// every frame after the first reuses one table.
    func testCineFrameToFrameBaseline() {
        print("\n[bench] cine — same window, repeated frames, per-frame cost")
        let window = WindowSettings(center: 2048, width: 4096)
        let frames = 30
        for testCase in monochromeCases where testCase.rows * testCase.columns <= 2048 * 2500 {
            let renderer = PixelDataRenderer(
                pixelData: monochromePixelData(rows: testCase.rows, columns: testCase.columns)
            )
            let milliseconds = bestMilliseconds(iterations: 3) {
                for _ in 0..<frames {
                    _ = renderer.renderMonochromeFrame(0, window: window)
                }
            }
            report(testCase.name + " (per frame)", milliseconds / Double(frames),
                   pixels: testCase.rows * testCase.columns)
        }
    }

    func testColorRenderBaseline() {
        print("\n[bench] colour paths")
        let rgb = PixelDataRenderer(pixelData: rgbPixelData(rows: 1024, columns: 1024))
        report("RGB 1024×1024 8-bit", bestMilliseconds { _ = rgb.renderColorFrame(0) },
               pixels: 1024 * 1024)

        let (palettePixels, lut) = palettePixelData(rows: 512, columns: 512)
        let palette = PixelDataRenderer(pixelData: palettePixels, paletteColorLUT: lut)
        report("PALETTE 512×512 8-bit",
               bestMilliseconds { _ = palette.renderPaletteColorFrame(0) },
               pixels: 512 * 512)
    }
    #endif

    /// What a copy of each frame would cost.
    ///
    /// Design pillar 2 of the plan is built entirely around avoiding an upload and a
    /// readback. If these numbers were negligible the pillar would not be worth its
    /// complexity, so they belong on the record *before* the Metal work starts.
    func testFrameCopyCost() {
        print("\n[bench] plain memcpy of one frame (the copies pillar 2 removes)")
        for testCase in monochromeCases {
            let byteCount = testCase.rows * testCase.columns * 2
            let source = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 16)
            let destination = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 16)
            defer { source.deallocate(); destination.deallocate() }
            memset(source, 0x5A, byteCount)

            let milliseconds = bestMilliseconds(iterations: 10) {
                destination.copyMemory(from: source, byteCount: byteCount)
            }
            report(testCase.name + " (\(byteCount / (1024 * 1024)) MB)", milliseconds)
        }
    }

    /// Records the machine the numbers above were taken on, and whether it is the
    /// unified-memory hardware `RenderBackend.automatic()` will select Metal for.
    func testDeviceCapabilities() {
        print("\n[bench] device")
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            print("  name                 \(device.name)")
            print("  hasUnifiedMemory     \(device.hasUnifiedMemory)")
            let workingSet = Double(device.recommendedMaxWorkingSetSize) / (1024 * 1024 * 1024)
            print(String(format: "  recommendedMaxWorkingSetSize  %.1f GB", workingSet))
            print("  maxThreadsPerThreadgroup  \(device.maxThreadsPerThreadgroup)")
        } else {
            print("  no Metal device")
        }
        #else
        print("  Metal not available on this platform")
        #endif
        print("  activeProcessorCount \(ProcessInfo.processInfo.activeProcessorCount)")
        print("  physicalMemory       "
              + String(format: "%.1f GB",
                       Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)))
    }
}
