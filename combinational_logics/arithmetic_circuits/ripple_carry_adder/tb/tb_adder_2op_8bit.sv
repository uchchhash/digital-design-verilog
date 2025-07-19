`timescale 1ns/1ps

module tb_adder_2op_8bit;

    logic [7:0] A, B;
    logic       Cin;
    logic [8:0] S;

    logic [8:0] expected_S;

    int total_passed = 0;
    int total_failed = 0;

    int NUM_RANDOM_TESTS = 200000;

    // Instantiate DUT
    rca_2op_8bit DUT (
        .A   (A),
        .B   (B),
        .Cin (Cin),
        .S   (S)
    );

    initial begin
        $display("🔷 Starting RCA 2-Operand 8-bit Testbench");

        // Directed test cases
        run_test(8'h00, 8'h00, 1'b0);
        run_test(8'h01, 8'h01, 1'b0);
        run_test(8'hFF, 8'h00, 1'b0);
        run_test(8'hFF, 8'h01, 1'b0);
        run_test(8'hFF, 8'hFF, 1'b0);
        run_test(8'hF0, 8'h0F, 1'b0);
        run_test(8'h00, 8'h00, 1'b1);
        run_test(8'h01, 8'h01, 1'b1);
        run_test(8'hFF, 8'h00, 1'b1);
        run_test(8'hFF, 8'h01, 1'b1);
        run_test(8'hFF, 8'hFF, 1'b1);
        run_test(8'hF0, 8'h0F, 1'b1);
        run_test(8'd123, 8'd100, 1'b1);
        run_test(8'd200, 8'd55, 1'b1);

        // Randomized test cases
        $display("🔷 Running %0d randomized test cases...", NUM_RANDOM_TESTS);
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            A   = $urandom_range(0, 8'hFF);
            B   = $urandom_range(0, 8'hFF);
            Cin = $urandom_range(0, 1);

            #10; // wait for outputs to settle
            expected_S = A + B + Cin;
            compare($sformatf("Random Test %0d", i), expected_S, S);
        end

        report();
        $display(" Testbench completed.");
        $finish;
    end

    // Task to run one test
    task automatic run_test(
        input logic [7:0] a_in,
        input logic [7:0] b_in,
        input logic       cin_in
    );
        begin
            A   = a_in;
            B   = b_in;
            Cin = cin_in;
            #10; // Wait for outputs to settle

            expected_S = a_in + b_in + cin_in;

            compare("Directed Test", expected_S, S);
        end
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(
        input string test_name,
        input logic [8:0] expected,
        input logic [8:0] actual
    );
        if (expected !== actual) begin
            $display("  ❌ FAIL: %s", test_name);
            $display("     Expected: %h (%0d)", expected, expected);
            $display("     Got     : %h (%0d)", actual, actual);
            $display("     Inputs  : A=%h (%0d), B=%h (%0d), Cin=%b", 
                A, A, B, B, Cin);
            total_failed++;
        end else begin
            $display("  ✅ PASS: %s → Sum=%h (%0d) [A=%h (%0d), B=%h (%0d), Cin=%b]", 
                test_name, actual, actual, A, A, B, B, Cin);
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
