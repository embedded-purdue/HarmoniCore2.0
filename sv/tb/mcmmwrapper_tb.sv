
`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/mcmmwrapper_if.vh"
import types::*;

module mcmmwrapper_tb;

    parameter PERIOD = 10;
    logic clk = 1, nRST;

    // clocks
    always #(PERIOD/2) clk = ~clk; 

    mcmmwrapper_if mcmmif();

    // test program
    mcmmwrapper_test PROG (
        clk, nRST,
        mcmmif
    );

    // DUT
    mcmmwrapper DUT(clk , nRST, mcmmif);

endmodule

program mcmmwrapper_test (
    input logic clk,
    output logic nRST,
    mcmmwrapper_if.mcmm_tb mcmmif
);

    string test_name;
    initial begin

        nRST = 1'b0;
        repeat (2) @(negedge clk);
        nRST = 1'b1;
        repeat (2) @(negedge clk);
        
        // ************************************************************************
        // Test Case 1: Test MCMM
        // ************************************************************************
        test_name = "Test MCMM";
        $display("%s", test_name);

        while (mcmmif.clocks_rdy !== 1'b1) begin
            @(negedge clk);
        end

        assert (mcmmif.clocks_rdy == 1'b1) $display ("Correct lock value");
            else $display ("Incorrect lock value ERROR");
        @(negedge clk);

       

        repeat (15) @(negedge clk);
        $finish;

    end

endprogram
