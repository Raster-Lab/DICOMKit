# J2KSwift v3.2.0 Integration Plan for DICOMKit

> **Dependency:** `.package(url: "https://github.com/Raster-Lab/J2KSwift.git", from: "3.2.0")`
> **Target repo:** [Raster-Lab/DICOMKit](https://github.com/Raster-Lab/DICOMKit)
> **Branch:** `feature/j2kswift-v3-integration`
> **Supersedes:** [J2KSWIFT_INTEGRATION_PLAN.md](J2KSWIFT_INTEGRATION_PLAN.md) (earlier baseline plan)
> **Date:** 2026‑04‑20

> ⚠️ **Breaking platform bump required.** J2KSwift v3.2.0 requires `swift-tools-version: 6.2` and
> minimum platforms `macOS 15 / iOS 17 / tvOS 17 / watchOS 10 / visionOS 1`. DICOMKit currently
> targets `swift-tools-version: 6.0` with `macOS 14 / iOS 17 / visionOS 1`. Adopting J2KSwift
> therefore forces a **macOS 15** floor and a Swift toolchain bump to 6.2. This is scheduled as
> Milestone 1.0 (Platform Bump) below and must be merged before any Phase 1 dependency wiring.

---

## 1. Executive Summary

This plan replaces DICOMKit's Apple‑ImageIO‑based `NativeJPEG2000Codec` with a pure‑Swift codec stack backed by **J2KSwift v3.2.0**, and extends the library, viewer, and CLI surface to cover the full DICOM JPEG 2000 family: **Part 1 (J2K)**, **Part 15 (HTJ2K)**, and **Part 10 (JP3D)** — plus JPIP streaming.

### 1.1 Why v3.2.0 (vs. the earlier baseline plan)

| Change in J2KSwift 3.x | Impact on DICOMKit |
|------------------------|--------------------|
| **Apple‑first architecture** — x86‑64 SIMD code paths removed in v3.0.0 | Simplifies build matrix; ARM64 macOS/iOS/visionOS + Linux ARM64 only for accelerated paths (scalar fallback elsewhere) |
| **CLI superset** (`encode3d`, `decode3d`, `jpip server/client`, `batch`, `compare`, `convert`, `completions`) | Clear design template for `dicom-j2k` CLI + `dicom-compress`/`dicom-3d` enhancements |
| **JP3D production ready** (ISO/IEC 15444‑10, HTJ2K‑backed) | Direct mapping to multi‑frame / volumetric DICOM (CT, MR, PET, 4D series) |
| **Multi‑spectral JP3D + Vulkan 3D DWT** | Future path for hyperspectral / functional MRI datasets |
| **3,100+ tests, 100% pass, Part 4 conformance + OpenJPEG interop** | Strong justification for replacing ImageIO on macOS and unlocking Linux |
| **Minor bump 3.1.0 → 3.2.0** | We pin `from: "3.2.0"` to pick up the latest 3.x additive features while staying on a stable major |
| **Tooling** | J2KSwift requires `swift-tools-version: 6.2` and `macOS 15+`; DICOMKit must follow suit |

### 1.2 End‑State Capability Matrix

| DICOM Transfer Syntax | UID | Today | After this plan |
|-----------------------|-----|-------|-----------------|
| JPEG 2000 Lossless | `1.2.840.10008.1.2.4.90` | ImageIO (Apple only) | J2KCodec (all platforms) |
| JPEG 2000 Lossy | `1.2.840.10008.1.2.4.91` | ImageIO (Apple only) | J2KCodec (all platforms) |
| JPEG 2000 Part 2 Lossless | `1.2.840.10008.1.2.4.92` | ✅ | J2KSwiftCodec Part 2 |
| JPEG 2000 Part 2 Lossy | `1.2.840.10008.1.2.4.93` | ✅ | J2KSwiftCodec Part 2 |
| HTJ2K Lossless | `1.2.840.10008.1.2.4.201` | ✅ J2KSwift v3.2.0 | J2KCodec HTJ2K |
| HTJ2K RPCL Lossless | `1.2.840.10008.1.2.4.202` | ✅ J2KSwift v3.2.0 | J2KCodec HTJ2K + RPCL |
| HTJ2K Lossy | `1.2.840.10008.1.2.4.203` | ⚠️ Partially validated | J2KCodec HTJ2K |
| JPIP Referenced | `1.2.840.10008.1.2.4.94` | ❌ | JPIP module |
| JPIP Referenced Deflate | `1.2.840.10008.1.2.4.95` | ❌ | JPIP + zlib |
| (Vendor) JP3D in multi‑frame wrapper | — | ❌ | J2K3D (experimental private SOP) |

### 1.3 Consumer Impact

| Consumer | Integration |
|----------|-------------|
| `DICOMCore` / `DICOMKit` library | New `J2KSwiftCodec`, `HTJ2KCodec`, `JP3DCodec`; `NativeJPEG2000Codec` deprecated |
| `DICOMNetwork` | HTJ2K/JPIP presentation contexts, C‑STORE/Q/R over new transfer syntaxes |
| `DICOMWeb` | New media types (`image/jph`, `image/jphc`), QIDO/WADO/STOW HTJ2K |
| **`dicom-viewer` CLI** (terminal renderer) | Decode J2K/HTJ2K frames + JP3D volume slice traversal for terminal preview |
| **`DICOMStudio` SwiftUI viewer** | Full HTJ2K display, progressive/ROI decoding, JP3D MPR views, JPIP streaming |
| **CLI tools** | New `dicom-j2k` tool + extensions to `dicom-compress`, `dicom-3d`, `dicom-convert`, `dicom-diff`, `dicom-retrieve`, `dicom-send` |

---

## 2. Architecture

### 2.1 J2KSwift Module Map (v3.2.0)

```
J2KSwift 3.2.0
├── J2KCore          ─ Image model, wavelet, entropy, quantisation
├── J2KCodec         ─ J2KEncoder / J2KDecoder / J2KTranscoder (Part 1 + Part 15 HTJ2K)
├── J2KFileFormat    ─ JP2 / J2K / JPX / JPM / JPH / JHC / MJ2 containers
├── J2KAccelerate    ─ Accelerate + ARM Neon vectorised kernels
├── J2KMetal         ─ Metal compute (Apple)
├── J2KVulkan        ─ SPIR‑V compute (Linux/Windows)
├── JPIP             ─ Interactive streaming (2D + 3D)
└── J2K3D            ─ JP3D volumetric (ISO/IEC 15444‑10)
```

**Platforms / toolchain (v3.2.0):** `swift-tools-version: 6.2`, `macOS 15`, `iOS 17`, `tvOS 17`,
`watchOS 10`, `visionOS 1`. Linux is supported via Swift 6.2 with the scalar codec path; GPU
backends require Metal (Apple) or Vulkan (Linux/Windows).

### 2.2 Proposed DICOMKit Layering

```
┌──────────────────────────────────────────────────────────────┐
│  DICOMStudio (SwiftUI viewer) / dicom-viewer (terminal)      │
│  + dicom-j2k / dicom-3d / dicom-compress / dicom-convert CLI │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  DICOMKit (facade) / DICOMNetwork / DICOMWeb                 │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  DICOMCore                                                   │
│  ├── CodecRegistry (prioritised)                             │
│  │   ├── MetalJ2KCodec        (Apple, GPU)    ── priority 0 │
│  │   ├── AcceleratedJ2KCodec  (Apple, SIMD)   ── priority 1 │
│  │   ├── VulkanJ2KCodec       (Linux, GPU)    ── priority 2 │
│  │   ├── J2KSwiftCodec        (all, scalar)   ── priority 3 │
│  │   └── NativeJPEG2000Codec  (Apple, legacy) ── deprecated │
│  ├── HTJ2KCodec / JP3DCodec / JPIPCodec                      │
│  └── TransferSyntax / PixelDataDescriptor                    │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  J2KSwift 3.2.0 (external SPM dependency)                    │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Package.swift Trait Model

Because J2KSwift ships ~10 modules, we introduce **package traits** to keep small embedders lightweight:

| Trait | Products pulled in | Default? |
|-------|--------------------|----------|
| `J2K` (base)           | `J2KCore`, `J2KCodec`, `J2KFileFormat` | ✅ |
| `J2KAccelerated`       | + `J2KAccelerate`                      | ✅ on Apple |
| `J2KMetal`             | + `J2KMetal`                           | ✅ on Apple |
| `J2KVulkan`            | + `J2KVulkan`                          | opt‑in     |
| `J2K3D`                | + `J2K3D`                              | ✅         |
| `JPIP`                 | + `JPIP`                               | opt‑in     |

Apple users get J2K + 3D + Metal + Accelerate by default; Linux server‑side users can opt into Vulkan and JPIP.

---

## 3. Phased Milestones

Each phase is shippable on its own and gated by a green `swift build && swift test` on macOS + Linux CI, plus the listed CLI smoke tests.

### Phase 0 — Branch & Scaffolding (this branch)

- [x] Create branch `feature/j2kswift-v3-integration`
- [ ] Add `J2KSWIFT_V3_2_INTEGRATION_PLAN.md` (this file) to main
- [ ] Update `MILESTONES.md` with a “Milestone 24 — J2KSwift v3 Integration” section pointing here
- [ ] Record acceptance‑criteria table in `MILESTONES.md`
- [ ] Open tracking issue `J2KSwift v3.2.0 integration` on GitHub

---

### Milestone 1.0 — Platform & Toolchain Bump (prerequisite)

**Goal:** Unblock the J2KSwift dependency by raising DICOMKit's minimum Swift toolchain and
Apple platform versions to the levels required by J2KSwift v3.2.0.

- [ ] `Package.swift`: change header to `// swift-tools-version: 6.2`
- [ ] `Package.swift`: bump Apple platforms:
  - [ ] `.macOS(.v14)` → `.macOS(.v15)`
  - [ ] `.iOS(.v17)` (unchanged)
  - [ ] `.visionOS(.v1)` (unchanged)
  - [ ] Add `.tvOS(.v17)` and `.watchOS(.v10)` **only if** we actually ship on those platforms; otherwise document explicit non‑support
- [ ] `.github/workflows/*`: pin Xcode 16.2+ (or newer) for Swift 6.2 on macOS runners; pin Swift 6.2 toolchain on Linux runners
- [ ] Audit `#available` / `@available` in DICOMKit sources — remove any now‑redundant `macOS 14` gates
- [ ] Update `README.md` requirements table (“macOS 15+”)
- [ ] Update `INSTALLATION.md`, `Documentation/*IntegrationGuide.md`, `Formula/*.rb` minimum macOS
- [ ] Update `CHANGELOG.md` → record breaking platform bump
- [ ] Semver: DICOMKit moves to **v2.0.0** because this is a breaking platform change
- [ ] `swift build` green on macOS 15 + Xcode 16.2+
- [ ] `swift test` green (no behavioural changes expected from the bump alone)

**Exit criteria:** Package compiles and all tests pass under Swift 6.2 on macOS 15 with no
J2KSwift dependency added yet. Only after this lands does Phase 1 begin.

---

### Phase 1 — SPM Dependency & Core Codec Swap (DICOMCore) ✅ Completed locally

**Goal:** J2KSwift 3.2.0 resolves cleanly and handles all existing JPEG 2000 transfer syntaxes without regression.

#### Milestone 1.1 — Package.swift wiring

- [x] Add dependency:
  ```swift
  .package(url: "https://github.com/Raster-Lab/J2KSwift.git", from: "3.2.0")
  ```
- [x] Add default products to `DICOMCore` target: `J2KCore`, `J2KCodec`, `J2KFileFormat`
- [x] Gate `J2KMetal` / `J2KAccelerate` behind `#if canImport(Metal)` / `#if canImport(Accelerate)` *(completed in Phase 5)*
- [ ] Gate `J2KVulkan` behind `#if canImport(Vulkan)` (Linux CI) *(deferred — requires Linux CI configuration)*
- [x] Verify `swift build` on macOS with Swift 6.2
- [ ] Verify Linux CI runner status for this branch
- [x] Verify `swift package show-dependencies` resolves 3.2.0 (or newer 3.x)
- [x] Document the Apple‑first note in `Documentation/Architecture.md`

#### Milestone 1.2 — `J2KSwiftCodec` adapter

- [x] Create `Sources/DICOMCore/J2KSwiftCodec.swift` conforming to `ImageCodec` + `ImageEncoder`
- [x] Implement `DICOMKit.PixelDataDescriptor ↔ J2KCore.J2KImage` bridge:
  - [x] 8/12/16‑bit grayscale (signed & unsigned)
  - [x] 8‑bit RGB (YBR_FULL / YBR_FULL_422 / RGB photometric interpretations)
  - [x] Planar vs. interleaved samples
  - [x] Multi‑frame sequences
- [x] Map `CompressionConfiguration` to `J2KEncodingConfiguration` (quality, lossless, progression)
- [x] Return `J2KSwiftCodec.supportedTransferSyntaxes = [.jpeg2000Lossless, .jpeg2000]` with HTJ2K expansion available on the same adapter

#### Milestone 1.3 — Registry swap

- [x] Update `CodecRegistry` to prefer `J2KSwiftCodec` for JPEG 2000 UIDs
- [x] Keep `NativeJPEG2000Codec` available only for separate Apple-side diagnostics
- [x] Remove legacy runtime masking from the default Phase 1 path
- [x] Use the J2KSwift path consistently for supported builds

#### Milestone 1.4 — Regression & conformance tests

- [x] `Tests/DICOMCoreTests/J2KSwiftCodecTests.swift`
  - [x] Decode and round-trip representative JPEG 2000 payloads from real LocalDatasets inputs
  - [x] Round‑trip 8/12/16‑bit grayscale, RGB, multi‑frame
  - [x] Corrupt / truncated / wrong‑VR cases
  - [x] Benchmarks recorded on macOS arm64 with real DICOM input
- [x] Update conformance statement: `Documentation/ConformanceStatement.md`

**Verified evidence on 2026-04-20:**
- `swift build` completed successfully
- `swift test --filter J2KSwiftCodecTests` passed with **16 tests in 1 suite** after **12.071 seconds**
- `swift test --filter J2KSwiftCodecBenchmarkTests` passed with **3 tests in 1 suite** after **125.882 seconds**
- `swift package show-dependencies` resolved **J2KSwift 3.2.0**
- Real-file benchmark on `instance_003317.dcm`: **J2KSwift decode 4809.322 ms**, **HTJ2K decode 886.122 ms**, **5.447× speedup**

> **Phase 1 sign-off:** implementation, local regression validation, and live dcm4chee PACS validation are complete. On 2026-04-20, the LDAP-backed local archive stack accepted both C-ECHO and a real MR C-STORE on AE DCM4CHEE over port 11112.

**CLI smoke:**
```bash
swift test --filter J2KSwiftCodecTests
dicom-info fixtures/ct_j2k_lossless.dcm
dicom-compress compress fixtures/ct.dcm -o /tmp/ct.j2k.dcm --codec j2k-lossless
dicom-diff fixtures/ct.dcm /tmp/ct.j2k.dcm
```

---

### Phase 2 — HTJ2K Transfer Syntaxes (ISO/IEC 15444‑15) ✅ Completed

**Goal:** Full support for the three DICOM HTJ2K transfer syntaxes end‑to‑end (library + network + CLI + viewer).

#### Milestone 2.1 — Transfer syntax model

- [x] Add to `TransferSyntax`:
  - [x] `.htj2kLossless` → `1.2.840.10008.1.2.4.201`
  - [x] `.htj2kRPCLLossless` → `1.2.840.10008.1.2.4.202`
  - [x] `.htj2kLossy` → `1.2.840.10008.1.2.4.203`
- [x] `isHTJ2K`, `isEncapsulated`, `isLossless`, `displayName` updates
- [x] Add to `TransferSyntax.allKnown`, `DICOMValidator`, `StorageSCP` presentation contexts
- [x] Update `Sources/DICOMDictionary/UIDDictionary.swift`

#### Milestone 2.2 — `HTJ2KCodec`

- [x] `Sources/DICOMCore/HTJ2KCodec.swift` implementing `ImageCodec` + `ImageEncoder`
- [x] Internally delegates to `J2KSwiftCodec` configured with HTJ2K encoding (useHTJ2K flag)
- [x] RPCL progression ordering wired for `.202`
- [x] Register in `CodecRegistry` for all three UIDs (overrides generic J2KSwiftCodec entries)
- [x] Expose helper: `TransferSyntaxConverter.recommendHTJ2K(for: PixelDataDescriptor) -> TransferSyntax`

#### Milestone 2.3 — Transcoding

- [x] `HTJ2KCodec.transcodeToHTJ2K/transcodeFromHTJ2K` wrapping `J2KTranscoder` for bit‑exact J2K ↔ HTJ2K
- [x] `TransferSyntaxConverter` fast‑path transcoding via `canUseFastPathTranscode` + `transcodeFastPath` (no pixel decode)
- [x] Benchmark: 5.434× decode speed‑up for HTJ2K vs. J2K on CT volumes (exceeds 5× target)

#### Milestone 2.4 — Network & Web

- [x] `DICOMNetwork`: add HTJ2K to default SCP/SCU presentation contexts
- [x] `DICOMWeb`: add `image/jph` and `image/jphc` media types; update capability advertising for HTJ2K retrieval/storage
- [x] `dicom-retrieve` / `dicom-send`: accept `--transfer-syntax htj2k|htj2k-rpcl|htj2k-lossless`

**Progress update (2026-04-20):** The shared transfer syntax converter now supports verified JPEG 2000 ↔ HTJ2K recompression via the decode/re-encode path, DICOMweb now advertises and handles HTJ2K media types, and the send/retrieve command builders and runtime parsing now accept HTJ2K aliases with the focused CLI suites passing 11 tests across 2 suites.

**CLI smoke:**
```bash
swift test --filter HTJ2KCodecTests
dicom-compress compress ct.dcm -o ct.htj2k.dcm --codec htj2k-lossless
dicom-compress transcode ct.j2k.dcm --to htj2k -o ct.htj2k.dcm
dicom-send ct.htj2k.dcm --host pacs.local --port 11112 --aet TEST \
  --transfer-syntax htj2k-lossless
```

**Phase 2 completion update (2026-04-21):** All four Phase 2 milestones are now complete:
- **2.1** Transfer syntax model: HTJ2K UIDs, `isHTJ2K` property, parse aliases
- **2.2** `HTJ2KCodec.swift`: dedicated adapter wrapping `J2KSwiftCodec` with HTJ2K encoding config, registered in `CodecRegistry` for all three UIDs, `recommendHTJ2K(for:)` helper added to `TransferSyntaxConverter`
- **2.3** Fast-path transcoding: `HTJ2KCodec.transcodeToHTJ2K/transcodeFromHTJ2K` using `J2KTranscoder` coefficient re-encoding, wired into `TransferSyntaxConverter.transcodeFastPath` (bypasses pixel decode/re-encode). Benchmark: 5.434× HTJ2K speedup.
- **2.4** Network & Web: DICOMweb HTJ2K media types, CLI send/retrieve HTJ2K support
- 92/93 tests pass; the single failure is a pre-existing `NativeJPEG2000Codec` 12-bit Apple ImageIO limitation (not Phase 2 related)

---

### Phase 3 — JPEG 2000 Part 2 Extensions ✅ Completed

**Goal:** Support `.92` / `.93` Part 2 transfer syntaxes (MCT, arbitrary wavelet kernels).

- [x] Transfer syntaxes `.jpeg2000Part2Lossless` / `.jpeg2000Part2` (pre-existing in `TransferSyntax.swift`)
- [x] Extend `J2KSwiftCodec` to support Part 2 UIDs in `supportedTransferSyntaxes` and encoding
- [x] Part 2 features enabled by default — J2KSwift handles Part 2 natively; no gate needed (reader is permissive, writer supports Part 2 UIDs)
- [x] `dicom-compress`: `--codec j2k-part2[-lossless]` added to CLI
- [x] `StorageSCP` presentation contexts include Part 2 UIDs
- [x] `DICOMValidator` already includes Part 2 UIDs
- [x] Test: Part 2 lossless/lossy round-trip, codec registry, parse aliases (4 new tests, all passing)

---

### Phase 4 — JP3D Volumetric Integration (ISO/IEC 15444‑10)

**Status:** In Progress

**Goal:** Represent multi‑frame CT/MR/PET/US volumes with **JP3D** inside DICOMKit for compact storage and fast ROI decode. JP3D in DICOM has no standard transfer syntax yet, so we expose it via:

1. **Private transfer syntax** for round‑trip testing (`1.2.840.10008.1.2.4.203.*` vendor extension — clearly labelled experimental).
2. **Encapsulated document SOP** (1.2.840.10008.5.1.4.1.1.104.1 or private) carrying a `.jp3d` blob, with JSON sidecar describing voxel geometry.
3. **Runtime‑only codec** that converts a DICOM multi‑frame series ↔ `J2K3D.J2KVolume` for viewer consumption.

#### Milestone 4.1 — Volume bridge ✅

- [x] `Sources/DICOMKit/JP3DVolumeBridge.swift`
  - [x] `func makeVolume(from series: [DICOMFile]) throws -> J2KVolume`
  - [x] `func makeDICOMSeries(from volume: J2KVolume, template: DICOMFile) throws -> [DICOMFile]`
  - [x] Handles per‑slice `SliceLocation`, `ImagePositionPatient`
  - [x] Preserves `SeriesInstanceUID`, regenerates `SOPInstanceUID` per slice
- [x] Validation: slice spacing uniformity, consistent rows/cols/bits stored

#### Milestone 4.2 — `JP3DCodec` ✅

- [x] `Sources/DICOMCore/JP3DCodec.swift` wrapping `JP3DEncoder` / `JP3DDecoder`
- [x] Supports `compressionMode: .lossless | .losslessHTJ2K | .lossy(psnr:) | .lossyHTJ2K(psnr:)`
- [x] Registered in `CodecRegistry` for experimental JP3D transfer syntaxes
- [x] Async volumetric API (`encodeVolume`/`decodeVolume`) + sync protocol bridge
- [x] 17 tests passing: transfer syntax, codec, canEncode, registry, round-trip, sync bridge, frame extraction

#### Milestone 4.3 — Encapsulated SOP adapter ✅

- [x] Private SOP Class UID for "DICOMKit JP3D Volume (experimental)" (`1.2.826.0.1.3680043.10.511.10`)
- [x] Encapsulated‑document writer embeds `.jp3d` data + JSON sidecar (via `JP3DVolumeDocument`)
- [x] Reader detects the SOP and returns decoded `[DICOMFile]` slices via `decode(from:)`
- [x] MIME type `application/x-jp3d`, payload = 4-byte JP3D len + codestream + 4-byte JSON len + sidecar
- [x] Round-trip encode/decode verified lossless in 8 tests

#### Milestone 4.4 — Viewer‑time virtual decode ✅

- [x] `DICOMFile.openVolume(from: URL) async throws -> DICOMVolume` that:
  - [x] Detects conventional multi‑frame series → returns uncompressed volume
  - [x] Detects JP3D encapsulation → decodes on demand via `JP3DVolumeDocument`
  - [x] Handles directories of single-frame slices (sorted by Z/InstanceNumber)
  - [x] `DICOMVolume` struct with `slice(at:)`, `voxel(x:y:z:)`, spacing, origin, modality
- [ ] Progressive decoding via JPIP (see Phase 6) for huge CT/MR studies

**Tests (25 total, all passing):**
```
swift test --filter "JP3DVolumeDocumentTests"
```

---

### Phase 5 — Hardware Acceleration ✅ COMPLETE

**Goal:** Opportunistically use the best J2KSwift backend on each platform.

| Backend | Where | DICOMKit type |
|---------|-------|---------------|
| `J2KMetal`     | Apple (iOS 17+, macOS 14+, visionOS 1+) | Exposed via `CodecBackend.metal` |
| `J2KAccelerate`| Apple (all)                              | Exposed via `CodecBackend.accelerate` |
| `J2KCodec` (scalar) | everywhere (fallback)                | Exposed via `CodecBackend.scalar` |

- [x] Add `CodecBackend` enum (`metal`, `accelerate`, `scalar`); `CodecBackendProbe` probes best available at startup
- [x] `CodecBackendPreference` lets callers force or fall back gracefully
- [x] `CodecRegistry` extension: `activeBackend`, `availableBackends`, `backendDescription`
- [x] Runtime Metal probe via `J2KMetalDevice.isAvailable` on Apple; falls through to Accelerate then scalar
- [x] `J2KAccelerate` and `J2KMetal` added as explicit dependencies in `DICOMCore` target in `Package.swift`
- [x] `--backend <auto|metal|accelerate|scalar>` option on `dicom-compress compress` subcommand
- [x] `backends` subcommand on both `dicom-compress` and `dicom-3d` listing all backends with availability
- [x] 20 unit tests in `Tests/DICOMCoreTests/CodecBackendTests.swift` — all pass

> Note: `J2KVulkan` support deferred — requires Linux CI configuration (Phase 5 scope was Apple-only).
> Per-codec micro-benchmarks in `Benchmarks/j2k_v3/` deferred to a future benchmarking sprint.

---

### Phase 6 — JPIP Streaming ✅ Completed

**Goal:** Progressive 2D + 3D streaming for remote studies and huge WSI/CT datasets.

- [x] Optional dependency on `JPIP` module (trait `JPIP`) — added to DICOMKit target in `Package.swift`
- [x] `DICOMJPIPClient` wrapping JPIP session; maps WADO‑URI + JPIP URL templates — `Sources/DICOMKit/DICOMJPIPClient.swift`
- [x] Transfer syntaxes `.jpip` (`.94`) and `.jpipDeflate` (`.95`) — registered in `TransferSyntax.swift` with `isJPIP` property
- [ ] `dicom-viewer` (terminal) shows live resolution‑progressive ASCII preview via JPIP — deferred to Phase 7
- [ ] `DICOMStudio`: JPIP study loader (quality/resolution slider wired to JPIP session) — deferred to Phase 8
- [x] CLI tool `dicom-jpip` (new) with `fetch`, `uri`, `serve`, and `info` subcommands — `Sources/dicom-jpip/main.swift`
- [x] 28 tests passing — `Tests/DICOMKitTests/JPIPTests.swift`

---

### Phase 7 — DICOMKit `dicom-viewer` CLI Upgrade ✅ Completed

**Goal:** The terminal viewer decodes and displays every JPEG 2000 flavour.

- [x] Rewire `TerminalRenderer` to pull pixels through `CodecRegistry` (`DICOMFile.pixelData()` path; HTJ2K/Part 2 work automatically)
- [x] Add `--reduce <n>` for low-res fast preview — post-decode nearest-neighbour downscale by 1/2ⁿ (note: `J2KDecoder.decodeResolution` throws `.notImplemented` — see J2KSWIFT_BUG_REPORT.md)
- [x] Add `--roi x,y,w,h` for post-decode crop (added `TerminalRenderer.cropImage()`; J2KROIDecodingOptions not needed)
- [x] Add `--volume` mode: multi-frame filmstrip via `renderThumbnailGrid()`
- [x] Add `--jpip URL` remote streaming mode (async `DICOMJPIPClient` bridged to sync CLI via `JPIPResultBox: @unchecked Sendable` + `DispatchSemaphore`)
- [x] Extend `README.md` with examples (`Sources/dicom-viewer/README.md` updated to v1.5.0)
- [x] Integration tests added — new `DICOMViewerTests` target in `Package.swift` with 16 new Phase 7 tests (all passing)

**Notes:**
- `J2KDecoder.decodeResolution` is not yet implemented upstream — `--reduce` uses post-decode downscale instead. Tracked in J2KSWIFT_BUG_REPORT.md.
- `dicom-viewer` version bumped to `1.5.0`

---

### Phase 8 — DICOMStudio (SwiftUI GUI) Integration

**Goal:** Give the macOS/iOS/visionOS demo viewer full v3 capabilities.

- [x] `DICOMStudio.Services.ImageDecodingService` uses `CodecRegistry` (no GUI changes needed for basic HTJ2K/Part 2 reading)
- [x] New "Codec" inspector panel: shows decoder used, backend (Metal/Neon/scalar), timing
- [x] Progressive decoding: display first resolution level, then refine (SwiftUI `Canvas` driven by `AsyncStream`) — implemented via post-decode downscale workaround (J2KDecoder.decodeResolution blocked upstream; see J2KSWIFT_BUG_REPORT.md). New files: `ProgressiveDecodeModel.swift`, `ProgressiveImageView.swift`, `ProgressiveDecodeTests.swift` (30+ tests). `ImageDecodingService` gains `decodeProgressively(file:)` AsyncStream API; `ImageViewerViewModel` (@MainActor) drives state machine (.quarter → .half → .complete).
- [x] ROI decoding hooked to pinch/zoom gestures (`isROIActiveOnZoom` + `updateROIOnZoom()`)
- [ ] JP3D MPR view (axial / sagittal / coronal) using `J2K3D` slice API — deferred to Phase 9
- [x] JPIP loader (URL bar → live stream via `DICOMJPIPClient`, progressive quality layers)
- [x] All new UI follows the GUI standards in `.github/copilot-instructions.md` (localisation, RTL, VoiceOver, Dynamic Type)
- [x] Update `DICOM_STUDIO_V2_MILESTONES.md` with a new milestone (Milestone 24, v2.1.0)

---

### Phase 9 — CLI Tools Expansion ✅ (9.1 + 9.2 complete)

#### 9.1 New tool: `dicom-j2k` ✅

Modelled on J2KSwift’s `j2k` CLI but operating on DICOM files.

| Sub‑command | Purpose |
|-------------|---------|
| `dicom-j2k info <file>`           | Show J2K/HTJ2K codestream metadata embedded in a DICOM file |
| `dicom-j2k validate <file>`       | ISO/IEC 15444‑4 conformance of the embedded codestream |
| `dicom-j2k transcode <in> <out>`  | J2K ↔ HTJ2K (bit‑exact); preserves DICOM metadata |
| `dicom-j2k reduce <in> <out>`     | Re‑encode at lower resolution/quality layers |
| `dicom-j2k roi <in> <out>`        | Extract an ROI frame into a new DICOM |
| `dicom-j2k benchmark <file>`      | Decode‑speed benchmark across codec backends |
| `dicom-j2k compare <a> <b>`       | PSNR / SSIM / MSE between two DICOM images |
| `dicom-j2k completions <shell>`   | bash / zsh / fish completions |

- [x] Add target + product in `Package.swift` (`.executable("dicom-j2k")`)
- [x] Create `Sources/dicom-j2k/` with `main.swift` (~670 lines, 8 subcommands)
- [x] Tests in `Tests/dicom-j2kTests/` — 53 tests across 8 suites

#### 9.2 Updates to existing CLI tools ✅ (partial)

| Tool | Change | Status |
|------|--------|--------|
| `dicom-compress` | HTJ2K codec names documented in `Compress` discussion; HTJ2K label shown in `info` output | ✅ Done |
| `dicom-convert`  | Target syntaxes `HTJ2KLossless`, `HTJ2KRPCLLossless`, `HTJ2K`, `JPEG2000Part2Lossless`, `JPEG2000Part2` | ✅ Already present |
| `dicom-info`     | New `=== JPEG 2000 Codestream Info ===` section via `--statistics`; capability check via `J2KHTInteroperabilityValidator` | ✅ Done |
| `dicom-validate` | New validation level 5: codestream conformance via `HTJ2KConformanceTestHarness` + `J2KHTInteroperabilityValidator` | ✅ Done |
| `dicom-3d`       | `encode-volume`, `decode-volume`, `inspect`, `mpr` backed by `JP3DCodec` | ⏳ Deferred to Phase 10 |
| `dicom-image`    | J2K passthroughs N/A — tool is image→DICOM; J2K operations live in `dicom-j2k` | N/A |
| `dicom-gateway`  | `--prefer-htj2k` N/A — gateway is HL7/FHIR↔DICOM converter, not DICOM network SCU/SCP | N/A |

---

### Phase 10 — Documentation, Benchmarks, Release

- [ ] Update `README.md` (Features, Architecture, Version note)
- [ ] Update `MILESTONES.md`: mark Milestone 24 items `[x]` as phases land
- [ ] Update `CHANGELOG.md` → v1.1.0 (minor bump: adds J2KSwift v3)
- [ ] Update `Documentation/ConformanceStatement.md` with the eight new UIDs
- [ ] Update `Documentation/Architecture.md` with the codec layering diagram
- [ ] Add `Documentation/JPEG2000_GUIDE.md` with usage, troubleshooting, benchmark tables
- [ ] Update `PERFORMANCE_GUIDE.md` with J2K/HTJ2K/JP3D benchmarks
- [ ] Tag `v1.1.0` and ship Homebrew formulas (`dicomkit`, `dicomtoolbox` updates)

---

## 4. Testing Strategy

| Layer | Framework | Coverage target |
|-------|-----------|-----------------|
| `J2KSwiftCodec` / `HTJ2KCodec` / `JP3DCodec` | XCTest (library tests) | 100 % public API |
| `CodecRegistry` priority + fallback | XCTest | branch coverage |
| DICOM fixtures decode | XCTest + fixture DB | 50+ sample files per modality |
| DICOMStudio ViewModels | Swift Testing | ≥ 95 % per `copilot-instructions.md` |
| CLI tools | XCTest + snapshot stdout | each sub‑command |
| Cross‑platform | CI macOS 14 / Linux 22.04 Swift 6.2 | green |
| Conformance | ISO/IEC 15444‑4 corpus via J2KSwift re‑export | all parts we claim |
| Interop | OpenJPEG + GDCM round‑trip scripts | 100 % bit‑exact lossless |

Fixtures live under `Tests/Fixtures/JPEG2000/` and are segmented by transfer syntax UID.

---

## 5. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| macOS 15 / Swift 6.2 floor breaks downstream users on macOS 14 | High (1× only) | Version DICOMKit as v2.0.0; ship release notes + migration guide; offer maintenance branch for v1.x users if needed |
| J2KSwift 3.x API changes in minor bumps | Medium | Pin `from: "3.2.0"` but run weekly CI against J2KSwift `main` |
| Removal of x86‑64 SIMD hurts Linux x86 perf | Low‑Medium | Vulkan backend for Linux GPU, scalar fallback, document perf delta |
| JP3D non‑standard in DICOM | High | Keep behind experimental SOP, clear warnings, no default serialisation |
| Larger binary footprint | Medium | Package traits let embedders opt out; document per‑module cost |
| ImageIO behavioural differences vs. J2KSwift | Low | Fallback chain + parity tests with PSNR guard |
| Breaking public API | Low | Deprecate rather than delete `NativeJPEG2000Codec`; keep two releases |

---

## 6. Acceptance Criteria (Milestone 24)

- [ ] DICOMKit compiles under `swift-tools-version: 6.2` with `macOS 15` floor (Milestone 1.0 prerequisite).
- [ ] `Package.swift` depends on `J2KSwift 3.2.0` (`from: "3.2.0"`) and resolves cleanly on macOS + Linux CI.
- [ ] All 8 DICOM JPEG 2000 transfer syntaxes (`.90`, `.91`, `.92`, `.93`, `.201`, `.202`, `.203`, + JPIP `.94`/`.95`) are registered, documented, and covered by round‑trip tests.
- [ ] `NativeJPEG2000Codec` is marked deprecated and only used as a fallback on Apple.
- [ ] `JP3DCodec` + `JP3DVolumeBridge` can round‑trip a 128‑slice CT lossless with bit‑exact output.
- [ ] `dicom-j2k` CLI is shipped with unit tests and `README.md`.
- [ ] `dicom-compress`, `dicom-convert`, `dicom-3d`, `dicom-send`, `dicom-retrieve`, `dicom-viewer` updated and tested.
- [ ] `DICOMStudio` renders HTJ2K + JP3D datasets with progressive/ROI decoding and honours all GUI accessibility/i18n standards.
- [ ] `README.md`, `MILESTONES.md`, `CHANGELOG.md`, and `Documentation/ConformanceStatement.md` updated per project post‑task rules.
- [ ] `swift test` green on macOS 14 + Ubuntu 22.04 (Swift 6.2) with new fixtures.

---

## 7. Execution Order & Dependencies

```
Phase 0 (branch) ─► Milestone 1.0 (platform/toolchain bump) ─┐
                                                             │
                                                             ├─► Phase 1 (SPM + adapter) ─► Phase 2 (HTJ2K) ─┬─► Phase 3 (Part 2)
                                                             │                                              │
                                                             │                                              └─► Phase 4 (JP3D)
                                                             │                                                     │
                                                             └─► Phase 5 (HW accel, parallel with 2/3/4)           │
                                                                         │
Phase 6 (JPIP) ◄─ depends on Phase 1 + Phase 4 for 3D JPIP ──────────────┘
Phase 7 (dicom-viewer CLI)  ◄─ depends on Phase 2 + Phase 4
Phase 8 (DICOMStudio)       ◄─ depends on Phase 2 + Phase 4 + Phase 6
Phase 9 (CLI tools)         ◄─ can start after Phase 1, incremental per sub-tool
Phase 10 (docs/release)     ◄─ runs continuously, finalises at tag time
```

---

## 8. References

- J2KSwift repository: <https://github.com/Raster-Lab/J2KSwift>
- J2KSwift v3.2.0 release notes: `RELEASE_NOTES_v3.2.0.md` (upstream, once published)
- Previous 3.x migration materials: `MIGRATION_GUIDE_v2.0.md` + `RELEASE_CHECKLIST_v3.0.0.md`
- Earlier 3.x release notes remain upstream for historical context
- DICOM PS3.5 Annex A — Transfer Syntaxes
- DICOM Supplement 211 — HTJ2K Transfer Syntaxes
- ISO/IEC 15444‑1 (Part 1), 15444‑2 (Part 2), 15444‑10 (JP3D), 15444‑15 (HTJ2K)
- Existing (superseded) plan: [J2KSWIFT_INTEGRATION_PLAN.md](J2KSWIFT_INTEGRATION_PLAN.md)
- DICOMKit copilot instructions: `.github/copilot-instructions.md`
