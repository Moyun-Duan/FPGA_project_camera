# Requirements Extracted From Proposal

## Must Have

- Interface OV7670 camera to FPGA and receive stable image data.
- Implement grayscale conversion and Sobel edge detection in FPGA logic.
- Output processed video to VGA/HDMI display in real time.
- Target frame rate is at least 30 fps.

## Advanced Goals

- Switch between multiple filter modes using buttons or slide switches.
- Optional face contour highlight based on simple thresholding.
- Optional hand gesture recognition based on connected-region features.

## Implemented Offline Scope

The current project implements the must-have digital pipeline except for physical
pin validation:

- OV7670 RGB565 byte capture.
- SCCB write-only initialization state machine and register ROM.
- 320x240 streaming grayscale conversion.
- 3x3 line-buffer window generation.
- Gaussian smoothing and Sobel edge detection.
- Multi-mode selection.
- 320x240 processed frame buffer with 640x480 VGA readout.
- Testbenches for key logic blocks.

## Assumptions

- OV7670 is configured for RGB565 and QVGA-like timing.
- Camera `VSYNC` is active high for frame reset and `HREF` is active high for valid
  row data.
- VGA DAC on the board accepts 4 bits per color channel.
- The EGO1 board part is treated as `xc7a35tcsg324-1` until confirmed.

These assumptions are intentionally documented because they must be verified during
the first hardware session.
