
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

	@echo Removing Vivado IP cores...
	-@cmd /C "rmdir /S /Q project.srcs\\sources_1\\ip >nul 2>&1"
	-@cmd /C "rmdir /S /Q project.srcs\\sources_1\\ipshared >nul 2>&1"
	-@cmd /C "rmdir /S /Q ip_user_files\\ip >nul 2>&1"
	-@cmd /C "rmdir /S /Q ip_user_files\\sim_scripts >nul 2>&1"
	-@cmd /C "del /Q project.srcs\\sources_1\\bd\\*\\*.xci >nul 2>&1"
	-@cmd /C "del /Q project.srcs\\sources_1\\ip\\*.xci >nul 2>&1"

	@echo Clean complete.
%.sim:
	for %%f in (src\*.sv) do xvlog -sv %%f
	xvlog -sv ./tb/$*_tb.sv
	xvhdl ./HarmoniCore.gen/sources_1/ip/fft_core/sim/fft_core.vhd
	xvhdl ./HarmoniCore.gen/sources_1/ip/div/sim/div.vhd
	xvlog ./HarmoniCore.gen/sources_1/ip/blk_mem/simulation/blk_mem_gen_v8_4.v
	xvlog ./HarmoniCore.gen/sources_1/ip/blk_mem/sim/blk_mem.v
	xvhdl ./HarmoniCore.gen/sources_1/ip/shift_reg/sim/shift_reg.vhd
	xelab -debug typical $*_tb -s $*_sim
	xsim $*_sim -gui -view ./waves/$*_sim.wcfg
Template.sim:
	xvlog -sv ./tb/AFC_tb.sv ./src/*.sv 
	xvlog ./AFC.gen/sources_1/ip/rom/sim/*.v
	xvhdl ./AFC.gen/sources_1/ip/*/sim/*.vhd ./AFC.gen/sources_1/ip/fft_core/hdl/*.vhd \
	./AFC.gen/sources_1/ip/cmult/hdl/*.vhd ./AFC.gen/sources_1/ip/div/hdl/*.vhd
	xelab -debug typical AFC_tb -s AFC_sim -L blk_mem_gen_v8_4_9 -L unisims_ver
	xsim AFC_sim -gui -view /home/varun/FPGAProjects/R2FFT/AFC/waves/AFC_sim.wcfg
.PHONY: AFC.sim