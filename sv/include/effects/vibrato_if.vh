`timescale 1ns/1ps

`ifndef VIBRATO_IF
`define VIBRATO_IF

`include "../../include/types.sv"
import types::*;

interface vibrato_if;
    logic valid_in, valid_out;
    logic signed [DW-1:0] data_in, data_out;

    modport vibrato (
        input  valid_in, data_in,
        output valid_out, data_out
    );
    modport vibrato_tb (
        output valid_in, data_in,
        input  valid_out, data_out
    );
endinterface

`endif
