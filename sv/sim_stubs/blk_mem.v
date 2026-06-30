// Simulation stub for Vivado blk_mem_gen True Dual-Port RAM.
// Matches project config: 256 x 24-bit, synchronous registered output,
// zero-initialized (equivalent to C_USE_DEFAULT_DATA=1, C_DEFAULT_DATA=0).
// Used by the Makefile when Vivado-generated files are not present.
`timescale 1ns/1ps
module blk_mem (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [7:0]  addra,
    input  wire [23:0] dina,
    output reg  [23:0] douta,

    input  wire        clkb,
    input  wire        enb,
    input  wire [0:0]  web,
    input  wire [7:0]  addrb,
    input  wire [23:0] dinb,
    output reg  [23:0] doutb
);
    reg [23:0] mem [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 24'd0;
        douta = 24'd0;
        doutb = 24'd0;
    end

    // Port A — registered output (READ_FIRST: captures pre-write value)
    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) mem[addra] <= dina;
            douta <= mem[addra];
        end
    end

    // Port B — registered output
    always @(posedge clkb) begin
        if (enb) begin
            if (web[0]) mem[addrb] <= dinb;
            doutb <= mem[addrb];
        end
    end

endmodule
