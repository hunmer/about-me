$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$workspace = Split-Path -Parent $PSScriptRoot
$server = Join-Path $workspace "packages/server-nodejs"

Push-Location $server
try {
  npm install
  npx tsc --noEmit
  npm test
  npm run build
} finally {
  Pop-Location
}

Push-Location $workspace
try {
  flutter pub get
  flutter analyze
  flutter test
} finally {
  Pop-Location
}
