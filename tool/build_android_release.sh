#!/usr/bin/env bash
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build apk --release --split-per-abi

mkdir -p "$OUTPUT_DIR"

sources=(
  "app-arm64-v8a-release.apk"
  "app-armeabi-v7a-release.apk"
  "app-x86_64-release.apk"
)
outputs=(
  "pixora-android-arm64-v8a-release.apk"
  "pixora-android-armeabi-v7a-release.apk"
  "pixora-android-x86_64-release.apk"
)

for index in "${!sources[@]}"; do
  source_path="build/app/outputs/flutter-apk/${sources[$index]}"
  output_path="$OUTPUT_DIR/${outputs[$index]}"
  cp "$source_path" "$output_path"
  (
    cd "$OUTPUT_DIR"
    sha256sum "${outputs[$index]}" > "${outputs[$index]}.sha256"
  )
  printf 'Created %s\n' "$output_path"
done
