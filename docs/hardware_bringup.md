# Hardware Bring-Up Checklist

## 1. Confirm Board-Level Constraints

Before generating a bitstream, fill `constraints/ego1_template.xdc` from the EGO1
schematic or official master XDC:

- 100 MHz system clock pin
- Reset key or switch pin
- Slide switches used for `mode_sw`
- VGA RGB, HSYNC, VSYNC pins
- OV7670 `PCLK`, `VSYNC`, `HREF`, `D[7:0]`, `XCLK`, `SIOD`, `SIOC`, `RESET`, `PWDN`

Do not guess these pins. Wrong camera power or IO pin assignments can damage hardware.

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

The offline top-level uses a simple divide-by-4 clock from 100 MHz to generate
approximately 25 MHz for VGA and OV7670 XCLK. This is adequate for early classroom
bring-up, but a Clocking Wizard/MMCM is recommended before final timing closure.

## 4. Common Hardware Issues

- Wrong RGB565 byte order: colors or grayscale look inverted/random.
- `VSYNC` polarity mismatch: frame never starts or constantly resets.
- `HREF` polarity mismatch: pixel counter increments outside active rows.
- SCCB pull-ups missing: camera registers are not configured.
- Camera module outputs YUV instead of RGB565: grayscale values look strange.
- Sobel threshold too high/low for lighting: edge output appears blank or saturated.
