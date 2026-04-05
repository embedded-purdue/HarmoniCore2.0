module ring_mod #(
    parameter acc_in = 16'd27968     // Acculumator input value = 13.65625
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] sample_in, 
    input logic valid,

    // Debug/observation outputs
    output logic [17:0] acc_out,
    output logic acc_sign2,
    output logic acc_sign1,
    output logic acc_sign,
    output logic [17:0] phase,
    output logic [17:0] osc, 
    output logic [17:0] osc_new,
    output logic [35:0] mult_out,
    output logic [17:0] out
);

ring_mod_accum U1(
    .B(acc_in),
    .CLK(valid ? clk : 1'b0), // Only clock when valid is high
    .Q(acc_out),
    .BYPASS(1'b0)
);

ring_mod_lut U2(
    .clka(clk),
    .addra(phase[16:11]), // Use the upper 7 bits of phase as address
    .douta(osc)
);

always_comb begin
    if (acc_out[16] == 0) begin
        phase = acc_out;
    end else begin
        phase = 63 - acc_out;
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if (~n_rst) begin
        acc_sign2 <= 1'b0;
        acc_sign1 <= 1'b0;
        acc_sign <= 1'b0;
    end else begin 
        acc_sign2 <= acc_out[17];
        acc_sign1 <= acc_sign2;
        acc_sign <= acc_sign1;
    end
end

always_comb begin
    if (~n_rst) begin
        osc_new = 18'b0;
    end else begin
        if(acc_sign == 1'b1) begin
            osc_new = ~osc + 18'd1;
        end else begin
            osc_new = osc;
        end
    end
end

ring_mod_mult U3(
    .CLK(clk),
    .A(osc_new),
    .B(sample_in),
    .P(mult_out)
);

always_comb begin
    out = mult_out[28:11]; // Take the correct 18 bits as output
end

// change to combinatonal logic between accum and LUT
// change to combinational logic between LUT and mult

endmodule
