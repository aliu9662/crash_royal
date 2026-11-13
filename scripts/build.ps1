param([string]$VivadoBin = 'C:/AMDDesignTools/2026.1/Vivado/bin')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $VivadoBin 'vivado.bat'))) {
    $tool = Get-Command vivado.bat -ErrorAction Stop
    $VivadoBin = Split-Path $tool.Source -Parent
}
$buildDirectory = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force $buildDirectory | Out-Null
Push-Location $buildDirectory
try {
    & (Join-Path $VivadoBin 'vivado.bat') -mode batch -source (Join-Path $PSScriptRoot 'build.tcl') -log build.log -journal build.jou
    if ($LASTEXITCODE -ne 0) { throw 'FPGA build failed. See build/build.log.' }
} finally { Pop-Location }
