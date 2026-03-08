// IntegrationTestingView.swift
// DICOMStudio
//
// DICOM Studio — Integration Testing, Accessibility & Polish view (Milestone 23)

#if canImport(SwiftUI)
import SwiftUI

/// View for integration testing, accessibility auditing, performance benchmarking,
/// UI polish checks, and documentation progress tracking.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct IntegrationTestingView: View {
    @Bindable var viewModel: IntegrationTestingViewModel

    public init(viewModel: IntegrationTestingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(IntegrationTestingTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.selectedTab = tab
                    } label: {
                        Label(tab.displayName, systemImage: tab.symbolName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
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
        switch viewModel.selectedTab {
        case .e2eTesting:
            e2eTestingTab
        case .unitTests:
            unitTestsTab
        case .accessibility:
            accessibilityTab
        case .performance:
            performanceTab
        case .uiPolish:
            uiPolishTab
        case .documentation:
            documentationTab
        }
    }

    // MARK: - E2E Testing Tab

    private var e2eTestingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("End-to-End Integration Tests")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Run All") {
                        viewModel.runAllTests()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Run all integration tests")

                    Button("Reset") {
                        viewModel.resetAllTests()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Reset all integration test results")
                }

                if viewModel.testSuites.isEmpty {
                    Button("Initialize Test Suites") {
                        viewModel.initializeTestSuites()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Initialize integration test suites")
                } else {
                    Text(viewModel.e2eTestSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.testSuites.indices, id: \.self) { suiteIdx in
                        let suite = viewModel.testSuites[suiteIdx]
                        GroupBox(suite.category.displayName) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(suite.testCases.indices, id: \.self) { testIdx in
                                    let test = suite.testCases[testIdx]
                                    HStack {
                                        Image(systemName: test.status.symbolName)
                                            .foregroundStyle(test.status == .passed ? Color.green : (test.status == .failed ? Color.red : Color.secondary))
                                        Text(test.testDescription)
                                            .font(.caption)
                                        Spacer()
                                        if let duration = test.durationSeconds {
                                            Text(String(format: "%.2fs", duration))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Unit Tests Tab

    private var unitTestsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Unit Test Coverage")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Initialize") {
                        viewModel.initializeUnitTestEntries()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Initialize unit test entries")
                }

                if viewModel.unitTestEntries.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "checkmark.circle",
                        description: Text("Tap Initialize to load unit test coverage data.")
                    )
                } else {
                    Text(viewModel.unitTestCoverageSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.unitTestEntries, id: \.id) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.target.displayName)
                                    .font(.caption)
                                    .bold()
                                Text("\(entry.passedCount)/\(entry.testCount) tests")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", entry.coveragePercent))
                                .font(.caption)
                                .bold()
                                .foregroundStyle(entry.coveragePercent >= 80.0 ? .green : (entry.coveragePercent >= 60.0 ? .orange : .red))
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Accessibility Tab

    private var accessibilityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Accessibility Audit")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Run Audit") {
                        viewModel.initializeAccessibilityAudits()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Run accessibility audit")
                }

                Text(viewModel.accessibilityComplianceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.accessibilityAudits, id: \.id) { audit in
                    GroupBox(audit.category.displayName) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(audit.items, id: \.id) { check in
                                HStack {
                                    Image(systemName: check.status.symbolName)
                                        .foregroundStyle(check.status == .compliant ? Color.green : (check.status == .nonCompliant ? Color.red : Color.orange))
                                    Text(check.checkDescription)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Performance Tab

    private var performanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Performance Benchmarks")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Run Benchmarks") {
                        viewModel.initializeBenchmarks()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Run performance benchmarks")
                }

                Text(viewModel.performanceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.benchmarkResults, id: \.id) { result in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.metric.displayName)
                                .font(.caption)
                                .bold()
                            Text(result.metric.targetDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(result.formattedValue)
                                .font(.caption)
                                .bold()
                            Image(systemName: result.meetsTarget ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.meetsTarget ? .green : .red)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
            .padding()
        }
    }

    // MARK: - UI Polish Tab

    private var uiPolishTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("UI Polish Checks")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Run Checks") {
                        viewModel.initializePolishChecks()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Run UI polish checks")
                }

                Text(viewModel.polishCompletionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.polishChecks, id: \.id) { check in
                    HStack {
                        Image(systemName: check.isVerified ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(check.isVerified ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.checkDescription)
                                .font(.caption)
                                .bold()
                            Text(check.category.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
            .padding()
        }
    }

    // MARK: - Documentation Tab

    private var documentationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Documentation Progress")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Load") {
                        viewModel.initializeDocumentationEntries()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Load documentation progress")
                }

                Text(viewModel.documentationProgressSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.documentationEntries, id: \.id) { entry in
                    HStack {
                        Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.isComplete ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.caption)
                                .bold()
                            Text(entry.section.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.status.displayName)
                            .font(.caption)
                            .foregroundStyle(entry.isComplete ? .green : .secondary)
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
            .padding()
        }
    }
}
#endif
