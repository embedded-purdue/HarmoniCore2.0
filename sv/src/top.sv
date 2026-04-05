
`timescale 1ns / 10ps
`include "../include/types.sv"
`include "../include/adc_to_fpga_if.vh"

module top
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

    // DAC
    fpga_to_dac_if ftdif();
    assign ftdif.dac_fclk = dac_fclk;
    assign ftdif.dac_bclk = dac_bclk;
    assign dac_data = ftdif.dac_data_out;

    // ---- MMCM instantiation (placeholder) ----
    // Your MMCM takes fpga_clk (156MHz) and produces:
    //   - adc_mclk (24.5MHz) → drives ADC
    //   - dac_mclk (50MHz)   → drives DAC (later)
    //   - locked signal
    // For now, just pass through or assign:
    // assign adc_mclk = mmcm_clk_24m5;

    adc_to_fpga u_adc (.fpga_clk(fpga_clk), .n_rst(n_rst), .atfif(atfif));

    fpga_to_dac u_dac (.fpga_clk(fpga_clk), .n_rst(n_rst), .ftdif(ftdif));

    assign ftdif.audio_data  = atfif.adc_valid ? atfif.adc_data_out : '0;
    assign ftdif.audio_valid = atfif.adc_valid;

endmodule