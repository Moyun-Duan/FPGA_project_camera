set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_dir [file join $root_dir "vivado_vga_only_reports"]
file mkdir $report_dir

source [file join $script_dir "create_vga_only_project.tcl"]

launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_drc -file [file join $report_dir "post_synth_drc.txt"]

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1

report_timing_summary -file [file join $report_dir "post_impl_timing_summary.txt"]
report_utilization -file [file join $report_dir "post_impl_utilization.txt"]
report_drc -file [file join $report_dir "post_impl_drc.txt"]

puts "VGA-only bitstream:"
puts [file join $root_dir "vivado_vga_only_build" "fpga_vga_only.runs" "impl_1" "vga_only_top.bit"]
puts "Reports:"
puts $report_dir
