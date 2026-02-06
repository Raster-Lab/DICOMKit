//
//  HangingProtocolService.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation

/// Service for managing hanging protocols
@MainActor
final class HangingProtocolService: ObservableObject {
    // MARK: - Properties
    
    /// Available hanging protocols
    @Published var protocols: [HangingProtocol]
    
    /// Current protocol (nil if manual arrangement)
    @Published var currentProtocol: HangingProtocol?
    
    // MARK: - Initialization
    
    init(protocols: [HangingProtocol] = HangingProtocol.standard) {
        self.protocols = protocols
    }
    
    // MARK: - Protocol Selection
    
    /// Select a hanging protocol
    func selectProtocol(_ protocol: HangingProtocol?) {
        currentProtocol = `protocol`
    }
    
    /// Find best matching protocol for a study
    func findMatchingProtocol(for study: DicomStudy) -> HangingProtocol? {
        // Try to match by modality and body part
        var matchingProtocols = protocols.filter { protocol in
            if let modality = protocol.modality {
                guard study.modalities?.contains(modality) == true else {
                    return false
                }
            }
            
            if let bodyPart = protocol.bodyPart {
                // Check if any series has matching body part
                // This would require querying series, simplified for now
                return true
            }
            
            return true
        }
        
        // Return first match or default to single viewport
        return matchingProtocols.first
    }
    
    /// Apply a protocol to arrange series in viewports
    func applyProtocol(
        _ protocol: HangingProtocol,
        series: [DicomSeries],
        layoutService: ViewportLayoutService
    ) {
        // Set the layout
        layoutService.setLayout(protocol.layout)
        
        // Clear all viewports first
        layoutService.clearAllViewports()
        
        // Sort rules by priority
        let sortedRules = protocol.rules.sorted { $0.priority < $1.priority }
        
        // Assign series to viewports based on rules
        for rule in sortedRules {
            // Find first matching series
            if let matchingSeries = series.first(where: { rule.matches($0) }) {
                // Assign to viewport
                if rule.viewportIndex < layoutService.viewports.count {
                    let viewportId = layoutService.viewports[rule.viewportIndex].id
                    layoutService.assignSeries(matchingSeries, to: viewportId)
                }
            }
        }
        
        // Assign remaining series to empty viewports
        var assignedSeriesIds = Set<String>()
        for viewport in layoutService.viewports {
            if let series = viewport.series {
                assignedSeriesIds.insert(series.seriesInstanceUID)
            }
        }
        
        let unassignedSeries = series.filter { !assignedSeriesIds.contains($0.seriesInstanceUID) }
        var emptyViewportIndices = layoutService.viewports.enumerated()
            .filter { $0.element.series == nil }
            .map { $0.offset }
        
        for (seriesIndex, series) in unassignedSeries.enumerated() {
            if seriesIndex < emptyViewportIndices.count {
                let viewportIndex = emptyViewportIndices[seriesIndex]
                let viewportId = layoutService.viewports[viewportIndex].id
                layoutService.assignSeries(series, to: viewportId)
            }
        }
        
        currentProtocol = `protocol`
    }
    
    // MARK: - Protocol Management
    
    /// Add a custom protocol
    func addProtocol(_ protocol: HangingProtocol) {
        protocols.append(`protocol`)
    }
    
    /// Remove a protocol
    func removeProtocol(_ protocol: HangingProtocol) {
        protocols.removeAll { $0.id == `protocol`.id }
    }
    
    /// Update a protocol
    func updateProtocol(_ protocol: HangingProtocol) {
        if let index = protocols.firstIndex(where: { $0.id == `protocol`.id }) {
            protocols[index] = `protocol`
        }
    }
}
