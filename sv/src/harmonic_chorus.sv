module harmonic_chorus #(
    parameter N = 1024,
    parameter MAX_DELAY = 512
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] y_in, 
    input logic sample_en,
    input logic [$clog2(N)-1:0] delay,
    input logic [17:0] DELAY_MS,
    input logic [17:0] AMOUNT,
    input logic [17:0] sr,

    // Output
    output logic [23:0] out     
);

logic [$clog2(N)-1:0]idx = 0;
logic [35:0] mult_out, depth, add1, add2, result;
logic [17:0] state [0:N-1];
logic [17:0] y_out, out1, out2, mix_out;
logic [17:0] amount;
logic [$clog2(N)-1:0] r_idx;
logic [17:0] delayed;
logic [17:0] harm;

mult_gen_0 U1 (
    .CLK(clk),
    .A(sr),
    .B(DELAY_MS),
    .P(mult_out)
);

assign depth = (mult_out + 36'd512) >> 10;
// <for loop>
always @(posedge clk, negedge n_rst) begin
    if (~n_rst) begin
        idx <= 0;
    end
    else if (sample_en) begin
        idx <= idx + 1;
        state[idx] <= y_in;
    end
end

always_comb begin
    r_idx = idx - delay;
    delayed  = (idx >= delay) ? state[r_idx] : y_in;
    y_out = (y_in + delayed) >>> 1;
end

// need to check if the output of distortion also 1 sign bit and rest magnitude bit
distortion #(.K(2)) output1 (.clk(clk), .n_rst(n_rst), .y_in(y_out), .out(out1));
distortion #(.K(1)) output2 (.clk(clk), .n_rst(n_rst), .y_in(y_out), .out(out2));

assign mix_out = out2 >> 1;
assign harm = out1 + mix_out;

// AMOUNT complement for mixing (adjust per Q-format if needed)
assign amount = 18'd1 - AMOUNT;

    // needs to check harm (continued from distortion), shouldn't be 2's complement for clean calculation)
mult_gen_0 U2(clk, AMOUNT, harm, add1);
mult_gen_0 U3(clk, amount, y_out, add2);

assign result = add1 + add2;

// Drive module output (truncate/round as appropriate)
    assign out = result[23:0];

endmodule
