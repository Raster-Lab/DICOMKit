// ViewerDecodedPixelCacheTests.swift
// DICOMStudioTests
//
// The focused viewport now holds its decoded pixels across re-windows instead of
// re-decoding on every window/level delta. That removes a full codec run per mouse
// event — 355 ms per step for RLE, 16 ms for JPEG 2000, on a 2048×2500 CR.
//
// A cache can only be wrong in one interesting way: by serving the previous image's
// pixels. These tests are aimed squarely at that.

import Testing
@testable import DICOMStudio
import Foundation
import DICOMCore
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite("Viewer Decoded Pixel Cache Tests")
@MainActor
struct ViewerDecodedPixelCacheTests {

    // MARK: - Fixtures

    /// A small MONOCHROME2 file whose pixels are all one value, so what is on screen
    /// identifies which file produced it without ambiguity.
    private func uniformFile(value: UInt16, rows: Int = 16, columns: Int = 16) throws -> Data {
        var elements: [DataElement] = []
        elements.append(.uint16(tag: .rows, value: UInt16(rows)))
        elements.append(.uint16(tag: .columns, value: UInt16(columns)))
        elements.append(.uint16(tag: .bitsAllocated, value: 16))
        elements.append(.uint16(tag: .bitsStored, value: 16))
        elements.append(.uint16(tag: .highBit, value: 15))
        elements.append(.uint16(tag: .pixelRepresentation, value: 0))
        elements.append(.uint16(tag: .samplesPerPixel, value: 1))
        elements.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        elements.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.1"))
        elements.append(.string(tag: .sopInstanceUID, vr: .UI,
                                value: "1.2.3.4.5.6.7.8.\(value)"))

        var pixels = Data(count: rows * columns * 2)
        pixels.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for i in 0..<(rows * columns) { out[i] = value }
        }
        elements.append(DataElement(tag: .pixelData, vr: .OW,
                                    length: UInt32(pixels.count), valueData: pixels))

        return try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        ).write()
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewerPixelCache-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    #if canImport(CoreGraphics)
    private func firstByte(of image: CGImage) -> UInt8? {
        guard let data = image.dataProvider?.data as Data? else { return nil }
        return data.first
    }

    // MARK: - Correctness

    /// The one failure this cache could cause: loading a second file and still
    /// showing the first one's pixels.
    @Test("Loading another file does not show the previous file's pixels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCacheIsInvalidatedOnFileChange() throws {
        let darkURL = try write(try uniformFile(value: 1000), name: "dark.dcm")
        let brightURL = try write(try uniformFile(value: 60000), name: "bright.dcm")
        defer {
            try? FileManager.default.removeItem(at: darkURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: brightURL.deletingLastPathComponent())
        }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: darkURL.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536
        vm.renderCurrentFrame()
        let dark = try #require(vm.currentImage.flatMap(firstByte))

        vm.loadFile(at: brightURL.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536
        vm.renderCurrentFrame()
        let bright = try #require(vm.currentImage.flatMap(firstByte))

        #expect(dark != bright,
                "the second file rendered identically to the first — stale cached pixels")
        #expect(dark < bright)
    }

    /// Re-windowing must change the picture. If the cache were keyed too coarsely —
    /// or the rendered image itself were cached — a drag would show nothing moving.
    @Test("Re-windowing the same file re-renders from the cached pixels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRewindowingStillChangesTheImage() throws {
        let url = try write(try uniformFile(value: 20000), name: "ct.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)

        vm.windowCenter = 20000
        vm.windowWidth = 65536
        vm.renderCurrentFrame()
        let midGrey = try #require(vm.currentImage.flatMap(firstByte))

        // Window entirely above the pixel value — it must clamp to black.
        vm.windowCenter = 60000
        vm.windowWidth = 1000
        vm.renderCurrentFrame()
        let black = try #require(vm.currentImage.flatMap(firstByte))

        // …and entirely below it — white.
        vm.windowCenter = 100
        vm.windowWidth = 100
        vm.renderCurrentFrame()
        let white = try #require(vm.currentImage.flatMap(firstByte))

        #expect(black == 0)
        #expect(white == 255)
        #expect(midGrey != black && midGrey != white)
    }

    /// A repeated drag must keep producing correct output, not just a correct first
    /// frame — the cached buffer is reused, and reuse is where a lifetime bug would
    /// show up as a corrupted or frozen image.
    @Test("A long drag keeps rendering correctly from one cached decode")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRepeatedDragRemainsCorrect() throws {
        let url = try write(try uniformFile(value: 30000), name: "drag.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)
        vm.windowWidth = 65536

        var seen: [UInt8] = []
        for step in 0..<40 {
            vm.windowCenter = 30000 + Double(step) * 400
            vm.renderCurrentFrame()
            seen.append(try #require(vm.currentImage.flatMap(firstByte)))
        }

        // Sweeping the centre upward past a constant pixel value drives it darker,
        // monotonically. Any wrong-buffer or stale-image bug breaks the ordering.
        #expect(seen.count == 40)
        #expect(seen.first! > seen.last!)
        for (earlier, later) in zip(seen, seen.dropFirst()) {
            #expect(earlier >= later, "window sweep produced a non-monotonic result")
        }
    }

    /// Frame index must still select the right frame from the cached pixel data —
    /// the cache holds every frame, and the render picks one by offset.
    @Test("Frames are still selected correctly from cached multi-frame pixels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMultiFrameSelectionFromCache() throws {
        let rows = 8, columns = 8, frames = 4
        var elements: [DataElement] = []
        elements.append(.uint16(tag: .rows, value: UInt16(rows)))
        elements.append(.uint16(tag: .columns, value: UInt16(columns)))
        elements.append(.string(tag: .numberOfFrames, vr: .IS, value: "\(frames)"))
        elements.append(.uint16(tag: .bitsAllocated, value: 16))
        elements.append(.uint16(tag: .bitsStored, value: 16))
        elements.append(.uint16(tag: .highBit, value: 15))
        elements.append(.uint16(tag: .pixelRepresentation, value: 0))
        elements.append(.uint16(tag: .samplesPerPixel, value: 1))
        elements.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        elements.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.1"))
        elements.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.9.1"))

        // Each frame is a different flat value, so the rendered byte names the frame.
        var pixels = Data(count: rows * columns * 2 * frames)
        pixels.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for frame in 0..<frames {
                for i in 0..<(rows * columns) {
                    out[frame * rows * columns + i] = UInt16(10000 + frame * 12000)
                }
            }
        }
        elements.append(DataElement(tag: .pixelData, vr: .OW,
                                    length: UInt32(pixels.count), valueData: pixels))
        let data = try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()

        let url = try write(data, name: "multiframe.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536

        var perFrame: [UInt8] = []
        for frame in 0..<frames {
            vm.currentFrameIndex = frame
            vm.renderCurrentFrame()
            perFrame.append(try #require(vm.currentImage.flatMap(firstByte)))
        }

        #expect(Set(perFrame).count == frames,
                "frames rendered identically — the frame offset is being ignored")
        for (earlier, later) in zip(perFrame, perFrame.dropFirst()) {
            #expect(earlier < later)
        }
    }
    #endif
}

// MARK: - GPU display path (GPU_RENDERING_PLAN.md M5)

#if canImport(Metal)
import Metal
import DICOMRenderKit

@Suite("Viewer GPU Display Path Tests")
@MainActor
struct ViewerDisplayTexturePathTests {

    private func uniformFile(
        value: UInt16, rows: Int = 32, columns: Int = 32,
        overlay: Bool = false
    ) throws -> Data {
        var elements: [DataElement] = []
        elements.append(.uint16(tag: .rows, value: UInt16(rows)))
        elements.append(.uint16(tag: .columns, value: UInt16(columns)))
        elements.append(.uint16(tag: .bitsAllocated, value: 16))
        elements.append(.uint16(tag: .bitsStored, value: 16))
        elements.append(.uint16(tag: .highBit, value: 15))
        elements.append(.uint16(tag: .pixelRepresentation, value: 0))
        elements.append(.uint16(tag: .samplesPerPixel, value: 1))
        elements.append(.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"))
        elements.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"))
        elements.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.9.\(value)"))

        if overlay {
            // A 1-bit overlay plane covering the frame — the Patient Protocol shape.
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

        var pixels = Data(count: rows * columns * 2)
        pixels.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for i in 0..<(rows * columns) { out[i] = value }
        }
        elements.append(DataElement(tag: .pixelData, vr: .OW,
                                    length: UInt32(pixels.count), valueData: pixels))

        return try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewerDisplayPath-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    private var metalAvailable: Bool {
        FrameRenderService.shared.activeBackend == .metal
    }

    /// A plain frame goes to the GPU display path, at any size — the sub-megapixel
    /// threshold applies to the CGImage route, where a dispatch competes with a cheap
    /// CPU render, not to a frame already headed for a texture.
    @Test("A plain frame is displayed from a GPU texture")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPlainFrameUsesDisplayTexture() throws {
        // A machine without a GPU is a supported configuration, not a failure.
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "plain.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536
        vm.renderCurrentFrame()

        #expect(vm.displayTexture != nil)
        #expect(vm.displayTexture?.width == 32)
        #expect(vm.displayTexture?.height == 32)
        #expect(vm.displayTexture?.isGrayscale == true)
        // The CGImage is still produced, from the same dispatch and the same memory.
        #expect(vm.currentImage != nil)
    }

    /// A frame carrying an overlay plane must NOT take the texture path: overlays are
    /// burned into the CGImage, and some Secondary Captures have all-zero pixels with
    /// their entire content in the overlay. Showing the texture would present a blank
    /// square where a page of text belongs.
    @Test("A frame with an overlay plane falls back to the burned CGImage")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverlayFrameDoesNotUseDisplayTexture() throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000, overlay: true), name: "overlay.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536
        vm.renderCurrentFrame()

        #expect(vm.displayTexture == nil,
                "an overlay-bearing frame must keep the CPU-burned image")
        #expect(vm.currentImage != nil)
    }

    /// Inversion on the GPU path is a shader flag: it must reach the presentation and
    /// must not trigger a re-render.
    @Test("Toggling inversion on the GPU path re-renders nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInversionIsFreeOnTheDisplayPath() throws {
        guard metalAvailable else { return }

        let url = try write(try uniformFile(value: 25000), name: "invert.dcm")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vm = ImageViewerViewModel()
        vm.loadFile(at: url.path)
        vm.windowCenter = 32768
        vm.windowWidth = 65536
        vm.renderCurrentFrame()
        try #require(vm.displayTexture != nil)

        let before = vm.currentImage
        vm.toggleInversion()

        #expect(vm.isInverted)
        #expect(vm.displayPresentation.invert)
        #expect(vm.currentImage === before,
                "inversion must not re-render on the GPU path — it is a shader flag")
    }

    /// The tool state must reach the shader's geometry, or the transforms silently do
    /// nothing.
    @Test("Tool state is carried into the display presentation")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPresentationReflectsToolState() {
        let vm = ImageViewerViewModel()
        vm.zoomLevel = 2.5
        vm.panOffsetX = 12
        vm.panOffsetY = -7
        vm.rotationAngle = 90
        vm.isFlippedHorizontal = true
        vm.isFlippedVertical = false
        vm.isInverted = true

        let presentation = vm.displayPresentation
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
