// PrintFillPanTests.swift
// DICOMStudioTests
//
// Panning a fill-scaled film cell — end to end, model to shader.
//
// The regression this pins down was subtle because it lived *between* layers:
// the model accepted and stored the pan (its clamp knew the covering geometry),
// but the render path re-read the visible region with the fitted geometry,
// which answered "the whole image", and the fill crop then re-centred it. The
// pan survived in the mark and moved nothing on screen or on film. So these
// tests assert on what the shader and the print transform are actually given,
// not on the stored value.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

@MainActor
@Suite("Print Fill Pan Tests")
struct PrintFillPanTests {

    /// One mark, in a view model set to fill-to-film.
    private func makeViewModel() -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0))
        let viewModel = PrintViewModel(selection: selection)
        viewModel.scalingMode = .fillToFilm
        return viewModel
    }

    /// A 1000×500 frame filling a square 300-point cell covers it at scale 0.6:
    /// a 500×500 crop, 250 source pixels hidden either side.
    private let cell = CGSize(width: 300, height: 300)
    private let pixels = CGSize(width: 1000, height: 500)

    @Test("The shader is given the panned crop, not the centred one")
    func testShaderRegionFollowsThePan() {
        let viewModel = makeViewModel()

        // 100 view points at cover scale 0.6 is 166⅔ source pixels: the crop's
        // centre moves from 500 to 333⅓, so its left edge lands at 83.
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 100, dy: 0,
                          cellSize: cell, pixelSize: pixels)

        let display = PrintCellDisplay.presentation(
            for: viewModel.selection.items[0],
            imageWidth: 1000, imageHeight: 500,
            fillingCellOfSize: cell)

        let region = try! #require(display.sourceRegion)
        #expect(abs(region.x - 83) <= 1, "the crop slid with the drag")
        #expect(abs(region.width - 500) <= 1, "the crop is the same size wherever it sits")
        #expect(region.y == 0)
        #expect(abs(region.height - 500) <= 1)
    }

    @Test("Unpanned, the fill crop is centred — exactly as before")
    func testUnpannedCropIsCentred() {
        let viewModel = makeViewModel()

        let display = PrintCellDisplay.presentation(
            for: viewModel.selection.items[0],
            imageWidth: 1000, imageHeight: 500,
            fillingCellOfSize: cell)

        let region = try! #require(display.sourceRegion)
        #expect(abs(region.x - 250) <= 1)
        #expect(abs(region.width - 500) <= 1)
    }

    @Test("The print transform crops the same panned region the preview shows")
    func testPrintedCropMatchesThePreview() {
        let viewModel = makeViewModel()
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 100, dy: 0,
                          cellSize: cell, pixelSize: pixels)
        let presentation = try! #require(viewModel.selection.items[0].presentation)

        // What the film's pixel path crops (PrintPresentationTransform reads
        // this same call with the job's scaling) versus what the shader shows.
        let printed = try! #require(presentation.visibleRegion(
            imageWidth: 1000, imageHeight: 500, covers: true))
        let shown = try! #require(PrintCellDisplay.presentation(
            for: viewModel.selection.items[0],
            imageWidth: 1000, imageHeight: 500,
            fillingCellOfSize: cell).sourceRegion)

        #expect(abs(Double(printed.x) - shown.x) <= 1)
        #expect(abs(Double(printed.width) - shown.width) <= 1)
    }

    @Test("The pan stops when the crop reaches the image's edge")
    func testPanStopsAtTheEdge() {
        let viewModel = makeViewModel()

        // Far past the 150 view points of travel that exist.
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 5000, dy: 0,
                          cellSize: cell, pixelSize: pixels)

        let region = try! #require(PrintCellDisplay.presentation(
            for: viewModel.selection.items[0],
            imageWidth: 1000, imageHeight: 500,
            fillingCellOfSize: cell).sourceRegion)
        #expect(region.x == 0, "the crop stops at the edge instead of leaving the image")
        #expect(abs(region.width - 500) <= 1, "and is still a full cell's worth of pixels")
    }

    @Test("A fitted cell still reads its region with the fitted geometry")
    func testFittedRegionIsUnchanged() {
        let viewModel = makeViewModel()
        viewModel.scalingMode = .fitToFilm
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 100, dy: 0,
                          cellSize: cell, pixelSize: pixels)

        // Fitted at zoom 1, the whole image is on the film: no region, no pan.
        let display = PrintCellDisplay.presentation(
            for: viewModel.selection.items[0],
            imageWidth: 1000, imageHeight: 500)
        let region = display.sourceRegion
        #expect(region == nil || (region!.x == 0 && Int(region!.width) == 1000),
                "nothing is hidden, so nothing slides")
    }
}
#endif
