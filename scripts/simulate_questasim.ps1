param([string]$QuestaBin = 'C:/questasim64_2024.1/win64')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $QuestaBin 'vsim.exe'))) {
    $tool = Get-Command vsim.exe -ErrorAction Stop
    $QuestaBin = Split-Path $tool.Source -Parent
}
$simDirectory = Join-Path $projectRoot 'build/questasim'
New-Item -ItemType Directory -Force $simDirectory | Out-Null
$rtlDirectory = Join-Path $projectRoot 'rtl'
$sources = @(Get-ChildItem $rtlDirectory -Filter '*.v' | ForEach-Object FullName)
$spriteDir = Join-Path $rtlDirectory 'sprites'
if (Test-Path $spriteDir) {
    $sources += Get-ChildItem $spriteDir -Filter '*.v' -ErrorAction SilentlyContinue | ForEach-Object FullName
}
$sources += Get-ChildItem (Join-Path $projectRoot 'sim') -Filter '*_tb.v' | ForEach-Object FullName
Push-Location $simDirectory
try {
    if (-not (Test-Path 'work')) {
        & (Join-Path $QuestaBin 'vlib.exe') work
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed.' }
    }
    & (Join-Path $QuestaBin 'vlog.exe') -vlog01compat "+incdir+$rtlDirectory" -work work @sources
    if ($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed.' }
    foreach ($test in @('game_core_tb','input_tb','video_tb')) {
        & (Join-Path $QuestaBin 'vsim.exe') -c "work.$test" -l "$test.log" -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
        if (-not (Select-String -LiteralPath "$test.log" -SimpleMatch "PASS ${test}:" -Quiet)) {
            throw "Simulation did not reach its success marker: $test"
        }
    }
    Write-Output 'All gameplay, input, and video tests passed.'
} finally { Pop-Location }
