# Hardware Bring-Up Checklist

## 1. Confirm Board-Level Constraints

Before generating a bitstream, confirm `constraints/ego1_template.xdc` against the
actual board and camera adapter:

- 100 MHz system clock pin from EGO1 V2.2: `P17`
- Reset pin from EGO1 V2.2: `P15`
- Slide switches used for `mode_sw`
- VGA RGB, HSYNC, VSYNC pins
- OV7670 `PCLK`, `VSYNC`, `HREF`, `D[7:0]`, `XCLK`, `SIOD`, `SIOC`, `RESET`, `PWDN`
  wired to the J5 positions shown in the XDC comments. `PCLK` must use J5-19
  because it is the MRCC clock-capable pin used by the current RTL.

Do not guess the camera adapter cable order. Wrong camera power or IO pin
assignments can damage hardware.

## 2. First Bitstream Strategy

Use this order when hardware becomes available:

1. Program a VGA-only test pattern.
2. Check VGA monitor lock at 640x480.
3. Enable OV7670 XCLK and check it with an oscilloscope or logic analyzer.
4. Enable SCCB initialization and verify `config_done`.
5. Probe `PCLK`, `HREF`, and `VSYNC`.
6. Display grayscale mode first.
7. Tune Sobel threshold and switch to edge modes.

## 3. Expected Clocking

The current top-level uses fabric-divided clocks from 100 MHz:

- VGA pixel clock: approximately 25 MHz (`clk_100m / 4`)
- OV7670 XCLK: selected by SW4:
  - SW4=0: approximately 12.5 MHz (`clk_100m / 8`)
  - SW4=1: approximately 25 MHz (`clk_100m / 4`)

Use SW4=0 during bring-up to improve margin with DuPont-wire parallel camera
connections. Use SW4=1 only to compare whether higher frame rate improves blur
or exposure stability. Toggle SW4 before pressing RESET so the camera is
re-initialized with a stable XCLK. A Clocking Wizard/MMCM is recommended before
final timing closure.

## 4. Common Hardware Issues

- Wrong RGB565 byte order: colors or grayscale look inverted/random.
- `VSYNC` polarity mismatch: frame never starts or constantly resets.
- `HREF` polarity mismatch: pixel counter increments outside active rows.
- SCCB pull-ups missing: camera registers are not configured.
- Camera module outputs YUV instead of RGB565: grayscale values look strange.
- Sobel threshold too high/low for lighting: edge output appears blank or saturated.
