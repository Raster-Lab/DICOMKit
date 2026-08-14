# Print gap closure — FR-003, FR-004, FR-006

> **Status (2026-08-13, verified against code — see
> `PRINT_SRS_CONFORMANCE_REPORT.md` §4 for file:line evidence):**
>
> - **FR-003 — ✅ complete.** All four scaling modes, nine alignments, true-size
>   from all three spacing tags, Requested Image Size (2020,0030) on the wire,
>   audible fallback on missing spacing, byte-for-byte default regression gate.
>   Two accepted deviations from this plan: no `clipWhenOversize` knob (the crop
>   branch always clips — never silently shrinks), and no separate `.trueSize`
>   fitter branch (expressed via requested-size + CROP instead).
> - **FR-004 — ✅ complete (2026-08-14).** Table LUTs were already done (both
>   sequences, correct precedence ladder, Modality-suppresses-rescale,
>   signedness from Modality LUT output). The three former gaps closed
>   2026-08-14: VOI LUT Function (0028,1056) is inherited by viewer-mark
>   windows so SIGMOID prints sigmoid (`PrintImagePreparer.resolvedFunction`);
>   a custom Presentation LUT travels as the LUT Sequence
>   (`PresentationLUTTable`); LIN OD is a real 10^(−OD) density curve
>   (`FilmComposer.linODTransfer`), same orientation as before.
> - **FR-006 — ⚠️ bands complete (2026-08-14), small items open.**
>   Header/side/overlay bands landed as `FilmAnnotationEdge` — the band carves
>   off any edge, side text runs spine-wise, overlay reserves nothing; chosen
>   in the emulator settings. Fields and style were already complete. **Still
>   open:** custom free-text and Study Time fields, background config, and the
>   burned per-image caption floor (9 px, not DPI-aware).

Implementation plan for the three partially-complete functional requirements from
`DICOM_Film_Printing_SRS_TDD.md`. Each section states what already works, what is
missing, and the concrete edits that close the gap.

**Scope:** scaling/positioning, LUT handling, and annotation fields. Queue,
presets, audit and user management are *not* covered here — they are separate,
larger gaps.

**Ordering note.** FR-004's LUT-sequence work is the only item that changes
diagnostic pixel values, so it carries the most clinical risk and the most test
weight. FR-003's true-size work is the one users are most likely to ask for by
name. FR-006 is the cheapest. Suggested order: FR-003 → FR-006 → FR-004, so the
riskiest change lands with the other two already stable.

---

## FR-003 — Scaling & Positioning

### Status

| Capability | State | Where |
|---|---|---|
| Fit-to-film (aspect fit, letterboxed) | ✅ Done | `FilmGeometry.swift:261-278` (`.decimate`) |
| Fill-to-film (aspect fill + crop) | ✅ Done | `FilmGeometry.swift:280-289` (`.crop`) |
| **True Size (1:1 physical)** | ❌ Absent | no code reads PixelSpacing on the print path |
| **Stretch (non-uniform)** | ❌ Absent | both branches use a single scalar `scale` |
| **9-way positioning** | ❌ Absent | placement hard-coded centred, `FilmGeometry.swift:274-276` |

The fitter is keyed off the DICOM wire attribute *Requested Decimate/Crop
Behavior* (2020,0040), not off a user-facing scaling mode. `requestedSizeMillimeters`
already exists as a parameter but is only ever populated from a value **received**
on the wire (`FilmComposer.swift:296-297`) — the SCU never sends one, because
`PrintJobRequest` has no field for it.

### Design

Keep the wire behaviour as the fitter's contract and add an orthogonal
presentation intent on top. Do **not** overload `DecimateCropBehavior` — it is a
DICOM attribute with defined semantics and the SCP must keep honouring it as
received.

**1. New type — `PrintScalingMode`** (new file, `Sources/DICOMPrintKit/PrintScalingMode.swift`)

```swift
public enum PrintScalingMode: String, Sendable, CaseIterable {
    case fitToFilm      // aspect fit, letterbox      (current default)
    case fillToFilm     // aspect fill, crop overflow
    case trueSize       // 1:1 physical via PixelSpacing
    case stretch        // independent x/y scale, ignores aspect
}
```

`stretch` must be labelled in the UI as not for diagnostic use, per the spec's own
warning (SRS §4.3).

**2. New type — `PrintCellAlignment`** (same file)

```swift
public enum PrintCellAlignment: String, Sendable, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight
}
```

Give it a single geometry helper so no call site does the arithmetic itself:

```swift
func origin(forContent size: CGSize, in cell: FilmCell) -> (x: Double, y: Double)
```

**3. Extend `FilmImageFitter.fit`** — `Sources/DICOMPrintKit/Printing/FilmGeometry.swift:245`

Add two parameters with defaults, so every existing call site compiles unchanged:

```swift
mode: PrintScalingMode = .fitToFilm,
alignment: PrintCellAlignment = .center,
```

- Replace the three hard-coded centring expressions (`:274-276`, `:287-288`,
  `:304-306`) with `alignment.origin(forContent:in:)`.
- Add a `.stretch` path: `scaleX = cell.width / imageWidth`, `scaleY = cell.height / imageHeight`,
  applied independently. `FilmFitResult.placed` already carries a full destination
  rect, so no result-type change is needed.
- Add a `.trueSize` path — see below.

**4. True Size — the substantive piece**

Physical width in mm = `imageWidth × columnSpacing`, where spacing comes from the
first available of:

| Tag | Name | Note |
|---|---|---|
| (0028,0030) | Pixel Spacing | preferred; row\\column, **row first** |
| (0018,1164) | Imager Pixel Spacing | projection radiography (CR/DX/MG) — detector plane, *not* patient plane |
| (0018,2010) | Nominal Scanned Pixel Spacing | fallback |

Add to `Sources/DICOMPrintKit/PrintImagePreparer.swift`:

```swift
/// Physical size of one pixel in mm, (row, column), when the file records it.
static func pixelSpacing(from dataSet: DataSet) -> (row: Double, column: Double)?
```

Then add `requestedImageSizeMillimeters: Double?` to `PrintJobRequest`
(`Sources/DICOMPrintKit/PrintJobRequest.swift:124-261`) and populate the DICOM
*Requested Image Size* (2020,0030) from it in the SCU N-SET
(`Sources/DICOMNetwork/PrintService.swift:2888-2895` — the write already exists
and is currently always skipped because the value is always `nil`).

**Correctness requirements — these are the ones that will bite:**

- **Non-square pixels.** Row and column spacing can differ (common in US, some MR).
  True size must scale x and y independently by their own spacing, or anatomy is
  distorted. This means true-size is *not* simply "fit with a pinned scale".
- **Anisotropy vs. stretch.** `.trueSize` may produce a non-uniform scale for the
  legitimate reason above; `.stretch` does so to fill the cell. Keep them distinct
  in code even though both end up with `scaleX != scaleY`.
- **Magnification.** DICOM *Requested Image Size* is the printed **width**. The
  printer may itself scale. This plan pins geometry SCU-side; document that true
  size is only guaranteed when the printer honours 2020,0030.
- **Overflow.** An image whose true size exceeds the cell must not silently shrink
  — that would be a *false* 1:1. Either clip (and say so), or fail. Recommend:
  report via a new `FilmFitResult.failed(reason:)` case that already exists,
  gated by a `clipWhenOversize: Bool` so the caller chooses.
- **Missing spacing.** Absent all three tags, true size is undefined. Fall back to
  fit-to-film **and surface a warning** — never silently print a wrong-scale film
  that a clinician might measure against.
- **Imager vs. patient spacing.** (0018,1164) is at the detector, so for
  projection images true size is detector-plane size, not anatomical size
  (geometric magnification is real). Note this in the UI copy; do not claim
  anatomical accuracy the data cannot support.

**5. Wire through**

- `PrintJobRequest`: add `scalingMode`, `alignment`, `requestedImageSizeMillimeters`.
- `PrintPlan` / `FilmComposer.swift:296` — pass the mode and alignment into `fit`.
- UI: pickers in `Sources/DICOMStudio/Views/Print/PrintSettingsView.swift`,
  near the existing film-size/layout controls (`:521-547`). A 3×3 alignment grid
  reads better than a 9-item dropdown.
- Preview must use the identical path — `FilmPreviewView` already calls the same
  `FilmCellLayout`/fitter code, so this comes free if the parameters are threaded
  rather than duplicated.

### Tests — `Tests/DICOMPrintKitTests/FilmGeometryTests.swift`

- Each of the 9 alignments places content at the expected origin, in a cell that is
  both wider and taller than the content.
- Alignment is a no-op when content exactly fills the cell.
- Stretch fills the cell exactly and, for a non-matching aspect, `scaleX != scaleY`.
- True size: 512 px at 0.5 mm spacing → 256 mm printed width, at a known DPI.
- True size with anisotropic spacing (0.5 × 1.0) produces a 2:1 destination aspect.
- True size falls back to fit **and reports a warning** when no spacing tag exists.
- Oversize true-size image fails (or clips) per `clipWhenOversize`, and never
  silently rescales.
- Regression: default arguments reproduce today's centred fit byte-for-byte.

### Effort

Medium. ~2–3 days. The geometry is easy; the pixel-spacing semantics and the
oversize/missing-data policy are where the care goes.

---

## FR-004 — Window/Level & LUT

### Status

| Capability | State | Where |
|---|---|---|
| Manual W/L (job-wide + per-cell) | ✅ Done | `PrintSettingsView.swift:1406`, `:1078-1089` |
| DICOM-default W/L (header VOI) | ✅ Done | `PrintImagePreparer.swift:249` |
| Auto W/L | ✅ Done (naive) | `ImagePreprocessor.swift:232-238` — full min/max stretch |
| Modality LUT — linear rescale | ✅ Done | `ImagePreprocessor.swift:223-226` |
| Presentation LUT — shapes | ✅ Done | IDENTITY / INVERSE / LIN OD |
| **Modality LUT Sequence (0028,3000)** | ❌ Absent | tag defined `Tag+PixelData.swift:118`, never read |
| **VOI LUT Sequence (0028,3010)** | ❌ Absent | tag defined `Tag+PixelData.swift:136`, never read |
| **Custom Presentation LUT data** | ❌ Absent | acknowledged, `PrintService.swift:672-674` |
| **W/L presets beyond CT+MR** | ❌ Absent | `WindowLevelPresets.swift:71-79` returns `[]` |

**This is the highest-risk item in the plan.** An image whose correct presentation
requires a table LUT currently prints with wrong contrast, *silently*. There is no
warning and no visual cue.

### Design

**1. LUT decoding — `Sources/DICOMKit/LUTTable.swift` (new)**

One shared representation for both Modality and VOI LUTs, since both use the same
LUT Descriptor / LUT Data structure:

```swift
public struct LUTTable: Sendable {
    public let firstMapped: Int    // descriptor[1], may be signed
    public let bitsPerEntry: Int   // descriptor[2]
    public let entries: [UInt16]   // descriptor[0] == 0 means 65536
    public func apply(to value: Double) -> Double
}
```

Decoding rules that must be handled — these are the classic failure points:

- **Descriptor[0] == 0 means 65536 entries**, not zero. Getting this wrong reads
  an empty table.
- **Descriptor[1] is signed** when Pixel Representation is 1.
- Values below `firstMapped` clamp to `entries.first`; at or above
  `firstMapped + count` clamp to `entries.last`.
- LUT Data may be **OW or US**; both must decode. 8-bit-in-16 data occurs.
- `bitsPerEntry` of 8 vs 16 changes the output normalisation.

**2. Modality LUT Sequence** — `ImagePreprocessor.swift:223-226`

Per PS3.3 C.11.1: Modality LUT Sequence and Rescale Slope/Intercept are
**mutually exclusive**. If the sequence is present, it *replaces* the linear
rescale — applying both is a real bug.

```
if let lut = ModalityLUT.sequence(in: dataSet) { pixelValues = lut.apply(...) }
else { pixelValues = applyRescale(to: pixelValues, dataSet: dataSet) }
```

Note the output of a Modality LUT Sequence is in *manufacturer-defined* units
(often not Hounsfield), so `rescaleType`/`lutExplanation` should be carried
forward for display.

**3. VOI LUT Sequence** — `ImagePreprocessor.swift:241`

Precedence per PS3.3 C.11.2, highest first:

1. User-specified window (explicit request) — always wins
2. VOI LUT Sequence (0028,3010), if present
3. Window Center/Width (0028,1050/1051)
4. Auto min/max stretch

Extend the existing ladder in `PrintImagePreparer.swift:240-250` to insert VOI LUT
Sequence at rung 2. Also honour **VOI LUT Function (0028,1056)** — `SIGMOID` vs
the default `LINEAR` — since it is already a defined tag (`Tag+PixelData.swift:152`)
and is currently ignored. `LINEAR_EXACT` is a third value worth handling.

**4. Custom Presentation LUT data**

Extend `PresentationLUTShape` (`PrintService.swift:675-682`) to a two-case model:

```swift
public enum PresentationLUT: Sendable {
    case shape(PresentationLUTShape)   // IDENTITY / INVERSE / LIN OD
    case table(LUTTable)               // custom LUT data
}
```

The SCU already N-CREATEs a Presentation LUT SOP instance
(`PrintService.swift:2765-2807`) writing only (2050,0020) Presentation LUT Shape.
For the table case, write (3006,0010)-style LUT Descriptor / LUT Data into the
Presentation LUT sequence instead. The SCP composer
(`FilmComposer.swift:530-533`) must apply the table when present.

**Also worth fixing while here:** `.linearOpticalDensity` is currently treated as
a plain inversion, identical to `.inverse` (`FilmComposer.swift:531`). LIN OD is
a density curve, not a negation. Either implement the curve or rename the case and
document the approximation — the present state quietly misrepresents it.

**5. Presets beyond CT+MR** — `Sources/DICOMStudio/Components/WindowLevelPresets.swift:43-79`

Add entries for CR/DX (chest, bone, soft tissue), MG, PT (SUV-oriented), NM, US,
XA. Keep the existing `presets(for:)` shape; only the table grows. Where a
modality has no meaningful fixed window (US is usually already 8-bit display-ready),
return empty rather than inventing values.

### Tests

`Tests/DICOMKitTests/LUTTableTests.swift`:
- Descriptor[0] == 0 decodes as 65536 entries.
- Signed `firstMapped` when PixelRepresentation == 1.
- Clamping below/above the mapped range.
- OW and US encodings both decode identically.
- 8-bit and 16-bit `bitsPerEntry`.

`Tests/DICOMPrintKitTests/`:
- Modality LUT Sequence **suppresses** rescale slope/intercept (assert the linear
  path did not also run).
- VOI LUT Sequence beats Window Center/Width; explicit user window beats both.
- SIGMOID VOI function differs measurably from LINEAR at the same centre/width.
- Custom Presentation LUT table round-trips SCU → SCP → composed film.
- Regression: files with no LUT sequences produce byte-identical output to today.

### Effort

Large. ~4–6 days. The LUT decoder itself is a day; correct *precedence* across
Modality/VOI/Presentation and not regressing existing images is the rest.

---

## FR-006 — Annotations

### Status

| Capability | State | Where |
|---|---|---|
| Burn-in engine (halo text, grayscale + RGB) | ✅ Done, strong | `ImageAnnotationBurner.swift:214-289` |
| Corner placement (4 corners) | ✅ Done | `PrintCornerAnnotation.swift:24-27` |
| Film-wide footer band | ✅ Done | `FilmIdentification.swift:26-63`, `FilmComposer.swift:615-654` |
| Patient name, ID, modality, study date/desc, instance no., technique | ✅ Done | `PatientOverlayText.swift:141-154` |
| **Patient DOB (0010,0030)** | ❌ Absent | never read |
| **Accession Number (0008,0050)** | ❌ Absent | never read |
| **Institution Name (0008,0080)** | ❌ Absent | never read |
| **Series Description (0008,103E)** | ❌ Absent | deliberately declined, `:178-182` |
| **Header / side positions** | ❌ Absent | footer-only, `FilmComposer.swift:604-614` |
| **Configurable font / colour / size for ID text** | ❌ Absent | hard-coded Helvetica, auto-size, forced contrast |

### A note on existing design intent

The current corner layout is **deliberate**, and the reasoning is documented at
length in `PrintCornerAnnotation.swift:1-18` and `PatientOverlayText.swift:120-129`:
top-left is left clear for the printer's own label; fields are unlabelled where
self-evident; series description is omitted because a film cell is one image and
the sheet already carries the study description.

This plan therefore **adds the missing fields as opt-in**, rather than changing
the default layout. Anyone implementing this should read those comments first —
the omissions are decisions, not oversights, and the spec's field list is a menu
rather than a mandate.

### Design

**1. Add the four missing fields** — `Sources/DICOMStudio/Models/PatientOverlayText.swift`

Extend `make(from:)` to read:

| Field | Tag | Formatting |
|---|---|---|
| Patient birth date | (0010,0030) | `DICOMValueParser.formatDate`; consider printing age instead |
| Accession number | (0008,0050) | verbatim |
| Institution name | (0008,0080) | verbatim, likely truncated |
| Series description | (0008,103E) | verbatim |

**Privacy note.** DOB is a direct identifier. Burning it into pixels makes it
survive de-identification of the header — that is precisely the point on a
clinical film, and precisely the hazard on anything shared. Default DOB to **off**,
and keep it off in any anonymised/export path.

**2. Make the corner mapping configurable**

The blocker is that `corners` (`PatientOverlayText.swift:130-135`) is a hard-coded
computed property. Introduce a layout descriptor:

```swift
public struct PrintAnnotationLayout: Sendable, Codable {
    public enum Field: String, Codable, CaseIterable {
        case patientName, patientID, patientBirthDate
        case studyDate, studyTime, studyDescription, accessionNumber
        case institutionName, modality, seriesDescription
        case instanceNumber, technique
        case customText(String)   // requires manual Codable
    }
    public enum Slot: String, Codable, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case header, footer, leftMargin, rightMargin
    }
    public var assignments: [Slot: [Field]]
    public static let clinicalDefault: PrintAnnotationLayout  // == today's behaviour
}
```

`corners` then becomes a projection of this layout onto the four corner slots, with
`clinicalDefault` reproducing the current output exactly.

**3. Header and side positions** — `FilmComposer.swift:604-654`

`drawAnnotations` currently reserves and draws a bottom band only. Generalise to
reserve up to four margin bands (top/bottom/left/right), each sized from the text
it holds, and shrink the image area accordingly. **The cell layout must be computed
after the bands are reserved**, or annotations will overlap the outer row/column of
images — this is the main correctness risk in FR-006. Side bands need rotated text
(90° / 270°); `ImageAnnotationBurner` currently draws horizontally only, so it needs
a rotation parameter.

**4. Configurable typography**

Replace the hard-coded values with a struct threaded through the burner:

```swift
public struct PrintAnnotationStyle: Sendable, Codable {
    public var fontFamily: String        // default "Helvetica"
    public var sizeMode: SizeMode        // .automatic (current) or .fixedPoints(Double)
    public var colorMode: ColorMode      // .automatic (current contrast rule) or .explicit
    public var backgroundOpaque: Bool    // solid box behind text vs. current halo
}
```

Touch points: `ImageAnnotationBurner.swift:312` and `:378` (font family),
`:347-355` (`captionFontSize`), `:121-134` (colour), `FilmComposer.swift:627-628`
(footer font and colour), `FilmIdentification.swift:191-201` (footer sizing).

**Keep `.automatic` as the default.** The existing auto-size and
contrast-selection logic is genuinely good — it adapts to image size and flips
correctly for MONOCHROME1. Manual override should be available, not mandatory.

**5. Enforce the spec's legibility floor**

SRS §4.6 requires a minimum 8 pt at 300 DPI. The current floor is 9 px
(`ImageAnnotationBurner.swift:347-355`), which at 300 DPI is ~2.2 pt — well under.
Add a DPI-aware minimum and clamp `.fixedPoints` so a user cannot select an
illegible size.

**6. Safe zones**

SRS §4.6 also requires that annotations not obscure diagnostic regions. Corner
placement mostly achieves this for fitted images, but a **`.crop`/fill** image
covers the full cell, so corner text lands on anatomy. Add an opt-in inset that
shifts text into the letterbox margin when one exists, and warn when it does not.

**7. UI**

Extend `PrintSettingsView.swift:1164` (currently a single "Patient identification"
toggle) into a small editor: per-slot field assignment, a style section, and a live
preview. `FilmPreviewView.swift:1029-1039` already draws identification exactly
where it burns, so preview fidelity comes free.

### Tests

Extend `Tests/DICOMPrintKitTests/ImageAnnotationBurnerTests.swift` and
`Tests/DICOMStudioTests/PatientOverlayTextTests.swift`:

- Each new field is read and formatted; each is absent-safe (missing tag → no line,
  no stray separators — the existing `make(from:)` contract).
- `clinicalDefault` layout produces byte-identical output to today. **Regression
  gate for the whole FR.**
- Custom slot assignment moves a field to the requested corner.
- Header/side bands reserve space and the image area shrinks — assert no cell
  overlaps a band.
- Rotated side text stays within its band.
- Font/colour/size overrides take effect; `.automatic` matches current behaviour.
- The 8 pt @ 300 DPI floor is enforced, including against a too-small explicit size.
- MONOCHROME1 colour inversion still correct under explicit colour.
- DOB is off by default.

### Effort

Small–Medium for fields and typography (~2 days). Medium for header/side bands
(~2–3 days), because band reservation interacts with cell layout and needs rotated
text.

---

## Summary

| FR | Gap | Effort | Risk | Key hazard |
|---|---|---|---|---|
| FR-003 | True size, stretch, 9-way alignment | 2–3 d | Medium | Non-square pixels; silent wrong-scale on missing spacing |
| FR-004 | Modality/VOI LUT sequences, custom PLUT, presets | 4–6 d | **High** | LUT precedence; silently wrong contrast today |
| FR-006 | 4 fields, header/side slots, typography | 4–5 d | Low–Med | Band reservation vs. cell layout; DOB privacy |

**Total: roughly 10–14 working days.**

Two cross-cutting rules for all three:

1. **Every default must reproduce current output byte-for-byte.** Each FR has an
   explicit regression test for this. These paths produce diagnostic films.
2. **Never silently degrade.** Missing pixel spacing, an undecodable LUT, or an
   unfittable true-size image must surface a warning through the existing
   `PrintDiagnostic` console (`PrintViewModel.swift:838-845`) — not fall back
   quietly. A film that is silently wrong is worse than one that refuses to print.
