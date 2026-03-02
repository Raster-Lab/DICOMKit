// SegmentationHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Segmentation Helpers Tests")
struct SegmentationHelpersTests {

    // MARK: - defaultColor

    @Test("defaultColor returns red for segment 1")
    func testDefaultColorSegment1() {
        #expect(SegmentationHelpers.defaultColor(for: 1) == .red)
    }

    @Test("defaultColor returns blue for segment 2")
    func testDefaultColorSegment2() {
        #expect(SegmentationHelpers.defaultColor(for: 2) == .blue)
    }

    @Test("defaultColor wraps around for segment 9")
    func testDefaultColorWrapsAround() {
        let color1 = SegmentationHelpers.defaultColor(for: 1)
        let color9 = SegmentationHelpers.defaultColor(for: 9)
        #expect(color1 == color9)
    }

    @Test("defaultColor returns 8 distinct values in first cycle")
    func testDefaultColorDistinctInFirstCycle() {
        let colors = (1...8).map { SegmentationHelpers.defaultColor(for: $0) }
        let unique = Set(colors)
        #expect(unique.count == 8)
    }

    // MARK: - sfSymbolForAlgorithmType

    @Test("sfSymbolForAlgorithmType returns hand.draw for manual")
    func testSFSymbolManual() {
        #expect(SegmentationHelpers.sfSymbolForAlgorithmType(.manual) == "hand.draw")
    }

    @Test("sfSymbolForAlgorithmType returns cpu for automatic")
    func testSFSymbolAutomatic() {
        #expect(SegmentationHelpers.sfSymbolForAlgorithmType(.automatic) == "cpu")
    }

    @Test("sfSymbolForAlgorithmType returns non-empty for all types")
    func testSFSymbolNonEmptyForAllTypes() {
        for type in SegmentAlgorithmType.allCases {
            #expect(!SegmentationHelpers.sfSymbolForAlgorithmType(type).isEmpty)
        }
    }

    // MARK: - overlayDescription

    @Test("overlayDescription contains label")
    func testOverlayDescriptionContainsLabel() {
        let overlay = SegmentOverlay(segmentNumber: 1, label: "Liver", algorithmType: .manual,
                                     color: .red)
        let desc = SegmentationHelpers.overlayDescription(for: overlay)
        #expect(desc.contains("Liver"))
    }

    @Test("overlayDescription contains algorithm display name")
    func testOverlayDescriptionContainsAlgorithmName() {
        let overlay = SegmentOverlay(segmentNumber: 1, label: "Liver", algorithmType: .automatic,
                                     color: .red)
        let desc = SegmentationHelpers.overlayDescription(for: overlay)
        #expect(desc.contains(SegmentAlgorithmType.automatic.displayName))
    }

    // MARK: - visibleSegmentCount

    @Test("visibleSegmentCount counts only visible overlays")
    func testVisibleSegmentCount() {
        let overlays = [
            SegmentOverlay(segmentNumber: 1, label: "A", algorithmType: .manual,
                           color: .red, isVisible: true),
            SegmentOverlay(segmentNumber: 2, label: "B", algorithmType: .manual,
                           color: .blue, isVisible: false),
            SegmentOverlay(segmentNumber: 3, label: "C", algorithmType: .manual,
                           color: .green, isVisible: true),
        ]
        let state = SegmentOverlayState(overlays: overlays)
        #expect(SegmentationHelpers.visibleSegmentCount(in: state) == 2)
    }

    @Test("visibleSegmentCount returns zero for empty state")
    func testVisibleSegmentCountEmpty() {
        let state = SegmentOverlayState(overlays: [])
        #expect(SegmentationHelpers.visibleSegmentCount(in: state) == 0)
    }

    // MARK: - buildOverlays

    @Test("buildOverlays creates correct number of overlays")
    func testBuildOverlaysCount() {
        let overlays = SegmentationHelpers.buildOverlays(segmentCount: 5)
        #expect(overlays.count == 5)
    }

    @Test("buildOverlays labels contain Segment prefix")
    func testBuildOverlaysLabels() {
        let overlays = SegmentationHelpers.buildOverlays(segmentCount: 3)
        for overlay in overlays {
            #expect(overlay.label.contains("Segment"))
        }
    }

    @Test("buildOverlays segment numbers start at 1")
    func testBuildOverlaysSegmentNumbers() {
        let overlays = SegmentationHelpers.buildOverlays(segmentCount: 3)
        #expect(overlays.first?.segmentNumber == 1)
        #expect(overlays.last?.segmentNumber == 3)
    }

    // MARK: - alphaBlend

    @Test("alphaBlend with opacity 0 returns base color")
    func testAlphaBlendZeroOpacity() {
        let result = SegmentationHelpers.alphaBlend(base: .red, overlay: .blue, opacity: 0.0)
        #expect(abs(result.red - RTColor.red.red) < 0.01)
        #expect(abs(result.blue - RTColor.red.blue) < 0.01)
    }

    @Test("alphaBlend with opacity 1 returns overlay color")
    func testAlphaBlendFullOpacity() {
        let result = SegmentationHelpers.alphaBlend(base: .red, overlay: .blue, opacity: 1.0)
        #expect(result.blue > 0.9)
    }

    @Test("alphaBlend result channels are within 0 to 1")
    func testAlphaBlendChannelRange() {
        let result = SegmentationHelpers.alphaBlend(base: .white, overlay: .red, opacity: 0.5)
        #expect(result.red >= 0.0 && result.red <= 1.0)
        #expect(result.green >= 0.0 && result.green <= 1.0)
        #expect(result.blue >= 0.0 && result.blue <= 1.0)
    }
}
