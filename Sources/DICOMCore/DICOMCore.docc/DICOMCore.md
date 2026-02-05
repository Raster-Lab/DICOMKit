# ``DICOMCore``

Core types and utilities for DICOM data representation and manipulation.

## Overview

DICOMCore provides the fundamental building blocks for working with DICOM data. It includes data element types, value representations (VR), tags, and low-level parsing utilities.

### Key Components

- **Data Elements**: Basic unit of DICOM data containing a tag, VR, and value
- **Tags**: DICOM attribute identifiers using group and element numbers
- **Value Representations**: Type descriptors for data element values
- **Transfer Syntaxes**: Encoding rules for DICOM data
- **Character Sets**: International text encoding support

## Topics

### Data Elements

- ``DataElement``
- ``Tag``
- ``VR``

### Value Types

- ``DICOMDate``
- ``DICOMTime``
- ``DICOMDateTime``
- ``DICOMPersonName``
- ``DICOMUniqueIdentifier``
- ``DICOMAgeString``
- ``DICOMDecimalString``
- ``DICOMIntegerString``
- ``DICOMCodeString``
- ``DICOMApplicationEntity``

### Pixel Data

- ``PixelData``
- ``PixelDataDescriptor``
- ``PixelDataError``
- ``EncapsulatedPixelData``
- ``PhotometricInterpretation``
- ``PaletteColorLUT``

### Image Compression

- ``ImageCodec``
- ``NativeJPEGCodec``
- ``NativeJPEG2000Codec``
- ``RLECodec``
- ``TransferSyntaxConverter``

### Transfer Syntax

- ``TransferSyntax``
- ``ByteOrder``

### Character Sets

- ``CharacterSetHandler``

### File Writing

- ``DICOMWriter``

### Sequences

- ``SequenceItem``

### UID Generation

- ``UIDGenerator``

### Window/Level

- ``WindowSettings``

### Private Tags

- ``PrivateTagAllocator``
- ``PrivateCreator``
- ``PrivateDataElement``
- ``PrivateTagDictionary``

### Structured Reporting

- ``SRTemplate``
- ``SRConcept``
- ``SRRelationship``
