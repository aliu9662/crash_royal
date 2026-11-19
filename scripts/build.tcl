set project_root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $project_root build]
file mkdir $out
set_param general.maxThreads 4
foreach source [glob -nocomplain [file join $project_root rtl *.v]] {
    read_verilog $source
}
foreach source [glob -nocomplain [file join $project_root rtl sprites *.v]] {
    read_verilog $source
}
read_xdc [file join $project_root constraints nexys_a7_100t.xdc]
synth_design -top royale_top -part xc7a100tcsg324-1 -include_dirs [list [file join $project_root rtl]]
source [file join $project_root constraints pixel_timing.tcl]
report_utilization -file [file join $out utilization_synth.rpt]
write_checkpoint -force [file join $out synthesized.dcp]
opt_design
place_design
phys_opt_design
route_design
source [file join $project_root scripts finish_build.tcl]
