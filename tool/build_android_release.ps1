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

$artifacts = @(
  @{ Source = "app-arm64-v8a-release.apk"; Output = "pixora-android-arm64-v8a-release.apk" },
  @{ Source = "app-armeabi-v7a-release.apk"; Output = "pixora-android-armeabi-v7a-release.apk" },
  @{ Source = "app-x86_64-release.apk"; Output = "pixora-android-x86_64-release.apk" }
)

foreach ($artifact in $artifacts) {
  $source = Join-Path "build/app/outputs/flutter-apk" $artifact.Source
  $destination = Join-Path $OutputDirectory $artifact.Output
  Copy-Item $source $destination -Force
  $stream = [System.IO.File]::OpenRead($destination)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = [System.BitConverter]::ToString($sha256.ComputeHash($stream)).Replace("-", "").ToLowerInvariant()
  }
  finally {
    $stream.Dispose()
    $sha256.Dispose()
  }
  "$hash  $($artifact.Output)" | Set-Content "$destination.sha256"
  Write-Host "Created $destination"
}
