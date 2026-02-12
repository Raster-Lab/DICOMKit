# DICOMToolbox v1.0.16 Release Notes

**Release Date**: 2026  
**Platform**: macOS 14.0 (Sonoma) and later  
**Architecture**: Universal (Apple Silicon and Intel)

---

## Highlights

DICOMToolbox v1.0.16 is the **initial release** of the DICOMToolbox GUI application — a native macOS SwiftUI interface for all 29 DICOMKit command-line tools. This release delivers a complete visual command builder that makes DICOM file inspection, processing, network operations, and automation accessible without requiring command-line experience.

Key highlights:

- 🖥️ **Native macOS experience** — Built with SwiftUI for seamless integration with macOS Sonoma and later.
- 🧰 **All 29 CLI tools** — Every DICOMKit command-line tool is available through a graphical interface.
- 📚 **Educational-first design** — Beginner Mode, DICOM Glossary, and example presets help new users learn DICOM while working.
- ⌨️ **Real-time command preview** — Every GUI action generates the equivalent CLI command with syntax highlighting.
- 🌐 **Persistent network configuration** — Configure PACS connections once; all network tools share the settings.

---

## New Features

### Application Foundation

- Native macOS SwiftUI application targeting macOS 14+.
- Six-tab interface organizing 29 tools into logical categories.
- Persistent network configuration bar with PACS server profiles.
- Dynamic parameter configuration panel with type-appropriate controls (file pickers, toggles, dropdowns, sliders, date pickers).
- Console output panel with monospaced font (SF Mono) and syntax highlighting.
- Drag-and-drop file support with visual feedback, highlighting, and file count badges.
- Full Dark Mode support following system appearance.

### Command Builder

- Real-time CLI command preview updated as parameters change.
- Syntax highlighting: tool names (**bold**), flags (blue), values (green), paths (orange).
- One-click command execution with streaming console output.
- Copy generated command to clipboard for use in Terminal.
- Paste commands from clipboard to populate the parameter panel.

### Command History

- Stores the last 50 executed commands.
- Reload any historical command to repopulate the parameter panel.
- Search and filter history by tool name or parameter values.
- Export full history as a shell script for automation workflows.

### Network Features

- Persistent PACS connection settings shared across all network tools.
- Server profile management — save, switch, and delete named profiles.
- Built-in quick presets for common PACS configurations (Orthanc, DCM4CHEE).
- One-click C-ECHO connectivity test with status indicator.
- Configurable connection timeout and association limits.

### Educational Features

- **Beginner Mode** — Hides advanced parameters; shows contextual explanations and tooltips.
- **Advanced Mode** — Full parameter access for experienced users.
- **DICOM Glossary** — Searchable reference of DICOM terminology with standard section references.
- **Example Presets** — Pre-filled parameter configurations demonstrating common use cases for each tool.
- **Tool Info Popovers** — Expandable descriptions of what each tool does and when to use it.

### Accessibility

- Full keyboard navigation with Tab order across all controls.
- Customizable keyboard shortcuts via Settings.
- VoiceOver support with descriptive labels on all controls and output regions.
- Dynamic Type support respecting system text size preferences.
- Reduced Motion support disabling animations when the system preference is enabled.
- High Contrast mode compatibility.

---

## Tools Supported

### File Inspection (4 tools)

| Tool         | Description                                              |
|--------------|----------------------------------------------------------|
| dicom-info   | Display DICOM metadata with filtering and statistics     |
| dicom-dump   | Hex dump of DICOM data with byte-level annotation        |
| dicom-tags   | View and edit DICOM tags (set, delete, copy)             |
| dicom-diff   | Compare two DICOM files with configurable tolerance      |

### File Processing (4 tools)

| Tool             | Description                                          |
|------------------|------------------------------------------------------|
| dicom-convert    | Transfer syntax conversion and format transformation |
| dicom-validate   | DICOM conformance validation at multiple levels      |
| dicom-anon       | Anonymize patient data (basic/clinical-trial/research profiles) |
| dicom-compress   | Compression management (compress/decompress/info/batch) |

### File Organization (4 tools)

| Tool           | Description                                            |
|----------------|--------------------------------------------------------|
| dicom-split    | Split multi-frame DICOM files into individual frames   |
| dicom-merge    | Merge multiple DICOM files with sorting options        |
| dicom-dcmdir   | DICOMDIR creation, validation, dump, and update        |
| dicom-archive  | Archive management and organization operations         |

### Data Export (6 tools)

| Tool           | Description                                            |
|----------------|--------------------------------------------------------|
| dicom-json     | Convert DICOM to/from JSON (PS3.18 Annex F compliant) |
| dicom-xml      | Convert DICOM to/from XML (PS3.19 Native format)      |
| dicom-pdf      | Encapsulate or extract PDF documents in DICOM          |
| dicom-image    | Encapsulate standard images as DICOM Secondary Capture |
| dicom-export   | Export DICOM images (single/contact-sheet/animate/bulk)|
| dicom-pixedit  | Pixel data editing (mask, crop, invert, window)        |

### Network Operations (8 tools)

| Tool            | Description                                           |
|-----------------|-------------------------------------------------------|
| dicom-echo      | Test PACS connectivity via C-ECHO                     |
| dicom-query     | C-FIND queries with configurable search criteria      |
| dicom-send      | Send DICOM files to PACS via C-STORE                  |
| dicom-retrieve  | Retrieve from PACS via C-MOVE or C-GET                |
| dicom-qr        | Combined query-retrieve workflow                      |
| dicom-wado      | DICOMweb access (WADO-RS, QIDO-RS, STOW-RS, UPS-RS)  |
| dicom-mwl       | Modality Worklist queries                             |
| dicom-mpps      | Modality Performed Procedure Step (create/update)     |

### Automation (3 tools)

| Tool           | Description                                            |
|----------------|--------------------------------------------------------|
| dicom-study    | Study management (organize/summary/check/stats/compare)|
| dicom-uid      | UID generation, validation, lookup, and regeneration   |
| dicom-script   | Script execution, validation, and template generation  |

---

## System Requirements

| Requirement       | Minimum                        |
|-------------------|--------------------------------|
| Operating System  | macOS 14.0 (Sonoma) or later   |
| Architecture      | Apple Silicon or Intel (x86_64)|
| Memory            | 4 GB RAM (8 GB recommended)    |
| Disk Space        | 50 MB for application          |
| Display           | 1280 × 800 minimum resolution  |

DICOMKit command-line tools must be installed separately if you wish to use generated commands in Terminal.

---

## Known Limitations

- **No pixel data preview** — The parameter panel does not display a visual preview of DICOM images. Use dicom-export to generate viewable images.
- **Single command execution** — Only one command can run at a time. Concurrent execution is not supported in this release.
- **Local execution only** — Commands execute on the local machine. Remote execution or SSH tunneling is not supported.
- **History limit** — Command history is capped at 50 entries. Older entries are discarded automatically.
- **No script editor** — The dicom-script tool supports running and validating scripts but does not include a built-in script editor with syntax highlighting.
- **Large file performance** — Processing very large multi-frame DICOM files (>1 GB) may result in high memory usage. Use the CLI tools directly for such files.
- **Localization** — The application is available in English only in this release.

---

## Future Plans

Planned improvements for upcoming releases:

- **Pixel data preview panel** — Inline image preview for DICOM files with pixel data.
- **Concurrent command execution** — Run multiple tools simultaneously with tabbed console output.
- **Script editor** — Built-in editor with syntax highlighting and autocompletion for dicom-script.
- **Batch workflow builder** — Visual pipeline for chaining multiple tools into automated workflows.
- **Plugin system** — Support for community-contributed tool extensions.
- **Localization** — Support for additional languages.
- **Touch Bar support** — Quick actions on MacBook Pro Touch Bar (legacy hardware).
- **Shortcuts integration** — macOS Shortcuts app actions for DICOMToolbox operations.

---

## Acknowledgments

DICOMToolbox is built on the [DICOMKit](https://github.com/dicomkit/DICOMKit) Swift library. Thanks to the DICOMKit contributors and the medical imaging community for feedback and testing.

---

*DICOMToolbox v1.0.16 — Part of the DICOMKit project*
