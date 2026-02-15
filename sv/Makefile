setup:
	vivado -mode batch -source create_project.tcl

# powershell commands
clean:
	powershell -Command "Remove-Item -Force -ErrorAction SilentlyContinue *.log,*.jou,*.wdb,*.str, *.pb"
	powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .Xil, HarmoniCore2.0.cache, HarmoniCore2.0.gen, HarmoniCore2.0.hw, HarmoniCore2.0.ip_user_files, HarmoniCore2.0.srcs"

%.sim:
	for %%f in (src\*.sv) do xvlog -sv %%f
	xvlog -sv ./tb/$*_tb.sv

# 	FIFO
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/sim/fifo.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/simulation/fifo_generator_vlog_beh.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/hdl/fifo_generator_v13_2_rfs.v
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/fifo/hdl/fifo_generator_v13_2_rfs.vhd

	xelab -debug typical $*_tb -s $*_sim
	xsim $*_sim -gui -view ./waves/$*_sim.wcfg


# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/fft_core/sim/fft_core.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/div/sim/div.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/shift_reg/sim/shift_reg.vhd
# xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/simulation/blk_mem_gen_v8_4.v
# xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/sim/blk_mem.v