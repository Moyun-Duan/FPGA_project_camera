## EGO1 constraint template.
## Fill PACKAGE_PIN values from the official EGO1 schematic/master XDC.
## The placeholders are intentionally invalid until verified.

## System clock, expected 100 MHz
# set_property PACKAGE_PIN <CLK100_PIN> [get_ports clk_100m]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_100m]
create_clock -period 10.000 -name clk_100m [get_ports clk_100m]

## Camera PCLK is board/module dependent. 24 MHz is a conservative OV7670 QVGA
## bring-up target and can be adjusted after probing the real module.
create_clock -period 41.667 -name cam_pclk [get_ports cam_pclk]

## Temporary fabric-divided VGA/camera XCLK. Replace with Clocking Wizard/MMCM
## before final bitstream if stricter timing practice is required.
create_generated_clock -name pix_clk -source [get_ports clk_100m] -divide_by 4 [get_pins clk_div_reg[1]/Q]

## Reset, active low
# set_property PACKAGE_PIN <RESET_N_PIN> [get_ports reset_n]
# set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

## Mode switches
# set_property PACKAGE_PIN <SW0_PIN> [get_ports {mode_sw[0]}]
# set_property PACKAGE_PIN <SW1_PIN> [get_ports {mode_sw[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {mode_sw[*]}]

## VGA output
# set_property PACKAGE_PIN <VGA_R0_PIN> [get_ports {vga_r[0]}]
# set_property PACKAGE_PIN <VGA_R1_PIN> [get_ports {vga_r[1]}]
# set_property PACKAGE_PIN <VGA_R2_PIN> [get_ports {vga_r[2]}]
# set_property PACKAGE_PIN <VGA_R3_PIN> [get_ports {vga_r[3]}]
# set_property PACKAGE_PIN <VGA_G0_PIN> [get_ports {vga_g[0]}]
# set_property PACKAGE_PIN <VGA_G1_PIN> [get_ports {vga_g[1]}]
# set_property PACKAGE_PIN <VGA_G2_PIN> [get_ports {vga_g[2]}]
# set_property PACKAGE_PIN <VGA_G3_PIN> [get_ports {vga_g[3]}]
# set_property PACKAGE_PIN <VGA_B0_PIN> [get_ports {vga_b[0]}]
# set_property PACKAGE_PIN <VGA_B1_PIN> [get_ports {vga_b[1]}]
# set_property PACKAGE_PIN <VGA_B2_PIN> [get_ports {vga_b[2]}]
# set_property PACKAGE_PIN <VGA_B3_PIN> [get_ports {vga_b[3]}]
# set_property PACKAGE_PIN <VGA_HS_PIN> [get_ports vga_hsync]
# set_property PACKAGE_PIN <VGA_VS_PIN> [get_ports vga_vsync]
# set_property IOSTANDARD LVCMOS33 [get_ports {vga_*}]

## OV7670 camera
# set_property PACKAGE_PIN <CAM_PCLK_PIN> [get_ports cam_pclk]
# set_property PACKAGE_PIN <CAM_VSYNC_PIN> [get_ports cam_vsync]
# set_property PACKAGE_PIN <CAM_HREF_PIN> [get_ports cam_href]
# set_property PACKAGE_PIN <CAM_D0_PIN> [get_ports {cam_data[0]}]
# set_property PACKAGE_PIN <CAM_D1_PIN> [get_ports {cam_data[1]}]
# set_property PACKAGE_PIN <CAM_D2_PIN> [get_ports {cam_data[2]}]
# set_property PACKAGE_PIN <CAM_D3_PIN> [get_ports {cam_data[3]}]
# set_property PACKAGE_PIN <CAM_D4_PIN> [get_ports {cam_data[4]}]
# set_property PACKAGE_PIN <CAM_D5_PIN> [get_ports {cam_data[5]}]
# set_property PACKAGE_PIN <CAM_D6_PIN> [get_ports {cam_data[6]}]
# set_property PACKAGE_PIN <CAM_D7_PIN> [get_ports {cam_data[7]}]
# set_property PACKAGE_PIN <CAM_XCLK_PIN> [get_ports cam_xclk]
# set_property PACKAGE_PIN <CAM_SIOC_PIN> [get_ports cam_sioc]
# set_property PACKAGE_PIN <CAM_SIOD_PIN> [get_ports cam_siod]
# set_property PACKAGE_PIN <CAM_RESET_N_PIN> [get_ports cam_reset_n]
# set_property PACKAGE_PIN <CAM_PWDN_PIN> [get_ports cam_pwdn]
# set_property IOSTANDARD LVCMOS33 [get_ports {cam_*}]
