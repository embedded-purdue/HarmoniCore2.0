`timescale 1ns / 10ps
`include "../src/distortion.sv"


module distortion_tb ();
    localparam CLK_PERIOD = 10ns;

    //inputs 
    logic clk;
    logic n_rst;
    logic [17:0] y_in;

    //outputs
    logic [17:0] out;
    logic [17:0] test_mult; // TEST MULTIPLIER OUTPUT
    logic [17:0] test_add;  // TEST ADDRESS OUTPUT

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
    task run_test(input logic [17:0] test_input);
    begin
        y_in = test_input;
        repeat (8) @(posedge clk);  // Wait for pipelinelatency
        $display("Input: %d, Output: %d", test_input, out);
    end
    endtask

    initial begin
        // Initialize inputs
        y_in = 18'b0;
        n_rst = 0;

        // Reset DUT
        reset_dut();

        // Test cases - Q11 format (value/2048)
        // Zero
        run_test(18'd0); 
        
        // Positive values in range (< 0.04)
        run_test(18'd20);   // expected: tanh(0.98) = ~0.753
        run_test(18'd41);   // expected: tanh(2.0) = ~0.964
        run_test(18'd61);   // expected: tanh(3.0) = ~0.995
        run_test(18'd82);   // expected: tanh(4.0) = ~0.999
        
        // Negative values in range (> -0.04)
        run_test(-18'd20);  // expected: -tanh(0.98) = ~-0.753
        run_test(-18'd41);  // expected: -tanh(2.0) = ~-0.964
        run_test(-18'd61);  // expected: -tanh(3.0) = ~-0.995
        run_test(-18'd82);  // expected: -tanh(4.0) = ~-0.999
        
        // Out of range - positive (clipped to 4)
        run_test(18'd200);   // expected: tanh(4.0) = ~0.999 (clipped)
        run_test(18'd1000);  // expected: tanh(4.0) = ~0.999 (clipped)
        run_test(18'd5000);  // expected: tanh(4.0) = ~0.999 (clipped)
        
        // Out of range - negative (clipped to -4)
        run_test(-18'd200);  // expected: -tanh(4.0) = ~-0.999 (clipped)
        run_test(-18'd1000); // expected: -tanh(4.0) = ~-0.999 (clipped)
        run_test(-18'd5000); // expected: -tanh(4.0) = ~-0.999 (clipped)

        y_in = 18'd0; // Reset input to zero

        repeat (5) @(posedge clk);

        // Finish simulation
        $finish;
    end

endmodule