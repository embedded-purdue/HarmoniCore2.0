`timescale 1ns / 10ps


module harmonic_chorus_tb;

	localparam N = 1024;

	// Instantiate interface
	harmonic_chorus_if #(N) iface();

	// Instantiate DUT using interface
	harmonic_chorus #(.N(N)) uut (
		.iface(iface)
	);


	// VCD dump for waveform viewing
	initial begin
		$dumpfile("harmonic_chorus_tb.vcd");
		$dumpvars(0, harmonic_chorus_tb);
	end


	// Clock: 36 MHz -> period ≈ 27.777778 ns
	localparam real CLK_FREQ_MHZ = 36.0;
	localparam real CLK_PERIOD_NS = 1000.0 / CLK_FREQ_MHZ; // ns
	initial iface.clk = 0;
	always #(CLK_PERIOD_NS/2.0) iface.clk = ~iface.clk;


	// Reset and stimulus
	initial begin
		// init
		iface.n_rst = 0;
		iface.sample_en = 0;
		iface.y_in = 18'd0;
		iface.delay = 0;
		iface.DELAY_MS = 18'd16; // example
		iface.AMOUNT = 18'd65536; // mid-scale (example fixed-point)
		iface.sr = 18'd48000;

		// hold reset a couple cycles
		#20;
		iface.n_rst = 1;

		// enable sampling and drive inputs
		iface.sample_en = 1;
		iface.delay = 10;

		// Provide a simple ramp input for a number of samples
		repeat (2048) begin
			@(posedge iface.clk);
			iface.y_in <= iface.y_in + 18'd1000;
		end

		// change some parameters to exercise mixing path
		@(posedge iface.clk);
		iface.AMOUNT <= 18'd262144; // closer to full (18-bit value)
		iface.DELAY_MS <= 18'd32;

		// a few more samples
		repeat (256) begin
			@(posedge iface.clk);
			iface.y_in <= iface.y_in + 18'd500;
		end

		$display("Testbench finished at time %0t", $time);
		#100 $finish;
	end


	// Simple monitor: print time, input and output periodically
	always @(posedge iface.clk) begin
		if (iface.sample_en) begin
			$display("%0t : y_in=%0d delay=%0d AMOUNT=%0d out=%0d", $time, iface.y_in, iface.delay, iface.AMOUNT, iface.out);
		end
	end

endmodule

