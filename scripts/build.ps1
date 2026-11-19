param([string]$VivadoBin = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($VivadoBin) {
    if (-not (Test-Path -LiteralPath (Join-Path $VivadoBin 'vivado.bat'))) {
        throw "Vivado was not found in the requested directory: $VivadoBin"
    }
} else {
    $tool = Get-Command vivado.bat -ErrorAction SilentlyContinue
    if ($tool) {
        $VivadoBin = Split-Path $tool.Source -Parent
    } elseif ($env:XILINX_VIVADO -and (Test-Path -LiteralPath (Join-Path $env:XILINX_VIVADO 'bin/vivado.bat'))) {
        $VivadoBin = Join-Path $env:XILINX_VIVADO 'bin'
    } else {
        $installations = @(Get-ChildItem -Path @(
            'C:/AMDDesignTools/*/Vivado/bin/vivado.bat',
            'C:/Xilinx/Vivado/*/bin/vivado.bat',
            'C:/AMD/Vivado/*/bin/vivado.bat'
        ) -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)
        if ($installations.Count -eq 0) {
            throw 'Vivado was not found. Supply -VivadoBin with the directory containing vivado.bat.'
        }
        $VivadoBin = $installations[0].DirectoryName
    }
}
$buildDirectory = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force $buildDirectory | Out-Null
Push-Location $buildDirectory
try {
    Write-Output "Building with Vivado from $VivadoBin"
    # Capture launcher output too: licensing can fail before Vivado opens build.log.
    & (Join-Path $VivadoBin 'vivado.bat') -mode batch -source (Join-Path $PSScriptRoot 'build.tcl') -log build.log -journal build.jou 2>&1 |
        Tee-Object -FilePath build_console.log
    if ($LASTEXITCODE -ne 0) { throw 'FPGA build failed. See build/build_console.log and, if created, build/build.log.' }
} finally { Pop-Location }
