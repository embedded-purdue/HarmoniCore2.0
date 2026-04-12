module harmonic_chorus #(
    parameter N = 1024,
    parameter MAX_DELAY = 512
)(
    harmonic_chorus_if.dut iface
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
        .CLK(iface.clk),
        .A(iface.sr),
        .B(iface.DELAY_MS),
        .P(mult_out)
    );


    assign depth = (mult_out + 36'd512) >> 10;
    // <for loop>
    always @(posedge iface.clk, negedge iface.n_rst) begin
        if (~iface.n_rst) begin
            idx <= 0;
        end
        else if (iface.sample_en) begin
            idx <= idx + 1;
            state[idx] <= iface.y_in;
        end
    end

    always_comb begin
        r_idx = idx - iface.delay;
        delayed  = (idx >= iface.delay) ? state[r_idx] : iface.y_in;
        y_out = (iface.y_in + delayed) >>> 1;
    end

    // need to check if the output of distortion also 1 sign bit and rest magnitude bit
    distortion #(.K(2)) output1 (.clk(iface.clk), .n_rst(iface.n_rst), .y_in(y_out), .out(out1));
    distortion #(.K(1)) output2 (.clk(iface.clk), .n_rst(iface.n_rst), .y_in(y_out), .out(out2));

    assign mix_out = out2 >> 1;
    assign harm = out1 + mix_out;

    // AMOUNT complement for mixing (adjust per Q-format if needed)
    assign amount = 18'd1 - iface.AMOUNT;

    // needs to check harm (continued from distortion), shouldn't be 2's complement for clean calculation)
    mult_gen_0 U2(iface.clk, iface.AMOUNT, harm, add1);
    mult_gen_0 U3(iface.clk, amount, y_out, add2);

    assign result = add1 + add2;

    // Drive module output (truncate/round as appropriate)
    assign iface.out = result[23:0];

endmodule
