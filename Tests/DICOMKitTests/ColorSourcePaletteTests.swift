// ColorSourcePaletteTests.swift
// DICOMKitTests
//
// A pseudo-colour palette used to reach only monochrome frames, so choosing one
// for an ultrasound did nothing at all. These cover the other two doors — RGB /
// YBR and PALETTE COLOR — and the promise that comes with them: the palette
// recolours the *output* and never the source pixels.

import Testing
import Foundation
import DICOMCore
@testable import DICOMKit

@Suite("Palette over colour sources")
struct ColorSourcePaletteTests {

    /// Mid-grey RGB: every channel equal, so luminance is the channel value
    /// whatever the Rec.601 weights are.
    private func greyRGB(_ value: UInt8, pixels: Int) -> Data {
        Data(repeating: value, count: pixels * 3)
    }

    /// An RGB fixture: the data set the preprocessor reads metadata from, and
    /// the `PixelData` it reads samples from.
    private func rgbFixture(_ source: Data) -> (DataSet, PixelData) {
        var dataSet = DataSet()
        dataSet.setUInt16(2, for: .rows)
        dataSet.setUInt16(2, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(3, for: .samplesPerPixel)
        dataSet.setString("RGB", for: .photometricInterpretation, vr: .CS)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: source)

        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3, photometricInterpretation: .rgb)
        return (dataSet, PixelData(data: source, descriptor: descriptor))
    }

    // MARK: The scalar a colour frame is indexed by

    /// Rec.601 luminance, the same coefficients the grayscale conversion uses —
    /// so a palettised colour frame and a grey one agree about which pixels are
    /// bright.
    @Test("Pure channels index by Rec.601 luminance, not by channel order")
    func luminanceWeighting() throws {
        // One red, one green, one blue pixel.
        let rgb = Data([255, 0, 0, 0, 255, 0, 0, 0, 255])
        let out = try ImagePreprocessor.colorizeRGB(
            rgb, palette: .grayscale, width: 3, height: 1)
        // Grayscale palette returns the level itself, so the output reads back
        // the luminance each pixel was reduced to.
        let r = out.pixelData[0], g = out.pixelData[3], b = out.pixelData[6]
        #expect(g > r)   // 0.587 > 0.299
        #expect(r > b)   // 0.299 > 0.114
    }

    @Test("A colour frame comes back as 8-bit RGB")
    func colourFrameShape() throws {
        let out = try ImagePreprocessor.colorizeRGB(
            greyRGB(128, pixels: 4), palette: .hotIron, width: 2, height: 2)
        #expect(out.photometricInterpretation == "RGB")
        #expect(out.samplesPerPixel == 3)
        #expect(out.bitsAllocated == 8)
        #expect(out.bitsStored == 8)
        #expect(out.pixelData.count == 4 * 3)
    }

    /// The palette must actually change the pixels — a silent pass-through is
    /// exactly the bug this work exists to fix.
    @Test("A colour palette recolours a grey RGB frame")
    func paletteRecolours() throws {
        let source = greyRGB(128, pixels: 4)
        let out = try ImagePreprocessor.colorizeRGB(
            source, palette: .hotIron, width: 2, height: 2)
        #expect(out.pixelData != source)
        // Hot-iron at mid level is warm: red leads blue.
        #expect(out.pixelData[0] > out.pixelData[2])
    }

    // MARK: The non-destructive promise

    /// The source buffer is read, never written. `Data` is a value type, but the
    /// helper takes it and returns a *new* buffer rather than mutating in place,
    /// and this is the test that keeps it that way.
    @Test("Colourising leaves the source pixels untouched")
    func sourceIsNotMutated() throws {
        let source = greyRGB(200, pixels: 16)
        let before = Array(source)
        _ = try ImagePreprocessor.colorizeRGB(
            source, palette: .rainbow, width: 4, height: 4)
        #expect(Array(source) == before)
    }

    // MARK: Truncated input

    @Test("A short frame is rejected rather than read past its end")
    func shortFrameThrows() {
        #expect(throws: ImagePreprocessingError.self) {
            // Four pixels claimed, three pixels' worth of bytes supplied.
            _ = try ImagePreprocessor.colorizeRGB(
                Data(repeating: 0, count: 9), palette: .hotIron, width: 2, height: 2)
        }
    }

    // MARK: Grayscale printers

    /// A palette makes RGB, and a grayscale film still cannot take it. The
    /// reduction has to work off the *prepared* frame, not the source
    /// descriptor — a PALETTE COLOR source carries one sample per pixel on disk
    /// and three by this point, and driving it from the source would reject it.
    @Test("A palettised frame flattens to MONOCHROME2 for a grey film")
    func flattenForGreyFilm() throws {
        let colorized = try ImagePreprocessor.colorizeRGB(
            greyRGB(128, pixels: 4), palette: .hotIron, width: 2, height: 2)
        let grey = try ImagePreprocessor.flattenToGrayscale(colorized)
        #expect(grey.photometricInterpretation == "MONOCHROME2")
        #expect(grey.samplesPerPixel == 1)
        #expect(grey.pixelData.count == 4)
    }

    // MARK: End to end, through the preprocessor

    /// The whole point: an RGB source — an ultrasound, say — now honours a
    /// chosen palette instead of ignoring it.
    @Test("An RGB source honours a chosen palette end to end")
    func rgbSourceHonoursPalette() async throws {
        let source = greyRGB(128, pixels: 4)
        let (dataSet, pixelData) = rgbFixture(source)

        let preprocessor = ImagePreprocessor()
        let plain = try await preprocessor.prepareForPrint(
            pixelData: pixelData, dataSet: dataSet, colorMode: .color)
        let palettised = try await preprocessor.prepareForPrint(
            pixelData: pixelData, dataSet: dataSet, colorMode: .color,
            palette: .hotIron)

        #expect(palettised.photometricInterpretation == "RGB")
        #expect(palettised.pixelData != plain.pixelData)
        // And the source frame is still exactly what it was: the palette built
        // a new buffer rather than recolouring the pixels in place.
        #expect(pixelData.data == source)
    }

    /// Grey palettes add no colour, so a colour source must be left exactly as
    /// the ordinary colour path would have prepared it.
    @Test("A grey palette leaves a colour source on its normal path")
    func greyPaletteIsInert() async throws {
        let (dataSet, pixelData) = rgbFixture(greyRGB(128, pixels: 4))

        let preprocessor = ImagePreprocessor()
        let plain = try await preprocessor.prepareForPrint(
            pixelData: pixelData, dataSet: dataSet, colorMode: .color)
        let greyPalette = try await preprocessor.prepareForPrint(
            pixelData: pixelData, dataSet: dataSet, colorMode: .color,
            palette: .grayscale)
        #expect(greyPalette.pixelData == plain.pixelData)
    }
}
