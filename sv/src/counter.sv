`timescale 1ns / 10ps
`include "../include/types.sv"

module counter 
import types::*;
(
    input logic clk,
    input logic rst,
    input logic count_enable,
    input logic [DW-1:0] rollover_val,
    output logic [DW-1:0] count,
    output logic flag
);
    logic [DW-1:0] next_count;
    logic next_flag;

    always_ff @(posedge clk) begin : counter_ff
        if (rst) begin
            count <= '0;
            flag <= 1'b0;
        end else begin
            count <= next_count;
            flag <= next_flag;
        end
    end

    always_comb begin : countLogic
        next_count = count;
        if (count_enable) begin
            if (count >= rollover_val) next_count = count; // hold at rollover value
            else                       next_count = count + 1;
        end
    end

    always_comb begin : flagLogic
        next_flag = flag;
        if (count == rollover_val) next_flag = 1'b1; // lag by 1 cycle
        else                       next_flag = 1'b0;
    end

endmodule
