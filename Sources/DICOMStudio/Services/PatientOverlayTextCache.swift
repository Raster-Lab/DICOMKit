// PatientOverlayTextCache.swift
// DICOMStudio
//
// DICOM Studio — overlay text for files other than the one that is open.
//
// A viewer tile or a film cell shows a file the view model has not loaded, and
// its patient is not always the same one: two studies can hang side by side.
// Reading each file's header once and keeping the result is cheap — the values
// are a handful of short strings — and it is the only way an overlay can be
// honest about whose image a tile is actually showing.

import Foundation
import DICOMKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PatientOverlayTextCache {

    private var texts: [String: PatientOverlayText] = [:]
    private var inFlight: Set<String> = []

    public init() {}

    /// The overlay text for a file, or `nil` until it has been read.
    public func text(forPath path: String) -> PatientOverlayText? { texts[path] }

    /// Reads whatever these paths still need, and forgets the rest.
    public func refresh(for paths: [String]) {
        let live = Set(paths)
        texts = texts.filter { live.contains($0.key) }
        inFlight = inFlight.intersection(live)

        for path in live where texts[path] == nil && !inFlight.contains(path) {
            load(path)
        }
    }

    public func clear() {
        texts.removeAll()
        inFlight.removeAll()
    }

    private func load(_ path: String) {
        inFlight.insert(path)
        Task { [weak self] in
            let text = await Task.detached(priority: .utility) { () -> PatientOverlayText? in
                guard let data = FileManager.default.contents(atPath: path),
                      let file = try? DICOMFile.read(from: data, force: true) else { return nil }
                return PatientOverlayText.make(from: file.dataSet)
            }.value
            guard let self else { return }
            self.inFlight.remove(path)
            // An unreadable file simply has no overlay: the tile still shows the
            // picture, which is what the user is there for.
            self.texts[path] = text ?? PatientOverlayText(primaryLine: "", secondaryLine: "")
        }
    }
}
