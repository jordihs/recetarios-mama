# Builds the distributable Windows app: PyInstaller backend + Flutter Windows GUI.
# Output: dist/recetarios-mama/  (Flutter app with the backend bundled at backend/)
[CmdletBinding()]
param(
    [string]$FlutterBin = "C:\soft\flutter\bin\flutter.bat"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Native tools write progress to stderr; judge them by exit code only.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments, [string]$Label)
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0) { throw "$Label failed (exit $LASTEXITCODE)" }
    } finally { $ErrorActionPreference = $eap }
}

Write-Host "[1/3] Building backend with PyInstaller..."
Push-Location (Join-Path $root 'backend')
try {
    $python = Join-Path $root 'backend\.venv\Scripts\python.exe'
    if (-not (Test-Path $python)) { $python = 'python' }
    Invoke-Native $python @('-m', 'PyInstaller', 'recetarios.spec', '--noconfirm', '--distpath', 'dist') 'PyInstaller'
} finally { Pop-Location }

Write-Host "[2/3] Building Flutter Windows app..."
Push-Location (Join-Path $root 'frontend')
try {
    Invoke-Native $FlutterBin @('build', 'windows', '--release') 'flutter build'
} finally { Pop-Location }

Write-Host "[3/3] Assembling dist/recetarios-mama..."
$out = Join-Path $root 'dist\recetarios-mama'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item -Recurse (Join-Path $root 'frontend\build\windows\x64\runner\Release\*') $out
# The Flutter app looks for the backend at <exe-dir>/backend/recetarios.exe
Copy-Item -Recurse (Join-Path $root 'backend\dist\recetarios') (Join-Path $out 'backend')

Write-Host "Done: $out"
