# DICOMKit v2.2.9

Patch release resolving SwiftPM consumer build-hygiene warnings and hardening
immutable release publication.

## SwiftPM build hygiene

- Excluded the documentation-only `README.md` files from the `dicom-3d` and
  `dicom-j2k` executable targets. Consumer package planning no longer emits the
  two unhandled-file warnings reported by RasterOneImage V2-029.
- Excluded the intentionally inactive complements of the explicitly sourced
  `DICOMKitTests` and `DICOMViewerTests` targets. This removes two additional
  planning warnings covering 102 test files without changing which tests compile.
- No decoder, runtime, product API, ABI, resource, or command behavior changed.

## Release infrastructure

- Release builds now compile with warnings as errors and reject any remaining
  SwiftPM or compiler warning in captured build output. Release tests also fail
  if an unhandled-file package-planning warning recurs.
- The release artifact matrix now matches all 36 enabled CLI products, including
  `dicom-jpip` and `dicom-j2k`.
- Manually dispatched release jobs now check out the requested tag in every job,
  preventing artifacts from a different ref from being locked into a release.
- GitHub releases are assembled as drafts before publication so their tags and
  assets can be locked by GitHub immutable releases.

## Verification

- `swift package dump-package`: passed.
- `swift build -c release --product dicom-3d -Xswiftc -warnings-as-errors`:
  passed with zero warnings.
- `swift build -c release --product dicom-j2k -Xswiftc -warnings-as-errors`:
  passed with zero warnings.
- `swift test --filter dicom_j2kTests`: 53 tests passed with zero warnings.
- `swift build -Xswiftc -warnings-as-errors`: passed with zero warnings.
- `swift build -c release -Xswiftc -warnings-as-errors`: passed with zero warnings.
- `PARITY_STRICT=1 PARITY_COVERAGE_MIN=19.8 swift test --filter StudioParityTests`:
  160/160 scenarios matched with 26.5% output-flag coverage and zero warnings.

Validation used Swift 6.3.3 on macOS. The repository release workflow repeats
the release build and test gates with Swift 6.2 or newer before publishing
artifacts.
