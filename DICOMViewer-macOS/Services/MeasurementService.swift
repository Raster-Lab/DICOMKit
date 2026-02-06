// MeasurementService.swift
// DICOMViewer macOS - Measurement Management Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import AppKit

/// Service for managing measurements in the application
@MainActor
final class MeasurementService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All measurements across all studies
    @Published private(set) var measurements: [String: [Measurement]] = [:]
    
    /// Currently selected measurement tool
    @Published var selectedTool: MeasurementType?
    
    /// Currently active (being drawn) measurement
    @Published var activeMeasurement: Measurement?
    
    /// Currently selected measurements for editing
    @Published var selectedMeasurements: Set<UUID> = []
    
    // MARK: - Singleton
    
    static let shared = MeasurementService()
    
    private init() {
        loadMeasurements()
    }
    
    // MARK: - Public Methods
    
    /// Add a measurement for a specific instance
    func addMeasurement(_ measurement: Measurement, for instanceUID: String) {
        if measurements[instanceUID] == nil {
            measurements[instanceUID] = []
        }
        measurements[instanceUID]?.append(measurement)
        saveMeasurements()
    }
    
    /// Update an existing measurement
    func updateMeasurement(_ measurement: Measurement, for instanceUID: String) {
        guard let index = measurements[instanceUID]?.firstIndex(where: { $0.id == measurement.id }) else {
            return
        }
        measurements[instanceUID]?[index] = measurement
        saveMeasurements()
    }
    
    /// Remove a measurement
    func removeMeasurement(id: UUID, for instanceUID: String) {
        measurements[instanceUID]?.removeAll { $0.id == id }
        selectedMeasurements.remove(id)
        saveMeasurements()
    }
    
    /// Get measurements for a specific instance and frame
    func getMeasurements(for instanceUID: String, frameIndex: Int) -> [Measurement] {
        guard let instanceMeasurements = measurements[instanceUID] else {
            return []
        }
        return instanceMeasurements.filter { $0.frameIndex == frameIndex && $0.isVisible }
    }
    
    /// Get all measurements for a specific instance
    func getAllMeasurements(for instanceUID: String) -> [Measurement] {
        return measurements[instanceUID] ?? []
    }
    
    /// Clear all measurements for a specific instance
    func clearMeasurements(for instanceUID: String) {
        measurements[instanceUID] = nil
        saveMeasurements()
    }
    
    /// Toggle visibility of a measurement
    func toggleVisibility(id: UUID, for instanceUID: String) {
        guard let index = measurements[instanceUID]?.firstIndex(where: { $0.id == id }) else {
            return
        }
        measurements[instanceUID]?[index].isVisible.toggle()
        saveMeasurements()
    }
    
    /// Start creating a new measurement
    func startMeasurement(type: MeasurementType, frameIndex: Int, pixelSpacing: (row: Double, column: Double)?) {
        activeMeasurement = Measurement(
            type: type,
            frameIndex: frameIndex,
            pixelSpacing: pixelSpacing
        )
    }
    
    /// Add a point to the active measurement
    func addPoint(_ point: ImagePoint) {
        guard var active = activeMeasurement else { return }
        active.points.append(point)
        activeMeasurement = active
    }
    
    /// Finish the active measurement
    func finishMeasurement(for instanceUID: String) -> Measurement? {
        guard let measurement = activeMeasurement else { return nil }
        
        // Validate measurement has enough points
        let isValid = switch measurement.type {
        case .length: measurement.points.count >= 2
        case .angle: measurement.points.count >= 3
        case .rectangle, .ellipse: measurement.points.count >= 2
        case .polygon: measurement.points.count >= 3
        }
        
        guard isValid else {
            activeMeasurement = nil
            return nil
        }
        
        addMeasurement(measurement, for: instanceUID)
        activeMeasurement = nil
        return measurement
    }
    
    /// Cancel the active measurement
    func cancelMeasurement() {
        activeMeasurement = nil
    }
    
    /// Export measurements for an instance to JSON
    func exportMeasurements(for instanceUID: String) throws -> Data {
        let instanceMeasurements = measurements[instanceUID] ?? []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(instanceMeasurements)
    }
    
    /// Import measurements from JSON data
    func importMeasurements(from data: Data, for instanceUID: String) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([Measurement].self, from: data)
        
        if measurements[instanceUID] == nil {
            measurements[instanceUID] = []
        }
        measurements[instanceUID]?.append(contentsOf: imported)
        saveMeasurements()
    }
    
    // MARK: - Private Methods
    
    private func saveMeasurements() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("Failed to get application support directory")
            return
        }
        
        let measurementsDir = appSupport.appendingPathComponent("DICOMViewer-macOS/Measurements")
        
        do {
            try FileManager.default.createDirectory(
                at: measurementsDir,
                withIntermediateDirectories: true
            )
            
            for (instanceUID, instanceMeasurements) in measurements {
                let fileURL = measurementsDir.appendingPathComponent("\(instanceUID).json")
                let data = try exportMeasurements(for: instanceUID)
                try data.write(to: fileURL)
            }
        } catch {
            print("Failed to save measurements: \(error)")
        }
    }
    
    private func loadMeasurements() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        
        let measurementsDir = appSupport.appendingPathComponent("DICOMViewer-macOS/Measurements")
        
        guard FileManager.default.fileExists(atPath: measurementsDir.path) else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: measurementsDir, includingPropertiesForKeys: nil)
            
            for fileURL in files where fileURL.pathExtension == "json" {
                let instanceUID = fileURL.deletingPathExtension().lastPathComponent
                let data = try Data(contentsOf: fileURL)
                try importMeasurements(from: data, for: instanceUID)
            }
        } catch {
            print("Failed to load measurements: \(error)")
        }
    }
}
