# Changelog

All notable changes to DICOMKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### DICOM Print tool (`dicom-print`) — features + fixes

- **`--layout` now honored (bug fix):** the flag was parsed and echoed but never
  applied — `send` always used the automatic layout. `printImages` gained an
  optional explicit `layout:` override (nil = existing auto-layout) and the CLI
  now threads `--layout` through. A single image with an explicit `--layout` is
  routed accordingly.
- **`--color` added (gap fix):** the CLI always printed grayscale because
  `PrintConfiguration.colorMode` was never set. Added `--color grayscale|color`
  on `send`, which negotiates the Color Print Management Meta SOP Class and sends
  color image boxes.
- **Conformant image descriptors:** `send` now extracts per-image attributes
  (rows, columns, bits allocated/stored, high bit, samples per pixel, pixel
  representation, photometric interpretation) from each dataset and sends them in
  the N-SET Preformatted Image Sequence (PS3.3 C.13.5.1). Previously required
  image attributes were omitted.
- **N-EVENT-REPORT reception:** the Print SCU now receives, decodes, and
  acknowledges asynchronous printer/print-job notifications pushed by the SCP
  (Printer SOP Class status; Print Job SOP Class progress). New `PrintEvent`,
  `PrinterEventType`, `PrintJobEventType`, and a `PrintEventHandler` callback
  wired through `printImage`/`printImages`. `dicom-print send` prints faults
  always and routine progress in `--verbose`. This also fixes a latent
  correctness bug where an interleaved event could be mis-parsed as the awaited
  DIMSE response.
- **Build:** the `dicom-print` target was excluded from `Package.swift` and had
  drifted out of compilability (`DICOMParser`/`data(for:)` no longer existed,
  `@Sendable` capture errors). Repaired to use `DICOMFile.read(from:force:)`.
- **Layout presets + retry:** `dicom-print send` gained `--template`
  (single/comparison/grid/multi-phase — sets layout + film size + orientation,
  routed through the conformant single-association path) and `--retries N`
  (retry on connection/setup failure with exponential backoff; a submitted job
  is never retried, so no duplicate prints).
- **Presentation LUT:** added `PresentationLUTShape` and a `presentationLUTShape`
  print option. When set, the workflow N-CREATEs a Presentation LUT SOP Instance
  (part of the Grayscale/Color Print Management Meta, so no extra presentation
  context) and references it from each film box (Referenced Presentation LUT
  Sequence, 2050,0500). CLI: `--presentation-lut identity|inverse|lin-od`.
- **Annotation boxes:** added `PrintAnnotation` and `annotations` /
  `annotationDisplayFormatID` print options. The workflow sets Annotation Display
  Format ID on the film box and N-SETs each Basic Annotation Box (position + text)
  using a new sequence-scoped UID parser so annotation-box UIDs are not confused
  with image-box UIDs. CLI: repeatable `--annotate <text>` + `--annotation-format
  <id>`. Note: the Annotation Display Format ID is printer-specific.
- **Overlay box scaffolding:** added the Basic Print Image Overlay Box SOP Class
  UID and Referenced Image Overlay Box Sequence tag; full overlay-plane extraction
  remains a follow-up.

### Tests

- **Re-enabled the `DICOMNetworkTests` target** (was excluded from `Package.swift`),
  so print logic — including the new Presentation LUT / annotation / N-EVENT-REPORT
  code — is covered again (177 tests). The rotted, live-PACS `PACSIntegrationTests`
  is quarantined via `exclude:` until ported to the current API; two outdated
  MONOCHROME1 `ImagePreprocessor` expectations are `XCTSkip`-quarantined pending a
  product decision on 8-bit vs 16-bit print output.

### Fixed — Bug review pass (library crashes/correctness + CLI hardening)

- **STOW-RS server (critical):** the multipart parser decoded the entire body as UTF-8
  before splitting, so binary `application/dicom` uploads (almost never valid UTF-8)
  parsed to zero parts and were silently dropped while the server still reported
  success; rare bodies that did decode were corrupted by whitespace-trimming raw bytes.
  Now uses the same byte-scanning `MultipartMIME` parser as the client. See `BUG_REVIEW.md` (C1).
- **SIMD window/level:** `applyWindowLevel` passed a positive offset instead of
  `-minValue` into the vDSP scalar-add, blowing out every image rendered through the
  fast path. `PerformanceTests/SIMDImageProcessorTests.swift` had also silently dropped
  out of the build (excluded in `Package.swift`), so the regression test for this never
  ran; both are now fixed and back in the build. See `BUG_REVIEW.md` (H1).
- **Crash hardening:** bounds-check encapsulated pixel-data fragment lengths before
  slicing (`TransferSyntaxConverter`), handle empty/dot-only `TM` values (`DICOMTime`),
  tolerate duplicate tags inside a sequence item (`SequenceItem`), and guard a
  double-`resume()` race in the Storage SCP association handshake (`StorageSCP`). See
  `BUG_REVIEW.md` (H2, H3, M3, H4).
- **Correctness:** `allowMissingVR` in the DICOM JSON decoder had its condition
  inverted and never inferred a VR from the dictionary; `AT`-valued elements were
  byte-swapped as a single 32-bit word instead of two ordered 16-bit words on
  cross-endian transcode (also added missing `OD`/`OL`/`SV`/`UV` to the numeric-VR
  swap set); the data element dictionary loader dropped rows with an empty `Name`
  field (`(0018,0061)`, `(0400,0315)`, `(300A,0782)`). See `BUG_REVIEW.md` (M1, M2, M4).
- **Hardening:** segmentation palette index underflow on `segmentNumber == 0`,
  slice-unsafe absolute-index reads in `ByteOrder`/`PaletteColorLUT` (now relative to
  `startIndex`), non-ASCII digits accepted in UID validation, and a 3-byte G1 escape
  sequence unrecognized at end-of-buffer. See `BUG_REVIEW.md` (L1-L4, M5).
- **CLI / DICOMStudio Workshop parity:** rejected negative `--frame`/`--retry`/
  `--parallel`/`--batch` values that previously reached a trapping range or stride
  instead of erroring cleanly; `dicom-anon` and its app equivalent now require
  `--output` (or `--dry-run`) instead of silently doing nothing; directory converts in
  `dicom-convert` now retag non-DICOM output files with the correct extension per file
  (previously only the single-file path did); reversed `--select` ranges in `dicom-qr`
  no longer trap; study-level C-GET with `--hierarchical` now recovers the series UID
  from the received dataset instead of collapsing to a flat layout; `dicom-split` now
  reports real per-file failure counts and exits non-zero when any file failed. See
  `BUG_REVIEW.md` ("CLI / DICOMStudio Workshop hardening").

## [2.2.10] - 2026-07-15

### Added — J2K GPU/CPU Encode Route Planner

- Introduced `J2KRoutePlanner`, which resolves the three previously conflated encode
  choices — backend (`CPU`/`GPU`/`auto`), intent (`lossy`/`lossless`/`lossless-only`),
  and compression type (JPEG 2000 Part-1/Part-2/HTJ2K) — into a single deterministic
  J2KSwift API call instead of reverse-engineering them from the transfer-syntax UID.
  `auto` now genuinely selects the Metal GPU backend for lossy JPEG 2000/HTJ2K encodes
  where previously it never did. See `J2K_ROUTING_ARCHITECTURE.md`.
- JPEG 2000 Part-2 (`.92`/`.93`) *encoding* is explicitly rejected with a clear error —
  the pinned J2KSwift v11.0.2 cannot decode the Part-2 codestreams it encodes — while
  *decoding* existing Part-2 files remains fully supported; the real-Part-2 encode path
  is gated behind a flag for when the library gains decode support.
- Updated `CodecBackend`/`CompressionManager`/`CompressionConsole` wiring and added
  `J2KRoutePlannerTests` and `J2KGPUEncodeRoundTripTests` covering the new routing
  decisions and GPU round-trip correctness.

### Added — CharLS (dcmdjpls) JPEG-LS Bench Peer, `repro12bit` Repro Tool

- Added `CharLSCLICodec` (macOS-only), a decode-only DICOMStudio bench peer that wraps DCMTK's
  `dcmdjpls` to cross-validate JLSwift-produced JPEG-LS codestreams against a CharLS-backed
  reference decoder, matching the existing `binaryPath`/`version`/`decodeFrame` surface used by
  the other CLI peers (djpeg/djxl/Kakadu/Grok).
- `J2KTestBenchModels`/`J2KTestBenchService`/`J2KTestBenchViewModel`/`J2KTestBenchView`: wired
  `.charls` through the JPEG-LS bench family (`includeCharLS`), and `J2KBenchSyntax.all` is now
  derived entirely from `TransferSyntax.selectableEncodings` for every format (previously only
  JPEG 2000/HTJ2K rows were catalog-driven), excluding JPEG XL JPEG Recompression (`.111`) since
  the bench encodes raw frames rather than repacking an existing JPEG.
- Added `repro12bit`, a standalone executable target for reproducing/isolating 12-bit codec
  issues against J2KSwift, alongside `JLISWIFT_GAP_ANALYSIS.md` documenting a verified bit-depth,
  color/sampling, and gap audit of the JLISwift dependency (no critical/high findings).
- `CompressionQuality.expectedMinPSNRDb` gives each encode preset (`.low`/`.medium`/`.high`/
  `.maximum`, and `.custom` via interpolation) a conservative minimum-PSNR pass bar for lossy
  round-trip tests, so the bench's `lossyPSNRThresholdDb` default now tracks
  `J2KTestBenchService.lossyEncodeQuality` instead of a fixed 40 dB value a lower-quality preset
  could never clear.
- `ModalityMapping.StandardModality`/`allCodes` centralizes the canonical DICOM modality list;
  the CLI Workshop's modality pickers (C-FIND/C-MOVE/MWL/etc.) now draw their `allowedValues`
  from it instead of hand-maintained arrays, so new modalities need updating in one place.

### Fixed — Same-syntax lossy recompression silently dropped `--quality`

- `CompressionManager.isRecompression`/`compressData`/`compressDataWithMetrics` now treat a
  same-UID lossy target with an explicit `quality` as a genuine recompression (decode-to-native
  + re-encode) rather than a byte passthrough. Previously, re-compressing an already-JPEG-2000
  (or other lossy-encapsulated) file into the *same* transfer syntax UID with a new `--quality`
  silently copied the existing codestream through unchanged (input size == output size, ~0 ms),
  discarding the requested quality. Lossless / no-quality same-syntax targets keep the
  passthrough. `dicom-compress` and the DICOMStudio Workshop both pass `quality` through to
  `isRecompression` so their two-phase-recompression UI note stays accurate.

### Fixed — Standalone macOS packaging

- Removed the DICOMStudio-only OpenJPEG comparison wrapper from `DICOMCore`'s
  default dependency graph. Standalone macOS consumers no longer require a
  Homebrew installation or the absolute `/opt/homebrew/lib/libopenjp2.a` path.
- Removed the corresponding DICOMStudio static-link and arm64-only Xcode settings;
  production JPEG 2000 support continues to use J2KSwift.
- Optional real-image codec and benchmark tests now report as skipped when the
  gitignored `LocalDatasets` or `SampleStudies` corpora are unavailable in CI.

### Changed — J2KSwift v11.0.2

- Updated the JPEG 2000 / HTJ2K / JP3D dependency floor to J2KSwift v11.0.2.
- The decoder-only update stops truncated quality-layer decoding at the exact
  coding-pass boundary and bounds scratch clearing to the active code-block region,
  without changing the DICOMKit public API or codestream format.

### Added — JPEG Baseline Encoder Choice (DICOMStudio-only)

- Added `JPEGCodecEngine` (DICOMCore: `.jli` / `.native`) and
  `CodecRegistry.encoder(for:engine:)`, which honours the engine selection **only** for
  JPEG Baseline (1.2.840.10008.1.2.4.50) — the one transfer syntax this library can encode
  two ways: the pure-Swift `JLICodec` (the registry default for all four JPEG syntaxes) or
  Apple's `NativeJPEGCodec` (ImageIO). JPEG Extended/Lossless/Lossless SV1 have no second
  encoder, so `engine` is a no-op for them.
- Threaded `jpegEngine` through `CompressionManager.compressData` /
  `compressDataWithMetrics`, defaulting to `.jli` so `dicom-compress` output is unchanged.
- Added an internal "JPEG Engine" picker to the DICOMStudio CLI Workshop's `dicom-compress`
  form, visible only for `operation == compress && codec == jpeg` — a benchmarking aid with
  no `dicom-compress` CLI counterpart, so it never appears in the copy-pasteable command
  preview. Required a new `CLIParameterDefinition.visibleWhenAll` ([`[CLIParameterVisibilityCondition]`],
  ANDed with the existing single-condition `visibleWhen`) since `codec` persists across
  operations and a single condition couldn't pin the picker to compress-only.
  `CommandBuilderHelpers.isVisible(...)` is now the one predicate shared by command-preview
  generation, required-field validation, and the ViewModel's form rendering.

### Fixed — `dicom-convert` to DEFLATE dropped pixel data from encapsulated sources

- An encapsulated source (JPEG/JPEG 2000/RLE/…) converted to Deflated Explicit VR Little
  Endian is now decoded to native pixels first. DEFLATE (PS3.5 A.5) is a data-set-level
  codec over a *native* stream — it has no encapsulated form — but `DICOMConverter` used to
  serialize the encapsulated (7FE0,0010) straight into the deflate stream: the codestream
  survived, but the output was labelled 1.2.840.10008.1.2.1.99 while still carrying an
  undefined-length, Item-fragmented pixel element, so no conformant reader (including
  DICOMKit's own) could decode pixel data from it — and the tool reported success.

### Fixed — `dicom-compress`/`dicom-convert` `--output` naming a directory failed with "Is a directory"

- Both CLIs now resolve `--output` through the existing `OutputPathResolver` (already used
  elsewhere) before writing, so passing a directory (e.g. `~/Desktop/DICOM_Output/`, or
  whatever the DICOMStudio Workshop's Browse button hands back) writes the input's filename
  into that directory instead of failing. An explicit file path is still used verbatim.

### Fixed — DICOMStudio CLI Workshop could build/compare against a different checkout's DICOMKit

- `CLIToolBuilder.repoRoot()` and `CLIToolTerminalCompare.locateBinary()` no longer fall back
  to a hard-coded absolute path or the process's working directory (which is `/` for a GUI
  app). They now resolve the SwiftPM package root by walking up from `#filePath` — the
  checkout the running app was actually compiled from — so `swift build`/binary lookup can
  no longer silently target a sibling repo whose DICOMKit accepts different tokens, which
  previously made "Compare CLI" report diffs that didn't exist in the current repo.

### Added — Transfer-Syntax Lossy/Lossless Split and Encode-Intent Threading

- Introduced `LosslessCapability` (`losslessOnly`/`lossyOnly`/`both`), `EncodingIntent`, and
  `SelectableEncoding` on `TransferSyntax` to correctly model the JPEG 2000/HTJ2K/JPEG XL
  "general" UIDs (`.91`/`.93`/`.203`/`.112`), which per PS3.5 may carry either a lossy or
  lossless codestream. `TransferSyntax.parse()` itself remains conservative (bare
  `…-lossless` still maps to the old reversible-only UID, to avoid changing association
  negotiation behavior in dicom-send/retrieve/qr) — the lossy/lossless split is exposed only
  through the new `parseEncoding()` API.
  See `J2K_HTJ2K_TRANSFER_SYNTAX_SPLIT_PLAN.md`.
- Added missing `UIDDictionary` entries and corrected display names for `.92`/`.93`/`.201`/
  `.202`/`.203` (e.g. "JPEG 2000 Lossless Only", "HTJ2K Lossless Only (RPCL)").
- Threaded `EncodingIntent` from CLI/app codec-name resolution through to `JXLCodec` and
  `DICOMConverter`, so `…-lossless` codec names now genuinely encode reversibly into the
  general UID (previously not possible) and `…-lossy` produces true irreversible compression.
  See `J2K_HTJ2K_JXL_ENCODE_INTENT_AND_LOSSY_ATTRS_PLAN.md`.
- Added `CompressionManager.applyLossyImageCompressionAttributes`, shared by `dicom-compress`
  and `dicom-convert`, which stamps Lossy Image Compression (0028,2110), Method (0028,2114),
  and Ratio (0028,2112) plus Image Type → DERIVED per PS3.3 C.7.6.1.1.5, with
  append/once-lossy-always-lossy semantics.
- `JXLCodec`: added signed 16-bit support (JXLSwift `int16` level-shift) and genuine lossy
  VarDCT grayscale encoding (JXLSwift 1.4.0) instead of silently falling back to lossless.

## [2.2.9] - 2026-07-15

### Fixed — SwiftPM consumer build hygiene

- Declared the `dicom-3d` and `dicom-j2k` target README files as excluded package
  inputs, removing the two unhandled-file warnings emitted during consumer builds.
- Declared the intentionally inactive complements of the explicitly sourced
  `DICOMKitTests` and `DICOMViewerTests` targets as excluded inputs, removing two
  package-planning warnings covering 102 test files without changing test membership.
- Applied the existing optional-fixture contract to two HTJ2K benchmark tests so
  clean CI checkouts skip them when the gitignored MR corpus is unavailable.
- Hardened release validation to reject production compiler warnings and test
  package-planning warnings, synchronized the release artifact matrix with all
  36 enabled CLI products, pinned manual release jobs to the requested tag, and
  staged release creation as a draft before publication for immutable releases.
- No decoder, runtime, product API, ABI, or command behavior changed.

## [2.2.6] - 2026-07-09

Patch release: shared transfer-syntax negotiation token list for `dicom-retrieve`/`dicom-qr`,
plus two reporting-accuracy fixes (`--backend`, `dicom-compress info` lossless state). No
association-negotiation or encode-behavior changes — this release only corrects what tools
report and what token lists they offer.

### Added — Shared transfer-syntax negotiation token list

- Added `TransferSyntax.negotiableImageSyntaxTokens` / `negotiableImageTokens` (DICOMCore) as
  the single source of truth for the transfer-syntax lists offered by the UID-only negotiation
  tools (`dicom-retrieve`, `dicom-qr`) — the negotiation analogue of
  `CompressionManager.supportedCodecs()` (dicom-compress) and `DICOMConverter.cliTokens`
  (dicom-convert). Every token round-trips through `TransferSyntax.parse()` (enforced by tests).
- Wired the DICOMStudio CLI Workshop `dicom-retrieve` / `dicom-qr` transfer-syntax pickers and
  the `dicom-retrieve` / `dicom-qr` CLI `--transfer-syntax` help onto that shared list, so both
  surfaces stay in lockstep. This adds the previously-missing JPEG-LS, JPEG XL, and JPEG 2000
  Part 2 (plus `explicit-vr-be`, `deflate`, `jpeg-extended`, `jpeg-lossless-sv1`) syntaxes that
  the old hand-maintained lists stopped short of; regenerated the `CLIContracts.json` parity
  golden to match.
- CLI Workshop: the `dicom-convert` transfer-syntax dropdown now shows the short kebab aliases
  (`DICOMConverter.aliasTokens`, e.g. `jpeg2000-lossless`, `htj2k-lossy`) instead of the CamelCase
  `cliTokens`, so it reads the same as the `dicom-compress` / `dicom-retrieve` / `dicom-qr`
  dropdowns. The `dicom-convert` CLI resolves the kebab alias identically, so the generated
  command and in-process execution are unchanged.

### Fixed — `dicom-compress info` reports the true lossless state for general J2K/HTJ2K/JXL UIDs

- `CompressionManager.getCompressionInfo` now derives `isLossless` (and the transfer-syntax
  display name) from Lossy Image Compression (0028,2110) for the `both`-capable general UIDs
  (`.91`/`.93`/`.203`/`.112`), instead of the UID-level flag which always reported "Lossy".
  A file reversibly encoded into a general UID (e.g. `--codec jpeg2000-lossless` → `.91`) now
  reports `Transfer Syntax: JPEG 2000 Lossless` / `Lossless: Yes` on both `dicom-compress info`
  surfaces (text + `--json`) and in the CLI Workshop, so the name and the Lossless line no
  longer contradict each other. Single-capability UIDs (e.g. `.90`, `.50`) are unchanged —
  their UID is authoritative. Reference: PS3.3 C.7.6.1.1.5.

### Fixed — `--backend` reporting reflected the hardware probe, not the actual encode path

- Added `CodecBackendPreference.effectiveEncodeBackend(isLossless:isJPEG2000Family:)` (DICOMCore)
  and `CompressionConsole.compressBackend(codec:preference:)` (DICOMKit), which report the backend
  the encoder will **actually** dispatch to rather than the best available hardware.
  `J2KSwiftCodec` only takes the Metal GPU path for a genuinely lossy JPEG 2000/HTJ2K encode — the
  lossless GPU path isn't bit-exact on 12/16-bit medical data — so `auto`/`--backend metal` on a
  lossless or non-J2K encode previously reported "Metal (GPU)" in `dicom-compress`/CLI Workshop
  verbose output even though the encode ran on the CPU. An explicit `--backend metal` request that
  can't use the GPU is now downgraded to the CPU backend with an explanatory note instead of
  silently misreporting.
- `CodecBackend.accelerate.displayName` now reports "Accelerate (CPU)" instead of the stale
  "Accelerate (not available)" on platforms where Apple's `Accelerate` framework is present but the
  old J2KAccelerate SIMD-family probe (removed in J2KSwift v11.0.0) no longer exists.

## [2.2.1] - 2026-07-06

Patch release: strict-concurrency bridge fix plus package-wide warning cleanup.
Both `swift build` and `swift build -Xswiftc -warnings-as-errors` pass cleanly;
no runtime behavior changes.

### Fixed — Swift 6 Strict-Concurrency Task Bridge in CLI Targets

- Fixed the `DispatchSemaphore` + `Task {}` async-to-sync bridge pattern used by CLI entry points so Swift 6 strict-concurrency no longer flags data-race sendability risks for `waitForTask`/`runAsync` helpers. The bridge now uses `Task.result` and an explicitly documented manually-synchronized capture (`nonisolated(unsafe)`), preserving runtime behavior while satisfying the compiler's model.
- Updated affected targets:
  - `Sources/dicom-jpip/main.swift`
  - `Sources/dicom-3d/main.swift`
  - `Sources/dicom-j2k/main.swift`
  - `Sources/dicom-viewer/main.swift`
- Also cleaned up adjacent strict/warnings-as-errors diagnostics surfaced during validation in shared runtime files (`ScriptEngine`, `DICOMDIRReader`/`DICOMDIRWriter`, `ImagePreprocessor`, `ImageResizer`, `JP3DVolumeBridge`, `JP3DVolumeDocument`, `StudyManager`, gateway mapping/converter helpers, and compression manager) without changing intended behavior.

### Fixed — Remaining `-warnings-as-errors` Diagnostics Across the Package

- `dicom-3d`: never-mutated `var` locals converted to `let` (`VolumeExport`, `MPRGenerator`); redundant `try`/`try?` removed from non-throwing `DataSet` accessor calls (`VolumeData`).
- `DICOMWeb`: redundant `await` removed from synchronous same-isolation calls (`ConformanceStatementGenerator`, `HTTPConnectionPool`, `HTTPRequestPipeline`); unused `guard let url` binding replaced with a `URL(string:) != nil` existence test (`DICOMJSONDecoder`); unused locals dropped (`CompressionMiddleware`, `HTTPRequestPipeline`).
- `DICOMStudio`: pure static J2K test helpers marked `nonisolated` — they already executed off the main actor at runtime (`J2KTestingViewModel`); pipe-drain captures in `CLIToolTerminalCompare` use the same documented `nonisolated(unsafe)` + happens-before pattern as the CLI bridge; cine timer callback wrapped in `MainActor.assumeIsolated` (timer is scheduled on the main run loop); slider `Binding` setters pass closures instead of non-`@Sendable` function values (`DICOMVolumeViewerView`, `JP3DComparisonView`, `JP3DVolumeComparisonView`); unused locals removed (`CLIWorkshopViewModel`, `JP3DMPRView`).

## [2.2.0] - 2026-07-04

CLI parity harness, JPEG XL lossy/recompression, and round-trip regression suite.

### Changed — P2/P3 Console-Builder and Dir-Walk Dedup (2026-07-04)

Follow-up to the remediation batch: every remaining hand-duplicated console block and directory
walk now lives in one shared builder/gatherer that both the CLI and the Workshop call, so the two
surfaces can no longer drift (`CLI_TOOLS_SHARED_CORE_VERIFICATION.md` → *P — duplication*).

- **New shared console builders (CLI text canonical):** `AnonConsole` (+ shared
  `Anonymizer.parseFlexibleTag`), `PixelEditConsole`, `ImageConsole`, `ExportConsole`,
  `UIDConsole`, `CompressionConsole.infoText/infoJSON/backendsText/backendsJSON`,
  `NetworkConsole` qr-line additions, `UPSConsole` (DICOMWeb), and
  `NetworkConsole.mwlCreateDetailBlock` (dedups the app's HL7/REST MWL-create branches).
- **New shared gatherers:** `FileGatherer.regularFiles(under:recursive:)` (sorted,
  content-agnostic walk — anon/validate/convert/pdf/export/image on both surfaces) and
  `FrameMerger.gatherInputFiles(from:recursive:)` + `FrameMerger.isDICOMFile` (dicom-merge).
- **Real drift found and fixed while hoisting** (all previously hiding in un-goldened paths):
  the app's pixedit executor double-printed the Image line, added an "Edited pixel data:" line
  and a byte-size suffix the CLI never prints; anon's per-file verbose text and single-file
  failure behavior differed from the CLI; UPS create-workitem/change-state used app-invented
  wording instead of the CLI's response text; dicom-merge sorted its inputs in-app but not in
  the CLI, so merged instance order could differ between surfaces (both now sort).
- **Deterministic batch order:** all shared walks sort by path, so directory-mode output order
  is stable run-to-run on both surfaces (previously filesystem enumeration order).
- App-only additions that have no CLI counterpart (sandbox redirect notes, UPS pre-flight
  guidance and error hints, MWL create banners) are unchanged.

### Changed — Three-Axis Shared-Core Remediation Batch (2026-07-04)

Follow-up to the three-axis verification of all 40 tools (`CLI_TOOLS_SHARED_CORE_VERIFICATION.md`,
full per-claim outcomes in its *Remediation outcomes* section). Eleven tools were held by user
triage (measure, viewer, 3d, ai, report, gateway, cloud, server, j2k, jpip, print) and the network
port/hostname workflow was left untouched as planned. Highlights:

- **New shared surfaces (CLI + Workshop call one implementation):**
  - `DataExchangeWorkflow` (DICOMWeb) — the entire dicom-json/dicom-xml pipeline (default output
    path, always-write-file behavior, tag filtering, metadata-only, verbose lines). Fixes the app's
    divergent print-to-console/refuse-reverse behavior.
  - `ConvertConsole` (DICOMKit) — dicom-convert's terse console (transcode line, batch ✓/✗ +
    `Conversion complete:` summary); the app's extra Read/Wrote/Transfer-Syntax chrome removed.
  - `TagEditConsole` (DICOMKit) — dicom-tags change block + `Output written to:` completion line
    (the app previously printed an unconditional count and `Saved:`).
  - `QRSessionState` (DICOMNetwork) — dicom-qr's save-state model hoisted from the executable;
    `--save-state` now also works in the Workshop and app-saved states resume via `dicom-qr resume`.
  - App validate now renders via the shared `ValidationReport` (the drifted app copy with its
    `Exit code:` annotation block was deleted); app compress batch uses the shared
    `findDICOMFiles`; app uid/pixedit call the shared `validateFileUIDs`/`parseRegion`.
- **Formerly-inert flags implemented:** `dicom-merge --format enhanced-ct/mr/xa` (Enhanced SOP
  Class + Shared/Per-frame Functional Groups), `dicom-script run --parallel` (concurrent pipeline
  commands with source-order output replay), `dicom-compress --backend`
  (`CompressionConfiguration.forcedBackend` → J2K/HTJ2K Metal GPU encode; other codecs unaffected),
  `dicom-image --use-exif` under `--split-pages` (per-page EXIF), `dicom-dcmdir update`
  (real implementation via `DICOMDIRWorkflow.updateDirectory`), `dicom-query
  --referring-physician` (now a study-level C-FIND matching key on both surfaces).
- **Removed (declared no-ops):** `dicom-json --format standard|dicomweb` and `--stream` (goldens
  proved byte-identical output for every value; the encoder always emits the DICOMweb PS3.18 JSON
  model); the app-only qido timeout field.
- **Wire/exit-code correctness:** app mpps update no longer sends a `studyInstanceUID` the CLI
  never sets; anon in-app exit code is now structured (any failed file → 1) instead of sniffed
  from output text; dump's No-Color toggle is honored (defaults ON in-app with a truthful
  `--no-color` preview).
- **Surface adds:** uid regenerate accepts multiple inputs in-app (cross-file UID mapping like the
  CLI); ups gains the CLI's `--create <json-file>` form; qido gains `--verbose`.
- **New round-trip oracles:** merge enhanced-format (SOP class + functional groups + standard
  unchanged), script parallel-pipeline (rendezvous concurrency + source-order replay + failure
  propagation), dcmdir update (add + prune-missing).

### Added — JPEG XL Lossy Encode (Transfer Syntax …4.112) in dicom-compress

- **`dicom-compress compress --codec jpeg-xl`** now produces **lossy** JPEG XL (`1.2.840.10008.1.2.4.112`, general JPEG XL) via JXLSwift's VarDCT encoder, alongside the existing lossless JPEG XL (`…4.110`). Both the `dicom-compress` CLI and the DICOMStudio CLI Workshop drive the identical shared `CompressionManager` / `CodecRegistry` path, so the two surfaces cannot drift. `--quality maximum|high|medium|low|0.0–1.0` maps to the JPEG XL quality/distance curve (mirroring the `--quality` mapping already used by the JPEG and JPEG-LS lossy codecs).
  - **Codec naming** aligns with the rest of the family (`jpeg2000`/`htj2k`): the bare `jpeg-xl`/`jxl` names now resolve to the **lossy** syntax (`…4.112`); the explicit `jpeg-xl-lossless`/`jxl-lossless` names select the lossless syntax (`…4.110`). `jpeg-xl-lossy`/`jxl-lossy` are accepted aliases for the lossy target. (Behaviour change: `jpeg-xl`/`jxl` previously encoded lossless.)
  - **`JXLCodec`** (`Sources/DICOMCore/JXLCodec.swift`): added `…4.112` to `supportedEncodingTransferSyntaxes`, a per-instance `encodingTransferSyntaxUID` that selects the encode mode (…4.110 → lossless Modular, distance 0; …4.112 → lossy VarDCT at a quality-derived distance), and a `jxlQuality(from:)` mapping. JXLSwift's VarDCT lossy encoder covers 8-/16-bit RGB/RGBA within its size limits; for inputs it can't take (grayscale, oversized) it transparently falls back to the lossless Modular path, so a `…4.112` encode always yields a valid — and conformant, since the general syntax permits both — JPEG XL codestream.
  - **`CodecRegistry`** (`Sources/DICOMCore/ImageCodec.swift`): the JPEG XL encoder is now wired per-UID (`JXLCodec(encodingTransferSyntaxUID: uid)` for `…4.110` and `…4.112`), mirroring the per-syntax encoder wiring already used for JLISwift / J2KSwift.
  - **`CompressionManager`** (`Sources/DICOMKit/Compression/CompressionManager.swift`): codec-name map splits JPEG XL into a lossless entry (`jpeg-xl-lossless`/`jxl-lossless` → `…4.110`) and a lossy entry (`jpeg-xl`/`jxl`/`jpeg-xl-lossy`/`jxl-lossy` → `…4.112`). Flows automatically to the CLI validator, the `--help` codec list, and the DICOMStudio Workshop codec picker (which derives from `supportedCodecs()`).
  - **DICOMStudio** (`Sources/DICOMStudio/Views/DataExchangeView.swift`): the Data Exchange compression-algorithm picker gains "JPEG XL Lossless" and "JPEG XL Lossy" entries, with `jpeg-xl` marked lossy.
  - **Tests** (`Tests/DICOMCoreTests/JXLCodecRegistryTests.swift`, `CompressionCodecMapTests.swift`): registry now exposes an encoder for `…4.112`; new round-trips prove an RGB lossy encode decodes back to source dimensions and a grayscale lossy request falls back to lossless (bit-exact); the codec-map parity test pins `jpeg-xl` → `…4.112` and `jpeg-xl-lossless` → `…4.110`.
  - **Note:** `dicom-convert`'s `jpeg-xl`/`jxl` `--transfer-syntax` aliases remain **lossless** (`…4.112` is not yet a convert target) — this change is scoped to `dicom-compress`.

### Added — JPEG XL JPEG Recompression (Transfer Syntax …4.111) in dicom-convert

- **`dicom-convert --transfer-syntax JPEGXLRecompression`** now losslessly transcodes a JPEG Baseline (…4.50) file to JPEG XL JPEG Recompression (`1.2.840.10008.1.2.4.111`) and back. Unlike every other codec, recompression is not a pixel operation: it wraps the existing JPEG bitstream in a JPEG XL container (with a `jbrd` reconstruction box) so the original JPEG is recovered **byte-for-byte** — no additional loss on top of the JPEG the file already carries. The reverse (`…4.111` → `JPEGBaseline`) reconstructs the byte-identical original JPEG.
  - **`JXLCodec`** (`Sources/DICOMCore/JXLCodec.swift`): added the fragment-level `recompressJPEGFragment(_:)` / `reconstructJPEGFragment(_:)` helpers (backed by JXLSwift's `encodeLosslessJPEG` / `decodeLosslessJPEG`), added `…4.111` to the decodable transfer syntaxes, and routed the `…4.111` pixel decode through JPEG reconstruction → the JPEG codec so decoded pixels match the wrapped JPEG with the descriptor's channel layout (rather than the VarDCT bridge's colour-space representation). The forward encode is deliberately NOT registered as a pixel `ImageEncoder` (recompression takes JPEG bytes, not pixels).
  - **`TransferSyntaxConverter`** (`Sources/DICOMCore/TransferSyntaxConverter.swift`): added `isJXLRecompressionForward` / `isJXLRecompressionReverse` predicates (gated to JPEG Baseline ↔ …4.111, matching JXLSwift's baseline-DCT scope), a fragment-level `transcodeJXLRecompression(…)` path (no pixel decode/re-encode — structurally mirrors the J2K↔HTJ2K fast path), the `canTranscode` admission for these pairs, and a lossless-guard bypass so a lossy-Baseline → …4.111 wrap is correctly treated as lossless (it adds no loss).
  - **`DICOMConverter`** (`Sources/DICOMKit/DICOMConverter.swift`): added `JPEGXLRecompression` to the shared convert target catalog, so the new target flows automatically to the CLI `--transfer-syntax` help, the DICOMStudio CLI Workshop picker, the representative parameter catalog, and `parseTarget(_:)` — the CLI and the Workshop share one code path. It is convert-only (not a `dicom-compress`/`CompressionManager` pixel codec).
  - **CLI parity**: `CLIContracts.json` transfer-syntax abstract updated; `cli-parity-gen` gains a derived `syn-ct-baseline.dcm` JPEG-Baseline fixture (`ctbaseline`) and a `dicom-convert ts-JPEGXLRecompression` decoded-pixel-hash scenario exercising the shared path in both surfaces.
  - **Tests** (`Tests/DICOMRoundTripTest/ConvertRoundTripTests.swift`): oracle round-trips proving byte-identical JPEG reconstruction through the …4.111 wrap, …4.111 pixel decode equals the wrapped JPEG's pixels, onward transcode …4.111 → J2K Lossless, and rejection of a non-JPEG source.

### Added — Shared CLI ↔ App Orchestration: CompressionConsole, DICOMConverter, DICOMDIRDumpFormatter, DICOMDIRWorkflow, EncapsulatedDocumentWorkflow

- **`CompressionConsole`** (`Sources/DICOMKit/Compression/CompressionConsole.swift`): Pure shared formatter and input-parser for `dicom-compress`. Both the CLI binary and DICOMStudio's CLI Workshop call this single type for `--quality` / `--backend` parsing, binary byte formatting, and every console line (compress header, stats, batch totals). Replaces duplicated inline formatting on both sides. Mirrors the `NetworkConsole` shared-formatter pattern.
- **`DICOMConverter`** (`Sources/DICOMKit/DICOMConverter.swift`): Single source of truth for the `dicom-convert` transfer-syntax conversion API — the ordered target catalog (UID, CamelCase CLI tokens, kebab aliases), `parseTarget(_:)`, `cliTokens`/`aliasTokens` picker lists, and the shared `convertToDICOM(dicomFile:to:stripPrivate:)` pipeline. Both the CLI (`dicom-convert`) and the DICOMStudio CLI Workshop call this directly so conversion bytes are identical and the `--transfer-syntax` help text cannot drift from the picker.
- **`DICOMDIRDumpFormatter`** (`Sources/DICOMKit/DICOMDIRDumpFormatter.swift`): Shared renderer for `dicom-dcmdir dump` output (tree / json / text formats). The CLI and the CLI Workshop both call `DICOMDIRDumpFormatter.render(_:format:verbose:)` so their output pipelines cannot drift.
- **`DICOMDIRWorkflow`** (`Sources/DICOMKit/DICOMDIRWorkflow.swift`): Shared orchestration helpers for `dicom-dcmdir` — recursive DICOM file discovery (skipping the existing DICOMDIR, sorting by path), the create build-loop (read, compute relative path, add to `DICOMDirectory.Builder`, emit summary), and the validate report (statistics + file-set + record-type breakdown). Both the CLI and the Workshop call these helpers, eliminating hand-mirrored orchestration that could silently diverge.
- **`EncapsulatedDocumentWorkflow`** (`Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocumentWorkflow.swift`): Shared orchestration helpers for `dicom-pdf` — `EncapsulatedDocumentType.fileExtension`, `defaultModality`, the `--show-metadata` report block, and the human-readable file-size formatter. Both the CLI and the Workshop call these helpers so the `dicom-pdf` parity surface cannot drift.
- **Synthetic DICOMDIR fixture** (`Sources/DICOMStudio/Resources/CLIParity/synthetic/syn-dicomdir`): Pre-built minimal DICOMDIR file added to the synthetic corpus for the offline `dicom-dcmdir` parity scenario, making the dcmdir dump/validate scenarios runnable without a real PACS file hierarchy.

### Fixed — DICOMWriter Drops Encapsulated Pixel Data

- **`DICOMWriter.serializeElement(_:)` now emits encapsulated pixel data** (`Sources/DICOMCore/DICOMWriter.swift`): The generic serializer previously skipped any undefined-length (`0xFFFFFFFF`) element that was not `.SQ`, silently emitting an empty PixelData shell. This caused `DICOMConverter`/`dicom-convert` to fail on ANY compressed source — the decoder saw zero fragments and threw "Frame 0 starts beyond data bounds" — and would have corrupted any `DataSet.write()` / `DICOMFile.write()` rewrite of a compressed dataset. Fixed by adding a dedicated `serializeEncapsulatedPixelData(_:fragments:)` branch that emits the full Basic Offset Table Item + one Item per codestream fragment (odd fragments padded to even length per PS3.5 A.4) + the Sequence Delimitation Item.

### Fixed — DICOMFile.pixelData() No Longer Relabels YBR as RGB

- **Removed stale YBR→RGB photometric relabel** (`Sources/DICOMKit/DICOMFile+PixelData.swift`): The previous code relabelled YBR pixel data as RGB for transfer syntaxes that the retired ImageIO-based codecs once handled (JPEG 50/51/57/70, JPEG 2000 90/91). The current registry uses pure-Swift codecs (JLISwift, J2KSwiftCodec, JPEG-LS, RLE) that decode to the *source* photometric interpretation and leave YBR→RGB conversion to `PixelDataRenderer`. The relabel suppressed that renderer conversion and washed out/blanked colour compressed previews. Removing it restores correct colour rendering for all compressed sources while preserving the existing `isImageIODecodedTransferSyntax` helper (unused after this change).

### Fixed — JPEG-LS NEAR Parameter Overflow for 16-bit Sources

- **JPEG-LS NEAR clamped to 255** (`Sources/DICOMCore/JPEGLSCodec.swift`): JLSwift's `JPEGLSEncoder.Configuration` rejects a NEAR value above 255. For a 16-bit source at high quality, the formula `maxVal * (1 - quality) * 0.1` could yield NEAR ≈ 655, causing the encode to throw. Added a `maxNear = 255` clamp so lossy JPEG-LS encoding of 16-bit images at any quality level succeeds.

### Fixed — PixelEditor Handles Compressed Sources

- **`PixelEditor` decodes encapsulated sources before editing** (`Sources/DICOMKit/PixelEditing/PixelEditor.swift`): Editing a compressed (encapsulated) PixelData element in place corrupts the encoded bitstream; the output — still tagged as the compressed transfer syntax — cannot be decoded by a viewer. `PixelEditor` now detects an encapsulated source, decodes it to native pixels first, and emits the edited result as uncompressed Explicit VR Little Endian. Multi-frame sources are handled correctly.

### Fixed — dicom-pixedit `--invert` Rendered Solid White

- **`PixelEditor` now inverts the VOI window and uses the correct signed pivot** (`Sources/DICOMKit/PixelEditing/PixelEditor.swift`): `dicom-pixedit --invert` (and the CLI Workshop "Invert" toggle, which shares `PixelEditor.processData`) produced a solid-white image. `applyInvert` inverted stored pixels around `2^bitsStored − 1` but never updated the file's VOI Window Center (0028,1050); because the viewer, image exporter, and Horos all honour the stored window by default (`DICOMImageExporter.determineWindowSettings`, rescale-adjusted), every inverted pixel fell outside the unchanged window and clamped to white. Signed data was additionally clamped because the pivot used the unsigned max instead of `−1`. Fixes: (1) invert around `isSigned ? −1 : maxValue`; (2) re-point each Window Center to `slope·pivot + 2·intercept − center` (output-unit equivalent of inverting the stored center around the pivot), leaving Window Width unchanged and no-op when the file carries no stored window; (3) `--apply-window` now bakes into — and resets the stored VOI window to — the full *representable* stored range (signed-aware: `[0, 2^b−1]` unsigned, `[−2^(b−1), 2^(b−1)−1]` signed), so a baked signed image is no longer written into only half the range and rendered ~2× too dark. `formatDS` guards against non-finite values from pathological rescale metadata. Regression tests in `PixelEditorTests` render the inverted frame through the shared viewer/export window policy and assert a true photographic negative (not solid white) for both MONOCHROME2 and MONOCHROME1, plus the signed window-bake range.

### Added — DICOMKitTests: Parity and Regression Test Suite

Seven new test files added to the `DICOMKitTests` target (`Package.swift` sources updated):

- **`EncapsulatedPixelDataWriteTests`**: Regression for the `DICOMWriter` encapsulated pixel data fix — asserts the full BOT + fragment structure is emitted, odd fragments are padded, a zero-fragment BOT writes cleanly, and a round-trip `DataSet.write()` → `DICOMParser.parse()` recovers the original fragments.
- **`CompressionManagerImplicitVRTests`**: Regression for `CompressionManager` on Implicit VR Little Endian sources — pins that the shared `DICOMWriter` path re-encodes sequences from parsed items (not raw bytes) and promotes oversized short-VR values to UN, preventing byte-stream desync and the "No pixel data found" failure on decompress.
- **`CompressedPreviewRenderParityTests`**: Parity regression that the `DICOMFile.pixelData()` return value for a freshly compressed file matches the value after a round-trip decompress, for every codec — so the photometric-relabel removal cannot silently reintroduce colour corruption.
- **`CompressionConsoleTests`**: Contract tests that lock the exact `dicom-compress` console strings produced by `CompressionConsole` — byte formatting, quality parsing, header lines, compressed-result lines — so the CLI and CLI Workshop cannot drift.
- **`DICOMConverterTests`**: Contract tests for the shared `DICOMConverter` API — every catalog token (cliToken / aliasToken / UID / extraAliases) round-trips through `parseTarget`; picker token lists are exactly the catalog; `CLIContracts.json` entry is regenerable from the catalog; DEFLATE converts without error.
- **`ExportWindowParityTests`**: Regression that `DICOMImageExporter.renderFrameForExport` and `determineWindowSettings` rescale-adjust the VOI window (HU → stored via Rescale Slope/Intercept), so a CT with a non-zero Rescale Intercept exports with the correct contrast — not washed out.
- **`PixelEditorTests`**: Regression that `PixelEditor` decodes encapsulated sources to native pixels before editing, emits Explicit VR Little Endian output, and preserves tag edits in the serialized file.

### Added — WADORetrieveConsoleFormatter (Shared WADO-RS / WADO-URI Retrieve Renderer)

- **`WADORetrieveConsoleFormatter`** (`Sources/DICOMWeb/WADORetrieveConsoleFormatter.swift`): Shared output renderer for WADO-RS / WADO-URI retrieve — verbose preamble blocks, per-mode status lines (metadata / rendered / thumbnail / frames / instances / WADO-URI result), and the metadata body (JSON pretty-printed + PS3.19 Native DICOM Model XML). Mirrors `QIDOResultFormatter` (query) and `UPSResultFormatter` (ups): a SINGLE formatter both sides call, so the `dicom-wado retrieve` CLI binary and DICOMStudio's in-app retrieve cannot produce different output.
  - `DICOMWado.swift` (`RetrieveCommand`) now delegates all verbose preamble, per-mode status, and metadata body output to `WADORetrieveConsoleFormatter` instead of hand-rolling inline strings.
  - `CLIWorkshopViewModel.swift` (WADO retrieve case) likewise delegates to the formatter; the mode-detection / inline-echo block is removed, and the verbose preamble is gated by `--verbose` on both sides identically.
  - `parseFrameNumbers` moved from `RetrieveCommand` into `WADORetrieveConsoleFormatter` (as a throwing method returning `[Int]`) with a companion `WADOFrameParseError` type; the CLI catches `WADOFrameParseError` and re-throws as `ValidationError`.

### Added — STOWResultFormatter (Shared WADO STOW-RS Upload Renderer)

- **`STOWResultFormatter`** (`Sources/DICOMWeb/STOWResultFormatter.swift`): Shared console renderer for `dicom-wado store` (STOW-RS) upload output — verbose pre-upload header, per-batch start/result lines, per-failure detail, and the always-printed final summary block. Both the `dicom-wado store` CLI path and DICOMStudio's in-app STOW upload call this single formatter, preventing output pipeline drift. The summary block format is a parity contract that `CLIParityWADOComparator.parseStore` anchors on.

### Added — UPS-RS Parity Harness: Full Operation Matrix, Global Subscribe, and get --format/--verbose

- **UPS write scenarios run out-of-the-box**: The parity harness no longer gates the full UPS operation matrix on a user-supplied Procedure Step Label. A `upsDefaultLabel` (`"CLI Parity Workitem"`) is substituted when the WADO panel's label is blank, so `ups-lifecycle`, `ups-lifecycle-complete`, `ups-lifecycle-cancel`, `ups-get`, `ups-create-attrs`, `ups-create-json`, and `ups-subscribe` always appear in the scenario list — matching how the harness already auto-picks the AE title and station filter.
- **Global UPS subscribe scenario** (`ups-subscribe-global`): New `runWADOUPSSubscribeGlobalScenario` runner exercises `ups --subscribe --aet <ae>` (no `--workitem-uid`) → `ups --unsubscribe --aet <ae>` — the GLOBAL round-trip that subscribes to ALL workitems' events. Reference uses `DICOMwebClient.subscribeToAllWorkitems` + `unsubscribeFromWorkitem(nil)`. Parity on round-trip outcome; servers that don't enable UPS subscription fail both sides identically (`failureAgreement`).
- **ups-get `--format` / `--verbose` variants**: Four `--format` flag variants (`table`, `json`, `csv`) plus a `--verbose` variant are now generated for the `ups-get` scenario. The flags are threaded through `studioParams["get-format"]` and `"get-verbose"` and appended at run time (after the Workitem UID is known), mirroring how the CLI appends them to the chained `ups --get <uid>` command.
- **Transaction UID flow corrected**: The UPS lifecycle runner (`runWADOUPSLifecycleScenario`) no longer pre-mints a Transaction UID and supplies it to the `--update --state IN_PROGRESS` claim. Instead it lets the server assign one, parses it from the CLI's IN PROGRESS output (`Transaction UID: …`), and reuses it for the terminal `COMPLETED`/`CANCELED` transition — exactly how a real operator works. The reference (`CLIParityNetworkReference.wadoUPSLifecycle`) likewise captures and reuses `claimResp.transactionUID`. When no UID is returned the terminal transition is skipped and recorded as not reached.
- **`wadoUPSSubscribeGlobal`** reference method added to `CLIParityNetworkReference`: calls `client.subscribeToAllWorkitems` + `client.unsubscribeFromWorkitem(nil)`; `createOK` is vacuously true (no workitem is created).

### Changed — C-GET and dicom-send Dry-Run Comparators Aligned with Shared Formatters

- **C-GET comparator** (`CLIParityRetrieveComparator`): The shared `NetworkConsole.cGetSummary` now emits exactly one terse line — `"✅ C-GET completed — N file(s) received"` on success or `"⚠️ C-GET completed but received 0 instances. …"` when nothing arrived — instead of a structured `C-GET Completed:` block with sub-operation counts. The parser now reads the received-file count from that line only; `completed`/`failed` are no longer parsed or compared for C-GET (they are unobservable in the CLI text). `canonical()` updated accordingly: C-GET compares `success + files`; C-MOVE still compares `completed + failed + warning`.
- **dicom-send dry-run comparator** (`CLIParitySendComparator`): The shared formatter's dry-run path (`NetworkConsole.sendHeader`) prints the gathered file count in the header's `"Files: N"` field rather than `"Found N file(s) to send"`. The parser now reads the first `"Files:"` line — the header count — rather than `"Found"`.

### Changed — UPS CLI Workshop: unsubscribe Operation and Simplified cliMapping

- **`unsubscribe` operation added** to the UPS parameter definition in `CLIWorkshopHelpers`: the operation picker now lists `search`, `get`, `create-workitem`, `change-state`, `subscribe`, `unsubscribe`. `--workitem-uid` is shown for `unsubscribe` as well as `subscribe` and `create-workitem`.
- **`--search` and `--create-workitem` moved to `cliMapping`**: Both flags are now emitted automatically when the matching operation tab is selected, removing the separate boolean-toggle `CLIParameterDefinition` entries that were previously needed. This mirrors the existing `--subscribe`/`--unsubscribe` mapping pattern.
- **No auto-pre-selection in Network mode**: Switching to Network mode no longer pre-selects the first network tool. The user explicitly picks which tools to include in the parity sweep.

### Fixed — HL7 ORM^O01 Field Placement for dcm4chee-arc MWL Create

- **HL7 ORM IPC segment + OBR field map corrected** (`ModalityWorklistService.buildHL7ORM`): The previous implementation wrote `scheduledStationAETitle` into `OBR-20`, which dcm4chee-arc's default inbound order stylesheet (`hl7-order2dcm.xsl`) reads as the **Scheduled Procedure Step ID** (`0040,0009`) — so a user's Station AET surfaced on the server as the SPS ID. Fixed in two ways:
  - **OBR path corrected**: rebuilt with an explicit index→value map (`hl7Segment(_:fields:)` helper) so the values land at their exact positions. OBR-18 = Accession Number, OBR-19 = Requested Procedure ID, OBR-20 = SPS ID, OBR-24 = Modality, OBR-27 4th component = SPS Start Date/Time.
  - **IPC segment added**: a dcm4che-private `IPC` (Imaging Procedure Control) segment is emitted after OBR so every SPS attribute has an unambiguous, configuration-independent slot — **IPC-7 = Station Name**, **IPC-9 = Scheduled Station AE Title** (the only ORM path that carries them). IPC-1/2/3 also supply Accession / Requested Procedure ID / Study Instance UID, matching the OBR fallback exactly.
  - `buildHL7ORM` promoted from `private` to `internal` to allow the new field-placement regression tests (`Tests/DICOMStudioTests/MWLCreateHL7ORMTests.swift`) to assert each value's exact HL7 position without requiring a live MLLP server.

### Fixed — WADO-URI Endpoint Resolution for dcm4chee5

- **`WADOURIClient.resolveURIEndpoint(_:)`** (new public static method): dcm4chee-arc 5.x serves WADO-URI (`?requestType=WADO`) from `/wado`, while the sibling WADO-RS/QIDO-RS endpoint lives at `/rs`. Supplying a WADO-RS base URL for a WADO-URI request returned HTTP 404. The resolver rewrites a trailing `/rs` path segment to `/wado`; all other base URLs are returned unchanged. Because the `dicom-wado` CLI, CLI Workshop, and parity reference all retrieve through this one client, they resolve identically and cannot drift.

### Fixed — dicom-mpps N-CREATE Status Guard

- **`dicom-mpps create --status` validation**: N-CREATE must always start the step `IN PROGRESS`; the previous code accepted `COMPLETED` or `DISCONTINUED` at creation, which servers reject (terminal states are reached only via N-SET). The `create` subcommand now validates that `--status` is `IN PROGRESS` and emits a clear `ValidationError` directing the user to `dicom-mpps update` for state transitions.

### Added — UPS-RS Result Formatter (Shared)

- **`UPSResultFormatter`** (`Sources/DICOMWeb/UPSResultFormatter.swift`): Shared output renderer for UPS-RS worklist search results — table, JSON (`UPSOutputFormat`), and CSV — used by both the `dicom-wado ups --search` CLI path and DICOMStudio's in-app UPS worklist search. Mirrors `QIDOResultFormatter` (QIDO-RS) and `DICOMQueryResultFormatter` (DIMSE): a single formatter both sides call so their output pipelines cannot drift.

### Added — CLI Workshop PACS Server Edit

- **Edit saved PACS server profiles**: The CLI Workshop saved-server list now supports in-place editing (`beginEditServer(id:)` / `saveEditedServer()` on `CLIWorkshopViewModel`). A new `showEditServerSheet` / `editingServerID` pair drives the edit sheet; saving re-applies the updated values when the edited profile is currently selected. Previously only add and delete were supported.

### Changed — NetworkConsole Shared Formatter Covers All Network CLIs

- **`NetworkConsole` (DICOMNetwork) now covers all DIMSE network tools**: `dicom-echo`, `dicom-mwl` (query), and `dicom-mpps` joined the shared formatter, completing the set started with `dicom-query / dicom-send / dicom-retrieve / dicom-qr / dicom-wado`. All human console output — headers, per-echo progress, summaries, verbose details — routes through one `NetworkConsole` method on both the CLI binary and the DICOMStudio CLI Workshop in-process path, making terminal-compare diff drift impossible by construction.
- **`dicom-send/ProgressReporter.swift` removed**: its logic was absorbed into `NetworkConsole`. Any callers that imported it directly must switch to the corresponding `NetworkConsole.*` methods.

### Added — Network CLI & DICOMweb Tests

- **`MWLCreateHL7ORMTests`** (`Tests/DICOMStudioTests/`): Regression tests asserting each value in the HL7 ORM^O01 message built by `ModalityWorklistService.buildHL7ORM` lands at its exact field position in both the OBR fallback path and the IPC segment, so the field-placement bug (`OBR-20` Station AET mismap) cannot silently return.
- **`UPSTests`** (`Tests/DICOMWebTests/`): Coverage for UPS-RS workitem query parsing and the new `UPSResultFormatter` output (table/JSON/CSV).
- **`WADOURIClientTests`** (`Tests/DICOMWebTests/`): Coverage for `WADOURIClient.resolveURIEndpoint` (no-op for `/wado`, rewrite for `/rs`, passthrough for other paths) and WADO-URI URL building.

### Added — Network Utility (Live Terminal Output)

- **Network Utility panel** (`NetworkUtilityView`, `NetworkUtilityViewModel`, `NetworkUtilityService`): Six-tab general-purpose network diagnostics tool surfaced as a new sidebar destination in DICOMStudio.
  - **Ping** — wraps `/sbin/ping`; live per-packet output streams into a terminal panel, parsed summary (min/avg/max RTT, packet loss) replaces it on completion.
  - **Port Scanner** — concurrent TCP probes via `NWConnection`; results append in arrival order for a live scan log, sorted by port number on completion.
  - **Traceroute** — wraps `/usr/sbin/traceroute`; each hop line streams as it resolves; stderr merged into stdout so the `traceroute to …` header appears at the top in real time.
  - **DNS Lookup** — wraps `/usr/bin/dig` per selected record type (A, AAAA, MX, TXT, NS, CNAME, SOA, PTR); each query echoes a `$ dig …` header then streams its answer block.
  - **Interfaces** — lists all network interfaces with IPv4/IPv6 addresses, MAC address, MTU, flags, and status badges.
  - **Netstat** — wraps `/usr/sbin/netstat`; streams TCP/UDP connections or routing table live; parsed counts (listening/established/routes) shown on completion.
- **Shared host input**: A single `sharedHost` field is shared by the Ping, Port Scanner, and Traceroute tabs — typing a host in any one of them pre-fills the others.
- **`AsyncStream<String>`-based live streaming** (`runStreamingProcess`): All five process-based tools share a single streaming process runner; stdout and stderr are merged into one pipe so output arrives in natural order, then yielded chunk-by-chunk via `AsyncStream`.
- **UTF-8 carry-over buffer**: A `var pending = Data()` accumulator in the `availableData` read loop ensures multibyte characters (IDN hostnames, TXT/PTR record content) are never split and silently dropped between reads.
- **Run-identity guard** (`streamGeneration` / `portScanGeneration`): Each run captures a generation counter; `onChunk` closures and completion assignments check `self.streamGeneration == gen` and discard stale deliveries from cancelled or superseded runs.
- **SIGKILL escalation**: Both the wall-clock watchdog and `ProcessKillBox.cancel()` send SIGTERM then escalate to SIGKILL after a 3-second grace period, preventing hung processes from blocking the UI indefinitely.
- **Watchdog liveness guard**: The watchdog `DispatchWorkItem` checks `proc.isRunning` before acting, preventing a process that exits naturally at the deadline from being mislabelled as timed out.

## [2.1.0] - 2026-05-21

DICOMStudio: J2K Test Bench, responsive layout, and imaging-first navigation.

## [2.0.0] - 2026-05-21

### Added — J2KSwift v3.2.0 Integration (Phases 1–9)

- **J2KSwift v3.2.0 codec stack** (`Sources/DICOMCore/J2KSwiftCodec.swift`, `HTJ2KCodec.swift`, `JP3DCodec.swift`): Replaces Apple ImageIO as the primary JPEG 2000 path on all platforms, enabling full Linux support via a pure-Swift scalar backend.
  - `J2KSwiftCodec`: Handles JPEG 2000 Lossless (`.90`), JPEG 2000 Lossy (`.91`), Part 2 Lossless (`.92`), Part 2 Lossy (`.93`) with 8/12/16-bit grayscale and RGB support.
  - `HTJ2KCodec`: Full HTJ2K Lossless (`.201`), HTJ2K RPCL Lossless (`.202`), HTJ2K Lossy (`.203`). Fast-path transcoder via `J2KTranscoder` (no pixel decode); 5.4× decode speedup over J2K on macOS arm64.
  - `JP3DCodec`: ISO/IEC 15444-10 volumetric encoding/decoding for multi-frame CT/MR/PET series with lossless, lossless-HTJ2K, and lossy modes.
- **JPIP streaming** (`Sources/DICOMKit/DICOMJPIPClient.swift`): Progressive 2D and 3D tile streaming for large remote studies; transfer syntaxes JPIP Referenced (`.94`) and JPIP Referenced Deflate (`.95`) registered.
  - `dicom-jpip` CLI tool with `fetch`, `uri`, `serve`, and `info` subcommands.
  - `DICOMFile.openVolumeProgressively(serverURL:sliceJPIPURIs:qualityLayers:)` API for huge CT/MR datasets.
- **JP3D volume bridge** (`Sources/DICOMKit/JP3DVolumeBridge.swift`): Converts multi-frame DICOM series ↔ `J2KVolume`; preserves `SliceLocation`, `ImagePositionPatient`, `SeriesInstanceUID`.
  - `JP3DVolumeDocument`: Encapsulated document SOP (private SOP `1.2.826.0.1.3680043.10.511.10`) with `.jp3d` payload + JSON sidecar; MIME type `application/x-jp3d`.
  - `DICOMFile.openVolume(from:)` / `openVolume(from:jpipServerURL:)` for unified volume access.
- **Hardware acceleration** (`CodecBackend` enum): Metal (Apple GPU), Accelerate (SIMD), scalar fallback; `CodecBackendProbe` selects best available at runtime. `--backend` flag on `dicom-compress` and `dicom-3d`.
- **`dicom-j2k` CLI tool** (8 subcommands): `info`, `validate`, `transcode`, `reduce`, `roi`, `benchmark`, `compare`, `completions`. 53 tests.
- **DICOMStudio enhancements**:
  - Progressive decoding with `ProgressiveDecodeModel` / `ProgressiveImageView` (AsyncStream-driven `.quarter → .half → .complete` state machine).
  - ROI decoding wired to pinch-zoom gestures.
  - JP3D MPR views (axial / sagittal / coronal) via `JP3DMPRViewModel` / `JP3DMPRView`.
  - JPIP loader with quality-layer slider.
- **Transfer syntaxes** added to registry, `DICOMValidator`, and `StorageSCP` presentation contexts: `.htj2kLossless`, `.htj2kRPCLLossless`, `.htj2kLossy`, `.jpip`, `.jpipDeflate`, `.jpeg2000Part2Lossless`, `.jpeg2000Part2`.
- **DICOMweb HTJ2K media types**: `image/jph` and `image/jphc` advertised in capability; WADO-RS accept headers updated.
- **`dicom-compress`**, **`dicom-convert`**, **`dicom-send`**, **`dicom-retrieve`**, **`dicom-viewer`**, **`dicom-info`**, **`dicom-validate`** extended for HTJ2K, JP3D, and JPIP transfer syntaxes.
- **Codec Inspector panel** in DICOMStudio: shows decoder name, backend (Metal/Accelerate/scalar), and decode timing.

### Fixed
- **JPEG 2000 16-bit rendering pipeline**: Fixed near-black output after conversion when preserving original bit depth
  - Normalized ImageIO-decoded 16-bit JPEG 2000 samples back to the DICOM `Bits Stored` range in `NativeJPEG2000Codec`
  - Preserved original metadata for JPEG 2000 and JPEG 2000 Lossless conversions (`BitsAllocated`, `BitsStored`, `HighBit`)
  - Verified CT-style datasets with VOI/Rescale tags render correctly after implicit VR → JPEG 2000 lossless transcoding

- **DICOM Studio metadata consistency**: Fixed transfer syntax source ordering in metadata loading
  - `MetadataViewModel` now prefers File Meta Information `(0002,0010)` before dataset fallback
  - Aligns metadata display behavior with converted-file transfer syntax as stored on disk

- **Test Infrastructure**: Fixed platform-specific test compilation errors
  - Added `#if canImport(CoreGraphics)` guards to ColorTransformTests for Apple platform-only APIs
  - Fixed DataElement initializer calls in ICCProfileAdvancedTests with missing length parameters
  - Fixed ambiguous type references in SegmentationParserTests
  - Tests now compile cleanly on Linux CI runners and Apple platforms

### Changed - DICOM Standard Edition Update
- **Updated DICOM standard reference from 2025e to 2026a**
  - The 2026a release is now the current edition available at https://www.dicomstandard.org/current/
  - Updated `dicomStandardEdition` constant to "2026a"
  - Updated all source code doc comments referencing DICOM PS3.x editions
  - Updated conformance statement, FAQ, contributing guide, and README
  - Key differences from 2025e to 2026a:
    - New supplements including CT Image Storage for Processing (Sup252)
    - Radiation Dose Structured Report (RDSR) informative annex (Sup245)
    - Enhanced DICOMweb services (Sup248, Sup228)
    - Data dictionary and controlled terminology updates
    - Correction proposals addressing encoding clarifications and CID additions
    - Improved sex and gender data representation
    - Frame Deflate transfer syntax enhancements for segmentation encoding

## [1.2.6] - 2026-02-07

### Added - Phase 5 CLI Tools Complete
- **dicom-mpps (v1.2.6)**: Modality Performed Procedure Step (MPPS) operations
  - N-CREATE operation for creating MPPS instances (procedure start)
  - N-SET operation for updating MPPS instances (procedure completion/discontinuation)
  - Support for IN PROGRESS, COMPLETED, and DISCONTINUED states
  - Referenced SOP instance tracking
  - MPPSService in DICOMNetwork module
  - Complete CLI tool with create and update subcommands
  - Documentation and README

## [1.2.5] - 2026-02-07

### Added - Phase 5 CLI Tools
- **dicom-mwl (v1.2.5)**: Modality Worklist Management
  - C-FIND query support for Modality Worklist Information Model
  - WorklistQueryKeys with flexible filtering (date, station AET, patient, modality)
  - JSON output support for automation
  - Verbose mode for detailed attribute display
  - ModalityWorklistService in DICOMNetwork module
  - Complete CLI tool with query subcommand
  - Documentation and README

## [1.0.0] - TBD

### Major Release - Production Ready

This is the first production-ready release of DICOMKit, a pure Swift DICOM toolkit for Apple platforms (iOS 17+, macOS 14+, visionOS 1+).

### Core Features (v0.1-v0.5)

#### DICOM File Support
- **Reading & Parsing**: Full support for reading DICOM files with comprehensive parsing
- **Transfer Syntaxes**: 
  - Explicit VR Little Endian (1.2.840.10008.1.2.1)
  - Implicit VR Little Endian (1.2.840.10008.1.2)
  - Explicit VR Big Endian (1.2.840.10008.1.2.2)
  - Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
- **Data Types**: All standard DICOM Value Representations (VR) supported
- **Specialized Types**: Date, Time, DateTime, AgeString, PersonName, UniqueIdentifier, etc.
- **Writing**: Create and modify DICOM files with proper serialization
- **UID Generation**: Utilities for creating unique DICOM identifiers

#### Pixel Data Support (v0.3-v0.4)
- **Uncompressed Images**: Support for all standard photometric interpretations
  - MONOCHROME1, MONOCHROME2
  - RGB, PALETTE COLOR
- **Compressed Images**: Native codec support for:
  - JPEG Baseline (Process 1)
  - JPEG Extended (Process 2 & 4)
  - JPEG Lossless & JPEG Lossless SV1
  - JPEG 2000 (Lossless and Lossy)
  - RLE Lossless (pure Swift implementation)
- **Multi-frame Support**: Handle image sequences
- **CGImage Rendering**: Native Apple platform integration for display
- **Windowing**: Window Center/Width support for grayscale images

### Networking Features (v0.6-v0.7)

#### DICOM Network Protocol (DIMSE)
- **Core Infrastructure**: PDU handling, association management
- **C-ECHO**: Verification service for connectivity testing
- **C-FIND**: Query services for searching DICOM archives (Patient, Study, Series, Image levels)
- **C-MOVE & C-GET**: Retrieve services for fetching studies and images
- **C-STORE**: Storage services (SCU and SCP)
  - Single file and batch storage operations
  - Progress tracking with AsyncSequence
  - Storage SCP for receiving files
- **Storage Commitment**: N-ACTION based commitment verification
- **Advanced Features**:
  - TLS/SSL support for secure connections
  - Connection pooling and reuse
  - Association timeout configuration
  - Asynchronous API with Swift Concurrency

### DICOMweb Services (v0.8)

#### RESTful Web Services
- **WADO-RS**: Retrieve studies, series, and instances via HTTP
  - Multi-part response parsing
  - Metadata retrieval
  - Rendered image support
- **QIDO-RS**: Query services over HTTP
  - Study, series, and instance queries
  - Fuzzy matching support
  - Pagination with limit/offset
- **STOW-RS**: Store instances via HTTP multipart upload
  - Batch upload support
  - Progress tracking
- **UPS-RS**: Unified Procedure Step worklist services
  - Workitem creation, retrieval, updates
  - State transitions (SCHEDULED → IN PROGRESS → COMPLETED/CANCELED)
  - Subscription support for notifications
- **Authentication**: Bearer token and OAuth2 support
- **TLS**: Secure HTTPS connections with custom certificate validation

### Structured Reporting (v0.9)

#### SR Document Support
- **Core Infrastructure**: SR IOD parsing and document tree navigation
- **Document Types**: Support for all standard SR templates
  - Basic Text SR, Enhanced SR, Comprehensive SR
  - Key Object Selection
  - Measurement reports
  - CAD SR (Chest, Mammography)
- **Content Items**: All relationship types and value types supported
- **Coded Terminology**: SNOMED CT, LOINC, RadLex integration
- **Measurement Extraction**: Automated extraction of measurements and coordinates
- **Document Creation**: SR document builders with template validation
- **Template Support**: TID 1500 (Measurement Report), TID 1400 (Chest CAD SR), and more

### Advanced Features (v1.0.1-v1.0.13)

#### Presentation States
- **Grayscale Presentation State (GSPS)**: Annotations, LUT transformations, spatial transforms
- **Color Presentation State (CSPS)**: Color management, blending operations
- **Pseudo-Color**: Color lookup tables, hot/cold mapping

#### Hanging Protocols
- **Protocol Definition**: Screen layout and viewport configuration
- **Matching Logic**: Image set selection based on modality, anatomy, laterality
- **Display Sets**: Multi-image layout management

#### Radiation Therapy (RT)
- **RT Structure Set**: ROI contours, structure visualization, volume calculation
- **RT Plan**: Beam definitions, treatment machine setup
- **RT Dose**: Dose grids, isodose curves, DVH (Dose-Volume Histogram)

#### Segmentation
- **SEG IOD**: Binary and fractional segmentation support
- **Rendering**: Segment overlay with configurable colors
- **Builder API**: Create segmentation objects programmatically

#### Parametric Maps
- **Quantitative Imaging**: Float pixel data support
- **Real-World Value Mapping**: Physical units, SUV calculation
- **ICC Color Profiles**: Professional color management

#### International Support
- **Character Sets**: ISO 2022, ISO 8859, GB18030, GBK, EUC-KR, Shift_JIS, UTF-8
- **Private Tags**: Vendor-specific tag dictionaries (GE, Siemens, Philips)

#### Performance
- **Memory Optimization**: Efficient large file handling
- **SIMD Acceleration**: Vectorized operations for image processing
- **Lazy Loading**: On-demand pixel data decompression

#### Documentation
- **DocC Catalogs**: Comprehensive API documentation
- **Platform Guides**: iOS, macOS, visionOS integration guides
- **DICOM Conformance**: Formal conformance statement

### Example Applications (v1.0.14)

#### DICOMViewer iOS
- Multi-modality image viewer with gesture controls
- Windowing, pan, zoom, measurements
- Hanging protocol support
- Series browser with thumbnails
- Local file import and PACS integration

#### DICOMViewer macOS
- Removed from the repository.

#### Command-Line Tools
- **dicom-info**: Display DICOM file metadata
- **dicom-dump**: Detailed data element dump
- **dicom-convert**: Transfer syntax conversion
- **dicom-anon**: Anonymization tool
- **dicom-validate**: Conformance validation
- **dicom-query**: PACS query tool
- **dicom-send**: DICOM network send utility

#### Sample Code & Playgrounds
- 27 Xcode Playgrounds demonstrating library features
- Integration examples for iOS, macOS, visionOS
- Network protocol examples
- Image processing examples

### Technical Highlights

- **Pure Swift**: No Objective-C runtime dependencies
- **Swift 6 Compliant**: Full strict concurrency support
- **Platform Native**: Leverages Apple frameworks (ImageIO, CoreGraphics, RealityKit)
- **Modern API**: Swift Concurrency (async/await), Sendable types
- **Comprehensive Testing**: 1,920+ tests across core, networking, and applications
- **Medical Imaging Standards**: DICOM PS3.x compliant

### Platform Support

- **iOS**: 17.0 and later
- **macOS**: 14.0 and later  
- **visionOS**: 1.0 and later
- **Swift**: 6.0 and later

### Dependencies

- Swift Argument Parser 1.3+ (for CLI tools only)

### Installation

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.0.0")
]
```

### Documentation

- [README.md](README.md) - Overview and quick start
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [MILESTONES.md](MILESTONES.md) - Development roadmap
- [Documentation/](Documentation/) - API documentation and guides

### Known Limitations

- Network integration tests require access to test PACS systems (documented for future)
- Transfer syntax conversion deferred to future versions
- Some advanced character sets deferred (ISO IR 100 extended)
- Store-and-forward networking features deferred

### Security & Privacy

- No known vulnerabilities in dependencies
- HIPAA considerations documented
- PHI (Protected Health Information) handling guidelines provided
- Secure network communication with TLS support

### Breaking Changes

This is the first stable release (v1.0.0). Future breaking changes will only occur in major version updates (2.0, 3.0, etc.).

### Contributors

Built with ❤️ by the DICOMKit team and contributors.

### License

See [LICENSE](LICENSE) file for details.

---

## Pre-release History

For detailed development history of pre-release versions (v0.1 - v0.9, v1.0.1 - v1.0.15), see [MILESTONES.md](MILESTONES.md).

### Notable Pre-release Versions

- **v0.1**: Core infrastructure, basic file parsing
- **v0.2**: Extended transfer syntax support
- **v0.3**: Pixel data access
- **v0.4**: Compressed pixel data
- **v0.5**: DICOM writing
- **v0.6**: Networking (Query/Retrieve)
- **v0.7**: Storage services
- **v0.8**: DICOMweb
- **v0.9**: Structured Reporting
- **v1.0.1-v1.0.13**: Advanced features
- **v1.0.14**: Example applications
- **v1.0.15**: Production release preparation

---

[1.0.0]: https://github.com/Raster-Lab/DICOMKit/releases/tag/v1.0.0
