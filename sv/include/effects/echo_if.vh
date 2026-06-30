`timescale 1ns/1ps

`ifndef ECHO_IF
`define ECHO_IF

`include "../types.sv"
import types::*;

interface echo_if;
    logic valid_in, valid_out;
    logic signed [DW-1:0] data_in, data_out;

    modport echo (
        input  valid_in, data_in,
        output valid_out, data_out
    );
    modport echo_tb (
        output valid_in, data_in,
        input  valid_out, data_out
    );
endinterface

`endif
