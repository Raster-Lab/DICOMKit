# J2KSwift Bug Report (Historical + Accepted Phase 2 Note)

> Status update: the Phase 1 issues documented below were reproduced against J2KSwift 2.4.0 during early integration work and have since been fixed upstream in J2KSwift v3.2.0. A Phase 2 HTJ2K lossy issue observed on v3.2.0 is retained below as a documented, non-blocking note for now.

## Active Phase 2 Issue — HTJ2K Lossy 16-bit Real Sample Decodes Too Short

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
