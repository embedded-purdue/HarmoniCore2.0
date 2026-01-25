
// `timescale 1ns / 10ps
// `include "../include/types.sv"
// `include "../include/vibrato_if.vh"

// module vibrato
// import types::*;
// (
//     input logic clk, rst,
//     vibrato_if.vibrato vif
// );
//     // declare interfaces
//     memwrapper_if memif;

//     // declare modules
//     memwrapper MEM(clk, rst, memif);

//     // declare FSM
//     typedef enum logic [1:0] {WRITE, WAIT_WRITE, READ, WAIT_READ, INTERP, DONE} state_t;
//     state_t state, next_state;

//     // additional signals
//     logic [11:0] w_ptr, r_ptr;

//     // ************************************************************************
//     // START THE CODE
//     // ************************************************************************

//     always_ff @(posedge clk) begin : fsmStates
//         if (rst) state <= IDLE;
//         else     state <= next_state;
//     end

//     always_comb begin : fsmNextStates
//         next_state = state;
//         case(state) 
//             WRITE: next_state = WAIT_WRITE;
//             WAIT_WRITE: if (memif.valid_a) next_state = READ;
//             READ: next_state = WAIT_READ;
//             WAIT_READ: if (memif.valid_a & memif.valid_b) next_state = INTERP;
//             INTERP: if () next_state = DONE;
//             default: next_state = WRITE;
//         endcase
//     end

//     always_comb begin : fsmOutputs

//         case(state)
//             WRITE: begin
//                 memif.wea = 1'b1;
//                 memif.addra = w_ptr;
//                 memif.dina = vif.input_data;
//                 memif.web = 1'b0;
//                 memif.addrb = '0;
//                 memif.dinb = '0;
//             end

//             READ: begin
//                 memif.wea = 1'b0;
//                 memif.addra = r_ptr[] // take the floor
//                 memif.dina = '0;
//                 memif.web = 1'b0;
//                 memif.addra = r_ptr[] + '1' // floor + 1
//                 memif.dinb = '0;
//             end

//         endcase
        
//     end

//     always_ff @(posedge clk) begin : writePtr
//         if      (rst) w_ptr <= '0;
//         else if (input_en) w_ptr <= w_ptr + 1;
//     end








// endmodule