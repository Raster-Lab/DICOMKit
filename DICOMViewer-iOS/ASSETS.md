# DICOMViewer iOS - Assets Guide

This guide explains the assets needed for the DICOMViewer iOS app.

## Overview

The app requires assets for:
- App icon (all sizes for iOS/iPadOS)
- Launch screen (optional image)
- Color assets for dark/light mode
- SF Symbols (provided by iOS, no custom assets needed)

## Required Assets

### App Icon

Create an app icon set in Xcode:

1. **In Xcode:** Assets.xcassets → App Icon
2. **Required sizes:**
   - iPhone: 60pt @2x, 60pt @3x (120x120, 180x180)
   - iPad: 76pt @2x (152x152)
   - App Store: 1024x1024

3. **Design guidelines:**
   - Medical imaging theme (e.g., CT scan, MRI, or medical cross)
   - Dark background with light icon (medical apps convention)
   - Avoid text (icon should be recognizable at small sizes)
   - Use simple, bold shapes
   - Consider accessibility (high contrast)

4. **Suggested design:**
   ```
   - Background: Dark blue/gray (#1C1C1E or #2C2C2E)
   - Icon: White/light gray DICOM viewer symbol
   - Options:
     * Stylized DICOM grid pattern
     * Medical imaging cross with film icon
     * Minimalist CT/MRI scanner symbol
   ```

### Color Assets

Add color sets for consistent theming:

**In Assets.xcassets, create Color Sets:**

1. **AccentColor** (Xcode default, customizable)
   - Light Appearance: System Blue (#007AFF)
   - Dark Appearance: System Blue (#0A84FF)
   - Use: Tappable elements, selected states

2. **LaunchScreenBackground**
   - Any Appearance: Dark Gray (#1C1C1E)
   - Use: Launch screen background

3. **MeasurementColor** (optional)
   - Any Appearance: System Yellow (#FFCC00)
   - Use: Measurement overlays

4. **PresentationStateColor** (optional)
   - Any Appearance: System Green (#32D74B)
   - Use: GSPS annotations

### Launch Screen

iOS 17+ uses `UILaunchScreen` in Info.plist (no storyboard needed):

**Option 1: Solid Color (Simplest)**
- Set in Info.plist → UILaunchScreen → UIColorName: LaunchScreenBackground
- No image needed

**Option 2: With Image**
1. Add image to Assets.xcassets → New Image Set → "LaunchImage"
2. Recommended size: 1024x1024 (centered, scales down)
3. Design: App icon or simple medical imaging symbol
4. Set in Info.plist → UILaunchScreen → UIImageName: LaunchImage

**Recommended:** Use Option 1 (solid dark color) for medical imaging apps

## SF Symbols Used

The app uses Apple's SF Symbols (no custom assets needed):

**Library Tab:**
- `folder` - Library tab icon
- `magnifyingglass` - Search
- `line.3.horizontal.decrease.circle` - Filter
- `plus.circle` - Add files
- `trash` - Delete

**Viewer Tab:**
- `eye` - Viewer tab icon
- `play.fill` / `pause.fill` - Cine playback
- `slider.horizontal.3` - Window/level
- `arrow.clockwise` - Rotate
- `arrow.uturn.backward` - Reset

**Measurements:**
- `ruler` - Length measurement
- `angle` - Angle measurement
- `circle.dashed` - Ellipse ROI
- `rectangle.dashed` - Rectangle ROI
- `scribble` - Freehand ROI

**Settings Tab:**
- `gear` - Settings tab icon
- `moon` - Dark mode toggle
- `info.circle` - About/info

**Others:**
- `doc.on.doc` - Copy
- `square.and.arrow.up` - Share/export
- `photo` - Save to Photos
- `xmark.circle` - Close/dismiss

All SF Symbols are automatically tinted with AccentColor.

## Creating Assets in Xcode

### Step 1: Create Asset Catalog (if not exists)

```
File → New → File... → Resource → Asset Catalog
Name: Assets
Click Create
```

### Step 2: Add App Icon

```
Assets.xcassets → Right-click → New App Icon
Name: AppIcon (default)

For each size slot:
- Drag PNG file from Finder
- OR click slot → Import → Select image file
```

### Step 3: Add Colors

```
Assets.xcassets → Right-click → New Color Set
Name: [ColorName]

For each color:
1. Select "Any Appearance" color well
2. Click color picker
3. Choose color or enter hex code
4. (Optional) Add "Dark Appearance" variant
```

### Step 4: Verify in Info.plist

Ensure `Info.plist` references the asset catalog:

```xml
<key>CFBundleIcons</key>
<dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconName</key>
        <string>AppIcon</string>
    </dict>
</dict>
```

This is usually auto-configured by Xcode.

## Using Assets in Code

### Colors

```swift
import SwiftUI

// Accent color (automatic)
Button("Action") { }
    .foregroundColor(.accentColor)

// Custom color
Text("Measurement")
    .foregroundColor(Color("MeasurementColor"))

// System colors
Rectangle()
    .fill(Color(uiColor: .systemBackground))
```

### SF Symbols

```swift
// Simple icon
Image(systemName: "folder")
    .font(.title)

// Custom size and color
Image(systemName: "ruler")
    .font(.system(size: 24))
    .foregroundColor(.yellow)

// In buttons
Button(action: {}) {
    Label("Measure", systemImage: "ruler")
}
```

## Asset Checklist

Before App Store submission:

- [ ] App icon created for all required sizes
- [ ] App icon follows design guidelines (no transparency, square, etc.)
- [ ] 1024x1024 App Store icon included
- [ ] AccentColor set (or use system default)
- [ ] LaunchScreenBackground color defined
- [ ] Launch screen tested on iPhone and iPad
- [ ] Dark mode tested (all assets visible)
- [ ] Light mode tested (if supported)
- [ ] High contrast mode tested (accessibility)
- [ ] All image assets are @2x and @3x for Retina displays

## Tools for Creating Icons

### Free Tools
- **SF Symbols App** (Apple) - Browse available symbols
- **Pixelmator** (Free tier) - Icon design
- **Sketch** (Trial) - Vector design
- **Canva** (Free) - Simple designs

### Professional Tools
- **Adobe Illustrator** - Vector graphics
- **Sketch** - macOS design tool
- **Figma** - Collaborative design

### Icon Generators
- **App Icon Generator** - Generate all sizes from 1024x1024
  - [appicon.co](https://www.appicon.co/)
  - [makeappicon.com](https://makeappicon.com/)

### Design Services
- **Fiverr** - Commission custom icon ($10-50)
- **99designs** - Professional design contest

## Recommendations for DICOMViewer

**Minimalist Approach:**
1. Use a simple dark icon with white/gray medical symbol
2. Use system colors throughout (no custom color sets)
3. Use solid color launch screen (no image)
4. Rely on SF Symbols for all UI icons

**Benefits:**
- Fast to implement (< 30 minutes)
- Professional appearance
- Consistent with iOS design language
- Low maintenance
- Excellent dark mode support

**To get started quickly:**
1. Create a 1024x1024 dark icon with simple medical symbol
2. Use an icon generator to create all sizes
3. Import to Xcode Assets.xcassets
4. Set LaunchScreenBackground to dark gray
5. Done!

## Sample Icon Concept (Text Description)

```
Background: #2C2C2E (dark gray)
Icon: White (#FFFFFF) simplified CT scanner or film grid
Style: Minimalist, flat design
Shape: Rounded square (iOS automatically applies corner radius)

Central element:
- Option A: 3x3 grid of small squares (DICOM film strip)
- Option B: Simplified CT scanner outline
- Option C: Medical cross with imaging icon

Keep it simple, recognizable, and professional.
```

## Resources

- **Apple HIG - App Icons:** [developer.apple.com/design/human-interface-guidelines/app-icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- **SF Symbols:** [developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols/)
- **Asset Catalog Guide:** [developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format)

---

**For help:** See [BUILD.md](BUILD.md) or open an issue on GitHub
