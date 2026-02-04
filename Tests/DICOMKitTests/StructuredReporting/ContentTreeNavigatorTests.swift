import Testing
import Foundation
import DICOMCore
@testable import DICOMKit

// MARK: - ContentTreeIterator Tests

@Suite("ContentTreeIterator Tests")
struct ContentTreeIteratorTests {
    
    /// Creates a test container with nested content
    private func createTestContainer() -> ContainerContentItem {
        // Create a tree structure:
        // Root
        // ├── Text 1
        // ├── Container A
        // │   ├── Text A1
        // │   └── Text A2
        // └── Container B
        //     ├── Text B1
        //     └── Container B1
        //         └── Text B1a
        
        let containerB1 = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "B1", codingSchemeDesignator: "TEST", codeMeaning: "Container B1"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text B1a", relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        let containerA = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "A", codingSchemeDesignator: "TEST", codeMeaning: "Container A"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text A1", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Text A2", relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        let containerB = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "B", codingSchemeDesignator: "TEST", codeMeaning: "Container B"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text B1", relationshipType: .contains)),
                AnyContentItem(containerB1)
            ],
            relationshipType: .contains
        )
        
        return ContainerContentItem(
            conceptName: CodedConcept(codeValue: "ROOT", codingSchemeDesignator: "TEST", codeMeaning: "Root"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text 1", relationshipType: .contains)),
                AnyContentItem(containerA),
                AnyContentItem(containerB)
            ]
        )
    }
    
    @Test("Depth-first iteration visits all items")
    func testDepthFirstIterationVisitsAll() {
        let container = createTestContainer()
        var iterator = ContentTreeIterator(container: container)
        
        var items: [AnyContentItem] = []
        while let item = iterator.next() {
            items.append(item)
        }
        
        // Should visit: Text 1, Container A, Text A1, Text A2, Container B, Text B1, Container B1, Text B1a
        #expect(items.count == 8)
    }
    
    @Test("Depth-first iteration order is correct")
    func testDepthFirstIterationOrder() {
        let container = createTestContainer()
        let items = Array(ContentTreeSequence(container: container, order: .depthFirst))
        
        // First item should be Text 1
        #expect(items[0].asText?.textValue == "Text 1")
        
        // Second should be Container A
        #expect(items[1].asContainer?.conceptName?.codeMeaning == "Container A")
        
        // Third should be Text A1 (child of A)
        #expect(items[2].asText?.textValue == "Text A1")
        
        // Fourth should be Text A2 (child of A)
        #expect(items[3].asText?.textValue == "Text A2")
        
        // Fifth should be Container B
        #expect(items[4].asContainer?.conceptName?.codeMeaning == "Container B")
    }
    
    @Test("Max depth limits iteration")
    func testMaxDepthLimitsIteration() {
        let container = createTestContainer()
        
        // Only iterate to depth 0 (direct children only)
        let itemsDepth0 = Array(ContentTreeSequence(container: container, order: .depthFirst, maxDepth: 0))
        #expect(itemsDepth0.count == 3) // Text 1, Container A, Container B
        
        // Iterate to depth 1 (direct children and their children)
        let itemsDepth1 = Array(ContentTreeSequence(container: container, order: .depthFirst, maxDepth: 1))
        #expect(itemsDepth1.count == 7) // All except Text B1a (which is at depth 2)
        
        // Unlimited depth
        let itemsUnlimited = Array(ContentTreeSequence(container: container, order: .depthFirst))
        #expect(itemsUnlimited.count == 8)
    }
}

// MARK: - BreadthFirstIterator Tests

@Suite("BreadthFirstIterator Tests")
struct BreadthFirstIteratorTests {
    
    private func createTestContainer() -> ContainerContentItem {
        let innerContainer = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "INNER", codingSchemeDesignator: "TEST", codeMeaning: "Inner Container"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Deep Text", relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        return ContainerContentItem(
            conceptName: CodedConcept(codeValue: "ROOT", codingSchemeDesignator: "TEST", codeMeaning: "Root"),
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text 1", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Text 2", relationshipType: .contains)),
                AnyContentItem(innerContainer)
            ]
        )
    }
    
    @Test("Breadth-first visits all items at each level before descending")
    func testBreadthFirstOrder() {
        let container = createTestContainer()
        let items = Array(ContentTreeSequence(container: container, order: .breadthFirst))
        
        // Level 0: Text 1, Text 2, Inner Container (indices 0, 1, 2)
        // Level 1: Deep Text (index 3)
        #expect(items.count == 4)
        #expect(items[0].asText?.textValue == "Text 1")
        #expect(items[1].asText?.textValue == "Text 2")
        #expect(items[2].asContainer != nil)
        #expect(items[3].asText?.textValue == "Deep Text")
    }
    
    @Test("Breadth-first max depth works correctly")
    func testBreadthFirstMaxDepth() {
        let container = createTestContainer()
        
        let itemsDepth0 = Array(ContentTreeSequence(container: container, order: .breadthFirst, maxDepth: 0))
        #expect(itemsDepth0.count == 3) // Only root's direct children
        
        let itemsUnlimited = Array(ContentTreeSequence(container: container, order: .breadthFirst))
        #expect(itemsUnlimited.count == 4)
    }
}

// MARK: - SRPath Tests

@Suite("SRPath Tests")
struct SRPathTests {
    
    @Test("Empty path represents root")
    func testEmptyPathIsRoot() {
        let path = SRPath()
        #expect(path.isRoot)
        #expect(path.components.isEmpty)
        #expect(path.depth == 0)
        #expect(path.description == "/")
    }
    
    @Test("Path from string parsing")
    func testPathFromString() throws {
        let path = try SRPath(pathString: "/Finding/Measurement")
        
        #expect(path.components.count == 2)
        #expect(path.components[0].conceptName == "Finding")
        #expect(path.components[1].conceptName == "Measurement")
    }
    
    @Test("Path with index parsing")
    func testPathWithIndex() throws {
        let path = try SRPath(pathString: "/Finding[1]/Measurement[0]")
        
        #expect(path.components.count == 2)
        #expect(path.components[0].conceptName == "Finding")
        #expect(path.components[0].index == 1)
        #expect(path.components[1].conceptName == "Measurement")
        #expect(path.components[1].index == 0)
    }
    
    @Test("Path description")
    func testPathDescription() throws {
        let path = try SRPath(pathString: "/Finding[1]/Measurement")
        #expect(path.description == "/Finding[1]/Measurement")
    }
    
    @Test("Path appending")
    func testPathAppending() {
        let path = SRPath()
            .appending(conceptName: "Finding")
            .appending(conceptName: "Measurement", index: 0)
        
        #expect(path.components.count == 2)
        #expect(path.description == "/Finding/Measurement[0]")
    }
    
    @Test("Parent path")
    func testParentPath() throws {
        let path = try SRPath(pathString: "/Finding/Measurement")
        let parent = path.parent
        
        #expect(parent != nil)
        #expect(parent?.description == "/Finding")
        
        let grandparent = parent?.parent
        #expect(grandparent != nil)
        #expect(grandparent?.isRoot == true)
        
        let greatGrandparent = grandparent?.parent
        #expect(greatGrandparent == nil)
    }
    
    @Test("Path component matching")
    func testComponentMatching() {
        let component = SRPath.Component(conceptName: "Finding")
        
        let matchingItem = AnyContentItem(TextContentItem(
            conceptName: CodedConcept(codeValue: "F1", codingSchemeDesignator: "TEST", codeMeaning: "Finding"),
            textValue: "Test"
        ))
        
        let nonMatchingItem = AnyContentItem(TextContentItem(
            conceptName: CodedConcept(codeValue: "O1", codingSchemeDesignator: "TEST", codeMeaning: "Other"),
            textValue: "Test"
        ))
        
        #expect(component.matches(matchingItem))
        #expect(!component.matches(nonMatchingItem))
    }
    
    @Test("Path component matching by code value")
    func testComponentMatchingByCodeValue() {
        let component = SRPath.Component(conceptName: "F1")
        
        let matchingItem = AnyContentItem(TextContentItem(
            conceptName: CodedConcept(codeValue: "F1", codingSchemeDesignator: "TEST", codeMeaning: "Finding"),
            textValue: "Test"
        ))
        
        #expect(component.matches(matchingItem))
    }
    
    @Test("Path component with value type filter")
    func testComponentValueTypeFilter() {
        let component = SRPath.Component(conceptName: "Finding", valueType: .text)
        
        let textItem = AnyContentItem(TextContentItem(
            conceptName: CodedConcept(codeValue: "F1", codingSchemeDesignator: "TEST", codeMeaning: "Finding"),
            textValue: "Test"
        ))
        
        let codeItem = AnyContentItem(CodeContentItem(
            conceptName: CodedConcept(codeValue: "F1", codingSchemeDesignator: "TEST", codeMeaning: "Finding"),
            conceptCode: CodedConcept.finding
        ))
        
        #expect(component.matches(textItem))
        #expect(!component.matches(codeItem))
    }
}

// MARK: - ContainerContentItem Navigation Tests

@Suite("ContainerContentItem Navigation Tests")
struct ContainerNavigationTests {
    
    private func createMeasurementContainer() -> ContainerContentItem {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let lengthConcept = CodedConcept(codeValue: "410668003", codingSchemeDesignator: "SCT", codeMeaning: "Length")
        
        return ContainerContentItem(
            conceptName: CodedConcept(codeValue: "MEAS", codingSchemeDesignator: "TEST", codeMeaning: "Measurements"),
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: volumeConcept, value: 125.5, relationshipType: .contains)),
                AnyContentItem(NumericContentItem(conceptName: lengthConcept, value: 5.2, relationshipType: .contains)),
                AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(codeValue: "NOTE", codingSchemeDesignator: "TEST", codeMeaning: "Note"),
                    textValue: "Measurement note",
                    relationshipType: .contains
                ))
            ]
        )
    }
    
    @Test("Subscript by index")
    func testSubscriptByIndex() {
        let container = createMeasurementContainer()
        
        #expect(container[0]?.asNumeric != nil)
        #expect(container[1]?.asNumeric != nil)
        #expect(container[2]?.asText != nil)
        #expect(container[3] == nil) // Out of bounds
        #expect(container[-1] == nil) // Negative index
    }
    
    @Test("Subscript by concept string")
    func testSubscriptByConceptString() {
        let container = createMeasurementContainer()
        
        let volume = container[concept: "Volume"]
        #expect(volume?.asNumeric?.value == 125.5)
        
        let length = container[concept: "Length"]
        #expect(length?.asNumeric?.value == 5.2)
        
        let note = container[concept: "Note"]
        #expect(note?.asText?.textValue == "Measurement note")
        
        let nonExistent = container[concept: "NonExistent"]
        #expect(nonExistent == nil)
    }
    
    @Test("Subscript by coded concept")
    func testSubscriptByCodedConcept() {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let container = createMeasurementContainer()
        
        let volume = container[concept: volumeConcept]
        #expect(volume?.asNumeric?.value == 125.5)
    }
    
    @Test("Children by concept string")
    func testChildrenByConceptString() {
        let findingConcept = CodedConcept(codeValue: "F", codingSchemeDesignator: "TEST", codeMeaning: "Finding")
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Finding 1")),
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Finding 2")),
                AnyContentItem(TextContentItem(textValue: "Other"))
            ]
        )
        
        let findings = container.children(withConcept: "Finding")
        #expect(findings.count == 2)
    }
    
    @Test("Children by value type")
    func testChildrenByValueType() {
        let container = createMeasurementContainer()
        
        let numericChildren = container.children(ofType: .num)
        #expect(numericChildren.count == 2)
        
        let textChildren = container.children(ofType: .text)
        #expect(textChildren.count == 1)
        
        let codeChildren = container.children(ofType: .code)
        #expect(codeChildren.count == 0)
    }
    
    @Test("Item at path")
    func testItemAtPath() throws {
        let innerContainer = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "I", codingSchemeDesignator: "TEST", codeMeaning: "Inner"),
            contentItems: [
                AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(codeValue: "T", codingSchemeDesignator: "TEST", codeMeaning: "Target"),
                    textValue: "Target Text"
                ))
            ],
            relationshipType: .contains
        )
        
        let root = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text 1")),
                AnyContentItem(innerContainer)
            ]
        )
        
        let path = try SRPath(pathString: "/Inner/Target")
        let item = root.item(at: path)
        
        #expect(item?.asText?.textValue == "Target Text")
    }
    
    @Test("Item at path with index")
    func testItemAtPathWithIndex() throws {
        let findingConcept = CodedConcept(codeValue: "F", codingSchemeDesignator: "TEST", codeMeaning: "Finding")
        let root = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Finding 1")),
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Finding 2")),
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Finding 3"))
            ]
        )
        
        let path0 = try SRPath(pathString: "/Finding[0]")
        let path1 = try SRPath(pathString: "/Finding[1]")
        let path2 = try SRPath(pathString: "/Finding[2]")
        
        #expect(root.item(at: path0)?.asText?.textValue == "Finding 1")
        #expect(root.item(at: path1)?.asText?.textValue == "Finding 2")
        #expect(root.item(at: path2)?.asText?.textValue == "Finding 3")
    }
    
    @Test("Find items by concept name")
    func testFindItemsByConceptName() {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let container = createMeasurementContainer()
        
        let items = container.findItems(byConceptName: volumeConcept)
        #expect(items.count == 1)
        #expect(items[0].asNumeric?.value == 125.5)
    }
    
    @Test("Find items by value type")
    func testFindItemsByValueType() {
        let container = createMeasurementContainer()
        
        let numItems = container.findItems(byValueType: .num)
        #expect(numItems.count == 2)
        
        let textItems = container.findItems(byValueType: .text)
        #expect(textItems.count == 1)
    }
    
    @Test("Find items by relationship")
    func testFindItemsByRelationship() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Contains 1", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Contains 2", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Property", relationshipType: .hasProperties))
            ]
        )
        
        let containsItems = container.findItems(byRelationship: .contains)
        #expect(containsItems.count == 2)
        
        let propertyItems = container.findItems(byRelationship: .hasProperties)
        #expect(propertyItems.count == 1)
    }
    
    @Test("Find items with predicate")
    func testFindItemsWithPredicate() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(NumericContentItem(value: 10.0)),
                AnyContentItem(NumericContentItem(value: 25.0)),
                AnyContentItem(NumericContentItem(value: 50.0)),
                AnyContentItem(TextContentItem(textValue: "Text"))
            ]
        )
        
        let largeValues = container.findItems { item in
            guard let numeric = item.asNumeric else { return false }
            return numeric.value ?? 0 > 20
        }
        
        #expect(largeValues.count == 2)
    }
    
    @Test("Non-recursive find")
    func testNonRecursiveFind() {
        let innerContainer = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Inner Text"))
            ],
            relationshipType: .contains
        )
        
        let root = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Outer Text")),
                AnyContentItem(innerContainer)
            ]
        )
        
        let recursiveItems = root.findItems(byValueType: .text, recursive: true)
        #expect(recursiveItems.count == 2)
        
        let nonRecursiveItems = root.findItems(byValueType: .text, recursive: false)
        #expect(nonRecursiveItems.count == 1)
    }
}

// MARK: - Relationship Navigation Tests

@Suite("Relationship Navigation Tests")
struct RelationshipNavigationTests {
    
    @Test("Property items navigation")
    func testPropertyItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Property 1", relationshipType: .hasProperties)),
                AnyContentItem(TextContentItem(textValue: "Property 2", relationshipType: .hasProperties)),
                AnyContentItem(TextContentItem(textValue: "Content", relationshipType: .contains))
            ]
        )
        
        #expect(container.propertyItems.count == 2)
    }
    
    @Test("Contained items navigation")
    func testContainedItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Content 1", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Content 2", relationshipType: .contains)),
                AnyContentItem(TextContentItem(textValue: "Property", relationshipType: .hasProperties))
            ]
        )
        
        #expect(container.containedItems.count == 2)
    }
    
    @Test("Inferred from items navigation")
    func testInferredFromItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Inferred 1", relationshipType: .inferredFrom)),
                AnyContentItem(TextContentItem(textValue: "Content", relationshipType: .contains))
            ]
        )
        
        #expect(container.inferredFromItems.count == 1)
    }
    
    @Test("Observation context items")
    func testObservationContextItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Observer", relationshipType: .hasObsContext)),
                AnyContentItem(TextContentItem(textValue: "Content", relationshipType: .contains))
            ]
        )
        
        #expect(container.observationContextItems.count == 1)
    }
    
    @Test("Acquisition context items")
    func testAcquisitionContextItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Acquisition", relationshipType: .hasAcqContext)),
                AnyContentItem(TextContentItem(textValue: "Content", relationshipType: .contains))
            ]
        )
        
        #expect(container.acquisitionContextItems.count == 1)
    }
    
    @Test("Selected from items")
    func testSelectedFromItems() {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(ImageContentItem(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6", relationshipType: .selectedFrom)),
                AnyContentItem(TextContentItem(textValue: "Content", relationshipType: .contains))
            ]
        )
        
        #expect(container.selectedFromItems.count == 1)
    }
}

// MARK: - Measurement Navigation Tests

@Suite("Measurement Navigation Tests")
struct MeasurementNavigationTests {
    
    private func createMeasurementDocument() -> ContainerContentItem {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let lengthConcept = CodedConcept(codeValue: "410668003", codingSchemeDesignator: "SCT", codeMeaning: "Length")
        let areaConcept = CodedConcept(codeValue: "42798000", codingSchemeDesignator: "SCT", codeMeaning: "Area")
        
        let measurementGroup = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "MG", codingSchemeDesignator: "TEST", codeMeaning: "Measurement Group"),
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: lengthConcept, value: 5.2)),
                AnyContentItem(NumericContentItem(conceptName: areaConcept, value: 15.0))
            ],
            relationshipType: .contains
        )
        
        return ContainerContentItem(
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: volumeConcept, value: 125.5, relationshipType: .contains)),
                AnyContentItem(measurementGroup),
                AnyContentItem(TextContentItem(textValue: "Note", relationshipType: .contains))
            ]
        )
    }
    
    @Test("Find all measurements")
    func testFindAllMeasurements() {
        let container = createMeasurementDocument()
        let measurements = container.findMeasurements()
        
        #expect(measurements.count == 3)
    }
    
    @Test("Find measurements by concept")
    func testFindMeasurementsByConcept() {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let container = createMeasurementDocument()
        
        let volumes = container.findMeasurements(forConcept: volumeConcept)
        #expect(volumes.count == 1)
        #expect(volumes[0].value == 125.5)
    }
    
    @Test("Find measurements by concept string")
    func testFindMeasurementsByConceptString() {
        let container = createMeasurementDocument()
        
        let lengths = container.findMeasurements(forConceptString: "Length")
        #expect(lengths.count == 1)
        #expect(lengths[0].value == 5.2)
    }
    
    @Test("Find measurement groups")
    func testFindMeasurementGroups() {
        let container = createMeasurementDocument()
        
        let groups = container.findMeasurementGroups()
        #expect(groups.count == 1)
        #expect(groups[0].conceptName?.codeMeaning == "Measurement Group")
    }
    
    @Test("Get measurement value")
    func testGetMeasurementValue() {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let container = createMeasurementDocument()
        
        let volume = container.getMeasurementValue(forConcept: volumeConcept)
        #expect(volume == 125.5)
        
        let nonExistent = container.getMeasurementValue(forConcept: CodedConcept.finding)
        #expect(nonExistent == nil)
    }
    
    @Test("Get measurement value by string")
    func testGetMeasurementValueByString() {
        let container = createMeasurementDocument()
        
        let area = container.getMeasurementValue(forConceptString: "Area")
        #expect(area == 15.0)
    }
    
    @Test("Non-recursive measurement search")
    func testNonRecursiveMeasurementSearch() {
        let container = createMeasurementDocument()
        
        let recursiveMeasurements = container.findMeasurements(recursive: true)
        #expect(recursiveMeasurements.count == 3)
        
        let nonRecursiveMeasurements = container.findMeasurements(recursive: false)
        #expect(nonRecursiveMeasurements.count == 1) // Only the volume at root level
    }
}

// MARK: - SRDocument Navigation Tests

@Suite("SRDocument Navigation Tests")
struct SRDocumentNavigationTests {
    
    private func createTestDocument() -> SRDocument {
        let findingConcept = CodedConcept(codeValue: "F1", codingSchemeDesignator: "TEST", codeMeaning: "Finding")
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        
        let measurementContainer = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "MEAS", codingSchemeDesignator: "TEST", codeMeaning: "Measurements"),
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: volumeConcept, value: 100.0, relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        let rootContent = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "REPORT", codingSchemeDesignator: "TEST", codeMeaning: "Report"),
            contentItems: [
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Lesion found", relationshipType: .contains)),
                AnyContentItem(measurementContainer)
            ]
        )
        
        return SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3.4.5",
            rootContent: rootContent
        )
    }
    
    @Test("Document content tree sequence")
    func testDocumentContentTreeSequence() {
        let document = createTestDocument()
        let items = Array(document.contentTreeSequence())
        
        // Text, Container, Numeric = 3 items
        #expect(items.count == 3)
    }
    
    @Test("Document item at path string")
    func testDocumentItemAtPathString() {
        let document = createTestDocument()
        
        let item = document.item(at: "/Measurements/Volume")
        #expect(item?.asNumeric?.value == 100.0)
    }
    
    @Test("Document subscript path access")
    func testDocumentSubscriptPathAccess() {
        let document = createTestDocument()
        
        let item = document[path: "/Finding"]
        #expect(item?.asText?.textValue == "Lesion found")
    }
    
    @Test("Document subscript index access")
    func testDocumentSubscriptIndexAccess() {
        let document = createTestDocument()
        
        let firstItem = document[0]
        #expect(firstItem?.asText != nil)
        
        let secondItem = document[1]
        #expect(secondItem?.asContainer != nil)
    }
    
    @Test("Document subscript concept access")
    func testDocumentSubscriptConceptAccess() {
        let document = createTestDocument()
        
        let finding = document[concept: "Finding"]
        #expect(finding?.asText?.textValue == "Lesion found")
    }
    
    @Test("Document find items by predicate")
    func testDocumentFindItemsByPredicate() {
        let document = createTestDocument()
        
        let textItems = document.findItems { $0.valueType == .text }
        #expect(textItems.count == 1)
    }
    
    @Test("Document find items by concept")
    func testDocumentFindItemsByConcept() {
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let document = createTestDocument()
        
        let items = document.findItems(byConceptName: volumeConcept)
        #expect(items.count == 1)
    }
    
    @Test("Document find items by relationship")
    func testDocumentFindItemsByRelationship() {
        let document = createTestDocument()
        
        let containsItems = document.findItems(byRelationship: .contains)
        #expect(containsItems.count == 3)
    }
    
    @Test("Document find all measurements")
    func testDocumentFindAllMeasurements() {
        let document = createTestDocument()
        
        let measurements = document.findAllMeasurements()
        #expect(measurements.count == 1)
        #expect(measurements[0].value == 100.0)
    }
    
    @Test("Document find measurement groups")
    func testDocumentFindMeasurementGroups() {
        let document = createTestDocument()
        
        let groups = document.findMeasurementGroups()
        #expect(groups.count == 1)
        #expect(groups[0].conceptName?.codeMeaning == "Measurements")
    }
    
    @Test("Document get measurement value")
    func testDocumentGetMeasurementValue() {
        let document = createTestDocument()
        
        let volume = document.getMeasurementValue(forConceptString: "Volume")
        #expect(volume == 100.0)
    }
    
    @Test("Document relationship navigation properties")
    func testDocumentRelationshipNavigation() {
        let document = createTestDocument()
        
        let containedItems = document.containedItems
        #expect(containedItems.count == 3)
    }
}

// MARK: - AnyContentItem Navigation Tests

@Suite("AnyContentItem Navigation Tests")
struct AnyContentItemNavigationTests {
    
    @Test("AnyContentItem sequence for container")
    func testAnyContentItemSequenceForContainer() {
        let innerContainer = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "Text 1")),
                AnyContentItem(TextContentItem(textValue: "Text 2"))
            ]
        )
        
        let anyItem = AnyContentItem(innerContainer)
        let sequence = anyItem.contentTreeSequence()
        
        #expect(sequence != nil)
        let items = Array(sequence!)
        #expect(items.count == 2)
    }
    
    @Test("AnyContentItem sequence for non-container")
    func testAnyContentItemSequenceForNonContainer() {
        let textItem = AnyContentItem(TextContentItem(textValue: "Test"))
        let sequence = textItem.contentTreeSequence()
        
        #expect(sequence == nil)
    }
    
    @Test("AnyContentItem subscript access")
    func testAnyContentItemSubscriptAccess() {
        let innerContainer = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(textValue: "First")),
                AnyContentItem(TextContentItem(textValue: "Second"))
            ]
        )
        
        let anyItem = AnyContentItem(innerContainer)
        
        #expect(anyItem[0]?.asText?.textValue == "First")
        #expect(anyItem[1]?.asText?.textValue == "Second")
        #expect(anyItem[2] == nil)
    }
    
    @Test("AnyContentItem concept subscript")
    func testAnyContentItemConceptSubscript() {
        let findingConcept = CodedConcept(codeValue: "F", codingSchemeDesignator: "TEST", codeMeaning: "Finding")
        let innerContainer = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(conceptName: findingConcept, textValue: "Found it"))
            ]
        )
        
        let anyItem = AnyContentItem(innerContainer)
        let finding = anyItem[concept: "Finding"]
        
        #expect(finding?.asText?.textValue == "Found it")
    }
}

// MARK: - SRPath Error Tests

@Suite("SRPath Error Tests")
struct SRPathErrorTests {
    
    @Test("Invalid path format throws error")
    func testInvalidPathFormat() {
        #expect(throws: SRPathError.self) {
            _ = try SRPath(pathString: "/Finding[invalid]")
        }
    }
    
    @Test("Path not found returns nil")
    func testPathNotFoundReturnsNil() throws {
        let container = ContainerContentItem(contentItems: [])
        let path = try SRPath(pathString: "/NonExistent")
        
        let item = container.item(at: path)
        #expect(item == nil)
    }
    
    @Test("Index out of bounds returns nil")
    func testIndexOutOfBoundsReturnsNil() throws {
        let container = ContainerContentItem(
            contentItems: [
                AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(codeValue: "F", codingSchemeDesignator: "TEST", codeMeaning: "Finding"),
                    textValue: "Only one"
                ))
            ]
        )
        
        let path = try SRPath(pathString: "/Finding[5]")
        let item = container.item(at: path)
        #expect(item == nil)
    }
}

// MARK: - Complex Tree Navigation Tests

@Suite("Complex Tree Navigation Tests")
struct ComplexTreeNavigationTests {
    
    /// Creates a realistic SR document structure for testing
    private func createRealisticDocument() -> SRDocument {
        let patientConcept = CodedConcept(codeValue: "121029", codingSchemeDesignator: "DCM", codeMeaning: "Subject")
        let findingConcept = CodedConcept(codeValue: "121071", codingSchemeDesignator: "DCM", codeMeaning: "Finding")
        let measurementConcept = CodedConcept(codeValue: "125007", codingSchemeDesignator: "DCM", codeMeaning: "Measurement")
        let volumeConcept = CodedConcept(codeValue: "118565006", codingSchemeDesignator: "SCT", codeMeaning: "Volume")
        let diameterConcept = CodedConcept(codeValue: "81827009", codingSchemeDesignator: "SCT", codeMeaning: "Diameter")
        
        // Create measurement groups for two findings
        let finding1Measurements = ContainerContentItem(
            conceptName: measurementConcept,
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: volumeConcept, value: 125.0, relationshipType: .contains)),
                AnyContentItem(NumericContentItem(conceptName: diameterConcept, value: 5.5, relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        let finding2Measurements = ContainerContentItem(
            conceptName: measurementConcept,
            contentItems: [
                AnyContentItem(NumericContentItem(conceptName: volumeConcept, value: 75.0, relationshipType: .contains)),
                AnyContentItem(NumericContentItem(conceptName: diameterConcept, value: 3.2, relationshipType: .contains))
            ],
            relationshipType: .contains
        )
        
        // Create findings
        let finding1 = ContainerContentItem(
            conceptName: findingConcept,
            contentItems: [
                AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(codeValue: "121073", codingSchemeDesignator: "DCM", codeMeaning: "Impression"),
                    textValue: "Mass in right upper lobe",
                    relationshipType: .contains
                )),
                AnyContentItem(finding1Measurements)
            ],
            relationshipType: .contains
        )
        
        let finding2 = ContainerContentItem(
            conceptName: findingConcept,
            contentItems: [
                AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(codeValue: "121073", codingSchemeDesignator: "DCM", codeMeaning: "Impression"),
                    textValue: "Nodule in left lower lobe",
                    relationshipType: .contains
                )),
                AnyContentItem(finding2Measurements)
            ],
            relationshipType: .contains
        )
        
        // Create root
        let rootContent = ContainerContentItem(
            conceptName: CodedConcept(codeValue: "126000", codingSchemeDesignator: "DCM", codeMeaning: "Imaging Report"),
            contentItems: [
                AnyContentItem(PersonNameContentItem(
                    conceptName: patientConcept,
                    personName: "Doe^John",
                    relationshipType: .hasObsContext
                )),
                AnyContentItem(finding1),
                AnyContentItem(finding2)
            ]
        )
        
        return SRDocument(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.33",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            patientName: "Doe^John",
            documentTitle: CodedConcept(codeValue: "126000", codingSchemeDesignator: "DCM", codeMeaning: "Imaging Report"),
            rootContent: rootContent
        )
    }
    
    @Test("Navigate complex document by path")
    func testNavigateComplexDocumentByPath() throws {
        let document = createRealisticDocument()
        
        // Navigate to the first finding's volume measurement
        let path = try SRPath(pathString: "/Finding[0]/Measurement/Volume")
        let item = document.item(at: path)
        
        #expect(item?.asNumeric?.value == 125.0)
    }
    
    @Test("Navigate to second finding")
    func testNavigateToSecondFinding() throws {
        let document = createRealisticDocument()
        
        let path = try SRPath(pathString: "/Finding[1]/Measurement/Diameter")
        let item = document.item(at: path)
        
        #expect(item?.asNumeric?.value == 3.2)
    }
    
    @Test("Find all findings")
    func testFindAllFindings() {
        let document = createRealisticDocument()
        let findingConcept = CodedConcept(codeValue: "121071", codingSchemeDesignator: "DCM", codeMeaning: "Finding")
        
        let findings = document.findItems(byConceptName: findingConcept)
        #expect(findings.count == 2)
    }
    
    @Test("Find all volume measurements")
    func testFindAllVolumeMeasurements() {
        let document = createRealisticDocument()
        
        let volumes = document.findMeasurements(forConceptString: "Volume")
        #expect(volumes.count == 2)
        
        let totalVolume = volumes.compactMap { $0.value }.reduce(0, +)
        #expect(totalVolume == 200.0) // 125 + 75
    }
    
    @Test("Find observation context")
    func testFindObservationContext() {
        let document = createRealisticDocument()
        
        let contextItems = document.observationContextItems
        #expect(contextItems.count == 1)
        #expect(contextItems[0].asPersonName?.personName == "Doe^John")
    }
    
    @Test("Depth-first traversal of complex document")
    func testDepthFirstTraversalOfComplexDocument() {
        let document = createRealisticDocument()
        
        // Count all items
        let allItems = Array(document.contentTreeSequence(order: .depthFirst))
        
        // Subject(PN), Finding1(Container), Impression1(Text), Measurement1(Container), 
        // Volume1(Num), Diameter1(Num), Finding2(Container), Impression2(Text),
        // Measurement2(Container), Volume2(Num), Diameter2(Num) = 11 items
        #expect(allItems.count == 11)
    }
    
    @Test("Breadth-first traversal of complex document")
    func testBreadthFirstTraversalOfComplexDocument() {
        let document = createRealisticDocument()
        let items = Array(document.contentTreeSequence(order: .breadthFirst))
        
        // First level: Subject, Finding1, Finding2
        #expect(items[0].asPersonName != nil)
        #expect(items[1].asContainer != nil)
        #expect(items[2].asContainer != nil)
    }
    
    @Test("Find all measurement groups in complex document")
    func testFindMeasurementGroupsInComplexDocument() {
        let document = createRealisticDocument()
        
        let groups = document.findMeasurementGroups()
        #expect(groups.count == 2)
    }
}
