// ParametricMapHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Parametric Map Helpers Tests")
struct ParametricMapHelpersTests {

    // MARK: - normalizedValue

    @Test("normalizedValue maps minimum to 0.0")
    func testNormalizedValueMin() {
        let v = ParametricMapHelpers.normalizedValue(0.0, min: 0.0, max: 100.0)
        #expect(v == 0.0)
    }

    @Test("normalizedValue maps maximum to 1.0")
    func testNormalizedValueMax() {
        let v = ParametricMapHelpers.normalizedValue(100.0, min: 0.0, max: 100.0)
        #expect(v == 1.0)
    }

    @Test("normalizedValue maps midpoint to 0.5")
    func testNormalizedValueMid() {
        let v = ParametricMapHelpers.normalizedValue(50.0, min: 0.0, max: 100.0)
        #expect(abs(v - 0.5) < 0.0001)
    }

    @Test("normalizedValue clamps below minimum to 0.0")
    func testNormalizedValueClampLow() {
        let v = ParametricMapHelpers.normalizedValue(-10.0, min: 0.0, max: 100.0)
        #expect(v == 0.0)
    }

    @Test("normalizedValue clamps above maximum to 1.0")
    func testNormalizedValueClampHigh() {
        let v = ParametricMapHelpers.normalizedValue(200.0, min: 0.0, max: 100.0)
        #expect(v == 1.0)
    }

    // MARK: - colorForValue

    @Test("colorForValue gray colormap returns near-black at minimum")
    func testColorForValueGrayMin() {
        let color = ParametricMapHelpers.colorForValue(0.0, min: 0.0, max: 1.0, colormap: .gray)
        #expect(color.red < 0.01)
        #expect(color.green < 0.01)
        #expect(color.blue < 0.01)
    }

    @Test("colorForValue gray colormap returns near-white at maximum")
    func testColorForValueGrayMax() {
        let color = ParametricMapHelpers.colorForValue(1.0, min: 0.0, max: 1.0, colormap: .gray)
        #expect(color.red > 0.99)
        #expect(color.green > 0.99)
        #expect(color.blue > 0.99)
    }

    @Test("colorForValue all colormaps return valid RGB values")
    func testColorForValueAllColormapsValid() {
        for colormap in ColormapName.allCases {
            let color = ParametricMapHelpers.colorForValue(0.5, min: 0.0, max: 1.0,
                                                           colormap: colormap)
            #expect(color.red >= 0.0 && color.red <= 1.0)
            #expect(color.green >= 0.0 && color.green <= 1.0)
            #expect(color.blue >= 0.0 && color.blue <= 1.0)
        }
    }

    // MARK: - colorScaleStops

    @Test("colorScaleStops returns requested count")
    func testColorScaleStopsCount() {
        let stops = ParametricMapHelpers.colorScaleStops(colormap: .gray, count: 10)
        #expect(stops.count == 10)
    }

    @Test("colorScaleStops first stop is black for gray colormap")
    func testColorScaleStopsFirstGray() {
        let stops = ParametricMapHelpers.colorScaleStops(colormap: .gray, count: 5)
        #expect(stops.first!.red < 0.01)
    }

    @Test("colorScaleStops last stop is white for gray colormap")
    func testColorScaleStopsLastGray() {
        let stops = ParametricMapHelpers.colorScaleStops(colormap: .gray, count: 5)
        #expect(stops.last!.red > 0.99)
    }

    // MARK: - calculateSUV

    @Test("calculateSUV returns positive result")
    func testCalculateSUVPositive() {
        let params = SUVInputParameters(
            patientWeightKg: 70.0,
            injectedDoseBq: 3.7e8,
            injectionDateTime: Date())
        let suv = ParametricMapHelpers.calculateSUV(pixelValue: 2000.0, mapping: params)
        #expect(suv > 0)
    }

    @Test("calculateSUV follows expected formula")
    func testCalculateSUVFormula() {
        let weight = 70.0
        let dose = 3.7e8
        let pixelValue = 1000.0
        let params = SUVInputParameters(
            patientWeightKg: weight,
            injectedDoseBq: dose,
            injectionDateTime: Date())
        let suv = ParametricMapHelpers.calculateSUV(pixelValue: pixelValue, mapping: params)
        let expected = (pixelValue * weight * 1000.0) / dose
        #expect(abs(suv - expected) < 0.0001)
    }

    @Test("calculateSUV returns 0 when injected dose is zero")
    func testCalculateSUVZeroDose() {
        let params = SUVInputParameters(
            patientWeightKg: 70.0,
            injectedDoseBq: 0.0,
            injectionDateTime: Date())
        let suv = ParametricMapHelpers.calculateSUV(pixelValue: 1000.0, mapping: params)
        #expect(suv == 0.0)
    }

    // MARK: - defaultDisplayState

    @Test("defaultDisplayState for T1 has min=0 and max=3000")
    func testDefaultDisplayStateT1() {
        let state = ParametricMapHelpers.defaultDisplayState(for: .t1Mapping)
        #expect(state.minValue == 0)
        #expect(state.maxValue == 3000)
    }

    @Test("defaultDisplayState for ADC has max=3.0")
    func testDefaultDisplayStateADC() {
        let state = ParametricMapHelpers.defaultDisplayState(for: .adcMapping)
        #expect(state.maxValue == 3.0)
    }

    @Test("defaultDisplayState for SUV uses jet colormap")
    func testDefaultDisplayStateSUV() {
        let state = ParametricMapHelpers.defaultDisplayState(for: .suvMap)
        #expect(state.colormapName == .jet)
    }

    // MARK: - formattedValue

    @Test("formattedValue for T1 contains ms unit")
    func testFormattedValueT1() {
        let s = ParametricMapHelpers.formattedValue(1500.0, mapType: .t1Mapping)
        #expect(s.contains("ms"))
    }

    @Test("formattedValue for ADC contains mm unit")
    func testFormattedValueADC() {
        let s = ParametricMapHelpers.formattedValue(0.85, mapType: .adcMapping)
        #expect(s.contains("mm"))
    }

    @Test("formattedValue for SUV contains g/mL")
    func testFormattedValueSUV() {
        let s = ParametricMapHelpers.formattedValue(5.2, mapType: .suvMap)
        #expect(s.contains("g/mL"))
    }
}
