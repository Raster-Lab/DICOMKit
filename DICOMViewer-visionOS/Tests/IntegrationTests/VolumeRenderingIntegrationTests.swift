// VolumeRenderingIntegrationTests.swift

import Testing
import Foundation
@testable import DICOMViewer

@Suite("Volume Rendering Integration Tests")
@MainActor
struct VolumeRenderingIntegrationTests {
    
    @Test("End-to-end volume rendering setup")
    func testVolumeRenderingSetup() async {
        let vm = VolumeViewModel()
        let service = VolumeRenderingService()
        
        // Create test volume
        let volume = createTestVolume()
        vm.volume = volume
        
        // Set transfer function
        vm.setTransferFunction(.bone)
        
        #expect(vm.volume != nil)
        #expect(vm.transferFunction.name == "Bone")
    }
    
    @Test("Measurement workflow")
    func testMeasurementWorkflow() {
        let volumeVM = VolumeViewModel()
        let measurementVM = MeasurementViewModel()
        
        // Setup volume
        volumeVM.volume = createTestVolume()
        
        // Create measurement
        measurementVM.beginMeasurement(tool: .length)
        measurementVM.addPoint(.zero)
        measurementVM.addPoint(simd_float3(10, 0, 0))
        
        #expect(measurementVM.measurements.count == 1)
        #expect(measurementVM.measurements[0].value == 10.0)
    }
    
    private func createTestVolume() -> Volume3D {
        let width = 256, height = 256, depth = 128
        let voxelData = Array(repeating: UInt16(1000), count: width * height * depth)
        return Volume3D(
            width: width,
            height: height,
            depth: depth,
            voxelData: voxelData,
            minValue: 0,
            maxValue: 4095,
            spacing: [1.0, 1.0, 2.0],
            patientName: "Test",
            modality: "CT"
        )
    }
}
