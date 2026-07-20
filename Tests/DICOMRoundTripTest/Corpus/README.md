# Round-trip corpus (Tier 2) — user-supplied

This directory is intentionally empty. It holds the optional Tier 2 corpus of real
DICOM files used by the round-trip tests. **No files are committed here.**

The tests resolve this directory at runtime via `#filePath` (see
`../RoundTripFixture.swift`) and skip cleanly when a file is absent:

    Executed 400 tests, with 18 tests skipped and 0 failures

So the suite is green with an empty corpus. Supplying files only *adds* coverage.

## Supplying your own files

Drop files in with the exact names below. Each is optional — supply only what you
have, and the tests for the rest keep skipping.

| Filename          | Expected content                                                        |
|-------------------|-------------------------------------------------------------------------|
| `CT.dcm`          | CT 512×512, 16-bit MONOCHROME2, Explicit VR LE                          |
| `MR.dcm`          | MR 384×384, 16/12-bit MONOCHROME2, **Implicit VR LE** (1.2.840.10008.1.2) |
| `US.dcm`          | US 8-bit YBR_FULL_422, multi-frame **JPEG Baseline** (1.2.840.10008.1.2.4.50) |
| `j2klossless.dcm` | CT 512×512, 16-bit MONOCHROME2, **J2K lossless** (1.2.840.10008.1.2.4.90) |
| `CT_Multiframe`   | Enhanced-MR 192×192, 16/12-bit, multi-frame, Explicit VR LE (no extension) |

Some tests assert on window centre/width, rescale, and pixel spacing that were
tied to the previously committed files. Expect a few to need retuning for your
data; they are marked with `loadCorpus(...)` / `corpusURL(...)`.

## Do not commit files here

Anything placed here stays local. `.gitignore` excludes the contents of this
directory, and `Package.swift` excludes it from the build via `exclude: ["Corpus"]`.

**Use only de-identified data**, and verify it — de-identification is not just a
matter of blanking `PatientName`:

- Check **pixel data**, not just tags. Ultrasound, secondary capture, and screen
  captures routinely burn patient name, DOB, and institution into the image
  itself. `BurnedInAnnotation` (0028,0301) = `YES` means the pixels carry
  identifiers regardless of how clean the tags look.
- Check residual identifiers: `AccessionNumber` (0008,0050), `StudyDate`,
  `PatientAge`/`Size`/`Weight`, `InstitutionalDepartmentName` (0008,1040), and
  private blocks (e.g. Siemens CSA) that can retain site and operator detail.
- A date shift applied to tags but not to burned-in pixel text leaks the offset,
  which re-links the study.
- Prefer public de-identified sources (e.g. TCIA) or synthetic data. The Tier 1
  synthetic builders in `../RoundTripFixture.swift` need no real data at all.

See PS3.15 Annex E (Basic Application Level Confidentiality Profile) for the full
tag list.

## CI enforcement

The **PHI Guard** workflow (`.github/workflows/phi-guard.yml`) runs
`Scripts/check_burned_in_phi.py` on every push and pull request. It scans every
committed DICOM file in the repository and **fails the build** if any has
`BurnedInAnnotation` (0028,0301) = `YES`. This is a backstop only — it catches the
burned-in case; it cannot detect PHI in pixels of a file whose tag is missing or
lies, so the manual verification above still applies.
