// ViewerPalettePickerView.swift
// DICOMStudio
//
// DICOM Studio — choosing the viewer's pseudo-colour palette.
//
// A palette is a display choice over the *windowed* grey: the stored pixels are
// untouched, and the same measurement under two palettes is one measurement seen
// two ways. The picker shows each palette as the ramp it actually is rather than
// as its name alone — "Hot Metal Blue" and "Hot Iron" are two names that sound
// alike and look nothing alike, and a reader choosing a colour scale for uptake
// is choosing the picture, not the word.

#if canImport(SwiftUI)
import SwiftUI
import DICOMCore

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerPalettePickerView: View {
    @Bindable var viewModel: ImageViewerViewModel

    var body: some View {
        Menu {
            // "No colour" is first and separate: it is the way back, and a
            // reader who has coloured an image by accident should not have to
            // read a list of twenty to undo it.
            Button {
                viewModel.applyPalette(nil)
            } label: {
                if viewModel.palette == nil {
                    Label("None (grayscale)", systemImage: "checkmark")
                } else {
                    Text("None (grayscale)")
                }
            }

            // Grouped, because the list is long and the groups are the part that
            // matters: the DICOM heading is a promise that those eight mean the
            // same thing on any conforming system, which none of the others can
            // make. Same catalogue the print sheet offers, in the same order —
            // a palette chosen in the viewer and one chosen on the film are the
            // same list, so they cannot drift apart.
            ForEach(DICOMCore.PseudoColorPalette.catalog, id: \.group) { entry in
                Section(entry.group.title) {
                    ForEach(entry.palettes, id: \.self) { palette in
                        Button {
                            viewModel.applyPalette(palette)
                        } label: {
                            if palette == viewModel.palette {
                                Label(palette.displayName, systemImage: "checkmark")
                            } else {
                                Text(palette.displayName)
                            }
                        }
                    }
                }
            }
        } label: {
            label
        }
        // Available for every image the viewer can show, whatever the file says
        // it is made of. A ramp over a monochrome frame folds into the window;
        // a ramp over a frame that carries its own colours — an ultrasound's
        // YBR samples, a palette-colour frame's own table — is applied to that
        // frame's luminance instead. Both are the same display choice, and
        // neither touches the stored pixels, so there is no file for which the
        // control is meaningless and none for which it should be withheld.
        //
        // The control used to grey out on `carriesOwnColor`, which was honest
        // while the renderers discarded the palette for such a frame; they no
        // longer do. See `FrameRenderRequest.readerPalette`.
        .disabled(!viewModel.hasImage)
        .accessibilityLabel(accessibilityLabel)
        .help(helpText)
    }

    /// The toolbar face: the ramp and the palette's name, or the grey icon and
    /// "No CLUT" when the image is being read in plain grey.
    ///
    /// The name is drawn as its own `Text` in an `HStack` rather than handed to
    /// a `Label`'s title. A `Menu` inside a `ToolbarItemGroup` collapses a
    /// `Label` to its icon — which is why the name never appeared, however the
    /// palette was chosen — and no label style asks it not to. Building the row
    /// out of a swatch and a `Text` gives the toolbar nothing to collapse, so
    /// what the reader chose stays legible.
    ///
    /// Showing the ramp *and* the name answers two different questions: the
    /// ramp says "which colours" from across the room, which on a grid where
    /// one tile is a PET and the rest are CT is what is actually being asked,
    /// and the name settles "Hot Metal Blue" against "Hot Iron" — two names
    /// that sound alike, look nothing alike, and are quoted in reports by name.
    ///
    /// The grey state names itself too. A bare `paintpalette` glyph says "there
    /// is a palette control here" but not "and it is off", and a reader who has
    /// coloured an image by accident is looking for exactly that. "No CLUT" is
    /// the reader's own wording for it, kept rather than paraphrased — the
    /// menu's clearing row still reads "None (grayscale)", which describes the
    /// result, where the face has to describe the state in two words.
    @ViewBuilder
    private var label: some View {
        HStack(spacing: 5) {
            if let palette = rampPalette {
                PaletteRampSwatch(palette: palette, showsGlyph: true)
            } else {
                Image(systemName: "paintpalette")
                    // Matched to the swatch's box, so the face keeps one width
                    // whichever state it is in and the items either side of it
                    // do not shift as a palette is chosen and cleared.
                    .frame(width: 17, height: 17)
            }

            Text(faceText)
                .font(.system(size: StudioTypography.captionSize, weight: .medium))
                .lineLimit(1)
                // Shortened in the string rather than by a truncating frame —
                // see `savedViewsBadgeText` in `ImageViewerView` for the same
                // reasoning: a max-width frame is greedy and takes its full
                // width whatever the text, leaving a short name adrift at the
                // left of a long gap.
                .fixedSize()
        }
        // The name is decoration over the swatch, which already carries the
        // answer; keeping it secondary stops the toolbar's longest word from
        // being the loudest thing in a row of glyphs.
        .foregroundStyle(namedPalette == nil ? Color.secondary : Color.primary)
    }

    /// The palette the reader chose, whether or not it recolours anything.
    ///
    /// Deliberately `viewModel.palette` and not `isPseudoColored`, which is
    /// false for Grayscale and Inverse Grayscale — those leave the frame grey
    /// but are chosen CLUTs all the same. Naming them "No CLUT" would report a
    /// choice the reader made as no choice at all, and would disagree with the
    /// menu standing open beside it, which puts its checkmark on the row they
    /// picked. Clearing the palette is a separate action with a separate
    /// result, so the face has to be able to tell the two apart.
    ///
    /// The ramp still follows what is on the picture — see ``rampPalette``.
    private var namedPalette: DICOMCore.PseudoColorPalette? { viewModel.palette }

    /// The palette to draw as a ramp, or nil to draw the plain glyph.
    ///
    /// This one *does* test `isPseudoColored`: a swatch is a picture of what
    /// the image is being coloured in, and a grey palette colours it in
    /// nothing. Drawing a black-to-white ramp there would claim a recolouring
    /// the renderer did not perform.
    private var rampPalette: DICOMCore.PseudoColorPalette? {
        viewModel.isPseudoColored ? viewModel.palette : nil
    }

    /// What the face says: the palette's name, or "No CLUT".
    private var faceText: String { Self.faceText(for: namedPalette) }

    /// What the toolbar face says for a given palette, or for none.
    ///
    /// A static over the palette rather than a computed property over the view
    /// model, so the wording is pinned by a test without standing a viewer up
    /// around it — the string is what the reader reads and quotes, and it is
    /// the part of this control most likely to be changed by accident.
    static func faceText(for palette: DICOMCore.PseudoColorPalette?) -> String {
        guard let palette else { return noPaletteLabel }
        let name = palette.displayName
        guard name.count > nameCap else { return name }
        return name.prefix(nameCap - 1) + "…"
    }

    /// What the face says when no palette is applied.
    static let noPaletteLabel = "No CLUT"

    /// How long a palette name may run on the toolbar before it is shortened.
    ///
    /// Set by the catalogue rather than by taste: its longest name is "Inverse
    /// Grayscale" at seventeen characters, so eighteen shows every shipped
    /// palette whole and the shortening only ever bites on a name longer than
    /// anything in the catalogue today. `everyCatalogueNameFitsTheToolbarFace`
    /// pins that, so adding a longer palette fails a test rather than quietly
    /// putting an ellipsis on the toolbar.
    static let nameCap = 18

    private var accessibilityLabel: String {
        guard let palette = namedPalette else { return "Colour palette, no CLUT" }
        return "Colour palette, currently \(palette.displayName)"
    }

    private var helpText: String {
        // One sentence for every image, because the control now behaves the same
        // way on every image. What differs underneath — a ramp folded into the
        // window for grey pixels, a ramp over luminance for pixels that carry
        // their own colours — is not a difference the reader acts on.
        if viewModel.carriesOwnColor {
            return "Pseudo-colour palette — this image carries its own colours, "
                + "so the palette recolours it by brightness. The stored pixels "
                + "are unchanged, and the choice travels to the film with the mark."
        }
        return "Pseudo-colour palette — recolours the windowed grey without "
            + "changing the stored pixels. The choice travels to the film with "
            + "the mark."
    }
}

// MARK: - Ramp swatch

/// A palette drawn as the ramp it is, left (black) to right (full).
///
/// Built from the palette's own ``PseudoColorPalette/entries()`` rather than
/// from a hand-picked pair of endpoint colours, so the swatch cannot drift from
/// what the renderer produces — a gradient guessed at from two ends would show
/// Hot Metal Blue's blue mid-band as a straight red-to-white fade and claim a
/// palette the image will not be drawn in.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PaletteRampSwatch: View {
    let palette: DICOMCore.PseudoColorPalette

    /// How many stops the gradient is drawn with.
    ///
    /// The palette has 256; a swatch is a few dozen points wide, so sampling
    /// every eighth entry is indistinguishable on screen and builds a gradient
    /// SwiftUI can interpolate cheaply as the menu scrolls.
    private static let stopCount = 32

    /// Whether the palette glyph is drawn over the ramp.
    ///
    /// The menu rows want the ramp alone — they already carry the palette's name
    /// beside it, and twenty rows each stamped with the same symbol is noise. The
    /// toolbar face wants the glyph, because that is the form that has to survive
    /// being shown without its text.
    var showsGlyph: Bool = false

    var body: some View {
        if showsGlyph {
            // Sized to a toolbar icon rather than to a menu row's swatch, and
            // square: this is the form the toolbar falls back to when it drops
            // the label, so it has to hold its own as an icon.
            ramp(cornerRadius: 3)
                .frame(width: 17, height: 17)
                .overlay(
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10, weight: .semibold))
                        // Both colours, so the glyph stays legible over a ramp
                        // that may be light at one end and dark at the other.
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 1)
                )
                .accessibilityHidden(true)
        } else {
            ramp(cornerRadius: 2)
                .frame(width: 28, height: 12)
                .accessibilityHidden(true)
        }
    }

    /// The gradient rectangle both forms are built on.
    private func ramp(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(
                colors: Self.stops(for: palette),
                startPoint: .leading,
                endPoint: .trailing))
            // Hairline: the ramps that end in black or white would otherwise
            // have no edge against a dark or a light menu.
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
    }

    /// The gradient stops for a palette, sampled from its own table.
    static func stops(for palette: DICOMCore.PseudoColorPalette) -> [Color] {
        let entries = palette.entries()
        guard !entries.isEmpty else { return [.black, .white] }
        let step = max(1, entries.count / stopCount)
        return stride(from: 0, to: entries.count, by: step).map { index in
            let entry = entries[index]
            return Color(
                red: Double(entry.red) / 255.0,
                green: Double(entry.green) / 255.0,
                blue: Double(entry.blue) / 255.0)
        }
    }
}
#endif
