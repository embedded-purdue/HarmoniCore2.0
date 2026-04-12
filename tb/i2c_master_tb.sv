//=========================================================================
// I2C Master Testbench
// Author: Kameron Jackson
// Username: jacks908@purdue.edu
//=========================================================================

`timescale 1ns/1ps

module tb_i2c_master;

    //=========================================================================
    // Testbench Signals
    //=========================================================================
    logic       clk;
    logic       n_rst;
    logic       i2c_en;
    logic [6:0] slave_addr;
    logic [7:0] reg_addr;
    logic [7:0] data_in;
    logic       busy;
    logic       ack_error;
    wire        sda;
    logic       scl;
    
    //=========================================================================
    // Slave Simulation Signals
    //=========================================================================
    logic slave_ack_enable;
    integer scl_rise_count;
    
    // Pull-up simulation
    assign (weak0, weak1) sda = 1'b1;
    
    // Slave ACK - pulls SDA low after each byte (8 bits)
    assign (strong0, weak1) sda = slave_ack_enable ? 1'b0 : 1'bz;

    //=========================================================================
    // DUT
    //=========================================================================
    i2c_master DUT (
        .clk        (clk),
        .n_rst      (n_rst),
        .i2c_en     (i2c_en),
        .slave_addr (slave_addr),
        .reg_addr   (reg_addr),
        .data_in    (data_in),
        .busy       (busy),
        .ack_error  (ack_error),
        .sda        (sda),
        .scl        (scl)
    );

    //=========================================================================
    // Clock Generation: 50MHz = 20ns period
    //=========================================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    //=========================================================================
    // SCL Rise Counter
    //=========================================================================
    always @(posedge scl, negedge n_rst) begin
        if (!n_rst)
            scl_rise_count <= 0;
        else
            scl_rise_count <= scl_rise_count + 1;
    end

    //=========================================================================
    // Slave ACK Logic
    // ACK after each byte: bits 8, 17, 26
    //=========================================================================
    always @(*) begin
        if ((scl_rise_count >= 8 && scl_rise_count < 10) ||
            (scl_rise_count >= 17 && scl_rise_count < 19) ||
            (scl_rise_count >= 26 && scl_rise_count < 28))
            slave_ack_enable = 1'b1;
        else
            slave_ack_enable = 1'b0;
    end

    //=========================================================================
    // Test Tasks
    //=========================================================================
    
    // Reset task
    task reset_dut();
        begin
            n_rst = 1'b0;
            i2c_en = 1'b0;
            slave_addr = 7'h00;
            reg_addr = 8'h00;
            data_in = 8'h00;
            @(posedge clk);
            @(posedge clk);
            n_rst = 1'b1;
            @(posedge clk);
        end
    endtask
    
    // Send I2C write task
    task send_i2c_write(
        input [6:0] addr,
        input [7:0] reg_a,
        input [7:0] data
    );
        begin
            @(posedge clk);
            slave_addr = addr;
            reg_addr = reg_a;
            data_in = data;
            i2c_en = 1'b1;
            
            // Wait for busy to go high
            wait (busy == 1'b1);
            @(posedge clk);
            i2c_en = 1'b0;
            
            // Wait for transaction to complete
            wait (busy == 1'b0);
            @(posedge clk);
        end
    endtask

    //=========================================================================
    // Test Sequence
    //=========================================================================
    initial begin
        $display("=========================================");
        $display("      I2C Master Testbench Start");
        $display("=========================================");
        
        // Initialize
        reset_dut();
        
        //---------------------------------------------------------------------
        // Test 1: Write to DAC address 0x18, register 0x1B, data 0x0D
        //---------------------------------------------------------------------
        $display("\n--- Test 1: Write 0x0D to reg 0x1B at addr 0x18 ---");
        $display("Time %0t: Starting transaction", $time);
        
        send_i2c_write(7'h18, 8'h1B, 8'h0D);
        
        $display("Time %0t: Transaction complete", $time);
        $display("ACK error: %b (expected 0)", ack_error);
        
        if (ack_error == 1'b0)
            $display("TEST 1 PASSED!");
        else
            $display("TEST 1 FAILED!");
        
        // Reset counter for next test
        #1000;
        reset_dut();
        
        //---------------------------------------------------------------------
        // Test 2: Write to DAC address 0x18, register 0x00, data 0x01
        //---------------------------------------------------------------------
        $display("\n--- Test 2: Write 0x01 to reg 0x00 (page select) ---");
        $display("Time %0t: Starting transaction", $time);
        
        send_i2c_write(7'h18, 8'h00, 8'h01);
        
        $display("Time %0t: Transaction complete", $time);
        $display("ACK error: %b (expected 0)", ack_error);
        
        if (ack_error == 1'b0)
            $display("TEST 2 PASSED!");
        else
            $display("TEST 2 FAILED!");
        
        // Reset counter for next test
        #1000;
        reset_dut();
        
        //---------------------------------------------------------------------
        // Test 3: Different slave address (0x50)
        //---------------------------------------------------------------------
        $display("\n--- Test 3: Write to different slave addr 0x50 ---");
        $display("Time %0t: Starting transaction", $time);
        
        send_i2c_write(7'h50, 8'hAA, 8'h55);
        
        $display("Time %0t: Transaction complete", $time);
        $display("ACK error: %b (expected 0)", ack_error);
        
        if (ack_error == 1'b0)
            $display("TEST 3 PASSED!");
        else
            $display("TEST 3 FAILED!");
        
        //---------------------------------------------------------------------
        // Done
        //---------------------------------------------------------------------
        #1000;
        $display("\n=========================================");
        $display("      I2C Master Testbench Complete");
        $display("=========================================");
        $finish;
    end

    //=========================================================================
    // Debug Monitor
    //=========================================================================
    always @(posedge scl) begin
        $display("Time %0t: SCL rise #%0d, state=%0d, sda=%b", 
                 $time, scl_rise_count, DUT.state, sda);
    end

    //=========================================================================
    // Waveform Dump
    //=========================================================================
    initial begin
        $dumpfile("tb_i2c_master.vcd");
        $dumpvars(0, tb_i2c_master);
    end

    //=========================================================================
    // Timeout
    //=========================================================================
    initial begin
        #5000000;
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule