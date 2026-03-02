// SRHelpersTests.swift
// DICOMStudioTests
//
// Tests for SR tree, builder, terminology, and CAD visualization helpers (Milestone 7)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - SRTreeHelpers Tests

@Suite("SRTreeHelpers Tests")
struct SRTreeHelpersTests {

    // MARK: - Flatten Tree

    @Test("flattenTree with single item")
    func testFlattenSingle() {
        let root = SRContentItem(valueType: .text, textValue: "Hello")
        let flat = SRTreeHelpers.flattenTree(root)
        #expect(flat.count == 1)
        #expect(flat[0].depth == 0)
    }

    @Test("flattenTree with nested items")
    func testFlattenNested() {
        let child = SRContentItem(valueType: .text, textValue: "Child")
        let root = SRContentItem(valueType: .container, children: [child], isExpanded: true)
        let flat = SRTreeHelpers.flattenTree(root)
        #expect(flat.count == 2)
        #expect(flat[0].depth == 0)
        #expect(flat[1].depth == 1)
    }

    @Test("flattenTree respects collapsed nodes")
    func testFlattenCollapsed() {
        let child = SRContentItem(valueType: .text, textValue: "Hidden")
        let root = SRContentItem(valueType: .container, children: [child], isExpanded: false)
        let flat = SRTreeHelpers.flattenTree(root)
        #expect(flat.count == 1) // Only root, children hidden
    }

    @Test("flattenTree with deep nesting")
    func testFlattenDeep() {
        let level3 = SRContentItem(valueType: .text, textValue: "L3")
        let level2 = SRContentItem(valueType: .container, children: [level3])
        let level1 = SRContentItem(valueType: .container, children: [level2])
        let root = SRContentItem(valueType: .container, children: [level1])
        let flat = SRTreeHelpers.flattenTree(root)
        #expect(flat.count == 4)
        #expect(flat[3].depth == 3)
    }

    // MARK: - Total Item Count

    @Test("totalItemCount for leaf")
    func testTotalItemCountLeaf() {
        let item = SRContentItem(valueType: .text, textValue: "Leaf")
        #expect(SRTreeHelpers.totalItemCount(item) == 1)
    }

    @Test("totalItemCount for tree")
    func testTotalItemCountTree() {
        let child1 = SRContentItem(valueType: .text, textValue: "C1")
        let child2 = SRContentItem(valueType: .text, textValue: "C2")
        let root = SRContentItem(valueType: .container, children: [child1, child2])
        #expect(SRTreeHelpers.totalItemCount(root) == 3)
    }

    // MARK: - Max Depth

    @Test("maxDepth for leaf is 0")
    func testMaxDepthLeaf() {
        let item = SRContentItem(valueType: .text, textValue: "Leaf")
        #expect(SRTreeHelpers.maxDepth(item) == 0)
    }

    @Test("maxDepth for nested tree")
    func testMaxDepthNested() {
        let deep = SRContentItem(valueType: .text, textValue: "Deep")
        let mid = SRContentItem(valueType: .container, children: [deep])
        let root = SRContentItem(valueType: .container, children: [mid])
        #expect(SRTreeHelpers.maxDepth(root) == 2)
    }

    // MARK: - Search

    @Test("searchTree finds text matches")
    func testSearchText() {
        let child = SRContentItem(valueType: .text, textValue: "Pneumonia finding")
        let root = SRContentItem(valueType: .container, children: [child])
        let results = SRTreeHelpers.searchTree(root, query: "pneumonia")
        #expect(results.count == 1)
        #expect(results[0] == child.id)
    }

    @Test("searchTree finds concept name matches")
    func testSearchConceptName() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Findings Section"
        )
        let item = SRContentItem(valueType: .container, conceptName: concept)
        let results = SRTreeHelpers.searchTree(item, query: "findings")
        #expect(results.count == 1)
    }

    @Test("searchTree finds code value matches")
    func testSearchCodeValue() {
        let code = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "SCT", codeMeaning: "Mass"
        )
        let item = SRContentItem(valueType: .code, codeValue: code)
        let results = SRTreeHelpers.searchTree(item, query: "mass")
        #expect(results.count == 1)
    }

    @Test("searchTree with empty query returns empty")
    func testSearchEmpty() {
        let item = SRContentItem(valueType: .text, textValue: "Hello")
        let results = SRTreeHelpers.searchTree(item, query: "")
        #expect(results.isEmpty)
    }

    @Test("searchTree finds person name matches")
    func testSearchPersonName() {
        let item = SRContentItem(valueType: .personName, personName: "DOE^JOHN")
        let results = SRTreeHelpers.searchTree(item, query: "doe")
        #expect(results.count == 1)
    }

    @Test("searchTree finds UID matches")
    func testSearchUID() {
        let item = SRContentItem(valueType: .uidRef, uidValue: "1.2.3.4.5")
        let results = SRTreeHelpers.searchTree(item, query: "1.2.3")
        #expect(results.count == 1)
    }

    @Test("itemMatchesQuery returns false for non-match")
    func testItemNoMatch() {
        let item = SRContentItem(valueType: .text, textValue: "Hello")
        #expect(!SRTreeHelpers.itemMatchesQuery(item, query: "goodbye"))
    }

    // MARK: - Expand / Collapse

    @Test("expandAll expands all nodes")
    func testExpandAll() {
        let child = SRContentItem(valueType: .container, children: [], isExpanded: false)
        let root = SRContentItem(valueType: .container, children: [child], isExpanded: false)
        let expanded = SRTreeHelpers.expandAll(root)
        #expect(expanded.isExpanded)
        #expect(expanded.children[0].isExpanded)
    }

    @Test("collapseAll collapses all nodes")
    func testCollapseAll() {
        let child = SRContentItem(valueType: .container, children: [], isExpanded: true)
        let root = SRContentItem(valueType: .container, children: [child], isExpanded: true)
        let collapsed = SRTreeHelpers.collapseAll(root)
        #expect(!collapsed.isExpanded)
        #expect(!collapsed.children[0].isExpanded)
    }

    @Test("toggleExpansion toggles specific node")
    func testToggleExpansion() {
        let child = SRContentItem(valueType: .text, textValue: "C", isExpanded: true)
        let root = SRContentItem(valueType: .container, children: [child], isExpanded: true)
        let toggled = SRTreeHelpers.toggleExpansion(root, itemID: child.id)
        #expect(toggled.isExpanded) // Root unchanged
        #expect(!toggled.children[0].isExpanded) // Child toggled
    }

    @Test("toggleExpansion on root")
    func testToggleRoot() {
        let root = SRContentItem(valueType: .container, isExpanded: true)
        let toggled = SRTreeHelpers.toggleExpansion(root, itemID: root.id)
        #expect(!toggled.isExpanded)
    }

    // MARK: - Display Formatting

    @Test("formatItemValue for text")
    func testFormatText() {
        let item = SRContentItem(valueType: .text, textValue: "Finding text")
        #expect(SRTreeHelpers.formatItemValue(item) == "Finding text")
    }

    @Test("formatItemValue for code")
    func testFormatCode() {
        let code = CodedConcept(
            codeValue: "4147007", codingSchemeDesignator: "SCT", codeMeaning: "Mass"
        )
        let item = SRContentItem(valueType: .code, codeValue: code)
        let formatted = SRTreeHelpers.formatItemValue(item)
        #expect(formatted.contains("Mass"))
        #expect(formatted.contains("SCT"))
    }

    @Test("formatItemValue for numeric with unit")
    func testFormatNumericWithUnit() {
        let unit = CodedConcept(codeValue: "mm", codingSchemeDesignator: "UCUM", codeMeaning: "mm")
        let item = SRContentItem(valueType: .numeric, numericValue: 42.5, measurementUnit: unit)
        let formatted = SRTreeHelpers.formatItemValue(item)
        #expect(formatted.contains("42.5"))
        #expect(formatted.contains("mm"))
    }

    @Test("formatItemValue for numeric without unit")
    func testFormatNumericNoUnit() {
        let item = SRContentItem(valueType: .numeric, numericValue: 3.14)
        let formatted = SRTreeHelpers.formatItemValue(item)
        #expect(formatted.contains("3.14"))
    }

    @Test("formatItemValue for container")
    func testFormatContainer() {
        let item = SRContentItem(valueType: .container, continuityOfContent: .separate)
        #expect(SRTreeHelpers.formatItemValue(item) == "SEPARATE")
    }

    @Test("formatItemValue for personName")
    func testFormatPersonName() {
        let item = SRContentItem(valueType: .personName, personName: "DOE^JOHN")
        #expect(SRTreeHelpers.formatItemValue(item) == "DOE^JOHN")
    }

    @Test("formatItemValue for date")
    func testFormatDate() {
        let item = SRContentItem(valueType: .date, dateValue: "20240115")
        #expect(SRTreeHelpers.formatItemValue(item) == "20240115")
    }

    @Test("formatItemValue for spatialCoord")
    func testFormatSpatialCoord() {
        let item = SRContentItem(
            valueType: .spatialCoord,
            graphicType: .circle,
            graphicData: [100, 100, 150, 100]
        )
        let formatted = SRTreeHelpers.formatItemValue(item)
        #expect(formatted.contains("CIRCLE"))
        #expect(formatted.contains("2 points"))
    }

    @Test("formatItemValue for image with frames")
    func testFormatImageWithFrames() {
        let item = SRContentItem(
            valueType: .image,
            referencedSOPInstanceUID: "1.2.3",
            referencedFrameNumbers: [1, 5]
        )
        let formatted = SRTreeHelpers.formatItemValue(item)
        #expect(formatted.contains("1.2.3"))
        #expect(formatted.contains("frames"))
    }

    @Test("itemLabel returns concept name when present")
    func testItemLabelConcept() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Findings"
        )
        let item = SRContentItem(valueType: .container, conceptName: concept)
        #expect(SRTreeHelpers.itemLabel(item) == "Findings")
    }

    @Test("itemLabel returns value type when no concept")
    func testItemLabelNoConceptName() {
        let item = SRContentItem(valueType: .text, textValue: "Hello")
        #expect(SRTreeHelpers.itemLabel(item) == "Text")
    }

    @Test("sfSymbolForValueType returns non-empty strings")
    func testSFSymbols() {
        for vt in ContentItemValueType.allCases {
            #expect(!SRTreeHelpers.sfSymbolForValueType(vt).isEmpty)
        }
    }

    @Test("colorForRelationship returns non-empty strings")
    func testRelationshipColors() {
        for rt in SRRelationshipType.allCases {
            #expect(!SRTreeHelpers.colorForRelationship(rt).isEmpty)
        }
    }

    // MARK: - Statistics

    @Test("valueTypeCounts counts correctly")
    func testValueTypeCounts() {
        let child1 = SRContentItem(valueType: .text, textValue: "A")
        let child2 = SRContentItem(valueType: .text, textValue: "B")
        let child3 = SRContentItem(valueType: .code, codeValue: CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "T"
        ))
        let root = SRContentItem(valueType: .container, children: [child1, child2, child3])
        let counts = SRTreeHelpers.valueTypeCounts(root)
        #expect(counts[.container] == 1)
        #expect(counts[.text] == 2)
        #expect(counts[.code] == 1)
    }

    @Test("allCodedConcepts collects unique concepts")
    func testAllCodedConcepts() {
        let concept1 = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Finding"
        )
        let concept2 = CodedConcept(
            codeValue: "2", codingSchemeDesignator: "SCT", codeMeaning: "Mass"
        )
        let child = SRContentItem(valueType: .code, conceptName: concept1, codeValue: concept2)
        let root = SRContentItem(valueType: .container, conceptName: concept1, children: [child])
        let concepts = SRTreeHelpers.allCodedConcepts(root)
        #expect(concepts.count == 2) // concept1 and concept2 (concept1 deduplicated)
    }
}

// MARK: - SRBuilderHelpers Tests

@Suite("SRBuilderHelpers Tests")
struct SRBuilderHelpersTests {

    @Test("UCUM unit concepts are defined")
    func testUCUMConcepts() {
        #expect(SRBuilderHelpers.ucumMillimeter.codeValue == "mm")
        #expect(SRBuilderHelpers.ucumCentimeter.codeValue == "cm")
        #expect(SRBuilderHelpers.ucumSquareMillimeter.codeValue == "mm2")
        #expect(SRBuilderHelpers.ucumMilliliter.codeValue == "ml")
        #expect(SRBuilderHelpers.ucumHounsfieldUnit.codeMeaning == "HU")
        #expect(SRBuilderHelpers.ucumNoUnits.codingSchemeDesignator == "UCUM")
    }

    @Test("Common coded concepts are defined")
    func testCommonConcepts() {
        #expect(SRBuilderHelpers.measurementGroupConcept.codeValue == "125007")
        #expect(SRBuilderHelpers.trackingIdentifierConcept.codeMeaning == "Tracking Identifier")
        #expect(SRBuilderHelpers.findingConcept.codeMeaning == "Finding")
        #expect(SRBuilderHelpers.keyObjectSelectionTitle.codeMeaning == "Key Object Selection")
    }

    @Test("containerItem creates CONTAINER type")
    func testContainerItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report"
        )
        let item = SRBuilderHelpers.containerItem(conceptName: concept)
        #expect(item.valueType == .container)
        #expect(item.continuityOfContent == .separate)
    }

    @Test("textItem creates TEXT type")
    func testTextItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Findings"
        )
        let item = SRBuilderHelpers.textItem(conceptName: concept, text: "Normal chest")
        #expect(item.valueType == .text)
        #expect(item.textValue == "Normal chest")
    }

    @Test("codeItem creates CODE type")
    func testCodeItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Finding"
        )
        let code = CodedConcept(
            codeValue: "4147007", codingSchemeDesignator: "SCT", codeMeaning: "Mass"
        )
        let item = SRBuilderHelpers.codeItem(conceptName: concept, code: code)
        #expect(item.valueType == .code)
        #expect(item.codeValue?.codeMeaning == "Mass")
    }

    @Test("numericItem creates NUM type with units")
    func testNumericItem() {
        let concept = CodedConcept(
            codeValue: "410668003", codingSchemeDesignator: "SCT", codeMeaning: "Length"
        )
        let item = SRBuilderHelpers.numericItem(
            conceptName: concept,
            value: 15.5,
            unit: SRBuilderHelpers.ucumMillimeter
        )
        #expect(item.valueType == .numeric)
        #expect(item.numericValue == 15.5)
        #expect(item.measurementUnit?.codeValue == "mm")
    }

    @Test("personNameItem creates PNAME type")
    func testPersonNameItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Observer"
        )
        let item = SRBuilderHelpers.personNameItem(conceptName: concept, name: "DOE^JOHN")
        #expect(item.valueType == .personName)
        #expect(item.personName == "DOE^JOHN")
        #expect(item.relationshipType == .hasObsContext)
    }

    @Test("dateItem creates DATE type")
    func testDateItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Date"
        )
        let item = SRBuilderHelpers.dateItem(conceptName: concept, date: "20240101")
        #expect(item.valueType == .date)
        #expect(item.dateValue == "20240101")
    }

    @Test("uidRefItem creates UIDREF type")
    func testUidRefItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "UID"
        )
        let item = SRBuilderHelpers.uidRefItem(conceptName: concept, uid: "1.2.3.4")
        #expect(item.valueType == .uidRef)
        #expect(item.uidValue == "1.2.3.4")
    }

    @Test("imageItem creates IMAGE type")
    func testImageItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Image"
        )
        let item = SRBuilderHelpers.imageItem(
            conceptName: concept,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            frameNumbers: [1, 2]
        )
        #expect(item.valueType == .image)
        #expect(item.referencedSOPClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(item.referencedFrameNumbers?.count == 2)
    }

    @Test("spatialCoordItem creates SCOORD type")
    func testSpatialCoordItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Region"
        )
        let item = SRBuilderHelpers.spatialCoordItem(
            conceptName: concept,
            graphicType: .polygon,
            graphicData: [0, 0, 100, 0, 100, 100, 0, 100]
        )
        #expect(item.valueType == .spatialCoord)
        #expect(item.graphicType == .polygon)
        #expect(item.graphicData?.count == 8)
    }

    @Test("spatialCoord3DItem creates SCOORD3D type")
    func testSpatialCoord3DItem() {
        let concept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Volume"
        )
        let item = SRBuilderHelpers.spatialCoord3DItem(
            conceptName: concept,
            graphicType: .ellipsoid,
            graphicData: [10, 20, 30, 40, 50, 60]
        )
        #expect(item.valueType == .spatialCoord3D)
        #expect(item.graphicType3D == .ellipsoid)
    }

    // MARK: - Template Builders

    @Test("buildBasicTextSR creates radiology report template")
    func testBuildBasicTextRadiology() {
        let root = SRBuilderHelpers.buildBasicTextSR(template: .radiologyReport)
        #expect(root.valueType == .container)
        #expect(root.children.count == 3)
    }

    @Test("buildBasicTextSR with section texts")
    func testBuildBasicTextWithSections() {
        let texts = ["Findings": "No acute findings"]
        let root = SRBuilderHelpers.buildBasicTextSR(
            template: .radiologyReport,
            sectionTexts: texts
        )
        #expect(root.children.count == 3)
        // The "Findings" section should have a text child
        let findingsSection = root.children[0]
        #expect(findingsSection.children.count == 1)
    }

    @Test("buildKeyObjectSelection creates KOS document")
    func testBuildKOS() {
        let root = SRBuilderHelpers.buildKeyObjectSelection(
            purpose: .teaching,
            description: "Notable case",
            imageReferences: [("1.2.3", "4.5.6")]
        )
        #expect(root.valueType == .container)
        #expect(root.children.count == 2) // description + 1 image
    }

    @Test("buildMeasurementReport creates empty report")
    func testBuildEmptyMeasurementReport() {
        let root = SRBuilderHelpers.buildMeasurementReport()
        #expect(root.valueType == .container)
        #expect(root.children.isEmpty)
    }

    @Test("buildMeasurementReport with measurements")
    func testBuildMeasurementReportWithData() {
        let unit = CodedConcept(codeValue: "mm", codingSchemeDesignator: "UCUM", codeMeaning: "mm")
        let measurements = [
            TrackedMeasurement(trackingIdentifier: "L1", value: 15.0, unit: unit),
            TrackedMeasurement(trackingIdentifier: "L2", value: 22.0, unit: unit),
        ]
        let root = SRBuilderHelpers.buildMeasurementReport(measurements: measurements)
        #expect(root.children.count == 2)
    }

    @Test("buildMeasurementGroup creates group with tracking")
    func testBuildMeasurementGroup() {
        let unit = CodedConcept(codeValue: "mm", codingSchemeDesignator: "UCUM", codeMeaning: "mm")
        let site = CodedConcept(codeValue: "39607008", codingSchemeDesignator: "SCT", codeMeaning: "Lung")
        let m = TrackedMeasurement(
            trackingIdentifier: "L1",
            trackingUID: "1.2.3.4",
            value: 15.0,
            unit: unit,
            findingSite: site
        )
        let group = SRBuilderHelpers.buildMeasurementGroup(for: m)
        #expect(group.valueType == .container)
        #expect(group.children.count == 4) // tracking ID + tracking UID + measurement + site
    }

    // MARK: - Validation

    @Test("validateDocument catches empty title")
    func testValidateEmptyTitle() {
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "")
        let doc = SRDocument(documentType: .basicText, title: title)
        let errors = SRBuilderHelpers.validateDocument(doc)
        #expect(errors.contains { $0.contains("title") })
    }

    @Test("validateDocument catches non-container root")
    func testValidateNonContainerRoot() {
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report")
        let textRoot = SRContentItem(valueType: .text, textValue: "Not a container")
        let doc = SRDocument(documentType: .basicText, title: title, rootContentItem: textRoot)
        let errors = SRBuilderHelpers.validateDocument(doc)
        #expect(errors.contains { $0.contains("CONTAINER") })
    }

    @Test("validateDocument catches empty content")
    func testValidateEmptyContent() {
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report")
        let doc = SRDocument(documentType: .basicText, title: title)
        let errors = SRBuilderHelpers.validateDocument(doc)
        #expect(errors.contains { $0.contains("no content") })
    }

    @Test("validateDocument catches empty text value")
    func testValidateEmptyText() {
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report")
        let textItem = SRContentItem(valueType: .text, textValue: "")
        let root = SRContentItem(valueType: .container, continuityOfContent: .separate, children: [textItem])
        let doc = SRDocument(documentType: .basicText, title: title, rootContentItem: root)
        let errors = SRBuilderHelpers.validateDocument(doc)
        #expect(errors.contains { $0.contains("empty value") })
    }

    @Test("validateDocument catches numeric without unit")
    func testValidateNumericNoUnit() {
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report")
        let numItem = SRContentItem(valueType: .numeric, numericValue: 42.0)
        let root = SRContentItem(valueType: .container, continuityOfContent: .separate, children: [numItem])
        let doc = SRDocument(documentType: .basicText, title: title, rootContentItem: root)
        let errors = SRBuilderHelpers.validateDocument(doc)
        #expect(errors.contains { $0.contains("no unit") })
    }

    // MARK: - Supported Types

    @Test("supportedDocumentTypes for template mode")
    func testSupportedTypesTemplate() {
        let types = SRBuilderHelpers.supportedDocumentTypes(for: .template)
        #expect(types.count == 4)
        #expect(types.contains(.basicText))
    }

    @Test("supportedDocumentTypes for freeForm mode")
    func testSupportedTypesFreeForm() {
        let types = SRBuilderHelpers.supportedDocumentTypes(for: .freeForm)
        #expect(types.count == SRDocumentType.allCases.count)
    }

    @Test("availableTemplates for basicText")
    func testTemplatesBasicText() {
        let templates = SRBuilderHelpers.availableTemplates(for: .basicText)
        #expect(templates.count == SRTemplate.allCases.count)
    }

    @Test("availableTemplates for keyObjectSelection is empty")
    func testTemplatesKOS() {
        let templates = SRBuilderHelpers.availableTemplates(for: .keyObjectSelection)
        #expect(templates.isEmpty)
    }
}

// MARK: - TerminologyHelpers Tests

@Suite("TerminologyHelpers Tests")
struct TerminologyHelpersTests {

    @Test("SNOMED CT concepts are non-empty")
    func testSnomedCTConcepts() {
        #expect(!TerminologyHelpers.snomedCTConcepts.isEmpty)
        #expect(TerminologyHelpers.snomedCTConcepts.count >= 20)
    }

    @Test("LOINC concepts are non-empty")
    func testLoincConcepts() {
        #expect(!TerminologyHelpers.loincConcepts.isEmpty)
        #expect(TerminologyHelpers.loincConcepts.count >= 10)
    }

    @Test("RadLex concepts are non-empty")
    func testRadlexConcepts() {
        #expect(!TerminologyHelpers.radlexConcepts.isEmpty)
        #expect(TerminologyHelpers.radlexConcepts.count >= 10)
    }

    @Test("UCUM units are non-empty")
    func testUcumUnits() {
        #expect(!TerminologyHelpers.ucumUnits.isEmpty)
        #expect(TerminologyHelpers.ucumUnits.count >= 15)
    }

    @Test("Search finds matching entries")
    func testSearchFindsMatch() {
        let results = TerminologyHelpers.search(query: "Lung")
        #expect(!results.isEmpty)
    }

    @Test("Search is case-insensitive")
    func testSearchCaseInsensitive() {
        let results1 = TerminologyHelpers.search(query: "lung")
        let results2 = TerminologyHelpers.search(query: "LUNG")
        #expect(results1.count == results2.count)
    }

    @Test("Search with scope filters correctly")
    func testSearchWithScope() {
        let sctResults = TerminologyHelpers.search(query: "Lung", scope: .snomedCT)
        let allResults = TerminologyHelpers.search(query: "Lung", scope: .all)
        #expect(allResults.count >= sctResults.count)
    }

    @Test("Search with empty query returns empty")
    func testSearchEmpty() {
        let results = TerminologyHelpers.search(query: "")
        #expect(results.isEmpty)
    }

    @Test("entriesForScope returns correct terminology")
    func testEntriesForScope() {
        let sctEntries = TerminologyHelpers.entriesForScope(.snomedCT)
        for entry in sctEntries {
            #expect(entry.concept.codingSchemeDesignator == "SCT")
        }
    }

    @Test("categories returns sorted unique categories")
    func testCategories() {
        let cats = TerminologyHelpers.categories(for: .snomedCT)
        #expect(!cats.isEmpty)
        // Verify sorted
        for i in 0..<(cats.count - 1) {
            #expect(cats[i] <= cats[i + 1])
        }
    }

    @Test("entriesInCategory filters correctly")
    func testEntriesInCategory() {
        let bodyParts = TerminologyHelpers.entriesInCategory("Body Part", scope: .snomedCT)
        #expect(!bodyParts.isEmpty)
        for entry in bodyParts {
            #expect(entry.category == "Body Part")
        }
    }

    @Test("schemeDisplayName returns readable names")
    func testSchemeDisplayName() {
        #expect(TerminologyHelpers.schemeDisplayName(for: "SCT") == "SNOMED CT")
        #expect(TerminologyHelpers.schemeDisplayName(for: "LN") == "LOINC")
        #expect(TerminologyHelpers.schemeDisplayName(for: "RADLEX") == "RadLex")
        #expect(TerminologyHelpers.schemeDisplayName(for: "UCUM") == "UCUM")
        #expect(TerminologyHelpers.schemeDisplayName(for: "XYZ") == "XYZ")
    }

    @Test("sfSymbolForScheme returns non-empty symbols")
    func testSFSymbols() {
        let schemes = ["SCT", "LN", "RADLEX", "UCUM", "DCM", "OTHER"]
        for scheme in schemes {
            #expect(!TerminologyHelpers.sfSymbolForScheme(scheme).isEmpty)
        }
    }

    @Test("crossTerminologyMappings returns mappings")
    func testCrossMapping() {
        let massConcept = CodedConcept(
            codeValue: "4147007", codingSchemeDesignator: "SCT", codeMeaning: "Mass"
        )
        let mappings = TerminologyHelpers.crossTerminologyMappings(for: massConcept)
        #expect(!mappings.isEmpty)
        #expect(mappings[0].codingSchemeDesignator == "RADLEX")
    }

    @Test("crossTerminologyMappings returns empty for unknown")
    func testCrossMappingUnknown() {
        let concept = CodedConcept(
            codeValue: "999999", codingSchemeDesignator: "UNK", codeMeaning: "Unknown"
        )
        let mappings = TerminologyHelpers.crossTerminologyMappings(for: concept)
        #expect(mappings.isEmpty)
    }

    @Test("convertUCUM converts mm to cm")
    func testConvertMMtoCM() {
        let result = TerminologyHelpers.convertUCUM(value: 100.0, fromUnit: "mm", toUnit: "cm")
        #expect(result != nil)
        #expect(result! == 10.0)
    }

    @Test("convertUCUM converts cm to mm")
    func testConvertCMtoMM() {
        let result = TerminologyHelpers.convertUCUM(value: 5.0, fromUnit: "cm", toUnit: "mm")
        #expect(result == 50.0)
    }

    @Test("convertUCUM returns nil for incompatible units")
    func testConvertIncompatible() {
        let result = TerminologyHelpers.convertUCUM(value: 10.0, fromUnit: "mm", toUnit: "kg")
        #expect(result == nil)
    }

    @Test("convertUCUM handles degrees to radians")
    func testConvertDegToRad() {
        let result = TerminologyHelpers.convertUCUM(value: 180.0, fromUnit: "deg", toUnit: "rad")
        #expect(result != nil)
        let diff = abs(result! - Double.pi)
        #expect(diff < 0.001)
    }

    @Test("Search by code value works")
    func testSearchByCode() {
        let results = TerminologyHelpers.search(query: "410668003")
        #expect(!results.isEmpty)
        #expect(results[0].concept.codeMeaning == "Length")
    }
}

// MARK: - CADVisualizationHelpers Tests

@Suite("CADVisualizationHelpers Tests")
struct CADVisualizationHelpersTests {

    @Test("colorForFindingType returns non-empty colors")
    func testColorForFindingType() {
        for ft in CADFindingType.allCases {
            #expect(!CADVisualizationHelpers.colorForFindingType(ft).isEmpty)
        }
    }

    @Test("Colors are distinct for different types")
    func testDistinctColors() {
        let massColor = CADVisualizationHelpers.colorForFindingType(.mass)
        let calcColor = CADVisualizationHelpers.colorForFindingType(.calcification)
        let noduleColor = CADVisualizationHelpers.colorForFindingType(.nodule)
        #expect(massColor != calcColor)
        #expect(massColor != noduleColor)
    }

    @Test("opacityForConfidence returns value in range")
    func testOpacityRange() {
        #expect(CADVisualizationHelpers.opacityForConfidence(0.0) >= 0.3)
        #expect(CADVisualizationHelpers.opacityForConfidence(1.0) <= 1.0)
        #expect(CADVisualizationHelpers.opacityForConfidence(0.5) > 0.3)
    }

    @Test("opacityForConfidence clamps input")
    func testOpacityClamping() {
        #expect(CADVisualizationHelpers.opacityForConfidence(-1.0) == 0.3)
        #expect(CADVisualizationHelpers.opacityForConfidence(2.0) == 1.0)
    }

    @Test("severityLabel returns correct labels")
    func testSeverityLabels() {
        #expect(CADVisualizationHelpers.severityLabel(for: 0.1) == "Low")
        #expect(CADVisualizationHelpers.severityLabel(for: 0.4) == "Moderate")
        #expect(CADVisualizationHelpers.severityLabel(for: 0.7) == "High")
        #expect(CADVisualizationHelpers.severityLabel(for: 0.9) == "Very High")
    }

    @Test("sfSymbolForStatus returns non-empty symbols")
    func testSFSymbols() {
        for status in CADFindingStatus.allCases {
            #expect(!CADVisualizationHelpers.sfSymbolForStatus(status).isEmpty)
        }
    }

    @Test("colorForStatus returns non-empty colors")
    func testColorForStatus() {
        for status in CADFindingStatus.allCases {
            #expect(!CADVisualizationHelpers.colorForStatus(status).isEmpty)
        }
    }

    @Test("colorForBIRADS returns non-empty colors")
    func testColorForBIRADS() {
        for category in BIRADSCategory.allCases {
            #expect(!CADVisualizationHelpers.colorForBIRADS(category).isEmpty)
        }
    }

    @Test("biradsDescription returns non-empty descriptions")
    func testBIRADSDescription() {
        for category in BIRADSCategory.allCases {
            #expect(!CADVisualizationHelpers.biradsDescription(category).isEmpty)
        }
    }

    @Test("buildMammographyFindings creates correct findings")
    func testBuildMammographyFindings() {
        let findings = CADVisualizationHelpers.buildMammographyFindings(
            masses: [("Upper outer quadrant", 0.85)],
            calcifications: [("Central region", 0.65)],
            distortions: [("Lower inner quadrant", 0.4)],
            birads: .category4
        )
        #expect(findings.count == 3)
        #expect(findings[0].findingType == .mass)
        #expect(findings[1].findingType == .calcification)
        #expect(findings[2].findingType == .architecturalDistortion)
        #expect(findings[0].biradsCategory == .category4)
    }

    @Test("buildChestCADFindings creates correct findings")
    func testBuildChestCADFindings() {
        let findings = CADVisualizationHelpers.buildChestCADFindings(
            nodules: [("Right upper lobe", 0.9), ("Left lower lobe", 0.7)],
            masses: [("Left hilum", 0.8)],
            consolidations: [("Right middle lobe", 0.6)]
        )
        #expect(findings.count == 4)
        #expect(findings[0].findingType == .nodule)
        #expect(findings[2].findingType == .mass)
    }

    @Test("filterByType filters correctly")
    func testFilterByType() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.8),
            CADFinding(findingType: .nodule, confidence: 0.7),
            CADFinding(findingType: .mass, confidence: 0.6),
        ]
        let masses = CADVisualizationHelpers.filterByType(findings, type: .mass)
        #expect(masses.count == 2)
    }

    @Test("filterByStatus filters correctly")
    func testFilterByStatus() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.8, status: .accepted),
            CADFinding(findingType: .nodule, confidence: 0.7, status: .pending),
            CADFinding(findingType: .mass, confidence: 0.6, status: .rejected),
        ]
        let pending = CADVisualizationHelpers.filterByStatus(findings, status: .pending)
        #expect(pending.count == 1)
    }

    @Test("filterByMinConfidence filters correctly")
    func testFilterByMinConfidence() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.9),
            CADFinding(findingType: .nodule, confidence: 0.4),
            CADFinding(findingType: .mass, confidence: 0.7),
        ]
        let highConf = CADVisualizationHelpers.filterByMinConfidence(findings, minConfidence: 0.5)
        #expect(highConf.count == 2)
    }

    @Test("sortByConfidence sorts descending")
    func testSortByConfidence() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.5),
            CADFinding(findingType: .nodule, confidence: 0.9),
            CADFinding(findingType: .lesion, confidence: 0.7),
        ]
        let sorted = CADVisualizationHelpers.sortByConfidence(findings)
        #expect(sorted[0].confidence == 0.9)
        #expect(sorted[1].confidence == 0.7)
        #expect(sorted[2].confidence == 0.5)
    }

    @Test("sortByTypeAndConfidence groups by type")
    func testSortByTypeAndConfidence() {
        let findings = [
            CADFinding(findingType: .nodule, confidence: 0.5),
            CADFinding(findingType: .mass, confidence: 0.9),
            CADFinding(findingType: .nodule, confidence: 0.8),
        ]
        let sorted = CADVisualizationHelpers.sortByTypeAndConfidence(findings)
        #expect(sorted[0].findingType == .mass)
        #expect(sorted[1].findingType == .nodule)
        #expect(sorted[1].confidence == 0.8) // Higher confidence first within type
    }

    @Test("findingStatistics returns correct counts")
    func testFindingStatistics() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.8, status: .accepted),
            CADFinding(findingType: .mass, confidence: 0.6, status: .pending),
            CADFinding(findingType: .nodule, confidence: 0.7, status: .rejected),
        ]
        let stats = CADVisualizationHelpers.findingStatistics(findings)
        #expect(stats["total"] == 3)
        #expect(stats["accepted"] == 1)
        #expect(stats["pending"] == 1)
        #expect(stats["rejected"] == 1)
        #expect(stats["mass"] == 2)
        #expect(stats["nodule"] == 1)
    }

    @Test("averageConfidence computes correctly")
    func testAverageConfidence() {
        let findings = [
            CADFinding(findingType: .mass, confidence: 0.8),
            CADFinding(findingType: .nodule, confidence: 0.6),
        ]
        let avg = CADVisualizationHelpers.averageConfidence(findings)
        #expect(abs(avg - 0.7) < 0.001)
    }

    @Test("averageConfidence returns 0 for empty array")
    func testAverageConfidenceEmpty() {
        let avg = CADVisualizationHelpers.averageConfidence([])
        #expect(avg == 0.0)
    }
}
