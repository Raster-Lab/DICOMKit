// DICOMKit Sample Code: Async Loading with SwiftUI
//
// This example demonstrates how to:
// - Load DICOM files asynchronously with async/await
// - Display progress indicators
// - Handle errors with async/await
// - Cancel async tasks
// - Load in background
// - Load multiple files concurrently
// - Stream large files
// - Implement retry logic

#if canImport(SwiftUI)
import SwiftUI
import DICOMKit
import DICOMCore
import Foundation

// MARK: - Example 1: Basic Async Loading

struct Example1_BasicAsyncLoad: View {
    let fileURL: URL
    
    @State private var dicomFile: DICOMFile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading DICOM file...")
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task { await loadFile() }
                    }
                }
            } else if let file = dicomFile {
                VStack(alignment: .leading) {
                    Text("SOP Class: \(file.sopClassUID)")
                    Text("Transfer Syntax: \(file.transferSyntax)")
                    if let pixelData = file.pixelData {
                        Text("Image: \(pixelData.width) × \(pixelData.height)")
                    }
                }
            }
        }
        .task {
            await loadFile()
        }
    }
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load file asynchronously
            let file = try await Task.detached {
                try DICOMFile.read(from: fileURL)
            }.value
            
            dicomFile = file
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Example 2: Progress Indicator

actor FileLoader {
    private(set) var progress: Double = 0.0
    private(set) var status: String = "Preparing..."
    
    func updateProgress(_ value: Double, status: String) {
        self.progress = value
        self.status = status
    }
    
    func load(from url: URL) async throws -> DICOMFile {
        await updateProgress(0.0, status: "Reading file...")
        
        // Read file data
        let data = try Data(contentsOf: url)
        
        await updateProgress(0.3, status: "Parsing DICOM...")
        
        // Parse DICOM
        let file = try DICOMFile(data: data)
        
        await updateProgress(0.7, status: "Loading pixel data...")
        
        // Access pixel data to ensure it's loaded
        if let pixelData = file.pixelData {
            _ = pixelData.width
        }
        
        await updateProgress(1.0, status: "Complete")
        
        return file
    }
}

struct Example2_ProgressIndicator: View {
    let fileURL: URL
    
    @State private var dicomFile: DICOMFile?
    @State private var progress: Double = 0.0
    @State private var status: String = ""
    @State private var isLoading = false
    
    private let loader = FileLoader()
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack(spacing: 15) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
                .padding()
            } else if let file = dicomFile {
                Text("Loaded: \(file.sopInstanceUID)")
                    .font(.headline)
            }
        }
        .task {
            await loadWithProgress()
        }
    }
    
    private func loadWithProgress() async {
        isLoading = true
        
        // Monitor progress
        Task {
            while isLoading {
                progress = await loader.progress
                status = await loader.status
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        
        do {
            dicomFile = try await loader.load(from: fileURL)
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Example 3: Task Cancellation

struct Example3_CancellableLoad: View {
    let fileURL: URL
    
    @State private var dicomFile: DICOMFile?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack {
                    ProgressView("Loading...")
                    Button("Cancel") {
                        cancelLoad()
                    }
                    .foregroundColor(.red)
                }
            } else if let file = dicomFile {
                Text("Loaded: \(file.sopInstanceUID)")
            } else {
                Button("Load File") {
                    startLoad()
                }
            }
        }
        .onDisappear {
            cancelLoad()
        }
    }
    
    private func startLoad() {
        isLoading = true
        
        loadTask = Task {
            do {
                // Simulate long-running load
                try await Task.sleep(for: .seconds(2))
                
                // Check for cancellation
                try Task.checkCancellation()
                
                let file = try await Task.detached {
                    try DICOMFile.read(from: fileURL)
                }.value
                
                // Check again before updating UI
                try Task.checkCancellation()
                
                dicomFile = file
                isLoading = false
            } catch is CancellationError {
                print("Load cancelled")
                isLoading = false
            } catch {
                print("Error: \(error)")
                isLoading = false
            }
        }
    }
    
    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

// MARK: - Example 4: Background Loading

struct Example4_BackgroundLoad: View {
    let fileURL: URL
    
    @State private var displayImage: CGImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadInBackground()
        }
    }
    
    private func loadInBackground() async {
        // Load file on background queue
        let image = await Task.detached(priority: .userInitiated) {
            do {
                let file = try DICOMFile.read(from: fileURL)
                guard let pixelData = file.pixelData else { return nil }
                
                let dataSet = file.dataSet
                let windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
                let windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
                
                return try pixelData.createCGImage(
                    frame: 0,
                    windowCenter: windowCenter,
                    windowWidth: windowWidth
                )
            } catch {
                print("Error loading: \(error)")
                return nil
            }
        }.value
        
        displayImage = image
        isLoading = false
    }
}

// MARK: - Example 5: Concurrent Loading of Multiple Files

struct Example5_ConcurrentLoading: View {
    let fileURLs: [URL]
    
    @State private var loadedFiles: [DICOMFile] = []
    @State private var progress: Double = 0.0
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack {
                    ProgressView("Loading \(fileURLs.count) files...",
                                value: progress,
                                total: Double(fileURLs.count))
                    Text("\(loadedFiles.count) / \(fileURLs.count) complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text("Loaded \(loadedFiles.count) files")
                    .font(.headline)
                
                List(loadedFiles, id: \.sopInstanceUID) { file in
                    VStack(alignment: .leading) {
                        Text(file.sopInstanceUID)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .task {
            await loadConcurrently()
        }
    }
    
    private func loadConcurrently() async {
        isLoading = true
        loadedFiles = []
        progress = 0.0
        
        // Use TaskGroup for concurrent loading
        await withTaskGroup(of: DICOMFile?.self) { group in
            for url in fileURLs {
                group.addTask {
                    try? await Task.detached {
                        try DICOMFile.read(from: url)
                    }.value
                }
            }
            
            // Collect results as they complete
            for await file in group {
                if let file = file {
                    loadedFiles.append(file)
                    progress = Double(loadedFiles.count)
                }
            }
        }
        
        isLoading = false
    }
}

// MARK: - Example 6: Error Recovery with Retry

struct Example6_RetryLogic: View {
    let fileURL: URL
    
    @State private var dicomFile: DICOMFile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var retryCount = 0
    
    private let maxRetries = 3
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack {
                    ProgressView("Loading...")
                    if retryCount > 0 {
                        Text("Retry attempt \(retryCount) of \(maxRetries)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            } else if let error = errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    if retryCount < maxRetries {
                        Button("Retry (\(maxRetries - retryCount) attempts left)") {
                            Task { await loadWithRetry() }
                        }
                    } else {
                        Text("Maximum retries exceeded")
                            .foregroundColor(.secondary)
                    }
                }
            } else if let file = dicomFile {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Successfully loaded")
                    Text(file.sopInstanceUID)
                        .font(.caption)
                }
            }
        }
        .task {
            await loadWithRetry()
        }
    }
    
    private func loadWithRetry() async {
        isLoading = true
        errorMessage = nil
        
        while retryCount <= maxRetries {
            do {
                let file = try await Task.detached {
                    try DICOMFile.read(from: fileURL)
                }.value
                
                dicomFile = file
                isLoading = false
                return
            } catch {
                retryCount += 1
                
                if retryCount <= maxRetries {
                    // Exponential backoff
                    let delay = Double(retryCount) * 0.5
                    try? await Task.sleep(for: .seconds(delay))
                } else {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }
            }
        }
    }
}

// MARK: - Example 7: Streaming Large Files

struct Example7_StreamingLoad: View {
    let fileURL: URL
    
    @State private var bytesLoaded: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var dicomFile: DICOMFile?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView(value: Double(bytesLoaded),
                                total: Double(totalBytes))
                    
                    HStack {
                        Text("Loading:")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: bytesLoaded, countStyle: .file))
                        Text("/")
                        Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
                .padding()
            } else if let file = dicomFile {
                Text("File loaded: \(file.sopInstanceUID)")
            }
        }
        .task {
            await streamLoad()
        }
    }
    
    private func streamLoad() async {
        isLoading = true
        
        do {
            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            totalBytes = attributes[.size] as? Int64 ?? 0
            
            // Simulate streaming by reading chunks
            let chunkSize = 1024 * 1024  // 1 MB chunks
            var data = Data()
            
            if let fileHandle = try? FileHandle(forReadingFrom: fileURL) {
                defer { try? fileHandle.close() }
                
                while true {
                    let chunk = fileHandle.readData(ofLength: chunkSize)
                    if chunk.isEmpty { break }
                    
                    data.append(chunk)
                    bytesLoaded = Int64(data.count)
                    
                    // Small delay to show progress
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            
            // Parse DICOM from complete data
            dicomFile = try DICOMFile(data: data)
            
        } catch {
            print("Error: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Example 8: Lazy Loading with Pagination

struct Example8_LazyLoadingList: View {
    @State private var files: [DICOMFile] = []
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var hasMore = true
    
    private let pageSize = 20
    private let fileURLs: [URL] = []  // Your file list
    
    var body: some View {
        List {
            ForEach(files, id: \.sopInstanceUID) { file in
                VStack(alignment: .leading) {
                    Text(file.sopInstanceUID)
                        .font(.headline)
                    Text(file.sopClassUID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    // Load more when approaching end
                    if file.sopInstanceUID == files.last?.sopInstanceUID {
                        Task { await loadNextPage() }
                    }
                }
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .task {
            await loadNextPage()
        }
    }
    
    private func loadNextPage() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, fileURLs.count)
        
        guard startIndex < endIndex else {
            hasMore = false
            isLoading = false
            return
        }
        
        // Load page concurrently
        let pageURLs = Array(fileURLs[startIndex..<endIndex])
        
        await withTaskGroup(of: DICOMFile?.self) { group in
            for url in pageURLs {
                group.addTask {
                    try? await Task.detached {
                        try DICOMFile.read(from: url)
                    }.value
                }
            }
            
            for await file in group {
                if let file = file {
                    files.append(file)
                }
            }
        }
        
        currentPage += 1
        hasMore = endIndex < fileURLs.count
        isLoading = false
    }
}

// MARK: - Example 9: Complete Async Loader Component

@MainActor
class DICOMFileLoader: ObservableObject {
    @Published var file: DICOMFile?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var progress: Double = 0.0
    
    private var loadTask: Task<Void, Never>?
    
    func load(from url: URL) {
        // Cancel existing load
        cancel()
        
        isLoading = true
        error = nil
        progress = 0.0
        
        loadTask = Task {
            do {
                progress = 0.1
                
                // Load in background
                let loadedFile = try await Task.detached(priority: .userInitiated) {
                    try DICOMFile.read(from: url)
                }.value
                
                // Check cancellation
                try Task.checkCancellation()
                
                progress = 0.9
                
                // Update on main actor
                self.file = loadedFile
                self.progress = 1.0
                self.isLoading = false
                
            } catch is CancellationError {
                // Silent cancellation
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
    
    deinit {
        cancel()
    }
}

struct Example9_CompleteAsyncLoader: View {
    let fileURL: URL
    
    @StateObject private var loader = DICOMFileLoader()
    
    var body: some View {
        VStack(spacing: 20) {
            // Status display
            if loader.isLoading {
                VStack(spacing: 15) {
                    ProgressView(value: loader.progress)
                        .progressViewStyle(.linear)
                    
                    Text("Loading DICOM file...")
                        .font(.headline)
                    
                    Button("Cancel", role: .cancel) {
                        loader.cancel()
                    }
                }
                .padding()
            } else if let error = loader.error {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Error Loading File")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        loader.load(from: fileURL)
                    }
                }
                .padding()
            } else if let file = loader.file {
                FileInfoView(file: file)
            } else {
                Button("Load File") {
                    loader.load(from: fileURL)
                }
            }
        }
        .task {
            loader.load(from: fileURL)
        }
    }
}

struct FileInfoView: View {
    let file: DICOMFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoRow(label: "SOP Instance UID", value: file.sopInstanceUID)
            InfoRow(label: "SOP Class UID", value: file.sopClassUID)
            InfoRow(label: "Transfer Syntax", value: file.transferSyntax)
            
            if let pixelData = file.pixelData {
                InfoRow(label: "Image Size",
                       value: "\(pixelData.width) × \(pixelData.height)")
                InfoRow(label: "Frames",
                       value: "\(pixelData.numberOfFrames)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples in your app:
// let url = URL(fileURLWithPath: "/path/to/file.dcm")
// Example1_BasicAsyncLoad(fileURL: url)
// Example2_ProgressIndicator(fileURL: url)
// Example3_CancellableLoad(fileURL: url)
// Example4_BackgroundLoad(fileURL: url)
// Example6_RetryLogic(fileURL: url)
// Example9_CompleteAsyncLoader(fileURL: url)

// MARK: - Quick Reference

/*
 Swift Async/Await with SwiftUI:
 
 Task Creation:
 • .task { }              - View-attached task
 • .task(id:) { }         - Re-run on value change
 • Task { }               - Manual task creation
 • Task.detached { }      - Detached background task
 • Task(priority:) { }    - With priority
 
 Task Priorities:
 • .high                  - Time-critical user interaction
 • .medium                - Default priority
 • .low                   - Prefetching, maintenance
 • .userInitiated         - User-requested action
 • .utility               - Long-running computation
 • .background            - Low priority background work
 
 Cancellation:
 • task.cancel()          - Request cancellation
 • Task.checkCancellation() - Check if cancelled
 • Task.isCancelled       - Boolean property
 • CancellationError      - Error thrown when cancelled
 • .onDisappear { cancel() } - Cancel on view dismiss
 
 Progress Tracking:
 • @State var progress    - Progress value
 • ProgressView(value:)   - Progress bar
 • Actor for thread-safe  - Progress updates
 • Periodic updates       - Small delays
 
 Error Handling:
 • do-catch in Task       - Handle errors
 • @State var error       - Store error state
 • try Task.checkCancellation() - Cancellation handling
 • Retry logic            - With exponential backoff
 
 Concurrent Loading:
 • withTaskGroup          - Structured concurrency
 • group.addTask          - Add concurrent tasks
 • for await in group     - Collect results
 • TaskGroup<T>           - Typed task group
 
 Background Work:
 • Task.detached          - Independent background work
 • await on main actor    - Update UI
 • @MainActor annotation  - Main thread functions
 • Task(priority: .background) - Low priority
 
 State Management:
 • @State                 - View-local state
 • @StateObject           - Observable object lifecycle
 • @Published             - Observable changes
 • @MainActor class       - Main thread class
 
 Common Patterns:
 
 Basic Async Load:
 • .task { await load() }
 • try await background work
 • Update @State on completion
 
 Cancellable Load:
 • Store Task reference
 • Cancel on button press
 • Cancel on .onDisappear
 • Check cancellation periodically
 
 Progress Tracking:
 • Actor for thread-safe updates
 • @State for UI binding
 • Periodic reads from actor
 • ProgressView with value
 
 Error Recovery:
 • Try/catch in loop
 • Increment retry counter
 • Exponential backoff delay
 • Max retry limit
 
 Concurrent Loading:
 • withTaskGroup for multiple files
 • Collect results as they complete
 • Update progress incrementally
 • Handle individual failures
 
 Streaming:
 • Read in chunks
 • Update progress per chunk
 • FileHandle for large files
 • Parse when complete
 
 Lazy Loading:
 • Load pages on demand
 • .onAppear on last item
 • Track current page
 • Prevent duplicate loads
 
 Best Practices:
 
 1. Always handle cancellation
 2. Use appropriate task priority
 3. Update UI on main actor
 4. Provide progress feedback
 5. Show loading states
 6. Handle all error cases
 7. Cancel tasks on view dismiss
 8. Use Task.detached for heavy work
 9. Check cancellation periodically
 10. Implement retry for network loads
 11. Use actors for thread safety
 12. Profile async performance
 13. Avoid blocking main thread
 14. Test cancellation behavior
 15. Provide cancel buttons for long operations
 
 Performance Tips:
 
 1. Load on background queue
 2. Use Task.detached for CPU-intensive work
 3. Cancel unnecessary work early
 4. Batch concurrent operations
 5. Cache loaded results
 6. Use lazy loading for lists
 7. Implement pagination
 8. Monitor memory usage
 9. Profile with Instruments
 10. Minimize main thread updates
 
 DICOMKit Integration:
 
 Loading Files:
 • DICOMFile.read(from: URL)  - Sync read
 • Wrap in Task.detached      - Async wrapper
 • Parse large files off main - Background queue
 
 Progress Tracking:
 • Track bytes read           - File streaming
 • Report parsing stages      - Status updates
 • Update UI incrementally    - Progressive display
 
 Error Handling:
 • DICOMError types          - Specific errors
 • Validate before parsing   - Early detection
 • Retry on network failures - Resilience
 
 Memory Management:
 • Load on demand            - Minimize memory
 • Unload when not visible   - Free resources
 • Generate thumbnails async - Background work
 • Cache strategically       - Balance memory/speed
 
 Common Issues:
 
 1. Blocking main thread      - Use Task.detached
 2. Memory leaks              - Cancel tasks properly
 3. Race conditions           - Use actors
 4. Not handling cancellation - Check Task.isCancelled
 5. UI updates off main       - Use @MainActor
 6. Retain cycles             - Weak self in closures
 7. Task explosion            - Limit concurrency
 8. No error handling         - Always try/catch
 9. Progress not updating     - Check main thread
 10. Slow list scrolling      - Use lazy loading
 
 Testing Async Code:
 
 • XCTest with await          - Test async functions
 • expectation(description:)  - Async expectations
 • Task.sleep                 - Simulate delays
 • Mock cancellation          - Test cancel handling
 • Test error cases           - Verify error handling
 */

#endif // canImport(SwiftUI)
