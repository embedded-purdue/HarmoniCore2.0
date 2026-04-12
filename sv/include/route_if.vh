
`timescale 1ns/1ps

`ifndef ROUTE_UNIT_IF
`define ROUTE_UNIT_IF

`include "../include/types.sv"

import types::*;

interface route_unit_if;

    logic CLK;
    logic n_rst;
    logic [9:0] switch;
    logic valid;
    logic [DW-1:0] din;
    logic [DW-1:0] dout;

    modport route(
        input CLK, n_rst, switch, valid, din,
        output dout
    );

    modport tb(
        output dout,
        input CLK, n_rst, switch, valid, din
    );

endinterface

`endif