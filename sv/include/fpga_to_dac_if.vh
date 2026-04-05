
`timescale 1ns/1ps

`ifndef FPGA_TO_DAC_IF
`define FPGA_TO_DAC_IF

`include "../include/types.sv"
import types::*;

interface fpga_to_dac_if;

    // inputs
    logic [DW-1:0] audio_data;
    logic audio_valid;
    logic dac_fclk, dac_bclk;

    // outputs
    logic dac_data_out;

    modport fpga_to_dac (
        input audio_data, audio_valid, dac_fclk, dac_bclk,
        output dac_data_out
    );

    modport fpga_to_dac_tb (
        input dac_data_out,
        output audio_data, audio_valid, dac_fclk, dac_bclk
    );
    
endinterface

`endif