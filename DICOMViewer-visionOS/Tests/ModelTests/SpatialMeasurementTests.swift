// SpatialMeasurementTests.swift

import Testing
import Foundation
import simd
@testable import DICOMViewer

@Suite("SpatialMeasurement Tests")
struct SpatialMeasurementTests {
    
    @Test("Length measurement creation")
    func testLengthMeasurement() {
        let start = simd_float3(0, 0, 0)
        let end = simd_float3(10, 0, 0)
        
        let measurement = SpatialMeasurement.length(from: start, to: end)
        
        #expect(measurement.type == .length)
        #expect(measurement.value == 10.0)
        #expect(measurement.unit == "mm")
    }
    
    @Test("Angle measurement creation")
    func testAngleMeasurement() {
        let p1 = simd_float3(1, 0, 0)
        let vertex = simd_float3(0, 0, 0)
        let p2 = simd_float3(0, 1, 0)
        
        let measurement = SpatialMeasurement.angle(point1: p1, vertex: vertex, point2: p2)
        
        #expect(measurement.type == .angle)
        #expect(measurement.unit == "°")
        #expect(abs(measurement.value - 90.0) < 0.1)
    }
    
    @Test("Formatted value includes unit")
    func testFormattedValue() {
        let measurement = SpatialMeasurement.length(
            from: .zero,
            to: simd_float3(5.5, 0, 0)
        )
        
        let formatted = measurement.formattedValue
        #expect(formatted.contains("mm"))
    }
}
