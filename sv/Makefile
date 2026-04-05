setup:
	vivado -mode batch -source create_project.tcl

# powershell commands
clean:
	powershell -Command "Remove-Item -Force -ErrorAction SilentlyContinue *.log,*.jou,*.wdb,*.str, *.pb"
	powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .Xil, HarmoniCore2.0.cache, HarmoniCore2.0.gen, HarmoniCore2.0.hw, HarmoniCore2.0.ip_user_files, HarmoniCore2.0.srcs, HarmoniCore2.0.runs, reports, *.dir"

%.sim:
	for %%f in (src\*.sv) do xvlog -sv -i ./include %%f
	xvlog -sv -i ./include ./tb/$*_tb.sv



	xelab -debug typical $*_tb -s $*_sim
	xsim $*_sim -gui -view ./waves/$*_sim.wcfg

synth:
	vivado -mode batch -source synth.tcl

impl:
	vivado -mode batch -source impl.tcl

bistream:
	vivado -mode batch -source bitstream.tcl