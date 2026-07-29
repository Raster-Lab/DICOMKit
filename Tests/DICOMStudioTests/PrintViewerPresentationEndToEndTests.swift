// PrintViewerPresentationEndToEndTests.swift
// DICOMStudioTests
//
// From the viewer's transforms to the bytes that go on film: marking a frame
// while zoomed and rotated must produce film pixels that are cropped and
// permuted accordingly — at source resolution, never resampled.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import DICOMNetwork
import Foundation

@MainActor
@Suite("Print Viewer Presentation End-to-End Tests")
struct PrintViewerPresentationEndToEndTests {

    private func fixturePath() throws -> String {
        try #require(CLIParityEngine.fixtureURL(named: "syn-ct.dcm")).path
    }

    // MARK: - Capture

    @Test("Marking captures the viewer's transforms")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkCapturesPresentation() throws {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/a.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.zoomLevel = 3.0
        viewModel.panOffsetX = 25
        viewModel.panOffsetY = -10
        viewModel.rotationAngle = 90
        viewModel.isFlippedHorizontal = true
        viewModel.isInverted = true

        let item = try #require(viewModel.currentSelectionItem)
        let presentation = try #require(item.presentation)

        #expect(presentation.zoom == 3.0)
        #expect(presentation.panX == 25)
        #expect(presentation.panY == -10)
        #expect(presentation.viewportWidth == 800)
        #expect(presentation.viewportHeight == 600)
        #expect(presentation.quarterTurns == 1)
        #expect(presentation.flipHorizontal)
        #expect(presentation.flipVertical == false)
        #expect(presentation.invert)
    }

    @Test("A mark is a snapshot — later viewer changes do not alter it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkIsASnapshot() throws {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/a.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.zoomLevel = 2.0

        viewModel.togglePrintMarkForCurrentFrame()

        // The user carries on exploring the series.
        viewModel.zoomLevel = 7.0
        viewModel.rotationAngle = 180

        let marked = try #require(viewModel.printSelection.items.first)
        #expect(marked.presentation?.zoom == 2.0)
        #expect(marked.presentation?.quarterTurns == 0)
    }

    @Test("Marking every frame carries the arrangement to each one")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAllFramesCarryPresentation() {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/cine.dcm"
        viewModel.numberOfFrames = 3
        viewModel.viewContentWidth = 500
        viewModel.viewContentHeight = 500
        viewModel.zoomLevel = 2.0
        viewModel.rotationAngle = 270

        #expect(viewModel.markAllFramesOfCurrentFileForPrint() == 3)
        #expect(viewModel.printSelection.items.allSatisfy {
            $0.presentation?.zoom == 2.0 && $0.presentation?.quarterTurns == 3
        })
    }

    // MARK: - Through the print path

    @Test("A zoomed, rotated mark prints cropped and rotated pixels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPreparedFilmPixelsAreTransformed() async throws {
        let path = try fixturePath()
        let service = PrintService()
        var request = PrintJobRequest()
        request.frameSelection = .single(1)

        let plain = PrintSelectionItem(filePath: path)
        let baseline = try await service.prepare(items: [plain], request: request)
        let source = try #require(baseline.first).descriptor

        // 2× zoom in a square viewport over a square image → the centre quarter,
        // then a quarter turn.
        let viewport = Double(max(source.columns, source.rows)) * 2
        let presentation = ViewerPresentation(
            zoom: 2.0,
            viewportWidth: viewport, viewportHeight: viewport,
            rotationDegrees: 90)
        let marked = PrintSelectionItem(filePath: path, presentation: presentation)

        let prepared = try await service.prepare(items: [marked], request: request)
        let film = try #require(prepared.first).descriptor

        #expect(film.columns < source.columns || film.rows < source.rows,
                "zooming must crop rather than print the whole frame")
        // A quarter turn: the cropped region's axes are swapped on film.
        let region = try #require(presentation.visibleRegion(
            imageWidth: Int(source.columns), imageHeight: Int(source.rows)))
        #expect(Int(film.columns) == region.height)
        #expect(Int(film.rows) == region.width)
        #expect(film.pixelData.count
                == Int(film.rows) * Int(film.columns) * Int(film.samplesPerPixel)
                   * Int(film.bitsAllocated) / 8)
    }

    @Test("Film pixels are the source's own — cropping never resamples")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCropKeepsSourcePixels() async throws {
        let path = try fixturePath()
        let service = PrintService()
        var request = PrintJobRequest()
        request.frameSelection = .single(1)

        let baseline = try await service.prepare(
            items: [PrintSelectionItem(filePath: path)], request: request)
        let source = try #require(baseline.first).descriptor

        let viewport = Double(max(source.columns, source.rows)) * 2
        let presentation = ViewerPresentation(
            zoom: 2.0, viewportWidth: viewport, viewportHeight: viewport)
        let prepared = try await service.prepare(
            items: [PrintSelectionItem(filePath: path, presentation: presentation)],
            request: request)
        let film = try #require(prepared.first).descriptor

        let region = try #require(presentation.visibleRegion(
            imageWidth: Int(source.columns), imageHeight: Int(source.rows)))
        let stride = Int(source.samplesPerPixel) * Int(source.bitsAllocated) / 8
        let sourceBytes = [UInt8](source.pixelData)
        let filmBytes = [UInt8](film.pixelData)

        // Compare the first cropped row byte for byte against the source.
        let sourceRowStart = (region.y * Int(source.columns) + region.x) * stride
        let rowBytes = region.width * stride
        #expect(Array(filmBytes[0..<rowBytes])
                == Array(sourceBytes[sourceRowStart..<(sourceRowStart + rowBytes)]))
    }

    @Test("Turning the setting off prints the untouched frame")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPresentationCanBeDisabled() async throws {
        let path = try fixturePath()
        let service = PrintService()
        var request = PrintJobRequest()
        request.frameSelection = .single(1)

        let presentation = ViewerPresentation(
            zoom: 4.0, viewportWidth: 1000, viewportHeight: 1000, rotationDegrees: 90)
        let item = PrintSelectionItem(filePath: path, presentation: presentation)

        let plain = try await service.prepare(
            items: [PrintSelectionItem(filePath: path)], request: request)
        let off = try await service.prepare(
            items: [item], request: request, applyViewerPresentation: false)

        let offDescriptor = try #require(off.first).descriptor
        let plainDescriptor = try #require(plain.first).descriptor
        #expect(offDescriptor == plainDescriptor)
    }

    @Test("Raw requests ignore the presentation — raw means stored pixels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRawIgnoresPresentation() async throws {
        let path = try fixturePath()
        let service = PrintService()
        var request = PrintJobRequest()
        request.frameSelection = .single(1)
        request.raw = true

        let presentation = ViewerPresentation(
            zoom: 4.0, viewportWidth: 1000, viewportHeight: 1000, rotationDegrees: 90)

        let plain = try await service.prepare(
            items: [PrintSelectionItem(filePath: path)], request: request)
        let marked = try await service.prepare(
            items: [PrintSelectionItem(filePath: path, presentation: presentation)],
            request: request)

        let markedDescriptor = try #require(marked.first).descriptor
        let plainDescriptor = try #require(plain.first).descriptor
        #expect(markedDescriptor == plainDescriptor)
    }
}
