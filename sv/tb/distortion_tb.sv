`timescale 1ns / 10ps
`include "../src/distortion.sv"


module distortion_tb ();
    localparam CLK_PERIOD = 10ns;

    //inputs 
    logic clk;
    logic n_rst;
    logic signed [23:0] y_in;

    //outputs
    logic signed [23:0] out;

    distortion DUT (.*);

    always begin
        clk = 0; #(CLK_PERIOD/2.0);
        clk = 1; #(CLK_PERIOD/2.0);
    end

    //reset 
    task reset_dut;
    begin
        n_rst = 0;
        repeat (2) @(posedge clk);
        n_rst = 1;
        repeat (2) @(posedge clk);
    end
    endtask

    // Test task
    task run_test(input logic signed [23:0] test_input);
    begin
        y_in = test_input;
        repeat (5) @(posedge clk);
        $display("Input: %0d, Output: %0d", test_input, out);
    end
    endtask

    initial begin
        // Initialize inputs
        y_in = 24'sd0;
        n_rst = 0;

        // Reset DUT
        reset_dut();

        // Test cases - Q1.23 format (value/8388608)
        // Zero
        run_test(24'sd0); 
        
        // Positive values in range after K=64 gain
        run_test(24'sd1);       // one LSB
        run_test(24'sd81920);   // expected: tanh(0.625) = ~0.555
        run_test(24'sd167936);  // expected: tanh(1.281) = ~0.857
        run_test(24'sd249856);  // expected: tanh(1.906) = ~0.957
        run_test(24'sd335872);  // expected: tanh(2.563) = ~0.988
        
        // Negative values in range after K=64 gain
        run_test(-24'sd1);
        run_test(-24'sd81920);   // expected: -tanh(0.625) = ~-0.555
        run_test(-24'sd167936);  // expected: -tanh(1.281) = ~-0.857
        run_test(-24'sd249856);  // expected: -tanh(1.906) = ~-0.957
        run_test(-24'sd335872);  // expected: -tanh(2.563) = ~-0.988
        
        // Out of range - positive (clipped to 4)
        run_test(24'sd524288);   // threshold: 4.0 after gain
        run_test(24'sd838861);   // expected: tanh(4.0) = ~0.999 (clipped)
        run_test(24'sh7FFFFF);   // max positive, clipped
        
        // Out of range - negative (clipped to -4)
        run_test(-24'sd524288);  // threshold: -4.0 after gain
        run_test(-24'sd838861);  // expected: -tanh(4.0) = ~-0.999 (clipped)
        run_test(24'sh800000);   // min negative, clipped

        y_in = 24'sd0; // Reset input to zero

        repeat (5) @(posedge clk);

        // Finish simulation
        $finish;
    end

endmodule
