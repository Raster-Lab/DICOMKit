// ComparisonViewModel.swift
// DICOMViewer iOS - Comparison View Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftUI
import Observation

/// View model for side-by-side image comparison
///
/// Manages two viewer instances and optional synchronization of their controls.
@MainActor
@Observable
final class ComparisonViewModel {
    // MARK: - Viewer Models
    
    /// Left viewer view model
    var leftViewModel = ViewerViewModel()
    
    /// Right viewer view model
    var rightViewModel = ViewerViewModel()
    
    // MARK: - Synchronization State
    
    /// Whether viewers are synchronized
    var isSynchronized: Bool = true {
        didSet {
            if isSynchronized != oldValue {
                if isSynchronized {
                    // When re-enabling sync, sync right to left
                    syncRightToLeft()
                }
            }
        }
    }
    
    /// Whether to sync frame navigation
    var syncFrames: Bool = true
    
    /// Whether to sync window/level
    var syncWindowLevel: Bool = true
    
    /// Whether to sync zoom and pan
    var syncZoomPan: Bool = true
    
    /// Whether to sync rotation and flip
    var syncTransforms: Bool = true
    
    // MARK: - Observation Tokens
    
    private var leftFrameObserver: Task<Void, Never>?
    private var rightFrameObserver: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Swap the left and right viewers
    func swapViewers() {
        let temp = leftViewModel
        leftViewModel = rightViewModel
        rightViewModel = temp
    }
    
    /// Sync right viewer to left viewer settings
    func syncRightToLeft() {
        guard isSynchronized else { return }
        
        if syncFrames && rightViewModel.frameCount == leftViewModel.frameCount {
            rightViewModel.currentFrame = leftViewModel.currentFrame
        }
        
        if syncWindowLevel {
            rightViewModel.windowCenter = leftViewModel.windowCenter
            rightViewModel.windowWidth = leftViewModel.windowWidth
            rightViewModel.isInverted = leftViewModel.isInverted
        }
        
        if syncZoomPan {
            rightViewModel.zoomScale = leftViewModel.zoomScale
            rightViewModel.panOffset = leftViewModel.panOffset
        }
        
        if syncTransforms {
            rightViewModel.rotationAngle = leftViewModel.rotationAngle
            rightViewModel.isFlippedHorizontal = leftViewModel.isFlippedHorizontal
            rightViewModel.isFlippedVertical = leftViewModel.isFlippedVertical
        }
    }
    
    /// Sync left viewer to right viewer settings
    func syncLeftToRight() {
        guard isSynchronized else { return }
        
        if syncFrames && leftViewModel.frameCount == rightViewModel.frameCount {
            leftViewModel.currentFrame = rightViewModel.currentFrame
        }
        
        if syncWindowLevel {
            leftViewModel.windowCenter = rightViewModel.windowCenter
            leftViewModel.windowWidth = rightViewModel.windowWidth
            leftViewModel.isInverted = rightViewModel.isInverted
        }
        
        if syncZoomPan {
            leftViewModel.zoomScale = rightViewModel.zoomScale
            leftViewModel.panOffset = rightViewModel.panOffset
        }
        
        if syncTransforms {
            leftViewModel.rotationAngle = rightViewModel.rotationAngle
            leftViewModel.isFlippedHorizontal = rightViewModel.isFlippedHorizontal
            leftViewModel.isFlippedVertical = rightViewModel.isFlippedVertical
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // In a production app, we would use Combine or observation patterns
        // For now, synchronization happens through explicit method calls
        // when the user interacts with either viewer
    }
}
