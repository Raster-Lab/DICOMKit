// ViewerVideoTransitionTests.swift
// DICOMStudioTests
//
// Stepping between a clip and a picture, which is where state gets left behind.
//
// Loading one video correctly is the easy half. The half that breaks is the
// reader moving on: a clip that leaves `nonImageContent` set makes the next
// image look like a document, and a picture that leaves it set after a clip
// hides the tools on a study that has every right to them. Both directions are
// pinned here, and so is the round trip.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("Viewer video transitions")
@MainActor
struct ViewerVideoTransitionTests {

    // MARK: - Loading each kind

    @Test("A video file loads as a clip, not as an image that failed to decode")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testVideoLoadsAsClip() throws {
        let vm = ImageViewerViewModel()
        let path = try Self.writeVideoDICOM()
        defer { try? FileManager.default.removeItem(atPath: path) }

        vm.loadFile(at: path)

        #expect(vm.isVideoContent)
        #expect(vm.contentKind == .video)
        #expect(vm.videoContent != nil)
        // The bug this replaces: an error about pixel data the object never
        // claimed to hold as frames.
        #expect(vm.errorMessage == nil)
        #expect(vm.currentImage == nil)
    }

    @Test("A clip opens already running, and offers the cine transport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClipOpensPlaying() throws {
        let vm = ImageViewerViewModel()
        let path = try Self.writeVideoDICOM()
        defer { try? FileManager.default.removeItem(atPath: path) }

        vm.loadFile(at: path)

        #expect(vm.playbackState == .playing)
        #expect(vm.playbackMode == .loop)
        #expect(vm.hasCineTransport)
    }

    @Test("Cine play and stop drive the clip the same way they drive frames")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTogglePlaybackOnClip() throws {
        let vm = ImageViewerViewModel()
        let path = try Self.writeVideoDICOM()
        defer { try? FileManager.default.removeItem(atPath: path) }

        vm.loadFile(at: path)
        #expect(vm.playbackState == .playing)
        vm.togglePlayback()
        #expect(vm.playbackState == .paused)
        vm.togglePlayback()
        #expect(vm.playbackState == .playing)
    }

    // MARK: - The transitions

    @Test("Stepping from a clip to an image clears the clip entirely")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testVideoThenImageRestoresTheImagePath() throws {
        let vm = ImageViewerViewModel()
        let video = try Self.writeVideoDICOM()
        let image = try Self.writeImageDICOM(frames: 1)
        defer {
            try? FileManager.default.removeItem(atPath: video)
            try? FileManager.default.removeItem(atPath: image)
        }

        vm.loadFile(at: video)
        #expect(vm.isVideoContent)

        vm.loadFile(at: image)

        // Every flag the toolbar reads has to be back where an image expects it.
        #expect(!vm.isVideoContent)
        #expect(vm.videoContent == nil)
        #expect(!vm.isNonImageContent)
        #expect(vm.contentKind == .image)
        #expect(vm.nonImageContent == nil)
        // A single-frame image has nothing to run.
        #expect(!vm.hasCineTransport)
    }

    @Test("Stepping from an image to a clip leaves no pixels behind")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testImageThenVideoClearsTheImage() throws {
        let vm = ImageViewerViewModel()
        let image = try Self.writeImageDICOM(frames: 1)
        let video = try Self.writeVideoDICOM()
        defer {
            try? FileManager.default.removeItem(atPath: image)
            try? FileManager.default.removeItem(atPath: video)
        }

        vm.loadFile(at: image)
        #expect(!vm.isNonImageContent)

        vm.loadFile(at: video)

        #expect(vm.isVideoContent)
        #expect(vm.contentKind == .video)
        // The previous study's picture must not still be on screen under the
        // clip — the viewport would draw the last image's pixels.
        #expect(vm.currentImage == nil)
        #expect(vm.numberOfFrames == 1)
        #expect(vm.currentFrameIndex == 0)
    }

    @Test("Clip, picture, clip — the round trip settles correctly each time")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRoundTripBetweenKinds() throws {
        let vm = ImageViewerViewModel()
        let video = try Self.writeVideoDICOM()
        let image = try Self.writeImageDICOM(frames: 8)
        defer {
            try? FileManager.default.removeItem(atPath: video)
            try? FileManager.default.removeItem(atPath: image)
        }

        for _ in 0..<3 {
            vm.loadFile(at: video)
            #expect(vm.isVideoContent)
            #expect(vm.contentKind == .video)
            #expect(vm.hasCineTransport)

            vm.loadFile(at: image)
            #expect(!vm.isVideoContent)
            #expect(vm.contentKind == .image)
            #expect(vm.numberOfFrames == 8)
            // A multi-frame image runs on its own frame index, and the clip's
            // playback state must not have stopped it doing so.
            #expect(vm.hasCineTransport)
            #expect(vm.playbackState == .playing)
        }
    }

    @Test("A report between a clip and an image does not strand either one")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClipReportImageSequence() throws {
        let vm = ImageViewerViewModel()
        let video = try Self.writeVideoDICOM()
        let report = try Self.writeReportDICOM()
        let image = try Self.writeImageDICOM(frames: 1)
        defer {
            for p in [video, report, image] {
                try? FileManager.default.removeItem(atPath: p)
            }
        }

        vm.loadFile(at: video)
        #expect(vm.contentKind == .video)

        vm.loadFile(at: report)
        #expect(vm.contentKind == .report)
        #expect(!vm.isVideoContent)
        // A report has nothing to play, so the transport goes away with it.
        #expect(!vm.hasCineTransport)
        #expect(vm.playbackState == .stopped)

        vm.loadFile(at: image)
        #expect(vm.contentKind == .image)
        #expect(!vm.isNonImageContent)
    }

    // MARK: - Fixtures

    /// A video instance: image SOP Class, video transfer syntax, one fragment.
    static func writeVideoDICOM() throws -> String {
        var ds = DataSet()
        let sopClass = "1.2.840.10008.5.1.4.1.1.77.1.1.1"  // Video Endoscopic
        ds.setString(sopClass, for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.\(UUID().uuidString.prefix(8))", for: .sopInstanceUID, vr: .UI)
        ds.setString("ES", for: .modality, vr: .CS)
        ds.setUInt16(480, for: .rows)
        ds.setUInt16(640, for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(3, for: .samplesPerPixel)
        ds.setString("YBR_PARTIAL_420", for: .photometricInterpretation, vr: .CS)
        ds.setString("90", for: .numberOfFrames, vr: .IS)
        ds[.pixelData] = DataElement(
            tag: .pixelData, vr: .OB, length: 0xFFFFFFFF, valueData: Data(),
            encapsulatedFragments: [ViewerVideoContentTests.fakeMP4(bytes: 4096)],
            encapsulatedOffsetTable: [])

        var fmi = DataSet()
        fmi.setString("1.2.840.10008.1.2.4.102",
                      for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        fmi.setString(sopClass, for: Tag(group: 0x0002, element: 0x0002), vr: .UI)
        fmi.setString("1.2.3.4.5", for: Tag(group: 0x0002, element: 0x0003), vr: .UI)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-\(UUID().uuidString).dcm")
        try DICOMFile(fileMetaInformation: fmi, dataSet: ds).write().write(to: url)
        return url.path
    }

    /// An ordinary greyscale image, one or many frames.
    static func writeImageDICOM(frames: Int) throws -> String {
        let rows = 4, columns = 4
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.\(UUID().uuidString.prefix(8))", for: .sopInstanceUID, vr: .UI)
        ds.setString("US", for: .modality, vr: .CS)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        if frames > 1 { ds.setString(String(frames), for: .numberOfFrames, vr: .IS) }
        var pixels = Data()
        for frame in 0..<frames {
            pixels.append(contentsOf: [UInt8](
                repeating: UInt8(truncatingIfNeeded: frame * 8), count: rows * columns))
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)

        var fmi = DataSet()
        fmi.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        fmi.setString("1.2.840.10008.5.1.4.1.1.7",
                      for: Tag(group: 0x0002, element: 0x0002), vr: .UI)
        fmi.setString("1.2.3.4.5", for: Tag(group: 0x0002, element: 0x0003), vr: .UI)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("image-\(UUID().uuidString).dcm")
        try DICOMFile(fileMetaInformation: fmi, dataSet: ds).write().write(to: url)
        return url.path
    }

    /// A Basic Text SR, for the third kind in the sequence.
    static func writeReportDICOM() throws -> String {
        var ds = DataSet()
        let sopClass = "1.2.840.10008.5.1.4.1.1.88.11"
        ds.setString(sopClass, for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.\(UUID().uuidString.prefix(8))", for: .sopInstanceUID, vr: .UI)
        ds.setString("SR", for: .modality, vr: .CS)
        ds.setString("CONTAINER", for: Tag(group: 0x0040, element: 0xA040), vr: .CS)

        var fmi = DataSet()
        fmi.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        fmi.setString(sopClass, for: Tag(group: 0x0002, element: 0x0002), vr: .UI)
        fmi.setString("1.2.3.4.5", for: Tag(group: 0x0002, element: 0x0003), vr: .UI)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("report-\(UUID().uuidString).dcm")
        try DICOMFile(fileMetaInformation: fmi, dataSet: ds).write().write(to: url)
        return url.path
    }
}
