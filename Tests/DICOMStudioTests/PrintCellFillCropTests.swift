// PrintCellFillCropTests.swift
// DICOMStudioTests
//
// SRS FR-003, fill-to-film in the live preview: the fill is composed into the
// shader's *source region*, never into the view's size — the cell's Metal view
// must keep one size through every tool drag, because a drawable that resizes
// per mouse delta is the cost the GPU cell path exists to remove.

import Testing
@testable import DICOMStudio
import DICOMRenderKit
import Foundation

#if canImport(Metal)
@Suite("Print Cell Fill Crop Tests")
struct PrintCellFillCropTests {

    private func region(_ x: Double, _ y: Double, _ w: Double, _ h: Double)
        -> DisplayPresentation.SourceRegion {
        DisplayPresentation.SourceRegion(x: x, y: y, width: w, height: h)
    }

    @Test("A wide region is narrowed to the cell's aspect, centred")
    func testWideRegionNarrows() {
        let cropped = PrintCellDisplay.fillCrop(
            of: region(0, 0, 400, 100), cellAspect: 1, quarterTurns: 0)
        #expect(cropped.width == 100)
        #expect(cropped.height == 100)
        #expect(cropped.x == 150, "centred: (400 − 100) / 2")
        #expect(cropped.y == 0)
    }

    @Test("A tall region is shortened to the cell's aspect, centred")
    func testTallRegionShortens() {
        let cropped = PrintCellDisplay.fillCrop(
            of: region(10, 20, 100, 400), cellAspect: 2, quarterTurns: 0)
        #expect(cropped.width == 100)
        #expect(cropped.height == 50)
        #expect(cropped.x == 10)
        #expect(cropped.y == 20 + 175)
    }

    @Test("A region already at the cell's aspect is untouched")
    func testMatchingAspect() {
        let source = region(5, 7, 200, 100)
        let cropped = PrintCellDisplay.fillCrop(
            of: source, cellAspect: 2, quarterTurns: 0)
        #expect(cropped == source)
    }

    @Test("A quarter turn swaps the aspect the cell is matched against")
    func testQuarterTurnSwapsTarget() {
        // Turned on its side, a 400×100 region shows as 100×400 — to fill a
        // square cell the *unturned* crop must still be square.
        let cropped = PrintCellDisplay.fillCrop(
            of: region(0, 0, 400, 100), cellAspect: 1, quarterTurns: 1)
        #expect(cropped.width == 100)
        #expect(cropped.height == 100)

        // And a 2:1 cell wants a 1:2 unturned region.
        let wide = PrintCellDisplay.fillCrop(
            of: region(0, 0, 400, 400), cellAspect: 2, quarterTurns: 3)
        #expect(wide.width == 200)
        #expect(wide.height == 400)
    }

    @Test("Degenerate inputs pass through unchanged")
    func testDegenerate() {
        let empty = region(0, 0, 0, 100)
        #expect(PrintCellDisplay.fillCrop(of: empty, cellAspect: 1, quarterTurns: 0) == empty)
        let source = region(0, 0, 100, 100)
        #expect(PrintCellDisplay.fillCrop(of: source, cellAspect: 0, quarterTurns: 0) == source)
    }

    @Test("The presentation composes the fill crop and asks for smooth sampling")
    func testPresentationComposition() {
        let item = PrintSelectionItem(filePath: "/x.dcm", frameIndex: 0)
        let filled = PrintCellDisplay.presentation(
            for: item, imageWidth: 512, imageHeight: 512,
            fillingCellOfSize: CGSize(width: 200, height: 100))
        #expect(filled.sourceRegion == region(0, 128, 512, 256))
        #expect(filled.linearFiltering)

        // Without a cell to fill, the whole frame — exactly as before.
        let fitted = PrintCellDisplay.presentation(
            for: item, imageWidth: 512, imageHeight: 512)
        #expect(fitted.sourceRegion == region(0, 0, 512, 512))
    }
}
#endif
