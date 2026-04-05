`timescale 1ns / 1ps

module ring_mod_tb();

    // Testbench parameters
    parameter CLK_PERIOD = 20;  // 50 MHz clock (20ns period)
    parameter OUTPUT_FILE = "C:/Users/tejas/Projects/HarmoniCore2.0/ring_mod_output.csv";
    
    // DUT signals
    logic clk;
    logic n_rst;
    logic valid;
    logic [17:0] sample_in;
    logic [17:0] acc_out;
    logic [0:0] acc_sign2;
    logic [0:0] acc_sign1;
    logic [0:0] acc_sign;
    logic [17:0] phase;
    logic [17:0] osc;
    logic [17:0] osc_new;
    logic [35:0] mult_out;
    logic [17:0] out;
    
    // Test tracking
    integer sample_count;
    integer output_file;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    ring_mod DUT (.*);

    task test_case(input logic [17:0] test_sample);
        valid = 1'b1;
        sample_in = test_sample;
        @(posedge clk);
        valid = 1'b0;
        
        // Wait for pipeline to settle (3 cycles for negedge logic + multiplier)
        repeat(3) @(posedge clk);
        
        // Log output to CSV file
        $fwrite(output_file, "%0d,%0d,%0d,%0d,%0d\n", 
                sample_count, sample_in, phase, osc_new, out);
        sample_count = sample_count + 1;
        
        @(posedge clk);
    endtask

    // Test stimulus
    initial begin
        // Initialize signals
        n_rst = 1'b0;
        valid = 1'b0;
        sample_in = 18'h00000;
        sample_count = 0;
        
        // Open output file
        output_file = $fopen(OUTPUT_FILE, "w");
        if (output_file == 0) begin
            $display("ERROR: Could not open output file");
            $finish;
        end
        
        // Write CSV header
        $fwrite(output_file, "sample_num,sample_in,phase,osc,output\n");
        
        // Wait for clock to start
        #1;
        
        // Wait for a few clock cycles
        repeat(5) @(posedge clk);
        
        // Release reset
        n_rst = 1'b1;
        @(posedge clk);
        
        $display("========================================");
        $display("Ring Modulator Comprehensive Test Suite");
        $display("========================================");
        $display("Accumulator increment: 27968 per sample");
        $display("Oscillator period: ~%.2f samples", 262144.0 / 27968.0);
        $display("Output file: %s", OUTPUT_FILE);
        $display("========================================\n");
        
        // Test 1: Zero input (should always output zero regardless of oscillator phase)
        $display("Test Set 1: Zero input across oscillator phases");
        repeat(10) begin
            test_case(18'h00000);
        end
        
        // Test 2: Small positive amplitude across phases
        $display("Test Set 2: Small positive input (0x04000 = 1/8 scale)");
        repeat(10) begin
            test_case(18'h04000);
        end
        
        // Test 3: Medium positive amplitude
        $display("Test Set 3: Medium positive input (0x10000 = 1/2 scale)");
        repeat(10) begin
            test_case(18'h10000);
        end
        
        // Test 4: Large positive amplitude
        $display("Test Set 4: Large positive input (0x18000 = 3/4 scale)");
        repeat(10) begin
            test_case(18'h18000);
        end
        
        // Test 5: Maximum positive amplitude
        $display("Test Set 5: Max positive input (0x1FFFF)");
        repeat(10) begin
            test_case(18'h1FFFF);
        end
        
        // Test 6: Small negative amplitude
        $display("Test Set 6: Small negative input (0x3C000 = -1/8 scale)");
        repeat(10) begin
            test_case(18'h3C000);
        end
        
        // Test 7: Medium negative amplitude
        $display("Test Set 7: Medium negative input (0x30000 = -1/2 scale)");
        repeat(10) begin
            test_case(18'h30000);
        end
        
        // Test 8: Large negative amplitude
        $display("Test Set 8: Large negative input (0x28000 = -3/4 scale)");
        repeat(10) begin
            test_case(18'h28000);
        end
        
        // Test 9: Maximum negative amplitude
        $display("Test Set 9: Max negative input (0x20000)");
        repeat(10) begin
            test_case(18'h20000);
        end
        
        // Test 10: Alternating pattern
        $display("Test Set 10: Alternating positive/negative");
        repeat(5) begin
            test_case(18'h10000);
            test_case(18'h30000);
        end
        
        // Test 11: Edge cases specifically
        $display("Test Set 11: Edge cases");
        test_case(18'h00001);  // Minimum non-zero positive
        test_case(18'h3FFFF);  // Minimum non-zero negative (-1)
        test_case(18'h1FFFE);  // Max-1 positive
        test_case(18'h20001);  // Min+1 negative
        
        repeat(5) @(posedge clk);
        
        // Close file and finish
        $fclose(output_file);
        
        $display("\n========================================");
        $display("Total samples tested: %0d", sample_count);
        $display("Output written to: %s", OUTPUT_FILE);
        $display("Run Python verification: python python/verify_ring_mod.py");
        $display("========================================");
        $finish;
    end
    
    // Monitor outputs (commented out to reduce console clutter)
    // initial begin
    //     $monitor("Time=%0t ns | valid=%b | sample_in=%h | phase=%h | osc=%h | out=%h", 
    //              $time, valid, sample_in, phase, osc, out);
    // end

endmodule
