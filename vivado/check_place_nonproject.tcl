set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_dir [file join $root_dir "vivado_reports"]
file mkdir $report_dir

read_verilog [glob [file join $root_dir "rtl" "*.v"]]
read_xdc [file join $root_dir "constraints" "ego1_template.xdc"]

synth_design -top vision_top -part xc7a35tcsg324-1
opt_design
place_design

report_utilization -file [file join $report_dir "nonproject_post_place_utilization.rpt"]
report_timing_summary -file [file join $report_dir "nonproject_post_place_timing_summary.rpt"]

puts "Non-project place check completed."
puts "Reports written to $report_dir"
