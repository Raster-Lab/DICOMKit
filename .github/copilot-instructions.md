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
