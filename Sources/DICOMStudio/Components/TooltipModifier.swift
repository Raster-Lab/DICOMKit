// TooltipModifier.swift
// DICOMStudio
//
// A tooltip that shows on the first hover, and shows on a disabled control.
//
// SwiftUI's `.help` is the right thing on an ordinary bordered button, and the
// print screen's options bar uses it. It is the wrong thing on the film
// preview's tool rail, for two reasons that compound:
//
//  1. The rail's chips are `.buttonStyle(.plain)`. A plain button's tooltip
//     ends up on a wrapper view that the pointer does not actually enter — the
//     label's shaped content is what hover lands on — so AppKit never asks the
//     wrapper for a tooltip string. The rail read as having no tooltips at all
//     until a *bordered* button elsewhere in the window (More/Less in the
//     options bar) showed its own tooltip; that pass rebuilt the window's
//     tooltip tracking and the rail's stale wrappers started answering
//     afterwards. Hence "tooltips only work after you hover More".
//
//  2. Most of the rail is disabled a good deal of the time — Straighten until a
//     cell is askew, Invert and CLUT until a cell is focused, the window lock
//     while raw pixels are being sent. A disabled SwiftUI control drops out of
//     hit testing, so `.help` on it never fires. That is backwards: the tooltip
//     on a disabled chip is the one that says *why* it is disabled and what to
//     do about it, which is exactly when the reader needs it.
//
// Both go away by owning the tooltip outright: an AppKit view laid over the
// control, never disabled, with its `toolTip` set. AppKit tracks it directly,
// so the first hover works, and the chip's enabled state has no bearing on it.
// The overlay takes no clicks (`hitTest` returns nil), so the button under it
// still behaves as a button.

#if os(macOS)
import AppKit
import SwiftUI

extension View {
    /// A tooltip that works on the first hover and on a disabled control.
    ///
    /// Use on the film preview's rail chips and anywhere else a `.plain`
    /// button or a disabled control needs to explain itself. Ordinary bordered
    /// buttons should keep using `.help`.
    func railTooltip(_ text: String) -> some View {
        overlay(TooltipOverlay(text: text))
    }
}

private struct TooltipOverlay: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> TooltipNSView {
        let view = TooltipNSView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: TooltipNSView, context: Context) {
        // Most of the rail's strings are recomputed on every state change and
        // come back equal. Writing `toolTip` invalidates the window's tooltip
        // tracking, which cancels a tooltip that is currently on screen — so
        // an unchanged string must not be written back, or a tooltip the
        // reader is part-way through reading vanishes when some unrelated
        // corner of the view redraws.
        if nsView.toolTip != text { nsView.toolTip = text }
    }
}

/// Carries a tooltip and nothing else: transparent, and invisible to clicks so
/// the control underneath keeps every event it would otherwise get.
final class TooltipNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
}
#else
import SwiftUI

extension View {
    /// Non-macOS platforms have no pointer tooltips; `.help` carries the string
    /// to accessibility, which is what it is for there.
    func railTooltip(_ text: String) -> some View { help(text) }
}
#endif
