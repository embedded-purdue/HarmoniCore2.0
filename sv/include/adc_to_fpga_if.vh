
`timescale 1ns/1ps

`ifndef ADC_TO_FPGA_IF
`define ADC_TO_FPGA_IF

`include "../include/types.sv"
import types::*;

interface adc_to_fpga_if;

    // inputs
    logic adc_fclk, adc_bclk, adc_data;

    // outputs
    logic [DW-1:0] adc_data_out;
    logic adc_valid;

    modport adc_to_fpga (
        input adc_fclk, adc_bclk, adc_data,
        output adc_data_out, adc_valid
    );

    modport adc_to_fpga_tb (
        input adc_data_out, adc_valid,
        output adc_fclk, adc_bclk, adc_data
    );
    
endinterface

`endif