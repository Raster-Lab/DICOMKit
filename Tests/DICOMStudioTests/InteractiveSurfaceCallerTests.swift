// InteractiveSurfaceCallerTests.swift
// DICOMStudioTests
//
// The `.interactiveControl` / `.interactiveRow` caller contract, held to the
// source itself.
//
// Why a source test rather than a behavioural one: what keeps breaking here is
// SwiftUI hit testing and AppKit layering, which a unit test cannot observe —
// there is no view hierarchy to click in this target, and every one of the
// three regressions this file exists to prevent compiled cleanly and passed the
// whole suite. Three times a change made to suit one caller silently broke
// another: the series card's fix removed the stamped hit shape that the
// saved-views popover's rows depended on, and clicking a row stopped applying
// the view.
//
// What CAN be checked is that the callers whose requirements are known are
// still configured the way their requirement demands. That is a real guard: it
// fails the moment someone "tidies up" one of these flags or changes a default
// without walking the call sites, which is exactly how each regression arrived.
//
// See the caller contract at the top of `Components/InteractiveSurface.swift`.

import Testing
import Foundation

@Suite("Interactive Surface Caller Tests")
struct InteractiveSurfaceCallerTests {

    // MARK: - Reading the sources

    /// The package's `Sources` directory, found by walking up from this file.
    private static var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)          // …/Tests/DICOMStudioTests/this.swift
            .deletingLastPathComponent()          // …/Tests/DICOMStudioTests
            .deletingLastPathComponent()          // …/Tests
            .deletingLastPathComponent()          // package root
            .appendingPathComponent("Sources/DICOMStudio")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = Self.sourcesRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every `.swift` file under `Sources/DICOMStudio`, with its path.
    private func allSources() throws -> [(path: String, text: String)] {
        let root = Self.sourcesRoot
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil) else { return [] }
        var found: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            found.append((url.lastPathComponent, text))
        }
        return found
    }

    // MARK: - Question 1: who owns the drag gesture

    @Test("The series card keeps press tracking off — it owns the drag")
    func seriesCardDoesNotTrackPress() throws {
        // The card is `.draggable`, so a second zero-distance DragGesture under
        // it claims the pointer-down sequence and the card's own tap never
        // fires — which stopped a click from hanging the series.
        let text = try source("Views/ViewerSeriesPaneView.swift")
        #expect(text.contains(".draggable("),
                "if the card stopped being draggable, revisit tracksPress")
        #expect(text.contains("tracksPress: false"),
                "a draggable caller must not also carry the press gesture")
    }

    // MARK: - Question 2: whose hit shape wins

    @Test("The series card keeps its own hit shape")
    func seriesCardKeepsItsOwnHitShape() throws {
        // The whole card is the target, corners included; a rounded stamp over
        // it would trim them.
        let text = try source("Views/ViewerSeriesPaneView.swift")
        #expect(text.contains("extendsHitArea: false"))
    }

    @Test("List rows keep the stamped hit area — an HStack is only as wide as its content")
    func listRowsKeepTheStampedHitArea() throws {
        // These rows are an HStack inside a Button. Without a shape spanning the
        // row, a click in the empty space right of a short label falls through
        // and selects nothing — which is exactly what broke the saved-views
        // popover. None of them may opt out.
        // Not SavedViewPickerView: its on-image list has moved out to
        // `ViewerImageSavedViewList`, which draws its own rows and hover and
        // is covered by `badgeListIsSelfContained` instead. What is left in
        // that file is the toolbar picker's menu, which has no such rows.
        for path in ["Views/SavedViewPromptView.swift",
                     "Views/Print/FilmLayoutGalleryView.swift"] {
            let text = try source(path)
            #expect(text.contains("interactiveRow("),
                    "\(path) is expected to carry list rows")
            #expect(!text.contains("extendsHitArea: false"),
                    "\(path)'s rows depend on the stamped hit area")
        }
    }

    // MARK: - Question 3: the toolbar

    @Test("Toolbar-resident controls are inset, so the highlight stays in the bezel")
    func toolbarControlsAreInset() throws {
        // A ToolbarItemGroup lays its items to a fixed metric inside one shared
        // bezel; a highlight that grows the item draws over that bezel and the
        // neighbouring group.
        let viewer = try source("Views/ImageViewerView.swift")
        #expect(viewer.contains("isSelected: isActive, isInset: true"),
                "the armed drag-tool glyph must be inset")

        // The saved-view pair sits in the toolbar too, and satisfies the same
        // requirement without this modifier: both halves draw their own capsule
        // and light *that* on hover, which is inside their own bounds by
        // construction. What must not come back is a plate that grows the item
        // — an `interactiveControl` here without `isInset` is exactly that, and
        // it would also be a second, differently-shaped highlight a few points
        // from a capsule that already has one.
        let picker = try source("Views/SavedViewPickerView.swift")
        if picker.contains("interactiveControl(") {
            #expect(picker.contains("isInset: true"),
                    "a plate-drawn control in the saved-view toolbar pair must be inset")
        }
        #expect(picker.contains("in: Capsule())"),
                "the saved-view pair draws its own capsule, which is what lights on hover")
    }

    @Test("An inset control uses a small padding, or the plate is smaller than its glyph")
    func insetControlsUseSmallPadding() throws {
        // Inset takes the padding *out* of the item's bounds, so the rail's
        // 5×4 would leave the plate smaller than the icon it sits behind.
        for (path, text) in try allSources() {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false)
            where line.contains("isInset: true") {
                // The call may wrap, so the padding is checked on the whole
                // statement rather than on this one line.
                guard let range = text.range(of: String(line)) else { continue }
                let start = text.range(of: "interactiveControl(",
                                       options: .backwards,
                                       range: text.startIndex..<range.upperBound)
                guard let start else { continue }
                let call = String(text[start.lowerBound..<range.upperBound])
                #expect(call.contains("horizontal: 1") && call.contains("vertical: 1"),
                        "\(path): an inset control wants a 1-point plate inset, got: \(call)")
            }
        }
    }

    // MARK: - The badge's list closes through its owner's binding

    @Test("The badge's list is self-contained and closes via its caller")
    func badgeListIsSelfContained() throws {
        // The list must stay its own view (`ViewerImageSavedViewList`) and
        // borrow nothing: shared modifiers cost it its hit area once, and
        // `@Environment(.dismiss)` cannot clear an `isPresented` a caller owns
        // — the row applied its view and the list stood open over the changed
        // image, indistinguishable from a dead click.
        let list = try source("Views/ViewerImageSavedViewList.swift")
        let code = list
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        #expect(code.contains("let close: () -> Void"),
                "the list must take a close action from whoever presents it")
        #expect(!code.contains("Environment(\\.dismiss)"),
                "@Environment(.dismiss) cannot close a caller-owned popover")
        #expect(!code.contains("dismiss()"),
                "rows must call close(), which clears the presenter's own binding")
        #expect(!code.contains(".interactiveRow(") && !code.contains(".interactiveControl("),
                "the list draws its own hover so no other screen's fix reaches it")
        #expect(code.contains("byHand: true"),
                "a row's apply must be by-hand, or a series view lands on one slice")

        // Both presenters pass a closure clearing their own binding, checked
        // on the construction site itself — the tile grid clears its state
        // from onChange handlers too, so a file-wide search proves nothing.
        for (path, clears) in [
            ("Views/ImageViewerView.swift", "isSavedViewListPresented = false"),
            ("Views/ViewerTileGridView.swift", "savedViewListTile = nil")
        ] {
            let text = try source(path)
            guard let call = text.range(of: "ViewerImageSavedViewList(viewModel: viewModel)")
            else {
                Issue.record("\(path) does not present ViewerImageSavedViewList")
                continue
            }
            let tail = String(text[call.upperBound...].prefix(120))
            #expect(tail.contains(clears),
                    "\(path) must close the list by clearing its own binding")
        }
    }

    @Test("Arrival applies the first PR itself — the ask-first sheet stays held")
    func arrivalAppliesWithoutTheSheet() throws {
        // "Load the first PR by default": `offerSavedViewsIfNeeded` applies
        // the cycle's head instead of raising the "A saved view exists" sheet,
        // which put a dialog between the reader and the picture on every
        // arrival. The badge's list is the way to change the reading.
        let vm = try source("ViewModels/ImageViewerViewModel+PresentationStates.swift")
        #expect(!vm.contains("savedViewPrompt = SavedViewPrompt("),
                "nothing may raise the arrival sheet")
        let viewer = try source("Views/ImageViewerView.swift")
        #expect(!viewer.contains("SavedViewPromptView(viewModel:"),
                "the arrival sheet stays un-wired")
    }

    // MARK: - The contract itself

    @Test("The caller contract is still documented where the switches live")
    func theContractIsDocumented() throws {
        // The comment block is the thing that makes the switches legible. It
        // has earned its place three times over; losing it in a tidy-up is how
        // the fourth regression would arrive.
        let text = try source("Components/InteractiveSurface.swift")
        #expect(text.contains("The caller contract"))
        for switchName in ["tracksPress", "extendsHitArea", "isInset"] {
            #expect(text.contains(switchName),
                    "\(switchName) must stay described in the contract")
        }
    }
}
