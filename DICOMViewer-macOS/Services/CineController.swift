//
//  CineController.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import Combine

/// Controller for cine playback of multi-frame series
@MainActor
final class CineController: ObservableObject {
    // MARK: - Types
    
    enum PlaybackState: Equatable {
        case stopped
        case playing
        case paused
    }
    
    // MARK: - Properties
    
    /// Current playback state
    @Published var state: PlaybackState = .stopped
    
    /// Frames per second
    @Published var framesPerSecond: Double = 10.0
    
    /// Current frame index
    @Published var currentFrame: Int = 0
    
    /// Total number of frames
    var totalFrames: Int = 0
    
    /// Whether to loop playback
    @Published var loopEnabled: Bool = true
    
    /// Whether to play in reverse
    @Published var reversePlayback: Bool = false
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var frameInterval: TimeInterval {
        1.0 / framesPerSecond
    }
    
    // MARK: - Playback Control
    
    /// Start playback
    func play() {
        guard totalFrames > 1 else { return }
        
        state = .playing
        startTimer()
    }
    
    /// Pause playback
    func pause() {
        guard state == .playing else { return }
        
        state = .paused
        stopTimer()
    }
    
    /// Stop playback and reset to first frame
    func stop() {
        state = .stopped
        stopTimer()
        currentFrame = 0
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        switch state {
        case .stopped, .paused:
            play()
        case .playing:
            pause()
        }
    }
    
    /// Go to next frame
    func nextFrame() {
        if currentFrame < totalFrames - 1 {
            currentFrame += 1
        } else if loopEnabled {
            currentFrame = 0
        }
    }
    
    /// Go to previous frame
    func previousFrame() {
        if currentFrame > 0 {
            currentFrame -= 1
        } else if loopEnabled {
            currentFrame = totalFrames - 1
        }
    }
    
    /// Go to first frame
    func goToFirstFrame() {
        currentFrame = 0
    }
    
    /// Go to last frame
    func goToLastFrame() {
        currentFrame = max(0, totalFrames - 1)
    }
    
    /// Go to specific frame
    func goToFrame(_ frame: Int) {
        guard frame >= 0 && frame < totalFrames else { return }
        currentFrame = frame
    }
    
    // MARK: - Configuration
    
    /// Set the number of frames
    func setTotalFrames(_ count: Int) {
        totalFrames = count
        
        // Reset to first frame if current frame is out of bounds
        if currentFrame >= count {
            currentFrame = max(0, count - 1)
        }
    }
    
    /// Set frames per second
    func setFramesPerSecond(_ fps: Double) {
        let wasPlaying = state == .playing
        
        if wasPlaying {
            stopTimer()
        }
        
        framesPerSecond = max(1.0, min(120.0, fps))
        
        if wasPlaying {
            startTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
        
        // Ensure timer runs during UI interactions
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func advanceFrame() {
        if reversePlayback {
            if currentFrame > 0 {
                currentFrame -= 1
            } else if loopEnabled {
                currentFrame = totalFrames - 1
            } else {
                stop()
            }
        } else {
            if currentFrame < totalFrames - 1 {
                currentFrame += 1
            } else if loopEnabled {
                currentFrame = 0
            } else {
                stop()
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopTimer()
    }
}
