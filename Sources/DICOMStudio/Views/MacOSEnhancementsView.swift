// MacOSEnhancementsView.swift
// DICOMStudio
//
// DICOM Studio — macOS-Specific Enhancements view (Milestone 14)

#if canImport(SwiftUI)
import SwiftUI

/// View for macOS-specific enhancements: multi-window, menu bar, keyboard shortcuts,
/// dock integration, automation, and Quick Look support.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct MacOSEnhancementsView: View {
    @Bindable var viewModel: MacOSEnhancementsViewModel

    public init(viewModel: MacOSEnhancementsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(MacOSEnhancementsTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.activeTab = tab
                    } label: {
                        Label(tab.displayName, systemImage: tab.sfSymbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .multiWindow:
            multiWindowContent
        case .menuBar:
            menuBarContent
        case .keyboardShortcuts:
            keyboardShortcutsContent
        case .dockIntegration:
            dockIntegrationContent
        case .automation:
            automationContent
        case .quickLook:
            quickLookContent
        }
    }

    // MARK: - 14.1 Multi-Window

    private var multiWindowContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Multi-Window Management")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.openWindow(studyInstanceUID: UUID().uuidString)
                } label: {
                    Label("New Window", systemImage: "plus")
                }
                .accessibilityLabel("Open new viewer window")
            }
            .padding()

            if viewModel.isDragOperationActive, let drag = viewModel.pendingDragOperation {
                HStack {
                    Image(systemName: "hand.draw")
                    Text("Dragging frame \(drag.frameIndex) from SOP \(drag.sopInstanceUID.prefix(8))…")
                        .font(.caption)
                    Button("Cancel") {
                        viewModel.completeDragOperation()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            if viewModel.openWindows.isEmpty {
                ContentUnavailableView(
                    "No Windows Open",
                    systemImage: "macwindow",
                    description: Text("Open a new window to start viewing DICOM studies.")
                )
            } else {
                List {
                    ForEach(viewModel.openWindows) { window in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(window.title)
                                    .font(.body.bold())
                                Text("Study: \(window.studyInstanceUID.prefix(16))…")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    if window.isFullscreen {
                                        Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption2)
                                    }
                                    if window.isMiniaturized {
                                        Label("Minimized", systemImage: "arrow.down.right.and.arrow.up.left")
                                            .font(.caption2)
                                    }
                                    Text("Focused: \(window.lastFocused.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.focusWindow(id: window.id)
                            } label: {
                                Image(systemName: "macwindow")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Focus window \(window.title)")

                            Button(role: .destructive) {
                                viewModel.closeWindow(id: window.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close window \(window.title)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 14.2 Menu Bar

    private var menuBarContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Menu Bar Configuration")
                    .font(.headline)
                Spacer()
                Picker("Category", selection: $viewModel.selectedMenuCategory) {
                    ForEach(MenuCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .frame(width: 140)
                .accessibilityLabel("Menu category")
            }
            .padding()
            Divider()

            let filtered = viewModel.filteredMenuActions()
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Menu Actions",
                    systemImage: "menubar.rectangle",
                    description: Text("No actions in the \(viewModel.selectedMenuCategory.displayName) category.")
                )
            } else {
                List(filtered) { action in
                    if action.isSeparator {
                        Divider()
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(.body)
                                Text(action.actionIdentifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !action.keyboardShortcut.isEmpty {
                                Text(action.keyboardShortcut)
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Toggle("Enabled", isOn: Binding(
                                get: { action.isEnabled },
                                set: { _ in viewModel.toggleMenuAction(id: action.id) }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("Toggle \(action.title)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 14.3 Keyboard Shortcuts

    private var keyboardShortcutsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Picker("Scope", selection: Binding(
                    get: { viewModel.shortcutScopeFilter ?? .global },
                    set: { viewModel.updateScopeFilter($0) }
                )) {
                    ForEach(KeyboardShortcutScope.allCases, id: \.self) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .frame(width: 140)
                .accessibilityLabel("Shortcut scope filter")

                Button("Reset Defaults") {
                    viewModel.resetShortcutsToDefault()
                }
                .accessibilityLabel("Reset shortcuts to defaults")
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shortcuts…", text: Binding(
                    get: { viewModel.shortcutSearchQuery },
                    set: { viewModel.updateShortcutQuery($0) }
                ))
                .textFieldStyle(.plain)
                .accessibilityLabel("Search shortcuts")
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            Divider()

            let filtered = viewModel.filteredShortcuts()
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Shortcuts Found",
                    systemImage: "keyboard",
                    description: Text("Try adjusting the search query or scope filter.")
                )
            } else {
                List(filtered, selection: Binding(
                    get: { viewModel.selectedShortcutEntry?.id },
                    set: { newID in
                        viewModel.selectShortcut(filtered.first { $0.id == newID })
                    }
                )) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action)
                                .font(.body)
                            Text(entry.scope.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.shortcut)
                            .font(.body.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        if entry.isCustomizable {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(entry.action): \(entry.shortcut)")
                }
            }
        }
    }

    // MARK: - 14.4 Dock Integration

    private var dockIntegrationContent: some View {
        VStack(spacing: 16) {
            Text("Dock Integration")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            GroupBox("Dock Badge") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Active Transfers")
                            .font(.body)
                        Spacer()
                        Text("\(viewModel.dockBadgeState.transferCount)")
                            .font(.title2.bold().monospaced())
                    }
                    HStack {
                        Text("Badge Visible")
                        Spacer()
                        Toggle("Badge Visible", isOn: Binding(
                            get: { viewModel.dockBadgeState.isVisible },
                            set: { _ in viewModel.toggleBadgeVisibility() }
                        ))
                        .labelsHidden()
                    }
                    HStack {
                        Text("Badge Label")
                        Spacer()
                        Text(viewModel.dockBadgeState.badgeLabel.isEmpty ? "—" : viewModel.dockBadgeState.badgeLabel)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Increment") {
                            viewModel.updateTransferCount(viewModel.dockBadgeState.transferCount + 1)
                        }
                        .accessibilityLabel("Increment transfer count")
                        Button("Reset") {
                            viewModel.updateTransferCount(0)
                        }
                        .accessibilityLabel("Reset transfer count")
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - 14.5 Automation

    private var automationContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Automation Scripts")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.automationScripts.count) scripts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            Divider()

            if viewModel.automationScripts.isEmpty {
                ContentUnavailableView(
                    "No Scripts",
                    systemImage: "applescript",
                    description: Text("Automation scripts for DICOMKit workflows.")
                )
            } else {
                List(viewModel.automationScripts, selection: $viewModel.selectedScriptID) { script in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(script.name, systemImage: script.scriptType.sfSymbol)
                                .font(.body.bold())
                            Spacer()
                            Text(script.scriptType.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        Text(script.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if viewModel.selectedScriptID == script.id {
                            GroupBox("Script Preview") {
                                ScrollView(.horizontal) {
                                    Text(script.sampleScript)
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 120)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 14.6 Quick Look

    private var quickLookContent: some View {
        VStack(spacing: 16) {
            Text("Quick Look Plugin")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            GroupBox("Plugin Status") {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: viewModel.quickLookState.status.sfSymbol)
                            .font(.title)
                            .foregroundStyle(statusColor(for: viewModel.quickLookState.status))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.quickLookState.status.displayName)
                                .font(.body.bold())
                            Text(viewModel.quickLookState.status.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider()

                    HStack {
                        Text("Supported Extensions")
                        Spacer()
                        Text(viewModel.quickLookState.supportedExtensions.joined(separator: ", "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Thumbnail Cache")
                        Spacer()
                        Text("\(viewModel.quickLookState.thumbnailCacheCount) items")
                            .font(.body.monospaced())
                    }

                    if let lastRefresh = viewModel.quickLookState.lastRefreshDate {
                        HStack {
                            Text("Last Refresh")
                            Spacer()
                            Text(lastRefresh.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Button("Refresh Cache") {
                            viewModel.incrementThumbnailCache()
                        }
                        .accessibilityLabel("Refresh thumbnail cache")
                        Button("Clear Cache") {
                            viewModel.clearThumbnailCache()
                        }
                        .accessibilityLabel("Clear thumbnail cache")
                        Spacer()
                        Menu("Set Status") {
                            ForEach(QuickLookPluginStatus.allCases, id: \.self) { s in
                                Button(s.displayName) {
                                    viewModel.updateQuickLookStatus(s)
                                }
                            }
                        }
                        .accessibilityLabel("Set Quick Look plugin status")
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: QuickLookPluginStatus) -> Color {
        switch status {
        case .notInstalled: return .gray
        case .installed:    return .blue
        case .active:       return .green
        case .error:        return .red
        }
    }
}
#endif
