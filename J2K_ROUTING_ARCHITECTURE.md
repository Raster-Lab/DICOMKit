# DICOMKit ↔ J2KSwift Encode/Decode Routing Architecture

**Status:** **Phases 1–6 complete** — with one library-blocked caveat (Part-2, see §14)
**Author:** generated with Claude Code
**Date:** 2026-07-13
**Pinned J2KSwift:** v11.0.2

> ⚠️ **Headline caveat:** "Real Part-2" (D1) is **blocked by the pinned J2KSwift**, which cannot *decode* the Part-2 codestreams it encodes (empirically verified — see §14). Per the chosen policy (**option 2**), DICOMKit **rejects** any request to *encode* to Part-2 (`.92`/`.93`) with a clear, specific error rather than emitting a mislabeled or unreadable codestream; **decoding** of Part-2 remains available for reading existing files. Real Part-2 is gated behind a single flag for when the library gains decode support. Everything else (GPU lossy+lossless, decode backend, auto→GPU) is fully delivered.

---

## 1. Purpose

Make the user's three real choices — **backend**, **intent**, and **compression type** — independent inputs that resolve deterministically to a single J2KSwift API call. Today DICOMKit reverse-engineers all three from the transfer-syntax UID, one axis (compression type = Part-2) is faked, and one intent state (lossless-only vs. lossless-on-a-both-capable-syntax) is not modelled explicitly.

---

## 2. The three axes

| Axis | Values | Notes |
|---|---|---|
| **Backend** | `CPU` (accelerate / scalar) · `GPU` (metal) · `auto` | `auto` currently never selects GPU (to change — see §7 D4) |
| **Intent** | `lossy` · `lossless` · `lossless-only` | **Refined** — see §4 |
| **Compression type** | `JPEG 2000 Part-1` · `HTJ2K (Part-15)` · `JPEG 2000 Part-2` | Type is currently inferred from UID, not chosen |

---

## 3. Transfer-syntax reference

| Const | UID (`1.2.840.10008.1.2.4.`) | Name | Type | `LosslessCapability` |
|---|---|---|---|---|
| `jpeg2000Lossless` | `90` | JPEG 2000 Lossless Only | Part-1 | `.losslessOnly` |
| `jpeg2000` | `91` | JPEG 2000 | Part-1 | `.both` |
| `jpeg2000Part2Lossless` | `92` | JPEG 2000 Part 2 Multi-component Lossless Only | Part-2 | `.losslessOnly` |
| `jpeg2000Part2` | `93` | JPEG 2000 Part 2 Multi-component | Part-2 | `.both` |
| `htj2kLossless` | `201` | HTJ2K Lossless Only | HTJ2K | `.losslessOnly` |
| `htj2kRPCLLossless` | `202` | HTJ2K Lossless Only (RPCL) | HTJ2K | `.losslessOnly` |
| `htj2kLossy` | `203` | HTJ2K | HTJ2K | `.both` |

Source: `Sources/DICOMCore/TransferSyntax.swift` (`LosslessCapability` enum at line 875; `losslessCapability` at 897).

---

## 4. Intent — the refined model (this review's addition)

Intent is **not** binary. There are three distinct states, because a lossless result can be carried by two different kinds of transfer syntax:

| Intent state | Meaning | Encoded as | UID used |
|---|---|---|---|
| **lossy** | Irreversible, quality/rate driven | 9/7 ICT, `lossless=false`, `useReversibleFilter=false` | a `.both` UID (`.91`/`.93`/`.203`) |
| **lossless** | Reversible, carried by a dual-capable syntax | 5/3 RCT, `lossless=true`, `useReversibleFilter=true` | a `.both` UID (`.91`/`.93`/`.203`) |
| **lossless-only** | Reversible, carried by a dedicated lossless-only syntax | 5/3 RCT, `lossless=true`, `useReversibleFilter=true` | a `.losslessOnly` UID (`.90`/`.92`/`.201`/`.202`) |

**Key fact:** the *codestream bytes* for `lossless` and `lossless-only` are identical for a given type — only the **stamped transfer-syntax UID differs** (and, for `.202`, the mandated **RPCL** progression order). The distinction matters to DICOM receivers: a `.losslessOnly` UID *asserts* to the receiver that the pixels are mathematically lossless; a `.both` UID does not.

### Type → available intents / UIDs

| Type | lossy | lossless (`.both`) | lossless-only (dedicated) |
|---|---|---|---|
| **Part-1** | `.91` | `.91` (reversible) | `.90` |
| **Part-2** | `.93` | `.93` (reversible) | `.92` |
| **HTJ2K** | `.203` | `.203` (reversible) | `.201`, `.202` (RPCL) |

Notes:
- `.202` differs from `.201` only by the **RPCL** progression-order constraint. The planner must set `progressionOrder = .rpcl` for `.202` (today it is hardcoded `.rpcl` for *all* syntaxes — that must become a per-route decision).
- `lossy` is unavailable on `.losslessOnly` types; the planner must reject `(Part-1, lossless-only, lossy)` etc. as invalid combinations.

---

## 5. Target encode routing matrix (full)

Rows = type × intent; columns = the resolved outputs. `fwd53` = set `J2K_GPU_FORWARD_53` for GPU lossless DWT (bit-exactness verified — see §9).

| Type | Intent | UID | `useHTJ2K` | `htj2kBlockFormat` | wavelet / MCT | `lossless` / `reversible` | progression | CPU API | GPU API |
|---|---|---|---|---|---|---|---|---|---|
| Part-1 | lossy | .91 | false | — | standard / disabled | false / false | (default) | `encode` | `encodeGPU` |
| Part-1 | lossless | .91 | false | — | standard / disabled | true / true | (default) | `encode` | `encodeGPU`+fwd53 |
| Part-1 | lossless-only | .90 | false | — | standard / disabled | true / true | (default) | `encode` | `encodeGPU`+fwd53 |
| HTJ2K | lossy | .203 | true | `.conformant` | standard / disabled | false / false | (default) | `encode` | `encodeGPU` |
| HTJ2K | lossless | .203 | true | `.conformant` | standard / disabled | true / true | (default) | `encode` | `encodeGPU`+fwd53 |
| HTJ2K | lossless-only | .201 | true | `.conformant` | standard / disabled | true / true | (default) | `encode` | `encodeGPU`+fwd53 |
| HTJ2K | lossless-only (RPCL) | .202 | true | `.conformant` | standard / disabled | true / true | **`.rpcl`** | `encode` | `encodeGPU`+fwd53 |
| **Part-2** | lossy | .93 | false | — | **MCT / arbitrary** | false / false | (default) | `encode` | `encodeGPU` |
| **Part-2** | lossless | .93 | false | — | **MCT / arbitrary** | true / true | (default) | `encode` | `encodeGPU`+fwd53 |
| **Part-2** | lossless-only | .92 | false | — | **MCT / arbitrary** | true / true | (default) | `encode` | `encodeGPU`+fwd53 |

**The only structural difference between Part-1 and Part-2** is the wavelet/MCT column: Part-2 sets `mctConfiguration ≠ .disabled` (and/or `waveletKernelConfiguration ≠ .standard`) so J2KSwift emits Part-2 CAP/MCT/ADS markers. Everything else is shared.

Every lossless / lossless-only route (CPU or GPU) is protected by `verifyEncodedRoundTrip` (full `decoded == original` byte compare).

---

## 6. Target decode routing

Decode does **not** depend on compression type (J2KSwift auto-detects Part-1/Part-2/HTJ2K from codestream markers). It depends only on backend and image size.

| Backend | J2KSwift API | Runs on |
|---|---|---|
| CPU | `decode()` | full CPU |
| GPU (auto) | `recommendedDecodeAPI(w,h)` → `decode` / `decodeGPU` | GPU IDWT + CPU entropy |
| GPU (aggressive, HTJ2K) | `decodeWithGPUHT()` | GPU IDWT + GPU HT entropy |

Today decode always calls `decode()` (CPU) and never sees `--backend`.

---

## 7. Locked design decisions

| # | Decision | Choice |
|---|---|---|
| D1 | **Part-2 support** | **Real** — wire `mctConfiguration` (multi-component) and/or arbitrary wavelet so `.92/.93` emit genuine Part-2 codestreams |
| D2 | **GPU lossless encode** | **Enable, guarded** — remove the `!isLossless` gate, use `J2K_GPU_FORWARD_53` for large frames, keep `verifyEncodedRoundTrip` as the safety net |
| D3 | **Decode backend axis** | **Wire backend into decode** — GPU → `decodeGPU`/`recommendedDecodeAPI` (HTJ2K may use `decodeWithGPUHT`) |
| D4 | **auto mode** | **auto → GPU on Apple Silicon** for eligible frames (large; lossy, or lossless once D2 lands); CPU elsewhere |

---

## 8. Component design

New single source of truth: `Sources/DICOMCore/J2KRoutePlanner.swift`.

```
  CompressionRequest { type, intent, backend, quality, imageShape }
                        │
                        ▼
   J2KRoutePlanner.plan(request) -> EncodeRoute / DecodeRoute
       EncodeRoute { transferSyntax, config: J2KEncodingConfiguration,
                     api: .cpuEncode | .gpuEncode(fwd53: Bool) }
       DecodeRoute { api: .cpu | .gpu | .gpuHT }
                        │
             ┌──────────┴───────────┐
             ▼                       ▼
  J2KSwiftCodec.encodeFrame   J2KSwiftCodec.decodeFrame
   executes route.api;         executes route.api
   verifyEncodedRoundTrip
```

- `J2KRoutePlanner` owns the §4/§5/§6 tables; validates combinations (rejects e.g. lossy + lossless-only).
- `J2KSwiftCodec.encodeFrame` / `decodeFrame` become thin executors.
- `CodecBackendPreference.effectiveEncodeBackend` folds into the planner.
- Evaluate reusing `J2KDICOMHelpers/J2KDICOMTransferSyntax+EncodingConfiguration.swift` (J2KSwift ships a TS→config mapper) instead of hand-rolling.
- Stay on raw-codestream `encode()`/`decode()` — never the `J2KFileFormat` JP2/JPH box layer (DICOM pixel data is a raw codestream).

---

## 9. Verification matrix

Legend: ✅ produced & round-trip-verified · ⚠️ produced but wrong (label-only) · ❌ cannot produce · 🔬 new test required.

### 9.1 Current state (before this work)

| Type | Intent | CPU | GPU |
|---|---|---|---|
| Part-1 | lossy | ✅ | ✅ |
| Part-1 | lossless | ✅ | ❌ gated → silent CPU |
| Part-1 | lossless-only | ✅ | ❌ gated → silent CPU |
| HTJ2K | lossy | ✅ | ✅ |
| HTJ2K | lossless | ✅ | ❌ gated → silent CPU |
| HTJ2K | lossless-only | ✅ | ❌ gated → silent CPU |
| Part-2 | lossy | ⚠️ Part-1 bytes, `.93` label | ⚠️ same |
| Part-2 | lossless | ⚠️ Part-1 bytes, `.93` label | ❌ gated |
| Part-2 | lossless-only | ⚠️ Part-1 bytes, `.92` label | ❌ gated |

### 9.2 Target state (after this work) — the full test grid

Each cell must have an **encode → decode → compare** round-trip test. Lossless / lossless-only must be **byte-exact**; lossy must be within the configured tolerance. HTJ2K/Part-2 UID must be asserted on the output; Part-2 must assert real CAP/MCT markers.

| Type | Intent | UID | CPU | GPU | Notes |
|---|---|---|---|---|---|
| Part-1 | lossy | .91 | 🔬 | 🔬 | baseline |
| Part-1 | lossless | .91 | 🔬 | 🔬 | GPU=fwd53, byte-exact |
| Part-1 | lossless-only | .90 | 🔬 | 🔬 | assert `.90` UID |
| HTJ2K | lossy | .203 | 🔬 | 🔬 | |
| HTJ2K | lossless | .203 | 🔬 | 🔬 | |
| HTJ2K | lossless-only | .201 | 🔬 | 🔬 | assert `.201` UID |
| HTJ2K | lossless-only RPCL | .202 | 🔬 | 🔬 | assert `.202` UID **and** RPCL order |
| Part-2 | lossy | .93 | 🔬 | 🔬 | assert MCT markers |
| Part-2 | lossless | .93 | 🔬 | 🔬 | assert MCT + byte-exact |
| Part-2 | lossless-only | .92 | 🔬 | 🔬 | assert `.92` + MCT + byte-exact |

**Bit depths:** every lossless/lossless-only cell tested at **8-, 12-, and 16-bit** (matching the GPU forward-5/3 bit-exact evidence). **Samples:** grayscale (1-component) and RGB (3-component) — Part-2 MCT is only meaningful for multi-component, so define and test the grayscale-Part-2 behavior explicitly.

**Invalid combinations** (planner must reject, with a test): `lossy` + any `lossless-only` type; `lossy` intent requesting a `.losslessOnly` UID.

---

## 10. Phased implementation plan

| Phase | Scope | Behavior change | Tests |
|---|---|---|---|
| **P1 ✅** | Add `J2KRoutePlanner`; refactor `makeEncodingConfiguration` + `effectiveEncodeBackend` to delegate. Introduce the 3-state intent model. | None (pure refactor) | **Done** — see §13 |
| **P2 ✅** | GPU lossless (D2): allow lossless→GPU; keep round-trip guard | GPU now used for lossless | **Done** — see §13 |
| **P3 ⚠️** | Real Part-2 (D1): **BLOCKED by library** (§14). Chose **option 2**: reject Part-2 *encode* with a clear error; keep Part-2 *decode*. Gate: `part2MCTDecodeSupported` (off) | Part-2 encode refused (not mislabeled) | **Done** — see §13/§14 |
| **P4 ✅** | Decode backend axis (D3): `planDecode` + `J2KSwiftCodec(decodeBackend:)` → `decode`/`decodeGPU`; threaded through `decodePixelDataInPlace` + recompress | Decode honors backend | **Done** — see §13 |
| **P5 ✅** | auto → GPU (D4): `shouldUseGPUEncode`/`effectiveEncodeBackend` pick GPU on Metal HW for `auto` | `auto` uses GPU on Apple Silicon | **Done** — see §13 |
| **P6 ✅** | Reporting: `CompressionConsole` note reworded; matrix covered by planner + round-trip suites | — | **Done** — see §13 |

---

## 11. Open verification items (resolve during P1–P3)

1. ~~**`encodeGPU()` + lossless**~~ — **RESOLVED (Phase 2).** The GPU forward 5/3 DWT is a *stage-level* step inside the **shared** `applyWaveletTransform` (`J2KEncoderPipeline.swift:2916`), fired by both `encode()` and `encodeGPU()` when `_gpuForward53Enabled && metalAvailable && pixels ≥ threshold`. The `encodeGPU():957` "falls back to CPU for lossless" note refers only to the entry-level 9/7 orchestration; the reversible DWT still runs on GPU. `encodeGPU()` for lossless is bit-exact (J2KSwift `J2KGPUEncodeCorrectnessTests`, re-verified on this machine + the new DICOMKit round-trip suite).
2. ~~**`J2K_GPU_FORWARD_53` default & threshold**~~ — **RESOLVED.** Default **ON** since v6.1.0 (`_readGPUForward53Env` returns `true` when unset); threshold **3 MP** (`_gpuForward53PixelThreshold = 3_000_000`; the "4 MP" comment elsewhere is stale, lowered in v6.3.0 E2).
3. ~~**Part-2 decode fidelity**~~ — **RESOLVED: NO (§14).** Empirical probe: J2KSwift v11.0.2 does **not** invert the MCT on decode (max abs pixel error **253/255**). Real Part-2 is unsafe on this library; gated off.
4. ~~**Grayscale Part-2 semantics**~~ — **MOOT.** Real Part-2 MCT is disabled entirely (item #3), so the ≥2-component question does not arise; all Part-2 UIDs encode as Part-1-compatible for every sample count.

---

## 12. Files in scope

- `Sources/DICOMCore/J2KRoutePlanner.swift` *(new)*
- `Sources/DICOMCore/J2KSwiftCodec.swift` — encode/decode executors, config mapping
- `Sources/DICOMCore/CodecBackend.swift` — backend gate folds into planner
- `Sources/DICOMCore/HTJ2KCodec.swift` — thin delegate
- `Sources/DICOMKit/Compression/CompressionManager.swift` — codecMap / intent resolution
- `Sources/DICOMKit/Compression/CompressionConsole.swift` — backend/intent reporting
- `Sources/dicom-compress/main.swift` — CLI flags (wire `--backend` to decode)
- `Tests/DICOMCoreTests/` — planner unit tests + §9.2 round-trip grid

---

## 13. Implementation log

### Phase 1 — central planner + delegation ✅ (2026-07-13)

**Landed.** Pure refactor — no encode/decode behaviour change; verified by the existing parity tests staying green.

Added:
- `Sources/DICOMCore/J2KRoutePlanner.swift` — the single source of truth. Exposes:
  - `CompressionType {part1, htj2k, part2}` + `compressionType(forUID:)`
  - `ResolvedIntent {lossy, lossless, losslessOnly}` (the three-state model, §4) + `resolveIntent(uid:configuration:)`
  - `gpuEncodeEligible(intent:)` — the **one** GPU-encode policy switch (currently lossy-only; Phase 2 widens it)
  - `planEncode(transferSyntaxUID:configuration:) -> EncodePlan` — full structural plan (flags + `useGPU`)
  - No `J2KCodec` dependency — plan is expressed in DICOMCore-native enums, so routing policy is testable on every platform.

Refactored to delegate:
- `J2KSwiftCodec.makeEncodingConfiguration` → builds `J2KEncodingConfiguration` from `planEncode` (+ `progressionOrder(for:)` / `blockFormat(for:)` translators).
- `J2KSwiftCodec.encodeFrame` → GPU dispatch now reads `plan.useGPU`; config and API share one plan so they cannot disagree.
- `CodecBackendPreference.effectiveEncodeBackend` → GPU-eligibility delegates to `J2KRoutePlanner.gpuEncodeEligible` (console-reported backend can never diverge from the encoder's actual choice).

Tests:
- `Tests/DICOMCoreTests/J2KRoutePlannerTests.swift` — 11 tests (type mapping, three-state intent, structural-flag parity, Phase-1 progression/MCT parity, GPU gate).
- Result: **42/42 pass** across `J2KRoutePlanner`, `CodecBackend`, and `CompressionCodecMap` suites. Behaviour-parity guards held: *metal+lossless → CPU*, *metal+lossy → GPU*, *auto → CPU*, *metal+non-J2K → CPU*.

**Carried forward to Phase 2:** `gpuEncodeEligible` is the single edit point to enable GPU lossless; `enablePart2MCT` (always `false` today) is the Phase-3 hook; `ProgressionPlan` already supports per-route order for the Phase-later `.202`-RPCL split. Open verification items in §11 still stand (esp. #1 `encodeGPU()`+lossless behaviour) and gate Phase 2.

### Phase 2 — guarded GPU lossless encode ✅ (2026-07-13)

**Landed.** GPU (Metal) encode now covers lossy **and** lossless JPEG 2000 / HTJ2K.

Resolved open items #1 and #2 first (see §11) — the reversible GPU DWT is a stage-level step in the shared wavelet transform, default-on ≥ 3 MP, and `encodeGPU()` for lossless is bit-exact.

Changed:
- `J2KRoutePlanner.gpuEncodeEligible` → admits all intents (was lossy-only). This one function flip is the whole policy change; `planEncode`/`effectiveEncodeBackend` inherit it automatically.
- `J2KSwiftCodec.encodeFrame` + `CodecBackend.effectiveEncodeBackend` comments updated; `verifyEncodedRoundTrip` retained as the unconditional lossless backstop.
- `CompressionConsole.compressBackend` note reworded — a forced-Metal request is now only downgraded for non-J2K codecs or when Metal is unavailable (the old "GPU lossy only" text was stale).

Tests:
- `Tests/DICOMCoreTests/J2KGPUEncodeRoundTripTests.swift` (new) — 6 forced-Metal **lossless round-trips**: Part-1 lossless-only `.90` (8-bit), Part-1 `.91` (12/16-bit + RGB), HTJ2K `.201` (16-bit), plus a **2048×2048 (4 MP) 16-bit** case that crosses the 3 MP threshold and exercises the GPU forward-5/3 DWT end-to-end. All byte-exact.
- Updated `J2KRoutePlannerTests` (policy now all-intents) and `CodecBackendTests` (`metal + lossless → GPU`).
- Result: **44/44 pass** across the three suites (incl. the 4 MP GPU-DWT case, 36.9 s).

**Carried forward to Phase 3:** `enablePart2MCT` is still `false` everywhere — Phase 3 wires it and must first resolve open items #3 (Part-2 decode fidelity) and #4 (grayscale-Part-2 semantics).

### Phase 3 — Part-2 (library-blocked → option 2: reject) ⚠️ (2026-07-13)

**Real Part-2 is impossible on v11.0.2** (§14). Per the chosen policy (option 2), Part-2 *encode* is **rejected** with a clear error; Part-2 *decode* is retained.

- `J2KRoutePlanner.part2MCTDecodeSupported = false` (documents the probe finding) + `unsupportedEncodeReason(transferSyntaxUID:)` (the clear message; the single source of truth).
- Enforced in `J2KSwiftCodec.encodeFrame` (throws) + `canEncode` (false), `CompressionManager.encodePixelDataInPlace` (throws before the generic check), and `supportedEncodingTransferSyntaxes` (excludes `.92/.93` → no registered encoder). Decode list unchanged.
- `planEncode.enablePart2MCT = (type == .part2) && part2MCTDecodeSupported` stays wired for the future flip.
- Tests: planner `test_part2_encode_rejected` + `test_part2_decode_unsupported`; codec `part2Lossless/LossyEncodeRejected` + registry decoder-not-encoder; `J2KGPUEncodeRoundTripTests` Part-2 rejection cells; codec-map parity + preview-parity updated to treat Part-2 as decode-only. All green.

### Phase 4 — decode backend axis ✅ (2026-07-13)

- `J2KRoutePlanner.DecodeAPI {cpu, gpu, gpuHT}` + `planDecode(backend:pixelCount:)` — mirrors J2KSwift's `recommendedDecodeAPI` size band (GPU 0.5–15 MP); `gpuHT` reserved (default-off upstream).
- `J2KSwiftCodec(decodeBackend:)` — new init param; `decodeWithJ2KSwift` dispatches `decode`/`decodeGPU`/`decodeWithGPUHT` per the plan (codestream family auto-detected).
- `CompressionManager.decodePixelDataInPlace(…, backend:)` — new param; builds a decode-backend-aware `J2KSwiftCodec` for JPEG 2000 / HTJ2K sources; the recompress path threads `backend` in.
- Tests: `test_planDecode` (backend × size band).

### Phase 5 — auto → GPU ✅ (2026-07-13)

- `J2KRoutePlanner.shouldUseGPUEncode(forced:intent:)` — `auto` (nil) now selects GPU when Metal is available; forced `.metal` always; `.accelerate`/`.scalar` never. `planEncode.useGPU` and `effectiveEncodeBackend` both route through it (no divergence).
- Tests updated: planner `useGPU` for auto asserts `== isAvailable(.metal)`; `CodecBackendTests` "auto uses Metal when available".

### Phase 6 — reporting + matrix ✅ (2026-07-13)

- `CompressionConsole.compressBackend` note reworded — a forced-Metal downgrade is now only reported for non-J2K codecs or when Metal is unavailable (the old "GPU lossy only" text is gone).
- Matrix coverage: the §5 encode matrix and §6 decode matrix are covered across `J2KRoutePlannerTests` (type/intent/flags/GPU/decode) + `J2KGPUEncodeRoundTripTests` + existing `J2KSwiftCodecTests` (lossy + Part-2 cells).
- Final: full `swift build` clean (all targets incl. `dicom-compress`, DICOMStudio); focused suites **all green, 0 failures**.

---

## 14. Part-2 blocker — why "Real Part-2" is not delivered

**Decision D1 asked for real Part-2. The pinned J2KSwift (v11.0.2) makes it impossible to deliver safely, so it is gated off.**

### The evidence

**Root cause: the ENCODER emits a non-conformant Part-2 codestream — the defect is on the encode side, which makes decode unfixable.**

1. **No conformant decoder can read J2KSwift's Part-2 output.** Encode one 64×64 RGB image two ways (lossless): plain Part-1, and with a reversible array-based MCT. Decode both with the OpenJPEG **and** Kakadu reference decoders and compare to the known original:

   | Codestream | OpenJPEG | Kakadu | vs. original |
   |---|---|---|---|
   | Plain Part-1 | exact | exact | **maxAbsErr 0** |
   | Part-2 MCT | garbage | garbage | **maxAbsErr 253** |

   Both are lossless encodes of the same image, so a valid MCT stream must decode identically to the plain one. Instead every conformant decoder (and J2KSwift itself) produces garbage.

2. **The encoder writes an incomplete marker chain.** Marker scan of the MCT codestream: `SOC, SIZ, COD, QCD, MCO` — the **MCT** (transform matrix, 0xFF74), **MCC** (component collection, 0xFF75), and **CAP** (Part-2 capability, 0xFF50) markers are **missing**. The encoder bakes the forward transform into the coefficients (the MCT stream is smaller — decorrelation ran) but emits only the `MCO` "apply transform" pointer without ever defining the transform. The recipe to invert it is never written.

3. **Decode side also lacks support** (`J2KDecoderPipeline.swift` never parses MCT/MCC/MCO/ADS), but that is moot — even a perfect decoder cannot invert a transform the encoder never described. J2KSwift's own `J2KPart2ConformanceTests` assert only capability *marker bits*, never an end-to-end decode.

### What DICOMKit does instead — option 2: reject with a clear error

A request to **encode** to `.92` / `.93` is **refused** with a specific message
(`J2KRoutePlanner.unsupportedEncodeReason`), rather than emitting a mislabeled or
unreadable codestream:

> *"JPEG 2000 Part 2 Multi-component … (1.2.840.10008.1.2.4.93) encoding is not
> supported: the JPEG 2000 Part-2 multi-component transform cannot be inverted by
> the current decoder, so the resulting codestream would not decode correctly. Use
> JPEG 2000 Part 1 (lossless .90 / general .91) or HTJ2K (.201 / .202 / .203) instead."*

Enforcement (single reason, three layers):
- `J2KSwiftCodec.encodeFrame` throws `DICOMError.unsupportedTransferSyntax(reason)`; `canEncode` returns `false`.
- `CompressionManager.encodePixelDataInPlace` throws the reason before the generic layout check (so `dicom-compress --codec j2k-part2-lossless` prints the specific message, not "unknown codec").
- `J2KSwiftCodec.supportedEncodingTransferSyntaxes` excludes `.92`/`.93` → the registry registers **no Part-2 encoder** (`hasEncoder(.92/.93) == false`), while `supportedTransferSyntaxes` (decode) keeps them so existing Part-2 files can still be **read**.

Part-2 stays listed in the `dicom-compress` codec map and `dicom-convert` targets so that selecting it yields the *clear rejection*, not a generic "unknown codec". (Alternative option 1 — emit Part-1-compatible bytes under the Part-2 UID — was rejected as dishonest labeling.)

**Residual risk (documented):** decoding a *genuine external* Part-2 file that actually uses MCT would silently mis-decode (same library gap). Detecting that requires MCT/CAP marker parsing and is out of scope here; the encode-side rejection prevents DICOMKit from ever *creating* such a file.

### How to enable real Part-2 later (one flag)

When a J2KSwift release adds a self-configuring Part-2 decode path (parses MCT/MCC/MCO/ADS, applies the inverse MCT) **and** ships a bit-exact round-trip test:

1. Set `J2KRoutePlanner.part2MCTDecodeSupported = true`.
2. Wire `plan.enablePart2MCT` in `J2KSwiftCodec.makeEncodingConfiguration` to set `mctConfiguration` (reversible integer MCT for lossless `.92`; array-based for lossy `.93`); decide grayscale (1-component) behaviour (open item #4).
3. Add Part-2 MCT-marker assertions + bit-exact round-trip cells; `verifyEncodedRoundTrip` already backstops lossless.

Until then, real Part-2 is intentionally unreachable — shipping it would corrupt medical images.
