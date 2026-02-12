# DICOMToolbox - macOS GUI for DICOMKit CLI Tools

A native macOS SwiftUI application that provides a graphical interface for all 29 DICOMKit command-line tools. Designed to be educational for new users and convenient for experienced users.

## Features

### Tool Organization
- **6 Category Tabs**: File Analysis, Imaging, Networking, DICOMweb, Advanced, Utilities
- **29 Tools** with full parameter support organized into logical groups
- Tool sidebar with search and category filtering

### Interactive Parameter Configuration
- **Radio buttons** for mutually exclusive options
- **Toggle switches** for boolean flags
- **Dropdown menus** for enumerated options with descriptions
- **Text fields** for free-form input with placeholders
- **File picker** with native macOS open/save panels
- **Drag-and-drop** targets for file input parameters
- **Help popovers** with detailed parameter explanations

### Network Configuration
- **Always-visible PACS configuration bar** above the tab interface
- Auto-fills network parameters (AE Titles, hostname, port) across all network tools
- Separate DICOMweb URL configuration
- Visual indicator for connection status

### Command Console
- **Live command preview** in monospace text (SF Mono) at the bottom
- Shows the exact CLI syntax as the user configures parameters
- **Execute button** becomes active only when the command is valid
- Missing required parameters shown with warning indicator
- **Copy to clipboard** for the generated command
- Output displayed in the same console area with syntax highlighting

### Design
- Native macOS SwiftUI following Apple Human Interface Design Guidelines
- Resizable split-view layout
- Dark mode support
- Keyboard accessible

## Architecture

```
DICOMToolbox-macOS/
├── App/
│   └── DICOMToolboxApp.swift          # App entry point
├── Models/
│   ├── ToolCategory.swift             # Tool category enum
│   ├── ToolDefinition.swift           # Tool/subcommand definitions
│   ├── ToolParameter.swift            # Parameter types and metadata
│   ├── PACSConfiguration.swift        # PACS network config model
│   ├── ToolRegistry.swift             # Central tool registry
│   ├── ToolRegistry+FileAnalysis.swift
│   ├── ToolRegistry+Imaging.swift
│   ├── ToolRegistry+Networking.swift
│   ├── ToolRegistry+DICOMweb.swift
│   ├── ToolRegistry+Advanced.swift
│   └── ToolRegistry+Utilities.swift
├── ViewModels/
│   └── ToolboxViewModel.swift         # Main app state management
├── Views/
│   ├── ContentView.swift              # Root layout with sidebar + detail
│   ├── PACSConfigurationView.swift    # Network settings bar
│   ├── ToolDetailView.swift           # Tool parameter form
│   ├── ParameterInputView.swift       # Dynamic parameter input controls
│   ├── FileDropTarget.swift           # Drag-and-drop file zone
│   └── ConsoleView.swift              # Command preview + execution output
├── Services/
│   ├── CommandBuilder.swift           # CLI command string builder
│   └── CommandExecutor.swift          # Process execution service
├── Tests/
│   ├── ToolRegistryTests.swift
│   └── CommandBuilderTests.swift
├── project.yml                        # XcodeGen configuration
├── Info.plist
└── README.md
```

## Building

### Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 15+
- XcodeGen (for project generation)

### Setup

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project
cd DICOMToolbox-macOS
xcodegen generate

# Build the CLI tools first (so they can be executed)
cd ..
swift build

# Open the generated Xcode project
open DICOMToolbox-macOS/DICOMToolbox.xcodeproj
```

### Build & Run
1. Open `DICOMToolbox.xcodeproj` in Xcode
2. Select the DICOMToolbox scheme
3. Build and run (⌘R)

## Usage

1. **Configure PACS** (optional): Click the network configuration bar to set up your PACS server connection details
2. **Select a Category**: Choose from the category tabs (File Analysis, Imaging, etc.)
3. **Choose a Tool**: Select a tool from the sidebar list
4. **Configure Parameters**: Fill in the required parameters using the form controls
5. **Review Command**: Check the generated CLI command in the bottom console
6. **Execute**: Click Execute when the command is valid to run it

## Requirements
- macOS 14.0+
- Swift 5.9+
- DICOMKit framework
