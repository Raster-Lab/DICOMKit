# dicom-j2k

Purpose-built CLI for JPEG 2000 / HTJ2K codestream operations on DICOM files.
Part of DICOMKit, powered by J2KSwift v11.0.2.

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `info <file>` | Show J2K/HTJ2K codestream metadata (tile grid, components, progression order, layers) |
| `validate <file>` | ISO/IEC 15444-4 conformance check |
| `transcode <in>` | J2K ↔ HTJ2K safe lossless decode/re-encode |
| `reduce <in>` | Re-encode at lower resolution or quality layer count |
| `roi <in>` | Extract an ROI frame from a specific tile/region |
| `benchmark <file>` | Decode speed across all registered backends |
| `compare <a> <b>` | PSNR / SSIM / MSE between two DICOM images |
| `completions <shell>` | Generate shell completions (bash/zsh/fish) |

## Supported Transfer Syntaxes

| UID | Name |
|-----|------|
| `1.2.840.10008.1.2.4.90` | JPEG 2000 Lossless |
| `1.2.840.10008.1.2.4.91` | JPEG 2000 (Lossy) |
| `1.2.840.10008.1.2.4.92` | JPEG 2000 Part 2 Lossless (MC) |
| `1.2.840.10008.1.2.4.93` | JPEG 2000 Part 2 (MC, Lossy) |
| `1.2.840.10008.1.2.4.201` | HTJ2K Lossless |
| `1.2.840.10008.1.2.4.202` | HTJ2K RPCL Lossless |
| `1.2.840.10008.1.2.4.203` | HTJ2K (Lossy) |

## Examples

```bash
# Inspect a JPEG 2000 codestream
dicom-j2k info ct.dcm

# Inspect and output JSON
dicom-j2k info ct.dcm --json

# Validate HTJ2K conformance
dicom-j2k validate scan.htj2k.dcm

# Safely transcode J2K → HTJ2K
dicom-j2k transcode j2k.dcm --output htj2k.dcm --target htj2k-lossless

# Transcode HTJ2K → J2K
dicom-j2k transcode htj2k.dcm --output j2k.dcm --target j2k-lossless

# Re-encode at lower quality (3 resolution levels, 4 quality layers)
dicom-j2k reduce input.dcm --output small.dcm --levels 3 --layers 4

# Extract ROI from frame 0, region x=0,y=0,w=256,h=256
dicom-j2k roi input.dcm --output roi.dcm --frame 0 --region 0,0,256,256

# Benchmark all backends on a real CT file
dicom-j2k benchmark ct.dcm

# Benchmark with custom iterations
dicom-j2k benchmark ct.dcm --iterations 20 --backends all

# Compute PSNR/SSIM between original and transcoded
dicom-j2k compare ref.dcm test.dcm

# Install zsh completions
dicom-j2k completions zsh > ~/.zsh/completions/_dicom-j2k
```

## Safe Transcoding

The `transcode` subcommand assembles complete DICOM frames, decodes them losslessly, and
re-encodes them in the target syntax. Direct `J2KTranscoder` coefficient conversion is
temporarily quarantined because J2KSwift 11.0.2 does not preserve decoded pixels through
that path. See the [J2KSwift bug report](../../J2KSWIFT_BUG_REPORT.md).

## Notes

- `--reduce` uses post-decode nearest-neighbour downscale. Native codec-level resolution
  reduction (`J2KDecoder.decodeResolution`) is not yet available upstream in J2KSwift;
  tracked in `J2KSWIFT_BUG_REPORT.md`.
- HTJ2K Lossy (`.203`) is partially validated; some entropy-coder edge cases may return
  errors. Use lossless (`.201`) for archival.

## Tests

Unit tests live in `Tests/dicom-j2kTests/DicomJ2KTests.swift`.

```bash
swift test --filter dicom-j2kTests
```
