`timescale 1ns / 1ps

module distortion #(
    parameter int XMAX = 4,
    parameter int N = 128,
    parameter int K = 64
)(
    input logic clk,
    input logic n_rst,
    input logic signed [23:0] y_in,

    output logic signed [23:0] out
);

localparam int AUDIO_W = 24;
localparam int FRAC_W = 23;
localparam int ADDR_W = $clog2(N);
localparam int K_SHIFT = $clog2(K);
localparam int XMAX_SHIFT = $clog2(XMAX);
localparam int CLIP_SHIFT = FRAC_W + XMAX_SHIFT;

localparam logic [25:0] XMAX_Q = XMAX * (1 << FRAC_W);

logic signed [63:0] mult_out;
logic [63:0] mag_full;
logic [25:0] mag_clip;
logic [ADDR_W-1:0] addr;
logic [ADDR_W-1:0] n_new;
logic [32:0] pre_addr;
logic sign;
logic [2:0] sign_pipe;
logic signed [AUDIO_W-1:0] d_out;
logic signed [AUDIO_W-1:0] out_reg;

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst)
        mult_out <= '0;
    else
        mult_out <= $signed(y_in) <<< K_SHIFT;
end

always_comb begin
    sign = mult_out < 0;
    mag_full = sign ? $unsigned(-mult_out) : $unsigned(mult_out);
    mag_clip = (mag_full > XMAX_Q) ? XMAX_Q : mag_full[25:0];
    n_new = ADDR_W'(N - 1);
end

distortion_mult U2(
    .CLK(clk),
    .A(mag_clip),
    .B(n_new),
    .P(pre_addr)
);

always_comb begin
    addr = pre_addr[CLIP_SHIFT +: ADDR_W];
end

distortion_lut U3(
    .clka(clk),
    .addra(addr),
    .douta(d_out)
);

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
        sign_pipe <= '0;
        out_reg <= '0;
    end else begin
        sign_pipe <= {sign_pipe[1:0], sign};
        out_reg <= sign_pipe[2] ? -d_out : d_out;
    end
end

assign out = out_reg;

endmodule
