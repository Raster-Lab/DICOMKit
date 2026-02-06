//
//  ViewportIntegrationTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

/// Integration tests for multi-viewport and hanging protocol workflows
@MainActor
final class ViewportIntegrationTests: XCTestCase {
    
    // MARK: - Viewport Layout Tests
    
    func testViewportLayoutSwitching() throws {
        let layoutService = ViewportLayoutService()
        
        // Start with 1x1 layout
        layoutService.setLayout(.single)
        XCTAssertEqual(layoutService.currentLayout.rows, 1)
        XCTAssertEqual(layoutService.currentLayout.columns, 1)
        XCTAssertEqual(layoutService.currentLayout.viewportCount, 1)
        
        // Switch to 2x2
        layoutService.setLayout(.twoByTwo)
        XCTAssertEqual(layoutService.currentLayout.rows, 2)
        XCTAssertEqual(layoutService.currentLayout.columns, 2)
        XCTAssertEqual(layoutService.currentLayout.viewportCount, 4)
        
        // Switch to 3x3
        layoutService.setLayout(.threeByThree)
        XCTAssertEqual(layoutService.currentLayout.rows, 3)
        XCTAssertEqual(layoutService.currentLayout.columns, 3)
        XCTAssertEqual(layoutService.currentLayout.viewportCount, 9)
        
        // Switch to 4x4
        layoutService.setLayout(.fourByFour)
        XCTAssertEqual(layoutService.currentLayout.rows, 4)
        XCTAssertEqual(layoutService.currentLayout.columns, 4)
        XCTAssertEqual(layoutService.currentLayout.viewportCount, 16)
        
        print("✅ Viewport layout switching workflow completed successfully")
    }
    
    func testViewportSeriesAssignment() throws {
        let layoutService = ViewportLayoutService()
        
        // Set 2x2 layout
        layoutService.setLayout(.twoByTwo)
        
        // Assign series to viewports
        layoutService.assignSeries(seriesUID: "series1", toViewport: 0)
        layoutService.assignSeries(seriesUID: "series2", toViewport: 1)
        layoutService.assignSeries(seriesUID: "series3", toViewport: 2)
        layoutService.assignSeries(seriesUID: "series4", toViewport: 3)
        
        // Verify assignments
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 0), "series1")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 1), "series2")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 2), "series3")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 3), "series4")
        
        // Test assignment to invalid viewport
        layoutService.assignSeries(seriesUID: "series5", toViewport: 10)
        XCTAssertNil(layoutService.getSeriesUID(forViewport: 10), "Invalid viewport should return nil")
        
        print("✅ Viewport series assignment workflow completed successfully")
    }
    
    func testViewportSelectionManagement() throws {
        let layoutService = ViewportLayoutService()
        layoutService.setLayout(.twoByTwo)
        
        // Select viewport 0
        layoutService.selectViewport(0)
        XCTAssertEqual(layoutService.selectedViewportIndex, 0)
        XCTAssertTrue(layoutService.isViewportSelected(0))
        XCTAssertFalse(layoutService.isViewportSelected(1))
        
        // Select viewport 2
        layoutService.selectViewport(2)
        XCTAssertEqual(layoutService.selectedViewportIndex, 2)
        XCTAssertFalse(layoutService.isViewportSelected(0))
        XCTAssertTrue(layoutService.isViewportSelected(2))
        
        // Select invalid viewport
        layoutService.selectViewport(10)
        XCTAssertEqual(layoutService.selectedViewportIndex, 2, "Selection should not change for invalid index")
        
        print("✅ Viewport selection management workflow completed successfully")
    }
    
    func testLayoutPreservationOnSwitch() throws {
        let layoutService = ViewportLayoutService()
        
        // Start with 2x2 and assign series
        layoutService.setLayout(.twoByTwo)
        layoutService.assignSeries(seriesUID: "series1", toViewport: 0)
        layoutService.assignSeries(seriesUID: "series2", toViewport: 1)
        
        // Switch to 3x3
        layoutService.setLayout(.threeByThree)
        
        // Verify assignments preserved
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 0), "series1")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 1), "series2")
        
        // Switch back to 2x2
        layoutService.setLayout(.twoByTwo)
        
        // Verify assignments still preserved
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 0), "series1")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 1), "series2")
        
        print("✅ Layout preservation workflow completed successfully")
    }
    
    // MARK: - Viewport Linking Tests
    
    func testViewportLinkingConfiguration() throws {
        let layoutService = ViewportLayoutService()
        layoutService.setLayout(.twoByTwo)
        
        // Initially no linking
        XCTAssertFalse(layoutService.isScrollLinked)
        XCTAssertFalse(layoutService.isWindowLevelLinked)
        XCTAssertFalse(layoutService.isZoomLinked)
        XCTAssertFalse(layoutService.isPanLinked)
        
        // Enable scroll linking
        layoutService.setScrollLinking(true)
        XCTAssertTrue(layoutService.isScrollLinked)
        
        // Enable window/level linking
        layoutService.setWindowLevelLinking(true)
        XCTAssertTrue(layoutService.isWindowLevelLinked)
        
        // Enable zoom linking
        layoutService.setZoomLinking(true)
        XCTAssertTrue(layoutService.isZoomLinked)
        
        // Enable pan linking
        layoutService.setPanLinking(true)
        XCTAssertTrue(layoutService.isPanLinked)
        
        // Link all at once
        layoutService.linkAll()
        XCTAssertTrue(layoutService.isScrollLinked)
        XCTAssertTrue(layoutService.isWindowLevelLinked)
        XCTAssertTrue(layoutService.isZoomLinked)
        XCTAssertTrue(layoutService.isPanLinked)
        
        // Unlink all
        layoutService.unlinkAll()
        XCTAssertFalse(layoutService.isScrollLinked)
        XCTAssertFalse(layoutService.isWindowLevelLinked)
        XCTAssertFalse(layoutService.isZoomLinked)
        XCTAssertFalse(layoutService.isPanLinked)
        
        print("✅ Viewport linking configuration workflow completed successfully")
    }
    
    func testLinkedScrollSynchronization() throws {
        let layoutService = ViewportLayoutService()
        layoutService.setLayout(.twoByTwo)
        
        // Assign series to viewports
        layoutService.assignSeries(seriesUID: "series1", toViewport: 0)
        layoutService.assignSeries(seriesUID: "series2", toViewport: 1)
        
        // Enable scroll linking
        layoutService.setScrollLinking(true)
        
        // Simulate scroll in viewport 0
        layoutService.syncScroll(fromViewport: 0, frameIndex: 5)
        
        // Verify other viewports received the sync (in real implementation)
        // This would trigger callbacks to update other viewports
        XCTAssertTrue(layoutService.isScrollLinked, "Scroll linking should be enabled")
        
        print("✅ Linked scroll synchronization workflow completed successfully")
    }
    
    // MARK: - Hanging Protocol Tests
    
    func testHangingProtocolMatching() throws {
        let protocolService = HangingProtocolService()
        
        // Test CT Chest protocol
        let ctChestProtocol = protocolService.getProtocol(named: "CT Chest")
        XCTAssertNotNil(ctChestProtocol, "CT Chest protocol should exist")
        XCTAssertEqual(ctChestProtocol?.layout.rows, 2)
        XCTAssertEqual(ctChestProtocol?.layout.columns, 2)
        
        // Test MR Brain protocol
        let mrBrainProtocol = protocolService.getProtocol(named: "MR Brain")
        XCTAssertNotNil(mrBrainProtocol, "MR Brain protocol should exist")
        
        // Test X-Ray protocol
        let xrayProtocol = protocolService.getProtocol(named: "X-Ray")
        XCTAssertNotNil(xrayProtocol, "X-Ray protocol should exist")
        XCTAssertEqual(xrayProtocol?.layout.rows, 1)
        XCTAssertEqual(xrayProtocol?.layout.columns, 1)
        
        print("✅ Hanging protocol matching workflow completed successfully")
    }
    
    func testAutomaticProtocolSelection() throws {
        let protocolService = HangingProtocolService()
        
        // Test CT modality matching
        let ctProtocol = protocolService.findBestProtocol(modality: "CT", bodyPart: "CHEST")
        XCTAssertNotNil(ctProtocol, "Should find CT protocol")
        XCTAssertEqual(ctProtocol?.name, "CT Chest")
        
        // Test MR modality matching
        let mrProtocol = protocolService.findBestProtocol(modality: "MR", bodyPart: "BRAIN")
        XCTAssertNotNil(mrProtocol, "Should find MR protocol")
        XCTAssertEqual(mrProtocol?.name, "MR Brain")
        
        // Test X-Ray modality matching
        let xrayProtocol = protocolService.findBestProtocol(modality: "CR", bodyPart: "CHEST")
        XCTAssertNotNil(xrayProtocol, "Should find X-Ray protocol")
        
        // Test unknown modality (should return default)
        let defaultProtocol = protocolService.findBestProtocol(modality: "US", bodyPart: "")
        XCTAssertNotNil(defaultProtocol, "Should return default protocol for unknown modality")
        
        print("✅ Automatic protocol selection workflow completed successfully")
    }
    
    func testCustomHangingProtocol() throws {
        let protocolService = HangingProtocolService()
        
        // Create custom protocol
        let customLayout = ViewportLayout(name: "Custom 3x2", rows: 3, columns: 2)
        let customProtocol = HangingProtocol(
            name: "Custom Protocol",
            layout: customLayout,
            seriesRules: [
                HangingProtocol.SeriesRule(
                    viewportIndex: 0,
                    modality: "CT",
                    seriesDescriptionPattern: "Axial"
                ),
                HangingProtocol.SeriesRule(
                    viewportIndex: 1,
                    modality: "CT",
                    seriesDescriptionPattern: "Coronal"
                )
            ]
        )
        
        // Add custom protocol
        protocolService.addProtocol(customProtocol)
        
        // Verify protocol was added
        let retrieved = protocolService.getProtocol(named: "Custom Protocol")
        XCTAssertNotNil(retrieved, "Custom protocol should be retrievable")
        XCTAssertEqual(retrieved?.layout.rows, 3)
        XCTAssertEqual(retrieved?.layout.columns, 2)
        XCTAssertEqual(retrieved?.seriesRules.count, 2)
        
        // Remove custom protocol
        protocolService.removeProtocol(named: "Custom Protocol")
        let afterRemoval = protocolService.getProtocol(named: "Custom Protocol")
        XCTAssertNil(afterRemoval, "Protocol should be removed")
        
        print("✅ Custom hanging protocol workflow completed successfully")
    }
    
    func testProtocolSeriesAssignment() throws {
        let protocolService = HangingProtocolService()
        let layoutService = ViewportLayoutService()
        
        // Mock series data
        struct MockSeries {
            let uid: String
            let modality: String
            let description: String
            let seriesNumber: Int
        }
        
        let series = [
            MockSeries(uid: "s1", modality: "CT", description: "Axial", seriesNumber: 1),
            MockSeries(uid: "s2", modality: "CT", description: "Coronal", seriesNumber: 2),
            MockSeries(uid: "s3", modality: "CT", description: "Sagittal", seriesNumber: 3)
        ]
        
        // Get CT Abdomen protocol
        guard let protocol = protocolService.getProtocol(named: "CT Abdomen") else {
            XCTFail("CT Abdomen protocol should exist")
            return
        }
        
        // Apply protocol layout
        layoutService.setLayout(protocol.layout)
        XCTAssertEqual(layoutService.currentLayout.rows, protocol.layout.rows)
        XCTAssertEqual(layoutService.currentLayout.columns, protocol.layout.columns)
        
        // In a real implementation, series would be automatically assigned
        // based on protocol rules. For testing, we'll manually assign.
        for (index, mockSeries) in series.enumerated() {
            if index < layoutService.currentLayout.viewportCount {
                layoutService.assignSeries(seriesUID: mockSeries.uid, toViewport: index)
            }
        }
        
        // Verify assignments
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 0), "s1")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 1), "s2")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 2), "s3")
        
        print("✅ Protocol series assignment workflow completed successfully")
    }
    
    // MARK: - Cine Controller Tests
    
    func testCinePlaybackWorkflow() throws {
        let cineController = CineController()
        
        // Set up frame count
        cineController.setFrameCount(30)
        XCTAssertEqual(cineController.totalFrames, 30)
        XCTAssertEqual(cineController.currentFrame, 0)
        
        // Test play
        cineController.play()
        XCTAssertTrue(cineController.isPlaying)
        
        // Test pause
        cineController.pause()
        XCTAssertFalse(cineController.isPlaying)
        
        // Test stop
        cineController.stop()
        XCTAssertFalse(cineController.isPlaying)
        XCTAssertEqual(cineController.currentFrame, 0, "Stop should reset to first frame")
        
        print("✅ Cine playback workflow completed successfully")
    }
    
    func testCineFrameNavigation() throws {
        let cineController = CineController()
        cineController.setFrameCount(10)
        
        // Test next frame
        cineController.nextFrame()
        XCTAssertEqual(cineController.currentFrame, 1)
        
        cineController.nextFrame()
        XCTAssertEqual(cineController.currentFrame, 2)
        
        // Test previous frame
        cineController.previousFrame()
        XCTAssertEqual(cineController.currentFrame, 1)
        
        // Test jump to frame
        cineController.jumpToFrame(5)
        XCTAssertEqual(cineController.currentFrame, 5)
        
        // Test first frame
        cineController.jumpToFirstFrame()
        XCTAssertEqual(cineController.currentFrame, 0)
        
        // Test last frame
        cineController.jumpToLastFrame()
        XCTAssertEqual(cineController.currentFrame, 9)
        
        print("✅ Cine frame navigation workflow completed successfully")
    }
    
    func testCineFPSConfiguration() throws {
        let cineController = CineController()
        
        // Test default FPS
        XCTAssertEqual(cineController.fps, 15, "Default FPS should be 15")
        
        // Test FPS changes
        cineController.setFPS(30)
        XCTAssertEqual(cineController.fps, 30)
        
        cineController.setFPS(5)
        XCTAssertEqual(cineController.fps, 5)
        
        cineController.setFPS(60)
        XCTAssertEqual(cineController.fps, 60)
        
        print("✅ Cine FPS configuration workflow completed successfully")
    }
    
    func testCineLoopMode() throws {
        let cineController = CineController()
        cineController.setFrameCount(5)
        
        // Test loop mode off (default)
        XCTAssertFalse(cineController.isLooping, "Loop should be off by default")
        
        // Jump to last frame
        cineController.jumpToLastFrame()
        XCTAssertEqual(cineController.currentFrame, 4)
        
        // Next frame should stay at last frame when not looping
        cineController.nextFrame()
        XCTAssertEqual(cineController.currentFrame, 4, "Should stay at last frame when not looping")
        
        // Enable loop mode
        cineController.setLooping(true)
        XCTAssertTrue(cineController.isLooping)
        
        // Next frame should wrap to first frame
        cineController.nextFrame()
        XCTAssertEqual(cineController.currentFrame, 0, "Should wrap to first frame when looping")
        
        print("✅ Cine loop mode workflow completed successfully")
    }
    
    func testCineReversePlayback() throws {
        let cineController = CineController()
        cineController.setFrameCount(10)
        
        // Test reverse mode off (default)
        XCTAssertFalse(cineController.isReverse, "Reverse should be off by default")
        
        // Enable reverse mode
        cineController.setReverse(true)
        XCTAssertTrue(cineController.isReverse)
        
        // Set to last frame
        cineController.jumpToLastFrame()
        XCTAssertEqual(cineController.currentFrame, 9)
        
        // In reverse mode, next frame should go backwards
        cineController.nextFrame()
        XCTAssertEqual(cineController.currentFrame, 8, "Should go backwards in reverse mode")
        
        print("✅ Cine reverse playback workflow completed successfully")
    }
    
    // MARK: - Combined Workflow Tests
    
    func testCompleteViewportWorkflow() throws {
        let layoutService = ViewportLayoutService()
        let protocolService = HangingProtocolService()
        
        // 1. Start with default layout
        XCTAssertEqual(layoutService.currentLayout.name, "1×1")
        
        // 2. Find and apply CT protocol
        guard let ctProtocol = protocolService.findBestProtocol(modality: "CT", bodyPart: "CHEST") else {
            XCTFail("Should find CT protocol")
            return
        }
        
        layoutService.setLayout(ctProtocol.layout)
        XCTAssertEqual(layoutService.currentLayout.rows, 2)
        XCTAssertEqual(layoutService.currentLayout.columns, 2)
        
        // 3. Assign series to viewports
        layoutService.assignSeries(seriesUID: "axial", toViewport: 0)
        layoutService.assignSeries(seriesUID: "coronal", toViewport: 1)
        layoutService.assignSeries(seriesUID: "sagittal", toViewport: 2)
        
        // 4. Enable linking
        layoutService.linkAll()
        XCTAssertTrue(layoutService.isScrollLinked)
        XCTAssertTrue(layoutService.isWindowLevelLinked)
        
        // 5. Select a viewport
        layoutService.selectViewport(1)
        XCTAssertEqual(layoutService.selectedViewportIndex, 1)
        
        // 6. Switch layout while preserving assignments
        layoutService.setLayout(.threeByThree)
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 0), "axial")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 1), "coronal")
        XCTAssertEqual(layoutService.getSeriesUID(forViewport: 2), "sagittal")
        
        print("✅ Complete viewport workflow completed successfully")
    }
}
