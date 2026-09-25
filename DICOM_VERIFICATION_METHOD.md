# Verifying DICOMKit code against the DICOM standard

This is the method used to verify DICOMCore against DICOM 2026a (2026-09-24 to 2026-09-25; see
[DICOMCORE_STANDARD_IMPLEMENTATION.md](DICOMCORE_STANDARD_IMPLEMENTATION.md)). Use it unchanged for
every other module (DICOMDictionary, DICOMKit, DICOMNetwork, DICOMWeb, DICOMPrintKit,
DICOMRenderKit, DICOMToolbox, the CLI tools and DICOMStudio), and again for DICOMCore when the target
edition moves.

**Target edition:** DICOM **2026a** (`dicomStandardEdition = "2026a"`, [DICOMKit.swift](Sources/DICOMKit/DICOMKit.swift)).

**Principle:** code is checked against the frozen NEMA text, row by row, by script. Doc-comment
labels, README claims, internal consistency and memory are not evidence. A shared wrong assumption
passes every consistency check, and only a comparison with the standard catches it.

---

## 1. Policy: which edition a file is checked against

| The file cites… | Verify against | Then |
|---|---|---|
| An edition **later** than the target (e.g. 2026d) | That edition's NEMA text | Keep the citation once it is confirmed. It is a candidate for the next target edition. |
| An edition **earlier** than the target (e.g. 2024d), or a Sup/CP | The target edition, plus the release notes from the originating edition up to the target | Keep the old citation as provenance. The marker names the target edition. |
| The target edition, or nothing | The target edition | Mark it verified against the target. |

When DICOMKit moves to a newer target edition, run the whole procedure again against that edition.

## 2. Sources

- **Standard text.** `https://dicom.nema.org/medical/dicom/<edition>/source/docbook/partNN/partNN.xml`,
  e.g. `/2026a/`. Always use the **frozen** edition directory, and confirm the document subtitle names
  that edition (`Scripts/nema_docbook.py fetch` does this).
  - `/current/` is a rolling alias (it was 2026d on 2026-09-24). Use it only for a claim that cites a
    later edition, and confirm its subtitle.
  - As of 2026-09-24 NEMA publishes no frozen `/2026d/` DocBook (that directory only links to
    `/current/`), so 2026d claims are checked against `/current/` with its subtitle confirmed.
  - Strip zero-width spaces (U+200B) before comparing keywords, UIDs or codes. The scripts do this.
- **Release notes**, to date a CP or Supplement or to see what changed between editions: the mirror
  `celeron533/DICOM-Release-Notes` (`downloaded/releasenotes_<edition>.xml`, 2014a onwards), or NEMA's
  `/current/source/docbook/releasenotes/` for the newest one. Search for `xml:id="cp_NNNN"` or `sup_NNN`.
  Anything older than 2014a can only be dated "before 2014a".
  `gh api repos/celeron533/DICOM-Release-Notes/contents/downloaded/releasenotes_<ed>.xml --jq .content | base64 -d`
- **External terminologies** used by PS3.16 (SNOMED CT, LOINC, UCUM, RadLex, NCIt): check codes against
  the code lists that PS3.16 itself uses (its CID tables and Annex D). Say so in the marker when a code
  cannot be verified from NEMA text.
- **Vendor private dictionaries** (not in NEMA): compare with DCMTK `private.dic` and GDCM, and say so.

Which part holds what: PS3.3 IODs, modules and attribute semantics · PS3.5 encoding, VRs, transfer
syntax rules · PS3.6 data dictionary and UID registry · PS3.7/3.8 networking · PS3.10/3.11 files and
media · PS3.15 profiles · PS3.16 templates, context groups and codes · PS3.17 explanatory ·
PS3.18/3.19 web services and application hosting.

## 3. Classify every file first (buckets)

Read every Swift file of the module and put it in exactly one bucket. The report's Summary table
counts them.

| Bucket | Meaning | How it is verified |
|---|---|---|
| **A** | Claims to implement the target edition (cites it) | Internal consistency, then release notes, then row-by-row diff against the target |
| **B1** | Cites another edition, a CP or a Supplement | Row-by-row diff against the target; the citation is kept as provenance |
| **B2** | No citation, and its data does not match the target (known gaps) | Row-by-row diff; fix each gap; one file per commit |
| **C1** | Plumbing: no DICOM-derived data | Confirm it really carries none (citations, error text, constants); marker says so |
| **C2** | Carries standard-derived data that is stable across editions | Row-by-row diff all the same; edition-stable is a claim to check, not an exemption |

Out of scope: the internals of codecs (JPEG, JPEG 2000, HTJ2K, JPEG-LS, JPEG XL, RLE algorithms) belong to
ISO/IEC and ITU-T. DICOM governs only the boundary: the Transfer Syntax UID, the encapsulation and
fragment rules, the photometric interpretation and the pixel-module attributes, and those are checked.

## 4. Per-file procedure

For each file, in bucket order:

1. **Extract the standard.** `python3 Scripts/nema_docbook.py table partNN_<edition>.xml "<label>"` prints
   the table as tab-separated rows (`tables --grep` finds labels). For PS3.16 templates,
   `Scripts/generate_sr_templates.py` shows how to parse TID rows, INCLUDEs and parameters.
2. **Extract the code.** Pull the same values out of the Swift file with a script (regex over the
   literals, or a small test that prints them). Do not transcribe by hand.
3. **Diff row by row.** Compare the key (tag, UID, code, keyword) and every column the code carries
   (name, VR, VM, retired status, meaning, …). Record counts: matched, wrong, missing, extra.
4. **Decide each finding.**
   - Wrong or missing data in this module → fix it, with a test that pins the standard's value.
   - Behaviour that contradicts the standard (encoding, parsing, validation) → fix it, with a test.
   - A bug found in **another** module → do **not** fix it; add a row to that report's
     "Deferred findings" table (ID, module, file:line, problem, standard reference, severity).
     It is fixed when that module is audited.
   - A fix that changes **public API** (renames, removed or retyped members, new enum cases), or a
     point the standard leaves ambiguous → stop and ask before changing it. Deprecate rather than
     remove: `@available(*, deprecated, renamed:)`, or `unavailable` for a name that was simply wrong.
   - An earlier finding that turns out to be wrong against the text → record the correction in the
     report; do not change code to match the old finding.
   - Data too large to maintain by hand (template tables, context groups, dictionaries) → generate it
     from the DocBook with a script in `Scripts/`, and keep the script.
5. **Add the marker** (section 5).
6. **Build and test.** `swift build`, then the affected test targets
   (`swift test --filter <Target>`), and the full `swift test` before closing a bucket. Report failures
   as they are; if a failure also happens without your change, prove it (e.g. stash) and log it.
7. **Record it.** Update the file's row in its bucket table, add a Progress log line, and add a
   `CHANGELOG.md` `[Unreleased]` entry for every behaviour or API change.
8. **Commit** that file (or a small group of related files) on its own, on the feature branch. Do not
   push until the owner has reviewed.

## 5. The marker

Every Swift file of a verified module carries at least one marker line, in the file header or on the
type or section it covers:

```
NEMA-verified: <edition>, checked <yyyy-mm-dd> — <what was compared>; <provenance CP/Sup (edition)>
```

- One edition per marker line. A file verified against both the target and a later edition gets two
  lines (see `Sources/DICOMCore/VR.swift`).
- `<what was compared>` names the table or section and the result, e.g. "text-diffed against PS3.6
  2026a Table 6-1: 4,812 rows, all match" or "the 8 labels and UIDs match PS3.6 2026a; the RGB tables
  were not compared". Claim only what was compared.
- A C1 file says what was confirmed: "carries no DICOM-standard data (…)".
- A generated file gets its marker from the generator, and names the generator.
- Check a module with `python3 Scripts/check_nema_markers.py Sources/<Module>` (add `--list` for every
  finding). It exits 1 while a file has no marker or a malformed one.

## 6. The module report

Each module gets `<MODULE>_STANDARD_IMPLEMENTATION.md` at the repo root, with the layout of the
DICOMCore report:

1. Scope note and target edition, with a link to this method.
2. **Summary**: one row per bucket with file counts and status.
3. **Progress log**: date, bucket or item, what was compared, what changed, test result.
4. **Priority action list**: status table first (item, what, status, evidence), then one section per
   item. Items that need the owner's approval stay open until approved.
5. **Deferred findings**: this module's rows from earlier reports first (work through them before
   anything else, and mark each ✅ with date and commit), then new findings for other modules.
6. One section per bucket with a row per file.
7. Verification notes: anything not checked against the text is labelled as such until it is.

## 7. Definition of done for a module

- [ ] Every Swift file is in a bucket, and every bucket shows ✅ in the Summary.
- [ ] `python3 Scripts/check_nema_markers.py Sources/<Module>` exits 0, and each marker for an edition
      other than the target is justified by the policy table.
- [ ] Every data table the module carries has been diffed row by row by script, with counts in the report.
- [ ] All fixes have tests; `swift build` and the full `swift test` pass (or pre-existing failures are
      logged with proof).
- [ ] The Deferred findings rows for this module are closed or explicitly carried forward.
- [ ] No "from memory" or unverified claim remains in the report.
- [ ] CHANGELOG `[Unreleased]` lists every behaviour and API change; commits are local until review.

## 8. Tools

| Script | Use |
|---|---|
| [Scripts/nema_docbook.py](Scripts/nema_docbook.py) | Fetch a frozen part and check its subtitle; list tables; dump a table as TSV |
| [Scripts/check_nema_markers.py](Scripts/check_nema_markers.py) | Marker coverage and format for one or more modules |
| [Scripts/generate_sr_templates.py](Scripts/generate_sr_templates.py) | Example generator: SR templates from the PS3.16 TID tables |

## 9. Status by module (2026-09-25)

| Module | Swift files | Marked | Report |
|---|---|---|---|
| DICOMCore | 104 | 104 | [DICOMCORE_STANDARD_IMPLEMENTATION.md](DICOMCORE_STANDARD_IMPLEMENTATION.md) — complete |
| DICOMDictionary | 4 | 0 | Not started. Deferred D6, D7, D20 |
| DICOMKit | 156 | 0 | Not started. Deferred D5, D12, D14–D19 |
| DICOMNetwork | 63 | 0 | Not started. Deferred D1, D13 |
| DICOMWeb | 53 | 0 | Not started. Deferred D2–D4 |
| Other modules and CLI tools | — | 0 | Not started. Deferred D5, D9–D11, D15 (DICOMStudio, dicom-compress, dicom-dcmdir) |

The Deferred findings table in the DICOMCore report holds D1–D20.
