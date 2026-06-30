`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/vibrato_if.vh"
`include "../../include/effects/memwrapper_if.vh"

module vibrato // 6 clock cycle latency
import types::*;
(
    input logic clk, n_rst,
    vibrato_if.vibrato vbif
);
    // Quarter-wave sine LUT (same as ring_mod)
    // 64 entries, 18-bit signed, first 90° only
    logic signed [SIN_BITS-1:0] sin_lut [0:LUT_SIZE-1];
    initial
        for (int i = 0; i < LUT_SIZE; i++)
            sin_lut[i] = SIN_BITS'(int'($floor($sin(2.0*$acos(-1.0)*i/(LUT_SIZE*4))*real'(SIN_MAX)+0.5)));

    // Internal Signals
    logic [2:0] count; // manages clock cycles (basically an FSM)
    logic [7:0] wr_ptr;
    logic [PHASE_BITS-1:0] phase;
    logic signed [DW-1:0] p1_sample;
    logic signed [SIN_BITS-1:0] p2_lfo;
    logic [7:0] p2_wr;
    logic signed [23:0] p3_dprod; // VIB_DEPTH_SAMP * lfo
    logic [7:0] p3_wr;
    logic [16:0] p4_frac; // delay_frac [SIN_SHIFT-1:0]
    logic [7:0] p4_rd0, p4_rd1;
    logic signed [63:0] p5_prod0, p5_prod1;

    // BRAM module
    memwrapper_if memif();
    memwrapper u_mem (.clk(clk), .n_rst(n_rst), .memif(memif));

    // Decoding LUT address and sign
    logic [7:0] lfo_p8;
    logic [1:0] lfo_quad;
    logic [5:0] lfo_offs, lfo_addr;
    logic signed [SIN_BITS-1:0] lfo_raw, lfo_val;
    always_comb begin
        lfo_p8   = phase[31:24];
        lfo_quad = lfo_p8[7:6];
        lfo_offs = lfo_p8[5:0];
        lfo_addr = lfo_quad[0] ? (6'd63 - lfo_offs) : lfo_offs;
        lfo_raw  = sin_lut[lfo_addr];
        lfo_val  = lfo_quad[1] ? -lfo_raw : lfo_raw;
    end

    // delay_fixed = BASE * 2^17 + DEPTH * lfo  — always in [48, 144] integer samples
    logic signed [31:0] delay_fixed;
    logic [7:0]         delay_int; // delay_fixed >> 17
    logic [16:0]        delay_frac; // delay_fixed & (2^17-1)
    always_comb begin
        delay_fixed = VIB_BASE_DELAY * (1 << SIN_SHIFT) + p3_dprod;
        delay_int = 8'(delay_fixed >>> SIN_SHIFT);
        delay_frac = delay_fixed[SIN_SHIFT-1:0];
    end

    // comp = 2^17 - frac.  Range [1, 131072].  Needs 19 signed bits to stay +ve.
    logic signed [63:0] s0_ext, s1_ext, comp_ext, frac_ext;
    always_comb begin
        s0_ext   = {{40{memif.douta[DW-1]}}, memif.douta};
        s1_ext   = {{40{memif.doutb[DW-1]}}, memif.doutb};
        frac_ext = {47'b0, p4_frac};
        comp_ext = 64'sd131072 - $signed({47'b0, p4_frac});
    end

    // Basically FSM stages based on count
    always_ff @(posedge clk) begin
        if (~n_rst) begin
            count          <= '0;
            phase          <= '0;
            wr_ptr         <= '0;
            vbif.valid_out <= 1'b0;
            vbif.data_out  <= '0;
            memif.wea      <= 1'b0;  
            memif.web      <= 1'b0;
            memif.addra    <= '0;    
            memif.addrb    <= '0;
            memif.dina     <= '0;    
            memif.dinb     <= '0;
        end else begin
            memif.wea      <= 1'b0;
            memif.web      <= 1'b0;
            vbif.valid_out <= 1'b0;

            case (count)
                // ── Cycle 0: idle — wait for valid_in ──────────────────────
                3'd0: if (vbif.valid_in) begin
                    p1_sample <= vbif.data_in;
                    count     <= 3'd1;
                end

                // ── Cycle 1: write sample to BRAM; latch LFO value ─────────
                3'd1: begin
                    memif.wea   <= 1'b1;
                    memif.addra <= wr_ptr;
                    memif.dina  <= p1_sample;
                    p2_lfo      <= lfo_val;
                    p2_wr       <= wr_ptr;
                    phase       <= phase + PHASE_BITS'(VIB_PHASE_INC);
                    count         <= 3'd2;
                end

                // ── Cycle 2: DEPTH * lfo ────────────────────────────────────
                3'd2: begin
                    p3_dprod <= 24'(VIB_DEPTH_SAMP * p2_lfo);
                    p3_wr    <= p2_wr;
                    count    <= 3'd3;
                end

                // ── Cycle 3: compute rd0/rd1; issue BRAM dual-read ──────────
                3'd3: begin
                    p4_frac  <= delay_frac;
                    p4_rd0   <= 8'(p3_wr - delay_int);
                    p4_rd1   <= 8'(p3_wr - delay_int + 1);
                    memif.addra <= 8'(p3_wr - delay_int);
                    memif.addrb <= 8'(p3_wr - delay_int + 1);
                    count      <= 3'd4;
                end

                // ── Cycle 4: bubble — wait for BRAM registered output ──────
                3'd4: begin
                    count <= 3'd5;
                end

                // ── Cycle 5: BRAM output ready; interpolation multiplies ────
                3'd5: begin
                    p5_prod0 <= s0_ext * comp_ext;
                    p5_prod1 <= s1_ext * frac_ext;
                    count    <= 3'd6;
                end

                // ── Cycle 6: sum, shift, saturate, output ───────────────────
                3'd6: begin
                    begin : blk
                        logic signed [63:0] raw, shifted;
                        raw     = p5_prod0 + p5_prod1;
                        shifted = raw >>> SIN_SHIFT;
                        if      (shifted > $signed(64'(SAT_MAX))) vbif.data_out <= DW'(SAT_MAX);
                        else if (shifted < $signed(64'(SAT_MIN))) vbif.data_out <= DW'(SAT_MIN);
                        else                                       vbif.data_out <= DW'(shifted);
                    end
                    vbif.valid_out <= 1'b1;
                    wr_ptr         <= wr_ptr + 8'd1;
                    count          <= 3'd0;
                end

                default: count <= 3'd0;
            endcase
        end
    end

endmodule
