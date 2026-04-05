`timescale 1ns/1ps

module vibrato_tb;

    // -----------------------------------
    // Parameters
    // -----------------------------------
    localparam CLK_PERIOD_NS = 10;   // 100 MHz clock
    localparam SAMPLE_RATE   = 44100;
    localparam SAMPLE_PERIOD = 100_000_000 / SAMPLE_RATE; // in clock cycles (~2267)

    // -----------------------------------
    // DUT signals
    // -----------------------------------
    logic clk;
    logic n_rst;

    logic data_valid;
    logic signed [17:0] data_in;

    logic out_valid;
    logic signed [17:0] data_out;

    // -----------------------------------
    // DUT instantiation
    // -----------------------------------
    vibrato_core uut (
        .clk        (clk),
        .n_rst      (n_rst),
        .data_valid (data_valid),
        .data_in    (data_in),
        .out_valid  (out_valid),
        .data_out   (data_out)
    );

    // -----------------------------------
    // Clock generation
    // -----------------------------------
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // -----------------------------------
    // Reset
    // -----------------------------------
    initial begin
        n_rst = 0;
        repeat (10) @(posedge clk);
        n_rst = 1;
    end

    // -----------------------------------
    // Stimulus generation
    // -----------------------------------

    integer sample_count = 0;
    real t;
    real freq = 440.0; // A4 tone

    integer clk_counter = 0;

    always_ff @(posedge clk) begin
        if (!n_rst) begin
            clk_counter <= 0;
            data_valid  <= 0;
            data_in     <= 0;
        end else begin
            if (clk_counter == SAMPLE_PERIOD-1) begin
                clk_counter <= 0;
                data_valid  <= 1;

                // Generate sine wave input
                t = sample_count / real'(SAMPLE_RATE);
                real val = $sin(2.0 * 3.1415926535 * freq * t);

                // Convert to Q1.17
                data_in <= $rtoi(val * (1 << 17));

                sample_count++;
            end else begin
                clk_counter <= clk_counter + 1;
                data_valid  <= 0;
            end
        end
    end

    // -----------------------------------
    // Output monitoring
    // -----------------------------------
    integer outfile;

    initial begin
        outfile = $fopen("vibrato_output.txt", "w");
    end

    always_ff @(posedge clk) begin
        if (out_valid) begin
            $fwrite(outfile, "%d\n", data_out);
        end
    end

    // -----------------------------------
    // Debug prints (optional)
    // -----------------------------------
    always_ff @(posedge clk) begin
        if (data_valid) begin
            $display("IN  sample %0d: %0d", sample_count, data_in);
        end
        if (out_valid) begin
            $display("OUT sample %0d: %0d", sample_count, data_out);
        end
    end

    // -----------------------------------
    // Simulation control
    // -----------------------------------
    initial begin
        #10_000_000;  // run long enough (~0.1 sec)
        $fclose(outfile);
        $finish;
    end

endmodule