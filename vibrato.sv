module  vibrato(
    
)(
    // Inputs
    input logic clk,
    input logic rst,
    input logic [28:18] ring_mod_data
    input logic wrt_ptr_en
    input logic read_ptr_en
    input logic [18:0] buf_data
    input logic [18:0] read_in


    // Output
    output logic [17:0] write_out

vibrato_input_b_ram U1(
	addr_a(wrt_ptr_en)
	dina(buf_data)
	wea(write_out)
	addr_b(read_ptr_en)
	web(read_in)
)

always_ff @(posedge clk, negedge n_rst) begin
	if (rst) begin
		wrt_ptr = '0;
	end else if (wrt_ptr_en == buffer_data) begin
		wrt_ptr = '0;
	end else begin
		wrt_ptr++;
	end
end

always_ff @(posedge clk, negedge n_rst) begin
	if (rst) begin
		read_ptr = '0;
	end else if (read_ptr_en == buffer_data) begin
		read_ptr = 0;
	end else begin
		read_ptr++;
	end

end

always_comb begin
	out = //linear interpolation; 
end
endmodule
