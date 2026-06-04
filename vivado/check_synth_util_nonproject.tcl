set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_dir [file join $root_dir "vivado_reports"]
file mkdir $report_dir

read_verilog [glob [file join $root_dir "rtl" "*.v"]]
read_xdc [file join $root_dir "constraints" "ego1_template.xdc"]

synth_design -top vision_top -part xc7a35tcsg324-1

report_utilization -file [file join $report_dir "nonproject_post_synth_utilization.rpt"]
report_utilization -hierarchical -file [file join $report_dir "nonproject_post_synth_utilization_hier.rpt"]

puts "Non-project synthesis utilization reports written to $report_dir"
