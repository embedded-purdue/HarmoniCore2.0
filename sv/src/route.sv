module route(
    input logic CLK,
    input logic nRst,
    input logic [9:0] din,
    input logic valid,
    input logic [DW-1:0] din,
    output logic [DW-1:0] dout,
);

    typedef struct {
        logic one;
        logic two;
        logic three;
        logic four;
        logic five;
        logic six;
        logic seven;
        logic eight;
        logic three;

    } eff_t;

    // Valid Logic
        always_comb begin
            next_dcon = 0; 
            if(valid)begin
                next_dcon = din;
            end else begin 
                next_dcon = 0; 
            end
        end

    // Stage 0
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon0 <= '0;
            end else begin
                dcon0 <= next_dcon;
            end
        end
        //EFF0
        assign eff0_opa = dcon0 & input[0];
        assign eff0_opb = dcon0 & ~input[0];
        // PUT EFFECT HERE
        assign next_dcon1 = input[0] ? eff0_out : eff0_opb; 

    // Stage 1
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon1 <= '0;
            end else begin
                dcon1 <= next_dcon1;
            end
        end

        //EFF1
        assign eff1_opa = dcon1 & input[1];
        assign eff1_opb = dcon1 & ~input[1];
        // PUT EFFECT HERE
        assign next_dcon2 = input[1] ? eff1_out : eff1_opb;

    // Stage 2
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon2 <= '0;
            end else begin
                dcon2 <= next_dcon2;
            end
        end

        //EFF2 (mux)
        assign eff2_opa = dcon2 & input[2];
        assign eff2_opb = dcon2 & ~input[2];
        // PUT EFFECT HERE
        // (demux)
        assign next_dcon3 = input[2] ? eff1_out : eff1_opb;

    // Stage 3
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon3 <= '0;
            end else begin
                dcon3 <= next_dcon3;
            end
        end

        //EFF3
        assign eff3_opa = dcon3 & input[3];
        assign eff3_opb = dcon3 & ~input[3];
        // PUT EFFECT HERE
        assign next_dcon4 = input[3] ? eff0_out : eff0_opb;

    // Stage 4
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon4 <= '0;
            end else begin
                dcon4 <= next_dcon4;
            end
        end
        //EFF4
        assign eff4_opa = dcon4 & input[4];
        assign eff4_opb = dcon4 & ~input[4];
        // PUT EFFECT HERE
        assign next_dcon5 = input[4] ? eff4_out : eff4_opb;
    
    // Stage 5
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon5 <= '0;
            end else begin
                dcon5 <= next_dcon5;
            end
        end
        //EFF5
            assign eff5_opa = dcon5 & input[5];
            assign eff5_opb = dcon5 & ~input[5];
            // PUT EFFECT HERE
            assign next_dcon6 = input[5] ? eff5_out : eff5_opb;

    // Stage 6
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon6 <= '0;
            end else begin
                dcon6 <= next_dcon6;
            end
        end 
        //EFF6
            assign eff6_opa = dcon6 & input[6];
            assign eff6_opb = dcon6 & ~input[6];
            // PUT EFFECT HERE
            assign next_dcon7 = input[6] ? eff6_out : eff6_opb;
            // Stage 6
                always_ff @(posedge CLK, posedge nRST) begin 
                    if(~nRST)begin
                        dcon6 <= '0;
                    end else begin
                        dcon6 <= next_dcon6;
                    end
                end
    
    // Stage 7
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon7 <= '0;
            end else begin
                dcon7 <= next_dcon7;
            end
        end
        //EFF7
            assign eff7_opa = dcon7 & input[7];
            assign eff7_opb = dcon7 & ~input[7];
            // PUT EFFECT HERE
            assign next_dcon8 = input[7] ? eff7_out : eff7_opb;
        
    // Stage 8
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon8 <= '0;
            end else begin
                dcon8 <= next_dcon8;
            end
        end
        //EFF8
            assign eff8_opa = dcon8 & input[8];
            assign eff8_opb = dcon8 & ~input[8];
            // PUT EFFECT HERE
            assign next_dcon9 = input[8] ? eff8_out : eff8_opb;
    
    // Stage 9
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon9 <= '0;
            end else begin
                dcon9 <= next_dcon9;
            end
        end
        //EFF9
            assign eff9_opa = dcon9 & input[9];
            assign eff9_opb = dcon9 & ~input[9];
            // PUT EFFECT HERE
            assign next_dout = input[9] ? eff9_out : eff9_opb;

    // Stage 10
        always_ff @(posedge CLK, posedge nRST) begin 
            if(~nRST)begin
                dcon10 <= '0;
            end else begin
                dout <= next_dout;
            end
        end

endmodule
    