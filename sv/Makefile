setup:
	vivado -mode batch -source create_project.tcl

# powershell commands
clean:
	powershell -Command "Remove-Item -Force -ErrorAction SilentlyContinue *.log,*.jou,*.wdb,*.str, *.pb, dfx_runtime.txt, *.xpr"
	powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .Xil, HarmoniCore2.0.cache, HarmoniCore2.0.gen, HarmoniCore2.0.hw, HarmoniCore2.0.ip_user_files, HarmoniCore2.0.srcs, HarmoniCore2.0.runs, HarmoniCore2.0.sim, reports, *.dir"

%.sim:
	if exist HarmoniCore2.0.gen\sources_1\ip\blk_mem\simulation\blk_mem_gen_v6_4.v (xvlog HarmoniCore2.0.gen\sources_1\ip\blk_mem\simulation\blk_mem_gen_v6_4.v) else (xvlog sim_stubs\blk_mem.v)
	if exist HarmoniCore2.0.gen\sources_1\ip\blk_mem\simulation\blk_mem_gen_v6_4.v (xvlog HarmoniCore2.0.gen\sources_1\ip\blk_mem\sim\blk_mem.v)
	for %%f in (src\*.sv src\core\*.sv src\effects\*.sv) do xvlog -sv -i include -i include\core -i include\effects %%f
	for /r tb %%f in ($*_tb.sv) do if exist %%f xvlog -sv -i include -i include\core -i include\effects %%f
	xelab -debug typical $*_tb -s $*_sim
	if exist waves\$*_sim.wcfg (xsim $*_sim -gui -view waves\$*_sim.wcfg) else (xsim $*_sim -gui)

%.uvm:
	for %%f in (src\*.sv src\core\*.sv src\effects\*.sv) do xvlog -sv -L uvm -uvm -i include -i include\core -i include\effects %%f
	for /r tb %%f in ($*_tb_uvm.sv) do if exist %%f xvlog -sv -L uvm -uvm -i include -i include\core -i include\effects %%f
	xelab -debug typical -L uvm -uvm $*_tb_uvm -s $*_uvm_sim
	xsim $*_uvm_sim -testplusarg UVM_TESTNAME=$(TEST) -runall

synth:
	vivado -mode batch -source synth.tcl

impl:
	vivado -mode batch -source impl.tcl