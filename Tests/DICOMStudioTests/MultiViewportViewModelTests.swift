// MultiViewportViewModelTests.swift
// DICOMStudioTests
//
// Tests for MultiViewportViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MultiViewportViewModel Tests")
struct MultiViewportViewModelTests {

    @Test("Initial state has single viewport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialState() {
        let vm = MultiViewportViewModel()
        #expect(vm.viewports.count == 1)
        #expect(vm.activeViewportIndex == 0)
        #expect(vm.syncMode == .none)
        #expect(vm.toolMode == .scroll)
        #expect(!vm.showCrossReferenceLines)
    }

    @Test("Setup 2x2 layout")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetupLayout() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        #expect(vm.viewports.count == 4)
        #expect(vm.viewports[0].isActive)
    }

    @Test("Setup from hanging protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetupFromProtocol() {
        let vm = MultiViewportViewModel()
        let proto = HangingProtocolModel(
            name: "Test",
            layoutType: .twoByOne,
            viewportDefinitions: [
                ViewportDefinition(position: 0),
                ViewportDefinition(position: 1, isInitialActive: true)
            ]
        )
        vm.setupFromProtocol(proto)
        #expect(vm.viewports.count == 2)
        #expect(vm.activeViewportIndex == 1)
    }

    @Test("Set active viewport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetActive() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        vm.setActiveViewport(2)
        #expect(vm.activeViewportIndex == 2)
        #expect(vm.viewports[2].isActive)
        #expect(!vm.viewports[0].isActive)
    }

    @Test("Set active viewport out of range does nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetActiveOutOfRange() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        vm.setActiveViewport(10)
        #expect(vm.activeViewportIndex == 0) // unchanged
    }

    @Test("Next viewport cycles")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testNextViewport() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        vm.nextViewport()
        #expect(vm.activeViewportIndex == 1)
        vm.nextViewport()
        vm.nextViewport()
        vm.nextViewport()
        #expect(vm.activeViewportIndex == 0) // wrapped
    }

    @Test("Previous viewport cycles")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPreviousViewport() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        vm.previousViewport()
        #expect(vm.activeViewportIndex == 3) // wrapped to last
    }

    @Test("Active viewport accessor")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testActiveViewport() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        vm.setActiveViewport(2)
        let active = vm.activeViewport
        #expect(active?.position == 2)
    }

    @Test("Scroll active viewport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testScroll() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        vm.viewports[0].numberOfFrames = 10
        vm.scrollActiveViewport(delta: 3)
        #expect(vm.viewports[0].currentFrameIndex == 3)
    }

    @Test("Scroll clamps to range")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testScrollClamped() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        vm.viewports[0].numberOfFrames = 10
        vm.scrollActiveViewport(delta: 100)
        #expect(vm.viewports[0].currentFrameIndex == 9)
    }

    @Test("Synchronized scrolling")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSyncScroll() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByOne)
        vm.viewports[0].numberOfFrames = 10
        vm.viewports[1].numberOfFrames = 20
        vm.syncMode = .scroll

        vm.scrollActiveViewport(delta: 5)
        #expect(vm.viewports[0].currentFrameIndex == 5)
        // Proportional sync: 5/9 * 19 ≈ 10
        #expect(vm.viewports[1].currentFrameIndex > 0)
    }

    @Test("Set window/level")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetWindowLevel() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        vm.setWindowLevel(center: 40, width: 400)
        #expect(vm.viewports[0].windowCenter == 40)
        #expect(vm.viewports[0].windowWidth == 400)
    }

    @Test("Synchronized window/level")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSyncWindowLevel() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByOne)
        vm.syncMode = .windowLevel

        vm.setWindowLevel(center: 40, width: 400)
        #expect(vm.viewports[0].windowCenter == 40)
        #expect(vm.viewports[1].windowCenter == 40)
        #expect(vm.viewports[1].windowWidth == 400)
    }

    @Test("Load into viewport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadIntoViewport() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByOne)
        vm.loadIntoViewport(
            index: 1,
            filePath: "/path/to/image.dcm",
            sopInstanceUID: "1.2.3",
            numberOfFrames: 50
        )
        #expect(vm.viewports[1].filePath == "/path/to/image.dcm")
        #expect(vm.viewports[1].sopInstanceUID == "1.2.3")
        #expect(vm.viewports[1].numberOfFrames == 50)
        #expect(vm.viewports[1].hasImage)
    }

    @Test("Reset viewport")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetViewport() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        vm.viewports[0].zoomLevel = 3.0
        vm.viewports[0].panOffsetX = 100
        vm.resetViewport(0)
        #expect(vm.viewports[0].zoomLevel == 1.0)
        #expect(vm.viewports[0].panOffsetX == 0.0)
    }

    @Test("Tool mode")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToolMode() {
        let vm = MultiViewportViewModel()
        vm.setToolMode(.zoom)
        #expect(vm.toolMode == .zoom)
        #expect(vm.toolModeLabel == "Zoom")
    }

    @Test("Sync mode label")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSyncModeLabel() {
        let vm = MultiViewportViewModel()
        #expect(vm.syncModeLabel == "No Sync")
        vm.syncMode = .all
        #expect(vm.syncModeLabel == "Full Sync")
    }

    @Test("Viewport info text")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testViewportInfoText() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        #expect(vm.viewportInfoText(for: 0) == "Empty")

        vm.loadIntoViewport(index: 0, filePath: "/test.dcm")
        #expect(vm.viewportInfoText(for: 0) == "Loaded")

        vm.viewports[0].numberOfFrames = 10
        #expect(vm.viewportInfoText(for: 0) == "Frame 1/10")
    }

    @Test("Loaded viewport count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadedCount() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.twoByTwo)
        #expect(vm.loadedViewportCount == 0)

        vm.loadIntoViewport(index: 0, filePath: "/a.dcm")
        vm.loadIntoViewport(index: 2, filePath: "/b.dcm")
        #expect(vm.loadedViewportCount == 2)
    }

    @Test("Out of range operations are safe")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOutOfRange() {
        let vm = MultiViewportViewModel()
        vm.setupLayout(.single)
        vm.loadIntoViewport(index: 5, filePath: "/test.dcm")
        vm.resetViewport(5)
        #expect(vm.viewportInfoText(for: 5) == "")
    }
}
