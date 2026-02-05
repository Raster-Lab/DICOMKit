//
// SUVCalculator.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// PET Standardized Uptake Value Calculator
///
/// Calculates various SUV normalizations for PET imaging:
/// - SUVbw: Body weight normalized
/// - SUVlbm: Lean body mass normalized
/// - SUVbsa: Body surface area normalized
/// - SUVibw: Ideal body weight normalized
///
/// Reference: DICOM PS3.3 C.8.9.1 - PET Image Module
/// Reference: DICOM PS3.16 CID 4100 - PET Units
public struct SUVCalculator: Sendable {
    
    // MARK: - Patient Parameters
    
    /// Patient weight in kilograms
    public let patientWeight: Double
    
    /// Patient height in meters (optional, required for BSA and LBM calculations)
    public let patientHeight: Double?
    
    /// Patient sex (optional, required for ideal body weight calculation)
    public let patientSex: PatientSex?
    
    // MARK: - Radiopharmaceutical Parameters
    
    /// Injected dose in Bq (becquerels)
    public let injectedDose: Double
    
    /// Injection time
    public let injectionTime: Date
    
    /// Radionuclide half-life in seconds
    public let radionuclideHalfLife: Double
    
    /// Series acquisition time (for decay correction)
    public let seriesTime: Date
    
    // MARK: - Initialization
    
    /// Initialize SUV Calculator
    ///
    /// - Parameters:
    ///   - patientWeight: Patient weight in kg
    ///   - patientHeight: Patient height in meters (optional)
    ///   - patientSex: Patient sex (optional)
    ///   - injectedDose: Injected dose in Bq
    ///   - injectionTime: Time of injection
    ///   - radionuclideHalfLife: Radionuclide half-life in seconds
    ///   - seriesTime: Series acquisition time
    public init(
        patientWeight: Double,
        patientHeight: Double? = nil,
        patientSex: PatientSex? = nil,
        injectedDose: Double,
        injectionTime: Date,
        radionuclideHalfLife: Double,
        seriesTime: Date
    ) {
        self.patientWeight = patientWeight
        self.patientHeight = patientHeight
        self.patientSex = patientSex
        self.injectedDose = injectedDose
        self.injectionTime = injectionTime
        self.radionuclideHalfLife = radionuclideHalfLife
        self.seriesTime = seriesTime
    }
    
    // MARK: - Decay Correction
    
    /// Calculate decay-corrected dose at series acquisition time
    ///
    /// - Returns: Decay-corrected injected dose in Bq
    public func decayCorrectedDose() -> Double {
        let timeElapsed = seriesTime.timeIntervalSince(injectionTime)
        let decayConstant = log(2.0) / radionuclideHalfLife
        return injectedDose * exp(-decayConstant * timeElapsed)
    }
    
    // MARK: - SUV Calculations
    
    /// Calculate SUV body weight (SUVbw)
    ///
    /// SUVbw = (Activity Concentration [Bq/ml]) / (Injected Dose [Bq] / Patient Weight [g])
    ///
    /// - Parameter activityConcentration: Activity concentration in Bq/ml
    /// - Returns: SUVbw (unitless, typically g/ml)
    public func suvBodyWeight(activityConcentration: Double) -> Double {
        let decayedDose = decayCorrectedDose()
        let patientWeightGrams = patientWeight * 1000.0 // kg to g
        return activityConcentration / (decayedDose / patientWeightGrams)
    }
    
    /// Calculate SUV lean body mass (SUVlbm)
    ///
    /// Uses James formula for lean body mass:
    /// - Males: LBM = 1.10 × Weight - 128 × (Weight/Height)²
    /// - Females: LBM = 1.07 × Weight - 148 × (Weight/Height)²
    ///
    /// - Parameter activityConcentration: Activity concentration in Bq/ml
    /// - Returns: SUVlbm, or nil if height or sex is not available
    public func suvLeanBodyMass(activityConcentration: Double) -> Double? {
        guard let height = patientHeight, let sex = patientSex else {
            return nil
        }
        
        let lbm = calculateLeanBodyMass(weight: patientWeight, height: height, sex: sex)
        let decayedDose = decayCorrectedDose()
        let lbmGrams = lbm * 1000.0 // kg to g
        
        return activityConcentration / (decayedDose / lbmGrams)
    }
    
    /// Calculate SUV body surface area (SUVbsa)
    ///
    /// Uses Du Bois formula for body surface area:
    /// BSA = 0.007184 × Height^0.725 × Weight^0.425
    ///
    /// - Parameter activityConcentration: Activity concentration in Bq/ml
    /// - Returns: SUVbsa, or nil if height is not available
    public func suvBodySurfaceArea(activityConcentration: Double) -> Double? {
        guard let height = patientHeight else {
            return nil
        }
        
        let bsa = calculateBodySurfaceArea(weight: patientWeight, height: height)
        let decayedDose = decayCorrectedDose()
        let bsaCm2 = bsa * 10000.0 // m² to cm²
        
        return activityConcentration / (decayedDose / bsaCm2)
    }
    
    /// Calculate SUV ideal body weight (SUVibw)
    ///
    /// Uses Devine formula for ideal body weight:
    /// - Males: IBW = 50 + 2.3 × (Height [inches] - 60)
    /// - Females: IBW = 45.5 + 2.3 × (Height [inches] - 60)
    ///
    /// - Parameter activityConcentration: Activity concentration in Bq/ml
    /// - Returns: SUVibw, or nil if height or sex is not available
    public func suvIdealBodyWeight(activityConcentration: Double) -> Double? {
        guard let height = patientHeight, let sex = patientSex else {
            return nil
        }
        
        let ibw = calculateIdealBodyWeight(height: height, sex: sex)
        let decayedDose = decayCorrectedDose()
        let ibwGrams = ibw * 1000.0 // kg to g
        
        return activityConcentration / (decayedDose / ibwGrams)
    }
    
    // MARK: - Helper Calculations
    
    /// Calculate lean body mass using James formula
    ///
    /// - Parameters:
    ///   - weight: Patient weight in kg
    ///   - height: Patient height in meters
    ///   - sex: Patient sex
    /// - Returns: Lean body mass in kg
    private func calculateLeanBodyMass(
        weight: Double,
        height: Double,
        sex: PatientSex
    ) -> Double {
        let heightCm = height * 100.0
        
        switch sex {
        case .male:
            // LBM = 1.10 × Weight - 128 × (Weight/Height)²
            return 1.10 * weight - 128.0 * pow(weight / heightCm, 2)
            
        case .female:
            // LBM = 1.07 × Weight - 148 × (Weight/Height)²
            return 1.07 * weight - 148.0 * pow(weight / heightCm, 2)
            
        case .other:
            // Use average of male and female formulas
            let maleLBM = 1.10 * weight - 128.0 * pow(weight / heightCm, 2)
            let femaleLBM = 1.07 * weight - 148.0 * pow(weight / heightCm, 2)
            return (maleLBM + femaleLBM) / 2.0
        }
    }
    
    /// Calculate body surface area using Du Bois formula
    ///
    /// BSA (m²) = 0.007184 × Height^0.725 × Weight^0.425
    ///
    /// - Parameters:
    ///   - weight: Patient weight in kg
    ///   - height: Patient height in meters
    /// - Returns: Body surface area in m²
    private func calculateBodySurfaceArea(
        weight: Double,
        height: Double
    ) -> Double {
        let heightCm = height * 100.0
        return 0.007184 * pow(heightCm, 0.725) * pow(weight, 0.425)
    }
    
    /// Calculate ideal body weight using Devine formula
    ///
    /// - Parameters:
    ///   - height: Patient height in meters
    ///   - sex: Patient sex
    /// - Returns: Ideal body weight in kg
    private func calculateIdealBodyWeight(
        height: Double,
        sex: PatientSex
    ) -> Double {
        let heightInches = height * 39.3701 // meters to inches
        
        switch sex {
        case .male:
            // IBW = 50 + 2.3 × (Height [inches] - 60)
            return 50.0 + 2.3 * (heightInches - 60.0)
            
        case .female:
            // IBW = 45.5 + 2.3 × (Height [inches] - 60)
            return 45.5 + 2.3 * (heightInches - 60.0)
            
        case .other:
            // Use average of male and female formulas
            let maleIBW = 50.0 + 2.3 * (heightInches - 60.0)
            let femaleIBW = 45.5 + 2.3 * (heightInches - 60.0)
            return (maleIBW + femaleIBW) / 2.0
        }
    }
}

// MARK: - PatientSex

/// Patient sex enumeration
public enum PatientSex: String, Sendable {
    case male = "M"
    case female = "F"
    case other = "O"
    
    /// Initialize from DICOM Patient's Sex string
    ///
    /// - Parameter dicomString: DICOM Patient's Sex value (M, F, O, or other)
    /// - Returns: PatientSex value, or nil if unrecognized
    public init?(dicomString: String) {
        let normalized = dicomString.uppercased().trimmingCharacters(in: .whitespaces)
        
        switch normalized {
        case "M", "MALE":
            self = .male
        case "F", "FEMALE":
            self = .female
        case "O", "OTHER":
            self = .other
        default:
            return nil
        }
    }
}

// MARK: - Common Radionuclides

extension SUVCalculator {
    
    /// Common PET radionuclide half-lives
    public enum RadionuclideHalfLife {
        /// F-18 (Fluorine-18) half-life: 109.77 minutes
        public static let f18: Double = 109.77 * 60.0 // seconds
        
        /// C-11 (Carbon-11) half-life: 20.38 minutes
        public static let c11: Double = 20.38 * 60.0 // seconds
        
        /// O-15 (Oxygen-15) half-life: 2.03 minutes
        public static let o15: Double = 2.03 * 60.0 // seconds
        
        /// N-13 (Nitrogen-13) half-life: 9.97 minutes
        public static let n13: Double = 9.97 * 60.0 // seconds
        
        /// Ga-68 (Gallium-68) half-life: 67.71 minutes
        public static let ga68: Double = 67.71 * 60.0 // seconds
        
        /// Cu-64 (Copper-64) half-life: 12.7 hours
        public static let cu64: Double = 12.7 * 3600.0 // seconds
        
        /// Zr-89 (Zirconium-89) half-life: 78.41 hours
        public static let zr89: Double = 78.41 * 3600.0 // seconds
        
        /// I-124 (Iodine-124) half-life: 4.176 days
        public static let i124: Double = 4.176 * 24.0 * 3600.0 // seconds
    }
}
