// VolumeRenderingHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent volume rendering helpers

import Foundation

/// Platform-independent helpers for volume rendering transfer functions,
/// preset generation, color mapping, and Phong shading calculations.
public enum VolumeRenderingHelpers: Sendable {

    // MARK: - Transfer Function Presets

    /// Generates a preset transfer function.
    ///
    /// - Parameter preset: The preset type.
    /// - Returns: A `TransferFunction` matching the preset.
    public static func transferFunction(for preset: TransferFunctionPreset) -> TransferFunction {
        switch preset {
        case .bone:
            return TransferFunction(name: "Bone", points: [
                TransferFunctionPoint(huValue: -1000, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.0),
                TransferFunctionPoint(huValue: 200, opacity: 0.0, red: 0.9, green: 0.85, blue: 0.7),
                TransferFunctionPoint(huValue: 300, opacity: 0.3, red: 0.95, green: 0.9, blue: 0.75),
                TransferFunctionPoint(huValue: 500, opacity: 0.6, red: 1.0, green: 0.95, blue: 0.85),
                TransferFunctionPoint(huValue: 1500, opacity: 0.9, red: 1.0, green: 1.0, blue: 1.0),
            ])
        case .skin:
            return TransferFunction(name: "Skin", points: [
                TransferFunctionPoint(huValue: -1000, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.0),
                TransferFunctionPoint(huValue: -500, opacity: 0.0, red: 0.9, green: 0.7, blue: 0.6),
                TransferFunctionPoint(huValue: -100, opacity: 0.3, red: 0.95, green: 0.75, blue: 0.65),
                TransferFunctionPoint(huValue: 0, opacity: 0.5, red: 1.0, green: 0.8, blue: 0.7),
                TransferFunctionPoint(huValue: 200, opacity: 0.1, red: 0.9, green: 0.7, blue: 0.6),
            ])
        case .muscle:
            return TransferFunction(name: "Muscle", points: [
                TransferFunctionPoint(huValue: -1000, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.0),
                TransferFunctionPoint(huValue: 0, opacity: 0.0, red: 0.7, green: 0.3, blue: 0.2),
                TransferFunctionPoint(huValue: 30, opacity: 0.2, red: 0.8, green: 0.4, blue: 0.3),
                TransferFunctionPoint(huValue: 60, opacity: 0.5, red: 0.85, green: 0.45, blue: 0.35),
                TransferFunctionPoint(huValue: 100, opacity: 0.3, red: 0.7, green: 0.35, blue: 0.25),
            ])
        case .vascular:
            return TransferFunction(name: "Vascular", points: [
                TransferFunctionPoint(huValue: -1000, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.0),
                TransferFunctionPoint(huValue: 100, opacity: 0.0, red: 0.8, green: 0.1, blue: 0.1),
                TransferFunctionPoint(huValue: 150, opacity: 0.3, red: 0.9, green: 0.15, blue: 0.15),
                TransferFunctionPoint(huValue: 250, opacity: 0.7, red: 1.0, green: 0.2, blue: 0.2),
                TransferFunctionPoint(huValue: 500, opacity: 0.9, red: 1.0, green: 0.3, blue: 0.3),
            ])
        case .lung:
            return TransferFunction(name: "Lung", points: [
                TransferFunctionPoint(huValue: -1000, opacity: 0.0, red: 0.0, green: 0.0, blue: 0.2),
                TransferFunctionPoint(huValue: -900, opacity: 0.1, red: 0.3, green: 0.5, blue: 0.8),
                TransferFunctionPoint(huValue: -600, opacity: 0.3, red: 0.5, green: 0.7, blue: 0.9),
                TransferFunctionPoint(huValue: -400, opacity: 0.1, red: 0.7, green: 0.85, blue: 0.95),
                TransferFunctionPoint(huValue: 0, opacity: 0.0, red: 0.8, green: 0.8, blue: 0.8),
            ])
        case .custom:
            return TransferFunction(name: "Custom", points: [])
        }
    }

    // MARK: - Transfer Function Interpolation

    /// Interpolates opacity at a given HU value using a transfer function.
    ///
    /// - Parameters:
    ///   - huValue: Hounsfield Unit value.
    ///   - transferFunction: The transfer function to sample.
    /// - Returns: Interpolated opacity (0.0–1.0).
    public static func interpolateOpacity(
        huValue: Double,
        transferFunction: TransferFunction
    ) -> Double {
        guard !transferFunction.isEmpty else { return 0.0 }

        let points = transferFunction.points
        guard let first = points.first, let last = points.last else { return 0.0 }

        if huValue <= first.huValue { return first.opacity }
        if huValue >= last.huValue { return last.opacity }

        // Find bracketing points
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            if huValue >= p0.huValue && huValue <= p1.huValue {
                let range = p1.huValue - p0.huValue
                guard range > 0 else { return p0.opacity }
                let t = (huValue - p0.huValue) / range
                return p0.opacity + t * (p1.opacity - p0.opacity)
            }
        }

        return 0.0
    }

    /// Interpolates color (RGB) at a given HU value using a transfer function.
    ///
    /// - Parameters:
    ///   - huValue: Hounsfield Unit value.
    ///   - transferFunction: The transfer function to sample.
    /// - Returns: (red, green, blue) each in 0.0–1.0.
    public static func interpolateColor(
        huValue: Double,
        transferFunction: TransferFunction
    ) -> (red: Double, green: Double, blue: Double) {
        guard !transferFunction.isEmpty else { return (0.0, 0.0, 0.0) }

        let points = transferFunction.points
        guard let first = points.first, let last = points.last else { return (0.0, 0.0, 0.0) }

        if huValue <= first.huValue { return (first.red, first.green, first.blue) }
        if huValue >= last.huValue { return (last.red, last.green, last.blue) }

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            if huValue >= p0.huValue && huValue <= p1.huValue {
                let range = p1.huValue - p0.huValue
                guard range > 0 else { return (p0.red, p0.green, p0.blue) }
                let t = (huValue - p0.huValue) / range
                let r = p0.red + t * (p1.red - p0.red)
                let g = p0.green + t * (p1.green - p0.green)
                let b = p0.blue + t * (p1.blue - p0.blue)
                return (r, g, b)
            }
        }

        return (0.0, 0.0, 0.0)
    }

    // MARK: - Phong Shading

    /// Computes a Phong-shaded intensity value.
    ///
    /// - Parameters:
    ///   - normalX: Surface normal X component.
    ///   - normalY: Surface normal Y component.
    ///   - normalZ: Surface normal Z component.
    ///   - lightX: Light direction X.
    ///   - lightY: Light direction Y.
    ///   - lightZ: Light direction Z.
    ///   - viewX: View direction X.
    ///   - viewY: View direction Y.
    ///   - viewZ: View direction Z.
    ///   - config: Volume rendering configuration.
    /// - Returns: Shading intensity (0.0–1.0+).
    public static func phongShading(
        normalX: Double, normalY: Double, normalZ: Double,
        lightX: Double, lightY: Double, lightZ: Double,
        viewX: Double, viewY: Double, viewZ: Double,
        config: VolumeRenderingConfiguration
    ) -> Double {
        // Normalize normal
        let nLen = sqrt(normalX * normalX + normalY * normalY + normalZ * normalZ)
        guard nLen > 1e-10 else { return config.ambientCoefficient }
        let nx = normalX / nLen
        let ny = normalY / nLen
        let nz = normalZ / nLen

        // Normalize light direction
        let lLen = sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ)
        guard lLen > 1e-10 else { return config.ambientCoefficient }
        let lx = lightX / lLen
        let ly = lightY / lLen
        let lz = lightZ / lLen

        // Ambient
        let ambient = config.ambientCoefficient

        // Diffuse (N · L)
        let nDotL = max(0.0, nx * lx + ny * ly + nz * lz)
        let diffuse = config.diffuseCoefficient * nDotL

        // Specular (R · V)^n
        let specular: Double
        if nDotL > 0 {
            // Reflect: R = 2(N·L)N - L
            let rx = 2.0 * nDotL * nx - lx
            let ry = 2.0 * nDotL * ny - ly
            let rz = 2.0 * nDotL * nz - lz

            let vLen = sqrt(viewX * viewX + viewY * viewY + viewZ * viewZ)
            guard vLen > 1e-10 else { return ambient + diffuse }
            let vx = viewX / vLen
            let vy = viewY / vLen
            let vz = viewZ / vLen

            let rDotV = max(0.0, rx * vx + ry * vy + rz * vz)
            specular = config.specularCoefficient * pow(rDotV, config.specularExponent)
        } else {
            specular = 0.0
        }

        return ambient + diffuse + specular
    }

    // MARK: - Display Labels

    /// Returns a user-facing label for a shading model.
    ///
    /// - Parameter model: The shading model.
    /// - Returns: Display string.
    public static func shadingLabel(_ model: ShadingModel) -> String {
        switch model {
        case .none: return "No Shading"
        case .flat: return "Flat Shading"
        case .phong: return "Phong Shading"
        }
    }

    /// Returns a user-facing label for a transfer function preset.
    ///
    /// - Parameter preset: The preset.
    /// - Returns: Display string.
    public static func presetLabel(_ preset: TransferFunctionPreset) -> String {
        switch preset {
        case .bone: return "Bone"
        case .skin: return "Skin"
        case .muscle: return "Muscle"
        case .vascular: return "Vascular"
        case .lung: return "Lung"
        case .custom: return "Custom"
        }
    }

    /// Returns an SF Symbol name for a transfer function preset.
    ///
    /// - Parameter preset: The preset.
    /// - Returns: SF Symbol name.
    public static func presetSymbol(_ preset: TransferFunctionPreset) -> String {
        switch preset {
        case .bone: return "figure.stand"
        case .skin: return "hand.raised"
        case .muscle: return "bolt.heart"
        case .vascular: return "heart"
        case .lung: return "lungs"
        case .custom: return "slider.horizontal.3"
        }
    }

    // MARK: - Configuration Validation

    /// Validates a volume rendering configuration.
    ///
    /// - Parameter config: The configuration to validate.
    /// - Returns: Array of validation error messages (empty if valid).
    public static func validateConfiguration(
        _ config: VolumeRenderingConfiguration
    ) -> [String] {
        var errors: [String] = []

        if config.transferFunction.isEmpty && config.preset != .custom {
            errors.append("Transfer function has no control points")
        }
        if config.zoom < 0.1 {
            errors.append("Zoom must be at least 0.1")
        }
        if config.ambientCoefficient + config.diffuseCoefficient + config.specularCoefficient > 3.0 {
            errors.append("Lighting coefficients are unusually high")
        }

        return errors
    }
}
