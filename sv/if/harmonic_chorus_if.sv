interface harmonic_chorus_if #(parameter int N = 1024);
	logic clk;
	logic n_rst;
	logic [17:0] y_in;
	logic sample_en;
	logic [$clog2(N)-1:0] delay;
	logic [17:0] DELAY_MS;
	logic [17:0] AMOUNT;
	logic [17:0] sr;
	logic [23:0] out;

	modport dut (
		input  clk,
		input  n_rst,
		input  y_in,
		input  sample_en,
		input  delay,
		input  DELAY_MS,
		input  AMOUNT,
		input  sr,
		output out
	);

	modport tb (
		output clk,
		output n_rst,
		output y_in,
		output sample_en,
		output delay,
		output DELAY_MS,
		output AMOUNT,
		output sr,
		input  out
	);
endinterface
