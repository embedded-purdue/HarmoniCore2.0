`timescale 1ns/1ps

`ifndef REVERB_IF
`define REVERB_IF

`include "../types.sv"
import types::*;

interface reverb_if;
    logic valid_in, valid_out;
    logic signed [DW-1:0] data_in, data_out;

    modport reverb (
        input  valid_in, data_in,
        output valid_out, data_out
    );
    modport reverb_tb (
        output valid_in, data_in,
        input  valid_out, data_out
    );
endinterface

`endif
