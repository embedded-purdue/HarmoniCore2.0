module ring_mod #(
    parameter acc_in = 16'd27968,     // Acculumator input value = 13.65625
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] sample_in, 

    // Output
    output logic [17:0] acc_out,
    output logic [0:0] acc_sign2,
    output logic [0:0] acc_sign1,
    output logic [0:0] acc_sign,
    output logic [17:0] phase,
    output logic [17:0] osc, 
    output logic [17:0] osc_new,
    output logic [35:0] mult_out,
    output logic [17:0] out
);

ring_mod_accum U1(
    .B(acc_in),
    .CLK(clk),
    .P(acc_out)
);

ring_mod_lut U2(
    .clka(clk),
    .addra(phase[6:0]), // Use the upper 7 bits of phase as address
    .douta(osc)
);

always_ff @(posedge clk, negedge n_rst) begin
    if (~n_rst) begin
        acc_out <= 18'b0;
        phase <= 18'b0;
    end
    acc_sign2 <= acc_out[17];
    acc_sign1 <= acc_sign2;
    acc_sign <= acc_sign1;
end

always_ff @(negedge clk) begin
    if(acc_out[16] == 0) begin
            phase <= acc_out
        end else begin
            phase <= 63 - acc_out
    end

    if(acc_sign == 1) begin
        osc_new = ~osc + 1;
    end
    else begin
        osc_new = osc;
    end
end

ring_mod_mult U3(
    .clka(clk),
    .A(osc_new),
    .B(sample_in),
    .P(mult_out)
)

always_comb begin
    out = mult_out[28:11]; // Take the correct 18 bits as output
end

endmodule