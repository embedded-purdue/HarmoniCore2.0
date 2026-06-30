
`timescale 1ns/1ps

`ifndef DC_OFFSET_IF
`define DC_OFFSET_IF

`include "../types.sv"
import types::*;

interface dc_offset_if;

    // inputs
    logic signed [DW-1:0] adc_data;
    logic adc_valid;

    // outputs
    logic signed [DW-1:0] dc_data;
    logic dc_valid;

    modport dc_offset (
        input adc_data, adc_valid,
        output dc_data, dc_valid
    );

    modport dc_offset_tb (
        input dc_data, dc_valid,
        output adc_data, adc_valid
    );
    
endinterface

`endif