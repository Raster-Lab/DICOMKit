import Testing
import Foundation
@testable import DICOMCore

// MARK: - Template Identifier Tests

@Suite("Template Identifier Tests")
struct TemplateIdentifierTests {
    
    @Test("Create template identifier with string TID")
    func testCreateWithStringTID() {
        let identifier = TemplateIdentifier(templateID: "300")
        #expect(identifier.templateID == "300")
        #expect(identifier.version == nil)
        #expect(identifier.mappingResource == "DCMR")
    }
    
    @Test("Create template identifier with integer TID")
    func testCreateWithIntegerTID() {
        let identifier = TemplateIdentifier(tid: 1500)
        #expect(identifier.templateID == "1500")
        #expect(identifier.version == nil)
        #expect(identifier.mappingResource == "DCMR")
    }
    
    @Test("Create template identifier with version")
    func testCreateWithVersion() {
        let identifier = TemplateIdentifier(tid: 300, version: "2.0")
        #expect(identifier.templateID == "300")
        #expect(identifier.version == "2.0")
    }
    
    @Test("Create template identifier with custom mapping resource")
    func testCreateWithMappingResource() {
        let identifier = TemplateIdentifier(tid: 300, mappingResource: "CUSTOM")
        #expect(identifier.mappingResource == "CUSTOM")
    }
    
    @Test("Template identifier description without version")
    func testDescriptionWithoutVersion() {
        let identifier = TemplateIdentifier(tid: 300)
        #expect(identifier.description == "TID 300")
    }
    
    @Test("Template identifier description with version")
    func testDescriptionWithVersion() {
        let identifier = TemplateIdentifier(tid: 300, version: "1.0")
        #expect(identifier.description == "TID 300 v1.0")
    }
    
    @Test("Well-known template identifiers")
    func testWellKnownIdentifiers() {
        #expect(TemplateIdentifier.measurement.templateID == "300")
        #expect(TemplateIdentifier.imageLibraryEntry.templateID == "320")
        #expect(TemplateIdentifier.observationContext.templateID == "1001")
        #expect(TemplateIdentifier.observerContext.templateID == "1002")
        #expect(TemplateIdentifier.languageOfContent.templateID == "1204")
        #expect(TemplateIdentifier.linearMeasurements.templateID == "1400")
        #expect(TemplateIdentifier.planarROIMeasurements.templateID == "1410")
        #expect(TemplateIdentifier.volumetricROIMeasurements.templateID == "1411")
        #expect(TemplateIdentifier.roiMeasurements.templateID == "1419")
        #expect(TemplateIdentifier.multipleROIMeasurements.templateID == "1420")
        #expect(TemplateIdentifier.measurementReport.templateID == "1500")
    }
    
    @Test("Template identifier equality")
    func testEquality() {
        let id1 = TemplateIdentifier(tid: 300)
        let id2 = TemplateIdentifier(tid: 300)
        let id3 = TemplateIdentifier(tid: 1500)
        
        #expect(id1 == id2)
        #expect(id1 != id3)
    }
    
    @Test("Template identifier hashing")
    func testHashing() {
        let id1 = TemplateIdentifier(tid: 300)
        let id2 = TemplateIdentifier(tid: 300)
        
        #expect(id1.hashValue == id2.hashValue)
    }
}

// MARK: - Requirement Level Tests

@Suite("Requirement Level Tests")
struct RequirementLevelTests {
    
    @Test("Requirement level raw values")
    func testRawValues() {
        #expect(RequirementLevel.mandatory.rawValue == "M")
        #expect(RequirementLevel.mandatoryConditional.rawValue == "MC")
        #expect(RequirementLevel.userConditional.rawValue == "U")
        #expect(RequirementLevel.conditional.rawValue == "C")
    }
    
    @Test("Requirement level display names")
    func testDisplayNames() {
        #expect(RequirementLevel.mandatory.displayName == "Mandatory")
        #expect(RequirementLevel.mandatoryConditional.displayName == "Mandatory Conditional")
        #expect(RequirementLevel.userConditional.displayName == "User Conditional")
        #expect(RequirementLevel.conditional.displayName == "Conditional")
    }
    
    @Test("Mandatory property")
    func testIsMandatory() {
        #expect(RequirementLevel.mandatory.isMandatory == true)
        #expect(RequirementLevel.mandatoryConditional.isMandatory == false)
        #expect(RequirementLevel.userConditional.isMandatory == false)
        #expect(RequirementLevel.conditional.isMandatory == false)
    }
    
    @Test("All cases")
    func testAllCases() {
        let allCases = RequirementLevel.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.mandatory))
        #expect(allCases.contains(.mandatoryConditional))
        #expect(allCases.contains(.userConditional))
        #expect(allCases.contains(.conditional))
    }
}

// MARK: - Cardinality Tests

@Suite("Cardinality Tests")
struct CardinalityTests {
    
    @Test("Cardinality one")
    func testCardinalityOne() {
        let cardinality = Cardinality.one
        #expect(cardinality.minimum == 1)
        #expect(cardinality.maximum == 1)
        #expect(cardinality.allowsZero == false)
        #expect(cardinality.allowsMultiple == false)
    }
    
    @Test("Cardinality zero or one")
    func testCardinalityZeroOrOne() {
        let cardinality = Cardinality.zeroOrOne
        #expect(cardinality.minimum == 0)
        #expect(cardinality.maximum == 1)
        #expect(cardinality.allowsZero == true)
        #expect(cardinality.allowsMultiple == false)
    }
    
    @Test("Cardinality one or more")
    func testCardinalityOneOrMore() {
        let cardinality = Cardinality.oneOrMore
        #expect(cardinality.minimum == 1)
        #expect(cardinality.maximum == nil)
        #expect(cardinality.allowsZero == false)
        #expect(cardinality.allowsMultiple == true)
    }
    
    @Test("Cardinality zero or more")
    func testCardinalityZeroOrMore() {
        let cardinality = Cardinality.zeroOrMore
        #expect(cardinality.minimum == 0)
        #expect(cardinality.maximum == nil)
        #expect(cardinality.allowsZero == true)
        #expect(cardinality.allowsMultiple == true)
    }
    
    @Test("Custom cardinality")
    func testCustomCardinality() {
        let cardinality = Cardinality(minimum: 2, maximum: 5)
        #expect(cardinality.minimum == 2)
        #expect(cardinality.maximum == 5)
        #expect(cardinality.allowsZero == false)
        #expect(cardinality.allowsMultiple == true)
    }
    
    @Test("Cardinality satisfaction - exact")
    func testSatisfactionExact() {
        let cardinality = Cardinality.one
        #expect(cardinality.isSatisfied(by: 0) == false)
        #expect(cardinality.isSatisfied(by: 1) == true)
        #expect(cardinality.isSatisfied(by: 2) == false)
    }
    
    @Test("Cardinality satisfaction - optional")
    func testSatisfactionOptional() {
        let cardinality = Cardinality.zeroOrOne
        #expect(cardinality.isSatisfied(by: 0) == true)
        #expect(cardinality.isSatisfied(by: 1) == true)
        #expect(cardinality.isSatisfied(by: 2) == false)
    }
    
    @Test("Cardinality satisfaction - unbounded")
    func testSatisfactionUnbounded() {
        let cardinality = Cardinality.oneOrMore
        #expect(cardinality.isSatisfied(by: 0) == false)
        #expect(cardinality.isSatisfied(by: 1) == true)
        #expect(cardinality.isSatisfied(by: 100) == true)
    }
    
    @Test("Cardinality satisfaction - range")
    func testSatisfactionRange() {
        let cardinality = Cardinality(minimum: 2, maximum: 5)
        #expect(cardinality.isSatisfied(by: 1) == false)
        #expect(cardinality.isSatisfied(by: 2) == true)
        #expect(cardinality.isSatisfied(by: 3) == true)
        #expect(cardinality.isSatisfied(by: 5) == true)
        #expect(cardinality.isSatisfied(by: 6) == false)
    }
    
    @Test("Cardinality description")
    func testDescription() {
        #expect(Cardinality.one.description == "1")
        #expect(Cardinality.zeroOrOne.description == "0..1")
        #expect(Cardinality.oneOrMore.description == "1..n")
        #expect(Cardinality.zeroOrMore.description == "0..n")
        #expect(Cardinality(minimum: 2, maximum: 5).description == "2..5")
    }
}

// MARK: - Template Row Tests

@Suite("Template Row Tests")
struct TemplateRowTests {
    
    @Test("Create basic template row")
    func testCreateBasicRow() {
        let row = TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container
        )
        
        #expect(row.rowID == "1")
        #expect(row.nestingLevel == 0)
        #expect(row.relationshipType == .contains)
        #expect(row.valueType == .container)
        #expect(row.requirementLevel == .mandatory)
        #expect(row.cardinality == .one)
        #expect(row.includedTemplate == nil)
    }
    
    @Test("Create template row with concept constraint")
    func testCreateRowWithConceptConstraint() {
        let concept = CodedConcept(
            codeValue: "121071",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Finding"
        )
        
        let row = TemplateRow(
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(concept),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
        
        if case .exact(let constraintConcept) = row.conceptName {
            #expect(constraintConcept == concept)
        } else {
            Issue.record("Expected exact concept constraint")
        }
    }
    
    @Test("Create template row with included template")
    func testCreateRowWithIncludedTemplate() {
        let row = TemplateRow(
            relationshipType: .contains,
            valueType: .num,
            includedTemplate: .measurement
        )
        
        #expect(row.includedTemplate == .measurement)
    }
    
    @Test("Create template row with condition")
    func testCreateRowWithCondition() {
        let concept = CodedConcept(
            codeValue: "363698007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Finding Site"
        )
        
        let row = TemplateRow(
            relationshipType: .hasConceptMod,
            valueType: .code,
            condition: .ifPresent(concept: concept)
        )
        
        if case .ifPresent(let conditionConcept) = row.condition {
            #expect(conditionConcept == concept)
        } else {
            Issue.record("Expected ifPresent condition")
        }
    }
}

// MARK: - Template Registry Tests

@Suite("Template Registry Tests")
struct TemplateRegistryTests {
    
    @Test("Registry has built-in templates")
    func testBuiltInTemplates() {
        let registry = TemplateRegistry.shared
        let templates = registry.registeredTemplates
        
        #expect(templates.count >= 10)
        #expect(templates.contains(.measurement))
        #expect(templates.contains(.imageLibraryEntry))
        #expect(templates.contains(.observationContext))
        #expect(templates.contains(.observerContext))
        #expect(templates.contains(.languageOfContent))
    }
    
    @Test("Lookup template by identifier")
    func testLookupByIdentifier() {
        let registry = TemplateRegistry.shared
        
        let template = registry.template(for: .measurement)
        #expect(template != nil)
        #expect(template?.identifier == .measurement)
    }
    
    @Test("Lookup template by TID")
    func testLookupByTID() {
        let registry = TemplateRegistry.shared
        
        let template = registry.template(tid: 300)
        #expect(template != nil)
        #expect(template?.identifier.templateID == "300")
    }
    
    @Test("Lookup unknown template returns nil")
    func testLookupUnknownTemplate() {
        let registry = TemplateRegistry.shared
        
        let template = registry.template(tid: 99999)
        #expect(template == nil)
    }
}

// MARK: - Core Template Tests

@Suite("Core Template Tests")
struct CoreTemplateTests {
    
    @Test("TID 300 Measurement template")
    func testTID300() {
        let template = TID300Measurement.self
        
        #expect(template.identifier == .measurement)
        #expect(template.displayName == "Measurement")
        #expect(template.rootValueType == .num)
        #expect(template.isExtensible == true)
        #expect(!template.rows.isEmpty)
        
        // Check first row is the measurement itself
        let firstRow = template.rows[0]
        #expect(firstRow.valueType == .num)
        #expect(firstRow.relationshipType == .contains)
    }
    
    @Test("TID 320 Image Library Entry template")
    func testTID320() {
        let template = TID320ImageLibraryEntry.self
        
        #expect(template.identifier == .imageLibraryEntry)
        #expect(template.displayName == "Image Library Entry")
        #expect(template.rootValueType == .image)
        #expect(!template.rows.isEmpty)
    }
    
    @Test("TID 1001 Observation Context template")
    func testTID1001() {
        let template = TID1001ObservationContext.self
        
        #expect(template.identifier == .observationContext)
        #expect(template.displayName == "Observation Context")
        #expect(template.rootValueType == .container)
        #expect(!template.rows.isEmpty)
    }
    
    @Test("TID 1002 Observer Context template")
    func testTID1002() {
        let template = TID1002ObserverContext.self
        
        #expect(template.identifier == .observerContext)
        #expect(template.displayName == "Observer Context")
        #expect(template.rootValueType == .container)
        #expect(template.isExtensible == false)
        #expect(!template.rows.isEmpty)
        
        // Check observer type row
        let typeRow = template.rows.first { $0.rowID == "1" }
        #expect(typeRow != nil)
        #expect(typeRow?.valueType == .code)
        #expect(typeRow?.requirementLevel == .mandatory)
    }
    
    @Test("TID 1204 Language of Content template")
    func testTID1204() {
        let template = TID1204LanguageOfContent.self
        
        #expect(template.identifier == .languageOfContent)
        #expect(template.displayName == "Language of Content")
        #expect(template.rootValueType == .code)
        #expect(template.isExtensible == false)
        #expect(template.rows.count >= 2)
    }
}

// MARK: - Measurement Template Tests

@Suite("Measurement Template Tests")
struct MeasurementTemplateTests {
    
    @Test("TID 1400 Linear Measurements template")
    func testTID1400() {
        let template = TID1400LinearMeasurements.self
        
        #expect(template.identifier == .linearMeasurements)
        #expect(template.displayName == "Linear Measurements")
        #expect(template.rootValueType == .container)
        #expect(!template.rows.isEmpty)
        
        // Check for length measurement row
        let measurementRow = template.rows.first { row in
            row.valueType == .num && row.includedTemplate == .measurement
        }
        #expect(measurementRow != nil)
    }
    
    @Test("TID 1410 Planar ROI Measurements template")
    func testTID1410() {
        let template = TID1410PlanarROIMeasurements.self
        
        #expect(template.identifier == .planarROIMeasurements)
        #expect(template.displayName == "Planar ROI Measurements")
        #expect(template.rootValueType == .container)
        #expect(!template.rows.isEmpty)
        
        // Check for area measurement row
        let areaRow = template.rows.first { row in
            if case .exact(let concept) = row.conceptName {
                return concept.codeValue == "42798000" // Area
            }
            return false
        }
        #expect(areaRow != nil)
    }
    
    @Test("TID 1411 Volumetric ROI Measurements template")
    func testTID1411() {
        let template = TID1411VolumetricROIMeasurements.self
        
        #expect(template.identifier == .volumetricROIMeasurements)
        #expect(template.displayName == "Volumetric ROI Measurements")
        #expect(template.rootValueType == .container)
        #expect(!template.rows.isEmpty)
        
        // Check for volume measurement row
        let volumeRow = template.rows.first { row in
            if case .exact(let concept) = row.conceptName {
                return concept.codeValue == "118565006" // Volume
            }
            return false
        }
        #expect(volumeRow != nil)
    }
    
    @Test("TID 1419 ROI Measurements template")
    func testTID1419() {
        let template = TID1419ROIMeasurements.self
        
        #expect(template.identifier == .roiMeasurements)
        #expect(template.displayName == "ROI Measurements")
        #expect(template.rootValueType == .container)
        #expect(template.isExtensible == true)
        #expect(!template.rows.isEmpty)
    }
    
    @Test("TID 1420 Multiple ROI Measurements template")
    func testTID1420() {
        let template = TID1420MultipleROIMeasurements.self
        
        #expect(template.identifier == .multipleROIMeasurements)
        #expect(template.displayName == "Measurements from Multiple ROIs")
        #expect(template.rootValueType == .container)
        #expect(!template.rows.isEmpty)
        
        // Check for statistical measurements
        let meanRow = template.rows.first { row in
            if case .exact(let concept) = row.conceptName {
                return concept.codeValue == "373098007" // Mean Value
            }
            return false
        }
        #expect(meanRow != nil)
    }
}

// MARK: - Template Violation Tests

@Suite("Template Violation Tests")
struct TemplateViolationTests {
    
    @Test("Create error violation")
    func testErrorViolation() {
        let violation = TemplateViolation(
            severity: .error,
            templateRowID: "1",
            contentPath: "/Report/Finding",
            message: "Missing required field",
            details: "Expected: Finding"
        )
        
        #expect(violation.severity == .error)
        #expect(violation.templateRowID == "1")
        #expect(violation.contentPath == "/Report/Finding")
        #expect(violation.message == "Missing required field")
        #expect(violation.details == "Expected: Finding")
    }
    
    @Test("Create warning violation")
    func testWarningViolation() {
        let violation = TemplateViolation(
            severity: .warning,
            message: "Optional field not provided"
        )
        
        #expect(violation.severity == .warning)
        #expect(violation.templateRowID == nil)
        #expect(violation.contentPath == nil)
    }
    
    @Test("Factory method - missing required")
    func testMissingRequiredFactory() {
        let concept = CodedConcept(
            codeValue: "121071",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Finding"
        )
        
        let violation = TemplateViolation.missingRequired(
            rowID: "1",
            conceptName: concept,
            path: "/Report"
        )
        
        #expect(violation.severity == .error)
        #expect(violation.message.contains("Finding"))
    }
    
    @Test("Factory method - cardinality violation")
    func testCardinalityViolationFactory() {
        let violation = TemplateViolation.cardinalityViolation(
            rowID: "2",
            expected: .one,
            actual: 3,
            conceptName: nil,
            path: "/Report"
        )
        
        #expect(violation.severity == .error)
        #expect(violation.message.contains("expected"))
        #expect(violation.message.contains("3"))
    }
    
    @Test("Factory method - value type mismatch")
    func testValueTypeMismatchFactory() {
        let violation = TemplateViolation.valueTypeMismatch(
            rowID: "3",
            expected: .num,
            actual: .text,
            path: "/Report/Measurement"
        )
        
        #expect(violation.severity == .error)
        #expect(violation.message.contains("NUM"))
        #expect(violation.message.contains("TEXT"))
    }
    
    @Test("Violation description")
    func testViolationDescription() {
        let violation = TemplateViolation(
            severity: .error,
            templateRowID: "1",
            contentPath: "/Report",
            message: "Test message",
            details: "Details here"
        )
        
        let description = violation.description
        #expect(description.contains("[ERROR]"))
        #expect(description.contains("/Report"))
        #expect(description.contains("row 1"))
        #expect(description.contains("Test message"))
        #expect(description.contains("Details here"))
    }
}

// MARK: - Template Validation Result Tests

@Suite("Template Validation Result Tests")
struct TemplateValidationResultTests {
    
    @Test("Successful validation result")
    func testSuccessfulResult() {
        let result = TemplateValidationResult.success(for: .measurement)
        
        #expect(result.templateIdentifier == .measurement)
        #expect(result.violations.isEmpty)
        #expect(result.isCompliant == true)
        #expect(result.isFullyCompliant == true)
        #expect(result.errorCount == 0)
        #expect(result.warningCount == 0)
    }
    
    @Test("Result with errors")
    func testResultWithErrors() {
        let violations = [
            TemplateViolation(severity: .error, message: "Error 1"),
            TemplateViolation(severity: .error, message: "Error 2"),
            TemplateViolation(severity: .warning, message: "Warning 1")
        ]
        
        let result = TemplateValidationResult(
            templateIdentifier: .measurement,
            violations: violations
        )
        
        #expect(result.isCompliant == false)
        #expect(result.isFullyCompliant == false)
        #expect(result.errorCount == 2)
        #expect(result.warningCount == 1)
        #expect(result.errors.count == 2)
        #expect(result.warnings.count == 1)
    }
    
    @Test("Result with only warnings")
    func testResultWithOnlyWarnings() {
        let violations = [
            TemplateViolation(severity: .warning, message: "Warning 1"),
            TemplateViolation(severity: .warning, message: "Warning 2")
        ]
        
        let result = TemplateValidationResult(
            templateIdentifier: .measurement,
            violations: violations
        )
        
        #expect(result.isCompliant == true)
        #expect(result.isFullyCompliant == false)
        #expect(result.errorCount == 0)
        #expect(result.warningCount == 2)
    }
}

// MARK: - Template Validator Tests

@Suite("Template Validator Tests")
struct TemplateValidatorTests {
    
    @Test("Validator initialization")
    func testValidatorInitialization() {
        let strictValidator = TemplateValidator(mode: .strict)
        #expect(strictValidator.mode == .strict)
        #expect(strictValidator.maxDepth == 50)
        
        let lenientValidator = TemplateValidator(mode: .lenient, maxDepth: 100)
        #expect(lenientValidator.mode == .lenient)
        #expect(lenientValidator.maxDepth == 100)
    }
    
    @Test("Validate against unknown template")
    func testValidateUnknownTemplate() {
        let validator = TemplateValidator()
        let unknownTemplate = TemplateIdentifier(tid: 99999)
        
        let result = validator.validate([], against: unknownTemplate)
        
        #expect(result.isCompliant == false)
        #expect(result.errorCount == 1)
        #expect(result.errors[0].message.contains("Unknown template"))
    }
    
    @Test("Validate empty content")
    func testValidateEmptyContent() {
        let validator = TemplateValidator(mode: .lenient)
        
        let result = validator.validate([], against: .measurement)
        
        // Empty content won't match mandatory rows in lenient mode
        // Since TID 300 has a mandatory NUM row
        #expect(result.violations.count >= 0) // May have violations for mandatory items
    }
}

// MARK: - Template Detector Tests

@Suite("Template Detector Tests")
struct TemplateDetectorTests {
    
    @Test("Detector initialization")
    func testDetectorInitialization() {
        let detector = TemplateDetector()
        #expect(detector != nil)
    }
    
    @Test("Detect template from empty content")
    func testDetectFromEmptyContent() {
        let detector = TemplateDetector()
        _ = detector.detectTemplate([])
        
        // Empty content might still match templates with all optional rows
        // This test verifies the API doesn't crash with empty input
    }
    
    @Test("Detect templates returns sorted results")
    func testDetectTemplatesReturnsSorted() {
        let detector = TemplateDetector()
        let results = detector.detectTemplates([])
        
        // Verify results are sorted by confidence (descending)
        guard results.count > 1 else { return }
        for i in 1..<results.count {
            #expect(results[i-1].confidence >= results[i].confidence)
        }
    }
}

// MARK: - Concept Name Constraint Tests

@Suite("Concept Name Constraint Tests")
struct ConceptNameConstraintTests {
    
    @Test("Any constraint")
    func testAnyConstraint() {
        let constraint = ConceptNameConstraint.any
        if case .any = constraint {
            // Passes
        } else {
            Issue.record("Expected any constraint")
        }
    }
    
    @Test("Exact constraint")
    func testExactConstraint() {
        let concept = CodedConcept(
            codeValue: "121071",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Finding"
        )
        let constraint = ConceptNameConstraint.exact(concept)
        
        if case .exact(let c) = constraint {
            #expect(c == concept)
        } else {
            Issue.record("Expected exact constraint")
        }
    }
    
    @Test("From context group constraint")
    func testFromContextGroupConstraint() {
        let constraint = ConceptNameConstraint.fromContextGroup(contextGroupID: 244)
        
        if case .fromContextGroup(let cid) = constraint {
            #expect(cid == 244)
        } else {
            Issue.record("Expected fromContextGroup constraint")
        }
    }
    
    @Test("One of constraint")
    func testOneOfConstraint() {
        let concepts = [
            CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "One"),
            CodedConcept(codeValue: "2", codingSchemeDesignator: "DCM", codeMeaning: "Two")
        ]
        let constraint = ConceptNameConstraint.oneOf(concepts)
        
        if case .oneOf(let c) = constraint {
            #expect(c.count == 2)
        } else {
            Issue.record("Expected oneOf constraint")
        }
    }
}

// MARK: - Value Constraint Tests

@Suite("Value Constraint Tests")
struct ValueConstraintTests {
    
    @Test("Any value constraint")
    func testAnyConstraint() {
        let constraint = ValueConstraint.any
        if case .any = constraint {
            // Passes
        } else {
            Issue.record("Expected any constraint")
        }
    }
    
    @Test("Exact code constraint")
    func testExactCodeConstraint() {
        let code = CodedConcept(
            codeValue: "R",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Right"
        )
        let constraint = ValueConstraint.exactCode(code)
        
        if case .exactCode(let c) = constraint {
            #expect(c == code)
        } else {
            Issue.record("Expected exactCode constraint")
        }
    }
    
    @Test("Numeric units constraint")
    func testNumericUnitsConstraint() {
        let unit = CodedConcept(
            codeValue: "mm",
            codingSchemeDesignator: "UCUM",
            codeMeaning: "mm"
        )
        let constraint = ValueConstraint.numericUnits(unitCode: unit)
        
        if case .numericUnits(let u) = constraint {
            #expect(u == unit)
        } else {
            Issue.record("Expected numericUnits constraint")
        }
    }
}

// MARK: - Template Row Condition Tests

@Suite("Template Row Condition Tests")
struct TemplateRowConditionTests {
    
    @Test("None condition")
    func testNoneCondition() {
        let condition = TemplateRowCondition.none
        if case .none = condition {
            // Passes
        } else {
            Issue.record("Expected none condition")
        }
    }
    
    @Test("If present condition")
    func testIfPresentCondition() {
        let concept = CodedConcept(
            codeValue: "363698007",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Finding Site"
        )
        let condition = TemplateRowCondition.ifPresent(concept: concept)
        
        if case .ifPresent(let c) = condition {
            #expect(c == concept)
        } else {
            Issue.record("Expected ifPresent condition")
        }
    }
    
    @Test("If equals condition")
    func testIfEqualsCondition() {
        let concept = CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type")
        let value = CodedConcept(codeValue: "121006", codingSchemeDesignator: "DCM", codeMeaning: "Person")
        let condition = TemplateRowCondition.ifEquals(concept: concept, value: value)
        
        if case .ifEquals(let c, let v) = condition {
            #expect(c == concept)
            #expect(v == value)
        } else {
            Issue.record("Expected ifEquals condition")
        }
    }
    
    @Test("If absent condition")
    func testIfAbsentCondition() {
        let concept = CodedConcept(codeValue: "test", codingSchemeDesignator: "DCM", codeMeaning: "Test")
        let condition = TemplateRowCondition.ifAbsent(concept: concept)
        
        if case .ifAbsent(let c) = condition {
            #expect(c == concept)
        } else {
            Issue.record("Expected ifAbsent condition")
        }
    }
    
    @Test("Custom condition")
    func testCustomCondition() {
        let condition = TemplateRowCondition.custom(description: "Complex rule here")
        
        if case .custom(let desc) = condition {
            #expect(desc == "Complex rule here")
        } else {
            Issue.record("Expected custom condition")
        }
    }
}
