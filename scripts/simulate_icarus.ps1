param([string]$IcarusBin = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $IcarusBin) {
    $portableBin = Join-Path $projectRoot 'build/tools/mingw64/bin'
    if (Test-Path (Join-Path $portableBin 'iverilog.exe')) { $IcarusBin = $portableBin }
    else { $IcarusBin = Split-Path (Get-Command iverilog -ErrorAction Stop).Source -Parent }
}
$originalPath = $env:PATH
$env:PATH = "$IcarusBin;C:/msys64/mingw64/bin;$originalPath"
$simDirectory = Join-Path $projectRoot 'build/icarus'
New-Item -ItemType Directory -Force $simDirectory | Out-Null
$rtlDirectory = Join-Path $projectRoot 'rtl'
$sources = @(Get-ChildItem $rtlDirectory -Filter '*.v' | ForEach-Object FullName)
$sources += Get-ChildItem (Join-Path $projectRoot 'sim') -Filter '*_tb.v' | ForEach-Object FullName
Push-Location $simDirectory
try {
    foreach ($test in @('game_core_tb','input_tb','video_tb')) {
        & (Join-Path $IcarusBin 'iverilog.exe') -g2001 -I $rtlDirectory -s $test -o "$test.vvp" @sources 2> "$test.compile.log"
        if ($LASTEXITCODE -ne 0) { Get-Content "$test.compile.log"; throw "Compilation failed: $test" }
        & (Join-Path $IcarusBin 'vvp.exe') "$test.vvp" | Tee-Object -FilePath "$test.log"
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
        if (-not (Select-String -LiteralPath "$test.log" -SimpleMatch "PASS ${test}:" -Quiet)) {
            throw "Simulation did not reach its success marker: $test"
        }
    }
    Write-Output 'All gameplay, input, and video tests passed.'
} finally { Pop-Location; $env:PATH = $originalPath }
