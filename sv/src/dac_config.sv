//=========================================================================
// DAC Configuration Controller (Wrapper for I2C Master)
// Author: Kameron Jackson
// Username: jacks908@purdue.edu
//
// Configures TLV320DAC3120 DAC via I2C
// Sends 5 register writes in sequence
//=========================================================================

module dac_config (
    // System Signals
    input  logic clk,
    input  logic n_rst,
    
    // Control
    input  logic start,           // Pulse to begin configuration
    output logic done,            // High when all configs complete
    output logic sys_err,         // High if any NACK received
    
    // I2C bus (directly to DAC)
    inout  wire  sda,
    output logic scl
);

    //=========================================================================
    // Local Parameters - DAC Configuration Data
    //=========================================================================
    localparam SLAVE_ADDR = 7'h18;  // TLV320DAC3120 I2C address
    
    // Number of configurations to send
    localparam NUM_CONFIGS = 5;
    
    // Configuration table: {reg_addr, data}
    // Step 1: Select Page 0
    // Step 2: Codec Interface config (Page 0, Reg 0x1B)
    // Step 3: Select Page 1
    // Step 4: Headphone config (Page 1, Reg 0x1F)
    // Step 5: Speaker amp config (Page 1, Reg 0x20)
    
    logic [7:0] CONFIG_REG  [0:NUM_CONFIGS-1];
    logic [7:0] CONFIG_DATA [0:NUM_CONFIGS-1];
    
    // Initialize config arrays
    assign CONFIG_REG[0]  = 8'h00;  // Page select register
    assign CONFIG_DATA[0] = 8'h00;  // Select Page 0
    
    assign CONFIG_REG[1]  = 8'h1B;  // Codec Interface Control (reg 27)
    assign CONFIG_DATA[1] = 8'h0D;  // DSP mode, 16-bit, BCLK/WCLK input
    
    assign CONFIG_REG[2]  = 8'h00;  // Page select register
    assign CONFIG_DATA[2] = 8'h01;  // Select Page 1
    
    assign CONFIG_REG[3]  = 8'h1F;  // Headphone config (reg 31)
    assign CONFIG_DATA[3] = 8'h40;  // Headphone settings
    
    assign CONFIG_REG[4]  = 8'h20;  // Speaker amp config (reg 32)
    assign CONFIG_DATA[4] = 8'h86;  // Class D amp settings

    //=========================================================================
    // State Machine
    //=========================================================================
    typedef enum logic [1:0] {
        IDLE,
        SEND,
        WAIT,
        ERROR
    } state_t;
    
    state_t state, next_state;

    //=========================================================================
    // Registers
    //=========================================================================
    logic [2:0] config_index;       // Which config we're on (0 to 4)
    logic [2:0] next_config_index;
    
    //=========================================================================
    // I2C Master Signals
    //=========================================================================
    logic       i2c_en;
    logic [6:0] slave_addr;
    logic [7:0] reg_addr;
    logic [7:0] data_out;
    logic       busy;
    logic       ack_error;

    //=========================================================================
    // I2C Master Instance
    //=========================================================================
    i2c_master u_i2c_master (
        .clk        (clk),
        .n_rst      (n_rst),
        .i2c_en     (i2c_en),
        .slave_addr (slave_addr),
        .reg_addr   (reg_addr),
        .data_in    (data_out),
        .busy       (busy),
        .ack_error  (ack_error),
        .sda        (sda),
        .scl        (scl)
    );

    //=========================================================================
    // Input Register (Moore)
    //=========================================================================
    logic start_reg;
    logic busy_reg;
    logic ack_error_reg;
    
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            start_reg <= 1'b0;
            busy_reg <= 1'b0;
            ack_error_reg <= 1'b0;
        end else begin
            start_reg <= start;
            busy_reg <= busy;
            ack_error_reg <= ack_error;
        end
    end

    //=========================================================================
    // State Register
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    //=========================================================================
    // Config Index Register
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            config_index <= 3'd0;
        else
            config_index <= next_config_index;
    end

    //=========================================================================
    // Next State Logic
    //=========================================================================
    always_comb begin
        next_state = state;
        next_config_index = config_index;
        
        case (state)
            IDLE: begin
                if (start_reg) begin
                    next_state = SEND;
                    next_config_index = 3'd0;  
                end
            end
            
            SEND: begin
                next_state = WAIT;
            end
            
            WAIT: begin
                if (!busy_reg) begin
                    if (ack_error_reg) begin
                        // Error Transition
                        next_state = ERROR;
                    end else if (config_index == NUM_CONFIGS - 1) begin
                        // All sent correctly
                        next_state = IDLE;
                    end else begin
                        // More configs to send
                        next_config_index = config_index + 1;
                        next_state = SEND;
                    end
                end
            end
            
            ERROR: begin
                next_state = ERROR;
            end
            default: next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Output Logic
    //=========================================================================
    always_comb begin
        // Defaults
        i2c_en = 1'b0;
        slave_addr = SLAVE_ADDR;
        reg_addr = 8'h00;
        data_out = 8'h00;
        done = 1'b0;
        sys_err = 1'b0;
        
        case (state)
            IDLE: begin
                i2c_en = 1'b0;
                done = (config_index == NUM_CONFIGS - 1) && !start_reg; //unsure
            end
            
            SEND: begin
                i2c_en = 1'b1;
                reg_addr = CONFIG_REG[config_index];
                data_out = CONFIG_DATA[config_index];
            end
            
            WAIT: begin
                i2c_en = 1'b0;
                reg_addr = CONFIG_REG[config_index];
                data_out = CONFIG_DATA[config_index];
            end
            
            ERROR: begin
                i2c_en = 1'b0;
                sys_err = 1'b1;
            end
            default: begin
                i2c_en = 1'b0;
            end
        endcase
    end
endmodule