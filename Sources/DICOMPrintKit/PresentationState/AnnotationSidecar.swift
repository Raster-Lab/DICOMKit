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
// The GSPS *also* carries a best-effort Graphic Annotation Sequence now — see
// ``PrintOverlayAnnotationGSPS`` — written in addition to this file for the
// benefit of other viewers, never read back by ours: restore reads this
// sidecar, which is the copy that says what the reader actually drew.
//
// The sidecar carries two more things the GSPS vocabulary cannot:
//
//   * The frame each drawing belongs to. A GSPS object names the image it
//     describes, but a multi-frame image's arrows are statements about
//     individual frames — an arrow on frame 3 restored onto frame 0 points at
//     nothing. Drawings are therefore keyed by frame index.
//   * The pseudo-colour palette the view was read through, if any. GSPS has no
//     way to say "coloured" — its Presentation LUT speaks only of grey and its
//     inverse — so the palette lives here or nowhere.
//
// One file per GSPS object, named after it: `<sopInstanceUID>.annotations.json`
// sits next to `<sopInstanceUID>.dcm`. Pairing by name means the two cannot
// drift apart, a delete that removes the object removes its annotations, and a
// study copied elsewhere carries both.

import Foundation
import DICOMCore

/// Reads and writes the annotations stored alongside a presentation state.
enum AnnotationSidecar {

    /// What one sidecar says: the view's palette, and its drawings by frame.
    struct Contents: Equatable {
        var palette: PseudoColorPalette?
        var annotationsByFrame: [Int: [PrintOverlayAnnotation]] = [:]

        /// Nothing worth a file: no colour and nothing drawn.
        var isEmpty: Bool { palette == nil && annotationsByFrame.isEmpty }

        /// Every drawing regardless of frame, in frame order — what callers
        /// that speak to the whole image (the GSPS sequence, the pickers'
        /// "has drawings" checks) read.
        var flattened: [PrintOverlayAnnotation] {
            annotationsByFrame.sorted { $0.key < $1.key }.flatMap(\.value)
        }
    }

    /// The on-disk shape. Frame indices are JSON object keys, so they encode
    /// as strings — `JSONEncoder` would turn an `[Int:]` dictionary into a
    /// flat array, which reads back but diffs meaninglessly.
    private struct Payload: Codable {
        var palette: PseudoColorPalette?
        var frames: [String: [PrintOverlayAnnotation]]?
    }

    /// The file holding the annotations for the GSPS object at `stateURL`.
    static func url(forStateAt stateURL: URL) -> URL {
        stateURL.deletingPathExtension().appendingPathExtension("annotations.json")
    }

    /// Writes the sidecar for one saved presentation state.
    ///
    /// Empty contents write nothing and remove any file already there: a view
    /// re-saved after the reader deleted their last arrow and took the colour
    /// off should come back plain, and an orphaned sidecar would put both back.
    static func write(
        _ contents: Contents,
        forStateAt stateURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let url = url(forStateAt: stateURL)

        guard !contents.isEmpty else {
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
            return
        }

        var frames: [String: [PrintOverlayAnnotation]] = [:]
        for (frame, annotations) in contents.annotationsByFrame
        where !annotations.isEmpty {
            frames[String(frame)] = annotations
        }
        let payload = Payload(
            palette: contents.palette, frames: frames.isEmpty ? nil : frames)

        let encoder = JSONEncoder()
        // Sorted keys so a view saved twice with the same annotations produces
        // the same bytes — it makes a diff of the store meaningful.
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(payload).write(to: url, options: [.atomic])
    }

    /// Writes the annotations for one saved presentation state.
    ///
    /// The single-frame convenience: everything lands on frame 0, and there is
    /// no palette to record. Kept because most callers describe single-frame
    /// images and have nothing frame-shaped to say.
    static func write(
        _ annotations: [PrintOverlayAnnotation],
        forStateAt stateURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try write(
            Contents(
                palette: nil,
                annotationsByFrame: annotations.isEmpty ? [:] : [0: annotations]),
            forStateAt: stateURL,
            fileManager: fileManager)
    }

    /// What was saved with one presentation state.
    ///
    /// A missing file is the ordinary case — most saved views have no drawings —
    /// and an unreadable one is treated the same way. Neither is worth failing a
    /// restore for: the reader gets their window and zoom back, without the
    /// annotations, rather than getting nothing back at all.
    ///
    /// Sidecars written before frames and palettes were recorded are a bare
    /// array of annotations. Those were all saved from single-frame images (the
    /// multi-frame ones are what the keyed format exists for), so the array
    /// reads back as frame 0 and no palette.
    static func read(
        forStateAt stateURL: URL,
        fileManager: FileManager = .default
    ) -> Contents {
        let url = url(forStateAt: stateURL)
        guard let data = try? Data(contentsOf: url) else { return Contents() }
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(Payload.self, from: data) {
            var byFrame: [Int: [PrintOverlayAnnotation]] = [:]
            for (key, annotations) in payload.frames ?? [:] {
                guard let frame = Int(key), !annotations.isEmpty else { continue }
                byFrame[frame] = annotations
            }
            return Contents(palette: payload.palette, annotationsByFrame: byFrame)
        }

        guard let legacy = try? decoder.decode(
            [PrintOverlayAnnotation].self, from: data), !legacy.isEmpty
        else { return Contents() }
        return Contents(annotationsByFrame: [0: legacy])
    }

    /// Copies the annotations alongside a presentation state being copied.
    ///
    /// Publishing a saved view into the study copies the `.dcm`; the drawings
    /// live beside it, and an object that arrives without its sidecar restores
    /// a window and a zoom and silently loses every arrow the reader drew.
    ///
    /// Clears any sidecar already at the destination even when the source has
    /// none, for the same reason ``write(_:forStateAt:fileManager:)-swift.type.method``
    /// does: a view re-published after its last arrow was deleted must not find
    /// the old arrows still sitting there.
    static func copy(
        forStateAt sourceURL: URL,
        toStateAt destinationURL: URL,
        fileManager: FileManager = .default
    ) {
        let source = url(forStateAt: sourceURL)
        let destination = url(forStateAt: destinationURL)
        try? fileManager.removeItem(at: destination)
        guard fileManager.fileExists(atPath: source.path) else { return }
        try? fileManager.copyItem(at: source, to: destination)
    }

    /// Removes the annotations belonging to a presentation state being deleted.
    static func delete(forStateAt stateURL: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: url(forStateAt: stateURL))
    }
}
