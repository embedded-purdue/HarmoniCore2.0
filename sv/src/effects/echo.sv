`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/echo_if.vh"
`include "../../include/effects/echo_bram_if.vh"

// Algorithm:
//   1. buf[wr_ptr] holds the output written exactly ECHO_DELAY_SAMP steps ago.
//   2. Read past = buf[wr_ptr]  (via BRAM read; 1-cycle registered latency)
//   3. raw = data_in + (past >>> ECHO_FEEDBACK_SHIFT)
//   4. Saturate raw to 24-bit signed.
//   5. Write saturated result back to buf[wr_ptr]  (feedback loop)
//   6. Advance wr_ptr = (wr_ptr + 1) mod ECHO_DELAY_SAMP
//
// Pipeline stages (count 0..2):
//   count=0: idle — wait for valid_in; latch data_in; issue BRAM read at wr_ptr
//   count=1: bubble — BRAM registered output settling
//   count=2: BRAM output ready; compute raw; saturate; write to BRAM; output

module echo  // 3 clock cycle latency
import types::*;
(
    input logic clk, n_rst,
    echo_if.echo eif
);
    // Internal Signals
    logic [1:0]              count;
    logic [ECHO_ADDR_W-1:0]  wr_ptr;
    logic signed [DW-1:0]    p1_data;    // data_in latched at count=0
    logic [ECHO_ADDR_W-1:0]  p1_wr_ptr;  // wr_ptr latched at count=0

    // BRAM
    echo_bram_if bmif();
    echo_bram u_bram (.clk(clk), .bmif(bmif));

    // ── Next write pointer (wraps at ECHO_DELAY_SAMP) ───────────────────────
    logic [ECHO_ADDR_W-1:0] next_wr_ptr;
    always_comb
        next_wr_ptr = (wr_ptr == ECHO_ADDR_W'(ECHO_DELAY_SAMP - 1)) ? '0 : wr_ptr + 1'b1;

    // ── Main FSM ─────────────────────────────────────────────────────────────
    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            count         <= '0;
            wr_ptr        <= '0;
            p1_data       <= '0;
            p1_wr_ptr     <= '0;
            eif.valid_out <= 1'b0;
            eif.data_out  <= '0;
            bmif.wr_en    <= 1'b0;
            bmif.wr_addr  <= '0;
            bmif.rd_addr  <= '0;
            bmif.din      <= '0;
        end else begin
            eif.valid_out <= 1'b0;
            bmif.wr_en    <= 1'b0;

            case (count)

                // ── Cycle 0: idle ───────────────────────────────────────────
                2'd0: if (eif.valid_in) begin
                    p1_data      <= eif.data_in;
                    p1_wr_ptr    <= wr_ptr;
                    bmif.rd_addr <= wr_ptr;   // issue BRAM read; data ready after count=1
                    count        <= 2'd1;
                end

                // ── Cycle 1: bubble (BRAM output registering) ───────────────
                2'd1: count <= 2'd2;

                // ── Cycle 2: BRAM output ready; compute; write; output ───────
                2'd2: begin : blk
                    logic signed [DW:0]   raw;  // 25-bit
                    logic signed [DW-1:0] sat;

                    // raw = p1_data + (bmif.dout >>> ECHO_FEEDBACK_SHIFT)
                    // bmif.dout>>>SHIFT is pure wiring (arithmetic bit-select).
                    // 25-bit add + 2-bit overflow detect avoids 64-bit CARRY4 chains.
                    raw = {p1_data[DW-1], p1_data} +
                          {{(ECHO_FEEDBACK_SHIFT+1){bmif.dout[DW-1]}},
                            bmif.dout[DW-1:ECHO_FEEDBACK_SHIFT]};

                    if      (raw[DW:DW-1] == 2'b01) sat = DW'(SAT_MAX);
                    else if (raw[DW:DW-1] == 2'b10) sat = DW'(SAT_MIN);
                    else                              sat = raw[DW-1:0];

                    eif.data_out  <= sat;
                    eif.valid_out <= 1'b1;

                    // Write output back to BRAM (feedback loop)
                    bmif.wr_en   <= 1'b1;
                    bmif.wr_addr <= p1_wr_ptr;
                    bmif.din     <= sat;

                    wr_ptr <= next_wr_ptr;
                    count  <= 2'd0;
                end

                default: count <= 2'd0;
            endcase
        end
    end

endmodule
