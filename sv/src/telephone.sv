module telephone
(
    input logic clk,
    input logic n_rst,
    input logic signed [23:0] y_in, 
    input logic sample_en,

    output logic signed [23:0] out     
);
    //2 biquads that implement a 4th-order butterworth bandpass filter centered around ... kHz with a Q of ...
    //Function to implement
        //y[n]=b0​x[n]+b1​x[n−1]+b2​x[n−2]+b3​x[n−3]+b4​x[n−4]−a1​y[n−1]−a2​y[n−2]−a3​y[n−3]−a4​y[n−4]
        //Implemented using two biquads in series, where the output of the first biquad is the input to the second biquad
        //y[n]=b0​x[n]+b1​x[n−1]+b2​x[n−2]−a1​y[n−1]−a2​y[n−2]
    //Will need I think, 10 mult IPs, adders, delay reg, and subtration IPs. 

// Biquad 1
localparam signed [17:0] b0_1 = 18'sd1650; 
localparam signed [17:0] b1_1 = 18'sd3300; 
localparam signed [17:0] b2_1 = 18'sd1650; 
localparam signed [17:0] a1_1 = 18'sd-100929; 
localparam signed [17:0] a2_1 = 18'sd43243; 

// Biquad 2
localparam signed [17:0] b0_2 = 18'sd65536; 
localparam signed [17:0] b1_2 = 18'sd-131072; 
localparam signed [17:0] b2_2 = 18'sd65536; 
localparam signed [17:0] a1_2 = 18'sd-125165; 
localparam signed [17:0] a2_2 = 18'sd60030;

// Convert signed 24-bit Q1.23 input to signed 18-bit Q1.17 with rounding
logic signed [23:0] y_s;
logic signed [23:0] y_r;
logic signed [17:0] filter_in;
logic signed [17:0] filter_out;

//ROUNDING: Add 2^5 (32) to the input before shifting right by 6 to convert from Q1.23 to Q1.17 with rounding
// assign y_r = (y_in + 24'sd32) >>> 6; // add 2^5 for round-to-nearest then arithmetic shift
// assign filter_in = y_r[17:0];
assign filter_in = y_in[23:6]; // Simple truncation from Q1.23 to Q1.17, no rounding

logic signed [17:0] stage1_to_stage2; // Wire to connect stage 1 to stage 2

// Instantiate First Biquad (Low-pass section)
biquad #(
    .B0(b0_1),
    .B1(b1_1),
    .B2(b2_1),
    .A1(a1_1),
    .A2(a2_1)
) b1 (
    .clk(clk),
    .n_rst(n_rst),
    .sample_en(sample_en),
    .x_in(filter_in),
    .y_out(stage1_to_stage2)
);

// Instantiate Second Biquad (High-pass section)
biquad #(
    .B0(b0_2),
    .B1(b1_2),
    .B2(b2_2),
    .A1(a1_2),
    .A2(a2_2)
) b2 (
    .clk(clk),
    .n_rst(n_rst),
    .sample_en(sample_en),
    .x_in(stage1_to_stage2),
    .y_out(filter_out)
);

// SATURATION: Convert filter output (Q1.17) back to Q1.23 with saturating clamp to avoid wrap 
assign out = {filter_out, 6'b000000};

endmodule

module biquad #(
    parameter signed [17:0] B0 = 18'sd0,
    parameter signed [17:0] B1 = 18'sd0,
    parameter signed [17:0] B2 = 18'sd0,
    parameter signed [17:0] A1 = 18'sd0,
    parameter signed [17:0] A2 = 18'sd0
)
(
    input logic clk,
    input logic n_rst,
    input  logic sample_en,
    input  logic signed [17:0] x_in,  // Q1.17 from the system
    output logic signed [17:0] y_out  // Q1.17 back to the system
    
);

    logic signed [17:0] x_z1, x_z2;
    logic signed [17:0] y_z1, y_z2;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            x_z1 <= 18'sd0;
            x_z2 <= 18'sd0;
            y_z1 <= 18'sd0;
            y_z2 <= 18'sd0;
        end else if (sample_en) begin // Shift the history ONLY when a new audio sample arrives
            x_z1 <= x_in;
            x_z2 <= x_z1;

            y_z1 <= y_out;
            y_z2 <= y_z1;
        end
    end

    //Multipliers
    // 18-bit (Q1.17) x 18-bit (Q2.16) = 36-bit (Q3.33)
    logic signed [35:0] mult_b0, mult_b1, mult_b2;
    logic signed [35:0] mult_a1, mult_a2;

    assign mult_b0 = x_in * B0;
    assign mult_b1 = x_z1 * B1;
    assign mult_b2 = x_z2 * B2;
    
    assign mult_a1 = y_z1 * A1;
    assign mult_a2 = y_z2 * A2;

    // Accumulator
    logic signed [35:0] accumulator;
    
    assign accumulator = mult_b0 + mult_b1 + mult_b2 - mult_a1 - mult_a2;

    // Output Formatting
    // Shift right by 16 to chop off the coefficient fractional bits.
    // The 36-bit result cleanly truncates back down to 18-bit Q1.17.
    assign y_out = accumulator >>> 16;

endmodule