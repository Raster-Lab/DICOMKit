// MeasurementViewModel.swift
// DICOMViewer macOS - Measurement ViewModel
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import AppKit
import Combine

/// ViewModel for managing measurements in the image viewer
@MainActor
final class MeasurementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current measurements for the displayed image
    @Published private(set) var currentMeasurements: [Measurement] = []
    
    /// Whether measurement mode is active
    @Published var isMeasuring: Bool = false
    
    /// Currently selected tool
    @Published var selectedTool: MeasurementType?
    
    /// Active measurement being drawn
    @Published var activeMeasurement: Measurement?
    
    /// Selected measurement IDs for editing
    @Published var selectedMeasurementIDs: Set<UUID> = []
    
    /// Show measurement labels
    @Published var showLabels: Bool = true
    
    /// Show measurement values
    @Published var showValues: Bool = true
    
    // MARK: - Dependencies
    
    private let measurementService = MeasurementService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current Context
    
    private var currentInstanceUID: String?
    private var currentFrameIndex: Int = 0
    private var currentPixelSpacing: (row: Double, column: Double)?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Update the current image context
    func updateContext(
        instanceUID: String,
        frameIndex: Int,
        pixelSpacing: (row: Double, column: Double)?
    ) {
        self.currentInstanceUID = instanceUID
        self.currentFrameIndex = frameIndex
        self.currentPixelSpacing = pixelSpacing
        loadMeasurements()
    }
    
    /// Select a measurement tool
    func selectTool(_ tool: MeasurementType?) {
        selectedTool = tool
        isMeasuring = tool != nil
        
        if let tool = tool {
            startNewMeasurement(type: tool)
        } else {
            cancelActiveMeasurement()
        }
    }
    
    /// Add a point to the active measurement
    func addPoint(at imagePoint: ImagePoint) {
        guard var active = activeMeasurement else { return }
        active.points.append(imagePoint)
        
        // Auto-complete measurements based on type
        let shouldComplete = switch active.type {
        case .length: active.points.count >= 2
        case .angle: active.points.count >= 3
        case .rectangle, .ellipse: active.points.count >= 2
        case .polygon: false // Polygon requires manual completion
        }
        
        if shouldComplete {
            activeMeasurement = active
            completeMeasurement()
        } else {
            activeMeasurement = active
        }
    }
    
    /// Complete the current measurement (for polygon)
    func completeMeasurement() {
        guard let instanceUID = currentInstanceUID else { return }
        
        if let completed = measurementService.finishMeasurement(for: instanceUID) {
            loadMeasurements()
            
            // If continuous measurement mode, start a new one
            if let tool = selectedTool {
                startNewMeasurement(type: tool)
            }
        }
    }
    
    /// Cancel the active measurement
    func cancelActiveMeasurement() {
        measurementService.cancelMeasurement()
        activeMeasurement = nil
    }
    
    /// Delete a measurement
    func deleteMeasurement(id: UUID) {
        guard let instanceUID = currentInstanceUID else { return }
        measurementService.removeMeasurement(id: id, for: instanceUID)
        selectedMeasurementIDs.remove(id)
        loadMeasurements()
    }
    
    /// Delete selected measurements
    func deleteSelectedMeasurements() {
        guard let instanceUID = currentInstanceUID else { return }
        
        for id in selectedMeasurementIDs {
            measurementService.removeMeasurement(id: id, for: instanceUID)
        }
        selectedMeasurementIDs.removeAll()
        loadMeasurements()
    }
    
    /// Clear all measurements for current image
    func clearAllMeasurements() {
        guard let instanceUID = currentInstanceUID else { return }
        measurementService.clearMeasurements(for: instanceUID)
        selectedMeasurementIDs.removeAll()
        loadMeasurements()
    }
    
    /// Toggle visibility of a measurement
    func toggleVisibility(id: UUID) {
        guard let instanceUID = currentInstanceUID else { return }
        measurementService.toggleVisibility(id: id, for: instanceUID)
        loadMeasurements()
    }
    
    /// Select a measurement
    func selectMeasurement(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            selectedMeasurementIDs.insert(id)
        } else {
            selectedMeasurementIDs = [id]
        }
    }
    
    /// Deselect all measurements
    func deselectAll() {
        selectedMeasurementIDs.removeAll()
    }
    
    /// Update measurement label
    func updateLabel(id: UUID, label: String?) {
        guard let instanceUID = currentInstanceUID,
              let index = currentMeasurements.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var measurement = currentMeasurements[index]
        measurement.label = label
        measurementService.updateMeasurement(measurement, for: instanceUID)
        loadMeasurements()
    }
    
    /// Export measurements to JSON
    func exportMeasurements() throws -> Data {
        guard let instanceUID = currentInstanceUID else {
            throw NSError(domain: "MeasurementViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No instance selected"
            ])
        }
        return try measurementService.exportMeasurements(for: instanceUID)
    }
    
    /// Import measurements from JSON
    func importMeasurements(from data: Data) throws {
        guard let instanceUID = currentInstanceUID else {
            throw NSError(domain: "MeasurementViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No instance selected"
            ])
        }
        try measurementService.importMeasurements(from: data, for: instanceUID)
        loadMeasurements()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        measurementService.$activeMeasurement
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeMeasurement)
        
        measurementService.$selectedTool
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedTool)
    }
    
    private func loadMeasurements() {
        guard let instanceUID = currentInstanceUID else {
            currentMeasurements = []
            return
        }
        
        currentMeasurements = measurementService.getMeasurements(
            for: instanceUID,
            frameIndex: currentFrameIndex
        )
    }
    
    private func startNewMeasurement(type: MeasurementType) {
        measurementService.startMeasurement(
            type: type,
            frameIndex: currentFrameIndex,
            pixelSpacing: currentPixelSpacing
        )
        activeMeasurement = measurementService.activeMeasurement
    }
}
