## EGO1 V2.2 constraints for vision_top.
## Source: EGo1_V2.2/source/EGo1.rst from AJetfire/EES.
## OV7670 signals are assigned to J5 expansion header pins in the order below;
## match the camera adapter wiring to these J5 positions before programming.

## System clock, expected 100 MHz
set_property PACKAGE_PIN P17 [get_ports clk_100m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100m]
create_clock -period 10.000 -name clk_100m [get_ports clk_100m]

## Camera PCLK is board/module dependent. 25 MHz is the current OV7670 QVGA
## target because cam_xclk is fixed to clk_100m / 4.
create_clock -period 40.000 -name cam_pclk [get_ports cam_pclk]

## Temporary fabric-divided VGA pixel clock. Camera XCLK is also fixed to
## clk_100m / 4 = 25 MHz in rtl/vision_top.v after hardware A/B testing.
## Replace both with Clocking Wizard/MMCM before final bitstream if stricter
## timing practice is required.
create_generated_clock -name pix_clk -source [get_ports clk_100m] -divide_by 4 [get_pins {clk_div_reg[1]/Q}]

## Reset, active low
set_property PACKAGE_PIN P15 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

## Mode switches
set_property PACKAGE_PIN R1 [get_ports {mode_sw[0]}]
set_property PACKAGE_PIN N4 [get_ports {mode_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mode_sw[*]}]

## Style page switch. SW2=0 keeps the original four modes; SW2=1 enables
## added color modes for mode_sw 00/01.
set_property PACKAGE_PIN M4 [get_ports style_page_sw]
set_property IOSTANDARD LVCMOS33 [get_ports style_page_sw]

## Camera configuration status LED, high lights D1_0.
set_property PACKAGE_PIN K3 [get_ports camera_config_done]
set_property IOSTANDARD LVCMOS33 [get_ports camera_config_done]

## VGA output
set_property PACKAGE_PIN F5 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN C6 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN B7 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN E6 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN E5 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN E7 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN D7 [get_ports vga_hsync]
set_property PACKAGE_PIN C4 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_*}]

## OV7670 camera on J5 expansion header.
## cam_pclk uses J5-19, an MRCC clock-capable pin. Do not move it to a regular IO
## unless the clocking strategy is also changed.
set_property PACKAGE_PIN B16 [get_ports cam_pwdn]       ;# J5-1
set_property PACKAGE_PIN B17 [get_ports cam_vsync]      ;# J5-2
set_property PACKAGE_PIN A15 [get_ports cam_href]       ;# J5-3
set_property PACKAGE_PIN A16 [get_ports {cam_data[0]}]  ;# J5-4
set_property PACKAGE_PIN A13 [get_ports {cam_data[1]}]  ;# J5-5
set_property PACKAGE_PIN A14 [get_ports {cam_data[2]}]  ;# J5-6
set_property PACKAGE_PIN B18 [get_ports {cam_data[3]}]  ;# J5-7
set_property PACKAGE_PIN A18 [get_ports {cam_data[4]}]  ;# J5-8
set_property PACKAGE_PIN F13 [get_ports {cam_data[5]}]  ;# J5-9
set_property PACKAGE_PIN F14 [get_ports {cam_data[6]}]  ;# J5-10
set_property PACKAGE_PIN B13 [get_ports {cam_data[7]}]  ;# J5-11
set_property PACKAGE_PIN B14 [get_ports cam_xclk]       ;# J5-12
set_property PACKAGE_PIN D14 [get_ports cam_sioc]       ;# J5-13
set_property PACKAGE_PIN C14 [get_ports cam_siod]       ;# J5-14
set_property PACKAGE_PIN B11 [get_ports cam_reset_n]    ;# J5-15
set_property PACKAGE_PIN D15 [get_ports cam_pclk]       ;# J5-19, IO_L12P_T1_MRCC_15
set_property IOSTANDARD LVCMOS33 [get_ports {cam_*}]
