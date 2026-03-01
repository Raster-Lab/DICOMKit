// ImageViewerViewModelTests.swift
// DICOMStudioTests
//
// Tests for ImageViewerViewModel

import Testing
@testable import DICOMStudio
import Foundation
import DICOMCore

@Suite("ImageViewerViewModel Tests")
struct ImageViewerViewModelTests {

    // MARK: - Initialization

    @Test("Initial state has no image loaded")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialState() {
        let vm = ImageViewerViewModel()
        #expect(vm.filePath == nil)
        #expect(vm.dicomFile == nil)
        #expect(vm.sopInstanceUID == nil)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.hasImage == false)
    }

    @Test("Initial window/level defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialWindowLevel() {
        let vm = ImageViewerViewModel()
        #expect(vm.windowCenter == 128.0)
        #expect(vm.windowWidth == 256.0)
        #expect(vm.isInverted == false)
    }

    @Test("Initial zoom/pan/rotation defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialZoomPanRotation() {
        let vm = ImageViewerViewModel()
        #expect(vm.zoomLevel == 1.0)
        #expect(vm.panOffsetX == 0.0)
        #expect(vm.panOffsetY == 0.0)
        #expect(vm.rotationAngle == 0.0)
    }

    @Test("Initial playback state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialPlayback() {
        let vm = ImageViewerViewModel()
        #expect(vm.playbackState == .stopped)
        #expect(vm.playbackMode == .loop)
        #expect(vm.playbackDirection == .forward)
        #expect(vm.playbackFPS == CinePlaybackHelpers.defaultFPS)
        #expect(vm.currentFrameIndex == 0)
    }

    @Test("Initial overlay state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialOverlays() {
        let vm = ImageViewerViewModel()
        #expect(vm.showMetadataOverlay == false)
        #expect(vm.showPerformanceOverlay == false)
    }

    @Test("Initial metadata defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialMetadata() {
        let vm = ImageViewerViewModel()
        #expect(vm.imageRows == 0)
        #expect(vm.imageColumns == 0)
        #expect(vm.bitsAllocated == 0)
        #expect(vm.bitsStored == 0)
        #expect(vm.highBit == 0)
        #expect(vm.isSigned == false)
        #expect(vm.samplesPerPixel == 1)
        #expect(vm.planarConfiguration == 0)
        #expect(vm.photometricInterpretation == "")
        #expect(vm.numberOfFrames == 1)
    }

    // MARK: - Window/Level

    @Test("Apply preset updates window center and width")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyPreset() {
        let vm = ImageViewerViewModel()
        let preset = WindowLevelPreset(name: "Bone", center: 300, width: 1500, modality: "CT")
        vm.applyPreset(preset)
        #expect(vm.windowCenter == 300)
        #expect(vm.windowWidth == 1500)
    }

    @Test("Apply window settings")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyWindowSettings() {
        let vm = ImageViewerViewModel()
        let settings = WindowSettings(center: 50, width: 350, explanation: "Test")
        vm.applyWindowSettings(settings)
        #expect(vm.windowCenter == 50)
        #expect(vm.windowWidth == 350)
        #expect(vm.voiLUTFunction == "LINEAR")
    }

    @Test("Adjust window level from drag")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAdjustWindowLevel() {
        let vm = ImageViewerViewModel()
        let initialCenter = vm.windowCenter
        let initialWidth = vm.windowWidth
        vm.adjustWindowLevel(deltaX: 10, deltaY: 5)
        #expect(vm.windowWidth == initialWidth + 10)
        #expect(vm.windowCenter == initialCenter - 5)
    }

    @Test("Toggle inversion")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleInversion() {
        let vm = ImageViewerViewModel()
        #expect(vm.isInverted == false)
        vm.toggleInversion()
        #expect(vm.isInverted == true)
        vm.toggleInversion()
        #expect(vm.isInverted == false)
    }

    // MARK: - Frame Navigation

    @Test("Next frame step")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testNextFrame() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.currentFrameIndex = 0
        vm.nextFrame()
        #expect(vm.currentFrameIndex == 1)
    }

    @Test("Previous frame step")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPreviousFrame() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.currentFrameIndex = 5
        vm.previousFrame()
        #expect(vm.currentFrameIndex == 4)
    }

    @Test("Go to specific frame")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGoToFrame() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.goToFrame(7)
        #expect(vm.currentFrameIndex == 7)
    }

    @Test("Go to frame out of range does nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGoToFrameOutOfRange() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.goToFrame(20)
        #expect(vm.currentFrameIndex == 0)
    }

    @Test("Go to negative frame does nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGoToNegativeFrame() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.goToFrame(-1)
        #expect(vm.currentFrameIndex == 0)
    }

    // MARK: - Cine Playback

    @Test("Toggle playback from stopped")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTogglePlaybackFromStopped() {
        let vm = ImageViewerViewModel()
        vm.togglePlayback()
        #expect(vm.playbackState == .playing)
    }

    @Test("Toggle playback from playing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTogglePlaybackFromPlaying() {
        let vm = ImageViewerViewModel()
        vm.playbackState = .playing
        vm.togglePlayback()
        #expect(vm.playbackState == .paused)
    }

    @Test("Toggle playback from paused")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTogglePlaybackFromPaused() {
        let vm = ImageViewerViewModel()
        vm.playbackState = .paused
        vm.togglePlayback()
        #expect(vm.playbackState == .playing)
    }

    @Test("Stop playback resets state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testStopPlayback() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.currentFrameIndex = 5
        vm.playbackState = .playing
        vm.stopPlayback()
        #expect(vm.playbackState == .stopped)
        #expect(vm.currentFrameIndex == 0)
        #expect(vm.playbackDirection == .forward)
    }

    @Test("Advance cine frame loop mode")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAdvanceCineFrame() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.currentFrameIndex = 0
        vm.playbackMode = .loop
        vm.advanceCineFrame()
        #expect(vm.currentFrameIndex == 1)
    }

    @Test("Advance cine frame once mode stops at end")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAdvanceCineFrameOnce() {
        let vm = ImageViewerViewModel()
        vm.numberOfFrames = 10
        vm.currentFrameIndex = 9
        vm.playbackMode = .once
        vm.playbackState = .playing
        vm.advanceCineFrame()
        #expect(vm.currentFrameIndex == 9)
        #expect(vm.playbackState == .stopped)
    }

    // MARK: - Zoom / Pan / Rotation

    @Test("Zoom in increases zoom level")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testZoomIn() {
        let vm = ImageViewerViewModel()
        let initialZoom = vm.zoomLevel
        vm.zoomIn()
        #expect(vm.zoomLevel > initialZoom)
    }

    @Test("Zoom out decreases zoom level")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testZoomOut() {
        let vm = ImageViewerViewModel()
        let initialZoom = vm.zoomLevel
        vm.zoomOut()
        #expect(vm.zoomLevel < initialZoom)
    }

    @Test("Reset view restores defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetView() {
        let vm = ImageViewerViewModel()
        vm.zoomLevel = 3.0
        vm.panOffsetX = 100
        vm.panOffsetY = -50
        vm.rotationAngle = 90
        vm.resetView()
        #expect(vm.zoomLevel == 1.0)
        #expect(vm.panOffsetX == 0.0)
        #expect(vm.panOffsetY == 0.0)
        #expect(vm.rotationAngle == 0.0)
    }

    @Test("Fit to view adjusts zoom")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFitToView() {
        let vm = ImageViewerViewModel()
        vm.imageColumns = 1024
        vm.imageRows = 512
        vm.fitToView(viewWidth: 800, viewHeight: 600)
        #expect(vm.zoomLevel < 1.0) // image wider than view
        #expect(vm.panOffsetX == 0.0)
        #expect(vm.panOffsetY == 0.0)
    }

    @Test("Rotate clockwise")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRotateClockwise() {
        let vm = ImageViewerViewModel()
        vm.rotateClockwise()
        #expect(vm.rotationAngle == 90)
    }

    @Test("Rotate counter-clockwise")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRotateCounterClockwise() {
        let vm = ImageViewerViewModel()
        vm.rotateCounterClockwise()
        #expect(vm.rotationAngle == 270)
    }

    // MARK: - Display Text Helpers

    @Test("Window level text formatting")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testWindowLevelText() {
        let vm = ImageViewerViewModel()
        vm.windowCenter = 40
        vm.windowWidth = 400
        #expect(vm.windowLevelText == "C: 40 W: 400")
    }

    @Test("Frame text formatting")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFrameText() {
        let vm = ImageViewerViewModel()
        vm.currentFrameIndex = 0
        vm.numberOfFrames = 120
        #expect(vm.frameText == "Frame 1 / 120")
    }

    @Test("Dimensions text formatting")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDimensionsText() {
        let vm = ImageViewerViewModel()
        vm.imageColumns = 512
        vm.imageRows = 512
        #expect(vm.dimensionsText == "512 × 512")
    }

    @Test("Bit depth text formatting")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testBitDepthText() {
        let vm = ImageViewerViewModel()
        vm.bitsAllocated = 16
        vm.bitsStored = 12
        vm.highBit = 11
        #expect(vm.bitDepthText == "16 / 12 / 11")
    }

    @Test("Pixel representation text")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPixelRepresentationText() {
        let vm = ImageViewerViewModel()
        vm.isSigned = true
        #expect(vm.pixelRepresentationText == "Signed")
        vm.isSigned = false
        #expect(vm.pixelRepresentationText == "Unsigned")
    }

    @Test("Photometric label")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPhotometricLabel() {
        let vm = ImageViewerViewModel()
        vm.photometricInterpretation = "MONOCHROME2"
        #expect(vm.photometricLabel == "Monochrome 2")
    }

    @Test("Render time text")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRenderTimeText() {
        let vm = ImageViewerViewModel()
        vm.lastRenderTime = 0.0125
        #expect(vm.renderTimeText == "12.5 ms")
    }

    @Test("Is multi-frame")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsMultiFrame() {
        let vm = ImageViewerViewModel()
        #expect(vm.isMultiFrame == false) // numberOfFrames == 1
        vm.numberOfFrames = 10
        #expect(vm.isMultiFrame == true)
    }

    @Test("Has image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testHasImage() {
        let vm = ImageViewerViewModel()
        #expect(vm.hasImage == false)
    }

    @Test("Is monochrome")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsMonochrome() {
        let vm = ImageViewerViewModel()
        vm.photometricInterpretation = "MONOCHROME2"
        #expect(vm.isMonochrome == true)
        vm.photometricInterpretation = "MONOCHROME1"
        #expect(vm.isMonochrome == true)
        vm.photometricInterpretation = "RGB"
        #expect(vm.isMonochrome == false)
    }

    // MARK: - Load File Error

    @Test("Load nonexistent file sets error")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadFileError() {
        let vm = ImageViewerViewModel()
        vm.loadFile(at: "/nonexistent/file.dcm")
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - Service Injection

    @Test("Custom service injection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCustomServiceInjection() {
        let renderingService = ImageRenderingService()
        let cacheService = ImageCacheService()
        let vm = ImageViewerViewModel(
            renderingService: renderingService,
            cacheService: cacheService
        )
        #expect(vm.renderingService === renderingService)
        #expect(vm.cacheService === cacheService)
    }
}
