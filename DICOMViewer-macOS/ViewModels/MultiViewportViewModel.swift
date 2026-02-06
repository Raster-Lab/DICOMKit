//
//  MultiViewportViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit
import DICOMKit
import DICOMCore

/// ViewModel for multi-viewport image viewer
@MainActor
@Observable
final class MultiViewportViewModel {
    // MARK: - Properties
    
    /// Current study being viewed
    private(set) var study: DicomStudy?
    
    /// All series in the study
    private(set) var allSeries: [DicomSeries] = []
    
    /// Layout service
    let layoutService = ViewportLayoutService()
    
    /// Hanging protocol service
    let protocolService = HangingProtocolService()
    
    /// Cine controller
    let cineController = CineController()
    
    /// Viewport-specific view models
    private(set) var viewportViewModels: [UUID: ImageViewerViewModel] = [:]
    
    /// Shared window/level values (when linking is enabled)
    var sharedWindowCenter: Double = 128.0
    var sharedWindowWidth: Double = 256.0
    
    /// Shared zoom level (when linking is enabled)
    var sharedZoomLevel: Double = 1.0
    
    /// Shared pan offset (when linking is enabled)
    var sharedPanOffset: CGSize = .zero
    
    /// Loading state
    private(set) var isLoading = false
    
    /// Error message
    var errorMessage: String?
    
    // MARK: - Services
    
    private let databaseService = DatabaseService.shared
    
    // MARK: - Initialization
    
    init() {
        // Initialize view models for initial viewport
        updateViewportViewModels()
    }
    
    // MARK: - Study Loading
    
    /// Load a study for viewing
    func loadStudy(_ study: DicomStudy) async {
        self.study = study
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all series for the study
            allSeries = try databaseService.fetchSeries(forStudy: study.studyInstanceUID)
            
            // Try to find and apply matching hanging protocol
            if let protocol = protocolService.findMatchingProtocol(for: study) {
                protocolService.applyProtocol(`protocol`, series: allSeries, layoutService: layoutService)
            } else {
                // Default: single viewport with first series
                layoutService.setLayout(.single)
                if let firstSeries = allSeries.first {
                    layoutService.assignSeries(firstSeries, to: layoutService.viewports[0].id)
                }
            }
            
            // Update view models
            updateViewportViewModels()
            
            // Load images for all viewports
            await loadAllViewportImages()
        } catch {
            errorMessage = "Failed to load study: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load images for all viewports
    private func loadAllViewportImages() async {
        for viewport in layoutService.viewports {
            if let series = viewport.series,
               let viewModel = viewportViewModels[viewport.id] {
                await viewModel.loadSeries(series)
            }
        }
    }
    
    // MARK: - Layout Management
    
    /// Change viewport layout
    func setLayout(_ layout: ViewportLayout) {
        layoutService.setLayout(layout)
        updateViewportViewModels()
    }
    
    /// Apply hanging protocol
    func applyHangingProtocol(_ protocol: HangingProtocol) {
        protocolService.applyProtocol(`protocol`, series: allSeries, layoutService: layoutService)
        updateViewportViewModels()
        
        Task {
            await loadAllViewportImages()
        }
    }
    
    // MARK: - Viewport Management
    
    /// Assign series to viewport
    func assignSeries(_ series: DicomSeries, to viewportId: UUID) {
        layoutService.assignSeries(series, to: viewportId)
        
        // Load the series in the viewport
        if let viewModel = viewportViewModels[viewportId] {
            Task {
                await viewModel.loadSeries(series)
            }
        }
    }
    
    /// Get view model for viewport
    func viewModel(for viewportId: UUID) -> ImageViewerViewModel? {
        return viewportViewModels[viewportId]
    }
    
    /// Update viewport view models when layout changes
    private func updateViewportViewModels() {
        // Remove view models for viewports that no longer exist
        let currentViewportIds = Set(layoutService.viewports.map { $0.id })
        viewportViewModels = viewportViewModels.filter { currentViewportIds.contains($0.key) }
        
        // Create view models for new viewports
        for viewport in layoutService.viewports {
            if viewportViewModels[viewport.id] == nil {
                viewportViewModels[viewport.id] = ImageViewerViewModel()
            }
        }
    }
    
    // MARK: - Viewport Linking
    
    /// Update shared window/level and propagate to linked viewports
    func updateSharedWindowLevel(center: Double, width: Double) {
        guard layoutService.linking.windowLevelEnabled else { return }
        
        sharedWindowCenter = center
        sharedWindowWidth = width
        
        // Apply to all viewports
        for viewModel in viewportViewModels.values {
            viewModel.windowCenter = center
            viewModel.windowWidth = width
        }
    }
    
    /// Update shared zoom and propagate to linked viewports
    func updateSharedZoom(_ zoom: Double) {
        guard layoutService.linking.zoomEnabled else { return }
        
        sharedZoomLevel = zoom
        
        // Apply to all viewports
        for viewModel in viewportViewModels.values {
            viewModel.zoomLevel = zoom
        }
    }
    
    /// Update shared pan and propagate to linked viewports
    func updateSharedPan(_ offset: CGSize) {
        guard layoutService.linking.panEnabled else { return }
        
        sharedPanOffset = offset
        
        // Apply to all viewports
        for viewModel in viewportViewModels.values {
            viewModel.panOffset = offset
        }
    }
    
    // MARK: - Cine Playback
    
    /// Start cine playback for selected viewport
    func startCine() {
        guard let selectedId = layoutService.selectedViewportId,
              let viewModel = viewportViewModels[selectedId] else {
            return
        }
        
        cineController.setTotalFrames(viewModel.instances.count)
        cineController.currentFrame = viewModel.currentIndex
        cineController.play()
        
        // Observe cine controller frame changes
        observeCineFrameChanges(for: selectedId)
    }
    
    private func observeCineFrameChanges(for viewportId: UUID) {
        // This would use Combine in a production app
        // For now, the view will observe the cine controller directly
    }
}
