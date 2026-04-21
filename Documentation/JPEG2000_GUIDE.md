# JPEG 2000 Guide for DICOMKit

This guide covers JPEG 2000 (J2K), High-Throughput JPEG 2000 (HTJ2K), JP3D volumetric encoding, and JPIP streaming as implemented in DICOMKit via J2KSwift v3.2.0.

## Table of Contents

1. [Overview](#overview)
2. [Supported Transfer Syntaxes](#supported-transfer-syntaxes)
3. [Quick Start](#quick-start)
4. [HTJ2K — High-Throughput JPEG 2000](#htj2k--high-throughput-jpeg-2000)
5. [JP3D — Volumetric Encoding](#jp3d--volumetric-encoding)
6. [JPIP — Progressive Streaming](#jpip--progressive-streaming)
7. [Hardware Acceleration](#hardware-acceleration)
8. [CLI Tools](#cli-tools)
9. [Benchmark Tables](#benchmark-tables)
10. [Troubleshooting](#troubleshooting)
11. [Known Limitations](#known-limitations)

---

## Overview

DICOMKit uses **J2KSwift v3.2.0** as its primary JPEG 2000 codec stack, replacing Apple ImageIO as the default path. J2KSwift is a pure-Swift implementation that works on all supported platforms (macOS, iOS, visionOS, and Linux), with optional GPU acceleration on Apple hardware.

### Codec Stack

```
CodecRegistry
├── MetalJ2KCodec        (Apple GPU, priority 0)
├── AcceleratedJ2KCodec  (Apple SIMD, priority 1)
├── J2KSwiftCodec        (scalar, all platforms, priority 3)
└── NativeJPEG2000Codec  (Apple ImageIO, deprecated fallback)
```

The best available backend is selected automatically at startup by `CodecBackendProbe`. Override with `CodecBackendPreference` when needed.

---

## Supported Transfer Syntaxes

| Transfer Syntax | UID | Notes |
|-----------------|-----|-------|
| JPEG 2000 Lossless | `1.2.840.10008.1.2.4.90` | ISO/IEC 15444-1 |
| JPEG 2000 Lossy | `1.2.840.10008.1.2.4.91` | ISO/IEC 15444-1 |
| JPEG 2000 Part 2 Lossless | `1.2.840.10008.1.2.4.92` | ISO/IEC 15444-2 (MCT, arbitrary kernels) |
| JPEG 2000 Part 2 Lossy | `1.2.840.10008.1.2.4.93` | ISO/IEC 15444-2 |
| JPIP Referenced | `1.2.840.10008.1.2.4.94` | Streaming, tile-on-demand |
| JPIP Referenced Deflate | `1.2.840.10008.1.2.4.95` | JPIP + zlib compression |
| HTJ2K Lossless | `1.2.840.10008.1.2.4.201` | ISO/IEC 15444-15, DICOM Sup 211 |
| HTJ2K RPCL Lossless | `1.2.840.10008.1.2.4.202` | HTJ2K with RPCL progression order |
| HTJ2K Lossy | `1.2.840.10008.1.2.4.203` | HTJ2K lossy (partially validated) |

JP3D volumetric encoding uses a **private experimental SOP** (`1.2.826.0.1.3680043.10.511.10`) — not suitable for standard interchange.

---

## Quick Start

### Decode a JPEG 2000 DICOM file

```swift
import DICOMKit

let file = try DICOMFile.read(from: url)
let pixels = try file.pixelData()   // decoded automatically via CodecRegistry
let image = try pixels.cgImage()    // Apple platforms
```

### Encode with JPEG 2000 Lossless

```swift
let config = CompressionConfiguration(
    transferSyntax: .jpeg2000Lossless,
    lossless: true
)
let compressed = try dicomFile.compress(configuration: config)
try compressed.write(to: outputURL)
```

### Encode with HTJ2K Lossless

```swift
let config = CompressionConfiguration(
    transferSyntax: .htj2kLossless,
    lossless: true
)
let compressed = try dicomFile.compress(configuration: config)
```

### Transcode J2K → HTJ2K (fast path, no pixel decode)

```swift
let transcoder = TransferSyntaxConverter()
let htj2k = try await transcoder.transcodeFastPath(
    file,
    to: .htj2kLossless
)
```

The fast path uses `J2KTranscoder` coefficient re-encoding — pixel data is never decoded to RAM, giving 5–10× throughput over full decode + re-encode.

---

## HTJ2K — High-Throughput JPEG 2000

HTJ2K (ISO/IEC 15444-15) is a backward-compatible extension of JPEG 2000 that achieves near-lossless throughput at significantly higher speed by using the block-adaptive separable wavelet (FBCOT) entropy coder in HTJ2K mode.

### Performance

Measured on a real MR instance (macOS arm64, J2KSwift 3.2.0):

| Codec | Decode time | Speedup |
|-------|-------------|---------|
| JPEG 2000 Lossless | 4 809 ms | 1× |
| HTJ2K Lossless | 886 ms | **5.4×** |

### RPCL Progression

Transfer syntax `.202` uses RPCL (Resolution-Position-Component-Layer) progression order, which is ideal for progressive rendering — lower resolution levels arrive first.

```swift
let config = CompressionConfiguration(
    transferSyntax: .htj2kRPCLLossless,
    lossless: true,
    progressionOrder: .rpcl
)
```

### DICOMweb

HTJ2K is advertised in `Accept` headers as `image/jph` (`.201`) and `image/jphc` (`.202`):

```swift
let client = DICOMwebClient(baseURL: serverURL)
// Prefers HTJ2K if server supports it:
let frames = try await client.retrieveFrames(
    studyUID: uid,
    preferredTransferSyntax: .htj2kLossless
)
```

---

## JP3D — Volumetric Encoding

JP3D (ISO/IEC 15444-10) extends JPEG 2000 to three-dimensional wavelet transforms, enabling efficient encoding of volumetric CT/MR/PET datasets as a single codestream.

> **Experimental**: JP3D in DICOM has no standard transfer syntax UID. DICOMKit exposes it via a private SOP for round-trip testing. Do not use in production interchange.

### Encode a multi-frame series as JP3D

```swift
import DICOMKit

// Load a series of single-frame DICOM files
let slices: [DICOMFile] = try series.map { try DICOMFile.read(from: $0) }

// Build a JP3D volume document
let bridge = JP3DVolumeBridge()
let volume = try bridge.makeVolume(from: slices)

let codec = JP3DCodec()
let document = try await codec.encodeVolume(
    volume,
    mode: .losslessHTJ2K   // or .lossless, .lossy(psnr: 60), .lossyHTJ2K(psnr: 60)
)
try document.write(to: outputURL)
```

### Decode a JP3D document back to slices

```swift
let document = try JP3DVolumeDocument(contentsOf: jp3dURL)
let slices = try document.decode(from: document.data)
```

### Viewer-time virtual decode

```swift
// Open any volume source — multi-frame DICOM or JP3D encapsulation
let volume = try await DICOMFile.openVolume(from: directoryURL)

// Access individual slices
let axialSlice = try volume.slice(at: 64)
let voxelValue = volume.voxel(x: 128, y: 128, z: 64)
```

---

## JPIP — Progressive Streaming

JPIP (DICOM transfer syntaxes `.94` / `.95`) enables tile-and-quality-layer streaming from a JPIP server. Large CT, MR, or whole-slide imaging datasets are delivered progressively — lower quality arrives first and improves in place.

### 2D streaming

```swift
let client = DICOMJPIPClient(serverURL: jpipServerURL)

// Fetch a single frame progressively (4 quality layers)
for await update in client.stream(instanceUID: sopUID, quality: .layers(4)) {
    renderPreview(update.image)
}
```

### 3D progressive volume

```swift
let volume = try await DICOMFile.openVolumeProgressively(
    serverURL: jpipServerURL,
    sliceJPIPURIs: jpipURIs,
    qualityLayers: 6
)

for await update in volume {
    updateDisplay(update)  // DICOMVolumeProgressiveUpdate
}
```

### CLI

```bash
# Fetch a JPIP URL and save as DICOM
dicom-jpip fetch jpip://server/wado?studyUID=... -o study.dcm

# Generate a JPIP URI for a local DICOM file
dicom-jpip uri scan.dcm

# Start a local JPIP server
dicom-jpip serve --port 8080 ./studies/

# Show JPIP capabilities of a server
dicom-jpip info jpip://server/
```

---

## Hardware Acceleration

### Checking the active backend

```swift
let backend = CodecRegistry.shared.activeBackend
// .metal, .accelerate, or .scalar

let description = CodecRegistry.shared.backendDescription
// "Metal (Apple M-series GPU)"
```

### Listing available backends

```bash
dicom-compress backends
# ✅ metal      — J2KMetal (Apple GPU)
# ✅ accelerate — J2KAccelerate (ARM Neon / SIMD)
# ✅ scalar     — J2KCodec (portable fallback)
```

### Forcing a specific backend

```bash
dicom-compress compress scan.dcm -o scan_htj2k.dcm \
  --codec htj2k-lossless \
  --backend accelerate
```

---

## CLI Tools

### `dicom-j2k`

Purpose-built for JPEG 2000 codestream operations on DICOM files.

| Subcommand | Description |
|------------|-------------|
| `info <file>` | Show J2K/HTJ2K codestream metadata |
| `validate <file>` | ISO/IEC 15444-4 conformance check |
| `transcode <in> <out>` | J2K ↔ HTJ2K bit-exact transcode |
| `reduce <in> <out>` | Re-encode at lower resolution/quality |
| `roi <in> <out>` | Extract an ROI frame |
| `benchmark <file>` | Decode speed across all backends |
| `compare <a> <b>` | PSNR / SSIM / MSE between two images |
| `completions <shell>` | Shell completions (bash/zsh/fish) |

```bash
# Inspect a JPEG 2000 codestream
dicom-j2k info ct.dcm

# Validate HTJ2K conformance
dicom-j2k validate scan.htj2k.dcm

# Transcode J2K → HTJ2K (fast path)
dicom-j2k transcode j2k.dcm htj2k.dcm --target htj2k-lossless

# Benchmark all backends
dicom-j2k benchmark ct.dcm
```

### `dicom-compress`

```bash
# Compress with JPEG 2000 Lossless
dicom-compress compress ct.dcm -o ct.j2k.dcm --codec j2k-lossless

# Compress with HTJ2K Lossless
dicom-compress compress ct.dcm -o ct.htj2k.dcm --codec htj2k-lossless

# Transcode to HTJ2K using fast path
dicom-compress transcode ct.j2k.dcm --to htj2k -o ct.htj2k.dcm

# JP3D volumetric encode
dicom-3d encode-volume ./series/ -o volume.jp3d.dcm
```

---

## Benchmark Tables

### Decode time by codec (macOS arm64, Apple M-series)

| Transfer Syntax | Backend | Decode time (512×512 CT) |
|-----------------|---------|--------------------------|
| JPEG 2000 Lossless | scalar | ~4 800 ms |
| JPEG 2000 Lossless | accelerate | ~1 200 ms |
| JPEG 2000 Lossless | metal | ~480 ms |
| HTJ2K Lossless | scalar | ~886 ms |
| HTJ2K Lossless | accelerate | ~220 ms |
| HTJ2K Lossless | metal | ~90 ms |

> Measured with `swift test --filter J2KSwiftCodecBenchmarkTests` on `instance_003317.dcm` (real MR study, April 2026).

### Encode time by codec (macOS arm64)

| Transfer Syntax | Lossless | Encode time (512×512 CT) |
|-----------------|----------|--------------------------|
| JPEG 2000 | yes | ~5 200 ms (scalar) |
| HTJ2K | yes | ~950 ms (scalar) |
| HTJ2K | no (PSNR 60 dB) | ~400 ms (scalar) |

### Fast-path transcoding (no pixel decode)

| Operation | Time (128-slice CT) |
|-----------|---------------------|
| J2K → HTJ2K coefficient transcode | < 8 s |
| HTJ2K → J2K coefficient transcode | < 10 s |

---

## Troubleshooting

### Decoder not found for transfer syntax

**Symptom**: `DICOMError.unsupportedTransferSyntax`

**Cause**: The codec for the UID was not registered, or the J2KSwift module was not linked.

**Fix**:
```swift
// Verify the codec is registered
let codecs = CodecRegistry.shared.codecs(for: .htj2kLossless)
print(codecs.map(\.name))  // should include "HTJ2KCodec"

// Ensure DICOMCore target links J2KCodec and J2KFileFormat
```

### Near-black output after JPEG 2000 conversion

**Symptom**: Rendered image is extremely dark after J2K encode/decode.

**Cause**: 16-bit pixel data was not normalised back to `BitsStored` range after ImageIO decode.

**Fix**: Use J2KSwiftCodec (the default) rather than `NativeJPEG2000Codec`. The J2KSwift path preserves bit depth metadata correctly.

### HTJ2K decode returns errors on lossy files

**Symptom**: `J2KDecodingError` for transfer syntax `.203`.

**Cause**: HTJ2K lossy (`.203`) is partially validated. Some edge cases in the entropy coder produce decoding errors.

**Workaround**: Transcode to HTJ2K Lossless (`.201`) before archiving if lossless fidelity is required.

### `--reduce` flag does not reduce resolution at the codec level

**Symptom**: `dicom-viewer --reduce 2` returns the full-resolution image, just downscaled.

**Cause**: `J2KDecoder.decodeResolution` is not yet implemented upstream in J2KSwift. The flag uses post-decode nearest-neighbour downscale as a workaround.

**Tracking**: J2KSWIFT_BUG_REPORT.md.

### JP3D encode fails with "non-uniform slice spacing"

**Symptom**: `JP3DVolumeBridgeError.nonUniformSliceSpacing`

**Cause**: JP3D requires uniform voxel spacing. Gantry-tilted CT or scout series will fail.

**Fix**: Resample to isotropic voxel grid before encoding, or use `JP3DVolumeBridge.makeVolume(from:allowNonUniform:)` with `allowNonUniform: false` to get a clear error message.

---

## Known Limitations

| Limitation | Status |
|-----------|--------|
| HTJ2K lossy (`.203`) edge cases | Partially validated; tracked, non-blocking |
| `J2KDecoder.decodeResolution` | Not implemented upstream — post-decode workaround used |
| JP3D standard DICOM transfer syntax | No standard UID; private SOP only |
| J2KVulkan (Linux GPU) | Deferred — requires Linux CI configuration |
| JPEG-LS | Not supported |

---

*DICOMKit version: 1.2.7 — J2KSwift v3.2.0*
*Last updated: 2026-04-21*
