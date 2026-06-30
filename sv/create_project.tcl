# Set up a new project
create_project HarmoniCore2.0 ./ -part xc7a25tcsg325-2 -force
set_property SIMULATOR_LANGUAGE Verilog [current_project]

# ##################################################################
# # CREATE IP: MMCM
# ##################################################################
set mmcm [create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name mmcm]

set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {64.10000000000001} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {24.5} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {156} \
  CONFIG.CLKOUT3_USED {true} \
  CONFIG.CLK_OUT1_PORT {clk_24_5} \
  CONFIG.CLK_OUT2_PORT {clk_50} \
  CONFIG.CLK_OUT3_PORT {clk_156} \
  CONFIG.NUM_OUT_CLKS {3} \
  CONFIG.PRIMARY_PORT {clk_in} \
  CONFIG.PRIM_IN_FREQ {156} \
  CONFIG.MMCM_CLKIN1_PERIOD {6.410} \
] [get_ips mmcm]

generate_target all [get_ips mmcm]

##################################################################
# CREATE IP blk_mem
##################################################################

set blk_mem [create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name blk_mem]

# User Parameters
set_property -dict [list \
  CONFIG.Assume_Synchronous_Clk {true} \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Depth_A {256} \
  CONFIG.Write_Width_A {24} \
] [get_ips blk_mem]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $blk_mem

generate_target all [get_ips blk_mem]

##################################################################
# INCLUDE DIRECTORIES
# Add a new entry here whenever a new include subdirectory is created
##################################################################
set inc_dirs [list \
    [file normalize "./include"] \
    [file normalize "./include/core"] \
    [file normalize "./include/effects"] \
]
set_property include_dirs $inc_dirs [get_filesets sources_1]
set_property include_dirs $inc_dirs [get_filesets sim_1]

foreach dir $inc_dirs {
    foreach file [glob -nocomplain ${dir}/*.vh ${dir}/*.sv] {
        add_files -fileset sources_1 $file
        set_property file_type "Verilog Header" [get_files [file tail $file]]
    }
}

##################################################################
# RTL SOURCES
# Add a new entry here whenever a new src subdirectory is created
##################################################################
set src_dirs [list ./src ./src/core ./src/effects]
foreach dir $src_dirs {
    foreach file [glob -nocomplain ${dir}/*.sv ${dir}/*.v] {
        add_files -fileset sources_1 $file
        if {[string match "*.sv" $file]} {
            set_property file_type "SystemVerilog" [get_files [file tail $file]]
        }
    }
}

##################################################################
# TESTBENCHES
# Add a new entry here whenever a new tb subdirectory is created
##################################################################
set tb_dirs [list ./tb ./tb/core ./tb/effects]
foreach dir $tb_dirs {
    foreach file [glob -nocomplain ${dir}/*.sv ${dir}/*.v] {
        add_files -fileset sim_1 $file
        if {[string match "*.sv" $file]} {
            set_property file_type "SystemVerilog" [get_files [file tail $file] -of_objects [get_filesets sim_1]]
        }
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
set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created successfully."