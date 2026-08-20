// AnnotationSidecar.swift
// DICOMPrintKit
//
// The drawn annotations belonging to a saved view, kept beside its GSPS object.
//
// A GSPS can carry annotations — Graphic Annotation Sequence (PS3.3 C.10.5) is
// part of the standard, and the parser in DICOMKit already reads it. It is not
// what these are written to, for one reason: the standard's vocabulary cannot
// hold what a `PrintOverlayAnnotation` actually says. There is no arrow
// primitive in DICOM, per-annotation colour is not a GSPS concept (a layer
// carries one *recommended* value for everything on it), and nothing
// corresponds to `scale`. Writing an annotation out through that vocabulary and
// reading it back would return a different annotation than the reader drew,
// which is the exact failure this file exists to prevent.
//
// So the sidecar is lossless and private, and the GSPS beside it stays
// conformant and describes the display parameters it can describe honestly.
// Adding a Graphic Annotation Sequence later — for the benefit of other
// viewers, written *in addition to* this file rather than instead of it — does
// not disturb anything here.
//
// One file per GSPS object, named after it: `<sopInstanceUID>.annotations.json`
// sits next to `<sopInstanceUID>.dcm`. Pairing by name means the two cannot
// drift apart, a delete that removes the object removes its annotations, and a
// study copied elsewhere carries both.

import Foundation

/// Reads and writes the annotations stored alongside a presentation state.
enum AnnotationSidecar {

    /// The file holding the annotations for the GSPS object at `stateURL`.
    static func url(forStateAt stateURL: URL) -> URL {
        stateURL.deletingPathExtension().appendingPathExtension("annotations.json")
    }

    /// Writes the annotations for one saved presentation state.
    ///
    /// An empty array writes nothing and removes any file already there: a view
    /// re-saved after the reader deleted their last arrow should come back with
    /// no arrow, and an orphaned sidecar would put it back.
    static func write(
        _ annotations: [PrintOverlayAnnotation],
        forStateAt stateURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let url = url(forStateAt: stateURL)

        guard !annotations.isEmpty else {
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
            return
        }

        let encoder = JSONEncoder()
        // Sorted keys so a view saved twice with the same annotations produces
        // the same bytes — it makes a diff of the store meaningful.
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(annotations).write(to: url, options: [.atomic])
    }

    /// The annotations saved with one presentation state.
    ///
    /// A missing file is the ordinary case — most saved views have no drawings —
    /// and an unreadable one is treated the same way. Neither is worth failing a
    /// restore for: the reader gets their window and zoom back, without the
    /// annotations, rather than getting nothing back at all.
    static func read(
        forStateAt stateURL: URL,
        fileManager: FileManager = .default
    ) -> [PrintOverlayAnnotation] {
        let url = url(forStateAt: stateURL)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PrintOverlayAnnotation].self, from: data)) ?? []
    }

    /// Removes the annotations belonging to a presentation state being deleted.
    static func delete(forStateAt stateURL: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: url(forStateAt: stateURL))
    }
}
