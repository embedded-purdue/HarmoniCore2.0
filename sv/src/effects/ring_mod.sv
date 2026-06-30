
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/ring_mod_if.vh"

module ring_mod // 3 clock cycles latency
import types::*;
(
    input logic clk, n_rst,
    ring_mod_if.ring_mod rmif
);
    // Quarter-wave sine LUT
    // 64 entries, 18-bit signed, first 90° only
    logic signed [SIN_BITS-1:0] sin_lut [0:LUT_SIZE-1];
    initial
        for (int i = 0; i < LUT_SIZE; i++)
            sin_lut[i] = SIN_BITS'(int'($floor($sin(2.0*$acos(-1.0)*i/(LUT_SIZE*4))*real'(SIN_MAX)+0.5)));

    //  Internal Signals
    logic [PHASE_BITS-1:0] phase;
    logic [1:0] phase_quad;
    logic [LUT_BITS-1:0] phase_off, lut_addr;
    logic lut_negate;
    logic signed [SIN_BITS-1:0] lut_raw;

    always_comb begin
        phase_quad = phase[PHASE_BITS-1 -: 2]; // top 2 bits determine quadrant
        phase_off = phase[PHASE_BITS-3 -: LUT_BITS]; // rest determine sine LUT offset
        lut_addr = phase_quad[0] ? (LUT_BITS'(LUT_SIZE-1) - phase_off) : phase_off;
        lut_negate = phase_quad[1];
        lut_raw = sin_lut[lut_addr];
    end

    // LUT lookup + increment phase
    logic signed [SIN_BITS-1:0] carrier_s1;
    logic signed [DW-1:0] data_s1;
    logic valid_s1;

    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            phase <= '0;
            carrier_s1 <= '0;
            data_s1 <= '0;
            valid_s1 <= 1'b0;
        end 
        else begin
            valid_s1 <= rmif.valid_in;
            if (rmif.valid_in) begin
                carrier_s1 <= lut_negate ? -lut_raw : lut_raw; // get carrier from LUT
                data_s1    <= rmif.data_in;                    // will multiply carrier w/ data
                phase      <= phase + PHASE_BITS'(PHASE_INC);  // increment phase for next LUT lookup
            end
        end
    end

    // Multiply data
    // Q1.23 * Q1.17 = Q2.40 --> right shift by 17 bits to get back to Q1.23
    logic signed [DW+SIN_BITS-1:0] product;
    logic signed [DW:0] scaled;

    always_comb begin
        product = data_s1 * carrier_s1;
        scaled  = product[DW+SIN_BITS-1:SIN_SHIFT];
    end

    // Stage 2: register the DSP output (bit-select) — breaks combinational DSP→sat path
    logic signed [DW:0] p_scaled;
    logic valid_s2;

    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            p_scaled <= '0;
            valid_s2 <= 1'b0;
        end else begin
            valid_s2 <= valid_s1;
            if (valid_s1) p_scaled <= scaled;
        end
    end

    // Stage 3: saturate registered product
    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            rmif.valid_out <= 1'b0;
            rmif.data_out  <= '0;
        end else begin
            rmif.valid_out <= valid_s2;
            if (valid_s2) begin
                if      (p_scaled[DW:DW-1] == 2'b01) rmif.data_out <= DW'(SAT_MAX);
                else if (p_scaled[DW:DW-1] == 2'b10) rmif.data_out <= DW'(SAT_MIN);
                else                                  rmif.data_out <= DW'(p_scaled);
            end
        end
    end

endmodule
