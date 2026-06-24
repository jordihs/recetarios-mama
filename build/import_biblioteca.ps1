<#
.SYNOPSIS
    Importa biblioteca.recetarios en el directorio de datos del usuario.
    Llamado automáticamente por el instalador de Recetarios de Mamá.

.NOTES
    Arranca el backend brevemente, llama a la API de importación y lo detiene.
    El directorio de datos queda en %LOCALAPPDATA%\recetarios-mama.
#>
param(
    [Parameter(Mandatory)][string]$BackendExe,
    [Parameter(Mandatory)][string]$DbFile,
    [Parameter(Mandatory)][string]$DataDir
)

$ErrorActionPreference = 'Stop'

# Crear directorio de datos si no existe
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
}

# Arrancar el backend con un puerto aleatorio
$pinfo                          = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName                 = $BackendExe
$pinfo.Arguments                = "--port 0 --data-dir `"$DataDir`""
$pinfo.RedirectStandardOutput   = $true
$pinfo.UseShellExecute          = $false
$pinfo.CreateNoWindow           = $true
$pinfo.WorkingDirectory         = [System.IO.Path]::GetDirectoryName($BackendExe)

$proceso = [System.Diagnostics.Process]::Start($pinfo)

# Leer el anuncio de puerto (bloquea hasta que el backend lo emita)
$linea = $proceso.StandardOutput.ReadLine()

if ($linea -match 'RECETARIOS_PORT=(\d+)') {
    $puerto = $Matches[1]
} else {
    if (-not $proceso.HasExited) { $proceso.Kill() }
    exit 1
}

# Pausa breve para que el servidor termine de inicializarse
Start-Sleep -Milliseconds 500

# Importar la base de datos
$cuerpo = @{ path = $DbFile; confirm_replace = $true } | ConvertTo-Json
try {
    Invoke-RestMethod `
        -Uri         "http://127.0.0.1:$puerto/library/import" `
        -Method      POST `
        -Body        $cuerpo `
        -ContentType 'application/json' | Out-Null
} catch {
    # Si la importación falla, el usuario puede hacerlo desde la propia aplicación
}

# Apagar el backend
try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$puerto/shutdown" -Method POST | Out-Null
} catch {}

$proceso.WaitForExit(5000)
if (-not $proceso.HasExited) {
    try { $proceso.Kill() } catch {}
}

exit 0
