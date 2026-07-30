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

#endif
