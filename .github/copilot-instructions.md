# DICOMKit Copilot Instructions

## Project Overview

DICOMKit is a pure Swift DICOM (Digital Imaging and Communications in Medicine) toolkit designed for Apple platforms including iOS, macOS, and visionOS. This library provides native Swift implementations for reading, parsing, and working with DICOM medical imaging files.

## Tech Stack

- **Language**: Swift (targeting modern Swift versions)
- **Platforms**: iOS, macOS, visionOS
- **Package Manager**: Swift Package Manager (SPM)
- **Build System**: Swift Package Manager / Xcode
- **Testing Framework**: XCTest

## Coding Standards

### Swift Style Guide

- Follow Swift API Design Guidelines and naming conventions
- Use clear, descriptive names for types, properties, and methods
- Prefer value types (structs) over reference types (classes) where appropriate
- Use Swift's type safety features - avoid force unwrapping (`!`) unless absolutely necessary
- Prefer guard statements for early returns over nested if statements
- Use `let` for constants, `var` only when mutability is required
- Add appropriate access control (public, internal, private, fileprivate)
- Document public APIs with Swift documentation comments (`///`)

### DICOM-Specific Conventions

- Follow DICOM standard terminology and naming conventions
- Use proper medical imaging terminology
- Maintain accuracy and precision in data handling (DICOM data integrity is critical)
- Support standard DICOM Value Representations (VR) and Transfer Syntaxes

### File Organization

- Group related functionality into separate files
- Use extensions to organize code by protocol conformance
- Keep files focused and single-purpose
- Place tests in a Tests directory following Swift Package Manager conventions

## Forbidden Patterns

- **No force unwrapping** unless the code path guarantees safety (e.g., in tests)
- **No implicit unwrapped optionals** in production code
- **No Objective-C runtime dependencies** - keep it pure Swift
- **Avoid `Any` and `AnyObject`** - use specific types or generics
- **No hardcoded paths or magic numbers** - use constants or configuration
- **Don't ignore errors** - handle or propagate all errors appropriately
- **Avoid breaking changes** to public API without proper versioning

## Error Handling

- Use Swift's native error handling with `do-catch` and `throws`
- Define clear, specific error types using enums conforming to Error protocol
- Provide informative error messages that help with debugging
- Don't silently swallow errors - propagate or log appropriately

## Testing and Validation

- All public APIs should have corresponding unit tests
- Use XCTest framework for all tests
- Test edge cases, especially for DICOM data parsing
- Include tests for error conditions
- Use descriptive test method names following the pattern: `test_methodName_condition_expectedResult`
- Run tests before committing changes: `swift test`

## Documentation

- Document all public types, methods, and properties with Swift doc comments
- Include usage examples in documentation where helpful
- Update README.md for significant feature additions
- Maintain changelog for version releases
- Document DICOM tag support and limitations

## Dependencies

- Minimize external dependencies to keep the library lightweight
- Prefer Swift-native solutions over third-party libraries
- Any new dependency must be justified and reviewed
- Use Swift Package Manager for dependency management

## Performance Considerations

- DICOM files can be large - optimize for memory efficiency
- Consider lazy loading for large datasets
- Profile performance-critical code paths
- Avoid unnecessary copying of large data structures

## Platform Compatibility

- Ensure code works across iOS, macOS, and visionOS
- Use `#available` checks for platform-specific APIs
- Test on all supported platforms before release
- Avoid platform-specific code unless necessary

## Security and Privacy

- Handle medical imaging data with appropriate security
- Don't log or expose sensitive patient information
- Validate all input data to prevent crashes or exploits
- Follow HIPAA compliance guidelines where applicable

## Build and Release

- Ensure code compiles without warnings
- Run `swift build` to verify compilation
- Run `swift test` to verify all tests pass
- Follow semantic versioning for releases
- Tag releases appropriately in git

## Contributing Guidelines

- Keep commits focused and atomic
- Write clear commit messages describing the change
- Ensure all tests pass before submitting changes
- Update documentation for API changes
- Follow the existing code style and patterns

## Post-Task Requirements

After completing any significant work on DICOMKit, Copilot should:

### README.md Updates
When finishing any task that involves feature additions, API changes, or version updates:

1. **Update the Features section** if new functionality was added
   - Add new feature entries under the appropriate version heading
   - Use the established format with checkmarks (✅) and version tags

2. **Update the Architecture section** if new public types were added
   - Add new types under the relevant module (DICOMCore, DICOMDictionary, DICOMNetwork, or DICOMKit)
   - Include "(NEW in vX.X.X)" tag for new additions

3. **Update the version note at the bottom** if the version changed
   - Update the version number
   - Update the description to reflect the latest changes

4. **Update version headers** in the Architecture section module headers
   - Ensure module headers like "DICOMNetwork (v0.6, v0.7, ...)" include all version numbers

5. **Update the Limitations section** if any limitations were addressed or new ones discovered

### MILESTONES.md Updates
When finishing any task that involves milestone progress:

1. **Update the Status field** if a milestone's status has changed
   - Change "In Progress" to "Completed" when all deliverables are done
   - Change "Planned" to "In Progress" when work begins

2. **Update checklist items** to reflect completed work
   - Mark items as `[x]` when completed
   - Add new items if scope expanded during implementation
   - Note any deferred items with "(deferred to Milestone X.Y)"

3. **Update the Milestone Summary table** at the end of each major milestone section
   - Update the Status column (✅ Completed, In Progress, Planned)
   - Update the Key Deliverables column with accurate test counts or feature summaries

4. **Update acceptance criteria** to reflect what was achieved
   - Mark completed criteria as `[x]`
   - Note any criteria that were partially met or deferred

5. **Update Technical Notes** if implementation details changed
   - Add references to relevant DICOM standard sections
   - Note any design decisions or constraints discovered

### Code Examples
If new APIs were added:
- Add usage examples in the appropriate "Quick Start" or feature-specific sections
- Ensure examples follow the existing code style and are runnable

### Version Consistency
Ensure all version references are consistent throughout the README:
- Features section header version
- Architecture section module headers
- Note at the bottom of the file

This helps maintain accurate and up-to-date documentation for users of DICOMKit.

### Reminder
**IMPORTANT**: Always update BOTH README.md AND MILESTONES.md when completing tasks that involve:
- New features or functionality
- Milestone progress (items completed, status changes)
- Version updates
- API additions or changes

Failure to update these files can lead to inconsistent documentation and make it difficult for users and contributors to understand the current state of the project.

### CLI Tools for Completed Functionality

**IMPORTANT**: Whenever a new feature or functionality is completed in any DICOMKit library module (DICOMCore, DICOMDictionary, DICOMNetwork, DICOMWeb, DICOMToolbox, or DICOMKit), Copilot **must** also create a corresponding CLI tool that exposes that functionality via the command line.

#### When to Add a CLI Tool

A new CLI tool should be added when:
- A new public API or capability is added to any library module (e.g., new parsing, conversion, validation, networking, or processing feature)
- An existing feature is significantly enhanced with new operations that users would benefit from accessing via the command line
- A new DICOM service or workflow is implemented (e.g., a new SOP Class, network operation, or file manipulation)

#### CLI Tool Requirements

1. **Naming Convention**: Use the `dicom-<name>` format (e.g., `dicom-info`, `dicom-validate`, `dicom-compress`)
   - The name should clearly describe the tool's primary function
   - Use lowercase with hyphens to separate words

2. **Source Structure**: Create a new directory under `Sources/dicom-<name>/` containing:
   - `main.swift` — Entry point using `ArgumentParser`'s `ParsableCommand`
   - Additional Swift files as needed to keep the code organized

3. **Package.swift Updates**: Add the new CLI tool to `Package.swift`:
   - Add an `.executable(name: "dicom-<name>", targets: ["dicom-<name>"])` entry in the `products` array
   - Add a corresponding `.executableTarget(name: "dicom-<name>", dependencies: [...])` entry in the `targets` array
   - Include the appropriate library dependencies (e.g., `DICOMKit`, `DICOMCore`, `DICOMNetwork`) and `ArgumentParser`

4. **Implementation Standards**:
   - Use `ArgumentParser` for command-line argument parsing
   - Provide a clear `abstract` and `discussion` in the `CommandConfiguration`
   - Include usage examples in the `discussion` text
   - Set `version` to match the current DICOMKit version
   - Support common output formats where applicable (text, JSON, CSV)
   - Implement proper error handling with informative messages
   - Support `--verbose` and `--quiet` flags where appropriate
   - Support batch processing and directory recursion where applicable

5. **Testing**: Add unit tests for the new CLI tool in the `Tests/` directory
   - Test argument parsing and validation
   - Test core functionality with sample inputs
   - Test error conditions and edge cases
   - Follow the existing test naming pattern: `test_methodName_condition_expectedResult`

6. **Documentation**: Add a `README.md` inside the `Sources/dicom-<name>/` directory describing:
   - Purpose and capabilities of the tool
   - Usage examples with sample commands
   - Available options and flags
   - Example output

7. **Update CLI_TOOLS_COMPLETION_SUMMARY.md**: Add the new tool to the completion summary with:
   - Tool name and purpose
   - Lines of code and test count
   - Feature list and example usage

#### Existing CLI Tools Reference

The following CLI tools already exist and should serve as reference implementations for style and structure:

| Tool | Purpose |
|------|---------|
| `dicom-info` | Display DICOM file metadata |
| `dicom-convert` | Transfer syntax conversion and image export |
| `dicom-validate` | DICOM conformance validation |
| `dicom-anon` | DICOM file anonymization |
| `dicom-dump` | Hexadecimal dump with DICOM structure |
| `dicom-query` | Query DICOM servers (C-FIND) |
| `dicom-send` | Send DICOM files to servers (C-STORE) |
| `dicom-diff` | Compare DICOM files |
| `dicom-retrieve` | Retrieve from PACS (C-MOVE/C-GET) |
| `dicom-split` | Split multi-frame DICOM files |
| `dicom-merge` | Merge DICOM files into multi-frame |
| `dicom-json` | DICOM to/from JSON conversion |
| `dicom-xml` | DICOM to/from XML conversion |
| `dicom-pdf` | Encapsulated PDF operations |
| `dicom-image` | Image extraction and manipulation |
| `dicom-echo` | DICOM echo (C-ECHO) verification |
| `dicom-tags` | Tag dictionary lookup |
| `dicom-uid` | UID generation and lookup |
| `dicom-compress` | DICOM compression operations |
| `dicom-study` | Study-level operations |
| `dicom-report` | Structured report operations |
| `dicom-measure` | Measurement extraction |
| `dicom-viewer` | Terminal-based DICOM viewing |

Review the `main.swift` in any of these tools for the expected code structure and patterns.

## GUI Development Standards

When developing any graphical user interface (GUI) applications using DICOMKit (including demo apps, sample code, or example projects), adhere to the following standards for internationalization, localization, and accessibility.

### Internationalization and Localization

#### General Requirements

- **Externalize all user-facing strings**: Never hard-code user-facing text in source code
  - Use `NSLocalizedString()` or SwiftUI's `LocalizedStringKey` for all UI text
  - Create `.strings` or `.stringsdict` files for each supported language
  - Use descriptive keys that indicate context (e.g., `"study.count.format"` not just `"count"`)

- **Support pluralization**: Use `.stringsdict` files for proper plural handling
  - Handle zero, one, and multiple cases correctly
  - Different languages have different pluralization rules

- **Locale-aware formatting**: Use system formatters for all locale-specific content
  - Dates and times: Use `DateFormatter` with appropriate styles
  - Numbers: Use `NumberFormatter` for integers, decimals, percentages
  - Measurements: Use `MeasurementFormatter` for medical measurements (mm, cm, etc.)
  - File sizes: Use `ByteCountFormatter` for storage information

- **Context-aware translations**: Provide comments in localization files
  ```swift
  // Example:
  /* Medical imaging context: number of DICOM series in a study */
  "series.count" = "%d series";
  ```

#### Right-to-Left (RTL) Language Support

- **Layout mirroring**: Ensure all layouts automatically mirror for RTL languages
  - Use semantic layout constraints (`.leading`/`.trailing` not `.left`/`.right`)
  - SwiftUI: Use `.layoutDirection(.rightToLeft)` for testing
  - UIKit: Test with `semanticContentAttribute = .forceRightToLeft`

- **Text alignment**: Use natural text alignment
  - SwiftUI: Use `.multilineTextAlignment(.leading)` instead of `.multilineTextAlignment(.left)` for proper RTL support
  - UIKit: Use `NSTextAlignment.natural` not `.left`

- **Icon and image handling**: Consider RTL context for directional icons
  - Use SF Symbols with automatic mirroring where appropriate
  - Back/forward arrows should flip in RTL
  - Medical imaging controls (zoom, pan) may need custom handling

- **Testing RTL layouts**: Always test with Hebrew or Arabic language settings
  - Enable "RTL Pseudolanguage" in Xcode scheme for testing
  - Verify all UI elements mirror correctly
  - Check for text truncation or overflow issues

#### Supported Languages Priority

For medical imaging applications, prioritize:
1. **Primary**: English (US)
2. **High priority**: Spanish, French, German, Chinese (Simplified), Japanese
3. **Medical markets**: Korean, Portuguese (Brazil), Arabic, Hebrew
4. **Additional**: Italian, Dutch, Russian, Turkish

### Accessibility and Assistive Technologies

#### VoiceOver Support (Required for All GUI Elements)

- **Accessibility labels**: Provide clear, concise labels for all interactive elements
  ```swift
  // SwiftUI
  Button("Submit") { }
      .accessibilityLabel("Submit patient study")
  
  // UIKit
  button.accessibilityLabel = "Submit patient study"
  ```

- **Accessibility hints**: Provide context for complex actions
  ```swift
  .accessibilityHint("Uploads the selected DICOM files to the PACS server")
  ```

- **Accessibility values**: Expose current state for dynamic content
  ```swift
  slider.accessibilityValue = "\(Int(windowWidth)) Hounsfield units"
  ```

- **Accessibility traits**: Mark elements with appropriate traits
  ```swift
  .accessibilityAddTraits(.isButton)
  .accessibilityAddTraits(.isHeader)
  .accessibilityRemoveTraits(.isImage) // If image is purely decorative
  ```

- **Grouping related elements**: Use accessibility containers for complex layouts
  ```swift
  VStack {
      // Patient info elements
  }
  .accessibilityElement(children: .combine)
  .accessibilityLabel("Patient: John Doe, DOB: 1980-01-15")
  ```

#### VoiceOver Testing Requirements

- **Test all workflows**: Navigate through every screen using only VoiceOver
- **Verify reading order**: Ensure logical, top-to-bottom, left-to-right (or RTL) order
- **Check focus management**: Verify focus moves correctly after actions
- **Test custom controls**: Any custom UI components must have full VoiceOver support
- **Validate medical terminology**: Ensure proper pronunciation of medical terms

#### Additional Assistive Technologies

- **Dynamic Type support**: Respect user's text size preferences
  ```swift
  Text("Patient Name")
      .font(.body) // Uses Dynamic Type automatically
  ```
  - Test with largest accessibility text sizes
  - Ensure layouts don't break with large text
  - Provide horizontal scrolling if needed for large text

- **Reduce Motion**: Respect motion reduction preferences
  ```swift
  // SwiftUI
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  
  if !reduceMotion {
      // Perform animation
  }
  ```

- **Increase Contrast**: Support high contrast mode
  ```swift
  @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
  ```
  - Don't rely solely on color to convey information
  - Add patterns, icons, or text labels as alternatives

- **Switch Control**: Ensure full keyboard/switch control navigation
  - All actions must be reachable via keyboard shortcuts
  - Provide custom actions for complex gestures
  ```swift
  .accessibilityAction(named: "Adjust window width") {
      // Custom action
  }
  ```

#### Color Contrast and Visual Design

- **WCAG compliance**: Maintain WCAG AA contrast ratios
  - Minimum 4.5:1 for normal text (under 18pt or under 14pt bold)
  - Minimum 3:1 for large text (18pt and larger, or 14pt bold and larger)
- **Color blindness**: Don't use color alone to convey critical information
  - Add icons or labels to color-coded elements (e.g., measurement tools)
  - Test with Color Blindness simulator in Accessibility Inspector

- **Focus indicators**: Provide clear focus indicators for keyboard navigation
  ```swift
  .focusable(true)
  .focusEffectDisabled(false)
  ```

#### Medical Imaging Specific Accessibility

- **Image annotations**: Provide text alternatives for visual findings
  ```swift
  imageView.accessibilityLabel = "CT scan of chest, frame 45 of 120"
  imageView.accessibilityHint = "Shows lung tissue with contrast"
  ```

- **Measurement values**: Always expose measurement values to VoiceOver
  ```swift
  .accessibilityLabel("Distance measurement")
  .accessibilityValue("\(measurement.value) millimeters")
  ```

- **Window/Level controls**: Provide clear audio feedback for adjustments
  ```swift
  .accessibilityAdjustableAction { direction in
      // Adjust window/level based on direction
      // Announce new values
  }
  ```

#### Testing and Validation

- **Accessibility Audit Checklist**:
  - [ ] All interactive elements have accessibility labels
  - [ ] VoiceOver can navigate to all functionality
  - [ ] Dynamic Type works at all text sizes
  - [ ] High contrast mode is supported
  - [ ] Keyboard navigation works throughout the app
  - [ ] Color is not the only means of conveying information
  - [ ] All animations respect Reduce Motion setting
  - [ ] Focus indicators are visible and clear

- **Use Xcode Accessibility Inspector**: Run automated audits regularly
- **Test on physical devices**: Accessibility works differently on real hardware
- **User testing**: If possible, test with users who rely on assistive technologies

#### Documentation Requirements

For all GUI applications, document:
- Supported languages and localization status
- Accessibility features implemented
- Known accessibility limitations
- Keyboard shortcuts (for keyboard navigation)
- Testing procedures for accessibility compliance

### Resources

- [Apple Accessibility Programming Guide](https://developer.apple.com/documentation/accessibility)
- [Apple Internationalization and Localization Guide](https://developer.apple.com/documentation/xcode/localization)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Apple Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Testing Your App for Accessibility](https://developer.apple.com/documentation/accessibility/testing-your-app-for-accessibility)

---

## Demo Application Development (Post-Milestone 10)

**IMPORTANT**: After completing all Milestone 10 sub-milestones (10.1-10.15), the next priority is to develop comprehensive demo applications that showcase DICOMKit's capabilities.

### Demo Application Plan Reference

A comprehensive plan for demo application development is documented in:
**`DEMO_APPLICATION_PLAN.md`**

This plan includes:
- **DICOMViewer iOS App**: Mobile medical image viewing with gestures, measurements, and presentation state support
- **DICOMViewer macOS App**: Professional diagnostic workstation with PACS integration, MPR, and advanced features
- **DICOMViewer visionOS App**: Spatial computing medical imaging with 3D volume rendering and hand tracking
- **DICOMTools CLI Suite**: Command-line tools for automation (dicom-info, dicom-convert, dicom-anon, dicom-validate, etc.)
- **Sample Code Snippets**: Xcode Playgrounds demonstrating DICOMKit integration

### When to Start Demo Development

Demo application development should begin ONLY after:
- ✅ All Milestone 10 sub-milestones (10.1 through 10.13) are completed
- ✅ Comprehensive documentation is finalized (Milestone 10.13)
- ✅ Performance optimizations are complete (Milestone 10.12)
- ✅ All APIs are stable and tested

### Demo Development Workflow

When starting demo application work:

1. **Review the Plan**: 
   - Read `DEMO_APPLICATION_PLAN.md` in detail
   - Understand the architecture and technical requirements
   - Note the implementation phases and timelines

2. **Follow the Implementation Strategy**:
   - Phase 1 (Weeks 1-2): Foundation and iOS app core
   - Phase 2 (Weeks 3-5): Advanced features for iOS and macOS
   - Phase 3 (Weeks 6-7): visionOS and CLI tools
   - Phase 4 (Week 8): Polish, testing, and release preparation

3. **Maintain Quality Standards**:
   - Write unit tests for ViewModels (80%+ coverage)
   - Create integration tests for PACS connectivity
   - Build UI tests for critical user flows
   - Profile performance and optimize as needed
   - Follow SwiftUI best practices

4. **Document Progress**:
   - Update MILESTONES.md as demo features are completed
   - Create user documentation and guides
   - Record demo videos/screenshots for App Store
   - Write developer documentation for integration

5. **Testing and Validation**:
   - Test on physical devices (iOS, macOS, visionOS)
   - Validate against real PACS systems
   - **Perform comprehensive accessibility audit** (see "GUI Development Standards" section):
     - VoiceOver navigation testing
     - Dynamic Type at all sizes
     - Keyboard/Switch Control navigation
     - High contrast and color blindness testing
     - Reduce Motion compliance
   - **Validate internationalization**:
     - Test with multiple languages
     - Verify RTL layout mirroring (Hebrew/Arabic)
     - Check locale-specific formatting
   - Memory and performance profiling
   - App Store submission preparation

### Demo Application Guidelines

**Code Organization**:
- Create separate Xcode workspace or projects for demo apps
- Share common code via DICOMKit framework
- Use Swift Package Manager for dependencies
- Follow Apple's Human Interface Guidelines for each platform

**UI/UX Standards**:
- SwiftUI-first approach for modern, declarative UI
- Support Dark Mode and accessibility features
- **Follow all guidelines in "GUI Development Standards" section above**:
  - Full internationalization and localization support
  - RTL language compatibility
  - Comprehensive VoiceOver and assistive technology support
  - WCAG accessibility compliance
- Implement proper error handling and user feedback
- Use haptic feedback and animations appropriately
- Ensure responsive layouts for all device sizes

**Performance Requirements**:
- 60fps scrolling for multi-frame series
- <200MB memory usage on iOS
- <100ms UI interaction latency
- Smooth gesture recognition
- Efficient thumbnail generation

**Security and Privacy**:
- Handle PHI (Protected Health Information) appropriately
- Implement proper anonymization in export features
- Follow HIPAA guidelines where applicable
- No network logging of sensitive data
- Secure storage with encryption for saved files

### Quick Reference: Demo Apps

| Application | Platform | Primary Purpose | Complexity | Timeline |
|------------|----------|-----------------|------------|----------|
| DICOMViewer iOS | iOS 17+ | Mobile viewing, measurements | High | 3-4 weeks |
| DICOMViewer macOS | macOS 14+ | Diagnostic workstation, PACS | Very High | 4-5 weeks |
| DICOMViewer visionOS | visionOS 1+ | Spatial 3D imaging | Very High | 3-4 weeks |
| DICOMTools CLI | macOS/Linux | Automation, scripting | Medium | 2-3 weeks |
| Sample Playgrounds | Xcode | Learning, examples | Low | 1 week |

### Integration with Milestones

Demo application work corresponds to:
- **Milestone 10.14**: Example Applications (v1.0.14)
- **Milestone 10.15**: Production Release Preparation (v1.0.15)

Track progress in the Milestone 10 Summary table in MILESTONES.md.

### Support Resources

For questions during demo development:
- Reference `DEMO_APPLICATION_PLAN.md` for detailed specifications
- Review existing Examples/ directory for SR examples
- Consult DICOMKit README.md for API usage
- Check DICOM standard documentation (PS3.3, PS3.4, etc.)
- Review Apple's platform documentation (SwiftUI, RealityKit, etc.)

---

**Remember**: Demo applications are the showcase for DICOMKit. They should be polished, well-documented, and demonstrate best practices for medical imaging app development on Apple platforms.
