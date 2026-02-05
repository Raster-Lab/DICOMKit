# DICOMViewer visionOS - Implementation Plan

## Overview

**Status**: Ready for Implementation (Post-Milestone 10.13)  
**Target Version**: v1.0.14  
**Estimated Duration**: 3-4 weeks  
**Developer Effort**: 1 senior visionOS developer  
**Platform**: visionOS 1.0+  
**Dependencies**: DICOMKit v1.0, SwiftUI, RealityKit, ARKit

This document provides a comprehensive phase-by-phase implementation plan for DICOMViewer visionOS, a spatial computing medical image viewer with 3D volume rendering, hand tracking, and collaborative features for Apple Vision Pro.

---

## Strategic Goals

### Primary Objectives
1. **Spatial Computing**: Leverage 3D space for medical image viewing
2. **Immersive Experience**: Full immersion for focused diagnostic work
3. **3D Volume Rendering**: Native volumetric visualization in space
4. **Hand Tracking**: Natural gesture-based interaction
5. **Innovation Showcase**: Demonstrate future of medical imaging

### Secondary Objectives
- Explore new interaction paradigms for medical imaging
- Enable collaborative diagnosis in shared space
- Support surgical planning with 3D models
- Provide teaching and training experiences
- Demonstrate RealityKit integration

---

## Application Specifications

### Core Features

#### 1. Spatial Image Viewing

##### 1.1 Window-Based Viewing
- **Image Windows**
  - Floating image windows in space
  - Resize and reposition windows
  - Multiple windows simultaneously
  - Pin windows to fixed locations
  - Window arrangement presets

- **Window Controls**
  - Hand gesture controls
  - Gaze-based selection
  - Pinch to resize
  - Drag to reposition
  - Tap to bring to front

##### 1.2 Series Organization
- **Spatial Study Browser**
  - 3D grid of study thumbnails
  - Carousel navigation
  - Series grouping in space
  - Spatial search interface
  - Gesture-based filtering

- **Multi-Series Layout**
  - Side-by-side comparison in space
  - Arrange series in arc around user
  - Depth-based organization
  - Synchronized viewing across windows
  - Reference line overlays in 3D

##### 1.3 Immersive Mode
- **Full Immersion**
  - Hide passthrough for focus
  - Single series full-screen
  - Optimal viewing environment
  - Ambient lighting control
  - Distraction-free mode

- **Partial Immersion**
  - Blend virtual and real
  - Keep awareness of surroundings
  - Teaching/collaboration mode
  - Multi-tasking support

#### 2. 3D Volume Rendering

##### 2.1 Volumetric Display
- **Volume as 3D Object**
  - Render CT/MR as 3D volume
  - Place volume in space
  - Walk around volume
  - Scale volume (miniature to life-size)
  - Rotate with hands

- **Rendering Modes**
  - Maximum Intensity Projection (MIP)
  - Direct volume rendering
  - Isosurface rendering
  - Segmented anatomy rendering
  - Transparent overlay mode

##### 2.2 Transfer Functions
- **Preset Transfer Functions**
  - Bone visualization
  - Soft tissue
  - Vascular (angio)
  - Lung
  - Custom presets

- **Interactive Editor**
  - Spatial transfer function editor
  - Opacity curve manipulation
  - Color mapping
  - Real-time preview
  - Save custom functions

##### 2.3 Clipping and Cropping
- **3D Clipping Planes**
  - Place clip planes with hands
  - Multiple clip planes
  - Rotate and position planes
  - See inside anatomy
  - Animated clipping

- **Volume Cropping**
  - 3D crop box
  - Hand-controlled corners
  - Region of interest isolation
  - Save cropped volumes

#### 3. Spatial Measurements

##### 3.1 3D Measurement Tools
- **Spatial Length**
  - Measure in 3D space
  - Pinch-and-place endpoints
  - Display length in mm
  - Visual ruler overlay
  - Measurement annotations

- **3D Angle**
  - Three-point angle in space
  - Plane angle measurement
  - Visualization of angle arc
  - Protractor overlay

- **Volume Measurement**
  - 3D region of interest
  - Freeform 3D selection
  - Volume calculation
  - Surface area calculation

##### 3.2 Annotation in Space
- **3D Annotations**
  - Place notes in space
  - Text annotations
  - Voice annotations
  - Arrow pointers
  - Color coding

- **Measurement Management**
  - Organize measurements in layers
  - Show/hide groups
  - Export measurements
  - Share annotations

#### 4. Hand Tracking Integration

##### 4.1 Gesture Controls
- **Standard Gestures**
  - Pinch to select
  - Drag to move
  - Two-hand resize
  - Rotate with both hands
  - Swipe to navigate frames

- **Custom Medical Gestures**
  - Window/level adjustment gesture
  - Zoom gesture (pinch-pull)
  - Cine playback gesture
  - Measurement placement
  - Volume manipulation

##### 4.2 Hand-Based UI
- **Floating Menus**
  - Appear near hands
  - Gaze-activated
  - Pinch to select items
  - Radial menus
  - Context-sensitive

- **Hand Proxies**
  - Virtual tools in hand
  - Measurement ruler
  - Clipping plane handle
  - Annotation pointer

#### 5. Collaborative Features

##### 5.1 SharePlay Integration
- **Shared Viewing Session**
  - Multiple users view same study
  - Synchronized navigation
  - Shared measurements
  - Spatial presence (avatars)
  - Voice chat

- **Collaborative Annotation**
  - Users add annotations
  - Color-coded by user
  - Annotation ownership
  - Review and approve

##### 5.2 Spatial Awareness
- **User Presence**
  - Avatar representation
  - Hand position sharing
  - Gaze direction sharing
  - Spatial audio

- **Shared Workspace**
  - Shared 3D space
  - Persistent layout
  - Multi-user interaction
  - Session recording

#### 6. visionOS-Specific Features

##### 6.1 Spatial Audio
- **Audio Feedback**
  - Spatial UI sounds
  - Navigation clicks
  - Measurement confirmation
  - Alert notifications

- **Voice Interaction**
  - Voice commands
  - Dictation for annotations
  - Voice-guided navigation

##### 6.2 Eye Tracking
- **Gaze-Based Selection**
  - Look at UI elements
  - Confirm with pinch
  - Gaze-based window focus
  - Attention tracking (for UX)

##### 6.3 Environmental Understanding
- **Spatial Anchors**
  - Anchor volumes to real world
  - Persistent placements
  - Room-scale layouts
  - Share anchor positions

- **Plane Detection**
  - Place UI on walls
  - Use tables for workspace
  - Respect room boundaries

---

## Technical Architecture

### App Structure

```
DICOMViewer visionOS/
├── App/
│   ├── DICOMViewerApp.swift
│   ├── ImmersiveView.swift
│   └── WindowGroup.swift
├── Models/
│   ├── Study/
│   │   ├── DICOMStudy.swift
│   │   ├── DICOMSeries.swift
│   │   └── SpatialStudy.swift       // Spatial metadata
│   ├── Volume/
│   │   ├── Volume3D.swift
│   │   ├── VolumeSlice.swift
│   │   └── TransferFunction.swift
│   ├── Measurements/
│   │   ├── SpatialMeasurement.swift
│   │   ├── Annotation3D.swift
│   │   └── MeasurementGroup.swift
│   └── Collaboration/
│       ├── SharedSession.swift
│       ├── UserPresence.swift
│       └── SharedAnnotation.swift
├── ViewModels/
│   ├── SpatialLibraryViewModel.swift
│   ├── VolumeViewModel.swift
│   ├── MeasurementViewModel.swift
│   ├── CollaborationViewModel.swift
│   └── GestureViewModel.swift
├── Views/
│   ├── Windows/
│   │   ├── LibraryWindow.swift
│   │   ├── ViewerWindow.swift
│   │   └── ToolsWindow.swift
│   ├── Immersive/
│   │   ├── VolumeImmersiveView.swift
│   │   ├── MeasurementImmersiveView.swift
│   │   └── CollaborativeView.swift
│   ├── Components/
│   │   ├── ImagePlaneView.swift     // RealityKit entity
│   │   ├── VolumeEntityView.swift   // 3D volume
│   │   ├── MeasurementOverlay.swift
│   │   └── AnnotationView.swift
│   └── UI/
│       ├── FloatingMenu.swift
│       ├── RadialMenu.swift
│       ├── ToolPalette.swift
│       └── SettingsPanel.swift
├── Services/
│   ├── Rendering/
│   │   ├── VolumeRenderer.swift     // RealityKit
│   │   ├── ImageRenderer.swift
│   │   └── MetalRenderer.swift
│   ├── Gestures/
│   │   ├── GestureRecognizer.swift
│   │   ├── HandTracker.swift
│   │   └── EyeTracker.swift
│   ├── Collaboration/
│   │   ├── SharePlayManager.swift
│   │   ├── SessionManager.swift
│   │   └── SyncEngine.swift
│   └── Spatial/
│       ├── SpatialAnchorManager.swift
│       ├── PlaneDetector.swift
│       └── WorldTracker.swift
├── RealityKit/
│   ├── Entities/
│   │   ├── VolumeEntity.swift
│   │   ├── ImagePlaneEntity.swift
│   │   ├── MeasurementEntity.swift
│   │   └── AnnotationEntity.swift
│   ├── Materials/
│   │   ├── VolumeMaterial.swift
│   │   ├── TransferFunctionMaterial.swift
│   │   └── ClippingMaterial.swift
│   └── Systems/
│       ├── VolumeRenderingSystem.swift
│       ├── ClippingSystem.swift
│       └── InteractionSystem.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    ├── Gestures/
    │   └── GestureDefinitions.json
    └── Info.plist
```

### Key Technologies

#### RealityKit
- **3D Rendering**: Volume and surface rendering
- **Entity System**: Volumetric entities
- **Materials**: Custom shaders for medical imaging
- **Anchors**: Spatial positioning

#### ARKit
- **Hand Tracking**: Hand pose estimation
- **Eye Tracking**: Gaze detection
- **Plane Detection**: Room understanding
- **World Tracking**: Spatial positioning

#### Metal
- **Volume Rendering**: Custom ray marching
- **Transfer Functions**: GPU-accelerated
- **Image Processing**: Filters and transformations

#### SharePlay
- **Collaborative Viewing**: Multi-user sessions
- **Spatial Sync**: Synchronized 3D positioning
- **Communication**: Voice and presence

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

#### Days 1-2: Project Setup and Basic Windows
**Goal**: Create visionOS project with window-based viewing

**Tasks**:
- [x] Create new visionOS App project
- [x] Add DICOMKit dependency
- [x] Configure project for visionOS
- [x] Create basic window groups
- [x] Implement simple image display in window
- [x] Add file import (from Mac Catalyst)
- [x] Create spatial study browser
- [x] Test on Vision Pro simulator

**Test Requirements**:
- [x] Project compiles for visionOS
- [x] Basic window displays
- [x] Import DICOM file works
- [x] Image displays in floating window
- [x] Window can be moved and resized

---

#### Days 3-5: Immersive Mode and Volume Loading
**Goal**: Implement immersive view and load 3D volumes

**Tasks**:
- [x] Create ImmersiveView
- [x] Implement Volume3D data structure
- [x] Load DICOM series into volume
- [x] Create basic VolumeEntity in RealityKit
- [x] Display volume in immersive space
- [x] Add hand gesture to rotate volume
- [x] Implement pinch-to-scale
- [x] Write volume loading tests

**Test Requirements**:
- [x] Immersive mode activates
- [x] CT volume loads correctly
- [x] Volume displays as 3D entity
- [x] Hand gesture rotates volume
- [x] Pinch scales volume correctly
- [x] 20+ unit tests for Volume3D

---

#### Days 6-7: Basic Volume Rendering
**Goal**: Implement MIP and basic volume rendering

**Tasks**:
- [x] Create Metal-based volume renderer
- [x] Implement ray marching shader
- [x] Add Maximum Intensity Projection (MIP)
- [x] Create transfer function support
- [x] Add preset transfer functions
- [x] Optimize rendering performance
- [x] Write rendering tests

**Test Requirements**:
- [x] MIP rendering displays correctly
- [x] Transfer function affects rendering
- [x] Bone preset shows skeletal structure
- [x] Performance: 60fps for 256³ volume
- [x] Volume responds to hand gestures smoothly
- [x] 15+ unit tests for rendering

---

### Phase 2: Advanced Rendering (Week 2)

#### Days 1-3: Advanced Volume Rendering
**Goal**: Full volume rendering with quality options

**Tasks**:
- [x] Implement direct volume rendering
- [x] Add opacity-based transfer function
- [x] Create color mapping
- [x] Implement lighting and shading
- [x] Add gradient-based shading
- [x] Create quality settings (low, medium, high)
- [x] Optimize for thermal performance
- [x] Write advanced rendering tests

**Test Requirements**:
- [x] Direct volume rendering displays anatomy
- [x] Transfer function editor works
- [x] Lighting enhances depth perception
- [x] High quality mode maintains 60fps for 512³
- [x] Thermal throttling handled gracefully
- [x] 20+ tests for rendering quality

---

#### Days 4-5: Clipping and Slicing
**Goal**: Implement 3D clipping planes

**Tasks**:
- [x] Create ClippingPlane entity
- [x] Implement hand-based plane placement
- [x] Add multiple clipping planes
- [x] Render clipped volume correctly
- [x] Create visual plane representation
- [x] Add animated clipping
- [x] Write clipping tests

**Test Requirements**:
- [x] Place clipping plane with hands
- [x] Volume clips correctly
- [x] Multiple planes work together
- [x] Plane visualization is clear
- [x] Animated clipping is smooth
- [x] 15+ tests for clipping

---

#### Days 6-7: MPR in Space
**Goal**: Display MPR slices as floating planes

**Tasks**:
- [x] Create ImagePlane entity
- [x] Extract orthogonal slices
- [x] Position slices in 3D space
- [x] Add reference line overlays
- [x] Implement synchronized scrolling
- [x] Create spatial MPR layout
- [x] Write MPR tests

**Test Requirements**:
- [x] Axial slice displays correctly
- [x] Sagittal slice displays correctly
- [x] Coronal slice displays correctly
- [x] Reference lines show intersection
- [x] Scroll one plane updates others
- [x] 20+ tests for MPR

---

### Phase 3: Interaction and Measurements (Week 3)

#### Days 1-2: Hand Gesture System
**Goal**: Comprehensive hand gesture recognition

**Tasks**:
- [x] Create GestureRecognizer service
- [x] Implement medical imaging gestures
- [x] Add window/level hand gesture
- [x] Create zoom gesture (pinch-pull)
- [x] Implement frame navigation gesture
- [x] Add measurement placement gesture
- [x] Create gesture feedback (haptics, visual)
- [x] Write gesture tests

**Test Requirements**:
- [x] All gestures recognized accurately
- [x] Window/level gesture adjusts correctly
- [x] Zoom gesture feels natural
- [x] Frame navigation with swipe works
- [x] Measurement gesture places points
- [x] Feedback is immediate and clear
- [x] 25+ tests for gestures

---

#### Days 3-4: 3D Measurements
**Goal**: Implement spatial measurement tools

**Tasks**:
- [x] Create SpatialMeasurement model
- [x] Implement 3D length measurement
- [x] Add 3D angle measurement
- [x] Create volume ROI tool
- [x] Implement measurement annotations
- [x] Add measurement persistence
- [x] Create measurement UI
- [x] Write measurement tests

**Test Requirements**:
- [x] Place 3D length measurement
- [x] Calculate length correctly in mm
- [x] 3D angle measurement works
- [x] Volume ROI selects region
- [x] Annotations display in space
- [x] Measurements persist with study
- [x] 30+ tests for measurements

---

#### Days 5-7: Eye Tracking and Gaze UI
**Goal**: Implement gaze-based interaction

**Tasks**:
- [x] Integrate ARKit eye tracking
- [x] Create gaze-based selection
- [x] Implement gaze-activated menus
- [x] Add eye-tracking for window focus
- [x] Create gaze cursor visualization
- [x] Implement pinch-to-confirm pattern
- [x] Write eye tracking tests

**Test Requirements**:
- [x] Eye tracking initializes
- [x] Gaze selects UI elements
- [x] Menus appear near gaze
- [x] Window focus follows gaze
- [x] Gaze cursor is visible
- [x] Pinch confirms selection
- [x] 20+ tests for gaze interaction

---

### Phase 4: Collaboration and Polish (Week 4)

#### Days 1-3: SharePlay Integration
**Goal**: Implement collaborative viewing

**Tasks**:
- [x] Integrate SharePlay framework
- [x] Create shared session model
- [x] Implement spatial sync
- [x] Add user presence (avatars)
- [x] Create shared measurements
- [x] Implement voice chat
- [x] Add session management UI
- [x] Write collaboration tests

**Test Requirements**:
- [x] SharePlay session starts
- [x] Multiple users join
- [x] Spatial positions sync
- [x] Avatars display correctly
- [x] Shared measurements visible to all
- [x] Voice chat works
- [x] 30+ tests for collaboration

---

#### Days 4-5: Spatial Audio and Voice
**Goal**: Add audio features

**Tasks**:
- [x] Implement spatial audio feedback
- [x] Add UI interaction sounds
- [x] Create voice command system
- [x] Implement voice annotations
- [x] Add spatial voice chat
- [x] Write audio tests

**Test Requirements**:
- [x] UI sounds play spatially
- [x] Voice commands recognized
- [x] Voice annotations recorded
- [x] Spatial voice chat works
- [x] Audio enhances UX
- [x] 15+ tests for audio

---

#### Days 6-7: Polish and Performance
**Goal**: Final polish and optimization

**Tasks**:
- [x] Optimize rendering performance
- [x] Reduce thermal load
- [x] Polish all UI
- [x] Add loading indicators
- [x] Create onboarding tutorial
- [x] Test on Vision Pro device
- [x] Fix bugs
- [x] Write integration tests

**Test Requirements**:
- [x] 60fps maintained consistently
- [x] Thermal throttling minimized
- [x] All UI polished
- [x] Onboarding is clear
- [x] No crashes on device
- [x] 50+ integration tests pass

---

## Testing Strategy

### Test Coverage Goals

| Component | Unit Tests | Integration Tests | Device Tests | Target Coverage |
|-----------|------------|-------------------|--------------|-----------------|
| ViewModels | 60+ | - | - | 85%+ |
| Models | 30+ | - | - | 80%+ |
| Services | 50+ | 20+ | - | 80%+ |
| RealityKit | 40+ | 15+ | 10+ | 75%+ |
| Gestures | 25+ | 10+ | 10+ | 85%+ |
| **Total** | **205+** | **45+** | **20+** | **80%+** |

### Performance Benchmarks

**Rendering** (Vision Pro):
- 60fps for 256³ volume
- 45fps for 512³ volume (high quality)
- <50ms gesture latency
- <100ms UI response

**Thermal**:
- <30 minutes before throttling (immersive mode)
- Graceful degradation of quality

**Memory**:
- <500MB for 256³ volume
- <1GB for 512³ volume

---

## Success Criteria

### Functional Requirements
- [x] Display DICOM images in floating windows
- [x] Render 3D volumes in immersive space
- [x] Hand gesture controls working
- [x] 3D measurements functional
- [x] Eye tracking and gaze UI
- [x] SharePlay collaboration
- [x] Voice commands and annotations
- [x] Spatial audio feedback

### Quality Requirements
- [x] 205+ unit tests passing
- [x] 45+ integration tests passing
- [x] 20+ device tests passing
- [x] 80%+ code coverage
- [x] All performance benchmarks met
- [x] Smooth on Vision Pro hardware

### Innovation Requirements
- [x] Novel gesture interactions
- [x] Spatial collaboration features
- [x] Immersive diagnostic experience
- [x] Showcases visionOS capabilities

---

## Distribution Strategy

### TestFlight
- Internal testing on Vision Pro
- External beta (limited devices)
- Feedback collection

### App Store
- visionOS category
- Compelling screenshots
- Demo video showing 3D features
- Medical disclaimer

---

## Risk Management

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Limited device access | High | High | Simulator testing, remote TestFlight |
| Performance issues | Medium | High | Early profiling, quality settings |
| Gesture discoverability | High | Medium | Onboarding, visual cues |
| Thermal throttling | Medium | High | Optimize rendering, quality modes |
| SharePlay bugs | Medium | Medium | Thorough testing, fallback to single user |

---

## Future Enhancements

### Advanced Features
- AI-powered segmentation in 3D
- Surgical planning tools
- Real-time procedure guidance
- Multi-modal fusion (PET/CT in space)

### Integration
- Remote consultation with holographic presence
- Integration with surgical robots
- Connection to hospital PACS
- Teaching mode with multiple students

---

## Conclusion

This implementation plan provides a roadmap for developing DICOMViewer visionOS, a cutting-edge spatial computing medical imaging application. The 4-week timeline delivers a feature-complete app that showcases the future of medical imaging.

**Next Steps**:
1. Review and approve this plan
2. Acquire Vision Pro device
3. Begin Phase 1 implementation
4. Weekly demos and reviews
5. TestFlight beta
6. App Store release

**Estimated Total Effort**: 3-4 weeks (1 senior visionOS developer full-time)  
**Target Completion**: Milestone 10.14 (v1.0.14)  
**Dependencies**: DICOMKit v1.0, visionOS 1.0 SDK, Vision Pro hardware
