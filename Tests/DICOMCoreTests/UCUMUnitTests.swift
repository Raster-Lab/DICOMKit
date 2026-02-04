import Testing
@testable import DICOMCore

// MARK: - UCUMUnit Tests

@Suite("UCUMUnit Tests")
struct UCUMUnitTests {
    
    @Test("Basic creation")
    func testBasicCreation() {
        let unit = UCUMUnit(code: "mm", symbol: "millimeter", dimension: .length, baseMultiplier: 0.001)
        
        #expect(unit.code == "mm")
        #expect(unit.symbol == "millimeter")
        #expect(unit.dimension == .length)
        #expect(unit.baseMultiplier == 0.001)
        #expect(unit.concept.codingSchemeDesignator == "UCUM")
    }
    
    @Test("Creation from CodedConcept - valid UCUM")
    func testCreationFromCodedConcept() {
        let concept = CodedConcept(codeValue: "mm", scheme: .UCUM, codeMeaning: "millimeter")
        let unit = UCUMUnit(concept: concept)
        
        #expect(unit != nil)
        #expect(unit?.code == "mm")
    }
    
    @Test("Creation from CodedConcept - non-UCUM returns nil")
    func testCreationFromNonUCUM() {
        let concept = CodedConcept(codeValue: "12345", scheme: .DCM, codeMeaning: "Test")
        let unit = UCUMUnit(concept: concept)
        
        #expect(unit == nil)
    }
    
    @Test("Description format")
    func testDescription() {
        let unit = UCUMUnit.millimeter
        #expect(unit.description.contains("mm"))
        #expect(unit.description.contains("UCUM"))
    }
    
    // MARK: - Length Units
    
    @Test("Length unit codes")
    func testLengthUnitCodes() {
        #expect(UCUMUnit.meter.code == "m")
        #expect(UCUMUnit.centimeter.code == "cm")
        #expect(UCUMUnit.millimeter.code == "mm")
        #expect(UCUMUnit.micrometer.code == "um")
        #expect(UCUMUnit.nanometer.code == "nm")
        #expect(UCUMUnit.inch.code == "[in_i]")
        #expect(UCUMUnit.foot.code == "[ft_i]")
    }
    
    @Test("Length unit dimensions")
    func testLengthUnitDimensions() {
        #expect(UCUMUnit.meter.dimension == .length)
        #expect(UCUMUnit.centimeter.dimension == .length)
        #expect(UCUMUnit.millimeter.dimension == .length)
    }
    
    // MARK: - Area Units
    
    @Test("Area unit codes")
    func testAreaUnitCodes() {
        #expect(UCUMUnit.squareMeter.code == "m2")
        #expect(UCUMUnit.squareCentimeter.code == "cm2")
        #expect(UCUMUnit.squareMillimeter.code == "mm2")
    }
    
    @Test("Area unit dimensions")
    func testAreaUnitDimensions() {
        #expect(UCUMUnit.squareMeter.dimension == .area)
        #expect(UCUMUnit.squareCentimeter.dimension == .area)
        #expect(UCUMUnit.squareMillimeter.dimension == .area)
    }
    
    // MARK: - Volume Units
    
    @Test("Volume unit codes")
    func testVolumeUnitCodes() {
        #expect(UCUMUnit.cubicMeter.code == "m3")
        #expect(UCUMUnit.cubicCentimeter.code == "cm3")
        #expect(UCUMUnit.cubicMillimeter.code == "mm3")
        #expect(UCUMUnit.liter.code == "L")
        #expect(UCUMUnit.milliliter.code == "mL")
        #expect(UCUMUnit.microliter.code == "uL")
    }
    
    @Test("Volume unit dimensions")
    func testVolumeUnitDimensions() {
        #expect(UCUMUnit.cubicMeter.dimension == .volume)
        #expect(UCUMUnit.liter.dimension == .volume)
        #expect(UCUMUnit.milliliter.dimension == .volume)
    }
    
    // MARK: - Mass Units
    
    @Test("Mass unit codes")
    func testMassUnitCodes() {
        #expect(UCUMUnit.kilogram.code == "kg")
        #expect(UCUMUnit.gram.code == "g")
        #expect(UCUMUnit.milligram.code == "mg")
        #expect(UCUMUnit.microgram.code == "ug")
        #expect(UCUMUnit.pound.code == "[lb_av]")
    }
    
    // MARK: - Time Units
    
    @Test("Time unit codes")
    func testTimeUnitCodes() {
        #expect(UCUMUnit.second.code == "s")
        #expect(UCUMUnit.millisecond.code == "ms")
        #expect(UCUMUnit.minute.code == "min")
        #expect(UCUMUnit.hour.code == "h")
        #expect(UCUMUnit.day.code == "d")
        #expect(UCUMUnit.week.code == "wk")
        #expect(UCUMUnit.month.code == "mo")
        #expect(UCUMUnit.year.code == "a")
    }
    
    // MARK: - Temperature Units
    
    @Test("Temperature unit codes")
    func testTemperatureUnitCodes() {
        #expect(UCUMUnit.kelvin.code == "K")
        #expect(UCUMUnit.celsius.code == "Cel")
        #expect(UCUMUnit.fahrenheit.code == "[degF]")
    }
    
    // MARK: - Angle Units
    
    @Test("Angle unit codes")
    func testAngleUnitCodes() {
        #expect(UCUMUnit.radian.code == "rad")
        #expect(UCUMUnit.degree.code == "deg")
    }
    
    // MARK: - Ratio Units
    
    @Test("Ratio unit codes")
    func testRatioUnitCodes() {
        #expect(UCUMUnit.unity.code == "1")
        #expect(UCUMUnit.percent.code == "%")
        #expect(UCUMUnit.perThousand.code == "[ppth]")
        #expect(UCUMUnit.partsPerMillion.code == "[ppm]")
    }
    
    // MARK: - Medical Units
    
    @Test("Medical/imaging unit codes")
    func testMedicalUnitCodes() {
        #expect(UCUMUnit.hounsfieldUnit.code == "[hnsf'U]")
        #expect(UCUMUnit.suvUnit.code == "{SUVbw}")
        #expect(UCUMUnit.becquerel.code == "Bq")
        #expect(UCUMUnit.gray.code == "Gy")
        #expect(UCUMUnit.sievert.code == "Sv")
        #expect(UCUMUnit.beatsPerMinute.code == "/min")
    }
    
    // MARK: - Pressure Units
    
    @Test("Pressure unit codes")
    func testPressureUnitCodes() {
        #expect(UCUMUnit.pascal.code == "Pa")
        #expect(UCUMUnit.mmHg.code == "mm[Hg]")
        #expect(UCUMUnit.kilopascal.code == "kPa")
    }
    
    // MARK: - Unit Conversion
    
    @Test("Is convertible to same dimension")
    func testIsConvertibleToSameDimension() {
        #expect(UCUMUnit.millimeter.isConvertibleTo(.centimeter))
        #expect(UCUMUnit.centimeter.isConvertibleTo(.meter))
        #expect(UCUMUnit.gram.isConvertibleTo(.kilogram))
    }
    
    @Test("Is not convertible to different dimension")
    func testIsNotConvertibleToDifferentDimension() {
        #expect(!UCUMUnit.millimeter.isConvertibleTo(.gram))
        #expect(!UCUMUnit.second.isConvertibleTo(.meter))
        #expect(!UCUMUnit.percent.isConvertibleTo(.celsius))
    }
    
    @Test("Length conversion - mm to cm")
    func testLengthConversionMmToCm() {
        let result = UCUMUnit.millimeter.convert(25.4, to: .centimeter)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 2.54) < 0.0001)
    }
    
    @Test("Length conversion - m to mm")
    func testLengthConversionMToMm() {
        let result = UCUMUnit.meter.convert(1.0, to: .millimeter)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 1000.0) < 0.0001)
    }
    
    @Test("Mass conversion - kg to g")
    func testMassConversionKgToG() {
        let result = UCUMUnit.kilogram.convert(2.5, to: .gram)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 2500.0) < 0.0001)
    }
    
    @Test("Mass conversion - g to mg")
    func testMassConversionGToMg() {
        let result = UCUMUnit.gram.convert(1.5, to: .milligram)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 1500.0) < 0.0001)
    }
    
    @Test("Time conversion - hours to minutes")
    func testTimeConversionHoursToMinutes() {
        let result = UCUMUnit.hour.convert(2.0, to: .minute)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 120.0) < 0.0001)
    }
    
    @Test("Volume conversion - L to mL")
    func testVolumeConversionLToMl() {
        let result = UCUMUnit.liter.convert(1.5, to: .milliliter)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 1500.0) < 0.0001)
    }
    
    @Test("Ratio conversion - percent to unity")
    func testRatioConversionPercentToUnity() {
        let result = UCUMUnit.percent.convert(50.0, to: .unity)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 0.5) < 0.0001)
    }
    
    @Test("Temperature conversion - Celsius to Kelvin")
    func testTemperatureConversionCelsiusToKelvin() {
        let result = UCUMUnit.celsius.convert(25.0, to: .kelvin)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 298.15) < 0.01)
    }
    
    @Test("Temperature conversion - Celsius to Fahrenheit")
    func testTemperatureConversionCelsiusToFahrenheit() {
        let result = UCUMUnit.celsius.convert(100.0, to: .fahrenheit)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 212.0) < 0.1)
    }
    
    @Test("Incompatible conversion returns nil")
    func testIncompatibleConversionReturnsNil() {
        let result = UCUMUnit.millimeter.convert(10.0, to: .gram)
        #expect(result == nil)
    }
    
    @Test("Same unit conversion returns same value")
    func testSameUnitConversion() {
        let result = UCUMUnit.millimeter.convert(25.4, to: .millimeter)
        #expect(result != nil)
        #expect(abs((result ?? 0) - 25.4) < 0.0001)
    }
    
    // MARK: - Well-Known Units Registry
    
    @Test("Well-known unit lookup")
    func testWellKnownUnitLookup() {
        #expect(UCUMUnit.wellKnown(code: "mm") != nil)
        #expect(UCUMUnit.wellKnown(code: "cm") != nil)
        #expect(UCUMUnit.wellKnown(code: "L") != nil)
        #expect(UCUMUnit.wellKnown(code: "[hnsf'U]") != nil)
        #expect(UCUMUnit.wellKnown(code: "unknown") == nil)
    }
    
    // MARK: - CodedConcept Convenience
    
    @Test("CodedConcept to UCUM conversion")
    func testCodedConceptToUCUM() {
        let concept = CodedConcept(unit: UCUMUnit.millimeter)
        
        #expect(concept.codeValue == "mm")
        #expect(concept.codingSchemeDesignator == "UCUM")
        #expect(concept.isUCUM)
    }
    
    @Test("CodedConcept asUCUM property")
    func testCodedConceptAsUCUM() {
        let ucumConcept = CodedConcept(codeValue: "mm", scheme: .UCUM, codeMeaning: "millimeter")
        let dcmConcept = CodedConcept(codeValue: "121071", scheme: .DCM, codeMeaning: "Finding")
        
        #expect(ucumConcept.asUCUM != nil)
        #expect(dcmConcept.asUCUM == nil)
    }
    
    @Test("CodedConcept isUCUM property")
    func testCodedConceptIsUCUM() {
        let ucumConcept = CodedConcept(codeValue: "mm", scheme: .UCUM, codeMeaning: "millimeter")
        let sctConcept = CodedConcept(codeValue: "10200004", scheme: .SCT, codeMeaning: "Liver")
        
        #expect(ucumConcept.isUCUM == true)
        #expect(sctConcept.isUCUM == false)
    }
    
    // MARK: - Equatable / Hashable
    
    @Test("Equatable conformance")
    func testEquatable() {
        let unit1 = UCUMUnit(code: "mm", symbol: "millimeter", dimension: .length, baseMultiplier: 0.001)
        let unit2 = UCUMUnit.millimeter
        let unit3 = UCUMUnit.centimeter
        
        #expect(unit1 == unit2)
        #expect(unit1 != unit3)
    }
    
    @Test("Hashable conformance")
    func testHashable() {
        let unit1 = UCUMUnit.millimeter
        let unit2 = UCUMUnit(code: "mm", symbol: "millimeter", dimension: .length, baseMultiplier: 0.001)
        
        var set = Set<UCUMUnit>()
        set.insert(unit1)
        set.insert(unit2)
        
        #expect(set.count == 1)
    }
}
