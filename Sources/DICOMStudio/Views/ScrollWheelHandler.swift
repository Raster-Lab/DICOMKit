// ScrollWheelHandler.swift
// DICOMStudio
//
// DICOM Studio — scroll-wheel input, shared by the viewer and the film preview.
//
// The viewer pages images with the wheel and the film preview zooms cells with
// it, and both are sometimes on screen at once (the print sheet sits over the
// viewer), so the scoping rules below are not an implementation detail of
// either one.

#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Scroll input

/// One scroll event, in the terms a viewer needs to decide what it means.
struct ScrollWheelDelta {
    /// Vertical scroll. Positive is a scroll up / away from the user.
    let y: CGFloat

    /// Whether the device reports continuous, pixel-precise scrolling.
    ///
    /// A mouse wheel does not: it emits one event per physical notch, and the
    /// magnitude of that event is an acceleration curve, not a distance. Paging
    /// on the magnitude is what makes one notch jump several images. A trackpad
    /// does, and its many small deltas must be summed instead.
    let isPrecise: Bool
}

/// Turns scroll events into whole steps.
///
/// Wheel notches are one step each, however hard the wheel is spun; trackpad
/// deltas accumulate until they add up to a step. Keeps its own remainder, so
/// a slow drag still eventually steps rather than being rounded away.
struct ScrollStepAccumulator {
    private var accumulated: CGFloat = 0

    /// Points of precise scrolling per step — roughly one line of a trackpad
    /// swipe, which is the granularity a reader expects when paging a stack.
    private static let preciseThreshold: CGFloat = 12

    /// The number of steps this event is worth, signed the way the scroll was.
    ///
    /// A wheel notch is deliberately capped at one step: a fast spin should page
    /// faster because more events arrive, not because each one counts for more.
    mutating func steps(for delta: ScrollWheelDelta) -> Int {
        guard delta.y != 0 else { return 0 }
        guard delta.isPrecise else {
            accumulated = 0
            return delta.y > 0 ? 1 : -1
        }
        accumulated += delta.y
        let steps = Int(accumulated / Self.preciseThreshold)
        guard steps != 0 else { return 0 }
        accumulated -= CGFloat(steps) * Self.preciseThreshold
        return steps
    }

    /// Forgets any part-step, e.g. when the pointer leaves the image.
    mutating func reset() { accumulated = 0 }
}

// MARK: - Scroll Wheel monitor (macOS)

#if os(macOS)
/// Zero-size NSView that installs a local NSEvent monitor for scroll-wheel events.
///
/// The monitor is application-wide, so it must self-scope: a scroll only reaches
/// this view when the cursor is actually over it *in its own window*. Sheets,
/// popovers and other popups are presented in separate windows, so scrolling
/// inside them no longer leaks through to the image behind them.
struct ScrollWheelHandler: NSViewRepresentable {
    let onScroll: (ScrollWheelDelta) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak view] event in
            guard let view, let window = view.window else { return event }
            // Reject scrolls aimed at a different window (sheet / popover / popup).
            guard let eventWindow = event.window, eventWindow === window else { return event }
            // Only act when the cursor is over this view itself.
            let pointInView = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(pointInView) else { return event }
            let precise = event.hasPreciseScrollingDeltas
            onScroll(ScrollWheelDelta(
                y: precise ? event.scrollingDeltaY : event.deltaY,
                isPrecise: precise))
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var monitor: Any?
        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
#endif

// MARK: - Tool cursor (macOS)

#if os(macOS)
/// Sets the pointer's shape over the view it is placed behind.
///
/// Via a tracking area and `cursorUpdate` rather than SwiftUI's `.onHover` with
/// `NSCursor.push()`/`.pop()`. A push/pop pair is a stack, and hover callbacks
/// do not arrive in balanced pairs: move the mouse quickly between two cells and
/// the second cell's enter can land before the first cell's exit, so the pops
/// come out of order and the pointer is left as a magnifier over the whole
/// window until something else happens to reset it. `cursorUpdate` has no stack
/// — AppKit asks the view under the pointer what shape it wants, every time it
/// crosses a boundary, and a view that is gone is simply not asked.
struct ToolCursor: NSViewRepresentable {
    let cursor: NSCursor?

    func makeNSView(context: Context) -> CursorView {
        let view = CursorView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: CursorView, context: Context) {
        nsView.cursor = cursor
    }

    final class CursorView: NSView {
        /// Invisible to clicks, visible to the cursor.
        ///
        /// The two are separate questions in AppKit and this view answers them
        /// differently: it sits over the film cell, so it must not take the
        /// taps and drags the tools run on — but SwiftUI's own
        /// `allowsHitTesting(false)` answers *both* with no, and a view outside
        /// hit testing is a view AppKit never asks for a cursor. Refusing hits
        /// here instead keeps the tracking area live while every event still
        /// lands on the cell behind.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        var cursor: NSCursor? {
            didSet {
                guard cursor !== oldValue else { return }
                // The pointer may already be inside: the tool was changed from
                // the rail or by its keyboard shortcut, under a mouse that has
                // not moved. AppKit only asks at a boundary crossing, so
                // without this the new shape waits for one — and the reader,
                // who has just armed a tool and is about to drag, is looking at
                // the previous tool's pointer.
                if isPointerInside { (cursor ?? .arrow).set() }
            }
        }

        private var isPointerInside: Bool {
            guard let window else { return false }
            let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            return bounds.contains(point)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited],
                owner: self))
        }

        override func cursorUpdate(with event: NSEvent) {
            if let cursor { cursor.set() } else { super.cursorUpdate(with: event) }
        }
    }
}
#endif

#endif
