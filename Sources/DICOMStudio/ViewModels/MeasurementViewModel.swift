// MeasurementViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for measurement tools

import Foundation
import Observation

/// ViewModel for measurement and annotation tools, managing tool selection,
/// active measurements, calibration, and annotation layer state.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class MeasurementViewModel {

    // MARK: - Tool State

    /// Currently selected measurement tool, or nil for no tool.
    public var selectedTool: MeasurementToolType?

    /// Points collected for the current in-progress measurement.
    public var activePoints: [AnnotationPoint] = []

    /// Whether a measurement is currently being drawn.
    public var isDrawing: Bool {
        !activePoints.isEmpty
    }

    /// Display unit for measurements.
    public var displayUnit: MeasurementUnit = .millimeters

    // MARK: - Selection State

    /// ID of the currently selected measurement.
    public var selectedMeasurementID: UUID?

    /// Whether the measurement list panel is visible.
    public var showMeasurementList: Bool = false

    /// Whether the calibration panel is visible.
    public var showCalibrationPanel: Bool = false

    // MARK: - Services

    /// Measurement service for CRUD and undo/redo.
    public let measurementService: MeasurementService

    /// Calibration service.
    public let calibrationService: CalibrationService

    // MARK: - Current Image Context

    /// SOP Instance UID of the current image.
    public var currentSOPInstanceUID: String = ""

    /// Current frame number.
    public var currentFrameNumber: Int = 0

    // MARK: - Initialization

    /// Creates a measurement ViewModel with dependency-injected services.
    public init(
        measurementService: MeasurementService = MeasurementService(),
        calibrationService: CalibrationService = CalibrationService()
    ) {
        self.measurementService = measurementService
        self.calibrationService = calibrationService
    }

    // MARK: - Tool Selection

    /// Selects a measurement tool.
    ///
    /// - Parameter tool: The tool to select.
    public func selectTool(_ tool: MeasurementToolType) {
        cancelDrawing()
        selectedTool = tool
    }

    /// Deselects the current tool.
    public func deselectTool() {
        cancelDrawing()
        selectedTool = nil
    }

    /// Cancels the current in-progress measurement.
    public func cancelDrawing() {
        activePoints.removeAll()
    }

    // MARK: - Point Collection

    /// Adds a point to the current in-progress measurement.
    ///
    /// - Parameter point: The point in image coordinates.
    /// - Returns: True if the measurement is complete.
    @discardableResult
    public func addPoint(_ point: AnnotationPoint) -> Bool {
        guard let tool = selectedTool else { return false }

        activePoints.append(point)

        if let required = MeasurementHelpers.requiredPoints(for: tool),
           activePoints.count >= required {
            commitMeasurement()
            return true
        }
        return false
    }

    /// Completes and stores the current measurement.
    public func commitMeasurement() {
        guard let tool = selectedTool, !activePoints.isEmpty else { return }

        let entry = MeasurementEntry(
            toolType: tool,
            points: activePoints,
            label: MeasurementHelpers.toolLabel(for: tool),
            sopInstanceUID: currentSOPInstanceUID,
            frameNumber: currentFrameNumber
        )
        measurementService.addMeasurement(entry)
        activePoints.removeAll()
    }

    /// Completes a freehand/polygonal ROI (variable-point tools).
    public func finishFreeformMeasurement() {
        guard let tool = selectedTool else { return }
        guard tool == .freehandROI || tool == .polygonalROI else { return }
        guard activePoints.count >= 3 else { return }

        commitMeasurement()
    }

    // MARK: - Measurement Management

    /// Removes a measurement by ID.
    ///
    /// - Parameter id: The measurement ID.
    public func removeMeasurement(id: UUID) {
        measurementService.removeMeasurement(id: id, sopInstanceUID: currentSOPInstanceUID)
    }

    /// Toggles visibility of a measurement.
    ///
    /// - Parameter id: The measurement ID.
    public func toggleVisibility(id: UUID) {
        let measurements = measurementService.measurements(for: currentSOPInstanceUID)
        guard let entry = measurements.first(where: { $0.id == id }) else { return }
        measurementService.updateMeasurement(entry.withVisibility(!entry.isVisible))
    }

    /// Toggles lock state of a measurement.
    ///
    /// - Parameter id: The measurement ID.
    public func toggleLock(id: UUID) {
        let measurements = measurementService.measurements(for: currentSOPInstanceUID)
        guard let entry = measurements.first(where: { $0.id == id }) else { return }
        measurementService.updateMeasurement(entry.withLocked(!entry.isLocked))
    }

    /// Updates the label of a measurement.
    ///
    /// - Parameters:
    ///   - id: The measurement ID.
    ///   - label: New label.
    public func updateLabel(id: UUID, label: String) {
        let measurements = measurementService.measurements(for: currentSOPInstanceUID)
        guard let entry = measurements.first(where: { $0.id == id }) else { return }
        measurementService.updateMeasurement(entry.withLabel(label))
    }

    // MARK: - Undo / Redo

    /// Whether undo is available.
    public var canUndo: Bool {
        measurementService.canUndo
    }

    /// Whether redo is available.
    public var canRedo: Bool {
        measurementService.canRedo
    }

    /// Performs undo.
    public func undo() {
        measurementService.undo()
    }

    /// Performs redo.
    public func redo() {
        measurementService.redo()
    }

    // MARK: - Calibration

    /// Current calibration for the active image.
    public var currentCalibration: CalibrationModel {
        calibrationService.calibration(for: currentSOPInstanceUID)
    }

    /// Calibration display text.
    public var calibrationText: String {
        CalibrationHelpers.formatCalibration(currentCalibration)
    }

    /// Calibration indicator text for overlay.
    public var calibrationIndicator: String {
        CalibrationHelpers.calibrationIndicator(currentCalibration)
    }

    /// Sets manual calibration for the current image.
    ///
    /// - Parameters:
    ///   - pixelDistance: Known distance in pixels.
    ///   - knownDistanceMM: Known physical distance in mm.
    public func setManualCalibration(pixelDistance: Double, knownDistanceMM: Double) {
        calibrationService.setManualCalibration(
            for: currentSOPInstanceUID,
            pixelDistance: pixelDistance,
            knownDistanceMM: knownDistanceMM
        )
    }

    // MARK: - Queries

    /// All measurements for the current image.
    public var currentMeasurements: [MeasurementEntry] {
        measurementService.measurements(for: currentSOPInstanceUID)
    }

    /// Visible measurements for the current frame.
    public var visibleMeasurements: [MeasurementEntry] {
        measurementService.visibleMeasurements(
            for: currentSOPInstanceUID,
            frameNumber: currentFrameNumber
        )
    }

    /// Total count of measurements for the current image.
    public var measurementCount: Int {
        currentMeasurements.count
    }

    // MARK: - Export

    /// Exports current measurements to CSV.
    ///
    /// - Returns: CSV string.
    public func exportCSV() -> String {
        MeasurementPersistenceHelpers.measurementsToCSV(
            currentMeasurements,
            calibration: currentCalibration
        )
    }

    /// Exports current measurements to JSON dictionaries.
    ///
    /// - Returns: Array of dictionaries.
    public func exportJSON() -> [[String: String]] {
        MeasurementPersistenceHelpers.measurementsToJSON(
            currentMeasurements,
            calibration: currentCalibration
        )
    }

    // MARK: - Display Helpers

    /// Formats a length measurement result for display.
    ///
    /// - Parameter result: The linear measurement result.
    /// - Returns: Formatted string.
    public func formatLength(_ result: LinearMeasurementResult) -> String {
        MeasurementHelpers.formatLength(
            pixels: result.lengthPixels,
            mm: result.lengthMM,
            unit: displayUnit
        )
    }

    /// Formats an angle measurement result for display.
    ///
    /// - Parameter result: The angle measurement result.
    /// - Returns: Formatted string.
    public func formatAngle(_ result: AngleMeasurementResult) -> String {
        MeasurementHelpers.formatAngle(result.angleDegrees)
    }

    /// Selected tool label.
    public var selectedToolLabel: String {
        guard let tool = selectedTool else { return "No Tool" }
        return MeasurementHelpers.toolLabel(for: tool)
    }

    /// Selected tool system image name.
    public var selectedToolSystemImage: String {
        guard let tool = selectedTool else { return "hand.point.up.left" }
        return MeasurementHelpers.toolSystemImage(for: tool)
    }
}
