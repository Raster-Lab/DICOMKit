// FrameSourceCache.swift
// DICOMStudio
//
// DICOM Studio — the decoded frames behind a re-render.
//
// Windowing, zooming or panning a film cell changes how a frame is *shown*, not
// which frame it is. Without this, every mouse delta re-read the file from disk
// and re-decoded its pixels — for a JPEG 2000 CT that is tens of milliseconds
// per event, which is exactly the lag a window/level drag feels as stutter.
// Keeping the decoded pixels for the handful of files being worked on turns each
// subsequent render into a window mapping.

import Foundation
import DICOMCore
import DICOMKit
import DICOMRenderKit

#if canImport(CoreGraphics)
import CoreGraphics

/// A file's decoded pixels, ready to render at any window.
struct FrameSource: Sendable {
    let file: DICOMFile
    let pixelData: PixelData
    let paletteLUT: PaletteColorLUT?
}

/// Keeps the decoded pixels of the few files currently being looked at.
actor FrameSourceCache {

    static let shared = FrameSourceCache()

    /// How many files to hold. Small on purpose: a cine series' frames are
    /// hundreds of megabytes, and the working set of an edit is one cell — with
    /// enough room either side for the neighbours a user flicks between.
    private static let capacity = 3

    /// Largest decoded frame set worth keeping, in bytes. Beyond this the cost
    /// of holding it outweighs a re-decode nobody is doing at drag speed.
    private static let maximumBytes = 96 * 1024 * 1024

    private var entries: [(path: String, source: FrameSource)] = []

    /// Whether decoded frames are worth page-aligning on this machine.
    ///
    /// Resolved once: the backend cannot change during a run, and asking per file
    /// would probe the Metal device on the decode path.
    private static let alignsForGPU = FrameRenderService.shared.prefersAlignedPixelData

    /// The decoded source for a file, reading and decoding it if needed.
    ///
    /// Returns `nil` for anything that cannot be read or has no pixels — a
    /// report, a document, a corrupt file — and does not cache the failure: the
    /// caller has its own "this one failed" bookkeeping, and a file being
    /// written while it is read should not be poisoned forever.
    func source(forPath path: String) -> FrameSource? {
        if let index = entries.firstIndex(where: { $0.path == path }) {
            // Most recently used last, so eviction takes the coldest.
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.source
        }

        guard let data = FileManager.default.contents(atPath: path),
              let file = try? DICOMFile.read(from: data, force: true),
              let decoded = file.pixelData() else { return nil }

        // Page-align once, here, so every subsequent render can hand these bytes
        // straight to the GPU with `makeBuffer(bytesNoCopy:)` — no upload, ever.
        // The cost is one copy per *file*; the alternative is a copy of the same
        // size on every render, which for a mammogram is 23 MB per window delta.
        //
        // Only when the GPU is actually the active backend: on a CPU-only machine
        // the alignment buys nothing and the copy would be pure waste.
        let pixelData = Self.alignsForGPU ? decoded.pageAligned() : decoded

        let source = FrameSource(
            file: file,
            pixelData: pixelData,
            paletteLUT: file.dataSet.paletteColorLUT())

        if pixelData.data.count <= Self.maximumBytes {
            entries.append((path, source))
            if entries.count > Self.capacity { entries.removeFirst() }
        }
        return source
    }

    /// Forgets everything, e.g. when a study is closed.
    func clear() {
        entries.removeAll()
    }
}
#endif
