# DICOMViewer macOS - User Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Study Browser](#study-browser)
3. [Image Viewer](#image-viewer)
4. [Multi-Viewport Layouts](#multi-viewport-layouts)
5. [Hanging Protocols](#hanging-protocols)
6. [Measurements](#measurements)
7. [MPR and 3D Visualization](#mpr-and-3d-visualization)
8. [PACS Integration](#pacs-integration)
9. [Export and Reports](#export-and-reports)
10. [Keyboard Shortcuts](#keyboard-shortcuts)

---

## Getting Started

### Installation
1. Build DICOMViewer from source using Xcode
2. Open the project with `xcodegen && open DICOMViewer.xcodeproj`
3. Press ⌘R to build and run

### First Launch
When you first launch DICOMViewer, you'll see the main window with:
- **Study Browser** on the left - displays all imported studies
- **Image Viewer** on the right - displays selected series
- **Toolbar** at the top - contains image manipulation controls

---

## Study Browser

The Study Browser helps you organize and find your DICOM studies.

### Importing Files

**Import Single Files:**
1. Click **Import** button in toolbar, or
2. Press **⌘O**, or
3. Use menu: **File → Import Files...**

**Import Folders:**
1. Press **⌘⇧O**, or
2. Use menu: **File → Import Folder...**

**Watch Folder (Auto-Import):**
1. Set up a folder to automatically import new DICOM files
2. Files dropped into this folder are imported automatically
3. Configure in Settings

### Searching Studies

**Quick Search:**
- Click the search field or press **⌘F**
- Type patient name or patient ID
- Results update in real-time

**Filter by Modality:**
- Click the **Modality** dropdown
- Select CT, MR, CR, US, etc.
- Combine with search for precise results

**Sort Studies:**
- Click the **Sort** dropdown
- Options: Date, Patient Name, Modality
- Toggle ascending/descending order

### Managing Studies

**Star/Favorite Studies:**
- Right-click study → **Star**
- Starred studies appear at the top

**Delete Studies:**
- Right-click study → **Delete**
- Confirm deletion dialog appears
- DICOM files are removed from local storage

**View Study Details:**
- Click a study to view series list
- Series shows: modality, description, instance count
- Click a series to view images

---

## Image Viewer

The Image Viewer displays DICOM images with professional viewing tools.

### Basic Navigation

**Frame Navigation:**
- **Next Frame**: Right arrow or mouse scroll up
- **Previous Frame**: Left arrow or mouse scroll down
- Use the **frame slider** for quick jumps

**Zoom:**
- **Zoom In**: ⌘+ or **+** button
- **Zoom Out**: ⌘- or **-** button
- **Fit to Window**: ⌘0 or **Fit** button
- **Pinch gesture** on trackpad

**Pan:**
- Click and drag with mouse
- Two-finger swipe on trackpad

**Rotation:**
- **Rotate 90° CW**: Click rotate button
- **Rotate 90° CCW**: ⇧ + click rotate button

### Window/Level Adjustment

**Interactive Adjustment:**
- Right-click and drag on image
- Horizontal: changes window width (contrast)
- Vertical: changes window center (brightness)

**Presets:**
- **Lung**: WW 1500, WC -600
- **Bone**: WW 2500, WC 300
- **Soft Tissue**: WW 400, WC 40
- **Brain**: WW 80, WC 40
- **Liver**: WW 150, WC 70
- **Mediastinum**: WW 350, WC 50

Click preset button to apply instantly.

**Reset View:**
- Click **Reset** button to restore default view
- Resets zoom, pan, rotation, and window/level

### Cine Playback

For multi-frame series (e.g., cardiac, dynamic studies):

1. Click **Play** button to start cine
2. Adjust **FPS** (frames per second): 5, 10, 15, 20, 30, 60
3. Toggle **Loop** to repeat continuously
4. Toggle **Reverse** to play backwards
5. Use **frame navigation** while playing

**Shortcuts:**
- **Space**: Play/Pause
- **[**: Previous frame
- **]**: Next frame
- **Home**: First frame
- **End**: Last frame

---

## Multi-Viewport Layouts

View multiple series simultaneously with synchronized controls.

### Selecting Layouts

**Available Layouts:**
- **1×1**: Single viewport (default)
- **2×2**: Four viewports in grid
- **3×3**: Nine viewports in grid
- **4×4**: Sixteen viewports in grid

**Change Layout:**
1. Click layout buttons in toolbar, or
2. Use menu: **View → Layout → [layout]**, or
3. Keyboard shortcuts:
   - **⌘1**: 1×1 layout
   - **⌘2**: 2×2 layout
   - **⌘3**: 3×3 layout
   - **⌘4**: 4×4 layout

### Assigning Series to Viewports

**Manual Assignment:**
1. Select a viewport (click on it)
2. Click a series in the series list
3. Series loads into selected viewport

**Automatic Assignment:**
- Use Hanging Protocols (see next section)
- Drag and drop series to viewports

### Viewport Linking

Synchronize controls across multiple viewports:

**Link Options:**
- **Scroll Linking**: Navigate frames together
- **Window/Level Linking**: Share W/L settings
- **Zoom Linking**: Synchronize zoom level
- **Pan Linking**: Share pan position

**Enable Linking:**
1. Click **Link** button in toolbar
2. Choose which properties to link
3. Toggle **Link All** for all properties
4. Toggle **Unlink All** to disable

When linked, adjusting one viewport affects all linked viewports.

---

## Hanging Protocols

Hanging Protocols automatically arrange series based on modality and body part.

### Built-in Protocols

**CT Chest:**
- 2×2 layout
- Axial in top-left
- Coronal in top-right
- Sagittal in bottom-left
- 3D volume in bottom-right

**CT Abdomen:**
- 2×2 layout
- Arterial phase in top-left
- Venous phase in top-right
- Delayed phase in bottom-left

**MR Brain:**
- 2×2 layout
- T1 in top-left
- T2 in top-right
- FLAIR in bottom-left
- DWI in bottom-right

**X-Ray:**
- 1×1 layout
- Single view

### Applying Protocols

**Automatic:**
- Protocols auto-apply when opening compatible studies
- Based on modality and body part examined

**Manual:**
1. Click **Protocol** dropdown in toolbar
2. Select desired protocol
3. Series are automatically assigned to viewports

### Custom Protocols

Create your own hanging protocols:

1. Arrange series manually in desired layout
2. Click **Save Protocol** button
3. Name your protocol
4. Set matching rules (modality, body part, description)
5. Protocol saves for future use

**Edit Protocols:**
- Menu: **View → Edit Hanging Protocols...**
- Modify existing protocols
- Delete unused protocols

---

## Measurements

Perform calibrated measurements on images with ROI analysis.

### Measurement Tools

**Length Measurement:**
1. Click **Length** tool button
2. Click start point on image
3. Click end point
4. Measurement displays in mm (if pixel spacing available)

**Angle Measurement:**
1. Click **Angle** tool button
2. Click three points to define angle
3. Angle displays in degrees

**Ellipse ROI:**
1. Click **Ellipse** tool button
2. Click and drag to draw ellipse
3. Statistics display: mean, std dev, min, max, area

**Rectangle ROI:**
1. Click **Rectangle** tool button
2. Click and drag to draw rectangle
3. Statistics display automatically

**Polygon ROI:**
1. Click **Polygon** tool button
2. Click points to define polygon boundary
3. Double-click or press Enter to complete
4. Statistics display automatically

### Managing Measurements

**Measurement List:**
- View all measurements in sidebar
- Toggle visibility with checkboxes
- Click measurement to highlight on image
- Delete measurements individually

**Editing Measurements:**
- Click measurement to select
- Drag endpoints to adjust
- Press Delete to remove

**Measurement Labels:**
- Double-click measurement to edit label
- Labels appear next to measurements on image

### Exporting Measurements

**Export Options:**
1. Click **Export Measurements** button
2. Choose format:
   - **CSV**: Spreadsheet format with headers
   - **JSON**: Structured data for programs
   - **Text**: Human-readable report

**Copy to Clipboard:**
- Right-click measurement → **Copy**
- Paste into other applications

---

## MPR and 3D Visualization

Multiplanar Reconstruction (MPR) and 3D rendering for volumetric data.

### MPR View

**Opening MPR:**
1. Select a 3D series (CT, MR with multiple slices)
2. Press **⌘⇧M**, or
3. Menu: **View → MPR View...**

**MPR Interface:**
- 2×2 grid showing:
  - **Axial** (top-left): Original acquisition plane
  - **Sagittal** (top-right): Left-right slice
  - **Coronal** (bottom-left): Front-back slice
  - **Volume Info** (bottom-right): Dimensions and spacing

**Navigation:**
- Use sliders to move through planes
- Reference lines show current position
- All planes synchronized automatically

**Controls:**
- Adjust window/level for all planes
- Reset to center position
- Shared zoom and pan

### 3D Volume Rendering

**Opening Volume Rendering:**
1. Select a 3D series
2. Press **⌘⇧3**, or
3. Menu: **View → 3D Volume Rendering...**

**Rendering Modes:**
- **MIP** (Maximum Intensity Projection): Shows brightest voxels
- **MinIP** (Minimum Intensity Projection): Shows darkest voxels
- **Average IP**: Average of voxels in slab
- **Volume Rendering**: Full 3D visualization with opacity

**Transfer Functions:**
Pre-configured presets for different tissues:
- **Bone**: High density structures
- **Soft Tissue**: Organs and muscles
- **Lung**: Low density structures
- **Angiography**: Blood vessels
- **MIP**: Maximum intensity

**Interaction:**
- **Rotate**: Click and drag
- **Zoom**: Scroll wheel or pinch gesture
- **Slab Thickness**: Adjust slider for thicker/thinner projections

**Camera Controls:**
- Elevation and azimuth sliders
- Reset camera to default view

---

## PACS Integration

Connect to PACS servers to query, retrieve, and send studies.

### Server Configuration

**Add PACS Server:**
1. Press **⌘⇧,**, or
2. Menu: **File → Configure Servers...**
3. Click **Add Server**
4. Enter server details:
   - **Name**: Display name for server
   - **Host**: Server IP or hostname
   - **Port**: DICOM port (usually 11112)
   - **Calling AE**: Your application title
   - **Called AE**: PACS server AE title
   - **Retrieve AE**: Destination AE for C-MOVE

**Test Connection:**
- Click **Test** button
- C-ECHO verification runs
- Green checkmark = successful connection
- Red X = connection failed

**Protocol Selection:**
- **DIMSE**: Traditional DICOM (C-FIND, C-MOVE, C-STORE)
- **DICOMWeb**: Modern web-based (QIDO, WADO, STOW)

### Querying PACS

**Open Query Window:**
1. Press **⌘K**, or
2. Menu: **File → Query PACS...**

**Build Query:**
1. Select PACS server
2. Enter search criteria:
   - Patient Name (wildcard: *)
   - Patient ID
   - Study Date range
   - Modality
   - Accession Number
3. Click **Search**

**View Results:**
- Results table shows matching studies
- Click column headers to sort
- Select studies to retrieve

### Retrieving Studies

**Retrieve Selected Studies:**
1. Select studies in query results
2. Click **Retrieve** button
3. Studies download to local database

**Download Queue:**
- Press **⌘⇧D** to view download queue
- Monitor progress of multiple downloads
- Cancel individual downloads
- Clear completed downloads

**Background Downloads:**
- Downloads continue in background
- Notification when complete
- View in Study Browser immediately

### Sending Studies to PACS

**Send to Server:**
1. Select study in Study Browser
2. Right-click → **Send to PACS...**
3. Choose destination server
4. Click **Send**
5. Monitor progress in download queue

---

## Export and Reports

Export images and generate professional PDF reports.

### Image Export

**Export Current Image:**
1. Display desired image/frame
2. Menu: **File → Export Image...**
3. Choose format:
   - **PNG**: Lossless, supports transparency
   - **JPEG**: Compressed, smaller file size
4. Select quality settings
5. Choose burn-in options:
   - Include measurements
   - Include overlays
   - Include patient info
6. Click **Export**

**Batch Export:**
- Export entire series as image sequence
- Export all viewports as multi-image file

### Measurement Export

**Export Measurements:**
1. View series with measurements
2. Click **Export Measurements** button
3. Choose format (CSV, JSON, or Text)
4. Select save location
5. File includes:
   - Study information
   - Patient demographics
   - All measurements with values
   - Timestamps

### PDF Reports

**Generate Report:**
1. Menu: **File → Generate PDF Report...**
2. Configure report:
   - **Institution Name**: Your hospital/clinic
   - **Reporting Physician**: Doctor's name
   - **Page Size**: US Letter or A4
   - **Include**: Title page, patient info, measurements, images
3. Select images to include
4. Click **Generate**

**Report Contents:**
- Title page with institution logo (if available)
- Patient demographics
- Study information
- Measurements table with results
- Embedded images with captions
- Page numbers and timestamps

**Viewing Reports:**
- Report opens in Preview automatically
- Save or print from Preview
- Email as PDF attachment

### Watch Folder Auto-Import

**Set Up Watch Folder:**
1. Menu: **File → Watch Folder Settings...**
2. Click **Add Folder**
3. Choose folder to monitor
4. Configure options:
   - File extensions (.dcm, .dicom)
   - Minimum file size
   - Import delay (seconds)
5. Click **Enable Watching**

**How It Works:**
- Folder is monitored for new DICOM files
- Files are automatically imported after delay
- Duplicate detection prevents re-importing
- Import statistics tracked in settings

**Multiple Watch Folders:**
- Add multiple folders
- Each folder configured independently
- Enable/disable individually

---

## Keyboard Shortcuts

### File Management
| Shortcut | Action |
|----------|--------|
| ⌘O | Import Files... |
| ⌘⇧O | Import Folder... |
| ⌘F | Focus Search Field |
| ⌘K | Query PACS... |
| ⌘⇧, | Configure Servers... |
| ⌘⇧D | Download Queue... |
| ⌘W | Close Window |
| ⌘Q | Quit Application |

### Image Viewer
| Shortcut | Action |
|----------|--------|
| Space | Play/Pause Cine |
| Left Arrow | Previous Frame |
| Right Arrow | Next Frame |
| [ | Previous Frame |
| ] | Next Frame |
| Home | First Frame |
| End | Last Frame |
| ⌘+ | Zoom In |
| ⌘- | Zoom Out |
| ⌘0 | Fit to Window |
| R | Reset View |

### Viewport Layouts
| Shortcut | Action |
|----------|--------|
| ⌘1 | 1×1 Layout |
| ⌘2 | 2×2 Layout |
| ⌘3 | 3×3 Layout |
| ⌘4 | 4×4 Layout |
| ⌘L | Toggle Viewport Linking |

### Advanced Views
| Shortcut | Action |
|----------|--------|
| ⌘⇧M | MPR View... |
| ⌘⇧3 | 3D Volume Rendering... |

### Window Management
| Shortcut | Action |
|----------|--------|
| ⌘M | Minimize Window |
| ⌘` | Cycle Through Windows |

---

## Tips and Tricks

### Performance Optimization
- Close unused viewports to free memory
- Use lower FPS for smoother playback on older Macs
- Enable GPU acceleration in Settings
- Clear thumbnails cache periodically

### Workflow Efficiency
- Create custom hanging protocols for your specialty
- Use watch folders for automatic import
- Star frequently accessed studies
- Combine search and modality filters

### Measurement Accuracy
- Verify pixel spacing calibration
- Use ROI tools for quantitative analysis
- Export measurements for record keeping
- Label measurements descriptively

### PACS Tips
- Test server connections regularly
- Use wildcards (*) in patient name searches
- Queue multiple retrievals for batch downloads
- Verify received studies match query results

---

## Troubleshooting

### Cannot Import DICOM Files
- Verify files have DICM magic number
- Check file permissions
- Ensure sufficient disk space
- Try importing single file first

### Images Don't Display
- Check if series has pixel data
- Verify transfer syntax is supported
- Review error messages in console
- Try different window/level preset

### PACS Connection Failed
- Verify network connectivity
- Confirm server address and port
- Check AE titles match server configuration
- Test with C-ECHO before querying

### MPR/3D Not Available
- Series must have 3+ slices
- Slices must have position information
- Check if series is truly volumetric
- Verify slice spacing is consistent

---

## Getting Help

### Documentation
- [README.md](README.md) - Project overview
- [BUILD.md](BUILD.md) - Build instructions
- [STATUS.md](STATUS.md) - Implementation status
- [MACOS_VIEWER_PLAN.md](../MACOS_VIEWER_PLAN.md) - Detailed plan

### Support
- GitHub Issues: [DICOMKit Issues](https://github.com/Raster-Lab/DICOMKit/issues)
- Email: support@rasterlab.com (if available)

### Contributing
See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines on:
- Reporting bugs
- Requesting features
- Submitting pull requests
- Code style guidelines

---

*User Guide v1.0 - Last updated: February 6, 2026*
