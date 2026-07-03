# Run the Flutter app on Windows desktop without requiring Android Java tooling.
# Usage: .\run_flutter_windows.ps1

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
Write-Host 'Running flutter pub get...' -ForegroundColor Cyan
flutter pub get
Write-Host 'Launching flutter run -d windows...' -ForegroundColor Cyan
flutter run -d windows
