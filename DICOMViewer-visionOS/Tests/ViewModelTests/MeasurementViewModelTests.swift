// MeasurementViewModelTests.swift

import Testing
import Foundation
import simd
@testable import DICOMViewer

@Suite("MeasurementViewModel Tests")
@MainActor
struct MeasurementViewModelTests {
    
    @Test("Begin length measurement")
    func testBeginLengthMeasurement() {
        let vm = MeasurementViewModel()
        
        vm.beginMeasurement(tool: .length)
        #expect(vm.activeTool == .length)
        #expect(vm.pendingPoints.isEmpty)
    }
    
    @Test("Complete length measurement")
    func testCompleteLengthMeasurement() {
        let vm = MeasurementViewModel()
        
        vm.beginMeasurement(tool: .length)
        vm.addPoint(.zero)
        vm.addPoint(simd_float3(10, 0, 0))
        
        #expect(vm.measurements.count == 1)
        #expect(vm.measurements[0].type == .length)
    }
    
    @Test("Complete angle measurement")
    func testCompleteAngleMeasurement() {
        let vm = MeasurementViewModel()
        
        vm.beginMeasurement(tool: .angle)
        vm.addPoint(simd_float3(1, 0, 0))
        vm.addPoint(.zero)
        vm.addPoint(simd_float3(0, 1, 0))
        
        #expect(vm.measurements.count == 1)
        #expect(vm.measurements[0].type == .angle)
    }
    
    @Test("Delete measurement")
    func testDeleteMeasurement() {
        let vm = MeasurementViewModel()
        let measurement = SpatialMeasurement.length(from: .zero, to: simd_float3(5, 0, 0))
        vm.measurements.append(measurement)
        
        vm.deleteMeasurement(measurement)
        #expect(vm.measurements.isEmpty)
    }
    
    @Test("Clear all measurements")
    func testClearAllMeasurements() {
        let vm = MeasurementViewModel()
        vm.measurements.append(SpatialMeasurement.length(from: .zero, to: simd_float3(5, 0, 0)))
        vm.measurements.append(SpatialMeasurement.length(from: .zero, to: simd_float3(10, 0, 0)))
        
        vm.clearAllMeasurements()
        #expect(vm.measurements.isEmpty)
    }
}
