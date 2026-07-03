# Run the Flutter Android app with an auto-detected JDK.
# If the script finds a valid Java JDK, it sets JAVA_HOME for this session and runs flutter.
# Usage: .\run_flutter_android.ps1

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$javaPaths = @(
    'C:\Program Files\Java',
    'C:\Program Files (x86)\Java',
    'C:\Program Files\AdoptOpenJDK',
    'C:\Program Files\Zulu',
    'C:\Program Files\Amazon Corretto',
    'C:\Program Files\Microsoft\OpenJDK'
)

function Get-JdkInstallation {
    param($baseDir)
    if (-Not (Test-Path $baseDir)) { return $null }
    Get-ChildItem -Path $baseDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'jdk|jre|openjdk|corretto|zulu' } |
        Sort-Object Name -Descending |
        ForEach-Object {
            $candidate = $_.FullName
            if (Test-Path (Join-Path $candidate 'bin\java.exe')) { return $candidate }
        }
    return $null
}

$jdk = $null
foreach ($base in $javaPaths) {
    $jdk = Get-JdkInstallation -baseDir $base
    if ($jdk) { break }
}

if (-not $jdk) {
    Write-Host 'No JDK found in standard locations.' -ForegroundColor Yellow
    Write-Host 'Please install a JDK and set JAVA_HOME to the installation directory.'
    Write-Host 'Example:'
    Write-Host '  setx JAVA_HOME "C:\\Program Files\\Java\\jdk-21.0.9"' -ForegroundColor Gray
    Write-Host 'Then restart PowerShell and try again.'
    exit 1
}

Write-Host "Detected JDK: $jdk" -ForegroundColor Green
$env:JAVA_HOME = $jdk
$env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH

Set-Location $root
Write-Host 'Running flutter pub get...' -ForegroundColor Cyan
flutter pub get

Write-Host 'Launching flutter run...' -ForegroundColor Cyan
flutter run
