
`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/memwrapper_if.vh"

module memwrapper 
import types::*;
(
    input logic clk, rst,
    memwrapper_if.mem memif
);
    logic read_a, read_b, read_a2, read_b2;

    blk_mem your_instance_name (
        .clka(clk),           // input wire clka
        .ena(~rst),           // input wire ena
        .wea(memif.wea),      // input wire [0:0] wea
        .addra(memif.addra),  // input wire [11:0] addra
        .dina(memif.dina),    // input wire [17:0] dina
        .douta(memif.douta),   // output wire [17:0] douta
        .clkb(clk),           // input wire clkb
        .enb(~rst),           // input wire enb
        .web(memif.web),      // input wire [0:0] web
        .addrb(memif.addrb),  // input wire [11:0] addrb
        .dinb(memif.dinb),    // input wire [17:0] dinb
        .doutb(memif.doutb)    // output wire [17:0] doutb
    );

    // dout is registered, so need some extra logic to handle that here
    always_ff @(posedge clk) begin : lagDOUT
        if (rst) begin
            read_a <= 1'b0;
            read_b <= 1'b0;
            read_a2 <= 1'b0;
            read_b2 <= 1'b0;
        end else begin
            read_a <= ~memif.wea;
            read_b <= ~memif.web;
            read_a2 <= read_a;
            read_b2 <= read_b;
        end
    end

    always_ff @(posedge clk) begin : assignDOUT
        if (rst) begin
            memif.valid_a <= 1'b0;
            memif.valid_b <= 1'b0;
        end else begin
            if (read_a2) memif.valid_a <= 1'b1;
            else         memif.valid_a <= 1'b0;

            if (read_b2) memif.valid_b <= 1'b1;
            else         memif.valid_b <= 1'b0;
        end
    end

endmodule