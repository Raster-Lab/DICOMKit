#!/usr/bin/env bash
#
# cli-parity.sh — Tier 1 of the DICOMKit CLI parity harness.
#
# Builds the package, captures the REAL input contract of every dicom-* binary
# via `--experimental-dump-help`, dumps the DICOMStudio CLI Workshop catalog via
# the `studio-cli-introspect` tool, and produces a colour-coded .xlsx comparing
# the two so you can spot every flag/tool mismatch automatically.
#
# Usage:
#   Scripts/cli-parity.sh                 # full run (build + dump + report)
#   SKIP_BUILD=1 Scripts/cli-parity.sh    # reuse existing .build binaries
#   OPEN=1 Scripts/cli-parity.sh          # open the .xlsx when done (macOS)
#
set -euo pipefail

# Repo root = parent of this script's dir.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/build/cli-parity"
CLI_DIR="$OUT_DIR/cli"
STUDIO_JSON="$OUT_DIR/studio-catalog.json"
REPORT="$OUT_DIR/cli-parity-report.xlsx"
VENV="$ROOT/.venv-cli-parity"

mkdir -p "$CLI_DIR"

# --- 1. Build -------------------------------------------------------------
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "==> swift build (all products)…"
  swift build 2>&1 | grep -vE "object file .* was built for newer" || true
else
  echo "==> SKIP_BUILD=1 — reusing existing build."
fi

BIN_DIR="$(swift build --show-bin-path 2>/dev/null | tail -1)"
echo "==> binaries: $BIN_DIR"

# --- 2. Studio catalog dump ----------------------------------------------
INTROSPECT="$BIN_DIR/studio-cli-introspect"
if [[ ! -x "$INTROSPECT" ]]; then
  echo "==> building studio-cli-introspect…"
  swift build --product studio-cli-introspect 2>&1 | grep -vE "object file .* was built for newer" || true
fi
echo "==> dumping Studio catalog -> $STUDIO_JSON"
"$INTROSPECT" > "$STUDIO_JSON"

# --- 3. CLI --experimental-dump-help for every dicom-* binary ------------
echo "==> dumping CLI contracts (--experimental-dump-help)…"
rm -f "$CLI_DIR"/*.json
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout 20"; fi
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout 20"; fi

rm -f "$CLI_DIR"/*.error.txt
dumped=0; failed=0
while IFS= read -r bin; do
  name="$(basename "$bin")"
  case "$name" in
    *.dSYM|*.product|*.plist|*.json|*.bundle) continue ;;
  esac
  if $TIMEOUT_BIN "$bin" --experimental-dump-help > "$CLI_DIR/$name.json" 2>"$CLI_DIR/$name.stderr" \
     && [[ -s "$CLI_DIR/$name.json" ]] \
     && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CLI_DIR/$name.json" 2>/dev/null; then
    dumped=$((dumped+1))
    rm -f "$CLI_DIR/$name.stderr"
  else
    # Keep the stderr — a failed dump-help usually means the command's
    # ArgumentParser definition is itself broken (a real finding).
    mv -f "$CLI_DIR/$name.stderr" "$CLI_DIR/$name.error.txt" 2>/dev/null || true
    rm -f "$CLI_DIR/$name.json"
    firstline="$(grep -m1 -E '[A-Za-z]' "$CLI_DIR/$name.error.txt" 2>/dev/null | head -c 120 || true)"
    echo "    ! $name: dump-help failed — ${firstline:-no output} (see $name.error.txt)"
    failed=$((failed+1))
  fi
done < <(find "$BIN_DIR" -maxdepth 1 -type f -perm -111 -name 'dicom-*' | sort)
echo "    dumped $dumped binaries ($failed failed — see *.error.txt)"

# --- 4. Python venv (openpyxl) -------------------------------------------
if [[ ! -x "$VENV/bin/python" ]]; then
  echo "==> creating venv for openpyxl -> $VENV"
  python3 -m venv "$VENV"
  "$VENV/bin/python" -m pip install --quiet --upgrade pip
  "$VENV/bin/python" -m pip install --quiet openpyxl
fi

# --- 5. Generate report ---------------------------------------------------
echo "==> generating report…"
"$VENV/bin/python" "$ROOT/Scripts/cli_parity_report.py" \
  --cli-dir "$CLI_DIR" --studio "$STUDIO_JSON" --out "$REPORT"

echo
echo "Report: $REPORT"
if [[ "${OPEN:-0}" == "1" ]] && command -v open >/dev/null 2>&1; then
  open "$REPORT"
fi
