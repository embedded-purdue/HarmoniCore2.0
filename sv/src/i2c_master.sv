
//=========================================================================
// I2C module 
// Author: Kameron Jackson
// Username: jacks908@purdue.edu
//=========================================================================

module i2c_master (
    // System Signals
    input  logic       clk,
    input  logic       n_rst,
    
    // Control Signals
    input  logic       i2c_en,
    input  logic [6:0] slave_addr,    // 7-bit I2C address (0x18 for DAC)
    input  logic [7:0] reg_addr,      // Register to write
    input  logic [7:0] data_in,       // Data to write
    output logic       busy,
    output logic       ack_error,     // High if any NACK received
    
    // I2C bus
    inout  wire        sda,           // Bidirectional data line
    output logic       scl
);  

    //=========================================================================
    // SDA Tri-State Control
    //=========================================================================
    logic sda_oe;                     // Output enable: 1 = pull low, 0 = release
    logic sda_in;                     // Read value from SDA line
    
    assign sda = sda_oe ? 1'b0 : 1'bz;  // Drive low or release (pull-up brings high)
    assign sda_in = sda;                 // Read the line

    //=========================================================================
    // Input Registers (Moore)
    //=========================================================================
    logic i2c_en_reg;
    logic sda_in_reg;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            i2c_en_reg <= 1'b0;
            sda_in_reg <= 1'b1;
        end else begin
            i2c_en_reg <= i2c_en;
            sda_in_reg <= sda_in;
        end
    end

    //=========================================================================
    // Clock Divider
    // 50MHz / 250 = 200kHz tick rate
    // Toggle SCL every tick = 100kHz SCL
    //=========================================================================
    logic [7:0] clk_div;
    logic       tick;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            clk_div <= '0;
            tick <= 1'b0;
        end else if (clk_div == 8'd249) begin
            clk_div <= '0;
            tick <= 1'b1;
        end else begin
            clk_div <= clk_div + 1;
            tick <= 1'b0;
        end
    end

    //=========================================================================
    // State Machine
    //=========================================================================
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_BIT_LOW,
        SEND_BIT_HIGH,
        ACK_LOW,
        ACK_HIGH,
        STOP_LOW,
        STOP_HIGH
    } state_t;

    state_t state, next_state;

    //=========================================================================
    // Registers
    //=========================================================================
    logic [7:0] shift_reg;      // Byte being transmitted
    logic [2:0] bit_count;      // Which bit (7 down to 0)
    logic [1:0] byte_count;     // Which byte (0=addr, 1=reg, 2=data)
    logic       nack_flag;      // Set if any NACK received
    
    // Store the three bytes to send
    logic [7:0] addr_byte;      // Where
    logic [7:0] reg_byte;       // Who
    logic [7:0] data_byte;      // What

    //=========================================================================
    // State Register (State transition)
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            state <= IDLE;
        else if (tick)
            state <= next_state;
    end

    //=========================================================================
    // Next State Logic (Moore)
    //=========================================================================
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (i2c_en_reg)
                    next_state = START;
                else
                    next_state = IDLE;
            end
                
            START: begin
                next_state = SEND_BIT_LOW;
            end
            
            SEND_BIT_LOW: begin
                next_state = SEND_BIT_HIGH;
            end
            
            SEND_BIT_HIGH: begin
                if (bit_count == 3'd0)
                    next_state = ACK_LOW;
                else
                    next_state = SEND_BIT_LOW;
            end
            
            ACK_LOW: begin
                next_state = ACK_HIGH;
            end
            
            ACK_HIGH: begin
                if (sda_in_reg == 1'b1) begin
                    // NACK received - abort, go to STOP
                    next_state = STOP_LOW;
                end else if (byte_count < 2'd2) begin
                    // ACK received, more bytes to send
                    next_state = SEND_BIT_LOW;
                end else begin
                    // ACK received, all 3 bytes sent
                    next_state = STOP_LOW;
                end
            end
            
            STOP_LOW: begin
                next_state = STOP_HIGH;
            end
            
            STOP_HIGH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Byte Storage - latch inputs when starting
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            addr_byte <= 8'h00;
            reg_byte <= 8'h00;
            data_byte <= 8'h00;
        end else if (state == IDLE && i2c_en_reg) begin
            addr_byte <= {slave_addr, 1'b0};  // Address + Write bit
            reg_byte <= reg_addr;
            data_byte <= data_in;
        end
    end

    //=========================================================================
    // Shift Register, Bit Counter, Byte Counter
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            shift_reg <= 8'h00;
            bit_count <= 3'd7;
            byte_count <= 2'd0;
        end else if (state == IDLE && i2c_en_reg) begin
            // Load first byte (address) when starting
            shift_reg <= {slave_addr, 1'b0};
            bit_count <= 3'd7;
            byte_count <= 2'd0;
        end else if (tick && state == SEND_BIT_HIGH && bit_count != 3'd0) begin
            // Shift out bits
            shift_reg <= {shift_reg[6:0], 1'b0};
            bit_count <= bit_count - 1;
        end else if (tick && state == ACK_HIGH && sda_in_reg == 1'b0 && byte_count < 2'd2) begin
            // ACK received, load next byte
            bit_count <= 3'd7;
            byte_count <= byte_count + 1;
            case (byte_count)
                2'd0: shift_reg <= reg_byte;   // After addr, load reg
                2'd1: shift_reg <= data_byte;  // After reg, load data
                default: shift_reg <= 8'h00;
            endcase
        end
    end

    //=========================================================================
    // NACK Flag - set if any byte gets NACK'd
    //=========================================================================
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            nack_flag <= 1'b0;
        else if (state == IDLE && i2c_en_reg)
            nack_flag <= 1'b0;  // Clear on new transaction
        else if (tick && state == ACK_HIGH && sda_in_reg == 1'b1)
            nack_flag <= 1'b1;  // Set if NACK detected
    end

    //=========================================================================
    // Output Logic (Moore)
    //=========================================================================
    always_comb begin
        sda_oe = 1'b0;
        scl = 1'b1;
        
        case (state)
            IDLE: begin
                sda_oe = 1'b0;
                scl = 1'b1;
            end
            
            START: begin
                sda_oe = 1'b1;  // Pull SDA low 
                scl = 1'b1;
            end
            
            SEND_BIT_LOW: begin
                sda_oe = ~shift_reg[7];
                scl = 1'b0;
            end
            
            SEND_BIT_HIGH: begin
                sda_oe = ~shift_reg[7];
                scl = 1'b1;
            end
            
            ACK_LOW: begin
                sda_oe = 1'b0;
                scl = 1'b0;
            end
            
            ACK_HIGH: begin
                sda_oe = 1'b0;
                scl = 1'b1;
            end
            
            STOP_LOW: begin
                sda_oe = 1'b1;  // Pull SDA low
                scl = 1'b0;
            end
            
            STOP_HIGH: begin
                sda_oe = 1'b0;  // Release SDA (STOP)
                scl = 1'b1;
            end
            
            default: begin
                sda_oe = 1'b0;
                scl = 1'b1;
            end
        endcase
    end

    //=========================================================================
    // Status Outputs
    //=========================================================================
    assign busy = (state != IDLE);
    assign ack_error = nack_flag;

endmodule