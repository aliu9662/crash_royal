# Apply after synth_design: the FD* cells do not exist during RTL elaboration.
# Only pixel data paths use four clocks: both source and destination registers
# have the same one-in-four pixel enable. Control/CE/reset paths stay at 100 MHz.
# Pin-specific endpoints prevent relaxing the always-active CE and reset checks.
set pixel_source_cells [get_cells -hier -filter {REF_NAME =~ FD* && (NAME =~ *view_*_reg* || NAME =~ dc/hCount_reg* || NAME =~ dc/vCount_reg*)}]
set pixel_dest_cells [get_cells -hier -filter {REF_NAME =~ FD* && (NAME =~ *vgaR_reg* || NAME =~ *vgaG_reg* || NAME =~ *vgaB_reg*)}]
set pixel_source_pins [get_pins -of_objects $pixel_source_cells -filter {REF_PIN_NAME == C}]
set pixel_dest_pins [get_pins -of_objects $pixel_dest_cells -filter {REF_PIN_NAME == D}]
if {[llength $pixel_source_pins] == 0 || [llength $pixel_dest_pins] == 0} {
    error "Pixel timing registers were not found; check the scoped multicycle paths."
}
set_multicycle_path 4 -setup -from $pixel_source_pins -to $pixel_dest_pins
set_multicycle_path 3 -hold -from $pixel_source_pins -to $pixel_dest_pins
