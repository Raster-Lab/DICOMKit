// SurfaceExtractionHelpersTests.swift
// DICOMStudioTests
//
// Tests for surface extraction helpers (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Threshold Tests

@Suite("SurfaceExtractionHelpers Threshold Tests")
struct SurfaceExtractionHelpersThresholdTests {

    @Test("Standard thresholds")
    func testStandardThresholds() {
        #expect(SurfaceExtractionHelpers.boneThreshold == 300.0)
        #expect(SurfaceExtractionHelpers.softTissueThreshold == 0.0)
        #expect(SurfaceExtractionHelpers.skinThreshold == -200.0)
        #expect(SurfaceExtractionHelpers.lungThreshold == -500.0)
    }

    @Test("Standard presets exist")
    func testStandardPresets() {
        #expect(SurfaceExtractionHelpers.standardPresets.count == 4)
        #expect(SurfaceExtractionHelpers.standardPresets[0].label == "Bone")
    }

    @Test("Valid threshold within range")
    func testValidThreshold() {
        #expect(SurfaceExtractionHelpers.isValidThreshold(300.0))
        #expect(SurfaceExtractionHelpers.isValidThreshold(-1024.0))
        #expect(SurfaceExtractionHelpers.isValidThreshold(3071.0))
    }

    @Test("Invalid threshold outside range")
    func testInvalidThreshold() {
        #expect(!SurfaceExtractionHelpers.isValidThreshold(-1025.0))
        #expect(!SurfaceExtractionHelpers.isValidThreshold(3072.0))
    }

    @Test("Clamp threshold")
    func testClampThreshold() {
        #expect(SurfaceExtractionHelpers.clampThreshold(-2000.0) == -1024.0)
        #expect(SurfaceExtractionHelpers.clampThreshold(5000.0) == 3071.0)
        #expect(SurfaceExtractionHelpers.clampThreshold(300.0) == 300.0)
    }
}

// MARK: - Export Format Tests

@Suite("SurfaceExtractionHelpers Export Format Tests")
struct SurfaceExtractionHelpersFormatTests {

    @Test("STL file extension")
    func testSTLExtension() {
        #expect(SurfaceExtractionHelpers.fileExtension(for: .stl) == "stl")
    }

    @Test("OBJ file extension")
    func testOBJExtension() {
        #expect(SurfaceExtractionHelpers.fileExtension(for: .obj) == "obj")
    }

    @Test("MIME types")
    func testMIMETypes() {
        #expect(SurfaceExtractionHelpers.mimeType(for: .stl) == "model/stl")
        #expect(SurfaceExtractionHelpers.mimeType(for: .obj) == "model/obj")
    }

    @Test("Format labels")
    func testFormatLabels() {
        #expect(SurfaceExtractionHelpers.formatLabel(.stl) == "STL (Binary)")
        #expect(SurfaceExtractionHelpers.formatLabel(.obj) == "OBJ (ASCII)")
    }

    @Test("Format descriptions")
    func testFormatDescriptions() {
        #expect(!SurfaceExtractionHelpers.formatDescription(.stl).isEmpty)
        #expect(!SurfaceExtractionHelpers.formatDescription(.obj).isEmpty)
    }
}

// MARK: - File Size Estimation Tests

@Suite("SurfaceExtractionHelpers File Size Tests")
struct SurfaceExtractionHelpersFileSizeTests {

    @Test("STL file size estimation")
    func testSTLSize() {
        // 80 header + 4 count + 50 * triangles
        let size = SurfaceExtractionHelpers.estimatedSTLFileSize(triangleCount: 1000)
        #expect(size == 80 + 4 + 1000 * 50)
    }

    @Test("OBJ file size estimation")
    func testOBJSize() {
        let size = SurfaceExtractionHelpers.estimatedOBJFileSize(vertexCount: 500, triangleCount: 1000)
        #expect(size == 100 + 500 * 30 + 1000 * 20)
    }

    @Test("Format file size bytes")
    func testFormatBytes() {
        #expect(SurfaceExtractionHelpers.formatFileSize(512) == "512 B")
    }

    @Test("Format file size KB")
    func testFormatKB() {
        let result = SurfaceExtractionHelpers.formatFileSize(2048)
        #expect(result.contains("KB"))
    }

    @Test("Format file size MB")
    func testFormatMB() {
        let result = SurfaceExtractionHelpers.formatFileSize(2 * 1024 * 1024)
        #expect(result.contains("MB"))
    }
}

// MARK: - Mesh Summary Tests

@Suite("SurfaceExtractionHelpers Mesh Summary Tests")
struct SurfaceExtractionHelpersMeshSummaryTests {

    @Test("Format mesh summary")
    func testFormatMeshSummary() {
        let stats = MeshStatistics(vertexCount: 1500, triangleCount: 3000, threshold: 300)
        let summary = SurfaceExtractionHelpers.formatMeshSummary(stats)
        #expect(summary.contains("vertices"))
        #expect(summary.contains("triangles"))
    }

    @Test("Format count with separator")
    func testFormatCount() {
        let formatted = SurfaceExtractionHelpers.formatCount(1000000)
        #expect(formatted.contains("1"))
    }
}

// MARK: - Color Presets Tests

@Suite("SurfaceExtractionHelpers Color Presets Tests")
struct SurfaceExtractionHelpersColorPresetsTests {

    @Test("Color presets exist")
    func testPresetsExist() {
        #expect(SurfaceExtractionHelpers.colorPresets.count >= 4)
    }

    @Test("All colors in valid range")
    func testColorRange() {
        for preset in SurfaceExtractionHelpers.colorPresets {
            #expect(preset.red >= 0 && preset.red <= 1)
            #expect(preset.green >= 0 && preset.green <= 1)
            #expect(preset.blue >= 0 && preset.blue <= 1)
        }
    }
}

// MARK: - Surface Validation Tests

@Suite("SurfaceExtractionHelpers Validation Tests")
struct SurfaceExtractionHelpersValidationTests {

    @Test("Empty surfaces produce warning")
    func testEmptySurfaces() {
        let warnings = SurfaceExtractionHelpers.validateSurfaces([])
        #expect(!warnings.isEmpty)
    }

    @Test("Valid single surface produces no warning")
    func testValidSingle() {
        let surfaces = [SurfaceConfiguration(label: "Bone", threshold: 300)]
        let warnings = SurfaceExtractionHelpers.validateSurfaces(surfaces)
        #expect(warnings.isEmpty)
    }

    @Test("Duplicate thresholds produce warning")
    func testDuplicateThresholds() {
        let surfaces = [
            SurfaceConfiguration(label: "Bone 1", threshold: 300),
            SurfaceConfiguration(label: "Bone 2", threshold: 300),
        ]
        let warnings = SurfaceExtractionHelpers.validateSurfaces(surfaces)
        #expect(warnings.contains(where: { $0.contains("same threshold") }))
    }

    @Test("Invalid threshold produces warning")
    func testInvalidThreshold() {
        let surfaces = [SurfaceConfiguration(label: "Bad", threshold: 5000)]
        let warnings = SurfaceExtractionHelpers.validateSurfaces(surfaces)
        #expect(warnings.contains(where: { $0.contains("outside valid") }))
    }
}
