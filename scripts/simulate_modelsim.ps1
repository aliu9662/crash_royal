param([string]$ModelSimBin = 'C:/modeltech64_10.6e/win64')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$simDirectory = Join-Path $projectRoot 'build/modelsim'
New-Item -ItemType Directory -Force $simDirectory | Out-Null
$sources = @((Join-Path $projectRoot 'rtl/royale_pkg.sv'))
$sources += Get-ChildItem (Join-Path $projectRoot 'rtl') -Filter '*.sv' | Where-Object Name -ne 'royale_pkg.sv' | ForEach-Object FullName
$sources += Get-ChildItem (Join-Path $projectRoot 'sim') -Filter '*_tb.sv' | ForEach-Object FullName
Push-Location $simDirectory
try {
    if (-not (Test-Path 'modelsim.ini')) {
        & (Join-Path $ModelSimBin 'vmap.exe') -c
        if ($LASTEXITCODE -ne 0) { throw 'Could not create local ModelSim configuration.' }
    }
    if (-not (Test-Path 'work')) { & (Join-Path $ModelSimBin 'vlib.exe') work }
    & (Join-Path $ModelSimBin 'vlog.exe') -sv -work work @sources
    if ($LASTEXITCODE -ne 0) { throw 'SystemVerilog compilation failed.' }
    foreach ($test in @('game_core_tb','input_tb','video_tb')) {
        & (Join-Path $ModelSimBin 'vsim.exe') -c "work.$test" -l "$test.log" -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
        if (-not (Select-String -LiteralPath "$test.log" -SimpleMatch "PASS ${test}:" -Quiet)) {
            throw "Simulation did not reach its success marker: $test"
        }
    }
    Write-Output 'All gameplay, input, and video tests passed.'
} finally { Pop-Location }
