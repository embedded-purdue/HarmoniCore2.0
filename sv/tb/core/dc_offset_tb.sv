
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/core/dc_offset_if.vh"
import types::*;

module dc_offset_tb;
    parameter real FPGA_PERIOD = 6.4;   // 156 MHz

    logic fpga_clk = 0;
    logic n_rst;

    always #(FPGA_PERIOD/2) fpga_clk = ~fpga_clk;

    dc_offset_if dcif();
    dc_offset DUT (.fpga_clk(fpga_clk), .n_rst(n_rst), .dcif(dcif));
    dc_offset_test PROG (.fpga_clk(fpga_clk), .n_rst(n_rst), .dcif(dcif));

endmodule

program dc_offset_test (
    input logic fpga_clk,
    output logic n_rst,
    dc_offset_if.dc_offset_tb dcif
);
    // After 12000 samples the EMA (ALPHA=10) converges to >99.99% of any DC value.
    // At that point corr_data should be within CONVERGE_TOL LSBs of 0.
    parameter int CONVERGE_SAMPLES = 12000;
    parameter int CONVERGE_TOL     = 200;

    int pass_count, fail_count;

    // ── Helpers ───────────────────────────────────────────────────────────────

    task automatic do_reset();
        n_rst          = 1'b0;
        dcif.adc_valid = 1'b0;
        dcif.adc_data  = '0;
        repeat(4) @(negedge fpga_clk);
        n_rst = 1'b1;
        repeat(2) @(negedge fpga_clk);
    endtask

    // Drive one sample on negedge so it is stable before the next posedge.
    task automatic send(input int data, input logic valid = 1'b1);
        @(negedge fpga_clk);
        dcif.adc_data  = data[DW-1:0];  // truncate to 24-bit two's complement
        dcif.adc_valid = valid;
    endtask

    task automatic check(
        input string label,
        input int got,
        input int expected,
        input int tol
    );
        if (got >= (expected - tol) && got <= (expected + tol)) begin
            $display("  PASS  %-42s got=%-10d  exp=%0d +/-%0d",
                     label, got, expected, tol);
            pass_count++;
        end else begin
            $display("  FAIL  %-42s got=%-10d  exp=%0d +/-%0d",
                     label, got, expected, tol);
            fail_count++;
        end
    endtask

    // ── Test Cases ────────────────────────────────────────────────────────────

    // TC1 ─ After reset all outputs are 0
    task automatic tc1_reset();
        $display("\n[TC1] Reset");
        do_reset();
        @(negedge fpga_clk);
        check("dc_data  == 0",  $signed(dcif.dc_data),  0, 0);
        check("dc_valid == 0",  int'(dcif.dc_valid),    0, 0);
    endtask

    // TC2 ─ dc_valid is a 1-cycle registered copy of adc_valid
    task automatic tc2_valid_propagation();
        $display("\n[TC2] Valid Propagation");
        do_reset();
        send(100, 1'b1);
        @(negedge fpga_clk);   // output register latches on the posedge between these two negedges
        check("dc_valid high when adc_valid high", int'(dcif.dc_valid), 1, 0);
        send('0, 1'b0);
        @(negedge fpga_clk);
        check("dc_valid low  when adc_valid low",  int'(dcif.dc_valid), 0, 0);
    endtask

    // TC3 ─ Positive DC: constant +1000000 → output converges to 0
    task automatic tc3_positive_dc();
        $display("\n[TC3] Positive DC Convergence (+1000000)");
        do_reset();
        repeat(CONVERGE_SAMPLES) send(1000000);
        @(negedge fpga_clk);
        check("corrected output ~= 0", $signed(dcif.dc_data), 0, CONVERGE_TOL);
    endtask

    // TC4 ─ Negative DC: constant -1000000 → output converges to 0
    task automatic tc4_negative_dc();
        $display("\n[TC4] Negative DC Convergence (-1000000)");
        do_reset();
        repeat(CONVERGE_SAMPLES) send(-1000000);
        @(negedge fpga_clk);
        check("corrected output ~= 0", $signed(dcif.dc_data), 0, CONVERGE_TOL);
    endtask

    // TC5 ─ AC only (no DC): mean stays ~0, audio content passes through
    // Alternating +A / -A averages to 0 so the mean should converge to ~0.
    // After convergence, one more +500000 sample should appear nearly unchanged.
    task automatic tc5_ac_only();
        $display("\n[TC5] AC Only  (alternating +/-500000, mean should stay ~0)");
        do_reset();
        repeat(CONVERGE_SAMPLES / 2) begin
            send( 500000);
            send(-500000);
        end
        send(500000);   // final sample; with mean ~0, output should be ~+500000
        @(negedge fpga_clk);
        check("AC content passes through", $signed(dcif.dc_data), 500000, 1000);
    endtask

    // TC6 ─ Valid gating: mean must not change while adc_valid = 0
    // 1. Converge mean to +1000000.
    // 2. Feed opposite extreme with valid=0 — mean must hold.
    // 3. One valid sample at +1000000 — output must still be ~0.
    task automatic tc6_valid_gating();
        $display("\n[TC6] Valid Gating");
        do_reset();
        repeat(CONVERGE_SAMPLES) send(1000000, 1'b1);
        repeat(1000)             send(-8000000, 1'b0);   // must not affect mean
        send(1000000, 1'b1);
        @(negedge fpga_clk);
        check("mean held while valid=0", $signed(dcif.dc_data), 0, CONVERGE_TOL);
    endtask

    // TC7 ─ Large DC near the rail (+7000000, ~83 % of full scale)
    task automatic tc7_large_dc();
        $display("\n[TC7] Large DC  (+7000000)");
        do_reset();
        repeat(CONVERGE_SAMPLES) send(7000000);
        @(negedge fpga_clk);
        // Error scales with DC value; allow slightly larger tolerance here.
        check("large DC corrected to 0", $signed(dcif.dc_data), 0, 1000);
    endtask

    // TC8 ─ DC step change: converge on one value then switch to another
    // Mean must track the new value after enough samples.
    task automatic tc8_dc_step();
        $display("\n[TC8] DC Step Change (+500000 -> -500000)");
        do_reset();
        repeat(CONVERGE_SAMPLES) send( 500000);  // converge on positive DC
        repeat(CONVERGE_SAMPLES) send(-500000);  // switch to negative DC
        @(negedge fpga_clk);
        check("re-converged after step", $signed(dcif.dc_data), 0, CONVERGE_TOL);
    endtask

    // ── Main ──────────────────────────────────────────────────────────────────
    initial begin
        pass_count = 0;
        fail_count = 0;

        tc1_reset();
        tc2_valid_propagation();
        tc3_positive_dc();
        tc4_negative_dc();
        tc5_ac_only();
        tc6_valid_gating();
        tc7_large_dc();
        tc8_dc_step();

        $display("\n─────────────────────────────────────────────");
        if (fail_count == 0)
            $display("ALL PASS  (%0d / %0d)", pass_count, pass_count + fail_count);
        else
            $display("FAILED    (%0d passed, %0d failed)",
                     pass_count, fail_count);
        $display("─────────────────────────────────────────────");
        $finish;
    end

endprogram
