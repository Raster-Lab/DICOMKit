// DICOMKit Sample Code: SwiftUI Study/Series Browser
//
// This example demonstrates how to:
// - Display studies and series in List and Grid views
// - Generate thumbnails from DICOM images
// - Implement search and filter functionality
// - Handle selection and navigation
// - Use SwiftData for persistence
// - Organize DICOM files hierarchically
// - Build patient/study/series browsers

#if canImport(SwiftUI)
import SwiftUI
import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Model Types

struct DICOMStudy: Identifiable, Hashable {
    let id: String  // Study Instance UID
    let patientName: String
    let patientID: String
    let studyDate: String
    let studyDescription: String
    let modality: String
    var series: [DICOMSeries] = []
    
    init(from file: DICOMFile) {
        let ds = file.dataSet
        self.id = ds.string(for: .studyInstanceUID) ?? UUID().uuidString
        self.patientName = ds.string(for: .patientName) ?? "Unknown"
        self.patientID = ds.string(for: .patientID) ?? "Unknown"
        self.studyDate = ds.string(for: .studyDate) ?? ""
        self.studyDescription = ds.string(for: .studyDescription) ?? "No Description"
        self.modality = ds.string(for: .modality) ?? "OT"
    }
}

struct DICOMSeries: Identifiable, Hashable {
    let id: String  // Series Instance UID
    let seriesNumber: Int
    let seriesDescription: String
    let modality: String
    let numberOfInstances: Int
    var instances: [DICOMInstance] = []
    
    init(from file: DICOMFile) {
        let ds = file.dataSet
        self.id = ds.string(for: .seriesInstanceUID) ?? UUID().uuidString
        self.seriesNumber = ds.int32(for: .seriesNumber).map(Int.init) ?? 0
        self.seriesDescription = ds.string(for: .seriesDescription) ?? "No Description"
        self.modality = ds.string(for: .modality) ?? "OT"
        self.numberOfInstances = 1
    }
}

struct DICOMInstance: Identifiable, Hashable {
    let id: String  // SOP Instance UID
    let instanceNumber: Int
    let fileURL: URL
    let thumbnailImage: CGImage?
    
    init(from file: DICOMFile, url: URL) {
        let ds = file.dataSet
        self.id = file.sopInstanceUID
        self.instanceNumber = ds.int32(for: .instanceNumber).map(Int.init) ?? 0
        self.fileURL = url
        
        // Generate thumbnail
        if let pixelData = file.pixelData,
           let windowCenter = ds.float64(for: .windowCenter),
           let windowWidth = ds.float64(for: .windowWidth),
           let cgImage = try? pixelData.createCGImage(
               frame: 0,
               windowCenter: windowCenter,
               windowWidth: windowWidth
           ) {
            self.thumbnailImage = cgImage
        } else {
            self.thumbnailImage = nil
        }
    }
}

// MARK: - Example 1: Simple Study List

struct Example1_StudyList: View {
    @State private var studies: [DICOMStudy] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List(studies) { study in
                NavigationLink(value: study) {
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
            }
            .navigationTitle("Studies")
            .navigationDestination(for: DICOMStudy.self) { study in
                Text("Study Detail: \(study.patientName)")
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading studies...")
                }
            }
            .task {
                await loadStudies()
            }
        }
    }
    
    private func loadStudies() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load DICOM files from directory
        // In real app, this would scan a directory
        // For example purposes, we'll create sample data
        studies = []  // Populate from your DICOM files
    }
    
    private func formattedDate(_ dateString: String) -> String {
        // DICOM date format: YYYYMMDD
        guard dateString.count == 8 else { return dateString }
        let year = dateString.prefix(4)
        let month = dateString.dropFirst(4).prefix(2)
        let day = dateString.dropFirst(6)
        return "\(month)/\(day)/\(year)"
    }
}

// MARK: - Example 2: Series Grid View

struct Example2_SeriesGrid: View {
    let study: DICOMStudy
    
    @State private var series: [DICOMSeries] = []
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(series) { seriesItem in
                    NavigationLink(value: seriesItem) {
                        SeriesCard(series: seriesItem)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(study.studyDescription)
        .navigationDestination(for: DICOMSeries.self) { seriesItem in
            Text("Series: \(seriesItem.seriesDescription)")
        }
        .task {
            loadSeries()
        }
    }
    
    private func loadSeries() {
        series = study.series
    }
}

struct SeriesCard: View {
    let series: DICOMSeries
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1.0, contentMode: .fit)
                .overlay {
                    if let thumbnail = series.instances.first?.thumbnailImage {
                        #if os(macOS)
                        Image(thumbnail, scale: 1.0, label: Text(""))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        #else
                        Image(uiImage: UIImage(cgImage: thumbnail))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        #endif
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(series.seriesDescription)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(series.modality)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Text("\(series.numberOfInstances) images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Example 3: Search and Filter

struct Example3_SearchableStudyList: View {
    @State private var studies: [DICOMStudy] = []
    @State private var searchText = ""
    @State private var selectedModality: String = "All"
    
    private let modalities = ["All", "CT", "MR", "US", "CR", "DX", "MG", "PT"]
    
    var filteredStudies: [DICOMStudy] {
        var result = studies
        
        // Filter by modality
        if selectedModality != "All" {
            result = result.filter { $0.modality == selectedModality }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.patientName.localizedCaseInsensitiveContains(searchText) ||
                $0.patientID.localizedCaseInsensitiveContains(searchText) ||
                $0.studyDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Modality filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(modalities, id: \.self) { modality in
                            Button(action: {
                                selectedModality = modality
                            }) {
                                Text(modality)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedModality == modality ?
                                        Color.blue : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedModality == modality ?
                                        .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Study list
                List(filteredStudies) { study in
                    StudyRow(study: study)
                }
                .searchable(text: $searchText, prompt: "Search patients or studies")
            }
            .navigationTitle("DICOM Browser")
        }
    }
}

struct StudyRow: View {
    let study: DICOMStudy
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Modality icon
            Image(systemName: modalityIcon(study.modality))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(study.patientName)
                    .font(.headline)
                
                Text(study.studyDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(study.patientID, systemImage: "person.text.rectangle")
                    Label(study.studyDate, systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func modalityIcon(_ modality: String) -> String {
        switch modality {
        case "CT": return "brain"
        case "MR": return "waveform.path.ecg"
        case "US": return "waveform"
        case "CR", "DX": return "lungs"
        case "MG": return "heart.text.square"
        case "PT": return "dot.radiowaves.left.and.right"
        default: return "doc.text.image"
        }
    }
}

// MARK: - Example 4: Thumbnail Generator

class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private var cache: [String: CGImage] = [:]
    
    func thumbnail(for file: DICOMFile, instanceUID: String) async -> CGImage? {
        // Check cache
        if let cached = cache[instanceUID] {
            return cached
        }
        
        // Generate thumbnail
        guard let pixelData = file.pixelData else { return nil }
        
        let dataSet = file.dataSet
        let windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
        let windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
        
        guard let fullImage = try? pixelData.createCGImage(
            frame: 0,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        ) else {
            return nil
        }
        
        // Create thumbnail (in real app, resize the image)
        cache[instanceUID] = fullImage
        return fullImage
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Example 5: Instance Grid with Thumbnails

struct Example5_InstanceGrid: View {
    let series: DICOMSeries
    
    @State private var instances: [DICOMInstance] = []
    @State private var selectedInstance: DICOMInstance?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(instances) { instance in
                    InstanceThumbnail(instance: instance)
                        .onTapGesture {
                            selectedInstance = instance
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Series \(series.seriesNumber)")
        .sheet(item: $selectedInstance) { instance in
            InstanceViewer(instance: instance)
        }
        .task {
            instances = series.instances.sorted { $0.instanceNumber < $1.instanceNumber }
        }
    }
}

struct InstanceThumbnail: View {
    let instance: DICOMInstance
    
    var body: some View {
        VStack(spacing: 4) {
            if let thumbnail = instance.thumbnailImage {
                #if os(macOS)
                Image(thumbnail, scale: 1.0, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #else
                Image(uiImage: UIImage(cgImage: thumbnail))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
            }
            
            Text("#\(instance.instanceNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InstanceViewer: View {
    let instance: DICOMInstance
    
    var body: some View {
        VStack {
            if let thumbnail = instance.thumbnailImage {
                #if os(macOS)
                Image(thumbnail, scale: 1.0, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: thumbnail))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            }
            
            Text("Instance \(instance.instanceNumber)")
                .font(.headline)
        }
        .padding()
    }
}

// MARK: - Example 6: Hierarchical Navigation

struct Example6_HierarchicalBrowser: View {
    @State private var studies: [DICOMStudy] = []
    
    var body: some View {
        NavigationStack {
            List(studies) { study in
                Section {
                    ForEach(study.series) { series in
                        NavigationLink(value: series) {
                            HStack {
                                Text("Series \(series.seriesNumber)")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(series.numberOfInstances)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(study.patientName)
                            .font(.headline)
                        Text(study.studyDescription)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("DICOM Studies")
            .navigationDestination(for: DICOMSeries.self) { series in
                Example5_InstanceGrid(series: series)
            }
        }
    }
}

// MARK: - Example 7: SwiftData Integration

#if canImport(SwiftData)
import SwiftData

@Model
final class PersistedStudy {
    @Attribute(.unique) var studyInstanceUID: String
    var patientName: String
    var patientID: String
    var studyDate: String
    var studyDescription: String
    var modality: String
    var series: [PersistedSeries]
    
    init(studyInstanceUID: String, patientName: String, patientID: String,
         studyDate: String, studyDescription: String, modality: String) {
        self.studyInstanceUID = studyInstanceUID
        self.patientName = patientName
        self.patientID = patientID
        self.studyDate = studyDate
        self.studyDescription = studyDescription
        self.modality = modality
        self.series = []
    }
}

@Model
final class PersistedSeries {
    @Attribute(.unique) var seriesInstanceUID: String
    var seriesNumber: Int
    var seriesDescription: String
    var modality: String
    var study: PersistedStudy?
    
    init(seriesInstanceUID: String, seriesNumber: Int,
         seriesDescription: String, modality: String) {
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
    }
}

struct Example7_SwiftDataBrowser: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var studies: [PersistedStudy]
    
    var body: some View {
        NavigationStack {
            List(studies) { study in
                VStack(alignment: .leading) {
                    Text(study.patientName)
                        .font(.headline)
                    Text(study.studyDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Studies (SwiftData)")
            .toolbar {
                Button("Import", systemImage: "square.and.arrow.down") {
                    importStudy()
                }
            }
        }
    }
    
    private func importStudy() {
        // Import DICOM file and persist to SwiftData
        let study = PersistedStudy(
            studyInstanceUID: UUID().uuidString,
            patientName: "Sample Patient",
            patientID: "12345",
            studyDate: "20240101",
            studyDescription: "Sample Study",
            modality: "CT"
        )
        modelContext.insert(study)
    }
}
#endif

// MARK: - Example 8: Batch Operations

struct Example8_BatchOperations: View {
    @State private var instances: [DICOMInstance] = []
    @State private var selectedInstances: Set<DICOMInstance.ID> = []
    @State private var isSelectionMode = false
    
    var body: some View {
        VStack {
            List(instances, selection: $selectedInstances) { instance in
                HStack {
                    if let thumbnail = instance.thumbnailImage {
                        #if os(macOS)
                        Image(thumbnail, scale: 1.0, label: Text(""))
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        #else
                        Image(uiImage: UIImage(cgImage: thumbnail))
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        #endif
                    }
                    
                    Text("Instance \(instance.instanceNumber)")
                    
                    Spacer()
                    
                    if isSelectionMode {
                        Image(systemName: selectedInstances.contains(instance.id) ?
                              "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            #if os(iOS)
            .environment(\.editMode, isSelectionMode ? .constant(.active) : .constant(.inactive))
            #endif
            
            if isSelectionMode {
                HStack {
                    Button("Export \(selectedInstances.count)") {
                        exportSelected()
                    }
                    .disabled(selectedInstances.isEmpty)
                    
                    Spacer()
                    
                    Button("Delete \(selectedInstances.count)") {
                        deleteSelected()
                    }
                    .disabled(selectedInstances.isEmpty)
                    .foregroundColor(.red)
                }
                .padding()
            }
        }
        .navigationTitle("Instances")
        .toolbar {
            Button(isSelectionMode ? "Done" : "Select") {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedInstances.removeAll()
                }
            }
        }
    }
    
    private func exportSelected() {
        // Export selected instances
        print("Exporting \(selectedInstances.count) instances")
    }
    
    private func deleteSelected() {
        instances.removeAll { selectedInstances.contains($0.id) }
        selectedInstances.removeAll()
    }
}

// MARK: - Example 9: Complete Study Browser

struct Example9_CompleteBrowser: View {
    @State private var studies: [DICOMStudy] = []
    @State private var searchText = ""
    @State private var selectedModality = "All"
    @State private var sortOrder: SortOrder = .dateDescending
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case patientName = "Patient Name"
        
        func sort(_ studies: [DICOMStudy]) -> [DICOMStudy] {
            switch self {
            case .dateDescending:
                return studies.sorted { $0.studyDate > $1.studyDate }
            case .dateAscending:
                return studies.sorted { $0.studyDate < $1.studyDate }
            case .patientName:
                return studies.sorted { $0.patientName < $1.patientName }
            }
        }
    }
    
    var filteredStudies: [DICOMStudy] {
        var result = studies
        
        // Filter by modality
        if selectedModality != "All" {
            result = result.filter { $0.modality == selectedModality }
        }
        
        // Search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.patientName.localizedCaseInsensitiveContains(searchText) ||
                $0.studyDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        return sortOrder.sort(result)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                VStack(spacing: 10) {
                    // Modality filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["All", "CT", "MR", "US", "CR"], id: \.self) { modality in
                                FilterChip(
                                    title: modality,
                                    isSelected: selectedModality == modality
                                ) {
                                    selectedModality = modality
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sort picker
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Study list
                List(filteredStudies) { study in
                    NavigationLink(value: study) {
                        CompactStudyRow(study: study)
                    }
                }
                .searchable(text: $searchText, prompt: "Search studies")
            }
            .navigationTitle("DICOM Browser")
            .navigationDestination(for: DICOMStudy.self) { study in
                Example2_SeriesGrid(study: study)
            }
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await loadStudies() }
                }
            }
        }
    }
    
    private func loadStudies() async {
        // Load studies from directory
        // Implementation would scan directory and organize files
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CompactStudyRow: View {
    let study: DICOMStudy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(study.patientName)
                    .font(.headline)
                Spacer()
                Text(formattedDate(study.studyDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(study.studyDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(study.modality, systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                
                Text("\(study.series.count) series")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

// MARK: - Running the Examples

// Uncomment to run individual examples in your app:
// Example1_StudyList()
// Example3_SearchableStudyList()
// Example6_HierarchicalBrowser()
// Example9_CompleteBrowser()

// MARK: - Quick Reference

/*
 SwiftUI Study/Series Browser:
 
 List Views:
 • List(items) { }         - Basic list
 • List(selection:) { }    - Selectable list
 • Section(header:) { }    - Grouped sections
 • .searchable()           - Search bar
 • .listStyle()            - List appearance
 
 Grid Views:
 • LazyVGrid(columns:)     - Vertical grid
 • LazyHGrid(rows:)        - Horizontal grid
 • GridItem(.adaptive)     - Responsive columns
 • GridItem(.flexible)     - Flexible sizing
 • GridItem(.fixed)        - Fixed size
 
 Navigation:
 • NavigationStack         - Modern navigation
 • NavigationLink(value:)  - Type-safe links
 • .navigationDestination  - Destination views
 • .sheet(item:)           - Modal presentation
 • .fullScreenCover()      - Full screen modal
 
 Search and Filter:
 • .searchable(text:)      - Search functionality
 • Picker for filters      - Category selection
 • Custom filter chips     - Visual filters
 • Array.filter { }        - Filter logic
 
 Sorting:
 • .sorted { }             - Custom sorting
 • Comparable protocol     - Default sorting
 • Multiple sort keys      - Complex sorting
 • Picker for sort order   - User selection
 
 Selection:
 • @State var selected     - Selection state
 • Set<ID>                 - Multi-selection
 • .onTapGesture           - Handle taps
 • EditMode                - iOS selection mode
 
 Data Models:
 • Identifiable protocol   - List/ForEach requirement
 • Hashable for navigation - NavigationLink value
 • Codable for persistence - Save/load data
 • @Model for SwiftData    - Database persistence
 
 SwiftData Integration:
 • @Model macro            - Data model
 • @Query property         - Fetch data
 • ModelContext            - Insert/delete/save
 • @Attribute(.unique)     - Unique constraint
 • Relationships           - One-to-many, etc.
 
 Thumbnails:
 • Async loading           - Background generation
 • Caching strategy        - Avoid regeneration
 • LazyVGrid/LazyHGrid     - Lazy loading
 • Task.detached           - Background work
 
 Performance:
 • LazyVStack/LazyHStack   - Lazy loading
 • @State for local data   - View state
 • @StateObject lifecycle  - Object management
 • Task cancellation       - Cancel on dismiss
 • Image caching           - Reuse thumbnails
 
 Common Patterns:
 
 Study/Series/Instance Hierarchy:
 • Study → Series → Instance
 • NavigationStack with type-safe destinations
 • Drill-down navigation
 • Back button automatic
 
 Filter Pattern:
 • @State for filter values
 • Computed property for filtered results
 • Multiple filter dimensions
 • Clear all filters button
 
 Search Pattern:
 • .searchable(text:)
 • Filter in computed property
 • Case-insensitive contains
 • Multiple field search
 
 Selection Pattern:
 • Toggle selection mode
 • Set<ID> for selections
 • Batch operations toolbar
 • Select all / clear all
 
 Thumbnail Pattern:
 • Generate on background queue
 • Cache by UID
 • Placeholder while loading
 • Async/await for generation
 
 Best Practices:
 
 1. Use lazy loading for large lists
 2. Generate thumbnails asynchronously
 3. Cache generated images
 4. Implement pagination for huge datasets
 5. Provide loading states
 6. Handle empty states gracefully
 7. Support pull-to-refresh
 8. Use proper data models (Identifiable, Hashable)
 9. Organize by study/series hierarchy
 10. Implement search across multiple fields
 11. Allow filtering by modality, date, etc.
 12. Support batch operations
 13. Persist viewed studies (SwiftData)
 14. Handle file system errors
 15. Show study/series counts
 
 DICOM Organization:
 
 Patient Level:
 • Patient Name, ID
 • Multiple studies per patient
 
 Study Level:
 • Study Instance UID (unique)
 • Study Date, Description
 • Modality
 • Multiple series per study
 
 Series Level:
 • Series Instance UID (unique)
 • Series Number, Description
 • Modality
 • Multiple instances per series
 
 Instance Level:
 • SOP Instance UID (unique)
 • Instance Number
 • File path/URL
 • Pixel data
 
 Key DICOM Tags:
 • .patientName (0010,0010)
 • .patientID (0010,0020)
 • .studyInstanceUID (0020,000D)
 • .studyDate (0008,0020)
 • .studyDescription (0008,1030)
 • .seriesInstanceUID (0020,000E)
 • .seriesNumber (0020,0011)
 • .seriesDescription (0008,103E)
 • .sopInstanceUID (0008,0018)
 • .instanceNumber (0020,0013)
 • .modality (0008,0060)
 
 Tips:
 
 1. Organize files by study/series structure
 2. Use UIDs as unique identifiers
 3. Generate thumbnails lazily
 4. Cache frequently accessed data
 5. Support incremental loading
 6. Implement robust error handling
 7. Validate DICOM files before display
 8. Support both grid and list views
 9. Enable multi-selection for batch ops
 10. Persist user preferences (sort, filters)
 */

#endif // canImport(SwiftUI)
