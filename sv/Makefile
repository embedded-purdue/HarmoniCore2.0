
setup:
	vivado -mode batch -source create_project.tcl
clean:
	@echo Cleaning Vivado project files...
	-@cmd /C "del /Q *.wdb *.jou *.log *.pb *.str *.xci >nul 2>&1"
	-@cmd /C "rmdir /S /Q .Xil >nul 2>&1"
	-@cmd /C "rmdir /S /Q xsim.dir >nul 2>&1"
	-@cmd /C "rmdir /S /Q .runs >nul 2>&1"
	-@cmd /C "rmdir /S /Q .cache >nul 2>&1"
	-@cmd /C "rmdir /S /Q .sim >nul 2>&1"
	-@cmd /C "for /D %%G in (vivado_pid*) do rmdir /S /Q %%G >nul 2>&1"

%.sim:
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/simulation/blk_mem_gen_v8_4.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/blk_mem/sim/blk_mem.v

	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/simulation/fifo_generator_vlog_beh.v
	xvlog ./HarmoniCore2.0.gen/sources_1/ip/fifo/sim/fifo.v

	for %%f in (src\*.sv) do xvlog -sv %%f
	xvlog -sv ./tb/$*_tb.sv

	xelab -debug typical \
	      -L fifo_generator_v13_2_13 \
	      -L xpm \
	      $*_tb -s $*_sim

	xsim $*_sim -gui -view ./waves/$*_sim.wcfg


# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/fft_core/sim/fft_core.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/div/sim/div.vhd
# 	xvhdl ./HarmoniCore2.0.gen/sources_1/ip/shift_reg/sim/shift_reg.vhd