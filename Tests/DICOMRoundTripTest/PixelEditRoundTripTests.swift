import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Round-trip / oracle tests for `dicom-pixedit`.
///
/// Every case drives the DICOMKit library directly (never the CLI) via
/// `PixelEditor.processData(_:operations:)` — the same entry the CLI's
/// `processFile` funnels through — and asserts a mathematical/semantic invariant
/// (double-invert identity, two's-complement NOT, crop dimensions, mask fill,
/// window-bake endpoints, VOI-window update). No re-implementation of the tool.
final class PixelEditRoundTripTests: XCTestCase {

    // Shared editor (non-verbose).
    private let editor = PixelEditor(verbose: false)

    // MARK: - Private helpers

    /// Builds a 16-bit unsigned 1×N image from explicit sample values.
    private func makeU16Row(_ values: [UInt16]) -> DICOMFile {
        makeGrayscale16(rows: 1, cols: UInt16(values.count),
                        fillPattern: { values[$0] }, signed: false)
    }

    /// Builds a 16-bit signed 1×N image from explicit Int16 sample values.
    private func makeI16Row(_ values: [Int16]) -> DICOMFile {
        makeGrayscale16(rows: 1, cols: UInt16(values.count),
                        fillPattern: { UInt16(bitPattern: values[$0]) }, signed: true)
    }

    /// Runs operations on a file and returns the parsed output DICOMFile.
    private func run(_ file: DICOMFile, _ ops: [PixelOperation]) throws -> DICOMFile {
        let input = try file.write()
        let (out, _) = try editor.processData(input, operations: ops)
        return try DICOMFile.read(from: out)
    }

    // MARK: - Invert: 8-bit unsigned

    // Oracle: 8-bit unsigned invert -> output[i] + input[i] == 255, and invert∘invert == identity.
    func testInvert8BitUnsignedComplementAndInvolution() throws {
        let src: [UInt8] = [0, 50, 100, 200, 255]
        let file = makeGrayscale8(rows: 1, cols: UInt16(src.count), fillPattern: { src[$0] })

        let once = try run(file, [.invert])
        let onceBytes = pixelBytes(once)
        for i in 0..<src.count {
            XCTAssertEqual(Int(readU8(onceBytes, at: i)) + Int(src[i]), 255,
                           "invert must complement to 255 at index \(i)")
        }

        // Double invert restores the original bytes exactly.
        let twice = try run(file, [.invert, .invert])
        let twiceBytes = pixelBytes(twice)
        for i in 0..<src.count {
            XCTAssertEqual(readU8(twiceBytes, at: i), src[i],
                           "invert(invert(x)) must equal x at index \(i)")
        }
    }

    // MARK: - Invert: 16-bit unsigned

    // Oracle: 16-bit unsigned invert -> output[i] + input[i] == 65535.
    func testInvert16BitUnsignedComplement() throws {
        let src: [UInt16] = [0, 1000, 32767, 65535]
        let file = makeU16Row(src)

        let out = try run(file, [.invert])
        let bytes = pixelBytes(out)
        for i in 0..<src.count {
            XCTAssertEqual(Int(readU16(bytes, at: i)) + Int(src[i]), 65535,
                           "16-bit unsigned invert must complement to 65535 at index \(i)")
        }
    }

    // MARK: - Invert: 16-bit signed

    // Oracle: 16-bit signed invert -> output[i] == -(input[i] + 1) (two's-complement NOT); involution holds.
    func testInvert16BitSignedTwosComplementNot() throws {
        let src: [Int16] = [-32768, -100, 0, 100, 32767]
        let file = makeI16Row(src)

        let once = try run(file, [.invert])
        let onceBytes = pixelBytes(once)
        for i in 0..<src.count {
            let expected = Int16(truncatingIfNeeded: -(Int(src[i]) + 1))
            XCTAssertEqual(readI16(onceBytes, at: i), expected,
                           "signed invert must equal -(x+1) at index \(i)")
        }

        let twice = try run(file, [.invert, .invert])
        let twiceBytes = pixelBytes(twice)
        for i in 0..<src.count {
            XCTAssertEqual(readI16(twiceBytes, at: i), src[i],
                           "signed invert(invert(x)) must equal x at index \(i)")
        }
    }

    // MARK: - Invert + VOI window update (the original bug)

    // Oracle: invert must re-point VOI Window Center; unsigned 16-bit no slope/intercept -> 65535 - C.
    func testInvertUpdatesVOIWindowCenter() throws {
        var file = makeU16Row([0, 1000, 32767, 65535])
        var ds = file.dataSet
        ds.setString("500", for: .windowCenter, vr: .DS)
        ds.setString("1000", for: .windowWidth, vr: .DS)
        file = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)

        let out = try run(file, [.invert])
        let centers = try XCTUnwrap(out.dataSet.decimalStrings(for: .windowCenter),
                                    "output must retain a VOI Window Center")
        let c = try XCTUnwrap(centers.first).value
        // Must have changed away from the original 500 …
        XCTAssertNotEqual(c, 500, "invert must update Window Center, not leave it at 500")
        // … and for unsigned 16-bit with slope=1/intercept=0: C' = 65535 - 500 = 65035.
        XCTAssertEqual(c, 65035, accuracy: 0.5,
                       "inverted Window Center must be 65535 - 500")
        // Window Width is a span and is unchanged.
        let widths = try XCTUnwrap(out.dataSet.decimalStrings(for: .windowWidth))
        XCTAssertEqual(try XCTUnwrap(widths.first).value, 1000, accuracy: 0.5,
                       "Window Width must be unchanged by invert")
    }

    // MARK: - Mask

    // Oracle: mask fills exactly the requested region with fillValue; all other pixels unchanged.
    func testMaskFillsOnlyRegion() throws {
        // 4×4, all pixels = 128.
        let file = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 128 })
        let out = try run(file, [.mask(x: 1, y: 1, width: 2, height: 2, fillValue: 0)])
        let bytes = pixelBytes(out)

        let masked: Set<Int> = [
            1 * 4 + 1, 1 * 4 + 2,   // row 1, cols 1..2
            2 * 4 + 1, 2 * 4 + 2    // row 2, cols 1..2
        ]
        for idx in 0..<16 {
            let v = readU8(bytes, at: idx)
            if masked.contains(idx) {
                XCTAssertEqual(v, 0, "masked pixel \(idx) must be 0")
            } else {
                XCTAssertEqual(v, 128, "unmasked pixel \(idx) must stay 128")
            }
        }
    }

    // Oracle: --fill-value drives the exact masked value — a non-zero, non-default fill
    // (200) writes 200 into the region (not the default 0), leaving other pixels untouched.
    func testMaskUsesNonZeroFillValue() throws {
        let file = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 128 })
        let fill = 200
        let out = try run(file, [.mask(x: 1, y: 1, width: 2, height: 2, fillValue: fill)])
        let bytes = pixelBytes(out)

        let masked: Set<Int> = [1 * 4 + 1, 1 * 4 + 2, 2 * 4 + 1, 2 * 4 + 2]
        for idx in 0..<16 {
            let v = Int(readU8(bytes, at: idx))
            XCTAssertEqual(v, masked.contains(idx) ? fill : 128,
                           "pixel \(idx): masked→\(fill), else→128")
        }
    }

    // Oracle: a mask region overflowing the image is clamped (no throw); out-of-region pixels unchanged.
    func testMaskClampsAtBorder() throws {
        let file = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 128 })
        // Region starts inside but extends well past the right/bottom edges.
        let out = try run(file, [.mask(x: 2, y: 2, width: 10, height: 10, fillValue: 0)])
        let bytes = pixelBytes(out)

        for row in 0..<4 {
            for col in 0..<4 {
                let idx = row * 4 + col
                let v = readU8(bytes, at: idx)
                if row >= 2 && col >= 2 {
                    XCTAssertEqual(v, 0, "clamped-mask pixel (\(row),\(col)) must be 0")
                } else {
                    XCTAssertEqual(v, 128, "pixel (\(row),\(col)) outside mask must stay 128")
                }
            }
        }
    }

    // MARK: - Crop

    // Oracle: crop updates Rows/Columns and copies the exact sub-rectangle (output[r,c] == input[y+r, x+c]).
    func testCropUpdatesDimensionsAndCopiesRegion() throws {
        // 8×8 sequential: pixel[row*8 + col] = (row*8 + col) % 256.
        let file = makeGrayscale8(rows: 8, cols: 8, fillPattern: { UInt8($0 % 256) })
        let (out, info) = try {
            let input = try file.write()
            let (o, i) = try editor.processData(input,
                operations: [.crop(x: 2, y: 3, width: 4, height: 2)])
            return (try DICOMFile.read(from: o), i)
        }()

        // Dimensions from returned info and from the written DICOM tags.
        XCTAssertEqual(info.rows, 2)
        XCTAssertEqual(info.columns, 4)
        XCTAssertEqual(out.dataSet.uint16(for: .rows), 2, "cropped Rows tag must be 2")
        XCTAssertEqual(out.dataSet.uint16(for: .columns), 4, "cropped Columns tag must be 4")

        let bytes = pixelBytes(out)
        XCTAssertEqual(bytes.count, 2 * 4, "cropped pixel data must be 8 bytes")
        // output[r,c] == input[(3+r)*8 + (2+c)]
        for r in 0..<2 {
            for c in 0..<4 {
                let expected = UInt8(((3 + r) * 8 + (2 + c)) % 256)
                let actual = readU8(bytes, at: r * 4 + c)
                XCTAssertEqual(actual, expected,
                               "cropped output[\(r),\(c)] must equal source pixel")
            }
        }
        // Spot-check the two plan corners: output[0,0]==input[2,3], output[3,1]==input[5,4].
        XCTAssertEqual(readU8(bytes, at: 0 * 4 + 0), UInt8((3 * 8 + 2) % 256))
        XCTAssertEqual(readU8(bytes, at: 1 * 4 + 3), UInt8((4 * 8 + 5) % 256))
    }

    // MARK: - Window/Level bake

    // Oracle: window bake maps [center±width] linearly onto the full 0..65535 range at the endpoints.
    func testWindowLevelBakeEndpoints() throws {
        // 16-bit unsigned, pixels [0, 500, 1000, 1500, 2000].
        let file = makeU16Row([0, 500, 1000, 1500, 2000])
        let out = try run(file, [.windowLevel(center: 1000, width: 2000)])
        let bytes = pixelBytes(out)

        // The bake operates in-place on 16-bit samples (bitsAllocated stays 16 here),
        // remapping onto the full stored range [0, 65535].
        XCTAssertEqual(out.dataSet.uint16(for: .bitsAllocated), 16)

        let v0 = Int(readU16(bytes, at: 0))
        let v2 = Int(readU16(bytes, at: 2))
        let v4 = Int(readU16(bytes, at: 4))

        // center=1000,width=2000 => input 0 -> low endpoint, 2000 -> high endpoint,
        // 1000 -> mid. Ordering + endpoint saturation are the oracle.
        XCTAssertLessThan(v0, v2, "pixel below center must map lower than the mid pixel")
        XCTAssertLessThan(v2, v4, "pixel above center must map higher than the mid pixel")
        XCTAssertEqual(v0, 0, "the window's low endpoint must map to stored min (0)")
        XCTAssertEqual(v4, 65535, "the window's high endpoint must map to stored max (65535)")
        // Mid input sits at ~half the stored range.
        XCTAssertEqual(Double(v2), 65535.0 / 2.0, accuracy: 400,
                       "the window center input must map to ~mid stored range")
    }

    // Oracle: window bake resets the stored VOI window to the full range (Center/Width re-pointed).
    func testWindowLevelBakeResetsVOIWindow() throws {
        var file = makeU16Row([0, 500, 1000, 1500, 2000])
        var ds = file.dataSet
        ds.setString("1000", for: .windowCenter, vr: .DS)
        ds.setString("2000", for: .windowWidth, vr: .DS)
        file = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)

        let out = try run(file, [.windowLevel(center: 1000, width: 2000)])
        // Full stored range for 16-bit unsigned (slope 1, intercept 0): center 32767.5, width 65535.
        let centers = try XCTUnwrap(out.dataSet.decimalStrings(for: .windowCenter))
        let widths = try XCTUnwrap(out.dataSet.decimalStrings(for: .windowWidth))
        XCTAssertEqual(try XCTUnwrap(centers.first).value, 65535.0 / 2.0, accuracy: 1.0,
                       "baked window Center must re-point to the full-range midpoint")
        XCTAssertEqual(try XCTUnwrap(widths.first).value, 65535, accuracy: 1.0,
                       "baked window Width must re-point to the full stored span")
    }

    // MARK: - Multi-frame invert

    // Oracle: invert applies independently to every frame (16-bit unsigned complement per frame).
    func testMultiFrameInvertPerFrame() throws {
        // 3 frames, 2×2, frame f filled with values [100, 500, 1000].
        let fills: [UInt16] = [100, 500, 1000]
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
        ds.setUInt16(2, for: .rows)
        ds.setUInt16(2, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(16, for: .bitsStored)
        ds.setUInt16(15, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setString("3", for: .numberOfFrames, vr: .IS)
        let perFrame = 4
        var pixels = Data(count: perFrame * 3 * 2)
        for f in 0..<3 {
            for i in 0..<perFrame {
                let v = fills[f]
                let byte = (f * perFrame + i) * 2
                pixels[byte] = UInt8(v & 0xFF)
                pixels[byte + 1] = UInt8(v >> 8)
            }
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        let file = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")

        let out = try run(file, [.invert])
        let bytes = pixelBytes(out)
        for f in 0..<3 {
            let expected = UInt16(65535 - Int(fills[f]))
            for i in 0..<perFrame {
                let sampleIndex = f * perFrame + i
                XCTAssertEqual(readU16(bytes, at: sampleIndex), expected,
                               "frame \(f) sample \(i) must be 65535 - \(fills[f])")
            }
        }
    }

    // MARK: - Output structure

    // Oracle: pixedit output is a valid DICOM stream (128-byte preamble + 'DICM' at offset 128).
    func testOutputHasPreambleAndMagic() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let input = try file.write()
        let (out, _) = try editor.processData(input, operations: [.invert])
        XCTAssertGreaterThan(out.count, 132, "output must contain preamble + magic + data")
        let magic = out.subdata(in: 128..<132)
        XCTAssertEqual(magic, Data("DICM".utf8), "'DICM' magic must sit at offset 128")
    }

    // MARK: - Region parsing

    // Oracle: parseRegion parses "x,y,w,h"; invalid strings throw.
    func testParseRegionValidAndInvalid() throws {
        let r = try editor.parseRegion("10,20,30,40")
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 30); XCTAssertEqual(r.height, 40)

        XCTAssertThrowsError(try editor.parseRegion("1,2,3"),
                             "too few components must throw")
        XCTAssertThrowsError(try editor.parseRegion("1,2,0,4"),
                             "non-positive width must throw")
    }

    // MARK: - Error paths

    // Oracle: a mask region entirely outside image bounds throws regionOutOfBounds.
    func testMaskEntirelyOutOfBoundsThrows() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let input = try file.write()
        XCTAssertThrowsError(
            try editor.processData(input,
                operations: [.mask(x: 100, y: 100, width: 10, height: 10, fillValue: 0)])
        ) { error in
            XCTAssertTrue(error is PixelEditError, "must throw a PixelEditError")
        }
    }

    // MARK: - Compressed source (corpus)

    // Oracle: editing an encapsulated (J2K lossless) source decodes to native, uncompressed Explicit VR LE output.
    func testCompressedSourceDecodedToNative() throws {
        let f = try loadCorpus(.j2kLossless)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        let rows = file.dataSet.uint16(for: .rows)
        let cols = file.dataSet.uint16(for: .columns)

        let input = try file.write()
        let (out, info) = try editor.processData(input, operations: [.invert])
        let parsed = try DICOMFile.read(from: out)

        // Output transfer syntax must be uncompressed Explicit VR LE.
        XCTAssertEqual(parsed.transferSyntaxUID, TransferSyntax.explicitVRLittleEndian.uid,
                       "edited compressed source must be emitted as Explicit VR LE")
        // Native pixel data present, non-encapsulated, correctly sized.
        let bytes = pixelBytes(parsed)
        let expectedBytes = info.rows * info.columns * info.samplesPerPixel * (info.bitsAllocated / 8)
        XCTAssertEqual(bytes.count, expectedBytes,
                       "decoded native pixel data must be rows*cols*spp*bytesPerSample")
        // Dimensions preserved through an invert (no crop).
        XCTAssertEqual(UInt16(info.rows), rows)
        XCTAssertEqual(UInt16(info.columns), cols)
    }
}
