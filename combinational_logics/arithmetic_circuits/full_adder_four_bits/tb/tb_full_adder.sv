`timescale 1ns/1ps

module tb_full_adder;

    logic A, B, Cin;
    logic Sum, Cout;

    logic expected_Sum, expected_Cout;

    int total_passed = 0;
    int total_failed = 0;

    // Instantiate DUT
    full_adder DUT (
        .A     (A),
        .B     (B),
        .Cin   (Cin),
        .Sum   (Sum),
        .Cout  (Cout)
    );

    initial begin
        $display("🔷 Starting Full Adder Testbench");

        // Loop through all input combinations
        for (int i = 0; i < 8; i++) begin
            {A, B, Cin} = i[2:0];
            #10;  // wait for outputs to settle

            calculate_expected(A, B, Cin, expected_Sum, expected_Cout);
            compare("Sum", expected_Sum, Sum);
            compare("Cout", expected_Cout, Cout);
        end

        report();
        $display(" Testbench completed.");
        $finish;
    end

    // Task to calculate expected outputs
    task automatic calculate_expected(
        input  logic A,
        input  logic B,
        input  logic Cin,
        output logic expected_Sum,
        output logic expected_Cout
    );
        int total = A + B + Cin;
        expected_Sum  = total[0];
        expected_Cout = total[1];
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(
        input string signal_name,
        input logic expected,
        input logic actual
    );
        if (expected !== actual) begin
            $display("  ❌ Mismatch: %s: Expected=%b, Got=%b [A=%b, B=%b, Cin=%b]", signal_name, expected, actual, A, B, Cin);
            total_failed++;
        end else begin
            $display("  ✅ Match: %s=%b [A=%b, B=%b, Cin=%b]", signal_name, actual, A, B, Cin);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display("  🎉 All tests passed successfully!");
        else
            $display("  ⚠️ Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
