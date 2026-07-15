# DICOMKit and J2KSwift Optimization Status

Date: 2026-07-15

Status: The first P0 DICOMKit safety optimization is complete. The wider optimization work is still ongoing.

## Branch and commits

- Branch: `codex/dicom-j2k-optimization`
- Base commit: `c40f963ee46c28e0d3cbb2f8e99a24614f47cd86`
- Implementation commit: `0e2135bd0e034a0c07abecfc562ac85ab31e573a`

## Completed

- Removed the unsafe automatic J2K-to-HTJ2K and HTJ2K-to-J2K coefficient path.
- Made the two direct coefficient-transcoding APIs fail clearly instead of returning damaged pixels.
- Added strict complete-frame assembly for encapsulated Pixel Data.
- Made malformed or ambiguous Basic Offset Table data fail closed.
- Updated `dicom-j2k` to use complete-frame extraction.
- Removed stale Extended Offset Table elements after decompression.
- Added cross-platform exact-pixel tests for 8-bit and signed 16-bit lossless conversions.
- Corrected documentation that previously described the unsafe path as bit-exact.

## Verification

- Focused safety tests: 18 tests in 4 suites passed, 0 failures.
- JPEG XL recompression regression tests: 4 tests passed, 0 failures.
- Production warnings-as-errors build: passed in 168.86 seconds.
- `swift package describe`: passed with no SwiftPM planning warnings.
- Final diff whitespace check: passed.
- Independent read-only review: no blocking issue found.

## Remaining limits

- J2KSwift 11.0.2 coefficient transcoding still corrupts pixels. No J2KSwift source fix was made in this work group.
- Multi-frame data that has only an Extended Offset Table, with multiple fragments per frame, currently fails closed.
- A full test warnings-as-errors build is blocked by unrelated warnings that already exist in older tests. The production warnings-as-errors build passes.
- External-decoder interoperability and a new real-modality image corpus were not tested in this work group.

## Next work group

In J2KSwift, add a red command-line test proving that `j2k compare --bit-exact` returns a nonzero exit code when images differ. Then fix the exit status and run the focused CLI tests. The larger coefficient-transcoder repair remains P0 work after that small fail-loud contract.
