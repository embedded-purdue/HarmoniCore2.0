interface ring_mod_if;
    logic clk;
    logic n_rst;
    logic [17:0] sample_in;
    logic valid;
    logic [17:0] out;

    modport ring(
        input clk,
        input n_rst,
        input sample_in,
        input valid
        output out
    );

    modport tb_output (
        output clk,
        output n_rst,
        output sample_in,
        output valid,
        input out
    );
endinterface

`endif
