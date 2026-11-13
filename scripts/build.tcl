set project_root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $project_root build]
file mkdir $out
set_param general.maxThreads 4
foreach source [glob [file join $project_root rtl *.v]] {
    read_verilog -include_dirs [list [file join $project_root rtl]] $source
}
read_xdc [file join $project_root constraints nexys_a7_100t.xdc]
synth_design -top royale_top -part xc7a100tcsg324-1
report_utilization -file [file join $out utilization_synth.rpt]
write_checkpoint -force [file join $out synthesized.dcp]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint -force [file join $out routed.dcp]
set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_path] == 0 || [get_property SLACK $setup_path] < 0} {
    error "Setup timing failed. Read build/timing.rpt."
}
if {[llength $hold_path] == 0 || [get_property SLACK $hold_path] < 0} {
    error "Hold timing failed. Read build/timing.rpt."
}
set violations [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $violations] > 0} { error "DRC failed. Read build/drc.rpt." }
write_bitstream -force [file join $out royale_top.bit]
puts "BUILD PASS: [file join $out royale_top.bit]"
