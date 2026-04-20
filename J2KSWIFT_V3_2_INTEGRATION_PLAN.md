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

This plan replaces DICOMKit's Apple‑ImageIO‑based `NativeJPEG2000Codec` with a pure‑Swift codec stack backed by **J2KSwift v3.2.0**, and extends the library, viewer, and CLI surface to cover the full DICOM JPEG 2000 family: **Part 1 (J2K)**, **Part 15 (HTJ2K)**, and **Part 10 (JP3D)** — plus JPIP streaming and JPEG XS exploration.

### 1.1 Why v3.2.0 (vs. the earlier baseline plan)

| Change in J2KSwift 3.x | Impact on DICOMKit |
|------------------------|--------------------|
| **Apple‑first architecture** — x86‑64 SIMD code paths removed in v3.0.0 | Simplifies build matrix; ARM64 macOS/iOS/visionOS + Linux ARM64 only for accelerated paths (scalar fallback elsewhere) |
| **J2KXS is a full codec** (Phase 20, 52 tests) | New optional JPEG XS transfer‑syntax exploration for DICOMKit |
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
| JPEG 2000 Part 2 Lossless | `1.2.840.10008.1.2.4.92` | ❌ | J2KCodec Part 2 |
| JPEG 2000 Part 2 Lossy | `1.2.840.10008.1.2.4.93` | ❌ | J2KCodec Part 2 |
| HTJ2K Lossless | `1.2.840.10008.1.2.4.201` | ❌ | J2KCodec HTJ2K |
| HTJ2K RPCL Lossless | `1.2.840.10008.1.2.4.202` | ❌ | J2KCodec HTJ2K + RPCL |
| HTJ2K Lossy | `1.2.840.10008.1.2.4.203` | ❌ | J2KCodec HTJ2K |
| JPIP Referenced | `1.2.840.10008.1.2.4.94` | ❌ | JPIP module |
| JPIP Referenced Deflate | `1.2.840.10008.1.2.4.95` | ❌ | JPIP + zlib |
| (Vendor) JP3D in multi‑frame wrapper | — | ❌ | J2K3D (experimental private SOP) |
| JPEG XS exploration | TBD | ❌ | J2KXS (behind trait) |

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
├── J2K3D            ─ JP3D volumetric (ISO/IEC 15444‑10)
└── J2KXS            ─ JPEG XS (ISO/IEC 21122) — optional
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
| `J2KXS`                | + `J2KXS`                              | opt‑in     |

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
- [ ] Gate `J2KMetal` / `J2KAccelerate` behind `#if canImport(Metal)` / `#if canImport(Accelerate)` *(deferred to Phase 5)*
- [ ] Gate `J2KVulkan` behind `#if canImport(Vulkan)` (Linux CI) *(deferred to Phase 5)*
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

### Phase 2 — HTJ2K Transfer Syntaxes (ISO/IEC 15444‑15)

**Goal:** Full support for the three DICOM HTJ2K transfer syntaxes end‑to‑end (library + network + CLI + viewer).

#### Milestone 2.1 — Transfer syntax model

- [ ] Add to `TransferSyntax`:
  - [ ] `.htj2kLossless` → `1.2.840.10008.1.2.4.201`
  - [ ] `.htj2kRPCLLossless` → `1.2.840.10008.1.2.4.202`
  - [ ] `.htj2kLossy` → `1.2.840.10008.1.2.4.203`
- [ ] `isHTJ2K`, `isEncapsulated`, `isLossless`, `displayName` updates
- [ ] Add to `TransferSyntax.allKnown`, `DICOMValidator`, `StorageSCP` presentation contexts
- [ ] Update `Sources/DICOMDictionary/UIDDictionary.swift`

#### Milestone 2.2 — `HTJ2KCodec`

- [ ] `Sources/DICOMCore/HTJ2KCodec.swift` implementing `ImageCodec` + `ImageEncoder`
- [ ] Internally delegates to `J2KEncoder` / `J2KDecoder` configured with `codingStyle: .htj2k`
- [ ] RPCL progression ordering wired for `.202`
- [ ] Register in `CodecRegistry` for all three UIDs
- [ ] Expose helper: `TransferSyntaxConverter.recommendHTJ2K(for: PixelDataDescriptor) -> TransferSyntax`

#### Milestone 2.3 — Transcoding

- [ ] `HTJ2KTranscoder` wrapping `J2KTranscoder` for bit‑exact J2K ↔ HTJ2K
- [ ] Extend `TransferSyntaxConverter` with fast‑path transcoding (no pixel decode)
- [ ] Benchmark: ≥ 5× decode speed‑up for HTJ2K vs. J2K on CT volumes

#### Milestone 2.4 — Network & Web

- [ ] `DICOMNetwork`: add HTJ2K to default SCP/SCU presentation contexts
- [ ] `DICOMWeb`: add `image/jph` and `image/jphc` media types; update `WADOURIClient` / `STOWRSClient`
- [ ] `dicom-retrieve` / `dicom-send`: accept `--transfer-syntax htj2k|htj2k-rpcl|htj2k-lossless`

**CLI smoke:**
```bash
swift test --filter HTJ2KCodecTests
dicom-compress compress ct.dcm -o ct.htj2k.dcm --codec htj2k-lossless
dicom-compress transcode ct.j2k.dcm --to htj2k -o ct.htj2k.dcm
dicom-send ct.htj2k.dcm --host pacs.local --port 11112 --aet TEST \
  --transfer-syntax htj2k-lossless
```

---

### Phase 3 — JPEG 2000 Part 2 Extensions

**Goal:** Support `.92` / `.93` Part 2 transfer syntaxes (MCT, arbitrary wavelet kernels).

- [ ] Transfer syntaxes `.jpeg2000Part2Lossless` / `.jpeg2000Part2`
- [ ] Extend `J2KSwiftCodec` with a `partConfiguration: .part1 | .part2` knob
- [ ] Gate Part 2 features behind `DICOMKit.allowJPEG2000Part2` flag (defaults to `true` on writer, permissive on reader)
- [ ] `dicom-compress`: `--codec j2k-part2[-lossless]`
- [ ] Test: Part 2 fixtures from J2KSwift conformance corpus

---

### Phase 4 — JP3D Volumetric Integration (ISO/IEC 15444‑10)

**Goal:** Represent multi‑frame CT/MR/PET/US volumes with **JP3D** inside DICOMKit for compact storage and fast ROI decode. JP3D in DICOM has no standard transfer syntax yet, so we expose it via:

1. **Private transfer syntax** for round‑trip testing (`1.2.840.10008.1.2.4.203.*` vendor extension — clearly labelled experimental).
2. **Encapsulated document SOP** (1.2.840.10008.5.1.4.1.1.104.1 or private) carrying a `.jp3d` blob, with JSON sidecar describing voxel geometry.
3. **Runtime‑only codec** that converts a DICOM multi‑frame series ↔ `J2K3D.J2KVolume` for viewer consumption.

#### Milestone 4.1 — Volume bridge

- [ ] `Sources/DICOMCore/JP3DVolumeBridge.swift`
  - [ ] `func makeVolume(from series: [DICOMFile]) throws -> J2KVolume`
  - [ ] `func makeDICOMSeries(from volume: J2KVolume, template: DICOMFile) throws -> [DICOMFile]`
  - [ ] Handles per‑slice `RescaleSlope`/`RescaleIntercept`, `SliceLocation`, `ImagePositionPatient`
  - [ ] Preserves `SeriesInstanceUID`, regenerates `SOPInstanceUID` per slice
- [ ] Validation: slice spacing uniformity, consistent rows/cols/bits stored

#### Milestone 4.2 — `JP3DCodec`

- [ ] `Sources/DICOMCore/JP3DCodec.swift` wrapping `JP3DEncoder` / `JP3DDecoder`
- [ ] Supports `compressionMode: .lossless | .losslessHTJ2K | .lossyHTJ2K(quality:)`
- [ ] Emits `.jp3d` blob + sidecar JSON (modality, voxel size, photometric)
- [ ] Round‑trip test on a 128‑slice CT phantom with < 0.01 HU max error (lossless)

#### Milestone 4.3 — Encapsulated SOP adapter

- [ ] Private SOP Class UID for “DICOMKit JP3D Volume (experimental)”
- [ ] Encapsulated‑document writer embeds `.jp3d` data
- [ ] Reader detects the SOP and returns a `JP3DVolume` alongside a synthetic multi‑frame `DICOMFile`
- [ ] Documented limitations + warning in `Documentation/ConformanceStatement.md`

#### Milestone 4.4 — Viewer‑time virtual decode

- [ ] `DICOMKit.openVolume(seriesURL:) async throws -> DICOMVolume` that:
  - [ ] Detects conventional multi‑frame series → returns uncompressed volume
  - [ ] Detects JP3D encapsulation → decodes on demand with slice‑lazy loading
- [ ] Progressive decoding via JPIP (see Phase 6) for huge CT/MR studies

**CLI smoke:**
```bash
swift test --filter JP3DCodecTests
dicom-3d encode-volume series/ -o volume.jp3d.dcm --lossless
dicom-3d decode-volume volume.jp3d.dcm -o out/ --format dicom
dicom-3d inspect volume.jp3d.dcm         # voxel grid, compression, tiles
```

---

### Phase 5 — Hardware Acceleration

**Goal:** Opportunistically use the best J2KSwift backend on each platform.

| Backend | Where | DICOMKit type |
|---------|-------|---------------|
| `J2KMetal`     | Apple (iOS 17+, macOS 14+, visionOS 1+) | `MetalJ2KCodec` |
| `J2KAccelerate`| Apple (all)                              | `AcceleratedJ2KCodec` |
| `J2KVulkan`    | Linux / Windows                          | `VulkanJ2KCodec` |
| `J2KCodec` (scalar) | everywhere (fallback)                | `J2KSwiftCodec` |

- [ ] Add `CodecPriority` enum; registry ranks codecs on init
- [ ] Runtime Metal device probe on Apple; if unavailable fall through to Accelerate then scalar
- [ ] Per‑codec micro‑benchmarks recorded in `Benchmarks/j2k_v3/` (CSV)
- [ ] `--gpu`, `--simd`, `--scalar` flags on `dicom-compress` and `dicom-3d` for diagnostic forcing
- [ ] Tests ensure identical pixels across backends (hash parity on lossless)

---

### Phase 6 — JPIP Streaming

**Goal:** Progressive 2D + 3D streaming for remote studies and huge WSI/CT datasets.

- [ ] Optional dependency on `JPIP` module (trait `JPIP`)
- [ ] `DICOMJPIPClient` wrapping JPIP session; maps WADO‑URI + JPIP URL templates
- [ ] Transfer syntaxes `.jpip` (`.94`) and `.jpipDeflate` (`.95`)
- [ ] `dicom-viewer` (terminal) shows live resolution‑progressive ASCII preview via JPIP
- [ ] `DICOMStudio`: JPIP study loader (quality/resolution slider wired to JPIP session)
- [ ] CLI tool `dicom-jpip` (new) with `server` and `client` subcommands mirroring J2KSwift’s `j2k jpip`

---

### Phase 7 — DICOMKit `dicom-viewer` CLI Upgrade

**Goal:** The terminal viewer decodes and displays every JPEG 2000 flavour.

- [ ] Rewire `TerminalRenderer` to pull pixels through `CodecRegistry` (so HTJ2K/Part 2 work automatically)
- [ ] Add `--reduce <n>` for low‑res fast preview via J2KSwift progressive decoding
- [ ] Add `--roi x,y,w,h` for ROI decode (uses `J2KROIDecodingOptions`)
- [ ] Add `--volume` mode: iterate JP3D slices with ←/→, space to toggle MIP projection
- [ ] Add `--jpip URL` remote streaming mode
- [ ] Extend `README.md` with examples
- [ ] Integration tests (headless) using fixtures

---

### Phase 8 — DICOMStudio (SwiftUI GUI) Integration

**Goal:** Give the macOS/iOS/visionOS demo viewer full v3 capabilities.

- [ ] `DICOMStudio.Services.ImageDecodingService` uses `CodecRegistry` (no GUI changes needed for basic HTJ2K/Part 2 reading)
- [ ] New “Codec” inspector panel: shows decoder used, backend (Metal/Neon/scalar), timing
- [ ] Progressive decoding: display first resolution level, then refine (SwiftUI `Canvas` driven by `AsyncStream`)
- [ ] ROI decoding hooked to pinch/zoom gestures
- [ ] JP3D MPR view (axial / sagittal / coronal) using `J2K3D` slice API
- [ ] JPIP loader (URL bar → live stream)
- [ ] All new UI follows the GUI standards in `.github/copilot-instructions.md` (localisation, RTL, VoiceOver, Dynamic Type)
- [ ] Update `DICOM_STUDIO_V2_MILESTONES.md` with a new milestone

---

### Phase 9 — CLI Tools Expansion

#### 9.1 New tool: `dicom-j2k`

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

- [ ] Add target + product in `Package.swift` (`.executable("dicom-j2k")`)
- [ ] Create `Sources/dicom-j2k/` with `main.swift`, sub‑command files, `README.md`
- [ ] Tests in `Tests/dicom-j2kTests/`

#### 9.2 Updates to existing CLI tools

| Tool | Change |
|------|--------|
| `dicom-compress` | `--codec htj2k[-lossless|-rpcl]`, `--codec j2k-part2[-lossless]`, `--backend metal|accelerate|vulkan|scalar`, `transcode` sub‑command |
| `dicom-convert`  | New target syntaxes `HTJ2KLossless`, `HTJ2KRPCLLossless`, `HTJ2K`, `JPEG2000Part2Lossless`, `JPEG2000Part2` |
| `dicom-3d`       | `encode-volume`, `decode-volume`, `inspect`, `mpr` sub‑commands backed by `JP3DCodec` |
| `dicom-diff`     | Pixel diff honours new transfer syntaxes (no code change expected once registry is swapped — verify via tests) |
| `dicom-retrieve` / `dicom-send` / `dicom-qr` / `dicom-wado` | Negotiate HTJ2K presentation contexts by default; new flags |
| `dicom-info`     | New “JPEG 2000” section: part, progression, layers, tiles, HTJ2K flag |
| `dicom-validate` | Include J2KSwift codestream validator for encapsulated pixel data |
| `dicom-image`    | `--reduce`, `--roi`, `--layers` passthroughs to J2KSwift |
| `dicom-gateway`  | Advertise HTJ2K + JPIP; add `--prefer-htj2k` |

All changes must come with unit tests in the corresponding `Tests/*Tests` target.

---

### Phase 10 — JPEG XS Exploration (optional, trait‑gated)

**Goal:** Prototype ISO/IEC 21122 (JPEG XS) behind a `J2KXS` trait — no DICOM transfer syntax exists yet, so this is exploratory only.

- [ ] Opt‑in product dependency `J2KXS`
- [ ] `ExperimentalJPEGXSCodec` encapsulated in a private transfer syntax
- [ ] Documentation: clearly marked *experimental, non‑conformant*
- [ ] Track DICOM standard ballot progress

---

### Phase 11 — Documentation, Benchmarks, Release

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
Phase 10 (JPEG XS)          ◄─ optional, last
Phase 11 (docs/release)     ◄─ runs continuously, finalises at tag time
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
