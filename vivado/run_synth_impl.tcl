set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_dir [file join $root_dir "vivado_reports"]
file mkdir $report_dir

source [file join $script_dir "create_project.tcl"]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 status: $synth_status"
if {[string first "Complete" $synth_status] < 0} {
    error "synth_1 did not complete successfully"
}

open_run synth_1
report_utilization -file [file join $report_dir "post_synth_utilization.rpt"]
report_timing_summary -file [file join $report_dir "post_synth_timing_summary.rpt"]

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "impl_1 status: $impl_status"
if {[string first "Complete" $impl_status] < 0} {
    error "impl_1 did not complete successfully"
}

open_run impl_1
report_utilization -file [file join $report_dir "post_route_utilization.rpt"]
report_timing_summary -file [file join $report_dir "post_route_timing_summary.rpt"]

puts "Synthesis and implementation completed."
puts "Reports written to $report_dir"
puts "Bitstream generation is intentionally skipped until EGO1 pin constraints are verified."
