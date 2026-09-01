// PrintViewModel+ImageRange.swift
// DICOMStudio
//
// DICOM Studio — printing a run of each series rather than all of it.
//
// A CT of two hundred slices marked onto 4×5 films is fourteen sheets, and the
// reader wants four of them: images 60 to 140, say, where the finding is. Taking
// the other hundred and twenty off the film by hand is not work anyone should do
// with a mouse.
//
// So the range is a *filter*, not an edit. The marks stay exactly as they are —
// with whatever windowing and arrangement has been done to them — and the films
// are laid out from what falls inside it. Widening the range brings the images
// straight back, and "Load All" is one click rather than a re-mark of a series.
// Nothing is destroyed by narrowing a view, which is the property that makes it
// safe to fiddle with.
//
// The number is the image's own — Instance Number, the one printed in the cell's
// corner and the one a reader quotes. A mark whose header never recorded one
// falls back to its place among *its own series'* marks, so the control still
// works on a selection assembled by hand.
//
// Image numbers restart at 1 in every series, so the film does not carry one
// range: it carries one range per marked series, keyed by
// ``PrintSelectionItem/seriesKey``. "60 to 140" on the axial series and "1 to
// 30" on the scout are two separate statements, and a series nobody has
// narrowed prints whole.

import Foundation
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    // MARK: - What the film is laid out from

    /// The marks the films actually carry, in film-cell order.
    ///
    /// Everything downstream reads this rather than `selection.items`: the plan
    /// that counts the films, the preview that draws them, and the print run
    /// that sends them. One filter, applied once, so a preview cannot show a
    /// range the printer does not receive.
    public var printedItems: [PrintSelectionItem] {
        guard !imageRanges.isEmpty else { return selection.items }
        // Ordinal fallbacks count within each series, because that is the
        // position the range's numbers restart from.
        var ordinals: [String: Int] = [:]
        return selection.items.filter { item in
            let key = item.seriesKey
            let ordinal = (ordinals[key] ?? 0) + 1
            ordinals[key] = ordinal
            guard let range = imageRanges[key] else { return true }
            return range.contains(imageNumber(of: item, ordinal: ordinal))
        }
    }

    /// Whether any series' range is narrowing the film at all.
    ///
    /// A range covering everything is not active: it prints the same film as no
    /// range, and a control claiming to be filtering when it is not is a control
    /// that gets switched off in confusion.
    public var isImageRangeActive: Bool {
        markedSeriesRanges.contains { isImageRangeActive(forSeries: $0.key) }
    }

    /// Whether this series' range is narrowing its run.
    public func isImageRangeActive(forSeries key: String) -> Bool {
        guard let range = imageRanges[key],
              let bounds = imageNumberBounds(forSeries: key) else { return false }
        return range.lowerBound > bounds.lowerBound || range.upperBound < bounds.upperBound
    }

    /// The range in force for a series, or `nil` when it prints whole.
    public func imageRange(forSeries key: String) -> ClosedRange<Int>? {
        imageRanges[key]
    }

    /// The number this mark is filtered by: the image's own Instance Number.
    ///
    /// From the mark when it carries one — a frame marked from the open viewer
    /// does — and otherwise from the file itself, read once and kept by
    /// ``imageNumbers``. Marking a whole series records paths without reading
    /// two hundred headers, so most marks arrive without a number and the file
    /// is where the answer is.
    ///
    /// The ordinal is the last resort, for a file that records no Instance
    /// Number at all. It is deliberately last: the mark's *position among its
    /// series' marks* equals its image number only when the series was marked
    /// whole, from image one, with nothing skipped — and silently filtering by
    /// position when the reader asked for image numbers is how "3 to 9" prints
    /// something else.
    public func imageNumber(of item: PrintSelectionItem, ordinal: Int) -> Int {
        item.instanceNumber ?? imageNumbers.number(forPath: item.filePath) ?? ordinal
    }

    /// Reads the image numbers of every marked file, if they are not known yet.
    ///
    /// Called when the range control is opened rather than when the screen is:
    /// it is a header read per marked file, and a reader who never touches the
    /// range should never pay for it.
    public func loadImageNumbers() async {
        await imageNumbers.load(paths: Array(Set(selection.items.map(\.filePath))))
        clampImageRange()
    }

    /// Whether every marked file's number is known, so the control can say what
    /// it is filtering by rather than guessing.
    public var hasImageNumbers: Bool {
        selection.items.allSatisfy {
            $0.instanceNumber != nil || imageNumbers.number(forPath: $0.filePath) != nil
        }
    }

    // MARK: - What the control offers

    /// One marked series as the range control sees it: identity, a label for
    /// its row, and the run of numbers actually marked.
    public struct MarkedSeriesRange: Identifiable, Equatable, Sendable {
        /// ``PrintSelectionItem/seriesKey`` — what the range is stored under.
        public let key: String

        /// What the row calls the series: its description, or the file's
        /// folder when the marks never carried one.
        public let label: String

        /// How many marks the series contributes to the film.
        public let imageCount: Int

        /// The lowest and highest image number among this series' marks —
        /// what its range fields are bounded by, and what "all of them" means.
        public let bounds: ClosedRange<Int>

        public var id: String { key }
    }

    /// The marked series in film order, one entry per series.
    ///
    /// The range control offers one row per entry; a selection of one series
    /// gets one row, which is the old single-series control exactly.
    public var markedSeriesRanges: [MarkedSeriesRange] {
        var order: [String] = []
        var grouped: [String: [PrintSelectionItem]] = [:]
        for item in selection.items {
            let key = item.seriesKey
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(item)
        }
        return order.compactMap { key in
            guard let items = grouped[key] else { return nil }
            let numbers = items.enumerated().map { imageNumber(of: $0.element, ordinal: $0.offset + 1) }
            guard let low = numbers.min(), let high = numbers.max() else { return nil }
            // The row is named by the series' description: from the mark when
            // it carries one, else from the header read that already fetched
            // the image numbers. The containing folder is the last resort —
            // and in an export that folder is routinely the Series Instance
            // UID, which is an identity, not a name.
            let label: String
            if let description = items.first?.seriesDescription, !description.isEmpty {
                label = description
            } else if let description = items.lazy
                .compactMap({ self.imageNumbers.seriesDescription(forPath: $0.filePath) })
                .first {
                label = description
            } else if let path = items.first?.filePath {
                label = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
            } else {
                label = "Series"
            }
            return MarkedSeriesRange(key: key, label: label, imageCount: items.count, bounds: low...high)
        }
    }

    /// The lowest and highest image number in a series' marks, or `nil` when
    /// none of its frames are marked.
    public func imageNumberBounds(forSeries key: String) -> ClosedRange<Int>? {
        markedSeriesRanges.first { $0.key == key }?.bounds
    }

    /// The lowest and highest image number among all the marks, or `nil` when
    /// nothing is marked.
    public var markedImageNumberBounds: ClosedRange<Int>? {
        let all = markedSeriesRanges
        guard let low = all.map(\.bounds.lowerBound).min(),
              let high = all.map(\.bounds.upperBound).max() else { return nil }
        return low...high
    }

    /// Whether the range control is worth offering at all: it filters marks,
    /// so there have to be at least two to filter. Each series gets its own
    /// range, so a film mixing series is filtered series by series rather
    /// than by one set of numbers that restarts partway across it.
    public var canRangeImages: Bool {
        selection.items.count > 1
    }

    /// How many marks the ranges are holding back, for the control's caption.
    public var imagesHeldBackByRange: Int {
        max(0, selection.items.count - printedItems.count)
    }

    // MARK: - Driving it

    /// Applies a range to one series, clamped to what is actually marked of it.
    ///
    /// The two numbers are sorted rather than rejected when they arrive the wrong
    /// way round: "60 to 20" is a typo with an obvious meaning, and refusing it
    /// teaches nothing. A range that covers the whole series is stored as no
    /// range at all — it prints the same film, and an entry that filters
    /// nothing has nothing to say.
    public func setImageRange(from start: Int, to end: Int, forSeries key: String) {
        guard let bounds = imageNumberBounds(forSeries: key) else { return }
        let low = max(bounds.lowerBound, min(start, end))
        let high = min(bounds.upperBound, max(start, end))
        guard low <= high else { return }
        if low <= bounds.lowerBound && high >= bounds.upperBound {
            imageRanges[key] = nil
        } else {
            imageRanges[key] = low...high
        }
        pruneAfterRangeChange()
    }

    /// Applies a range when exactly one series is marked — the only case where
    /// "the series" needs no naming.
    public func setImageRange(from start: Int, to end: Int) {
        let series = markedSeriesRanges
        guard series.count == 1, let sole = series.first else { return }
        setImageRange(from: start, to: end, forSeries: sole.key)
    }

    /// Puts one series' every marked image back on the film.
    public func loadAllImages(forSeries key: String) {
        imageRanges[key] = nil
        pruneAfterRangeChange()
    }

    /// Puts every marked image of every series back on the film.
    public func loadAllImages() {
        imageRanges = [:]
        pruneAfterRangeChange()
    }

    /// Brings every stored range back inside what is marked.
    ///
    /// Called when the marks change under them: images added or taken off the
    /// film move a series' bounds, and a range left pointing outside them
    /// either prints nothing or claims to be filtering when it is not. A range
    /// for a series with no marks left is dropped with the series.
    public func clampImageRange() {
        guard !imageRanges.isEmpty else { return }
        var clamped: [String: ClosedRange<Int>] = [:]
        for series in markedSeriesRanges {
            guard let stored = imageRanges[series.key] else { continue }
            let low = min(max(stored.lowerBound, series.bounds.lowerBound), series.bounds.upperBound)
            let high = max(min(stored.upperBound, series.bounds.upperBound), low)
            if low > series.bounds.lowerBound || high < series.bounds.upperBound {
                clamped[series.key] = low...high
            }
        }
        imageRanges = clamped
    }

    /// The focus and the picked cells have to survive the film being re-laid out
    /// — but only if they are still on it.
    private func pruneAfterRangeChange() {
        let live = Set(printedItems.map(\.id))
        selectedItemIDs.formIntersection(live)
        if let focusedItemID, !live.contains(focusedItemID) { self.focusedItemID = nil }
    }
}
