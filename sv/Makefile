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

#   RING_MOD_ACCUM
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_accum/sim/ring_mod_accum.vhd

#   RING_MOD_MULT
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_mult/sim/ring_mod_mult.vhd

#   RING_MOD_LUT
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_lut/sim/ring_mod_lut.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_lut/simulation/blk_mem_gen_v8_4.v

#   DELAY_BRAM
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem_gen_0/sim/blk_mem_gen_0.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem_gen_0/simulation/blk_mem_gen_v8_4.v

#   DISTORTION_MULT
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/distortion_mult/sim/distortion_mult.vhd

#   DISTORTION_LUT
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/distortion_lut/sim/distortion_lut.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/distortion_lut/simulation/blk_mem_gen_v8_4.v

	copy /Y .\HarmoniCore2.0.gen\sources_1\ip\ring_mod_lut\ring_mod_lut.mif . >NUL
	copy /Y .\HarmoniCore2.0.gen\sources_1\ip\distortion_lut\distortion_lut.mif . >NUL

	xelab -debug typical $*_tb -s $*_sim
	xsim $*_sim -gui -view ./waves/$*_sim.wcfg

# Run ring modulator simulation in batch mode and generate CSV
ring_mod_run:
	xsim ring_mod_sim -R
	@echo CSV file generated: ring_mod_output.csv

# Ring modulator verification target (compile + run + verify)
ring_mod_verify: ring_mod.sim
	xsim ring_mod_sim -R
	python ../python/verify_ring_mod.py ring_mod_output.csv

# Batch simulation run (no GUI) for automated testing
%.batch:
	for %%f in (src\*.sv) do xvlog -sv %%f
	xvlog -sv ./tb/$*_tb.sv
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/sim/fifo.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/simulation/fifo_generator_vlog_beh.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/hdl/fifo_generator_v13_2_rfs.v
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/fifo/hdl/fifo_generator_v13_2_rfs.vhd
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_accum/sim/ring_mod_accum.vhd
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_mult/sim/ring_mod_mult.vhd
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_lut/sim/ring_mod_lut.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/ring_mod_lut/simulation/blk_mem_gen_v8_4.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem_gen_0/sim/blk_mem_gen_0.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem_gen_0/simulation/blk_mem_gen_v8_4.v
	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/distortion_mult/sim/distortion_mult.vhd
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/distortion_lut/sim/distortion_lut.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/distortion_lut/simulation/blk_mem_gen_v8_4.v
	copy /Y .\HarmoniCore2.0.gen\sources_1\ip\ring_mod_lut\ring_mod_lut.mif . >NUL
	copy /Y .\HarmoniCore2.0.gen\sources_1\ip\distortion_lut\distortion_lut.mif . >NUL
	xelab -debug typical $*_tb -s $*_sim
	xsim $*_sim -runall -nolog


# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/fft_core/sim/fft_core.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/div/sim/div.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/shift_reg/sim/shift_reg.vhd
# xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/simulation/blk_mem_gen_v8_4.v
# xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/sim/blk_mem.v
