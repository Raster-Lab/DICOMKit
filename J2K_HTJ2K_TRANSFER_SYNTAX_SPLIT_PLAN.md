# J2K / HTJ2K Transfer Syntax Lossy-Lossless Split — Plan & Status

**Status:** In progress
**Owner:** DICOMKit
**Started:** 2026-07-06
**Last updated:** 2026-07-06

---

## Problem

Per the DICOM standard, several JPEG 2000 / HTJ2K UIDs are a *single UID* that can carry
**either** a lossy or a lossless codestream. DICOMKit currently treats the "general" UIDs as
lossy-only, so the user-facing transfer-syntax list is incomplete and, in some tools, wrong.

Target list (J2K + HTJ2K):

| UID     | Label                     | Capability     | Intent shown |
|---------|---------------------------|----------------|--------------|
| `.90`   | JPEG 2000 Lossless Only   | losslessOnly   | (n/a)        |
| `.91`   | JPEG 2000 Lossless        | both           | lossless     |
| `.91`   | JPEG 2000 Lossy           | both           | lossy        |
| `.92`   | JPEG 2000 Part 2 Lossless Only | losslessOnly | (n/a)     |
| `.93`   | JPEG 2000 Part 2 Lossless | both           | lossless     |
| `.93`   | JPEG 2000 Part 2 Lossy    | both           | lossy        |
| `.201`  | HTJ2K Lossless Only       | losslessOnly   | (n/a)        |
| `.202`  | HTJ2K Lossless (RPCL)     | losslessOnly   | (n/a)        |
| `.203`  | HTJ2K Lossless            | both           | lossless     |
| `.203`  | HTJ2K Lossy               | both           | lossy        |

## Decisions

- **Model:** Capability + expanded catalog. One `TransferSyntax` struct per UID
  (`from(uid:)` stays deterministic). A new shared, expandable catalog renders the list above.
- **(a) Include Part 2 `.92`/`.93`:** YES — same standard semantics as `.90`/`.91`.
- **(b) Fix `.201`/`.202`/`.203` CLI mismatch:** YES — `dicom-j2k` CLI and `MetadataPresenter`
  currently map `.202`→"HTJ2K Lossless"/`.201`→"Part 2", contradicting canonical
  `.201`=HTJ2K Lossless. Consolidating onto the shared catalog fixes this.
  ⚠️ **This changes emitted UIDs for `htj2k-lossless` CLI targets** — external scripts/fixtures
  depending on the old (incorrect) behavior need a heads-up.

## Core principle

`Sources/DICOMCore/TransferSyntax.swift` is the single shared source of truth. Every tool,
the app, and every test must enumerate the shared catalog instead of hardcoding UID lists.
Today ~30 files hardcode their own lists; this work consolidates them.

---

## Phases & Status

Legend: ⬜ pending · 🟨 in progress · ✅ done

### Phase 1 — Shared API in DICOMCore ✅
- ✅ Add `LosslessCapability { losslessOnly, lossyOnly, both }` + `losslessCapability` property
- ✅ Add `EncodingIntent { lossless, lossy, notApplicable }`
- ✅ Add `SelectableEncoding { transferSyntax, intent, uid, displayName, isLossless, id }`
- ✅ Add `selectableEncodings: [SelectableEncoding]` catalog (expands `both` → 2 rows)
- ✅ Fix `displayName` labels (`.90` → "JPEG 2000 Lossless Only", `.201` → "HTJ2K Lossless Only", etc.)
- ✅ Intent-aware `isLossless` on `SelectableEncoding`
- ✅ Add `parseEncoding(_:)` → resolve to `SelectableEncoding` with intent aliases
- ✅ `swift build --target DICOMCore` green

### Phase 2 — Library consumers → shared API 🟨
- ✅ `Sources/DICOMKit/Validation/DICOMValidator.swift` — replaced hardcoded set (had bogus `.204`) with `TransferSyntax.from(uid:)?.isJPEG2000`
- ✅ `Sources/DICOMKit/MetadataPresenter.swift` — removed scrambled label map + bogus `.204`; now delegates to `TransferSyntax.displayName`
- ✅ `Sources/DICOMDictionary/UIDDictionary.swift` — added `.92/.93/.201/.202/.203` name+keyword entries
- ✅ `Sources/DICOMNetwork/DICOMValidator.swift` — reviewed: supported-list already correct (.201/.202/.203), left as curated superset
- ✅ `Sources/DICOMNetwork/StorageSCP.swift`, `RetrieveService.swift` — reviewed: mappings already correct
- ✅ `Sources/DICOMWeb/DICOMwebCapabilities.swift`, `DICOMMediaType.swift` — reviewed: mappings already correct
- ✅ Builds green: DICOMCore, DICOMDictionary, DICOMKit

### Phase 3 — CLI `dicom-j2k` ✅
- ✅ `tsLabel` → `TransferSyntax.displayName`; `isJ2KTransferSyntax` → `isJPEG2000`
- ✅ `targetTransferSyntaxUID` → `TransferSyntax.parse` (fixes htj2k-lossless→.201, htj2k-rpcl→.202, htj2k→.203)
- ✅ `isLossless` derived from shared `TransferSyntax.isLossless`
- ✅ Help text corrected (removed duplicate `.202`, removed bogus `.204`, added .92/.93)
- ✅ `swift build --product dicom-j2k` green
- ⚠️ BEHAVIOR CHANGE: `--target htj2k-lossless` now emits `.201` (was `.202`); `htj2k-rpcl`→`.202` (was `.203`); `htj2k`→`.203` (was bogus `.204`)

### Phase 4 — App (DICOMStudio) ✅
- ✅ Label maps corrected + shared: ImageMetadataHelpers, PerformanceToolsHelpers, MetadataViewModel
- ✅ `J2KTestingViewModel` — support matrix + round-trip picker driven by `selectableEncodings`,
  keyed on `SelectableEncoding.id`, intent threaded into encode (`.91` lossless vs lossy differ)
- ✅ `JP3DVolumeComparisonViewModel` — codec options from catalog, intent threaded into encode
- ✅ `J2KTestBenchModels`/`J2KTestBenchViewModel`/`J2KTestBenchView` — bench syntaxes from catalog with unique `id`, intent threaded
- ✅ `ProgressiveDecodeModel` — J2K UID set from catalog (decode-only, deduped)
- ✅ `DataExchangeView` — conversion targets from catalog; **CLI-target mapping corrected**
  (htj2k-lossless→.201, htj2k-rpcl→.202, htj2k→.203)
- ✅ Consumer views updated (J2KTestingView, CodecImageComparisonView, JP3DVolumeComparisonView)
- ✅ `swift build --target DICOMStudio` green

### Phase 5 — Tests ✅
- ✅ Unit tests (`TransferSyntaxCapabilityTests`, 11 tests): capability per UID, catalog shape
  (10 J2K/HTJ2K rows), dual `.91`/`.93`/`.203` entries, intent-aware displayName/isLossless,
  deterministic `from(uid:)`, `parseEncoding` intent aliases, CLI target aliases
- ✅ `DicomJ2KTests` rewritten to call shared API and assert the CORRECTED mapping
  (htj2k-lossless→.201, htj2k-rpcl→.202, htj2k→.203); removed bogus `.204`
- ✅ `DICOMMediaTypeTests` reviewed — already correct
- ✅ Round-trip: added `.91`-lossless (bit-exact), `.91`-lossy (PSNR), `.203`-lossless
  (bit-exact + HTJ2K-flagged) driven by `SelectableEncoding` intent — all 3 pass
- ✅ Parity harness: found a SECOND stale help block (`TranscodeCommand.discussion`) with `.204`;
  fixed it, rebuilt CLI, regenerated `CLIContracts.json` + `goldens.synthetic.json` via
  `swift run cli-parity-gen` — 0 stale `.204` refs remain

### Verification ✅
- ✅ `swift build` (full package) — Build complete, no errors
- ✅ Affected suites green: `TransferSyntax*` (incl. 11 new capability tests), `DicomJ2K*`,
  `J2KRoundTrip` (22 incl. 3 new), `CLIParityEngine`, `DICOMMediaType`, progressive/codec-inspector
- ✅ Stray-list grep: 0 bogus `.204`, 0 old-wrong HTJ2K mappings in Sources
- ✅ `dicom-uid list` golden now reports **31 UIDs** (was 26) — the 5 new UIDDictionary
  entries propagate through the shared path automatically
- ⚠️ 3 PRE-EXISTING/ENV failures, unrelated to this change (verified by stash test + file scan):
  1. "Registry does not have encoder for RLE" — RLE codec registration (I touched no CodecRegistry)
  2. "Lossless 12-bit grayscale roundtrip" — marked a **known issue** (expected)
  3. "Per-format codec comparison on SampleStudies" — requires `./SampleStudies` corpus (absent here)

---

## Status: COMPLETE

All 5 phases implemented, built, and tested. `TransferSyntax` is now the single shared source
of truth; `.91`/`.93`/`.203` present two selectable rows (lossless + lossy) everywhere, `.90`/`.92`/
`.201`/`.202` are single "Lossless Only" rows, and the long-standing `.201/.202/.203` CLI mismatch
+ bogus `.204` are eliminated across library, CLI, app, and regenerated parity goldens.

## Work Log

- 2026-07-06 — Plan documented; decisions (a) Part 2 `.92/.93` and (b) fix `.201/.202/.203`
  mismatch confirmed.
- 2026-07-06 — Phase 1 shared API (LosslessCapability, EncodingIntent, SelectableEncoding,
  selectableEncodings, parseEncoding); labels fixed. DICOMCore green.
- 2026-07-06 — Phase 2 library consumers routed through shared API; removed bogus `.204` +
  scrambled labels; added missing UIDDictionary entries.
- 2026-07-06 — Phase 3 CLI onto shared catalog; fixed `.201/.202/.203` target mismatch,
  help typo, both help blocks.
- 2026-07-06 — Phase 4 app pickers (5 files + 4 consumer views) onto shared catalog with
  intent threading; DataExchange CLI-target mapping corrected.
- 2026-07-06 — Phase 5 tests: rewrote CLI tests to shared API, added 11 unit + 3 round-trip
  tests, regenerated parity contracts/goldens. Full build + affected suites green.
