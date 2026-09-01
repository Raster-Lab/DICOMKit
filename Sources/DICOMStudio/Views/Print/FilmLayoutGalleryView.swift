// FilmLayoutGalleryView.swift
// DICOMStudio
//
// DICOM Studio — picking the film's grid by looking at it.
//
// A layout is a shape, and a shape is chosen faster from a picture of it than
// from a line of text in a pop-up menu: "3×4" and "4×3" read alike in a list and
// are unmistakable as two drawings. The gallery is also where the two grids that
// are not a fixed choice live — the viewer's own grid, and the automatic one —
// so every answer to "how is this film laid out" is in one place.
//
// That includes the layouts a grid cannot state. The bands of PS3.3 C.13.3 —
// one image over two, one beside two columns of four — are drawn here as the
// films they are, and the format they send is left in the custom field below
// them so the chosen layout can be read as a string and adjusted from there.

#if canImport(SwiftUI)
import SwiftUI
import DICOMNetwork
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmLayoutGalleryView: View {
    @Bindable var viewModel: PrintViewModel

    /// Raised so picking a layout puts the gallery away, as picking from a menu
    /// would — the film behind it is the thing being judged.
    @Binding var isPresented: Bool

    var body: some View {
        // Scrolls rather than growing past the screen: the grids, the bands, the
        // custom field and the presets together are taller than a short display.
        ScrollView {
            gallery
        }
        .frame(width: 280)
        .frame(maxHeight: 560)
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Layout")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // The two grids that follow something rather than being chosen.
            HStack(spacing: 6) {
                automaticTile(
                    mode: .matchViewer,
                    title: "Viewer",
                    symbol: "rectangle.split.2x2",
                    help: viewModel.viewerLayout.map {
                        "Match the viewer's \($0.rows)×\($0.columns) grid"
                    } ?? "No viewer grid — falls back to automatic")
                    .disabled(viewModel.viewerLayout == nil)
                automaticTile(
                    mode: .automatic,
                    title: "Auto",
                    symbol: "wand.and.stars",
                    help: "Grid chosen to fit \(viewModel.selection.count) image(s)")
            }

            Divider()

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.tileSize), spacing: 6),
                                     count: 4),
                      spacing: 8) {
                ForEach(PrintLayoutOption.allCases) { option in
                    layoutTile(option)
                }
            }

            Divider()
            bandSection

            Divider()
            customSection

            if !PrintTemplatePreset.allCases.isEmpty {
                Divider()
                Text("Presets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                // A preset carries its own film size and orientation, so it is
                // named rather than drawn: the drawing would not be the whole
                // truth about what it does.
                ForEach(PrintTemplatePreset.allCases) { preset in
                    Button {
                        viewModel.templatePreset = preset
                        viewModel.layoutMode = .template
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: viewModel.layoutMode == .template
                                  && viewModel.templatePreset == preset
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(.secondary)
                            Text(preset.displayName)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .interactiveRow()
                }
            }
        }
        .padding(12)
    }

    // MARK: - Bands

    /// The named band layouts, drawn as the films they are.
    ///
    /// They are chosen the same way the grids are — by looking at them — and
    /// picking one fills the custom field with its format, so the layout that is
    /// in force is always visible as the string that will be sent, and can be
    /// adjusted from there without starting over.
    @ViewBuilder
    private var bandSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bands")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                     count: 3),
                      spacing: 8) {
                ForEach(PrintBandLayout.allCases) { band in
                    bandTile(band)
                }
            }
        }
    }

    /// One named band layout.
    private func bandTile(_ band: PrintBandLayout) -> some View {
        let isCurrent = viewModel.layoutMode == .custom
            && viewModel.customLayoutText == band.imageDisplayFormat
        return Button {
            viewModel.customLayoutText = band.imageDisplayFormat
            viewModel.layoutMode = .custom
            isPresented = false
        } label: {
            VStack(spacing: 3) {
                FilmLayoutThumbnail(format: band.displayFormat)
                    .frame(width: Self.tileSize, height: Self.tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isCurrent ? Color.accentColor : .secondary.opacity(0.35),
                                          lineWidth: isCurrent ? 2 : 1)
                    )
                Text(band.imageDisplayFormat)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .interactiveControl(cornerRadius: 6, horizontal: 3, vertical: 3)
        // `.railTooltip`, not `.help` — a plain button's tooltip lands on a
        // wrapper the pointer never enters. See `railTooltip`.
        .railTooltip("\(band.displayName) — \(band.displayFormat.summary)")
        .accessibilityLabel("\(band.displayName), \(band.cellCount) images")
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    // MARK: - Custom format

    /// The layouts a grid cannot state, written as the standard states them.
    ///
    /// PS3.3 C.13.3 lets a film's rows hold different numbers of images —
    /// `ROW\1,2` is one image over two, the shape a scout above its slices takes.
    /// There is no grid for that, so the format itself is the control, with the
    /// film it describes drawn beside it as it is typed.
    @ViewBuilder
    private var customSection: some View {
        let format = viewModel.customLayoutFormat
        let isCurrent = viewModel.layoutMode == .custom

        VStack(alignment: .leading, spacing: 6) {
            Text("Custom")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                FilmLayoutThumbnail(format: format)
                    .frame(width: Self.tileSize, height: Self.tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isCurrent && format != nil
                                          ? Color.accentColor : .secondary.opacity(0.35),
                                          lineWidth: isCurrent && format != nil ? 2 : 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    TextField("ROW\\2,1,2", text: $viewModel.customLayoutText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .onSubmit { useCustomFormat() }
                        .accessibilityLabel("Image Display Format")

                    Text(format?.summary ?? "Not an Image Display Format")
                        .font(.caption2)
                        .foregroundStyle(format == nil ? Color.red : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 6) {
                Text("Any Image Display Format — ROW\\, COL\\ or STANDARD\\")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button("Use") { useCustomFormat() }
                    .font(.caption)
                    .disabled(format == nil)
            }
        }
    }

    /// Adopts what is in the field, if it is a layout.
    private func useCustomFormat() {
        guard viewModel.customLayoutFormat != nil else { return }
        viewModel.layoutMode = .custom
        isPresented = false
    }

    // MARK: - Tiles

    /// One fixed grid, drawn as the grid it is.
    private func layoutTile(_ option: PrintLayoutOption) -> some View {
        let isCurrent = viewModel.layoutMode == .explicit && viewModel.layoutOption == option
        return Button {
            viewModel.layoutOption = option
            viewModel.layoutMode = .explicit
            isPresented = false
        } label: {
            VStack(spacing: 3) {
                FilmLayoutThumbnail(format: PrintImageDisplayFormat(layout: option.layout))
                    .frame(width: Self.tileSize, height: Self.tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isCurrent ? Color.accentColor : .secondary.opacity(0.35),
                                          lineWidth: isCurrent ? 2 : 1)
                    )
                Text("\(option.layout.rows)×\(option.layout.columns)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .interactiveControl(cornerRadius: 6, horizontal: 3, vertical: 3)
        .railTooltip(option.displayName)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    /// A grid that follows something: the viewer, or the number of marks.
    private func automaticTile(
        mode: PrintViewModel.LayoutMode, title: String, symbol: String, help: String
    ) -> some View {
        let isCurrent = viewModel.layoutMode == mode
        return Button {
            viewModel.layoutMode = mode
            isPresented = false
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(isCurrent ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .interactiveControl(cornerRadius: 7, horizontal: 2, vertical: 2)
        .railTooltip(help)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    private static let tileSize: CGFloat = 52
}

// MARK: - Layout thumbnail

/// A miniature of a film: its cells, where the film puts them.
///
/// Drawn from ``FilmCellLayout`` — the same code that lays out a film for
/// printing — so a band layout is drawn as the bands it is rather than as the
/// bounding grid it is not. An empty format (text that is not one) draws an
/// empty sheet.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmLayoutThumbnail: View {
    let format: PrintImageDisplayFormat?

    var body: some View {
        GeometryReader { geo in
            let cells = format.map {
                FilmCellLayout.cells(
                    for: $0,
                    on: FilmSheet(widthMillimeters: max(1, geo.size.width),
                                  heightMillimeters: max(1, geo.size.height),
                                  dpi: 25.4),
                    marginMillimeters: 1.5, spacingMillimeters: 1.5)
            } ?? []
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.35)
                ForEach(cells, id: \.position) { cell in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: max(1, cell.width), height: max(1, cell.height))
                        .offset(x: cell.x, y: cell.y)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }
}
#endif
