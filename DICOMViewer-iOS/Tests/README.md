# DICOMViewer iOS - Tests

This directory contains unit tests for the DICOMViewer iOS application.

## Test Files

### MeasurementTests.swift (377 lines)
Tests for measurement calculation logic:

**Test Coverage:**
- ✅ Length measurements (pixel and mm calculations)
- ✅ Angle measurements (three-point angles)
- ✅ Ellipse ROI area calculations
- ✅ Rectangle ROI area calculations
- ✅ Freehand ROI area calculations (shoelace formula)
- ✅ Pixel spacing handling
- ✅ Measurement point distance calculations
- ✅ Edge cases (nil pixel spacing, invalid points, etc.)

**Test Count:** 15+ unit tests

### PresentationStateTests.swift (340 lines)
Tests for GSPS (Grayscale Softcopy Presentation State) functionality:

**Test Coverage:**
- ✅ GSPS file parsing
- ✅ Window/level extraction from GSPS
- ✅ Annotation rendering (graphic objects)
- ✅ Text annotation handling
- ✅ Shutter parsing (rectangular, circular, polygonal)
- ✅ Spatial transformation extraction
- ✅ Layer ordering and colors
- ✅ Display area calculations
- ✅ Integration with real GSPS files

**Test Count:** 20+ unit tests

## Running Tests

### In Xcode

1. Open the project in Xcode
2. Select the test target from the scheme selector
3. Press `⌘U` to run all tests
4. Or use **Product → Test**

Individual test methods can be run by:
- Clicking the diamond icon next to the test method in the gutter
- Right-clicking the test method → Run "[TestName]"

### From Command Line

```bash
# Navigate to project directory
cd /path/to/DICOMViewer.xcodeproj/..

# Run all tests
xcodebuild test \
  -scheme DICOMViewer \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test \
  -scheme DICOMViewer \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DICOMViewerTests/MeasurementTests
```

## Test Requirements

- iOS 17.0+ Simulator or device
- DICOMKit framework (included as dependency)
- XCTest framework (included with Xcode)

## Expected Results

When all tests pass, you should see:

```
Test Suite 'All tests' passed at [timestamp]
Executed 35 tests, with 0 failures (0 unexpected) in 2.145 seconds
```

## Coverage Goals

The test suite aims for:
- **80%+ code coverage** for Models
- **70%+ code coverage** for Services (file I/O is harder to test)
- **60%+ code coverage** for ViewModels (UI interaction dependent)
- **Comprehensive edge case testing** for calculations

## Adding New Tests

When adding new features, follow this pattern:

```swift
import XCTest
@testable import DICOMViewer

final class MyNewFeatureTests: XCTestCase {
    
    func testFeatureName_whenCondition_thenExpectedResult() {
        // Arrange
        let input = createTestInput()
        
        // Act
        let result = performAction(input)
        
        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Naming Convention
- Test method names: `test[MethodName]_when[Condition]_then[ExpectedResult]`
- Be descriptive: `testLengthCalculation_withPixelSpacing_returnsCorrectMM()`

### Test Structure
- **Arrange:** Set up test data
- **Act:** Execute the code under test
- **Assert:** Verify the expected outcome

## Test Data

Some tests require sample DICOM files. These are typically:
- Located in test bundle resources
- Generated programmatically in tests
- Mocked using test doubles

For GSPS tests, sample presentation state objects are created inline or loaded from test resources.

## Common Test Failures

### "Module 'DICOMKit' not found"
**Solution:** Ensure DICOMKit is added to the test target's dependencies

### "Data file not found"
**Solution:** Add test resources to the test target's "Copy Bundle Resources" build phase

### "Test crashes on launch"
**Solution:** Check for force unwrapping (`!`) in test code; use optional binding instead

## Performance Tests

Some tests include performance measurements:

```swift
func testThumbnailGeneration_performance() {
    measure {
        // Code to benchmark
        generateThumbnail(for: largeImage)
    }
}
```

Run with **Product → Perform Action → Run Without Building** for accurate results.

## Integration Tests

Future integration tests will cover:
- File import workflow end-to-end
- Image rendering pipeline
- SwiftData persistence
- GSPS application to images

These will be added in separate test files as needed.

## Continuous Integration

Tests can be run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: |
    xcodebuild test \
      -scheme DICOMViewer \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -enableCodeCoverage YES
```

## Resources

- **XCTest Documentation:** [developer.apple.com/documentation/xctest](https://developer.apple.com/documentation/xctest)
- **Testing Guide:** [developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode)
- **Unit Testing Best Practices:** [developer.apple.com/videos/play/wwdc2020/10147/](https://developer.apple.com/videos/play/wwdc2020/10147/)

## Contributing

When contributing code:
1. Write tests for new features
2. Ensure existing tests still pass
3. Aim for 80%+ code coverage on new code
4. Follow existing test patterns and naming conventions

---

**Total Test Lines:** 717 lines  
**Test Coverage:** 35+ unit tests  
**Frameworks:** XCTest, DICOMKit
