# Set up a new project
create_project HarmoniCore2.0 ./ -part xc7a25tcsg325-2 -force

set_property SIMULATOR_LANGUAGE Verilog [current_project]
set FFT_DW 18
set FFT_LEN 1024

##################################################################
# CREATE IP fft_core
##################################################################

create_ip -name xfft -vendor xilinx.com -library ip -version 9.1 -module_name fft_core
set_property CONFIG.channels 1 [get_ips fft_core]
set_property CONFIG.transform_length $FFT_LEN [get_ips fft_core]
set_property CONFIG.target_clock_frequency 250 [get_ips fft_core]
set_property CONFIG.target_data_throughput 1 [get_ips fft_core]
set_property CONFIG.phase_factor_width 16 [get_ips fft_core]
set_property CONFIG.scaling_options Block_Floating_Point [get_ips fft_core]
set_property CONFIG.aresetn true [get_ips fft_core]
set_property CONFIG.xk_index true [get_ips fft_core]
set_property CONFIG.Input_Width $FFT_DW [get_ips fft_core]
set_property CONFIG.Cyclic_Prefix_Insertion false [get_ips fft_core]
set_property CONFIG.Output_Ordering natural_order [get_ips fft_core]
set_property CONFIG.Implementation_Options radix_2_burst_io [get_ips fft_core]
generate_target all [get_ips fft_core]

##################################################################
# CREATE IP fifo
##################################################################

set fifo [create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_generator_0]

# User Parameters
set_property -dict [list \
  CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
  CONFIG.Input_Depth {64} \
  CONFIG.Valid_Flag {true} \
] [get_ips fifo]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $fifo_generator_0

generate_target all [get_ips fifo]
##################################################################

##################################################################
# CREATE IP blk_mem
##################################################################

set blk_mem [create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name blk_mem]

# User Parameters
set_property -dict [list \
  CONFIG.Assume_Synchronous_Clk {true} \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Depth_A {2048} \
  CONFIG.Write_Width_A {18} \
] [get_ips blk_mem]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $blk_mem

generate_target all [get_ips blk_mem]
##################################################################

##################################################################
# CREATE IP shift_reg
##################################################################

set shift_reg [create_ip -name c_shift_ram -vendor xilinx.com -library ip -version 12.0 -module_name shift_reg]

# User Parameters
set_property -dict [list \
  CONFIG.Depth {33} \
  CONFIG.SCLR {true} \
  CONFIG.Width {18} \
] [get_ips shift_reg]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $shift_reg

generate_target all [get_ips shift_reg]
##################################################################

##################################################################
# CREATE IP blk_mem_gen_0 (tanh LUT)
##################################################################

set blk_mem_gen_0 [create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name blk_mem_gen_0]

# User Parameters
set_property -dict [list \
  CONFIG.Coe_File {../source/tanh_lut.coe} \
  CONFIG.Enable_A {Always_Enabled} \
  CONFIG.Load_Init_File {true} \
  CONFIG.Memory_Type {Single_Port_ROM} \
  CONFIG.Write_Depth_A {128} \
  CONFIG.Write_Width_A {18} \
] [get_ips blk_mem_gen_0]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $blk_mem_gen_0

generate_target all [get_ips blk_mem_gen_0]
##################################################################

##################################################################
# CREATE IP mult_gen_0
##################################################################

set mult_gen_0 [create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name mult_gen_0]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $mult_gen_0

generate_target all [get_ips mult_gen_0]
##################################################################

add_files constraints.xdc
set_property FILE_TYPE XDC [get_files constraints.xdc]
set_property top AFC [current_fileset] 

set include_path "./include"
foreach file [glob -directory $include_path *] {
     add_files $file    
}
set src_path "./src"
foreach file [glob -directory $src_path *] {
     add_files $file    
}
set tb_path "./tb"
foreach file [glob -directory $tb_path *] {
     add_files $file    
}
set wav_path "./waves"
foreach file [glob -directory $wav_path *] {
     add_files $file    
}
