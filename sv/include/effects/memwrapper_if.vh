
`timescale 1ns/1ps

`ifndef MEMWRAPPER_IF
`define MEMWRAPPER_IF

`include "../../include/types.sv"
import types::*;

interface memwrapper_if;

    logic wea, web, valid_a, valid_b;
    logic [7:0] addra, addrb;
    logic [DW-1:0] dina, dinb;
    logic [DW-1:0] douta, doutb;

    modport mem (
        input wea, web, addra, addrb, dina, dinb,
        output douta, doutb, valid_a, valid_b
    );

    modport mem_tb (
        input  douta, doutb, valid_a, valid_b,
        output wea, web, addra, addrb, dina, dinb
    );
    
endinterface

`endif