// SpecializedModalityViewModelTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Specialized Modality ViewModel Tests")
struct SpecializedModalityViewModelTests {

    // MARK: - RT

    @Test("loadDefaultROIs creates 4 ROIs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadDefaultROIs() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultROIs()
        #expect(vm.rois.count == 4)
    }

    @Test("toggleROIVisibility changes visibility of specified ROI")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleROIVisibility() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultROIs()
        let initial = vm.rois.first!.isVisible
        vm.toggleROIVisibility(roiID: vm.rois.first!.id)
        #expect(vm.rois.first!.isVisible == !initial)
    }

    // MARK: - Segmentation

    @Test("loadDefaultSegments creates correct number of overlays")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadDefaultSegments() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultSegments(count: 5)
        #expect(vm.segmentOverlayState.overlays.count == 5)
    }

    @Test("toggleSegmentVisibility changes segment visibility")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleSegmentVisibility() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultSegments(count: 3)
        let initial = vm.segmentOverlayState.overlays.first!.isVisible
        vm.toggleSegmentVisibility(segmentNumber: 1)
        #expect(vm.segmentOverlayState.overlays.first!.isVisible == !initial)
    }

    @Test("setGlobalSegmentOpacity updates opacity")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetGlobalSegmentOpacity() {
        let vm = SpecializedModalityViewModel()
        vm.setGlobalSegmentOpacity(0.75)
        #expect(abs(vm.segmentOverlayState.globalOpacity - 0.75) < 0.001)
    }

    // MARK: - Parametric Map

    @Test("applyColormap updates colormapName in display state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyColormap() {
        let vm = SpecializedModalityViewModel()
        vm.applyColormap(.viridis)
        #expect(vm.parametricMapDisplayState.colormapName == .viridis)
    }

    // MARK: - Waveform

    @Test("loadDefaultWaveformChannels for ECG creates 12 channels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadDefaultWaveformChannelsECG() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultWaveformChannels(sopClassUID: "1.2.840.10008.5.1.4.1.1.9.1.1")
        #expect(vm.waveformChannels.count == 12)
    }

    @Test("addCaliperMeasurement increases count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddCaliperMeasurement() {
        let vm = SpecializedModalityViewModel()
        #expect(vm.caliperMeasurements.isEmpty)
        let m = WaveformCaliperMeasurement(startSampleIndex: 0, endSampleIndex: 250,
                                           samplingFrequency: 250.0)
        vm.addCaliperMeasurement(m)
        #expect(vm.caliperMeasurements.count == 1)
    }

    @Test("clearCaliperMeasurements removes all measurements")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearCaliperMeasurements() {
        let vm = SpecializedModalityViewModel()
        let m = WaveformCaliperMeasurement(startSampleIndex: 0, endSampleIndex: 250,
                                           samplingFrequency: 250.0)
        vm.addCaliperMeasurement(m)
        vm.addCaliperMeasurement(m)
        vm.clearCaliperMeasurements()
        #expect(vm.caliperMeasurements.isEmpty)
    }

    // MARK: - Video

    @Test("loadSampleVideo creates non-nil videoDisplayState")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadSampleVideo() {
        let vm = SpecializedModalityViewModel()
        vm.loadSampleVideo(totalFrames: 120, frameRate: 25.0)
        #expect(vm.videoDisplayState != nil)
    }

    @Test("toggleVideoPlayback flips isVideoPlaying")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleVideoPlayback() {
        let vm = SpecializedModalityViewModel()
        vm.loadSampleVideo()
        #expect(!vm.isVideoPlaying)
        vm.toggleVideoPlayback()
        #expect(vm.isVideoPlaying)
    }

    @Test("advanceVideoFrame increments frame in state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAdvanceVideoFrame() {
        let vm = SpecializedModalityViewModel()
        vm.loadSampleVideo(totalFrames: 120, frameRate: 25.0)
        vm.advanceVideoFrame()
        #expect(vm.videoDisplayState?.currentFrameIndex == 1)
    }

    // MARK: - Document

    @Test("loadDocument creates non-nil documentDisplayState")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadDocument() {
        let vm = SpecializedModalityViewModel()
        vm.loadDocument(type: .pdf, title: "Radiology Report")
        #expect(vm.documentDisplayState != nil)
        #expect(vm.documentDisplayState?.documentType == .pdf)
    }

    @Test("nextDocumentPage increments current page")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testNextDocumentPage() {
        let vm = SpecializedModalityViewModel()
        vm.loadDocument(type: .pdf, title: nil)
        let initial = vm.documentDisplayState?.currentPage ?? 0
        vm.nextDocumentPage()
        #expect((vm.documentDisplayState?.currentPage ?? 0) == initial + 1)
    }

    // MARK: - WSI

    @Test("loadWSILevels creates 5 tile levels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadWSILevels() {
        let vm = SpecializedModalityViewModel()
        vm.loadWSILevels()
        #expect(vm.wsiTileLevels.count == 5)
    }

    @Test("zoomWSI updates wsiDisplayState zoomFactor")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testZoomWSI() {
        let vm = SpecializedModalityViewModel()
        vm.zoomWSI(to: 3.5)
        #expect(abs(vm.wsiDisplayState.zoomFactor - 3.5) < 0.001)
    }

    // MARK: - Reset

    @Test("resetAll clears rois and other state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetAll() {
        let vm = SpecializedModalityViewModel()
        vm.loadDefaultROIs()
        vm.loadSampleVideo()
        #expect(vm.rois.count == 4)
        vm.resetAll()
        #expect(vm.rois.isEmpty)
        #expect(vm.videoDisplayState == nil)
    }
}
