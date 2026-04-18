`timescale 1ns / 1ps

module ring_mod #(
    parameter logic [15:0] acc_in = 16'd27968
)(
    input logic clk,
    input logic n_rst,
    input logic signed [23:0] sample_in,
    input logic valid,

    output logic signed [23:0] out
);

localparam int AUDIO_W = 24;
localparam int FRAC_W = 23;
localparam int PHASE_W = 18;

localparam logic signed [AUDIO_W-1:0] AUDIO_MAX = 24'sh7FFFFF;
localparam logic signed [AUDIO_W-1:0] AUDIO_MIN = 24'sh800000;
localparam logic signed [47:0] AUDIO_MAX_EXT = 48'sd8388607;
localparam logic signed [47:0] AUDIO_MIN_EXT = -48'sd8388608;

logic [PHASE_W-1:0] acc_out;
logic [PHASE_W-1:0] phase;
logic [5:0] lut_addr;
logic acc_sign_lut;
logic signed [AUDIO_W-1:0] osc;
logic signed [AUDIO_W-1:0] osc_new;
logic signed [47:0] mult_out;
logic signed [47:0] scaled_out;
logic signed [AUDIO_W-1:0] out_comb;

ring_mod_accum U1(
    .B(acc_in),
    .CLK(valid ? clk : 1'b0),
    .Q(acc_out),
    .BYPASS(1'b0)
);

always_comb begin
    phase = acc_out;
    lut_addr = acc_out[16] ? ~acc_out[15:10] : acc_out[15:10];
end

ring_mod_lut U2(
    .clka(clk),
    .addra(lut_addr),
    .douta(osc)
);

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst)
        acc_sign_lut <= 1'b0;
    else
        acc_sign_lut <= acc_out[17];
end

always_comb begin
    if (!n_rst)
        osc_new = '0;
    else
        osc_new = acc_sign_lut ? -osc : osc;
end

ring_mod_mult U3(
    .CLK(clk),
    .A(osc_new),
    .B(sample_in),
    .P(mult_out)
);

always_comb begin
    scaled_out = mult_out >>> FRAC_W;

    if (scaled_out > AUDIO_MAX_EXT)
        out_comb = AUDIO_MAX;
    else if (scaled_out < AUDIO_MIN_EXT)
        out_comb = AUDIO_MIN;
    else
        out_comb = scaled_out[AUDIO_W-1:0];
end

assign out = out_comb;

endmodule
