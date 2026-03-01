# DICOMKit Integration Templates

This directory contains starter templates and examples for integrating DICOMKit into various types of applications.

## Available Templates

### 1. SwiftUI Viewer Template

**File**: `SwiftUI-Viewer-Template.md`

A complete template for building a DICOM viewer app using SwiftUI. Demonstrates:
- File import and DICOM parsing
- Patient metadata display
- Medical image rendering
- Cross-platform support (iOS/macOS)

**Best for**: 
- Building a simple DICOM viewer
- Learning DICOMKit basics
- Creating prototypes quickly

**Platforms**: iOS 17+, macOS 14+

---

## Using These Templates

1. **Read the template** - Each template includes setup instructions
2. **Copy the code** - Start with the provided code as a foundation
3. **Customize** - Modify to fit your specific needs
4. **Extend** - Add features like measurements, annotations, etc.

## Template Categories

### Viewer Applications
Templates for building DICOM viewing applications

- ✅ SwiftUI Viewer (iOS/macOS)
- 🚧 UIKit Viewer (iOS) - Coming soon
- 🚧 AppKit Viewer (macOS) - Coming soon

### Network Applications
Templates for PACS and DICOMweb integration

- 🚧 PACS Query/Retrieve Client - Coming soon
- 🚧 DICOMweb Client - Coming soon
- 🚧 DICOM Storage SCP - Coming soon

### Command-Line Tools
Templates for building CLI utilities

- 🚧 Custom CLI Tool Template - Coming soon
- 🚧 Batch Processing Script - Coming soon

### Workflow Applications
Templates for medical imaging workflows

- 🚧 Worklist Client - Coming soon
- 🚧 MPPS Reporter - Coming soon

## Contributing Templates

Have a useful integration pattern? Consider contributing a template!

1. Create a markdown file with:
   - Clear setup instructions
   - Complete, working code
   - Feature explanations
   - Best practices

2. Submit a pull request to the DICOMKit repository

## Example Applications

For complete, production-ready applications, see the CLI tools and example code.

## Resources

- **Installation Guide**: [INSTALLATION.md](../../INSTALLATION.md)
- **Distribution Guide**: [DISTRIBUTION.md](../../DISTRIBUTION.md)
- **DICOMKit Documentation**: [Documentation/](../../Documentation/)
- **CLI Tools**: 29 command-line utilities in [Sources/](../../Sources/)

## Support

- GitHub Issues: https://github.com/Raster-Lab/DICOMKit/issues
- Discussions: https://github.com/Raster-Lab/DICOMKit/discussions

---

**Note**: Templates are provided for educational and development purposes. For production medical imaging applications, ensure compliance with relevant regulations (FDA, CE marking, etc.) and implement appropriate security, privacy, and validation measures.
