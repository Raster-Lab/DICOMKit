//
//  ViewportLayoutService.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation

/// Service for managing viewport layouts and viewports
@MainActor
final class ViewportLayoutService: ObservableObject {
    // MARK: - Properties
    
    /// Current layout
    @Published var currentLayout: ViewportLayout = .single
    
    /// All viewports in current layout
    @Published var viewports: [Viewport] = [Viewport()]
    
    /// Currently selected viewport
    @Published var selectedViewportId: UUID?
    
    /// Viewport linking settings
    @Published var linking: ViewportLinking = .none
    
    // MARK: - Initialization
    
    init() {
        selectedViewportId = viewports.first?.id
    }
    
    // MARK: - Layout Management
    
    /// Change the viewport layout
    func setLayout(_ layout: ViewportLayout) {
        currentLayout = layout
        
        // Create viewports for new layout
        let newViewports = (0..<layout.viewportCount).map { _ in
            Viewport()
        }
        
        // Copy series from existing viewports where possible
        var updatedViewports: [Viewport] = []
        for (index, newViewport) in newViewports.enumerated() {
            if index < viewports.count {
                // Copy series from old viewport
                var viewport = newViewport
                viewport.series = viewports[index].series
                viewport.currentInstanceIndex = viewports[index].currentInstanceIndex
                updatedViewports.append(viewport)
            } else {
                updatedViewports.append(newViewport)
            }
        }
        
        viewports = updatedViewports
        
        // Select first viewport if current selection is invalid
        if let selectedId = selectedViewportId,
           !viewports.contains(where: { $0.id == selectedId }) {
            selectedViewportId = viewports.first?.id
        } else if selectedViewportId == nil {
            selectedViewportId = viewports.first?.id
        }
    }
    
    /// Assign a series to a specific viewport
    func assignSeries(_ series: DicomSeries, to viewportId: UUID) {
        if let index = viewports.firstIndex(where: { $0.id == viewportId }) {
            viewports[index].series = series
            viewports[index].currentInstanceIndex = 0
        }
    }
    
    /// Clear a specific viewport
    func clearViewport(_ viewportId: UUID) {
        if let index = viewports.firstIndex(where: { $0.id == viewportId }) {
            viewports[index].series = nil
            viewports[index].currentInstanceIndex = 0
        }
    }
    
    /// Clear all viewports
    func clearAllViewports() {
        for index in viewports.indices {
            viewports[index].series = nil
            viewports[index].currentInstanceIndex = 0
        }
    }
    
    /// Select a viewport
    func selectViewport(_ viewportId: UUID) {
        guard viewports.contains(where: { $0.id == viewportId }) else { return }
        selectedViewportId = viewportId
    }
    
    // MARK: - Viewport Navigation
    
    /// Update the current instance index for a viewport
    func updateInstanceIndex(_ index: Int, for viewportId: UUID) {
        if let viewportIndex = viewports.firstIndex(where: { $0.id == viewportId }) {
            viewports[viewportIndex].currentInstanceIndex = index
            
            // Sync with linked viewports if scroll linking is enabled
            if linking.scrollEnabled {
                syncInstanceIndex(index, excludingViewport: viewportId)
            }
        }
    }
    
    // MARK: - Viewport Linking
    
    /// Enable/disable scroll linking
    func setScrollLinking(_ enabled: Bool) {
        linking.scrollEnabled = enabled
    }
    
    /// Enable/disable window/level linking
    func setWindowLevelLinking(_ enabled: Bool) {
        linking.windowLevelEnabled = enabled
    }
    
    /// Enable/disable zoom linking
    func setZoomLinking(_ enabled: Bool) {
        linking.zoomEnabled = enabled
    }
    
    /// Enable/disable pan linking
    func setPanLinking(_ enabled: Bool) {
        linking.panEnabled = enabled
    }
    
    /// Set all linking options at once
    func setLinking(_ linking: ViewportLinking) {
        self.linking = linking
    }
    
    // MARK: - Private Methods
    
    private func syncInstanceIndex(_ index: Int, excludingViewport: UUID) {
        for i in viewports.indices {
            if viewports[i].id != excludingViewport && viewports[i].series != nil {
                viewports[i].currentInstanceIndex = index
            }
        }
    }
}
