
`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/memwrapper_if.vh"
import types::*;

module memwrapper_tb;

    parameter PERIOD = 10;
    logic clk = 1, nRST;

    // clock
    always #(PERIOD/2) clk++;

    memwrapper_if memif();

    // test program
    test PROG (
        clk, nRST,
        memif
    );

    // DUT
    memwrapper DUT(clk, nRST, memif);

endmodule

program test (
    input logic clk, 
    output logic nRST,
    memwrapper_if.mem_tb memif
);

    task memWrite (input logic [11:0] addr_a, input logic [11:0] addr_b, input logic [DW-1:0] data_a, input logic [DW-1:0] data_b);
        begin
            memif.wea = 1'b1;
            memif.web = 1'b1;
            memif.addra = addr_a;
            memif.addrb = addr_b;
            memif.dina = data_a;
            memif.dinb = data_b;
            @(negedge clk);
        end
    endtask

    task memRead (input logic [11:0] addr_a, input logic [11:0] addr_b);
        begin
            memif.wea = 1'b0;
            memif.web = 1'b0;
            memif.addra = addr_a;
            memif.addrb = addr_b;
            @(negedge clk);
        end
    endtask

    string test_name;
    integer i;
    logic [11:0] mem_addr;
    initial begin

        nRST = 1'b1;
        repeat (2) @(negedge clk);
        nRST = 1'b0;
        repeat (2) @(negedge clk);
        
        // ************************************************************************
        // Test Case 1: Test BRAM Writes
        // ************************************************************************
        test_name = "Test BRAM Writes";
        $display("%s", test_name);

        mem_addr = 12'h000;
        for (i = 0; i < 2048; i++) begin
            memWrite(mem_addr, mem_addr+1, i, i + 18'h1000);
            mem_addr += 2;
        end

        // ************************************************************************
        // Test Case 2: Test BRAM Reads
        // ************************************************************************
        test_name = "Test BRAM Reads";
        $display("%s", test_name);

        mem_addr = 12'h000;
        for (i = 0; i < 2051; i++) begin
            memRead(mem_addr, mem_addr+1);
            mem_addr += 2;
        end

        repeat (15) @(negedge clk);
        $finish;

    end

endprogram
