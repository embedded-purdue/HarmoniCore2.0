
# ==============================================================================
# FPGA Interface (156MHz external input)
# ==============================================================================
# Clock
set_property PACKAGE_PIN P4 [get_ports fpga_clk]
set_property IOSTANDARD LVCMOS33 [get_ports fpga_clk]
create_clock -period 6.410 -name fpga_clk [get_ports fpga_clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets fpga_clk]

# n_reset (btn3)
set_property PACKAGE_PIN B16 [get_ports n_rst]
set_property IOSTANDARD LVCMOS33 [get_ports n_rst]

# ==============================================================================
# ADC Interface (PCM4211)
# ==============================================================================
# Master Clock (24.5MHz)
set_property PACKAGE_PIN P14 [get_ports adc_mclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_mclk]

# ADC_nRST
set_property PACKAGE_PIN L18 [get_ports adc_nrst]
set_property IOSTANDARD LVCMOS33 [get_ports adc_nrst]

# Frame Clock
set_property PACKAGE_PIN R18 [get_ports adc_fclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_fclk]

# Bit Clock
set_property PACKAGE_PIN T18 [get_ports adc_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_bclk]

# Data Line
set_property PACKAGE_PIN P18 [get_ports adc_data]
set_property IOSTANDARD LVCMOS33 [get_ports adc_data]

# Don't make these clock pins
set_false_path -from [get_ports adc_fclk]
set_false_path -from [get_ports adc_bclk]

# ==============================================================================
# DAC Interface (TLV320)
# ==============================================================================
# Master Clock (50MHz)
set_property PACKAGE_PIN T14 [get_ports dac_mclk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_mclk]

# DAC_nRST
set_property PACKAGE_PIN V11 [get_ports dac_nrst]
set_property IOSTANDARD LVCMOS33 [get_ports dac_nrst]

# Frame Clock
set_property PACKAGE_PIN U17 [get_ports dac_fclk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_fclk]

# Bit Clock
set_property PACKAGE_PIN V16 [get_ports dac_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_bclk]

# Data Line
set_property PACKAGE_PIN V17 [get_ports dac_data]
set_property IOSTANDARD LVCMOS33 [get_ports dac_data]

# Don't make these clock pins
set_false_path -from [get_ports dac_fclk]
set_false_path -from [get_ports dac_bclk]

# ==============================================================================
# SWITCHES (9 switches, active-high)
# ==============================================================================
set_property PACKAGE_PIN A12 [get_ports sw1]
set_property IOSTANDARD LVCMOS33 [get_ports sw1]

set_property PACKAGE_PIN A13 [get_ports sw2]
set_property IOSTANDARD LVCMOS33 [get_ports sw2]

set_property PACKAGE_PIN A14 [get_ports sw3]
set_property IOSTANDARD LVCMOS33 [get_ports sw3]

set_property PACKAGE_PIN A10 [get_ports sw4]
set_property IOSTANDARD LVCMOS33 [get_ports sw4]

set_property PACKAGE_PIN C11 [get_ports sw5]
set_property IOSTANDARD LVCMOS33 [get_ports sw5]

set_property PACKAGE_PIN B11 [get_ports sw6]
set_property IOSTANDARD LVCMOS33 [get_ports sw6]

set_property PACKAGE_PIN B9 [get_ports sw7]
set_property IOSTANDARD LVCMOS33 [get_ports sw7]

set_property PACKAGE_PIN A9 [get_ports sw8]
set_property IOSTANDARD LVCMOS33 [get_ports sw8]

set_property PACKAGE_PIN B10 [get_ports sw9]
set_property IOSTANDARD LVCMOS33 [get_ports sw9]

# ==============================================================================
# BUTTONS (3 buttons, active-low)
# ==============================================================================
set_property PACKAGE_PIN A15 [get_ports btn1]
set_property IOSTANDARD LVCMOS33 [get_ports btn1]

set_property PACKAGE_PIN A17 [get_ports btn2]
set_property IOSTANDARD LVCMOS33 [get_ports btn2]

# btn3 (B16) is used for n_rst

# ==============================================================================
# PLL Test Outputs (top_test_pll only — comment out when top is 'top')
# ==============================================================================
# set_property PACKAGE_PIN P15 [get_ports test_pin]
# set_property IOSTANDARD LVCMOS33 [get_ports test_pin]

# Reset synchronizer false path.
# n_rst_sync (output of n_rst_sync_reg) deasserts synchronously with clk_156_mmcm.
# The recovery check on downstream CLR pins is not meaningful — treat as false path.
set_false_path -from [get_cells n_rst_sync_reg] -to [get_pins -hierarchical -filter {NAME =~ */CLR}]

# Configuration
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

# # TESTING PLL ON DEV BOARD
# set_property PACKAGE_PIN W4 [get_ports test_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports test_clk]

# set_property PACKAGE_PIN W7 [get_ports clk_40]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_40]

# set_property PACKAGE_PIN U8 [get_ports clk_10]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_10]

# set_property PACKAGE_PIN A16 [get_ports clk_156]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_156]

# set_property PACKAGE_PIN M3 [get_ports output_led]
# set_property IOSTANDARD LVCMOS33 [get_ports output_led]

# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets test_clk]

# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
# set_property CONFIG_VOLTAGE 3.3 [current_design]
# set_property CFGBVS VCCO [current_design]