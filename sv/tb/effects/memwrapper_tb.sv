
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/memwrapper_if.vh"
import types::*;

module memwrapper_tb;
    parameter real FPGA_PERIOD = 6.4;  // 156 MHz

    logic clk = 1'b0;
    logic n_rst;

    always #(FPGA_PERIOD / 2.0) clk = ~clk;

    memwrapper_if memif();
    logic [8*40-1:0] test_name;  // ASCII label — add to wave, set Radix → ASCII

    memwrapper DUT  (.clk(clk), .n_rst(n_rst), .memif(memif));
    memwrapper_test PROG (.clk(clk), .n_rst(n_rst), .test_name(test_name), .memif(memif));

endmodule


program memwrapper_test (
    input  logic clk,
    output logic n_rst,
    output logic [8*40-1:0] test_name,
    memwrapper_if.mem_tb memif
);
    int pass_count, fail_count;

    task automatic do_reset();
        n_rst       = 1'b0;
        memif.wea   = 1'b0;   memif.web   = 1'b0;
        memif.addra = '0;     memif.addrb = '0;
        memif.dina  = '0;     memif.dinb  = '0;
        repeat(4) @(negedge clk);
        n_rst = 1'b1;
        repeat(2) @(negedge clk);
    endtask

    // Drive a write on both ports simultaneously.
    task automatic do_write(
        input logic [7:0]    addr_a, addr_b,
        input logic [DW-1:0] data_a, data_b
    );
        @(negedge clk);
        memif.wea   = 1'b1;   memif.web   = 1'b1;
        memif.addra = addr_a; memif.addrb = addr_b;
        memif.dina  = data_a; memif.dinb  = data_b;
    endtask

    // Initiate a read on both ports. Data is on douta/doutb one cycle later.
    task automatic do_read(input logic [7:0] addr_a, addr_b);
        @(negedge clk);
        memif.wea   = 1'b0;   memif.web   = 1'b0;
        memif.addra = addr_a; memif.addrb = addr_b;
    endtask

    task automatic check(
        input string         label,
        input logic [DW-1:0] got,
        input logic [DW-1:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %-40s got=%0d", label, $signed(got));
            pass_count++;
        end else begin
            $display("  FAIL  %-40s got=%0d  exp=%0d", label, $signed(got), $signed(expected));
            fail_count++;
        end
    endtask

    // ── Test Cases ────────────────────────────────────────────────────────────

    // TC1 — Write a value to Port A and read it back through Port A
    task automatic tc1_write_read_porta();
        test_name = "TC1: Write then Read - Port A";
        $display("\n[TC1] Write then Read - Port A");
        do_reset();
        do_write(8'h0A, 8'h00, 24'h123456, 24'h0);  // write 0x123456 to addr 0x0A
        do_read(8'h0A, 8'h00);                        // read back addr 0x0A on Port A
        @(negedge clk);                               // wait 1 cycle for registered output
        check("Port A readback addr 0x0A", memif.douta, 24'h123456);
    endtask

    // TC2 — Write a value to Port B and read it back through Port B
    task automatic tc2_write_read_portb();
        test_name = "TC2: Write then Read - Port B";
        $display("\n[TC2] Write then Read - Port B");
        do_reset();
        do_write(8'h00, 8'h1F, 24'h0, 24'hABCDEF);  // write 0xABCDEF to addr 0x1F
        do_read(8'h00, 8'h1F);                        // read back addr 0x1F on Port B
        @(negedge clk);
        check("Port B readback addr 0x1F", memif.doutb, 24'hABCDEF);
    endtask

    // TC3 — Write different values to two addresses and read both simultaneously
    task automatic tc3_simultaneous_read();
        test_name = "TC3: Simultaneous Read - both ports";
        $display("\n[TC3] Simultaneous Read - both ports (vibrato use case)");
        do_reset();
        do_write(8'h20, 8'h21, 24'h111111, 24'h222222);  // write adjacent samples
        do_read(8'h20, 8'h21);                             // read rd0 and rd1 at same time
        @(negedge clk);
        check("Port A (rd0) = 0x111111", memif.douta, 24'h111111);
        check("Port B (rd1) = 0x222222", memif.doutb, 24'h222222);
    endtask

    // TC4 — valid_a and valid_b assert exactly 1 cycle after the read address
    task automatic tc4_valid_timing();
        test_name = "TC4: Valid Signal Timing";
        $display("\n[TC4] Valid Signal Timing");
        do_reset();
        do_write(8'h05, 8'h06, 24'hDEAD00, 24'hBEEF00);

        // Initiate read — valid should NOT be high yet
        @(negedge clk);
        memif.wea = 1'b0; memif.web = 1'b0;
        memif.addra = 8'h05; memif.addrb = 8'h06;

        // Check: valid_a and valid_b should be 0 before BRAM output is ready
        check("valid_a = 0 before read completes", {23'b0, memif.valid_a}, 24'h0);
        check("valid_b = 0 before read completes", {23'b0, memif.valid_b}, 24'h0);

        // 1 cycle later — BRAM registered output is ready, valid should assert
        @(negedge clk);
        check("valid_a = 1 after 1 cycle",  {23'b0, memif.valid_a}, 24'h1);
        check("valid_b = 1 after 1 cycle",  {23'b0, memif.valid_b}, 24'h1);
        check("douta correct", memif.douta, 24'hDEAD00);
        check("doutb correct", memif.doutb, 24'hBEEF00);

        // valid should deassert when no read is in flight
        @(negedge clk);
        memif.wea = 1'b1; memif.web = 1'b1;  // switch to write — no read pending
        @(negedge clk);
        check("valid_a = 0 when not reading", {23'b0, memif.valid_a}, 24'h0);
        check("valid_b = 0 when not reading", {23'b0, memif.valid_b}, 24'h0);
    endtask

    // TC5 — Write to all 256 entries and verify a sample of them
    task automatic tc5_full_address_sweep();
        test_name = "TC5: Full Address Sweep";
        $display("\n[TC5] Full Address Sweep (256 entries)");
        do_reset();

        // Write: addr N → value N*10 on both ports (stagger addresses by 1)
        for (int i = 0; i < 255; i++) begin
            do_write(8'(i), 8'(i+1), DW'(i * 10), DW'((i+1) * 10));
        end

        // Read back a few spot-check addresses
        do_read(8'h00, 8'h01);
        @(negedge clk);
        check("addr 0x00 = 0",  memif.douta, 24'd0);
        check("addr 0x01 = 10", memif.doutb, 24'd10);

        do_read(8'h7F, 8'h80);
        @(negedge clk);
        check("addr 0x7F = 1270", memif.douta, 24'd1270);
        check("addr 0x80 = 1280", memif.doutb, 24'd1280);

        do_read(8'hFE, 8'hFF);
        @(negedge clk);
        check("addr 0xFE = 2540", memif.douta, 24'd2540);
        // addr 0xFF was never written (loop only goes to i=254), so skip doutb
    endtask

    // TC6 — Write to Port A, read back through Port B (cross-port check)
    task automatic tc6_cross_port();
        test_name = "TC6: Cross-Port Readback";
        $display("\n[TC6] Cross-Port Readback (write A, read B)");
        do_reset();
        do_write(8'h42, 8'h00, 24'hC0FFEE, 24'h0);  // write to addr 0x42 via Port A
        do_read(8'h00, 8'h42);                        // read addr 0x42 via Port B
        @(negedge clk);
        check("Port B reads value written by Port A", memif.doutb, 24'hC0FFEE);
    endtask

    // ── Main ──────────────────────────────────────────────────────────────────
    initial begin
        pass_count = 0;
        fail_count = 0;

        tc1_write_read_porta();
        tc2_write_read_portb();
        tc3_simultaneous_read();
        tc4_valid_timing();
        tc5_full_address_sweep();
        tc6_cross_port();

        $display("\n─────────────────────────────────────────────");
        if (fail_count == 0)
            $display("ALL PASS  (%0d / %0d)", pass_count, pass_count + fail_count);
        else
            $display("FAILED    (%0d passed, %0d failed)", pass_count, fail_count);
        $display("─────────────────────────────────────────────");
        $finish;
    end

endprogram
