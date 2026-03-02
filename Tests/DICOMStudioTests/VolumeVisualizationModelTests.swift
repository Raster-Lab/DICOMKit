// VolumeVisualizationModelTests.swift
// DICOMStudioTests
//
// Tests for 3D Visualization models (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - MPRPlane Tests

@Suite("MPRPlane Tests")
struct MPRPlaneTests {

    @Test("All planes have raw values")
    func testRawValues() {
        #expect(MPRPlane.axial.rawValue == "AXIAL")
        #expect(MPRPlane.sagittal.rawValue == "SAGITTAL")
        #expect(MPRPlane.coronal.rawValue == "CORONAL")
    }

    @Test("CaseIterable has 3 planes")
    func testCaseIterable() {
        #expect(MPRPlane.allCases.count == 3)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        #expect(MPRPlane.axial == MPRPlane.axial)
        #expect(MPRPlane.axial != MPRPlane.sagittal)
    }

    @Test("Hashable conformance")
    func testHashable() {
        let set: Set<MPRPlane> = [.axial, .sagittal, .coronal, .axial]
        #expect(set.count == 3)
    }
}

// MARK: - InterpolationQuality Tests

@Suite("InterpolationQuality Tests")
struct InterpolationQualityTests {

    @Test("All qualities have raw values")
    func testRawValues() {
        #expect(InterpolationQuality.nearestNeighbor.rawValue == "NEAREST")
        #expect(InterpolationQuality.bilinear.rawValue == "BILINEAR")
        #expect(InterpolationQuality.bicubic.rawValue == "BICUBIC")
    }

    @Test("CaseIterable has 3 qualities")
    func testCaseIterable() {
        #expect(InterpolationQuality.allCases.count == 3)
    }
}

// MARK: - ProjectionMode Tests

@Suite("ProjectionMode Tests")
struct ProjectionModeTests {

    @Test("All modes have raw values")
    func testRawValues() {
        #expect(ProjectionMode.mip.rawValue == "MIP")
        #expect(ProjectionMode.minIP.rawValue == "MinIP")
        #expect(ProjectionMode.avgIP.rawValue == "AvgIP")
    }

    @Test("CaseIterable has 3 modes")
    func testCaseIterable() {
        #expect(ProjectionMode.allCases.count == 3)
    }
}

// MARK: - TransferFunctionPreset Tests

@Suite("TransferFunctionPreset Tests")
struct TransferFunctionPresetTests {

    @Test("All presets have raw values")
    func testRawValues() {
        #expect(TransferFunctionPreset.bone.rawValue == "BONE")
        #expect(TransferFunctionPreset.skin.rawValue == "SKIN")
        #expect(TransferFunctionPreset.muscle.rawValue == "MUSCLE")
        #expect(TransferFunctionPreset.vascular.rawValue == "VASCULAR")
        #expect(TransferFunctionPreset.lung.rawValue == "LUNG")
        #expect(TransferFunctionPreset.custom.rawValue == "CUSTOM")
    }

    @Test("CaseIterable has 6 presets")
    func testCaseIterable() {
        #expect(TransferFunctionPreset.allCases.count == 6)
    }
}

// MARK: - ShadingModel Tests

@Suite("ShadingModel Tests")
struct ShadingModelTests {

    @Test("All shading models have raw values")
    func testRawValues() {
        #expect(ShadingModel.none.rawValue == "NONE")
        #expect(ShadingModel.flat.rawValue == "FLAT")
        #expect(ShadingModel.phong.rawValue == "PHONG")
    }

    @Test("CaseIterable has 3 models")
    func testCaseIterable() {
        #expect(ShadingModel.allCases.count == 3)
    }
}

// MARK: - SurfaceExportFormat Tests

@Suite("SurfaceExportFormat Tests")
struct SurfaceExportFormatTests {

    @Test("All formats have raw values")
    func testRawValues() {
        #expect(SurfaceExportFormat.stl.rawValue == "STL")
        #expect(SurfaceExportFormat.obj.rawValue == "OBJ")
    }

    @Test("CaseIterable has 2 formats")
    func testCaseIterable() {
        #expect(SurfaceExportFormat.allCases.count == 2)
    }
}

// MARK: - VisualizationMode Tests

@Suite("VisualizationMode Tests")
struct VisualizationModeTests {

    @Test("All modes have raw values")
    func testRawValues() {
        #expect(VisualizationMode.mpr.rawValue == "MPR")
        #expect(VisualizationMode.projection.rawValue == "PROJECTION")
        #expect(VisualizationMode.volumeRendering.rawValue == "VOLUME_RENDERING")
        #expect(VisualizationMode.surfaceRendering.rawValue == "SURFACE_RENDERING")
    }

    @Test("CaseIterable has 4 modes")
    func testCaseIterable() {
        #expect(VisualizationMode.allCases.count == 4)
    }
}

// MARK: - TransferFunctionPoint Tests

@Suite("TransferFunctionPoint Tests")
struct TransferFunctionPointTests {

    @Test("Create point with defaults")
    func testDefaults() {
        let p = TransferFunctionPoint(huValue: 100, opacity: 0.5)
        #expect(p.huValue == 100)
        #expect(p.opacity == 0.5)
        #expect(p.red == 1.0)
        #expect(p.green == 1.0)
        #expect(p.blue == 1.0)
    }

    @Test("Create point with full color")
    func testFullColor() {
        let p = TransferFunctionPoint(huValue: 200, opacity: 0.8, red: 0.5, green: 0.3, blue: 0.7)
        #expect(p.red == 0.5)
        #expect(p.green == 0.3)
        #expect(p.blue == 0.7)
    }

    @Test("Opacity clamped to 0-1")
    func testOpacityClamping() {
        let p1 = TransferFunctionPoint(huValue: 0, opacity: -0.5)
        #expect(p1.opacity == 0.0)
        let p2 = TransferFunctionPoint(huValue: 0, opacity: 1.5)
        #expect(p2.opacity == 1.0)
    }

    @Test("Color components clamped to 0-1")
    func testColorClamping() {
        let p = TransferFunctionPoint(huValue: 0, opacity: 0.5, red: -0.1, green: 1.5, blue: 0.5)
        #expect(p.red == 0.0)
        #expect(p.green == 1.0)
        #expect(p.blue == 0.5)
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let p1 = TransferFunctionPoint(huValue: 0, opacity: 0.5)
        let p2 = TransferFunctionPoint(huValue: 0, opacity: 0.5)
        #expect(p1.id != p2.id)
    }
}

// MARK: - TransferFunction Tests

@Suite("TransferFunction Tests")
struct TransferFunctionTests {

    @Test("Empty transfer function")
    func testEmpty() {
        let tf = TransferFunction(name: "Empty", points: [])
        #expect(tf.isEmpty)
        #expect(tf.huRange == nil)
    }

    @Test("Points are sorted by HU value")
    func testSorting() {
        let tf = TransferFunction(name: "Test", points: [
            TransferFunctionPoint(huValue: 500, opacity: 0.9),
            TransferFunctionPoint(huValue: -1000, opacity: 0.0),
            TransferFunctionPoint(huValue: 200, opacity: 0.5),
        ])
        #expect(tf.points[0].huValue == -1000)
        #expect(tf.points[1].huValue == 200)
        #expect(tf.points[2].huValue == 500)
    }

    @Test("HU range computed correctly")
    func testHURange() {
        let tf = TransferFunction(name: "Test", points: [
            TransferFunctionPoint(huValue: -500, opacity: 0.0),
            TransferFunctionPoint(huValue: 1000, opacity: 1.0),
        ])
        #expect(tf.huRange == -500.0 ... 1000.0)
    }
}

// MARK: - CrosshairPosition3D Tests

@Suite("CrosshairPosition3D Tests")
struct CrosshairPosition3DTests {

    @Test("Origin position")
    func testOrigin() {
        let c = CrosshairPosition3D.origin
        #expect(c.x == 0)
        #expect(c.y == 0)
        #expect(c.z == 0)
        #expect(c.voxelX == 0)
        #expect(c.voxelY == 0)
        #expect(c.voxelZ == 0)
    }

    @Test("Formatted physical coordinates")
    func testFormattedPhysical() {
        let c = CrosshairPosition3D(x: 10.5, y: 20.3, z: 30.7, voxelX: 10, voxelY: 20, voxelZ: 30)
        #expect(c.formattedPhysical == "(10.5, 20.3, 30.7) mm")
    }

    @Test("Formatted voxel coordinates")
    func testFormattedVoxel() {
        let c = CrosshairPosition3D(x: 10.5, y: 20.3, z: 30.7, voxelX: 10, voxelY: 20, voxelZ: 30)
        #expect(c.formattedVoxel == "(10, 20, 30)")
    }
}

// MARK: - MPRSliceConfiguration Tests

@Suite("MPRSliceConfiguration Tests")
struct MPRSliceConfigurationTests {

    @Test("Default configuration")
    func testDefaults() {
        let config = MPRSliceConfiguration(plane: .axial)
        #expect(config.plane == .axial)
        #expect(config.sliceIndex == 0)
        #expect(config.sliceThickness == nil)
        #expect(config.interpolation == .bilinear)
    }

    @Test("Negative slice index clamped to 0")
    func testNegativeIndex() {
        let config = MPRSliceConfiguration(plane: .axial, sliceIndex: -5)
        #expect(config.sliceIndex == 0)
    }

    @Test("Builder withSliceIndex")
    func testWithSliceIndex() {
        let config = MPRSliceConfiguration(plane: .sagittal, sliceIndex: 10)
        let updated = config.withSliceIndex(25)
        #expect(updated.sliceIndex == 25)
        #expect(updated.plane == .sagittal)
    }

    @Test("Builder withInterpolation")
    func testWithInterpolation() {
        let config = MPRSliceConfiguration(plane: .coronal)
        let updated = config.withInterpolation(.bicubic)
        #expect(updated.interpolation == .bicubic)
        #expect(updated.plane == .coronal)
    }

    @Test("Builder withSliceThickness")
    func testWithSliceThickness() {
        let config = MPRSliceConfiguration(plane: .axial)
        let updated = config.withSliceThickness(5.0)
        #expect(updated.sliceThickness == 5.0)
    }
}

// MARK: - ObliquePlaneConfiguration Tests

@Suite("ObliquePlaneConfiguration Tests")
struct ObliquePlaneConfigurationTests {

    @Test("Valid oblique plane")
    func testValid() {
        let config = ObliquePlaneConfiguration(normalX: 0, normalY: 0, normalZ: 1, centerX: 0, centerY: 0, centerZ: 50)
        #expect(config.isValid)
    }

    @Test("Zero normal is invalid")
    func testZeroNormal() {
        let config = ObliquePlaneConfiguration(normalX: 0, normalY: 0, normalZ: 0, centerX: 0, centerY: 0, centerZ: 0)
        #expect(!config.isValid)
    }
}

// MARK: - ProjectionConfiguration Tests

@Suite("ProjectionConfiguration Tests")
struct ProjectionConfigurationTests {

    @Test("Default projection")
    func testDefaults() {
        let config = ProjectionConfiguration(mode: .mip)
        #expect(config.mode == .mip)
        #expect(config.direction == .axial)
        #expect(!config.isSlab)
    }

    @Test("Slab projection")
    func testSlab() {
        let config = ProjectionConfiguration(mode: .mip, slabThickness: 20.0)
        #expect(config.isSlab)
    }

    @Test("Slab from slice range")
    func testSlabFromRange() {
        let config = ProjectionConfiguration(mode: .minIP, startSlice: 10, endSlice: 30)
        #expect(config.isSlab)
    }
}

// MARK: - ClipPlane Tests

@Suite("ClipPlane Tests")
struct ClipPlaneTests {

    @Test("Default clip plane is enabled")
    func testDefault() {
        let clip = ClipPlane(normalX: 1, normalY: 0, normalZ: 0, distance: 50)
        #expect(clip.isEnabled)
    }

    @Test("Builder withEnabled")
    func testWithEnabled() {
        let clip = ClipPlane(normalX: 1, normalY: 0, normalZ: 0, distance: 50)
        let disabled = clip.withEnabled(false)
        #expect(!disabled.isEnabled)
        #expect(disabled.id == clip.id)
    }

    @Test("Builder withDistance")
    func testWithDistance() {
        let clip = ClipPlane(normalX: 1, normalY: 0, normalZ: 0, distance: 50)
        let moved = clip.withDistance(75.0)
        #expect(moved.distance == 75.0)
        #expect(moved.id == clip.id)
    }
}

// MARK: - SurfaceConfiguration Tests

@Suite("SurfaceConfiguration Tests")
struct SurfaceConfigurationTests {

    @Test("Default surface")
    func testDefault() {
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        #expect(surface.label == "Bone")
        #expect(surface.threshold == 300)
        #expect(surface.red == 1.0)
        #expect(surface.opacity == 1.0)
        #expect(surface.isVisible)
    }

    @Test("Color and opacity clamped")
    func testClamping() {
        let surface = SurfaceConfiguration(label: "Test", threshold: 0, red: 1.5, green: -0.1, blue: 0.5, opacity: 2.0)
        #expect(surface.red == 1.0)
        #expect(surface.green == 0.0)
        #expect(surface.blue == 0.5)
        #expect(surface.opacity == 1.0)
    }

    @Test("Builder withVisible")
    func testWithVisible() {
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        let hidden = surface.withVisible(false)
        #expect(!hidden.isVisible)
        #expect(hidden.id == surface.id)
    }

    @Test("Builder withOpacity")
    func testWithOpacity() {
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        let updated = surface.withOpacity(0.5)
        #expect(updated.opacity == 0.5)
    }

    @Test("Builder withThreshold")
    func testWithThreshold() {
        let surface = SurfaceConfiguration(label: "Bone", threshold: 300)
        let updated = surface.withThreshold(200)
        #expect(updated.threshold == 200)
    }
}

// MARK: - VolumeRenderingConfiguration Tests

@Suite("VolumeRenderingConfiguration Tests")
struct VolumeRenderingConfigurationTests {

    @Test("Default configuration")
    func testDefaults() {
        let config = VolumeRenderingConfiguration()
        #expect(config.shadingModel == .phong)
        #expect(config.ambientCoefficient == 0.2)
        #expect(config.diffuseCoefficient == 0.7)
        #expect(config.specularCoefficient == 0.3)
        #expect(config.rotationX == 0)
        #expect(config.zoom == 1.0)
        #expect(!config.isEnabled)
    }

    @Test("Coefficient clamping")
    func testClamping() {
        let config = VolumeRenderingConfiguration(ambientCoefficient: -0.1, diffuseCoefficient: 1.5, zoom: 0.01)
        #expect(config.ambientCoefficient == 0.0)
        #expect(config.diffuseCoefficient == 1.0)
        #expect(config.zoom == 0.1)
    }

    @Test("Active clip planes filter")
    func testActiveClipPlanes() {
        let active = ClipPlane(normalX: 1, normalY: 0, normalZ: 0, distance: 50, isEnabled: true)
        let inactive = ClipPlane(normalX: 0, normalY: 1, normalZ: 0, distance: 30, isEnabled: false)
        let config = VolumeRenderingConfiguration(clipPlanes: [active, inactive])
        #expect(config.activeClipPlanes.count == 1)
    }
}

// MARK: - VolumeDimensionsModel Tests

@Suite("VolumeDimensionsModel Tests")
struct VolumeDimensionsModelTests {

    @Test("Total voxels")
    func testTotalVoxels() {
        let dims = VolumeDimensionsModel(width: 256, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        #expect(dims.totalVoxels == 256 * 256 * 100)
    }

    @Test("Physical dimensions")
    func testPhysicalDimensions() {
        let dims = VolumeDimensionsModel(width: 512, height: 512, depth: 200, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        #expect(dims.physicalWidth == 256.0)
        #expect(dims.physicalHeight == 256.0)
        #expect(dims.physicalDepth == 200.0)
    }

    @Test("Max slice index for each plane")
    func testMaxSliceIndex() {
        let dims = VolumeDimensionsModel(width: 512, height: 256, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        #expect(dims.maxSliceIndex(for: .axial) == 99)
        #expect(dims.maxSliceIndex(for: .sagittal) == 511)
        #expect(dims.maxSliceIndex(for: .coronal) == 255)
    }

    @Test("Formatted dimensions")
    func testFormattedDimensions() {
        let dims = VolumeDimensionsModel(width: 512, height: 512, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        #expect(dims.formattedDimensions == "512 × 512 × 100")
    }

    @Test("Isotropic detection")
    func testIsotropic() {
        let iso = VolumeDimensionsModel(width: 100, height: 100, depth: 100, spacingX: 1.0, spacingY: 1.0, spacingZ: 1.0)
        #expect(iso.isIsotropic)

        let aniso = VolumeDimensionsModel(width: 100, height: 100, depth: 100, spacingX: 0.5, spacingY: 0.5, spacingZ: 1.0)
        #expect(!aniso.isIsotropic)
    }
}

// MARK: - MeshStatistics Tests

@Suite("MeshStatistics Tests")
struct MeshStatisticsTests {

    @Test("Valid mesh")
    func testValid() {
        let stats = MeshStatistics(vertexCount: 1000, triangleCount: 500, threshold: 300)
        #expect(stats.isValid)
    }

    @Test("Empty mesh is invalid")
    func testEmpty() {
        let stats = MeshStatistics(vertexCount: 0, triangleCount: 0, threshold: 300)
        #expect(!stats.isValid)
    }
}
