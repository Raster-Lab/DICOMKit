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
public struct PrintSelectionItem: Identifiable, Hashable, Sendable, Codable {
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

    /// Series Instance UID, when the mark was made somewhere that knew it.
    ///
    /// Carried for grouping rather than display: synchronised cell editing has
    /// to know which cells came off the same series, and a description is not
    /// an identity — two series of one study are routinely described alike.
    public let seriesInstanceUID: String?

    /// Instance number, for the marks tray.
    public let instanceNumber: Int?

    /// Window center captured from the viewer when the frame was marked.
    ///
    /// The film should look like the screen, so the viewer's presentation is
    /// carried with the mark rather than re-derived at print time.
    public let windowCenter: Double?

    /// Window width captured from the viewer when the frame was marked.
    public let windowWidth: Double?

    /// Which space ``windowCenter`` / ``windowWidth`` are stated in.
    ///
    /// A mark's window normally comes off the viewer, which holds it in stored
    /// values — so that is the default. The exception is the print sheet's
    /// job-wide window, which a user types in output units (HU) and which
    /// ``PrintViewModel/previewItem(for:)`` folds into a mark so the preview
    /// shows the film's actual window. Carrying the space with the numbers is
    /// what stops the preview from rendering one as the other and washing the
    /// cell out. See ``PrintWindowSpace``.
    public let windowSpace: PrintWindowSpace

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
        seriesInstanceUID: String? = nil,
        instanceNumber: Int? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        windowSpace: PrintWindowSpace = .storedValues,
        presentation: ViewerPresentation? = nil
    ) {
        self.filePath = filePath
        self.sopInstanceUID = sopInstanceUID
        self.frameIndex = frameIndex
        self.frameCount = frameCount
        self.seriesDescription = seriesDescription
        self.seriesInstanceUID = seriesInstanceUID
        self.instanceNumber = instanceNumber
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.windowSpace = windowSpace
        self.presentation = presentation
    }

    /// A copy of this mark with its presentation fields replaced.
    ///
    /// The identity fields are left alone, so the copy still matches the mark it
    /// came from and takes its place on film. Each parameter is doubly optional
    /// because "leave this alone" and "clear this" are different edits: passing
    /// `.some(nil)` clears the value, omitting it keeps it.
    /// - Parameter windowSpace: The space a replaced window is stated in.
    ///   Defaults to the viewer's, which is where a mark's window comes from
    ///   everywhere except the job-wide override.
    public func with(
        windowCenter: Double?? = .none,
        windowWidth: Double?? = .none,
        windowSpace: PrintWindowSpace = .storedValues,
        presentation: ViewerPresentation?? = .none
    ) -> PrintSelectionItem {
        PrintSelectionItem(
            filePath: filePath,
            sopInstanceUID: sopInstanceUID,
            frameIndex: frameIndex,
            frameCount: frameCount,
            seriesDescription: seriesDescription,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            windowCenter: windowCenter ?? self.windowCenter,
            windowWidth: windowWidth ?? self.windowWidth,
            windowSpace: windowSpace,
            presentation: presentation ?? self.presentation
        )
    }

    /// What counts as "the same series" when grouping marks.
    ///
    /// The Series Instance UID when the mark carries one. Marks made without
    /// opening the file (a whole series marked from the library) carry neither
    /// UID nor description, so the containing folder stands in — the arrangement
    /// on disk is the only thing left that says these frames belong together,
    /// and grouping by it is closer to right than treating every such mark as
    /// its own series.
    public var seriesKey: String {
        if let seriesInstanceUID, !seriesInstanceUID.isEmpty { return seriesInstanceUID }
        if let seriesDescription, !seriesDescription.isEmpty { return "desc:" + seriesDescription }
        return "dir:" + (filePath as NSString).deletingLastPathComponent
    }

    /// The image identity this mark's annotations are shared under.
    public var annotationKey: ImageAnnotationKey {
        ImageAnnotationKey(filePath: filePath, frameIndex: frameIndex)
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

    /// Marks the user has adjusted by hand in the print preview.
    ///
    /// The viewer keeps marks in step with the screen (`refreshMarksFromViewer`),
    /// which is right until the user has deliberately windowed a film cell —
    /// re-syncing then throws that work away without saying so. A hand-adjusted
    /// mark stops following the viewer until it is reverted or reset.
    public private(set) var adjustedIDs: Set<String> = []

    /// Each adjusted mark as it stood before the first hand adjustment, so the
    /// edit can be taken back.
    private var preAdjustment: [String: PrintSelectionItem] = [:]

    // MARK: Drawn annotations

    /// The text and arrows drawn on each image, keyed by image identity rather
    /// than by mark: an image marked onto two film cells shows one shared set
    /// of annotations in both, and the main viewer can look annotations up by
    /// file path and frame index alone, without any notion of a film mark. See
    /// `PrintSelectionModel+Annotations.swift`.
    public var cellAnnotations: [ImageAnnotationKey: [PrintOverlayAnnotation]] = [:]

    /// The annotation the inspector is editing, if any.
    public var selectedAnnotationID: UUID?

    /// Size the next annotation is drawn at, as a fraction of the image's
    /// height. Changing a selected annotation's size adopts it here too.
    public var annotationScale: Double = PrintOverlayAnnotation.defaultScale

    /// Colour the next annotation is drawn in.
    public var annotationColor: PrintOverlayColor = .yellow

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
        pruneAdjustments()
    }

    /// Removes every marked frame of a file.
    public func removeAllFrames(ofFile filePath: String) {
        items.removeAll { $0.filePath == filePath }
        pruneAdjustments()
    }

    /// Replaces a mark's payload in place, keeping its film position.
    ///
    /// Marking is a snapshot, but the snapshot has to keep up while the user is
    /// still arranging: zooming a tile after ticking it must change what prints,
    /// or the film silently disagrees with the screen. Returns `true` if a
    /// matching mark was found and updated.
    ///
    /// A mark the user has adjusted by hand in the print preview is left alone —
    /// see ``adjustedIDs``. Pass `force: true` for edits that are themselves the
    /// user's (the preview's own tools), which is what ``adjust(_:)`` does.
    @discardableResult
    public func update(_ item: PrintSelectionItem, force: Bool = false) -> Bool {
        guard let index = items.firstIndex(where: {
            $0.filePath == item.filePath && $0.frameIndex == item.frameIndex
        }) else { return false }
        guard force || !adjustedIDs.contains(item.id) else { return false }
        guard items[index] != item else { return false }
        items[index] = item
        return true
    }

    /// Applies a hand adjustment made in the print preview.
    ///
    /// Records the mark as it stood first, so the edit can be reverted, and from
    /// here on the mark ignores viewer re-syncs.
    @discardableResult
    public func adjust(_ item: PrintSelectionItem) -> Bool {
        guard let index = items.firstIndex(where: {
            $0.filePath == item.filePath && $0.frameIndex == item.frameIndex
        }) else { return false }
        if preAdjustment[item.id] == nil {
            preAdjustment[item.id] = items[index]
        }
        adjustedIDs.insert(item.id)
        guard items[index] != item else { return false }
        items[index] = item
        return true
    }

    /// Whether a mark has been adjusted by hand.
    public func isAdjusted(_ id: String) -> Bool { adjustedIDs.contains(id) }

    /// The marks as they were made, with the print screen's hand adjustments
    /// left out — in the same film order as ``items``.
    ///
    /// Two readers of the same list want different things from it. The film and
    /// the printer want the mark as it now stands, hand adjustments included:
    /// that is the picture being sent. The viewer's tray wants the image as it
    /// was picked, because it answers "what have I put on the film?" and a tool
    /// used on the print screen is not an answer to that — it belongs to the
    /// film being composed, not to the selection. Rendering the live mark there
    /// made every windowing drag on the print screen flicker a tray row beside
    /// it.
    public var itemsAsMarked: [PrintSelectionItem] {
        guard !preAdjustment.isEmpty else { return items }
        return items.map { preAdjustment[$0.id] ?? $0 }
    }

    /// Takes back every hand adjustment to a mark, restoring it to how it was
    /// marked, and lets it follow the viewer again.
    @discardableResult
    public func revertAdjustments(forID id: String) -> Bool {
        guard let original = preAdjustment.removeValue(forKey: id) else { return false }
        adjustedIDs.remove(id)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index] = original
        return true
    }

    /// Forgets that a mark was adjusted, without restoring anything.
    ///
    /// Used by "reset cell", whose result — the untouched frame — is a state the
    /// viewer may legitimately overwrite again.
    public func clearAdjustment(forID id: String) {
        adjustedIDs.remove(id)
        preAdjustment.removeValue(forKey: id)
    }

    /// Takes back every hand adjustment, so all marks say what they said when
    /// they were marked and follow the viewer again.
    ///
    /// A hand adjustment defends a cell against ``refreshMarksFromViewer()`` for
    /// as long as that film is being composed, which is what it is for. It must
    /// not outlive the visit. The print screen is kept alive between openings, so
    /// without this the flag is permanent: window one cell in the preview, close
    /// the screen, then go on windowing, zooming and turning that image in the
    /// viewer, and reopening the screen shows none of it — the mark stopped
    /// listening on the first visit and never started again. Reopening the screen
    /// is opening it on what is ticked *now*, so the marks start following the
    /// screen again too.
    ///
    /// The values are restored, not merely unflagged. Clearing the flags alone
    /// looked equivalent — "the viewer's next re-sync overwrites them anyway" —
    /// but the re-sync only reaches marks that are *on screen*; every other
    /// mark kept the last visit's pans and zooms, and a film reopened after a
    /// cancelled visit still wore the edits the cancel appeared to discard.
    public func revertAllAdjustments() {
        for (id, original) in preAdjustment {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = original
            }
        }
        adjustedIDs.removeAll()
        preAdjustment.removeAll()
    }

    /// Drops adjustment bookkeeping for marks that are no longer selected.
    private func pruneAdjustments() {
        let live = Set(items.map(\.id))
        adjustedIDs.formIntersection(live)
        preAdjustment = preAdjustment.filter { live.contains($0.key) }
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
        pruneAdjustments()
    }

    /// Clears every mark.
    public func clear() {
        items.removeAll()
        pruneAdjustments()
    }

    /// Replaces the entire selection (used by "print this series" entry points).
    public func replace(with newItems: [PrintSelectionItem]) {
        items = newItems
        pruneAdjustments()
    }
}
