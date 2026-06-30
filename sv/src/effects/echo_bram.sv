`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/echo_bram_if.vh"

// Behavioral simple dual-port BRAM.
// Write port: wr_en / wr_addr / din  (synchronous, no read on write)
// Read port : rd_addr / dout         (registered output — 1 clock latency)
// Depth = ECHO_DELAY_SAMP (14 400), Width = DW (24-bit signed).
// Vivado infers this as a Simple Dual Port Block RAM automatically.
module echo_bram
import types::*;
(
    input logic clk,
    echo_bram_if.mem bmif
);
    logic signed [DW-1:0] mem [0:ECHO_DELAY_SAMP-1];

    // Zero-initialise for simulation (Xilinx BRAMs power up at 0 by default)
    initial
        for (int i = 0; i < ECHO_DELAY_SAMP; i++)
            mem[i] = '0;

    always_ff @(posedge clk) begin
        if (bmif.wr_en)
            mem[bmif.wr_addr] <= bmif.din;
        bmif.dout <= mem[bmif.rd_addr];
    end

endmodule
