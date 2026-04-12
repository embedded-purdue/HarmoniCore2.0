module distortion #(
    parameter XMAX = 4,     // Maximum input value (clips at ±4.0)
    parameter N = 128,      // LUT size: 128 entries
    parameter K = 64        // Gain multiplier for distortion amount; keep as a power of 2
)(
    // Inputs
    input logic clk,
    input logic n_rst,
    input logic [17:0] y_in, 

    // Output
    output logic [17:0] out
);

    localparam int K_SHIFT = $clog2(K);

    logic [17:0] mag, mag_clip, d_out, N_new;
    logic signed [17:0] y_in_signed;
    logic signed [35:0] y_in_ext;
    logic signed [35:0] mult_out;
    logic [35:0] pre_addr;
    logic sign;
    logic [2:0] sign_pipe;  // 3-stage pipeline for sign
    logic [6:0] addr;       // 7-bit address for 128-entry LUT
    logic [17:0] out_reg;

    assign y_in_signed = y_in;
    assign y_in_ext = {{18{y_in_signed[17]}}, y_in_signed};

    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst)
            mult_out <= '0;
        else
            mult_out <= y_in_ext <<< K_SHIFT;
    end

    always_comb begin
        sign = mult_out[35];
        mag = sign ? (~mult_out[17:0] + 1) : mult_out[17:0];
        mag_clip = mag > 8192 ? 8192 : mag;  // 4.0 in Q11 format
        N_new = N - 1;
    end

    mult_gen_0 U2(
        .CLK(clk),
        .A(mag_clip),
        .B(N_new),
        .P(pre_addr)
    );

    always_comb begin
        addr = pre_addr[19:13]; // addr = (mag_clip * 127) / 8192, extract 7 bits
    end

    blk_mem_gen_0 U3(
        .clka(clk),
        .addra(addr),
        .douta(d_out)
    );

    // Pipeline register with negative reset
    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            sign_pipe <= 3'b0;
            out_reg <= 18'b0;
        end else begin
            sign_pipe <= {sign_pipe[1:0], sign};  // 3-cycle delay shift register
            out_reg <= sign_pipe[2] ? ~d_out + 1 : d_out;
        end
    end

    assign out = out_reg;

endmodule