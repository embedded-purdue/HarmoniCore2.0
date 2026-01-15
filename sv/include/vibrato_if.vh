
`ifndef VIBRATO_IF_VH
`define VIBRATO_IF_VH

`include "../include/types.sv"

interface vibrato_if;
    import types::*;

    modport vibrato (

    );

    modport vibrato_tb (

    );
endinterface

`endif