// MeasurementService.swift
// DICOMStudio
//
// DICOM Studio — Service for measurement operations and undo/redo

import Foundation

/// Service for managing measurements, including add/remove/update operations
/// and undo/redo support.
public final class MeasurementService: @unchecked Sendable {

    /// Lock for thread-safe access.
    private let lock = NSLock()

    /// All measurements (keyed by SOP Instance UID).
    private var measurementsByImage: [String: [MeasurementEntry]]

    /// All ROI entries (keyed by SOP Instance UID).
    private var roisByImage: [String: [ROIEntry]]

    /// Undo stack.
    private var undoStack: [MeasurementAction]

    /// Redo stack.
    private var redoStack: [MeasurementAction]

    /// Maximum undo history size.
    public let maxUndoHistory: Int

    /// Creates a new measurement service.
    public init(maxUndoHistory: Int = 100) {
        self.maxUndoHistory = maxUndoHistory
        self.measurementsByImage = [:]
        self.roisByImage = [:]
        self.undoStack = []
        self.redoStack = []
    }

    // MARK: - Measurements

    /// Adds a measurement entry.
    ///
    /// - Parameter entry: The measurement to add.
    public func addMeasurement(_ entry: MeasurementEntry) {
        lock.lock()
        defer { lock.unlock() }

        var measurements = measurementsByImage[entry.sopInstanceUID] ?? []
        measurements.append(entry)
        measurementsByImage[entry.sopInstanceUID] = measurements

        pushUndo(.add(entry))
    }

    /// Removes a measurement by ID.
    ///
    /// - Parameters:
    ///   - id: The measurement ID to remove.
    ///   - sopInstanceUID: The SOP Instance UID.
    /// - Returns: The removed measurement, or nil if not found.
    @discardableResult
    public func removeMeasurement(id: UUID, sopInstanceUID: String) -> MeasurementEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard var measurements = measurementsByImage[sopInstanceUID],
              let index = measurements.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let removed = measurements.remove(at: index)
        measurementsByImage[sopInstanceUID] = measurements

        pushUndo(.remove(removed))
        return removed
    }

    /// Updates a measurement entry.
    ///
    /// - Parameter entry: The updated measurement.
    /// - Returns: The old measurement, or nil if not found.
    @discardableResult
    public func updateMeasurement(_ entry: MeasurementEntry) -> MeasurementEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard var measurements = measurementsByImage[entry.sopInstanceUID],
              let index = measurements.firstIndex(where: { $0.id == entry.id }) else {
            return nil
        }

        let old = measurements[index]
        measurements[index] = entry
        measurementsByImage[entry.sopInstanceUID] = measurements

        pushUndo(.update(old: old, new: entry))
        return old
    }

    /// Returns all measurements for a given SOP Instance UID.
    ///
    /// - Parameter sopInstanceUID: SOP Instance UID.
    /// - Returns: Array of measurement entries.
    public func measurements(for sopInstanceUID: String) -> [MeasurementEntry] {
        lock.lock()
        defer { lock.unlock() }
        return measurementsByImage[sopInstanceUID] ?? []
    }

    /// Returns all measurements across all images.
    ///
    /// - Returns: Array of all measurement entries.
    public func allMeasurements() -> [MeasurementEntry] {
        lock.lock()
        defer { lock.unlock() }
        return measurementsByImage.values.flatMap { $0 }
    }

    /// Returns visible measurements for a given image and frame.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - frameNumber: Frame number.
    /// - Returns: Visible measurements for the specified frame.
    public func visibleMeasurements(
        for sopInstanceUID: String,
        frameNumber: Int
    ) -> [MeasurementEntry] {
        lock.lock()
        defer { lock.unlock() }
        return (measurementsByImage[sopInstanceUID] ?? []).filter {
            $0.isVisible && $0.frameNumber == frameNumber
        }
    }

    // MARK: - ROI Entries

    /// Adds an ROI entry.
    ///
    /// - Parameter entry: The ROI to add.
    public func addROI(_ entry: ROIEntry) {
        lock.lock()
        defer { lock.unlock() }

        var rois = roisByImage[entry.sopInstanceUID] ?? []
        rois.append(entry)
        roisByImage[entry.sopInstanceUID] = rois
    }

    /// Removes an ROI by ID.
    ///
    /// - Parameters:
    ///   - id: ROI ID.
    ///   - sopInstanceUID: SOP Instance UID.
    /// - Returns: The removed ROI, or nil if not found.
    @discardableResult
    public func removeROI(id: UUID, sopInstanceUID: String) -> ROIEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard var rois = roisByImage[sopInstanceUID],
              let index = rois.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let removed = rois.remove(at: index)
        roisByImage[sopInstanceUID] = rois
        return removed
    }

    /// Returns all ROIs for a given SOP Instance UID.
    ///
    /// - Parameter sopInstanceUID: SOP Instance UID.
    /// - Returns: Array of ROI entries.
    public func rois(for sopInstanceUID: String) -> [ROIEntry] {
        lock.lock()
        defer { lock.unlock() }
        return roisByImage[sopInstanceUID] ?? []
    }

    // MARK: - Undo / Redo

    /// Whether an undo operation is available.
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !undoStack.isEmpty
    }

    /// Whether a redo operation is available.
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }

    /// The number of actions on the undo stack.
    public var undoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count
    }

    /// The number of actions on the redo stack.
    public var redoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.count
    }

    /// Performs an undo operation.
    ///
    /// - Returns: True if an action was undone.
    @discardableResult
    public func undo() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let action = undoStack.popLast() else { return false }

        switch action {
        case .add(let entry):
            // Undo add = remove
            if var measurements = measurementsByImage[entry.sopInstanceUID],
               let index = measurements.firstIndex(where: { $0.id == entry.id }) {
                measurements.remove(at: index)
                measurementsByImage[entry.sopInstanceUID] = measurements
            }
            redoStack.append(action)

        case .remove(let entry):
            // Undo remove = add back
            var measurements = measurementsByImage[entry.sopInstanceUID] ?? []
            measurements.append(entry)
            measurementsByImage[entry.sopInstanceUID] = measurements
            redoStack.append(action)

        case .update(let old, _):
            // Undo update = restore old
            if var measurements = measurementsByImage[old.sopInstanceUID],
               let index = measurements.firstIndex(where: { $0.id == old.id }) {
                measurements[index] = old
                measurementsByImage[old.sopInstanceUID] = measurements
            }
            redoStack.append(action)
        }

        return true
    }

    /// Performs a redo operation.
    ///
    /// - Returns: True if an action was redone.
    @discardableResult
    public func redo() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let action = redoStack.popLast() else { return false }

        switch action {
        case .add(let entry):
            // Redo add = add again
            var measurements = measurementsByImage[entry.sopInstanceUID] ?? []
            measurements.append(entry)
            measurementsByImage[entry.sopInstanceUID] = measurements
            undoStack.append(action)

        case .remove(let entry):
            // Redo remove = remove again
            if var measurements = measurementsByImage[entry.sopInstanceUID],
               let index = measurements.firstIndex(where: { $0.id == entry.id }) {
                measurements.remove(at: index)
                measurementsByImage[entry.sopInstanceUID] = measurements
            }
            undoStack.append(action)

        case .update(_, let new):
            // Redo update = apply new again
            if var measurements = measurementsByImage[new.sopInstanceUID],
               let index = measurements.firstIndex(where: { $0.id == new.id }) {
                measurements[index] = new
                measurementsByImage[new.sopInstanceUID] = measurements
            }
            undoStack.append(action)
        }

        return true
    }

    /// Clears all undo and redo history.
    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Clears all measurements and ROIs.
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        measurementsByImage.removeAll()
        roisByImage.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Private

    private func pushUndo(_ action: MeasurementAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }
        // Adding a new action clears the redo stack
        redoStack.removeAll()
    }
}
