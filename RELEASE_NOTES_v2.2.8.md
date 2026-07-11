# DICOMKit v2.2.8

Patch release hardening DIMSE security propagation and updating the JPEG 2000
codec dependency.

## Security and networking

- Preserved the complete TLS policy and user identity across every
  `DICOMClient` DIMSE route, association setup, connection pooling, query,
  retrieve, verification, and storage operation.
- Tightened cancellation and timeout handling so cancelled work cannot submit a
  late credential-bearing association, pending transports are aborted, and
  abandoned batch C-STORE producers terminate promptly.
- Redacted credential-bearing DIMSE values from descriptions and recursive
  reflection while retaining useful non-secret diagnostics.
- Added focused cross-platform and security-propagation regression coverage.

## JPEG 2000 codecs

- Updated the J2KSwift dependency floor and tracked resolution to v11.0.2
  (`b1949084eeedaafb40bff8f1745bbab19e4bc36d`).
- Adopted upstream decoder fixes that stop truncated quality-layer decoding at
  the exact coding-pass boundary and limit scratch clearing to the active
  code-block region.
- DICOMKit public APIs and J2KSwift codestream structure remain unchanged.

## Build infrastructure

- CI and release workflows now select an installed Swift 6.2 toolchain instead
  of assuming a single Xcode installation name.
- Removed the optional DICOMStudio OpenJPEG comparison wrapper from
  `DICOMCore`'s default dependency graph. Standalone macOS consumers no longer
  require Homebrew, an absolute `libopenjp2.a` path, or an arm64-only build.
- Production JPEG 2000 support remains provided by J2KSwift.

## Validation

- `J2KSwiftCodecTests`: 20/20 passed.
- `DICOMClientSecurityPropagationTests`: 17/17 passed.
- `swift build -c release`: passed.
- The tag-triggered release workflow performs the repository's full test, CLI,
  and documentation release gates before publishing assets.
