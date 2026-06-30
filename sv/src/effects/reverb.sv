`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/reverb_if.vh"

// Schroeder reverb — 15 clock cycle latency.
// Python reference: python/reverb.py  apply_reverb()
//
// Signal flow:
//   x ──┬──> comb_0 ──┐
//       ├──> comb_1 ──┤
//       ├──> comb_2 ──┼──> sum>>>2 ──> allpass_0 ──> allpass_1 ──> wet ──> mix ──> out
//       └──> comb_3 ──┘
//
// Pipeline (count 0..14):
//   0 : idle — latch data_in; issue comb BRAM reads
//   1 : bubble (comb BRAM settling)
//   2 : comb DSP    — comb_dout*COMB_GAIN_NUM → p_prod_shifted[4]; latch/advance comb ptrs
//   3 : comb sat    — sat(p1_x+p_prod_shifted[j]) → p_cout[4]; write comb BRAMs
//   4 : comb acc    — sum p_cout[0..3]>>>2 → p2_wet; issue ap0 read
//   5 : bubble (ap0 BRAM settling)
//   6 : ap0 DSP-1   — ap_dout[0]*AP_GAIN_NUM → p_buf_shifted[0]; latch/advance ap0 wr ptr
//   7 : ap0 DSP-2   — v=p2_wet+p_buf_shifted[0]; v*AP_GAIN_NUM → p_vprod_shifted[0]; store p_v[0]
//   8 : ap0 sat     — p2_wet=sat(ap_dout[0]-p_vprod_shifted[0]); write v to ap0 BRAM; issue ap1 read
//   9 : bubble (ap1 BRAM settling)
//  10 : ap1 DSP-1   — ap_dout[1]*AP_GAIN_NUM → p_buf_shifted[1]; latch/advance ap1 wr ptr
//  11 : ap1 DSP-2   — v=p2_wet+p_buf_shifted[1]; v*AP_GAIN_NUM → p_vprod_shifted[1]; store p_v[1]
//  12 : ap1 sat     — p2_wet=sat(ap_dout[1]-p_vprod_shifted[1]); write v to ap1 BRAM
//  13 : mix DSP     — p2_wet*WET_NUM → p_wet_shifted (24-bit registered)
//  14 : mix sat     — (p1_x>>>2)+p_wet_shifted → saturate → data_out; assert valid_out
//
// Splitting comb into 3 stages (DSP / saturate / accumulate) breaks the DSP-P→fanout-44
// saturation chain that violated 156 MHz.  15 cycles << 3250 cycles between 48 kHz samples.

module reverb
import types::*;
(
    input logic clk, n_rst,
    reverb_if.reverb rvif
);
    localparam int COMB_D [4] = REVERB_COMB_DELAYS;
    localparam int AP_D   [2] = REVERB_AP_DELAYS;

    logic [3:0]           count;
    logic signed [DW-1:0] p1_x;
    logic signed [DW-1:0] p2_wet;

    // ── Pipeline registers across count boundaries ───────────────────────────
    logic signed [DW-1:0] p_prod_shifted  [4]; // comb DSP:   (comb_dout*COMB_GAIN) >>> GAIN_SHIFT
    logic signed [DW-1:0] p_cout          [4]; // comb sat:   saturated (p1_x+p_prod_shifted[j])
    logic signed [DW-1:0] p_buf_shifted   [2]; // allpass DSP1: (ap_dout*AP_GAIN) >>> GAIN_SHIFT
    logic signed [DW:0]   p_vprod_shifted [2]; // allpass DSP2: (v*AP_GAIN) >>> GAIN_SHIFT (25-bit)
    logic signed [DW:0]   p_v             [2]; // allpass: unsaturated v, for BRAM write
    logic signed [DW-1:0] p_wet_shifted;       // mix DSP:    (p2_wet*WET_NUM) >>> GAIN_SHIFT

    // ── Comb BRAM signals ────────────────────────────────────────────────────
    logic [REVERB_COMB_ADDR_W-1:0] comb_wr_ptr  [4];
    logic [REVERB_COMB_ADDR_W-1:0] comb_wr_addr [4];
    logic [REVERB_COMB_ADDR_W-1:0] comb_rd_addr [4];
    logic                           comb_wr_en   [4];
    logic signed [DW-1:0]           comb_din     [4];
    logic signed [DW-1:0]           comb_dout    [4];

    generate
        for (genvar j = 0; j < 4; j++) begin : comb_brams
            reverb_bram #(.DEPTH(COMB_D[j]), .ADDR_W(REVERB_COMB_ADDR_W)) u (
                .clk(clk), .wr_en(comb_wr_en[j]),
                .wr_addr(comb_wr_addr[j]), .rd_addr(comb_rd_addr[j]),
                .din(comb_din[j]),         .dout(comb_dout[j])
            );
        end
    endgenerate

    // ── Allpass BRAM signals ─────────────────────────────────────────────────
    logic [REVERB_AP_ADDR_W-1:0] ap_wr_ptr  [2];
    logic [REVERB_AP_ADDR_W-1:0] ap_wr_addr [2];
    logic [REVERB_AP_ADDR_W-1:0] ap_rd_addr [2];
    logic                         ap_wr_en   [2];
    logic signed [DW-1:0]         ap_din     [2];
    logic signed [DW-1:0]         ap_dout    [2];

    generate
        for (genvar k = 0; k < 2; k++) begin : ap_brams
            reverb_bram #(.DEPTH(AP_D[k]), .ADDR_W(REVERB_AP_ADDR_W)) u (
                .clk(clk), .wr_en(ap_wr_en[k]),
                .wr_addr(ap_wr_addr[k]), .rd_addr(ap_rd_addr[k]),
                .din(ap_din[k]),         .dout(ap_dout[k])
            );
        end
    endgenerate

    // ── Main FSM ─────────────────────────────────────────────────────────────
    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            count          <= '0;
            p1_x           <= '0;
            p2_wet         <= '0;
            p_wet_shifted  <= '0;
            rvif.valid_out <= 1'b0;
            rvif.data_out  <= '0;
            for (int j = 0; j < 4; j++) begin
                p_prod_shifted[j] <= '0;
                p_cout        [j] <= '0;
                comb_wr_ptr  [j]  <= '0;
                comb_wr_addr [j]  <= '0;
                comb_rd_addr [j]  <= '0;
                comb_wr_en   [j]  <= 1'b0;
                comb_din     [j]  <= '0;
            end
            for (int k = 0; k < 2; k++) begin
                p_buf_shifted   [k] <= '0;
                p_vprod_shifted [k] <= '0;
                p_v             [k] <= '0;
                ap_wr_ptr  [k]  <= '0;
                ap_wr_addr [k]  <= '0;
                ap_rd_addr [k]  <= '0;
                ap_wr_en   [k]  <= 1'b0;
                ap_din     [k]  <= '0;
            end
        end else begin
            rvif.valid_out <= 1'b0;
            for (int j = 0; j < 4; j++) comb_wr_en[j] <= 1'b0;
            for (int k = 0; k < 2; k++) ap_wr_en  [k] <= 1'b0;

            case (count)

                // ── 0: idle ──────────────────────────────────────────────────
                4'd0: if (rvif.valid_in) begin
                    p1_x <= rvif.data_in;
                    for (int j = 0; j < 4; j++)
                        comb_rd_addr[j] <= comb_wr_ptr[j];
                    count <= 4'd1;
                end

                // ── 1: bubble (comb BRAM settling) ───────────────────────────
                4'd1: count <= 4'd2;

                // ── 2: comb DSP only ─────────────────────────────────────────
                // Path: comb_dout(BRAM FF) → DSP A→P → bit-select(wiring) → FF
                4'd2: begin : comb_dsp
                    for (int j = 0; j < 4; j++) begin
                        logic signed [34:0] prod;   // 24×11-bit = 35-bit
                        prod = $signed(comb_dout[j]) *
                               $signed(11'(REVERB_COMB_GAIN_NUM));
                        p_prod_shifted[j] <= prod[DW-1+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];

                        comb_wr_addr[j] <= comb_wr_ptr[j];
                        comb_wr_ptr [j] <= (comb_wr_ptr[j] == REVERB_COMB_ADDR_W'(COMB_D[j]-1))
                                            ? '0 : comb_wr_ptr[j] + REVERB_COMB_ADDR_W'(1);
                    end
                    count <= 4'd3;
                end

                // ── 3: comb saturate → p_cout[4]; write comb BRAMs ───────────
                // One 25-bit add + overflow detect per output. No fanout issues.
                // Path: FF × 2 → 25-bit add → 2-bit overflow → FF  (~4 ns)
                4'd3: begin : comb_sat
                    for (int j = 0; j < 4; j++) begin
                        logic signed [DW:0]   raw;
                        logic signed [DW-1:0] cout;
                        raw = {p1_x[DW-1],             p1_x}             +
                              {p_prod_shifted[j][DW-1], p_prod_shifted[j]};
                        if      (raw[DW:DW-1] == 2'b01) cout = DW'(SAT_MAX);
                        else if (raw[DW:DW-1] == 2'b10) cout = DW'(SAT_MIN);
                        else                              cout = raw[DW-1:0];
                        p_cout    [j] <= cout;
                        comb_din  [j] <= cout;
                        comb_wr_en[j] <= 1'b1;
                    end
                    count <= 4'd4;
                end

                // ── 4: comb accumulate → p2_wet; issue ap0 read ──────────────
                // 4-way sum of registered p_cout values, then shift-right-2 (wiring).
                // Path: FF × 4 → tree-add(26-bit) → shift(wiring) → FF  (~4 ns)
                4'd4: begin : comb_acc
                    logic signed [DW+1:0] comb_sum;  // 26-bit
                    comb_sum = {{2{p_cout[0][DW-1]}}, p_cout[0]} +
                               {{2{p_cout[1][DW-1]}}, p_cout[1]} +
                               {{2{p_cout[2][DW-1]}}, p_cout[2]} +
                               {{2{p_cout[3][DW-1]}}, p_cout[3]};
                    // sum>>>2 always fits in DW bits (4×24-bit / 4 ≤ 24-bit range)
                    p2_wet <= comb_sum[DW+1:2];

                    ap_rd_addr[0] <= ap_wr_ptr[0];
                    count <= 4'd5;
                end

                // ── 5: bubble (ap0 BRAM settling) ────────────────────────────
                4'd5: count <= 4'd6;

                // ── 6: ap0 DSP-1 ─────────────────────────────────────────────
                // Path: ap_dout[0](BRAM FF) → DSP A→P → bit-select → FF
                4'd6: begin : ap0_dsp1
                    logic signed [34:0] prod;
                    prod = $signed(ap_dout[0]) * $signed(11'(REVERB_AP_GAIN_NUM));
                    p_buf_shifted[0] <= prod[DW-1+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];

                    ap_wr_addr[0] <= ap_wr_ptr[0];
                    ap_wr_ptr [0] <= (ap_wr_ptr[0] == REVERB_AP_ADDR_W'(AP_D[0]-1))
                                      ? '0 : ap_wr_ptr[0] + REVERB_AP_ADDR_W'(1);
                    count <= 4'd7;
                end

                // ── 7: ap0 DSP-2 ─────────────────────────────────────────────
                // Path: FF+FF → 25-bit add → DSP A→P (no intermediate sat) → bit-select → FF
                4'd7: begin : ap0_dsp2
                    logic signed [DW:0]  v;
                    logic signed [35:0]  vprod;
                    v     = {p2_wet[DW-1],           p2_wet}           +
                            {p_buf_shifted[0][DW-1], p_buf_shifted[0]};
                    vprod = $signed(v) * $signed(11'(REVERB_AP_GAIN_NUM));
                    p_vprod_shifted[0] <= vprod[DW+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];
                    p_v[0]             <= v;
                    count <= 4'd8;
                end

                // ── 8: ap0 subtract+saturate; write ap0 BRAM; issue ap1 read ─
                4'd8: begin : ap0_sat
                    logic signed [DW+1:0] raw;
                    raw = {{2{ap_dout[0][DW-1]}}, ap_dout[0]} -
                          {p_vprod_shifted[0][DW], p_vprod_shifted[0]};
                    if      (raw[DW+1:DW-1] == 3'b000 ||
                             raw[DW+1:DW-1] == 3'b111)  p2_wet <= raw[DW-1:0];
                    else if (raw[DW+1])                  p2_wet <= DW'(SAT_MIN);
                    else                                  p2_wet <= DW'(SAT_MAX);

                    if      (p_v[0][DW:DW-1] == 2'b01) ap_din[0] <= DW'(SAT_MAX);
                    else if (p_v[0][DW:DW-1] == 2'b10) ap_din[0] <= DW'(SAT_MIN);
                    else                                 ap_din[0] <= p_v[0][DW-1:0];
                    ap_wr_en[0] <= 1'b1;

                    ap_rd_addr[1] <= ap_wr_ptr[1];
                    count <= 4'd9;
                end

                // ── 9: bubble (ap1 BRAM settling) ────────────────────────────
                4'd9: count <= 4'd10;

                // ── 10: ap1 DSP-1 ────────────────────────────────────────────
                4'd10: begin : ap1_dsp1
                    logic signed [34:0] prod;
                    prod = $signed(ap_dout[1]) * $signed(11'(REVERB_AP_GAIN_NUM));
                    p_buf_shifted[1] <= prod[DW-1+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];

                    ap_wr_addr[1] <= ap_wr_ptr[1];
                    ap_wr_ptr [1] <= (ap_wr_ptr[1] == REVERB_AP_ADDR_W'(AP_D[1]-1))
                                      ? '0 : ap_wr_ptr[1] + REVERB_AP_ADDR_W'(1);
                    count <= 4'd11;
                end

                // ── 11: ap1 DSP-2 ────────────────────────────────────────────
                4'd11: begin : ap1_dsp2
                    logic signed [DW:0]  v;
                    logic signed [35:0]  vprod;
                    v     = {p2_wet[DW-1],           p2_wet}           +
                            {p_buf_shifted[1][DW-1], p_buf_shifted[1]};
                    vprod = $signed(v) * $signed(11'(REVERB_AP_GAIN_NUM));
                    p_vprod_shifted[1] <= vprod[DW+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];
                    p_v[1]             <= v;
                    count <= 4'd12;
                end

                // ── 12: ap1 subtract+saturate; write ap1 BRAM ────────────────
                4'd12: begin : ap1_sat
                    logic signed [DW+1:0] raw;
                    raw = {{2{ap_dout[1][DW-1]}}, ap_dout[1]} -
                          {p_vprod_shifted[1][DW], p_vprod_shifted[1]};
                    if      (raw[DW+1:DW-1] == 3'b000 ||
                             raw[DW+1:DW-1] == 3'b111)  p2_wet <= raw[DW-1:0];
                    else if (raw[DW+1])                  p2_wet <= DW'(SAT_MIN);
                    else                                  p2_wet <= DW'(SAT_MAX);

                    if      (p_v[1][DW:DW-1] == 2'b01) ap_din[1] <= DW'(SAT_MAX);
                    else if (p_v[1][DW:DW-1] == 2'b10) ap_din[1] <= DW'(SAT_MIN);
                    else                                 ap_din[1] <= p_v[1][DW-1:0];
                    ap_wr_en[1] <= 1'b1;

                    count <= 4'd13;
                end

                // ── 13: mix DSP — wet term only ──────────────────────────────
                // Path: p2_wet(FF) → DSP A→P (3.23 ns) → bit-select(wiring) → FF
                4'd13: begin : mix_dsp
                    logic signed [34:0] prod;
                    prod = $signed(p2_wet) * $signed(11'(REVERB_WET_NUM));
                    p_wet_shifted <= prod[DW-1+REVERB_GAIN_SHIFT : REVERB_GAIN_SHIFT];
                    count <= 4'd14;
                end

                // ── 14: mix add/saturate; output ─────────────────────────────
                // dry_shifted = p1_x*DRY_NUM>>>GAIN_SHIFT = p1_x>>>2 (pure wiring)
                // Path: FF×2 → 25-bit add → 2-bit overflow → FF  (~3 ns)
                4'd14: begin : mix_sat
                    logic signed [DW:0] raw;
                    raw = {{3{p1_x[DW-1]}}, p1_x[DW-1:2]} +
                          {p_wet_shifted[DW-1], p_wet_shifted};
                    if      (raw[DW:DW-1] == 2'b01) rvif.data_out <= DW'(SAT_MAX);
                    else if (raw[DW:DW-1] == 2'b10) rvif.data_out <= DW'(SAT_MIN);
                    else                              rvif.data_out <= raw[DW-1:0];
                    rvif.valid_out <= 1'b1;
                    count <= 4'd0;
                end

                default: count <= 4'd0;
            endcase
        end
    end

endmodule
