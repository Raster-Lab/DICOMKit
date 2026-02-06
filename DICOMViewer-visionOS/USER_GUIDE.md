# DICOMViewer visionOS - User Guide

**Welcome to the future of medical imaging on Apple Vision Pro**

Version: 1.0.14  
Platform: visionOS 1.0+

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Basic Operations](#basic-operations)
4. [3D Volume Viewing](#3d-volume-viewing)
5. [Measurements and Annotations](#measurements-and-annotations)
6. [Hand Gestures](#hand-gestures)
7. [Eye Tracking](#eye-tracking)
8. [Collaborative Viewing](#collaborative-viewing)
9. [Tips and Tricks](#tips-and-tricks)
10. [Troubleshooting](#troubleshooting)

---

## Getting Started

### First Launch

1. Put on your Apple Vision Pro
2. Launch DICOMViewer from the Home View
3. Grant permissions when prompted:
   - Hand tracking
   - Eye tracking (optional)
   - Local network (for SharePlay)

### Importing DICOM Files

**Method 1: From Mac**
1. Connect Mac via Universal Control
2. Drag DICOM file to Vision Pro
3. Select DICOMViewer to open

**Method 2: From Files App**
1. Open Files app on Vision Pro
2. Navigate to DICOM file
3. Tap and select "Open in DICOMViewer"

**Method 3: Direct Import**
1. In DICOMViewer, tap "Import"
2. Browse to file location
3. Select file to import

---

## Interface Overview

### Window Types

#### Library Window
- Displays all imported studies
- Grid layout with thumbnails
- Filter and sort options
- Study details panel

#### Viewer Window
- Shows selected series
- 2D image viewing
- Navigation controls
- Window/level adjustment

#### Tools Window
- Measurement tools
- Transfer function editor
- Settings
- Collaboration controls

#### Immersive View
- Full 3D volume rendering
- Hand-controlled interaction
- Clipping and MPR
- Maximum immersion mode

---

## Basic Operations

### Navigating Studies

1. **Open Library**: Say "Show Library" or pinch the Library button
2. **Select Study**: Look at study thumbnail and pinch to select
3. **Open Series**: Pinch on a series to open in viewer

### Viewing 2D Images

1. **Navigate Frames**:
   - Swipe left/right to navigate
   - Or use frame slider
   
2. **Adjust Window/Level**:
   - Pinch and drag vertically (window/brightness)
   - Pinch and drag horizontally (level/contrast)
   
3. **Zoom and Pan**:
   - Pinch with two hands and pull/push to zoom
   - Drag to pan

### Window Management

- **Move Window**: Grab window bar and drag
- **Resize Window**: Grab corner and drag
- **Close Window**: Tap X button or say "Close"
- **Minimize**: Push window away (or tap minimize)

---

## 3D Volume Viewing

### Entering Immersive Mode

1. Open a volumetric series (CT or MR)
2. Tap "3D Volume" button
3. Choose immersion level:
   - **Partial**: See surroundings
   - **Full**: Complete immersion

### Volume Interaction

#### Rotate Volume
- Grab volume with both hands
- Rotate naturally as if holding object
- Single hand: Grab and rotate around axis

#### Scale Volume
- Pinch with both hands
- Pull apart to enlarge
- Push together to shrink
- Scale range: 10% to 500%

#### Position Volume
- Grab and drag to move
- Place in comfortable viewing position
- Pin in space with "Anchor" gesture

### Transfer Functions

Transfer functions control how the volume is displayed.

**Presets**:
1. **Bone**: High-density structures (CT)
2. **Soft Tissue**: Organs and muscles
3. **Vascular**: Blood vessels (angio)
4. **Lung**: Air-filled spaces

**Custom Transfer Function**:
1. Open Tools Window
2. Select "Transfer Function Editor"
3. Adjust opacity curve with pinch-drag
4. Adjust color mapping
5. Save as custom preset

### Rendering Modes

- **MIP** (Maximum Intensity Projection): Brightest voxels
- **Direct Volume**: Opacity-based rendering
- **Isosurface**: Surface at threshold value

### Clipping Planes

**Add Clipping Plane**:
1. Tap "Add Clip Plane" in tools
2. Pinch to place plane in space
3. Grab plane to position
4. Rotate with two hands

**Use Cases**:
- See inside anatomy
- Remove unwanted structures
- Focus on region of interest

### MPR (Multi-Planar Reformation)

**Activate MPR**:
1. Tap "MPR" button
2. Three planes appear (axial, sagittal, coronal)
3. Position planes in space

**Interaction**:
- Scroll plane: Pinch and drag plane
- Rotate plane: Two-hand rotation gesture
- Reference lines: Show intersection of planes

---

## Measurements and Annotations

### 3D Length Measurement

1. Activate measurement tool (say "Measure" or tap tool)
2. Double-pinch at first point
3. Move hand to second point
4. Double-pinch to complete
5. Length displays in mm

### 3D Angle Measurement

1. Activate angle tool
2. Place three points with double-pinch
3. Angle displays in degrees
4. Visual arc shows measurement

### Volume ROI

1. Activate ROI tool
2. Create 3D bounding box:
   - Place corners with pinch
   - Resize with grab-and-drag
3. Volume and surface area calculated

### Annotations

**Text Annotation**:
1. Tap "Annotate" button
2. Pinch to place annotation point
3. Speak or type text
4. Annotation appears in 3D space

**Voice Annotation**:
1. Tap "Voice Note" button
2. Speak your observation
3. Audio icon appears at location
4. Tap icon to replay

### Managing Measurements

- **Show/Hide**: Toggle in measurements panel
- **Edit**: Look at measurement and say "Edit"
- **Delete**: Look and say "Delete" or tap trash icon
- **Export**: Save measurements with study

---

## Hand Gestures

### Standard Gestures

| Gesture | Action | Use Case |
|---------|--------|----------|
| Pinch | Select | Tap buttons, select items |
| Pinch + Drag | Move | Reposition windows, volumes |
| Double Pinch | Place Point | Measurements, annotations |
| Swipe Left/Right | Navigate | Frame navigation |
| Two-Hand Pinch + Pull/Push | Scale | Zoom in/out |
| Two-Hand Rotate | Rotate | Rotate volume |

### Medical Imaging Gestures

| Gesture | Action | Use Case |
|---------|--------|----------|
| Pinch + Vertical Drag | Window | Adjust brightness |
| Pinch + Horizontal Drag | Level | Adjust contrast |
| Sustained Pinch | Lock | Lock current tool |
| Three-Finger Swipe | Switch Mode | Change tools |

### Advanced Gestures

| Gesture | Action | Use Case |
|---------|--------|----------|
| Palm Up + Pinch | Menu | Open radial menu |
| Palm Flat + Push | Dismiss | Close windows/menus |
| Fist + Twist | Reset | Reset view to default |

---

## Eye Tracking

### Gaze Selection

- **Look at UI element**: Element highlights
- **Pinch to confirm**: Activates element
- **Dwell time**: Auto-select after 2 seconds (optional)

### Gaze-Based Navigation

- **Window focus**: Active window follows gaze
- **Menu appearance**: Menus appear near gaze point
- **Tooltip display**: Information shows at gaze location

### Gaze Cursor

- Small dot follows your eyes
- Shows where you're looking
- Helpful for precise selection
- Toggle in Settings

---

## Collaborative Viewing

### Starting a SharePlay Session

1. Open FaceTime call with colleague
2. Tap "Share" button in DICOMViewer
3. Select "SharePlay"
4. Colleague accepts invitation

### Shared Viewing

**Synchronized**:
- All users see same study
- Navigation synced automatically
- Window/level changes shared

**Spatial Presence**:
- See colleague's avatar
- Hand positions visible
- Gaze direction indicated

### Shared Annotations

- Place measurements visible to all
- Color-coded by user
- Voice chat enabled
- Annotation ownership tracked

### Session Management

- **Invite User**: Tap "Invite" button
- **Mute Audio**: Tap mic icon
- **End Session**: Tap "End SharePlay"

---

## Tips and Tricks

### Performance

- **Reduce quality** if volume rendering is slow:
  - Settings > Rendering Quality > Low
  
- **Close unused windows** to save resources

- **Partial immersion** uses less power than full

### Comfort

- **Position volumes** at comfortable viewing distance (1-2 meters)

- **Use partial immersion** for longer sessions

- **Take breaks** every 20-30 minutes

### Workflow Efficiency

- **Voice commands**: Faster than hand gestures for some actions
  - "Show measurements"
  - "Bone preset"
  - "Next frame"
  
- **Pin frequently used windows** to fixed positions

- **Create window arrangements** for different tasks:
  - Review: Library + Viewer
  - Diagnosis: Viewer + 3D Volume + Tools
  - Collaboration: All windows + SharePlay

### Hand Gesture Tips

- **Exaggerate gestures** for better recognition

- **Keep hands visible** in field of view

- **Rest arms** on armrests when possible

- **Use two hands** for complex operations

---

## Troubleshooting

### Hand Tracking Not Working

**Problem**: Gestures not recognized

**Solutions**:
1. Check lighting (adequate light needed)
2. Ensure hands are clean and visible
3. Calibrate hand tracking in Settings
4. Restart Vision Pro

### Volume Rendering Slow

**Problem**: Frame rate drops, stuttering

**Solutions**:
1. Reduce rendering quality (Settings > Rendering Quality > Low)
2. Close other immersive apps
3. Reduce volume size (crop ROI)
4. Check thermal state (device may be hot)

### Eye Tracking Inaccurate

**Problem**: Gaze cursor doesn't follow eyes

**Solutions**:
1. Re-calibrate eye tracking (Settings > Eye Tracking)
2. Ensure good fit of Vision Pro
3. Clean front sensors
4. Check lighting conditions

### SharePlay Not Connecting

**Problem**: Can't join or start SharePlay session

**Solutions**:
1. Check network connection
2. Ensure FaceTime call is active
3. Check SharePlay settings (Settings > SharePlay)
4. Restart app
5. Ensure both devices on compatible versions

### App Crashes on Volume Load

**Problem**: App crashes when opening 3D volume

**Solutions**:
1. Check DICOM file integrity
2. Reduce volume size (may be too large)
3. Restart app
4. Report crash to developer (Settings > Help > Report Issue)

### Measurements Not Accurate

**Problem**: Measurements seem incorrect

**Solutions**:
1. Ensure DICOM has correct pixel spacing
2. Recalibrate spatial tracking
3. Check volume orientation
4. Place measurement points carefully

---

## Keyboard Shortcuts

When using Bluetooth keyboard:

| Key | Action |
|-----|--------|
| Space | Play/Pause cine |
| ← → | Navigate frames |
| ↑ ↓ | Adjust window/level |
| W | Window adjustment mode |
| L | Level adjustment mode |
| M | Measurement mode |
| A | Annotation mode |
| 1-4 | Transfer function presets |
| Cmd+I | Import file |
| Cmd+W | Close window |
| Cmd+F | Full immersion |
| Cmd+Shift+S | Start SharePlay |
| Esc | Exit immersive mode |

---

## Advanced Features

### Voice Commands

**Navigation**:
- "Next frame" / "Previous frame"
- "Show library"
- "Close window"

**Tools**:
- "Measure"
- "Annotate"
- "Bone preset"
- "Soft tissue preset"

**Collaboration**:
- "Start SharePlay"
- "Invite user"
- "Mute"

### Custom Presets

**Save Transfer Function**:
1. Adjust transfer function
2. Tap "Save Preset"
3. Name your preset
4. Access from preset menu

**Save Layout**:
1. Arrange windows
2. Tap "Save Layout"
3. Name layout
4. Load from layouts menu

---

## Accessibility

### Features

- **Voice control**: Full voice navigation support
- **Larger text**: Adjustable font sizes
- **High contrast**: Enhanced visibility mode
- **Reduced motion**: Minimal animations
- **Haptic feedback**: Tactile confirmation

### Activation

Settings > Accessibility > enable desired features

---

## Privacy and Security

### Data Handling

- **Local storage**: DICOM files stored on device
- **No cloud upload**: Patient data stays local
- **Encryption**: Files encrypted at rest
- **Secure sharing**: SharePlay uses end-to-end encryption

### Patient Privacy

- **HIPAA consideration**: App designed with privacy in mind
- **De-identification**: Use anonymization features before sharing
- **Session recording**: Disabled by default

---

## Support

### Getting Help

- **In-app help**: Tap "?" button
- **Tutorial**: Settings > Tutorial
- **Documentation**: README.md and BUILD.md
- **GitHub**: File issues and feature requests

### Contact

For support, feedback, or bug reports:
- GitHub: https://github.com/GITHUB_USERNAME/DICOMKit/issues
- Email: support@example.com (placeholder)

---

## Appendix

### Supported DICOM Formats

- **Modalities**: CT, MR, XA, US, PET, DX, CR
- **Transfer Syntaxes**: 
  - Implicit VR Little Endian
  - Explicit VR Little Endian
  - Explicit VR Big Endian
  - JPEG Baseline
  - JPEG Lossless
  - JPEG 2000
  - RLE
  
### System Requirements

- **Device**: Apple Vision Pro
- **OS**: visionOS 1.0 or later
- **Storage**: 500MB minimum for app, additional for DICOM files
- **Network**: WiFi for SharePlay features

### Medical Disclaimer

**This application is for educational and research purposes.**

It is not FDA-approved or CE-marked for clinical diagnostic use. Always consult qualified medical professionals for clinical decisions. Do not use for emergency or life-threatening situations.

---

_Enjoy exploring the future of medical imaging! 🏥✨_

_User Guide Version 1.0 - Updated for DICOMKit v1.0.14_
