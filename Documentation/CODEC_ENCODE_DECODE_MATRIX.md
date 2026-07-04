# DICOMKit Codec Encode/Decode Matrix

Per–transfer-syntax **decode** and **encode** coverage for the four Swift codec
libraries integrated into DICOMKit Core: **J2KSwift**, **JLSwift**, **JLISwift**,
and **JXLSwift**.

Verified against the live registry wiring in
[`Sources/DICOMCore/ImageCodec.swift`](../Sources/DICOMCore/ImageCodec.swift)
(the `CodecRegistry` initializer), not just documentation.

**Legend**
- ✅ `<Codec>` — wired into `CodecRegistry` and user-facing; the name is the
  **final owning codec** after any registration overrides.
- `— (decode-only)` — the codec decodes this syntax but registers no encoder.
- `— (unsupported)` — no codec backs this syntax (the transfer syntax may still
  be *named/parsed*, but pixel data cannot be (de)coded).

All UIDs are under the `1.2.840.10008.1.2.4.*` prefix unless noted.

---

## 1. J2KSwift — `J2KSwiftCodec` + `HTJ2KCodec`

JPEG 2000 (Part 1 & Part 2) and High-Throughput JPEG 2000 (Part 15).
Pure Swift + a small custom NEON C layer for HT block coding.

| UID | Transfer Syntax | Decode | Encode |
|---|---|---|---|
| `.90` | JPEG 2000 Lossless | ✅ J2KSwiftCodec | ✅ J2KSwiftCodec |
| `.91` | JPEG 2000 (lossy) | ✅ J2KSwiftCodec | ✅ J2KSwiftCodec |
| `.92` | JPEG 2000 Part 2 Lossless | ✅ J2KSwiftCodec | ✅ J2KSwiftCodec |
| `.93` | JPEG 2000 Part 2 (lossy) | ✅ J2KSwiftCodec | ✅ J2KSwiftCodec |
| `.201` | HTJ2K Lossless | ✅ HTJ2KCodec | ✅ HTJ2KCodec |
| `.202` | HTJ2K RPCL Lossless | ✅ HTJ2KCodec | ✅ HTJ2KCodec |
| `.203` | HTJ2K (lossy) | ✅ HTJ2KCodec | ✅ HTJ2KCodec |

**Notes**
- **HTJ2K override:** `J2KSwiftCodec` registers all seven UIDs first; `HTJ2KCodec`
  then **overwrites** `.201/.202/.203` in *both* the decode and encode registries.
  Final owner of the three HTJ2K UIDs is `HTJ2KCodec` (wraps J2KSwift with
  `htj2kBlockFormat: .conformant` for OpenJPH/PACS interop; `progressionOrder: .rpcl`).
- **`canEncode` gate (all seven):** `bitsAllocated ∈ {8,16}`, `samplesPerPixel ∈ {1,3}`.
- **Round-trip check:** lossless encodes run a bit-exact `verifyEncodedRoundTrip`;
  lossy encodes (`.91/.93/.203`) are permitted to differ — `encode ✅` does **not**
  imply round-trip fidelity for those three.
- **Part-2 caveat (`.92/.93`):** routed through the identical Part-1 pipeline; the
  adapter adds **no** explicit multi-component-transform (MCT) configuration.

---

## 2. JLSwift — `JPEGLSCodec`

JPEG-LS (ISO 14495-1 / ITU-T T.87). Pure Swift.
A single shared `JPEGLSCodec()` instance serves both UIDs (decode + encode).

| UID | Transfer Syntax | Decode | Encode |
|---|---|---|---|
| `.80` | JPEG-LS Lossless | ✅ JPEGLSCodec | ✅ JPEGLSCodec |
| `.81` | JPEG-LS Near-Lossless | ✅ JPEGLSCodec | ✅ JPEGLSCodec |

**Notes**
- **NEAR is config-driven, not UID-driven.** Lossless ⇒ `NEAR = 0`;
  near-lossless ⇒ `NEAR = max(0, maxVal·(1−quality)·0.1)`. Because one
  UID-agnostic instance is registered, requesting `.81` with a *lossless* config
  still yields `NEAR = 0` (bit-exact) — TS↔quality consistency is not enforced.
- `canEncode`: `bitsAllocated ∈ {8,16}`, `samplesPerPixel ∈ {1,3}`. No signed-sample guard.

---

## 3. JLISwift — `JLICodec`

Native-Swift legacy JPEG (ITU-T T.81: baseline / extended / lossless),
Accelerate-backed. One shared **mode-agnostic decoder** (the SOF marker auto-selects
baseline/extended/progressive/lossless); a **per-UID encoder** constructed via
`JLICodec(encodingTransferSyntaxUID:)`.

| UID | Transfer Syntax | JPEG process | Decode | Encode |
|---|---|---|---|---|
| `.50` | JPEG Baseline (Process 1) | SOF0 DCT, 8-bit, lossy | ✅ JLICodec | ✅ JLICodec |
| `.51` | JPEG Extended (Process 2 & 4) | SOF1 DCT, ≤12-bit, lossy | ✅ JLICodec | ✅ JLICodec |
| `.57` | JPEG Lossless (Process 14) | SOF3 predictive, lossless | ✅ JLICodec | ✅ JLICodec |
| `.70` | JPEG Lossless SV1 (Process 14, SV1) | SOF3 predictive (predictor 1), lossless | ✅ JLICodec | ✅ JLICodec |

**Notes**
- **Signed samples:** **rejected** on the lossy DCT path (`.50/.51` — level shift
  undefined for signed); **accepted / byte-exact** on the lossless path (`.57/.70`).
- **Mode is driven by the transfer syntax, not the quality flag.** Lossless syntaxes
  are always bit-exact (point transform 0); lossy syntaxes map
  `CompressionConfiguration.quality` (0.0–1.0) to a JPEG quality factor (1–100).
- A bare `JLICodec()` defaults to `.70` (Lossless SV1), so it round-trips bit-exactly —
  the contract the multi-codec bench relies on.
- `NativeJPEGCodec` (Apple ImageIO) is **no longer registered**; `JLICodec`
  superseded it for all four JPEG UIDs.

---

## 4. JXLSwift — `JXLCodec`

JPEG XL (ISO/IEC 18181, Modular + VarDCT). Pure Swift.
A single shared `JXLCodec()` instance is **registered and user-facing**.
Encode is **lossless-only** because the VarDCT lossy encoder is only partially
implemented.

| UID | Transfer Syntax | Decode | Encode |
|---|---|---|---|
| `.110` | JPEG XL Lossless | ✅ JXLCodec | ✅ JXLCodec |
| `.112` | JPEG XL (general) | ✅ JXLCodec | — (decode-only) |
| `.111` | JPEG XL JPEG Recompression | — | — (unsupported) |

**Notes**
- `.112` decodes **both** VarDCT (lossy) and Modular (lossless) bitstreams;
  encoding deliberately targets only `.110`.
- `.111` is a defined / parseable transfer syntax with **no codec** — faithful
  handling requires bit-exact reconstruction of the *original* JPEG bitstream,
  which is not a generic pixel (de)code operation.
- `canEncode` (`.110`): `bitsAllocated ∈ {8,16}`, `samplesPerPixel ∈ {1,3}`,
  **unsigned only** (signed frames rejected, not silently mis-encoded).

### Why `.111` (JPEG XL Recompression) isn't a pixel codec

JPEG XL Recompression is **not** "decode the JPEG to pixels, then re-encode the
pixels as JXL." That would be lossy again (the original quantization is already
baked in) and would discard the exact original JPEG — the one thing `.111` exists
to preserve. It is instead a **coefficient-level bitstream transcode** that never
leaves the frequency domain:

1. **Parse** the source JPEG's entropy-coded (Huffman) DCT coefficients — *without*
   running the inverse DCT. No pixels are ever produced.
2. **Re-pack** those exact quantized coefficients into a JXL VarDCT frame using
   JXL's stronger entropy coder (ANS instead of Huffman) — same coefficients,
   ~20% fewer bytes.
3. **Store a `jbrd` box** (JPEG Bitstream Reconstruction Data: markers, Huffman
   tables, padding, component ordering, APPn/COM segments) so the **byte-for-byte
   identical** original JPEG can be reassembled on retrieval.

So `.111` is lossless *with respect to the original JPEG file*, not just its pixels.
In JXLSwift this is `JXLEncoder().encodeLosslessJPEG(jpegBytes)` — note the input is
**JPEG bytes, not an `ImageFrame`/pixels**.

**Is the `jbrd` machinery implemented in JXLSwift?** Yes. The `jbrd`
(JPEG Bitstream Reconstruction Data) box has a full model, reader, writer, a
forward extractor (`JBRDBox.extract(fromJPEG:)`), a reverse reconstructor
(`JXLToJPEGAdapter.reconstruct`), and a Brotli codec for the marker payloads —
all exercised by ~20 byte-identical end-to-end tests and cross-checked with
`djxl --jpeg`. JXLSwift's Phase J is functionally complete in both directions.
(The inline "scaffold / stub" comments in `JBRDBox.swift` / `JXLEncoder.swift`
are stale; the package's `STATUS-AND-ROADMAP.md §5` is authoritative.)

**So why is `.111` still left unsupported in the DICOMKit registry?** Three reasons:

1. **It doesn't fit the `ImageCodec` contract.** Every registered codec is
   pixel-in / pixel-out (`encodeFrame(pixelData) -> Data`,
   `decodeFrame(_) -> pixelData`). Recompression is `JPEG bytes ⇄ JXL bytes` and
   needs the **original JPEG bitstream** as input, which `encodeFrame(pixels)`
   cannot supply. There is no meaningful "encode `.111` from pixels": if all you
   have is pixels, the original JPEG is already gone and you'd emit `.110`/`.112`
   instead. `.111` belongs in a **transfer-syntax converter** that recompresses the
   encapsulated JPEG fragments of a `.50/.51/.57/.70` object — not in a per-frame
   pixel codec.
2. **The bridge is package-internal — DICOMKit can't reach the reverse path.**
   The entire `jbrd` surface (`JBRDBox`, `JBRDBoxReader`/`Writer`, `JBRDExtractor`,
   `JXLToJPEGAdapter.reconstruct`, `JXLDecoder.decodeJPEGBridgeData`) is
   `package`-scoped — visible only inside the JXLSwift package (its own `JXLTool`
   CLI). The **only** `public` JPEG-bridge entry point is the forward encoder
   `JXLEncoder.encodeLosslessJPEG(jpegBytes)`. There is **no public
   reverse-reconstruct API**, so DICOMKit could *produce* a `.111` JXL but could not
   losslessly recover the original JPEG from it — which defeats the purpose of `.111`.
3. **Bit-depth and size limits exclude the medical JPEG range.** The transcode
   rejects 16-bit quantization tables (`JBRDError.invalidQuantPrecision`, mirroring
   libjxl) — so **12-bit Extended and 16-bit JPEGs can't be bridged**, which are
   exactly the depths medical JPEG uses. The forward path is also capped at
   **≤ 2048 px/side**. (Within those limits it *does* handle baseline, progressive,
   and extended-sequential at 8-bit — it is not "baseline-only.")

Nuance: merely **displaying** a `.111` image wouldn't need any of this — the
embedded JXL can be decoded straight to pixels (the same VarDCT path `.112` uses).
The `jbrd` / coefficient-bridge machinery is required only for the two operations
that define `.111`: **producing** it from an existing JPEG, and **losslessly
reconstructing** the exact original JPEG back out.

---

## Combined at-a-glance

| Library | Codec(s) | UIDs | Decode | Encode |
|---|---|---|---|---|
| J2KSwift | `J2KSwiftCodec`, `HTJ2KCodec` | `.90 .91 .92 .93 .201 .202 .203` | all 7 | all 7 |
| JLSwift | `JPEGLSCodec` | `.80 .81` | both | both |
| JLISwift | `JLICodec` | `.50 .51 .57 .70` | all 4 | all 4 |
| JXLSwift | `JXLCodec` | `.110 .112` (`.111` unsupported) | `.110 .112` | `.110` only |

**Also registered (not from these four libraries):**

| Codec | Transfer Syntax UID(s) | Decode | Encode |
|---|---|---|---|
| `RLECodec` | `1.2.840.10008.1.2.5` — RLE Lossless | ✅ | ✅ |
| `JP3DCodec` | `1.2.826.0.1.3680043.10.511.1` — JP3D Lossless *(private)* | ✅ | ✅ |
| `JP3DCodec` | `1.2.826.0.1.3680043.10.511.2` — JP3D Lossy *(private)* | ✅ | ✅ |

---

## Encoder instance model (how the registry constructs encoders)

| Codec | Encoder construction |
|---|---|
| `J2KSwiftCodec` | **per-UID** — `J2KSwiftCodec(encodingTransferSyntaxUID:)` |
| `HTJ2KCodec` | **per-UID** — `HTJ2KCodec(targetTransferSyntaxUID:)` (overwrites J2KSwiftCodec for `.201/.202/.203`) |
| `JLICodec` | **per-UID** — `JLICodec(encodingTransferSyntaxUID:)` (decode uses one shared mode-agnostic instance) |
| `JPEGLSCodec` | **single shared instance** for `.80` + `.81` (lossless vs near-lossless chosen by config) |
| `JXLCodec` | **single shared instance** (only produces `.110`) |
| `JP3DCodec` | **per-UID** — `JP3DCodec(compressionMode:)` (`.lossless` / `.lossy()`) |
| `RLECodec` | **single shared instance** |

---

## Codecs present in the tree but NOT registered

These exist under `Sources/DICOMCore/` but are **not** wired into `CodecRegistry`,
so they are not user-facing for any transfer syntax:

| Codec | Role |
|---|---|
| `NativeJPEGCodec` | Apple ImageIO JPEG — superseded by `JLICodec`; kept for its own unit tests only |
| `NativeJPEG2000Codec` | Apple ImageIO JPEG 2000 — superseded by `J2KSwiftCodec`/`HTJ2KCodec` |
| `OpenJPEGCodec` | OpenJPEG J2K — **bench-only** (DICOMStudio `J2KTestBenchService`) |
| `DjpegCLICodec` | libjpeg `djpeg` CLI wrapper — bench-only |
| `DjxlCLICodec` | libjxl `djxl` CLI wrapper — bench-only |
| `GrokCLICodec` | Grok HTJ2K CLI wrapper — bench-only |
| `KakaduCLICodec` | Kakadu CLI wrapper — bench-only |

The external reference tools (OpenJPEG, OpenJPH, Grok, Kakadu, CharLS,
libjpeg-turbo, mozjpeg, jpegli, libjxl) are **test-time validation oracles only** —
none of the four libraries carry a runtime C/C++ codec dependency.

---

*Generated from a source-level audit of `ImageCodec.swift`, `J2KSwiftCodec.swift`,
`HTJ2KCodec.swift`, `JPEGLSCodec.swift`, `JLICodec.swift`, `JXLCodec.swift`, and
`TransferSyntax.swift`. If you change codec registration, re-verify against
`CodecRegistry` in `ImageCodec.swift`.*
