// CLIAutomationTestingService.swift
// DICOMStudio
//
// Thread-safe backing store for the CLI Automation Testing feature.

import Foundation

public final class CLIAutomationTestingService: @unchecked Sendable {
    private let lock = NSLock()

    private var _results: [ToolParityResult] = []
    private var _selectedToolID: String? = nil
    private var _outputComparisons: [String: [OutputComparison]] = [:] // toolId -> comparisons

    public init() {}

    public func getResults() -> [ToolParityResult] { lock.withLock { _results } }
    public func setResults(_ r: [ToolParityResult]) { lock.withLock { _results = r } }

    public func getSelectedToolID() -> String? { lock.withLock { _selectedToolID } }
    public func setSelectedToolID(_ id: String?) { lock.withLock { _selectedToolID = id } }

    public func getOutputComparisons(for toolID: String) -> [OutputComparison] {
        lock.withLock { _outputComparisons[toolID] ?? [] }
    }
    public func setOutputComparisons(_ comparisons: [OutputComparison], for toolID: String) {
        lock.withLock { _outputComparisons[toolID] = comparisons }
    }
}
