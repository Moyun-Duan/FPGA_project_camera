# FPGA Real-Time Vision System

This project implements the core of the proposal product: an FPGA-based real-time
vision pipeline for OV7670 camera input, grayscale/Sobel processing, and VGA output.

Target from proposal:

- Board: EGO1 FPGA development board
- Camera: OV7670, with the stable top using YUV422 luma capture
- Display: VGA
- Toolchain: Vivado 2017, Verilog
- Basic feature: camera frame -> grayscale/Sobel pipeline -> VGA display

## Current Offline Deliverables

The repository contains the parts that can be completed without physical hardware:

- Synthesizable Verilog modules for camera capture, SCCB camera initialization,
  grayscale conversion, 3x3 line-buffer windowing, Gaussian/Sobel filters, frame
  buffer, VGA timing, and top-level integration.
- Icarus Verilog testbenches for the OV7670 byte capture path and image pipeline.
- Vivado project creation Tcl script.
- EGO1 V2.2 constraints for clock, reset, switches, VGA, status LED, and a J5
  expansion-header OV7670 wiring map.
- Hardware bring-up checklist for the first board-debug session.

## Directory Layout

```text
fpga_vision_system/
  constraints/         EGO1 V2.2 XDC and J5 camera-header mapping
  docs/                Requirement extraction and bring-up notes
  rtl/                 Synthesizable Verilog source
  scripts/             Local simulation helper script
  tb/                  Icarus/Vivado Simulator testbenches
  vivado/              Vivado project Tcl
```

## Top-Level Variants

`rtl/vision_top.v` is the stable grayscale/sketch top. It configures the OV7670
for YUV422 and captures only the Y luma byte, so the main demo is not affected by
RGB565 color-format experiments.

`mode_sw[1:0]` selects the stable top display mode:

- `00`: direct grayscale from the Y channel
- `01`: sharpened grayscale
- `10`: white-background sketch with dark edges
- `11`: grayscale cartoon tone bands with dark edges

`style_page_sw` is kept in the port list for board compatibility, but the stable
top no longer uses it to enable color output.

`rtl/vision_rgb565_color_top.v` is an isolated color top. It does not use the
grayscale/Sobel processing pipeline from `vision_top`; it configures the camera
for the same stable YUV422 stream used by `vision_top`, converts YUV to RGB565
inside the color top, then stores those 16-bit color pixels in a color frame
buffer for VGA output. To try it in Vivado, set the top module to
`vision_rgb565_color_top`.

On the color top, `SW2=0` selects the color-channel check page:

- `00`: standard UYVY-to-RGB color with boosted chroma
- `01`: same image with U/V chroma bytes swapped
- `10`: same image with red/green output channels swapped
- `11`: same image with the V chroma direction inverted

`SW2=1` selects the color style page:

- `00`: selected raw color
- `01`: posterized color
- `10`: pixel-cartoon style with 4x4 block sampling
- `11`: anime-style color blocks

After checking the color-channel page on real hardware, set `COLOR_UV_SWAP`,
`COLOR_SWAP_RG`, `COLOR_INVERT_V`, or `COLOR_SWAP_RB` in
`vision_rgb565_color_top.v` so the style page uses the correct interpretation.

The internal processing resolution is 320x240. VGA output is 640x480, using 2x
nearest-neighbor scaling from the processed frame buffer.

## Run Offline Simulation

From this directory:

```powershell
.\scripts\run_iverilog.ps1
```

The script checks:

- OV7670 RGB565 byte pairing, YUV luma extraction, and pixel coordinate generation
- grayscale/window/Gaussian/Sobel pipeline behavior on a synthetic edge image
- full RTL source-set compilation with `vision_top` included

## Create Vivado Project

Open Vivado 2017 Tcl console from `fpga_vision_system` and run:

```tcl
source vivado/create_project.tcl
```

The script assumes the EGO1 V2.2 Artix-7 `xc7a35tcsg324-1` package.

## Run Vivado Synthesis And Implementation

On this machine Vivado 2017.4 is installed at:

```text
E:\program\Vivado-2017\Vivado\2017.4\bin\vivado.bat
```

Run:

```powershell
.\scripts\run_vivado_impl.ps1
```

This runs `synth_1` and `impl_1` through `route_design`, then writes reports under
`vivado_reports/`. Bitstream generation is still skipped until the physical J5
to OV7670 wiring has been verified.

## Hardware Work Still Required

Physical board debugging is still required for:

- Confirming the OV7670 adapter wiring matches the J5 signal order in the XDC.
- Verifying OV7670 SCCB register values with the exact camera module.
- Checking camera `PCLK/HREF/VSYNC` polarity and byte order.
- Replacing fabric-divided clocks with a Vivado Clocking Wizard/MMCM if the course
  requires stricter timing closure.
- Tuning Sobel threshold for the actual camera lighting environment.

## Chinese Project Handoff

For current status, missing work, Vivado 2017.4 usage, simulation, board bring-up,
and post-verification direction, see:

```text
docs/project_status_and_next_steps.md
```
