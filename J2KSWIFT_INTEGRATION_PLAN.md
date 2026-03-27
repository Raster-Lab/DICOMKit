# J2KSwift Integration Plan for DICOMKit

> **Repository:** [Raster-Lab/J2KSwift](https://github.com/Raster-Lab/J2KSwift)  
> **Target:** [Raster-Lab/DICOMKit](https://github.com/Raster-Lab/DICOMKit)  
> **J2KSwift Version:** 2.2.0  
> **Date:** 2026-03-27

---

## Executive Summary

This document outlines a phased integration plan for replacing DICOMKit's Apple ImageIO-based JPEG 2000 codec (`NativeJPEG2000Codec`) with the pure-Swift [J2KSwift](https://github.com/Raster-Lab/J2KSwift) library. The integration unlocks HTJ2K (High-Throughput JPEG 2000) transfer syntaxes, JPEG 2000 Part 2 extensions, JPIP progressive streaming, JP3D volumetric compression, hardware-accelerated codecs (Metal/Vulkan/SIMD), and cross-platform Linux support — none of which are possible with the current Apple ImageIO approach.

### Current State

| Capability | DICOMKit Today | After Integration |
|-----------|---------------|-------------------|
| JPEG 2000 Lossless (1.2.840.10008.1.2.4.90) | ✅ Apple ImageIO | ✅ J2KSwift (cross-platform) |
| JPEG 2000 Lossy (1.2.840.10008.1.2.4.91) | ✅ Apple ImageIO | ✅ J2KSwift (cross-platform) |
| JPEG 2000 Part 2 Lossless (1.2.840.10008.1.2.4.92) | ❌ | ✅ J2KCodec + J2KFileFormat |
| JPEG 2000 Part 2 Lossy (1.2.840.10008.1.2.4.93) | ❌ | ✅ J2KCodec + J2KFileFormat |
| HTJ2K Lossless (1.2.840.10008.1.2.4.201) | ❌ | ✅ J2KCodec HTJ2K mode |
| HTJ2K RPCL Lossless (1.2.840.10008.1.2.4.202) | ❌ | ✅ J2KCodec HTJ2K + RPCL |
| HTJ2K Lossy (1.2.840.10008.1.2.4.203) | ❌ | ✅ J2KCodec HTJ2K mode |
| Linux Support | ❌ (ImageIO unavailable) | ✅ Pure Swift |
| Progressive Decoding | ❌ | ✅ J2KCodec progressive modes |
| ROI Decoding | ❌ | ✅ J2KCodec ROI options |
| JPIP Streaming | ❌ | ✅ JPIP module |
| JP3D Volumetric | ❌ | ✅ J2K3D module |
| Metal GPU Acceleration | ❌ | ✅ J2KMetal module |
| Vulkan GPU Acceleration | ❌ | ✅ J2KVulkan module |
| ARM NEON / Intel SSE SIMD | ❌ | ✅ J2KAccelerate module |
| JPEG XS (ISO 21122) | ❌ | 🔶 J2KXS (scaffold) |
| Lossless Transcoding | ❌ | ✅ J2KTranscoder |
| Quality Metrics (PSNR/SSIM) | ❌ | ✅ J2KCodec metrics |

### J2KSwift Module Map

```
J2KSwift (package)
├── J2KCore          ─ Core types, image model, wavelet, entropy, quantization
├── J2KCodec         ─ Encoder/Decoder/Transcoder pipelines (J2KEncoder, J2KDecoder, J2KTranscoder)
│   ├── ARM/         ─ ARM NEON optimised code paths
│   └── x86/         ─ Intel SSE/AVX optimised code paths
├── J2KAccelerate    ─ Apple Accelerate framework, vImage, advanced SIMD
├── J2KFileFormat    ─ JP2, J2K, JPX, JPM, MJ2 container formats
├── J2KMetal         ─ Metal GPU DWT, quantization, MCT, ROI
├── J2KVulkan        ─ Vulkan GPU DWT, color transform, quantization, JP3D
├── JPIP             ─ JPEG 2000 Interactive Protocol (streaming)
├── J2K3D            ─ JP3D volumetric (Part 10) encoder/decoder
├── J2KXS            ─ JPEG XS (ISO 21122) scaffold
└── J2KCLI           ─ CLI reference tool (encode/decode/transcode/validate/bench)
```

---

## Phase 1 — Foundation: SPM Dependency & Core Codec Replacement

**Goal:** Add J2KSwift as a dependency and replace `NativeJPEG2000Codec` with a J2KSwift-backed codec while maintaining full backward compatibility.

**Status:** In Progress ✅ (core integration complete; J2KSwift decoder has known reconstruction bugs — encoding via J2KSwift, decoding falls back to NativeJPEG2000Codec on Apple platforms)

### Known Upstream Issues (J2KSwift v2.0.0)

> [!WARNING]
> **Dependency Issue — `J2KSwift` v`2.0.0`**: Int32 overflow crash in the `DecoderPipeline.applyDequantization` method and decoder reconstruction fidelity bugs.
> **Impact**: JPEG 2000 decoding on Linux is unreliable; Apple platforms fall back to `NativeJPEG2000Codec` via ImageIO. Affects Phase 1 decoder integration and any milestone requiring cross-platform JPEG 2000 decode.
> **Workaround**: Clamped conversion patch applied locally via `swift package edit J2KSwift`. Encoding uses J2KSwift on all platforms; decoding uses ImageIO on Apple, J2KSwift (with patch) on Linux.
> **Upstream**: Patch pending at `patches/j2kswift-fix-dequantization-overflow.patch` — upstream PR not yet opened.
> **Tracking**: [J2KSWIFT_INTEGRATION_PLAN.md — Phase 1](J2KSWIFT_INTEGRATION_PLAN.md)

1. **Int32 overflow crash in `DecoderPipeline.applyDequantization`** — Fixed locally via clamped conversion. Patch at `patches/j2kswift-fix-dequantization-overflow.patch`.
2. **Decoder reconstruction fidelity** — Lossless encode → decode is not bit-exact; decoded pixel values diverge significantly. Root cause is in the J2KSwift decoder pipeline (wavelet inverse, dequantization, or colour transform). Requires upstream investigation.
3. **Multi-component decoding** — RGB images (3 components) are decoded as 1 component. The decoder doesn't reconstruct all colour channels.

### Milestone 1.1 — Package.swift Integration ✅

- [x] Add J2KSwift package dependency to `Package.swift`:
  ```
  .package(url: "https://github.com/Raster-Lab/J2KSwift.git", from: "2.0.0")
  ```
- [x] Add `J2KCore` and `J2KCodec` product dependencies to `DICOMCore` target
- [x] Add `J2KFileFormat` product dependency to `DICOMCore` target
- [x] Verify `swift build` succeeds on Linux (CI)
- [x] Document version pinning strategy — `from: "2.0.0"` (semver range)

### Milestone 1.2 — J2KSwift Codec Adapter ✅

- [x] Create `Sources/DICOMCore/J2KSwiftCodec.swift` implementing `ImageCodec` & `ImageEncoder`
- [x] Map J2KSwift's `J2KImage` ↔ DICOMKit's `PixelDataDescriptor` / raw `Data`
- [x] Implement `decodeFrame()` using `J2KDecoder.decode()`
- [x] Implement `encodeFrame()` using `J2KEncoder.encode()`
- [x] Support all `PixelDataDescriptor` configurations:
  - [x] 8-bit grayscale
  - [x] 16-bit grayscale (signed and unsigned)
  - [x] 8-bit RGB (3 samples/pixel)
  - [x] 12-bit grayscale
  - [x] Multi-frame sequences
- [x] Handle lossless vs lossy via `CompressionConfiguration` → `J2KEncodingConfiguration` mapping
- [x] Handle `CompressionConfiguration.quality` → J2KSwift quality presets mapping
- [x] Add `static let supportedTransferSyntaxes` for UIDs 1.2.840.10008.1.2.4.90 and .91
- [x] Add `static let supportedEncodingTransferSyntaxes` for UIDs 1.2.840.10008.1.2.4.90 and .91

### Milestone 1.3 — Codec Registry Swap ✅

- [x] Update `CodecRegistry.init()` to register `J2KSwiftCodec` for encoding
- [x] Keep `NativeJPEG2000Codec` as decoding fallback behind `#if canImport(ImageIO)` guard
- [x] On non-Apple platforms `J2KSwiftCodec` handles both encode and decode
- [x] Update `CodecRegistry.supportedTransferSyntaxes` — JPEG 2000 UIDs present on all platforms
- [ ] Add `isJPEG2000Part2` and `isHTJ2K` query helpers to `TransferSyntax` (deferred to Phase 2)
- [ ] Add unit tests comparing J2KSwift vs ImageIO output (deferred — requires J2KSwift decoder fix)

### Milestone 1.4 — Regression & Compatibility Testing ✅

- [x] Create test suite: `Tests/DICOMCoreTests/J2KSwiftCodecTests.swift` (50 tests)
- [x] Test encoding for all pixel configurations (8-bit gray, 16-bit gray unsigned/signed, RGB, 12-bit, uniform data, large images)
- [x] Test lossy encode at quality levels: 0.25, 0.50, 0.75, 0.95 (compression validated)
- [x] Test error handling: empty data, corrupt data, truncated streams, too-short pixel data
- [x] Test multi-frame encoding
- [x] Test codec registry integration (platform-aware: NativeJPEG2000Codec on Apple, J2KSwiftCodec on Linux)
- [x] Test J2K codestream format validation (SOC marker)
- [x] Test Sendable conformance
- [ ] Test lossless encode → decode bit-exact round-trip (deferred — J2KSwift decoder bugs)
- [ ] Performance benchmark: J2KSwift vs ImageIO (deferred to Phase 2)

### Upstream Fix: J2KSwift Dequantization Overflow

A patch for the Int32 overflow crash is included at `patches/j2kswift-fix-dequantization-overflow.patch`.
Apply to J2KSwift `Sources/J2KCodec/J2KDecoderPipeline.swift` line 845-848:

```diff
-            // Dequantize coefficients
-            let dequantized = info.coefficients.map { coeff in
-                Int32(Double(coeff) * stepSize)
-            }
+            // Dequantize coefficients (clamped to Int32 range to prevent overflow)
+            let dequantized = info.coefficients.map { coeff in
+                let product = Double(coeff) * stepSize
+                let clamped = max(Double(Int32.min), min(Double(Int32.max), product))
+                return Int32(clamped)
+            }
```

---

## Phase 2 — HTJ2K (High-Throughput JPEG 2000) Transfer Syntaxes

**Goal:** Add support for the three HTJ2K DICOM transfer syntaxes using J2KSwift's HTJ2K codec mode.

### Milestone 2.1 — Transfer Syntax Definitions

- [ ] Add `TransferSyntax.htj2kLossless` — UID `1.2.840.10008.1.2.4.201`
- [ ] Add `TransferSyntax.htj2kRPCLLossless` — UID `1.2.840.10008.1.2.4.202`
- [ ] Add `TransferSyntax.htj2kLossy` — UID `1.2.840.10008.1.2.4.203`
- [ ] Add `isHTJ2K: Bool` computed property to `TransferSyntax`
- [ ] Mark all three as `isExplicitVR: true`, `byteOrder: .littleEndian`, `isEncapsulated: true`
- [ ] Update `isCompressed`, `isLossless`, `displayName` for the new syntaxes
- [ ] Add to `TransferSyntax.allKnown` collection
- [ ] Update `DICOMValidator` to accept HTJ2K transfer syntaxes
- [ ] Update `StorageSCP` presentation contexts to include HTJ2K

**CLI Validation:**
```bash
swift test --filter TransferSyntaxTests
dicom-tags --search "HTJ2K"          # Verify UID lookup works
dicom-uid 1.2.840.10008.1.2.4.201   # Verify UID recognition
```

### Milestone 2.2 — HTJ2K Codec Implementation

- [ ] Extend `J2KSwiftCodec` to support HTJ2K encode/decode
- [ ] Map HTJ2K transfer syntax UIDs to `J2KEncodingConfiguration(codingStyle: .htj2k, ...)`
- [ ] Support RPCL (Resolution-Progression-Component-Layer) ordering for UID .202
- [ ] Register HTJ2K syntaxes in `CodecRegistry`
- [ ] Add `htj2k`, `htj2k-lossless`, `htj2k-rpcl` codec names to `dicom-compress`
- [ ] Update `CompressionManager.codecMap` with HTJ2K entries

**CLI Validation:**
```bash
swift test --filter HTJ2KCodecTests
dicom-compress compress input.dcm -o htj2k.dcm --codec htj2k --verbose
dicom-compress compress input.dcm -o htj2k_ll.dcm --codec htj2k-lossless --verbose
dicom-compress info htj2k.dcm                   # Should show HTJ2K transfer syntax
dicom-compress decompress htj2k.dcm -o round.dcm
dicom-diff input.dcm round.dcm                  # Verify fidelity
```

### Milestone 2.3 — HTJ2K Transcoding Support

- [ ] Integrate `J2KTranscoder` for legacy J2K ↔ HTJ2K lossless transcoding
- [ ] Add `transcode` subcommand to `dicom-compress` CLI:
  - `dicom-compress transcode input.dcm --from j2k --to htj2k -o output.dcm`
- [ ] Support bit-exact transcoding (verify via checksum)
- [ ] Support batch transcoding of directories
- [ ] Add parallel transcoding support for multi-tile images

**CLI Validation:**
```bash
dicom-compress transcode j2k_file.dcm --to htj2k -o htj2k_file.dcm --verbose
dicom-compress transcode htj2k_file.dcm --to j2k -o j2k_round.dcm --verbose
# Verify bit-exact:
shasum j2k_file.dcm_pixels vs j2k_round.dcm_pixels
dicom-compress batch transcode input_dir/ --to htj2k -o output_dir/ --recursive --verbose
```

### Milestone 2.4 — HTJ2K Testing & Benchmarks

- [ ] Create `Tests/DICOMCoreTests/HTJ2KTests.swift`
- [ ] Test all three HTJ2K transfer syntax encode/decode round-trips
- [ ] Test transcoding: J2K → HTJ2K → J2K round-trip (bit-exact)
- [ ] Benchmark HTJ2K vs legacy J2K decode speed (expect 5–70× improvement)
- [ ] Benchmark HTJ2K vs legacy J2K encode speed
- [ ] Test interoperability: write HTJ2K DICOM, verify readable by other viewers
- [ ] Test network transfer: C-STORE with HTJ2K transfer syntax

**CLI Validation:**
```bash
swift test --filter HTJ2KTests
# Performance comparison:
time dicom-compress compress large_ct.dcm -o j2k.dcm --codec j2k
time dicom-compress compress large_ct.dcm -o htj2k.dcm --codec htj2k
# Verify network:
dicom-send htj2k.dcm --host pacs.local --port 11112 --aet TEST --verbose
```

---

## Phase 3 — JPEG 2000 Part 2 (Extensions) Transfer Syntaxes

**Goal:** Add support for JPEG 2000 Part 2 (JPX extensions) transfer syntaxes.

### Milestone 3.1 — Part 2 Transfer Syntax Definitions

- [ ] Add `TransferSyntax.jpeg2000Part2Lossless` — UID `1.2.840.10008.1.2.4.92`
- [ ] Add `TransferSyntax.jpeg2000Part2` — UID `1.2.840.10008.1.2.4.93`
- [ ] Add `isJPEG2000Part2: Bool` computed property
- [ ] Update `isCompressed`, `isLossless`, `displayName`
- [ ] Register in `DICOMValidator` and `StorageSCP`

### Milestone 3.2 — Part 2 Codec Implementation

- [ ] Extend `J2KSwiftCodec` with Part 2 encode/decode support
- [ ] Map Part 2 UIDs to J2KSwift's Part 2 encoding configuration
- [ ] Support Part 2 features: multi-component transform, arbitrary wavelet kernels
- [ ] Register Part 2 syntaxes in `CodecRegistry`
- [ ] Add `j2k-part2`, `j2k-part2-lossless` codec names to `dicom-compress`
- [ ] Update `CompressionManager.codecMap`

**CLI Validation:**
```bash
swift test --filter JPEG2000Part2Tests
dicom-compress compress input.dcm -o part2.dcm --codec j2k-part2 --verbose
dicom-compress decompress part2.dcm -o round.dcm
dicom-info part2.dcm
```

### Milestone 3.3 — Part 2 Testing

- [ ] Create `Tests/DICOMCoreTests/JPEG2000Part2Tests.swift`
- [ ] Test Part 2 lossless and lossy round-trips
- [ ] Test Part 2 extension features (MCT, arbitrary wavelets)
- [ ] Test interoperability with standard Part 1 files
- [ ] Verify error handling for unsupported Part 2 features

---

## Phase 4 — Hardware Acceleration Integration

**Goal:** Leverage J2KSwift's hardware-accelerated codecs for maximum performance.

### Milestone 4.1 — Accelerate Framework Integration

- [ ] Add `J2KAccelerate` dependency to `DICOMCore` target
- [ ] Create `AcceleratedJ2KCodec` that uses `J2KAccelerate` for SIMD-optimised DWT
- [ ] Auto-detect platform capabilities (ARM NEON on Apple Silicon, SSE/AVX on Intel)
- [ ] Add accelerated codec to `CodecRegistry` with priority over base codec
- [ ] Benchmark: measure speedup over base J2KSwift codec

**CLI Validation:**
```bash
swift test --filter AcceleratedJ2KCodecTests
# Benchmark comparison:
dicom-compress compress large_ct.dcm -o accel.dcm --codec j2k --verbose  # Should show "accelerated"
```

### Milestone 4.2 — Metal GPU Integration (Apple Platforms)

- [ ] Add `J2KMetal` dependency to `DICOMKit` target (gated behind `#if canImport(Metal)`)
- [ ] Create `MetalJ2KCodec` using Metal GPU DWT, quantization, and MCT
- [ ] Implement GPU→CPU pixel data transfer for DICOM frame extraction
- [ ] Register as highest-priority codec when Metal device is available
- [ ] Add `--gpu` flag to `dicom-compress` to force GPU codec path
- [ ] Benchmark: measure GPU vs CPU speedup (expect 2–10× for large images)

**CLI Validation:**
```bash
swift test --filter MetalJ2KCodecTests   # macOS only
dicom-compress compress large_ct.dcm -o gpu.dcm --codec j2k --gpu --verbose
```

### Milestone 4.3 — Vulkan GPU Integration (Cross-Platform)

- [ ] Add `J2KVulkan` dependency to `DICOMKit` (gated behind Vulkan availability)
- [ ] Create `VulkanJ2KCodec` using Vulkan compute shaders for DWT
- [ ] Register as alternative to Metal on non-Apple platforms
- [ ] Add Vulkan availability detection at runtime
- [ ] Benchmark on Linux with Vulkan-capable GPU

**CLI Validation:**
```bash
swift test --filter VulkanJ2KCodecTests  # Linux + Vulkan only
dicom-compress compress large_ct.dcm -o vulkan.dcm --codec j2k --gpu --verbose
```

### Milestone 4.4 — Codec Selection Strategy

- [ ] Implement automatic codec tier selection:
  1. Metal GPU (if available, Apple platforms)
  2. Vulkan GPU (if available, Linux/cross-platform)
  3. J2KAccelerate + SIMD (if platform supports)
  4. Base J2KSwift (pure Swift, always available)
  5. Apple ImageIO fallback (Apple platforms, `canImport(ImageIO)`)
- [ ] Add `--codec-backend` flag to `dicom-compress`: `auto`, `gpu-metal`, `gpu-vulkan`, `simd`, `swift`, `imageio`
- [ ] Log selected backend in verbose mode
- [ ] Create `dicom-compress benchmark` subcommand to compare all available backends

**CLI Validation:**
```bash
dicom-compress compress input.dcm -o out.dcm --codec j2k --codec-backend auto --verbose
dicom-compress compress input.dcm -o out.dcm --codec j2k --codec-backend swift --verbose
dicom-compress benchmark input.dcm --codec j2k  # Compare all backends
```

---

## Phase 5 — Progressive & ROI Decoding

**Goal:** Expose J2KSwift's progressive and region-of-interest decoding capabilities through DICOMKit APIs and CLI.

### Milestone 5.1 — Progressive Decoding API

- [ ] Define `ProgressiveDecodingOptions` in DICOMCore:
  - Quality-progressive mode (target quality 0.0–1.0)
  - Resolution-progressive mode (target resolution level)
  - Layer-progressive mode (target layer count)
- [ ] Extend `ImageCodec` protocol with optional progressive decode method:
  ```
  func decodeFrameProgressively(..., options: ProgressiveDecodingOptions) throws -> Data
  ```
- [ ] Implement in `J2KSwiftCodec` using `J2KProgressiveDecodingOptions`
- [ ] Expose through high-level `DICOMKit` API on `DataSet`

**CLI Validation:**
```bash
swift test --filter ProgressiveDecodingTests
dicom-image extract input_j2k.dcm --progressive --quality 0.5 -o preview.png  # Low-quality preview
dicom-image extract input_j2k.dcm --progressive --quality 1.0 -o full.png     # Full quality
```

### Milestone 5.2 — ROI Decoding API

- [ ] Define `ROIDecodingOptions` in DICOMCore:
  - Region rectangle (x, y, width, height)
  - Resolution level for region
  - Quality level for region
- [ ] Extend `ImageCodec` protocol with optional ROI decode method
- [ ] Implement in `J2KSwiftCodec` using `J2KROIDecodingOptions`
- [ ] Support ROI decode without full image decompression

**CLI Validation:**
```bash
swift test --filter ROIDecodingTests
dicom-image extract input_j2k.dcm --roi 100,100,200,200 -o roi_crop.png --verbose
dicom-image extract input_j2k.dcm --roi 0,0,512,512 --resolution 2 -o low_res.png
```

### Milestone 5.3 — Quality Metrics

- [ ] Integrate J2KSwift's PSNR, SSIM, MS-SSIM quality metrics
- [ ] Add `dicom-compress quality` subcommand:
  - Compare original vs compressed DICOM pixel data
  - Report PSNR (dB), SSIM (0.0–1.0), MS-SSIM
  - Support per-frame metrics for multi-frame files
- [ ] Add `--metrics` flag to `dicom-compress compress` to report quality after compression

**CLI Validation:**
```bash
dicom-compress quality original.dcm compressed.dcm --verbose
# Output: PSNR: 45.2 dB, SSIM: 0.9987, MS-SSIM: 0.9991
dicom-compress compress input.dcm -o lossy.dcm --codec j2k --quality medium --metrics
```

---

## Phase 6 — JPIP Streaming Integration

**Goal:** Integrate J2KSwift's JPIP module to enable progressive JPEG 2000 streaming for large images.

### Milestone 6.1 — JPIP Client in DICOMKit

- [ ] Add `JPIP` dependency to `DICOMNetwork` or new `DICOMStreaming` module
- [ ] Create `JPIPClient` wrapper bridging J2KSwift JPIP to DICOMKit:
  - Session management (connect, disconnect, keep-alive)
  - Progressive image requests (by resolution, quality, region)
  - Cache management with DICOMKit's caching infrastructure
- [ ] Support JPIP over HTTP/HTTPS transport
- [ ] Handle JPIP→DICOM metadata mapping

### Milestone 6.2 — JPIP CLI Tool

- [ ] Create `dicom-jpip` CLI tool:
  - `dicom-jpip connect <url>` — Establish JPIP session
  - `dicom-jpip fetch <url> --resolution <level> -o output.dcm` — Fetch at resolution
  - `dicom-jpip fetch <url> --roi <x,y,w,h> -o output.dcm` — Fetch ROI
  - `dicom-jpip fetch <url> --quality <0.0-1.0> -o output.dcm` — Fetch at quality
  - `dicom-jpip info <url>` — Query image metadata via JPIP
  - `dicom-jpip bench <url>` — Benchmark streaming throughput
- [ ] Add ArgumentParser command structure
- [ ] Add to `Package.swift` as executable target
- [ ] Add README in `Sources/dicom-jpip/`

**CLI Validation:**
```bash
swift build --target dicom-jpip
dicom-jpip info jpip://server:8080/image1
dicom-jpip fetch jpip://server:8080/image1 --resolution 3 -o preview.dcm
dicom-jpip fetch jpip://server:8080/image1 --roi 256,256,512,512 -o roi.dcm
```

### Milestone 6.3 — JPIP Server Integration

- [ ] Extend `dicom-server` to serve JPIP requests for JPEG 2000 DICOM images
- [ ] Support JPIP session management in server mode
- [ ] Implement on-the-fly JPEG 2000 codestream serving
- [ ] Support bandwidth throttling and client concurrency

**CLI Validation:**
```bash
dicom-server start --jpip --port 8080 --dicom-dir /data/images/ --verbose
# In separate terminal:
dicom-jpip fetch jpip://localhost:8080/study1/series1/image1 --quality 0.5 -o test.dcm
```

---

## Phase 7 — JP3D Volumetric Compression

**Goal:** Integrate J2KSwift's JP3D module for volumetric DICOM compression, enabling 3D wavelet-based compression of CT/MR volume data.

### Milestone 7.1 — JP3D Codec Adapter

- [ ] Add `J2K3D` dependency to `DICOMCore` target
- [ ] Create `JP3DCodec` implementing `ImageCodec` & `ImageEncoder`
- [ ] Map DICOM multi-frame series → `J2KVolume` (width × height × frames)
- [ ] Map `J2KVolumeComponent` → DICOMKit pixel data descriptors
- [ ] Support volumetric lossless and lossy compression modes
- [ ] Support HTJ2K mode for JP3D (`JP3DEncoderConfiguration.losslessHTJ2K`)
- [ ] Define new transfer syntax constant for JP3D (private or experimental UID)

### Milestone 7.2 — JP3D CLI Tool

- [ ] Create `dicom-jp3d` CLI tool:
  - `dicom-jp3d compress <dir-or-multiframe.dcm> -o volume.jp3d` — Compress volume
  - `dicom-jp3d decompress volume.jp3d -o output_dir/` — Decompress to frames
  - `dicom-jp3d info volume.jp3d` — Volume metadata (dimensions, compression ratio)
  - `dicom-jp3d slice volume.jp3d --frame 45 -o slice.png` — Extract single slice
  - `dicom-jp3d benchmark <input> --mode lossless,lossy,htj2k` — Compare modes
- [ ] Add ArgumentParser command structure
- [ ] Add to `Package.swift`
- [ ] Add README in `Sources/dicom-jp3d/`

**CLI Validation:**
```bash
swift build --target dicom-jp3d
dicom-jp3d compress ct_series/ -o ct_volume.jp3d --mode lossless --verbose
dicom-jp3d info ct_volume.jp3d
dicom-jp3d decompress ct_volume.jp3d -o ct_frames/ --verbose
dicom-jp3d slice ct_volume.jp3d --frame 64 -o slice64.png
dicom-jp3d benchmark ct_series/ --mode lossless,lossy,htj2k
```

### Milestone 7.3 — JP3D Testing

- [ ] Create `Tests/DICOMCoreTests/JP3DCodecTests.swift`
- [ ] Test volumetric encode/decode round-trip
- [ ] Test slice extraction from compressed volume
- [ ] Test HTJ2K mode for volumetric data
- [ ] Test multi-spectral JP3D encoding
- [ ] Performance benchmark: volume compression vs per-frame compression

---

## Phase 8 — Advanced CLI Tooling

**Goal:** Create comprehensive CLI tools for J2K-specific operations and update existing tools.

### Milestone 8.1 — Update `dicom-compress` CLI

- [ ] Add all new codecs to help text and codec map:
  - `htj2k` / `htj2k-lossless` / `htj2k-rpcl`
  - `j2k-part2` / `j2k-part2-lossless`
- [ ] Add `transcode` subcommand (J2K ↔ HTJ2K)
- [ ] Add `quality` subcommand (PSNR/SSIM metrics)
- [ ] Add `benchmark` subcommand (compare backends)
- [ ] Add `--codec-backend` flag (auto/gpu-metal/gpu-vulkan/simd/swift/imageio)
- [ ] Add `--gpu` shorthand flag
- [ ] Add `--metrics` flag to `compress` subcommand
- [ ] Add `--progressive` flag for progressive encoding configuration
- [ ] Update existing help text and examples
- [ ] Update `Sources/dicom-compress/README.md`

**CLI Validation:**
```bash
dicom-compress --help                          # Verify new subcommands appear
dicom-compress compress --help                 # Verify new flags appear
dicom-compress transcode --help                # New subcommand works
dicom-compress quality --help                  # New subcommand works
dicom-compress benchmark --help                # New subcommand works
```

### Milestone 8.2 — Create `dicom-j2k` CLI Tool

- [ ] Create dedicated J2K analysis and manipulation tool:
  - `dicom-j2k info <file.dcm>` — Detailed J2K codestream analysis:
    - Marker segment breakdown (SIZ, COD, QCD, SOT, etc.)
    - Tile structure and dimensions
    - Progression order
    - Wavelet levels and filter type
    - Quality layers
    - Component subsampling
  - `dicom-j2k markers <file.dcm>` — List all J2K marker segments with offsets
  - `dicom-j2k validate <file.dcm>` — J2K codestream conformance check
  - `dicom-j2k extract <file.dcm> -o raw.j2k` — Extract raw J2K codestream from DICOM
  - `dicom-j2k inject raw.j2k template.dcm -o output.dcm` — Inject J2K codestream into DICOM
  - `dicom-j2k compare file1.dcm file2.dcm` — Compare J2K encoding parameters
- [ ] Add ArgumentParser command structure
- [ ] Add to `Package.swift` as executable target
- [ ] Add README in `Sources/dicom-j2k/`
- [ ] Add tests in `Tests/dicom-j2kTests/`

**CLI Validation:**
```bash
swift build --target dicom-j2k
dicom-j2k info j2k_compressed.dcm --verbose
dicom-j2k markers j2k_compressed.dcm
dicom-j2k validate j2k_compressed.dcm
dicom-j2k extract j2k_compressed.dcm -o raw.j2k
dicom-j2k inject raw.j2k template.dcm -o rebuilt.dcm
dicom-j2k compare original.dcm recompressed.dcm
```

### Milestone 8.3 — Update `dicom-convert` CLI

- [ ] Add HTJ2K as output transfer syntax option
- [ ] Add JPEG 2000 Part 2 as output transfer syntax option
- [ ] Support conversion between all J2K variants
- [ ] Add `--j2k-quality` and `--j2k-levels` encoding parameters

### Milestone 8.4 — Update `dicom-info` CLI

- [ ] Display J2K codestream parameters when transfer syntax is J2K/HTJ2K
- [ ] Show wavelet type, decomposition levels, tile dimensions
- [ ] Show whether HTJ2K or legacy J2K
- [ ] Show quality layers information

### Milestone 8.5 — Update `dicom-validate` CLI

- [ ] Add J2K codestream validation rules
- [ ] Validate J2K parameters match DICOM metadata (dimensions, bit depth)
- [ ] Check for HTJ2K compliance
- [ ] Validate encapsulated pixel data fragment structure for J2K

---

## Phase 9 — DICOMWeb & Network Integration

**Goal:** Ensure all network modules support the new transfer syntaxes.

### Milestone 9.1 — DICOMWeb Updates

- [ ] Update `DICOMwebCapabilities` to advertise HTJ2K transfer syntaxes
- [ ] Update WADO-RS to accept/serve HTJ2K content
- [ ] Update STOW-RS to accept HTJ2K uploads
- [ ] Support `Accept` header negotiation for J2K variants

### Milestone 9.2 — DICOM Network Updates

- [ ] Update SCP presentation contexts to include HTJ2K and Part 2 syntaxes
- [ ] Update SCU association negotiation for new syntaxes
- [ ] Update C-STORE to handle HTJ2K transfer
- [ ] Test C-FIND/C-MOVE with HTJ2K-compressed images

**CLI Validation:**
```bash
# Test network with HTJ2K:
dicom-echo --host pacs.local --port 11112 --aet TEST
dicom-send htj2k_file.dcm --host pacs.local --port 11112 --aet TEST --verbose
dicom-query --host pacs.local --port 11112 --aet TEST --level STUDY
dicom-retrieve --host pacs.local --port 11112 --aet TEST --study-uid 1.2.3 --syntax htj2k
```

### Milestone 9.3 — WADO-RS Progressive Retrieval

- [ ] Support progressive WADO-RS retrieval using J2KSwift's progressive decoding
- [ ] Return low-resolution preview first, then progressively enhance
- [ ] Support `quality` query parameter for WADO-RS requests

---

## Phase 10 — MJ2 (Motion JPEG 2000) Integration

**Goal:** Integrate J2KSwift's MJ2 support for DICOM cine/video sequences.

### Milestone 10.1 — MJ2 Container Support

- [ ] Add `J2KFileFormat` dependency for MJ2 support
- [ ] Create `MJ2Handler` bridging MJ2 playback to DICOMKit multi-frame handling
- [ ] Support MJ2 creation from DICOM cine series
- [ ] Support MJ2 extraction to DICOM frames

### Milestone 10.2 — MJ2 CLI

- [ ] Add MJ2 support to `dicom-convert`:
  - `dicom-convert export-mj2 cine_series/ -o output.mj2` — Create MJ2 from DICOM
  - `dicom-convert import-mj2 input.mj2 -o dicom_dir/` — Extract DICOM from MJ2
- [ ] Add to `dicom-j2k` tool:
  - `dicom-j2k mj2-info input.mj2` — MJ2 container analysis
  - `dicom-j2k mj2-frames input.mj2 --frame 10-20 -o frames/` — Extract frame range

**CLI Validation:**
```bash
dicom-convert export-mj2 cardiac_cine/ -o cardiac.mj2 --verbose
dicom-j2k mj2-info cardiac.mj2
dicom-convert import-mj2 cardiac.mj2 -o extracted/ --verbose
dicom-j2k mj2-frames cardiac.mj2 --frame 0-5 -o frame_samples/
```

---

## Phase 11 — JPEG XS Integration (Future/Experimental)

**Goal:** Prepare for JPEG XS (ISO/IEC 21122) when J2KSwift's J2KXS module matures.

### Milestone 11.1 — JPEG XS Scaffolding

- [ ] Add `J2KXS` dependency (conditional, behind feature flag)
- [ ] Define experimental transfer syntax UIDs for JPEG XS
- [ ] Create `J2KXSCodec` scaffold implementing `ImageCodec`
- [ ] Add `--experimental-xs` flag to `dicom-compress`
- [ ] Track DICOM standard proposals for JPEG XS transfer syntax UIDs

**Note:** J2KXS is currently in scaffold/exploration phase in J2KSwift v2.2.0. Implementation will track the module's maturity.

---

## Phase 12 — DICOMStudio GUI Integration

**Goal:** Update DICOMStudio UI to expose J2KSwift capabilities.

### Milestone 12.1 — Data Exchange View Updates

- [ ] Add HTJ2K, J2K Part 2 to transfer syntax conversion picker
- [ ] Add J2K codestream analysis panel
- [ ] Add quality metrics display (PSNR/SSIM) after compression
- [ ] Add codec backend selector (Auto/GPU/SIMD/Swift/ImageIO)

### Milestone 12.2 — Performance Tools Updates

- [ ] Add J2K-specific benchmarks to Performance Dashboard
- [ ] Show GPU vs CPU codec comparison charts
- [ ] Display SIMD utilisation metrics from J2KAccelerate

### Milestone 12.3 — CLI Workshop Updates

- [ ] Add `dicom-j2k`, `dicom-jpip`, `dicom-jp3d` to tool catalog
- [ ] Add updated `dicom-compress` subcommands (transcode, quality, benchmark)
- [ ] Update parameter builder for new codec options

---

## Testing Strategy

### Unit Tests (per phase)

| Phase | Test Target | Minimum Tests | Coverage Target |
|-------|-----------|---------------|-----------------|
| 1 | `J2KSwiftCodecTests` | 40 | 90% |
| 2 | `HTJ2KTests` | 30 | 90% |
| 3 | `JPEG2000Part2Tests` | 20 | 85% |
| 4 | `AcceleratedCodecTests` | 25 | 80% |
| 5 | `ProgressiveDecodingTests`, `ROIDecodingTests` | 30 | 85% |
| 6 | `JPIPIntegrationTests` | 20 | 80% |
| 7 | `JP3DCodecTests` | 25 | 85% |
| 8 | CLI tool tests | 40 | 80% |
| 9 | Network integration tests | 15 | 75% |
| 10 | `MJ2IntegrationTests` | 15 | 80% |

### Integration Tests

- [ ] Round-trip test: Raw → J2K → DICOM → Decode → Compare
- [ ] Round-trip test: Raw → HTJ2K → DICOM → Decode → Compare
- [ ] Transcode test: J2K DICOM → HTJ2K DICOM → J2K DICOM (bit-exact)
- [ ] Multi-codec test: Same image compressed with all backends, verify identical decode
- [ ] Network test: C-STORE HTJ2K file to test SCP, verify storage
- [ ] Cross-platform test: Encode on macOS, decode on Linux (and vice versa)

### Performance Benchmarks

| Benchmark | Metric | Baseline (ImageIO) | Target (J2KSwift) |
|-----------|--------|--------------------|--------------------|
| Decode 512×512 8-bit | ms | baseline | ≤ 1.5× baseline |
| Decode 512×512 16-bit | ms | baseline | ≤ 1.5× baseline |
| Decode 2048×2048 16-bit | ms | baseline | ≤ 2× baseline |
| Encode 512×512 lossless | ms | baseline | ≤ 2× baseline |
| HTJ2K decode 512×512 | ms | N/A | ≤ 0.5× J2K decode |
| GPU decode 2048×2048 | ms | N/A | ≤ 0.3× CPU decode |
| Memory peak 4096×4096 | MB | baseline | ≤ 1.2× baseline |

---

## Rollout Strategy

### Phase Gates

Each phase requires these gates before proceeding to the next:

1. **All unit tests pass** (`swift test`)
2. **No regression in existing tests** (baseline test count maintained)
3. **Build succeeds on all platforms** (macOS + Linux CI)
4. **CLI validation commands succeed** (documented in each milestone)
5. **Code review approved**
6. **Performance benchmarks within targets** (no >2× regression)

### Version Mapping

| Phase | DICOMKit Version | Key Deliverable |
|-------|-----------------|-----------------|
| Phase 1 | v2.0.0-alpha.1 | J2KSwift core integration, codec replacement |
| Phase 2 | v2.0.0-alpha.2 | HTJ2K transfer syntaxes |
| Phase 3 | v2.0.0-alpha.3 | JPEG 2000 Part 2 |
| Phase 4 | v2.0.0-beta.1 | Hardware acceleration (Metal/Vulkan/SIMD) |
| Phase 5 | v2.0.0-beta.2 | Progressive & ROI decoding |
| Phase 6 | v2.0.0-beta.3 | JPIP streaming |
| Phase 7 | v2.0.0-beta.4 | JP3D volumetric |
| Phase 8 | v2.0.0-rc.1 | Complete CLI tooling |
| Phase 9 | v2.0.0-rc.2 | Network integration |
| Phase 10 | v2.0.0-rc.3 | MJ2 support |
| Phase 11 | v2.1.0 | JPEG XS (experimental) |
| Phase 12 | v2.0.0 | DICOMStudio GUI |

### Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| J2KSwift decode quality differs from ImageIO | High | Round-trip PSNR tests; keep ImageIO fallback |
| Performance regression vs ImageIO | Medium | Benchmark gates; Accelerate/Metal paths |
| Linux build breaks (no ImageIO) | Medium | J2KSwift is pure Swift; CI on both platforms |
| J2KSwift API changes | Low | Pin to specific version; test against `from:` range |
| HTJ2K interop with other PACS | Medium | Test with reference implementations (OpenJPEG) |
| Large dependency size | Low | J2KSwift is modular; only import needed modules |

---

## Dependency Graph

```
DICOMCore
├── J2KCore          (always)
├── J2KCodec         (always)
├── J2KFileFormat    (always)
├── J2KAccelerate    (always, SIMD auto-detected)
├── J2KMetal         (Apple platforms, #if canImport(Metal))
└── J2KVulkan        (Linux + Vulkan, conditional)

DICOMNetwork / DICOMStreaming
└── JPIP             (optional, for streaming)

DICOMKit (umbrella)
├── J2K3D            (optional, for volumetric)
└── J2KXS            (experimental, feature-flagged)

CLI Tools
├── dicom-compress   → DICOMKit, J2KCodec
├── dicom-j2k        → DICOMCore, J2KCore, J2KCodec, J2KFileFormat
├── dicom-jpip       → DICOMNetwork, JPIP
└── dicom-jp3d       → DICOMCore, J2K3D
```

---

## Summary

| Phase | Milestones | New CLI Tools | Updated CLI Tools | New Transfer Syntaxes |
|-------|-----------|---------------|-------------------|----------------------|
| 1 — Foundation | 4 | — | dicom-compress | — |
| 2 — HTJ2K | 4 | — | dicom-compress | 3 (201, 202, 203) |
| 3 — Part 2 | 3 | — | dicom-compress | 2 (92, 93) |
| 4 — HW Accel | 4 | — | dicom-compress | — |
| 5 — Progressive/ROI | 3 | — | dicom-image, dicom-compress | — |
| 6 — JPIP | 3 | dicom-jpip | dicom-server | — |
| 7 — JP3D | 3 | dicom-jp3d | — | — |
| 8 — CLI | 5 | dicom-j2k | dicom-compress, dicom-convert, dicom-info, dicom-validate | — |
| 9 — Network | 3 | — | dicom-send, dicom-query, dicom-retrieve, dicom-wado | — |
| 10 — MJ2 | 2 | — | dicom-convert, dicom-j2k | — |
| 11 — JPEG XS | 1 | — | dicom-compress | (experimental) |
| 12 — GUI | 3 | — | — | — |
| **Total** | **38** | **3** | **12** | **5** |

---

> **Note:** This plan assumes J2KSwift v2.2.0 as the baseline. Module APIs and capabilities should be verified against the latest J2KSwift release before starting each phase. Per DICOMKit conventions, J2KSwift is a first-party Raster-Lab library and should be used directly without reimplementation.
