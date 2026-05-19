set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set proj_dir [file join $root_dir "vivado_build"]

create_project fpga_vision_system $proj_dir -part xc7a35tcsg324-1 -force
set_property target_language Verilog [current_project]
set_property source_mgmt_mode None [current_project]

add_files -norecurse [glob [file join $root_dir "rtl" "*.v"]]
update_compile_order -fileset sources_1
set_property top vision_top [get_filesets sources_1]

add_files -fileset sim_1 -norecurse [glob [file join $root_dir "tb" "*.v"]]
add_files -fileset constrs_1 [file join $root_dir "constraints" "ego1_template.xdc"]

update_compile_order -fileset sim_1

puts "Project created at $proj_dir"
puts "Before bitstream generation, verify the OV7670 adapter matches the J5 mapping in constraints/ego1_template.xdc."
