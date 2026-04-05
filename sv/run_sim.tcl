set tb_name [lindex $argv 0]
open_project HarmoniCore2.0.xpr
set_property top ${tb_name}_tb [get_filesets sim_1]
launch_simulation