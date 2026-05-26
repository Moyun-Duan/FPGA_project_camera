## EGO1 V2.2 VGA-only constraints for vga_only_top.
## Use this XDC only with rtl/vga_only_top.v. Do not enable ego1_template.xdc
## in the same VGA-only verification project.

## System clock, expected 100 MHz.
set_property PACKAGE_PIN P17 [get_ports clk_100m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100m]
create_clock -period 10.000 -name clk_100m [get_ports clk_100m]

## Fabric-divided 25 MHz pixel clock: pix_clk = clk_100m / 4.
create_generated_clock -name pix_clk -source [get_ports clk_100m] -divide_by 4 [get_pins {clk_div_reg[1]/Q}]

## Reset, active low.
set_property PACKAGE_PIN P15 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

## Pattern select switches.
set_property PACKAGE_PIN R1 [get_ports {mode_sw[0]}]
set_property PACKAGE_PIN N4 [get_ports {mode_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mode_sw[*]}]

## Heartbeat LED. It should blink while clk_100m is running.
set_property PACKAGE_PIN K3 [get_ports test_led]
set_property IOSTANDARD LVCMOS33 [get_ports test_led]

## VGA output.
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

## Common EGO1/Artix-7 configuration-voltage settings.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
