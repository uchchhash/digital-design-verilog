`timescale 1ns/1ps

module tb_multiplier_4_bits;

  // --------------------------------------------------------------------------
  // Testbench Signals
  // --------------------------------------------------------------------------
  logic [3:0] a_tb; // Using distinct names for TB signals to avoid confusion
  logic [3:0] b_tb;
  logic [7:0] p_tb;

  logic [7:0] expected_p; // Expected product calculated by testbench

  int total_tests = 0;
  int total_passed = 0;
  int total_failed = 0;

  // --------------------------------------------------------------------------
  // Instantiate Device Under Test (DUT)
  // --------------------------------------------------------------------------
  four_bit_multiplier DUT (
    .A (a_tb), // Connect testbench signals to DUT ports
    .B (b_tb),
    .P (p_tb)
  );

  // --------------------------------------------------------------------------
  // Initial Block for Test Sequence Control
  // --------------------------------------------------------------------------
  initial begin
    $display("🔷 Starting 4x4 Unsigned Multiplier Testbench");

    // Configure for VCD waveform dumping (optional)
    $dumpfile("tb_multiplier_4_bits.vcd");
    $dumpvars(0, tb_multiplier_4_bits);

    // Exhaustive Test Loop (256 combinations)
    for (int i = 0; i < 16; i++) begin
      for (int j = 0; j < 16; j++) begin
        total_tests++;
        a_tb = i[3:0];
        b_tb = j[3:0];
        #10; // Allow sufficient time for combinational logic to propagate and settle

        // Calculate expected value using SystemVerilog's built-in multiplication
        expected_p = a_tb * b_tb;

        // Call the comparison task
        check_result("Product", expected_p, p_tb, a_tb, b_tb);
      end
    end

    // Report test summary
    report_summary();

    $display(" Testbench completed.");
    $finish; // End simulation
  end

  // --------------------------------------------------------------------------
  // Tasks for Testbench Operations
  // --------------------------------------------------------------------------

  // Task to compare expected and actual outputs for a specific test case
  task automatic check_result(
    input string signal_name,
    input logic [7:0] expected,
    input logic [7:0] actual,
    input logic [3:0] current_a,
    input logic [3:0] current_b
  );
    if (expected !== actual) begin // Using '===' for X/Z sensitivity, '==' for value only
      $error("❌ Mismatch for %s: A=%0d (0x%h), B=%0d (0x%h) | Expected P=%0d (0x%h), Actual P=%0d (0x%h)",
             signal_name, current_a, current_a, current_b, current_b,
             expected, expected, actual, actual);
      total_failed++;
    end else begin
      // Optional: uncomment for verbose passing messages
      // $info("✅ Match for %s: A=%0d (0x%h), B=%0d (0x%h) | P=%0d (0x%h)",
      //       signal_name, current_a, current_a, current_b, current_b, actual, actual);
      total_passed++;
    end
  endtask

  // Task to print the final test summary
  task automatic report_summary();
    $display("\n-------------------------------------------------");
    $display("Test Summary:");
    $display("  Total Tests Run: %0d", total_tests);
    $display("  Passed: %0d", total_passed);
    $display("  Failed: %0d", total_failed);
    if (total_failed == 0)
      $display("  🎉 All %0d tests passed successfully!", total_passed);
    else
      $display("  ⚠️ %0d tests failed. Please check the log for details.", total_failed);
    $display("-------------------------------------------------");
  endtask


endmodule