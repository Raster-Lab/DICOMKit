# DICOMKit CLI Parity — Tier 2 (Output Parity) Plan

**Goal:** mechanically verify that the **DICOMStudio CLI Workshop** (which *re-implements*
each `dicom-*` command in-process — it does **not** shell out) produces the **same output**
as the **real CLI binary**, for **every subcommand and every flag**.

This is the **Tier 2** companion to the already-shipped **Tier 1 input-contract** harness
(`Scripts/cli-parity.sh` + `Scripts/CLI-PARITY-README.md`). Tier 1 checks *which flags each
side accepts*; Tier 2 checks *whether they behave identically*.

> Status: **PLAN** (no code written yet). Generated from an authoritative sweep of the
> dumped `--experimental-dump-help` contracts (`build/cli-parity/cli/*.json` /
> `Sources/DICOMStudio/Resources/CLIParity/CLIContracts.json`), the live Studio catalog
> (`build/cli-parity/studio-catalog.json`), and the 32-case `executeCommand()` switch in
> `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`.

---

## 0. TL;DR

| Metric | Value |
|---|---|
| Tools with a working CLI contract | **35** (+`dicom-dcmdir` broken, +4 non-ArgParser) |
| Subcommands | **102** |
| Flag / argument slots to cover | **884** |
| Tool IDs wired in `executeCommand()` | **32** |
| Target Tier-2 scenarios (W1–W5) | **~495** |
| Estimated effort (W1–W5) | **~43–68 engineer-days** |

**Locked decisions** (see §6): non-determinism handled by a **TEST-ONLY seeded RNG / injected
clock**; CI fixtures are **synthetic & committed** (PHI-free, byte-deterministic); first
delivery is **Wave 1 only** (deterministic stdout, ~250 scenarios) end-to-end before expanding.

**Today's gap:** Tier-2 output parity exists only as a **5-template skeleton**
(`dicom-info` ×3, `dicom-validate` ×2) over **one random fixture**, in
`Sources/cli-parity-gen/main.swift`. Everything below scales that skeleton.

---

## 1. Why output can drift (and why this harness is needed)

DICOMStudio keeps **two independent, hand-maintained** representations of every tool that must
track the real CLI by hand:

1. **Input contract** — `ToolCatalogHelpers.allTools()` / `parameterDefinitions(for:)` declare
   each tool's flags; `CommandBuilderHelpers.buildCommand()` turns them into the preview.
   *(Tier 1 checks this.)*
2. **Output** — `CLIWorkshopViewModel.executeCommand()` re-implements each command against
   DICOMCore/DICOMKit and formats its **own** console text + writes its **own** output files.
   *(Tier 2 — this document — checks this.)*

Both drift silently from the real swift-argument-parser commands. Tier 2 catches behavioural
drift the same way Tier 1 catches contract drift: mechanically, in CI.

---

## 2. Coverage reality — five buckets, five strategies

Not all 40 tools are testable the same way. Each subcommand's **parity category** dictates the
test strategy. Counts are per-subcommand.

| Category | # | Representative tools | How Tier-2 checks it |
|---|---|---|---|
| **stdout-comparable** | 36 | info, dump, diff, validate, study `summary/check/stats/compare`, uid `validate/lookup`, script `*`, compress `info/backends`, archive `query/list/check/stats`, dcmdir `validate/dump` | normalize text → LCS diff (engine already exists) |
| **artifact-comparable** | 35 | anon, convert, json/xml (file), pdf, pixedit, image, export `*`, compress `compress/decompress`, tags (write), split, merge, dcmdir `create` | compare *produced files* (DICOM-semantic / perceptual), **never bytes** |
| **network-mock-needed** | 14 | echo, query, send, retrieve, qr, mwl, mpps, wado `query/retrieve/store/ups` | requires a mock SCP / DICOMweb server (Wave 5) |
| **not-wired-in-studio** | 13 | 3d, measure, gateway, jpip, report, viewer, j2k, dcmdir `update` | no UI reimplementation → **wire-in-Studio first**, then inherits a wave |
| **contract-only-broken** | 4 | ai, cloud, print, server | CLI itself fails dump-help / is a daemon → **fix-CLI first** |

### Two blockers to file now

- **`dicom-dcmdir` is wired in Studio but its CLI contract is broken** —
  `--experimental-dump-help` fails with *"Validation failed for `Create`"*, so it never lands
  in `CLIContracts.json`. Studio reimplements `create/validate/dump` but there is nothing to
  diff against until the ArgumentParser definition is fixed.
- **`dicom-ai`, `dicom-cloud`, `dicom-print`, `dicom-server`** produce no contract at all
  (broken parsers or long-running daemons). A server has no UI equivalent; treat these as
  permanent `SKIPPED(reason)` until triaged.

The full per-subcommand classification is in **Appendix A**.

---

## 3. Architecture (build *on top of* Tier 1 — don't redesign it)

```
cli-parity-gen (offline, shells out)          StudioParityTests (@MainActor, in-process)
  ├─ run real binary per scenario ──► goldens   ├─ instantiate CLIWorkshopViewModel
  │   stdout/stderr/exit + artifact digest      ├─ inject params (no NSOpenPanel / bookmark)
  ├─ capability-matched synthetic fixtures      ├─ executeCommand() → consoleOutput + files
  └─ derive studioParams via buildCommand()     └─ normalize BOTH sides → diff → verdict
                          │                                        │
                          └────────► goldens.json ◄────────────────┘
                                          │
              cli_parity_report.py → "Output Parity" xlsx sheet  +  in-app panel
```

**Load-bearing insight:** the headless path already works.
`CLIAutomationTestingViewModel.compareOutput()` already drives `executeCommand()` in-process,
and every tool's `inputScopedURL ?? URL(fileURLWithPath:)` pattern means an **un-sandboxed
`swift test` bundle gets file access for free** (the security-scoped-bookmark branch simply
no-ops). Tier 2 is therefore **not a new execution mechanism** — it is:

1. generalizing that path to **file artifacts** and **network mocks**,
2. **deriving** `studioParams` from `CommandBuilderHelpers.buildCommand()` instead of
   hand-authoring them, and
3. wrapping it in a **sharded, gating, machine-readable** CI harness.

---

## 4. The four cross-cutting components

### 4a. Fixtures — replace "one random file" with a capability-tagged corpus

`randomElement()` in `selectInputFixtures()` (`Sources/cli-parity-gen/main.swift`) is a
correctness bug: goldens aren't reproducible run-to-run, and one file can't satisfy
`dicom-split` (needs **multiframe**), `dicom-study` (needs a **multi-study set**), `dicom-pdf`
(needs **encapsulated PDF**), etc.

- Define a **closed capability vocabulary**: `single-frame`, `multiframe`, `uniform-spacing`,
  `high-bit-depth`, `compressed-j2k`, `has-overlay`, `sr-document`, `encapsulated-pdf`,
  `rtstruct`, `multi-file-set`, `multi-study-set`, `complete-study`/`incomplete-study`,
  `identical-studies`/`divergent-studies`, plus non-DICOM companions (`hl7-v2-message`,
  `fhir-json-resource`, `dicom-script`).
- Ship a **committed, PHI-free `synthetic/` corpus** — extend the existing
  `makeSyntheticFixture()` into one builder per capability, with **fixed UIDs/dates/pixel
  patterns** (no `randomElement`, no `Date()`, no live UID generation). This makes CI
  byte-deterministic and lets deterministic-tool goldens be **committed**
  (`goldens.synthetic.json`).
- Real PHI files stay **git-ignored** and *augment* coverage locally (preferred only for
  realism-sensitive tools: compress/j2k/image/export/convert).
- A `CLIFixtureManifest.json` (committed, PHI-free) tags each fixture; a **deterministic
  resolver** (total ordering: origin → tightest-fit → smallest → id) binds each scenario to a
  compatible fixture, or emits `UNAVAILABLE` cleanly.

#### Local real-fixture corpus

**Real-fixture input directory: `/Users/raster/Desktop/DICOM_Input/`** (the existing
`cli-parity-gen` default; override with `$DICOM_INPUT_DIR` or arg 3). This is the **PHI,
git-ignored** augmentation source — never committed; only the synthetic corpus and PHI-free
contracts are committed.

Current contents (PHI-free capability survey via the project's own `dicom-info` parser —
**35 `.dcm` files**, 7 modality folders; full per-file table in **Appendix B**):

| Modality dir | Files | Transfer syntaxes | Frames | What it provides |
|---|--:|---|---|---|
| `CT/` (+ top-level `CT.dcm`) | 6 | explicit-le | 1 | `single-frame`, `high-bit-depth`, `ct-modality`, `multi-study-set` (Study1–4) |
| `DX/` | 5 | implicit-le | 1 | `single-frame`, `high-bit-depth` (large 12–15 MB) |
| `MG/` | 5 | implicit-le ×3, **jpls-lossless** ×2 | 1 | `single-frame`, `compressed` (Modality tag = `CR`; 12–33 MB) |
| `MR/` | 5 | explicit-le ×3, implicit-le ×2 | 1 | `single-frame`, `multi-study-set` (⚠ 3 files carry `Modality=CT`) |
| `PX/` | 5 | implicit-le ×3, **jpeg-ll-sv1**, **jpls-lossless** | 1 | `single-frame`, `compressed` |
| `US/` | 4 | **jpeg-baseline** | **76–92** ×3, 1 | **`multiframe`**, `compressed`, YBR color, 8-bit |
| `XA/` | 5 | implicit-le | **30–59** ×3, 1 ×2 | **`multiframe`** (uncompressed), `single-frame` |

**Capability availability vs the §4a vocabulary** (drives synthetic-vs-real routing):

| Need | Real corpus? | Source |
|---|---|---|
| `single-frame`, `high-bit-depth`, `multiframe`, `multi-study-set`, modality variety (CT/CR/DX/MR/PX/US/XA), uncompressed (implicit/explicit-le), compressed (jpeg-baseline / jpeg-lossless-sv1 / jpeg-ls-lossless) | ✅ available | use real (preferred for realism-sensitive tools) |
| **`compressed-j2k` / `j2k-lossless`** (JPEG 2000) | ❌ **absent** — corpus has JPEG & JPEG-LS only | **synthesize**, or transcode a real file via `dicom-compress` at gen-time |
| `has-overlay`, `sr-document`, `encapsulated-pdf`, `rtstruct` | ❌ absent | **synthesize** (the committed `synthetic/` builders) |
| `uniform-spacing` volume set for `dicom-3d` | ⚠ partial — CT slices exist but span different studies | synthesize, or assemble a same-series subset |

> 🔎 **Classifier must read the `Modality` tag, not the folder name** — this corpus has MG files
> tagged `CR` and three `MR/` files tagged `CT`. `FixtureClassifier` keys off DICOM tags only.

> ⚠️ **Coverage caveat — the `MAX_BYTES = 5 MB` cap excludes 19 of 35 files today.** All MG,
> DX, most XA/US/PX files exceed the generator's `MAX_BYTES` (`Sources/cli-parity-gen/main.swift`),
> so under the current code only ~16 small CT/MR/PX/US files are even eligible, and
> `randomElement()` then picks **one**. To use this corpus meaningfully the generator must
> (a) raise/parameterize `MAX_BYTES` (or exempt capability-needed large files), and
> (b) replace random single-pick with the capability-matched resolver above. The
> `FixtureClassifier` (`Sources/cli-parity-gen/FixtureClassifier.swift`, new) tags each real
> file (transfer syntax, frames, bit depth, overlay, SOP class, modality) so XA/US multiframe
> and the CT/MR multi-study sets are routed to the tools that need them.

**Acceptance gate:** re-running `cli-parity-gen` with **no input dir** (CI) yields a
**byte-identical** `goldens.synthetic.json`; with `DICOM_INPUT_DIR=/Users/raster/Desktop/DICOM_Input/`
(local) it *adds* real-augmented scenarios on top, deterministically resolved (never
`randomElement`).

### 4b. Normalization — the make-or-break of output parity

Extend `CLIParityEngine.normalize()` into an **ordered pipeline applied identically to both
sides**:

1. channel-select (stdout, or stdout+stderr deterministically joined),
2. line-ending canon + ANSI strip,
3. drop the Studio `$ cmd` echo,
4. **drop whole status-banner lines** (✅/❌/⚠️ + Studio-authored copy) — *current code only
   strips the glyph, leaving the English text that then mismatches*,
5. canonicalize fixture paths,
6. **mask volatile fields** via a per-tool rule table (UIDs, ISO timestamps, DICOM dates/times,
   durations, temp paths, `(N bytes)` previews, encoder/impl version),
7. **JSON/XML canonicalize** (sort keys, fixed float precision),
8. whitespace trim.

For **artifacts**, *never* byte-compare:
- **DICOM producers** → parse both with DICOMKit, diff tag-by-tag **minus a volatile-tag
  deny-list** (SOP Instance UID, Study/Series UID when auto-generated, Study Date/Time);
  PixelData compared as `sha256(decoded pixels)` so transfer-syntax/encapsulation differences
  don't matter; lossy codecs fall back to **SSIM/PSNR** with a per-codec threshold.
- **Image/PDF producers** → decode to raster, compare via **SSIM** (strip ICC/EXIF/`tEXt`);
  PDF compared as structural extract (page count/sizes + masked text), not rasterized.

### 4c. Headless runner + CI

- New **`StudioParityTests`** XCTest target (`@MainActor`). Per scenario: copy fixture into a
  fresh temp workdir, point input/output params at it, `await executeCommand()`, capture
  `consoleOutput` + written files, normalize, diff, emit **one JSONL line** + an
  `XCTAttachment` diff.
- Put the engine in **product code** (`StudioParityRunner.swift`) so the in-app screen and the
  test target share it.
- **Derive `studioParams` from `cliArgs`** by walking the parameter definitions and
  **round-tripping through `buildCommand()`** — if the round-trip flag-set doesn't match the
  scenario's `cliArgs`, that *is* a parity bug (Studio can't express the flag) → fail it loudly.
- **Shard** the ~495 scenarios across N processes (`PARITY_SHARDS` / `PARITY_SHARD`),
  concatenate JSONL, fold into the report. Per-scenario timeout so a hung tool fails as
  `error`, not a wedged shard.
- Extend `Scripts/cli-parity.sh` with a `TIER2=1` path: **gen → rebuild DICOMStudio (so
  `Bundle.module` re-bundles fresh goldens) → sharded `swift test` → merge → report.**
  *(Per project memory: editing shared DICOMKit source means rebuild the affected `dicom-*`
  tools — release **and** debug — before regenerating goldens, or capture goes stale.)*
- **CI gate** fails on any un-allowlisted `differs`/`error` **and** on **coverage regression**
  against a committed baseline (so silently dropping scenarios is itself a failure).

### 4d. Reporting

- Add an **"Output Parity" sheet** to `Scripts/cli_parity_report.py`: one row per
  `(tool, subcommand, scenario)` → **MATCH / DIFF / SKIPPED(reason) / ERROR**, exit-code match,
  comparator used, diff snippet, plus a per-tool **coverage ratio**.
- The in-app **"CLI Automation Testing"** screen already models `OutputParityStatus` /
  `OutputComparison` / `OutputDiffLine` — it needs the SKIPPED axis and more scenarios
  surfaced, plus filter chips and a coverage ratio.
- **Enumerate all 40 tools** including broken / not-wired ones as explicit SKIPPED rows so gaps
  are visible, never hidden by absence.

---

## 5. Rollout waves (each ships independently; capability grows monotonically)

| Wave | Scope | Scenarios | Effort | New capability | Exit criteria |
|---|---|--:|--:|---|---|
| **W1 Deterministic stdout** | info, dump, diff, validate, json/xml (stdout), tags (read), study `summary/check/stats/compare`, uid `validate/lookup`, dcmdir `validate/dump`, compress `info/backends`, script `*`, archive `query/list/check/stats` | ~250 | 5–7d | **none** (reuse normalize/diff) | every subcmd ≥1 scenario; 100% MATCH or reasoned SKIP |
| **W2 File producers** | anon (no-regen), convert, pdf, pixedit, image, export `*`, compress (lossless), tags (write), json/xml (file) | ~120 | 8–12d | artifact comparators | deterministic→byte MATCH; UID/ts-only→semantic MATCH w/ reviewed deny-list |
| **W3 Stateful** | dcmdir `create`, archive `init/import/export`, split, merge, study `organize` | ~30 | 6–9d | fixture-sets + workdir sandbox | round-trips (split→merge, create→dump) MATCH |
| **W4 Non-deterministic** | uid `generate/regenerate`, anon (regen), lossy compress/convert, export `animate`, `Date()`-injecting tools | ~40 | 8–14d | **seed/clock injection** + invariant asserts | each scenario seeded-exact **or** invariant-asserted w/ committed note |
| **W5a DIMSE** | echo, query, send, retrieve, qr, mwl, mpps | ~30 | 8–12d | **live DCM4CHEE round-trip** (seeded set) + mock SCP as CI fallback | seeded round-trip latency-stripped MATCH; deterministic ×10 runs |
| **W5b DICOMweb** | wado `query/retrieve/store/ups` (`ups` = 38 flags, own milestone) | ~25 | 8–14d | **live dcm4chee DICOMweb REST** + mock HTTP as CI fallback | stateful workitem lifecycle MATCH |
| **Backlog** | *wire-first:* 3d, measure, gateway, jpip, report, j2k, dcmdir `update` · *fix-first:* ai, cloud, print, server, dcmdir contract | — | open | prerequisite work | tracked SKIPPED rows, never counted as pass |

`dicom-viewer` (ANSI/Sixel terminal rendering) and pure benchmarks are flagged **permanently
SKIPPED** (`terminal-rendering / timing — not comparable`) rather than forced into a flaky
comparison.

**Start with W1** — zero new machinery (normalize/diff already exist), highest-value
deterministic tools, and it proves the gen→runner→report→gate loop before investing in
comparators and mocks.

### Network test endpoints (Wave 5) — live DCM4CHEE + mock fallback

Two reachable **DCM4CHEE** archives are available for DIMSE parity (lab network, **not**
CI-reachable). They turn Wave 5 from "build a mock" into "round-trip against real PACS", with
the mock retained only as the cloud-CI fallback.

| Node | Host | AE Title | DIMSE Port | DICOMweb base (default) |
|---|---|---|--:|---|
| **DCM4CHEE-2** | `172.17.1.200` | `TEAMPACS` | `11112` | `http://172.17.1.200:8080/dcm4chee-arc/aets/TEAMPACS/rs` |
| **DCM4CHEE-5** | `172.17.1.111` | `DCM4CHEE` | `11112` | `http://172.17.1.111:8080/dcm4chee-arc/aets/DCM4CHEE/rs` |

> The credentials given are **DIMSE** (AE title + port 11112). The DICOMweb REST is served on
> **HTTP port 8080** (confirmed) at `…/dcm4chee-arc/aets/<AET>/rs`.

**Indirection (don't hardcode lab IPs in test source):** parameterize via env —
`$PARITY_PACS2_HOST/AET/PORT`, `$PARITY_PACS5_HOST/AET/PORT` (and `*_WEB` for the REST base),
with the values above as documented defaults in a single `PACSConfig` read by the test target.

**Determinism on a live PACS — "seed then round-trip":**
1. Pre-stage a **fixed synthetic dataset** (fixed UIDs via the §6 seed hook) under a dedicated
   test Study/Series UID range, C-STORE'd **once** to the target node.
2. Each scenario queries/retrieves **by those exact known UIDs** → result identity and counts
   are deterministic, independent of whatever else the archive holds.
3. **Normalize** the genuinely volatile bits: round-trip latency, server-minted UIDs (MPPS SOP
   Instance UID, STOW transaction UID), response timestamps (reuse §4b mask rules).
4. **Idempotent staging:** dcm4chee dedups on SOP Instance UID, so re-runs are stable; query by
   the fixed study UID so the result set never depends on global archive state.

**Two-node scenarios the credentials unlock:**
- **C-ECHO** (`dicom-echo`) to each node — deterministic success/fail.
- **C-STORE** (`dicom-send`) of the seeded set → assert stored count.
- **C-FIND** (`dicom-query`, `dicom-mwl`) by known keys → deterministic result set.
- **C-MOVE / C-GET** (`dicom-retrieve`, `dicom-qr`) of the seeded instances; **cross-node
  C-MOVE** from node A with **destination AE = node B** — each node is already registered as a
  move destination on the other (confirmed), so A→B and B→A both work out of the box.
- **MPPS** (`dicom-mpps` create/update) against the MPPS SCP.
- **DICOMweb** (`dicom-wado` query/retrieve/store/ups) against the REST base URL.

**CI caveat:** GitHub runners cannot reach `172.17.x.x`, so live-PACS scenarios run **only when
`$PARITY_PACS*` is reachable** (lab / self-hosted runner). In cloud CI they fall back to the
in-process mock SCP/HTTP (§4c) or are emitted `SKIPPED(reason="PACS unreachable")` and counted
against the coverage baseline — **never silently green**.

**Safety:** these are **shared archives**. Tests must use a dedicated test AE + an isolated
Study-UID range, write only the **seeded synthetic** set (no PHI), and clean up; never run broad
C-MOVE / delete against production data.

---

## 6. Locked decisions

| Decision | Choice | Consequence |
|---|---|---|
| **Non-determinism** | **TEST-ONLY seed/clock hook** | `UIDGenerator.seed(_:)` + injectable `Clock`, gated on an env var (e.g. `DICOMKIT_PARITY_SEED`) that **ships unset**. Both CLI capture and Studio run use the same seed → non-deterministic tools become **exact-match**. Hook **must be inert in release** and asserted off. *(Same TEST-ONLY discipline as the existing `dicom-info terminal-compare` sandbox toggle.)* |
| **Fixtures** | **Synthetic, committed** | PHI-free `synthetic/` corpus + `CLIFixtureManifest.json` → CI is byte-deterministic and deterministic goldens are committable. Real PHI files remain git-ignored and optional — sourced from **`/Users/raster/Desktop/DICOM_Input/`** (7 modalities: CT/DX/MG/MR/PX/US/XA; see §4a, incl. the `MAX_BYTES` caveat). |
| **Network (W5)** | **Live DCM4CHEE + mock CI fallback** | DIMSE round-trip against **DCM4CHEE-2** (`172.17.1.200` / `TEAMPACS` / `11112`) and **DCM4CHEE-5** (`172.17.1.111` / `DCM4CHEE` / `11112`), seeded for determinism; in-process mock SCP/HTTP when `$PARITY_PACS*` is unreachable (cloud CI). See §5 → *Network test endpoints*. |
| **Scope** | **W1 only first** | Build deterministic-stdout end-to-end (~250 scenarios), prove gen→runner→report→gate, then expand. No comparators, no mocks yet. |

---

## 7. Wave 1 — the concrete starting deliverable

**In scope (deterministic stdout, wired):** info, dump, diff, validate, json/xml (stdout),
tags (read), study `summary/check/stats/compare`, uid `validate/lookup`, dcmdir
`validate/dump`, compress `info/backends`, script `run/validate/template`, archive
`query/list/check/stats`.

**Tasks:**

1. **Synthetic fixtures** — `SyntheticFixtures.swift` builders (single-frame, multiframe,
   has-overlay, multi-file-set, SR) + committed `synthetic/` + `CLIFixtureManifest.json`.
   *(No seed hook needed yet — W1 tools are already deterministic; the hook lands in W4.)*
2. **Template registry** — replace the 5-entry `templates` array in
   `Sources/cli-parity-gen/main.swift` with a data-driven `templates.json` (per-flag
   one-at-a-time + enum-value coverage) and a deterministic capability-matched resolver
   replacing `randomElement()`.
3. **Golden schema v3** — add `stderr`, `parityCategory`, `subcommand`, `maskRules`; write
   committed `goldens.synthetic.json`; keep `GoldenScenario` decode back-compatible.
4. **Headless runner** — `StudioParityRunner.swift` + `StudioParityTests` target; derive
   `studioParams` via `buildCommand()` round-trip (divergence = logged parity bug).
5. **Normalization** — upgrade `CLIParityEngine.normalize()`: whole-line status-banner drop +
   JSON canonicalization (W1 needs little masking since these tools are deterministic).
6. **Report + gate** — `TIER2=1` path in `Scripts/cli-parity.sh`, "Output Parity" sheet in
   `Scripts/cli_parity_report.py`, `Scripts/cli_parity_gate.py`, CI workflow.

**Exit criteria:** every listed subcommand has ≥1 committed synthetic-golden scenario; all
resolve to MATCH or reasoned SKIPPED (zero silent gaps); coverage ratio per
`(tool, subcommand)` flags any untested flag; CI gate fails on un-allowlisted DIFF/ERROR and on
coverage regression.

**Fix-first blocker:** `dicom-dcmdir`'s broken `--experimental-dump-help` — its
`validate`/`dump` subcommands are W1 candidates but can't be captured until the ArgumentParser
definition is fixed. Track it so it doesn't silently drop out.

### Wave 1 — implementation status (in progress)

The harness loop is **built and green end-to-end**. Run it with:

```bash
swift run cli-parity-gen          # regenerate goldens (deterministic fixture + W1 matrix)
swift test --filter StudioParityTests          # drive Studio reimpl vs goldens, report MATCH/DIFFERS
# STUDIO_PARITY_OUT=/tmp/p.jsonl swift test --filter StudioParityTests   # + machine-readable diff dump (may contain PHI)
# PARITY_STRICT=1 …                # also fail the test on any DIFFERS (CI-gate mode)
```

Landed:

| Piece | Change |
|---|---|
| `executeSupported` sync | `CLIParityEngine.swift` — added the 14 wired local tools that were missing (json/xml/uid/dcmdir/pdf/pixedit/split/merge/archive/compress/study/image/export/script), so they're no longer silently `UNAVAILABLE`. |
| **Synthetic fixtures** | new `cli-parity-gen/SyntheticFixtures.swift` — byte-deterministic, PHI-free Part-10 builders (single-frame CT, a second CT for diff, multiframe CT). Committed under `Resources/CLIParity/synthetic/`. |
| **Dual goldens** | `cli-parity-gen` writes `goldens.json` (full local superset incl. real-fixture augmentation, git-ignored) **and** `goldens.synthetic.json` (PHI-free, **committed**). `loadGoldens()` prefers the former, falls back to the latter → harness runs from a clean checkout with no gen step / no PHI. |
| **Determinism gate** | generator JSON-canonicalizes stdout (sorted keys) **and** auto-probes each committable scenario twice, excluding any non-deterministic CLI output (e.g. `dicom-diff --format json`'s unsorted array). Regenerating `goldens.synthetic.json` is now byte-identical. |
| **Capability-matched fixtures** | `Template.fixture` logical id (`ct`/`mf`/`ctpair`/`studyset`/`studypair`/`archive`/`none`) + `FIXTURE`/`FIXTURE2` placeholders; `fixtureFile2` golden field; `fixtureURL` searches `synthetic/` and resolves **directories**; `compareOutput` resolves two inputs + no-file tools. |
| **Directory fixtures** | `SyntheticFixtures.studySet()` builds multi-file study directories (committed under `synthetic/syn-studyset*`); a populated **archive** is built at gen time via `dicom-archive init`+`import` into git-ignored `fixtures/syn-archive` (local-only: its index carries timestamps + absolute paths). |
| **Harness fidelity** | `normalize` canonicalizes JSON (sorted keys) + collapses separator-glyph rules (CLI `═` vs Studio `=`); `compareOutput` clears optional output-path params the scenario didn't set (Studio default-filled `~/Desktop/DICOM_Output`, causing spurious file writes). |
| W1 template matrix | 5 → **71** scenarios (**43 committed** PHI-free + real/archive/non-portable augmentation): info ×5, validate ×6, dump ×6, compress info/backends ×4, script ×2, uid ×6, **multiframe** ×4, **dicom-diff (2-file)** ×4, **dicom-study (directory)** ×10, **dicom-archive (query/list/check)** ×6. `dicom-json`/`dicom-xml` write files → Wave 2. |
| Headless runner | `StudioParityTests` target — drives `runOutputVerification` over all bundled goldens, PHI-safe report, opt-in JSONL, asserts no ERROR/UNAVAILABLE. |
| **CI gate** | Under `PARITY_STRICT=1` the test fails on any DIFFERS not in the committed `parity-allowlist.json` (the 9 triaged findings), on stale allowlist entries (a finding that silently went green), and on any ERROR/UNAVAILABLE. Wired as a `parity-gate` job in `.github/workflows/dicom-studio-ci.yml`, running against the committed `goldens.synthetic.json` (no `cli-parity-gen`, no dicom-* binaries). Non-portable scenarios (`compress backends` — host-dependent hardware list) are excluded from the committed set via a `portable` flag. |

Current result (Wave 1 + Wave 2.1/2.2): **85 MATCH / 11 DIFFERS / 0 ERROR / 0 UNAVAILABLE** (96 local
scenarios; **55 committed deterministic + portable** drive CI). 16 tools across 3 comparison modes;
json/xml file artifacts (8/8), tags+convert DICOM artifacts (10/10), split multi-file (2/2) match;
anon (F13) and merge (F14) DIFFER. The gate is **green** (all 11 DIFFERS allowlisted) and verified to
have teeth (drops an allowlist entry → fails on that scenario).

**Findings the harness surfaced (none masked). ✅ = fixed and re-verified green by the harness.**

| # | Scenario(s) | Severity | Studio behaviour vs CLI | Status |
|---|---|---|---|---|
| F1 | `validate --format json` | bug | Studio ignored `--format json`, emitted text not JSON. | **✅ fixed** — `ValidationHelpers.renderJSON` + `runValidation` honors `format`. |
| F2 | `script template` (all 5 names) | bug | `executeDicomScript` didn't handle `template` — errored instead of emitting the script. | **✅ fixed** — template branch + `dicomScriptTemplate()` helper. |
| F3 | `validate --level 5` | bug | Studio omitted the CLI's `File contains N private tags …` warning. | **✅ fixed** — private-tag check added to `validateBestPractices`. |
| F12 | `validate --level 5` (no-charset) | minor | Studio's `Specific Character Set` warning wording/tag differed from the CLI. | **✅ fixed** — wording + tag matched to CLI. |
| F4 | `compress backends` (text) | minor | Studio paraphrases the CLI's backend hint. *(The `--json` variant MATCHES — was pure key-ordering.)* | open (cosmetic) |
| F5 | `uid lookup --list-all` | minor | List matches; Studio appends a `26 UIDs found` footer. | open (cosmetic) |
| F6 | `diff --format json` | bug | CLI's `modified`/`onlyInFile` arrays came from unordered collections (non-deterministic); a normalize regex (`\S*`) also ate the leading JSON quote, breaking key-canonicalization. | **✅ fixed** — CLI sorts the arrays by tag (now deterministic → committed); normalize path-regex changed to `[^\s"]*`. |
| F11 | `archive list` / `list-instances` | bug | CLI renders a **tree**, Studio a flat **table** — Studio's tree renderer existed but the `format` param default-filled `table`, overriding the per-subcommand `tree` default. | **✅ fixed** — removed the wrong `format` default so `executeDicomArchive` applies the CLI's per-subcommand default. |
| F9 | `study summary --format json` | minor | Same data, **series array order** differs (Studio asc, CLI desc). | open (same class as F6 — sort the CLI array) |
| F10 | `study check` / `compare` | minor | Studio uses `[OK]` where the CLI uses `✓`; `check` prints a line the CLI omits. | open (cosmetic) |
| F13 | `anon` (basic / clinical-trial) | bug | Studio's anon **removes** PatientName/PatientID; the CLI **replaces** them (`ANONYMOUS` + a hashed PatientID). | open (needs CLI's pseudonymization hash) |
| F14 | `merge` (mixed-series dir) | minor | Studio inherits `SeriesNumber` from a different source frame than the CLI (1 vs 2). | open (cosmetic / ambiguous input) |

*(Latent, not yet tested: Studio's `validateBestPractices` adds an InstanceNumber-absent warning the
CLI doesn't emit — no current fixture lacks InstanceNumber, so it's untested. Also resolved by
legitimate harness fixes, not masking: the `═`/`=` separator glyph; `study check` writing to
`~/Desktop/DICOM_Output`; the `backends --json` key-ordering false positive.)*

**Bugs fixed (all 6 verified green by the harness):** F1/F2/F3/F12 (validate/script) in
`ValidationModel.swift`, `ValidationViewModel.swift`, `CLIWorkshopViewModel.swift`; **F6**
(`dicom-diff/main.swift` sorts its JSON arrays + `CLIParityEngine.normalize` path-regex fix);
**F11** (`CLIWorkshopHelpers.swift` archive `format` default). MATCH 5 → **65** scenarios.

Disposition of the 6 remaining DIFFERS (all allowlisted, gate green): **F4** is host-dependent
(hardware backend list — excluded from the committed set, local-only); **F5/F9/F10** are
cosmetic/ordering drift left as a team triage call (match-the-CLI vs accept-as-intentional-UI). F9 is
the same class as F6 (sort the CLI's series array) if you choose to close it.

### ✅ Wave 1 is functionally COMPLETE

All deterministic-stdout tools are covered (9 tools, 71 scenarios), goldens are PHI-free/committable
and byte-deterministic, every real reimplementation bug found has been fixed and re-verified green,
and a CI gate (`parity-gate` job, allowlist-backed, with teeth) protects it from regression.

### Wave 2 — file-producer artifact comparison (in progress)

The harness now compares **written output files**, not just stdout. New mechanism: a template sets
`artifactName` + an `OUTPUT` placeholder; the generator runs the binary writing to a scratch file and
stores that file's content as the golden; `compareOutput` points the Studio output param at its own
temp file, runs `executeCommand`, and diffs the written file. (`cli-parity-gen/main.swift` `produce()`,
`GoldenScenario.artifactName`, `CLIAutomationTestingViewModel.compareOutput`.)

Landed — **W2.1 text artifacts (json/xml file mode)**: 8 scenarios (`dicom-json`/`dicom-xml`
`--metadata-only [--pretty] --output`), all **MATCH**. Reuses the text normalize/diff + JSON
canonicalization.

Landed — **W2.2 DICOM-semantic artifacts** (binary `.dcm` producers): the harness produces the file,
**re-dumps it via `dicom-info`** (shared `MetadataPresenter`) on both sides — in-process chaining on
the Studio side — and diffs the dumps with a **volatile-tag mask** (`CLIParityEngine.maskVolatileDumpTags`:
file-meta impl/SOP UIDs, instance/study/series UIDs). The generator canonicalizes the producer's stderr
temp-path so committed goldens stay byte-stable. Producers covered:

- **`dicom-tags` write** (set/delete/delete-private) — 8/8 **MATCH**.
- **`dicom-convert`** (transfer-syntax explicit→implicit LE; pixel bytes unchanged) — 2/2 **MATCH**.
- **`dicom-anon`** (basic / clinical-trial — deterministic, no UID regen) — **DIFFERS → finding F13**:
  Studio's anon *removes* PatientName/PatientID, the CLI *replaces* them (`ANONYMOUS` + a hashed
  PatientID). Real reimplementation gap; allowlisted (fix needs the CLI's exact pseudonymization hash).
- **`dicom-split`** (multiframe → **multiple** single-frame files) — **2/2 MATCH**. Added a
  `dicom-multi` artifact kind: `OUTPUT` is a directory, each produced frame is re-dumped and
  concatenated with index headers; per-frame SOP UIDs masked. (Also fixed a `normalize` blank-run
  collapse so concatenated per-file dumps align.)
- **`dicom-merge`** (a directory of single-frame files → one multiframe; multi-input via a directory
  fixture) — **DIFFERS → finding F14** (minor): merging a *mixed-series* directory, Studio inherits
  `SeriesNumber` from a different source frame than the CLI (1 vs 2). Mechanism proven (only 1 tag differs).

Result: **85 MATCH / 11 DIFFERS / 0 ERROR** (96 local, **55 committed**). Three comparison modes:
stdout, text-file, DICOM-semantic (single + multi-file). Determinism + gate still green.

Next in Wave 2: **`compress`/`decompress`** is **blocked on this host** (the RLE encoder isn't
registered — codec availability is host-dependent, like the backends list — and lossy codecs need
pixel decode + SSIM); it would be non-portable/local-only. Then **image/PDF** artifacts
(SSIM/structural). Then **network** (Wave 5) against the DCM4CHEE servers.

**55 committed scenarios** drive CI from a clean checkout.

Remaining housekeeping: **commit** the new artifacts (`synthetic/`, `goldens.synthetic.json`,
`parity-allowlist.json`, `SyntheticFixtures.swift`, `Tests/StudioParityTests/`, the `.github` gate job,
+ the source edits). Optional: close the cosmetic F5/F9/F10; the xlsx "Output Parity" sheet (the in-app
screen + `swift test` gate already cover reporting + gating). **Wave 2+** (file-producer artifact
comparison, network via the DCM4CHEE servers) is scoped in §5.

---

## 8. Silent-coverage-cap risks (make each loud, never green-by-omission)

1. **Cartesian-explosion avoidance hides flags** — a flag never placed in any template "passes"
   only because it's never exercised. *Mitigation:* coverage ratio compares template-covered
   flags vs the contract's accepted set; uncovered flags render as `SKIPPED(flag not covered)`.
2. **SKIPPED masquerading as pass** — report pass-rate as `MATCH ÷ (MATCH+DIFF+ERROR)` and show
   SKIPPED + coverage ratio separately.
3. **Over-aggressive normalization eats real diffs** — every mask/exclusion is per-tool,
   committed, reviewed, and its reason is rendered in the report.
4. **Perceptual/invariant tolerances drifting upward** — thresholds are committed named
   constants; PRs that change them are flagged.
5. **Single random fixture under-represents inputs** — capability-by-kind selection guarantees
   each template runs against its declared kinds; a missing kind → `SKIPPED(no <kind> fixture)`.
6. **Broken / not-wired tools vanishing from the denominator** — the report enumerates the full
   40-tool catalog and renders these as explicit SKIPPED rows.
7. **Exit-code-only matches** — empty-stdout MATCH rows are flagged `MATCH (empty)`.

---

## 9. File-change index (for the full W1–W5 build)

| File | Role |
|---|---|
| `Sources/cli-parity-gen/main.swift` | replace 5-template list + `randomElement()`; matrix generator; `cliArgs→studioParams` round-trip; golden schema v3; write `goldens.synthetic.json` |
| `Sources/cli-parity-gen/SyntheticFixtures.swift` *(new)* | per-capability synthetic fixture builders |
| `Sources/cli-parity-gen/FixtureClassifier.swift` *(new)* | classify real local fixtures via DICOMKit core |
| `Sources/cli-parity-gen/FixtureResolver.swift` *(new)* | deterministic capability-matched selection |
| `Sources/cli-parity-gen/templates.json` *(new, committed)* | flag-coverage scenario matrix |
| `Sources/DICOMStudio/Resources/CLIParity/synthetic/**` *(new, committed)* | materialized PHI-free fixtures |
| `Sources/DICOMStudio/Resources/CLIParity/CLIFixtureManifest.json` *(new, committed)* | capability manifest |
| `Sources/DICOMStudio/Resources/CLIParity/goldens.synthetic.json` *(new, committed)* | CI baseline goldens |
| `Sources/DICOMStudio/Components/StudioParityRunner.swift` *(new)* | headless per-scenario runner |
| `Sources/DICOMStudio/Components/CLIParityEngine.swift` | normalize pipeline + mask library + artifact comparators + dispatch |
| `Sources/DICOMStudio/Models/CLIAutomationTestingModel.swift` | extend `GoldenScenario` (+`stderr`, category, written-files, comparator) |
| `Sources/DICOMStudio/ViewModels/CLIAutomationTestingViewModel.swift` | delegate `compareOutput` to runner; handle `FIXTURE_DIR` |
| `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift` | upgrade status-banner drop; route artifact URLs to comparator |
| `Sources/DICOMStudio/Views/CLIAutomationTestingView.swift` | Output-Parity panel: status pills, filters, coverage ratio |
| `Tests/StudioParityTests/StudioParityTests.swift` *(new)* | sharded enumeration, JSONL emission, artifact normalizer, mock SCP/HTTP |
| `Tests/StudioParityTests/PACSConfig.swift` *(new)* | live-PACS endpoints from `$PARITY_PACS*` env (defaults: DCM4CHEE-2 `172.17.1.200`/`TEAMPACS`, DCM4CHEE-5 `172.17.1.111`/`DCM4CHEE`, port `11112`); seed/cleanup helpers; reachability gate |
| `Package.swift` | new `StudioParityTests` test target |
| `Scripts/cli-parity.sh` | `TIER2=1` gen→build→test→merge→report path |
| `Scripts/cli_parity_report.py` | `--studio-parity` JSONL → "Output Parity" sheet |
| `Scripts/cli_parity_gate.py` *(new)* | CI gate: fail on un-allowlisted DIFF/ERROR + coverage regression + PHI-absence assert |
| `.github/workflows/cli-parity.yml` *(new)* | sharded matrix + gate job |
| `Sources/DICOMKit/…UIDGenerator` + `Date()` sites | TEST-ONLY env-gated seed/clock hook (W4) |

---

## Appendix A — Full per-subcommand classification

Authoritative, derived from the dumped `--experimental-dump-help` contracts cross-referenced
with the `executeCommand()` switch. `Wired` = has a Studio reimplementation. `Det.` =
deterministic. `Flags` = real option/flag/positional count (excludes `help`/`version`).
`non` = non-deterministic (needs §4b masking or §6 seeding).

| Tool | Subcommand | Wired | Category | Det. | Flags | Fixture need / non-determinism |
|---|---|:--:|---|---|--:|---|
| dicom-3d | mpr | — | artifact | det | 11 | multi-frame-set, uniform-spacing |
|  | mip |  | artifact | det | 8 | multi-frame-set, uniform-spacing |
|  | minip |  | artifact | det | 8 | multi-frame-set, uniform-spacing |
|  | average |  | artifact | det | 7 | multi-frame-set, uniform-spacing |
|  | surface |  | artifact | det | 8 | multi-frame-set, uniform-spacing |
|  | volume |  | artifact | det | 7 | multi-frame-set · nd: ray-casting precision |
|  | export |  | artifact | det | 6 | multi-frame-set, uniform-spacing |
|  | encode-volume |  | artifact | det | 7 | multi-frame-set · nd: J2K encoder version |
|  | decode-volume |  | artifact | det | 4 | encapsulated-jp3d |
|  | inspect |  | stdout | det | 3 | encapsulated-jp3d |
|  | backends |  | stdout | det | 2 | none |
| dicom-ai | classify | — | broken | ? | 10 | nd: CoreML inference timing / GPU variance |
| dicom-anon | (root) | Y | artifact | **non** | 16 | single-frame, multiframe · nd: regenerateUIDs (random UIDs), audit-log Date() |
| dicom-archive | init | Y | stdout | det | 2 | nd: archive-creation timestamp (isoDate) |
|  | import |  | artifact | **non** | 5 | multi-file-set · nd: importDate timestamp |
|  | query |  | stdout | det | 7 | populated-archive |
|  | list |  | stdout | det | 3 | populated-archive |
|  | export |  | artifact | **non** | 5 | populated-archive · nd: file copy order |
|  | check |  | stdout | det | 3 | healthy + corrupted archive |
|  | stats |  | stdout | det | 2 | populated-archive |
| dicom-cloud | upload | — | broken | **non** | 12 | nd: network latency |
| dicom-compress | compress | Y | artifact | **non** | 8 | nd: codec encapsulation / quality / backend |
|  | decompress |  | artifact | **non** | 6 | nd: target transfer syntax encoding |
|  | info |  | stdout | det | 3 |  |
|  | batch |  | artifact | **non** | 10 | nd: file enumeration order + codec |
|  | backends |  | stdout | det | 2 |  |
| dicom-convert | (root) | Y | artifact | **non** | 14 | nd: JPEG encoding artifacts, windowing rounding |
| dicom-dcmdir | create | Y | artifact | det | 6 | nd: file enumeration order (both sorted) |
|  | validate |  | stdout | det | 3 |  |
|  | dump |  | stdout | det | 3 |  |
|  | update |  | not-wired | ? | 2 | (not wired in Studio) |
| dicom-diff | (root) | Y | stdout | det | 12 | single-frame, multiframe |
| dicom-dump | (root) | Y | stdout | det | 12 | single-frame, multiframe |
| dicom-echo | (root) | Y | network | **non** | 9 | nd: round-trip latency |
| dicom-export | single | Y | artifact | **non** | 11 | single-frame, multiframe · nd: JPEG/PNG encoder metadata |
|  | contact-sheet |  | artifact | **non** | 10 | multi-file-set · nd: font rendering, encoder metadata |
|  | animate |  | artifact | **non** | 11 | multiframe · nd: GIF palette optimization |
|  | bulk |  | artifact | **non** | 10 | multi-file-set · nd: encoder format |
| dicom-gateway | dicom-to-hl7 | — | stdout | det | 6 | single-file |
|  | hl7-to-dicom |  | artifact | det | 5 | hl7-v2-message · nd: UID/timestamp gen |
|  | dicom-to-fhir |  | stdout | det | 6 | single-file · nd: JSON key ordering |
|  | fhir-to-dicom |  | artifact | det | 5 | fhir-json-resource · nd: UID/timestamps |
|  | batch |  | artifact | det | 8 | multi-file-set · nd: file iteration order |
|  | listen |  | not-wired | **non** | 8 | nd: network listener scheduling |
|  | forward |  | not-wired | **non** | 8 | nd: forwarding latency |
| dicom-image | (root) | Y | artifact | **non** | 16 | single-frame · nd: Date() studyDate/Time, auto UIDs |
| dicom-info | (root) | Y | stdout | det | 8 | single-frame, multiframe |
| dicom-j2k | info | — | not-wired | det | 6 |  |
|  | validate |  | not-wired | det | 6 |  |
|  | transcode |  | not-wired | **non** | 9 | nd: lossy re-encoding boundaries |
|  | reduce |  | not-wired | **non** | 7 | nd: quality-layer truncation |
|  | roi |  | not-wired | det | 7 |  |
|  | benchmark |  | not-wired | **non** | 6 | nd: decode timings |
|  | compare |  | not-wired | det | 6 |  |
|  | completions |  | not-wired | det | 2 |  |
| dicom-jpip | fetch | — | artifact | **non** | 8 | nd: network latency |
|  | uri |  | stdout | det | 3 | jpip-referenced-transfer-syntax |
|  | serve |  | not-wired | **non** | 8 | nd: network listener scheduling |
|  | info |  | stdout | det | 4 | optional-jpip-file |
| dicom-json | (root) | Y | artifact | det | 14 | single-frame, multiframe · nd: key order (--no-sort-keys), float precision |
| dicom-measure | distance | — | stdout | det | 9 | single-frame |
|  | area |  | stdout | det | 9 | single-frame |
|  | angle |  | stdout | det | 10 | single-frame |
|  | roi |  | stdout | det | 13 | single-frame |
|  | hu |  | stdout | det | 10 | single-frame, ct-modality |
|  | pixel |  | stdout | det | 9 | single/multi-frame |
| dicom-merge | (root) | Y | artifact | **non** | 8 | multi-file-set, multiframe · nd: new SOP UID, input order |
| dicom-mpps | create | Y | network | **non** | 10 | nd: MPPS SOP UID from SCP |
|  | update |  | network | det | 10 |  |
| dicom-mwl | query | Y | network | **non** | 12 | nd: SPS result counts/ordering |
| dicom-pdf | (root) | Y | artifact | det | 16 | single-frame, encapsulated-pdf · nd: auto SOP UID |
| dicom-pixedit | (root) | Y | artifact | det | 11 | single-frame, has-overlay · nd: fresh SOP UID (excluded) |
| dicom-print | send | — | broken | **non** | 14 | nd: printer response timing |
| dicom-qr | query | Y | network | **non** | 28 | nd: query result counts/ordering |
|  | resume |  | network | **non** | 3 | nd: state file contents |
| dicom-query | (C-FIND) | Y | network | **non** | 17 | nd: PACS state, response ordering |
| dicom-report | (root) | — | stdout | det | 18 | sr-dicom · nd: HTML rendering, embed timestamps |
| dicom-retrieve | (C-MOVE/C-GET) | Y | network | **non** | 14 | nd: response timing, retrieved file ordering |
| dicom-script | run | Y | stdout | det | 6 |  |
|  | validate |  | stdout | det | 3 |  |
|  | template |  | stdout | det | 1 |  |
| dicom-send | (C-STORE) | Y | network | **non** | 13 | nd: enumeration order, negotiation, per-file timing |
| dicom-server | start | — | broken | **non** | 11 | nd: server startup / listener state |
| dicom-split | (root) | Y | artifact | **non** | 10 | multiframe, high-bit-depth · nd: new SOP UID per output |
| dicom-study | organize | Y | stdout | **non** | 5 | multi-file-set · nd: dict iteration order |
|  | summary |  | stdout | det | 3 | multi-file-set, single-frame |
|  | check |  | stdout | det | 4 | complete + incomplete study |
|  | stats |  | stdout | det | 3 | multi-file-set (varied modalities) |
|  | compare |  | stdout | det | 3 | identical + divergent studies |
| dicom-tags | (root) | Y | artifact | det | 11 | single-frame, multiframe (file-write mode) |
| dicom-uid | generate | Y | artifact | **non** | 5 | nd: random UIDs (seed in W4) |
|  | validate |  | stdout | det | 4 |  |
|  | lookup |  | stdout | det | 4 |  |
|  | regenerate |  | artifact | **non** | 6 | nd: new UIDs + export-map per run |
| dicom-validate | (root) | Y | stdout | det | 10 | single-frame, multiframe, has-overlay · nd: JSON timestamp/order |
| dicom-viewer | (root) | — | not-wired | **non** | 25 | nd: terminal rendering (permanently SKIPPED) |
| dicom-wado | query (QIDO-RS) | Y | network | **non** | 18 | mock QIDO-RS endpoints |
|  | retrieve (WADO-RS) |  | network | **non** | 17 | mock WADO-RS endpoints |
|  | retrieve (WADO-URI) |  | network | **non** | 16 | mock WADO-URI endpoint |
|  | store (STOW-RS) |  | network | **non** | 12 | mock STOW-RS endpoint |
|  | ups (UPS-RS) |  | network | **non** | 38 | mock UPS-RS endpoints (own milestone) |
| dicom-xml | (root) | Y | artifact | det | 11 | single-frame, multiframe · nd: --pretty whitespace |

---

## Appendix B — Local real-fixture corpus survey

PHI-free capability survey of `/Users/raster/Desktop/DICOM_Input/` (35 `.dcm` files), produced
by parsing structural tags only (transfer syntax, modality, frames, bit depth, dimensions) with
the project's own `dicom-info`. **No patient identifiers were read or recorded.** This is the
table the planned `FixtureClassifier` will regenerate automatically.

| File | Mod | Transfer syntax | Frames | Bits | Dims | Size | Capabilities |
|---|---|---|--:|--:|---|--:|---|
| CT.dcm | CT | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| CT/CT_01_…Thorax_Covid_0007-0036.dcm | CT | explicit-le | 1 | 16 | 512×555 | 559KB | single-frame, high-bit-depth |
| CT/CT_02_…Abd_Triple_0018-0189.dcm | CT | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| CT/CT_03_…Thorax_Covid_0002-0457.dcm | CT | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| CT/CT_04_…Thorax_Covid_0002-0160.dcm | CT | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| CT/CT_05_…Abd_Triple_0006-0141.dcm | CT | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| DX/DX_01_…Chest_Pa_0005-0001.dcm | DX | implicit-le | 1 | 16 | 2288×2800 | 12525KB | single-frame, high-bit-depth |
| DX/DX_02_…Dl_Spine_0002-0001-0002.dcm | DX | implicit-le | 1 | 16 | 3056×2544 | 15236KB | single-frame, high-bit-depth |
| DX/DX_03_…Dl_Spine_0001-0001-0001.dcm | DX | implicit-le | 1 | 16 | 3056×2544 | 15236KB | single-frame, high-bit-depth |
| DX/DX_04_…Chest_Pa_0005-0001.dcm | DX | implicit-le | 1 | 16 | 2288×2800 | 12525KB | single-frame, high-bit-depth |
| DX/DX_05_…BL_Knee_0008-0001.dcm | DX | implicit-le | 1 | 16 | 2337×2848 | 13012KB | single-frame, high-bit-depth |
| MG/MG_01_…Mammogram_0012-0001.dcm | CR | implicit-le | 1 | 16 | 4784×3517 | 32881KB | single-frame, high-bit-depth |
| MG/MG_02_…Mammogram_0011-0001.dcm | CR | implicit-le | 1 | 16 | 4784×3520 | 32909KB | single-frame, high-bit-depth |
| MG/MG_03_…Mammogram_0018-0001.dcm | CR | **jpls-lossless** | 1 | 16 | 4784×3521 | 12537KB | single-frame, high-bit-depth, compressed |
| MG/MG_04_…Mammogram_0035-0001.dcm | CR | implicit-le | 1 | 16 | 4784×3520 | 32910KB | single-frame, high-bit-depth |
| MG/MG_05_…Mammogram_0020-0001.dcm | CR | **jpls-lossless** | 1 | 16 | 4784×3518 | 13177KB | single-frame, high-bit-depth, compressed |
| MR/MR_01_…Head_Dot_0168-0001.dcm | MR | implicit-le | 1 | 16 | 384×384 | 389KB | single-frame, high-bit-depth |
| MR/MR_02_…Head_Dot_0051-0484.dcm | **CT** | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| MR/MR_03_…Head_Dot_0053-0194.dcm | **CT** | explicit-le | 1 | 16 | 531×512 | 535KB | single-frame, high-bit-depth |
| MR/MR_04_…Head_Dot_0059-1620.dcm | **CT** | explicit-le | 1 | 16 | 512×512 | 516KB | single-frame, high-bit-depth |
| MR/MR_05_…Head_Dot_0153-0015.dcm | MR | implicit-le | 1 | 16 | 320×270 | 281KB | single-frame, high-bit-depth |
| PX/PX_01_…0001-0001.dcm | PX | implicit-le | 1 | 16 | 1316×2793 | 7216KB | single-frame, high-bit-depth |
| PX/PX_02_…0001-0001.dcm | PX | implicit-le | 1 | 16 | 1316×2794 | 7219KB | single-frame, high-bit-depth |
| PX/PX_03_…0001-0001-0001.dcm | PX | implicit-le | 1 | 16 | 1316×2812 | 7265KB | single-frame, high-bit-depth |
| PX/PX_04_…0001-0001.dcm | PX | **jpeg-ll-sv1** | 1 | 16 | 1116×2155 | 2301KB | single-frame, high-bit-depth, compressed |
| PX/PX_05_…0001-0001.dcm | PX | **jpls-lossless** | 1 | 16 | 1316×2459 | 2593KB | single-frame, high-bit-depth, compressed |
| US/US_01_…0001-0094-0001.dcm | US | **jpeg-baseline** | **92** | 8 | 758×1016 | 9913KB | multiframe, compressed |
| US/US_02_…0007-0121-0002.dcm | US | **jpeg-baseline** | **92** | 8 | 758×1016 | 10428KB | multiframe, compressed |
| US/US_04_…0009-0018.dcm | US | **jpeg-baseline** | 1 | 8 | 758×1016 | 134KB | single-frame, compressed |
| US/US_05_…0007-0085.dcm | US | **jpeg-baseline** | **76** | 8 | 758×1016 | 9880KB | multiframe, compressed |
| XA/XA_01_…Card_Sks_0451-0040.dcm | XA | implicit-le | **40** | 8 | 512×512 | 10245KB | multiframe |
| XA/XA_02_…Card_Sks_0389-0030.dcm | XA | implicit-le | **30** | 8 | 512×512 | 7685KB | multiframe |
| XA/XA_03_…Card_Sks_0442-0059.dcm | XA | implicit-le | **59** | 8 | 512×512 | 15109KB | multiframe |
| XA/XA_04_…0667-0001.dcm | XA | implicit-le | 1 | 16 | 1024×1024 | 2082KB | single-frame, high-bit-depth |
| XA/XA_05_…0155-0001.dcm | XA | implicit-le | 1 | 16 | 1024×1024 | 2082KB | single-frame, high-bit-depth |

**Rollup:** modalities CT 9 (incl. 3 mislabeled in `MR/`), CR 5, DX 5, MR 2, PX 5, US 4, XA 5 ·
transfer syntaxes implicit-le 18, explicit-le 9, jpeg-baseline 4, jpeg-ls-lossless 3,
jpeg-lossless-sv1 1 · **6 multiframe** (US 76–92f, XA 30–59f) · **0 overlay / SR / encap-PDF /
RTSTRUCT / JPEG-2000** → those capabilities are **synthetic-only**.

---

## See also

- `Scripts/CLI-PARITY-README.md` — Tier 1 (input-contract) harness, already shipped.
- `Sources/cli-parity-gen/main.swift` — golden generator (the Tier-2 skeleton to extend).
- `Sources/DICOMStudio/Components/CLIParityEngine.swift` — `normalize()` / `diff()` engine.
- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift` — the 32-case `executeCommand()`
  switch (the Studio reimplementations under test).
