param(
  [string]$Flutter = "D:\flutter\bin\flutter.bat",
  [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"

& $Flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$destination = Join-Path $OutputDirectory "pixora-android-arm64-release.apk"
Copy-Item "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" $destination -Force
Write-Host "Created $destination"
