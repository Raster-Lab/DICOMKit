# J2K / HTJ2K / JXL — Per-UID Lossy & Lossless Encode Intent + Lossy Image Compression Attributes

**Status:** IMPLEMENTED (phases 1–4 + tests) — pending review
**Owner:** DICOMKit
**Created:** 2026-07-08
**Last updated:** 2026-07-08 (implemented; symmetric naming locked for all four families)
**Depends on:** the completed "J2K / HTJ2K Transfer Syntax Lossy-Lossless Split" work
(`SelectableEncoding`, `selectableEncodings`, `parseEncoding` already exist)

---

## 1. Goal

Per the DICOM standard, the **general** JPEG 2000 / HTJ2K / JPEG XL transfer-syntax UIDs are a
*single UID* that may carry **either** a lossless (reversible) **or** a lossy (irreversible)
codestream. Today DICOMKit can only ever encode the **lossy** form into those general UIDs, and it
never records the DICOM lossy-compression provenance attributes.

This plan makes each general codec family offer **three** selectable entries (four where a second
reversible-only UID exists), makes the encoder honour the chosen intent, and populates the correct
DICOM attributes.

Example — JPEG 2000 becomes three entries:

| Codec alias | UID | Encode intent | Lossy attrs written? |
|---|---|---|---|
| `jpeg2000-lossy` | `…4.91` | irreversible (lossy) | **yes** |
| `jpeg2000-lossless` | `…4.91` | reversible (lossless) | no |
| `jpeg2000-lossless-only` | `…4.90` | reversible (lossless-only UID) | no |

The **same symmetric pattern** applies to J2K Part 2, HTJ2K, and JPEG XL (see §4.1).

### Decisions locked with the reviewer

- **Symmetric naming for every family.** `<family>-lossy` and `<family>-lossless` **both** map to the
  **general** UID (intent decides the codestream); `<family>-lossless-only` maps to the
  **reversible-only** UID. Concretely:
  - JPEG 2000 — `jpeg2000-lossy`/`jpeg2000-lossless` → `.91`, `jpeg2000-lossless-only` → `.90`
  - JPEG 2000 Part 2 — `j2k-part2-lossy`/`j2k-part2-lossless` → `.93`, `j2k-part2-lossless-only` → `.92`
  - HTJ2K — `htj2k-lossy`/`htj2k-lossless` → `.203`, `htj2k-lossless-only` → `.201`,
    `htj2k-rpcl-lossless-only` → `.202`
  - JPEG XL — `jpeg-xl-lossy`/`jpeg-xl-lossless` → `.112`, `jpeg-xl-lossless-only` → `.110`,
    `jpeg-xl-recompression` → `.111`
- **"Lossless-only" is preserved as a named entry, not as the bare `-lossless` alias.** The
  reversible-only UIDs (`.90`/`.92`/`.201`/`.202`/`.110`) remain fully selectable under their explicit
  `…-lossless-only` names. This satisfies "keep the existing lossless as lossless-only."
- **Consequence — the bare `…-lossless` aliases are intentionally re-pointed to the general UID.**
  This is a documented, deliberate change (see §6 Migration), not additive. The produced pixels stay
  lossless/bit-exact; only the emitted UID differs (`.90`→`.91`, `.201`→`.203`, `.110`→`.112`, `.92`→`.93`).

---

## 2. DICOM reference basis

- **PS3.5 §A.4.4 — JPEG 2000 Image Compression.**
  - `1.2.840.10008.1.2.4.90` "JPEG 2000 Image Compression (Lossless Only)": the codestream **shall**
    use only reversible (5/3) wavelet + reversible component transform — lossless only.
  - `1.2.840.10008.1.2.4.91` "JPEG 2000 Image Compression": the codestream **may** be reversible
    **or** irreversible (9/7). When irreversible is used, the image is lossy and the Lossy Image
    Compression attributes apply. JPEG 2000 Part 2 (`.92` lossless-only / `.93` general) mirror this.
  - Defined Term for Lossy Image Compression Method (0028,2114): **`ISO_15444_1`**.
  - The **HTJ2K** High-Throughput syntaxes (`.201` lossless-only, `.202` RPCL lossless-only,
    `.203` general) are the ISO/IEC **15444-15** variants; lossy `.203` uses method **`ISO_15444_15`**.
- **PS3.5 §A.4.12 — JPEG XL Image Compression** (Supplement 232, DICOM 2024d; ISO/IEC 18181).
  - `1.2.840.10008.1.2.4.110` "JPEG XL Lossless" (lossless-only), `.111` "JPEG XL JPEG
    Recompression", `.112` "JPEG XL Image Compression" (general — may be lossy or lossless).
  - Defined Term for method (0028,2114): **`ISO_18181_1`**.
- **PS3.3 C.7.6.1.1.5 / PS3.5** — Lossy Image Compression provenance attributes:
  - **(0028,2110) Lossy Image Compression** — CS, VM 1. `"00"` = not lossy, `"01"` = lossy.
  - **(0028,2112) Lossy Image Compression Ratio** — DS, VM **1-n**.
  - **(0028,2114) Lossy Image Compression Method** — CS, VM **1-n**.
  - **"Once lossy, always lossy":** if an image has ever been lossily compressed, `(0028,2110)`
    stays `"01"` and each successive lossy step **appends** a ratio + method value (parallel arrays).

Method Defined Terms used by this plan:

| Family (transfer syntaxes) | (0028,2114) method |
|---|---|
| JPEG Baseline / Extended (`.50`/`.51`) | `ISO_10918_1` |
| JPEG-LS Near-Lossless (`.81`) | `ISO_14495_1` |
| JPEG 2000 / Part 2 (`.91`/`.93`) | `ISO_15444_1` |
| HTJ2K (`.203`) | `ISO_15444_15` |
| JPEG XL (`.112`) | `ISO_18181_1` |

---

## 3. Root cause in the current code

1. **Encoder discards intent.** `J2KSwiftCodec.makeEncodingConfiguration`
   (`Sources/DICOMCore/J2KSwiftCodec.swift:344`):
   ```swift
   let isLossless = targetSyntax?.isLossless ?? (configuration.preferLossless || configuration.quality.isLossless)
   ```
   For a `both`-capable UID, `targetSyntax.isLossless` is hardwired `false`, and the `??` means the
   caller's `preferLossless` is only consulted when the UID is *unknown*. So `.91`/`.93`/`.203`/`.112`
   can never be encoded lossless via the registry. Same pattern to fix in `HTJ2KCodec` and `JXLCodec`.
2. **No attribute writer.** Tags exist (`Sources/DICOMCore/Tag+ImageInformation.swift:92` —
   `lossyImageCompression` / `…Ratio` / `…Method`) but are only *read* (VideoParser). The compress
   path (`CompressionManager`) never sets them.
3. **Catalog is UID-keyed.** `CompressionManager.codecMap`
   (`Sources/DICOMKit/Compression/CompressionManager.swift:43`) maps a codec name → a bare
   `TransferSyntax`, so it cannot express "lossless into the general UID".

---

## 4. Design — `SelectableEncoding` as the intent carrier (no new UIDs)

Keep **one `TransferSyntax` per UID** (`from(uid:)` stays deterministic). Represent lossy vs lossless
as the **encoding intent** already modelled by `SelectableEncoding = (TransferSyntax, EncodingIntent)`.
Thread that intent from selection → codec config → attribute writer.

### 4.1 Catalog: symmetric named entries per family

Extend `parseEncoding` (`Sources/DICOMCore/TransferSyntax.swift:980`) and make
`CompressionManager.codecMap` (`Sources/DICOMKit/Compression/CompressionManager.swift:43`) resolve
**name → `SelectableEncoding`** (UID + intent). Full target catalog:

| Alias(es) | UID | intent | Lossy attrs |
|---|---|---|---|
| `jpeg2000-lossy`, `j2k-lossy` | `.91` | lossy | yes |
| `jpeg2000-lossless`, `j2k-lossless` | `.91` | lossless | no |
| `jpeg2000-lossless-only`, `j2k-lossless-only` | `.90` | n/a | no |
| `j2k-part2-lossy`, `jpeg2000-part2-lossy` | `.93` | lossy | yes |
| `j2k-part2-lossless`, `jpeg2000-part2-lossless` | `.93` | lossless | no |
| `j2k-part2-lossless-only`, `jpeg2000-part2-lossless-only` | `.92` | n/a | no |
| `htj2k-lossy` | `.203` | lossy | yes |
| `htj2k-lossless` | `.203` | lossless | no |
| `htj2k-lossless-only` | `.201` | n/a | no |
| `htj2k-rpcl-lossless-only` | `.202` | n/a | no |
| `jpeg-xl-lossy`, `jxl-lossy` | `.112` | lossy | yes |
| `jpeg-xl-lossless`, `jxl-lossless` | `.112` | lossless | no |
| `jpeg-xl-lossless-only`, `jxl-lossless-only` | `.110` | n/a | no |
| `jpeg-xl-recompression` | `.111` | n/a | no |

Notes:
- Every general family (`.91`/`.93`/`.203`/`.112`) now has a symmetric `-lossy` / `-lossless` pair on
  the general UID plus a `-lossless-only` entry on the reversible-only UID.
- HTJ2K adds a fourth entry, `htj2k-rpcl-lossless-only` (`.202`), for the RPCL reversible-only UID.
- JPEG XL adds `jpeg-xl-recompression` (`.111`) — a distinct mode, unaffected by lossy/lossless intent.
- The UI list (`selectableEncodings`) already produces the lossy/lossless rows for `.91`/`.93`/`.203`;
  this step gives them stable **codec/CLI names**.

### 4.2 Encoder: honour intent for `both`-capable UIDs

Replace the `isLossless` derivation with a capability switch so intent wins only where the UID
actually permits a choice:
```swift
let isLossless: Bool
switch targetSyntax?.losslessCapability {
case .both:          isLossless = configuration.preferLossless      // caller/intent decides
case .losslessOnly:  isLossless = true
case .lossyOnly:     isLossless = false
case nil:            isLossless = configuration.preferLossless || configuration.quality.isLossless
}
```
- No `CodecRegistry` change: the same registered encoder for `.91`/`.203`/`.112` emits reversible
  (5/3, no quantization) or irreversible (9/7 + quantization) purely from the config passed at encode
  time.
- `CompressionManager.compressData(codec:)` resolves the codec name → `SelectableEncoding` and sets
  `config.preferLossless = encoding.isLossless`.
- Apply the same switch in `HTJ2KCodec` and `JXLCodec.makeEncodingConfiguration`.

### 4.3 Attribute writer (the DICOM-conformance piece)

At the **dataset/transcode layer** (`CompressionManager` after encode / `TransferSyntaxConverter`),
add one helper that runs when the resolved intent is **lossy** (or when the source was already lossy):
```
(0028,2110) Lossy Image Compression  = "01"                         // CS, set/keep
(0028,2112) Lossy Image Compression Ratio  ← append  ratio           // DS 1-n
(0028,2114) Lossy Image Compression Method ← append  method(syntax)  // CS 1-n
```
Rules:
- `ratio = uncompressedFrameBytes / compressedFrameBytes` (rounded per DS formatting).
- **Append, never overwrite** — 2112/2114 are parallel arrays that accumulate one entry per lossy step.
- **Once lossy, always lossy:** if `(0028,2110)` is already `"01"`, keep it `"01"`; a later *lossless*
  transcode must not reset it.
- For **lossless** intent into a general UID: leave `(0028,2110)` as-is (`"00"`/absent). Do not add a
  ratio/method.
- Optional (advisory, per IOD): set Image Type (0008,0008) value 1 to `DERIVED` and add Derivation
  Description (0008,2111) on first lossy compression. Flag for a follow-up; not required for MVP.

Add `TransferSyntax.lossyImageCompressionMethod: String?` (returns the Defined Term from the §2
table, `nil` for reversible-only syntaxes) so the method code has one source of truth.

### 4.4 CLI + app surfaces

- `dicom-compress --codec` / `dicom-j2k --target`: accept the new `…-lossy` / `…-lossless` /
  `…-lossless-only` names; help text lists all entries per family (sourced from the catalog).
- App pickers already carry `SelectableEncoding.intent`; pass it into the compression config.
- `dicom-compress info` already prints "Lossless: Yes/No" — it will now also reflect a lossless
  `.91`/`.203`/`.112`.

---

## 5. Phasing (each phase independently reviewable)

1. **Catalog + names** — `parseEncoding` aliases, `codecMap` → `SelectableEncoding`,
   `TransferSyntax.lossyImageCompressionMethod`. Includes the alias re-pointing in §6.
2. **Encoder intent** — capability switch in J2K/HTJ2K/JXL configs; `compressData` threads intent.
   Enables lossless-into-`.91`/`.93`/`.203`/`.112`.
3. **Attribute writer** — populate (0028,2110/2112/2114) with append + once-lossy-always-lossy.
4. **CLI/app wiring** — expose the entries; regenerate CLI parity goldens.

Phases 1–2 unlock the core capability; Phase 3 is the DICOM provenance conformance.

---

## 6. Migration — the intentionally re-pointed aliases

The symmetric scheme repurposes the bare `…-lossless` aliases from the reversible-only UID to the
general UID. This is deliberate (§1). Callers/scripts/fixtures relying on the old UID must migrate to
the explicit `…-lossless-only` name.

| Alias | Old UID (before) | New UID (after) | To keep old behaviour, use |
|---|---|---|---|
| `jpeg2000-lossless`, `j2k-lossless` | `.90` | `.91` (reversible) | `jpeg2000-lossless-only` |
| `j2k-part2-lossless`, `jpeg2000-part2-lossless` | `.92` | `.93` (reversible) | `j2k-part2-lossless-only` |
| `htj2k-lossless` | `.201` | `.203` (reversible) | `htj2k-lossless-only` |
| `htj2k-rpcl`, `htj2k-lossless-rpcl` | `.202` | *(renamed only)* `.202` | `htj2k-rpcl-lossless-only` |
| `jpeg-xl-lossless`, `jxl-lossless` | `.110` | `.112` (reversible) | `jpeg-xl-lossless-only` |

Notes:
- Pixels remain lossless/bit-exact across the change; only the emitted transfer-syntax UID differs.
- `htj2k-rpcl` is a name change only (UID stays `.202`); recommend keeping `htj2k-rpcl` as a
  deprecated alias of `htj2k-rpcl-lossless-only` for one release.
- **Search-and-fix list:** `dicom-compress`/`dicom-j2k` help text, `DICOMConverter.targets` aliases,
  CLI parity fixtures (`cli-parity-gen` templates) and goldens, and any `SampleStudies` scripts.

---

## 7. Open questions / risks for reviewer

1. **Encoder support for reversible into general UID.** Confirm J2KSwift/HTJ2K/JXL backends actually
   produce a spec-valid reversible codestream under the general UID (they already do for the
   lossless-only UIDs; this reuses the same reversible path — low risk, needs a bit-exact round-trip
   test as proof).
2. **Ratio for multi-frame** — compute per-frame vs whole-instance ratio; propose whole-instance
   (total uncompressed / total encapsulated) as the single reported value.
3. **Recompression provenance** — when transcoding an already-lossy source to another lossy syntax,
   append both the historical and new method/ratio? Standard says accumulate; confirm desired UX.
4. **Deprecation window** — keep the old `htj2k-rpcl` spelling (and optionally emit a one-line
   deprecation note) for how many releases?

---

## 8. Test plan (for when implemented)

- Unit: `parseEncoding` resolves every alias in §4.1 to the right `(UID, intent)`; a dedicated
  regression test pins the §6 re-pointing (old alias → new UID) so the change is explicit, not silent.
- Round-trip: lossless `.91`/`.93`/`.203`/`.112` are **bit-exact**; lossy counterparts meet a PSNR
  floor; lossless-only UIDs unchanged.
- Attributes: lossy encode sets `(0028,2110)="01"` + one ratio + correct method per family; lossless
  encode leaves 2110 untouched; re-compress **appends** a second ratio/method and never clears 2110.
- Parity: regenerate `CLIContracts.json` / `goldens*.json`; assert drift is confined to the intended
  new codec names + re-pointed aliases.

---

## 9. Implementation status (2026-07-08)

Implemented per the resolved §7 decisions (reversible-into-general reuses the existing reversible
path; whole-instance ratio; accumulate provenance; `htj2k-rpcl` kept as a deprecated alias).

**Done:**
- **Phase 1 — catalog.** `TransferSyntax`: `.112` added to `losslessCapability .both`; new
  `lossyImageCompressionMethod` (0028,2114 Defined Terms). `parse()`/`parseEncoding()` re-pointed to
  the symmetric scheme; `CompressionManager.codecMap` is now `name → SelectableEncoding` with a new
  `resolveEncoding(for:)`.
- **Phase 2 — encoder intent.** `J2KSwiftCodec.makeEncodingConfiguration` (shared by HTJ2K) and
  `JXLCodec.encoderOptions` honour the caller's intent for the general UIDs; intent is threaded from
  `compressData` through `encodePixelDataInPlace` / `transcodeEncapsulatedInPlace`.
- **Phase 3 — attribute writer.** `CompressionManager.applyLossyImageCompressionAttributes` sets
  (0028,2110)=`"01"` and appends (0028,2112)/(0028,2114); runs only on an irreversible encode; a
  lossless encode leaves any existing lossy history intact ("once lossy, always lossy").
- **Phase 4 — CLI.** `dicom-j2k` resolves via `parseEncoding` (fixes the `from(uid:).isLossless`
  trap) with the new target names + help; `dicom-compress` help lists the symmetric codecs;
  `CLIContracts.json` regenerated.
- **Tests.** `LossyImageCompressionAttributesTests` (method Defined Terms; writer set/append/no-op;
  end-to-end lossy attrs + reversible-into-`.91` bit-exact with no attrs). Re-point regression
  assertions updated across `TransferSyntaxTests`, `CompressionCodecMapTests`, `J2KSwiftCodecTests`,
  `DicomJ2KTests`, `CompressionManagerMetricsTests`, `CompressRoundTripTests`. All green.

**Adversarial review (16-agent workflow) — 12 findings, triaged:**
- **Fixed — `parse()` re-point reverted (was breaking negotiation).** The bare `…-lossless`
  names in `TransferSyntax.parse()` were re-pointed to the general UID, which silently broke the
  UID-only negotiation tools (`dicom-send` hard-failed the match-required store; `dicom-retrieve`/
  `dicom-qr` proposed the general UID). `parse()` is now CONSERVATIVE again (`…-lossless` →
  reversible-only UID); the intent split lives **only** in `parseEncoding`/`codecMap` (the encode
  paths). `dicom-j2k` uses `parseEncoding`, so it still emits `.203` for `htj2k-lossless`.
- **Fixed — parallel-array misalignment (0028,2112)/(0028,2114).** The writer now keeps only the
  paired prefix of prior history before appending, so a malformed source (ratio without method)
  can't misalign the Nth-ratio-↔-Nth-method correspondence.
- **Fixed — Image Type (0008,0008) → DERIVED** on lossy compression (PS3.3 C.7.6.1.1.5.1 "shall").
- **Fixed — JPEG XL `--quality maximum` false provenance.** `JXLCodec` no longer flips to lossless
  on `quality.isLossless`; the `.112` general UID is intent-driven (like J2K), so a lossy-intent
  encode stays lossy and its `0028,2110="01"` is truthful.

**Follow-up completed (2026-07-08): `dicom-convert` brought to parity with `dicom-compress`.**
- **`DICOMConverter.targets` is now intent-aware.** Each `Target` carries an `EncodingIntent`, and the
  catalog exposes the same symmetric three-entry naming as `CompressionManager.codecMap`: `…-lossy`
  (irreversible into the general UID), `…-lossless` (reversible into the *same* general UID), and
  `…-lossless-only` (the distinct reversible-only UID). `.112` (JPEG XL general) is now a convert target
  too. So `dicom-convert --transfer-syntax htj2k-lossless` → `.203` (reversible into general), matching
  `dicom-compress`; the two tools no longer diverge. Parsing adds `resolveTarget(_:)` /
  `resolveTargetEncoding(_:)` (UID + intent); `parseTarget(_:)` is retained (UID-only).
- **Intent is threaded end-to-end** through the CLI (`dicom-convert`) and the app (CLI Workshop), both of
  which resolve via `resolveTargetEncoding` and call the new
  `convertToDICOM(dicomFile:to encoding: SelectableEncoding, stripPrivate:)`. The `.both`-capable UIDs
  are driven by `compressionConfig.preferLossless` (the transcoder's lossy gate is permitted for `.both`
  targets since the UID reports `isLossless == false`; real fidelity is governed by `preferLossless`).
- **Lossy provenance now written by `dicom-convert`.** On an irreversible encapsulated encode,
  `convertToDICOM` re-reads the transcoded output and stamps `(0028,2110)="01"` + ratio (0028,2112) +
  method (0028,2114) + Image Type → DERIVED via the **shared** `CompressionManager.applyLossyImageCompressionAttributes`,
  so convert and compress produce identical provenance. Reversible-into-general-UID encodes stay
  bit-exact and unstamped. Covered by new `DICOMConverterTests` (13) + regenerated goldens; the
  `syn-ct-baseline` parity fixture now correctly carries `ISO_10918_1` provenance.

**Deliberately deferred (documented divergence + lower-severity review items):**
- **Derivation Description (0008,2111) / Derivation Code Sequence (0008,9215)** on lossy compression —
  "may"/recommended (not "shall"); Image Type=DERIVED *is* now written. Deferred.
- **No SOP/IOD eligibility gate (review #5, low).** `compressData` will lossy-encode any IOD, including
  ones that prohibit lossy compression (fractional Segmentation, RT Dose). Pre-existing (the lossy
  encode was already possible); a proper fix rejects lossy targets for prohibited SOP classes.
- **Same-UID lossless request is a no-op (review #9, medium).** Re-compressing a source that is already
  in a general UID carrying a lossy codestream (e.g. a `.91` lossy file) with `--codec jpeg2000-lossless`
  hits the same-UID passthrough branch and does not re-encode. The source pixels are already lossy
  (unrecoverable), so this is an unfulfilled request, not corruption; a fix would gate the transcode on
  intent as well as UID.
- **`dicom-j2k` lossy transcode omits the provenance attributes (review #12, low).** Its lossy
  `--target …-lossy` path writes the transfer syntax but not (0028,2110/2112/2114) — pre-existing, and
  `dicom-j2k` builds its dataset without `DICOMKit`/`CompressionManager`. `dicom-compress` is conformant.

## 10. Status

IMPLEMENTED and green; awaiting review sign-off.
