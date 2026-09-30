# DICOMRenderKit — DICOM Standard Implementation Report

Generated 2026-09-30. Covers all 10 Swift files in `Sources/DICOMRenderKit/` (about 2,300 lines)
and the shader source `Metal/FrameRender.metal.txt` (347 lines): backend selection, the CPU
backend (an adapter over DICOMKit's `PixelDataRenderer`), the Metal compute backend, the GPU
display path (textures, presentation geometry, `MTKView`) and its memory pool.

**Status: complete, two decisions open.** Every file is bucketed and carries a `NEMA-verified`
marker (`Scripts/check_nema_markers.py Sources/DICOMRenderKit` exits 0: 10 of 10; the shader
carries one too, which the checker does not scan). Every formula, constant and term the rendered
pixel depends on is diffed by script against the frozen 2026a DocBook
([Scripts/diff_renderkit.py](Scripts/diff_renderkit.py): 17 checks — 11 ok, 0 failing, 2 pending
the owner (P-PIPELINE, P-ICC), 4 deferred to other modules (D63–D67)). One behaviour in this
module contradicted the text and is fixed with a test (Metal read 32-bit Pixel Cells as their low
16 bits). The module had no open rows from earlier reports. Five new rows were opened for DICOMCore
and DICOMKit (D63–D67). The work is committed on `feature/dicom-tag-modality-audit`, locally.

Method: [DICOMCORE_STANDARD_IMPLEMENTATION.md → Verification method](DICOMCORE_STANDARD_IMPLEMENTATION.md#verification-method-reuse-for-every-module),
used unchanged. Package target: **DICOM 2026a** (`dicomStandardEdition = "2026a"`,
[DICOMKit.swift](Sources/DICOMKit/DICOMKit.swift)).

**Scope note.** DICOMRenderKit does no value arithmetic of its own. Both backends index byte
tables built in DICOMCore (`WindowLUT`, `ColorSampleLUT`, `PaletteDisplayLUT`) from
`WindowSettings` and `PaletteColorLUT`; the CPU backend is DICOMKit's `PixelDataRenderer`; the
window it renders is prepared by DICOMKit's `DICOMImageExporter.determineWindowSettings` (and
by DICOMStudio). So the diff script resolves every formula the rendered pixel depends on in the
module that defines it, turns it into a Python function, and evaluates it against the formula
extracted from the DocBook. Deviations found in those modules are Deferred findings, not fixed
here. Standard text used: PS3.3 C.7.6.3.1.2 (photometric interpretations, YBR equations, XYB),
C.7.6.3.1.3 (Planar Configuration), C.7.6.3.1.5–.6 (palette descriptor and data), C.7.9.2
(segmented palette data), C.10.6 (spatial transformation order), C.11.1.1.1, C.11.2.1.1
(LUT descriptors), C.11.2.1.2.1 (LINEAR), C.11.2.1.3.1 (SIGMOID, Equation C.11-1), C.11.2.1.3.2
(LINEAR_EXACT), C.11.6.1–C.11.6.1.2 (Presentation LUT), C.11.15.1.1–.2 (ICC Profile, Color
Space); PS3.5 8.1.1 and 8.2 (Pixel Cells, byte order); PS3.6 Annex B (Tables B.1-1,
B.1.N.2-1, B.1.N.2-2). PS3.4 and PS3.14 were fetched and read for N.2 and the GSDF; nothing in
this module depends on them.

---

## Summary

| Bucket | Files | Meaning | Status |
|---|---|---|---|
| A — cites 2026a | 0 | — | ✅ (none) |
| B1 — cites another edition, a CP or a Supplement | 0 | — | ✅ (none) |
| B2 — no citation, behaviour differed from 2026a | 2 | `MetalFrameRenderer` (fixed); `FrameRenderBackend` (what the request cannot carry: P-PIPELINE, P-ICC) | ✅ fixed / ⏳ two owner decisions |
| C1 — plumbing | 6 | Confirmed to carry no standard data | ✅ |
| C2 — standard-derived, edition-stable | 2 (+ the shader) | Diffed all the same; all values match | ✅ |

**10 Swift files total** (plus `Metal/FrameRender.metal.txt`, scored with C2).

### Baseline diff, before any change (2026-09-30, `Scripts/diff_renderkit.py` against HEAD `c6560fa`)

17 checks against PS3.3, PS3.5 and PS3.6 2026a; 11 ok, 1 failing, 2 pending, 3 deferred:

| Check | Standard | Result before | After |
|---|---|---|---|
| LINEAR, SIGMOID, LINEAR_EXACT: DocBook pseudo-code and Equation C.11-1 (MathML) vs `WindowSettings.apply`, evaluated on 8 centres × 7 widths × the points around every threshold | C.11.2.1.2.1, C.11.2.1.3.1, C.11.2.1.3.2 | match (3 / 3) | — |
| Window Width limits | LINEAR w ≥ 1; SIGMOID, LINEAR_EXACT w > 0 | **DEFR D64:** `WindowSettings.init` clamps every width to ≥ 1 | — |
| Identity window c = 2^(n−1), w = 2^n ("a mathematical identity"), byte = floor of the exact value | C.11.2.1.2.1 | **DEFR D63:** 32 / 256 (n = 8), 1 / 4,096 (12), 32 / 65,536 (16) inputs one level low | — |
| VOI applied after the Modality LUT / rescale | C.11.2.1.2.1 | **PEND P-PIPELINE** (the request has no Modality LUT); **DEFR D65:** the stored-unit conversion `(c−b)/m`, `w/|m|` is exact for slope 1 only; slope 2 / 0.5 differ on 4–124 of 4,000 values, slope −1 on 3,999 (inverted) | — |
| Auto (full input range) window when none is given | C.11.2.1.2.1: `(x1+x2+1)/2`, `x2−x1+1` | **DEFR D66:** `(min+max)/2`, `max−min` in `PixelDataRenderer` and the exporter; 127 / 4,001 values differ, `max−1` already saturates | — |
| Shift, mask, sign extension, VOI, then MONOCHROME1 inversion (`WindowLUT.build`, `PaletteDisplayLUT.make`) | PS3.5 8.1.1; C.7.6.3.1.2 | match | — |
| Sample assembly: cell width, least-significant byte first | PS3.5 8.1.1, 8.2 | **FAIL:** Metal read a Bits Allocated 32 cell as its low 16 bits; **DEFR D67:** so does the CPU | ok (Metal declines); D67 deferred |
| Planar Configuration 0 / 1 in the colour kernel and the CPU loop | C.7.6.3.1.3 | match (5) | — |
| Metal ↔ CPU: no floating point in the compute kernels, one table builder per family, parameter blocks field for field, identical bounds tests | design pillar 1 (parity) | match (16) | — |
| Photometric routing: MONOCHROME1/2 → monochrome, PALETTE COLOR → palette (tables required), 3-sample non-YBR → colour, YBR → CPU; XYB reaches the colour kernel as RGB | C.7.6.3.1.2 | match (15) | — |
| YBR_FULL / YBR_PARTIAL_420: the DocBook forward matrices inverted, vs the CPU fallback's coefficients (±5e-4, the text prints 4 decimals); display desaturate weights = YBR_FULL Y row | C.7.6.3.1.2 | match (8) | — |
| Palette index clamping, 0 = 65,536 entries, entry scaling | C.7.6.3.1.5, C.7.6.3.1.6 | match (3) | — |
| The eight Well-Known Color Palettes, 256 RGB entries each (Spring, Summer, Fall, Winter expanded from their segmented data) | PS3.6 Annex B; PS3.3 C.7.9.2 | match (8 / 8, 2,048 entries) | — |
| Rotation before horizontal flip in both display transforms | C.10.6 | match (2) | — |
| ICC Profile applied to colour output | C.11.15.1.1 | **PEND P-ICC:** both backends tag output Device RGB | — |
| Citations exist and name the right clause | PS3.3/3.5/3.6 2026a | match | — |

Tests at the start (HEAD `c6560fa`): DICOMRenderKitTests 92 XCTest cases, 14 skipped
(benchmarks), 0 failures (as recorded by the DICOMPrintKit pass on the same bundle). After this
pass: 96 XCTest cases, the same 14 skipped, 0 failures (`RenderStandardConformanceTests`, 4 new).

---

## Progress log

| Date | Item | What was compared | What changed | Tests |
|---|---|---|---|---|
| 2026-09-30 | Baseline | All 10 Swift files and the shader read in full and bucketed; the DICOMCore/DICOMKit sources they render through read (`WindowSettings`, `WindowLUT`, `ColorSampleLUT`, `PaletteColorLUT`, `PixelDataDescriptor`, `PixelData`, `DICOMWellKnownPalettes`, `PixelDataRenderer`, `DICOMImageExporter.determineWindowSettings`). PS3.3, 3.4, 3.5, 3.6, 3.14 2026a fetched into the session scratchpad (subtitles checked, not committed). `Scripts/diff_renderkit.py` written (reuses `diff_web` section helpers and `diff_kit` citation/photometric checks): 17 checks, 1 failing, 2 pending, 3 deferred | Script only (`a1c3721`) | — |
| 2026-09-30 | Pixel Cell width | PS3.5 8.1.1 ("The size of the Pixel Cell shall be specified by Bits Allocated"), 8.2 | `MetalFrameRenderer` declines samples wider than two bytes (the kernels assemble one or two and the tables have 256 / 65,536 entries); such frames fall back to the CPU. The CPU half is D67 | `RenderStandardConformanceTests.testMetalDeclinesPixelCellsWiderThanTwoBytes` (`85c5a80`) |
| 2026-09-30 | Standard pins | C.11.2.1.2.1 worked example (c = 0, w = 100), C.7.6.3.1.2 MONOCHROME1, C.7.6.3.1.3 Enumerated Value 1 | None needed: both backends already match; now pinned against the text rather than only against each other | 3 tests, both backends (`85c5a80`) |
| 2026-09-30 | Window units | C.11.2.1.2.1 ("after any Modality LUT or Rescale Slope and Intercept … have been applied") | `FrameRenderRequest.window` documented as stored-value units, with the slope-1 limit of the conversion (D65, P-PIPELINE) | — (`a1ae35d`) |
| 2026-09-30 | Findings in other modules | C.11.2.1.2.1, C.11.2.1.3.1/.2, PS3.5 8.1.1 | D63 (DICOMCore `WindowLUT` quantisation), D64 (DICOMCore width clamp), D65 (DICOMKit/DICOMStudio stored-unit window), D66 (DICOMKit auto window), D67 (DICOMKit/DICOMCore 32-bit cells) opened | — |
| 2026-09-30 | Markers, close | `check_nema_markers.py`: 10 / 10; `diff_renderkit.py`: 11 ok, 0 failing, 2 pending, 4 deferred | CHANGELOG `[Unreleased]`; DICOMCore status table | Full `swift test` exit 0: XCTest 5,022 (44 skipped, 0 failures), Swift Testing 9,005 |

---

## Priority action list

| # | What | Standard | Impact | Status |
|---|---|---|---|---|
| P1 | Metal rendered a Bits Allocated 32 Pixel Cell from its low two bytes (65,541 shown as 5) | PS3.5 8.1.1 | Medium for 32-bit monochrome (e.g. RT Dose): a wrong picture, not a missing one. The CPU does the same (D67), so today the picture is still wrong until D67 is fixed | ✅ Metal half |
| P-PIPELINE | The request carries only a window in stored-value units: no Modality LUT, no VOI LUT Sequence, no Presentation LUT | C.11.2.1.2.1 (VOI after the Modality LUT), C.11.1, C.11.2.1.1, C.11.6.1.2 | Medium: any rescale slope other than 1 (PET, NM, some CR/MR) shifts the LINEAR ramp by up to a few grey levels; a negative slope renders inverted; a Modality or VOI LUT Sequence cannot be shown at all (callers fall back to the pixel-range window) | ⏳ Owner decision |
| P-ICC | Colour output is tagged Device RGB; the file's ICC Profile is not applied | C.11.15.1.1 (the profile maps "device-dependent color stored pixel values into PCS-Values"); C.11.15.1.2 (SRGB, ADOBERGB, ROMMRGB, DISPLAYP3) | Low–Medium: sRGB images look right on an sRGB display; Display-P3, Adobe RGB and ROMM RGB images (and any scanner profile, e.g. WSI) show with the wrong gamut | ⏳ Owner decision |

### P-PIPELINE — recommendation

Add three defaulted inputs to `FrameRenderRequest`, reusing DICOMKit's existing
presentation-state types (`LUTTransformation.swift`):

```swift
public let modalityLUT: ModalityLUT?        // .rescale(slope:intercept:type:) or .lut(LUTData); nil = identity
public let voiLUT: VOILUT?                  // .window(...) in modality units, or .lut(LUTData); overrides `window`
public let presentationLUT: PresentationLUT? // .identity / .inverse / .lut; nil = MONOCHROME1 → INVERSE, else IDENTITY
```

When `modalityLUT` or `voiLUT` is given, one raw-sample → byte table is built through the
standard chain — shift/mask/sign (PS3.5 8.1.1) → Modality LUT (C.11.1) → VOI (C.11.2) →
Presentation LUT (C.11.6; MONOCHROME1 as INVERSE per C.7.6.3.1.2) — still 256 or 65,536 entries,
so neither kernel changes and the GPU stays byte-identical to the CPU. Without them the request
behaves exactly as today. The builder goes in DICOMRenderKit (it depends on DICOMKit); the CPU
path needs one additive `PixelDataRenderer` entry point that renders a monochrome frame through a
given grey table. DICOMKit's exporter and DICOMStudio then pass the file's rescale and the window
in modality units instead of converting it, which closes D65. Nothing is removed or renamed.

### P-ICC — recommendation

Add `iccProfile: Data? = nil` to `FrameRenderRequest`. Colour `CGImage`s (both backends) are then
created in `CGColorSpace(iccData:)` — Core Graphics does the conversion; a profile that does not
parse falls back to Device RGB as today. For the GPU display path, `MetalImageView` gains an
optional colour space that it sets on the view's layer, so the same profile reaches the screen.
Monochrome output is unchanged. Additive only; lower priority than P-PIPELINE.

### Decisions taken without asking (all within "fix behaviour that contradicts the standard")

- The Metal fix declines rather than widens: supporting 32-bit cells needs wider tables or a
  different kernel, and the CPU must be fixed first anyway (D67); declining keeps the GPU from
  shadowing that fix. No API change.
- The truncation to a byte (D63) and the width clamp (D64) are in DICOMCore and are shared with
  export, print and the SIMD path; they are recorded, not changed, because changing them moves
  pinned bytes in other modules' parity tests.
- The reader's pseudo-colour ramp over colour frames uses Rec. 709 luma (ITU-R BT.709), and the
  viewer inversion, zoom, pan, crop mask and filtering are display choices with no DICOM
  attribute; they are documented as such and not scored.

### Explicitly out of scope — do not chase

- Backend selection, buffer pooling, zero-copy wrapping and the `MTKView` plumbing (C1).
- Performance thresholds and benchmarks.
- Bits Allocated 1 frames: `PixelData.frameData(at:)` returns `nil` for bit-packed data, so both
  backends render nothing (fail closed, not a wrong picture). Supporting them is DICOMKit work.

---

## Deferred findings

No rows for this module were open from earlier reports.

New findings for other modules:

| ID | Module | Where | Problem | Standard | Severity | Status |
|---|---|---|---|---|---|---|
| D63 | DICOMCore (and DICOMKit `SIMDImageProcessor`) | [WindowLUT.swift:134](Sources/DICOMCore/WindowLUT.swift#L134) `UInt8(max(0, min(255, normalized * 255.0)))`; the SIMD path copies it | Truncating a floating-point result makes the standard's identity window lossy: with c = 128, w = 256, 32 of 256 8-bit values display one level low (1 → 0, 5 → 4, …); 1 / 4,096 at 12 bits, 32 / 65,536 at 16. The exact value is an integer; floating-point error puts it just below | PS3.3 C.11.2.1.2.1 ("a floating point calculation without integer truncation is assumed … as long as the result is the same"; c = 2^(n−1), w = 2^n "represents a mathematical identity") | Low (one grey level) | ⏳ Open. Suggested: floor the value with a relative tolerance (e.g. `(y * 255).nextUp` or `+ 1e-9` before the floor) so the byte is the floor of the exact value; moves pinned bytes in `WindowLUTParityTests`, `ExportWindowParityTests`, print golden hashes |
| D64 | DICOMCore | [WindowSettings.swift:43](Sources/DICOMCore/WindowSettings.swift#L43) `self.width = max(1.0, width)` | Every width is clamped to ≥ 1; SIGMOID and LINEAR_EXACT only require w > 0, so a width of 0.25 (float-valued or PET data, or any window in modality units once P-PIPELINE lands) is applied as 1 | PS3.3 C.11.2.1.2.1 (LINEAR: w ≥ 1); C.11.2.1.3.1, C.11.2.1.3.2 (w > 0) | Low–Medium | ⏳ Open. Suggested: clamp to ≥ 1 for LINEAR only; > 0 (e.g. `Double.leastNonzeroMagnitude`) for the others |
| D65 | DICOMKit, DICOMStudio | [DICOMImageExporter.swift:259](Sources/DICOMKit/ImageExport/DICOMImageExporter.swift#L259) `toStored`; DICOMStudio `ImageViewerViewModel.swift` ~L1390, ~L1432 and `ImageViewerViewModel+PresentationStates.swift` ~L1060 (same conversion) | The window is converted to stored units as `(c − b)/m`, `w/|m|` and applied to stored values. For LINEAR the −0.5 and w − 1 terms do not scale, so the result equals the standard only for slope 1 (slope 2 / 0.5: 4–124 of 4,000 values differ); for a negative slope the ramp runs the wrong way (3,999 of 4,000 differ — the image is inverted) | PS3.3 C.11.2.1.2.1 (window over the output of the Modality LUT / rescale) | Medium (High for negative slopes, which are rare) | ⏳ Open; the fix is P-PIPELINE (pass the rescale, keep the window in modality units). DICOMStudio half stays open until that module is audited |
| D66 | DICOMKit | [PixelDataRenderer.swift:58](Sources/DICOMKit/PixelDataRenderer.swift#L58), [DICOMImageExporter.swift:276](Sources/DICOMKit/ImageExport/DICOMImageExporter.swift#L276) | The pixel-range auto window is c = (min+max)/2, w = max − min; the standard's full-range window is c = (x1+x2+1)/2, w = x2 − x1 + 1. With the code's values `max − 1` already maps to white and the ramp is one step short (127 of 4,001 values of a −1000…3000 frame differ) | PS3.3 C.11.2.1.2.1 | Low | ⏳ Open |
| D67 | DICOMKit, DICOMCore | [PixelDataRenderer.swift](Sources/DICOMKit/PixelDataRenderer.swift) `renderMonochromeFrame`, `renderColorFrame`, `renderPaletteColorFrame`; `WindowLUT`, `ColorSampleLUT`, `PaletteDisplayLUT` (tables sized for 1 or 2 bytes) | A Bits Allocated 32 cell is assembled from its first two bytes, so 65,541 renders as 5 (e.g. 32-bit RT Dose) | PS3.5 8.1.1 ("The size of the Pixel Cell shall be specified by Bits Allocated") | Medium | ⏳ Open (the Metal half is fixed here, `85c5a80`). Suggested: render 32-bit cells through a direct per-pixel window (no 2^32 table), or decline until then |

---

## Bucket B2 — No citation, behaviour differed from 2026a (2 files)

| File | Before | After |
|---|---|---|
| [Metal/MetalFrameRenderer.swift](Sources/DICOMRenderKit/Metal/MetalFrameRenderer.swift) | Bits Allocated 32 cells read as their low 16 bits | ✅ Declined to the CPU (PS3.5 8.1.1); tables are the CPU's own DICOMCore builders; planar offsets per C.7.6.3.1.3; YBR on the CPU; parameter blocks match the kernels (all by script). Marked. |
| [FrameRenderBackend.swift](Sources/DICOMRenderKit/FrameRenderBackend.swift) | The request cannot carry a Modality LUT, VOI LUT Sequence, Presentation LUT or ICC Profile; `window` units undocumented | ✅ Routing by photometric matches C.7.6.3.1.2; `window` documented as stored-value units with the slope-1 limit; ⏳ P-PIPELINE, P-ICC. Marked. |

## Bucket C1 — Plumbing (6 files)

| File | Confirmed | Result |
|---|---|---|
| [RenderBackend.swift](Sources/DICOMRenderKit/RenderBackend.swift) | carries no DICOM-standard data (backend selection, `DICOMKIT_RENDER_BACKEND`) | ✅ Marked |
| [FrameRenderService.swift](Sources/DICOMRenderKit/FrameRenderService.swift) | carries no DICOM-standard data (backend choice, CPU fallback) | ✅ Marked |
| [Metal/AnnotationOverlayTexture.swift](Sources/DICOMRenderKit/Metal/AnnotationOverlayTexture.swift) | carries no DICOM-standard data | ✅ Marked |
| [Metal/MetalRenderDevice.swift](Sources/DICOMRenderKit/Metal/MetalRenderDevice.swift) | carries no DICOM-standard data (device, library, pipeline cache, kernel names) | ✅ Marked |
| [Metal/UnifiedMemoryPool.swift](Sources/DICOMRenderKit/Metal/UnifiedMemoryPool.swift) | carries no DICOM-standard data (buffers) | ✅ Marked |
| [Metal/MetalImageView.swift](Sources/DICOMRenderKit/Metal/MetalImageView.swift) | carries no DICOM-standard data (drawing, SwiftUI wrapper) | ✅ Marked |

## Bucket C2 — Standard-derived, edition-stable (2 files and the shader)

| File | Compared | Result |
|---|---|---|
| [CPUFrameRenderer.swift](Sources/DICOMRenderKit/CPUFrameRenderer.swift) | Its routing and the chain it delegates to: `WindowSettings.apply` evaluated against C.11.2.1.2.1 / C.11.2.1.3.1 / C.11.2.1.3.2, MONOCHROME1 after the VOI (C.7.6.3.1.2), palette lookup (C.7.6.3.1.5/.6), the eight PS3.6 Annex B palettes, the YBR inverses (C.7.6.3.1.2) | ✅ match; the no-window rung inherits D66, 32-bit cells D67. Marked. |
| [Metal/DisplayFrameTexture.swift](Sources/DICOMRenderKit/Metal/DisplayFrameTexture.swift) | Rotation before horizontal flip in both transforms (C.10.6); desaturate weights = YBR_FULL Y row (C.7.6.3.1.2) | ✅ match. Marked. |
| [Metal/FrameRender.metal.txt](Sources/DICOMRenderKit/Metal/FrameRender.metal.txt) (not Swift) | No floating point in the compute kernels; sample assembly (PS3.5 8.1.1, 8.2); planar configuration (C.7.6.3.1.3); parameter structs; desaturate weights | ✅ match. Marker added (the checker scans Swift only). |

---

## Verification notes

- **Scripted checks** ([Scripts/diff_renderkit.py](Scripts/diff_renderkit.py), 17 checks). The
  VOI functions are compared as functions: the pseudo-code of C.11.2.1.2.1 and C.11.2.1.3.2 is
  read from the DocBook text and Equation C.11-1 from its MathML (the script refuses to run if
  either changes shape), each is evaluated in Python, and so is the Swift of
  `WindowSettings.applyLinear/applyLinearExact/applySigmoid` after a mechanical rename of its
  variables; the identity check uses exact rational arithmetic (`fractions.Fraction`). The YBR
  matrices are inverted in the script. Palettes with segmented data are expanded per C.7.9.2
  (opcodes 0 and 1; half-to-even rounding, as the DICOMCore tables state). Structural checks
  (routing, parity, planar offsets, order of steps) match the Swift and Metal source by regex and
  stop with a message if a pattern is no longer found.
- **Not scored, by design:** Rec. 709 luma for the reader's ramp over colour frames (ITU-R
  BT.709, a display choice); zoom, pan, filtering, the film crop mask and the viewer's `invert`
  (display geometry, no DICOM attribute). The viewer's inversion applies after MONOCHROME1 and
  is a reader's choice, like a Presentation LUT INVERSE chosen at the workstation.
- **The shader is not a Swift file.** `check_nema_markers.py` only scans `.swift`; the marker in
  `FrameRender.metal.txt` is there for readers and is checked by `diff_renderkit.py`'s citation
  check.
- **Tests at the end** (2026-09-30, full `swift test`, exit 0): XCTest 5,022 cases, 44 skipped,
  0 failures (DICOMRenderKitTests 96 with 14 skipped — +4, `RenderStandardConformanceTests`;
  DICOMKitTests 1,992 / 11 skipped; DICOMNetworkTests 1,403; DICOMRoundTripTests 542 / 18
  skipped; DICOMWebTests 447; DICOMPrintKitTests 366 / 1 skipped; DICOMCoreTests 85;
  DICOMViewerTests 51; DICOMStudioTests 40); Swift Testing 9,005, all passing. The previous full
  run was XCTest 5,018 / 44 skipped and Swift Testing 9,005.
- **Commits** (local, `feature/dicom-tag-modality-audit`): `a1c3721` diff script, `85c5a80`
  Metal Pixel Cell width and the standard pins, `a1ae35d` markers and the window-units note, then
  this report, CHANGELOG and the status table.
