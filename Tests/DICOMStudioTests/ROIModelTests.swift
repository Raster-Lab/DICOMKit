// ROIModelTests.swift
// DICOMStudioTests
//
// Tests for ROI models

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ROIType Tests")
struct ROITypeTests {

    @Test("All types have raw values")
    func testRawValues() {
        #expect(ROIType.elliptical.rawValue == "ELLIPTICAL")
        #expect(ROIType.rectangular.rawValue == "RECTANGULAR")
        #expect(ROIType.freehand.rawValue == "FREEHAND")
        #expect(ROIType.polygonal.rawValue == "POLYGONAL")
        #expect(ROIType.circular.rawValue == "CIRCULAR")
    }

    @Test("CaseIterable has 5 types")
    func testCaseIterable() {
        #expect(ROIType.allCases.count == 5)
    }
}

@Suite("ROIStatistics Tests")
struct ROIStatisticsTests {

    @Test("Empty statistics")
    func testEmpty() {
        let stats = ROIStatistics.empty
        #expect(stats.mean == 0)
        #expect(stats.standardDeviation == 0)
        #expect(stats.minimum == 0)
        #expect(stats.maximum == 0)
        #expect(stats.areaPixels == 0)
        #expect(stats.areaMM2 == nil)
        #expect(stats.perimeterPixels == 0)
        #expect(stats.perimeterMM == nil)
    }

    @Test("Full statistics")
    func testFullStats() {
        let stats = ROIStatistics(
            mean: 100.5,
            standardDeviation: 15.3,
            minimum: 50.0,
            maximum: 200.0,
            areaPixels: 1000,
            areaMM2: 250.0,
            perimeterPixels: 112.0,
            perimeterMM: 28.0
        )
        #expect(stats.mean == 100.5)
        #expect(stats.standardDeviation == 15.3)
        #expect(stats.minimum == 50.0)
        #expect(stats.maximum == 200.0)
        #expect(stats.areaPixels == 1000)
        #expect(stats.areaMM2 == 250.0)
        #expect(stats.perimeterPixels == 112.0)
        #expect(stats.perimeterMM == 28.0)
    }

    @Test("ROIStatistics is Equatable")
    func testEquatable() {
        let a = ROIStatistics(mean: 100, standardDeviation: 10, minimum: 50, maximum: 150)
        let b = ROIStatistics(mean: 100, standardDeviation: 10, minimum: 50, maximum: 150)
        #expect(a == b)
    }

    @Test("ROIStatistics is Hashable")
    func testHashable() {
        let stats = ROIStatistics(mean: 100, standardDeviation: 10)
        var set: Set<ROIStatistics> = []
        set.insert(stats)
        #expect(set.contains(stats))
    }
}

@Suite("ROIEntry Tests")
struct ROIEntryTests {

    @Test("Default creation")
    func testDefaults() {
        let entry = ROIEntry(
            roiType: .circular,
            points: [AnnotationPoint(x: 100, y: 100), AnnotationPoint(x: 150, y: 100)]
        )
        #expect(entry.roiType == .circular)
        #expect(entry.points.count == 2)
        #expect(entry.statistics == ROIStatistics.empty)
        #expect(entry.isVisible == true)
        #expect(entry.isLocked == false)
    }

    @Test("Identifiable with unique IDs")
    func testIdentifiable() {
        let a = ROIEntry(roiType: .circular, points: [])
        let b = ROIEntry(roiType: .circular, points: [])
        #expect(a.id != b.id)
    }

    @Test("withStatistics creates new entry")
    func testWithStatistics() {
        let entry = ROIEntry(roiType: .circular, points: [])
        let stats = ROIStatistics(mean: 100, standardDeviation: 10, minimum: 50, maximum: 150, areaPixels: 500)
        let updated = entry.withStatistics(stats)
        #expect(updated.statistics.mean == 100)
        #expect(updated.id == entry.id)
    }

    @Test("withVisibility creates new entry")
    func testWithVisibility() {
        let entry = ROIEntry(roiType: .rectangular, points: [])
        let hidden = entry.withVisibility(false)
        #expect(hidden.isVisible == false)
        #expect(hidden.id == entry.id)
    }

    @Test("withLocked creates new entry")
    func testWithLocked() {
        let entry = ROIEntry(roiType: .elliptical, points: [])
        let locked = entry.withLocked(true)
        #expect(locked.isLocked == true)
        #expect(locked.id == entry.id)
    }

    @Test("Equatable")
    func testEquatable() {
        let id = UUID()
        let date = Date()
        let a = ROIEntry(id: id, roiType: .circular, points: [], createdAt: date)
        let b = ROIEntry(id: id, roiType: .circular, points: [], createdAt: date)
        #expect(a == b)
    }
}
