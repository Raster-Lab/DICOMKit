// ImageViewerViewModel+Print.swift
// DICOMStudio
//
// DICOM Studio — marking images in the viewer for a DICOM print job.
//
// The viewer owns the selection because marking is a viewing act: the user
// scrolls the series, decides what belongs on film, and marks it. The print
// sheet then consumes ``ImageViewerViewModel/printSelection`` in order.

import Foundation
import DICOMKit
import DICOMCore
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    // MARK: - Current frame

    /// A selection item describing the frame currently on screen.
    ///
    /// Carries the viewer's live window/level so the film matches what the user
    /// is looking at rather than the file's stored window.
    public var currentSelectionItem: PrintSelectionItem? {
        guard let filePath else { return nil }
        return PrintSelectionItem(
            filePath: filePath,
            sopInstanceUID: sopInstanceUID,
            frameIndex: currentFrameIndex,
            frameCount: numberOfFrames,
            seriesDescription: seriesDescriptionForPrint,
            instanceNumber: instanceNumberForPrint,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            presentation: currentPresentation
        )
    }

    /// The viewer's current arrangement of the frame on screen.
    ///
    /// Snapshotted at the moment of marking: the user marks what they are
    /// looking at, and later panning around the series must not retroactively
    /// change a film they already composed.
    public var currentPresentation: ViewerPresentation {
        ViewerPresentation(
            zoom: zoomLevel,
            panX: panOffsetX,
            panY: panOffsetY,
            viewportWidth: viewContentWidth,
            viewportHeight: viewContentHeight,
            rotationDegrees: rotationAngle,
            flipHorizontal: isFlippedHorizontal,
            flipVertical: isFlippedVertical,
            invert: isInverted
        )
    }

    /// Whether the frame currently on screen is marked for print.
    public var isCurrentFrameMarkedForPrint: Bool {
        guard let filePath else { return false }
        return printSelection.contains(filePath: filePath, frameIndex: currentFrameIndex)
    }

    /// The 1-based film position of the current frame, or `nil` if unmarked.
    public var currentFramePrintPosition: Int? {
        guard let filePath else { return nil }
        return printSelection.position(ofFilePath: filePath, frameIndex: currentFrameIndex)
    }

    // MARK: - Marking

    /// Marks or unmarks the frame currently on screen.
    @discardableResult
    public func togglePrintMarkForCurrentFrame() -> Bool {
        guard let item = currentSelectionItem else { return false }
        return printSelection.toggle(item)
    }

    /// Marks every frame of the currently loaded file, in frame order.
    ///
    /// The multi-frame counterpart of `--all-frames`: each frame becomes its own
    /// image box.
    @discardableResult
    public func markAllFramesOfCurrentFileForPrint() -> Int {
        guard let filePath else { return 0 }
        let presentation = currentPresentation
        let items = (0..<max(1, numberOfFrames)).map { frameIndex in
            PrintSelectionItem(
                filePath: filePath,
                sopInstanceUID: sopInstanceUID,
                frameIndex: frameIndex,
                frameCount: numberOfFrames,
                seriesDescription: seriesDescriptionForPrint,
                instanceNumber: instanceNumberForPrint,
                windowCenter: windowCenter,
                windowWidth: windowWidth,
                presentation: presentation
            )
        }
        return printSelection.add(contentsOf: items)
    }

    /// Marks the first frame of every file in the loaded series, in series order.
    ///
    /// Metadata beyond the current file is not loaded here — reading every file
    /// just to label the marks tray would stall the viewer — so entries for other
    /// files carry the file name and are labelled once they are opened.
    @discardableResult
    public func markWholeSeriesForPrint() -> Int {
        let paths = seriesFiles.isEmpty ? [filePath].compactMap { $0 } : seriesFiles
        let items = paths.map { path -> PrintSelectionItem in
            if path == filePath, let current = currentSelectionItem {
                return current
            }
            return PrintSelectionItem(filePath: path)
        }
        return printSelection.add(contentsOf: items)
    }

    // MARK: - Revisiting a mark

    /// Brings a marked image back on screen, in the focused tile.
    ///
    /// The tray is a list of what will be printed, and the reason to click one
    /// is to look at it again — usually to re-window it or to decide whether it
    /// belongs on the film at all. Loading through the series it belongs to
    /// rather than as a loose file keeps the arrow keys and the scroll wheel
    /// working from wherever the reader lands.
    public func showMarkedImage(_ item: PrintSelectionItem) {
        captureFocusedCell()

        if let index = seriesFiles.firstIndex(of: item.filePath) {
            if index != currentFileIndex || filePath != item.filePath {
                currentFileIndex = index
                loadFileInternal(at: item.filePath,
                                 securityScopedParent: seriesSecurityScopedParent)
            }
        } else if let entry = seriesEntry(containing: item.filePath),
                  let index = entry.filePaths.firstIndex(of: item.filePath) {
            loadSeries(files: entry.filePaths, startIndex: index,
                       securityScopedParent: seriesSecurityScopedParent)
            currentSeriesUID = entry.seriesInstanceUID
            visitedSeriesUIDs.insert(entry.seriesInstanceUID)
        } else if filePath != item.filePath {
            loadFile(at: item.filePath, securityScopedParent: seriesSecurityScopedParent)
        }

        // Multi-frame marks name a frame; it can only be applied once the file
        // has reported how many frames it has.
        if item.frameIndex != currentFrameIndex, item.frameIndex < numberOfFrames {
            goToFrame(item.frameIndex)
        }
    }

    /// Removes every mark belonging to the currently loaded file.
    public func clearPrintMarksForCurrentFile() {
        guard let filePath else { return }
        printSelection.removeAllFrames(ofFile: filePath)
    }

    /// Clears the whole print selection.
    public func clearAllPrintMarks() {
        printSelection.clear()
    }

    // MARK: - Metadata helpers

    /// Series Description (0008,103E) of the loaded file, if present.
    var seriesDescriptionForPrint: String? {
        guard let dataSet = dicomFile?.dataSet else { return nil }
        let value = dataSet.string(for: Tag(group: 0x0008, element: 0x103E))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    /// Instance Number (0020,0013) of the loaded file, if present.
    var instanceNumberForPrint: Int? {
        guard let dataSet = dicomFile?.dataSet,
              let value = dataSet.string(for: Tag(group: 0x0020, element: 0x0013))?
                  .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return Int(value)
    }
}
