// WatchFolderService.swift
// DICOMViewer macOS - Watch Folder Auto-Import Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import Combine

/// Service for monitoring folders and auto-importing DICOM files
@MainActor
final class WatchFolderService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the service is currently monitoring
    @Published private(set) var isMonitoring = false
    
    /// Currently watched folders
    @Published private(set) var watchedFolders: [URL] = []
    
    /// Import statistics
    @Published private(set) var statistics = ImportStatistics()
    
    // MARK: - Private Properties
    
    private var fileSystemEvents: [FSEventStreamRef] = []
    private var importService: FileImportService?
    private var databaseService: DatabaseService?
    private var processedFiles = Set<String>()
    private var importQueue = DispatchQueue(label: "com.rasterlab.dicomviewer.watchfolder", qos: .utility)
    
    // MARK: - Configuration
    
    struct Configuration {
        /// File extensions to monitor
        var extensions: Set<String> = ["dcm", "dicom", ""]
        
        /// Minimum file size in bytes (to avoid partial files)
        var minimumFileSize: Int = 128
        
        /// Delay before importing new file (seconds)
        var importDelay: TimeInterval = 2.0
        
        /// Enable duplicate detection
        var detectDuplicates: Bool = true
        
        /// Maximum concurrent imports
        var maxConcurrentImports: Int = 4
        
        /// Log imported files
        var enableLogging: Bool = true
    }
    
    var configuration = Configuration()
    
    // MARK: - Statistics
    
    struct ImportStatistics: Codable {
        var filesDetected: Int = 0
        var filesImported: Int = 0
        var filesFailed: Int = 0
        var duplicatesSkipped: Int = 0
        var lastImportDate: Date?
        
        mutating func reset() {
            filesDetected = 0
            filesImported = 0
            filesFailed = 0
            duplicatesSkipped = 0
            lastImportDate = nil
        }
    }
    
    // MARK: - Initialization
    
    init(importService: FileImportService? = nil, databaseService: DatabaseService? = nil) {
        self.importService = importService
        self.databaseService = databaseService
        loadWatchedFolders()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Add a folder to watch
    func addWatchedFolder(_ url: URL) throws {
        guard url.hasDirectoryPath else {
            throw WatchFolderError.notADirectory
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WatchFolderError.folderNotFound
        }
        
        guard !watchedFolders.contains(url) else {
            throw WatchFolderError.alreadyWatching
        }
        
        watchedFolders.append(url)
        saveWatchedFolders()
        
        if isMonitoring {
            try startWatchingFolder(url)
        }
    }
    
    /// Remove a folder from watch list
    func removeWatchedFolder(_ url: URL) {
        guard let index = watchedFolders.firstIndex(of: url) else { return }
        
        watchedFolders.remove(at: index)
        saveWatchedFolders()
        
        if isMonitoring {
            stopWatchingFolder(url)
        }
    }
    
    /// Start monitoring all watched folders
    func startMonitoring() throws {
        guard !isMonitoring else { return }
        
        for folder in watchedFolders {
            try startWatchingFolder(folder)
        }
        
        isMonitoring = true
        log("Started monitoring \(watchedFolders.count) folder(s)")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        for stream in fileSystemEvents {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        
        fileSystemEvents.removeAll()
        isMonitoring = false
        log("Stopped monitoring")
    }
    
    /// Reset statistics
    func resetStatistics() {
        statistics.reset()
    }
    
    // MARK: - Private Methods
    
    private func startWatchingFolder(_ url: URL) throws {
        let pathsToWatch = [url.path] as CFArray
        let latency: CFTimeInterval = 1.0
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            throw WatchFolderError.failedToCreateStream
        }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        if FSEventStreamStart(stream) {
            fileSystemEvents.append(stream)
            log("Started watching: \(url.path)")
        } else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw WatchFolderError.failedToStartStream
        }
    }
    
    private func stopWatchingFolder(_ url: URL) {
        // Find and stop the stream for this folder
        // This is a simplified implementation
        // In production, you'd track which stream corresponds to which folder
        log("Stopped watching: \(url.path)")
    }
    
    private func handleFileEvent(path: String, flags: FSEventStreamEventFlags) {
        // Check if file was created or modified
        let isCreated = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
        let isModified = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0
        let isFile = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)) != 0
        
        guard isFile && (isCreated || isModified) else { return }
        
        let url = URL(fileURLWithPath: path)
        
        // Check extension
        let ext = url.pathExtension.lowercased()
        guard configuration.extensions.contains(ext) || (ext.isEmpty && configuration.extensions.contains("")) else {
            return
        }
        
        // Check if already processed
        guard !processedFiles.contains(path) else {
            return
        }
        
        statistics.filesDetected += 1
        
        // Schedule import with delay (to ensure file is fully written)
        importQueue.asyncAfter(deadline: .now() + configuration.importDelay) { [weak self] in
            self?.importFile(at: url, path: path)
        }
    }
    
    private func importFile(at url: URL, path: String) {
        guard let importService = importService else {
            log("Import service not available", level: .error)
            return
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            guard fileSize >= configuration.minimumFileSize else {
                log("File too small, skipping: \(path)", level: .warning)
                return
            }
        } catch {
            log("Failed to get file attributes: \(error)", level: .error)
            Task { @MainActor in
                self.statistics.filesFailed += 1
            }
            return
        }
        
        // Import the file
        Task { @MainActor in
            do {
                let studyUID = try await importService.importFile(at: url)
                
                self.processedFiles.insert(path)
                self.statistics.filesImported += 1
                self.statistics.lastImportDate = Date()
                
                log("Imported: \(url.lastPathComponent) (Study: \(studyUID))")
            } catch {
                self.statistics.filesFailed += 1
                log("Failed to import: \(url.lastPathComponent) - \(error)", level: .error)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveWatchedFolders() {
        let paths = watchedFolders.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "WatchedFolders")
    }
    
    private func loadWatchedFolders() {
        if let paths = UserDefaults.standard.array(forKey: "WatchedFolders") as? [String] {
            watchedFolders = paths.map { URL(fileURLWithPath: $0) }
        }
    }
    
    // MARK: - Logging
    
    private func log(_ message: String, level: LogLevel = .info) {
        guard configuration.enableLogging else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = level.prefix
        print("[\(timestamp)] \(prefix) WatchFolderService: \(message)")
    }
    
    enum LogLevel {
        case info, warning, error
        
        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    // MARK: - Errors
    
    enum WatchFolderError: Error, LocalizedError {
        case notADirectory
        case folderNotFound
        case alreadyWatching
        case failedToCreateStream
        case failedToStartStream
        
        var errorDescription: String? {
            switch self {
            case .notADirectory:
                return "The provided path is not a directory"
            case .folderNotFound:
                return "The folder does not exist"
            case .alreadyWatching:
                return "This folder is already being watched"
            case .failedToCreateStream:
                return "Failed to create file system event stream"
            case .failedToStartStream:
                return "Failed to start file system event stream"
            }
        }
    }
}

// MARK: - FSEvents Callback

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    
    let service = Unmanaged<WatchFolderService>.fromOpaque(info).takeUnretainedValue()
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
    
    Task { @MainActor in
        for i in 0..<numEvents {
            service.handleFileEvent(path: paths[i], flags: eventFlags[i])
        }
    }
}
