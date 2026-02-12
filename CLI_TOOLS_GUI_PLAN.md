# DICOMKit CLI Tools GUI Application Plan

## Overview

**Status**: Planned  
**Target Version**: v1.0.16  
**Estimated Duration**: 4-5 weeks  
**Developer Effort**: 1 senior macOS/SwiftUI developer  
**Platform**: macOS 14+ (Sonoma and later)  
**Dependencies**: DICOMKit v1.0, All 29 CLI tools (Phases 1-6), SwiftUI, ArgumentParser

This document provides a comprehensive phase-by-phase implementation plan for **DICOMToolbox**, a native macOS SwiftUI application that provides a graphical interface for all 29 DICOMKit command-line tools. The application serves as both an educational resource for new DICOM users and a productivity tool for experienced professionals.

### Design Philosophy

1. **Educational First**: Every parameter includes contextual help, explanations, and expandable discussions
2. **Visual Command Building**: Users configure tools through native SwiftUI controls while watching the exact CLI syntax build in real time
3. **Execute In-App**: Run the constructed command directly and view results without leaving the application
4. **DICOM Network Aware**: Common PACS connection parameters are always visible and reusable across tools
5. **Apple HIG Compliant**: Native SwiftUI components following the latest Apple Human Interface Design Guidelines

---

## Architecture Overview

### Application Layout

```
+================================================================+
|  DICOMToolbox                                          macOS 14+|
+================================================================+
|                                                                 |
|  +-----------------------------------------------------------+ |
|  |  PACS / Network Configuration (Always Visible)             | |
|  |  [AE Title: ____] [Called AET: ____] [Host: ____]          | |
|  |  [Port: ____]     [Timeout: ____s]  [Protocol: DICOM/Web] | |
|  +-----------------------------------------------------------+ |
|                                                                 |
|  +-----------------------------------------------------------+ |
|  | File Inspection | Processing | Organization | Export |      | |
|  | Network Ops     | Automation |                              | |
|  +-----------------------------------------------------------+ |
|  |                                                             | |
|  |  +------------------+  +----------------------------------+ | |
|  |  | Tool List        |  | Parameter Configuration          | | |
|  |  | - dicom-info     |  |                                  | | |
|  |  | - dicom-dump     |  |  [Input File]  [Drop Zone]       | | |
|  |  | - dicom-tags     |  |  [Format: v]   [Options...]      | | |
|  |  |   ...            |  |  [Flags]       [Help i]          | | |
|  |  +------------------+  +----------------------------------+ | |
|  |                                                             | |
|  +-----------------------------------------------------------+ |
|                                                                 |
|  +-----------------------------------------------------------+ |
|  | $ dicom-info --format json --statistics scan.dcm    [Run]  | |
|  |                                                             | |
|  | (command output appears here after execution)               | |
|  +-----------------------------------------------------------+ |
+================================================================+
```

### Key UI Components

| Component | Description | SwiftUI Implementation |
|-----------|-------------|----------------------|
| **Network Config Bar** | Persistent PACS connection settings | `Form` in a `GroupBox` above `TabView` |
| **Tab Interface** | 6 logical tool groupings | `TabView` with `.tabViewStyle(.automatic)` |
| **Tool Sidebar** | Tool selection within each tab | `List` with `NavigationSplitView` |
| **Parameter Panel** | Dynamic form for selected tool | `Form` with `Section` and `DisclosureGroup` |
| **File Drop Zone** | Drag-and-drop + file picker | Custom `DropDelegate` + `.fileImporter()` |
| **Console Window** | Command preview + output | `ScrollView` with `Text` using `.font(.system(.body, design: .monospaced))` |
| **Execute Button** | Run command when valid | `Button` with `.disabled(!isCommandValid)` |

---

## Tool Grouping (Tab Structure)

### Tab 1: File Inspection (4 tools)

Tools for examining and understanding DICOM file contents.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-info** | Display DICOM metadata | `filePath`, `--format`, `--tag`, `--show-private`, `--statistics`, `--force` |
| **dicom-dump** | Hex dump of DICOM data | `filePath`, `--tag`, `--offset`, `--length`, `--bytes-per-line`, `--annotate`, `--no-color`, `--force` |
| **dicom-tags** | View/edit DICOM tags | `input`, `--output`, `--set`, `--delete`, `--copy-from`, `--tags`, `--delete-private`, `--dry-run` |
| **dicom-diff** | Compare two DICOM files | `file1`, `file2`, `--format`, `--ignore-tag`, `--tolerance`, `--ignore-private`, `--compare-pixels`, `--quick`, `--show-identical` |

### Tab 2: File Processing (4 tools)

Tools for transforming and validating DICOM files.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-convert** | Transfer syntax conversion | `inputPath`, `--output`, `--transfer-syntax`, `--format`, `--quality`, `--window-center`, `--window-width`, `--frame`, `--apply-window`, `--strip-private`, `--validate`, `--recursive` |
| **dicom-validate** | Conformance validation | `inputPath`, `--level`, `--iod`, `--format`, `--output`, `--detailed`, `--recursive`, `--strict` |
| **dicom-anon** | Anonymize patient data | `inputPath`, `--output`, `--profile`, `--shift-dates`, `--regenerate-uids`, `--remove`, `--replace`, `--keep`, `--recursive`, `--dry-run`, `--backup`, `--audit-log` |
| **dicom-compress** | Compression management | Subcommands: `compress`, `decompress`, `info`, `batch` with `--codec`, `--quality`, `--syntax`, `--recursive` |

### Tab 3: File Organization (4 tools)

Tools for organizing, splitting, and merging DICOM files.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-split** | Split multi-frame files | `input`, `--output`, `--frames`, `--format`, `--window-center`, `--window-width`, `--pattern`, `--apply-window`, `--recursive` |
| **dicom-merge** | Merge DICOM files | `inputs`, `--output`, `--format`, `--level`, `--sort-by`, `--order`, `--validate`, `--recursive` |
| **dicom-dcmdir** | DICOMDIR management | Subcommands: `create`, `validate`, `dump`, `update` with `--output`, `--file-set-id`, `--profile`, `--recursive` |
| **dicom-archive** | Archive management | File archival operations with `--output`, `--format`, `--recursive` |

### Tab 4: Data Export (6 tools)

Tools for exporting DICOM data to various formats.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-json** | DICOM to/from JSON | `input`, `--output`, `--format`, `--inline-threshold`, `--bulk-data-url`, `--reverse`, `--pretty`, `--stream`, `--metadata-only` |
| **dicom-xml** | DICOM to/from XML | `input`, `--output`, `--inline-threshold`, `--bulk-data-url`, `--reverse`, `--pretty`, `--no-keywords`, `--metadata-only` |
| **dicom-pdf** | Encapsulate/extract PDF | `input`, `--output`, `--patient-name`, `--patient-id`, `--title`, `--extract`, `--show-metadata` |
| **dicom-image** | Encapsulate images as DICOM | `input`, `--output`, `--patient-name`, `--patient-id`, `--modality`, `--use-exif`, `--split-pages`, `--recursive` |
| **dicom-export** | Export DICOM images | Subcommands: `single`, `contact-sheet`, `animate`, `bulk` with `--format`, `--quality`, `--apply-window`, `--organize-by` |
| **dicom-pixedit** | Pixel data editing | `input`, `--output`, `--mask-region`, `--fill-value`, `--crop`, `--apply-window`, `--invert` |

### Tab 5: Network Operations (8 tools)

Tools for DICOM network communication (DIMSE and DICOMweb).

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-echo** | Test PACS connectivity | `url`, `--aet`, `--called-aet`, `--count`, `--timeout`, `--stats`, `--diagnose` |
| **dicom-query** | C-FIND queries | `url`, `--aet`, `--called-aet`, `--level`, `--patient-name`, `--patient-id`, `--study-date`, `--modality`, `--format`, `--timeout` |
| **dicom-send** | C-STORE operations | `url`, `paths`, `--aet`, `--called-aet`, `--recursive`, `--verify`, `--retry`, `--dry-run`, `--timeout`, `--priority` |
| **dicom-retrieve** | C-MOVE/C-GET retrieval | `url`, `--aet`, `--called-aet`, `--study-uid`, `--series-uid`, `--instance-uid`, `--output`, `--method`, `--move-dest`, `--parallel` |
| **dicom-qr** | Combined query-retrieve | Subcommand: `query` with `--aet`, `--called-aet`, `--move-dest`, `--method`, `--interactive`, `--auto`, `--hierarchical` |
| **dicom-wado** | DICOMweb access | Subcommands: `retrieve`, `query`, `store`, `ups` with `--study`, `--series`, `--instance`, `--token`, `--metadata`, `--rendered` |
| **dicom-mwl** | Modality Worklist | Subcommand: `query` with `--aet`, `--called-aet`, `--date`, `--station`, `--patient`, `--modality`, `--json` |
| **dicom-mpps** | Modality Performed Procedure | Subcommands: `create`, `update` with `--aet`, `--called-aet`, `--study-uid`, `--status` |

### Tab 6: Automation (3 tools)

Tools for study management, UID operations, and scripting.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| **dicom-study** | Study management | Subcommands: `organize`, `summary`, `check`, `stats`, `compare` with `--pattern`, `--format`, `--expected-series` |
| **dicom-uid** | UID operations | Subcommands: `generate`, `validate`, `lookup`, `regenerate` with `--count`, `--type`, `--root`, `--json` |
| **dicom-script** | Script execution | Subcommands: `run`, `validate`, `template` with `--variables`, `--parallel`, `--dry-run`, `--log` |

---

## Parameter-to-UI Control Mapping

Each CLI parameter type maps to a specific SwiftUI control:

### Input Controls

| Parameter Type | SwiftUI Control | Example |
|---------------|-----------------|---------|
| **File path** (`@Argument`) | `DropZoneView` + `.fileImporter()` | DICOM file input |
| **Output path** (`@Option --output`) | `.fileExporter()` / `NSSavePanel` | Save anonymized file |
| **Enum option** (`@Option` with `ExpressibleByArgument`) | `Picker` with `.pickerStyle(.segmented)` or `.menu` | `--format text\|json\|csv` |
| **String option** (`@Option`) | `TextField` with placeholder | `--patient-name "SMITH*"` |
| **Integer option** (`@Option`) | `Stepper` or `TextField` with `.keyboardType(.numberPad)` | `--timeout 60` |
| **Boolean flag** (`@Flag`) | `Toggle` with `.toggleStyle(.switch)` | `--verbose`, `--recursive` |
| **Repeatable option** (`@Option` array) | Dynamic `List` with Add/Remove buttons | `--tag Name --tag ID` |
| **Date option** (`@Option`) | `DatePicker` with manual text input fallback | `--study-date 20240101` |
| **Subcommand** | `Picker` at top of parameter panel | `dicom-export single\|bulk\|animate` |

### Educational Controls

| UI Element | SwiftUI Implementation | Purpose |
|-----------|----------------------|---------|
| **Parameter tooltip** | `.help()` modifier | Brief description on hover |
| **Expandable help** | `DisclosureGroup` | Detailed explanation with examples |
| **Info popover** | `Button` + `.popover()` with `Image(systemName: "info.circle")` | Extended documentation |
| **Validation feedback** | `Text` with `.foregroundStyle(.red)` | Real-time parameter validation |
| **Required indicator** | `Text("*").foregroundStyle(.red)` | Mark required fields |

---

## Implementation Phases

### Phase 1: Application Foundation (Week 1)

**Goal**: Create the app shell with network configuration bar, tab interface, and console window.

#### Deliverables

- [x] **1.1 - Project Setup**
  - Create macOS app target in Xcode (macOS 14+)
  - Configure Swift Package Manager dependencies (DICOMKit, ArgumentParser)
  - Set up app entitlements (file access, network)
  - Configure app icon and metadata

- [x] **1.2 - Main Window Layout**
  - `ContentView` with `VStack` layout:
    1. Network Configuration Bar (`NetworkConfigView`)
    2. Tool Tab Interface (`ToolTabView`)
    3. Console Window (`ConsoleView`)
  - `NavigationSplitView` within each tab for tool list + parameter panel
  - Window sizing and minimum dimensions (1200x800)
  - Full-screen and split-view support

- [x] **1.3 - Network Configuration Bar**
  - `NetworkConfigView` component (always visible above tabs)
  - Fields:
    - **AE Title** (`TextField`, 16-char max, ASCII validation)
    - **Called AET** (`TextField`, default: "ANY-SCP")
    - **Host** (`TextField`, hostname or IP)
    - **Port** (`Stepper` + `TextField`, range: 1-65535, default: 11112)
    - **Timeout** (`Stepper`, range: 5-300s, default: 60)
    - **Protocol** (`Picker`: DICOM / DICOMweb)
  - `@AppStorage` persistence for all fields
  - Quick-connect presets dropdown (save/load server profiles)
  - Connection test button (runs `dicom-echo` internally)

- [x] **1.4 - Console Window**
  - `ConsoleView` component (always visible below tabs)
  - Monospaced font: `.font(.system(.body, design: .monospaced))` using SF Mono
  - Real-time command syntax preview (updated as parameters change)
  - Syntax highlighting:
    - Tool name in **bold**
    - Flags in blue
    - Values in green
    - File paths in orange
  - Copy-to-clipboard button for generated command
  - Clear output button
  - Scrollable output area for command results
  - **Execute button**: enabled only when all required parameters are provided
  - Loading indicator during execution (`.task {}` with `Process()`)

- [x] **1.5 - Command Builder Engine**
  - `CommandBuilder` class (ObservableObject)
  - Builds CLI command string from parameter model
  - Validates required parameters
  - Returns `isValid: Bool` to control Execute button state
  - Executes command via `Process` / `NSTask` and captures stdout/stderr
  - Streams output in real-time to console

#### Test Cases (Phase 1)
- [x] Network config persistence across app launches (5 tests)
- [x] AE Title validation (16-char max, ASCII only) (4 tests)
- [x] Port number validation (1-65535 range) (3 tests)
- [x] Command builder string generation (10 tests)
- [x] Execute button enable/disable logic (5 tests)
- [x] Console output rendering (3 tests)

**Phase 1 Total: ~30 tests** ✅ (60+ tests implemented)

---

### Phase 2: File Inspection Tools Tab (Week 2)

**Goal**: Implement the first tab with 4 file inspection tools, establishing the pattern for all subsequent tabs.

#### Deliverables

- [x] **2.1 - Reusable Components**
  - `FileDropZoneView`: Drag-and-drop target with visual feedback
    - Dashed border, icon, and label
    - `.onDrop(of:)` delegate for file URLs
    - `.fileImporter()` button as alternative
    - File validation (check DICOM header)
    - Display selected filename and size
  - `ParameterSectionView`: Reusable section with `DisclosureGroup` for help text
  - `EnumPickerView`: Generic picker for `ExpressibleByArgument` enums
  - `RepeatableOptionView`: Dynamic list for repeatable `--tag` style options
  - `OutputPathView`: Save panel integration for `--output` parameters

- [x] **2.2 - dicom-info Tool View**
  - `DicomInfoView` parameter form:
    - **Input File** (`FileDropZoneView` - required)
    - **Format** (`Picker`: text | json | csv, with description of each)
    - **Filter Tags** (`RepeatableOptionView` for `--tag`)
    - **Show Private Tags** (`Toggle`)
    - **Show Statistics** (`Toggle`)
    - **Force Parse** (`Toggle` with warning icon)
  - Help popovers for each parameter explaining DICOM concepts
  - Command preview updates in real-time

- [x] **2.3 - dicom-dump Tool View**
  - `DicomDumpView` parameter form:
    - **Input File** (`FileDropZoneView` - required)
    - **Filter Tag** (`TextField` for `--tag`)
    - **Offset** (`TextField` for `--offset`, hex format)
    - **Length** (`Stepper` for `--length`)
    - **Bytes Per Line** (`Stepper`: 8 | 16 | 32)
    - **Annotate** (`Toggle`)
    - **No Color** (`Toggle`)
    - **Highlight Tag** (`TextField` for `--highlight`)
    - **Force Parse** (`Toggle`)

- [x] **2.4 - dicom-tags Tool View**
  - `DicomTagsView` parameter form:
    - **Input File** (`FileDropZoneView` - required)
    - **Output File** (`OutputPathView`)
    - **Set Tags** (`RepeatableOptionView` for `--set TAG=VALUE`)
    - **Delete Tags** (`RepeatableOptionView` for `--delete TAG`)
    - **Copy From** (`FileDropZoneView` for `--copy-from`)
    - **Tag List File** (`FileDropZoneView` for `--tags`)
    - **Delete Private** (`Toggle`)
    - **Dry Run** (`Toggle`)
    - **Verbose** (`Toggle`)

- [x] **2.5 - dicom-diff Tool View**
  - `DicomDiffView` parameter form:
    - **File 1** (`FileDropZoneView` - required)
    - **File 2** (`FileDropZoneView` - required)
    - **Format** (`Picker`: text | json | summary)
    - **Ignore Tags** (`RepeatableOptionView`)
    - **Tolerance** (`TextField` for numeric tolerance)
    - **Ignore Private** (`Toggle`)
    - **Compare Pixels** (`Toggle`)
    - **Quick Mode** (`Toggle`)
    - **Show Identical** (`Toggle`)

#### Test Cases (Phase 2)
- [x] File drop zone accepts valid DICOM files (3 tests)
- [x] File drop zone rejects invalid files (2 tests)
- [x] File picker integration (2 tests)
- [x] dicom-info command generation with all parameter combinations (8 tests)
- [x] dicom-dump command generation (6 tests)
- [x] dicom-tags command generation (6 tests)
- [x] dicom-diff command generation (6 tests)
- [x] Required parameter validation (4 tests)
- [x] Help popover content accuracy (4 tests)

**Phase 2 Total: ~41 tests** ✅ (45 tests implemented)

---

### Phase 3: File Processing Tools Tab (Week 2-3)

**Goal**: Implement tools for conversion, validation, anonymization, and compression.

#### Deliverables

- [x] **3.1 - dicom-convert Tool View**
  - `DicomConvertView` parameter form:
    - **Input File/Directory** (`FileDropZoneView` - required)
    - **Output Path** (`OutputPathView` - required)
    - **Transfer Syntax** (`Picker`: Explicit VR LE | Implicit VR LE | Explicit VR BE | DEFLATE)
      - Each option with expandable explanation of the transfer syntax
    - **Output Format** (`Picker`: dicom | png | jpeg | tiff)
    - **JPEG Quality** (`Slider`: 1-100, shown only when format is jpeg)
    - **Window Center** (`TextField`, numeric)
    - **Window Width** (`TextField`, numeric)
    - **Frame Number** (`Stepper`, 0-indexed)
    - **Apply Window** (`Toggle`)
    - **Strip Private Tags** (`Toggle`)
    - **Validate Output** (`Toggle`)
    - **Recursive** (`Toggle`)
    - **Force Parse** (`Toggle`)

- [x] **3.2 - dicom-validate Tool View**
  - `DicomValidateView` parameter form:
    - **Input File/Directory** (`FileDropZoneView` - required)
    - **Validation Level** (`Picker` with segmented style: 1 | 2 | 3 | 4)
      - Each level with expandable description of what it checks
    - **IOD Type** (`Picker` with searchable: CTImageStorage, MRImageStorage, etc.)
    - **Output Format** (`Picker`: text | json)
    - **Output File** (`OutputPathView`, optional - stdout if not set)
    - **Detailed Report** (`Toggle`)
    - **Recursive** (`Toggle`)
    - **Strict Mode** (`Toggle` with warning about treating warnings as errors)
    - **Force Parse** (`Toggle`)

- [x] **3.3 - dicom-anon Tool View**
  - `DicomAnonView` parameter form:
    - **Input File/Directory** (`FileDropZoneView` - required)
    - **Output Path** (`OutputPathView`)
    - **Profile** (`Picker`: basic | clinical-trial | research)
      - Each profile with expandable DICOM PS3.15 reference
    - **Date Shift** (`Stepper` for days, with explanation of interval preservation)
    - **Regenerate UIDs** (`Toggle` with explanation)
    - **Tags to Remove** (`RepeatableOptionView`)
    - **Tags to Replace** (`RepeatableOptionView` with key=value format)
    - **Tags to Keep** (`RepeatableOptionView`)
    - **Recursive** (`Toggle`)
    - **Dry Run** (`Toggle`, highlighted - preview mode)
    - **Create Backup** (`Toggle`)
    - **Audit Log** (`OutputPathView`, optional)
    - **Force Parse** (`Toggle`)
    - **Verbose** (`Toggle`)

- [x] **3.4 - dicom-compress Tool View**
  - `DicomCompressView` parameter form:
    - **Subcommand** (`Picker`: compress | decompress | info | batch)
    - Dynamic form based on selected subcommand:
      - **compress**: input, output, codec picker, quality slider
      - **decompress**: input, output, target syntax picker
      - **info**: input only (shows compression details)
      - **batch**: input directory, output directory, codec, quality, recursive toggle
    - **Verbose** (`Toggle`)

#### Test Cases (Phase 3)
- [x] dicom-convert command generation with format-dependent options (10 tests)
- [x] Transfer syntax picker values (4 tests)
- [x] dicom-validate level descriptions (4 tests)
- [x] dicom-anon profile handling (6 tests)
- [x] dicom-anon custom tag actions (6 tests)
- [x] dicom-compress subcommand switching (8 tests)
- [x] Conditional UI visibility (quality slider appears for JPEG) (4 tests)
- [x] Output path required validation (3 tests)

**Phase 3 Total: ~45 tests** ✅ (65+ tests implemented)

---

### Phase 4: File Organization & Data Export Tabs (Week 3)

**Goal**: Implement Tabs 3 (Organization) and 4 (Export) with 10 tools total.

#### Deliverables

- [ ] **4.1 - File Organization Tab (4 tools)**
  - `DicomSplitView`: Input file, output dir, frame range, format picker, window settings
  - `DicomMergeView`: Multiple input files (list with add/remove), output, format, sort options
  - `DicomDcmdirView`: Subcommand picker (create | validate | dump | update), dynamic form
  - `DicomArchiveView`: Input, output, format, recursive toggle

- [ ] **4.2 - Data Export Tab (6 tools)**
  - `DicomJsonView`: Input file, output, format (standard | dicomweb), reverse toggle, pretty print
  - `DicomXmlView`: Input file, output, reverse toggle, pretty print, no-keywords
  - `DicomPdfView`: Input file, output, patient metadata fields, extract toggle
  - `DicomImageView`: Input image, output, patient metadata, EXIF toggle
  - `DicomExportView`: Subcommand picker (single | contact-sheet | animate | bulk), dynamic form
  - `DicomPixeditView`: Input file, output, mask region, crop, fill value, invert toggle

#### Test Cases (Phase 4)
- [ ] dicom-split frame range parsing (4 tests)
- [ ] dicom-merge multi-file list management (5 tests)
- [ ] dicom-dcmdir subcommand forms (4 tests)
- [ ] dicom-json reverse mode (3 tests)
- [ ] dicom-xml command generation (4 tests)
- [ ] dicom-pdf extract vs encapsulate modes (4 tests)
- [ ] dicom-image EXIF handling (3 tests)
- [ ] dicom-export subcommand dynamic forms (8 tests)
- [ ] dicom-pixedit region format validation (3 tests)
- [ ] Multi-file drop zone (4 tests)

**Phase 4 Total: ~42 tests**

---

### Phase 5: Network Operations Tab (Week 4)

**Goal**: Implement Tab 5 with all 8 network tools, integrating the persistent network configuration bar.

#### Deliverables

- [ ] **5.1 - Network Config Integration**
  - Auto-populate `--aet`, `--called-aet`, `--timeout` from Network Config Bar
  - Visual indicator showing inherited vs. overridden values
  - Override mechanism: local tool value takes precedence if set
  - URL auto-construction from Host + Port fields

- [ ] **5.2 - dicom-echo Tool View**
  - `DicomEchoView` parameter form:
    - **Server URL** (auto-built from Network Config, editable)
    - **AE Title** (inherited from Network Config, overridable)
    - **Called AET** (inherited, overridable)
    - **Count** (`Stepper`: 1-100)
    - **Timeout** (inherited, overridable `Stepper`)
    - **Show Statistics** (`Toggle`)
    - **Run Diagnostics** (`Toggle`)
    - **Verbose** (`Toggle`)
  - Quick-test button in Network Config Bar that runs echo

- [ ] **5.3 - dicom-query Tool View**
  - `DicomQueryView` parameter form:
    - **Server URL** (inherited)
    - **AE Title / Called AET** (inherited)
    - **Query Level** (`Picker` with segmented style: patient | study | series | instance)
    - **Search Criteria** section:
      - Patient Name (`TextField` with wildcard hint)
      - Patient ID (`TextField`)
      - Study Date (`DatePicker` + manual text)
      - Study UID (`TextField`)
      - Series UID (`TextField`)
      - Accession Number (`TextField`)
      - Modality (`Picker` from common modality codes: CT, MR, US, CR, DX, etc.)
      - Study Description (`TextField`)
      - Referring Physician (`TextField`)
    - **Output Format** (`Picker`: table | json | csv | compact)
    - **Verbose** (`Toggle`)

- [ ] **5.4 - dicom-send Tool View**
  - `DicomSendView` parameter form:
    - **Server URL** (inherited)
    - **AE Title / Called AET** (inherited)
    - **Files to Send** (multi-file `FileDropZoneView` with list)
    - **Recursive** (`Toggle`)
    - **Verify First** (`Toggle` - runs C-ECHO before send)
    - **Retry Count** (`Stepper`: 0-10)
    - **Priority** (`Picker`: low | medium | high)
    - **Dry Run** (`Toggle`, highlighted)
    - **Verbose** (`Toggle`)

- [ ] **5.5 - dicom-retrieve Tool View**
  - `DicomRetrieveView` parameter form:
    - **Server URL** (inherited)
    - **AE Title / Called AET** (inherited)
    - **Retrieval Target** section:
      - Study UID (`TextField`)
      - Series UID (`TextField`)
      - Instance UID (`TextField`)
      - UID List File (`FileDropZoneView`)
    - **Output Directory** (`OutputPathView` - required)
    - **Method** (`Picker`: C-MOVE | C-GET)
    - **Move Destination** (`TextField`, shown only for C-MOVE)
    - **Parallel Operations** (`Stepper`: 1-8)
    - **Hierarchical Output** (`Toggle`)
    - **Verbose** (`Toggle`)

- [ ] **5.6 - dicom-qr Tool View**
  - `DicomQRView` parameter form:
    - Combined query-retrieve interface
    - **Server URL** (inherited)
    - **AE Title / Called AET / Move Destination** (inherited)
    - **Query Parameters** (same as dicom-query)
    - **Retrieve Options**: method, output, parallel, hierarchical
    - **Workflow Mode** (`Picker`: interactive | auto | review)
    - **Validate Retrieved** (`Toggle`)

- [ ] **5.7 - dicom-wado Tool View**
  - `DicomWadoView` parameter form:
    - **Subcommand** (`Picker`: retrieve | query | store | ups)
    - **Base URL** (`TextField`, https:// format)
    - **Study/Series/Instance UIDs** (`TextField` each)
    - **OAuth2 Token** (`SecureField`)
    - **Frames** (`TextField`, comma-separated)
    - **Output Directory** (`OutputPathView`)
    - **Metadata Format** (`Picker`: json | xml)
    - **Retrieve Mode** toggles: metadata-only, rendered, thumbnail
    - **Verbose** (`Toggle`)

- [ ] **5.8 - dicom-mwl & dicom-mpps Tool Views**
  - `DicomMWLView`: Modality Worklist query with date, station, patient, modality filters
  - `DicomMPPSView`: Subcommand picker (create | update), study UID, status picker

#### Test Cases (Phase 5)
- [ ] Network config inheritance to tool views (6 tests)
- [ ] Network config override mechanism (4 tests)
- [ ] URL auto-construction from host+port (3 tests)
- [ ] dicom-echo command generation (4 tests)
- [ ] dicom-query command with search criteria (8 tests)
- [ ] dicom-send multi-file command (5 tests)
- [ ] dicom-retrieve method-dependent fields (4 tests)
- [ ] dicom-qr combined workflow (4 tests)
- [ ] dicom-wado subcommand forms (6 tests)
- [ ] dicom-mwl command generation (3 tests)
- [ ] dicom-mpps command generation (3 tests)
- [ ] OAuth token secure handling (2 tests)

**Phase 5 Total: ~52 tests**

---

### Phase 6: Automation Tab & Command Execution (Week 4-5)

**Goal**: Implement Tab 6 with automation tools and polish the command execution engine.

#### Deliverables

- [ ] **6.1 - Automation Tab (3 tools)**
  - `DicomStudyView`: Subcommand picker (organize | summary | check | stats | compare)
    - Dynamic forms per subcommand
    - Pattern builder with common placeholders
  - `DicomUIDView`: Subcommand picker (generate | validate | lookup | regenerate)
    - Generate: count, type, root OID
    - Validate: input UIDs or file
  - `DicomScriptView`: Subcommand picker (run | validate | template)
    - Script file picker
    - Variable key=value editor (`RepeatableOptionView`)
    - Template picker with preview
    - Parallel execution toggle
    - Dry run toggle

- [ ] **6.2 - Command Execution Engine**
  - `CommandExecutor` actor (Swift concurrency)
  - Execute via `Process` with stdout/stderr pipes
  - Real-time output streaming to console
  - Cancel button during execution
  - Exit code display (success/failure indicator)
  - Execution history (last 50 commands)
  - Re-run previous command button

- [ ] **6.3 - Command History**
  - Sidebar or dropdown showing recent commands
  - Click to reload parameters into the tool view
  - Copy command to clipboard
  - Export history as shell script

#### Test Cases (Phase 6)
- [ ] dicom-study subcommand forms (5 tests)
- [ ] dicom-uid generate command (4 tests)
- [ ] dicom-script variable parsing (4 tests)
- [ ] Command execution success path (3 tests)
- [ ] Command execution failure handling (3 tests)
- [ ] Output streaming (2 tests)
- [ ] Command cancellation (2 tests)
- [ ] History persistence (3 tests)
- [ ] History reload into tool view (3 tests)

**Phase 6 Total: ~29 tests**

---

### Phase 7: Educational Features & Polish (Week 5)

**Goal**: Add educational features, accessibility, and final polish.

#### Deliverables

- [ ] **7.1 - Educational Enhancements**
  - DICOM Glossary sidebar (searchable terms)
  - Context-sensitive help linking to DICOM standard sections
  - "What does this do?" expandable for each tool
  - Example command presets ("Show me an example")
  - Beginner/Advanced mode toggle (hides advanced parameters in beginner mode)

- [ ] **7.2 - Accessibility**
  - VoiceOver labels for all controls
  - Keyboard navigation (Tab order, shortcuts)
  - Dynamic Type support
  - Reduced Motion support
  - High Contrast mode support

- [ ] **7.3 - Visual Polish**
  - Dark Mode support (automatic)
  - Tool icons using SF Symbols
  - Animated transitions between tools
  - Toast notifications for command completion
  - Progress bar for long-running operations
  - Drag-and-drop visual feedback (highlight, badge)
  - Window toolbar integration

- [ ] **7.4 - Settings & Preferences**
  - Default output directory
  - Font size for console
  - Theme preferences
  - Server profile management (CRUD)
  - Keyboard shortcut customization

#### Test Cases (Phase 7)
- [ ] Beginner/Advanced mode toggle (4 tests)
- [ ] Glossary search (3 tests)
- [ ] Accessibility labels present (5 tests)
- [ ] Keyboard navigation (4 tests)
- [ ] Dark Mode rendering (2 tests)
- [ ] Settings persistence (4 tests)
- [ ] Server profile CRUD (5 tests)

**Phase 7 Total: ~27 tests**

---

### Phase 8: Integration Testing & Documentation (Week 5)

**Goal**: End-to-end testing, documentation, and release preparation.

#### Deliverables

- [ ] **8.1 - Integration Testing**
  - End-to-end test: select tool -> configure -> generate command -> execute -> view output
  - Test all 29 tools generate valid command syntax
  - Test file drop zone with various DICOM files
  - Test network tools with mock PACS server
  - Performance testing with large file lists
  - Memory profiling

- [ ] **8.2 - Documentation**
  - User guide with screenshots
  - Tool reference card
  - Keyboard shortcuts reference
  - Release notes
  - App Store description and screenshots

- [ ] **8.3 - Release Preparation**
  - App signing and notarization
  - Homebrew cask formula
  - DMG packaging
  - Website landing page content

#### Test Cases (Phase 8)
- [ ] End-to-end workflow tests (10 tests)
- [ ] All 29 tools generate valid syntax (29 tests)
- [ ] File drag-and-drop integration (5 tests)
- [ ] Network mock testing (5 tests)
- [ ] Performance benchmarks (3 tests)

**Phase 8 Total: ~52 tests**

---

## Detailed Component Specifications

### FileDropZoneView

```
+------------------------------------------+
|                                          |
|        +--------------------+            |
|        |   [icon: doc]      |            |
|        |   Drop DICOM file  |            |
|        |   here or          |            |
|        |   [Browse...]      |            |
|        +--------------------+            |
|                                          |
|  Selected: scan_001.dcm (2.4 MB)   [x]  |
+------------------------------------------+
```

**Behavior**:
- Dashed border when empty, solid when file selected
- Border turns blue on drag hover
- Validates file is accessible
- Shows filename, size, and remove button when populated
- For tools requiring multiple files (dicom-merge, dicom-send): shows list with reordering

### ConsoleView

```
+----------------------------------------------------------+
| $ dicom-info --format json --statistics scan.dcm   [Run] |
+----------------------------------------------------------+
| {                                                  [Copy] |
|   "PatientName": "SMITH^JOHN",                           |
|   "StudyDate": "20240115",                               |
|   "Modality": "CT",                                      |
|   ...                                              [Clear]|
| }                                                         |
+----------------------------------------------------------+
```

**Features**:
- Top section: generated command with syntax coloring (SF Mono)
- Execute (Run) button: enabled only when command is valid
- Output section: scrollable, selectable text
- Copy button: copies command or output to clipboard
- Clear button: clears output (keeps command)
- Status indicator: idle | running (spinner) | success (green checkmark) | error (red x)

### NetworkConfigView

```
+------------------------------------------------------------------+
| PACS Configuration                              [Test Connection] |
| AE Title: [MY_SCU_____]  Called AET: [ANY-SCP____]               |
| Host:     [pacs.hospital.org]  Port: [11112]  Timeout: [60]s     |
| Protocol: [DICOM v] | Saved: [Default Profile v] [Save] [Delete] |
+------------------------------------------------------------------+
```

**Features**:
- Always visible above tabs
- AE Title: 16-char max, ASCII validation, auto-trim
- Port: numeric only, 1-65535 range
- Timeout: 5-300 seconds
- Protocol toggle: DICOM (pacs://) vs DICOMweb (https://)
- Server profiles: save/load named configurations
- Test Connection: runs dicom-echo and shows result inline
- Validation badges: green checkmark when fields are valid

---

## Data Models

### ToolDefinition

```swift
struct ToolDefinition: Identifiable {
    let id: String              // e.g., "dicom-info"
    let name: String            // e.g., "DICOM Info"
    let icon: String            // SF Symbol name
    let category: ToolCategory  // Tab grouping
    let description: String     // One-line description
    let discussion: String      // Extended help text
    let parameters: [ParameterDefinition]
    let subcommands: [SubcommandDefinition]?
    let requiresNetwork: Bool
    let requiresOutput: Bool
}
```

### ParameterDefinition

```swift
struct ParameterDefinition: Identifiable {
    let id: String              // e.g., "format"
    let cliFlag: String         // e.g., "--format"
    let shortFlag: String?      // e.g., "-f"
    let label: String           // e.g., "Output Format"
    let help: String            // Brief help text
    let discussion: String?     // Extended help (shown in popover)
    let type: ParameterType     // .file, .string, .integer, .boolean, .enum, .repeatable
    let isRequired: Bool
    let defaultValue: String?
    let enumValues: [EnumValue]? // For enum type
    let validation: ValidationRule?
}
```

### NetworkConfig

```swift
@Observable
class NetworkConfig {
    @AppStorage("aeTitle") var aeTitle: String = "DICOMTOOLBOX"
    @AppStorage("calledAET") var calledAET: String = "ANY-SCP"
    @AppStorage("host") var host: String = "localhost"
    @AppStorage("port") var port: Int = 11112
    @AppStorage("timeout") var timeout: Int = 60
    @AppStorage("protocol") var protocolType: ProtocolType = .dicom
    
    var serverURL: String {
        switch protocolType {
        case .dicom: return "pacs://\(host):\(port)"
        case .dicomweb: return "https://\(host):\(port)/dicom-web"
        }
    }
    
    var isValid: Bool {
        !aeTitle.isEmpty && aeTitle.count <= 16 &&
        !host.isEmpty &&
        (1...65535).contains(port)
    }
}
```

---

## Test Summary

| Phase | Description | Tests |
|-------|-------------|-------|
| Phase 1 | Application Foundation | 30 |
| Phase 2 | File Inspection Tools | 41 |
| Phase 3 | File Processing Tools | 45 |
| Phase 4 | Organization & Export | 42 |
| Phase 5 | Network Operations | 52 |
| Phase 6 | Automation & Execution | 29 |
| Phase 7 | Education & Polish | 27 |
| Phase 8 | Integration & Docs | 52 |
| **Total** | | **318** |

---

## Technology Requirements

| Requirement | Specification |
|-------------|---------------|
| **Platform** | macOS 14+ (Sonoma) |
| **Language** | Swift 5.9+ with strict concurrency |
| **UI Framework** | SwiftUI (primary), AppKit (file panels, Process) |
| **Minimum Window** | 1200 x 800 points |
| **Dependencies** | DICOMKit, ArgumentParser (for model reference) |
| **Architecture** | MVVM with Observable |
| **Data Persistence** | @AppStorage, UserDefaults, Codable JSON |
| **Process Execution** | Foundation.Process for CLI tool invocation |
| **Accessibility** | Full VoiceOver, Keyboard Nav, Dynamic Type |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CLI tool not found at runtime | Medium | High | Bundle tools with app or configure PATH |
| Long-running commands block UI | Low | High | Use Swift concurrency with Task cancellation |
| Large output overwhelms console | Medium | Medium | Virtualized scrolling, output truncation option |
| PACS connectivity issues | Medium | Low | Clear error messages, diagnostic mode |
| Parameter validation edge cases | Medium | Medium | Comprehensive unit tests for each tool |

---

## Success Criteria

1. **All 29 CLI tools** are accessible through the GUI with all parameters configurable
2. **Network configuration** persists and auto-populates across all network tools
3. **Command preview** updates in real-time as parameters are changed
4. **Execute button** correctly enables/disables based on parameter validation
5. **Command output** displays in monospaced console with proper formatting
6. **File drag-and-drop** works for all file input parameters
7. **Educational content** helps new users understand DICOM concepts
8. **Accessibility** meets Apple HIG standards (VoiceOver, keyboard navigation)
9. **318+ unit tests** pass with >85% code coverage
10. **Performance**: app launches in <2 seconds, parameter changes reflect in <100ms

---

## Appendix A: Complete Tool-to-Tab Mapping

| # | Tool | Tab | Network | Subcommands | File Input | File Output |
|---|------|-----|:-------:|:-----------:|:----------:|:-----------:|
| 1 | dicom-info | File Inspection | - | - | Yes | - |
| 2 | dicom-dump | File Inspection | - | - | Yes | - |
| 3 | dicom-tags | File Inspection | - | - | Yes | Yes |
| 4 | dicom-diff | File Inspection | - | - | Yes (x2) | - |
| 5 | dicom-convert | File Processing | - | - | Yes | Yes |
| 6 | dicom-validate | File Processing | - | - | Yes | Optional |
| 7 | dicom-anon | File Processing | - | - | Yes | Yes |
| 8 | dicom-compress | File Processing | - | Yes | Yes | Yes |
| 9 | dicom-split | File Organization | - | - | Yes | Yes |
| 10 | dicom-merge | File Organization | - | - | Yes (multi) | Yes |
| 11 | dicom-dcmdir | File Organization | - | Yes | Yes | Yes |
| 12 | dicom-archive | File Organization | - | - | Yes | Yes |
| 13 | dicom-json | Data Export | - | - | Yes | Yes |
| 14 | dicom-xml | Data Export | - | - | Yes | Yes |
| 15 | dicom-pdf | Data Export | - | - | Yes | Yes |
| 16 | dicom-image | Data Export | - | - | Yes | Yes |
| 17 | dicom-export | Data Export | - | Yes | Yes | Yes |
| 18 | dicom-pixedit | Data Export | - | - | Yes | Yes |
| 19 | dicom-echo | Network Ops | Yes | - | - | - |
| 20 | dicom-query | Network Ops | Yes | - | - | - |
| 21 | dicom-send | Network Ops | Yes | - | Yes (multi) | - |
| 22 | dicom-retrieve | Network Ops | Yes | - | Optional | Yes |
| 23 | dicom-qr | Network Ops | Yes | Yes | - | Yes |
| 24 | dicom-wado | Network Ops | Yes | Yes | Optional | Yes |
| 25 | dicom-mwl | Network Ops | Yes | Yes | - | - |
| 26 | dicom-mpps | Network Ops | Yes | Yes | - | - |
| 27 | dicom-study | Automation | - | Yes | Yes | Optional |
| 28 | dicom-uid | Automation | - | Yes | Optional | - |
| 29 | dicom-script | Automation | - | Yes | Yes | Optional |

---

## Appendix B: SF Symbol Recommendations

| Tool Category | SF Symbol | Usage |
|--------------|-----------|-------|
| File Inspection | `doc.text.magnifyingglass` | Tab icon |
| File Processing | `gearshape.2` | Tab icon |
| File Organization | `folder.badge.gearshape` | Tab icon |
| Data Export | `square.and.arrow.up` | Tab icon |
| Network Operations | `network` | Tab icon |
| Automation | `terminal` | Tab icon |
| File Drop Zone | `doc.badge.plus` | Empty state |
| Execute Button | `play.fill` | Run command |
| Stop Button | `stop.fill` | Cancel execution |
| Copy Button | `doc.on.doc` | Copy to clipboard |
| Help/Info | `info.circle` | Parameter help |
| Warning | `exclamationmark.triangle` | Validation warning |
| Success | `checkmark.circle.fill` | Command succeeded |
| Error | `xmark.circle.fill` | Command failed |
| Settings | `gear` | Preferences |
| History | `clock.arrow.circlepath` | Command history |

---

*This plan is part of the DICOMKit Demo Application suite. See [DEMO_APPLICATION_PLAN.md](DEMO_APPLICATION_PLAN.md) for the overall strategy.*

*Created: February 2026*  
*Last Updated: February 2026*  
*Version: 1.0*
