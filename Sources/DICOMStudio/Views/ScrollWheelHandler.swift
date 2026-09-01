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
/// Gives the pointer back to the arrow over a control that sits on the image.
///
/// The reading area is covered edge to edge by `ToolCursor`, which is what puts
/// the armed tool's glyph under the pointer wherever the picture is. The
/// controls that float on top of the picture — the print checkbox, the
/// saved-views badge — are inside that rect, so they inherited the tool's
/// pointer: hovering the print tick showed the windowing sun or the zoom
/// magnifier rather than an arrow, which says "drag me to window this image"
/// over a thing that is actually a checkbox.
///
/// Restoring the arrow is a rect of its own, registered by a view *above*
/// `ToolCursor` in the overlay order. The window resolves a cursor rect from
/// the topmost view that registered one at that point, so a small rect over the
/// badge beats the big one over the image without either knowing about the
/// other — no geometry to keep in step, and a control that moves or comes and
/// goes takes its rect with it.
///
/// Attach with ``SwiftUI/View/arrowPointer()``.
struct ArrowPointer: NSViewRepresentable {

    func makeNSView(context: Context) -> PointerView { PointerView() }

    func updateNSView(_ nsView: PointerView, context: Context) {}

    /// Restores the arrow on entry and hands the pointer back on exit.
    ///
    /// Deliberately *not* a cursor rect, which is what `ToolCursor` uses.
    /// A rect is resolved by z-order — the topmost view that registered one at
    /// that point wins — and these controls are not always on top: the tiles of
    /// a grid are content, drawn below the viewer's tool-cursor overlay, so a
    /// rect here would be outranked and the tool's glyph would keep the badge.
    ///
    /// Enter and exit events have no such ordering: they are dispatched to the
    /// tracking area's owner whatever is layered over it, so this sets the
    /// arrow the moment the pointer arrives on the control, wherever the
    /// control sits in the hierarchy. On the way out the shape is left alone —
    /// the cursor rect underneath re-resolves at the same crossing and puts the
    /// tool's glyph back, and setting the arrow here would fight it.
    final class PointerView: NSView {

        /// Invisible to clicks, for the same reason `ToolCursor.CursorView` is:
        /// this sits over a button and must not take the click meant for it.
        /// Tracking areas do not need hit testing, so refusing it costs nothing.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func mouseEntered(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        /// A pointer that arrives without crossing the boundary — the control
        /// appearing under a stationary mouse, a tile re-laid out beneath it —
        /// gets the arrow too.
        override func cursorUpdate(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .inVisibleRect,
                          .mouseEnteredAndExited, .cursorUpdate],
                owner: self))
        }
    }
}

@available(macOS 14.0, *)
extension View {
    /// Restores the arrow pointer over this control, above the image's tool
    /// cursor. See ``ArrowPointer``.
    func arrowPointer() -> some View {
        overlay(ArrowPointer())
    }
}
#endif

#if os(macOS)
/// Sets the pointer's shape over the view it is placed behind.
///
/// Via the window's cursor rects rather than SwiftUI's `.onHover` with
/// `NSCursor.push()`/`.pop()`. A push/pop pair is a stack, and hover callbacks
/// do not arrive in balanced pairs: move the mouse quickly between two cells and
/// the second cell's enter can land before the first cell's exit, so the pops
/// come out of order and the pointer is left as a magnifier over the whole
/// window until something else happens to reset it. A cursor rect has no stack
/// — the window resolves the shape from the rects its views have registered,
/// every time the pointer crosses one, and a view that is gone is simply no
/// longer registered. Leaving a rect resets to the arrow by itself.
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
                // The rect the window holds for this view still names the old
                // shape; ask it to rebuild from `resetCursorRects`.
                window?.invalidateCursorRects(for: self)
                // The pointer may already be inside: the tool was changed from
                // the rail or by its keyboard shortcut, under a mouse that has
                // not moved. The window only re-resolves its rects at a
                // boundary crossing, so without this the new shape waits for
                // one — and the reader, who has just armed a tool and is about
                // to drag, is looking at the previous tool's pointer.
                if isPointerInside { (cursor ?? .arrow).set() }
            }
        }

        private var isPointerInside: Bool {
            guard let window else { return false }
            let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            return bounds.contains(point)
        }

        /// Cursor rects, not a `.cursorUpdate` tracking area.
        ///
        /// The two mechanisms differ in who is asked. A tracking area's
        /// `cursorUpdate` event is dispatched by the window to the view that
        /// *hit-tests* under the pointer — and this view refuses hit testing
        /// on purpose, so the event sailed past it to the image behind, which
        /// answered with the arrow. The shape then only ever changed through
        /// `didSet`, when a tool was switched under a stationary mouse; move
        /// the pointer onto a film cell and it stayed an arrow. A cursor rect
        /// is the window's own bookkeeping: it resolves the shape from the
        /// rects each view has registered, no hit testing involved, so a view
        /// that is invisible to clicks can still own the pointer over it.
        override func resetCursorRects() {
            if let cursor { addCursorRect(bounds, cursor: cursor) }
        }

        /// Enter events *are* owner-dispatched, so this backstops the rect for
        /// the crossing that established it — the rect alone can lose the race
        /// when the pointer enters at speed and the window resolves before the
        /// rect is registered.
        override func mouseEntered(with event: NSEvent) {
            cursor?.set()
        }

        /// Hands the pointer back on the way out.
        ///
        /// `NSCursor.set()` is global, not scoped to this view: whatever was set
        /// last is the shape the whole application draws until something sets
        /// another. Cursor rects undo themselves at a boundary crossing *within
        /// the window that owns them*, so leaving the image for a different
        /// window — the print sheet, a panel — left the tool's pointer armed
        /// over it, and a reader who had picked Rotate went to click Print with
        /// the rotate cursor still under their hand. Restoring the arrow here is
        /// the exit half of `mouseEntered`, and it costs nothing when the
        /// pointer merely moves to another cursor rect: that rect sets its own
        /// shape immediately afterwards.
        override func mouseExited(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        /// The tracking area is deliberately not `.activeInKeyWindow`.
        ///
        /// Exit events have to arrive even as the window stops being key —
        /// which is exactly what happens when the pointer leaves for the print
        /// sheet. Scoped to the key window, AppKit stops delivering at the
        /// moment key changes hands, the exit never lands, and the tool cursor
        /// is left behind on the window the reader just moved to.
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self))
        }

        /// A view being torn down cannot be asked to restore anything later, so
        /// a pointer still standing on it gives the arrow back now. Closing the
        /// viewer with a tool armed otherwise left its shape behind everywhere.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { NSCursor.arrow.set() }
        }
    }
}
#endif

#endif
