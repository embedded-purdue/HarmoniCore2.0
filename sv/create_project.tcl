# Resolve the script directory so relative paths work portably
set origin_dir [file normalize [file dirname [info script]]]

# Set up a new project
create_project HarmoniCore2.0 ./ -part xc7a25tcsg325-2 -force

set_property SIMULATOR_LANGUAGE Verilog [current_project]

##################################################################
# CREATE IP fifo
##################################################################

set fifo [create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo]

# User Parameters
set_property -dict [list \
  CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
  CONFIG.Input_Depth {16} \
  CONFIG.Valid_Flag {true} \
] [get_ips fifo]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $fifo

generate_target all [get_ips fifo]
##################################################################

##################################################################
# CREATE IP ring_mod_accum
##################################################################

set ring_mod_accum [create_ip -name c_accum -vendor xilinx.com -library ip -version 12.0 -module_name ring_mod_accum]

# User Parameters
set_property -dict [list \
  CONFIG.Input_Type {Unsigned} \
  CONFIG.Output_Width {18} \
] [get_ips ring_mod_accum]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $ring_mod_accum

generate_target all [get_ips ring_mod_accum]
##################################################################


##################################################################
# CREATE IP ring_mod_lut
##################################################################

set ring_mod_lut [create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name ring_mod_lut]

# User Parameters
set coe_file [file normalize "$origin_dir/../source/sin_lut.coe"]
set_property -dict [list \
  CONFIG.Coe_File $coe_file \
  CONFIG.Enable_A {Always_Enabled} \
  CONFIG.Load_Init_File {true} \
  CONFIG.Memory_Type {Single_Port_ROM} \
  CONFIG.Write_Depth_A {64} \
  CONFIG.Write_Width_A {18} \
] [get_ips ring_mod_lut]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $ring_mod_lut

generate_target all [get_ips ring_mod_lut]
##################################################################

##################################################################
# CREATE IP ring_mod_mult
##################################################################

set ring_mod_mult [create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name ring_mod_mult]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $ring_mod_mult

generate_target all [get_ips ring_mod_mult]
##################################################################


add_files constraints.xdc
set_property FILE_TYPE XDC [get_files constraints.xdc]
set_property top AFC [current_fileset] 

foreach dir {./include ./src ./tb ./waves} {
    if {[file isdirectory $dir]} {
        foreach file [glob -nocomplain -directory $dir *] {
            add_files $file
        }
    }
}
