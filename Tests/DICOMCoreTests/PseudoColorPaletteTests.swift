// PseudoColorPaletteTests.swift
// DICOMCoreTests
//
// The palettes are the one part of the print path whose *values* are the
// contract: "Hot Iron" has to be the standard's Hot Iron, not a lookalike, or
// naming it in the audit trail is a false claim. These tests hold the
// transcription to the spec at the points the spec is quotable, and hold every
// palette to the shape a 256-entry sRGB ramp must have.

import Testing
import Foundation
@testable import DICOMCore

@Suite("Pseudo-colour palettes")
struct PseudoColorPaletteTests {

    // MARK: Shape

    @Test("Every palette gives exactly 256 entries", arguments: PseudoColorPalette.allCases)
    func entryCount(_ palette: PseudoColorPalette) {
        #expect(palette.entries().count == PseudoColorPalette.entryCount)
    }

    @Test("Every palette fills a full LUT", arguments: PseudoColorPalette.allCases)
    func lutShape(_ palette: PseudoColorPalette) {
        let lut = palette.lut()
        #expect(lut.redLUT.count == 256)
        #expect(lut.greenLUT.count == 256)
        #expect(lut.blueLUT.count == 256)
        #expect(lut.redDescriptor.numberOfEntries == 256)
        #expect(lut.redDescriptor.firstMappedValue == 0)
        #expect(lut.redDescriptor.bitsPerEntry == 8)
    }

    /// The LUT stores 8-bit entries in the *high* byte, which is what
    /// `PaletteColorLUT.lookup` reads back. Getting this wrong is invisible in
    /// a unit that only counts entries and produces a black film.
    @Test("LUT entries survive a round trip through lookup",
          arguments: PseudoColorPalette.allCases)
    func lookupRoundTrip(_ palette: PseudoColorPalette) {
        let entries = palette.entries()
        let lut = palette.lut()
        for index in [0, 1, 64, 127, 128, 192, 254, 255] {
            let (r, g, b) = lut.lookup(index)
            #expect(r == entries[index].red)
            #expect(g == entries[index].green)
            #expect(b == entries[index].blue)
        }
    }

    // MARK: DICOM PS3.6 Annex B

    /// Spot values read from the standard's own tables. If a transcription ever
    /// drifts, these fail before a film does.
    @Test("Well-known palettes match PS3.6 Annex B at the quotable points")
    func wellKnownSpotValues() {
        func entry(_ palette: PseudoColorPalette, _ index: Int)
            -> (Int, Int, Int) {
            let e = palette.entries()[index]
            return (Int(e.red), Int(e.green), Int(e.blue))
        }

        #expect(entry(.hotIron, 0) == (0, 0, 0))
        #expect(entry(.hotIron, 64) == (128, 0, 0))
        #expect(entry(.hotIron, 128) == (255, 0, 0))
        #expect(entry(.hotIron, 192) == (255, 128, 4))
        #expect(entry(.hotIron, 255) == (255, 255, 255))

        #expect(entry(.pet, 0) == (0, 0, 0))
        #expect(entry(.pet, 64) == (1, 126, 127))
        #expect(entry(.pet, 128) == (128, 0, 255))
        #expect(entry(.pet, 192) == (255, 128, 0))
        #expect(entry(.pet, 255) == (255, 255, 255))

        #expect(entry(.hotMetalBlue, 0) == (0, 0, 0))
        #expect(entry(.hotMetalBlue, 64) == (0, 0, 125))
        #expect(entry(.hotMetalBlue, 128) == (116, 17, 97))
        #expect(entry(.hotMetalBlue, 192) == (255, 137, 65))
        #expect(entry(.hotMetalBlue, 255) == (255, 255, 255))

        #expect(entry(.petTwentyStep, 0) == (0, 0, 0))
        #expect(entry(.petTwentyStep, 64) == (96, 96, 176))
        #expect(entry(.petTwentyStep, 128) == (80, 192, 80))
        #expect(entry(.petTwentyStep, 192) == (208, 144, 0))
        #expect(entry(.petTwentyStep, 255) == (255, 255, 255))
    }

    /// The four segmented palettes are published as opcode streams and expanded
    /// at transcription time. Their endpoints are what the expansion has to get
    /// right: a stream decoded one entry short lands the ramp in the wrong place.
    @Test("Segmented palettes expand to the right endpoints")
    func segmentedEndpoints() {
        func first(_ palette: PseudoColorPalette) -> (Int, Int, Int) {
            let e = palette.entries()[0]
            return (Int(e.red), Int(e.green), Int(e.blue))
        }
        func last(_ palette: PseudoColorPalette) -> (Int, Int, Int) {
            let e = palette.entries()[255]
            return (Int(e.red), Int(e.green), Int(e.blue))
        }
        // Spring runs magenta to yellow.
        #expect(first(.spring) == (255, 0, 255))
        #expect(last(.spring) == (255, 255, 0))
        // Summer runs green to pale yellow-green.
        #expect(first(.summer) == (0, 255, 0))
        #expect(last(.summer) == (0, 128, 254))
        // Fall runs yellow to red.
        #expect(first(.fall) == (255, 255, 0))
        #expect(last(.fall) == (255, 0, 0))
        // Winter runs blue to pale cyan.
        #expect(first(.winter) == (0, 0, 255))
        #expect(last(.winter) == (127, 255, 128))
    }

    @Test("The eight standard palettes carry the standard's identity")
    func wellKnownIdentity() {
        let expected: [(PseudoColorPalette, String, String)] = [
            (.hotIron, "HOT_IRON", "1.2.840.10008.1.5.1"),
            (.pet, "PET", "1.2.840.10008.1.5.2"),
            (.hotMetalBlue, "HOT_METAL_BLUE", "1.2.840.10008.1.5.3"),
            (.petTwentyStep, "PET_20_STEP", "1.2.840.10008.1.5.4"),
            (.spring, "SPRING", "1.2.840.10008.1.5.5"),
            (.summer, "SUMMER", "1.2.840.10008.1.5.6"),
            (.fall, "FALL", "1.2.840.10008.1.5.7"),
            (.winter, "WINTER", "1.2.840.10008.1.5.8")
        ]
        for (palette, label, uid) in expected {
            #expect(palette.contentLabel == label)
            #expect(palette.wellKnownSOPInstanceUID == uid)
            // The stored form is the standard's label, so a saved job is
            // itself normative.
            #expect(palette.rawValue == label)
        }
    }

    /// Only the standard's palettes may claim a UID. One of ours carrying one
    /// would put a false normative identity in the audit trail.
    @Test("Palettes of our own claim no standard identity")
    func ownPalettesHaveNoUID() {
        for palette in PseudoColorPalette.allCases
        where palette.group != .dicomStandard {
            #expect(palette.wellKnownSOPInstanceUID == nil)
            #expect(palette.contentLabel == nil)
        }
    }

    // MARK: CC0 colormaps

    @Test("Perceptual colormaps match their published endpoints")
    func perceptualEndpoints() {
        // 0.267004, 0.004874, 0.329415 → 68, 1, 84
        let viridis = PseudoColorPalette.viridis.entries()
        #expect((Int(viridis[0].red), Int(viridis[0].green), Int(viridis[0].blue))
                == (68, 1, 84))
        // 0.993248, 0.906157, 0.143936 → 253, 231, 37
        #expect((Int(viridis[255].red), Int(viridis[255].green), Int(viridis[255].blue))
                == (253, 231, 37))

        // Inferno and magma genuinely share a near-black first entry and
        // diverge after it — this is the standard data, not a copy-paste slip.
        let inferno = PseudoColorPalette.inferno.entries()
        let magma = PseudoColorPalette.magma.entries()
        #expect(inferno[0].red == magma[0].red)
        #expect(inferno[0].green == magma[0].green)
        #expect(inferno[0].blue == magma[0].blue)
        #expect(inferno[200].red != magma[200].red
                || inferno[200].green != magma[200].green
                || inferno[200].blue != magma[200].blue)
    }

    // MARK: Grey

    @Test("Grayscale is the identity ramp")
    func grayscaleIdentity() {
        let entries = PseudoColorPalette.grayscale.entries()
        for index in 0..<256 {
            #expect(entries[index].red == UInt8(index))
            #expect(entries[index].green == UInt8(index))
            #expect(entries[index].blue == UInt8(index))
        }
    }

    @Test("Inverse grayscale is the identity ramp, reversed")
    func inverseGrayscale() {
        let entries = PseudoColorPalette.inverseGrayscale.entries()
        for index in 0..<256 {
            #expect(entries[index].red == UInt8(255 - index))
        }
    }

    /// The print path asks exactly this to decide whether a film has to widen
    /// to RGB — and widening costs it deep-grayscale bit depth and the density
    /// curve. Only the two grey ramps may answer yes.
    @Test("Only the grey ramps report themselves grey")
    func grayscaleClassification() {
        for palette in PseudoColorPalette.allCases {
            let isGrey = palette == .grayscale || palette == .inverseGrayscale
            #expect(palette.isGrayscale == isGrey)
        }
    }

    /// A palette that claims colour must actually produce some, or the print
    /// path pays for RGB and gets a grey film.
    @Test("Colour palettes actually produce colour",
          arguments: PseudoColorPalette.allCases.filter { !$0.isGrayscale })
    func colourPalettesAreColoured(_ palette: PseudoColorPalette) {
        let entries = palette.entries()
        #expect(entries.contains { $0.red != $0.green || $0.green != $0.blue })
    }

    // MARK: Catalogue

    /// The picker is built from the catalogue, so anything missing from it is
    /// unreachable in the UI and anything listed twice is a duplicate entry.
    @Test("The catalogue lists every palette exactly once")
    func catalogueIsComplete() {
        let listed = PseudoColorPalette.catalog.flatMap(\.palettes)
        #expect(Set(listed).count == listed.count)
        #expect(Set(listed) == Set(PseudoColorPalette.allCases))
    }

    @Test("Every palette is filed under the group it is listed in")
    func catalogueGroupsAgree() {
        for (group, palettes) in PseudoColorPalette.catalog {
            for palette in palettes {
                #expect(palette.group == group)
            }
        }
    }

    @Test("Display names are distinct and non-empty")
    func displayNames() {
        let names = PseudoColorPalette.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(!names.contains { $0.isEmpty })
    }
}
