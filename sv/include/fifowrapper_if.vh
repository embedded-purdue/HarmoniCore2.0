
`timescale 1ns/1ps

`ifndef FIFOWRAPPER_IF
`define FIFOWRAPPER_IF

`include "../include/types.sv"
import types::*;

interface fifowrapper_if;

    logic [DW-1:0] wr_data, rd_data;
    logic wr_en, rd_en, full, empty;

    modport fifo (
        input wr_data, wr_en, rd_en,
        output rd_data, full, empty
    );

    modport fifo_tb (
        output rd_data, full, empty,
        input wr_data, wr_en, rd_en
    );
    
endinterface

`endif