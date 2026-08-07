// ViewerAnnotationTextCache.swift
// DICOMStudio
//
// DICOM Studio — corner annotations for files the view model has not loaded.
//
// Every tile of a grid annotates its own image, and those images are different
// files — different series, sometimes different studies. Reading each file's
// header once and keeping the result is what lets a 4×4 grid label all sixteen
// tiles honestly without decoding sixteen headers on every redraw.
//
// The same shape as ``PatientOverlayTextCache``, and deliberately separate from
// it: film needs two lines of identification and nothing else, and folding the
// viewer's much larger block into that type would send it to the printer too.

import Foundation
import DICOMKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class ViewerAnnotationTextCache {

    private var texts: [String: ViewerAnnotationText] = [:]
    private var inFlight: Set<String> = []

    public init() {}

    /// The annotations for a file, or `nil` until it has been read.
    public func text(forPath path: String) -> ViewerAnnotationText? { texts[path] }

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
            let text = await Task.detached(priority: .utility) { () -> ViewerAnnotationText? in
                guard let data = FileManager.default.contents(atPath: path),
                      let file = try? DICOMFile.read(from: data, force: true) else { return nil }
                return ViewerAnnotationText.make(from: file)
            }.value
            guard let self else { return }
            self.inFlight.remove(path)
            // An unreadable file simply has no annotations: the tile still shows
            // the picture, which is what the user is there for.
            self.texts[path] = text ?? ViewerAnnotationText()
        }
    }
}
