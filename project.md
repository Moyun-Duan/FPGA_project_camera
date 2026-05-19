# Project Handoff Notes For Codex

## User Intent

The user is working on a Digital System course FPGA project. The proposal requires
an FPGA real-time vision processing system:

- Board: EGO1 FPGA development board
- Camera: OV7670
- Display: VGA
- HDL/toolchain: Verilog + Vivado 2017
- Main function: capture live camera image, process it on FPGA, and display
  grayscale/Sobel/sketch-style output in real time

The user's latest direction is:

- Do as much as possible without physical hardware.
- Vivado synthesis/implementation should be runnable now.
- Hardware-specific issues such as pin constraints, camera polarity, and tuning
  should wait until hardware is available.

## Repository Location

Workspace root:

```text
G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project
```

Project directory created by Codex:

```text
G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
```

Original proposal:

```text
proposal\project_proposal.tex
proposal\project_proposal.pdf
```

## What Has Been Implemented

The current implementation is a synthesizable offline-ready FPGA vision pipeline:

- `rtl/vision_top.v`
  - top-level integration
  - 100 MHz system clock input
  - temporary fabric clock divide for about 25 MHz VGA pixel clock / camera XCLK
  - OV7670 capture path
  - filter pipeline
  - grayscale frame buffer
  - VGA output

- `rtl/ov7670_capture.v`
  - captures OV7670 RGB565 byte stream using `PCLK`, `HREF`, `VSYNC`
  - produces pixel-valid, RGB565 pixel, x/y coordinates

- `rtl/ov7670_init.v`, `rtl/sccb_master.v`, `rtl/ov7670_config_rom.v`
  - write-only SCCB initialization flow
  - register ROM for a basic OV7670 RGB565/QVGA-like setup

- `rtl/rgb565_to_gray.v`
  - fixed-point grayscale conversion

- `rtl/image_window_3x3.v`
  - 3x3 sliding window using line buffers

- `rtl/sobel_pipeline.v`
  - Sobel gradient magnitude and edge thresholding

- `rtl/pixel_filter_pipeline.v`
  - mode selection:
    - `00`: grayscale
    - `01`: 3x3 Gaussian-smoothed grayscale
    - `10`: Sobel magnitude
    - `11`: sketch mode, white background with black edges

- `rtl/frame_buffer_gray.v`
  - dual-clock grayscale frame buffer
  - internal frame size is 320x240

- `rtl/vga_timing.v`
  - 640x480 VGA timing
  - frame buffer is displayed with 2x nearest-neighbor scaling

## Project Scripts

Offline Icarus Verilog simulation:

```powershell
cd G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
.\scripts\run_iverilog.ps1
```

This runs:

- `tb/tb_ov7670_capture.v`
- `tb/tb_pixel_filter_pipeline.v`
- full RTL compile check including `vision_top`

Vivado synthesis and implementation:

```powershell
cd G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
.\scripts\run_vivado_impl.ps1
```

This calls:

```text
vivado/run_synth_impl.tcl
```

It creates/recreates the Vivado project under:

```text
vivado_build/
```

and writes reports under:

```text
vivado_reports/
```

Bitstream generation is intentionally skipped until the OV7670 adapter wiring is
verified against the J5 expansion-header mapping in the XDC.

## Vivado Installation Status

Vivado 2017.4 is installed on this machine at:

```text
E:\program\Vivado-2017\Vivado\2017.4\bin\vivado.bat
```

The script `scripts/run_vivado_impl.ps1` can call this fixed path directly.

The Vivado bin directory was also written into the current user's PATH:

```text
E:\program\Vivado-2017\Vivado\2017.4\bin
```

If a new PowerShell window is opened, this should work:

```powershell
vivado -version
```

In the Codex tool process, PATH inheritance may lag behind, so prefer the project
script or the full Vivado path if direct `vivado` is not recognized.

## Verification Already Run

Icarus Verilog:

```text
PASS: tb_ov7670_capture
PASS: tb_pixel_filter_pipeline, edge responses=8
All offline simulations passed.
```

Vivado 2017.4:

```text
synth_1: complete
impl_1: route_design Complete!
```

Current post-route timing/resource summary:

- WNS: 5.432 ns
- TNS: 0.000 ns
- Hold worst slack: 0.069 ns
- Slice LUTs: 495 / 20800, 2.38%
- Slice Registers: 298 / 41600, 0.72%
- Block RAM Tile: 17.5 / 50, 35.00%
- DSPs: 0 / 90, 0.00%
- Bonded IOB: 35 / 210, 16.67%

Important: these results were produced before the EGO1 V2.2 pin constraints were
filled in and before bitstream generation.

## Constraints Status

Constraint file:

```text
constraints/ego1_template.xdc
```

Currently included:

- timing constraints for `clk_100m`, `cam_pclk`, and generated `pix_clk`
- EGO1 V2.2 `PACKAGE_PIN` assignments for system clock, reset, switches, VGA,
  status LED, and the OV7670 signals mapped to J5. `cam_pclk` is placed on
  J5-20/D15 because that pin is MRCC clock-capable.

Currently not included:

- input/output delays for camera/VGA external timing

Reason: the board pins are now taken from the EGO1 V2.2 manual, but the camera
adapter cable order still has to match the J5 signal order in the XDC.

## Known Warnings / Current Technical Debt

These are known and intentionally deferred unless the user asks to clean them now:

- Vivado reports missing input/output delays. This is expected until board-level
  camera/VGA timing is finalized.
- `cam_siod` uses inferred tri-state behavior for SCCB. Hardware validation may
  require explicit `IOBUF` instantiation depending on Vivado/board practice.
- There are DRC warnings related to async reset interaction with inferred BRAM.
  This can be cleaned later by making reset handling more synchronous around BRAM
  controls.
- `cam_pwdn` is tied constant low, which is intended for normal OV7670 operation.
- `sobel_pipeline` does not use the center pixel `p11`, which is normal for Sobel.
- The current 25 MHz clock is made by fabric divide from 100 MHz. For a polished
  final project, replace it with a Clocking Wizard/MMCM.
- OV7670 register ROM is a reasonable starter configuration, not yet verified
  against the exact camera module.

## Hardware Bring-Up Plan

When hardware arrives, proceed in this order:

1. Confirm EGO1 FPGA part number. Current Tcl assumes:

   ```text
   xc7a35tcsg324-1
   ```

2. Confirm the OV7670 adapter wiring matches `constraints/ego1_template.xdc`.

3. First test VGA output alone, preferably by temporarily replacing framebuffer
   output with a simple pattern.

4. Confirm `cam_xclk` exists on the camera pin using scope/logic analyzer if
   available.

5. Confirm SCCB lines have pull-ups and `camera_config_done` asserts.

6. Probe or observe `cam_pclk`, `cam_href`, `cam_vsync`.

7. Start in grayscale mode `mode_sw = 00`.

8. Check RGB565 byte order and `HREF/VSYNC` polarity.

9. Try Sobel/sketch modes and tune the threshold in `rtl/sobel_pipeline.v`.

10. Only after the J5 camera wiring is confirmed, add bitstream generation to
    `vivado/run_synth_impl.tcl`.

## User Preference

The user wants progress-oriented engineering work, not long theoretical discussion.
For the next Codex session:

- First read this file.
- Do not redo proposal extraction unless necessary.
- Do not spend time on hardware-only questions until hardware is available.
- If asked to continue now, focus on code/report/test improvements that can be
  done offline.
- If asked to prepare for hardware, fill pins only from a reliable EGO1 source,
  never by guessing.
