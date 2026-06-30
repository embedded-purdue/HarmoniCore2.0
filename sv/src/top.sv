`timescale 1ns / 10ps
`include "../include/types.sv"
`include "../include/core/adc_to_fpga_if.vh"
`include "../include/core/fpga_to_dac_if.vh"
`include "../include/core/dc_offset_if.vh"
`include "../include/effects/ring_mod_if.vh"
`include "../include/effects/vibrato_if.vh"
`include "../include/effects/echo_if.vh"
`include "../include/effects/reverb_if.vh"

// Fixed-order effects chain with per-effect bypass.
//
// SW[3:0] — effect enables (0 = bypass, 1 = active):
//   SW[0] : ring_mod
//   SW[1] : vibrato
//   SW[2] : echo
//   SW[3] : reverb
//
// Signal chain:
//   ADC → dc_offset → [ring_mod] → [vibrato] → [echo] → [reverb] → DAC

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
    output logic dac_data,

    // Switches (active-high)
    input logic sw1, sw2, sw3, sw4, sw5, sw6, sw7, sw8, sw9,

    // Buttons (active-low); btn3 is n_rst — not a separate port
    input logic btn1, btn2
);

    // ---- Internal connections ----
    // RESETS
    assign adc_nrst = n_rst;
    assign dac_nrst = n_rst;

    logic sys_clk, clk_ready;
    mmcm u_mmcm (.clk_24_5(adc_mclk), .clk_50(dac_mclk), .clk_156(sys_clk), .reset(~n_rst), .locked(clk_ready), .clk_in(fpga_clk));

    // Reset synchronizer: holds fabric in reset until n_rst is high AND MMCM is locked.
    // adc_nrst/dac_nrst/MMCM keep using raw n_rst (external hard blocks, not fabric FFs).
    logic n_rst_s1, n_rst_sync;
    always_ff @(posedge sys_clk, negedge n_rst) begin
        if (~n_rst) {n_rst_sync, n_rst_s1} <= 2'b00;
        else        {n_rst_sync, n_rst_s1} <= {n_rst_s1, clk_ready};
    end

    // ADC
    adc_to_fpga_if atfif();
    assign atfif.adc_fclk = adc_fclk;
    assign atfif.adc_bclk = adc_bclk;
    assign atfif.adc_data = adc_data;
    adc_to_fpga u_adc (.fpga_clk(sys_clk), .n_rst(n_rst_sync), .atfif(atfif));

    // DC Offset Correction
    dc_offset_if dcif();
    assign dcif.adc_valid = atfif.adc_valid;
    assign dcif.adc_data  = atfif.adc_data_out;
    dc_offset u_dc_offset (.fpga_clk(sys_clk), .n_rst(n_rst_sync), .dcif(dcif));

    // Effects Pipeline
    logic signed [DW-1:0] s0_data, s1_data, s2_data, s3_data, s4_data;
    logic s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;

    assign s0_valid = dcif.dc_valid;
    assign s0_data = dcif.dc_data;

    // Ring Mod
    ring_mod_if rmif();
    assign rmif.valid_in = s0_valid;
    assign rmif.data_in  = s0_data;
    ring_mod u_ring_mod (.clk(sys_clk), .n_rst(n_rst_sync), .rmif(rmif));

    assign s1_valid = sw1 ? rmif.valid_out : s0_valid;
    assign s1_data  = sw1 ? rmif.data_out  : s0_data;

    // Vibrato
    vibrato_if vbif();
    assign vbif.valid_in = s1_valid;
    assign vbif.data_in  = s1_data;
    vibrato u_vibrato (.clk(sys_clk), .n_rst(n_rst_sync), .vbif(vbif));

    assign s2_valid = sw2 ? vbif.valid_out : s1_valid;
    assign s2_data  = sw2 ? vbif.data_out  : s1_data;

    // Echo
    echo_if ecif();
    assign ecif.valid_in = s2_valid;
    assign ecif.data_in  = s2_data;
    echo u_echo (.clk(sys_clk), .n_rst(n_rst_sync), .eif(ecif));

    assign s3_valid = sw3 ? ecif.valid_out : s2_valid;
    assign s3_data  = sw3 ? ecif.data_out  : s2_data;

    // Reverb
    reverb_if rvif();
    assign rvif.valid_in = s3_valid;
    assign rvif.data_in  = s3_data;
    reverb u_reverb (.clk(sys_clk), .n_rst(n_rst_sync), .rvif(rvif));

    assign s4_valid = sw4 ? rvif.valid_out : s3_valid;
    assign s4_data  = sw4 ? rvif.data_out  : s3_data;

    // DAC
    fpga_to_dac_if ftdif();
    assign ftdif.dac_fclk   = dac_fclk;
    assign ftdif.dac_bclk   = dac_bclk;
    assign dac_data          = ftdif.dac_data_out;
    assign ftdif.audio_valid = s4_valid;
    assign ftdif.audio_data  = s4_valid ? s4_data : '0;
    fpga_to_dac u_dac (.fpga_clk(sys_clk), .n_rst(n_rst_sync), .ftdif(ftdif));

endmodule
