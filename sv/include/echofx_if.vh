`timescale 1ns/1ps

`ifndef ECHOFX_IF
`define ECHOFX_IF

`include "../include/types.sv"
import types::*;

interface echofx_if;

    logic signed [DW-1:0] data_in, data_out;
    logic fx_en;

    modport echo (
        input data_in, fx_en,
        output data_out
    );

    modport tb (
        output data_in, fx_en,
        input data_out
    );
    
endinterface
`endif