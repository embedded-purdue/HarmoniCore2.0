
`timescale 1ns / 10ps
`include "../include/types.sv"
`include "../include/core/adc_to_fpga_if.vh"
`include "../include/core/fpga_to_dac_if.vh"
`include "../include/core/dc_offset_if.vh"

module top_noEffects
import types::*;
(
    // FPGA Interface
    input  logic fpga_clk,
    input  logic n_rst,

    // ADC Interface
    output logic adc_mclk,
    output logic adc_nrst,
    input  logic adc_fclk,
    input  logic adc_bclk,
    input  logic adc_data,

    // DAC Interface
    output logic dac_mclk,
    output logic dac_nrst,
    input  logic dac_fclk,
    input  logic dac_bclk,
    output logic dac_data
);

    // ---- Internal connections ----
    // RESETS
    assign adc_nrst = n_rst;
    assign dac_nrst = n_rst;

    // ADC
    adc_to_fpga_if atfif();
    assign atfif.adc_fclk = adc_fclk;
    assign atfif.adc_bclk = adc_bclk;
    assign atfif.adc_data = adc_data;

    // DC Offset Correction
    dc_offset_if dcif();
    assign dcif.adc_valid = atfif.adc_valid;
    assign dcif.adc_data  = atfif.adc_data_out;

    // DAC
    fpga_to_dac_if ftdif();
    assign ftdif.dac_fclk = dac_fclk;
    assign ftdif.dac_bclk = dac_bclk;
    assign dac_data = ftdif.dac_data_out;

    // ---- Modules ----
    // MMCM/PLL
    logic sys_clk, clk_ready;
    mmcm u_mmcm (.clk_24_5(adc_mclk), .clk_50(dac_mclk), .clk_156(sys_clk), .reset(~n_rst), .locked(clk_ready), .clk_in(fpga_clk));

    // ADC
    adc_to_fpga u_adc (.fpga_clk(sys_clk), .n_rst(n_rst), .atfif(atfif));

    // DC Offset Correction
    dc_offset u_dc_offset (.fpga_clk(sys_clk), .n_rst(n_rst), .dcif(dcif));
     
     // DAC
    fpga_to_dac u_dac (.fpga_clk(sys_clk), .n_rst(n_rst), .ftdif(ftdif));

    // Temp Logic
    assign ftdif.audio_data  = clk_ready && dcif.dc_valid ? dcif.dc_data : '0;
    assign ftdif.audio_valid = clk_ready && dcif.dc_valid;

endmodule