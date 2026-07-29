// FrameImageStore.swift
// DICOMStudio
//
// DICOM Studio — the caching half of frame rendering.
//
// `FrameRenderer` turns a file, frame and arrangement into a picture;
// this keeps those pictures, tracks what is in flight, and forgets what is no
// longer on screen. Film cells, viewer tiles and series thumbnails all want that
// same behaviour, and one implementation is what keeps them agreeing with each
// other.

import Foundation
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class FrameImageStore {

    private var images: [String: CGImage] = [:]
    private var failed: Set<String> = []
    private var inFlight: Set<String> = []

    /// Longest edge of a stored image, in pixels.
    private let maxDimension: Int

    public init(maxDimension: Int) {
        self.maxDimension = maxDimension
    }

    /// The image for a key, or `nil` while it renders or if it failed.
    public func image(forKey key: String) -> CGImage? { images[key] }

    /// Whether this key was tried and could not be rendered.
    public func didFail(_ key: String) -> Bool { failed.contains(key) }

    /// Forgets everything.
    public func clear() {
        images.removeAll()
        failed.removeAll()
        inFlight.removeAll()
    }

    /// One thing to render, identified by everything that changes its pixels.
    public struct Request: Sendable {
        public let key: String
        public let path: String
        public let frameIndex: Int
        public let windowCenter: Double?
        public let windowWidth: Double?
        public let presentation: ViewerPresentation?

        public init(
            path: String,
            frameIndex: Int = 0,
            windowCenter: Double? = nil,
            windowWidth: Double? = nil,
            presentation: ViewerPresentation? = nil
        ) {
            self.key = FrameRenderer.cacheKey(
                path: path,
                frameIndex: frameIndex,
                windowCenter: windowCenter,
                windowWidth: windowWidth,
                presentation: presentation)
            self.path = path
            self.frameIndex = frameIndex
            self.windowCenter = windowCenter
            self.windowWidth = windowWidth
            self.presentation = presentation
        }
    }

    /// Renders whatever these requests still need, and drops everything else.
    ///
    /// A failed render is remembered so a broken file is not retried on every
    /// redraw, and an in-flight one is not started twice when SwiftUI
    /// re-evaluates mid-load.
    public func refresh(_ requests: [Request]) {
        let live = Set(requests.map(\.key))
        images = images.filter { live.contains($0.key) }
        failed = failed.intersection(live)
        inFlight = inFlight.intersection(live)

        for request in requests {
            guard images[request.key] == nil,
                  !failed.contains(request.key),
                  !inFlight.contains(request.key) else { continue }
            load(request)
        }
    }

    private func load(_ request: Request) {
        inFlight.insert(request.key)
        let key = request.key
        let limit = maxDimension

        Task { [weak self] in
            let rendered = await FrameRenderer.render(
                path: request.path,
                frameIndex: request.frameIndex,
                windowCenter: request.windowCenter,
                windowWidth: request.windowWidth,
                presentation: request.presentation,
                maxDimension: limit)
            guard let self else { return }
            self.inFlight.remove(key)
            if let rendered {
                self.images[key] = rendered
            } else {
                self.failed.insert(key)
            }
        }
    }
}
#endif
