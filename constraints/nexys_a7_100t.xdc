# Pin assignments verified against Digilent's Nexys-A7-100T-Master.xdc:
# https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -add -name sys_clk -period 10.000 [get_ports CLK100MHZ]
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports CPU_RESETN]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports BTNC]
set sw_pins {J15 L16 M13 R15 R17 T18 U18 R13 T8 U8 R16 T13 H6 U12 U11 V10}
set led_pins {H17 K15 J13 N14 R18 V17 U17 U16 V16 T15 U14 T16 V15 V14 V12 V11}
for {set i 0} {$i < 16} {incr i} {
    set sw [get_ports [format {SW[%d]} $i]]
    set_property PACKAGE_PIN [lindex $sw_pins $i] $sw
    # Switches 8 and 9 are on the board's 1.8 V bank.
    set_property IOSTANDARD [expr {$i == 8 || $i == 9 ? "LVCMOS18" : "LVCMOS33"}] $sw
    set led [get_ports [format {LED[%d]} $i]]
    set_property PACKAGE_PIN [lindex $led_pins $i] $led
    set_property IOSTANDARD LVCMOS33 $led
}
set an_pins {J17 J18 T9 J14 P14 T14 K2 U13}
for {set i 0} {$i < 8} {incr i} {
    set p [get_ports [format {AN[%d]} $i]]
    set_property PACKAGE_PIN [lindex $an_pins $i] $p
    set_property IOSTANDARD LVCMOS33 $p
}
foreach port {CA CB CC CD CE CF CG DP VGA_HS VGA_VS} pin {T10 R10 K16 K13 P15 T11 L18 H15 B11 B12} {
    set_property -dict [list PACKAGE_PIN $pin IOSTANDARD LVCMOS33] [get_ports $port]
}
foreach color {R G B} pins {{A3 B4 C5 A4} {C6 A5 B6 A6} {B7 C7 D7 D8}} {
    for {set i 0} {$i < 4} {incr i} {
        set p [get_ports [format {VGA_%s[%d]} $color $i]]
        set_property -dict [list PACKAGE_PIN [lindex $pins $i] IOSTANDARD LVCMOS33] $p
    }
}
# Asynchronous controls terminate at explicitly marked first-stage synchronizers.
set_false_path -from [get_ports {SW[*] BTNC}] -to [get_cells -hier -filter {NAME =~ */meta_reg*}]
set_false_path -from [get_ports CPU_RESETN]
# Conservative board-output timing budget; these peripherals have no shared clock.
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.0 [all_outputs]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
