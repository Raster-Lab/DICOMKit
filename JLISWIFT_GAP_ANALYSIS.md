# JLISwift Gap Analysis

Verified 2026-07-14 against **JLISwift `v0.5.0`, commit `9f1c6eb`** — confirmed via `git ls-remote --tags` and `git ls-remote HEAD` against `github.com/Raster-Lab/JLISwift` to be both the latest tagged release *and* current `main` HEAD (no unreleased commits past the tag). This is also the exact commit DICOMKit's `Package.resolved` already pins, so DICOMKit is not behind. Verified by cloning fresh from GitHub, not by reading a possibly-stale local `.build/checkouts/` copy (see note below).

> **Process note:** an earlier pass of this analysis produced a false "critical" finding (16-bit lossless decode broken) by (a) reading a JLISwift checkout from an unrelated sibling repo on disk instead of this project's own dependency, and (b) generalizing from one validation gate without tracing the full decode call graph. Both errors are corrected here; see "Verified non-issues" below. Going forward, findings in this doc are grounded in a fresh `git clone` of confirmed-latest source, with claims traced end-to-end through the actual code path rather than a single function in isolation.

## Bit-depth support matrix

| SOF type | Marker | Encode | Decode | Notes |
|---|---|---|---|---|
| SOF0 (baseline) | 0xC0 | 8-bit | 8-bit | Fully symmetric |
| SOF1 (extended sequential) | 0xC1 | 12-bit | 12-bit | Fully symmetric; also reads 12-bit libjpeg/ImageIO files |
| SOF2 (progressive) | 0xC2 | 8-bit only | 8-bit only | Fully implemented for 8-bit (DC/AC scans, EOBRUN, successive approximation); no 12-bit progressive path exists. DCT Huffman category tables top out at 12-bit by design (`JLIEncoder.swift:161-163`) |
| SOF3 (lossless) | 0xC3 | 2–16-bit | 2–16-bit | Fully separate code path from DCT — branches off before the DCT-only `validateDecodable` 8/12-bit gate (`JLIDecoder.swift:71-76`), with its own `(2...16).contains(precision)` check (`JLIDecoder.swift:554`) |

## Color / sampling support

**Encode:** Grayscale, RGB, RGBA, pre-converted YCbCr (8-bit); YCbCr BT.601 (Accelerate-backed, 8-bit); 12-bit RGB→YCbCr (RGB/RGBA input only — 12-bit pre-converted YCbCr input is rejected, `JLIEncoder.swift:155-159`); chroma subsampling 4:4:4/4:2:2/4:2:0/4:0:0; XYB (JPEG-XL perceptual space, experimental, 8-bit RGB/4:4:4 only); CMYK enum case exists but unimplemented.

**Decode:** Grayscale and RGB auto-detected; 12-bit YCbCr→`.uint16` RGB; `.float32` output for grayscale and XYB only (explicit throw, not silent wrong output, for YCbCr→RGB and lossless — `JLIDecoder.swift:472-479`); reduced-scale decode (1/2, 1/4, 1/8) via DC-coefficient averaging; no CMYK/YCCK (4-component) decode path; lossless decode requires 1×1 chroma sampling only (no subsampled lossless — `JLIDecoder.swift:579-581`), grayscale or RGB only (`:575-578`).

## Gap list (prioritized)

### 🔴 Critical
None found.

### 🟠 High
None found. Grep across `Sources/` for `TODO`/`FIXME`/"not implemented"/`fatalError`/`preconditionFailure` returned zero hits; no `XCTSkip` or disabled tests in `Tests/JLISwiftTests`.

### 🟡 Medium
1. **Signed pixel data rejected on the lossy DCT path, by design** (`JLIEncoder.swift:135-138`, `if image.isSigned { throw ... }`). Only the lossless path preserves signed samples bit-exactly. Deliberate, documented (ROADMAP §WS-M2, deferred stretch item), not a bug — but a real functional gap if DICOMKit ever wants lossy-compressed signed CT.
2. **Subsampled lossless unsupported** — lossless requires 1×1 sampling on every component (`JLIDecoder.swift:579-581`); irrelevant to DICOM since lossless JPEG is always 4:4:4/1×1 in practice.
3. CMYK/YCCK is a dead enum case (`Core/JLIImage.swift:44-45`) with zero conversion/APP14 logic anywhere. False-capability trap for other consumers; DICOM never uses CMYK JPEG so no impact here.
4. JLIDICOM's own DICOM container layer (Big-Endian, RLE, JPEG-2000/JPEG-LS-in-DICOM, PALETTE COLOR, overlays, ICC-in-object) is explicitly documented as out of scope (`MEDICAL_GRADE_ASSESSMENT.md` §8, `docs/regulatory/DICOM_CONFORMANCE_STATEMENT.md`). Moot for DICOMKit, which bypasses JLIDICOM's container and talks to `JLIEncoder`/`JLIDecoder`/`JLIImage` directly.
5. 12-bit progressive (SOF2) isn't on any roadmap and remains 8-bit-only by design. Currently inert for DICOMKit since it never registers the progressive transfer syntaxes (1.2.840.10008.1.2.4.52/53).

### 🟢 Low
6. **Stale docstring**: `JLIDecoder.swift:12-14` still says "full progressive decoding is planned for a future milestone," but progressive (SOF2) decode is fully implemented and tested per ROADMAP.md and the `ProgressiveDecoder`/`ProgressiveEncoder` code paths. Cosmetic doc-lag only.
7. Restart-interval for lossless requires row-alignment (`restartInterval % width == 0`) — matches libjpeg-turbo's own constraint, not a gap vs. the reference implementation.

### Verified non-issues (checked closely, confirmed fine)
- **16-bit lossless decode**: works correctly. Confirmed by full code trace (separate path from the DCT precision gate) *and* by a real-world round trip — compressing/decompressing a genuinely 16-bit-stored CT DICOM (`Bits Allocated=16`, `Bits Stored=16` per `dicom-info`) through JPEG-Lossless SV1 in DICOMKit's `dicom-compress` tool produced correct 16-bit images both directions.
- **Thread-safety of concurrent frame decode/encode**: parallel lossless-segment decode and parallel DCT reconstruction both use `@unchecked Sendable` pointer carriers over disjoint row/block ranges, gated by a 52-case SHA-256 bit-exactness CI check plus forced-serial equality tests — a deliberately validated pattern, not an ad hoc unsafe shortcut.
- **Decompression-bomb / large-CT-volume memory safety**: both DCT (`maxDecodablePixels = 1<<28`, `JLIDecoder.swift:1017`) and lossless (`:571-574`) paths cap total pixels before allocation.
- **Metal GPU acceleration**: the kernel file was deliberately deleted as dead code in the 0.5.0-perf branch (per ROADMAP.md) — no GPU path exists, and none is claimed. (Earlier README language calling it "compiles but not wired" was itself stale relative to this deletion — not re-verified against current README in this pass.)
- **Arithmetic coding**: Huffman-only, not planned — standard for DICOM, no impact.
- **JFIF vs. Exif/APP1 and APP2 ICC**: both parsed and cross-validated against libjpeg-turbo.

## Roadmap / version status
`HEAD` (`9f1c6eb`) == tag `v0.5.0` == `origin/main` — no unreleased commits past the tag. ROADMAP.md's "Last updated" entry (2026-06-12) describes the 0.5.0-perf pass as complete, all five phases landed, no in-progress unreleased version string found. `MEDICAL_GRADE_ASSESSMENT.md` is explicit that "medical grade" claims remain unauthorized regardless of code quality — a process/regulatory verdict, not a code-correctness one, and unaffected by this analysis.

## Bottom line
No critical or high-priority defect currently affects DICOMKit's actual usage surface (baseline 8-bit, extended 12-bit, lossless/SV1 up to 16-bit, restart markers). The medium items (signed lossy, CMYK, JLIDICOM container scope, 12-bit progressive) are either out of DICOMKit's current invocation path or genuinely deferred-by-design upstream features worth tracking if DICOMKit's requirements expand — none require action today.

## Relevant files
- `Decoder/JLIDecoder.swift`, `Encoder/JLIEncoder.swift` — JLISwift (fresh clone, commit `9f1c6eb`)
- `ROADMAP.md`, `MEDICAL_GRADE_ASSESSMENT.md`, `docs/regulatory/DICOM_CONFORMANCE_STATEMENT.md` — JLISwift
- `Sources/DICOMCore/ImageCodec.swift`, `Sources/DICOMCore/JLICodec.swift` — DICOMKit
