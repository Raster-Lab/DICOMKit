// ValidationService.swift
// DICOMStudio
//
// Thread-safe backing store for the Validation view.

import Foundation

/// Thread-safe service backing ValidationViewModel.
public final class ValidationService: @unchecked Sendable {
    private let lock = NSLock()

    // MARK: - Stored State

    private var _inputPath: String = ""
    private var _level: Int = 3
    private var _iod: String = ""
    private var _detailed: Bool = false
    private var _recursive: Bool = false
    private var _format: ValidateOutputFormat = .text
    private var _outputPath: String = ""
    private var _strict: Bool = false
    private var _force: Bool = false
    private var _history: [ValidationRunRecord] = []

    public init() {}

    // MARK: - Getters

    public func getInputPath() -> String        { lock.withLock { _inputPath } }
    public func getLevel() -> Int               { lock.withLock { _level } }
    public func getIOD() -> String              { lock.withLock { _iod } }
    public func getDetailed() -> Bool           { lock.withLock { _detailed } }
    public func getRecursive() -> Bool          { lock.withLock { _recursive } }
    public func getFormat() -> ValidateOutputFormat { lock.withLock { _format } }
    public func getOutputPath() -> String       { lock.withLock { _outputPath } }
    public func getStrict() -> Bool             { lock.withLock { _strict } }
    public func getForce() -> Bool              { lock.withLock { _force } }
    public func getHistory() -> [ValidationRunRecord] { lock.withLock { _history } }

    // MARK: - Setters

    public func setInputPath(_ v: String)           { lock.withLock { _inputPath = v } }
    public func setLevel(_ v: Int)                  { lock.withLock { _level = max(1, min(5, v)) } }
    public func setIOD(_ v: String)                 { lock.withLock { _iod = v } }
    public func setDetailed(_ v: Bool)              { lock.withLock { _detailed = v } }
    public func setRecursive(_ v: Bool)             { lock.withLock { _recursive = v } }
    public func setFormat(_ v: ValidateOutputFormat) { lock.withLock { _format = v } }
    public func setOutputPath(_ v: String)          { lock.withLock { _outputPath = v } }
    public func setStrict(_ v: Bool)                { lock.withLock { _strict = v } }
    public func setForce(_ v: Bool)                 { lock.withLock { _force = v } }

    public func addHistory(_ record: ValidationRunRecord) {
        lock.withLock { _history.insert(record, at: 0) }
    }

    public func clearHistory() {
        lock.withLock { _history.removeAll() }
    }
}
