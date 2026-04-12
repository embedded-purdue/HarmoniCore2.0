# Set up a new project
# create_project HarmoniCore2.0 ./ -part xc7a25tcsg325-2 -force
create_project HarmoniCore2.0 ./ -part xc7a35tcpg236-1 -force
set_property SIMULATOR_LANGUAGE Verilog [current_project]

# ##################################################################
# # CREATE IP: MMCM
# ##################################################################
# set mmcm [create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name mmcm]

# set_property -dict [list \
#   CONFIG.CLKIN1_JITTER_PS {64.10000000000001} \
#   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {24.5} \
#   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50} \
#   CONFIG.CLKOUT2_USED {true} \
#   CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {156} \
#   CONFIG.CLKOUT3_USED {true} \
#   CONFIG.CLK_OUT1_PORT {clk_24_5} \
#   CONFIG.CLK_OUT2_PORT {clk_50} \
#   CONFIG.CLK_OUT3_PORT {clk_156} \
#   CONFIG.NUM_OUT_CLKS {3} \
#   CONFIG.PRIMARY_PORT {clk_in} \
#   CONFIG.PRIM_IN_FREQ {156} \
#   CONFIG.MMCM_CLKIN1_PERIOD {6.410} \
# ] [get_ips mmcm]

# generate_target all [get_ips mmcm]
# create_ip_run [get_ips mmcm]
# launch_runs mmcm_synth_1 -jobs 4
# wait_on_run mmcm_synth_1

##################################################################
# INCLUDE DIRECTORY
##################################################################
set include_path [file normalize "./include"]
set_property include_dirs [list $include_path] [get_filesets sources_1]
set_property include_dirs [list $include_path] [get_filesets sim_1]

foreach file [glob -nocomplain ${include_path}/*.vh ${include_path}/*.sv] {
    add_files -fileset sources_1 $file
    set_property file_type "Verilog Header" [get_files [file tail $file]]
}

##################################################################
# RTL SOURCES
##################################################################
foreach file [glob -nocomplain ./src/*.sv ./src/*.v] {
    add_files -fileset sources_1 $file
    if {[string match "*.sv" $file]} {
        set_property file_type "SystemVerilog" [get_files [file tail $file]]
    }
}

##################################################################
# TESTBENCHES
##################################################################
foreach file [glob -nocomplain ./tb/*.sv ./tb/*.v] {
    add_files -fileset sim_1 $file
    if {[string match "*.sv" $file]} {
        set_property file_type "SystemVerilog" [get_files [file tail $file] -of_objects [get_filesets sim_1]]
    }
}

##################################################################
# WAVE CONFIGS
##################################################################
foreach file [glob -nocomplain ./waves/*.wcfg] {
    add_files -fileset sim_1 $file
}

##################################################################
# CONSTRAINTS
##################################################################
if {[file exists constraints.xdc]} {
    add_files -fileset constrs_1 constraints.xdc
}

##################################################################
# FINALIZE
##################################################################
set_property top top_test_flashing [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created successfully."