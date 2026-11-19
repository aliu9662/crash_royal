# Finalize a fully routed design; also usable after open_checkpoint routed.dcp.
set project_root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $project_root build]
set setup_path [get_timing_paths -delay_type max -max_paths 1]
if {[llength $setup_path] && [get_property SLACK $setup_path] < 0} {
    # Post-route optimization reroutes its edits and can close small violations.
    phys_opt_design -directive AggressiveExplore
}
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_timing -delay_type max -max_paths 20 -file [file join $out critical_paths.rpt]
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
