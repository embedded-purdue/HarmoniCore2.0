
# # ==============================================================================
# # FPGA Interface (156MHz external input)
# # ==============================================================================
# # Clock
# set_property PACKAGE_PIN P4 [get_ports fpga_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports fpga_clk]

# # n_reset
# set_property PACKAGE_PIN B16 [get_ports n_rst]
# set_property IOSTANDARD LVCMOS33 [get_ports n_rst]

# # set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets fpga_clk]

# # ==============================================================================
# # ADC Interface (PCM4211)
# # ==============================================================================
# # Master Clock (24.5MHz)
# set_property PACKAGE_PIN P14 [get_ports adc_mclk]
# set_property IOSTANDARD LVCMOS33 [get_ports adc_mclk]

# # ADC_nRST
# set_property PACKAGE_PIN L18 [get_ports adc_nrst]
# set_property IOSTANDARD LVCMOS33 [get_ports adc_nrst]

# # Frame Clock
# set_property PACKAGE_PIN R18 [get_ports adc_fclk]
# set_property IOSTANDARD LVCMOS33 [get_ports adc_fclk]

# # Bit Clock
# set_property PACKAGE_PIN T18 [get_ports adc_bclk]
# set_property IOSTANDARD LVCMOS33 [get_ports adc_bclk]

# # Data Line
# set_property PACKAGE_PIN P18 [get_ports adc_data]
# set_property IOSTANDARD LVCMOS33 [get_ports adc_data]

# # Don't make these clock pins
# set_false_path -from [get_ports adc_fclk]
# set_false_path -from [get_ports adc_bclk]

# # ==============================================================================
# # DAC Interface (TLV320)
# # ==============================================================================
# # Master Clock (50MHz)
# set_property PACKAGE_PIN T14 [get_ports dac_mclk]
# set_property IOSTANDARD LVCMOS33 [get_ports dac_mclk]

# # DAC_nRST
# set_property PACKAGE_PIN V11 [get_ports dac_nrst]
# set_property IOSTANDARD LVCMOS33 [get_ports dac_nrst]

# # Frame Clock
# set_property PACKAGE_PIN U17 [get_ports dac_fclk]
# set_property IOSTANDARD LVCMOS33 [get_ports dac_fclk]

# # Bit Clock
# set_property PACKAGE_PIN V16 [get_ports dac_bclk]
# set_property IOSTANDARD LVCMOS33 [get_ports dac_bclk]

# # Data Line
# set_property PACKAGE_PIN V17 [get_ports dac_data]
# set_property IOSTANDARD LVCMOS33 [get_ports dac_data]

# # Don't make these clock pins
# set_false_path -from [get_ports dac_fclk]
# set_false_path -from [get_ports dac_bclk]

# TESTING PLL ON DEV BOARD
set_property PACKAGE_PIN W4 [get_ports test_clk]
set_property IOSTANDARD LVCMOS33 [get_ports test_clk]

set_property PACKAGE_PIN W7 [get_ports clk_40]
set_property IOSTANDARD LVCMOS33 [get_ports clk_40]

set_property PACKAGE_PIN U8 [get_ports clk_10]
set_property IOSTANDARD LVCMOS33 [get_ports clk_10]

set_property PACKAGE_PIN A16 [get_ports clk_156]
set_property IOSTANDARD LVCMOS33 [get_ports clk_156]

set_property PACKAGE_PIN M3 [get_ports output_led]
set_property IOSTANDARD LVCMOS33 [get_ports output_led]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets test_clk]

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]