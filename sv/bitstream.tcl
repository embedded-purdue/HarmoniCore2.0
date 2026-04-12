open_project HarmoniCore2.0/HarmoniCore2.0.xpr

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Bitstream generation failed"
}

puts "Bitstream complete"