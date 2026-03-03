// PolishReleaseView.swift
// DICOMStudio
//
// DICOM Studio — Polish, Accessibility & Release view (Milestone 15)

#if canImport(SwiftUI)
import SwiftUI

/// View for polish, accessibility, and release preparation: i18n, accessibility audit,
/// testing, performance profiling, documentation, and release checklist.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct PolishReleaseView: View {
    @Bindable var viewModel: PolishReleaseViewModel

    public init(viewModel: PolishReleaseViewModel) {
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
                ForEach(PolishReleaseTab.allCases, id: \.self) { tab in
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
        case .i18n:
            i18nContent
        case .accessibility:
            accessibilityContent
        case .testing:
            testingContent
        case .performance:
            performanceContent
        case .documentation:
            documentationContent
        case .release:
            releaseContent
        }
    }

    // MARK: - 15.1 Internationalization

    private var i18nContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Internationalization")
                    .font(.headline)
                Spacer()
                Picker("Language", selection: Binding(
                    get: { viewModel.selectedLanguage },
                    set: { viewModel.selectLanguage($0) }
                )) {
                    ForEach(LocalizationLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 200)
                .accessibilityLabel("Select language")
            }
            .padding()

            // Coverage summary for selected language
            if let summary = viewModel.selectedLanguageSummary {
                GroupBox {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("Coverage")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", summary.coveragePercent))
                                .font(.title3.bold())
                        }
                        Divider().frame(height: 30)
                        VStack(spacing: 2) {
                            Text("Translated")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(summary.translatedStrings) / \(summary.totalStrings)")
                                .font(.title3.bold())
                        }
                        Divider().frame(height: 30)
                        VStack(spacing: 2) {
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label(summary.status.displayName, systemImage: summary.status.sfSymbol)
                                .font(.body)
                        }
                        if viewModel.selectedLanguage.isRTL {
                            Divider().frame(height: 30)
                            Label("RTL", systemImage: "text.alignright")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.top, 8)

            if viewModel.localizationEntries.isEmpty {
                ContentUnavailableView(
                    "No Localization Entries",
                    systemImage: "globe",
                    description: Text("Localization strings will appear here.")
                )
            } else {
                List(viewModel.localizationEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.key)
                            .font(.body.monospaced())
                        Text(entry.baseValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let translation = entry.translations[viewModel.selectedLanguage.rawValue] {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text(translation)
                                    .font(.caption)
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text("Not translated")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !entry.context.isEmpty {
                            Text("Context: \(entry.context)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 15.2 Accessibility

    private var accessibilityContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Accessibility Audit")
                    .font(.headline)
                Spacer()

                Picker("Category", selection: $viewModel.selectedCheckCategory) {
                    Text("All").tag(nil as AccessibilityCheckCategory?)
                    ForEach(AccessibilityCheckCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat as AccessibilityCheckCategory?)
                    }
                }
                .frame(width: 180)
                .accessibilityLabel("Accessibility check category")
            }
            .padding()

            // Audit Report Summary
            let report = viewModel.auditReport
            GroupBox {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Pass Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", report.passRate))
                            .font(.title3.bold())
                            .foregroundStyle(report.passRate >= 80 ? .green : .red)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("Passed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.passedChecks)")
                            .font(.body.bold())
                            .foregroundStyle(.green)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("Failed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.failedChecks)")
                            .font(.body.bold())
                            .foregroundStyle(.red)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("Partial")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.partialChecks)")
                            .font(.body.bold())
                            .foregroundStyle(.orange)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("Not Tested")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.notTestedChecks)")
                            .font(.body.bold())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            if viewModel.filteredCheckItems.isEmpty {
                ContentUnavailableView(
                    "No Check Items",
                    systemImage: "accessibility",
                    description: Text("Accessibility checks will appear here.")
                )
            } else {
                List(viewModel.filteredCheckItems) { item in
                    HStack {
                        Image(systemName: item.status.sfSymbol)
                            .foregroundStyle(statusColor(for: item.status))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(item.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.screenName.isEmpty {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(item.screenName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Menu(item.status.displayName) {
                            ForEach(AccessibilityCheckStatus.allCases, id: \.self) { status in
                                Button(status.displayName) {
                                    viewModel.updateCheckItemStatus(id: item.id, status: status)
                                }
                            }
                        }
                        .frame(width: 100)
                        .accessibilityLabel("Update status for \(item.description)")
                    }
                }
            }
        }
    }

    // MARK: - 15.3 Testing

    private var testingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Comprehensive Testing")
                        .font(.headline)
                    Spacer()
                    if viewModel.allUITestsPassing {
                        Label("All Passing", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // UI Test Flows
                GroupBox("UI Test Flows") {
                    if viewModel.uiTestFlows.isEmpty {
                        Text("No UI test flows configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    } else {
                        ForEach(viewModel.uiTestFlows) { flow in
                            HStack {
                                Image(systemName: flow.status.sfSymbol)
                                    .foregroundStyle(uiTestStatusColor(for: flow.status))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(flow.flowType.displayName)
                                        .font(.body)
                                    if let lastRun = flow.lastRunDate {
                                        Text("Last run: \(lastRun.formatted(.relative(presentation: .named)))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let error = flow.errorMessage {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                                Spacer()
                                Menu(flow.status.displayName) {
                                    ForEach(UITestFlowStatus.allCases, id: \.self) { s in
                                        Button(s.displayName) {
                                            viewModel.updateUITestFlowStatus(id: flow.id, status: s)
                                        }
                                    }
                                }
                                .frame(width: 90)
                            }
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)

                // Coverage Targets
                GroupBox("Test Coverage") {
                    HStack {
                        Text("Average Coverage:")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1f%%", viewModel.averageCoveragePercent))
                            .font(.body.bold())
                    }
                    .padding(.bottom, 4)

                    if viewModel.coverageTargets.isEmpty {
                        Text("No coverage targets configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.coverageTargets) { target in
                            HStack {
                                Image(systemName: target.meetsTarget ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(target.meetsTarget ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.moduleName)
                                        .font(.body)
                                    Text("\(target.testCount) tests")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", target.coveragePercent))
                                    .font(.body.monospaced())
                            }
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)

                // Benchmarks
                GroupBox("Performance Benchmarks") {
                    if viewModel.benchmarks.isEmpty {
                        Text("No benchmarks configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.benchmarks) { benchmark in
                            HStack {
                                Image(systemName: benchmark.isPassing ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(benchmark.isPassing ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benchmark.name)
                                        .font(.body)
                                    Text(benchmark.targetDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }

    // MARK: - 15.4 Performance Profiling

    private var performanceContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Performance Profiling")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.completedSessionCount) of \(viewModel.profilingSessions.count) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            Divider()

            if viewModel.profilingSessions.isEmpty {
                ContentUnavailableView(
                    "No Profiling Sessions",
                    systemImage: "gauge.with.needle",
                    description: Text("Profiling sessions will appear here.")
                )
            } else {
                List(viewModel.profilingSessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(session.sessionType.displayName, systemImage: session.sessionType.sfSymbol)
                                .font(.body.bold())
                            Spacer()
                            Text(session.status.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(profilingStatusBackground(for: session.status))
                                .clipShape(Capsule())
                        }
                        if let start = session.startDate {
                            Text("Started: \(start.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if session.durationSeconds > 0 {
                            Text(String(format: "Duration: %.1fs", session.durationSeconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !session.findings.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Findings:")
                                    .font(.caption.bold())
                                ForEach(session.findings, id: \.self) { finding in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("•")
                                        Text(finding)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 15.5 Documentation

    private var documentationContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Documentation")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%% complete", viewModel.documentationCompletionPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            Divider()

            if viewModel.documentationEntries.isEmpty {
                ContentUnavailableView(
                    "No Documentation Entries",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Documentation tracking will appear here.")
                )
            } else {
                List(viewModel.documentationEntries) { entry in
                    HStack {
                        Image(systemName: entry.docType.sfSymbol)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(entry.docType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if entry.wordCount > 0 {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text("\(entry.wordCount) words")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let updated = entry.lastUpdatedDate {
                                Text("Updated: \(updated.formatted(.relative(presentation: .named)))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(entry.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(docStatusBackground(for: entry.status))
                            .clipShape(Capsule())

                        if entry.status != .complete {
                            Button("Mark Complete") {
                                viewModel.markDocumentationComplete(id: entry.id)
                            }
                            .font(.caption)
                            .accessibilityLabel("Mark \(entry.title) as complete")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 15.6 Release

    private var releaseContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Release Preparation")
                    .font(.headline)
                Spacer()
                Label(viewModel.overallReleaseStatus.displayName, systemImage: viewModel.overallReleaseStatus.sfSymbol)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(releaseStatusBackground(for: viewModel.overallReleaseStatus))
                    .clipShape(Capsule())
            }
            .padding()

            Text(viewModel.releaseChecklistSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 4)

            Divider()

            if viewModel.releaseChecklist.isEmpty {
                ContentUnavailableView(
                    "No Checklist Items",
                    systemImage: "checklist",
                    description: Text("Release checklist items will appear here.")
                )
            } else {
                List(viewModel.releaseChecklist) { item in
                    HStack {
                        Button {
                            viewModel.toggleChecklistItem(id: item.id)
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.isCompleted ? "Completed" : "Not completed")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.body)
                                .strikethrough(item.isCompleted)
                            HStack(spacing: 6) {
                                Text(item.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.notes.isEmpty {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(item.notes)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: AccessibilityCheckStatus) -> Color {
        switch status {
        case .passed:    return .green
        case .failed:    return .red
        case .partial:   return .orange
        case .notTested: return .gray
        }
    }

    private func uiTestStatusColor(for status: UITestFlowStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .passing: return .green
        case .failing: return .red
        case .skipped: return .secondary
        }
    }

    private func profilingStatusBackground(for status: ProfilingSessionStatus) -> Color {
        switch status {
        case .notStarted: return .gray.opacity(0.15)
        case .running:    return .blue.opacity(0.15)
        case .completed:  return .green.opacity(0.15)
        case .failed:     return .red.opacity(0.15)
        }
    }

    private func docStatusBackground(for status: DocPageStatus) -> Color {
        switch status {
        case .complete:   return .green.opacity(0.15)
        case .inProgress: return .blue.opacity(0.15)
        case .planned:    return .gray.opacity(0.15)
        }
    }

    private func releaseStatusBackground(for status: ReleaseStatus) -> Color {
        switch status {
        case .notStarted:     return .gray.opacity(0.15)
        case .inProgress:     return .blue.opacity(0.15)
        case .readyForReview: return .orange.opacity(0.15)
        case .submitted:      return .purple.opacity(0.15)
        case .approved:       return .green.opacity(0.15)
        }
    }
}
#endif
