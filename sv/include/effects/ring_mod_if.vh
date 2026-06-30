
`timescale 1ns/1ps

`ifndef RING_MOD_IF
`define RING_MOD_IF

`include "../types.sv"
import types::*;

interface ring_mod_if;

    // inputs
    logic signed [DW-1:0] data_in;
    logic valid_in;

    // outputs
    logic signed [DW-1:0] data_out;
    logic valid_out;

    modport ring_mod (
        input data_in, valid_in,
        output data_out, valid_out
    );

    modport ring_mod_tb (
        input data_out, valid_out,
        output data_in, valid_in
    );
    
endinterface

`endif