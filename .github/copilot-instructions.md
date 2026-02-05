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
   - Perform accessibility audit
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
