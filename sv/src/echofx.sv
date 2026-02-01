`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/echofx_if.vh"


import types::*;
module echofx #(parameter DELAY = 11025
) (
    input logic clk, rst,   // this is the 44.1 khz clock
    echofx_if echo_if
);

logic wr_en, full, empty, start_pop, n_start_pop;
logic signed [DW-1:0] din, dout, delay_and_feedback, calc_dout;
logic [13:0] count, n_count;

assign din = echo_if.data_in;   // input data to FIFO
assign wr_en = 1'b1;             // always be pushing data into FIFO
assign rd_en = start_pop;       // start popping after <DELAY> samples

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
fifo_echo my_fifo (
  .clk(clk),      // input wire clk
  .srst(rst),    // input wire srst
  .din(din),      // input wire [17 : 0] din
  .wr_en(wr_en),  // input wire wr_en
  .rd_en(rd_en),  // input wire rd_en
  .dout(dout),    // output wire [17 : 0] dout
  .full(full),    // output wire full
  .empty(empty)  // output wire empty
);
// INST_TAG_END ------ End INSTANTIATION Template ---------

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        count     <= 1'b0; // count up to delay
        start_pop <= 1'b0; // signal to start popping
    end
    else begin
        count     <= n_count;
        start_pop <= n_start_pop; 
    end
end

always_comb begin : initialization
    n_count = count + 1;
    n_start_pop = start_pop;
    if (n_count == DELAY-1)   // if next count is 11024, set start_pop high at sample 11024, pop sample at 11025
        n_start_pop = 1'b1;
end

always_comb begin : Math_Block
    delay_and_feedback = (count < DELAY) ? (0 : dout >>> 2);   // effectively dividing dout by 4
    calc_dout = (din >>> 1) + (delay_and_feedback); 
end

assign echo_if.data_out = (echo_if.fx_en) ? calc_dout : din;    // if fx not enabled, just act as wire
endmodule