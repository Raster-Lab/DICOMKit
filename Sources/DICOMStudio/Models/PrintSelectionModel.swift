// PrintSelectionModel.swift
// DICOMStudio
//
// DICOM Studio — the set of images a user has marked for printing.
//
// Marks are frame-level (a cine loop can contribute one frame or all of them)
// and **ordered**: image box position on film follows this order, so the
// collection is an array, never a Set.

import Foundation
import Observation
import DICOMPrintKit

// MARK: - Selection Item

/// One marked frame destined for a film cell.
public struct PrintSelectionItem: Identifiable, Hashable, Sendable {
    /// Stable identity: a given frame of a given file can be marked only once.
    public var id: String { "\(filePath)#\(frameIndex)" }

    /// Path of the DICOM file the frame comes from.
    public let filePath: String

    /// SOP Instance UID, when known (used for display and job history).
    public let sopInstanceUID: String?

    /// 0-based frame index within the file.
    public let frameIndex: Int

    /// Total frames in the source, for display ("frame 3 of 60").
    public let frameCount: Int

    /// Series description, for the marks tray.
    public let seriesDescription: String?

    /// Instance number, for the marks tray.
    public let instanceNumber: Int?

    /// Window center captured from the viewer when the frame was marked.
    ///
    /// The film should look like the screen, so the viewer's presentation is
    /// carried with the mark rather than re-derived at print time.
    public let windowCenter: Double?

    /// Window width captured from the viewer when the frame was marked.
    public let windowWidth: Double?

    /// Zoom, pan, rotation, flip and inversion as the viewer was showing them.
    ///
    /// Carried so the film reproduces the arrangement the user built rather than
    /// the untouched frame. It is geometry over the source image, not a
    /// screenshot: the print path crops and permutes full-resolution pixels.
    public let presentation: ViewerPresentation?

    public init(
        filePath: String,
        sopInstanceUID: String? = nil,
        frameIndex: Int = 0,
        frameCount: Int = 1,
        seriesDescription: String? = nil,
        instanceNumber: Int? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        presentation: ViewerPresentation? = nil
    ) {
        self.filePath = filePath
        self.sopInstanceUID = sopInstanceUID
        self.frameIndex = frameIndex
        self.frameCount = frameCount
        self.seriesDescription = seriesDescription
        self.instanceNumber = instanceNumber
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.presentation = presentation
    }

    /// Label for the marks tray, e.g. "CHEST AXIAL · #14 · frame 3/60".
    public var displayLabel: String {
        var parts: [String] = []
        if let seriesDescription, !seriesDescription.isEmpty {
            parts.append(seriesDescription)
        } else {
            parts.append((filePath as NSString).lastPathComponent)
        }
        if let instanceNumber {
            parts.append("#\(instanceNumber)")
        }
        if frameCount > 1 {
            parts.append("frame \(frameIndex + 1)/\(frameCount)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Selection Model

/// The ordered list of frames marked for printing.
///
/// Shared by the viewer (which marks frames) and the print sheet (which turns
/// them into film cells). Order is significant and user-editable.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintSelectionModel {

    /// The marked frames, in film-cell order.
    public private(set) var items: [PrintSelectionItem] = []

    public init() {}

    // MARK: Queries

    /// Number of marked frames.
    public var count: Int { items.count }

    /// Whether anything is marked.
    public var isEmpty: Bool { items.isEmpty }

    /// Whether this exact frame is marked.
    public func contains(filePath: String, frameIndex: Int) -> Bool {
        items.contains { $0.filePath == filePath && $0.frameIndex == frameIndex }
    }

    /// Whether any frame of this file is marked.
    public func containsAnyFrame(ofFile filePath: String) -> Bool {
        items.contains { $0.filePath == filePath }
    }

    /// The 1-based position of a frame in the print order, or `nil` if unmarked.
    public func position(ofFilePath filePath: String, frameIndex: Int) -> Int? {
        items.firstIndex { $0.filePath == filePath && $0.frameIndex == frameIndex }
            .map { $0 + 1 }
    }

    // MARK: Mutations

    /// Adds a frame if it is not already marked. Returns `true` when added.
    @discardableResult
    public func add(_ item: PrintSelectionItem) -> Bool {
        guard !contains(filePath: item.filePath, frameIndex: item.frameIndex) else { return false }
        items.append(item)
        return true
    }

    /// Adds several frames, skipping any already marked. Returns the number added.
    @discardableResult
    public func add(contentsOf newItems: [PrintSelectionItem]) -> Int {
        newItems.reduce(0) { $0 + (add($1) ? 1 : 0) }
    }

    /// Removes a frame if marked.
    public func remove(filePath: String, frameIndex: Int) {
        items.removeAll { $0.filePath == filePath && $0.frameIndex == frameIndex }
    }

    /// Removes every marked frame of a file.
    public func removeAllFrames(ofFile filePath: String) {
        items.removeAll { $0.filePath == filePath }
    }

    /// Replaces a mark's payload in place, keeping its film position.
    ///
    /// Marking is a snapshot, but the snapshot has to keep up while the user is
    /// still arranging: zooming a tile after ticking it must change what prints,
    /// or the film silently disagrees with the screen. Returns `true` if a
    /// matching mark was found and updated.
    @discardableResult
    public func update(_ item: PrintSelectionItem) -> Bool {
        guard let index = items.firstIndex(where: {
            $0.filePath == item.filePath && $0.frameIndex == item.frameIndex
        }) else { return false }
        guard items[index] != item else { return false }
        items[index] = item
        return true
    }

    /// Marks the frame if unmarked, unmarks it otherwise. Returns the new state.
    @discardableResult
    public func toggle(_ item: PrintSelectionItem) -> Bool {
        if contains(filePath: item.filePath, frameIndex: item.frameIndex) {
            remove(filePath: item.filePath, frameIndex: item.frameIndex)
            return false
        }
        items.append(item)
        return true
    }

    /// Moves marks within the print order (drag-to-reorder in the marks tray).
    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    /// Moves one mark to a new 0-based position.
    public func move(from sourceIndex: Int, to destinationIndex: Int) {
        guard items.indices.contains(sourceIndex),
              destinationIndex >= 0, destinationIndex <= items.count,
              sourceIndex != destinationIndex else { return }
        let item = items.remove(at: sourceIndex)
        let clamped = min(destinationIndex, items.count)
        items.insert(item, at: clamped)
    }

    /// Removes marks at the given offsets (swipe/delete in the marks tray).
    public func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    /// Clears every mark.
    public func clear() {
        items.removeAll()
    }

    /// Replaces the entire selection (used by "print this series" entry points).
    public func replace(with newItems: [PrintSelectionItem]) {
        items = newItems
    }
}
