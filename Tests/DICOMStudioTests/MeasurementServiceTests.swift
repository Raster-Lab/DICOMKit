// MeasurementServiceTests.swift
// DICOMStudioTests
//
// Tests for MeasurementService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MeasurementService Basic CRUD Tests")
struct MeasurementServiceCRUDTests {

    @Test("Add and retrieve measurement")
    func testAddAndRetrieve() {
        let service = MeasurementService()
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)],
            sopInstanceUID: "1.2.3"
        )
        service.addMeasurement(entry)
        let measurements = service.measurements(for: "1.2.3")
        #expect(measurements.count == 1)
        #expect(measurements[0].id == entry.id)
    }

    @Test("Remove measurement")
    func testRemove() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        let removed = service.removeMeasurement(id: entry.id, sopInstanceUID: "1.2.3")
        #expect(removed != nil)
        #expect(service.measurements(for: "1.2.3").isEmpty)
    }

    @Test("Remove non-existent measurement returns nil")
    func testRemoveNonExistent() {
        let service = MeasurementService()
        let removed = service.removeMeasurement(id: UUID(), sopInstanceUID: "1.2.3")
        #expect(removed == nil)
    }

    @Test("Update measurement")
    func testUpdate() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], label: "Original", sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)

        let updated = entry.withLabel("Updated")
        let old = service.updateMeasurement(updated)
        #expect(old?.label == "Original")

        let measurements = service.measurements(for: "1.2.3")
        #expect(measurements[0].label == "Updated")
    }

    @Test("Update non-existent returns nil")
    func testUpdateNonExistent() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        let old = service.updateMeasurement(entry)
        #expect(old == nil)
    }

    @Test("All measurements across images")
    func testAllMeasurements() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        service.addMeasurement(MeasurementEntry(toolType: .angle, points: [], sopInstanceUID: "1.2.4"))
        #expect(service.allMeasurements().count == 2)
    }

    @Test("Visible measurements filter by frame")
    func testVisibleMeasurements() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3", frameNumber: 0))
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3", frameNumber: 1))
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], isVisible: false, sopInstanceUID: "1.2.3", frameNumber: 0))

        let visible = service.visibleMeasurements(for: "1.2.3", frameNumber: 0)
        #expect(visible.count == 1)
    }
}

@Suite("MeasurementService ROI Tests")
struct MeasurementServiceROITests {

    @Test("Add and retrieve ROI")
    func testAddROI() {
        let service = MeasurementService()
        let roi = ROIEntry(roiType: .circular, points: [
            AnnotationPoint(x: 100, y: 100),
            AnnotationPoint(x: 150, y: 100)
        ], sopInstanceUID: "1.2.3")
        service.addROI(roi)
        let rois = service.rois(for: "1.2.3")
        #expect(rois.count == 1)
    }

    @Test("Remove ROI")
    func testRemoveROI() {
        let service = MeasurementService()
        let roi = ROIEntry(roiType: .circular, points: [], sopInstanceUID: "1.2.3")
        service.addROI(roi)
        let removed = service.removeROI(id: roi.id, sopInstanceUID: "1.2.3")
        #expect(removed != nil)
        #expect(service.rois(for: "1.2.3").isEmpty)
    }

    @Test("Remove non-existent ROI returns nil")
    func testRemoveNonExistentROI() {
        let service = MeasurementService()
        let removed = service.removeROI(id: UUID(), sopInstanceUID: "1.2.3")
        #expect(removed == nil)
    }
}

@Suite("MeasurementService Undo/Redo Tests")
struct MeasurementServiceUndoRedoTests {

    @Test("Undo add")
    func testUndoAdd() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        #expect(service.measurements(for: "1.2.3").count == 1)

        let result = service.undo()
        #expect(result == true)
        #expect(service.measurements(for: "1.2.3").isEmpty)
    }

    @Test("Redo add")
    func testRedoAdd() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        service.undo()
        #expect(service.measurements(for: "1.2.3").isEmpty)

        let result = service.redo()
        #expect(result == true)
        #expect(service.measurements(for: "1.2.3").count == 1)
    }

    @Test("Undo remove")
    func testUndoRemove() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        service.removeMeasurement(id: entry.id, sopInstanceUID: "1.2.3")
        #expect(service.measurements(for: "1.2.3").isEmpty)

        service.undo()
        #expect(service.measurements(for: "1.2.3").count == 1)
    }

    @Test("Undo update")
    func testUndoUpdate() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], label: "Original", sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        service.updateMeasurement(entry.withLabel("Updated"))
        #expect(service.measurements(for: "1.2.3")[0].label == "Updated")

        service.undo()
        #expect(service.measurements(for: "1.2.3")[0].label == "Original")
    }

    @Test("Redo update")
    func testRedoUpdate() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], label: "Original", sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        service.updateMeasurement(entry.withLabel("Updated"))
        service.undo()
        #expect(service.measurements(for: "1.2.3")[0].label == "Original")

        service.redo()
        #expect(service.measurements(for: "1.2.3")[0].label == "Updated")
    }

    @Test("canUndo and canRedo")
    func testCanUndoRedo() {
        let service = MeasurementService()
        #expect(!service.canUndo)
        #expect(!service.canRedo)

        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        #expect(service.canUndo)
        #expect(!service.canRedo)

        service.undo()
        #expect(!service.canUndo)
        #expect(service.canRedo)
    }

    @Test("New action clears redo stack")
    func testNewActionClearsRedo() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        service.undo()
        #expect(service.canRedo)

        service.addMeasurement(MeasurementEntry(toolType: .angle, points: [], sopInstanceUID: "1.2.3"))
        #expect(!service.canRedo)
    }

    @Test("Undo on empty stack returns false")
    func testUndoEmpty() {
        let service = MeasurementService()
        #expect(!service.undo())
    }

    @Test("Redo on empty stack returns false")
    func testRedoEmpty() {
        let service = MeasurementService()
        #expect(!service.redo())
    }

    @Test("Undo count and redo count")
    func testCounts() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        service.addMeasurement(MeasurementEntry(toolType: .angle, points: [], sopInstanceUID: "1.2.3"))
        #expect(service.undoCount == 2)
        #expect(service.redoCount == 0)

        service.undo()
        #expect(service.undoCount == 1)
        #expect(service.redoCount == 1)
    }

    @Test("Clear history")
    func testClearHistory() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        service.clearHistory()
        #expect(!service.canUndo)
        #expect(!service.canRedo)
        // Measurements should still be there
        #expect(service.measurements(for: "1.2.3").count == 1)
    }

    @Test("Clear all")
    func testClearAll() {
        let service = MeasurementService()
        service.addMeasurement(MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3"))
        service.addROI(ROIEntry(roiType: .circular, points: [], sopInstanceUID: "1.2.3"))
        service.clearAll()
        #expect(service.measurements(for: "1.2.3").isEmpty)
        #expect(service.rois(for: "1.2.3").isEmpty)
        #expect(!service.canUndo)
    }

    @Test("Max undo history limit")
    func testMaxUndoHistory() {
        let service = MeasurementService(maxUndoHistory: 3)
        for i in 0..<5 {
            service.addMeasurement(MeasurementEntry(toolType: .length, points: [], label: "\(i)", sopInstanceUID: "1.2.3"))
        }
        #expect(service.undoCount == 3)
    }

    @Test("Redo remove")
    func testRedoRemove() {
        let service = MeasurementService()
        let entry = MeasurementEntry(toolType: .length, points: [], sopInstanceUID: "1.2.3")
        service.addMeasurement(entry)
        service.removeMeasurement(id: entry.id, sopInstanceUID: "1.2.3")
        service.undo() // Undo remove → measurement is back
        #expect(service.measurements(for: "1.2.3").count == 1)

        service.redo() // Redo remove → measurement gone again
        #expect(service.measurements(for: "1.2.3").isEmpty)
    }
}
