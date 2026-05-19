create_project j5_pin_query ./vivado_pin_query -part xc7a35tcsg324-1 -force
set_property design_mode PinPlanning [current_fileset]
open_io_design -name io_1

set j5_pins {
    B16 B17 A15 A16 A13 A14 B18 A18
    F13 F14 B13 B14 D14 C14 B11 A11
    D12 C12 E15 D15 H16 G16 J15 H15
    G12 F12 H14 G14 E17 D17 G17 F17
}

foreach pin $j5_pins {
    set pkg_pin [get_package_pins $pin]
    puts [format "%-4s FUNC=%s" $pin [get_property PIN_FUNC $pkg_pin]]
}
