// ScrollWheelModifier.swift
// DICOMStudio
//
// Scroll-wheel / two-finger-swipe slice navigation for macOS MPR panels.
// NSViewRepresentable overlay so DragGesture (pan) keeps working independently.

#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Public modifier

extension View {
    /// Calls `handler` with the vertical scroll delta whenever a scroll-wheel
    /// (or two-finger swipe) event occurs over this view.  Positive delta = scroll down.
    func onScrollWheel(_ handler: @escaping (Double) -> Void) -> some View {
        overlay(ScrollWheelView(onScroll: handler).allowsHitTesting(false))
    }
}

// MARK: - NSViewRepresentable shim

private struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> ScrollNSView {
        let v = ScrollNSView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: ScrollNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

// MARK: - NSView that captures scroll wheel events

final class ScrollNSView: NSView {
    var onScroll: ((Double) -> Void)?

    override var acceptsFirstResponder: Bool { false }

    // hitTest returns nil so mouse clicks pass through to the SwiftUI layer below.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func scrollWheel(with event: NSEvent) {
        let dy = event.scrollingDeltaY
        guard abs(dy) > 0.5 else { return }      // ignore tiny jitter
        onScroll?(dy)
    }
}
#endif
