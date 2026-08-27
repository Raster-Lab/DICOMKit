// ViewerPaletteTests.swift
// DICOMStudioTests
//
// The viewer's pseudo-colour palette: choosing one, where it travels, and where
// it deliberately does not.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Viewer Palette Tests")
struct ViewerPaletteTests {

    private func monochromeViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/a.dcm"
        viewModel.samplesPerPixel = 1
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 800
        return viewModel
    }

    private func studyViewModel() -> ImageViewerViewModel {
        let viewModel = monochromeViewModel()
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "s1", title: "PET", seriesNumber: 1,
                              filePaths: ["/s1-a.dcm", "/s1-b.dcm", "/s1-c.dcm"],
                              frameCount: 3),
            ViewerSeriesEntry(seriesInstanceUID: "s2", title: "CT", seriesNumber: 2,
                              filePaths: ["/s2-a.dcm", "/s2-b.dcm"], frameCount: 2)
        ], studyUID: "1.2")
        return viewModel
    }

    // MARK: - Choosing

    @Test("The viewer starts with no palette, which is not the same as grey")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultIsNoChoice() {
        let viewModel = monochromeViewModel()
        #expect(viewModel.palette == nil)
        #expect(viewModel.isPseudoColored == false)
    }

    @Test("Choosing a palette colours the image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyPalette() {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.hotIron)

        #expect(viewModel.palette == .hotIron)
        #expect(viewModel.isPseudoColored)
    }

    @Test("Choosing None takes the colour off again")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearPalette() {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.viridis)
        viewModel.applyPalette(nil)

        #expect(viewModel.palette == nil)
        #expect(viewModel.isPseudoColored == false)
    }

    @Test("Grey chosen on purpose is a choice, but it is not a colouring")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGrayscaleIsAChoiceWithoutColour() {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.grayscale)

        // Recorded — a film-wide palette must not overwrite a deliberate grey…
        #expect(viewModel.palette == .grayscale)
        // …but nothing on screen is coloured by it.
        #expect(viewModel.isPseudoColored == false)
    }

    @Test("A colour image takes a palette too, over its luminance")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testColourImageTakesPalette() {
        let viewModel = monochromeViewModel()
        viewModel.samplesPerPixel = 3
        viewModel.applyPalette(.hotIron)

        // The renderer no longer discards a ramp for a frame that carries its
        // own colours — it applies it to that frame's luminance — so the
        // toolbar showing the ramp is showing what was actually drawn. See
        // `FrameRenderRequest.readerPalette`.
        #expect(viewModel.isPseudoColored)
    }

    // MARK: - Travelling to the film

    @Test("The palette goes onto the film with the mark")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteReachesThePrintMark() throws {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.pet)
        viewModel.togglePrintMarkForCurrentFrame()

        let item = try #require(viewModel.printSelection.items.first)
        #expect(item.presentation?.palette == .pet)
    }

    @Test("Recolouring after marking keeps the film in step with the screen")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRecolouringUpdatesExistingMark() throws {
        let viewModel = monochromeViewModel()
        viewModel.togglePrintMarkForCurrentFrame()
        #expect(viewModel.printSelection.items.first?.presentation?.palette == nil)

        viewModel.applyPalette(.inferno)

        let item = try #require(viewModel.printSelection.items.first)
        #expect(item.presentation?.palette == .inferno)
        #expect(viewModel.printSelection.count == 1, "recolouring marks nothing new")
    }

    // MARK: - Per tile

    @Test("A tile's palette is its own — colouring one does not tint its neighbour")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteIsPerTile() {
        let viewModel = studyViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        // Colour the focused tile.
        viewModel.applyPalette(.hotIron)
        #expect(viewModel.cells[0].palette == .hotIron)
        #expect(viewModel.cells[1].palette == nil)
    }

    @Test("A tile keeps its colour when focus moves away and back")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteSurvivesFocusChange() {
        let viewModel = studyViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.applyPalette(.magma)

        viewModel.focusCell(1)
        // The incoming tile has none of its own, so the live viewer shows none —
        // the previous tile's colour must not follow the reader across a hang.
        #expect(viewModel.palette == nil)

        viewModel.focusCell(0)
        #expect(viewModel.palette == .magma)
        #expect(viewModel.cells[0].palette == .magma)
    }

    @Test("A tile's palette reaches the film cell it becomes")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTilePaletteReachesItsFilmCell() throws {
        let viewModel = studyViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.applyPalette(.plasma)
        viewModel.markLayoutForPrint()

        let items = viewModel.printSelection.items
        #expect(items.count == 2)
        #expect(items[0].presentation?.palette == .plasma)
        #expect(items[1].presentation?.palette == nil)
    }

    @Test("A new tile takes the colour only within the series it came from")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteTravelsOnlyWithinItsSeries() {
        let viewModel = studyViewModel()
        // Hang s1 the way a load leaves it, without touching the disk: the test
        // is about where the colour travels, not about loading a file.
        viewModel.seriesFiles = ["/s1-a.dcm", "/s1-b.dcm", "/s1-c.dcm"]
        viewModel.currentFileIndex = 0
        viewModel.filePath = "/s1-a.dcm"
        viewModel.currentSeriesUID = "s1"
        viewModel.applyPalette(.hotIron)

        // An image grid stays inside s1, so the colour continues with the stack.
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 3), fill: .image)
        #expect(viewModel.cells.allSatisfy { $0.palette == .hotIron })
    }

    @Test("A series-led grid does not paint one series' colour onto another")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteDoesNotCrossSeries() {
        let viewModel = studyViewModel()
        viewModel.seriesFiles = ["/s1-a.dcm", "/s1-b.dcm", "/s1-c.dcm"]
        viewModel.currentFileIndex = 0
        viewModel.filePath = "/s1-a.dcm"
        viewModel.currentSeriesUID = "s1"
        viewModel.applyPalette(.hotIron)
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2), fill: .series)

        // The PET keeps its ramp; the CT beside it is not tinted by a palette
        // chosen against a different set of measurements.
        #expect(viewModel.cells[0].palette == .hotIron)
        #expect(viewModel.cells[1].palette == nil)
    }

    // MARK: - Resetting

    @Test("Reset View takes the colour off with the rest of the arrangement")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetViewClearsPalette() {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.jet)
        viewModel.resetView()

        #expect(viewModel.palette == nil)
    }

    @Test("The default view is the file's own picture, which carries no palette")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultViewClearsPalette() {
        let viewModel = monochromeViewModel()
        viewModel.applyPalette(.rainbow)
        viewModel.applyDefaultView()

        #expect(viewModel.palette == nil)
    }

    // MARK: - When the control is on offer

    @Test("A monochrome ultrasound that never stated its sample count can still be coloured")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMonochromeUltrasoundOffersPalette() {
        // The shape behind "the palette is dead on US": a multi-frame study
        // whose Samples per Pixel sits in the per-frame functional groups, so
        // the top of the dataset answers nothing and the count falls back to 1.
        // Photometric Interpretation is the tag that actually settles it.
        let viewModel = monochromeViewModel()
        viewModel.photometricInterpretation = "MONOCHROME2"

        #expect(viewModel.carriesOwnColor == false)

        viewModel.applyPalette(.hotIron)
        #expect(viewModel.isPseudoColored)
    }

    @Test("An RGB ultrasound carries its own colours and still takes a ramp")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testColorUltrasoundTakesPalette() {
        let viewModel = monochromeViewModel()
        viewModel.photometricInterpretation = "RGB"
        viewModel.samplesPerPixel = 3

        // Still true, and still worth knowing — it is what decides *how* the
        // ramp is applied. It no longer decides *whether* it is.
        #expect(viewModel.carriesOwnColor)

        viewModel.applyPalette(.hotIron)
        #expect(viewModel.isPseudoColored,
                "a ramp over a colour frame recolours its luminance, so the toolbar must say so")
    }

    @Test("A PALETTE COLOR image is colour despite storing one sample per pixel")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaletteColorCarriesOwnColor() {
        // One sample per pixel, and colour all the same: the samples index the
        // image's own LUT. A sample count alone would call this grey and offer
        // a second palette on top of the one it already has.
        let viewModel = monochromeViewModel()
        viewModel.photometricInterpretation = "PALETTE COLOR"
        viewModel.samplesPerPixel = 1

        #expect(viewModel.carriesOwnColor)
    }

    @Test("An unrecognised photometric interpretation falls back to the sample count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUnknownPhotometricFallsBackToSampleCount() {
        let viewModel = monochromeViewModel()
        viewModel.photometricInterpretation = ""
        viewModel.samplesPerPixel = 3
        #expect(viewModel.carriesOwnColor)

        viewModel.samplesPerPixel = 1
        #expect(viewModel.carriesOwnColor == false)
    }

    // MARK: - The swatch

    @Test("Every offered palette draws a ramp with more than one colour in it")
    func testEveryPaletteHasARamp() {
        for palette in DICOMCore.PseudoColorPalette.allCases {
            let stops = PaletteRampSwatch.stops(for: palette)
            #expect(stops.count > 1, "\(palette.displayName) has no ramp to draw")
        }
    }

    @Test("The catalogue the viewer offers is the one the film offers")
    func testCatalogueIsShared() {
        let offered = DICOMCore.PseudoColorPalette.catalog.flatMap(\.palettes)
        #expect(Set(offered) == Set(DICOMCore.PseudoColorPalette.allCases),
                "a palette missing from the catalogue can be printed but not chosen")
    }
}


// MARK: - The toolbar face

@Suite("Viewer Palette Toolbar Face Tests")
struct ViewerPaletteToolbarFaceTests {

    @Test("A chosen palette is named on the toolbar")
    func testChosenPaletteIsNamed() {
        // The name is the point of the change: the face showed a ramp and no
        // word, so "Hot Metal Blue" and "Hot Iron" — two names that sound
        // alike and look nothing alike — were told apart by gradient alone.
        #expect(ViewerPalettePickerView.faceText(for: .hotIron) == "Hot Iron")
        #expect(ViewerPalettePickerView.faceText(for: .hotMetalBlue) == "Hot Metal Blue")
        #expect(ViewerPalettePickerView.faceText(for: .petTwentyStep) == "PET 20 Step")
    }

    @Test("No palette says so rather than showing a bare glyph")
    func testNoPaletteIsNamed() {
        // A bare paintpalette glyph says "there is a palette control here",
        // not "and it is off" — which is what a reader who has coloured an
        // image by accident is looking for.
        #expect(ViewerPalettePickerView.faceText(for: nil) == "No CLUT")
        #expect(ViewerPalettePickerView.noPaletteLabel == "No CLUT")
    }

    @Test("A grey palette is still named — it is a choice, not the absence of one")
    @MainActor
    func testGreyPalettesAreNamed() {
        // Grayscale and Inverse Grayscale leave the frame grey but are chosen
        // CLUTs all the same, and the toolbar must not report them as "No
        // CLUT": the reader picked something, clearing it is a separate action
        // with a separate result, and the menu standing open beside the face
        // puts its checkmark on the row they picked.
        #expect(ViewerPalettePickerView.faceText(for: .grayscale) == "Grayscale")
        #expect(ViewerPalettePickerView.faceText(for: .inverseGrayscale)
                == "Inverse Grayscale")

        // The distinction the face rests on: a grey palette is chosen
        // (`palette` is set) but colours nothing (`isPseudoColored` is false),
        // so the name comes from the first and the ramp from the second.
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/a.dcm"
        viewModel.samplesPerPixel = 1
        viewModel.applyPalette(.grayscale)
        #expect(viewModel.palette == .grayscale)
        #expect(!viewModel.isPseudoColored)

        viewModel.applyPalette(.hotIron)
        #expect(viewModel.isPseudoColored)

        viewModel.applyPalette(nil)
        #expect(viewModel.palette == nil)
        #expect(!viewModel.isPseudoColored)
        #expect(ViewerPalettePickerView.faceText(for: viewModel.palette) == "No CLUT")
    }

    @Test("Every catalogue name fits the toolbar face whole")
    func everyCatalogueNameFitsTheToolbarFace() {
        // The cap exists for a name longer than anything shipped. If a new
        // palette pushes past it, this fails here rather than quietly putting
        // an ellipsis on the toolbar where the reader would read a truncated
        // name and quote it into a report.
        for entry in DICOMCore.PseudoColorPalette.catalog {
            for palette in entry.palettes {
                let face = ViewerPalettePickerView.faceText(for: palette)
                #expect(face == palette.displayName,
                        "\(palette.displayName) does not fit the toolbar face")
                #expect(!face.contains("…"))
            }
        }
    }

    @Test("The cap is the width the face is allowed, ellipsis included")
    func testCapIsTheFaceWidth() {
        // No catalogue palette exercises the shortening, so what is pinned
        // here is the contract the cap has to keep: the face never exceeds it.
        // Checked against every palette rather than a synthetic string, because
        // a synthetic one would only re-implement the arithmetic and prove
        // nothing about `faceText`.
        for entry in DICOMCore.PseudoColorPalette.catalog {
            for palette in entry.palettes {
                #expect(ViewerPalettePickerView.faceText(for: palette).count
                        <= ViewerPalettePickerView.nameCap)
            }
        }
        #expect(ViewerPalettePickerView.noPaletteLabel.count
                <= ViewerPalettePickerView.nameCap)
    }
}
