// PrintCellTextureCacheTests.swift
// DICOMStudioTests
//
// The film preview draws its cells from GPU textures, because the preview is
// where the tools are used: window/level, zoom, pan, rotate and invert all run as
// drags over a cell, and each of them used to re-render that cell on the CPU.
//
// Two claims carry the whole path, and both are testable. First, a cell's texture
// is keyed on its *pixels* — file, frame, window — and never on its arrangement,
// so a zoom or a rotation re-draws a quad and renders nothing. Second, the
// geometry handed to the shader is the *film's*, resolved through the same
// `visibleRegion` the print path uses, so a cell that looks right still prints
// that way. The fallbacks have to survive both.

import Testing
@testable import DICOMStudio
import Foundation
import DICOMCore
import DICOMKit
import DICOMPrintKit

#if canImport(Metal)
import Metal
import DICOMRenderKit

@Suite("Print Cell Texture Cache Tests")
@MainActor
struct PrintCellTextureCacheTests {

    // MARK: - Fixtures

    /// A flat MONOCHROME2 frame, optionally carrying a 1-bit overlay plane.
    private func uniformFile(
        value: UInt16, rows: Int = 32, columns: Int = 32,
        frames: Int = 1, overlay: Bool = false
    ) throws -> Data {
        var elements: [DataElement] = []
        elements.append(.uint16(tag: .rows, value: UInt16(rows)))
        elements.append(.uint16(tag: .columns, value: UInt16(columns)))
        if frames > 1 {
            elements.append(.string(tag: .numberOfFrames, vr: .IS, value: "\(frames)"))
        }
        elements.append(.uint16(tag: .bitsAllocated, value: 16))
        elements.append(.uint16(tag: .bitsStored, value: 16))
        elements.append(.uint16(tag: .highBit, value: 15))
        elements.append(.uint16(tag: .pixelRepresentation, value: 0))
        elements.append(.uint16(tag: .samplesPerPixel, value: 1))
        elements.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        elements.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"))
        elements.append(.string(tag: .sopInstanceUID, vr: .UI,
                                value: "1.2.3.4.5.77.\(value).\(frames)"))

        if overlay {
            elements.append(DataElement(tag: Tag(group: 0x6000, element: 0x0010),
                                        vr: .US, length: 2,
                                        valueData: Data([UInt8(rows & 0xFF), UInt8(rows >> 8)])))
            elements.append(DataElement(tag: Tag(group: 0x6000, element: 0x0011),
                                        vr: .US, length: 2,
                                        valueData: Data([UInt8(columns & 0xFF), UInt8(columns >> 8)])))
            elements.append(.string(tag: Tag(group: 0x6000, element: 0x0040),
                                    vr: .CS, value: "G"))
            elements.append(.uint16(tag: Tag(group: 0x6000, element: 0x0100), value: 1))
            elements.append(.uint16(tag: Tag(group: 0x6000, element: 0x0102), value: 0))
            elements.append(DataElement(tag: Tag(group: 0x6000, element: 0x0050),
                                        vr: .SS, length: 4,
                                        valueData: Data([1, 0, 1, 0])))
            let overlayBytes = Data(repeating: 0xFF, count: (rows * columns + 7) / 8)
            elements.append(DataElement(tag: Tag(group: 0x6000, element: 0x3000),
                                        vr: .OW, length: UInt32(overlayBytes.count),
                                        valueData: overlayBytes))
        }

        var pixels = Data(count: rows * columns * 2 * frames)
        pixels.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for frame in 0..<frames {
                for i in 0..<(rows * columns) {
                    out[frame * rows * columns + i] = value &+ UInt16(frame &* 5000)
                }
            }
        }
        elements.append(DataElement(tag: .pixelData, vr: .OW,
                                    length: UInt32(pixels.count), valueData: pixels))

        return try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintCellTexture-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    private func mark(
        path: String, frameIndex: Int = 0,
        windowCenter: Double? = 32768, windowWidth: Double? = 65536,
        windowSpace: PrintWindowSpace = .storedValues,
        presentation: ViewerPresentation? = nil
    ) -> PrintSelectionItem {
        PrintSelectionItem(
            filePath: path, frameIndex: frameIndex,
            windowCenter: windowCenter, windowWidth: windowWidth,
            windowSpace: windowSpace, presentation: presentation)
    }

    /// Renders the given marks and waits for the cache to settle — texture
    /// production is a detached decode plus a dispatch, so asserting immediately
    /// would only ever see the pending state.
    private func settle(
        _ cache: PrintCellTextureCache, for items: [PrintSelectionItem]
    ) async {
        cache.refresh(for: items)
        for _ in 0..<200 {
            // `renderedTexture`, not `texture`: the stand-in would answer for a
            // window that has not actually been rendered yet.
            let pending = items.contains { cache.renderedTexture(for: $0) == nil
                                            && !cache.isUnavailable($0) }
            if !pending { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private var metalAvailable: Bool { PrintCellTextureCache.isAvailable }

    // MARK: - The path exists

    @Test("A marked frame is rendered to a GPU texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCellGetsATexture() async throws {
        // A machine without a GPU is a supported configuration, not a failure.
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "cell.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let item = mark(path: url.path)
        await settle(cache, for: [item])

        let texture = try #require(cache.texture(for: item))
        #expect(texture.width == 32)
        #expect(texture.height == 32)
        #expect(texture.isGrayscale)
    }

    // MARK: - The claim

    /// The point of the path: every tool the preview offers is the shader's
    /// transform, so using one must not produce a new texture. If this fails, a
    /// zoom or window-drag on a cell re-renders it on every mouse delta.
    @Test("Zoom, pan, rotation, flip and inversion do not re-render the texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testArrangementDoesNotInvalidateTheTexture() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "arrange.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let item = mark(path: url.path)
        await settle(cache, for: [item])
        let original = try #require(cache.texture(for: item))

        let dragged = mark(
            path: url.path,
            presentation: ViewerPresentation(
                zoom: 3.4, panX: 120, panY: -64,
                viewportWidth: 256, viewportHeight: 256,
                rotationDegrees: 90,
                flipHorizontal: true, flipVertical: true, invert: true))
        cache.refresh(for: [dragged])

        let after = try #require(cache.texture(for: dragged))
        #expect(after.texture === original.texture,
                "a tool move re-rendered the texture — the key is including the arrangement")
    }

    /// …but what genuinely changes pixels must still invalidate it.
    @Test("Changing frame, window or window space renders a new texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPixelChangingStateInvalidatesTheTexture() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 20000, frames: 3), name: "frames.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let first = mark(path: url.path, frameIndex: 0)
        await settle(cache, for: [first])
        let firstTexture = try #require(cache.texture(for: first))

        let secondFrame = mark(path: url.path, frameIndex: 1)
        await settle(cache, for: [first, secondFrame])
        let secondTexture = try #require(cache.texture(for: secondFrame))
        #expect(secondTexture.texture !== firstTexture.texture,
                "frame index is not in the texture key — cells would show the wrong frame")

        let rewindowed = mark(path: url.path, windowCenter: 8000, windowWidth: 2000)
        await settle(cache, for: [first, rewindowed])
        let rewindowedTexture = try #require(cache.renderedTexture(for: rewindowed))
        #expect(rewindowedTexture.texture !== firstTexture.texture,
                "window is not in the texture key — a window drag would show nothing move")

        // The same two numbers mean different pictures in stored values and in
        // output units, so the space belongs in the key as well.
        #expect(PrintCellTextureCache.key(for: mark(path: url.path, windowSpace: .outputUnits))
                != PrintCellTextureCache.key(for: first))
    }

    /// A window/level drag makes a new texture per delta, and each one takes a
    /// dispatch to arrive. The cell must keep showing the last picture in the
    /// meantime — falling back to the CPU there would mean rendering a thumbnail
    /// per mouse delta, which is the cost this whole path removes.
    @Test("A re-windowed cell keeps showing the previous texture while it renders")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRewindowedCellKeepsThePreviousTexture() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 30000), name: "standin.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let item = mark(path: url.path)
        await settle(cache, for: [item])
        let original = try #require(cache.texture(for: item))

        // One delta of a window drag, asserted before the render can land.
        let dragged = mark(path: url.path, windowCenter: 12000, windowWidth: 4000)
        cache.refresh(for: [dragged])

        #expect(cache.renderedTexture(for: dragged) == nil,
                "the new window cannot have rendered yet — the test is not testing anything")
        #expect(cache.texture(for: dragged)?.texture === original.texture,
                "the cell dropped to the CPU mid-drag instead of holding the last picture")
    }

    // MARK: - Fallbacks

    /// An overlay-bearing frame must refuse the GPU path, exactly as the viewer
    /// refuses it: a Patient Protocol has all-zero pixels and its whole content in
    /// the plane, so its texture would be a black square.
    @Test("A cell with an overlay plane falls back to the CPU thumbnail")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverlayCellFallsBackToCPU() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000, overlay: true), name: "overlay.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let item = mark(path: url.path)
        await settle(cache, for: [item])

        #expect(cache.texture(for: item) == nil,
                "an overlay-bearing cell must keep the CPU-burned thumbnail")
        #expect(cache.isUnavailable(item),
                "the cell must be marked unavailable so it stops waiting and draws the still")
    }

    /// Textures are full-resolution GPU allocations, so paging to another film
    /// must let the last one's go — a hundred-image selection held on the GPU is
    /// exactly the leak this eviction exists to prevent.
    @Test("Cells no longer on the film release their textures")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPagingReleasesTextures() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 21000, frames: 2), name: "paging.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = PrintCellTextureCache()
        let onFirstFilm = mark(path: url.path, frameIndex: 0)
        let onSecondFilm = mark(path: url.path, frameIndex: 1)
        await settle(cache, for: [onFirstFilm])
        #expect(cache.texture(for: onFirstFilm) != nil)

        await settle(cache, for: [onSecondFilm])
        #expect(cache.texture(for: onFirstFilm) == nil,
                "a cell off the visible film kept its texture — the GPU would fill up")
    }

    // MARK: - Film geometry

    /// An untouched mark shows the whole frame — the preview must not crop
    /// something nobody asked it to.
    @Test("An unarranged mark shows the whole frame")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUnarrangedMarkShowsWholeFrame() {
        let item = mark(path: "/x.dcm")
        let presentation = PrintCellDisplay.presentation(
            for: item, imageWidth: 512, imageHeight: 256)

        #expect(presentation.sourceRegion == DisplayPresentation.SourceRegion(
            x: 0, y: 0, width: 512, height: 256))
        #expect(presentation.rotationDegrees == 0)
        #expect(!presentation.invert)

        let size = PrintCellDisplay.arrangedPixelSize(
            for: item, imageWidth: 512, imageHeight: 256)
        #expect(size.width == 512)
        #expect(size.height == 256)
    }

    /// The region the shader is given is the region the *printer* will crop —
    /// resolved by the one call that makes that decision. A preview that worked it
    /// out any other way would be a preview of a different film.
    @Test("The shader is given the print path's own visible region")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRegionMatchesThePrintPath() throws {
        let arrangement = ViewerPresentation(
            zoom: 2, panX: 30, panY: -20,
            viewportWidth: 256, viewportHeight: 256)
        let item = mark(path: "/x.dcm", presentation: arrangement)

        let expected = try #require(
            arrangement.visibleRegion(imageWidth: 512, imageHeight: 512))
        let region = try #require(PrintCellDisplay.presentation(
            for: item, imageWidth: 512, imageHeight: 512).sourceRegion)

        #expect(region.x == Double(expected.x))
        #expect(region.y == Double(expected.y))
        #expect(region.width == Double(expected.width))
        #expect(region.height == Double(expected.height))
    }

    /// A quarter turn swaps the printed picture's axes, which is what decides the
    /// shape of the picture in the cell — and so where the reader's annotations
    /// anchor, since the margin beside a fitted picture has no pixels on film.
    @Test("A quarter turn swaps the arranged picture's axes")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testQuarterTurnSwapsArrangedSize() {
        let item = mark(path: "/x.dcm",
                        presentation: ViewerPresentation(rotationDegrees: 90))
        let size = PrintCellDisplay.arrangedPixelSize(
            for: item, imageWidth: 400, imageHeight: 200)

        #expect(size.width == 200)
        #expect(size.height == 400)

        let presentation = PrintCellDisplay.presentation(
            for: item, imageWidth: 400, imageHeight: 200)
        #expect(presentation.rotationDegrees == 90)
    }
}
#endif
