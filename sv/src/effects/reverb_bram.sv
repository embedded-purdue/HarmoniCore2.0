`timescale 1ns / 10ps
`include "../../include/types.sv"

// Parameterized simple dual-port BRAM.
// Write port: wr_en / wr_addr / din  (synchronous)
// Read port : rd_addr / dout         (registered output — 1-cycle latency)
// Vivado infers this as a Simple Dual Port Block RAM.
// Instantiated 6× by reverb.sv with different DEPTH/ADDR_W values.
module reverb_bram
import types::*;
#(
    parameter int DEPTH  = 2011,
    parameter int ADDR_W = REVERB_COMB_ADDR_W
) (
    input  logic              clk,
    input  logic              wr_en,
    input  logic [ADDR_W-1:0] wr_addr,
    input  logic [ADDR_W-1:0] rd_addr,
    input  logic signed [DW-1:0] din,
    output logic signed [DW-1:0] dout
);
    logic signed [DW-1:0] mem [0:DEPTH-1];

    initial
        for (int i = 0; i < DEPTH; i++)
            mem[i] = '0;

    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= din;
        dout <= mem[rd_addr];
    end

endmodule
