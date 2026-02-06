// TransferFunctionTests.swift

import Testing
import Foundation
@testable import DICOMViewer

@Suite("TransferFunction Tests")
struct TransferFunctionTests {
    
    @Test("Bone preset exists")
    func testBonePreset() {
        let bone = TransferFunction.bone
        #expect(bone.name == "Bone")
        #expect(bone.isPreset == true)
        #expect(!bone.opacityPoints.isEmpty)
    }
    
    @Test("Opacity sampling at edges")
    func testOpacitySampling() {
        let tf = TransferFunction.bone
        let opacity0 = tf.opacity(at: 0.0)
        let opacity1 = tf.opacity(at: 1.0)
        
        #expect(opacity0 >= 0.0)
        #expect(opacity1 <= 1.0)
    }
    
    @Test("All presets available")
    func testAllPresets() {
        let presets = TransferFunction.presets
        #expect(presets.count == 4)
        #expect(presets.contains { $0.name == "Bone" })
        #expect(presets.contains { $0.name == "Soft Tissue" })
        #expect(presets.contains { $0.name == "Vascular" })
        #expect(presets.contains { $0.name == "Lung" })
    }
}
