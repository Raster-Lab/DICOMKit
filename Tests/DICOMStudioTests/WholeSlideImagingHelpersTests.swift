// WholeSlideImagingHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Whole Slide Imaging Helpers Tests")
struct WholeSlideImagingHelpersTests {

    // MARK: - zoomLevelForMagnification

    @Test("zoomLevelForMagnification 40x maps to level 0")
    func testZoomLevelFor40x() {
        #expect(WholeSlideImagingHelpers.zoomLevelForMagnification(40.0) == 0)
    }

    @Test("zoomLevelForMagnification 20x maps to level 1")
    func testZoomLevelFor20x() {
        #expect(WholeSlideImagingHelpers.zoomLevelForMagnification(20.0) == 1)
    }

    @Test("zoomLevelForMagnification 10x maps to level 2")
    func testZoomLevelFor10x() {
        #expect(WholeSlideImagingHelpers.zoomLevelForMagnification(10.0) == 2)
    }

    @Test("zoomLevelForMagnification 5x maps to level 3")
    func testZoomLevelFor5x() {
        #expect(WholeSlideImagingHelpers.zoomLevelForMagnification(5.0) == 3)
    }

    // MARK: - magnificationForZoomLevel

    @Test("magnificationForZoomLevel level 0 returns 40.0")
    func testMagnificationForLevel0() {
        #expect(WholeSlideImagingHelpers.magnificationForZoomLevel(0) == 40.0)
    }

    @Test("magnificationForZoomLevel level 1 returns 20.0")
    func testMagnificationForLevel1() {
        #expect(WholeSlideImagingHelpers.magnificationForZoomLevel(1) == 20.0)
    }

    @Test("magnificationForZoomLevel level 2 returns 10.0")
    func testMagnificationForLevel2() {
        #expect(WholeSlideImagingHelpers.magnificationForZoomLevel(2) == 10.0)
    }

    // MARK: - tileKey

    @Test("tileKey returns expected format")
    func testTileKey() {
        let key = WholeSlideImagingHelpers.tileKey(level: 2, tileX: 3, tileY: 4)
        #expect(key == "2/3/4")
    }

    @Test("tileKey for level 0 tile 0,0")
    func testTileKeyOrigin() {
        let key = WholeSlideImagingHelpers.tileKey(level: 0, tileX: 0, tileY: 0)
        #expect(key == "0/0/0")
    }

    // MARK: - formatMagnification

    @Test("formatMagnification 40.0 returns 40x")
    func testFormatMagnification40() {
        #expect(WholeSlideImagingHelpers.formatMagnification(40.0) == "40x")
    }

    @Test("formatMagnification 2.5 returns 2.5x")
    func testFormatMagnification2_5() {
        #expect(WholeSlideImagingHelpers.formatMagnification(2.5) == "2.5x")
    }

    // MARK: - defaultOpticalPathColor

    @Test("defaultOpticalPathColor index 0 is white")
    func testDefaultOpticalPathColorIndex0() {
        #expect(WholeSlideImagingHelpers.defaultOpticalPathColor(index: 0) == .white)
    }

    @Test("defaultOpticalPathColor index 1 is red")
    func testDefaultOpticalPathColorIndex1() {
        #expect(WholeSlideImagingHelpers.defaultOpticalPathColor(index: 1) == .red)
    }

    @Test("defaultOpticalPathColor wraps at index 5")
    func testDefaultOpticalPathColorWraps() {
        let color0 = WholeSlideImagingHelpers.defaultOpticalPathColor(index: 0)
        let color5 = WholeSlideImagingHelpers.defaultOpticalPathColor(index: 5)
        #expect(color0 == color5)
    }

    // MARK: - tileCacheCapacity

    @Test("tileCacheCapacity returns positive result for 100MB limit")
    func testTileCacheCapacity() {
        let cap = WholeSlideImagingHelpers.tileCacheCapacity(
            for: 100, tileWidth: 256, tileHeight: 256)
        #expect(cap > 0)
    }

    @Test("tileCacheCapacity is correct for 1MB with 512x512 tiles")
    func testTileCacheCapacityCalculation() {
        // 1 MB / (512 * 512 * 4) = 1048576 / 1048576 = 1
        let cap = WholeSlideImagingHelpers.tileCacheCapacity(
            for: 1, tileWidth: 512, tileHeight: 512)
        #expect(cap == 1)
    }
}
