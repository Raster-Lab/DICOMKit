import XCTest
import DICOMRenderKit
import DICOMKit
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Measures the cost the focused viewer pays on every window/level delta.
///
/// `ImageViewerViewModel.renderCurrentFrame` calls `DICOMFile.tryRenderFrame`, which
/// calls `tryPixelData()` — so **every mouse-move re-decodes the whole frame**. For a
/// compressed file that means running the codec again, per event. The tile and film
/// path solved this long ago with `FrameSourceCache`; the focused viewer never got
/// the same treatment.
///
/// These benchmarks exist to put a number on it before it is fixed, rather than
/// trusting the estimate in `FrameSourceCache`'s own header comment ("tens of
/// milliseconds per event"). The comparison is deliberately like-for-like: the same
/// window, the same frame, the same renderer — only the decode is hoisted.
///
/// ```
/// DICOMKIT_RUN_RENDER_BENCH=1 swift test -c release --filter DecodePerDragBenchmarks
/// ```
final class DecodePerDragBenchmarks: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DICOMKIT_RUN_RENDER_BENCH"] == "1",
            "Set DICOMKIT_RUN_RENDER_BENCH=1 to run render benchmarks")
    }

    private func bestMilliseconds(iterations: Int = 3, _ body: () -> Void) -> Double {
        var best = Double.infinity
        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            body()
            best = min(best, Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        return best
    }

    private func report(_ label: String, _ milliseconds: Double) {
        let padded = label.padding(toLength: max(label.count, 44), withPad: " ", startingAt: 0)
        print("  " + padded + String(format: "%9.3f ms", milliseconds))
    }

    // MARK: - Fixture

    /// A CR-sized 16-bit MONOCHROME2 file, uncompressed, as raw DICOM bytes.
    ///
    /// 2048×2500 rather than 512×512 because the point is the interactive path on a
    /// frame big enough for the cost to matter.
    private func uncompressedFileData(rows: Int = 2500, columns: Int = 2048) throws -> Data {
        var elements: [DataElement] = []
        elements.append(.uint16(tag: .rows, value: UInt16(rows)))
        elements.append(.uint16(tag: .columns, value: UInt16(columns)))
        elements.append(.uint16(tag: .bitsAllocated, value: 16))
        elements.append(.uint16(tag: .bitsStored, value: 12))
        elements.append(.uint16(tag: .highBit, value: 11))
        elements.append(.uint16(tag: .pixelRepresentation, value: 0))
        elements.append(.uint16(tag: .samplesPerPixel, value: 1))
        elements.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        elements.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.1"))
        elements.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9.10"))
        elements.append(.string(tag: .studyInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9.11"))
        elements.append(.string(tag: .seriesInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9.12"))

        // Structured content, not noise: a smooth gradient compresses the way real
        // anatomy roughly does. Random bytes would make a lossless codec look far
        // slower and larger than it is in practice.
        var pixels = Data(count: rows * columns * 2)
        pixels.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for y in 0..<rows {
                for x in 0..<columns {
                    out[y * columns + x] = UInt16((x / 2 + y / 3) % 4096)
                }
            }
        }
        elements.append(DataElement(tag: .pixelData, vr: .OW,
                                    length: UInt32(pixels.count), valueData: pixels))

        return try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        ).write()
    }

    // MARK: - Benchmarks

    /// The measurement that matters: 30 window deltas, decoding per step (today) vs
    /// decoding once (with a pixel cache).
    func testDragCostWithAndWithoutPixelCache() throws {
        let steps = 30
        let cases: [(name: String, codec: String?)] = [
            ("uncompressed (Explicit VR LE)", nil),
            ("JPEG 2000 lossless", "jpeg2000-lossless"),
            ("JPEG-LS lossless", "jpeg-ls-lossless"),
            ("RLE lossless", "rle")
        ]

        let raw = try uncompressedFileData()
        print("\n[bench] focused-viewer window drag — \(steps) deltas, CR/DX 2048×2500")
        print("        'per step, decoding each time' is what the viewer does today.")

        for testCase in cases {
            var data = raw
            if let codec = testCase.codec {
                do {
                    data = try CompressionManager().compressData(
                        raw, codec: codec, quality: nil)
                } catch {
                    print("  \(testCase.name): skipped — \(error)")
                    continue
                }
            }

            let file = try DICOMFile.read(from: data, force: true)
            let window = WindowSettings(center: 2048, width: 4096)

            // Today's path: renderCurrentFrame → tryRenderFrame → tryPixelData.
            let perStepDecoding = bestMilliseconds {
                for step in 0..<steps {
                    let w = WindowSettings(center: 2048 + Double(step) * 8, width: 4096)
                    _ = try? file.tryRenderFrame(0, window: w)
                }
            }

            // With a pixel cache: decode once, then re-window the cached pixels —
            // exactly what FrameSourceCache already does for tiles.
            guard let decoded = file.pixelData() else {
                print("  \(testCase.name): skipped — no pixel data")
                continue
            }
            let cached = decoded.pageAligned()
            let decodeOnce = bestMilliseconds { _ = file.pixelData() }
            let perStepCached = bestMilliseconds {
                for step in 0..<steps {
                    let w = WindowSettings(center: 2048 + Double(step) * 8, width: 4096)
                    autoreleasepool {
                        _ = FrameRenderService.shared.renderFrame(
                            FrameRenderRequest(pixelData: cached, frameIndex: 0, window: w))
                    }
                }
            }

            print("  \(testCase.name):")
            report("    per step, decoding each time (today)", perStepDecoding / Double(steps))
            report("    per step, cached pixels", perStepCached / Double(steps))
            report("    one-time decode", decodeOnce)
            _ = window
        }
    }
}
