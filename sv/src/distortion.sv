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
logic sign, sign_reg;
logic [9:0] addr; 
logic [17:0] out_reg;

mult_gen_0 U1(y_in, K, clk, mult_out);

always_comb begin
    sign = mult_out[35];
    mag = sign ? (~mult_out + 1) : mult_out;
    mag_clip = mag > 8192 ? 8192 : mag;  // 4.0 in Q11 format
    N_new = N - 1;
end

mult_gen_0 U2(mag_clip, N_new, clk, pre_addr);

always_comb begin
    addr = pre_addr >> 2; //make this in terms of xmax
end

blk_mem_gen_0 U1(addr, clk, d_out, 1'b1);

// Pipeline register with negative reset
always_ff @(posedge clk, negedge n_rst) begin
    if (~n_rst) begin
        sign_reg <= 1'b0;
        out_reg <= 18'b0;
    end else begin
        sign_reg <= sign;
        out_reg <= sign_reg ? ~d_out + 1 : d_out;
    end
end

assign out = out_reg;

endmodule