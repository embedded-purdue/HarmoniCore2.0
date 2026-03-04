`timescale 1ns / 10ps

module harmonic_chorus_tb;

	localparam N = 1024;

	// DUT signals
	reg clk;
	reg n_rst;
	reg [17:0] y_in;
	reg sample_en;
	reg [$clog2(N)-1:0] delay;
	reg [17:0] DELAY_MS;
	reg [17:0] AMOUNT;
	reg [17:0] sr;
	wire [17:0] out;

	// Instantiate DUT
	harmonic_chorus #(.N(N)) uut (
		.clk(clk),
		.n_rst(n_rst),
		.y_in(y_in),
		.sample_en(sample_en),
		.delay(delay),
		.DELAY_MS(DELAY_MS),
		.AMOUNT(AMOUNT),
		.sr(sr),
		.out(out)
	);

	// VCD dump for waveform viewing
	initial begin
		$dumpfile("harmonic_chorus_tb.vcd");
		$dumpvars(0, harmonic_chorus_tb);
	end

	// Clock: 36 MHz -> period ≈ 27.777778 ns
	localparam real CLK_FREQ_MHZ = 36.0;
	localparam real CLK_PERIOD_NS = 1000.0 / CLK_FREQ_MHZ; // ns
	initial clk = 0;
	always #(CLK_PERIOD_NS/2.0) clk = ~clk;

	// Reset and stimulus
	initial begin
		// init
		n_rst = 0;
		sample_en = 0;
		y_in = 18'd0;
		delay = 0;
		DELAY_MS = 18'd16; // example
		AMOUNT = 18'd65536; // mid-scale (example fixed-point)
		sr = 18'd48000;

		// hold reset a couple cycles
		#20;
		n_rst = 1;

		// enable sampling and drive inputs
		sample_en = 1;
		delay = 10;

		// Provide a simple ramp input for a number of samples
		repeat (2048) begin
			@(posedge clk);
			y_in <= y_in + 18'd1000;
		end

		// change some parameters to exercise mixing path
		@(posedge clk);
		AMOUNT <= 18'd262144; // closer to full (18-bit value)
		DELAY_MS <= 18'd32;

		// a few more samples
		repeat (256) begin
			@(posedge clk);
			y_in <= y_in + 18'd500;
		end

		$display("Testbench finished at time %0t", $time);
		#100 $finish;
	end

	// Simple monitor: print time, input and output periodically
	always @(posedge clk) begin
		if (sample_en) begin
			$display("%0t : y_in=%0d delay=%0d AMOUNT=%0d out=%0d", $time, y_in, delay, AMOUNT, out);
		end
	end

endmodule

