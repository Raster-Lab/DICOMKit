//
//  CineControllerTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

@MainActor
final class CineControllerTests: XCTestCase {
    
    var controller: CineController!
    
    override func setUp() async throws {
        controller = CineController()
        controller.setTotalFrames(10)
    }
    
    override func tearDown() async throws {
        controller = nil
    }
    
    func testInitialState() {
        XCTAssertEqual(controller.state, .stopped)
        XCTAssertEqual(controller.currentFrame, 0)
        XCTAssertEqual(controller.framesPerSecond, 10.0)
        XCTAssertTrue(controller.loopEnabled)
        XCTAssertFalse(controller.reversePlayback)
    }
    
    func testSetTotalFrames() {
        controller.setTotalFrames(20)
        
        XCTAssertEqual(controller.totalFrames, 20)
    }
    
    func testNextFrame() {
        controller.currentFrame = 0
        controller.nextFrame()
        
        XCTAssertEqual(controller.currentFrame, 1)
    }
    
    func testPreviousFrame() {
        controller.currentFrame = 5
        controller.previousFrame()
        
        XCTAssertEqual(controller.currentFrame, 4)
    }
    
    func testGoToFirstFrame() {
        controller.currentFrame = 5
        controller.goToFirstFrame()
        
        XCTAssertEqual(controller.currentFrame, 0)
    }
    
    func testGoToLastFrame() {
        controller.goToLastFrame()
        
        XCTAssertEqual(controller.currentFrame, 9)
    }
    
    func testGoToFrame() {
        controller.goToFrame(5)
        
        XCTAssertEqual(controller.currentFrame, 5)
    }
    
    func testGoToFrameOutOfBounds() {
        controller.goToFrame(100)
        
        // Should not change frame if out of bounds
        XCTAssertEqual(controller.currentFrame, 0)
    }
    
    func testNextFrameWithLooping() {
        controller.currentFrame = 9 // Last frame
        controller.loopEnabled = true
        controller.nextFrame()
        
        XCTAssertEqual(controller.currentFrame, 0)
    }
    
    func testNextFrameWithoutLooping() {
        controller.currentFrame = 9 // Last frame
        controller.loopEnabled = false
        controller.nextFrame()
        
        XCTAssertEqual(controller.currentFrame, 9) // Should stay at last frame
    }
    
    func testPreviousFrameWithLooping() {
        controller.currentFrame = 0 // First frame
        controller.loopEnabled = true
        controller.previousFrame()
        
        XCTAssertEqual(controller.currentFrame, 9)
    }
    
    func testPreviousFrameWithoutLooping() {
        controller.currentFrame = 0 // First frame
        controller.loopEnabled = false
        controller.previousFrame()
        
        XCTAssertEqual(controller.currentFrame, 0) // Should stay at first frame
    }
    
    func testSetFramesPerSecond() {
        controller.setFramesPerSecond(30.0)
        
        XCTAssertEqual(controller.framesPerSecond, 30.0)
    }
    
    func testSetFramesPerSecondClamp() {
        // Test minimum
        controller.setFramesPerSecond(0.5)
        XCTAssertEqual(controller.framesPerSecond, 1.0)
        
        // Test maximum
        controller.setFramesPerSecond(200.0)
        XCTAssertEqual(controller.framesPerSecond, 120.0)
    }
    
    func testPlayChangesState() {
        controller.play()
        
        XCTAssertEqual(controller.state, .playing)
    }
    
    func testPauseChangesState() {
        controller.play()
        controller.pause()
        
        XCTAssertEqual(controller.state, .paused)
    }
    
    func testStopResetsFrame() {
        controller.currentFrame = 5
        controller.play()
        controller.stop()
        
        XCTAssertEqual(controller.state, .stopped)
        XCTAssertEqual(controller.currentFrame, 0)
    }
    
    func testTogglePlayPauseFromStopped() {
        controller.togglePlayPause()
        
        XCTAssertEqual(controller.state, .playing)
    }
    
    func testTogglePlayPauseFromPlaying() {
        controller.play()
        controller.togglePlayPause()
        
        XCTAssertEqual(controller.state, .paused)
    }
    
    func testTogglePlayPauseFromPaused() {
        controller.play()
        controller.pause()
        controller.togglePlayPause()
        
        XCTAssertEqual(controller.state, .playing)
    }
}
