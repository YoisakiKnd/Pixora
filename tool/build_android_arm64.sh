#!/usr/bin/env bash
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build apk --release --split-per-abi

mkdir -p "$OUTPUT_DIR"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  "$OUTPUT_DIR/pixora-android-arm64-release.apk"

printf 'Created %s\n' "$OUTPUT_DIR/pixora-android-arm64-release.apk"
