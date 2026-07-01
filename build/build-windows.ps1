# Builds the distributable Windows app: Flutter Windows GUI (standalone, no backend process).
# Output: dist/recetarios-mama/
#
# Agregar -BuildInstaller para compilar también el instalador con Inno Setup.
# Requiere Inno Setup 6 instalado (https://jrsoftware.org/isinfo.php).
# Output del instalador: dist/recetarios-mama-setup.exe
[CmdletBinding()]
param(
    [string]$FlutterBin       = "C:\soft\flutter\bin\flutter.bat",
    [switch]$BuildInstaller
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

Write-Host "[1/2] Building Flutter Windows app..."
Push-Location (Join-Path $root 'frontend')
try {
    Invoke-Native $FlutterBin @('build', 'windows', '--release') 'flutter build'
} finally { Pop-Location }

Write-Host "[2/2] Assembling dist/recetarios-mama..."
$out = Join-Path $root 'dist\recetarios-mama'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item -Recurse (Join-Path $root 'frontend\build\windows\x64\runner\Release\*') $out

Write-Host "Done: $out"

if ($BuildInstaller) {
    Write-Host "[3/3] Compilando instalador con Inno Setup..."
    $iscc = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $iscc) {
        throw "No se encontró Inno Setup 6. Instálalo desde https://jrsoftware.org/isinfo.php"
    }
    Invoke-Native $iscc @((Join-Path $PSScriptRoot 'installer.iss')) 'ISCC'
    Write-Host "Instalador: $(Join-Path $root 'dist\recetarios-mama-setup.exe')"
}
