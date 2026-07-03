#!/usr/bin/env bash
# ─── App Store Connect Screenshot Resizer ────────────────────────────────────
# Resizes all PNG/JPG files in ./screnshots/ to the required App Store sizes.
# Output goes to ./screnshots/appstore/<size>/
#
# Required sizes (portrait):
#   6.9"  — 1320 × 2868  (iPhone 16 Pro Max)          ← required since 2024
#   6.7"  — 1290 × 2796  (iPhone 14/15 Plus)           ← required
#   6.5"  — 1242 × 2688  (iPhone 11 Pro Max / XS Max)
#   5.5"  — 1242 × 2208  (iPhone 8 Plus)               ← legacy, optional
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/../screnshots" && pwd)"
OUT_DIR="$SRC_DIR/appstore"

declare -a SIZES=(
  "6.9inch:1320:2868"
  "6.7inch:1290:2796"
  "6.5inch:1242:2688"
  "5.5inch:1242:2208"
)

echo "Source: $SRC_DIR"
echo "Output: $OUT_DIR"
echo ""

for entry in "${SIZES[@]}"; do
  IFS=':' read -r label w h <<< "$entry"
  mkdir -p "$OUT_DIR/$label"
done

shopt -s nullglob
files=("$SRC_DIR"/*.png "$SRC_DIR"/*.jpg "$SRC_DIR"/*.PNG "$SRC_DIR"/*.JPG)

if [ ${#files[@]} -eq 0 ]; then
  echo "No PNG/JPG files found in $SRC_DIR"
  exit 1
fi

for src in "${files[@]}"; do
  name="$(basename "$src")"
  echo "Processing: $name"

  for entry in "${SIZES[@]}"; do
    IFS=':' read -r label w h <<< "$entry"
    dst="$OUT_DIR/$label/$name"

    # Copy then resize in place (sips edits files directly)
    cp "$src" "$dst"
    sips -z "$h" "$w" "$dst" --out "$dst" > /dev/null 2>&1
    echo "  ✓ $label  ${w}×${h}"
  done
  echo ""
done

echo "Done. Files saved to:"
for entry in "${SIZES[@]}"; do
  IFS=':' read -r label w h <<< "$entry"
  count=$(ls "$OUT_DIR/$label"/*.png "$OUT_DIR/$label"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
  echo "  $OUT_DIR/$label/  ($count files)"
done
