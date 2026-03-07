# DICOM Studio v2.0 — CLI Shell Redesign Milestones

## Overview

DICOM Studio v2.0 is a fundamental architectural redesign, transforming the application from a
library-embedding showcase app into a **native macOS shell** for the 38 DICOMKit command-line tools.
Inspired by Apple's now-discontinued **Network Utility**, the new DICOM Studio provides a polished
graphical interface for every CLI tool while delegating all DICOM processing to the installed
command-line binaries.

### Design Philosophy

1. **Shell, Not Library** — DICOM Studio does not link against DICOMKit libraries. It discovers,
   manages, and invokes the `dicom-*` CLI tools installed on the system via `Foundation.Process`.
2. **Version-Locked** — On launch, DICOM Studio checks that the installed tool versions match its
   own version. Mismatched or missing tools trigger an offer to download the correct release from
   GitHub.
3. **Self-Updating** — DICOM Studio checks for newer versions of itself on GitHub and offers
   in-app download and installation.
4. **Network Utility UX** — A persistent sidebar browser groups the 38 tools into intuitive
   categories, a tabbed area presents each tool's options as native macOS controls, and an
   integrated terminal shows the built command and its output.
5. **Server-Centric** — A global PACS/DICOMweb server configuration persists across sessions and
   auto-populates all network tool parameters.

### Target Platform

- **macOS 14.0+** (Sonoma and later)
- **Swift 6.2** with Strict Concurrency
- **SwiftUI** with AppKit integration where required (terminal, drag-and-drop, file dialogs)

### Architecture

- **Pattern**: MVVM with Service Layer
- **CLI Invocation**: `Foundation.Process` with `Pipe`-based I/O and `AsyncStream` for real-time output
- **Persistence**: `UserDefaults` for preferences and server profiles, Keychain for credentials
- **Updates**: GitHub Releases API (`https://api.github.com/repos/Raster-Lab/DICOMKit/releases`)
- **Distribution**: GitHub Releases (universal macOS binary, code-signed and notarized)

### Tool Categories (Browser Sidebar)

The 38 CLI tools are organized into the following browser categories:

| Category | Tools | Count |
|----------|-------|-------|
| **Networking** | echo, query, send, retrieve, qr, wado, mwl, mpps, print, gateway, server | 11 |
| **Viewer & Imaging** | viewer, image, 3d | 3 |
| **File Inspection** | info, dump, tags, diff | 4 |
| **File Processing** | convert, validate, anon, compress | 4 |
| **File Organization** | split, merge, dcmdir, archive | 4 |
| **Data Exchange** | json, xml, pdf, export, pixedit | 5 |
| **Clinical** | report, measure, study | 3 |
| **Utilities** | uid, script | 2 |
| **Cloud & AI** | cloud, ai | 2 |
| **Total** | | **38** |

---

## Milestone 17: CLI Shell Foundation & Tool Management

**Version**: v2.0.0-alpha.1
**Status**: Planned
**Estimated Effort**: 3 weeks (1 developer)

### Goal

Replace the library-embedding architecture with a process-based CLI shell. Implement tool
discovery, version checking, GitHub-based download/install, and self-update functionality.
This milestone establishes the core infrastructure that all subsequent milestones build upon.

### Deliverables

#### 17.1 Tool Discovery & Registry

- [ ] `ToolRegistryService` — discovers installed `dicom-*` binaries on the system
  - [ ] Search `$PATH`, `/usr/local/bin`, `~/.local/bin`, Homebrew prefix, and a bundled
        `~/.dicomstudio/tools/` directory
  - [ ] Parse `--version` output from each discovered tool to extract version string
  - [ ] Build an in-memory registry mapping tool name → path, version, and availability
  - [ ] Provide `async` API: `discoverTools() async -> [ToolInfo]`
  - [ ] Cache discovery results with a configurable TTL (default: session lifetime)
- [ ] `ToolInfo` model — represents a single discovered tool
  - [ ] Properties: `name`, `path`, `version`, `isCompatible`, `category`
  - [ ] `Sendable`, `Identifiable`, `Hashable`, `Codable`
- [ ] `ToolCategory` enum — the 9 browser categories listed in the Overview
  - [ ] Computed property mapping each of the 38 tools to its category
  - [ ] SF Symbol and display name for each category

#### 17.2 Version Compatibility Checking

- [ ] `VersionService` — compares tool versions against DICOM Studio's embedded version
  - [ ] Parse semantic version strings (`major.minor.patch`)
  - [ ] Define compatibility rules: tools must match `major.minor` of DICOM Studio
  - [ ] Identify missing tools, outdated tools, and tools with version mismatches
  - [ ] Generate a `VersionReport` summarizing compatibility status
- [ ] `VersionReport` model
  - [ ] Properties: `studioVersion`, `compatibleTools`, `incompatibleTools`,
        `missingTools`, `overallStatus`
  - [ ] `Sendable`, `Codable`

#### 17.3 GitHub Release Integration

- [ ] `GitHubReleaseService` — interacts with the GitHub Releases API
  - [ ] Fetch latest release metadata:
        `GET https://api.github.com/repos/Raster-Lab/DICOMKit/releases/latest`
  - [ ] Fetch release by tag:
        `GET https://api.github.com/repos/Raster-Lab/DICOMKit/releases/tags/{tag}`
  - [ ] List release assets to find platform-specific tool binaries
  - [ ] Download release assets with progress reporting via `AsyncStream<DownloadProgress>`
  - [ ] Verify downloaded binary integrity (SHA-256 checksum from release notes)
  - [ ] Handle rate limiting and authentication (optional GitHub token)
- [ ] `ReleaseInfo` model — GitHub release metadata
  - [ ] Properties: `tagName`, `name`, `body`, `assets`, `publishedAt`, `isPrerelease`
  - [ ] `Sendable`, `Codable`
- [ ] `ReleaseAsset` model — individual downloadable asset
  - [ ] Properties: `name`, `downloadURL`, `size`, `contentType`, `checksum`
  - [ ] `Sendable`, `Codable`

#### 17.4 Tool Installation Manager

- [ ] `ToolInstallService` — downloads and installs CLI tool binaries
  - [ ] Default install directory: `~/.dicomstudio/tools/` (user-writable, no sudo required)
  - [ ] Download the universal macOS binary archive from GitHub Releases
  - [ ] Extract archive (`.tar.gz` or `.zip`) to install directory
  - [ ] Set executable permissions (`chmod +x`)
  - [ ] Verify installation by invoking `<tool> --version`
  - [ ] Rollback on failure (restore previous version if one existed)
  - [ ] Progress reporting: download progress, extraction progress, verification
- [ ] `InstallationState` enum — `idle`, `downloading(progress)`, `extracting`,
      `verifying`, `completed`, `failed(error)`
- [ ] `InstallationPreferences` — user-configurable install directory, auto-update toggle

#### 17.5 Self-Update Mechanism

- [ ] `AutoUpdateService` — checks for newer DICOM Studio versions
  - [ ] On launch, check GitHub Releases for a version newer than the running app
  - [ ] Compare using semantic versioning (ignore pre-release tags by default)
  - [ ] Present update notification with release notes
  - [ ] Download the new `.app` bundle or `.dmg` from GitHub Releases
  - [ ] Optionally use Sparkle-compatible appcast or direct GitHub API
  - [ ] Configurable update check frequency: on launch, daily, weekly, never
- [ ] `UpdateState` enum — `upToDate`, `updateAvailable(ReleaseInfo)`,
      `downloading(progress)`, `readyToInstall`, `failed(error)`

#### 17.6 Launch Sequence Orchestration

- [ ] `LaunchCoordinator` — orchestrates the startup sequence
  - [ ] Step 1: Discover installed tools (`ToolRegistryService`)
  - [ ] Step 2: Check version compatibility (`VersionService`)
  - [ ] Step 3: Check for self-update (`AutoUpdateService`)
  - [ ] Step 4: Present results to user
    - If all tools compatible and no update → proceed to main UI
    - If tools missing/incompatible → show Tool Setup Assistant
    - If self-update available → show Update Available banner
  - [ ] Support "Skip" and "Remind Me Later" for non-blocking issues
- [ ] `ToolSetupAssistantView` — SwiftUI sheet presented when tools need installation
  - [ ] List of missing/incompatible tools with status indicators
  - [ ] "Install All" button with aggregate progress bar
  - [ ] "Install Selected" for granular control
  - [ ] "Skip" to proceed without all tools (disabled tools shown as unavailable in browser)
- [ ] `UpdateBannerView` — non-modal banner for available self-updates
  - [ ] Shows version number, brief changelog, and "Update Now" / "Later" buttons

### Technical Notes

- Use `Process` (Foundation) for tool invocation, not `NSTask`
- Use `URLSession` for GitHub API and asset downloads (supports background downloads)
- GitHub API requests should include `User-Agent: DICOMStudio/{version}` header
- Handle GitHub rate limiting (60 requests/hour unauthenticated, 5000 with token)
- Store optional GitHub personal access token in Keychain for higher rate limits
- The install directory `~/.dicomstudio/tools/` must be added to the tool search path
- Use `@AppStorage` for update check frequency preference
- Reference: GitHub REST API — [Releases](https://docs.github.com/en/rest/releases)

### Acceptance Criteria

- [ ] All 38 CLI tools are discovered when installed in standard locations
- [ ] Version mismatch correctly identified for tools with different `major.minor`
- [ ] GitHub latest release is fetched and parsed correctly
- [ ] Tool download shows accurate progress and completes successfully
- [ ] Installed tools pass `--version` verification
- [ ] Self-update check identifies newer versions correctly
- [ ] Launch sequence presents Tool Setup Assistant when tools are missing
- [ ] "Skip" allows launching with reduced functionality (missing tools grayed out)
- [ ] Works offline (skips GitHub checks, uses cached tool registry)
- [ ] Unit tests for VersionService, ToolRegistryService, GitHubReleaseService

---

## Milestone 18: Browser Navigation & Category Sidebar

**Version**: v2.0.0-alpha.2
**Status**: Planned
**Estimated Effort**: 2 weeks (1 developer)

### Goal

Implement the left-hand browser sidebar that groups the 38 CLI tools into categories, with a
tabbed content area that changes based on the selected tool. This establishes the primary
navigation model inspired by Network Utility.

### Deliverables

#### 18.1 Sidebar Browser

- [ ] `BrowserSidebarView` — SwiftUI `List` with `DisclosureGroup` for each category
  - [ ] 9 collapsible category groups (Networking, Viewer & Imaging, etc.)
  - [ ] Each category shows its SF Symbol, display name, and tool count badge
  - [ ] Individual tools listed under their category with availability indicator
    - Available tools: standard text
    - Unavailable tools (not installed): dimmed with "Not Installed" badge
  - [ ] Selection highlights the active tool
  - [ ] Keyboard navigation: arrow keys to move, Enter to select, Space to expand/collapse
  - [ ] Category expansion state persists across launches (`@AppStorage`)
- [ ] `SidebarViewModel` — manages sidebar state
  - [ ] Properties: `categories`, `selectedTool`, `searchText`, `expandedCategories`
  - [ ] Methods: `selectTool(_:)`, `toggleCategory(_:)`, `filterTools(query:)`
  - [ ] Published as `@Observable` for SwiftUI binding
- [ ] `ToolSearchBar` — filter tools by name or description
  - [ ] Filters across all categories simultaneously
  - [ ] Highlights matching text in tool names
  - [ ] Clears with Escape key or ✕ button

#### 18.2 Tabbed Content Area

- [ ] `ToolContentView` — right-hand area that displays the selected tool's interface
  - [ ] `TabView` within each category when multiple tools are selected
  - [ ] Tab bar shows tool names with SF Symbols
  - [ ] Smooth transition animation when switching tools
  - [ ] Each tab contains the tool's parameter panel (Milestone 21) and terminal (Milestone 20)
  - [ ] Remembers last-selected tab per category across navigation
- [ ] Content area layout:
  - [ ] **Top section**: Tool header with name, brief description, and DICOM standard reference
  - [ ] **Middle section**: Parameter configuration panel (scrollable)
  - [ ] **Bottom section**: Integrated terminal (resizable via drag handle)

#### 18.3 Main Window Layout

- [ ] `MainWindowView` — primary app window using `NavigationSplitView`
  - [ ] Leading column: Browser sidebar (collapsible, minimum 220pt width)
  - [ ] Detail area: Tool content view
  - [ ] Top bar: Server configuration display (Milestone 19)
  - [ ] Respects system appearance (light/dark mode)
  - [ ] Window title: "DICOM Studio — {selected tool name}"
  - [ ] Minimum window size: 1024 × 768
  - [ ] Default window size: 1400 × 900
  - [ ] Window position and size persist across launches
- [ ] `AppMenuBar` — custom menu bar items
  - [ ] **Tools** menu: quick-jump to any tool (grouped by category)
  - [ ] **Server** menu: switch active server, open server manager
  - [ ] **View** menu: toggle sidebar, toggle terminal, increase/decrease terminal size
  - [ ] Standard **Edit**, **Window**, **Help** menus

#### 18.4 Empty States & Onboarding

- [ ] `WelcomeView` — shown when no tool is selected
  - [ ] App logo and version
  - [ ] Quick-start guide: "Select a tool from the sidebar to begin"
  - [ ] Recently used tools (last 5)
  - [ ] Keyboard shortcut reference card
- [ ] `ToolUnavailableView` — shown when a selected tool is not installed
  - [ ] Message explaining the tool is not installed
  - [ ] "Install Now" button (triggers Milestone 17 install flow)
  - [ ] Alternative: "Open in Terminal" with the manual install command

### Technical Notes

- Use `NavigationSplitView` (macOS 14+) for the split layout
- Sidebar minimum width of 220pt prevents truncation of tool names
- Tool selection drives a `@Bindable` property on the ViewModel
- Category SF Symbols:
  - Networking: `network`
  - Viewer & Imaging: `eye`
  - File Inspection: `doc.text.magnifyingglass`
  - File Processing: `gearshape.2`
  - File Organization: `folder.badge.gearshape`
  - Data Exchange: `square.and.arrow.up`
  - Clinical: `heart.text.clipboard`
  - Utilities: `wrench.and.screwdriver`
  - Cloud & AI: `cloud`
- Use `.listStyle(.sidebar)` for native macOS sidebar appearance
- Keyboard shortcut ⌘1–⌘9 for quick category switching

### Acceptance Criteria

- [ ] All 9 categories visible in sidebar with correct tools listed
- [ ] Tool selection updates the content area immediately
- [ ] Unavailable tools shown as dimmed with install option
- [ ] Search filters tools across all categories in real time
- [ ] Sidebar collapse/expand works smoothly
- [ ] Category expansion state persists across app launches
- [ ] Keyboard navigation (arrows, Enter, Escape) works throughout
- [ ] Window remembers size and position
- [ ] VoiceOver correctly announces categories, tools, and selection state
- [ ] Dynamic Type respected in sidebar and content area

---

## Milestone 19: Server Configuration Management

**Version**: v2.0.0-alpha.3
**Status**: Planned
**Estimated Effort**: 2 weeks (1 developer)

### Goal

Implement the persistent PACS/DICOMweb server configuration that is visible at all times and
shared across all network tools. A server icon in the top-right corner provides access to
server management.

### Deliverables

#### 19.1 Server Configuration Model

- [ ] `ServerProfile` model — represents a PACS or DICOMweb server
  - [ ] Properties:
    - `id: UUID`
    - `name: String` (user-assigned display name)
    - `type: ServerType` (`.dicom` or `.dicomweb`)
    - DICOM: `aeTitle`, `calledAET`, `host`, `port`, `timeout`
    - DICOMweb: `baseURL`, `authMethod` (none, basic, bearer, certificate)
    - `tlsEnabled: Bool`, `tlsCertificatePath: String?`
    - `isActive: Bool` (only one server active at a time)
    - `createdAt: Date`, `modifiedAt: Date`
  - [ ] `Sendable`, `Identifiable`, `Hashable`, `Codable`
- [ ] `ServerType` enum — `.dicom`, `.dicomweb`
- [ ] `AuthMethod` enum — `.none`, `.basic(username, password)`, `.bearer(token)`,
      `.certificate(path)`

#### 19.2 Server Persistence Service

- [ ] `ServerConfigService` — manages server profile CRUD and persistence
  - [ ] Store server profiles as JSON in `~/Library/Application Support/DICOMStudio/servers.json`
  - [ ] Store credentials (passwords, tokens) in macOS Keychain
  - [ ] CRUD operations: `add(_:)`, `update(_:)`, `delete(_:)`, `list() -> [ServerProfile]`
  - [ ] Active server management: `setActive(_:)`, `getActive() -> ServerProfile?`
  - [ ] Enforce single active server constraint
  - [ ] Migration support for future schema changes
  - [ ] Observation: publish changes via `AsyncStream<[ServerProfile]>`

#### 19.3 Server Configuration UI

- [ ] `ServerStatusBarView` — persistent display at the top of the window
  - [ ] Shows active server details: name, host:port (DICOM) or base URL (DICOMweb)
  - [ ] Connection type icon (DICOM vs DICOMweb)
  - [ ] TLS lock indicator when TLS is enabled
  - [ ] "No Server Configured" placeholder when no servers exist
  - [ ] Clicking the server name opens a quick-switch popover
  - [ ] Always visible regardless of selected tool or category
- [ ] `ServerIconButton` — top-right corner icon button
  - [ ] SF Symbol: `server.rack` (or `externaldrive.connected.to.line.below`)
  - [ ] Badge indicator showing active server connection status
  - [ ] Click opens `ServerManagerPopover`
  - [ ] Context menu: "Add Server…", "Manage Servers…", list of servers for quick switch
- [ ] `ServerManagerPopover` — popover for quick server management
  - [ ] List of configured servers with radio selection for active
  - [ ] Quick "Test Connection" button (runs `dicom-echo` for DICOM servers)
  - [ ] "Add Server…" button → opens `ServerEditorSheet`
  - [ ] "Manage Servers…" button → opens `ServerManagerSheet`
- [ ] `ServerEditorSheet` — modal sheet for adding/editing a server
  - [ ] `Form` with sections:
    - **General**: Name, Type (DICOM/DICOMweb picker)
    - **DICOM Connection** (shown when type = DICOM):
      AE Title, Called AE Title, Host, Port, Timeout
    - **DICOMweb Connection** (shown when type = DICOMweb):
      Base URL, Authentication Method, credentials
    - **Security**: TLS toggle, certificate path picker
  - [ ] Real-time validation (AE title ≤16 chars, port 1–65535, valid URL, etc.)
  - [ ] "Test Connection" button with spinner and result indicator
  - [ ] "Save" / "Cancel" buttons
- [ ] `ServerManagerSheet` — full server list management
  - [ ] Table of all configured servers: Name, Type, Host, Port/URL, Status
  - [ ] Toolbar: Add (+), Remove (−), Edit (pencil), Duplicate
  - [ ] Drag to reorder
  - [ ] Double-click to edit
  - [ ] "Set Active" button for selected server
  - [ ] Import/Export server configurations (JSON file)

#### 19.4 Network Parameter Auto-Population

- [ ] `NetworkParameterInjector` — automatically populates network tool parameters
  - [ ] When a network tool tab is selected, inject active server details into its parameters
  - [ ] Parameters injected:
    - DICOM: `--host`, `--port`, `--aet`, `--called-aet`, `--timeout`, `--tls`
    - DICOMweb: `--url`, `--auth`, `--token`
  - [ ] Server parameter fields in tool tabs are pre-filled but user-editable
  - [ ] If no server is active, network parameters show placeholder "Configure a server…"
  - [ ] Changes to the active server immediately update all open network tool tabs

### Technical Notes

- Server profiles are stored outside the app sandbox for portability:
  `~/Library/Application Support/DICOMStudio/servers.json`
- Credentials are stored in the macOS Keychain using `Security.framework`
  - Service name: `com.rasterlab.dicomstudio.server.{serverId}`
- "Test Connection" for DICOM servers invokes `dicom-echo --host {host} --port {port}
  --aet {aet} --called-aet {calledAET}`
- "Test Connection" for DICOMweb servers sends a QIDO-RS capabilities request
- The `ServerStatusBarView` is placed in the `toolbar` of `MainWindowView`, positioned
  before the `ServerIconButton`
- Use `@Observable` for `ServerConfigViewModel` to drive all UI bindings
- Server import/export uses the same JSON schema as the persistence file

### Acceptance Criteria

- [ ] Server profiles persist across app launches
- [ ] Credentials stored securely in macOS Keychain (not in JSON file)
- [ ] Only one server is active at any time
- [ ] Active server details always visible in the status bar
- [ ] Switching active server updates all network tool parameter fields
- [ ] "Test Connection" correctly invokes `dicom-echo` or QIDO-RS
- [ ] Validation prevents saving invalid server configurations
- [ ] Server import/export round-trips correctly
- [ ] VoiceOver announces server status and selection changes
- [ ] Server manager supports keyboard-only navigation

---

## Milestone 20: Integrated Terminal & Command Execution

**Version**: v2.0.0-alpha.4
**Status**: Planned
**Estimated Effort**: 3 weeks (1 developer)

### Goal

Implement the integrated terminal window at the bottom of each tool's content area. The terminal
shows the command being built in real time, executes it on user action, and displays all output
including errors. Users can select and copy any text from the terminal.

### Deliverables

#### 20.1 Terminal Emulator View

- [ ] `TerminalView` — custom SwiftUI view backed by `NSTextView` for rich text display
  - [ ] Monospaced font: SF Mono, 12pt (user-configurable size)
  - [ ] Dark background with light text (terminal aesthetic)
  - [ ] Automatic color scheme adaptation (dark: black bg / light: dark gray bg)
  - [ ] Scrollable with scroll-to-bottom on new output
  - [ ] Resizable via drag handle between parameter panel and terminal
  - [ ] Minimum height: 120pt; maximum: 60% of content area
  - [ ] Terminal height persists across tool switches and app launches
- [ ] Text rendering features:
  - [ ] Syntax highlighting for the command preview line:
    - Tool name: **bold white**
    - Flags/options (`--flag`): **blue**
    - Values: **green**
    - File paths: **orange**
    - Pipes and redirects: **magenta**
  - [ ] ANSI color code support for tool output (basic 16 colors)
  - [ ] Error output (stderr): **red** text
  - [ ] Timestamp prefix for each output line (optional, configurable)
  - [ ] Word wrap with horizontal scroll toggle

#### 20.2 Command Preview & Building

- [ ] `CommandPreviewLine` — always-visible line at the top of the terminal
  - [ ] Shows the fully built command as it would be typed in a real terminal
  - [ ] Updates in real time as GUI controls are adjusted (Milestone 21)
  - [ ] Syntax-highlighted for readability
  - [ ] Click to select the entire command for copying
  - [ ] "Copy Command" button (⌘C when command line is focused)
  - [ ] Separator line between command preview and output area
- [ ] `CommandBuilder` — constructs the CLI command string from current parameters
  - [ ] Input: tool name, parameter key-value pairs, file paths, flags
  - [ ] Output: fully qualified command string (e.g., `dicom-echo --host 10.0.0.1 --port 11112`)
  - [ ] Handles:
    - Boolean flags (present/absent, not `--flag true`)
    - Value parameters (`--key value`)
    - Positional arguments (file paths)
    - Subcommands (`dicom-compress compress --input file.dcm`)
    - Quoted strings for paths with spaces
    - Multiple input files
    - Output file/directory specification

#### 20.3 Command Execution Engine

- [ ] `CommandExecutor` — Swift actor that manages process execution
  - [ ] Launch tool as a child process using `Foundation.Process`
  - [ ] Set working directory to the file's parent directory (or user-specified)
  - [ ] Capture stdout and stderr via `Pipe` with `AsyncStream` output
  - [ ] Stream output to terminal in real time (not buffered until completion)
  - [ ] Support cancellation: "Stop" button terminates the running process (SIGTERM, then SIGKILL)
  - [ ] Track execution state: `idle`, `running(pid)`, `completed(exitCode)`, `cancelled`, `failed(error)`
  - [ ] Timeout support: configurable per-tool maximum execution time
  - [ ] Environment: inherit system environment, add `~/.dicomstudio/tools/` to `PATH`
- [ ] `ExecutionResult` model:
  - [ ] Properties: `exitCode`, `stdout`, `stderr`, `duration`, `command`, `timestamp`
  - [ ] `Sendable`, `Codable`

#### 20.4 Execute / Run Button

- [ ] `ExecuteButton` — prominent button adjacent to the terminal
  - [ ] States:
    - **Ready**: "Run" with ▶ icon, enabled when all required parameters are valid
    - **Running**: "Stop" with ■ icon, red tint
    - **Completed**: "Run" re-enabled, showing last exit code as badge
  - [ ] Keyboard shortcut: ⌘R to run, ⌘. (⌘Period) to stop
  - [ ] Disabled with tooltip when required parameters are missing
  - [ ] Button pulses subtly when the command has changed since last execution
- [ ] `ClearButton` — clears terminal output
  - [ ] Keyboard shortcut: ⌘K
  - [ ] Preserves command preview line

#### 20.5 Text Selection & Copy

- [ ] Full text selection support in the terminal output area
  - [ ] Click and drag to select text
  - [ ] ⌘A to select all terminal output
  - [ ] ⌘C to copy selected text
  - [ ] Right-click context menu: Copy, Select All, Clear
  - [ ] Triple-click to select entire line
- [ ] "Copy Output" toolbar button — copies all terminal output to clipboard
- [ ] "Save Output…" toolbar button — saves terminal output to a text file

#### 20.6 Command History

- [ ] `CommandHistoryService` — persists executed commands
  - [ ] Store last 100 commands per tool (ring buffer)
  - [ ] Properties per entry: `command`, `exitCode`, `timestamp`, `duration`
  - [ ] Navigate history with ↑/↓ arrow keys when command line is focused
  - [ ] Searchable history panel (⌘⇧H to toggle)
  - [ ] "Re-run" button to replay a historical command
  - [ ] "Copy" button to copy historical command to clipboard
  - [ ] Persistence: `~/Library/Application Support/DICOMStudio/history.json`
  - [ ] PHI redaction: Strip file paths and patient-identifying parameters before storing

### Technical Notes

- The terminal view wraps `NSTextView` via `NSViewRepresentable` for performance with large
  output (SwiftUI `Text` is too slow for streaming terminal output)
- Use `DispatchIO` or `FileHandle.readabilityHandler` for non-blocking pipe reads
- ANSI escape code parsing: support CSI sequences for color (SGR), cursor movement is not needed
- The `CommandExecutor` actor ensures thread-safe process management
- Process environment should include:
  - `PATH`: prepend `~/.dicomstudio/tools/` to system `$PATH`
  - `TERM`: set to `xterm-256color` for tools that check terminal capabilities
  - `COLUMNS`: set to terminal view's character width
- For long-running operations (e.g., `dicom-send` with large files), show an indeterminate
  progress indicator in the terminal header
- Maximum output buffer: 10 MB per session (truncate oldest lines beyond this)

### Acceptance Criteria

- [ ] Command preview updates in real time as GUI controls change
- [ ] Syntax highlighting correctly colorizes tool name, flags, values, and paths
- [ ] "Run" executes the tool and streams output line by line
- [ ] "Stop" terminates a running process within 2 seconds
- [ ] stderr output appears in red
- [ ] Exit code displayed after completion (green for 0, red for non-zero)
- [ ] Text selection and ⌘C work correctly
- [ ] Command history navigable with ↑/↓ keys
- [ ] Terminal resizable via drag handle, height persists
- [ ] VoiceOver announces execution state changes and output
- [ ] Terminal handles 10,000+ lines of output without UI lag

---

## Milestone 21: Dynamic GUI Controls & Parameter Builder

**Version**: v2.0.0-beta.1
**Status**: Planned
**Estimated Effort**: 4 weeks (1 developer)

### Goal

For each of the 38 CLI tools, present its options and switches as native macOS GUI controls
(radio buttons, sliders, checkboxes, dropdowns, and text fields) following Apple's Human
Interface Guidelines. As each control is adjusted, the command in the terminal updates in
real time.

### Deliverables

#### 21.1 Parameter Definition Schema

- [ ] `ToolParameterDefinition` — describes a single CLI parameter declaratively
  - [ ] Properties:
    - `name: String` — the CLI flag (e.g., `--output-format`)
    - `displayName: String` — human-readable label
    - `description: String` — help text / tooltip
    - `type: ParameterType` — the control type to render
    - `isRequired: Bool`
    - `defaultValue: ParameterValue?`
    - `validation: ParameterValidation?`
    - `dependsOn: String?` — conditional visibility (show only when another param has a value)
    - `group: String?` — logical grouping within the form
  - [ ] `Sendable`, `Codable`
- [ ] `ParameterType` enum:
  - [ ] `.text(placeholder: String)` → `TextField`
  - [ ] `.number(range: ClosedRange<Int>, step: Int)` → `Stepper` or `Slider`
  - [ ] `.toggle` → `Toggle` (checkbox)
  - [ ] `.picker(options: [PickerOption])` → `Picker` (dropdown / segmented)
  - [ ] `.radio(options: [PickerOption])` → radio button group
  - [ ] `.slider(range: ClosedRange<Double>, step: Double)` → `Slider` with value label
  - [ ] `.filePath(allowedTypes: [UTType])` → file picker + drag target
  - [ ] `.directoryPath` → directory picker
  - [ ] `.outputPath(defaultExtension: String)` → output file picker
  - [ ] `.aeTitle` → validated AE title field (≤16 chars, DICOM charset)
  - [ ] `.port` → port number field (1–65535)
  - [ ] `.host` → hostname/IP field with validation
  - [ ] `.date` → `DatePicker`
  - [ ] `.multiText` → multi-line text editor
- [ ] `ParameterValue` — type-erased value container
  - [ ] Cases: `.string(String)`, `.int(Int)`, `.double(Double)`, `.bool(Bool)`,
        `.date(Date)`, `.filePath(URL)`, `.directoryPath(URL)`
- [ ] `ParameterValidation` — validation rules
  - [ ] `.regex(String)`, `.range(ClosedRange)`, `.maxLength(Int)`, `.required`,
        `.custom((ParameterValue) -> Bool)`

#### 21.2 Tool Parameter Catalog

- [ ] Define parameter schemas for all 38 CLI tools
  - [ ] **File Inspection** (4 tools):
    - `dicom-info`: input file, output format (text/json/xml), tag filter, verbose
    - `dicom-dump`: input file, offset, length, show-vr, hex-only
    - `dicom-tags`: search query, group filter, VR filter, output format
    - `dicom-diff`: file A, file B, ignore-private, ignore-pixel-data, output format
  - [ ] **File Processing** (4 tools):
    - `dicom-convert`: input file, output file, transfer syntax picker (20+ options), force
    - `dicom-validate`: input file(s), IOD type, strict mode, report format
    - `dicom-anon`: input file, output file, anonymization profile (basic/standard/full),
      retain-dates, retain-device-id, custom rules
    - `dicom-compress`: subcommand (compress/decompress/info), input, output, codec picker,
      quality slider (0-100), effort slider
  - [ ] **File Organization** (4 tools):
    - `dicom-split`: input file, output directory, naming pattern
    - `dicom-merge`: input files (multi), output file, frame ordering
    - `dicom-dcmdir`: subcommand, input directory, output file, recursive toggle
    - `dicom-archive`: input directory, output directory, naming template, flatten toggle
  - [ ] **Data Exchange** (5 tools):
    - `dicom-json`: input file, output file, format (DICOM JSON / FHIR), pretty-print
    - `dicom-xml`: input file, output file, format (native / DICOM XML), indent
    - `dicom-pdf`: mode (extract/encapsulate), input, output, metadata options
    - `dicom-export`: subcommand, input, output dir, format (PNG/JPEG/TIFF), quality, frame range
    - `dicom-pixedit`: operation (mask/crop/fill/invert), input, output, region params
  - [ ] **Networking** (11 tools):
    - `dicom-echo`: host, port, AE title, called AET, timeout, TLS, repeat count
    - `dicom-query`: host, port, AE titles, query level (patient/study/series/instance),
      filters (PatientName, PatientID, StudyDate, Modality, etc.), limit
    - `dicom-send`: host, port, AE titles, input file(s), proposed transfer syntaxes
    - `dicom-retrieve`: host, port, AE titles, study/series/instance UID, method (C-MOVE/C-GET),
      output directory
    - `dicom-qr`: combines query + retrieve parameters
    - `dicom-wado`: subcommand, base URL, study/series/instance UID, accept type, auth
    - `dicom-mwl`: host, port, AE titles, date range, modality filter, station name
    - `dicom-mpps`: subcommand, host, port, AE titles, instance UID, status
    - `dicom-print`: host, port, AE titles, input file, film size, layout, copies, priority
    - `dicom-gateway`: listen port, forward host/port, AE title mapping, protocol translation
    - `dicom-server`: listen port, AE title, storage directory, allowed AE titles, services toggle
  - [ ] **Viewer & Imaging** (3 tools):
    - `dicom-viewer`: input file, window/level presets, zoom, frame, colormap
    - `dicom-image`: input file, output, format, frame range, resize, window/level
    - `dicom-3d`: input directory, reconstruction mode (MPR/MIP/VR), output, quality
  - [ ] **Clinical** (3 tools):
    - `dicom-report`: input file, output format, template, include measurements
    - `dicom-measure`: input file, measurement type, coordinates, output format
    - `dicom-study`: subcommand, input directory, output, sort criteria, summary format
  - [ ] **Utilities** (2 tools):
    - `dicom-uid`: subcommand (generate/validate/lookup), UID string, root OID, count
    - `dicom-script`: subcommand (run/validate/template), script file, variables, dry-run
  - [ ] **Cloud & AI** (2 tools):
    - `dicom-cloud`: provider (AWS/GCS/Azure), operation, bucket/container, credentials, input
    - `dicom-ai`: model path, input file, output, model format (CoreML/ONNX), inference device

#### 21.3 Dynamic Form Renderer

- [ ] `ParameterFormView` — renders a tool's parameter definitions as a native macOS form
  - [ ] `Form` layout with `Section` grouping by parameter group
  - [ ] Each `ParameterType` maps to the corresponding SwiftUI control:
    | ParameterType | SwiftUI Control | macOS HIG Compliance |
    |---------------|----------------|---------------------|
    | `.text` | `TextField` | Standard text input |
    | `.number` | `Stepper` / `Slider` | Numeric input with bounds |
    | `.toggle` | `Toggle` | Checkbox style on macOS |
    | `.picker` | `Picker` | Dropdown menu style |
    | `.radio` | Radio button group | Vertical radio layout |
    | `.slider` | `Slider` with label | Shows current value |
    | `.filePath` | Button + path label | Opens `NSOpenPanel` |
    | `.directoryPath` | Button + path label | Opens `NSOpenPanel` (directory mode) |
    | `.outputPath` | Button + path label | Opens `NSSavePanel` |
    | `.aeTitle` | `TextField` (validated) | 16-char limit, DICOM chars |
    | `.port` | `Stepper` (1–65535) | Numeric with range |
    | `.host` | `TextField` (validated) | Hostname/IP format |
    | `.date` | `DatePicker` | Calendar date picker |
    | `.multiText` | `TextEditor` | Multi-line input |
  - [ ] Conditional parameter visibility (show/hide based on `dependsOn`)
  - [ ] Inline validation with error messages below each field
  - [ ] Tooltips on hover showing parameter description
  - [ ] "Reset to Defaults" button in the form toolbar
- [ ] `ParameterFormViewModel` — manages form state and command building
  - [ ] Holds current values for all parameters: `[String: ParameterValue]`
  - [ ] Validates all parameters on change
  - [ ] Generates command string on every parameter change (throttled to 100ms)
  - [ ] Tracks which parameters are user-modified vs. default vs. auto-injected (server)
  - [ ] Publishes `isValid: Bool` for Execute button enablement

#### 21.4 Network Parameter Integration

- [ ] Network tool parameter forms auto-populate from the active server configuration
  - [ ] Host, port, AE titles, TLS, timeout injected from `ServerConfigService`
  - [ ] Injected parameters are visually distinct (lighter background or "from server" badge)
  - [ ] User can override injected values per-tool without affecting the server config
  - [ ] If no server is configured, network parameter fields show warning and link to server setup

#### 21.5 Subcommand Handling

- [ ] Tools with subcommands (8 tools) display a subcommand selector
  - [ ] `Picker` at the top of the parameter form
  - [ ] Switching subcommands changes the available parameters below
  - [ ] Command preview updates to include the subcommand:
        `dicom-compress compress --input file.dcm --codec jpeg2000`
  - [ ] Subcommand-specific validation rules

### Technical Notes

- Parameter definitions are declared in code as static arrays on each tool's definition struct
  (not loaded from external files)
- All 38 tools × their parameters = approximately 300+ individual parameter definitions
- The `ParameterFormView` uses `@ViewBuilder` composition to render controls dynamically
- Command string generation is debounced (100ms) to avoid excessive updates during rapid
  slider movement
- File picker uses `NSOpenPanel` via `.fileImporter()` modifier where possible, falling back
  to AppKit for directory selection
- All form controls use `.controlSize(.regular)` for macOS HIG compliance
- Parameter sections are collapsible with disclosure triangles
- Use `.help()` modifier for inline tooltips
- Radio button groups are implemented using `Picker` with `.radioGroup` style on macOS

### Acceptance Criteria

- [ ] All 38 tools have complete parameter definitions covering every CLI flag
- [ ] Parameter forms render with correct control types for each parameter
- [ ] Command preview updates within 200ms of any parameter change
- [ ] Required parameter validation prevents execution when missing
- [ ] Network parameters auto-populate from active server config
- [ ] Subcommand picker correctly switches parameter sets for all 8 tools with subcommands
- [ ] File picker opens `NSOpenPanel` with correct file type filters
- [ ] "Reset to Defaults" restores all parameters to their defaults
- [ ] All controls are accessible via keyboard (Tab, Shift+Tab, Space, Enter)
- [ ] VoiceOver announces control labels, values, and validation errors
- [ ] Dynamic Type adjusts form layout and text sizes

---

## Milestone 22: File Operations & Drag-and-Drop

**Version**: v2.0.0-beta.2
**Status**: Planned
**Estimated Effort**: 2 weeks (1 developer)

### Goal

Implement native file handling including file pickers, drag-and-drop targets, and output
directory management. Tools that require input files should offer both a file picker and a
drag-and-drop zone. Output files default to the source directory with an option to change.

### Deliverables

#### 22.1 File Input Controls

- [ ] `FileDropZoneView` — drag-and-drop target for DICOM files
  - [ ] Visual: Rounded rectangle with dashed border and "Drop DICOM files here" label
  - [ ] Drop highlight: Blue tinted border and background on drag hover
  - [ ] Accepts `.dcm`, `.dicom`, `.DCM`, and extensionless DICOM files
  - [ ] Validates dropped files are DICOM (check for DICM preamble magic bytes)
  - [ ] Shows file name, size, and modality icon after a successful drop
  - [ ] Multiple file variant for tools that accept multiple inputs (`dicom-merge`,
        `dicom-send`, `dicom-validate`)
    - [ ] List of dropped files with reorder support (drag to reorder)
    - [ ] Remove individual files (× button or Delete key)
    - [ ] "Add More…" button to append files
  - [ ] Single-file variant for tools with one input
    - [ ] Replacing drop: new file replaces existing
    - [ ] Shows thumbnail preview where applicable
- [ ] `FileBrowseButton` — "Browse…" button that opens `NSOpenPanel`
  - [ ] Configured with allowed UTTypes for DICOM files
  - [ ] Supports single-file and multi-file selection modes
  - [ ] Remembers last-used directory per tool (`@AppStorage`)
  - [ ] Keyboard shortcut: ⌘O

#### 22.2 Output Path Controls

- [ ] `OutputPathView` — output file/directory configuration
  - [ ] **Default behavior**: output goes to the same directory as the input file
  - [ ] Display: shows the resolved output path
  - [ ] "Change…" button opens `NSSavePanel` (for file output) or `NSOpenPanel` (for directory
        output, in directory-selection mode)
  - [ ] Auto-generates output filename based on tool and operation:
    - `dicom-convert`: `{input}_converted.dcm`
    - `dicom-anon`: `{input}_anonymized.dcm`
    - `dicom-json`: `{input}.json`
    - etc.
  - [ ] Overwrite warning when output file already exists
  - [ ] "Open in Finder" button to reveal the output location after execution
- [ ] `OutputDirectoryView` — for tools that output to a directory
  - [ ] Default: same directory as input, or `~/Desktop/DICOMStudio Output/`
  - [ ] Directory picker with "Create Folder" support
  - [ ] Shows free disk space for the selected directory
  - [ ] Remembers last-used output directory per tool

#### 22.3 File Validation & Preview

- [ ] `FileValidationService` — validates dropped/selected files
  - [ ] Quick DICOM header check (132-byte preamble + "DICM" magic)
  - [ ] Extract basic metadata for preview: Patient Name, Study Description, Modality,
        Transfer Syntax, Image Dimensions
  - [ ] File size display with human-readable formatting
  - [ ] Warning for non-standard files (missing preamble, unusual transfer syntax)
- [ ] `FilePreviewView` — compact preview of the selected input file
  - [ ] File icon based on modality (CT, MR, US, etc.)
  - [ ] File name and size
  - [ ] Key metadata: Patient Name (if not anonymized), Modality, Study Date
  - [ ] Thumbnail if available (64×64)
  - [ ] Warning badges for issues (corrupt, unusual format, very large)

#### 22.4 Directory Input Support

- [ ] For tools that accept directories (`dicom-archive`, `dicom-dcmdir`, `dicom-study`,
      `dicom-3d`):
  - [ ] Directory drop zone variant accepting folder drops
  - [ ] Directory browser button using `NSOpenPanel` in directory mode
  - [ ] Recursive file count display (e.g., "42 DICOM files found")
  - [ ] Optional recursive toggle when the tool supports `--recursive`

### Technical Notes

- Drag-and-drop uses SwiftUI's `.onDrop(of:)` with `UTType.fileURL`
- File validation reads only the first 132 bytes (preamble) + 4 bytes (magic) for quick checking
- For thumbnail generation, use the existing `dicom-image` tool if available, otherwise show
  a generic DICOM file icon
- `NSOpenPanel` and `NSSavePanel` are accessed via `@MainActor` to ensure main-thread usage
- File paths with spaces are automatically quoted in the command builder
- Output path default logic:
  1. If input file is set → output directory = input file's parent directory
  2. If no input file → output directory = last-used directory
  3. If no history → output directory = `~/Desktop/`
- Security: validate that the app has read/write access to the selected directories
- For multi-file tools, the command builder generates the correct multi-file syntax
  (e.g., `dicom-send file1.dcm file2.dcm file3.dcm`)

### Acceptance Criteria

- [ ] DICOM files can be dragged and dropped onto the drop zone
- [ ] Non-DICOM files are rejected with appropriate feedback
- [ ] Multi-file drop zone supports reordering and removal
- [ ] "Browse…" opens `NSOpenPanel` with correct filters
- [ ] Output path defaults to input file's directory
- [ ] "Change…" allows selecting a different output path
- [ ] Auto-generated output filenames follow tool conventions
- [ ] Overwrite warning shown when output file exists
- [ ] Directory input works for directory-accepting tools
- [ ] File preview shows correct metadata after drop/selection
- [ ] Drag-and-drop provides visual feedback (highlight on hover)
- [ ] Keyboard alternative exists for all file operations (⌘O)
- [ ] VoiceOver announces drop zone state and file information
- [ ] Large files (>1 GB) don't block the UI during validation

---

## Milestone 23: Integration Testing, Accessibility & Polish

**Version**: v2.0.0-rc.1
**Status**: Planned
**Estimated Effort**: 3 weeks (1 developer)

### Goal

Comprehensive integration testing with real CLI tools, accessibility compliance, performance
optimization, and final UI polish to bring DICOM Studio v2.0 to release quality.

### Deliverables

#### 23.1 End-to-End Integration Testing

- [ ] Test all 38 tools through the GUI → terminal → execution → output pipeline
  - [ ] **File Inspection tools**: Load a DICOM file, verify metadata display
  - [ ] **File Processing tools**: Convert, validate, anonymize, compress → verify output files
  - [ ] **File Organization tools**: Split, merge, create DICOMDIR → verify directory structure
  - [ ] **Data Exchange tools**: Export to JSON/XML/PDF/images → verify output format
  - [ ] **Networking tools**: Echo, query, send, retrieve against a test PACS (Orthanc)
  - [ ] **Viewer tools**: Open and display DICOM images through `dicom-viewer`
  - [ ] **Clinical tools**: Generate reports, extract measurements
  - [ ] **Utilities**: Generate/validate UIDs, run scripts
  - [ ] **Cloud & AI**: Verify parameter building (execution requires cloud/model setup)
- [ ] Error handling tests:
  - [ ] Invalid file input → error message in terminal
  - [ ] Network timeout → appropriate error and retry suggestion
  - [ ] Tool not installed → "Install Now" prompt
  - [ ] Permission denied → helpful error message
  - [ ] Disk full → warning before write operations
- [ ] Edge case tests:
  - [ ] Very large files (>2 GB)
  - [ ] Files with special characters in paths (spaces, unicode)
  - [ ] Simultaneous tool execution (run a tool while another is running in a different tab)
  - [ ] Rapid parameter changes during execution
  - [ ] Loss of network connectivity during network operations

#### 23.2 Unit & ViewModel Tests

- [ ] `ToolRegistryServiceTests` — tool discovery and version checking
- [ ] `VersionServiceTests` — semantic version comparison
- [ ] `GitHubReleaseServiceTests` — API response parsing (mocked)
- [ ] `ServerConfigServiceTests` — CRUD, persistence, active server management
- [ ] `CommandBuilderTests` — command string generation for all 38 tools
- [ ] `CommandExecutorTests` — process management, cancellation, timeout
- [ ] `ParameterFormViewModelTests` — validation, default values, dependencies
- [ ] `FileValidationServiceTests` — DICOM header detection, metadata extraction
- [ ] `CommandHistoryServiceTests` — storage, PHI redaction, search
- [ ] `SidebarViewModelTests` — category filtering, search, tool selection
- [ ] Target: **≥ 95% code coverage** on all Services and ViewModels
- [ ] Target: **≥ 200 test cases** covering all features

#### 23.3 Accessibility Compliance

- [ ] VoiceOver audit:
  - [ ] All interactive elements have meaningful accessibility labels
  - [ ] Navigation order follows logical reading flow (sidebar → content → terminal)
  - [ ] Tool selection and execution are fully navigable without mouse
  - [ ] Terminal output is readable by VoiceOver (configurable verbosity)
  - [ ] Server status changes are announced
  - [ ] Error states are announced with appropriate urgency
- [ ] Keyboard navigation:
  - [ ] Full Tab key navigation through all controls
  - [ ] ⌘R to run, ⌘. to stop, ⌘K to clear, ⌘O to open file
  - [ ] ⌘1–⌘9 for category switching
  - [ ] Arrow keys for sidebar navigation
  - [ ] Escape to dismiss popovers/sheets
- [ ] Dynamic Type:
  - [ ] All text respects system text size settings
  - [ ] Terminal font size adjustable independently
  - [ ] Layout adapts without clipping or overlap at largest sizes
- [ ] High Contrast:
  - [ ] All UI elements meet WCAG AA contrast ratios
  - [ ] Status indicators use both color and shape
  - [ ] Drop zone borders visible in high contrast mode
- [ ] Reduce Motion:
  - [ ] Animations respect `accessibilityReduceMotion` preference
  - [ ] Transitions use dissolves instead of slides when reduced

#### 23.4 Performance Optimization

- [ ] Launch time: app usable within 2 seconds (tool discovery runs concurrently)
- [ ] Sidebar rendering: smooth 60fps scrolling through all 38 tools
- [ ] Parameter form rendering: < 50ms when switching tools
- [ ] Terminal output: handles 10,000+ lines without frame drops
- [ ] Memory usage: < 150 MB base, < 300 MB during heavy tool output
- [ ] File drop validation: < 200ms for DICOM header check
- [ ] Command preview update: < 100ms from parameter change
- [ ] Profile with Instruments: Time Profiler, Allocations, Leaks

#### 23.5 UI Polish & Refinement

- [ ] Consistent spacing and alignment across all views
- [ ] Smooth animations for sidebar expand/collapse, tab switching, sheet presentation
- [ ] Loading states for all async operations (tool discovery, downloads, execution)
- [ ] Error states with actionable messages (not just error codes)
- [ ] Empty states for all list views
- [ ] Window title updates to reflect current tool and server
- [ ] Touch Bar support (if applicable): Run/Stop button, tool quick-switch
- [ ] Menu bar items update correctly based on context
- [ ] Dark mode: all custom colors adapt correctly
- [ ] Light mode: proper contrast and readability
- [ ] Toolbar customization support

#### 23.6 Documentation & Help

- [ ] In-app help:
  - [ ] Each tool has a "?" button linking to its README or man page
  - [ ] Parameter tooltips with DICOM standard references
  - [ ] "What's New in v2.0" welcome sheet on first launch
- [ ] User guide:
  - [ ] Getting started with DICOM Studio v2.0
  - [ ] Server configuration walkthrough
  - [ ] Tool-by-tool reference with screenshots
  - [ ] Keyboard shortcut reference
  - [ ] Troubleshooting guide (tool not found, connection failures, etc.)
- [ ] Release notes:
  - [ ] Comprehensive changelog for v2.0.0
  - [ ] Migration notes from v1.x (if applicable)

### Technical Notes

- Integration tests require installed CLI tools; skip gracefully when tools are unavailable
- Use `XCUITest` for end-to-end UI automation tests
- Mock `Process` execution in unit tests using a protocol-based abstraction
- Accessibility testing: use Xcode Accessibility Inspector and manual VoiceOver testing
- Performance benchmarks should be automated and run in CI
- Profile with Instruments: Time Profiler, Allocations, Leaks, Core Animation
- Terminal performance: consider virtualized rendering (only render visible lines) for
  very large outputs

### Acceptance Criteria

- [ ] All 38 tools execute successfully through the GUI with correct output
- [ ] ≥ 95% code coverage on Services and ViewModels
- [ ] ≥ 200 unit tests passing
- [ ] Full VoiceOver navigation without mouse
- [ ] All keyboard shortcuts functional
- [ ] WCAG AA contrast compliance verified
- [ ] Launch time < 2 seconds on M1 Mac
- [ ] No memory leaks detected in Instruments
- [ ] All error states tested and showing helpful messages
- [ ] User guide covers all features with screenshots
- [ ] Release notes accurately describe all v2.0 changes

---

## Milestone Summary

| Milestone | Title | Version | Status | Effort | Key Deliverables |
|-----------|-------|---------|--------|--------|------------------|
| **17** | CLI Shell Foundation & Tool Management | v2.0.0-alpha.1 | Planned | 3 weeks | Tool discovery, version checking, GitHub download/install, self-update |
| **18** | Browser Navigation & Category Sidebar | v2.0.0-alpha.2 | Planned | 2 weeks | 9-category sidebar, tabbed content, main window layout |
| **19** | Server Configuration Management | v2.0.0-alpha.3 | Planned | 2 weeks | Server CRUD, persistence, status bar, auto-populate network params |
| **20** | Integrated Terminal & Command Execution | v2.0.0-alpha.4 | Planned | 3 weeks | Terminal view, command preview, execution engine, history |
| **21** | Dynamic GUI Controls & Parameter Builder | v2.0.0-beta.1 | Planned | 4 weeks | 300+ parameter definitions, dynamic form renderer, 38 tool configs |
| **22** | File Operations & Drag-and-Drop | v2.0.0-beta.2 | Planned | 2 weeks | File picker, drag-and-drop, output path management, validation |
| **23** | Integration Testing, Accessibility & Polish | v2.0.0-rc.1 | Planned | 3 weeks | E2E tests, 200+ unit tests, VoiceOver, performance, documentation |
| | **Total** | | | **19 weeks** | |

---

## Dependency Graph

```
Milestone 17 (CLI Shell Foundation)
    ├── Milestone 18 (Browser Navigation) ← depends on tool registry
    │   └── Milestone 19 (Server Configuration) ← depends on main window layout
    │       └── Milestone 21 (GUI Controls) ← depends on server auto-populate
    ├── Milestone 20 (Terminal) ← depends on command execution engine
    │   └── Milestone 21 (GUI Controls) ← depends on command preview
    └── Milestone 22 (File Operations) ← depends on parameter definitions
        └── Milestone 23 (Integration & Polish) ← depends on all above
```

```
M17 ──┬── M18 ── M19 ──┐
      │                 ├── M21 ── M22 ── M23
      └── M20 ──────────┘
```

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tool version fragmentation | High | Medium | Strict version-locked bundles; single download for all 38 tools |
| GitHub API rate limiting | Medium | Low | Cache release metadata; optional PAT in Keychain; offline mode |
| macOS Gatekeeper blocks unsigned tools | High | Medium | Code-sign all binaries; notarize the release archive |
| Terminal performance with large output | Medium | Medium | Virtualized text rendering; output buffer limit (10 MB) |
| DICOM file validation false negatives | Low | Low | Conservative validation; allow override for non-standard files |
| Process execution security | High | Low | Validate tool paths; no shell injection; fixed binary locations |
| Accessibility compliance gaps | Medium | Medium | Early and continuous VoiceOver testing; hire accessibility auditor |
| Scope creep in parameter definitions | Medium | High | Prioritize networking + file ops; defer advanced tool params to v2.1 |

---

## Version Progression

```
v2.0.0-alpha.1  →  M17 complete: tools discoverable and installable
v2.0.0-alpha.2  →  M18 complete: sidebar navigation functional
v2.0.0-alpha.3  →  M19 complete: server configuration working
v2.0.0-alpha.4  →  M20 complete: terminal executing commands
v2.0.0-beta.1   →  M21 complete: all 38 tools have GUI controls
v2.0.0-beta.2   →  M22 complete: file handling polished
v2.0.0-rc.1     →  M23 complete: tested, accessible, documented
v2.0.0          →  Final release
```

---

## Key Architectural Decisions

### 1. Shell Architecture (No Library Embedding)

**Decision**: DICOM Studio v2.0 does not link against DICOMKit, DICOMCore, DICOMNetwork, or any
library module. All DICOM operations are performed by invoking the installed CLI tools.

**Rationale**:
- Decouples the GUI lifecycle from the library release cycle
- Users benefit from CLI tool updates without recompiling the GUI
- Ensures the CLI tools are the single source of truth for all DICOM processing
- Reduces the application binary size significantly
- Matches the "shell" metaphor (like Terminal.app wrapping shell commands)

**Trade-off**: Slightly higher latency per operation (process spawn overhead ~10ms) compared to
in-process library calls. Acceptable for the interactive use case.

### 2. Version-Locked Tool Bundles

**Decision**: All 38 CLI tools are distributed as a single versioned archive on GitHub Releases,
version-locked to the DICOM Studio release.

**Rationale**:
- Guarantees compatibility between the GUI parameter definitions and tool behavior
- Simplifies installation: one download installs all tools
- Avoids partial-update scenarios where some tools are newer/older

### 3. User-Space Installation

**Decision**: Tools install to `~/.dicomstudio/tools/` (not `/usr/local/bin` or system paths).

**Rationale**:
- No `sudo` required
- No conflict with Homebrew or other package manager installs
- DICOM Studio fully controls its tool versions
- Easy cleanup: delete the directory to remove all tools

### 4. NSTextView-Backed Terminal

**Decision**: The terminal view uses `NSTextView` (via `NSViewRepresentable`) instead of SwiftUI
`Text` or `TextEditor`.

**Rationale**:
- `NSTextView` handles large text efficiently (100K+ lines)
- Supports attributed strings for syntax highlighting and ANSI colors
- Native text selection and copy behavior
- Better performance than SwiftUI text views for streaming appends

---

*Document created: 2026-03-07*
*Based on DICOMKit v1.8.0 with 38 CLI tools*
*Estimated total effort: 19 weeks (1 developer)*
