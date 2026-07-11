#!/bin/zsh

# Prepare and validate the local-only DICOM corpus used by codec integration
# tests. Only public TCIA de-identified instances and J2KSwift's generated
# non-PHI fixtures are accepted. No source file is modified.

emulate -L zsh
setopt errexit nounset pipefail typesetsilent

readonly script_dir="${0:A:h}"
readonly repository_root="${script_dir:h}"
readonly checksum_manifest="LocalDatasets/codec-fixtures.sha256"
readonly provenance_manifest="LocalDatasets/codec-fixtures-provenance.tsv"
readonly validation_report="LocalDatasets/codec-fixtures-validation.tsv"

readonly tcia_ct_collection="RIDER_Lung_CT"
readonly tcia_ct_series="1.3.6.1.4.1.9328.50.1.48441840081578419409180519840073808100"
readonly tcia_mr_collection="BREAST-DIAGNOSIS"
readonly tcia_mr_series="1.3.6.1.4.1.14519.5.2.1.4792.2001.226299354647098584258497258041"
readonly tcia_mg_collection="BREAST-DIAGNOSIS"
readonly tcia_mg_series_1="1.3.6.1.4.1.14519.5.2.1.4792.2001.754281941826542555402761972816"
readonly tcia_mg_series_2="1.3.6.1.4.1.14519.5.2.1.4792.2001.104616474240757574154876423123"

fail() {
    print -u2 -r -- "error: $1"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  Scripts/prepare-local-codec-fixtures.sh \
    --tcia-root /path/to/tcia-verification \
    --j2kswift-root /path/to/J2KSwift

  Scripts/prepare-local-codec-fixtures.sh --verify

The install command refuses to replace an existing LocalDatasets or
SampleStudies directory. Remove or archive an obsolete local fixture set
explicitly before rebuilding it.
EOF
}

resolve_validation_tools() {
    command -v jq >/dev/null || fail "jq is required for safe fixture validation"
    command -v base64 >/dev/null || fail "base64 is required for pixel-length validation"

    local bin_path="$(cd "$repository_root" && swift build --show-bin-path)"
    dicom_info="$bin_path/dicom-info"
    dicom_json="$bin_path/dicom-json"
    [[ -x "$dicom_info" ]] || fail "dicom-info is not built; run 'swift build --product dicom-info'"
    [[ -x "$dicom_json" ]] || fail "dicom-json is not built; run 'swift build --product dicom-json'"
}

validate_fixtures() {
    local fixture_root="$1"
    [[ -f "$fixture_root/$checksum_manifest" ]] || fail "fixture checksum manifest is not installed"
    [[ -f "$fixture_root/$provenance_manifest" ]] || fail "fixture provenance manifest is not installed"

    resolve_validation_tools

    (
        cd "$fixture_root"
        shasum -a 256 -c "$checksum_manifest" >/dev/null
    )

    local report_path="$fixture_root/$validation_report"
    printf 'destination\tmodality\trows\tcolumns\tframes\tsamples\tbits_stored\tbits_allocated\tsigned\ttransfer_syntax\traw_bytes\tsha256\n' \
        > "$report_path"
    chmod 0600 "$report_path"

    local ct_signature=""
    integer ct_slice_count=0
    integer fixture_count=0
    integer expected_owner_uid="$(id -u)"

    while IFS=$'\t' read -r source_class source_identity destination expected_modality digest byte_count; do
        [[ "$source_class" == "source_class" ]] && continue

        local fixture_path="$fixture_root/$destination"
        [[ -f "$fixture_path" && ! -L "$fixture_path" ]] \
            || fail "fixture must be a regular non-symlink file: $destination"
        local owner_uid="$(stat -f '%u' "$fixture_path")"
        local permission_mode="$(stat -f '%Lp' "$fixture_path")"
        (( owner_uid == expected_owner_uid )) || fail "fixture is not owned by the current user: $destination"
        [[ "$permission_mode" == "600" ]] || fail "fixture mode is not 0600: $destination"

        # dicom-info parses without --force, so success confirms a Part-10 file.
        # Restrict its data-set output to Modality; statistics supplies only the
        # SOP class and transfer syntax.
        local info_json="$("$dicom_info" --format json --statistics --tag Modality "$fixture_path")"
        local transfer_syntax="$(print -r -- "$info_json" | jq -r '.statistics.transferSyntax // empty')"
        [[ -n "$transfer_syntax" ]] || fail "missing transfer syntax: $destination"
        case "$transfer_syntax" in
            1.2.840.10008.1.2|1.2.840.10008.1.2.1|1.2.840.10008.1.2.2) ;;
            *) fail "fixture is not uncompressed: $destination" ;;
        esac

        # Export only pixel-description tags plus Pixel Data to a mode-0600
        # temporary JSON file. No patient/study attributes are read into the
        # validation report.
        local safe_json="$(mktemp "${TMPDIR:-/tmp}/dicomkit-fixture-tags.XXXXXX")"
        chmod 0600 "$safe_json"
        "$dicom_json" "$fixture_path" --output "$safe_json" --inline-threshold 100000000 \
            --filter-tag Modality \
            --filter-tag SamplesPerPixel \
            --filter-tag NumberOfFrames \
            --filter-tag Rows \
            --filter-tag Columns \
            --filter-tag BitsAllocated \
            --filter-tag BitsStored \
            --filter-tag PixelRepresentation \
            --filter-tag PhotometricInterpretation \
            --filter-tag PixelData >/dev/null

        local fields="$(jq -r '[
            ."00080060".Value[0],
            ."00280002".Value[0],
            (."00280008".Value[0] // "1"),
            ."00280010".Value[0],
            ."00280011".Value[0],
            ."00280100".Value[0],
            ."00280101".Value[0],
            ."00280103".Value[0],
            ."00280004".Value[0]
        ] | @tsv' "$safe_json")"

        local modality samples frames rows columns bits_allocated bits_stored signed_value photometric
        IFS=$'\t' read -r modality samples frames rows columns bits_allocated bits_stored signed_value photometric \
            <<< "$fields" >/dev/null

        [[ "$modality" == "$expected_modality" ]] || fail "modality mismatch for $destination"
        (( rows > 0 && columns > 0 && samples > 0 && frames > 0 )) || fail "invalid pixel dimensions: $destination"
        (( bits_allocated == 8 || bits_allocated == 16 )) || fail "unsupported allocated bit depth: $destination"
        (( bits_stored > 0 && bits_stored <= bits_allocated )) || fail "invalid stored bit depth: $destination"
        (( signed_value == 0 || signed_value == 1 )) || fail "invalid pixel representation: $destination"
        [[ -n "$photometric" ]] || fail "missing photometric interpretation: $destination"

        jq -e '."7FE00010".Value[0].InlineBinary | length > 0' "$safe_json" >/dev/null \
            || fail "fixture has no inline image Pixel Data: $destination"
        local raw_bytes="$(jq -r '."7FE00010".Value[0].InlineBinary' "$safe_json" \
            | base64 -D | wc -c | tr -d ' ')"
        rm -f -- "$safe_json"

        integer expected_raw_bytes=$(( rows * columns * samples * frames * (bits_allocated / 8) ))
        (( raw_bytes == expected_raw_bytes )) || fail "raw frame length mismatch for $destination"

        if [[ "$destination" == LocalDatasets/medical-dicom-organized/ct/study_002/* ]]; then
            local signature="$rows:$columns:$samples:$bits_allocated:$bits_stored:$signed_value:$photometric"
            if [[ -z "$ct_signature" ]]; then
                ct_signature="$signature"
            else
                [[ "$signature" == "$ct_signature" ]] || fail "CT volume geometry is heterogeneous"
            fi
            (( ct_slice_count += 1 ))
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$destination" "$modality" "$rows" "$columns" "$frames" "$samples" \
            "$bits_stored" "$bits_allocated" "$signed_value" "$transfer_syntax" \
            "$raw_bytes" "$digest" >> "$report_path"
        (( fixture_count += 1 ))
    done < "$fixture_root/$provenance_manifest"

    (( ct_slice_count == 16 )) || fail "the validated CT volume must contain exactly 16 slices"
    chmod 0600 "$fixture_root/$checksum_manifest" "$fixture_root/$provenance_manifest" "$report_path"
    print -r -- "Validated $fixture_count Part-10 image fixtures, exact raw pixel lengths, and homogeneous 16-slice CT geometry."
}

if [[ "${1:-}" == "--verify" ]]; then
    [[ $# -eq 1 ]] || fail "--verify does not accept additional arguments"
    validate_fixtures "$repository_root"
    exit 0
fi

tcia_root="${DICOMKIT_TCIA_ROOT:-}"
j2kswift_root="${DICOMKIT_J2KSWIFT_ROOT:-}"

while (( $# > 0 )); do
    case "$1" in
        --tcia-root)
            (( $# >= 2 )) || fail "--tcia-root requires a value"
            tcia_root="$2"
            shift 2
            ;;
        --j2kswift-root)
            (( $# >= 2 )) || fail "--j2kswift-root requires a value"
            j2kswift_root="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

[[ -n "$tcia_root" && -d "$tcia_root/images" ]] || fail "a valid TCIA verification root is required"
[[ -n "$j2kswift_root" && -d "$j2kswift_root/Tests/Fixtures/CrossCodec/synthetic" ]] \
    || fail "a valid J2KSwift source root is required"
[[ ! -e "$repository_root/LocalDatasets" ]] || fail "LocalDatasets already exists; refusing to replace it"
[[ ! -e "$repository_root/SampleStudies" ]] || fail "SampleStudies already exists; refusing to replace it"

find_tcia_series() {
    local collection="$1"
    local modality="$2"
    local series_uid="$3"
    local directory="$(find "$tcia_root/images/$collection" -type d -name "${modality}_${series_uid}" -print -quit)"
    [[ -n "$directory" ]] || fail "required TCIA series is not downloaded: $collection/$modality"
    print -r -- "$directory"
}

sorted_series_files() {
    find "$1" -maxdepth 1 -type f -iname '*.dcm' -print | LC_ALL=C sort
}

readonly ct_directory="$(find_tcia_series "$tcia_ct_collection" CT "$tcia_ct_series")"
readonly mr_directory="$(find_tcia_series "$tcia_mr_collection" MR "$tcia_mr_series")"
readonly mg_directory_1="$(find_tcia_series "$tcia_mg_collection" MG "$tcia_mg_series_1")"
readonly mg_directory_2="$(find_tcia_series "$tcia_mg_collection" MG "$tcia_mg_series_2")"

ct_files=("${(@f)$(sorted_series_files "$ct_directory")}")
mr_files=("${(@f)$(sorted_series_files "$mr_directory")}")
mg_files_1=("${(@f)$(sorted_series_files "$mg_directory_1")}")
mg_files_2=("${(@f)$(sorted_series_files "$mg_directory_2")}")
ct_volume_files=("${(@f)$(find "$ct_directory" -maxdepth 1 -type f -iname '*.dcm' -size +399999c -print | LC_ALL=C sort)}")

(( ${#ct_files} >= 50 )) || fail "the selected TCIA CT series has fewer than 50 instances"
(( ${#mr_files} >= 100 )) || fail "the selected TCIA MR series has fewer than 100 instances"
(( ${#mg_files_1} >= 1 && ${#mg_files_2} >= 1 )) || fail "the selected TCIA MG series are incomplete"
(( ${#ct_volume_files} >= 16 )) || fail "the selected TCIA CT series has fewer than 16 slices above 400 KB"

readonly synthetic_root="$j2kswift_root/Tests/Fixtures/CrossCodec/synthetic"
readonly dx_fixture="$synthetic_root/dx_synth_mid.dcm"
readonly px_fixture="$synthetic_root/px_synth_mid.dcm"
readonly xa_fixture="$synthetic_root/xa_synth_small.dcm"
readonly xa_mid_fixture="$synthetic_root/xa_synth_mid.dcm"
for fixture in "$dx_fixture" "$px_fixture" "$xa_fixture" "$xa_mid_fixture"; do
    [[ -f "$fixture" ]] || fail "required generated J2KSwift fixture is missing"
done

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/dicomkit-codec-fixtures.XXXXXX")"
trap 'rm -rf -- "$stage_root"' EXIT INT TERM

mkdir -p \
    "$stage_root/LocalDatasets/medical-dicom-organized/ct/study_001" \
    "$stage_root/LocalDatasets/medical-dicom-organized/ct/study_002" \
    "$stage_root/LocalDatasets/medical-dicom-organized/ct/study_003" \
    "$stage_root/LocalDatasets/medical-dicom-organized/dx/study_001" \
    "$stage_root/LocalDatasets/medical-dicom-organized/dx/study_002" \
    "$stage_root/LocalDatasets/medical-dicom-organized/mg/study_001" \
    "$stage_root/LocalDatasets/medical-dicom-organized/mg/study_002" \
    "$stage_root/LocalDatasets/medical-dicom-organized/mr/study_001" \
    "$stage_root/LocalDatasets/medical-dicom-organized/mr/study_002" \
    "$stage_root/LocalDatasets/medical-dicom-organized/px/study_001" \
    "$stage_root/LocalDatasets/medical-dicom-organized/xa/study_001" \
    "$stage_root/SampleStudies/ct/study_001" \
    "$stage_root/SampleStudies/dx/study_001" \
    "$stage_root/SampleStudies/mg/study_001" \
    "$stage_root/SampleStudies/mr/study_003" \
    "$stage_root/SampleStudies/px/study_003" \
    "$stage_root/SampleStudies/xa/study_001"

printf '# DICOMKit local codec fixtures (SHA-256)\n' > "$stage_root/$checksum_manifest"
printf 'source_class\tsource_identity\tdestination\texpected_modality\tsha256\tbytes\n' \
    > "$stage_root/$provenance_manifest"

copy_fixture() {
    local source="$1"
    local destination="$2"
    local source_class="$3"
    local source_identity="$4"
    local expected_modality="$5"
    local target="$stage_root/$destination"

    [[ -f "$source" ]] || fail "selected source DICOM file is missing"
    cp -p -- "$source" "$target"
    chmod 0600 "$target"

    local digest="$(shasum -a 256 "$target" | awk '{print $1}')"
    local byte_count="$(stat -f '%z' "$target")"
    printf '%s  %s\n' "$digest" "$destination" >> "$stage_root/$checksum_manifest"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$source_class" "$source_identity" "$destination" "$expected_modality" "$digest" "$byte_count" \
        >> "$stage_root/$provenance_manifest"
}

copy_fixture "${ct_files[1]}" \
    "LocalDatasets/medical-dicom-organized/ct/study_001/instance_000001.dcm" \
    "TCIA-public" "$tcia_ct_collection/CT_$tcia_ct_series/ordinal-1" "CT"
copy_fixture "${ct_files[50]}" \
    "LocalDatasets/medical-dicom-organized/ct/study_003/instance_000050.dcm" \
    "TCIA-public" "$tcia_ct_collection/CT_$tcia_ct_series/ordinal-50" "CT"

integer slice_index=1
for source in "${(@)ct_volume_files[1,16]}"; do
    printf -v filename 'instance_%06d.dcm' "$slice_index"
    copy_fixture "$source" \
        "LocalDatasets/medical-dicom-organized/ct/study_002/$filename" \
        "TCIA-public" "$tcia_ct_collection/CT_$tcia_ct_series/volume-ordinal-$slice_index" "CT"
    (( slice_index += 1 ))
done

copy_fixture "$dx_fixture" \
    "LocalDatasets/medical-dicom-organized/dx/study_001/instance_000001.dcm" \
    "J2KSwift-generated" "dx_synth_mid.dcm" "DX"
copy_fixture "$dx_fixture" \
    "LocalDatasets/medical-dicom-organized/dx/study_002/instance_000001.dcm" \
    "J2KSwift-generated" "dx_synth_mid.dcm" "DX"
copy_fixture "${mg_files_1[1]}" \
    "LocalDatasets/medical-dicom-organized/mg/study_001/instance_000001.dcm" \
    "TCIA-public" "$tcia_mg_collection/MG_$tcia_mg_series_1/ordinal-1" "MG"
copy_fixture "${mg_files_2[1]}" \
    "LocalDatasets/medical-dicom-organized/mg/study_002/instance_000001.dcm" \
    "TCIA-public" "$tcia_mg_collection/MG_$tcia_mg_series_2/ordinal-1" "MG"
copy_fixture "${mr_files[1]}" \
    "LocalDatasets/medical-dicom-organized/mr/study_001/instance_000001.dcm" \
    "TCIA-public" "$tcia_mr_collection/MR_$tcia_mr_series/ordinal-1" "MR"
copy_fixture "${mr_files[100]}" \
    "LocalDatasets/medical-dicom-organized/mr/study_002/instance_000100.dcm" \
    "TCIA-public" "$tcia_mr_collection/MR_$tcia_mr_series/ordinal-100" "MR"
copy_fixture "$px_fixture" \
    "LocalDatasets/medical-dicom-organized/px/study_001/instance_000001.dcm" \
    "J2KSwift-generated" "px_synth_mid.dcm" "PX"
copy_fixture "$xa_fixture" \
    "LocalDatasets/medical-dicom-organized/xa/study_001/instance_000001.dcm" \
    "J2KSwift-generated" "xa_synth_small.dcm" "XA"

# Complete SampleStudies contract inventory:
# - Kakadu cross-codec lane: CT 1...10, MR 1...5, XA 1...2,
#   PX 1, DX 1...2, and MG 1...2 at the literal paths below.
# - DICOM Studio Lane-B: the first path for each of those six modalities.
# - Multi-codec table: recursive modality-directory walk (this set covers it).
integer sample_index=1
for source in "${(@)ct_files[1,10]}"; do
    printf -v filename 'instance_%06d.dcm' "$sample_index"
    copy_fixture "$source" "SampleStudies/ct/study_001/$filename" \
        "TCIA-public" "$tcia_ct_collection/CT_$tcia_ct_series/ordinal-$sample_index" "CT"
    (( sample_index += 1 ))
done

sample_index=1
for source in "${(@)mr_files[1,5]}"; do
    printf -v filename 'instance_%06d.dcm' "$sample_index"
    copy_fixture "$source" "SampleStudies/mr/study_003/$filename" \
        "TCIA-public" "$tcia_mr_collection/MR_$tcia_mr_series/ordinal-$sample_index" "MR"
    (( sample_index += 1 ))
done

copy_fixture "$xa_fixture" "SampleStudies/xa/study_001/instance_000001.dcm" \
    "J2KSwift-generated" "xa_synth_small.dcm" "XA"
copy_fixture "$xa_mid_fixture" "SampleStudies/xa/study_001/instance_000002.dcm" \
    "J2KSwift-generated" "xa_synth_mid.dcm" "XA"
copy_fixture "$px_fixture" "SampleStudies/px/study_003/instance_000001.dcm" \
    "J2KSwift-generated" "px_synth_mid.dcm" "PX"
copy_fixture "$dx_fixture" "SampleStudies/dx/study_001/instance_000001.dcm" \
    "J2KSwift-generated" "dx_synth_mid.dcm" "DX"
copy_fixture "$dx_fixture" "SampleStudies/dx/study_001/instance_000002.dcm" \
    "J2KSwift-generated" "dx_synth_mid.dcm" "DX"
copy_fixture "${mg_files_1[1]}" "SampleStudies/mg/study_001/instance_000001.dcm" \
    "TCIA-public" "$tcia_mg_collection/MG_$tcia_mg_series_1/ordinal-1" "MG"
copy_fixture "${mg_files_2[1]}" "SampleStudies/mg/study_001/instance_000002.dcm" \
    "TCIA-public" "$tcia_mg_collection/MG_$tcia_mg_series_2/ordinal-1" "MG"

chmod 0600 "$stage_root/$checksum_manifest" "$stage_root/$provenance_manifest"
validate_fixtures "$stage_root"
mv "$stage_root/LocalDatasets" "$repository_root/LocalDatasets"
mv "$stage_root/SampleStudies" "$repository_root/SampleStudies"

print -r -- "Installed 48 public/generated non-PHI codec fixture files with local integrity records."
