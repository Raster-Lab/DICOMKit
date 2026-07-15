# J2KSwift Bug Report (Active Transcoder Blocker + Historical Notes)

> Status update (2026-07-15): J2KSwift 11.0.2 coefficient transcoding does not preserve decoded pixels. DICOMKit temporarily quarantines that path and uses full-frame decode/re-encode for J2K ↔ HTJ2K conversion. Older integration findings remain below for history.

## Active Blocker — J2K ↔ HTJ2K Coefficient Transcoding Corrupts Pixels

**Status**: Blocking upstream defect; temporary DICOMKit safety mitigation explicitly approved by the repository owner

**J2KSwift version**: 11.0.2, revision `b1949084eeedaafb40bff8f1745bbab19e4bc36d`

**Date verified**: 2026-07-15

**Area**: `J2KTranscoder`, legacy J2K ↔ HTJ2K in both directions

### Reproduction evidence

The standalone J2KSwift comparison harness measured severe pixel changes after a nominally lossless coefficient transcode:

| Direction | Bit exact | PSNR | Mean absolute error | Maximum error |
|-----------|-----------|------|---------------------|---------------|
| Legacy J2K → HTJ2K | No | 8.14595 dB | 25,615.84 | 32,768 |
| HTJ2K → legacy J2K | No | 7.81341 dB | 26,484.97 | 33,122 |

A true DICOMKit compressed-to-compressed test also reproduced both failures on the active consumer path before mitigation:

- J2K → HTJ2K changed the full 64 × 64 gradient to a constant value of 128.
- HTJ2K → J2K produced an invalid codestream that failed with `Unexpected end of data at position 32`.

### Causal finding

`J2KTranscoder` passes a whole tile payload to each synthetic code-block rather than reconstructing canonical code-block descriptors and payload boundaries. Decode failures are caught and replaced with zero coefficients. The caller can therefore receive a syntactically returned result even though image content was lost.

### Consumer impact and temporary mitigation

- `HTJ2KCodec.transcodeToHTJ2K` and `transcodeFromHTJ2K` fail closed instead of returning corrupted data.
- `TransferSyntaxConverter` decodes each complete encapsulated frame to pixels and re-encodes it with the target codec under the caller's compression configuration.
- Complete frames are assembled from the Basic Offset Table when present. Ambiguous multi-frame data without usable boundaries is rejected rather than guessed.
- End-to-end tests compare decoded pixel bytes in both directions.

Extended Offset Table-only multi-frame input with more than one fragment per frame is not yet assembled by this fallback. It fails closed when the Basic Offset Table and fragment count do not provide unambiguous boundaries.

This mitigation is intentionally temporary. It uses the same codec pixel representation, but it is slower and intentionally changes the two public direct-transcode methods to throw a clear error instead of returning corrupted data. Remove the quarantine only after the upstream coefficient path meets the exit criteria below.

### Upstream exit criteria

- Reconstruct and validate real tile/component/resolution/subband/code-block descriptors.
- Never replace a decode error with zero coefficients; return a descriptive failure.
- Preserve decoded pixels exactly in both directions across 8-bit, 12/16-bit signed and unsigned, RGB, multi-tile, multi-component, multi-frame, and progression-order cases.
- Validate generated codestreams with independent decoders such as OpenJPEG or Grok.
- Re-enable DICOMKit direct APIs and the fragment-level fast path only after the upstream fix is released and consumer tests pass.

---

## Historical Phase 2 Note — HTJ2K Lossy 16-bit Real Sample Decodes Too Short

**Status**: Known upstream issue on J2KSwift v3.2.0, accepted as non-blocking for the current DICOMKit milestone
**Area**: HTJ2K lossy encode/decode
**Platform**: macOS arm64, Swift 6.2
**DICOMKit evidence**:
- Verified HTJ2K lossless and RPCL round-trips pass on a real LocalDatasets MR sample
- Verified benchmark shows HTJ2K lossless decode improvement from **4767.679 ms** to **900.251 ms** (**5.296×**)
- HTJ2K lossy on the same real 16-bit payload currently throws during decode validation with:
  - `Parsing failed: Decoded component data too short: expected 524288 bytes, got 131072`

**Impact**:
- Phase 2 lossless and RPCL support are working in DICOMKit
- HTJ2K lossy validation against real 16-bit DICOM payloads is a known limitation but is not considered blocking for current progress
- No DICOMKit-side workaround has been added, per project policy

---

## Historical Phase 1 Issues (fixed upstream in v3.2.0)

**Reporter**: DICOMKit Phase 1 J2KSwift integration
**J2KSwift version observed**: 2.4.0 (revision `4ae0990b7bbe0e1d7c67de6aa433f33a6d3a3fad`)
**Platform**: macOS (arm64e), Swift 6.2
**Date**: 2026-04-20
**DICOMKit branch**: `feature/j2kswift-v3-integration`
**Adapter under test**: [Sources/DICOMCore/J2KSwiftCodec.swift](Sources/DICOMCore/J2KSwiftCodec.swift)
**Test suite**: [Tests/DICOMCoreTests/J2KSwiftCodecTests.swift](Tests/DICOMCoreTests/J2KSwiftCodecTests.swift)

The DICOMKit adapter calls J2KSwift directly (no ImageIO workaround). With workarounds removed, the following bugs surface from the J2KSwift codec path. All four bugs need to be fixed in the upstream `J2KSwift` repository before Phase 1 can be marked complete.

---

## Reproduction Setup

DICOMKit's adapter feeds J2KSwift through:

```swift
let encoder = J2KEncoder(encodingConfiguration: J2KEncodingConfiguration(
    quality: 1.0,            // (or configuration.quality.value for lossy)
    lossless: true,
    decompositionLevels: 0,
    qualityLayers: 1,
    progressionOrder: .lrcp
))
let encoded = try encoder.encode(image)
let decoded = try J2KDecoder().decode(encoded)
```

`J2KImage` is constructed with one `J2KComponent` per sample plane (1 for grayscale, 3 for RGB), `bitDepth = descriptor.bitsStored`, `signed = descriptor.isSigned`. 16-bit samples are passed in **little-endian** byte order matching the DICOM stream.

The DICOMKit test suite runs round-trip checks:

| Test | Layout | Quality |
|------|--------|---------|
| 8-bit grayscale | 1 channel × 8-bit unsigned, 32×32 | lossless |
| 16-bit grayscale | 1 channel × 16-bit unsigned, 32×32 | lossless |
| 12-bit-in-16-bit grayscale | 1 channel × `bitsStored=12 / bitsAllocated=16` | lossless |
| Lossy grayscale | 1 channel × 8-bit unsigned | quality 0.5 |
| RGB lossless | 3 channels × 8-bit unsigned, 16×16 | lossless |

---

## Bug 1 — Lossless 8-bit grayscale round-trip is **not lossless**

**Test**: `Lossless 8-bit grayscale round-trip preserves payload`
**Error**:

```
J2KSwiftCodecTests.swift:124:6: Caught error: Parsing failed:
J2KSwift lossless round-trip validation failed
```

**Behaviour**: `J2KEncoder` accepts the input and `J2KDecoder` returns a byte buffer of the correct length, but the decoded bytes do **not** equal the input bytes despite `J2KEncodingConfiguration.lossless = true`.

**Expected**: with `lossless = true` and `quality = 1.0`, the decoded buffer must equal the input byte-for-byte (per JPEG 2000 Part 1 reversible 5/3 wavelet + reversible color transform).

**Suspected cause**:
- The reversible (5/3) wavelet may not be applied even when `lossless = true`.
- Or the quantizer is run for a lossless tile and introduces error.
- Or `decompositionLevels = 0` is interpreted as "encode without DC handling" and rounds samples.

**Suggested fix**: when `lossless == true`, force the 5/3 reversible filter, disable quantization, and ensure the inverse transform is exact.

---

## Bug 2 — Lossless 12-bit-in-16-bit grayscale is **not lossless**

**Test**: `12-bit grayscale in 16-bit container round-trip preserves payload size`
**Error**:

```
J2KSwiftCodecTests.swift:162:6: Caught error: Parsing failed:
J2KSwift lossless round-trip validation failed
```

**Behaviour**: identical symptom to Bug 1 — bytes change between encode → decode despite `lossless = true`. Component is constructed with `bitDepth = 12, signed = false`, packed in 16 bits per sample.

**Expected**: lossless contract holds for `bitDepth < bytesPerSample × 8`.

**Suspected cause**: encoder may be using `bitsAllocated * 8 = 16` as the active range and quantizing to 12 bits incorrectly, or vice versa.

**Suggested fix**: respect `J2KComponent.bitDepth` for both quantization range and inverse-transform clipping.

---

## Bug 3 — Lossless RGB round-trip drops two of three components

**Test**: `Lossless RGB round-trip preserves dimensions`
**Error**:

```
J2KSwiftCodecTests.swift:195:6: Caught error: Parsing failed:
Decoded component count 1 does not match samples per pixel 3
```

**Behaviour**: `J2KEncoder.encode(_:)` is called with a `J2KImage(colorSpace: .sRGB, components: [r, g, b])` (3 components). `J2KDecoder.decode(_:)` returns a `J2KImage` with only **1** component.

**Expected**: round-trip must preserve the component count (`image.components.count == 3` after decode).

**Suspected cause**:
- `J2KEncoder` may be discarding components 1 and 2.
- Or the codestream main header is being written with `Csiz = 1` regardless of input.
- Or the irreversible color transform (RCT/ICT) is being applied without storing the resulting per-component subbands.

**Suggested fix**: confirm that `J2KEncoder` writes `Csiz` and `SIZ` markers matching `image.components.count`, and that all component subbands are emitted.

---

## Bug 4 — `Int32` overflow crashes the process for 16-bit lossless / lossy grayscale

**Tests crashed (process aborted before test verdict)**:
- `Lossless 16-bit grayscale round-trip preserves payload`
- `Lossy grayscale round-trip preserves dimensions`

**Error** (fatal — `SIGTRAP`):

```
Swift/arm64e-apple-macos.swiftinterface:42109: Fatal error:
Double value cannot be converted to Int32 because
the result would be greater than Int32.max
```

(Followed by `error: Exited with unexpected signal code 5` — the test runner is terminated.)

**Likely call sites in J2KSwift 2.4.0** (from earlier inspection during Phase 1):

| File | Line(s) | Pattern |
|------|---------|---------|
| `J2KQuantization.swift` | 616, 629, 636, 643 | `Int32(Double(magnitude) / stepSize)` |
| `J2KDecoderPipeline.swift` | 847 | `Int32(Double(...))` without clamping |
| `J2KExtendedROI.swift` | 241, 423, 481 | `Int32(Double(...))` without clamping |
| `J2KDWT1D.swift` | 216–282 | `Int32(Double(...))` without clamping |

**Behaviour**: For `bitDepth = 16` lossless input, the magnitude post-DWT can exceed `Int32.max` when divided by a near-zero quantization step (or for lossy when the stepSize denominator is small).

**Expected**: encoder must never crash on valid in-range inputs. JPEG 2000 specifies fixed-point arithmetic; `Int32` overflow is a programming bug, not a content bug.

**Suggested fix**: replace every `Int32(Double(x))` with a clamped conversion such as:

```swift
@inlinable
func clampedInt32(_ value: Double) -> Int32 {
    if value >= Double(Int32.max) { return Int32.max }
    if value <= Double(Int32.min) { return Int32.min }
    return Int32(value)
}
```

Apply at every quantization, dequantization, ROI shift, and DWT step. Better still, refactor the quantization pipeline to use `Int64` internally for accumulators and only narrow at marker-write time, with explicit clamping.

---

## Bugs that are *not* present (verified working)

For the record, the following Phase 1 paths exercise J2KSwift end-to-end and currently pass:

- `Supports JPEG 2000 transfer syntaxes` — supportedTransferSyntaxes wiring
- `canEncode accepts supported descriptor layouts` — descriptor matrix
- `canEncode rejects unsupported descriptor layouts`
- `CodecRegistry exposes a JPEG 2000 codec and encoder`
- `TransferSyntax helpers recognize Part 2 and HTJ2K families`
- `Decoding empty data throws` — empty-input guard
- All seven non-round-trip tests pass cleanly.

---

## Test Output (verbatim)

```
◇ Suite "J2KSwiftCodec Tests" started.
✔ Test "TransferSyntax helpers recognize Part 2 and HTJ2K families" passed after 0.001 seconds.
✔ Test "canEncode rejects unsupported descriptor layouts" passed after 0.001 seconds.
✔ Test "canEncode accepts supported descriptor layouts" passed after 0.001 seconds.
✔ Test "CodecRegistry exposes a JPEG 2000 codec and encoder" passed after 0.001 seconds.
✔ Test "Supports JPEG 2000 transfer syntaxes" passed after 0.001 seconds.
✔ Test "Decoding empty data throws" passed after 0.001 seconds.
✘ Test "Lossless RGB round-trip preserves dimensions" recorded an issue at J2KSwiftCodecTests.swift:195:6:
    Caught error: Parsing failed: Decoded component count 1 does not match samples per pixel 3
✘ Test "Lossless 8-bit grayscale round-trip preserves payload" recorded an issue at J2KSwiftCodecTests.swift:124:6:
    Caught error: Parsing failed: J2KSwift lossless round-trip validation failed
✘ Test "12-bit grayscale in 16-bit container round-trip preserves payload size" recorded an issue at J2KSwiftCodecTests.swift:162:6:
    Caught error: Parsing failed: J2KSwift lossless round-trip validation failed
Swift/arm64e-apple-macos.swiftinterface:42109: Fatal error:
    Double value cannot be converted to Int32 because the result would be greater than Int32.max
error: Exited with unexpected signal code 5
```

---

## Required Action

Open four issues against [Raster-Lab/J2KSwift](https://github.com/Raster-Lab/J2KSwift) — one per bug above, each linking back to this report and to the failing test name. Phase 1 of `J2KSWIFT_INTEGRATION_PLAN.md` is **blocked** on these fixes; no DICOMKit workaround will be added per the project owner's direction.

Until then, DICOMKit Phase 1 status is:

- ✅ Adapter, registry, transfer-syntax wiring, encode/decode plumbing complete
- ✅ 7 / 11 J2KSwift codec tests pass (configuration, registry, helpers, error paths)
- 🔴 4 / 11 round-trip tests blocked by upstream J2KSwift bugs (Bugs 1–4 above)
