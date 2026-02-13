# dicom-viewer

Terminal-based DICOM image viewer for quick inspection and triage.

## Overview

`dicom-viewer` displays DICOM images directly in the terminal using various rendering methods including ASCII art, ANSI colors, and terminal graphics protocols (iTerm2, Kitty, Sixel). This enables rapid image inspection without launching a full GUI viewer.

## Features

- **ASCII Art Rendering**: Convert images to ASCII characters (low and high quality)
- **ANSI Color Rendering**: Use 256-color or 24-bit true color terminal support
- **iTerm2 Inline Images**: Native image display in iTerm2 terminal
- **Kitty Graphics Protocol**: High-quality rendering in Kitty terminal
- **Sixel Graphics**: Sixel protocol support for compatible terminals
- **Window/Level Control**: Custom windowing for optimal contrast
- **Multi-frame Navigation**: View specific frames from multi-frame images
- **Thumbnail Grid**: Display multiple files or frames as a grid
- **Information Overlay**: Show patient and study metadata
- **Image Inversion**: Invert pixel values for better visibility

## Installation

```bash
swift build -c release
# Binary will be at .build/release/dicom-viewer
```

## Usage

### Basic Viewing

```bash
# View a DICOM image (defaults to ASCII art)
dicom-viewer scan.dcm

# View with high-quality ASCII art
dicom-viewer scan.dcm --mode ascii --quality high

# View with ANSI true color
dicom-viewer scan.dcm --mode ansi --color 24bit

# View with ANSI 256 colors (wider terminal compatibility)
dicom-viewer scan.dcm --mode ansi --color 256
```

### Terminal Graphics Protocols

```bash
# iTerm2 inline image (macOS iTerm2 terminal)
dicom-viewer scan.dcm --mode iterm2

# Kitty graphics protocol
dicom-viewer scan.dcm --mode kitty

# Sixel graphics (xterm, mlterm, etc.)
dicom-viewer scan.dcm --mode sixel
```

### Window/Level Adjustment

```bash
# CT Bone window
dicom-viewer ct.dcm --window-center 300 --window-width 1500

# CT Lung window
dicom-viewer ct.dcm --window-center -600 --window-width 1500

# CT Brain window
dicom-viewer ct.dcm --window-center 40 --window-width 80
```

### Multi-frame Images

```bash
# View specific frame
dicom-viewer multiframe.dcm --frame 5

# View all frames as thumbnails
dicom-viewer multiframe.dcm --thumbnail
```

### Thumbnail Grid

```bash
# View multiple files as thumbnails
dicom-viewer series/*.dcm --thumbnail

# Custom grid size
dicom-viewer series/*.dcm --thumbnail --size 120x60
```

### Information Display

```bash
# Show patient and study information
dicom-viewer scan.dcm --show-info

# Show with overlay at bottom
dicom-viewer scan.dcm --show-info --show-overlay
```

### Additional Options

```bash
# Custom output dimensions
dicom-viewer scan.dcm --width 100 --height 50

# Invert image (useful for dark background terminals)
dicom-viewer scan.dcm --invert

# Force parsing without DICM prefix
dicom-viewer scan.dcm --force

# Verbose output for debugging
dicom-viewer scan.dcm --verbose
```

## Display Modes

| Mode | Description | Terminal Support | Quality |
|------|-------------|-----------------|---------|
| `ascii` | ASCII character art | All terminals | Good |
| `ansi` | ANSI escape code colors | Most modern terminals | Very Good |
| `iterm2` | iTerm2 inline image protocol | iTerm2 (macOS) | Excellent |
| `kitty` | Kitty graphics protocol | Kitty terminal | Excellent |
| `sixel` | Sixel graphics protocol | xterm, mlterm, foot | Excellent |

## ASCII Quality Levels

- **low**: Uses 10-character ramp (` .:-=+*#%@`), faster rendering
- **high**: Uses 70-character ramp for much finer gradation

## Options Reference

| Option | Description | Default |
|--------|-------------|---------|
| `--mode` | Display mode (ascii, ansi, iterm2, kitty, sixel) | ascii |
| `--quality` | ASCII quality (low, high) | high |
| `--color` | ANSI color depth (256, 24bit) | 24bit |
| `--window-center` | Window center (level) | Auto |
| `--window-width` | Window width | Auto |
| `--frame` | Frame number (0-based) | 0 |
| `--width` | Output width in characters | Auto |
| `--height` | Output height in characters | Auto |
| `--invert` | Invert pixel values | false |
| `--show-info` | Show patient/study info | false |
| `--show-overlay` | Show overlay at bottom | false |
| `--thumbnail` | Display as thumbnail grid | false |
| `--size` | Thumbnail grid size (WxH) | Auto |
| `--force` | Force parse without DICM prefix | false |
| `--verbose` | Verbose debug output | false |

## Architecture

### Components

- **main.swift**: CLI interface with ArgumentParser, command routing
- **TerminalRenderer.swift**: Core rendering engine with all display modes

### Design Decisions

- Pure Swift implementation with no external graphics dependencies
- Terminal size auto-detection via `ioctl(TIOCGWINSZ)`
- Nearest-neighbor scaling for fast image resizing
- PGM format used for iTerm2 protocol (simple, no compression needed)
- Chunk-based encoding for Kitty protocol (4KB chunks)
- 64-level grayscale palette for Sixel rendering
- Half-block Unicode characters (▀) for ANSI mode (doubles vertical resolution)

## Dependencies

- **DICOMKit**: DICOM file parsing and pixel data access
- **DICOMCore**: Core data structures
- **DICOMDictionary**: Tag lookups
- **ArgumentParser**: Command-line argument parsing

## Version

Current: v1.4.0 (Phase 7.3)
