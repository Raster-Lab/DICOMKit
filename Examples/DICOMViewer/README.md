# DICOMViewer Example Application

An example SwiftUI application demonstrating the capabilities of DICOMKit for browsing and viewing DICOM images from PACS servers.

## Features

### Phase 1 (Current)
- ✅ PACS server configuration and management
- ✅ Connection testing with C-ECHO verification
- ✅ Patient search with wildcards support
- ✅ Patient → Study → Series hierarchy navigation
- ✅ Multi-platform support (iOS, macOS, visionOS)

### Phase 2 (Coming Soon)
- Image retrieval from PACS (C-GET)
- DICOM image rendering
- Image manipulation (windowing, pan, zoom)

## Requirements

- **macOS 14.0 (Sonoma)** or later for development
- **Xcode 16.0** or later (for Swift 6.2)
- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+ for running

## 🚀 How to Run the Application

### Option 1: Quick Start with Xcode (Recommended)

1. **Clone the DICOMKit repository** (if not already done):
   ```bash
   git clone https://github.com/raster-image/DICOMKit.git
   cd DICOMKit
   ```

2. **Create a new Xcode project**:
   - Open Xcode
   - Select **File → New → Project...**
   - Choose **App** under iOS or macOS
   - Product Name: `DICOMViewerApp`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click **Next** and choose a location

3. **Add DICOMKit as a dependency**:
   - Select your project in the Navigator
   - Go to **Package Dependencies** tab
   - Click **+** and enter: `https://github.com/raster-image/DICOMKit.git`
   - Click **Add Package**
   - Select all libraries (DICOMKit, DICOMCore, DICOMNetwork, DICOMDictionary)
   - Click **Add Package**

4. **Add the example source files**:
   - In Finder, navigate to `DICOMKit/Examples/DICOMViewer/`
   - Drag these folders into your Xcode project:
     - `App/` (AppState.swift, DICOMViewerApp.swift)
     - `Models/` (all .swift files)
     - `Views/` (all .swift files)
     - `Services/` (all .swift files)
   - When prompted, check **Copy items if needed** and your target

5. **Update your main App file**:
   - Delete the auto-generated `DICOMViewerAppApp.swift` (or similar)
   - The `DICOMViewerApp.swift` from the example will be your entry point

6. **Build and Run**:
   - Select your target device (iPhone simulator, Mac, etc.)
   - Press **⌘R** to build and run

### Option 2: Create Project via Command Line

```bash
# Clone repository
git clone https://github.com/raster-image/DICOMKit.git
cd DICOMKit

# Open the Package.swift to explore the library
open Package.swift
```

Then follow steps 2-6 from Option 1.

### Option 3: Integrate into Existing Project

If you already have a SwiftUI project:

1. Add DICOMKit package dependency (see step 3 above)
2. Copy the files from `Examples/DICOMViewer/` into your project
3. In your main App file, use `ContentView` from the example:

```swift
import SwiftUI

@main
struct YourApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
```

## Project Structure

```
DICOMViewer/
├── App/
│   ├── DICOMViewerApp.swift      # Main app entry point
│   └── AppState.swift            # Global state management
├── Models/
│   ├── PACSServer.swift          # PACS server configuration
│   ├── PatientSearchCriteria.swift # Search parameters
│   └── QueryResultModels.swift   # Display models
├── Views/
│   ├── ContentView.swift         # Root navigation view
│   ├── ServerListView.swift      # Server list and management
│   ├── ServerConfigView.swift    # Server configuration form
│   ├── PatientSearchView.swift   # Patient search form
│   ├── StudyListView.swift       # Studies for a patient
│   └── SeriesListView.swift      # Series within a study
├── Services/
│   ├── ServerStorageService.swift    # Server persistence
│   ├── ConnectionTestService.swift   # C-ECHO testing
│   └── PACSQueryService.swift        # PACS queries
└── Tests/                            # Unit tests
```

## 📱 Using the Application

Once running, the app provides a complete PACS browsing experience:

### 1. Configure a PACS Server
- Tap **+** on the Server List screen
- Enter connection details:
  | Field | Description | Example |
  |-------|-------------|---------|
  | Server Name | Display name | "Hospital PACS" |
  | Host | IP or hostname | "192.168.1.100" |
  | Port | DICOM port | 11112 |
  | Called AE | Remote PACS AE Title | "PACS_SCP" |
  | Calling AE | This app's AE Title | "DICOMVIEWER" |
- Tap **Test Connection** to verify connectivity
- Tap **Save** to store the configuration

### 2. Search for Patients
- Tap on a configured server to open Patient Search
- Enter search criteria:
  - **Patient Name**: Supports wildcards (`SMITH*`, `*JOHN*`)
  - **Patient ID**: Exact or wildcard match
  - **Sex**: Optional filter
  - **Birth Date Range**: Optional date filter
- Use **Quick Filters** for today/this week/this month
- Tap **Search** to query the PACS

### 3. Browse Study Hierarchy
- Tap a patient to see their studies
- Tap a study to see its series
- Series view shows modality, description, and image count

## 🧪 Testing with a DICOM Server

To test the application, you need a DICOM server. Options include:

### Public Test Servers
- **Orthanc Demo**: `demo.orthanc-server.com:4242` (AE: ORTHANC)
- **DCM4CHEE Demo**: Various public instances available

### Local Test Server (Recommended)
Install Orthanc locally using Docker:

```bash
docker run -p 4242:4242 -p 8042:8042 jodogne/orthanc
```

Then configure:
- Host: `localhost`
- Port: `4242`
- Called AE: `ORTHANC`
- Calling AE: `DICOMVIEWER`

### Upload Test DICOM Files
Access Orthanc's web interface at `http://localhost:8042` to upload DICOM files for testing.

## Architecture

The application follows the **MVVM** (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for PACS servers, search criteria, and query results
- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management (expanded in Phase 2)
- **Services**: Network and persistence services

### State Management

Uses Swift's new `@Observable` macro for reactive state management:

```swift
@Observable
final class AppState {
    var servers: [PACSServer] = []
    var selectedServer: PACSServer?
    var patientResults: [PatientDisplayModel] = []
    // ...
}
```

### Navigation

Uses SwiftUI's `NavigationStack` with type-safe navigation paths:

```swift
enum AppScreen: Hashable {
    case serverList
    case patientSearch(server: PACSServer)
    case studyList(server: PACSServer, patient: PatientDisplayModel)
    case seriesList(server: PACSServer, study: StudyDisplayModel)
    case imageViewer(server: PACSServer, series: SeriesDisplayModel)
}
```

## Usage Examples

### Adding a Server

```swift
let server = PACSServer(
    name: "Hospital PACS",
    host: "pacs.hospital.com",
    port: 11112,
    calledAETitle: "PACS",
    callingAETitle: "DICOMVIEWER"
)

try ServerStorageService.shared.addServer(server)
```

### Testing Connection

```swift
let status = await ConnectionTestService.shared.testConnection(to: server)
if status.success {
    print("Connected in \(status.responseTimeMs ?? 0)ms")
} else {
    print("Failed: \(status.errorMessage ?? "Unknown error")")
}
```

### Searching Patients

```swift
let criteria = PatientSearchCriteria(
    patientName: "SMITH*",
    sex: .male
)

let patients = try await PACSQueryService.shared.findPatients(
    on: server,
    matching: criteria
)
```

## License

This example is part of DICOMKit and shares its MIT license.

## Troubleshooting

### "No such module 'DICOMKit'" Error
- Ensure DICOMKit package is added to your project's Package Dependencies
- Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
- Reset package caches: **File → Packages → Reset Package Caches**

### Connection Test Fails
- Verify the PACS server is running and accessible
- Check firewall settings allow connections on the DICOM port
- Verify AE Title configuration matches the server's settings
- Try using `localhost` instead of `127.0.0.1` (or vice versa)

### App Crashes on Launch
- Ensure you're targeting iOS 17+ / macOS 14+ / visionOS 1.0+
- Check that all required files from `Examples/DICOMViewer/` are included
- Verify the `@main` attribute is only on one App struct

### Search Returns No Results
- Verify the PACS server has patient data (use web interface if available)
- Try a broader search with wildcards (e.g., `*` for all patients)
- Check the PACS server logs for query rejections

For more help, see the main [DICOMKit documentation](../../README.md) or open an issue on GitHub.
