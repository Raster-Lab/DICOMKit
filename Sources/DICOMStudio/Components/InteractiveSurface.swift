// InteractiveSurface.swift
// DICOMStudio
//
// Saying "this is clickable" the same way everywhere.
//
// The viewer and the print screen are built largely out of plain buttons —
// toolbar glyphs, tool-rail chips, list rows, badges over the image. A plain
// button draws nothing of its own, which is what the reading screens want (a
// row of system-chrome buttons over a CT is noise), but it leaves the reader
// with no way to tell a control from a label until they click it. On the
// print screen in particular, where a rail of chips sits beside static
// descriptive text, the two look identical at rest.
//
// So the affordance is drawn here instead: a soft fill and a border on hover,
// both stronger on press. At rest an ordinary control draws nothing at all, so
// the screens stay as quiet as they were — the cue appears when it is needed
// and gets out of the way when it is not, which is the requirement on a
// reading screen where the picture is the point.
//
// The one thing drawn at rest is `isSelected`: an accented border and a faint
// wash on the tool that is currently armed. That is not an affordance but a
// statement of state, and a reader has to be able to see which tool a drag
// will use without hovering each chip in turn to find out.
//
// Two shapes, because two kinds of thing need it:
//
//  - `interactiveControl` for a discrete control — a glyph, a chip, a badge.
//    Rounded to sit around the control's own shape.
//  - `interactiveRow` for a full-width row in a list, where the fill spans the
//    row and the corner radius is smaller.
//
// Press tracking is deliberately not `ButtonStyle.isPressed`: these are applied
// to controls that are already wearing a `.buttonStyle`, and to some things
// that are not buttons at all (a Menu label, a row carrying a tap gesture).
// A drag gesture with zero minimum distance reports the same down/up window
// without requiring the caller to restructure into a custom button style.

// MARK: - The caller contract
//
// This modifier is worn by around thirty controls across the viewer and the
// print screen, and they are not all the same kind of thing. Three times now a
// change made to suit one kind has silently broken another — the series card's
// fix killed clicks in the saved-views popover, and the toolbar's fix was drawn
// inside out. So the differences are written down here rather than rediscovered
// one bug report at a time.
//
// Four questions, four switches. Answer them for a new caller *before* adding
// it, and check them for every caller before changing a default.
//
//  1. Does the caller own the drag gesture?  → `tracksPress: false`
//     A `.draggable` card or a pannable tile has already spent the pointer-down
//     window. A second zero-distance `DragGesture` under it claims the sequence
//     and the caller's own tap never fires. Costs only the press cue.
//     Callers: the series card.
//
//  2. Does the caller need its own hit shape kept?  → `extendsHitArea: false`
//     Default ON, because list rows depend on it: an `HStack` in a `Button` is
//     only as wide as its content, so without a stamped shape a click right of
//     a short label falls through. Turn it OFF only where the caller has
//     deliberately shaped its own hit area and a rounded stamp would trim it.
//     Callers opting out: the series card (whole-card `Rectangle()`).
//     NOTE a `.contentShape` set *inside* a Button label does not conflict —
//     the outer stamp extends it, which is what those callers want.
//
//  3. Is the caller inside a macOS toolbar?  → `isInset: true`, padding 1×1
//     A `ToolbarItem(Group)` lays items to a fixed metric inside one shared
//     bezel; growing the item draws the highlight over that bezel and the
//     neighbouring group. Inset draws the plate *inside* the item instead.
//     Use a small padding: the rail's 5×4 taken inward leaves the plate
//     smaller than the glyph it sits behind.
//     Callers: the drag-tool glyphs.
//     NOTE a toolbar control that already draws a shaped background of its own
//     — the saved-view save button's capsule — wants neither switch: it lights
//     that background instead, because an inset rounded plate under a capsule
//     is a second, differently-shaped highlight in the same few points.
//
//  4. Does the caller draw its own armed/selected fill?
//     Then put this modifier OUTSIDE that fill so hover still reads when armed,
//     and give it a radius a point or two larger than the control's own.
//
// Anything that changes a DEFAULT above changes every caller at once. If that
// is the intent, walk the call sites — `grep -rn "interactiveControl(\|interactiveRow("` —
// and check each against these four questions. A build succeeding proves
// nothing here: every one of these failures compiled cleanly.

#if canImport(SwiftUI)
import SwiftUI

/// Draws hover and press states for a control that otherwise draws none.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct InteractiveSurface: ViewModifier {

    let cornerRadius: CGFloat

    /// How far the fill extends past the control's own bounds.
    let padding: EdgeInsets

    /// Whether the control can actually be used. A disabled control gets no
    /// hover cue: the fill would promise an action that is not on offer, which
    /// is the same reasoning the saved-view save button already applies to its
    /// tint.
    let isEnabled: Bool

    /// Whether this control is the one currently in effect — the armed tool on
    /// a rail, the layout that is showing.
    ///
    /// Drawn at rest, unlike hover and press, because it is a statement about
    /// state rather than about the pointer: a reader glancing at the rail has
    /// to be able to see which tool a drag will use without waving the mouse
    /// over each chip in turn. It is the accent rather than a brighter white,
    /// so "this is selected" cannot be mistaken for "the pointer is here".
    let isSelected: Bool

    /// Whether to track the mouse-down state with a gesture of this modifier's
    /// own.
    ///
    /// On by default, and right for a glyph or a chip: the press cue is the
    /// strongest of the three and a control that does not darken under the
    /// pointer reads as dead. It has to be switchable off, though, because the
    /// tracking gesture is a `DragGesture`, and a caller that is *itself* built
    /// out of drag — a `.draggable` card, a tile that pans — has already spent
    /// that gesture. Two drag recognisers over the same view do not coexist:
    /// the inner one claims the sequence, and the caller's own tap never
    /// arrives. That is what stopped a click on a series card from hanging the
    /// series. Those callers keep hover and selection and give up the press.
    let tracksPress: Bool

    /// Whether the fill is drawn inside the control's existing frame rather
    /// than around it.
    ///
    /// `padding` grows the control, which is what a chip on a rail wants — the
    /// fill needs room to sit clear of the glyph. Inside a macOS toolbar it is
    /// wrong: an item in a `ToolbarItemGroup` is laid out to a fixed metric and
    /// drawn inside a shared bezel, so a fill that grows the item spills over
    /// that bezel and over its neighbours. Inset instead: the same padding is
    /// taken *out* of the control's own bounds, so the highlight stays within
    /// the group.
    let isInset: Bool

    /// Whether the modifier gives the control a hit shape spanning the plate.
    ///
    /// On by default, and load-bearing for every list row in the app. A row is
    /// built as an `HStack` inside a `Button`, and an `HStack` is only as wide
    /// as what is in it — so without a shape over the full width, a click in
    /// the empty space right of a short label falls through and selects
    /// nothing. Several callers set `.contentShape` *inside* their button label
    /// and relied on this modifier to carry it out to the row's real bounds.
    ///
    /// Off for a caller that has already arranged its own hit testing and whose
    /// shape must not be replaced — a series card sets `.contentShape(Rectangle())`
    /// deliberately so its whole surface is clickable, and stamping a rounded
    /// shape over that changed what the card answered to.
    ///
    /// Removing the stamp outright — which is what the series-card fix first
    /// did — is what broke the saved-views popover: its rows lost the hit area
    /// this had always given them, and clicking one stopped applying the view.
    /// Hence a switch rather than a blanket choice: the two kinds of caller
    /// want opposite things, and neither may be quietly changed under the
    /// other's fix.
    let extendsHitArea: Bool

    @State private var isHovering = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        hitShaped(decorated(content))
            .onHover { hovering in
                isHovering = hovering
                // A pointer that leaves mid-press takes the press state with
                // it: the gesture's `onEnded` does not arrive if the button
                // was never released over the control, and a chip left lit
                // reads as a stuck toggle.
                if !hovering { isPressed = false }
            }
            // Nothing to animate on the way in that a reader would notice, but
            // the way out matters: the fill vanishing the instant the pointer
            // crosses the edge reads as a flicker when moving along a rail.
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    /// The control with a hit shape spanning its plate, unless the caller has
    /// asked to keep its own — see ``extendsHitArea``.
    @ViewBuilder
    private func hitShaped(_ content: some View) -> some View {
        if extendsHitArea {
            content.contentShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }

    /// The control with its fill and border, grown or inset per `isInset`.
    @ViewBuilder
    private func decorated(_ content: Content) -> some View {
        if isInset {
            content
                // Positive padding on the *plate*, which insets it inside the
                // control's own bounds. Negative padding here would grow it
                // back out — which is what the first attempt at this did, and
                // why the armed tool's border still crossed the toolbar
                // group's bezel.
                .background(alignment: .center) { plate.padding(padding) }
                .modifier(PressTracking(isPressed: $isPressed, isActive: tracksPress))
        } else {
            content
                .padding(padding)
                .background { plate }
                .modifier(PressTracking(isPressed: $isPressed, isActive: tracksPress))
        }
    }

    /// The fill and its border, drawn to whatever bounds it is handed.
    private var plate: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: borderWidth)
            }
    }

    /// The three states now read apart at a glance rather than only on close
    /// inspection. The previous values — a 10% fill under a 20% hairline —
    /// were nearly invisible against a black reading screen, so a reader could
    /// not tell a live control from a label without clicking it, which is the
    /// thing this modifier exists to prevent.
    private var fill: Color {
        guard isEnabled else { return .clear }
        if isPressed { return .white.opacity(0.32) }
        if isHovering { return .white.opacity(0.18) }
        // Selection is carried by its border and a faint accent wash. The wash
        // stays light: the chip's own tint already says which tool it is, and a
        // solid accent block behind it would drown that.
        if isSelected { return Color.accentColor.opacity(0.22) }
        return .clear
    }

    private var border: Color {
        guard isEnabled else { return .clear }
        if isPressed { return .white.opacity(0.70) }
        if isHovering { return .white.opacity(0.45) }
        if isSelected { return Color.accentColor }
        return .clear
    }

    /// Selection and press are drawn thicker as well as brighter.
    ///
    /// Colour alone is not enough on a reading screen: the room is dim, the
    /// display is calibrated for grey, and a reader may not distinguish the
    /// accent from white at a hairline width. The extra half-point gives the
    /// state a second, non-colour cue — which is also what makes it legible to
    /// anyone who does not separate those hues.
    private var borderWidth: CGFloat {
        guard isEnabled else { return 1 }
        if isPressed { return 2 }
        if isSelected { return 2 }
        if isHovering { return 1.5 }
        return 1
    }
}

/// Reports the mouse-down window, or nothing at all when switched off.
///
/// Split out as its own modifier rather than a `.simultaneousGesture` applied
/// conditionally in a ternary, because the two branches of a ternary over a
/// gesture produce different view types and SwiftUI would rebuild the subtree —
/// and the caller's own gestures with it — every time the flag was read.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct PressTracking: ViewModifier {

    @Binding var isPressed: Bool

    let isActive: Bool

    func body(content: Content) -> some View {
        // Ordered simultaneous so it never consumes the event: it has no action,
        // so the caller's own tap and the button's action still fire. That holds
        // for a button, which recognises a click rather than a drag; it does not
        // hold for a `.draggable` caller, which is why `isActive` exists.
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isActive && !isPressed { isPressed = true } }
                .onEnded { _ in if isActive { isPressed = false } },
            including: isActive ? .all : .subviews
        )
    }
}

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension View {

    /// Hover and press states for a discrete control — a glyph, chip or badge.
    ///
    /// - Parameters:
    ///   - cornerRadius: Rounding of the fill. Match the control's own shape;
    ///     a capsule-shaped badge wants something near half its height.
    ///   - horizontal: Room the fill takes either side of the control.
    ///   - vertical: Room above and below.
    ///   - isEnabled: False leaves the control bare — see `InteractiveSurface`.
    ///   - isSelected: True draws the armed/current state at rest. Defaults to
    ///     false, so every existing caller is unchanged.
    ///   - tracksPress: False for a caller that owns the drag gesture itself —
    ///     a `.draggable` card, a pannable tile. See `InteractiveSurface`.
    ///   - extendsHitArea: False for a caller whose own `contentShape` must
    ///     survive. See ``InteractiveSurface/extendsHitArea``.
    ///   - isInset: True to draw the highlight inside the control's own bounds
    ///     instead of growing it. Required inside a macOS toolbar group, whose
    ///     bezel a grown item spills out of.
    func interactiveControl(
        cornerRadius: CGFloat = 6,
        horizontal: CGFloat = 6,
        vertical: CGFloat = 4,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        tracksPress: Bool = true,
        isInset: Bool = false,
        extendsHitArea: Bool = true
    ) -> some View {
        modifier(InteractiveSurface(
            cornerRadius: cornerRadius,
            padding: EdgeInsets(top: vertical, leading: horizontal,
                                bottom: vertical, trailing: horizontal),
            isEnabled: isEnabled,
            isSelected: isSelected,
            tracksPress: tracksPress,
            isInset: isInset,
            extendsHitArea: extendsHitArea))
    }

    /// Hover and press states for a full-width row in a list.
    ///
    /// No padding of its own: a row has already been padded to its own metrics,
    /// and adding more here would make the rows taller than the list was laid
    /// out for.
    func interactiveRow(
        cornerRadius: CGFloat = 5,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        tracksPress: Bool = true,
        extendsHitArea: Bool = true
    ) -> some View {
        modifier(InteractiveSurface(
            cornerRadius: cornerRadius,
            padding: EdgeInsets(),
            isEnabled: isEnabled,
            isSelected: isSelected,
            tracksPress: tracksPress,
            isInset: false,
            extendsHitArea: extendsHitArea))
    }
}
#endif
