// MultiViewportViewModel.swift
// DICOMStudio
//
// DICOM Studio — Multi-viewport display ViewModel

import Foundation
import Observation

/// ViewModel for managing the multi-viewport display.
///
/// Coordinates synchronized scrolling, window/level, cross-reference lines,
/// and viewport-specific controls.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class MultiViewportViewModel {

    // MARK: - Viewport State

    /// All viewport states in the current layout.
    public var viewports: [ViewportState] = []

    /// Index of the active (focused) viewport.
    public var activeViewportIndex: Int = 0

    /// Synchronization mode for linked viewports.
    public var syncMode: ViewportSyncMode = .none

    /// Current active tool mode.
    public var toolMode: ViewportToolMode = .scroll

    // MARK: - Cross-Reference

    /// Cross-reference lines between viewports.
    public var crossReferenceLines: [CrossReferenceLine] = []

    /// Whether cross-reference lines are visible.
    public var showCrossReferenceLines: Bool = false

    // MARK: - Initialization

    /// Creates a multi-viewport ViewModel.
    public init() {
        viewports = [ViewportState(position: 0, isActive: true)]
    }

    // MARK: - Layout Management

    /// Sets up viewports for a given layout type.
    ///
    /// - Parameter layout: Layout type.
    public func setupLayout(_ layout: LayoutType) {
        viewports = ViewportLayoutHelpers.createViewportStates(
            for: layout,
            activeIndex: activeViewportIndex < layout.cellCount ? activeViewportIndex : 0
        )
        if activeViewportIndex >= viewports.count {
            activeViewportIndex = 0
        }
        updateActiveFlags()
        crossReferenceLines = []
    }

    /// Sets up viewports from a hanging protocol.
    ///
    /// - Parameter hangingProtocol: The hanging protocol.
    public func setupFromProtocol(_ hangingProtocol: HangingProtocolModel) {
        viewports = ViewportLayoutHelpers.createViewportStates(from: hangingProtocol)
        activeViewportIndex = viewports.firstIndex { $0.isActive } ?? 0
        updateActiveFlags()
        crossReferenceLines = []
    }

    // MARK: - Viewport Selection

    /// Sets the active viewport.
    ///
    /// - Parameter index: Viewport index to activate.
    public func setActiveViewport(_ index: Int) {
        guard index >= 0, index < viewports.count else { return }
        activeViewportIndex = index
        updateActiveFlags()
    }

    /// Cycles to the next viewport.
    public func nextViewport() {
        guard !viewports.isEmpty else { return }
        activeViewportIndex = (activeViewportIndex + 1) % viewports.count
        updateActiveFlags()
    }

    /// Cycles to the previous viewport.
    public func previousViewport() {
        guard !viewports.isEmpty else { return }
        activeViewportIndex = (activeViewportIndex - 1 + viewports.count) % viewports.count
        updateActiveFlags()
    }

    /// Returns the currently active viewport state.
    public var activeViewport: ViewportState? {
        guard activeViewportIndex >= 0, activeViewportIndex < viewports.count else { return nil }
        return viewports[activeViewportIndex]
    }

    // MARK: - Synchronized Scrolling

    /// Scrolls the active viewport and optionally syncs linked viewports.
    ///
    /// - Parameter delta: Frame index delta.
    public func scrollActiveViewport(delta: Int) {
        guard activeViewportIndex < viewports.count else { return }

        let currentFrame = viewports[activeViewportIndex].currentFrameIndex
        let totalFrames = viewports[activeViewportIndex].numberOfFrames
        let newFrame = max(0, min(totalFrames - 1, currentFrame + delta))
        viewports[activeViewportIndex].currentFrameIndex = newFrame

        if syncMode == .scroll || syncMode == .all {
            syncScrollToOtherViewports(fromIndex: activeViewportIndex, frameIndex: newFrame)
        }
    }

    /// Synchronizes scroll position from one viewport to others.
    private func syncScrollToOtherViewports(fromIndex: Int, frameIndex: Int) {
        for i in 0..<viewports.count where i != fromIndex {
            let total = viewports[i].numberOfFrames
            if total > 1 {
                // Proportional sync: map frame position relatively
                let sourceTotal = viewports[fromIndex].numberOfFrames
                let ratio = sourceTotal > 1 ? Double(frameIndex) / Double(sourceTotal - 1) : 0.0
                viewports[i].currentFrameIndex = max(0, min(total - 1, Int(ratio * Double(total - 1))))
            }
        }
    }

    // MARK: - Synchronized Window/Level

    /// Adjusts window/level for the active viewport and optionally syncs.
    ///
    /// - Parameters:
    ///   - center: New window center.
    ///   - width: New window width.
    public func setWindowLevel(center: Double, width: Double) {
        guard activeViewportIndex < viewports.count else { return }

        viewports[activeViewportIndex].windowCenter = center
        viewports[activeViewportIndex].windowWidth = width

        if syncMode == .windowLevel || syncMode == .all {
            syncWindowLevelToOtherViewports(fromIndex: activeViewportIndex, center: center, width: width)
        }
    }

    /// Synchronizes window/level from one viewport to others.
    private func syncWindowLevelToOtherViewports(fromIndex: Int, center: Double, width: Double) {
        for i in 0..<viewports.count where i != fromIndex {
            viewports[i].windowCenter = center
            viewports[i].windowWidth = width
        }
    }

    // MARK: - Viewport Properties

    /// Loads image metadata into a viewport.
    ///
    /// - Parameters:
    ///   - index: Viewport index.
    ///   - filePath: File path.
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - seriesInstanceUID: Series Instance UID.
    ///   - numberOfFrames: Total frames.
    public func loadIntoViewport(
        index: Int,
        filePath: String,
        sopInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        numberOfFrames: Int = 1
    ) {
        guard index >= 0, index < viewports.count else { return }
        viewports[index].filePath = filePath
        viewports[index].sopInstanceUID = sopInstanceUID
        viewports[index].seriesInstanceUID = seriesInstanceUID
        viewports[index].numberOfFrames = numberOfFrames
        viewports[index].currentFrameIndex = 0
    }

    /// Resets a viewport's view parameters (zoom, pan, rotation).
    ///
    /// - Parameter index: Viewport index.
    public func resetViewport(_ index: Int) {
        guard index >= 0, index < viewports.count else { return }
        viewports[index].zoomLevel = 1.0
        viewports[index].panOffsetX = 0.0
        viewports[index].panOffsetY = 0.0
        viewports[index].rotationAngle = 0.0
    }

    // MARK: - Tool Mode

    /// Sets the active tool mode.
    ///
    /// - Parameter mode: Tool mode.
    public func setToolMode(_ mode: ViewportToolMode) {
        toolMode = mode
    }

    // MARK: - Display Text

    /// Returns a formatted viewport info string.
    ///
    /// - Parameter index: Viewport index.
    /// - Returns: Formatted string.
    public func viewportInfoText(for index: Int) -> String {
        guard index >= 0, index < viewports.count else { return "" }
        let vp = viewports[index]
        if vp.hasImage {
            if vp.isMultiFrame {
                return "Frame \(vp.currentFrameIndex + 1)/\(vp.numberOfFrames)"
            }
            return "Loaded"
        }
        return "Empty"
    }

    /// Returns the sync mode label.
    public var syncModeLabel: String {
        switch syncMode {
        case .none: return "No Sync"
        case .scroll: return "Scroll Sync"
        case .windowLevel: return "W/L Sync"
        case .all: return "Full Sync"
        }
    }

    /// Returns the tool mode label.
    public var toolModeLabel: String {
        switch toolMode {
        case .scroll: return "Scroll"
        case .windowLevel: return "W/L"
        case .zoom: return "Zoom"
        case .pan: return "Pan"
        }
    }

    /// Number of viewports with loaded images.
    public var loadedViewportCount: Int {
        viewports.filter { $0.hasImage }.count
    }

    // MARK: - Private

    private func updateActiveFlags() {
        for i in 0..<viewports.count {
            viewports[i].isActive = (i == activeViewportIndex)
        }
    }
}
