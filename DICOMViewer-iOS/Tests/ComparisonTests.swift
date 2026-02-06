// ComparisonTests.swift
// DICOMViewer iOS - Comparison View Model Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer

/// Tests for ComparisonViewModel synchronization logic
@MainActor
final class ComparisonTests: XCTestCase {
    
    var viewModel: ComparisonViewModel!
    
    override func setUp() async throws {
        viewModel = ComparisonViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.isSynchronized, "Viewers should be synchronized by default")
        XCTAssertTrue(viewModel.syncFrames, "Frame sync should be enabled by default")
        XCTAssertTrue(viewModel.syncWindowLevel, "W/L sync should be enabled by default")
        XCTAssertTrue(viewModel.syncZoomPan, "Zoom/pan sync should be enabled by default")
        XCTAssertTrue(viewModel.syncTransforms, "Transform sync should be enabled by default")
    }
    
    // MARK: - Window/Level Sync Tests
    
    func testSyncWindowLevelRightToLeft() {
        // Given: Different window/level settings
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.leftViewModel.windowWidth = 200.0
        viewModel.rightViewModel.windowCenter = 150.0
        viewModel.rightViewModel.windowWidth = 300.0
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 100.0)
        XCTAssertEqual(viewModel.rightViewModel.windowWidth, 200.0)
    }
    
    func testSyncWindowLevelLeftToRight() {
        // Given: Different window/level settings
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.leftViewModel.windowWidth = 200.0
        viewModel.rightViewModel.windowCenter = 150.0
        viewModel.rightViewModel.windowWidth = 300.0
        
        // When: Sync left to right
        viewModel.syncLeftToRight()
        
        // Then: Left should match right
        XCTAssertEqual(viewModel.leftViewModel.windowCenter, 150.0)
        XCTAssertEqual(viewModel.leftViewModel.windowWidth, 300.0)
    }
    
    func testSyncInvertFlag() {
        // Given: Different invert settings
        viewModel.leftViewModel.isInverted = true
        viewModel.rightViewModel.isInverted = false
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertTrue(viewModel.rightViewModel.isInverted)
    }
    
    // MARK: - Zoom/Pan Sync Tests
    
    func testSyncZoomScale() {
        // Given: Different zoom scales
        viewModel.leftViewModel.zoomScale = 2.0
        viewModel.rightViewModel.zoomScale = 1.5
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertEqual(viewModel.rightViewModel.zoomScale, 2.0)
    }
    
    func testSyncPanOffset() {
        // Given: Different pan offsets
        viewModel.leftViewModel.panOffset = CGSize(width: 50, height: 100)
        viewModel.rightViewModel.panOffset = CGSize(width: 20, height: 30)
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertEqual(viewModel.rightViewModel.panOffset.width, 50)
        XCTAssertEqual(viewModel.rightViewModel.panOffset.height, 100)
    }
    
    // MARK: - Transform Sync Tests
    
    func testSyncRotation() {
        // Given: Different rotation angles
        viewModel.leftViewModel.rotationAngle = 90.0
        viewModel.rightViewModel.rotationAngle = 0.0
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertEqual(viewModel.rightViewModel.rotationAngle, 90.0)
    }
    
    func testSyncFlipHorizontal() {
        // Given: Different flip settings
        viewModel.leftViewModel.isFlippedHorizontal = true
        viewModel.rightViewModel.isFlippedHorizontal = false
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertTrue(viewModel.rightViewModel.isFlippedHorizontal)
    }
    
    func testSyncFlipVertical() {
        // Given: Different flip settings
        viewModel.leftViewModel.isFlippedVertical = true
        viewModel.rightViewModel.isFlippedVertical = false
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertTrue(viewModel.rightViewModel.isFlippedVertical)
    }
    
    // MARK: - Frame Sync Tests
    
    func testSyncFramesSameFrameCount() {
        // Given: Same frame count
        viewModel.leftViewModel.frameCount = 10
        viewModel.rightViewModel.frameCount = 10
        viewModel.leftViewModel.currentFrame = 5
        viewModel.rightViewModel.currentFrame = 2
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right should match left
        XCTAssertEqual(viewModel.rightViewModel.currentFrame, 5)
    }
    
    func testSyncFramesDifferentFrameCount() {
        // Given: Different frame counts
        viewModel.leftViewModel.frameCount = 10
        viewModel.rightViewModel.frameCount = 20
        viewModel.leftViewModel.currentFrame = 5
        viewModel.rightViewModel.currentFrame = 10
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Right frame should NOT be synced (different frame count)
        XCTAssertEqual(viewModel.rightViewModel.currentFrame, 10)
    }
    
    // MARK: - Selective Sync Tests
    
    func testSelectiveSyncWindowLevel() {
        // Given: Sync only W/L
        viewModel.syncFrames = false
        viewModel.syncWindowLevel = true
        viewModel.syncZoomPan = false
        viewModel.syncTransforms = false
        
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.leftViewModel.zoomScale = 2.0
        viewModel.rightViewModel.windowCenter = 150.0
        viewModel.rightViewModel.zoomScale = 1.5
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Only W/L should be synced
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 100.0)
        XCTAssertEqual(viewModel.rightViewModel.zoomScale, 1.5) // Unchanged
    }
    
    func testSelectiveSyncZoomPan() {
        // Given: Sync only zoom/pan
        viewModel.syncFrames = false
        viewModel.syncWindowLevel = false
        viewModel.syncZoomPan = true
        viewModel.syncTransforms = false
        
        viewModel.leftViewModel.zoomScale = 2.0
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.rightViewModel.zoomScale = 1.5
        viewModel.rightViewModel.windowCenter = 150.0
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Only zoom/pan should be synced
        XCTAssertEqual(viewModel.rightViewModel.zoomScale, 2.0)
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 150.0) // Unchanged
    }
    
    // MARK: - Synchronization Toggle Tests
    
    func testDisableSynchronization() {
        // Given: Synchronized viewers with different settings
        viewModel.isSynchronized = true
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.rightViewModel.windowCenter = 150.0
        
        // When: Disable synchronization
        viewModel.isSynchronized = false
        viewModel.leftViewModel.windowCenter = 200.0
        
        // Then: Right should not be affected
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 150.0)
    }
    
    func testEnableSynchronization() {
        // Given: Unsynchronized viewers with different settings
        viewModel.isSynchronized = false
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.rightViewModel.windowCenter = 150.0
        
        // When: Enable synchronization
        viewModel.isSynchronized = true
        
        // Then: Right should sync to left automatically
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 100.0)
    }
    
    // MARK: - Swap Tests
    
    func testSwapViewers() {
        // Given: Different settings
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.rightViewModel.windowCenter = 150.0
        
        // When: Swap viewers
        viewModel.swapViewers()
        
        // Then: Settings should be swapped
        XCTAssertEqual(viewModel.leftViewModel.windowCenter, 150.0)
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 100.0)
    }
    
    // MARK: - Edge Cases
    
    func testSyncWithNoSynchronizationEnabled() {
        // Given: All sync options disabled
        viewModel.syncFrames = false
        viewModel.syncWindowLevel = false
        viewModel.syncZoomPan = false
        viewModel.syncTransforms = false
        
        viewModel.leftViewModel.windowCenter = 100.0
        viewModel.leftViewModel.zoomScale = 2.0
        viewModel.rightViewModel.windowCenter = 150.0
        viewModel.rightViewModel.zoomScale = 1.5
        
        // When: Sync right to left
        viewModel.syncRightToLeft()
        
        // Then: Nothing should be synced
        XCTAssertEqual(viewModel.rightViewModel.windowCenter, 150.0)
        XCTAssertEqual(viewModel.rightViewModel.zoomScale, 1.5)
    }
}
