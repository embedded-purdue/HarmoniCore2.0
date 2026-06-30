
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/memwrapper_if.vh"

module memwrapper
import types::*;
(
    input logic clk, n_rst,
    memwrapper_if.mem memif
);
    blk_mem u_blk_mem (
        .clka(clk),
        .ena(n_rst),
        .wea(memif.wea),
        .addra(memif.addra),
        .dina(memif.dina),
        .douta(memif.douta),
        .clkb(clk),
        .enb(n_rst),
        .web(memif.web),
        .addrb(memif.addrb),
        .dinb(memif.dinb),
        .doutb(memif.doutb)
    );

    // BRAM output is registered
    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            memif.valid_a <= 1'b0;
            memif.valid_b <= 1'b0;
        end else begin
            memif.valid_a <= ~memif.wea;
            memif.valid_b <= ~memif.web;
        end
    end

endmodule