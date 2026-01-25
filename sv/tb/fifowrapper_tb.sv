
`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/fifowrapper_if.vh"
import types::*;

module fifowrapper_tb;

    parameter PERIOD = 10;
    logic clk1 = 1, clk2 = 1, nRST;

    // clock
    always #(PERIOD/6) clk1 = ~clk1; // clk1 slower
    always #(PERIOD/2) clk2 = ~clk2; // clk2 faster 

    fifowrapper_if fifoif();

    // test program
    test PROG (
        clk1, clk2, nRST,
        fifoif
    );

    // DUT
    fifowrapper DUT(clk1, clk2, nRST, fifoif);

endmodule

program test (
    input logic clk1, clk2, 
    output logic nRST,
    fifowrapper_if.fifo_tb fifoif
);

    task sendWrite (input logic [DW-1:0] data);
        fifoif.wr_data = data;
        fifoif.wr_en   = 1'b1;
        @(posedge clk1);
        fifoif.wr_en   = 1'b0;
    endtask

    task readWhenFull ();
        fifoif.rd_en = 1'b1;
        @(posedge clk2);
        fifoif.rd_en = 1'b0;
    endtask

    string test_name;
    integer i;
    initial begin

        nRST = 1'b1;
        repeat (2) @(negedge clk1);
        repeat (2) @(negedge clk2);
        nRST = 1'b0;
        repeat (2) @(negedge clk1);
        repeat (2) @(negedge clk2);
        
        // ************************************************************************
        // Test Case 1: Fill up FIFO
        // ************************************************************************
        test_name = "Fill up FIFO";
        $display("%s", test_name);

        for (i = 0; i < 512; i++) begin
            sendWrite(18'h1000 + i);
        end

        assert (fifoif.full == 1'b1) $display ("Correct full value");
            else $display ("Incorrect full value ERROR");
        @(negedge clk1);


        // ************************************************************************
        // Test Case 2: Empty FIFO
        // ************************************************************************
        test_name = "Empty FIFO";
        $display("%s", test_name);

        for (i = 0; i < 512; i++) begin
            readWhenFull();
            assert (fifoif.rd_data == (18'h1000 + i)) $display ("Correct data value read");
                else $display ("Incorrect data value read ERROR");
        end

        assert (fifoif.empty == 1'b1) $display ("Correct empty value");
            else $display ("Incorrect empty value ERROR");
        @(negedge clk2);

        repeat (15) @(negedge clk1);
        $finish;

    end

endprogram
