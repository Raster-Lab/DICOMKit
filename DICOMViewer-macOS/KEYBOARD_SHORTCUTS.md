# DICOMViewer macOS - Keyboard Shortcuts Reference

Quick reference guide for all keyboard shortcuts in DICOMViewer macOS.

## File Management

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘O** | Import Files... | Open file picker to import DICOM files |
| **⌘⇧O** | Import Folder... | Import all DICOM files from a folder |
| **⌘W** | Close Window | Close current window |
| **⌘Q** | Quit Application | Exit DICOMViewer |

## Search and Navigation

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘F** | Focus Search | Move cursor to search field in Study Browser |
| **↑** | Previous Study | Select previous study in list |
| **↓** | Next Study | Select next study in list |
| **⌘↑** | Scroll to Top | Jump to first study |
| **⌘↓** | Scroll to Bottom | Jump to last study |
| **Enter** | Open Study | View selected study's series |

## Image Viewer - Frame Navigation

| Shortcut | Action | Description |
|----------|--------|-------------|
| **Space** | Play/Pause | Start or stop cine playback |
| **←** | Previous Frame | Go to previous frame in series |
| **→** | Next Frame | Go to next frame in series |
| **[** | Previous Frame | Alternative shortcut for previous frame |
| **]** | Next Frame | Alternative shortcut for next frame |
| **Home** | First Frame | Jump to first frame |
| **End** | Last Frame | Jump to last frame |
| **⌘←** | Previous Series | Switch to previous series in study |
| **⌘→** | Next Series | Switch to next series in study |

## Image Viewer - Zoom and Pan

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘+** or **+** | Zoom In | Increase magnification |
| **⌘-** or **-** | Zoom Out | Decrease magnification |
| **⌘0** | Fit to Window | Reset zoom to fit image in viewport |
| **⌘=** | Actual Size | Display at 100% (1:1 pixels) |
| **Click + Drag** | Pan | Move image within viewport |

## Image Viewer - Adjustments

| Shortcut | Action | Description |
|----------|--------|-------------|
| **W** | Window/Level Mode | Toggle W/L adjustment mode |
| **Right-Click + Drag** | Adjust W/L | Interactive window/level adjustment |
| **I** | Invert | Toggle grayscale inversion |
| **R** | Rotate CW | Rotate 90° clockwise |
| **⇧R** | Rotate CCW | Rotate 90° counter-clockwise |
| **F** | Flip Horizontal | Mirror image horizontally |
| **⇧F** | Flip Vertical | Mirror image vertically |
| **⌘R** | Reset View | Reset zoom, pan, rotation, and W/L |

## Window/Level Presets

| Shortcut | Preset | Window/Level |
|----------|--------|--------------|
| **⌘⌥1** | Lung | WW 1500, WC -600 |
| **⌘⌥2** | Bone | WW 2500, WC 300 |
| **⌘⌥3** | Soft Tissue | WW 400, WC 40 |
| **⌘⌥4** | Brain | WW 80, WC 40 |
| **⌘⌥5** | Liver | WW 150, WC 70 |
| **⌘⌥6** | Mediastinum | WW 350, WC 50 |

## Viewport Layouts

| Shortcut | Layout | Description |
|----------|--------|-------------|
| **⌘1** | 1×1 | Single viewport (default) |
| **⌘2** | 2×2 | Four viewports in 2×2 grid |
| **⌘3** | 3×3 | Nine viewports in 3×3 grid |
| **⌘4** | 4×4 | Sixteen viewports in 4×4 grid |
| **⌘L** | Toggle Linking | Toggle viewport linking on/off |
| **Tab** | Next Viewport | Select next viewport |
| **⇧Tab** | Previous Viewport | Select previous viewport |

## Measurement Tools

| Shortcut | Tool | Description |
|----------|------|-------------|
| **L** | Length | Activate length measurement tool |
| **A** | Angle | Activate angle measurement tool |
| **E** | Ellipse ROI | Activate ellipse ROI tool |
| **Shift+E** | Rectangle ROI | Activate rectangle ROI tool |
| **P** | Polygon ROI | Activate polygon ROI tool |
| **Esc** | Cancel | Cancel current measurement |
| **Delete** | Remove | Delete selected measurement |
| **⌘M** | Show/Hide | Toggle measurement visibility |
| **⌘⇧E** | Export | Export measurements to file |

## PACS Operations

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘K** | Query PACS... | Open PACS query window |
| **⌘⇧,** | Configure Servers... | Open server configuration |
| **⌘⇧D** | Download Queue... | Show download queue status |
| **⌘T** | Test Connection | Test selected PACS server |
| **⌘G** | Retrieve | Retrieve selected studies from PACS |
| **⌘⇧S** | Send to PACS | Send study to PACS server |

## Advanced Views

| Shortcut | View | Description |
|----------|------|-------------|
| **⌘⇧M** | MPR View... | Open Multi-Planar Reconstruction window |
| **⌘⇧3** | 3D Volume... | Open 3D Volume Rendering window |
| **⌘⇧P** | Protocol... | Show hanging protocol selector |

## Export and Reports

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘S** | Save Image | Export current image to file |
| **⌘⇧S** | Save All | Export all frames in series |
| **⌘P** | Print... | Print current image |
| **⌘⇧R** | Generate Report | Create PDF report with measurements |
| **⌘C** | Copy Image | Copy current image to clipboard |
| **⌘⇧C** | Copy Metadata | Copy DICOM tags to clipboard |

## Window Management

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘M** | Minimize | Minimize current window |
| **⌘H** | Hide Application | Hide DICOMViewer |
| **⌘⌥H** | Hide Others | Hide all other applications |
| **⌘`** | Cycle Windows | Cycle through open windows |
| **⌘N** | New Window | Open new viewer window |

## Help and Info

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘?** | Help | Open help documentation |
| **⌘I** | Show Info | Display study/series information |
| **⌘⌥I** | DICOM Tags | Show all DICOM tags for current image |
| **F1** | Keyboard Shortcuts | Show this reference |

## Development and Debug (Debug builds only)

| Shortcut | Action | Description |
|----------|--------|-------------|
| **⌘⌥D** | Toggle Debug | Show/hide debug information overlay |
| **⌘⌥L** | Console Log | Show console log window |
| **⌘⌥R** | Reload | Reload current view |

---

## Modifier Key Symbols

For users unfamiliar with macOS keyboard symbols:

| Symbol | Key | Name |
|--------|-----|------|
| **⌘** | Command | Command key |
| **⇧** | Shift | Shift key |
| **⌥** | Option | Option/Alt key |
| **⌃** | Control | Control key |
| **↩** | Return | Return/Enter key |
| **⌫** | Delete | Delete/Backspace key |
| **⎋** | Escape | Escape key |
| **⇥** | Tab | Tab key |
| **↑** | Up Arrow | Up arrow key |
| **↓** | Down Arrow | Down arrow key |
| **←** | Left Arrow | Left arrow key |
| **→** | Right Arrow | Right arrow key |

---

## Customization

You can customize keyboard shortcuts in System Settings:
1. Open **System Settings**
2. Go to **Keyboard → Keyboard Shortcuts → App Shortcuts**
3. Click **+** to add shortcut
4. Select **DICOMViewer**
5. Enter exact menu title
6. Assign desired shortcut

**Note:** Custom shortcuts override default shortcuts.

---

## Context-Sensitive Shortcuts

Some shortcuts are only available in specific contexts:

### In MPR View
- **1**: Show axial plane
- **2**: Show sagittal plane
- **3**: Show coronal plane
- **4**: Show volume info
- **S**: Synchronize all planes

### In 3D Volume View
- **M**: Cycle rendering modes (MIP, MinIP, Average, Volume)
- **T**: Cycle transfer function presets
- **↑/↓**: Adjust slab thickness
- **Drag**: Rotate volume
- **Scroll**: Zoom in/out

### In PACS Query
- **⌘R**: Refresh results
- **⌘A**: Select all results
- **⌘D**: Deselect all
- **⌘↩**: Retrieve selected

### In Measurement Mode
- **Enter**: Complete current measurement
- **Esc**: Cancel current measurement
- **⌫**: Delete selected measurement
- **Click**: Add point (polygon)
- **Double-Click**: Complete measurement (polygon)

---

## Tips for Efficiency

### Mouse + Keyboard Combos
- **⌘ + Click**: Add to selection
- **⇧ + Click**: Select range
- **⌥ + Drag**: Duplicate measurement
- **Space + Drag**: Temporary pan (doesn't change tool)

### Quick Workflows
1. **Import and Review**: ⌘O → Select files → Space (play cine)
2. **Measure and Export**: L (length) → measure → ⌘⇧E (export)
3. **Multi-viewport Compare**: ⌘2 (2×2) → ⌘L (link) → scroll to compare
4. **PACS Query**: ⌘K → type name → ⌘G (retrieve)

### Power User Shortcuts
- Combine viewport layout (⌘2) + linking (⌘L) + W/L preset (⌘⌥1) for instant comparison setups
- Use arrow keys for frame navigation while typing measurements
- Tab through viewports while keeping hands on keyboard

---

## Accessibility

DICOMViewer supports macOS accessibility features:

### VoiceOver
- All controls have descriptive labels
- Images have alt text with series description
- Measurements are readable with values

### Keyboard Navigation
- Full keyboard navigation with Tab key
- Focus indicators on all interactive elements
- Escape key cancels modal dialogs

### Zoom
- System zoom (⌃⌥8) works with DICOMViewer
- All UI elements scale with system text size
- High contrast mode supported

---

## Quick Reference Card

Print this section for a handy desk reference:

```
┌─────────────────────────────────────────────────────┐
│         DICOMViewer - Essential Shortcuts           │
├─────────────────────────────────────────────────────┤
│ Import           ⌘O     │ PACS Query       ⌘K      │
│ Search           ⌘F     │ Zoom In          ⌘+      │
│ Play/Pause       Space  │ Zoom Out         ⌘-      │
│ Next Frame       →      │ Fit Window       ⌘0      │
│ Previous Frame   ←      │ Reset View       ⌘R      │
│                          │                           │
│ 1×1 Layout       ⌘1     │ MPR View         ⌘⇧M     │
│ 2×2 Layout       ⌘2     │ 3D Volume        ⌘⇧3     │
│ Link Viewports   ⌘L     │ Generate Report  ⌘⇧R     │
│                          │                           │
│ Length Tool      L      │ Export Measures  ⌘⇧E     │
│ Angle Tool       A      │ Save Image       ⌘S      │
│ ROI Tool         E      │ Show Info        ⌘I      │
└─────────────────────────────────────────────────────┘
```

---

*Keyboard Shortcuts Reference v1.0 - Last updated: February 6, 2026*

For the complete user guide, see [USER_GUIDE.md](USER_GUIDE.md).
