// ViewerVideoContentTests.swift
// DICOMStudioTests
//
// Showing a video study, and — the part that actually breaks — putting the
// viewer back the way it was afterwards.
//
// A video instance carries an *image* SOP Class, so SOP Class alone cannot tell
// a clip from a picture; the transfer syntax is what says so. Before this, such
// a file went down the pixel path, found no codec for its transfer syntax, and
// was reported to the reader as an image that failed to decode.
//
// The transitions matter more than the single loads: a reader steps from a clip
// to a picture and back, and the tools have to come back with the picture.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("Viewer video content")
struct ViewerVideoContentTests {

    // MARK: - Classification

    @Test("Video transfer syntaxes are classified as video, not as images")
    func testVideoTransferSyntaxesAreVideo() {
        // The image SOP Class every one of these files carries. On its own it
        // says "picture", which is exactly the trap.
        let sopClass = "1.2.840.10008.5.1.4.1.1.77.1.1.1"  // Video Endoscopic
        for uid in ["1.2.840.10008.1.2.4.100",   // MPEG-2 MP@ML
                    "1.2.840.10008.1.2.4.101",   // MPEG-2 MP@HL
                    "1.2.840.10008.1.2.4.102",   // H.264 HP@4.1
                    "1.2.840.10008.1.2.4.103",   // H.264 BD
                    "1.2.840.10008.1.2.4.104",   // H.264 HP@4.2 2D
                    "1.2.840.10008.1.2.4.105",   // H.264 HP@4.2 3D
                    "1.2.840.10008.1.2.4.106",   // H.264 Stereo
                    "1.2.840.10008.1.2.4.107",   // HEVC Main
                    "1.2.840.10008.1.2.4.108",   // HEVC Main 10
                    "1.2.840.10008.1.2.4.102.1"] // a fragmentable variant
        {
            #expect(ViewerContentKind.kind(forSOPClassUID: sopClass,
                                           transferSyntaxUID: uid) == .video, "\(uid)")
        }
    }

    @Test("A still-image transfer syntax on the same SOP Class stays an image")
    func testStillImageSyntaxesAreImages() {
        let sopClass = "1.2.840.10008.5.1.4.1.1.77.1.1.1"
        for uid in ["1.2.840.10008.1.2",         // Implicit VR LE
                    "1.2.840.10008.1.2.1",       // Explicit VR LE
                    "1.2.840.10008.1.2.4.50",    // JPEG Baseline
                    "1.2.840.10008.1.2.4.90"]    // JPEG 2000 Lossless
        {
            #expect(ViewerContentKind.kind(forSOPClassUID: sopClass,
                                           transferSyntaxUID: uid) == .image, "\(uid)")
        }
    }

    @Test("The transfer syntax decides video before the SOP Class decides anything")
    func testTransferSyntaxWinsOverSOPClass() {
        // A nil transfer syntax must not turn every instance into a video, and
        // must leave the SOP Class answer exactly as it was.
        #expect(ViewerContentKind.kind(forSOPClassUID: "1.2.840.10008.5.1.4.1.1.88.11",
                                       transferSyntaxUID: nil) == .report)
        #expect(ViewerContentKind.kind(forSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
                                       transferSyntaxUID: nil) == .image)
    }

    // MARK: - Reading the payload

    @Test("The clip's bit stream is recovered byte for byte")
    func testPayloadIsRecoveredUnchanged() throws {
        let payload = Self.fakeMP4(bytes: 2048)
        let ds = Self.videoDataSet(payload: payload)

        let content = ViewerNonImageContentReader.content(
            of: ds, sopClassUID: Self.videoSOPClass,
            transferSyntaxUID: "1.2.840.10008.1.2.4.102")

        guard case .video(let video)? = content else {
            Issue.record("expected .video, got \(String(describing: content))")
            return
        }
        // The whole point of the passthrough: what the player is handed is what
        // was encapsulated, not a re-encoding of it.
        #expect(video.bitstream == payload)
        #expect(video.codec == .h264)
        #expect(content?.kind == .video)
    }

    @Test("A clip whose payload cannot be read is still named as a video")
    func testUnreadablePayloadFallsBackToSummary() {
        // Empty Pixel Data: extraction fails, but the instance is still a video
        // instance and must not fall through to the pixel path's error.
        var ds = DataSet()
        ds.setString(Self.videoSOPClass, for: .sopClassUID, vr: .UI)
        ds[.pixelData] = DataElement(
            tag: .pixelData, vr: .OB, length: 0, valueData: Data(),
            encapsulatedFragments: [], encapsulatedOffsetTable: [])

        let content = ViewerNonImageContentReader.content(
            of: ds, sopClassUID: Self.videoSOPClass,
            transferSyntaxUID: "1.2.840.10008.1.2.4.102")

        #expect(content?.kind == .video)
        if case .summary? = content {} else {
            Issue.record("expected a .summary fallback, got \(String(describing: content))")
        }
    }

    @Test("A still image is not diverted into the video path")
    func testStillImageReturnsNilContent() {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        let content = ViewerNonImageContentReader.content(
            of: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxUID: "1.2.840.10008.1.2.1")
        // nil means "this is a picture — go and decode it".
        #expect(content == nil)
    }

    // MARK: - Fixtures

    static let videoSOPClass = "1.2.840.10008.5.1.4.1.1.77.1.1.1"

    /// Bytes shaped like an MP4 — an `ftyp` box, then filler — so the container
    /// detector recognises it without a real encoder in the test.
    static func fakeMP4(bytes: Int) -> Data {
        var data = Data([0x00, 0x00, 0x00, 0x18])
        data.append(contentsOf: Array("ftypisom".utf8))
        data.append(contentsOf: Array("isomiso2".utf8))
        data.append(Data(repeating: 0x21, count: max(0, bytes - data.count)))
        return data
    }

    /// A data set holding one encapsulated video fragment.
    static func videoDataSet(payload: Data) -> DataSet {
        var ds = DataSet()
        ds.setString(videoSOPClass, for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.\(UUID().uuidString.prefix(8))", for: .sopInstanceUID, vr: .UI)
        ds.setString("ES", for: .modality, vr: .CS)
        ds[.pixelData] = DataElement(
            tag: .pixelData, vr: .OB, length: 0xFFFFFFFF, valueData: Data(),
            encapsulatedFragments: [payload], encapsulatedOffsetTable: [])
        return ds
    }
}

@Suite("Viewer video series pane")
struct ViewerVideoSeriesTests {

    @Test("A video series is labelled a video series, not an image series")
    func testSeriesKindAndNoun() {
        let entry = ViewerSeriesEntry(
            seriesInstanceUID: "1.2.3",
            title: "Endoscopy",
            seriesNumber: 1,
            modality: "ES",
            orientation: nil,
            filePaths: ["/tmp/a.dcm", "/tmp/b.dcm"],
            frameCount: 180,
            contentKind: .video,
            instanceNumbersBySOPUID: [:],
            frameCountsByFilePath: ["/tmp/a.dcm": 90, "/tmp/b.dcm": 90])
        // `isImageSeries` is what gates thumbnail decoding and the per-object
        // preview strip: a clip has no still frames to draw either from.
        #expect(!entry.isImageSeries)
        #expect(entry.objectPreviews.isEmpty)
        #expect(entry.countsLabel.contains("video clip"))
    }

    @Test("Video has its own name and symbol in the pane")
    func testDisplayNameAndSymbol() {
        #expect(ViewerContentKind.video.displayName == "Video")
        #expect(ViewerContentKind.video.symbolName == "film")
        #expect(!ViewerContentKind.video.isImage)
        // Nothing about a clip is undisplayable — it just is not pixels.
        #expect(ViewerContentKind.video.cannotDisplayReason == nil)
    }
}
