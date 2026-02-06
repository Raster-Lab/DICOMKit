// VolumeViewModelTests.swift

import Testing
import Foundation
@testable import DICOMViewer

@Suite("VolumeViewModel Tests")
@MainActor
struct VolumeViewModelTests {
    
    @Test("Initial state")
    func testInitialState() {
        let vm = VolumeViewModel()
        
        #expect(vm.volume == nil)
        #expect(vm.transferFunction.name == "Bone")
        #expect(vm.isRendering == false)
    }
    
    @Test("Transform updates")
    func testTransformUpdates() {
        let vm = VolumeViewModel()
        
        vm.updateScale(2.0)
        #expect(vm.volumeScale == 2.0)
        
        vm.resetTransform()
        #expect(vm.volumeScale == 1.0)
    }
    
    @Test("Transfer function change")
    func testTransferFunctionChange() {
        let vm = VolumeViewModel()
        
        vm.setTransferFunction(.softTissue)
        #expect(vm.transferFunction.name == "Soft Tissue")
    }
    
    @Test("Clipping plane management")
    func testClippingPlanes() {
        let vm = VolumeViewModel()
        
        vm.addClippingPlane(at: .zero, normal: [0, 1, 0])
        #expect(vm.clippingPlanes.count == 1)
        
        vm.clearClippingPlanes()
        #expect(vm.clippingPlanes.isEmpty)
    }
    
    @Test("Render quality settings")
    func testRenderQuality() {
        let vm = VolumeViewModel()
        
        vm.renderQuality = .low
        #expect(vm.renderQuality.samplingRate == 128)
        
        vm.renderQuality = .high
        #expect(vm.renderQuality.samplingRate == 512)
    }
}
