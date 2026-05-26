set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set proj_dir [file join $root_dir "vivado_vga_only_build"]

create_project fpga_vga_only $proj_dir -part xc7a35tcsg324-1 -force
set_property target_language Verilog [current_project]
set_property source_mgmt_mode None [current_project]

add_files -norecurse [list \
    [file join $root_dir "rtl" "vga_timing.v"] \
    [file join $root_dir "rtl" "vga_only_top.v"] \
]
update_compile_order -fileset sources_1
set_property top vga_only_top [get_filesets sources_1]

add_files -fileset constrs_1 [file join $root_dir "constraints" "vga_only_ego1.xdc"]

puts "VGA-only project created at $proj_dir"
puts "Top module: vga_only_top"
puts "Constraint file: constraints/vga_only_ego1.xdc"
