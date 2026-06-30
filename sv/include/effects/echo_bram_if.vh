`timescale 1ns/1ps

`ifndef ECHO_BRAM_IF
`define ECHO_BRAM_IF

`include "../types.sv"
import types::*;

// Simple dual-port BRAM interface: one write port, one read port.
// Synthesizes to a Xilinx Simple Dual Port Block RAM.
interface echo_bram_if;
    logic                        wr_en;
    logic [ECHO_ADDR_W-1:0]      wr_addr;
    logic [ECHO_ADDR_W-1:0]      rd_addr;
    logic signed [DW-1:0]        din;
    logic signed [DW-1:0]        dout;   // registered output (1-cycle latency)

    modport mem (
        input  wr_en, wr_addr, rd_addr, din,
        output dout
    );
    modport ctrl (
        output wr_en, wr_addr, rd_addr, din,
        input  dout
    );
endinterface

`endif
