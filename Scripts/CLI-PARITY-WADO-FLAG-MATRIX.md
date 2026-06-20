# dicom-wado — Per-Flag / Flag-Combination Parity Test Matrix

> **Purpose.** Reference for automating CLI-parity tests of every `dicom-wado`
> subcommand, flag-by-flag and in valid combinations. Each row is one parity
> scenario: the app (CLI Workshop reimplementation) and the real `dicom-wado`
> binary run the **same** argv against the **same** live DICOMweb endpoint, and
> the harness compares the result semantically.
>
> **Source of truth.** Every flag, default, dependency, and mutual-exclusion
> below was extracted from [`Sources/dicom-wado/DICOMWado.swift`](../Sources/dicom-wado/DICOMWado.swift)
> and independently re-verified against source (audit run 2026-06-20). When the
> CLI changes, re-audit and update this file.
>
> Related: [CLI-PARITY-README.md](CLI-PARITY-README.md) ·
> [APP_CLI_NETWORK_PARITY.md](../APP_CLI_NETWORK_PARITY.md) ·
> tests in [`Tests/DICOMStudioTests/CLIParityWADOParityTests.swift`](../Tests/DICOMStudioTests/CLIParityWADOParityTests.swift)

---

## 1. The bottom line — can automation run on MANDATORY inputs only?

**Yes.** With just **two mandatory inputs** the harness can run ~30 scenarios
fully unattended. Optional inputs only *unlock more* scenarios; they are never
required to get a meaningful run.

| Input token | Meaning | Mandatory? | Unlocks |
|---|---|---|---|
| `WEBURL` | DICOMweb base URL (WADO-RS/QIDO/STOW/UPS) | **Yes** | all query, store, ups search/create scenarios |
| `STUDY` | Study Instance UID | **Yes** (for any `retrieve`) | all retrieve scenarios + scoped query |
| `SERIES` | Series Instance UID | Optional | series-level retrieve/query, + a precondition for rendered/frames/uri/instance |
| `INSTANCE` | SOP Instance UID | Optional | instance-level retrieve/query, rendered, frames, uri |
| `SENDFILE` | DICOM file(s) for store | Optional — **bundled `syn-ct.dcm` fallback** | nothing extra; store always runs |
| `URIURL` | Legacy WADO-URI endpoint (from UI) | Optional | `retrieve --uri` scenarios |
| `AET` | Local AE Title (from UI) | Optional | `ups --subscribe/--unsubscribe`, lifecycle `--update` |
| `WORKITEM_UID` | Existing workitem UID (from UI) | Optional | `ups --get` |
| `STATION` | Scheduled station name (from UI) | Optional | `ups --search --scheduled-station` |

> **Per the project plan**, `URIURL`, `SENDFILE` (DICOM files), `AET`,
> `WORKITEM_UID`, and `STATION` are surfaced as **editable UI fields** on the
> CLI-Parity screen (same pattern as the existing `WEBURL`/`SENDFILE` tokens).
> The runner substitutes them at run time; a scenario whose required token is
> blank is simply **not generated** (gated), exactly like the current
> `retrieve-series` / `ups-lifecycle` gating.

**Coverage by input level**

| Inputs available | retrieve | query | store | ups | Total |
|---|---:|---:|---:|---:|---:|
| `WEBURL` only | 0 | 9 | 6 | 17 | **32** |
| `+ STUDY` | 5 | +3 | +1 | +1 | +10 |
| `+ SERIES` | +4 | +1 | — | — | +5 |
| `+ INSTANCE` | +8 | — | — | — | +8 |
| `+ URIURL` (UI) | +4 | — | — | — | +4 |
| `+ AET` (UI) | — | — | — | +4 | +4 |
| `+ WORKITEM_UID` (UI) | — | — | — | +1 | +1 |

---

## 2. Critical cross-cutting semantics (read before writing scenarios)

These come straight from the source and **change how scenarios must be built**:

1. **`retrieve` modes are mutually exclusive by *precedence*, not by the parser.**
   `run()` is an `if / else-if` chain in this exact priority order:
   `--metadata` → `--rendered` → `--thumbnail` → `--frames` → *(default: download instances)*.
   If you pass two mode flags, only the **highest-priority** one runs and the
   rest are **silently ignored**. → **Every retrieve scenario must set exactly one mode.**

2. **`--uri` short-circuits everything.** When set, `run()` calls the WADO-URI
   path and returns *before* the WADO-RS chain. So `--metadata/--rendered/--thumbnail`
   are ignored under `--uri`; `--content-type` is honored **only** under `--uri`;
   `--format`/`--timeout` are ignored under `--uri`; `--frames` keeps only the
   **first** frame number.

3. **`ups` operations are mutually exclusive by precedence too:**
   `--search` → `--get` → `--create` → `--create-workitem` → `--update` →
   `--subscribe` → `--unsubscribe`. First match wins; passing none throws
   *"Specify an operation…"*. → **Every ups scenario must set exactly one selector.**

4. **`retrieve --timeout` is currently UNWIRED (dead option).** It is declared
   and parsed but never passed to the client/config — it has **no runtime
   effect**. A scenario can confirm it parses without error, but must **not**
   assert any behavioral difference. *(Flagged as a real finding; remove this
   note once it's wired.)*

5. **Two different `--format` enums:**
   - `retrieve --format` = `MetadataFormat` → **`json | xml`**, default `json`,
     **only consulted in `--metadata` mode**, no effect elsewhere.
   - `query`/`ups --format` = `OutputFormat` → **`table | json | csv`**, default `table`.

6. **`--format xml` on `retrieve --metadata` is now implemented** (this change):
   single instance → one `<NativeDicomModel>` (PS3.19 Native DICOM Model via the
   shared `DICOMXMLEncoder`); multiple → wrapped in `<NativeDicomModelList>`.

7. **UPS state transitions:** `--transaction-uid` is **auto-generated** for
   `IN_PROGRESS`, but **required** for `COMPLETED`/`CANCELED` (use the UID
   returned by the IN_PROGRESS transition). `--update` requires `--state`.

8. **`store` has no short flags** — every option/flag is `--long` only.

---

## 3. Subcommand: `retrieve` (WADO-RS / WADO-URI)

Positional: `baseURL` (required). **`--study` is mandatory at runtime for every
mode** (`guard let studyUID = study` throws *"--study is required for retrieve
operations"*).

### 3.1 Flag inventory

| Flag | Short | Kind | Type / values | Default | Notes |
|---|---|---|---|---|---|
| `--study` | | option | String | — | **Required (runtime guard).** |
| `--series` | | option | String | — | Required for uri/rendered/frames; selects series/instance granularity. |
| `--instance` | | option | String | — | Required (with `--series`) for uri/rendered/frames/instance-level. |
| `--frames` | | option | `1,2,3…` | — | Mode selector. WADO-URI uses **first** number only. Each must be a positive Int. |
| `--uri` | | flag | Bool | `false` | Switch to WADO-URI; short-circuits WADO-RS chain. |
| `--content-type` | | option | `application/dicom`, `image/jpeg`, `image/png`, `image/gif`, `image/jp2`, `image/jph`, `image/jphc`, `video/mpeg` | `application/dicom` | **WADO-URI only.** Sets saved-file extension. |
| `--metadata` | | flag | Bool | `false` | Mode (priority 1). Honors `--format json\|xml`. |
| `--rendered` | | flag | Bool | `false` | Mode (priority 2). **Needs `--series` + `--instance`.** |
| `--thumbnail` | | flag | Bool | `false` | Mode (priority 3). Study/series/instance level by which UIDs are present. |
| `--output` | `-o` | option | dir path | cwd | Created if missing. |
| `--token` | | option | String | — | OAuth2 bearer. |
| `--format` | `-f` | option | `json \| xml` (`MetadataFormat`) | `json` | **Only affects `--metadata`.** |
| `--timeout` | | option | Int (sec) | `60` | ⚠️ **Unwired — no runtime effect.** |
| `--verbose` | | flag | Bool | `false` | Diagnostics only; never changes what's retrieved. |

### 3.2 Dependency / mutual-exclusion rules

- **Mutex (modes):** exactly one of `--metadata` / `--rendered` / `--thumbnail` / `--frames` / *(default)*.
- **Mutex (protocol):** `--uri` vs all WADO-RS modes.
- `--uri` **requires** `--series` **and** `--instance` (else ValidationError).
- `--rendered` **requires** `--series` **and** `--instance`.
- `--frames` **requires** `--series` **and** `--instance`.
- `--metadata` / `--thumbnail` / default: instance-level only when **both** `--series` + `--instance` present (otherwise degrade to series/study — no error).

### 3.3 Test matrix

> Argv shown is everything **after** `dicom-wado retrieve`. All carry `WEBURL`
> + `--study STUDY` (+ `-o OUTDIR` for binary modes).

| Scenario ID | Flags under test | Argv | Required inputs | Assert |
|---|---|---|---|---|
| `retrieve-study` | default instances, study | `WEBURL --study STUDY -o OUTDIR` | WEBURL, STUDY | instance count |
| `retrieve-series` | series level | `WEBURL --study STUDY --series SERIES -o OUTDIR` | + SERIES | instance count |
| `retrieve-instance` | instance level | `WEBURL --study STUDY --series SERIES --instance INSTANCE -o OUTDIR` | + INSTANCE | instance count (1) |
| `retrieve-meta-study-json` | `--metadata --format json` | `WEBURL --study STUDY --metadata --format json` | WEBURL, STUDY | metadata obj count |
| `retrieve-meta-study-xml` | `--metadata --format xml` ⭐ | `WEBURL --study STUDY --metadata --format xml` | WEBURL, STUDY | `<NativeDicomModel>` count |
| `retrieve-meta-series` | series metadata | `WEBURL --study STUDY --series SERIES --metadata` | + SERIES | metadata obj count |
| `retrieve-meta-instance-json` | instance metadata json | `WEBURL --study STUDY --series SERIES --instance INSTANCE --metadata --format json` | + INSTANCE | obj count (1) |
| `retrieve-meta-instance-xml` | instance metadata xml ⭐ | `… --metadata --format xml` | + INSTANCE | model count (1) |
| `retrieve-thumb-study` | `--thumbnail` study | `WEBURL --study STUDY --thumbnail -o OUTDIR` | WEBURL, STUDY | success + bytes>0 |
| `retrieve-thumb-series` | `--thumbnail` series | `… --series SERIES --thumbnail -o OUTDIR` | + SERIES | success |
| `retrieve-thumb-instance` | `--thumbnail` instance | `… --series SERIES --instance INSTANCE --thumbnail -o OUTDIR` | + INSTANCE | success |
| `retrieve-rendered` | `--rendered` | `WEBURL --study STUDY --series SERIES --instance INSTANCE --rendered -o OUTDIR` | + INSTANCE | success + bytes>0 |
| `retrieve-frames` | `--frames 1` | `… --series SERIES --instance INSTANCE --frames 1 -o OUTDIR` | + INSTANCE | frame count |
| `retrieve-verbose` | `--verbose` (non-breaking) | `WEBURL --study STUDY --verbose -o OUTDIR` | WEBURL, STUDY | == `retrieve-study` |
| `retrieve-timeout` | `--timeout 30` (parse-only ⚠️) | `WEBURL --study STUDY --timeout 30 -o OUTDIR` | WEBURL, STUDY | parses OK; == baseline |
| `retrieve-token` | `--token` | `WEBURL --study STUDY --token TOKEN -o OUTDIR` | + TOKEN | success (gated) |
| `retrieve-uri-dicom` | `--uri` default | `URIURL --uri --study STUDY --series SERIES --instance INSTANCE -o OUTDIR` | URIURL, SERIES, INSTANCE | bytes>0, `.dcm` |
| `retrieve-uri-jpeg` | `--uri --content-type image/jpeg` | `URIURL --uri … --content-type image/jpeg -o OUTDIR` | URIURL, SERIES, INSTANCE | bytes>0, `.jpg` |
| `retrieve-uri-png` | `--content-type image/png` | `URIURL --uri … --content-type image/png -o OUTDIR` | URIURL, SERIES, INSTANCE | bytes>0, `.png` |
| `retrieve-uri-frame` | `--uri --frames 1` (first only) | `URIURL --uri … --frames 1 -o OUTDIR` | URIURL, SERIES, INSTANCE | bytes>0 |

⭐ = newly enabled by the `--format xml` fix.

---

## 4. Subcommand: `query` (QIDO-RS)

Positional: `baseURL` (required). **No filter is mandatory** — `run()` has no
throwing guards; every scenario runs on `WEBURL` alone.

### 4.1 Flag inventory

| Flag | Short | Kind | Type / values | Default |
|---|---|---|---|---|
| `--level` | | option | `study \| series \| instance` | `study` |
| `--patient-name` | | option | String (wildcards `*?`) | — |
| `--patient-id` | | option | String | — |
| `--study-date` | | option | `YYYYMMDD` or range | — |
| `--study` | | option | String (UID) | — |
| `--series` | | option | String (UID) | — |
| `--accession-number` | | option | String | — |
| `--modality` | | option | String (CT, MR…) | — |
| `--study-description` | | option | String | — |
| `--limit` | | option | Int | `100` |
| `--offset` | | option | Int | `0` |
| `--token` | | option | String | — |
| `--format` | `-f` | option | `table \| json \| csv` (`OutputFormat`) | `table` |
| `--verbose` | | flag | Bool | `false` |

- **Mutex/scoping:** `--level` is one-of-three; `--study`/`--series` scope the
  series/instance levels (used together at instance level). All filters are
  additive and independent.

### 4.2 Test matrix (argv after `dicom-wado query`)

| Scenario ID | Flags under test | Argv | Required inputs | Assert |
|---|---|---|---|---|
| `query-study-table` | default | `WEBURL` | WEBURL | table row count |
| `query-study-json` | `--format json` | `WEBURL --format json` | WEBURL | JSON result count |
| `query-study-csv` | `--format csv` | `WEBURL --format csv` | WEBURL | CSV rows−header |
| `query-series-all` | `--level series` | `WEBURL --level series` | WEBURL | count |
| `query-series-json` | `--level series --format json` | `WEBURL --level series --format json` | WEBURL | count |
| `query-instance-all` | `--level instance` | `WEBURL --level instance` | WEBURL | count |
| `query-limit` | `--limit 5` | `WEBURL --limit 5` | WEBURL | count ≤ 5 |
| `query-offset` | `--limit 5 --offset 5` | `WEBURL --limit 5 --offset 5` | WEBURL | count |
| `query-verbose` | `--verbose` | `WEBURL --verbose` | WEBURL | == baseline |
| `query-patient-name` | `--patient-name` | `WEBURL --patient-name 'DOE*'` | filter value | result set |
| `query-patient-id` | `--patient-id` | `WEBURL --patient-id PID` | filter value | result set |
| `query-study-date` | `--study-date` | `WEBURL --study-date 20240101-20241231` | filter value | result set |
| `query-accession` | `--accession-number` | `WEBURL --accession-number ACC` | filter value | result set |
| `query-modality` | `--modality` | `WEBURL --modality CT` | filter value | result set |
| `query-study-desc` | `--study-description` | `WEBURL --study-description CHEST` | filter value | result set |
| `query-combined` | ≥2 filters | `WEBURL --patient-name 'DOE*' --modality CT` | filter values | result set |
| `query-token` | `--token` | `WEBURL --token TOKEN` | + TOKEN | success (gated) |
| `query-series-scoped` | `--level series --study` | `WEBURL --level series --study STUDY` | + STUDY | count |
| `query-instance-by-study` | `--level instance --study` | `WEBURL --level instance --study STUDY` | + STUDY | count |
| `query-instance-by-series` | `--level instance --study --series` | `WEBURL --level instance --study STUDY --series SERIES` | + STUDY, SERIES | count |

> Filter-value scenarios are **gated** on the user supplying that filter on the
> screen (matches existing `QueryFilters` gating). With `WEBURL` alone, the 9
> always-on rows run.

---

## 5. Subcommand: `store` (STOW-RS)

Positional: `baseURL` (required) + `files…` (repeatable, optional). **Runtime
guard:** at least one of `files` or `--input` must resolve to a non-empty list,
else *"No files specified…"*. The harness resolves `SENDFILE` to the user-picked
DICOM file(s) or the bundled `syn-ct.dcm`, so store always runs. **No short flags.**

### 5.1 Flag inventory

| Flag | Kind | Type | Default |
|---|---|---|---|
| `files…` (positional) | argument | [String] | `[]` |
| `--study` | option | String | — |
| `--input` | option | path (file list, one per line, `#` comments) | — |
| `--batch` | option | Int | `10` |
| `--token` | option | String | — |
| `--continue-on-error` | flag | Bool | `false` |
| `--verbose` | flag | Bool | `false` |

### 5.2 Test matrix (argv after `dicom-wado store`)

| Scenario ID | Flags under test | Argv | Required inputs | Assert |
|---|---|---|---|---|
| `store-default` | baseline upload | `WEBURL SENDFILE` | WEBURL (SENDFILE fallback) | sent/succeeded/failed |
| `store-verbose` | `--verbose` | `WEBURL SENDFILE --verbose` | WEBURL | == baseline |
| `store-batch-1` | `--batch 1` | `WEBURL SENDFILE --batch 1` | WEBURL | == baseline |
| `store-batch-5` | `--batch 5` | `WEBURL SENDFILE --batch 5` | WEBURL | == baseline |
| `store-continue-on-error` | `--continue-on-error` | `WEBURL SENDFILE --continue-on-error` | WEBURL | summary OK |
| `store-input-list` | `--input` | `WEBURL --input FILELIST` | WEBURL (harness writes FILELIST→SENDFILE) | == baseline |
| `store-study-targeted` | `--study` | `WEBURL SENDFILE --study STUDY` | + STUDY | summary OK |
| `store-token` | `--token` | `WEBURL SENDFILE --token TOKEN` | + TOKEN | success (gated) |

---

## 6. Subcommand: `ups` (UPS-RS Worklist)

Positional: `baseURL` (required). **Exactly one operation selector** must be set
(`--search`/`--get`/`--create`/`--create-workitem`/`--update`/`--subscribe`/`--unsubscribe`),
else *"Specify an operation…"*. Selectors are mutually exclusive by precedence.

### 6.1 Flag inventory (grouped)

**Operation selectors**

| Flag | Kind | Type | Requires |
|---|---|---|---|
| `--search` | flag | Bool | — |
| `--get` | option | UID | — |
| `--create` | option | JSON file path | — |
| `--create-workitem` | flag | Bool | **`--label`** |
| `--update` | option | UID | **`--state`** |
| `--subscribe` | flag | Bool | **`--aet`** |
| `--unsubscribe` | flag | Bool | **`--aet`** |

**Search filters** — `--filter-state` (`SCHEDULED \| IN_PROGRESS \| COMPLETED \| CANCELED`, case-insensitive), `--scheduled-station`.

**State change** — `--state` (same enum), `--transaction-uid` (auto for `IN_PROGRESS`; **required** for `COMPLETED`/`CANCELED`), `--aet`.

**Create-workitem attributes** (all optional except `--label`): `--workitem-uid` (auto if omitted), `--label` *(required)*, `--patient-name`, `--patient-id`, `--priority` (`STAT\|HIGH\|MEDIUM\|LOW`, default MEDIUM), `--patient-birth-date` (YYYYMMDD), `--patient-sex` (`M\|F\|O`), `--study-uid`, `--accession-number`, `--referring-physician`, `--procedure-id`, `--step-id`, `--worklist-label`, `--comments`, `--scheduled-start` (ISO 8601), `--expected-completion` (ISO 8601), `--station-name`, `--performer-name`, `--performer-organization`, `--admission-id`.

**Common** — `--token`, `--format` (`table\|json\|csv`, default table), `--verbose`.

### 6.2 Test matrix (argv after `dicom-wado ups`)

| Scenario ID | Flags under test | Argv | Required inputs | Assert |
|---|---|---|---|---|
| `ups-search-all` | `--search` | `WEBURL --search` | WEBURL | workitem count |
| `ups-search-scheduled` | `--filter-state SCHEDULED` | `WEBURL --search --filter-state SCHEDULED` | WEBURL | count |
| `ups-search-in-progress` | `--filter-state IN_PROGRESS` | `WEBURL --search --filter-state IN_PROGRESS` | WEBURL | count |
| `ups-search-completed` | `--filter-state COMPLETED` | `WEBURL --search --filter-state COMPLETED` | WEBURL | count |
| `ups-search-canceled` | `--filter-state CANCELED` | `WEBURL --search --filter-state CANCELED` | WEBURL | count |
| `ups-search-json` | `--format json` | `WEBURL --search --format json` | WEBURL | count |
| `ups-search-csv` | `--format csv` | `WEBURL --search --format csv` | WEBURL | rows−header |
| `ups-search-verbose` | `--verbose` | `WEBURL --search --verbose` | WEBURL | == baseline |
| `ups-search-station` | `--scheduled-station` | `WEBURL --search --scheduled-station STATION` | + STATION | count (gated) |
| `ups-create-basic` | `--create-workitem --label` | `WEBURL --create-workitem --label 'Auto Test'` | WEBURL | create OK (ignore UID) |
| `ups-create-priority` | `+ --priority HIGH` | `WEBURL --create-workitem --label 'Auto Test' --priority HIGH` | WEBURL | create OK |
| `ups-create-patient` | `+ --patient-name/id` | `… --patient-name 'Doe^Jane' --patient-id PAT001` | WEBURL | create OK |
| `ups-create-demographics` | `+ --patient-sex/-birth-date` | `… --patient-sex F --patient-birth-date 19800101` | WEBURL | create OK |
| `ups-create-scheduled` | `+ --scheduled-start/--expected-completion` | `… --scheduled-start 2026-12-01T10:00:00 --expected-completion 2026-12-01T11:00:00` | WEBURL | create OK |
| `ups-create-study-ref` | `+ --study-uid/--accession-number/--referring-physician` | `… --study-uid STUDY --accession-number ACC --referring-physician 'Dr^Smith'` | WEBURL (STUDY optional) | create OK |
| `ups-create-procedure-ids` | `+ --procedure-id/--step-id/--worklist-label/--comments` | `… --procedure-id RP1 --step-id SPS1 --worklist-label WL --comments 'note'` | WEBURL | create OK |
| `ups-create-performer-station` | `+ --station-name/--performer-name/--performer-organization/--admission-id` | `… --station-name CT01 --performer-name 'Tech^A' --performer-organization Radiology --admission-id ADM1` | WEBURL | create OK |
| `ups-lifecycle` | create→IN_PROGRESS→COMPLETED | composite (3 calls, AET + auto-TX) | + AET | createOK ∧ claimOK ∧ finalState=COMPLETED |
| `ups-subscribe-global` | `--subscribe --aet` | `WEBURL --subscribe --aet AET` | + AET | success |
| `ups-subscribe-workitem` | `--subscribe --workitem-uid --aet` | `WEBURL --subscribe --workitem-uid UID --aet AET` | + AET (+ UID) | success |
| `ups-unsubscribe` | `--unsubscribe --aet` | `WEBURL --unsubscribe --aet AET` | + AET | success |
| `ups-get` | `--get` | `WEBURL --get WORKITEM_UID` | + WORKITEM_UID | JSON of item (gated) |
| `ups-create-json` | `--create` | `WEBURL --create worklist.json` | WEBURL (harness synth JSON) | create OK |

> **Lifecycle is self-contained:** it creates its own workitem, so it needs no
> pre-existing UID — only `AET`. The comparator ignores client-minted UIDs and
> checks the outcome (`createOK ∧ claimOK ∧ finalState`).

---

## 7. Comparators (what "parity" asserts per scenario)

| Mode | Reduce CLI output to | Compare on |
|---|---|---|
| query (json) | parsed result set → sorted `key=value;…` | order-independent set match |
| query (csv/table) | row count (minus header / minus borders) | count |
| retrieve (instances/series/study) | instance count | count |
| retrieve (metadata json) | object count in `[…]` | count |
| retrieve (metadata xml) ⭐ | `<NativeDicomModel>` count | count |
| retrieve (rendered/thumbnail/frames) | success + byte length > 0 | success/count |
| store | `sent / succeeded / failed` summary | tuple + `overallOK` |
| ups search | workitem count + sorted UIDs | count (UID set) |
| ups create / lifecycle | `createOK / claimOK / finalState` (UID-agnostic) | outcome |

`--verbose`, `--timeout`, `--batch`, `--token`, `--continue-on-error` are
**non-breaking** modifiers: assert the scenario yields the **same** semantic
record as its baseline (the flag must not alter the outcome).

---

## 8. What still needs manual / extra setup

| Case | Subcommand | Why | Mitigation |
|---|---|---|---|
| `--uri` family | retrieve | Needs a legacy WADO-URI endpoint distinct from WADO-RS | UI field `URIURL`; gated |
| `--get <uid>` | ups | Needs a pre-existing workitem UID on the server | UI field `WORKITEM_UID`; gated |
| `--input <filelist>` | store | Needs a file-list file | Harness synthesizes a temp list pointing at `SENDFILE` |
| `--timeout` | retrieve | ⚠️ Unwired in source — cannot assert behavior | Parse-only check until wired |

Everything else is fully automatable from `WEBURL` + `STUDY` (+ optional
`SERIES`/`INSTANCE` to widen coverage).

---

## 9. Implementation checklist (harness side)

1. Add scope fields: `wadoURIURL`, `upsAET`, `upsWorkitemUID`, `upsScheduledStation`
   (the DICOM-file path / `SENDFILE` already exists).
2. Generate the scenarios above in `CLIParityNetworkScenarios` — group as
   `wadoRetrieveScenarios`, `wadoQueryScenarios`, `wadoStoreScenarios`,
   `wadoUPSScenarios`; gate each on its required token(s).
3. Extend `CLIParityWADOComparator` for: metadata-XML count (`<NativeDicomModel>`),
   ups create/lifecycle outcome, ups search csv/table counts.
4. Mirror the `--format xml` metadata path in the app's CLI-Workshop
   reimplementation so the XML scenarios show **Pass**, not DIFFERS
   *(the reference must reflect the app + the same shared API/pipeline)*.
5. Add guard tests in `CLIParityWADOParityTests`: unique scenario IDs; every
   retrieve scenario carries `--study`; every ups scenario carries exactly one
   selector; a completeness test that cross-references `--experimental-dump-help`
   so any newly-added flag surfaces as uncovered.

---

*Generated 2026-06-20 from a source-verified audit of `Sources/dicom-wado/DICOMWado.swift`
(all four subcommand inventories independently re-verified; ⭐ rows enabled by the
`--format xml` implementation in the same change).*
