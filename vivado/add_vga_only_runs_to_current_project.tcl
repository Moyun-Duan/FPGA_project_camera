## Run this script from an already-open Vivado project.
## It adds independent VGA-only and full-system synthesis/implementation runs.

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]

if {[llength [get_projects -quiet]] == 0} {
    error "No Vivado project is open. Open fpga_vision_system.xpr first, then source this script."
}

set part_name [get_property PART [current_project]]

set src_fileset [get_filesets sources_1]

set vga_top_file [file join $root_dir "rtl" "vga_only_top.v"]
set vga_timing_file [file join $root_dir "rtl" "vga_timing.v"]
set vga_xdc [file join $root_dir "constraints" "vga_only_ego1.xdc"]
set vision_xdc [file join $root_dir "constraints" "ego1_template.xdc"]

foreach src_file [list $vga_timing_file $vga_top_file] {
    if {[llength [get_files -quiet $src_file]] == 0} {
        add_files -norecurse -fileset $src_fileset $src_file
    }
}

if {[llength [get_filesets -quiet constrs_vga_only]] == 0} {
    create_fileset -constrset constrs_vga_only
}
if {[llength [get_files -quiet $vga_xdc]] == 0} {
    add_files -fileset constrs_vga_only $vga_xdc
}
set_property target_constrs_file $vga_xdc [get_filesets constrs_vga_only]

if {[llength [get_filesets -quiet constrs_vision]] == 0} {
    create_fileset -constrset constrs_vision
}
if {[llength [get_files -quiet $vision_xdc]] == 0} {
    add_files -fileset constrs_vision $vision_xdc
}
set_property target_constrs_file $vision_xdc [get_filesets constrs_vision]

set synth_flow "Vivado Synthesis 2017"
set synth_strategy "Vivado Synthesis Defaults"
if {[llength [get_runs -quiet synth_1]] != 0} {
    set synth_flow [get_property FLOW [get_runs synth_1]]
    set synth_strategy [get_property STRATEGY [get_runs synth_1]]
}

set impl_flow "Vivado Implementation 2017"
set impl_strategy "Vivado Implementation Defaults"
if {[llength [get_runs -quiet impl_1]] != 0} {
    set impl_flow [get_property FLOW [get_runs impl_1]]
    set impl_strategy [get_property STRATEGY [get_runs impl_1]]
}

proc ensure_synth_run {run_name top_name constrset_name part_name flow_name strategy_name} {
    if {[llength [get_runs -quiet $run_name]] == 0} {
        create_run $run_name \
            -flow $flow_name \
            -strategy $strategy_name \
            -constrset $constrset_name \
            -part $part_name
    }

    set_property STEPS.SYNTH_DESIGN.ARGS.TOP $top_name [get_runs $run_name]
}

proc ensure_impl_run {run_name parent_run constrset_name part_name flow_name strategy_name} {
    if {[llength [get_runs -quiet $run_name]] == 0} {
        create_run $run_name \
            -parent_run $parent_run \
            -flow $flow_name \
            -strategy $strategy_name \
            -constrset $constrset_name \
            -part $part_name
    }
}

ensure_synth_run synth_vga_only vga_only_top constrs_vga_only $part_name $synth_flow $synth_strategy
ensure_impl_run impl_vga_only synth_vga_only constrs_vga_only $part_name $impl_flow $impl_strategy

ensure_synth_run synth_vision_top vision_top constrs_vision $part_name $synth_flow $synth_strategy
ensure_impl_run impl_vision_top synth_vision_top constrs_vision $part_name $impl_flow $impl_strategy

puts "Added or updated runs:"
puts "  synth_vga_only  -> top vga_only_top, constraints constrs_vga_only"
puts "  impl_vga_only   -> parent synth_vga_only"
puts "  synth_vision_top -> top vision_top, constraints constrs_vision"
puts "  impl_vision_top  -> parent synth_vision_top"
puts ""
puts "Use reset_run <run_name> before rerunning a run that already has old results."
