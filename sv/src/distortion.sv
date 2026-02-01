module distortion #(
    parameter XMAX = 4,
    parameter N = 1024,
    parameter K = 100
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] y_in, 

    // Output
    output logic [17:0] out     
);

logic [17:0] mag, mag_clip, d_out, N_new, pre_addr;
logic [35:0] mult_out;
logic sign;
logic [9:0] addr; 

multiplier_name U1(y_in, k, clk, mult_out);

always_comb begin
    sign = mult_out[35] > 0;
    mag = sign ? ~mult_out + 1 : mult_out;
    mag_clip = mag > 4 ? 4 : mag;
    N_new = N - 1;
end

multiplier_name U2(mag_clip, N_new, clk, pre_addr);

always_comb begin
    addr = pre_addr >> 2; //in terms of xmax
end

rom_name U1(addr, clk, d_out, 1'b1);

always_comb begin
    out = sign ? ~d_out + 1 : d_out;
end

endmodule