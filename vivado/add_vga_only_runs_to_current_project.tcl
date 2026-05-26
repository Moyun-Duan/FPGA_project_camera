## Run this script from an already-open Vivado 2017.4 project.
## It adds independent VGA-only and full-system synthesis/implementation runs.
##
## Vivado 2017.4 does not expose a reliable per-run
## STEPS.SYNTH_DESIGN.ARGS.TOP property in project mode. Use independent source
## filesets instead: each source fileset owns its top module.

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]

if {[llength [get_projects -quiet]] == 0} {
    error "No Vivado project is open. Open fpga_vision_system.xpr first, then source this script."
}

set part_name [get_property PART [current_project]]

set vga_top_file [file join $root_dir "rtl" "vga_only_top.v"]
set vga_timing_file [file join $root_dir "rtl" "vga_timing.v"]
set vga_xdc [file join $root_dir "constraints" "vga_only_ego1.xdc"]
set vision_xdc [file join $root_dir "constraints" "ego1_template.xdc"]

## VGA-only design source set.
if {[llength [get_filesets -quiet sources_vga_only]] == 0} {
    create_fileset -srcset sources_vga_only
}
add_files -quiet -norecurse -fileset sources_vga_only [list $vga_timing_file $vga_top_file]
set_property top vga_only_top [get_filesets sources_vga_only]
update_compile_order -fileset sources_vga_only

## Full vision design keeps using the existing sources_1 fileset.
if {[llength [get_filesets -quiet sources_1]] == 0} {
    error "sources_1 fileset is missing. This script expects the original project source set to exist."
}
set_property top vision_top [get_filesets sources_1]
update_compile_order -fileset sources_1

## VGA-only constraints.
if {[llength [get_filesets -quiet constrs_vga_only]] == 0} {
    create_fileset -constrset constrs_vga_only
}
add_files -quiet -fileset constrs_vga_only $vga_xdc
set_property target_constrs_file $vga_xdc [get_filesets constrs_vga_only]

## Full vision constraints.
if {[llength [get_filesets -quiet constrs_vision]] == 0} {
    create_fileset -constrset constrs_vision
}
add_files -quiet -fileset constrs_vision $vision_xdc
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

proc ensure_synth_run {run_name srcset_name constrset_name part_name flow_name strategy_name} {
    if {[llength [get_runs -quiet $run_name]] == 0} {
        create_run $run_name \
            -srcset $srcset_name \
            -constrset $constrset_name \
            -flow $flow_name \
            -strategy $strategy_name \
            -part $part_name
    } else {
        set_property srcset $srcset_name [get_runs $run_name]
        set_property constrset $constrset_name [get_runs $run_name]
    }
}

proc ensure_impl_run {run_name parent_run constrset_name part_name flow_name strategy_name} {
    if {[llength [get_runs -quiet $run_name]] == 0} {
        create_run $run_name \
            -parent_run $parent_run \
            -constrset $constrset_name \
            -flow $flow_name \
            -strategy $strategy_name \
            -part $part_name
    } else {
        set_property parent_run $parent_run [get_runs $run_name]
        set_property constrset $constrset_name [get_runs $run_name]
    }
}

ensure_synth_run synth_vga_only sources_vga_only constrs_vga_only $part_name $synth_flow $synth_strategy
ensure_impl_run impl_vga_only synth_vga_only constrs_vga_only $part_name $impl_flow $impl_strategy

ensure_synth_run synth_vision_top sources_1 constrs_vision $part_name $synth_flow $synth_strategy
ensure_impl_run impl_vision_top synth_vision_top constrs_vision $part_name $impl_flow $impl_strategy

puts "Added or updated runs:"
puts "  synth_vga_only   -> srcset sources_vga_only, top vga_only_top, constraints constrs_vga_only"
puts "  impl_vga_only    -> parent synth_vga_only"
puts "  synth_vision_top -> srcset sources_1, top vision_top, constraints constrs_vision"
puts "  impl_vision_top  -> parent synth_vision_top"
puts ""
puts "If a run already contains old results, reset it before launching again."
