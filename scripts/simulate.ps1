param([string]$VivadoBin = 'C:/AMDDesignTools/2026.1/Vivado/bin')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $VivadoBin 'xvlog.bat'))) {
    $compiler = Get-Command xvlog.bat -ErrorAction Stop
    $VivadoBin = Split-Path $compiler.Source -Parent
}
$simDirectory = Join-Path $projectRoot 'build/sim'
New-Item -ItemType Directory -Force $simDirectory | Out-Null
$sources = @((Join-Path $projectRoot 'rtl/royale_pkg.sv'))
$sources += Get-ChildItem (Join-Path $projectRoot 'rtl') -Filter '*.sv' | Where-Object Name -ne 'royale_pkg.sv' | ForEach-Object FullName
$sources += Get-ChildItem (Join-Path $projectRoot 'sim') -Filter '*_tb.sv' | ForEach-Object FullName
Push-Location $simDirectory
try {
    & (Join-Path $VivadoBin 'xvlog.bat') --sv @sources
    if ($LASTEXITCODE -ne 0) { throw 'SystemVerilog compilation failed.' }
    foreach ($test in @('game_core_tb','input_tb','video_tb')) {
        & (Join-Path $VivadoBin 'xelab.bat') $test -s $test
        if ($LASTEXITCODE -ne 0) { throw "Test elaboration failed: $test" }
        & (Join-Path $VivadoBin 'xsim.bat') $test -runall -log "$test.log"
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
        if (-not (Select-String -LiteralPath "$test.log" -SimpleMatch "PASS ${test}:" -Quiet)) {
            throw "Simulation did not reach its success marker: $test"
        }
    }
    Write-Output 'All gameplay, input, and video tests passed.'
} finally { Pop-Location }
