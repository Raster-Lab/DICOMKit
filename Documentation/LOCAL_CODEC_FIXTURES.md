# Local codec integration fixtures

The real-image codec and JP3D integration tests require a small local DICOM
corpus. DICOM objects and their generated integrity reports are not repository
resources: `LocalDatasets/` and `SampleStudies/` are both gitignored.

## Approved sources

Only these sources are accepted by the setup command:

- Public, de-identified TCIA instances from `RIDER_Lung_CT` (CT) and
  `BREAST-DIAGNOSIS` (MR and MG).
- J2KSwift's existing deterministic, generated non-PHI DICOM fixtures for
  modalities absent from the downloaded TCIA subset: DX, PX, and XA.

Never substitute RasterOneImage `TestData` or another PHI-capable clinical
corpus. The command neither rewrites modality tags nor synthesizes new DICOM
objects.

## Required fixture layout

The tests consume these stable slots:

- `LocalDatasets/medical-dicom-organized/{mr,px}` for J2K/HTJ2K parsing,
  round-trip, reference-decoder, and benchmark tests.
- Ten named report inputs under `ct`, `dx`, `mg`, `mr`, `px`, and `xa`.
- Sixteen homogeneous CT slices under `ct/study_002` for JP3D.
- The complete `SampleStudies` contract: ten CT instances under
  `ct/study_001`, five MR instances under `mr/study_003`, two instances each
  under `dx/study_001`, `mg/study_001`, and `xa/study_001`, plus one PX
  instance under `px/study_003`. These paths cover the Kakadu cross-codec
  lane, the six-modality DICOM Studio Lane-B substitute, and the recursive
  multi-codec table walk.

From the DICOMKit repository root, run:

```sh
Scripts/prepare-local-codec-fixtures.sh \
  --tcia-root /path/to/tcia-verification \
  --j2kswift-root /path/to/J2KSwift
```

Selection is deterministic and pinned to named TCIA collection/series pairs.
Instances are sorted bytewise and chosen by ordinal. The generated fixtures
retain their J2KSwift names and published generation manifest. The two report
DX slots and two SampleStudies DX slots intentionally reference the same sole
generated DX payload; their identical digest and source identity make that
duplication explicit. They are four fixture paths, not four unique images.

## Validation, integrity, and privacy

Before setup succeeds, every staged object is parsed without force as DICOM
Part 10 and checked for:

- expected modality, dimensions, frame count, sample count, stored/allocated
  bit depth, signedness, photometric interpretation, and transfer syntax;
- uncompressed, image-bearing Pixel Data whose byte length exactly equals the
  declared frame geometry; and
- identical geometry across all 16 CT volume slices.

Setup creates these mode-0600, local-only records:

- `LocalDatasets/codec-fixtures.sha256`
- `LocalDatasets/codec-fixtures-provenance.tsv`
- `LocalDatasets/codec-fixtures-validation.tsv`

Every staged DICOM object is also mode 0600. Verification rejects symlinks,
non-regular files, files not owned by the current user, and any permission
mode other than 0600 before attempting to parse content.

The provenance file contains only collection, series, ordinal (or generated
fixture name), destination, byte count, and SHA-256. It contains no patient
attribute or absolute source path. Re-run parser and digest validation with:

```sh
Scripts/prepare-local-codec-fixtures.sh --verify
```

Do not commit, publish, or attach any local fixture or report. TCIA collection
licensing remains available in the source archive's `catalog/collections.json`.
