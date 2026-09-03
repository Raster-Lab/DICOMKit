// ViewerPerFrameWindowTests.swift
// DICOMStudioTests
//
// An Enhanced multi-frame object may window and rescale every frame on its own
// (multi-echo MR, per-frame-windowed PET). Paging such a file in the focused
// viewport must adopt each frame's window while the reader has not touched it,
// keep a dragged window across frames, and always carry the frame's rescale
// pair — the same decisions the tile path makes through the shared policy.

import Testing
@testable import DICOMStudio
import Foundation
import DICOMCore
@testable import DICOMKit

@Suite("Viewer per-frame window")
@MainActor
struct ViewerPerFrameWindowTests {

    @Test("An untouched window follows the frame's own Frame VOI LUT and rescale")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func untouchedWindowFollowsFrame() throws {
        let path = try writeEnhancedCT(frames: 3, perFrameWindow: true)
        let vm = ImageViewerViewModel()
        vm.loadFile(at: path)
        #expect(vm.hasPerFrameWindow)
        #expect(vm.numberOfFrames == 3)
        // Frame 0: centre 100 HU, intercept −1000 → stored 1100.
        #expect(vm.rescaleIntercept == -1000)
        #expect(vm.windowCenter == 1100)
        #expect(vm.windowWidth == 200)

        vm.goToFrame(2)
        // Frame 2: centre 300 HU, intercept −1002 → stored 1302.
        #expect(vm.rescaleIntercept == -1002)
        #expect(vm.windowCenter == 1302)
        #expect(vm.windowWidth == 600)
        #expect(vm.headerWindowSettings.first?.center == 300)
        #expect(!vm.userAdjustedWindowInSeries, "following the frame is not a reader adjustment")

        vm.previousFrame()
        #expect(vm.windowCenter == 1201)
        #expect(vm.windowWidth == 400)
    }

    @Test("A reader's window survives paging; only the rescale pair follows")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func adjustedWindowStaysAcrossFrames() throws {
        let path = try writeEnhancedCT(frames: 3, perFrameWindow: true)
        let vm = ImageViewerViewModel()
        vm.loadFile(at: path)
        vm.adjustWindowLevel(deltaX: 10, deltaY: 5)
        let dragged = (vm.windowCenter, vm.windowWidth)
        #expect(dragged.0 != 1100 || dragged.1 != 200)

        vm.goToFrame(2)
        #expect(vm.windowCenter == dragged.0)
        #expect(vm.windowWidth == dragged.1)
        #expect(vm.rescaleIntercept == -1002)

        // A reset lands on the window of the frame on screen, not frame 0's.
        vm.autoWindowLevel()
        #expect(vm.windowCenter == 1302)
        #expect(vm.windowWidth == 600)
    }

    @Test("A shared window costs nothing and does not move when paging")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func sharedWindowIsNotPerFrame() throws {
        let path = try writeEnhancedCT(frames: 3, perFrameWindow: false)
        let vm = ImageViewerViewModel()
        vm.loadFile(at: path)
        #expect(!vm.hasPerFrameWindow)
        #expect(vm.windowCenter == 40 + 1024)
        vm.goToFrame(2)
        #expect(vm.windowCenter == 40 + 1024)
        #expect(vm.windowWidth == 400)
    }

    // MARK: - Helpers

    private func seq(_ tag: DICOMCore.Tag, _ elements: [DataElement]) -> DataElement {
        FunctionalGroupBuilder.sequenceElement(tag, items: [SequenceItem(elements: elements)], writer: DICOMWriter())
    }

    private func str(_ tag: DICOMCore.Tag, _ vr: DICOMCore.VR, _ value: String) -> DataElement {
        DataElement.string(tag: tag, vr: vr, value: value)
    }

    /// A 16-bit Enhanced CT. With `perFrameWindow`, frame f windows at centre
    /// 100·(f+1) / width 200·(f+1) with intercept −1000−f in its Per-frame item;
    /// otherwise the Shared item windows every frame at 40/400, intercept −1024.
    private func writeEnhancedCT(frames: Int, perFrameWindow: Bool) throws -> String {
        let rows = 4, columns = 4
        let enhancedCT = "1.2.840.10008.5.1.4.1.1.2.1"
        var ds = DataSet()
        ds.setString(enhancedCT, for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.\(UUID().uuidString.prefix(8))", for: .sopInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(12, for: .bitsStored)
        ds.setUInt16(11, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setString(String(frames), for: .numberOfFrames, vr: .IS)

        var shared: [DataElement] = [
            seq(.pixelMeasuresSequence, [str(.pixelSpacing, .DS, "0.5\\0.5")]),
            seq(.planeOrientationSequence, [str(.imageOrientationPatient, .DS, "1\\0\\0\\0\\1\\0")]),
        ]
        if !perFrameWindow {
            shared.append(seq(.frameVOILUTSequence, [str(.windowCenter, .DS, "40"), str(.windowWidth, .DS, "400")]))
            shared.append(seq(.pixelValueTransformationSequence, [str(.rescaleIntercept, .DS, "-1024"), str(.rescaleSlope, .DS, "1")]))
        }
        ds.setSequence([SequenceItem(elements: shared)], for: .sharedFunctionalGroupsSequence)

        var perFrame: [SequenceItem] = []
        for f in 0..<frames {
            var elements: [DataElement] = [
                seq(.frameContentSequence, [DataElement.uint32(tag: .inStackPositionNumber, value: UInt32(f + 1))]),
                seq(.planePositionSequence, [str(.imagePositionPatient, .DS, "0\\0\\\(f)")]),
            ]
            if perFrameWindow {
                elements.append(seq(.frameVOILUTSequence, [str(.windowCenter, .DS, "\(100 * (f + 1))"),
                                                           str(.windowWidth, .DS, "\(200 * (f + 1))")]))
                elements.append(seq(.pixelValueTransformationSequence, [str(.rescaleIntercept, .DS, "\(-1000 - f)"),
                                                                        str(.rescaleSlope, .DS, "1")]))
            }
            perFrame.append(SequenceItem(elements: elements))
        }
        ds.setSequence(perFrame, for: .perFrameFunctionalGroupsSequence)

        var pixels = Data(count: rows * columns * frames * 2)
        for f in 0..<frames {
            let v = UInt16(1000 + f)
            for i in 0..<(rows * columns) {
                pixels[(f * rows * columns + i) * 2] = UInt8(v & 0xFF)
                pixels[(f * rows * columns + i) * 2 + 1] = UInt8(v >> 8)
            }
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)

        var fmi = DataSet()
        fmi.setString("1.2.840.10008.1.2.1", for: DICOMCore.Tag(group: 0x0002, element: 0x0010), vr: .UI)
        fmi.setString(enhancedCT, for: DICOMCore.Tag(group: 0x0002, element: 0x0002), vr: .UI)
        fmi.setString(ds.string(for: .sopInstanceUID)!, for: DICOMCore.Tag(group: 0x0002, element: 0x0003), vr: .UI)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("per-frame-window-\(UUID().uuidString).dcm")
        try DICOMFile(fileMetaInformation: fmi, dataSet: ds).write().write(to: url)
        return url.path
    }
}
