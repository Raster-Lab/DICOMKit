// VolumeRenderingHelpersTests.swift
// DICOMStudioTests
//
// Tests for volume rendering helpers (Milestone 6)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - Transfer Function Preset Tests

@Suite("VolumeRenderingHelpers Preset Tests")
struct VolumeRenderingHelpersPresetTests {

    @Test("Bone preset has points")
    func testBonePreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .bone)
        #expect(tf.name == "Bone")
        #expect(!tf.isEmpty)
        #expect(tf.points.count >= 4)
    }

    @Test("Skin preset has points")
    func testSkinPreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .skin)
        #expect(tf.name == "Skin")
        #expect(!tf.isEmpty)
    }

    @Test("Muscle preset has points")
    func testMusclePreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .muscle)
        #expect(tf.name == "Muscle")
        #expect(!tf.isEmpty)
    }

    @Test("Vascular preset has points")
    func testVascularPreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .vascular)
        #expect(tf.name == "Vascular")
        #expect(!tf.isEmpty)
    }

    @Test("Lung preset has points")
    func testLungPreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .lung)
        #expect(tf.name == "Lung")
        #expect(!tf.isEmpty)
    }

    @Test("Custom preset is empty")
    func testCustomPreset() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .custom)
        #expect(tf.name == "Custom")
        #expect(tf.isEmpty)
    }

    @Test("All preset points are sorted by HU value")
    func testAllPresetsSorted() {
        for preset in TransferFunctionPreset.allCases {
            let tf = VolumeRenderingHelpers.transferFunction(for: preset)
            for i in 0..<max(0, tf.points.count - 1) {
                #expect(tf.points[i].huValue <= tf.points[i + 1].huValue)
            }
        }
    }
}

// MARK: - Opacity Interpolation Tests

@Suite("VolumeRenderingHelpers Opacity Interpolation Tests")
struct VolumeRenderingHelpersOpacityTests {

    let tf = TransferFunction(name: "Test", points: [
        TransferFunctionPoint(huValue: 0, opacity: 0.0),
        TransferFunctionPoint(huValue: 100, opacity: 0.5),
        TransferFunctionPoint(huValue: 200, opacity: 1.0),
    ])

    @Test("Interpolate at exact point")
    func testExactPoint() {
        let opacity = VolumeRenderingHelpers.interpolateOpacity(huValue: 100, transferFunction: tf)
        #expect(opacity == 0.5)
    }

    @Test("Interpolate at midpoint")
    func testMidpoint() {
        let opacity = VolumeRenderingHelpers.interpolateOpacity(huValue: 50, transferFunction: tf)
        #expect(abs(opacity - 0.25) < 0.001)
    }

    @Test("Below minimum returns first opacity")
    func testBelowMinimum() {
        let opacity = VolumeRenderingHelpers.interpolateOpacity(huValue: -500, transferFunction: tf)
        #expect(opacity == 0.0)
    }

    @Test("Above maximum returns last opacity")
    func testAboveMaximum() {
        let opacity = VolumeRenderingHelpers.interpolateOpacity(huValue: 500, transferFunction: tf)
        #expect(opacity == 1.0)
    }

    @Test("Empty transfer function returns 0")
    func testEmptyTF() {
        let empty = TransferFunction(name: "Empty", points: [])
        let opacity = VolumeRenderingHelpers.interpolateOpacity(huValue: 100, transferFunction: empty)
        #expect(opacity == 0.0)
    }
}

// MARK: - Color Interpolation Tests

@Suite("VolumeRenderingHelpers Color Interpolation Tests")
struct VolumeRenderingHelpersColorTests {

    let tf = TransferFunction(name: "Test", points: [
        TransferFunctionPoint(huValue: 0, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.0),
        TransferFunctionPoint(huValue: 100, opacity: 1.0, red: 1.0, green: 1.0, blue: 1.0),
    ])

    @Test("Interpolate color at midpoint")
    func testMidpoint() {
        let (r, g, b) = VolumeRenderingHelpers.interpolateColor(huValue: 50, transferFunction: tf)
        #expect(abs(r - 0.5) < 0.001)
        #expect(abs(g - 0.5) < 0.001)
        #expect(abs(b - 0.5) < 0.001)
    }

    @Test("Below minimum returns first color")
    func testBelowMinimum() {
        let (r, g, b) = VolumeRenderingHelpers.interpolateColor(huValue: -100, transferFunction: tf)
        #expect(r == 0.0)
        #expect(g == 0.0)
        #expect(b == 0.0)
    }

    @Test("Above maximum returns last color")
    func testAboveMaximum() {
        let (r, g, b) = VolumeRenderingHelpers.interpolateColor(huValue: 200, transferFunction: tf)
        #expect(r == 1.0)
        #expect(g == 1.0)
        #expect(b == 1.0)
    }

    @Test("Empty transfer function returns black")
    func testEmptyTF() {
        let empty = TransferFunction(name: "Empty", points: [])
        let (r, g, b) = VolumeRenderingHelpers.interpolateColor(huValue: 50, transferFunction: empty)
        #expect(r == 0.0)
        #expect(g == 0.0)
        #expect(b == 0.0)
    }
}

// MARK: - Phong Shading Tests

@Suite("VolumeRenderingHelpers Phong Shading Tests")
struct VolumeRenderingHelpersPhongTests {

    let config = VolumeRenderingConfiguration(
        ambientCoefficient: 0.2,
        diffuseCoefficient: 0.7,
        specularCoefficient: 0.3,
        specularExponent: 20.0
    )

    @Test("Front-facing surface has diffuse component")
    func testFrontFacing() {
        let intensity = VolumeRenderingHelpers.phongShading(
            normalX: 0, normalY: 0, normalZ: 1,
            lightX: 0, lightY: 0, lightZ: 1,
            viewX: 0, viewY: 0, viewZ: 1,
            config: config
        )
        // Should have ambient + diffuse + specular
        #expect(intensity > config.ambientCoefficient)
        #expect(intensity > 0.5)
    }

    @Test("Back-facing surface has only ambient")
    func testBackFacing() {
        let intensity = VolumeRenderingHelpers.phongShading(
            normalX: 0, normalY: 0, normalZ: -1,
            lightX: 0, lightY: 0, lightZ: 1,
            viewX: 0, viewY: 0, viewZ: 1,
            config: config
        )
        // N·L is negative → only ambient
        #expect(abs(intensity - config.ambientCoefficient) < 0.001)
    }

    @Test("Zero normal returns ambient only")
    func testZeroNormal() {
        let intensity = VolumeRenderingHelpers.phongShading(
            normalX: 0, normalY: 0, normalZ: 0,
            lightX: 0, lightY: 0, lightZ: 1,
            viewX: 0, viewY: 0, viewZ: 1,
            config: config
        )
        #expect(abs(intensity - config.ambientCoefficient) < 0.001)
    }

    @Test("Zero light direction returns ambient")
    func testZeroLight() {
        let intensity = VolumeRenderingHelpers.phongShading(
            normalX: 0, normalY: 0, normalZ: 1,
            lightX: 0, lightY: 0, lightZ: 0,
            viewX: 0, viewY: 0, viewZ: 1,
            config: config
        )
        #expect(abs(intensity - config.ambientCoefficient) < 0.001)
    }
}

// MARK: - Display Label Tests

@Suite("VolumeRenderingHelpers Label Tests")
struct VolumeRenderingHelpersLabelTests {

    @Test("Shading labels")
    func testShadingLabels() {
        #expect(VolumeRenderingHelpers.shadingLabel(.none) == "No Shading")
        #expect(VolumeRenderingHelpers.shadingLabel(.flat) == "Flat Shading")
        #expect(VolumeRenderingHelpers.shadingLabel(.phong) == "Phong Shading")
    }

    @Test("Preset labels")
    func testPresetLabels() {
        #expect(VolumeRenderingHelpers.presetLabel(.bone) == "Bone")
        #expect(VolumeRenderingHelpers.presetLabel(.skin) == "Skin")
        #expect(VolumeRenderingHelpers.presetLabel(.vascular) == "Vascular")
    }

    @Test("Preset symbols are non-empty")
    func testPresetSymbols() {
        for preset in TransferFunctionPreset.allCases {
            #expect(!VolumeRenderingHelpers.presetSymbol(preset).isEmpty)
        }
    }
}

// MARK: - Configuration Validation Tests

@Suite("VolumeRenderingHelpers Validation Tests")
struct VolumeRenderingHelpersValidationTests {

    @Test("Valid configuration produces no errors")
    func testValid() {
        let tf = VolumeRenderingHelpers.transferFunction(for: .bone)
        let config = VolumeRenderingConfiguration(transferFunction: tf, preset: .bone)
        let errors = VolumeRenderingHelpers.validateConfiguration(config)
        #expect(errors.isEmpty)
    }

    @Test("Empty non-custom transfer function produces error")
    func testEmptyNonCustom() {
        let config = VolumeRenderingConfiguration(preset: .bone)
        let errors = VolumeRenderingHelpers.validateConfiguration(config)
        #expect(!errors.isEmpty)
    }

    @Test("Custom preset with empty TF is valid")
    func testCustomEmpty() {
        let config = VolumeRenderingConfiguration(preset: .custom)
        let errors = VolumeRenderingHelpers.validateConfiguration(config)
        // Custom preset is allowed to have empty TF
        #expect(errors.isEmpty)
    }
}
