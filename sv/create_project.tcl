# Set up a new project
create_project HarmoniCore2.0 ./ -part xc7a25tcsg325-2 -force

set_property SIMULATOR_LANGUAGE Verilog [current_project]

# Include directory - add to BOTH filesets so headers resolve everywhere
set include_path "./include"
set include_files [glob -nocomplain -directory $include_path *.vh *.sv]
foreach file $include_files {
    add_files -fileset sources_1 $file
    set_property file_type "Verilog Header" [get_files $file]
}

# ---- Include directory (available to both synthesis and simulation) ----
set include_path [file normalize "./include"]
set_property include_dirs [list $include_path] [get_filesets sources_1]
set_property include_dirs [list $include_path] [get_filesets sim_1]

# Add include headers to sources_1 so Vivado tracks them
foreach file [glob -nocomplain ${include_path}/*.vh ${include_path}/*.sv] {
    add_files -fileset sources_1 $file
    set_property file_type "Verilog Header" [get_files [file tail $file]]
}

# ---- RTL sources ----
foreach file [glob -nocomplain ./src/*.sv ./src/*.v] {
    add_files -fileset sources_1 $file
    # mark .sv files explicitly as SystemVerilog
    if {[string match "*.sv" $file]} {
        set_property file_type "SystemVerilog" [get_files [file tail $file]]
    }
}

# ---- Testbenches (sim only) ----
foreach file [glob -nocomplain ./tb/*.sv ./tb/*.v] {
    add_files -fileset sim_1 $file
    if {[string match "*.sv" $file]} {
        set_property file_type "SystemVerilog" [get_files [file tail $file] -of_objects [get_filesets sim_1]]
    }
}

# ---- Wave configs ----
foreach file [glob -nocomplain ./waves/*.wcfg] {
    add_files -fileset sim_1 $file
}

# ---- Constraints ----
if {[file exists constraints.xdc]} {
    add_files -fileset constrs_1 constraints.xdc
}

# ---- Set top module ----
set_property top top [get_filesets sources_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created successfully."