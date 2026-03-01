// MeasurementViewModelTests.swift
// DICOMStudioTests
//
// Tests for MeasurementViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MeasurementViewModel Tool Selection Tests")
struct MeasurementViewModelToolTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial state has no tool selected")
    func testInitialState() {
        let vm = MeasurementViewModel()
        #expect(vm.selectedTool == nil)
        #expect(!vm.isDrawing)
        #expect(vm.activePoints.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Select tool")
    func testSelectTool() {
        let vm = MeasurementViewModel()
        vm.selectTool(.length)
        #expect(vm.selectedTool == .length)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Deselect tool")
    func testDeselectTool() {
        let vm = MeasurementViewModel()
        vm.selectTool(.length)
        vm.deselectTool()
        #expect(vm.selectedTool == nil)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Selecting new tool cancels drawing")
    func testSelectNewToolCancelsDrawing() {
        let vm = MeasurementViewModel()
        vm.selectTool(.length)
        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        #expect(vm.isDrawing)

        vm.selectTool(.angle)
        #expect(!vm.isDrawing)
        #expect(vm.selectedTool == .angle)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Cancel drawing clears active points")
    func testCancelDrawing() {
        let vm = MeasurementViewModel()
        vm.selectTool(.angle)
        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))
        #expect(vm.activePoints.count == 2)

        vm.cancelDrawing()
        #expect(vm.activePoints.isEmpty)
        #expect(!vm.isDrawing)
    }
}

@Suite("MeasurementViewModel Point Collection Tests")
struct MeasurementViewModelPointTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Add points for length measurement")
    func testLengthPoints() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.length)

        let completed1 = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        #expect(!completed1)
        #expect(vm.activePoints.count == 1)

        let completed2 = vm.addPoint(AnnotationPoint(x: 100, y: 0))
        #expect(completed2)
        #expect(vm.activePoints.isEmpty) // Points cleared after commit
        #expect(vm.measurementCount == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Add points for angle measurement")
    func testAnglePoints() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.angle)

        _ = vm.addPoint(AnnotationPoint(x: 100, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        let completed = vm.addPoint(AnnotationPoint(x: 0, y: 100))
        #expect(completed)
        #expect(vm.measurementCount == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Add point with no tool returns false")
    func testNoTool() {
        let vm = MeasurementViewModel()
        let completed = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        #expect(!completed)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Marker completes on single point")
    func testMarkerSinglePoint() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)

        let completed = vm.addPoint(AnnotationPoint(x: 50, y: 50))
        #expect(completed)
        #expect(vm.measurementCount == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Freehand ROI does not auto-complete")
    func testFreehandNoAutoComplete() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.freehandROI)

        for i in 0..<10 {
            let completed = vm.addPoint(AnnotationPoint(x: Double(i * 10), y: Double(i * 5)))
            #expect(!completed) // Variable-point tools don't auto-complete
        }
        #expect(vm.activePoints.count == 10)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Finish freeform measurement")
    func testFinishFreeform() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.freehandROI)

        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 100, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        vm.finishFreeformMeasurement()
        #expect(vm.measurementCount == 1)
        #expect(vm.activePoints.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Finish freeform with too few points does nothing")
    func testFinishFreeformTooFewPoints() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.polygonalROI)

        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 100, y: 0))

        vm.finishFreeformMeasurement()
        #expect(vm.measurementCount == 0)
        #expect(vm.activePoints.count == 2)
    }
}

@Suite("MeasurementViewModel Management Tests")
struct MeasurementViewModelManagementTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Remove measurement")
    func testRemove() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))
        #expect(vm.measurementCount == 1)

        let id = vm.currentMeasurements[0].id
        vm.removeMeasurement(id: id)
        #expect(vm.measurementCount == 0)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Toggle visibility")
    func testToggleVisibility() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        let id = vm.currentMeasurements[0].id
        #expect(vm.currentMeasurements[0].isVisible == true)

        vm.toggleVisibility(id: id)
        #expect(vm.currentMeasurements[0].isVisible == false)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Toggle lock")
    func testToggleLock() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        let id = vm.currentMeasurements[0].id
        #expect(vm.currentMeasurements[0].isLocked == false)

        vm.toggleLock(id: id)
        #expect(vm.currentMeasurements[0].isLocked == true)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Update label")
    func testUpdateLabel() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        let id = vm.currentMeasurements[0].id
        vm.updateLabel(id: id, label: "Custom Label")
        #expect(vm.currentMeasurements[0].label == "Custom Label")
    }
}

@Suite("MeasurementViewModel Undo/Redo Tests")
struct MeasurementViewModelUndoRedoTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Undo and redo")
    func testUndoRedo() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))
        #expect(vm.measurementCount == 1)
        #expect(vm.canUndo)

        vm.undo()
        #expect(vm.measurementCount == 0)
        #expect(vm.canRedo)

        vm.redo()
        #expect(vm.measurementCount == 1)
    }
}

@Suite("MeasurementViewModel Calibration Tests")
struct MeasurementViewModelCalibrationTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Initial calibration is uncalibrated")
    func testInitialCalibration() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        #expect(!vm.currentCalibration.isCalibrated)
        #expect(vm.calibrationText == "Uncalibrated")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Set manual calibration")
    func testManualCalibration() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.setManualCalibration(pixelDistance: 200, knownDistanceMM: 100)
        #expect(vm.currentCalibration.isCalibrated)
        #expect(vm.currentCalibration.source == .manual)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Calibration indicator text")
    func testCalibrationIndicator() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        #expect(vm.calibrationIndicator.contains("⚠️"))

        vm.setManualCalibration(pixelDistance: 200, knownDistanceMM: 100)
        #expect(vm.calibrationIndicator.contains("✓"))
    }
}

@Suite("MeasurementViewModel Export Tests")
struct MeasurementViewModelExportTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Export CSV")
    func testExportCSV() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.length)
        _ = vm.addPoint(AnnotationPoint(x: 0, y: 0))
        _ = vm.addPoint(AnnotationPoint(x: 100, y: 0))

        let csv = vm.exportCSV()
        #expect(csv.contains("LENGTH"))
        #expect(csv.contains("ID"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Export JSON")
    func testExportJSON() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        let json = vm.exportJSON()
        #expect(json.count == 1)
        #expect(json[0]["type"] == "MARKER")
    }
}

@Suite("MeasurementViewModel Display Helper Tests")
struct MeasurementViewModelDisplayTests {

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Selected tool label")
    func testToolLabel() {
        let vm = MeasurementViewModel()
        #expect(vm.selectedToolLabel == "No Tool")

        vm.selectTool(.length)
        #expect(vm.selectedToolLabel == "Length")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Selected tool system image")
    func testToolSystemImage() {
        let vm = MeasurementViewModel()
        #expect(!vm.selectedToolSystemImage.isEmpty)

        vm.selectTool(.angle)
        #expect(vm.selectedToolSystemImage == "angle")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Format length result")
    func testFormatLength() {
        let vm = MeasurementViewModel()
        let result = LinearMeasurementResult(
            lengthPixels: 100,
            lengthMM: 50.0,
            startPoint: AnnotationPoint(x: 0, y: 0),
            endPoint: AnnotationPoint(x: 100, y: 0)
        )
        let text = vm.formatLength(result)
        #expect(text.contains("50.0"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Format angle result")
    func testFormatAngle() {
        let vm = MeasurementViewModel()
        let result = AngleMeasurementResult(
            angleDegrees: 90,
            vertex: AnnotationPoint(x: 0, y: 0),
            point1: AnnotationPoint(x: 100, y: 0),
            point2: AnnotationPoint(x: 0, y: 100)
        )
        let text = vm.formatAngle(result)
        #expect(text.contains("90.0"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Visible measurements")
    func testVisibleMeasurements() {
        let vm = MeasurementViewModel()
        vm.currentSOPInstanceUID = "1.2.3"
        vm.currentFrameNumber = 0
        vm.selectTool(.marker)
        _ = vm.addPoint(AnnotationPoint(x: 50, y: 50))

        #expect(vm.visibleMeasurements.count == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Display unit can be changed")
    func testDisplayUnit() {
        let vm = MeasurementViewModel()
        #expect(vm.displayUnit == .millimeters)

        vm.displayUnit = .centimeters
        #expect(vm.displayUnit == .centimeters)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Panel visibility toggles")
    func testPanelVisibility() {
        let vm = MeasurementViewModel()
        #expect(!vm.showMeasurementList)
        #expect(!vm.showCalibrationPanel)

        vm.showMeasurementList = true
        vm.showCalibrationPanel = true
        #expect(vm.showMeasurementList)
        #expect(vm.showCalibrationPanel)
    }
}
