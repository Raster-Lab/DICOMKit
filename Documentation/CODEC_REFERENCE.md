# DICOMKit Codec Reference

A developer reference for the four Swift codec libraries integrated into DICOMKit Core:
**J2KSwift**, **JLSwift**, **JLISwift**, and **JXLSwift**.

---

## Quick-reference table

| Library | Runtime engine | In `CodecRegistry` | DICOM Transfer Syntaxes |
|---|---|---|---|
| **J2KSwift** | Pure Swift + custom NEON C (HT blocks) | ✅ Active | 7 — J2K Part 1/2 + HTJ2K |
| **JLSwift** | Pure Swift | ✅ Active | 2 — JPEG-LS lossless + near-lossless |
| **JLISwift** | Pure Swift + Accelerate | ✅ Active | 4 — JPEG Baseline/Extended (lossy) + Lossless/SV1 |
| **JXLSwift** | Pure Swift (C perf layer scaffolded) | ✅ Active | 2 — JPEG XL Lossless (encode + decode) + JPEG XL general (decode only) |

---

## J2KSwift — JPEG 2000 + HTJ2K

Pure Swift implementation with a small custom C + NEON layer for HT block-coding.
No external runtime dependencies (OpenJPEG, OpenJPH, Grok, Kakadu are test-time
validation oracles only).

### Library targets / products

| Target | Description |
|---|---|
| `J2KCore` | Codestream parser and writer |
| `J2KCodec` | Main JPEG 2000 encoder and decoder (Part 1 & Part 2) |
| `J2KCodecNEON` | Custom C + NEON block encode/decode for HTJ2K (Part 15) |
| `J2KMetal` | GPU-accelerated inverse DWT via Metal |
| `J2K3D` | Volumetric JPEG 2000 (JP3D, 3-D codestreams) |
| `JPIP` | JPEG 2000 Internet Protocol streaming |
| `J2KDICOMHelpers` | DICOM bridge helpers |

### DICOMCore codecs (`Sources/DICOMCore/`)

**`J2KSwiftCodec`** — registered for all seven J2K UIDs:

| Transfer Syntax UID | Name |
|---|---|
| `1.2.840.10008.1.2.4.90` | JPEG 2000 Lossless |
| `1.2.840.10008.1.2.4.91` | JPEG 2000 |
| `1.2.840.10008.1.2.4.92` | JPEG 2000 Part 2 Lossless |
| `1.2.840.10008.1.2.4.93` | JPEG 2000 Part 2 |
| `1.2.840.10008.1.2.4.201` | HTJ2K Lossless _(overridden — see below)_ |
| `1.2.840.10008.1.2.4.202` | HTJ2K RPCL Lossless _(overridden — see below)_ |
| `1.2.840.10008.1.2.4.203` | HTJ2K Lossy _(overridden — see below)_ |

**`HTJ2KCodec`** — overrides the three HTJ2K entries with HTJ2K-specific configuration:

| Transfer Syntax UID | Name |
|---|---|
| `1.2.840.10008.1.2.4.201` | HTJ2K Lossless |
| `1.2.840.10008.1.2.4.202` | HTJ2K RPCL Lossless |
| `1.2.840.10008.1.2.4.203` | HTJ2K Lossy |

---

## JLSwift — JPEG-LS

Pure Swift implementation of JPEG-LS (ISO 14495-1).
CharLS is a test-time validation oracle only, not a runtime dependency.

### Library targets / products

| Target | Description |
|---|---|
| `JPEGLS` | Native Swift JPEG-LS encoder and decoder (lossless + near-lossless) |

### DICOMCore codecs (`Sources/DICOMCore/`)

**`JPEGLSCodec`** — registered for both JPEG-LS UIDs (decoder and encoder):

| Transfer Syntax UID | Name |
|---|---|
| `1.2.840.10008.1.2.4.80` | JPEG-LS Lossless |
| `1.2.840.10008.1.2.4.81` | JPEG-LS Near-Lossless |

---

## JLISwift — JPEG (all modes, including lossless)

Pure Swift implementation of all ITU-T T.81 JPEG modes: baseline, extended-sequential,
progressive, and lossless (SOF3 predictive).
Hot paths accelerated via Apple's Accelerate framework (`vDSP_mmul`, `vDSP_vmul`).
Validated against libjpeg-turbo, mozjpeg, and jpegli — none are runtime dependencies.

### Library targets / products

| Target | Description |
|---|---|
| `JLISwift` | Baseline / extended / progressive / lossless JPEG codec |
| `JLIDICOM` | DICOM-specific helpers |
| `JLIBench` | Benchmark harness |

### DICOMCore codec (`Sources/DICOMCore/`)

**`JLICodec`** — registered in `CodecRegistry` as the active JPEG codec for all
four DICOM JPEG transfer syntaxes, both decode and encode. The decoder is
mode-agnostic (the SOF marker selects baseline/extended/progressive/lossless); the
encoder is per-syntax — the registry constructs one instance per encode UID via
`JLICodec(encodingTransferSyntaxUID:)`, and that UID selects the JPEG process:

| Transfer Syntax UID | Name | JPEG process | Quality |
|---|---|---|---|
| `1.2.840.10008.1.2.4.50` | JPEG Baseline (Process 1) | SOF0 DCT, 8-bit | Lossy |
| `1.2.840.10008.1.2.4.51` | JPEG Extended (Process 2 & 4) | SOF1 DCT, ≤12-bit | Lossy |
| `1.2.840.10008.1.2.4.57` | JPEG Lossless (Process 14) | SOF3 predictive | Lossless |
| `1.2.840.10008.1.2.4.70` | JPEG Lossless SV1 (Process 14, SV1) | SOF3 predictive, predictor 1 | Lossless |

Behaviour notes:
- **Mode is driven by the transfer syntax, not the quality flag.** The lossless
  syntaxes are always bit-exact (point transform 0); the lossy syntaxes map
  `CompressionConfiguration.quality` (0.0–1.0) to a JPEG quality factor (1–100).
- **Lossy is sequential and 4:4:4.** DICOM JPEG Baseline/Extended are non-progressive,
  so progressive is forced off; chroma is kept full-resolution for diagnostic fidelity.
- **Signed samples** (e.g. CT Hounsfield) are accepted on the lossless path (bytes
  preserved exactly) and rejected on the lossy DCT path (undefined level shift).
- A bare `JLICodec()` defaults to lossless SV1, so it round-trips bit-exactly — the
  contract `DICOMStudio/Services/J2KTestBenchService.swift` and the multi-codec bench
  adapter tests rely on for codec comparison.

This makes `dicom-compress --codec jpeg-baseline|jpeg-extended|jpeg-lossless|jpeg-lossless-sv1`
fully functional, and works on every platform (the prior ImageIO path was Apple-only
and could encode Baseline only).

---

## JXLSwift — JPEG XL

Pure Swift implementation of ISO/IEC 18181 JPEG XL (Modular and VarDCT modes).
An optional C performance layer (`JXLPerfC`) is scaffolded but not yet wired into
the codec path. libjxl 0.11.2 is used as a byte-exact test-time oracle only.

### Library targets / products

| Target | Description |
|---|---|
| `JXLSwift` | Full JPEG XL encoder and decoder (Modular + VarDCT) |
| `JXLPerfC` | Optional C hot-path primitives (scaffolded, not yet active) |
| `JXLTool` | CLI tool |

### DICOMCore codec (`Sources/DICOMCore/`)

**`JXLCodec`** — registered in `CodecRegistry` as the active JPEG XL codec.
Also used by `DICOMStudio/Services/J2KTestBenchService.swift` for codec comparison
benchmarking.

| Transfer Syntax UID | Name | Decode | Encode |
|---|---|---|---|
| `1.2.840.10008.1.2.4.110` | JPEG XL Lossless | ✅ | ✅ |
| `1.2.840.10008.1.2.4.112` | JPEG XL (general / lossy) | ✅ | — (decode-only) |
| `1.2.840.10008.1.2.4.111` | JPEG XL JPEG Recompression | — | — (unsupported) |

---

## CodecRegistry wiring

**Location:** `Sources/DICOMCore/ImageCodec.swift`

`CodecRegistry` maintains two dictionaries keyed by Transfer Syntax UID:
- `decoderRegistry` — returns `(any ImageCodec)?` via `codec(for:)`
- `encoderRegistry` — returns `(any ImageEncoder)?` via `encoder(for:)`

Registration order matters for HTJ2K: `J2KSwiftCodec` is registered first for all
seven UIDs, then `HTJ2KCodec` overwrites the three HTJ2K entries with its own instance.

`JLICodec` (JLISwift) is the registered JPEG codec for the four JPEG UIDs — one
shared decoder, plus one encoder instance per UID. `NativeJPEGCodec` (ImageIO) is
no longer wired into the registry; it remains in the tree as a standalone Apple
codec and is still exercised by its own unit tests.

`JXLCodec` (JXLSwift) is the registered JPEG XL codec — one shared instance decodes
both `.110` and `.112`; encoding is limited to `.110` (lossless Modular).

Other codecs in the registry (not from these four libraries):

| Codec | Transfer Syntax UIDs |
|---|---|
| `RLECodec` | `1.2.840.10008.1.2.5` RLE Lossless |
| `JP3DCodec` | Private JP3D lossless + lossy UIDs |

---

## Transfer Syntax categories

The DICOM transfer syntaxes DICOMKit handles can be read along three orthogonal
dimensions: pixel data storage format, compression quality, and VR/byte-order encoding.

### Dimension 1 — Pixel data storage format

| Category | Transfer Syntaxes | `isEncapsulated` |
|---|---|:---:|
| **Native** — pixel data as a flat byte blob | ImplicitVRLittleEndian, ExplicitVRLittleEndian, ExplicitVRBigEndian | — |
| **DEFLATE** — whole dataset zlib-compressed, pixel data not encapsulated | DEFLATE (`isDeflated: true`) | — |
| **Encapsulated** — pixel data wrapped in Basic Offset Table + fragment items | JPEGBaseline, JPEGExtended, JPEGLossless, JPEGLosslessSV1, RLELossless (and all J2K/HTJ2K/JPEG-LS) | ✅ |

DEFLATE is the unique hybrid: it compresses the entire dataset but does not
encapsulate pixel data. Native and DEFLATE syntaxes require no `ImageCodec`;
encapsulated syntaxes are dispatched through `CodecRegistry`.

### Dimension 2 — Compression quality

| Category | Transfer Syntaxes |
|---|---|
| **Lossless** (`isLossless: true`) | ImplicitVRLittleEndian, ExplicitVRLittleEndian, ExplicitVRBigEndian, DEFLATE, JPEGLossless, JPEGLosslessSV1, RLELossless |
| **Lossy** (`isLossless: false`) | JPEGBaseline, JPEGExtended |

Uncompressed syntaxes are always lossless. DEFLATE is lossless by algorithm.
The two JPEG DCT syntaxes (Baseline and Extended) are the only lossy members
of this group.

### Dimension 3 — VR encoding and byte order

| | Little Endian | Big Endian |
|---|---|---|
| **Implicit VR** | ImplicitVRLittleEndian | — |
| **Explicit VR** | ExplicitVRLittleEndian, DEFLATE, all JPEG / RLE syntaxes | ExplicitVRBigEndian _(Retired)_ |

`isExplicitVR` is `false` only for `ImplicitVRLittleEndian`. `ExplicitVRBigEndian`
was retired in PS3.5 (2011); DICOMKit supports it read-only for legacy files.

### Combined view — core transfer syntaxes at a glance

| Transfer Syntax | UID | `isEncapsulated` | `isLossless` | `isExplicitVR` | Byte order |
|---|---|:---:|:---:|:---:|---|
| ImplicitVRLittleEndian | `1.2.840.10008.1.2` | — | ✅ | ❌ | Little |
| ExplicitVRLittleEndian | `1.2.840.10008.1.2.1` | — | ✅ | ✅ | Little |
| ExplicitVRBigEndian _(Retired)_ | `1.2.840.10008.1.2.2` | — | ✅ | ✅ | Big |
| DEFLATE | `1.2.840.10008.1.2.1.99` | — ¹ | ✅ | ✅ | Little |
| JPEGBaseline | `1.2.840.10008.1.2.4.50` | ✅ | ❌ | ✅ | Little |
| JPEGExtended | `1.2.840.10008.1.2.4.51` | ✅ | ❌ | ✅ | Little |
| JPEGLossless | `1.2.840.10008.1.2.4.57` | ✅ | ✅ | ✅ | Little |
| JPEGLosslessSV1 | `1.2.840.10008.1.2.4.70` | ✅ | ✅ | ✅ | Little |
| RLELossless | `1.2.840.10008.1.2.5` | ✅ | ✅ | ✅ | Little |
| JPEGXLLossless | `1.2.840.10008.1.2.4.110` | ✅ | ✅ | ✅ | Little |
| JPEGXLRecompression | `1.2.840.10008.1.2.4.111` | ✅ | ✅ ² | ✅ | Little |
| JPEGXL | `1.2.840.10008.1.2.4.112` | ✅ | ❌ | ✅ | Little |

_¹ DEFLATE: `isDeflated: true`, `isEncapsulated: false` — compresses the entire dataset, not just pixel data._
_² JPEGXLRecompression is lossless with respect to the original JPEG bitstream, not necessarily the pixels._

### How the codec pipeline uses these categories

| Syntax | Codec |
|---|---|
| ImplicitVRLittleEndian, ExplicitVRLittleEndian, ExplicitVRBigEndian | No codec — pixel data read directly |
| DEFLATE | No codec — dataset inflated via zlib before parsing |
| JPEGBaseline, JPEGExtended | `JLICodec` (lossy DCT, encode + decode) |
| JPEGLossless, JPEGLosslessSV1 | `JLICodec` (SOF3 predictive, encode + decode) |
| RLELossless | `RLECodec` |
| JPEGXLLossless | `JXLCodec` (lossless Modular, encode + decode) |
| JPEGXL | `JXLCodec` (decode only — VarDCT lossy + Modular) |

---

## Validation oracles (test-time only)

None of the four libraries carry runtime C/C++ codec dependencies.
All interoperability validation is performed against external reference implementations
at test time:

| Library | Reference oracle(s) |
|---|---|
| J2KSwift | OpenJPEG, OpenJPH, Grok, Kakadu |
| JLSwift | CharLS |
| JLISwift | libjpeg-turbo, mozjpeg, jpegli, Apple CoreGraphics / ImageIO |
| JXLSwift | libjxl 0.11.2 |
