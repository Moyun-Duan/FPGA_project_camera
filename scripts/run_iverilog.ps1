$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root "sim_build"
New-Item -ItemType Directory -Force $Build | Out-Null

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_ov7670_capture.vvp") `
  (Join-Path $Root "tb/tb_ov7670_capture.v") `
  (Join-Path $Root "rtl/ov7670_capture.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_ov7670_capture.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_canny_threshold.vvp") `
  (Join-Path $Root "tb/tb_canny_threshold.v") `
  (Join-Path $Root "rtl/canny_pipeline.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_canny_threshold.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_pixel_filter_pipeline.vvp") `
  (Join-Path $Root "tb/tb_pixel_filter_pipeline.v") `
  (Join-Path $Root "rtl/rgb565_to_gray.v") `
  (Join-Path $Root "rtl/image_window_3x3.v") `
  (Join-Path $Root "rtl/canny_pipeline.v") `
  (Join-Path $Root "rtl/pixel_filter_pipeline.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_pixel_filter_pipeline.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_edge_noise_rejection.vvp") `
  (Join-Path $Root "tb/tb_edge_noise_rejection.v") `
  (Join-Path $Root "rtl/rgb565_to_gray.v") `
  (Join-Path $Root "rtl/image_window_3x3.v") `
  (Join-Path $Root "rtl/canny_pipeline.v") `
  (Join-Path $Root "rtl/pixel_filter_pipeline.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_edge_noise_rejection.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_edge_short_streak_rejection.vvp") `
  (Join-Path $Root "tb/tb_edge_short_streak_rejection.v") `
  (Join-Path $Root "rtl/rgb565_to_gray.v") `
  (Join-Path $Root "rtl/image_window_3x3.v") `
  (Join-Path $Root "rtl/canny_pipeline.v") `
  (Join-Path $Root "rtl/pixel_filter_pipeline.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_edge_short_streak_rejection.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

iverilog -g2005-sv -Wall -o (Join-Path $Build "tb_person_edge_highlight.vvp") `
  (Join-Path $Root "tb/tb_person_edge_highlight.v") `
  (Join-Path $Root "rtl/rgb565_to_gray.v") `
  (Join-Path $Root "rtl/image_window_3x3.v") `
  (Join-Path $Root "rtl/canny_pipeline.v") `
  (Join-Path $Root "rtl/pixel_filter_pipeline.v")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

vvp (Join-Path $Build "tb_person_edge_highlight.vvp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$RtlFiles = Get-ChildItem (Join-Path $Root "rtl") -Filter "*.v" | ForEach-Object { $_.FullName }
iverilog -g2005-sv -Wall -o (Join-Path $Build "vision_top_compile.vvp") $RtlFiles
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "All offline simulations passed."
