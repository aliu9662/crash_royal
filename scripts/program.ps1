param([string]$VivadoBin = 'C:/Xilinx/Vivado/2024.1/bin')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $VivadoBin 'vivado.bat'))) {
    $tool = Get-Command vivado.bat -ErrorAction Stop
    $VivadoBin = Split-Path $tool.Source -Parent
}
& (Join-Path $VivadoBin 'vivado.bat') -mode batch -source (Join-Path $PSScriptRoot 'program.tcl')
if ($LASTEXITCODE -ne 0) { throw 'FPGA program failed.' }
