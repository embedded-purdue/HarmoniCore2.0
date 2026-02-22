module harmonic_chorus #(
    parameter N = 1024,
    parameter MAX_DELAY = 512
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] y_in, 

    // Output
    output logic [17:0] out     
);

logic idx = 0;
logic [35:0] mult_out, depth, add1, add2, result;
logic [17:0] state, y_out, out1, out2, output;
logic amount;

mult_gen_0 U1(sr, DELAY_MS, clk, mult_out);

assign depth = (mult_out + 36'd512) >> 10;


// <for loop>
always @(posedge clk) begin
    if (rst)
        idx <= 0;
    else if (sample_en)
        idx <= idx + 1;
end

always @(posedge clk) begin
    if (sample_en)
        state[idx] <= y_in;
end

always_comb begin
    r_idx = idx - delay;
    delayed  = (idx >= delay) ? state[r_idx] : y_in;
    y_out = (y_in + delayed) >>> 1;
end

distortion #(.XMAX(), .N(), .K(2)) output1 (.clk(), .n_rst(), .y_in(y_out), .out(out1));
distortion #(.XMAX(), .N(), .K(1)) output2 (.clk(), .n_rst(), .y_in(y_out), .out(out2));

assign output = (out2) >> 1;
assign harm = out1 + output;

mult_gen_0 U2(harm, AMOUNT, clk, add1);

assign amount = 1 - AMOUNT;

mult_gen_0 U3(y_out, AMOUNT, clk, add2);

assign result = add1 + add2;


endmodule
