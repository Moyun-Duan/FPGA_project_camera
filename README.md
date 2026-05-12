# FPGA Real-Time Vision System

This project implements the core of the proposal product: an FPGA-based real-time
vision pipeline for OV7670 camera input, grayscale/Sobel processing, and VGA output.

Target from proposal:

- Board: EGO1 FPGA development board
- Camera: OV7670, preferably RGB565 output
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
- EGO1 constraints template with explicit TODO pin placeholders.
- Hardware bring-up checklist for the first board-debug session.

## Directory Layout

```text
fpga_vision_system/
  constraints/         XDC template, pins must be filled from the EGO1 schematic
  docs/                Requirement extraction and bring-up notes
  rtl/                 Synthesizable Verilog source
  scripts/             Local simulation helper script
  tb/                  Icarus/Vivado Simulator testbenches
  vivado/              Vivado project Tcl
```

## Display Modes

`mode_sw[1:0]` selects the frame written into the display buffer:

- `00`: grayscale
- `01`: 3x3 Gaussian-smoothed grayscale
- `10`: Sobel gradient magnitude
- `11`: sketch style, white background with dark edges

The internal processing resolution is 320x240. VGA output is 640x480, using 2x
nearest-neighbor scaling from the processed frame buffer.

## Run Offline Simulation

From this directory:

```powershell
.\scripts\run_iverilog.ps1
```

The script checks:

- OV7670 RGB565 byte pairing and pixel coordinate generation
- grayscale/window/Gaussian/Sobel pipeline behavior on a synthetic edge image
- full RTL source-set compilation with `vision_top` included

## Create Vivado Project

Open Vivado 2017 Tcl console from `fpga_vision_system` and run:

```tcl
source vivado/create_project.tcl
```

The script assumes an Artix-7 `xc7a35tcsg324-1`, which is commonly used by EGO1
class boards. Confirm the exact part number in your lab board documentation before
bitstream generation.

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
`vivado_reports/`. Bitstream generation is skipped until EGO1 pin constraints are
verified.

## Hardware Work Still Required

Physical board debugging is still required for:

- Confirming all EGO1 pin constraints.
- Verifying OV7670 SCCB register values with the exact camera module.
- Checking camera `PCLK/HREF/VSYNC` polarity and byte order.
- Replacing fabric-divided clocks with a Vivado Clocking Wizard/MMCM if the course
  requires stricter timing closure.
- Tuning Sobel threshold for the actual camera lighting environment.
