//
// ImageSetDefinitionTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class ImageSetDefinitionTests: XCTestCase {
    
    // MARK: - ImageSetDefinition Tests
    
    func test_imageSetDefinition_initialization_withRequiredParameters() {
        let imageSet = ImageSetDefinition(number: 1)
        
        XCTAssertEqual(imageSet.number, 1)
        XCTAssertNil(imageSet.label)
        XCTAssertEqual(imageSet.selectors.count, 0)
        XCTAssertEqual(imageSet.sortOperations.count, 0)
        XCTAssertNil(imageSet.category)
        XCTAssertNil(imageSet.timeSelection)
    }
    
    func test_imageSetDefinition_initialization_withAllParameters() {
        let selector = ImageSetSelector(attribute: .modality, values: ["CT"])
        let sortOp = SortOperation(sortByCategory: .instanceNumber)
        let timeSelection = TimeBasedSelection(relativeTime: 30, relativeTimeUnits: .days)
        
        let imageSet = ImageSetDefinition(
            number: 1,
            label: "Current Study",
            selectors: [selector],
            sortOperations: [sortOp],
            category: .current,
            timeSelection: timeSelection
        )
        
        XCTAssertEqual(imageSet.number, 1)
        XCTAssertEqual(imageSet.label, "Current Study")
        XCTAssertEqual(imageSet.selectors.count, 1)
        XCTAssertEqual(imageSet.sortOperations.count, 1)
        XCTAssertEqual(imageSet.category, .current)
        XCTAssertNotNil(imageSet.timeSelection)
    }
    
    func test_imageSetDefinition_multipleSelectors() {
        let selector1 = ImageSetSelector(attribute: .modality, values: ["CT"])
        let selector2 = ImageSetSelector(attribute: .seriesDescription, values: ["CHEST"])
        
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector1, selector2])
        
        XCTAssertEqual(imageSet.selectors.count, 2)
    }
    
    func test_imageSetDefinition_multipleSortOperations() {
        let sort1 = SortOperation(sortByCategory: .acquisitionTime)
        let sort2 = SortOperation(sortByCategory: .instanceNumber)
        
        let imageSet = ImageSetDefinition(number: 1, sortOperations: [sort1, sort2])
        
        XCTAssertEqual(imageSet.sortOperations.count, 2)
    }
    
    // MARK: - ImageSetSelector Tests
    
    func test_imageSetSelector_initialization_withMinimalParameters() {
        let selector = ImageSetSelector(attribute: .modality, values: ["CT"])
        
        XCTAssertEqual(selector.attribute, .modality)
        XCTAssertNil(selector.valueNumber)
        XCTAssertNil(selector.operator)
        XCTAssertEqual(selector.values, ["CT"])
        XCTAssertEqual(selector.usageFlag, .match)
    }
    
    func test_imageSetSelector_initialization_withAllParameters() {
        let selector = ImageSetSelector(
            attribute: .seriesDescription,
            valueNumber: 1,
            operator: .contains,
            values: ["CHEST", "THORAX"],
            usageFlag: .match
        )
        
        XCTAssertEqual(selector.attribute, .seriesDescription)
        XCTAssertEqual(selector.valueNumber, 1)
        XCTAssertEqual(selector.operator, .contains)
        XCTAssertEqual(selector.values.count, 2)
        XCTAssertEqual(selector.usageFlag, .match)
    }
    
    func test_imageSetSelector_noMatchFlag() {
        let selector = ImageSetSelector(
            attribute: .modality,
            values: ["DX"],
            usageFlag: .noMatch
        )
        
        XCTAssertEqual(selector.usageFlag, .noMatch, "Should exclude matching images")
    }
    
    func test_imageSetSelector_multipleValues() {
        let selector = ImageSetSelector(
            attribute: .modality,
            values: ["CT", "MR", "CR"]
        )
        
        XCTAssertEqual(selector.values.count, 3, "Should support multiple values")
        XCTAssertTrue(selector.values.contains("CT"))
        XCTAssertTrue(selector.values.contains("MR"))
        XCTAssertTrue(selector.values.contains("CR"))
    }
    
    // MARK: - SelectorUsageFlag Tests
    
    func test_selectorUsageFlag_rawValues() {
        XCTAssertEqual(SelectorUsageFlag.match.rawValue, "MATCH")
        XCTAssertEqual(SelectorUsageFlag.noMatch.rawValue, "NO_MATCH")
    }
    
    func test_selectorUsageFlag_fromString() {
        XCTAssertEqual(SelectorUsageFlag(rawValue: "MATCH"), .match)
        XCTAssertEqual(SelectorUsageFlag(rawValue: "NO_MATCH"), .noMatch)
        XCTAssertNil(SelectorUsageFlag(rawValue: "INVALID"))
    }
    
    // MARK: - FilterOperator Tests
    
    func test_filterOperator_allValues() {
        XCTAssertEqual(FilterOperator.equal.rawValue, "EQUAL")
        XCTAssertEqual(FilterOperator.notEqual.rawValue, "NOT_EQUAL")
        XCTAssertEqual(FilterOperator.lessThan.rawValue, "LESS_THAN")
        XCTAssertEqual(FilterOperator.lessThanOrEqual.rawValue, "LESS_THAN_OR_EQUAL")
        XCTAssertEqual(FilterOperator.greaterThan.rawValue, "GREATER_THAN")
        XCTAssertEqual(FilterOperator.greaterThanOrEqual.rawValue, "GREATER_THAN_OR_EQUAL")
        XCTAssertEqual(FilterOperator.contains.rawValue, "CONTAINS")
        XCTAssertEqual(FilterOperator.present.rawValue, "PRESENT")
        XCTAssertEqual(FilterOperator.notPresent.rawValue, "NOT_PRESENT")
    }
    
    func test_filterOperator_comparison() {
        let operators: [FilterOperator] = [
            .equal, .notEqual, .lessThan, .lessThanOrEqual,
            .greaterThan, .greaterThanOrEqual
        ]
        
        XCTAssertEqual(operators.count, 6, "Should have 6 comparison operators")
    }
    
    func test_filterOperator_presence() {
        let operators: [FilterOperator] = [.present, .notPresent]
        
        XCTAssertEqual(operators.count, 2, "Should have 2 presence operators")
    }
    
    // MARK: - ImageSetSelectorCategory Tests
    
    func test_imageSetSelectorCategory_rawValues() {
        XCTAssertEqual(ImageSetSelectorCategory.current.rawValue, "CURRENT")
        XCTAssertEqual(ImageSetSelectorCategory.prior.rawValue, "PRIOR")
        XCTAssertEqual(ImageSetSelectorCategory.comparison.rawValue, "COMPARISON")
    }
    
    func test_imageSetSelectorCategory_fromString() {
        XCTAssertEqual(ImageSetSelectorCategory(rawValue: "CURRENT"), .current)
        XCTAssertEqual(ImageSetSelectorCategory(rawValue: "PRIOR"), .prior)
        XCTAssertEqual(ImageSetSelectorCategory(rawValue: "COMPARISON"), .comparison)
        XCTAssertNil(ImageSetSelectorCategory(rawValue: "INVALID"))
    }
    
    // MARK: - TimeBasedSelection Tests
    
    func test_timeBasedSelection_initialization_empty() {
        let selection = TimeBasedSelection()
        
        XCTAssertNil(selection.relativeTime)
        XCTAssertNil(selection.relativeTimeUnits)
        XCTAssertNil(selection.abstractPriorValue)
    }
    
    func test_timeBasedSelection_relativeTime_days() {
        let selection = TimeBasedSelection(relativeTime: 30, relativeTimeUnits: .days)
        
        XCTAssertEqual(selection.relativeTime, 30)
        XCTAssertEqual(selection.relativeTimeUnits, .days)
        XCTAssertNil(selection.abstractPriorValue)
    }
    
    func test_timeBasedSelection_relativeTime_months() {
        let selection = TimeBasedSelection(relativeTime: 6, relativeTimeUnits: .months)
        
        XCTAssertEqual(selection.relativeTime, 6)
        XCTAssertEqual(selection.relativeTimeUnits, .months)
    }
    
    func test_timeBasedSelection_abstractPriorValue() {
        let selection = TimeBasedSelection(abstractPriorValue: "MOST_RECENT")
        
        XCTAssertNil(selection.relativeTime)
        XCTAssertEqual(selection.abstractPriorValue, "MOST_RECENT")
    }
    
    // MARK: - RelativeTimeUnits Tests
    
    func test_relativeTimeUnits_allValues() {
        XCTAssertEqual(RelativeTimeUnits.seconds.rawValue, "SECONDS")
        XCTAssertEqual(RelativeTimeUnits.minutes.rawValue, "MINUTES")
        XCTAssertEqual(RelativeTimeUnits.hours.rawValue, "HOURS")
        XCTAssertEqual(RelativeTimeUnits.days.rawValue, "DAYS")
        XCTAssertEqual(RelativeTimeUnits.weeks.rawValue, "WEEKS")
        XCTAssertEqual(RelativeTimeUnits.months.rawValue, "MONTHS")
        XCTAssertEqual(RelativeTimeUnits.years.rawValue, "YEARS")
    }
    
    func test_relativeTimeUnits_fromString() {
        XCTAssertEqual(RelativeTimeUnits(rawValue: "DAYS"), .days)
        XCTAssertEqual(RelativeTimeUnits(rawValue: "MONTHS"), .months)
        XCTAssertEqual(RelativeTimeUnits(rawValue: "YEARS"), .years)
        XCTAssertNil(RelativeTimeUnits(rawValue: "INVALID"))
    }
    
    // MARK: - SortOperation Tests
    
    func test_sortOperation_initialization_withCategory() {
        let sort = SortOperation(sortByCategory: .instanceNumber)
        
        XCTAssertEqual(sort.sortByCategory, .instanceNumber)
        XCTAssertEqual(sort.direction, .ascending)
        XCTAssertNil(sort.attribute)
    }
    
    func test_sortOperation_initialization_withDirection() {
        let sort = SortOperation(sortByCategory: .acquisitionTime, direction: .descending)
        
        XCTAssertEqual(sort.sortByCategory, .acquisitionTime)
        XCTAssertEqual(sort.direction, .descending)
    }
    
    func test_sortOperation_initialization_withAttribute() {
        let sort = SortOperation(
            sortByCategory: .attribute,
            direction: .ascending,
            attribute: .sliceLocation
        )
        
        XCTAssertEqual(sort.sortByCategory, .attribute)
        XCTAssertEqual(sort.direction, .ascending)
        XCTAssertEqual(sort.attribute, .sliceLocation)
    }
    
    // MARK: - SortByCategory Tests
    
    func test_sortByCategory_allValues() {
        XCTAssertEqual(SortByCategory.instanceNumber.rawValue, "INSTANCE_NUMBER")
        XCTAssertEqual(SortByCategory.acquisitionTime.rawValue, "ACQUISITION_TIME")
        XCTAssertEqual(SortByCategory.imagePosition.rawValue, "IMAGE_POSITION")
        XCTAssertEqual(SortByCategory.sliceLocation.rawValue, "SLICE_LOCATION")
        XCTAssertEqual(SortByCategory.attribute.rawValue, "ATTRIBUTE")
    }
    
    func test_sortByCategory_fromString() {
        XCTAssertEqual(SortByCategory(rawValue: "INSTANCE_NUMBER"), .instanceNumber)
        XCTAssertEqual(SortByCategory(rawValue: "ACQUISITION_TIME"), .acquisitionTime)
        XCTAssertEqual(SortByCategory(rawValue: "IMAGE_POSITION"), .imagePosition)
        XCTAssertNil(SortByCategory(rawValue: "INVALID"))
    }
    
    // MARK: - SortDirection Tests
    
    func test_sortDirection_rawValues() {
        XCTAssertEqual(SortDirection.ascending.rawValue, "ASCENDING")
        XCTAssertEqual(SortDirection.descending.rawValue, "DESCENDING")
    }
    
    func test_sortDirection_fromString() {
        XCTAssertEqual(SortDirection(rawValue: "ASCENDING"), .ascending)
        XCTAssertEqual(SortDirection(rawValue: "DESCENDING"), .descending)
        XCTAssertNil(SortDirection(rawValue: "INVALID"))
    }
}
