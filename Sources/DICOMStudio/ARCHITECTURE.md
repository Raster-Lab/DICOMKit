# DICOM Studio — Architecture

## Overview

DICOM Studio is a macOS SwiftUI application showcasing DICOMKit. It follows **MVVM** (Model–View–ViewModel) with a service layer, using Swift 6.2 strict concurrency and the `@Observable` macro.

## Directory Structure

```
Sources/DICOMStudio/
├── App/                        # Application entry point
│   └── DICOMStudioApp.swift    # @main (macOS only)
├── Models/                     # Data models (pure Swift, Sendable)
│   ├── StudyModel.swift        # Study-level DICOM metadata
│   ├── SeriesModel.swift       # Series-level DICOM metadata
│   ├── InstanceModel.swift     # Instance-level DICOM metadata
│   └── LibraryModel.swift      # In-memory file library/index
├── Services/                   # Business logic layer
│   ├── DICOMFileService.swift  # File I/O via DICOMKit
│   ├── ThumbnailService.swift  # Thumbnail generation/caching
│   ├── StorageService.swift    # Local file system management
│   ├── SettingsService.swift   # User preferences
│   └── NavigationService.swift # Routing and destinations
├── ViewModels/                 # @Observable ViewModels
│   ├── MainViewModel.swift     # Top-level navigation & state
│   └── SettingsViewModel.swift # Settings UI state
├── Views/                      # SwiftUI views (macOS/iOS)
│   ├── MainView.swift          # NavigationSplitView shell
│   ├── SidebarView.swift       # Sidebar navigation list
│   └── Settings/               # Settings tab views
│       ├── SettingsView.swift
│       ├── GeneralSettingsView.swift
│       ├── PrivacySettingsView.swift
│       ├── PerformanceSettingsView.swift
│       └── AboutView.swift
├── Components/                 # Reusable UI components
│   ├── DICOMTagView.swift      # (GGGG,EEEE) tag display
│   ├── VRBadge.swift           # Value Representation badge
│   ├── ModalityIcon.swift      # Modality-specific SF Symbol
│   └── StatusIndicator.swift   # Connection/transfer status
└── Theme/
    └── StudioTheme.swift       # Colors, typography constants
```

## Architecture Layers

### Models (Pure Swift)

All models are `Sendable` value types (`struct`) with no UI dependencies:

- **`StudyModel`** — Patient demographics, study metadata, modality tracking
- **`SeriesModel`** — Series number, modality, body part, transfer syntax
- **`InstanceModel`** — SOP UIDs, file path, image dimensions, multi-frame detection
- **`LibraryModel`** — In-memory index with study → series → instance hierarchy

### Services (Dependency-Injected)

Services encapsulate business logic and are injected into ViewModels:

| Service | Responsibility | Thread Safety |
|---------|---------------|---------------|
| `DICOMFileService` | Parse DICOM files via DICOMKit | `Sendable` |
| `ThumbnailService` | Generate/cache thumbnails | `Sendable` |
| `StorageService` | Manage directories (import, cache, export) | `Sendable` |
| `SettingsService` | Read/write user preferences | `@unchecked Sendable` (NSLock) |
| `NavigationService` | Define navigation destinations | `Sendable` |

### ViewModels (`@Observable`)

ViewModels use the `@Observable` macro (requires macOS 14+ / Swift 5.9+):

- **`MainViewModel`** — Owns all services, manages navigation, library state, status
- **`SettingsViewModel`** — Two-way binding to `SettingsService`, auto-persists changes

### Views (SwiftUI, `#if canImport(SwiftUI)`)

All SwiftUI code is wrapped in `#if canImport(SwiftUI)` for cross-platform library compilation:

- **`MainView`** — `NavigationSplitView` with sidebar + detail
- **`SidebarView`** — Lists 7 feature areas with SF Symbol icons
- **Settings views** — Tabbed on macOS, navigation stack on iOS

### Components (Reusable)

Platform-guarded SwiftUI components with full accessibility support:

| Component | Purpose | Accessibility |
|-----------|---------|--------------|
| `DICOMTagView` | Display `(GGGG,EEEE)` tag | Combined label with keyword |
| `VRBadge` | Color-coded VR type | Full VR name spoken |
| `ModalityIcon` | SF Symbol per modality | Full modality name spoken |
| `StatusIndicator` | Status dot + label | Status announced with context |

## Navigation Destinations

| Destination | SF Symbol | Description |
|------------|-----------|-------------|
| Library | `folder` | DICOM file browser (Milestone 2) |
| Viewer | `photo` | Image viewer (Milestone 3) |
| Networking | `network` | DICOM/DICOMweb hub (Milestone 9–10) |
| Reporting | `doc.text` | Structured reports (Milestone 7) |
| Tools | `wrench.and.screwdriver` | Data exchange tools (Milestone 12–13) |
| CLI Workshop | `terminal` | CLI tools GUI (Milestone 16) |
| Settings | `gear` | App configuration |

## Theme

### Color Palette

Medical imaging–appropriate colors defined in `StudioColors`:

- **Primary**: Teal blue (`#3899C7`) for navigation and actions
- **Background**: Deep navy (`#0F1219`) for radiology dark mode
- **Modality colors**: CT (blue), MR (purple), US (green), XR (amber)
- **Status colors**: Success (green), Warning (amber), Error (red)

### Typography Scale

Defined in `StudioTypography` using `CGFloat` constants that pair with Dynamic Type:

| Style | Size | Usage |
|-------|------|-------|
| Display | 28pt | Main titles |
| Header | 20pt | Section headers |
| Body | 14pt | Content text |
| Caption | 11pt | Details, labels |
| Mono | 12pt | Tags, UIDs |

## Testing

124 tests across 13 test suites covering:

- **Model tests**: Creation, defaults, display formatting, sorting, hierarchy
- **Service tests**: Settings persistence, storage operations, thumbnail caching
- **ViewModel tests**: Navigation, state management, dependency injection
- **Theme tests**: Color validation, modality mapping, typography scale

## Dependencies

- **DICOMKit** — DICOM file parsing, data sets
- **DICOMCore** — Tags, VR, data elements, transfer syntax
- **DICOMDictionary** — Tag and UID dictionaries
- **Observation** — `@Observable` macro (Swift standard library)
- **SwiftUI** — UI framework (Apple platforms only)

## Platform Support

| Layer | Linux | macOS | iOS | visionOS |
|-------|-------|-------|-----|----------|
| Models | ✅ | ✅ | ✅ | ✅ |
| Services | ✅ | ✅ | ✅ | ✅ |
| ViewModels | ✅ | ✅ | ✅ | ✅ |
| Views | ❌ | ✅ | ✅ | ✅ |
| Components | ❌ | ✅ | ✅ | ✅ |
| Tests | ✅ | ✅ | ✅ | ✅ |
