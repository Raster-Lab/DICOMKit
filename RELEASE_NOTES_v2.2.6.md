# DICOMKit v2.2.6

Patch release updating the JPEG 2000 dependency used by DICOM pixel decoding.

## Changed

- Updated the J2KSwift package requirement from v11.0.0 to v11.0.1.
- Verified SwiftPM resolution against the released v11.0.1 revision (the
  repository intentionally ignores its generated `Package.resolved`).
- Updated documentation to identify J2KSwift v11.0.1 as the supported codec
  baseline.

## Compatibility

- DICOMKit public APIs are unchanged.
- DICOM transfer syntax handling is unchanged.
- Decoded pixels remain bit-identical; the upstream change only removes
  redundant EBCOT decoder scratch state and adds a zero-pass fast path.

## Validation

- `swift build -c release`
- Focused DICOM/J2K integration coverage: 16 codec, registry, transfer-syntax,
  and round-trip tests passed.
- The full suite was attempted; existing fixture-dependent benchmarks require
  the repository's optional `LocalDatasets` corpus and are not part of this
  dependency-only patch gate.
