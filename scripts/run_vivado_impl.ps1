$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$VivadoCandidates = @(
    "E:\program\Vivado-2017\Vivado\2017.4\bin\vivado.bat",
    "C:\Xilinx\Vivado\2017.4\bin\vivado.bat",
    "C:\Program Files\Xilinx\Vivado\2017.4\bin\vivado.bat"
)

$Vivado = $null
foreach ($Candidate in $VivadoCandidates) {
    if (Test-Path $Candidate) {
        $Vivado = $Candidate
        break
    }
}

if (-not $Vivado) {
    $Cmd = Get-Command vivado -ErrorAction SilentlyContinue
    if ($Cmd) {
        $Vivado = $Cmd.Source
    }
}

if (-not $Vivado) {
    throw "Vivado 2017.4 was not found. Install it or add vivado.bat to PATH."
}

& $Vivado -mode batch -source (Join-Path $Root "vivado/run_synth_impl.tcl")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
