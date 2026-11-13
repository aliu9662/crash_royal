set project_root [file normalize [file join [file dirname [info script]] ..]]
set bitfile [file join $project_root build royale_top.bit]
if {![file exists $bitfile]} {
    error "Bitstream not found: $bitfile (run scripts/build.tcl first)."
}
open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set device [lindex [get_hw_devices] 0]
current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
puts "PROGRAM PASS: $bitfile"
