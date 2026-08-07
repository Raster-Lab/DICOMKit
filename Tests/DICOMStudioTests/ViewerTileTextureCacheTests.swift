// ViewerTileTextureCacheTests.swift
// DICOMStudioTests
//
// The viewer's unfocused tiles now draw from GPU textures, like the focused one.
//
// The claim that makes this worth doing is narrow and testable: a tile's texture
// is keyed on its *pixels* — file, frame, window — and not on its arrangement, so
// moving a tool re-draws a quad and re-renders nothing. A synchronised zoom or
// window drag across a grid then costs one redraw per tile instead of one decode.
// These tests are aimed at that claim, and at the fallbacks that must survive it.

import Testing
@testable import DICOMStudio
import Foundation
import DICOMCore
import DICOMKit

#if canImport(Metal)
import Metal
import DICOMRenderKit

@Suite("Viewer Tile Texture Cache Tests")
@MainActor
struct ViewerTileTextureCacheTests {

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
                                value: "1.2.3.4.5.11.\(value).\(frames)"))

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
            .appendingPathComponent("ViewerTileTexture-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    private func cell(
        path: String, index: Int = 1, frameIndex: Int = 0,
        windowCenter: Double? = 32768, windowWidth: Double? = 65536
    ) -> ViewerCellState {
        ViewerCellState(
            index: index, filePath: path, frameIndex: frameIndex,
            windowCenter: windowCenter, windowWidth: windowWidth,
            viewportWidth: 256, viewportHeight: 256)
    }

    /// Renders the given tiles and waits for the cache to settle.
    ///
    /// Texture production is a detached decode plus a dispatch, so a test that
    /// asserted immediately would only ever see the pending state.
    private func settle(
        _ cache: ViewerTileTextureCache, for cells: [ViewerCellState]
    ) async {
        cache.refresh(for: cells)
        for _ in 0..<200 {
            let pending = cells.contains { cache.texture(for: $0) == nil
                                            && !cache.isUnavailable(for: $0) }
            if !pending { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private var metalAvailable: Bool { ViewerTileTextureCache.isAvailable }

    // MARK: - The path exists

    /// An ordinary unfocused tile is drawn from a GPU texture, not a CPU still.
    @Test("An unfocused tile is rendered to a GPU texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTileGetsATexture() async throws {
        // A machine without a GPU is a supported configuration, not a failure.
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "tile.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = ViewerTileTextureCache()
        let tile = cell(path: url.path)
        await settle(cache, for: [tile])

        let texture = try #require(cache.texture(for: tile))
        #expect(texture.width == 32)
        #expect(texture.height == 32)
        #expect(texture.isGrayscale)
    }

    // MARK: - The claim

    /// The point of the whole path: arrangement is the shader's transform, so
    /// moving a tool must not produce a new texture. If this fails, a synchronised
    /// zoom re-decodes the grid on every mouse delta — the cost this exists to remove.
    @Test("Zoom, pan, rotation, flip and inversion do not re-render the texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testArrangementDoesNotInvalidateTheTexture() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "arrange.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = ViewerTileTextureCache()
        var tile = cell(path: url.path)
        await settle(cache, for: [tile])
        let original = try #require(cache.texture(for: tile))

        // A drag's worth of tool movement, of every kind the shader handles.
        tile.zoom = 3.4
        tile.panX = 120
        tile.panY = -64
        tile.rotationAngle = 90
        tile.isFlippedHorizontal = true
        tile.isFlippedVertical = true
        tile.isInverted = true
        cache.refresh(for: [tile])

        let after = try #require(cache.texture(for: tile))
        #expect(after.texture === original.texture,
                "a tool move re-rendered the texture — the key is including the arrangement")
    }

    /// …but the things that genuinely change pixels must still invalidate it.
    @Test("Changing frame or window renders a new texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPixelChangingStateInvalidatesTheTexture() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 20000, frames: 3), name: "frames.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = ViewerTileTextureCache()
        let first = cell(path: url.path, frameIndex: 0)
        await settle(cache, for: [first])
        let firstTexture = try #require(cache.texture(for: first))

        // A different frame of the same file is a different picture.
        let secondFrame = cell(path: url.path, frameIndex: 1)
        await settle(cache, for: [first, secondFrame])
        let secondTexture = try #require(cache.texture(for: secondFrame))
        #expect(secondTexture.texture !== firstTexture.texture,
                "frame index is not in the texture key — tiles would show the wrong frame")

        // So is the same frame under a different window.
        let rewindowed = cell(path: url.path, frameIndex: 0,
                              windowCenter: 8000, windowWidth: 2000)
        await settle(cache, for: [first, rewindowed])
        let rewindowedTexture = try #require(cache.texture(for: rewindowed))
        #expect(rewindowedTexture.texture !== firstTexture.texture,
                "window is not in the texture key — a window drag would show nothing move")
    }

    // MARK: - Fallbacks

    /// An overlay-bearing frame must refuse the GPU path, exactly as the focused
    /// viewport refuses it: a Patient Protocol has all-zero pixels and its whole
    /// content in the plane, so its texture is a black square.
    @Test("A tile with an overlay plane falls back to the CPU image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverlayTileFallsBackToCPU() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000, overlay: true), name: "overlay.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = ViewerTileTextureCache()
        let tile = cell(path: url.path)
        await settle(cache, for: [tile])

        #expect(cache.texture(for: tile) == nil,
                "an overlay-bearing tile must keep the CPU-burned image")
        #expect(cache.isUnavailable(for: tile),
                "the tile must be marked unavailable so it stops waiting and draws the CPU still")
    }

    /// An empty tile has nothing to render and must not be mistaken for a pending one.
    @Test("An empty tile is never pending")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEmptyTile() {
        let cache = ViewerTileTextureCache()
        let empty = ViewerCellState(index: 0)
        cache.refresh(for: [empty])
        #expect(cache.texture(for: empty) == nil)
        #expect(cache.isUnavailable(for: empty))
    }

    // MARK: - Memory

    /// Textures are full-resolution GPU allocations, so a grid that stopped showing
    /// a frame must let go of it. Without this, scrolling a series grows without bound.
    @Test("Tiles the grid no longer shows release their textures")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEviction() async throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000, frames: 3), name: "evict.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cache = ViewerTileTextureCache()
        let first = cell(path: url.path, frameIndex: 0)
        await settle(cache, for: [first])
        #expect(cache.texture(for: first) != nil)

        // The tile moves to another frame; the one it left is no longer shown.
        let moved = cell(path: url.path, frameIndex: 2)
        await settle(cache, for: [moved])

        #expect(cache.texture(for: moved) != nil)
        #expect(cache.texture(for: first) == nil,
                "a frame the grid stopped showing kept its texture — this leaks GPU memory")
    }

    // MARK: - Geometry

    /// A tile's arrangement must reach the shader, or the transforms silently do
    /// nothing — and it must agree with the focused viewport, so a tile looks the
    /// same on either side of gaining focus.
    @Test("Tile tool state is carried into the display presentation")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCellPresentation() {
        var tile = ViewerCellState(index: 0, filePath: "/x.dcm")
        tile.zoom = 2.5
        tile.panX = 12
        tile.panY = -7
        tile.rotationAngle = 90
        tile.isFlippedHorizontal = true
        tile.isFlippedVertical = false
        tile.isInverted = true

        let presentation = tile.displayPresentation
        #expect(presentation.zoom == 2.5)
        #expect(presentation.panX == 12)
        #expect(presentation.panY == -7)
        #expect(presentation.rotationDegrees == 90)
        #expect(presentation.flipHorizontal)
        #expect(!presentation.flipVertical)
        #expect(presentation.invert)
    }
}
#endif
