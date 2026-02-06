// DICOMKit Sample Code: MVVM Architecture Patterns
//
// This example demonstrates how to:
// - Create ViewModels for DICOM data
// - Use @Observable and @ObservableObject
// - Implement dependency injection
// - Navigate with NavigationStack
// - Manage state effectively
// - Test ViewModels
// - Separate concerns properly
// - Build scalable SwiftUI apps

#if canImport(SwiftUI)
import SwiftUI
import DICOMKit
import DICOMCore
import Foundation
import Combine

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Basic ViewModel with @Observable

@Observable
class DICOMFileViewModel {
    var dicomFile: DICOMFile?
    var isLoading = false
    var errorMessage: String?
    
    func load(from url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let file = try await Task.detached {
                try DICOMFile.read(from: url)
            }.value
            
            dicomFile = file
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    var patientName: String {
        dicomFile?.dataSet.string(for: .patientName) ?? "Unknown"
    }
    
    var studyDescription: String {
        dicomFile?.dataSet.string(for: .studyDescription) ?? "N/A"
    }
    
    var imageSize: String? {
        guard let pixelData = dicomFile?.pixelData else { return nil }
        return "\(pixelData.width) × \(pixelData.height)"
    }
}

struct Example1_BasicViewModel: View {
    @State private var viewModel = DICOMFileViewModel()
    let fileURL: URL
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if viewModel.dicomFile != nil {
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Patient", value: viewModel.patientName)
                    InfoRow(label: "Study", value: viewModel.studyDescription)
                    if let size = viewModel.imageSize {
                        InfoRow(label: "Image Size", value: size)
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.load(from: fileURL)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Example 2: ViewModel with @ObservableObject (Legacy)

class LegacyDICOMFileViewModel: ObservableObject {
    @Published var dicomFile: DICOMFile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func load(from url: URL) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let file = try await Task.detached {
                try DICOMFile.read(from: url)
            }.value
            
            await MainActor.run {
                self.dicomFile = file
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct Example2_ObservableObjectViewModel: View {
    @StateObject private var viewModel = LegacyDICOMFileViewModel()
    let fileURL: URL
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let file = viewModel.dicomFile {
                Text("Loaded: \(file.sopInstanceUID)")
            }
        }
        .task {
            await viewModel.load(from: fileURL)
        }
    }
}

// MARK: - Example 3: Image Viewer ViewModel

@Observable
class ImageViewerViewModel {
    var dicomFile: DICOMFile?
    var displayImage: CGImage?
    var currentFrame = 0
    var windowCenter: Double = 0.0
    var windowWidth: Double = 400.0
    var isLoading = false
    
    var totalFrames: Int {
        dicomFile?.pixelData?.numberOfFrames ?? 0
    }
    
    func load(from url: URL) async {
        isLoading = true
        
        do {
            let file = try await Task.detached {
                try DICOMFile.read(from: url)
            }.value
            
            dicomFile = file
            
            // Initialize window/level from DICOM tags
            if let center = file.dataSet.float64(for: .windowCenter) {
                windowCenter = center
            }
            if let width = file.dataSet.float64(for: .windowWidth) {
                windowWidth = width
            }
            
            await updateImage()
        } catch {
            print("Error loading file: \(error)")
        }
        
        isLoading = false
    }
    
    func updateImage() async {
        guard let pixelData = dicomFile?.pixelData else { return }
        
        if let cgImage = try? await Task.detached {
            try pixelData.createCGImage(
                frame: self.currentFrame,
                windowCenter: self.windowCenter,
                windowWidth: self.windowWidth
            )
        }.value {
            displayImage = cgImage
        }
    }
    
    func nextFrame() {
        guard totalFrames > 0 else { return }
        currentFrame = (currentFrame + 1) % totalFrames
        Task { await updateImage() }
    }
    
    func previousFrame() {
        guard totalFrames > 0 else { return }
        currentFrame = (currentFrame - 1 + totalFrames) % totalFrames
        Task { await updateImage() }
    }
    
    func adjustWindow(deltaWidth: Double, deltaCenter: Double) {
        windowWidth = max(1.0, windowWidth + deltaWidth)
        windowCenter += deltaCenter
        Task { await updateImage() }
    }
}

struct Example3_ImageViewerWithViewModel: View {
    @State private var viewModel = ImageViewerViewModel()
    let fileURL: URL
    
    var body: some View {
        VStack {
            // Image display
            if let image = viewModel.displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else if viewModel.isLoading {
                ProgressView()
            }
            
            // Controls
            HStack {
                Button("Previous", systemImage: "chevron.left") {
                    viewModel.previousFrame()
                }
                .disabled(viewModel.totalFrames <= 1)
                
                Text("\(viewModel.currentFrame + 1) / \(viewModel.totalFrames)")
                    .monospacedDigit()
                
                Button("Next", systemImage: "chevron.right") {
                    viewModel.nextFrame()
                }
                .disabled(viewModel.totalFrames <= 1)
            }
            .padding()
        }
        .task {
            await viewModel.load(from: fileURL)
        }
    }
}

// MARK: - Example 4: Dependency Injection

protocol DICOMFileService {
    func loadFile(from url: URL) async throws -> DICOMFile
}

class RealDICOMFileService: DICOMFileService {
    func loadFile(from url: URL) async throws -> DICOMFile {
        try await Task.detached {
            try DICOMFile.read(from: url)
        }.value
    }
}

class MockDICOMFileService: DICOMFileService {
    var fileToReturn: DICOMFile?
    var shouldThrowError = false
    
    func loadFile(from url: URL) async throws -> DICOMFile {
        if shouldThrowError {
            throw NSError(domain: "test", code: -1)
        }
        
        guard let file = fileToReturn else {
            throw NSError(domain: "test", code: -2)
        }
        
        return file
    }
}

@Observable
class DICOMViewModelWithDI {
    private let fileService: DICOMFileService
    
    var dicomFile: DICOMFile?
    var isLoading = false
    var error: Error?
    
    init(fileService: DICOMFileService = RealDICOMFileService()) {
        self.fileService = fileService
    }
    
    func load(from url: URL) async {
        isLoading = true
        error = nil
        
        do {
            dicomFile = try await fileService.loadFile(from: url)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

struct Example4_DependencyInjection: View {
    @State private var viewModel: DICOMViewModelWithDI
    
    init(fileService: DICOMFileService = RealDICOMFileService()) {
        _viewModel = State(initialValue: DICOMViewModelWithDI(fileService: fileService))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let file = viewModel.dicomFile {
                Text("File loaded: \(file.sopInstanceUID)")
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Example 5: Study Browser ViewModel

@Observable
class StudyBrowserViewModel {
    var studies: [DICOMStudy] = []
    var isLoading = false
    var searchText = ""
    var selectedModality = "All"
    
    var filteredStudies: [DICOMStudy] {
        var result = studies
        
        if selectedModality != "All" {
            result = result.filter { $0.modality == selectedModality }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.patientName.localizedCaseInsensitiveContains(searchText) ||
                $0.studyDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    func loadStudies(from directory: URL) async {
        isLoading = true
        
        // Load DICOM files from directory
        let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "dcm" }
        
        var loadedStudies: [String: DICOMStudy] = [:]
        
        for fileURL in files ?? [] {
            if let file = try? DICOMFile.read(from: fileURL) {
                let study = DICOMStudy(from: file)
                loadedStudies[study.id] = study
            }
        }
        
        studies = Array(loadedStudies.values).sorted {
            $0.studyDate > $1.studyDate
        }
        
        isLoading = false
    }
    
    func deleteStudy(_ study: DICOMStudy) {
        studies.removeAll { $0.id == study.id }
    }
}

struct DICOMStudy: Identifiable, Hashable {
    let id: String
    let patientName: String
    let studyDate: String
    let studyDescription: String
    let modality: String
    
    init(from file: DICOMFile) {
        let ds = file.dataSet
        self.id = ds.string(for: .studyInstanceUID) ?? UUID().uuidString
        self.patientName = ds.string(for: .patientName) ?? "Unknown"
        self.studyDate = ds.string(for: .studyDate) ?? ""
        self.studyDescription = ds.string(for: .studyDescription) ?? "No Description"
        self.modality = ds.string(for: .modality) ?? "OT"
    }
}

struct Example5_StudyBrowserViewModel: View {
    @State private var viewModel = StudyBrowserViewModel()
    
    var body: some View {
        NavigationStack {
            List(viewModel.filteredStudies) { study in
                VStack(alignment: .leading) {
                    Text(study.patientName)
                        .font(.headline)
                    Text(study.studyDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .searchable(text: $viewModel.searchText)
            .navigationTitle("Studies")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

// MARK: - Example 6: Navigation with ViewModels

enum Route: Hashable {
    case studyList
    case studyDetail(DICOMStudy)
    case imageViewer(URL)
}

@Observable
class NavigationViewModel {
    var path: [Route] = []
    
    func navigateToStudy(_ study: DICOMStudy) {
        path.append(.studyDetail(study))
    }
    
    func navigateToImage(_ url: URL) {
        path.append(.imageViewer(url))
    }
    
    func navigateBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func navigateToRoot() {
        path.removeAll()
    }
}

struct Example6_NavigationViewModel: View {
    @State private var navigationVM = NavigationViewModel()
    @State private var studyVM = StudyBrowserViewModel()
    
    var body: some View {
        NavigationStack(path: $navigationVM.path) {
            List(studyVM.studies) { study in
                Button(action: {
                    navigationVM.navigateToStudy(study)
                }) {
                    Text(study.patientName)
                }
            }
            .navigationTitle("Studies")
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .studyList:
            Text("Study List")
        case .studyDetail(let study):
            Text("Study: \(study.patientName)")
        case .imageViewer(let url):
            Text("Image: \(url.lastPathComponent)")
        }
    }
}

// MARK: - Example 7: State Management Best Practices

@Observable
class AppState {
    var currentStudy: DICOMStudy?
    var recentStudies: [DICOMStudy] = []
    var settings = AppSettings()
    
    func selectStudy(_ study: DICOMStudy) {
        currentStudy = study
        addToRecent(study)
    }
    
    private func addToRecent(_ study: DICOMStudy) {
        recentStudies.removeAll { $0.id == study.id }
        recentStudies.insert(study, at: 0)
        if recentStudies.count > 10 {
            recentStudies.removeLast()
        }
    }
}

struct AppSettings {
    var defaultWindowCenter: Double = 40.0
    var defaultWindowWidth: Double = 400.0
    var showMetadata: Bool = true
    var autoLoadPixelData: Bool = true
}

struct Example7_StateManagement: View {
    @State private var appState = AppState()
    
    var body: some View {
        TabView {
            StudiesTab(appState: appState)
                .tabItem {
                    Label("Studies", systemImage: "folder")
                }
            
            RecentTab(appState: appState)
                .tabItem {
                    Label("Recent", systemImage: "clock")
                }
            
            SettingsTab(settings: $appState.settings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct StudiesTab: View {
    @Bindable var appState: AppState
    
    var body: some View {
        NavigationStack {
            List {
                Text("Studies view")
            }
            .navigationTitle("Studies")
        }
    }
}

struct RecentTab: View {
    @Bindable var appState: AppState
    
    var body: some View {
        NavigationStack {
            List(appState.recentStudies) { study in
                Text(study.patientName)
            }
            .navigationTitle("Recent")
        }
    }
}

struct SettingsTab: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show Metadata", isOn: $settings.showMetadata)
                Toggle("Auto Load Pixel Data", isOn: $settings.autoLoadPixelData)
            }
            
            Section("Window/Level Defaults") {
                HStack {
                    Text("Window Center")
                    Spacer()
                    Text("\(Int(settings.defaultWindowCenter))")
                }
                
                Slider(value: $settings.defaultWindowCenter,
                       in: -1024...1024)
                
                HStack {
                    Text("Window Width")
                    Spacer()
                    Text("\(Int(settings.defaultWindowWidth))")
                }
                
                Slider(value: $settings.defaultWindowWidth,
                       in: 1...4096)
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Example 8: ViewModel Testing

// Test example - not executable in playground
/*
import XCTest

class DICOMFileViewModelTests: XCTestCase {
    func testLoadFile() async throws {
        // Arrange
        let mockService = MockDICOMFileService()
        mockService.fileToReturn = createMockDICOMFile()
        let viewModel = DICOMViewModelWithDI(fileService: mockService)
        let url = URL(fileURLWithPath: "/test.dcm")
        
        // Act
        await viewModel.load(from: url)
        
        // Assert
        XCTAssertNotNil(viewModel.dicomFile)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testLoadFileError() async throws {
        // Arrange
        let mockService = MockDICOMFileService()
        mockService.shouldThrowError = true
        let viewModel = DICOMViewModelWithDI(fileService: mockService)
        let url = URL(fileURLWithPath: "/test.dcm")
        
        // Act
        await viewModel.load(from: url)
        
        // Assert
        XCTAssertNil(viewModel.dicomFile)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    private func createMockDICOMFile() -> DICOMFile {
        // Create mock file for testing
        fatalError("Implement mock creation")
    }
}
*/

// MARK: - Example 9: Complete MVVM App Structure

// App entry point
@main
struct DICOMViewerApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// Main content view
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var studyBrowserVM = StudyBrowserViewModel()
    
    var body: some View {
        NavigationStack {
            StudyListView(viewModel: studyBrowserVM)
        }
    }
}

// Study list view
struct StudyListView: View {
    @Bindable var viewModel: StudyBrowserViewModel
    
    var body: some View {
        List(viewModel.filteredStudies) { study in
            NavigationLink(value: study) {
                StudyRowView(study: study)
            }
        }
        .searchable(text: $viewModel.searchText)
        .navigationTitle("Studies")
        .navigationDestination(for: DICOMStudy.self) { study in
            StudyDetailView(study: study)
        }
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                // Refresh logic
            }
        }
    }
}

// Study row component
struct StudyRowView: View {
    let study: DICOMStudy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(study.patientName)
                .font(.headline)
            
            Text(study.studyDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label(study.modality, systemImage: "waveform.path.ecg")
                Text(formattedDate(study.studyDate))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ dateString: String) -> String {
        guard dateString.count == 8 else { return dateString }
        let year = dateString.prefix(4)
        let month = dateString.dropFirst(4).prefix(2)
        let day = dateString.dropFirst(6)
        return "\(month)/\(day)/\(year)"
    }
}

// Study detail view
struct StudyDetailView: View {
    let study: DICOMStudy
    @State private var viewModel = StudyDetailViewModel()
    
    var body: some View {
        List {
            Section("Patient Information") {
                LabeledContent("Name", value: study.patientName)
                LabeledContent("Study Date", value: study.studyDate)
                LabeledContent("Modality", value: study.modality)
            }
            
            Section("Series") {
                ForEach(viewModel.series) { series in
                    Text("Series \(series.id)")
                }
            }
        }
        .navigationTitle(study.studyDescription)
        .task {
            await viewModel.loadSeries(for: study)
        }
    }
}

@Observable
class StudyDetailViewModel {
    var series: [SeriesInfo] = []
    var isLoading = false
    
    func loadSeries(for study: DICOMStudy) async {
        isLoading = true
        // Load series for study
        isLoading = false
    }
}

struct SeriesInfo: Identifiable {
    let id: String
    let description: String
}

// MARK: - Running the Examples

// Uncomment to run individual examples in your app:
// let url = URL(fileURLWithPath: "/path/to/file.dcm")
// Example1_BasicViewModel(fileURL: url)
// Example3_ImageViewerWithViewModel(fileURL: url)
// Example5_StudyBrowserViewModel()
// Example7_StateManagement()

// MARK: - Quick Reference

/*
 MVVM Architecture with SwiftUI:
 
 ViewModel Basics:
 • Separate business logic from UI
 • Observable state management
 • Async operations handling
 • Testable without UI
 
 @Observable (Swift 6):
 • Modern observation
 • Automatic change tracking
 • Better performance
 • Cleaner syntax
 • Use with @State in views
 
 @ObservableObject (Legacy):
 • Combine-based observation
 • @Published properties
 • Use with @StateObject/@ObservedObject
 • Backwards compatible
 
 View Annotations:
 • @State           - View-local state
 • @Bindable        - Two-way binding to @Observable
 • @Binding         - Two-way binding parameter
 • @Environment     - Shared environment values
 • @StateObject     - Create ObservableObject
 • @ObservedObject  - Receive ObservableObject
 
 Dependency Injection:
 • Protocol-based services
 • Constructor injection
 • Mock implementations for testing
 • Testable architecture
 • Swappable implementations
 
 Navigation Patterns:
 • NavigationStack with typed paths
 • @Observable navigation state
 • Programmatic navigation
 • Deep linking support
 • Back stack management
 
 State Management:
 • Single source of truth
 • Unidirectional data flow
 • Computed properties
 • Derived state
 • Minimal state
 
 Best Practices:
 
 ViewModel Design:
 1. Keep ViewModels platform-independent
 2. No SwiftUI imports in ViewModels
 3. Use protocols for dependencies
 4. Make ViewModels testable
 5. Handle errors gracefully
 6. Provide loading states
 7. Use async/await for operations
 8. Expose only necessary properties
 9. Use private for internal logic
 10. Document public interface
 
 View Design:
 1. Keep views simple and declarative
 2. Extract complex UI to components
 3. Use ViewModels for business logic
 4. Avoid direct data access in views
 5. Use @Bindable for two-way binding
 6. Pass dependencies explicitly
 7. Test views with PreviewProvider
 8. Support accessibility
 9. Handle all states (loading, error, success)
 10. Minimize view state
 
 Testing ViewModels:
 1. Use dependency injection
 2. Mock external dependencies
 3. Test async operations
 4. Verify state changes
 5. Test error handling
 6. Use XCTest framework
 7. Test edge cases
 8. Verify computed properties
 9. Test navigation logic
 10. Measure performance
 
 Common Patterns:
 
 Loading Pattern:
 • isLoading boolean
 • error optional
 • data optional
 • async load function
 • Loading/Error/Success states
 
 Navigation Pattern:
 • Path-based navigation
 • Enum for routes
 • NavigationViewModel
 • Type-safe destinations
 • Programmatic control
 
 Search/Filter Pattern:
 • Search text state
 • Filter criteria state
 • Computed filtered results
 • Reactive updates
 • Debouncing (optional)
 
 Multi-Tab Pattern:
 • Shared app state
 • Tab-specific ViewModels
 • Environment for global state
 • Independent navigation
 
 Form Pattern:
 • @Bindable for two-way binding
 • Validation in ViewModel
 • Save/cancel actions
 • Error display
 • Loading state
 
 DICOMKit Integration:
 
 File Loading:
 • Async loading in ViewModel
 • Error handling
 • Progress tracking
 • Background thread
 • Main thread UI updates
 
 Image Display:
 • ViewModel manages CGImage
 • Window/level state
 • Frame navigation
 • Async image generation
 
 Study/Series Management:
 • Hierarchical ViewModels
 • Lazy loading
 • Caching strategies
 • Search/filter logic
 
 Measurements:
 • Separate measurement ViewModel
 • Coordinate conversion
 • Real-world calculations
 • Export functionality
 
 Architecture Layers:
 
 1. View Layer (SwiftUI):
    • User interface
    • User interactions
    • Declarative layout
    • State binding
 
 2. ViewModel Layer:
    • Business logic
    • State management
    • Data transformation
    • Async operations
 
 3. Service Layer:
    • File I/O
    • Network operations
    • Data persistence
    • External APIs
 
 4. Model Layer:
    • Data structures
    • Domain models
    • DICOM types
    • Validation logic
 
 Error Handling:
 • Error property in ViewModel
 • Specific error types
 • User-friendly messages
 • Retry mechanisms
 • Logging for debugging
 
 Performance:
 • Minimize published properties
 • Use @Observable over ObservableObject
 • Lazy loading for heavy operations
 • Background processing
 • Cache expensive computations
 • Profile with Instruments
 
 Testing Strategy:
 
 Unit Tests:
 • ViewModel logic
 • State transitions
 • Computed properties
 • Error handling
 • Business rules
 
 Integration Tests:
 • ViewModel + Service
 • Full workflows
 • Error scenarios
 • Navigation flows
 
 UI Tests:
 • User interactions
 • Navigation
 • Search/filter
 • Error displays
 
 Common Pitfalls:
 
 1. UI code in ViewModels
 2. ViewModels referencing views
 3. Circular dependencies
 4. Not handling all states
 5. Synchronous heavy operations
 6. Retain cycles
 7. Not testing ViewModels
 8. Tight coupling
 9. Too much state
 10. Not using protocols for DI
 
 Tips:
 
 1. Start with @Observable in new code
 2. Use dependency injection
 3. Keep ViewModels focused
 4. Test business logic thoroughly
 5. Handle loading/error states
 6. Use environment for global state
 7. Prefer composition over inheritance
 8. Document public interfaces
 9. Follow SOLID principles
 10. Profile and optimize
 */

#endif // canImport(SwiftUI)
