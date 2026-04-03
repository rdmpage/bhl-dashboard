#!/usr/bin/env bash
# Download BHL data dump and extract TSV files into data/
set -euo pipefail

DATA_DIR="$(dirname "$0")/data"
ZIP_FILE="$DATA_DIR/data.zip"
URL="https://www.biodiversitylibrary.org/data/data.zip"

mkdir -p "$DATA_DIR"

echo "==> Downloading BHL data from $URL"
curl -L --progress-bar -C - -o "$ZIP_FILE" "$URL"

echo "==> Contents of archive:"
unzip -l "$ZIP_FILE"

echo "==> Extracting to $DATA_DIR"
unzip -o "$ZIP_FILE" -d "$DATA_DIR"

echo "==> Done. Files in $DATA_DIR:"
ls -lh "$DATA_DIR"
