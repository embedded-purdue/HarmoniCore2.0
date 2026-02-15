`timescale 1ns / 1ps

module ring_mod_tb();

    // Testbench parameters
    parameter CLK_PERIOD = 20;  // 50 MHz clock (20ns period)
    
    // DUT signals
    logic clk;
    logic n_rst;
    logic [17:0] sample_in;
    logic [17:0] acc_out;
    logic [0:0] acc_sign2;
    logic [0:0] acc_sign1;
    logic [0:0] acc_sign;
    logic [17:0] phase;
    logic [17:0] osc;
    logic [17:0] osc_new;
    logic [35:0] mult_out;
    logic [17:0] output;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    distortion DUT (.*);

    
    // Test stimulus
    initial begin
        // Initialize signals
        n_rst = 1'b0;
        sample_in = 18'h00000;
        
        // Wait for a few clock cycles
        repeat(5) @(posedge clk);
        
        // Release reset
        n_rst = 1'b1;
        @(posedge clk);
        
        // Test 1: Apply DC input
        $display("Test 1: DC input = 0");
        sample_in = 18'h00000;
        repeat(100) @(posedge clk);
        
        // Test 2: Apply positive sample
        $display("Test 2: Positive input = 0x10000");
        sample_in = 18'h10000;
        repeat(100) @(posedge clk);
        
        // Test 3: Apply negative sample
        $display("Test 3: Negative input = 0x30000 (sign-extended)");
        sample_in = 18'h30000;
        repeat(100) @(posedge clk);
        
        // Test 4: Apply max positive sample
        $display("Test 4: Max positive input = 0x1FFFF");
        sample_in = 18'h1FFFF;
        repeat(100) @(posedge clk);
        
        // Test 5: Apply max negative sample
        $display("Test 5: Max negative input = 0x20000");
        sample_in = 18'h20000;
        repeat(100) @(posedge clk);
        
        // Test 6: Sweep through various samples
        $display("Test 6: Sample sweep");
        for (int i = 0; i < 256; i++) begin
            sample_in = i * 256;  // Increment through range
            repeat(10) @(posedge clk);
        end
        
        $display("All tests completed!");
        $finish;
    end
    
    // Monitor outputs
    initial begin
        $monitor("Time=%0t ns | sample_in=%h | phase=%h | osc=%h | output=%h", 
                 $time, sample_in, phase, osc, output);
    end

endmodule
